import Foundation
import QuartzCore
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// Cross-sensory Core Haptics tactile engine:
/// respects global enable toggle, active-foreground app state, hardware capability caching, and automatic background teardown.
@MainActor
public final class AcousticHapticsEngine {
    public static let shared = AcousticHapticsEngine()

    public var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                stopForBackground()
            }
        }
    }

    private var lastPlaybackPulseTime: Double = 0
    private var lastVibratoPulseTime: Double = 0
    private var lastFrissonTickTime: Double = 0
    private var lastBrainwavePulseTime: Double = 0

    #if os(iOS)
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    private var didCheckCapabilities: Bool = false
    private var isEngineRunning: Bool = false
    private var isStarting: Bool = false
    private var startGeneration: UInt64 = 0

    private lazy var softImpact = UIImpactFeedbackGenerator(style: .soft)
    private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private lazy var rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var notifyGenerator = UINotificationFeedbackGenerator()
    #endif

    private init() {}

    public func stopForBackground() {
        #if os(iOS)
        startGeneration &+= 1
        isStarting = false
        isEngineRunning = false
        engine?.stop(completionHandler: { _ in })
        #endif
    }

    private func canFireHaptics() -> Bool {
        guard isEnabled else { return false }
        #if os(iOS)
        return UIApplication.shared.applicationState == .active
        #else
        return false
        #endif
    }

    #if os(iOS)
    private func ensureEngineAsync() {
        guard canFireHaptics() else { return }
        if !didCheckCapabilities {
            supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
            didCheckCapabilities = true
        }
        guard supportsHaptics, !isEngineRunning, !isStarting else { return }
        startGeneration &+= 1
        let gen = startGeneration
        isStarting = true

        if engine == nil {
            do {
                let eng = try CHHapticEngine()
                eng.isAutoShutdownEnabled = true
                eng.playsHapticsOnly = true
                eng.resetHandler = { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.isEngineRunning = false
                        self?.isStarting = false
                    }
                }
                eng.stoppedHandler = { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.isEngineRunning = false
                        self?.isStarting = false
                    }
                }
                self.engine = eng
            } catch {
                supportsHaptics = false
                isStarting = false
                return
            }
        }

        engine?.start { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.startGeneration == gen && self.canFireHaptics() else {
                    self.isStarting = false
                    self.isEngineRunning = false
                    if let eng = self.engine {
                        try? await eng.stop()
                    }
                    return
                }
                self.isStarting = false
                self.isEngineRunning = (error == nil)
            }
        }
    }
    #endif

    public func playPitchTouch(laneIndex: Int, isHome: Bool, isTension: Bool) {
        playExpressivePitchTouch(laneIndex: laneIndex, velocity: 0.62, isHome: isHome, isTension: isTension)
    }

    public func playExpressivePitchTouch(laneIndex: Int, velocity: Double, isHome: Bool, isTension: Bool) {
        guard canFireHaptics() else { return }
        let v = Float(max(0.30, min(1.0, velocity)))
        #if os(iOS)
        if isTension {
            playTensionFlutter(intensity: max(0.32, min(0.88, 0.72 * v)))
            return
        }
        guard supportsHaptics && isEngineRunning else {
            let impactStrength = CGFloat(max(0.35, min(1.0, v)))
            if isHome {
                mediumImpact.impactOccurred(intensity: impactStrength)
            } else {
                softImpact.impactOccurred(intensity: impactStrength)
            }
            ensureEngineAsync()
            return
        }
        let clamped = max(0, min(7, laneIndex))
        let baseSharpness = Float(0.16 + Double(clamped) * 0.08)
        let sharpness = max(0.10, min(0.92, baseSharpness + (v - 0.5) * 0.16))
        let intensity = max(0.24, min(1.0, (isHome ? 0.86 : 0.70) * v))
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playPlaybackNotePulse(laneIndex: Int, isHome: Bool, isTension: Bool, isDownbeat: Bool = false) {
        guard canFireHaptics() else { return }
        let now = CACurrentMediaTime()
        guard now - lastPlaybackPulseTime >= 0.085 else { return }
        lastPlaybackPulseTime = now

        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            softImpact.impactOccurred(intensity: isDownbeat ? 0.78 : (isHome ? 0.65 : 0.40))
            ensureEngineAsync()
            return
        }
        if isTension {
            let e0 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.38),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.64)
                ],
                relativeTime: 0.0
            )
            let e1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.28),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.64)
                ],
                relativeTime: 0.055
            )
            playPattern(events: [e0, e1], curves: [])
            return
        }

        let clamped = max(0, min(7, laneIndex))
        let intensity: Float = isDownbeat
            ? (isHome ? 0.76 : 0.62)
            : (isHome ? 0.62 : Float(0.34 + Double(clamped) * 0.03))
        let sharpness: Float = isDownbeat ? 0.15 : (isHome ? 0.20 : Float(0.18 + Double(clamped) * 0.08))
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playChordShiftBreath() {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            ensureEngineAsync()
            return
        }
        let pIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.36)
        let pSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
        let ev = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [pIntensity, pSharpness],
            relativeTime: 0.0,
            duration: 0.18
        )
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.25),
                .init(relativeTime: 0.05, value: 1.0),
                .init(relativeTime: 0.18, value: 0.0)
            ],
            relativeTime: 0.0
        )
        playPattern(events: [ev], curves: [curve])
        #endif
    }

    public func playScrubTick() {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            lightImpact.impactOccurred(intensity: 0.65)
            ensureEngineAsync()
            return
        }
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.48),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.62)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playConsonantGlow(intensity: Float = 0.62) {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            softImpact.impactOccurred()
            ensureEngineAsync()
            return
        }
        let pIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.2, min(1.0, intensity)))
        let pSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.16)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [pIntensity, pSharpness], relativeTime: 0, duration: 0.24)
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.4),
                .init(relativeTime: 0.07, value: 1.0),
                .init(relativeTime: 0.24, value: 0.0)
            ],
            relativeTime: 0
        )
        playPattern(events: [event], curves: [curve])
        #endif
    }

    public func playTensionFlutter(intensity: Float = 0.55) {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            rigidImpact.impactOccurred()
            ensureEngineAsync()
            return
        }
        var events: [CHHapticEvent] = []
        for i in 0..<5 {
            let t = Double(i) * 0.055
            let ev = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * (1.0 - Float(i) * 0.12)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.72)
                ],
                relativeTime: t
            )
            events.append(ev)
        }
        playPattern(events: events, curves: [])
        #endif
    }

    public func playResolutionExhale() {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            notifyGenerator.notificationOccurred(.success)
            ensureEngineAsync()
            return
        }
        let hit = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.80),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.24)
            ],
            relativeTime: 0
        )
        let bloom = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.50),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
            ],
            relativeTime: 0.03,
            duration: 0.34
        )
        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.03, value: 1.0),
                .init(relativeTime: 0.37, value: 0.0)
            ],
            relativeTime: 0
        )
        playPattern(events: [hit, bloom], curves: [fade])
        #endif
    }

    public func playBeatTap(isStrong: Bool = false) {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            if isStrong {
                mediumImpact.impactOccurred()
            } else {
                lightImpact.impactOccurred()
            }
            ensureEngineAsync()
            return
        }
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: isStrong ? 0.85 : 0.56),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: isStrong ? 0.45 : 0.35)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playVibratoShimmerTick(intensity: Double = 0.55) {
        guard canFireHaptics() else { return }
        let now = CACurrentMediaTime()
        guard now - lastVibratoPulseTime >= 0.11 else { return }
        lastVibratoPulseTime = now

        #if os(iOS)
        let amp = Float(max(0.25, min(0.75, intensity)))
        guard supportsHaptics && isEngineRunning else {
            softImpact.impactOccurred(intensity: CGFloat(amp * 0.7))
            ensureEngineAsync()
            return
        }
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: amp * 0.65),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.42)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playSeedBloom() {
        guard canFireHaptics() else { return }
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            mediumImpact.impactOccurred()
            ensureEngineAsync()
            return
        }
        let events: [CHHapticEvent] = [0.0, 0.09, 0.19].enumerated().map { idx, t in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.42 + Float(idx) * 0.16),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25 + Float(idx) * 0.12)
                ],
                relativeTime: t
            )
        }
        playPattern(events: events, curves: [])
        #endif
    }

    public func playBrainwaveDetent(bandIndex: Int) {
        guard canFireHaptics() else { return }
        let clamped = max(0, min(3, bandIndex))
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            mediumImpact.impactOccurred(intensity: 0.72)
            ensureEngineAsync()
            return
        }
        let sharpness = Float(0.20 + Double(clamped) * 0.18)
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.66),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playFrissonBuildTick(progress: Double) {
        guard canFireHaptics() else { return }
        let now = CACurrentMediaTime()
        guard now - lastFrissonTickTime >= 0.090 else { return }
        lastFrissonTickTime = now

        let p = Float(max(0.0, min(1.0, progress.isFinite ? progress : 0.0)))
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            softImpact.impactOccurred(intensity: CGFloat(0.28 + p * 0.55))
            ensureEngineAsync()
            return
        }
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.24 + p * 0.52),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28 + p * 0.44)
            ],
            relativeTime: 0
        )
        playPattern(events: [ev], curves: [])
        #endif
    }

    public func playFrissonCascade(intensity: Float = 0.85) {
        guard canFireHaptics() else { return }
        let clamped = max(0.35, min(1.0, intensity))
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            notifyGenerator.notificationOccurred(.success)
            ensureEngineAsync()
            return
        }
        let impact = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.34)
            ],
            relativeTime: 0.0
        )
        let ripple = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped * 0.72),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.22)
            ],
            relativeTime: 0.11
        )
        let exhale = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped * 0.62),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
            ],
            relativeTime: 0.06,
            duration: 0.42
        )
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.06, value: 1.0),
                .init(relativeTime: 0.48, value: 0.0)
            ],
            relativeTime: 0.0
        )
        playPattern(events: [impact, ripple, exhale], curves: [curve])
        #endif
    }

    public func playBrainwavePulse(intensity: Float = 0.32) {
        guard canFireHaptics() else { return }
        let now = CACurrentMediaTime()
        guard now - lastBrainwavePulseTime >= 0.45 else { return }
        lastBrainwavePulseTime = now

        let amp = max(0.14, min(0.65, intensity))
        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            softImpact.impactOccurred(intensity: CGFloat(amp))
            ensureEngineAsync()
            return
        }
        let ev = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: amp),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.10)
            ],
            relativeTime: 0.0,
            duration: 0.16
        )
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.2),
                .init(relativeTime: 0.06, value: 1.0),
                .init(relativeTime: 0.16, value: 0.0)
            ],
            relativeTime: 0.0
        )
        playPattern(events: [ev], curves: [curve])
        #endif
    }

    #if os(iOS)
    private func playPattern(events: [CHHapticEvent], curves: [CHHapticParameterCurve]) {
        guard let engine else {
            isEngineRunning = false
            ensureEngineAsync()
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            isEngineRunning = false
            engine.stop(completionHandler: { _ in })
            ensureEngineAsync()
        }
    }
    #endif
}
