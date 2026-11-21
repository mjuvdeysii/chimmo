import AVFAudio
import Foundation

/// 严格半双工音频状态机（Q02 排雷核心）：
/// - 播放态：纯 `.playback`，保住 AirPods 48 kHz A2DP 高保真立体声，绝不触发 HFP 电话音质降级；
/// - 录音态：纯 `.record` + `.measurement`，禁用破坏泛音的 `voiceChat`/`VoiceProcessingIO`，强制机身麦防外放自激与蓝牙降质。
public final class HalfDuplexAudioRouter {
    public enum Mode: Sendable, Equatable {
        case playback
        case recording
    }

    public private(set) var currentMode: Mode = .playback

    public init() {}

    public func configure(mode: Mode) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        switch mode {
        case .playback:
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        case .recording:
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.01)
            try session.setActive(true)
            // 若存在机身内置麦克风，优先选中内置麦，杜绝蓝牙通话麦把音质锁死到 16kHz HFP
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? session.setPreferredInput(builtIn)
            }
        }
        #endif
        currentMode = mode
    }
}
