import AVFAudio
import Foundation

/// 严格半双工音频状态机（Q02 排雷核心）：
/// - 播放态：纯 `.playback`，保住 AirPods 48 kHz A2DP 高保真立体声，绝不触发 HFP 电话音质降级；
/// - 录音态：纯 `.record` + `.measurement`，禁用破坏泛音的 `voiceChat`/`VoiceProcessingIO`，强制机身麦防外放自激与蓝牙降质。
public final class HalfDuplexAudioRouter: @unchecked Sendable {
    public enum Mode: Sendable, Equatable {
        case playback
        case recording
    }

    private let stateLock = NSLock()
    private var _currentMode: Mode = .playback

    public var currentMode: Mode {
        stateLock.withLock { _currentMode }
    }

    public var hardwareSampleRate: Double {
        #if os(iOS)
        let sr = AVAudioSession.sharedInstance().sampleRate
        if sr >= 22_050.0 && sr <= 96_000.0 {
            return sr
        }
        #endif
        return 48_000.0
    }

    public var isHeadphonesConnected: Bool {
        #if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { out in
            switch out.portType {
            case .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .usbAudio, .lineOut:
                return true
            default:
                return false
            }
        }
        #else
        return false
        #endif
    }

    public init() {}

    public func configure(mode: Mode) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        switch mode {
        case .playback:
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setPreferredIOBufferDuration(0.010)
            try session.setActive(true)
        case .recording:
            try session.setCategory(.record, mode: .measurement, options: [])
            try? session.setPreferredSampleRate(48_000)
            try? session.setPreferredIOBufferDuration(0.010)
            try session.setActive(true)
            // 若存在机身内置麦克风，优先选中内置麦，杜绝蓝牙通话麦把音质锁死到 16kHz HFP
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? session.setPreferredInput(builtIn)
            }
        }
        #endif
        _currentMode = mode
    }
}
