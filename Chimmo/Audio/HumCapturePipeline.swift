import AVFAudio
import Foundation
import os

/// Strict half-duplex on-device hum fundamental capture pipeline:
/// serializes AVAudioEngine capture teardown/startup cleanly on a dedicated session queue,
/// tracks live contour in RAM, and extracts median voiced F0 in Hz without network or disk writes.
@MainActor
public final class HumCapturePipeline: ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isStartingCapture: Bool = false
    @Published public private(set) var inputLevel: Double = 0.0
    @Published public private(set) var livePitchTrace: [Double] = []
    @Published public private(set) var statusMessage: String = ""

    private let router: HalfDuplexAudioRouter
    private let synth: FeltPianoSynth
    private let detector: any PitchDetector
    private let sessionQueue = DispatchQueue(label: "app.chimmo.hum.session", qos: .userInitiated)

    private var recordEngine: AVAudioEngine?
    private let sampleLock = OSAllocatedUnfairLock(initialState: [Float]())
    private var capturedSampleRate: Double = 48_000.0
    private var startTimestamp: Date?
    private var lastLevelTick: Date = .distantPast
    private var liveTraceTask: Task<Void, Never>?
    private var captureGeneration: UInt64 = 0
    private var observerTokens: [NSObjectProtocol] = []
    private var engineConfigToken: NSObjectProtocol?

    public init(
        router: HalfDuplexAudioRouter,
        synth: FeltPianoSynth,
        detector: any PitchDetector = YINvDSPPitchDetector()
    ) {
        self.router = router
        self.synth = synth
        self.detector = detector
        installSessionObservers()
    }

    deinit {
        let nc = NotificationCenter.default
        for token in observerTokens {
            nc.removeObserver(token)
        }
        if let tok = engineConfigToken {
            nc.removeObserver(tok)
        }
    }

    private func installSessionObservers() {
        let nc = NotificationCenter.default
        #if os(iOS)
        let inactiveToken = nc.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let ctx = note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
            guard ctx?.source != .app else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRecording || self.isStartingCapture else { return }
                self.cancelRecording()
            }
        }
        observerTokens.append(inactiveToken)

        let mediaResetToken = nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording || self.isStartingCapture else { return }
                self.cancelRecording()
            }
        }
        observerTokens.append(mediaResetToken)

        let routeToken = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let reasonRaw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            let reason = reasonRaw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRecording || self.isStartingCapture else { return }
                self.cancelRecording()
            }
        }
        observerTokens.append(routeToken)
        #endif
    }

    public func startRecording() {
        guard !isRecording, !isStartingCapture else { return }
        isStartingCapture = true
        statusMessage = ""
        synth.stopForRecordingAsync { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isStartingCapture else { return }
                self.requestPermissionAndBegin()
            }
        }
    }

    private func requestPermissionAndBegin() {
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            beginEngineCaptureAsync()
        case .denied:
            isStartingCapture = false
            synth.resumeAfterRecording()
            statusMessage = String(
                localized: "hum_mic_denied",
                defaultValue: "未开启麦克风权限，可先前往系统设置允许，或直接从常用人声声高里挑选"
            )
        case .undetermined:
            Task { @MainActor [weak self] in
                let granted = await AVAudioApplication.requestRecordPermission()
                guard let self, self.isStartingCapture else { return }
                if granted {
                    self.beginEngineCaptureAsync()
                } else {
                    self.isStartingCapture = false
                    self.synth.resumeAfterRecording()
                    self.statusMessage = String(
                        localized: "hum_mic_denied",
                        defaultValue: "未开启麦克风权限，可先前往系统设置允许，或直接从常用人声声高里挑选"
                    )
                }
            }
        @unknown default:
            beginEngineCaptureAsync()
        }
        #else
        beginEngineCaptureAsync()
        #endif
    }

    private func beginEngineCaptureAsync() {
        captureGeneration &+= 1
        let generation = captureGeneration
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []
        let routerRef = router
        let bufferLock = sampleLock
        let queueRef = sessionQueue
        bufferLock.withLock { $0.removeAll(keepingCapacity: true) }
        statusMessage = ""

        queueRef.async { [weak self] in
            do {
                try routerRef.configure(mode: .recording)
                let engine = AVAudioEngine()
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                let sr = format.sampleRate
                guard format.commonFormat == .pcmFormatFloat32,
                      sr.isFinite, sr >= 8_000.0, sr <= 192_000.0, format.channelCount >= 1 else {
                    throw NSError(
                        domain: "app.chimmo.humcapture",
                        code: -10,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid microphone input format"]
                    )
                }
                let maxSampleCap = Int(sr * 12.0)

                try input.installAudioTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    guard case let .float(span) = buffer.channelData(0) else { return }
                    let count = min(buffer.frameLength, span.count)
                    guard count > 0 else { return }

                    var sumSq: Float = 0.0
                    var frozenChunk = [Float]()
                    frozenChunk.reserveCapacity(count)
                    for idx in 0..<count {
                        let s = span[idx]
                        let safe = s.isFinite ? s : Float(0.0)
                        sumSq += safe * safe
                        frozenChunk.append(safe)
                    }
                    let chunk = frozenChunk
                    bufferLock.withLock { buf in
                        if buf.count < maxSampleCap {
                            buf.append(contentsOf: chunk)
                        }
                    }
                    let rms = sqrt(Double(sumSq) / Double(count))
                    let normalized = min(1.0, rms * 6.5)
                    Task { @MainActor [weak self] in
                        guard let self, self.captureGeneration == generation, self.isRecording else { return }
                        let now = Date()
                        if now.timeIntervalSince(self.lastLevelTick) >= 0.05 {
                            self.lastLevelTick = now
                            self.inputLevel = normalized
                        }
                    }
                }

                engine.prepare()
                try engine.start()

                Task { @MainActor [weak self] in
                    guard let self, self.captureGeneration == generation, self.isStartingCapture else {
                        queueRef.async {
                            engine.inputNode.removeTap(onBus: 0)
                            engine.stop()
                        }
                        return
                    }
                    self.isStartingCapture = false
                    self.recordEngine = engine
                    self.capturedSampleRate = sr
                    self.startTimestamp = Date()
                    self.isRecording = true
                    self.statusMessage = ""
                    self.attachConfigObserver(for: engine, generation: generation)
                    self.startLivePitchTracker()
                }
            } catch {
                try? routerRef.configure(mode: .playback)
                Task { @MainActor [weak self] in
                    guard let self, self.captureGeneration == generation else { return }
                    self.isStartingCapture = false
                    self.liveTraceTask?.cancel()
                    self.liveTraceTask = nil
                    self.livePitchTrace = []
                    self.statusMessage = String(
                        localized: "hum_mic_unavailable",
                        defaultValue: "麦克风暂时不可用，可直接从下方常用人声声高里选"
                    )
                    self.isRecording = false
                    self.synth.resumeAfterRecording()
                }
            }
        }
    }

    private func attachConfigObserver(for eng: AVAudioEngine, generation: UInt64) {
        if let old = engineConfigToken {
            NotificationCenter.default.removeObserver(old)
            engineConfigToken = nil
        }
        engineConfigToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: eng,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.captureGeneration == generation, self.isRecording || self.isStartingCapture else { return }
                self.cancelRecording()
            }
        }
    }

    private func startLivePitchTracker() {
        liveTraceTask?.cancel()
        livePitchTrace = []
        let det = detector
        let lock = sampleLock
        let srcRate = capturedSampleRate

        liveTraceTask = Task { @MainActor [weak self] in
            var recentSemitones: [Double] = []
            var lastSampleTotal = 0
            while !Task.isCancelled {
                guard let self, self.isRecording else { break }
                let snapshot = lock.withLock { buf -> (total: Int, tail: [Float]) in
                    let total = buf.count
                    let tailCount = max(1024, Int(srcRate * 0.09))
                    if total <= tailCount {
                        return (total, buf)
                    }
                    return (total, Array(buf.suffix(tailCount)))
                }

                if snapshot.total > lastSampleTotal && snapshot.tail.count >= max(512, Int(srcRate * 0.05)) {
                    lastSampleTotal = snapshot.total
                    let tail = snapshot.tail
                    let semitone = await Task.detached(priority: .utility) { () -> Double? in
                        var sumSq = 0.0
                        for v in tail { sumSq += Double(v * v) }
                        let rms = sqrt(sumSq / Double(max(1, tail.count)))
                        guard rms >= 0.0045 else { return nil }
                        let mono16k = HumCapturePipeline.resampleLinear(tail, from: srcRate, to: PitchContour.sampleRate)
                        let contour = det.detect(mono16kSamples: mono16k, fmin: 75.0, fmax: 1100.0)
                        var validSemis: [Double] = []
                        for i in 0..<contour.pitchHz.count {
                            let hz = contour.pitchHz[i]
                            let conf = i < contour.confidence.count ? contour.confidence[i] : 1.0
                            if hz > 65.0 && conf >= 0.35 {
                                validSemis.append(12.0 * log2(hz / 110.0))
                            }
                        }
                        guard !validSemis.isEmpty else { return nil }
                        let sorted = validSemis.sorted()
                        return sorted[sorted.count / 2]
                    }.value

                    guard !Task.isCancelled, self.isRecording else { break }
                    if let s = semitone, s.isFinite {
                        recentSemitones.append(s)
                        if recentSemitones.count > 28 {
                            recentSemitones.removeFirst(recentSemitones.count - 28)
                        }
                        self.livePitchTrace = LivePitchContourFilter.normalizeSemitoneTrace(recentSemitones)
                    }
                }
                try? await Task.sleep(nanoseconds: 85_000_000)
            }
        }
    }

    public func cancelRecording() {
        captureGeneration &+= 1
        isStartingCapture = false
        isRecording = false
        inputLevel = 0.0
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []
        if let tok = engineConfigToken {
            NotificationCenter.default.removeObserver(tok)
            engineConfigToken = nil
        }

        let engineToStop = recordEngine
        recordEngine = nil
        sampleLock.withLock { $0.removeAll(keepingCapacity: false) }
        statusMessage = ""

        let routerRef = router
        sessionQueue.async { [weak self] in
            if let engineToStop {
                engineToStop.inputNode.removeTap(onBus: 0)
                engineToStop.stop()
            }
            try? routerRef.configure(mode: .playback)
            Task { @MainActor [weak self] in
                self?.synth.resumeAfterRecording()
            }
        }
    }

    /// Captures on-device natural hum fundamental (Hz) to tune a personal acoustic resonance frequency.
    public func stopAndExtractFundamentalHz() async -> Double? {
        guard isRecording else { return nil }
        captureGeneration &+= 1
        isStartingCapture = false
        isRecording = false
        inputLevel = 0.0
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []
        if let tok = engineConfigToken {
            NotificationCenter.default.removeObserver(tok)
            engineConfigToken = nil
        }

        let engineToStop = recordEngine
        recordEngine = nil
        let elapsed = Date().timeIntervalSince(startTimestamp ?? Date())
        let rawSamples = sampleLock.withLock { buf -> [Float] in
            let copy = buf
            buf.removeAll(keepingCapacity: false)
            return copy
        }
        let sourceRate = capturedSampleRate
        let routerRef = router

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if let engineToStop {
                    engineToStop.inputNode.removeTap(onBus: 0)
                    engineToStop.stop()
                }
                try? routerRef.configure(mode: .playback)
                cont.resume()
            }
        }
        synth.resumeAfterRecording()

        guard elapsed >= 0.4, rawSamples.count > Int(sourceRate * 0.35) else {
            statusMessage = String(
                localized: "hum_too_short",
                defaultValue: "再轻轻多哼一小会儿，我就能锁住你的频率"
            )
            return nil
        }

        statusMessage = ""
        let det = detector

        let medianHz: Double? = await Task.detached(priority: .userInitiated) {
            let mono16k = HumCapturePipeline.resampleLinear(rawSamples, from: sourceRate, to: PitchContour.sampleRate)
            let contour = det.detect(mono16kSamples: mono16k, fmin: 70.0, fmax: 700.0)
            let rmsFrames = LivePitchContourFilter.frameRMS(
                mono16kSamples: mono16k,
                frameCount: contour.pitchHz.count,
                hopSize: PitchContour.hopSize
            )
            var voicedHz: [Double] = []
            for i in 0..<contour.pitchHz.count {
                let hz = contour.pitchHz[i]
                let conf = i < contour.confidence.count ? contour.confidence[i] : 1.0
                let rms = i < rmsFrames.count ? rmsFrames[i] : 0.05
                if hz.isFinite && hz >= 70.0 && hz <= 700.0 && conf >= 0.42 && rms >= 0.004 {
                    voicedHz.append(hz)
                }
            }
            guard voicedHz.count >= 3 else { return nil }
            let sorted = voicedHz.sorted()
            return sorted[sorted.count / 2]
        }.value

        if let hz = medianHz, hz.isFinite {
            statusMessage = ""
            return hz
        } else {
            statusMessage = String(
                localized: "hum_not_detected",
                defaultValue: "没听清轻哼声，再靠近轻哼试试，或直接选常用人声"
            )
            return nil
        }
    }

    nonisolated public static func resampleLinear(_ input: [Float], from srcRate: Double, to dstRate: Double) -> [Float] {
        guard !input.isEmpty, srcRate.isFinite, dstRate.isFinite, srcRate > 0, dstRate > 0 else { return [] }
        if abs(srcRate - dstRate) < 1.0 { return input }
        let ratio = srcRate / dstRate
        let outCount = max(1, Int(Double(input.count) / ratio))
        var out = [Float](repeating: 0, count: outCount)
        let lastIdx = input.count - 1
        for i in 0..<outCount {
            let pos = Double(i) * ratio
            let idx = min(lastIdx, max(0, Int(pos)))
            let next = min(lastIdx, idx + 1)
            let frac = Float(pos - Double(idx))
            out[i] = input[idx] * (1.0 - frac) + input[next] * frac
        }
        return out
    }
}
