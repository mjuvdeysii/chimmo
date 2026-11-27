import AVFAudio
import Foundation

/// Strict half-duplex audio session router:
/// - Playback: sole `.playback` with `.longFormAudio` policy (preserves high-fidelity A2DP & Now Playing controls, never forces mixing).
/// - Recording: `.playAndRecord` with `.measurement`, selecting built-in microphone prior to session activation.
public final class HalfDuplexAudioRouter: @unchecked Sendable {
    public enum Mode: Sendable, Equatable {
        case idle
        case playback
        case recording
    }

    private let stateLock = NSLock()
    private var _currentMode: Mode = .idle

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

    /// True only for genuine stereo headphones/headsets suitable for binaural separation (excludes mono HFP & speakers).
    public var isHeadphonesConnected: Bool {
        #if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { out in
            switch out.portType {
            case .headphones, .bluetoothA2DP, .bluetoothLE, .usbAudio:
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
        case .idle:
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        case .playback:
            do {
                try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            } catch {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try? session.setPreferredIOBufferDuration(0.010)
            try session.setActive(true)
        case .recording:
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try? session.setPreferredSampleRate(48_000)
            try? session.setPreferredIOBufferDuration(0.010)
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? session.setPreferredInput(builtIn)
            }
            try session.setActive(true)
        }
        #endif
        _currentMode = mode
    }

    public func deactivate() {
        try? configure(mode: .idle)
    }
}
