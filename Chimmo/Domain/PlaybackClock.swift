import Foundation
import QuartzCore

/// 零视图重绘的高精度播放时钟（非 ObservableObject）：
/// 画布在局部 `TimelineView` 中直接读取当前播放时间与连续旋转圈数，彻底消除 60Hz SwiftUI 状态广播风暴。
@MainActor
public final class PlaybackClock {
    public private(set) var isPlaying: Bool = false
    public private(set) var totalDuration: Double = 4.0
    public private(set) var anchorMediaTime: Double = 0
    public private(set) var anchorSongTime: Double = 0
    public var scrubTime: Double? = nil
    public var pauseTailSeconds: Double = 0.35

    private var completedLoopsBaseTurns: Double = 0

    public init() {}

    public func start(totalDuration: Double, from offset: Double = 0, at mediaTime: Double = CACurrentMediaTime()) {
        let safeDur = max(0.5, totalDuration)
        self.totalDuration = safeDur
        let clampedOffset = max(0, min(safeDur, offset))
        self.anchorSongTime = clampedOffset
        self.anchorMediaTime = mediaTime
        self.scrubTime = nil
        self.isPlaying = true
        self.completedLoopsBaseTurns = clampedOffset / safeDur
    }

    public func pause(preservingTime: Bool = false, at mediaTime: Double = CACurrentMediaTime()) {
        if preservingTime, let cur = currentTime(at: mediaTime) {
            scrubTime = cur
        } else if !preservingTime {
            scrubTime = nil
        }
        isPlaying = false
    }

    public func stop() {
        isPlaying = false
        scrubTime = nil
        anchorSongTime = 0
        completedLoopsBaseTurns = 0
    }

    public func setScrubTime(_ time: Double?) {
        if let t = time {
            scrubTime = max(0, min(totalDuration, t))
        } else {
            scrubTime = nil
        }
    }

    public func updateTotalDuration(_ dur: Double) {
        totalDuration = max(0.5, dur)
        if let s = scrubTime {
            scrubTime = min(s, totalDuration)
        }
    }

    public func currentTime(at mediaTime: Double = CACurrentMediaTime()) -> Double? {
        if let scrub = scrubTime {
            return max(0, min(totalDuration, scrub))
        }
        guard isPlaying else { return nil }
        let safeDur = max(0.5, totalDuration)
        let cycle = safeDur + max(0.0, pauseTailSeconds)
        let elapsed = max(0, mediaTime - anchorMediaTime) + anchorSongTime
        let inCycle = elapsed.truncatingRemainder(dividingBy: cycle)
        return min(safeDur, inCycle)
    }

    /// 连续无跳变旋转圈数（在乐曲循环呼吸间歇保持优雅平滑推进，绝不突然倒回）。
    public func continuousRotationTurns(at mediaTime: Double = CACurrentMediaTime()) -> Double {
        let safeDur = max(0.5, totalDuration)
        if let scrub = scrubTime {
            return scrub / safeDur
        }
        guard isPlaying else { return 0 }
        let cycle = safeDur + max(0.0, pauseTailSeconds)
        let elapsed = max(0, mediaTime - anchorMediaTime) + anchorSongTime
        let completedCycles = floor(elapsed / cycle)
        let inCycle = elapsed - completedCycles * cycle
        let inSongTurns = min(1.0, inCycle / safeDur)
        return completedCycles + inSongTurns
    }
}
