import Foundation
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// 跨感官声学触觉引擎（Core Haptics）：
/// 把音乐物理规律直接翻译到指尖——和谐音程如静水颂钵般温润平顺，半音/延留张力如细碎拍频震颤，解决瞬间如长舒一口气般绽放。
/// 让完全不懂乐理、甚至存在听觉障碍的用户，也能在掌心里「摸懂」音乐的张力与释然。
@MainActor
public final class AcousticHapticsEngine {
    public static let shared = AcousticHapticsEngine()

    #if os(iOS)
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    #endif

    private init() {
        #if os(iOS)
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepareEngineIfNeeded()
        #endif
    }

    private func prepareEngineIfNeeded() {
        #if os(iOS)
        guard supportsHaptics else { return }
        if engine == nil {
            do {
                let eng = try CHHapticEngine()
                eng.isAutoShutdownEnabled = true
                eng.resetHandler = { [weak self] in
                    Task { @MainActor in
                        try? self?.engine?.start()
                    }
                }
                eng.stoppedHandler = { _ in }
                self.engine = eng
            } catch {
                self.supportsHaptics = false
            }
        }
        try? engine?.start()
        #endif
    }

    /// 温润平顺的和谐共振（八度 2:1、纯五度 3:2、大三度 5:4）
    public func playConsonantGlow(intensity: Float = 0.62) {
        #if os(iOS)
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }
        prepareEngineIfNeeded()
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
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        prepareEngineIfNeeded()
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
        guard supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        prepareEngineIfNeeded()
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
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: isStrong ? .medium : .light).impactOccurred()
            return
        }
        prepareEngineIfNeeded()
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
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        prepareEngineIfNeeded()
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
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 静默兜底，永不打断音频体验
        }
    }
    #endif
}
