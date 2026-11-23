import AVFAudio
import Foundation
import os

/// 端到端离线哼唱捕捉管线：
/// 半双工机身麦采集 → 16 kHz 降采样 → YIN-vDSP (或未来 SwiftF0) → SwiftF0 DP 音符切分 → 调式引力陶珠与幽灵备选珠。
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
        synth.stopForRecording()

        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            beginEngineCapture()
        case .denied:
            statusMessage = "未开启麦克风权限，可直接点按下方七只咩哞创作旋律"
        case .undetermined:
            Task { @MainActor [weak self] in
                let granted = await AVAudioApplication.requestRecordPermission()
                guard let self else { return }
                if granted {
                    self.beginEngineCapture()
                } else {
                    self.statusMessage = "未开启麦克风权限，可直接点按下方七只咩哞创作旋律"
                }
            }
        @unknown default:
            beginEngineCapture()
        }
        #else
        beginEngineCapture()
        #endif
    }

    private func beginEngineCapture() {
        do {
            try router.configure(mode: .recording)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            capturedSampleRate = max(8_000.0, format.sampleRate)
            sampleLock.withLock { $0.removeAll(keepingCapacity: true) }

            let bufferLock = sampleLock
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                guard count > 0 else { return }

                var sumSq: Float = 0.0
                let frozenChunk = Array(UnsafeBufferPointer(start: channelData, count: count))
                for s in frozenChunk {
                    sumSq += s * s
                }
                bufferLock.withLock { buf in
                    // 单次哼唱上限 30 秒，防止内存暴涨
                    if buf.count < 48_000 * 30 {
                        buf.append(contentsOf: frozenChunk)
                    }
                }
                let rms = sqrt(Double(sumSq) / Double(count))
                let normalized = min(1.0, rms * 6.5)
                Task { @MainActor [weak self] in
                    self?.inputLevel = normalized
                }
            }

            engine.prepare()
            try engine.start()
            recordEngine = engine
            startTimestamp = Date()
            isRecording = true
            statusMessage = "用轻柔的 da / la 哼出脑海里的旋律…"
        } catch {
            statusMessage = "麦克风暂时不可用，可直接点按下方七只咩哞"
            isRecording = false
            synth.ensureRunning()
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

        // 切回高保真 48kHz 播放态
        synth.ensureRunning()

        // 误触防御：< 0.4 秒静默忽略
        guard elapsed >= 0.4, rawSamples.count > Int(sourceRate * 0.35) else {
            statusMessage = "轻触时间太短，按住哼出一小句试试"
            return nil
        }

        statusMessage = "正在把旋律凝结成陶珠…"
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
        statusMessage = "捉到 \(result.notes.count) 颗陶珠，点半透明幽灵珠可一指微修"
        return result
    }

    /// 「只听高低走势、不管跑调」的相对轮廓提取器：
    /// 即使五音不全或完全唱偏调，只要按着敲好的拍数随口哼出大致高低，就能按相对升降自动把拍子塑形成脑海里的山坡！
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

        statusMessage = "正在把你的高低走势贴到敲好的拍子上…"
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
        statusMessage = "已按你的哼唱高低排好木琴台阶，试听看看像不像！"
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
