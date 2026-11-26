import AVFAudio
import Foundation
import os

/// 端到端离线哼唱捕捉管线：
/// 半双工机身麦采集 → 16 kHz 降采样 → YIN-vDSP → SwiftF0 DP 音符切分 → 调式引力音符与相对高低轮廓。
@MainActor
public final class HumCapturePipeline: ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var inputLevel: Double = 0.0
    @Published public private(set) var livePitchTrace: [Double] = []
    @Published public private(set) var statusMessage: String = ""

    private let router: HalfDuplexAudioRouter
    private let synth: FeltPianoSynth
    private let detector: any PitchDetector

    private var recordEngine: AVAudioEngine?
    private let sampleLock = OSAllocatedUnfairLock(initialState: [Float]())
    private var capturedSampleRate: Double = 48_000.0
    private var startTimestamp: Date?
    private var lastLevelTick: Date = .distantPast
    private var liveTraceTask: Task<Void, Never>?
    private var captureGeneration: UInt64 = 0

    public init(
        router: HalfDuplexAudioRouter,
        synth: FeltPianoSynth,
        detector: any PitchDetector = YINvDSPPitchDetector()
    ) {
        self.router = router
        self.synth = synth
        self.detector = detector
    }

    public func startRecording() {
        guard !isRecording else { return }
        synth.stopForRecordingAsync { [weak self] in
            Task { @MainActor [weak self] in
                self?.requestPermissionAndBegin()
            }
        }
    }

    private func requestPermissionAndBegin() {
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            beginEngineCaptureAsync()
        case .denied:
            statusMessage = "未开启麦克风权限，可直接点下方琴键或手绘曲线"
        case .undetermined:
            Task { @MainActor [weak self] in
                let granted = await AVAudioApplication.requestRecordPermission()
                guard let self else { return }
                if granted {
                    self.beginEngineCaptureAsync()
                } else {
                    self.statusMessage = "未开启麦克风权限，可直接点下方琴键或手绘曲线"
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
        bufferLock.withLock { $0.removeAll(keepingCapacity: true) }
        statusMessage = ""

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try routerRef.configure(mode: .recording)
                let engine = AVAudioEngine()
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                let sr = max(8_000.0, format.sampleRate)

                try input.installAudioTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    guard case let .float(span) = buffer.channelData(0) else { return }
                    let count = min(buffer.frameLength, span.count)
                    guard count > 0 else { return }

                    var sumSq: Float = 0.0
                    var frozenChunk = [Float]()
                    frozenChunk.reserveCapacity(count)
                    for idx in 0..<count {
                        let s = span[idx]
                        sumSq += s * s
                        frozenChunk.append(s)
                    }
                    let chunk = frozenChunk
                    bufferLock.withLock { buf in
                        if buf.count < 48_000 * 30 {
                            buf.append(contentsOf: chunk)
                        }
                    }
                    let rms = sqrt(Double(sumSq) / Double(count))
                    let normalized = min(1.0, rms * 6.5)
                    Task { @MainActor [weak self] in
                        guard let self, self.captureGeneration == generation else { return }
                        let now = Date()
                        if now.timeIntervalSince(self.lastLevelTick) >= 0.05 {
                            self.lastLevelTick = now
                            self.inputLevel = normalized
                        }
                    }
                }

                engine.prepare()
                try engine.start()

                await MainActor.run { [weak self] in
                    guard let self, self.captureGeneration == generation else {
                        engine.inputNode.removeTap(onBus: 0)
                        engine.stop()
                        return
                    }
                    self.recordEngine = engine
                    self.capturedSampleRate = sr
                    self.startTimestamp = Date()
                    self.isRecording = true
                    self.statusMessage = ""
                    self.startLivePitchTracker()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.captureGeneration == generation else { return }
                    self.liveTraceTask?.cancel()
                    self.liveTraceTask = nil
                    self.livePitchTrace = []
                    self.statusMessage = "麦克风暂时不可用，可直接手绘曲线或点下方琴键"
                    self.isRecording = false
                    self.synth.ensureRunning()
                }
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
        isRecording = false
        inputLevel = 0.0
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []

        recordEngine?.inputNode.removeTap(onBus: 0)
        recordEngine?.stop()
        recordEngine = nil

        sampleLock.withLock { $0.removeAll(keepingCapacity: false) }
        statusMessage = ""
        synth.ensureRunning()
    }

    public func stopAndTranscribe(preferredMode: ScaleMode?) async -> ScaleGravityEngine.SnappedResult? {
        guard isRecording else { return nil }
        isRecording = false
        inputLevel = 0.0
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []

        recordEngine?.inputNode.removeTap(onBus: 0)
        recordEngine?.stop()
        recordEngine = nil

        let elapsed = Date().timeIntervalSince(startTimestamp ?? Date())
        let rawSamples = sampleLock.withLock { buf -> [Float] in
            let copy = buf
            buf.removeAll(keepingCapacity: false)
            return copy
        }
        let sourceRate = capturedSampleRate

        synth.ensureRunning()

        guard elapsed >= 0.4, rawSamples.count > Int(sourceRate * 0.35) else {
            statusMessage = "再哼长一点试试"
            return nil
        }

        statusMessage = ""
        let det = detector

        let result: ScaleGravityEngine.SnappedResult = await Task.detached(priority: .userInitiated) {
            let mono16k = HumCapturePipeline.resampleLinear(rawSamples, from: sourceRate, to: PitchContour.sampleRate)
            let contour = det.detect(mono16kSamples: mono16k, fmin: 75.0, fmax: 1100.0)
            let segmented = SwiftF0NoteSegmenter.segmentNotes(from: contour, pitchHoldMs: 85.0)
            return ScaleGravityEngine.snapToGravityScale(rawNotes: segmented, preferredMode: preferredMode)
        }.value

        if result.notes.isEmpty {
            statusMessage = "没听清声音，靠近些轻轻哼一段再试"
            return nil
        }
        statusMessage = ""
        return result
    }

    /// 「只听高低走势、不管跑调」的相对轮廓提取器（含自适应噪底门限与三点中值滤波）
    public func stopAndExtractRelativeContour(slotCount: Int) async -> [Double]? {
        guard isRecording else { return nil }
        isRecording = false
        inputLevel = 0.0
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []

        recordEngine?.inputNode.removeTap(onBus: 0)
        recordEngine?.stop()
        recordEngine = nil

        let elapsed = Date().timeIntervalSince(startTimestamp ?? Date())
        let rawSamples = sampleLock.withLock { buf -> [Float] in
            let copy = buf
            buf.removeAll(keepingCapacity: false)
            return copy
        }
        let sourceRate = capturedSampleRate
        synth.ensureRunning()

        guard slotCount > 0, elapsed >= 0.4, rawSamples.count > Int(sourceRate * 0.35) else {
            statusMessage = "再哼长一点试试"
            return nil
        }

        statusMessage = ""
        let det = detector

        let heights: [Double] = await Task.detached(priority: .userInitiated) {
            let mono16k = HumCapturePipeline.resampleLinear(rawSamples, from: sourceRate, to: PitchContour.sampleRate)
            let contour = det.detect(mono16kSamples: mono16k, fmin: 75.0, fmax: 1100.0)
            let rmsFrames = LivePitchContourFilter.frameRMS(
                mono16kSamples: mono16k,
                frameCount: contour.pitchHz.count,
                hopSize: PitchContour.hopSize
            )
            let voicedSemis = LivePitchContourFilter.extractVoicedSemitones(
                pitchHz: contour.pitchHz,
                confidence: contour.confidence,
                frameRMS: rmsFrames
            )
            guard voicedSemis.count >= max(2, slotCount) else { return [] }

            var slotMedians: [Double] = []
            for s in 0..<slotCount {
                let start = (s * voicedSemis.count) / slotCount
                let end = max(start + 1, ((s + 1) * voicedSemis.count) / slotCount)
                let slice = voicedSemis[start..<min(end, voicedSemis.count)].sorted()
                let mid = slice[slice.count / 2]
                slotMedians.append(mid)
            }

            guard let lo = slotMedians.min(), let hi = slotMedians.max() else { return [] }
            let span = hi - lo
            if span < 0.8 {
                return Array(repeating: 0.35, count: slotCount)
            }
            return slotMedians.map { ($0 - lo) / span }
        }.value

        if heights.isEmpty {
            statusMessage = "没听清声音，靠近些轻轻哼一段再试"
            return nil
        }
        statusMessage = ""
        return heights
    }

    /// 离线捕捉轻哼自然基频（Hz），用于「迷走神经同频共振」包裹人声根音。
    public func stopAndExtractFundamentalHz() async -> Double? {
        guard isRecording else { return nil }
        isRecording = false
        inputLevel = 0.0
        liveTraceTask?.cancel()
        liveTraceTask = nil
        livePitchTrace = []

        recordEngine?.inputNode.removeTap(onBus: 0)
        recordEngine?.stop()
        recordEngine = nil

        let elapsed = Date().timeIntervalSince(startTimestamp ?? Date())
        let rawSamples = sampleLock.withLock { buf -> [Float] in
            let copy = buf
            buf.removeAll(keepingCapacity: false)
            return copy
        }
        let sourceRate = capturedSampleRate
        synth.ensureRunning()

        guard elapsed >= 0.4, rawSamples.count > Int(sourceRate * 0.35) else {
            statusMessage = "再轻轻多哼一小会儿，我就能锁住你的频率"
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
            statusMessage = "没听清轻哼声，再靠近轻哼试试，或直接选常用人声"
            return nil
        }
    }

    nonisolated public static func resampleLinear(_ input: [Float], from srcRate: Double, to dstRate: Double) -> [Float] {
        guard !input.isEmpty else { return [] }
        if abs(srcRate - dstRate) < 1.0 { return input }
        let ratio = srcRate / dstRate
        let outCount = max(1, Int(Double(input.count) / ratio))
        var out = [Float](repeating: 0, count: outCount)
        let lastIdx = input.count - 1
        for i in 0..<outCount {
            let pos = Double(i) * ratio
            let idx = min(lastIdx, Int(pos))
            let next = min(lastIdx, idx + 1)
            let frac = Float(pos - Double(idx))
            out[i] = input[idx] * (1.0 - frac) + input[next] * frac
        }
        return out
    }
}
