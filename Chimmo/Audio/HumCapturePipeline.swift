import AVFAudio
import Foundation
import os

/// 端到端离线哼唱捕捉管线：
/// 半双工机身麦采集 → 16 kHz 降采样 → YIN-vDSP → SwiftF0 DP 音符切分 → 调式引力陶珠与相对高低轮廓。
@MainActor
public final class HumCapturePipeline: ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var inputLevel: Double = 0.0
    @Published public private(set) var statusMessage: String = ""

    private let router: HalfDuplexAudioRouter
    private let synth: FeltPianoSynth
    private let detector: any PitchDetector

    private var recordEngine: AVAudioEngine?
    private let sampleLock = OSAllocatedUnfairLock(initialState: [Float]())
    private var capturedSampleRate: Double = 48_000.0
    private var startTimestamp: Date?
    private var lastLevelTick: Date = .distantPast

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
            statusMessage = "未开启麦克风权限，可直接点按下方彩虹琴条或画山坡创作"
        case .undetermined:
            Task { @MainActor [weak self] in
                let granted = await AVAudioApplication.requestRecordPermission()
                guard let self else { return }
                if granted {
                    self.beginEngineCaptureAsync()
                } else {
                    self.statusMessage = "未开启麦克风权限，可直接点按下方彩虹琴条或画山坡创作"
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
        let routerRef = router
        let bufferLock = sampleLock
        bufferLock.withLock { $0.removeAll(keepingCapacity: true) }
        statusMessage = "正在唤醒麦克风…"

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
                        guard let self else { return }
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
                    guard let self else {
                        engine.inputNode.removeTap(onBus: 0)
                        engine.stop()
                        return
                    }
                    self.recordEngine = engine
                    self.capturedSampleRate = sr
                    self.startTimestamp = Date()
                    self.isRecording = true
                    self.statusMessage = "用轻柔的 da / la 哼出大概高低起伏就行…"
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.statusMessage = "麦克风暂时不可用，可直接画山坡或点彩虹琴条"
                    self.isRecording = false
                    self.synth.ensureRunning()
                }
            }
        }
    }

    public func stopAndTranscribe(preferredMode: ScaleMode?) async -> ScaleGravityEngine.SnappedResult? {
        guard isRecording else { return nil }
        isRecording = false
        inputLevel = 0.0

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
            statusMessage = "轻哼时间太短，再哼一小句试试"
            return nil
        }

        statusMessage = "正在把旋律凝结成音珠…"
        let det = detector

        let result: ScaleGravityEngine.SnappedResult = await Task.detached(priority: .userInitiated) {
            let mono16k = HumCapturePipeline.resampleLinear(rawSamples, from: sourceRate, to: PitchContour.sampleRate)
            let contour = det.detect(mono16kSamples: mono16k, fmin: 75.0, fmax: 1100.0)
            let segmented = SwiftF0NoteSegmenter.segmentNotes(from: contour, pitchHoldMs: 85.0)
            return ScaleGravityEngine.snapToGravityScale(rawNotes: segmented, preferredMode: preferredMode)
        }.value

        if result.notes.isEmpty {
            statusMessage = "没有听清音高，靠近手机轻轻哼 da / la 再试一次"
            return nil
        }
        statusMessage = "捉到 \(result.notes.count) 颗音珠！"
        return result
    }

    /// 「只听高低走势、不管跑调」的相对轮廓提取器
    public func stopAndExtractRelativeContour(slotCount: Int) async -> [Double]? {
        guard isRecording else { return nil }
        isRecording = false
        inputLevel = 0.0

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
            statusMessage = "哼的时间太短啦，按脑海里的高低多哼两秒试试"
            return nil
        }

        statusMessage = "正在把你的高低走势贴到拍子上…"
        let det = detector

        let heights: [Double] = await Task.detached(priority: .userInitiated) {
            let mono16k = HumCapturePipeline.resampleLinear(rawSamples, from: sourceRate, to: PitchContour.sampleRate)
            let contour = det.detect(mono16kSamples: mono16k, fmin: 75.0, fmax: 1100.0)
            var voicedSemis: [Double] = []
            for i in 0..<contour.pitchHz.count {
                let hz = contour.pitchHz[i]
                let conf = i < contour.confidence.count ? contour.confidence[i] : 1.0
                if hz > 65.0 && conf >= 0.32 {
                    voicedSemis.append(12.0 * log2(hz / 110.0))
                }
            }
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
            statusMessage = "没听清声音，靠近手机轻轻哼出高低起伏再试一次"
            return nil
        }
        statusMessage = "已按你的哼唱高低排好音轨！"
        return heights
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
