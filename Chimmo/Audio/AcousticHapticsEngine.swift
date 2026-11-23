import Foundation
import QuartzCore
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// 跨感官声学触觉引擎（Core Haptics）：
/// - 全异步启动与零主线程阻塞：绝不在 `init()` 或主线程同步调用 `CHHapticEngine.start()`，杜绝首屏 XPC 卡顿；
/// - 音高-质地双映射：低音浑厚沉稳、高音清脆明亮，张力音级微颤、回家主音长舒释然，让听障或零乐理用户也能在掌心里「摸懂」旋律与和声。
@MainActor
public final class AcousticHapticsEngine {
    public static let shared = AcousticHapticsEngine()

    private var lastPlaybackPulseTime: Double = 0

    #if os(iOS)
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    private var isEngineRunning: Bool = false
    private var isStarting: Bool = false

    private lazy var softImpact = UIImpactFeedbackGenerator(style: .soft)
    private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private lazy var rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var notifyGenerator = UINotificationFeedbackGenerator()
    #endif

    private init() {
        // 延迟检测与异步启动，确保启动首帧 < 0.1ms
    }

    #if os(iOS)
    private func ensureEngineAsync() {
        if !supportsHaptics && engine == nil {
            supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        }
        guard supportsHaptics, !isEngineRunning, !isStarting else { return }
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
                self.isStarting = false
                self.isEngineRunning = (error == nil)
            }
        }
    }
    #endif

    /// 音高触感：把 0...7 音阶轨道映射为细腻的质地与清脆度，指尖直接摸出高低起伏与张力解决。
    public func playPitchTouch(laneIndex: Int, isHome: Bool, isTension: Bool) {
        playExpressivePitchTouch(laneIndex: laneIndex, velocity: 0.62, isHome: isHome, isTension: isTension)
    }

    /// 带敲击力度的跨感官音高触感：随手指落键轻重平滑缩放脉冲强弱与锋利度。
    public func playExpressivePitchTouch(laneIndex: Int, velocity: Double, isHome: Bool, isTension: Bool) {
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

    /// 音乐播放时的低功耗掌心触觉脉冲（已做 85ms 节流，兼顾听障无障碍节奏共振与电池寿命）
    public func playPlaybackNotePulse(laneIndex: Int, isHome: Bool, isTension: Bool) {
        let now = CACurrentMediaTime()
        guard now - lastPlaybackPulseTime >= 0.085 else { return }
        lastPlaybackPulseTime = now

        #if os(iOS)
        guard supportsHaptics && isEngineRunning else {
            softImpact.impactOccurred(intensity: isHome ? 0.65 : 0.40)
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
        let intensity: Float = isHome ? 0.62 : Float(0.34 + Double(clamped) * 0.03)
        let sharpness: Float = isHome ? 0.20 : Float(0.18 + Double(clamped) * 0.08)
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

    /// 乐句和弦情绪幕布切换时的温柔深呼吸震动
    public func playChordShiftBreath() {
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

    /// 手拨音乐盒转盘经过音珠时的轻巧机械棘轮滴答感。
    public func playScrubTick() {
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

    /// 温润平顺的和谐共振（八度 2:1、纯五度 3:2、大三度 5:4）
    public func playConsonantGlow(intensity: Float = 0.62) {
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

    /// 细碎拍频摩擦微颤（半音 16:15、导音 7 或延留音 4 悬停时）
    public func playTensionFlutter(intensity: Float = 0.55) {
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

    /// 释然归家绽放（7→1↑ 或 4→3 延留落地的那一瞬间）
    public func playResolutionExhale() {
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

    /// 敲击心跳节拍时的温润木鱼敲击感
    public func playBeatTap(isStrong: Bool = false) {
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

    /// 种子折纸绽放时的逐颗轻盈连振
    public func playSeedBloom() {
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

    #if os(iOS)
    private func playPattern(events: [CHHapticEvent], curves: [CHHapticParameterCurve]) {
        guard let engine else {
            isEngineRunning = false
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            isEngineRunning = false
        }
    }
    #endif
}
