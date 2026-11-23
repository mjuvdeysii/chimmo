import Foundation
import SwiftUI

/// 主画布显示模式：
/// - `orbitalDisc`: 旋转音乐盒星盘（盘面随旋律顺滑旋转，每个发声的音符正好转到 12 点钟黄铜唱针下方绽放涟漪）
/// - `flowingRiver`: 流动山河画卷（金色光束锚定在 28% 处，整片旋律山河随歌声平滑向左流淌，永远停在视线中心）
/// - `resonanceNebula`: 星云万花筒（8 颗星辰环绕中央利萨如谐振星核，流星顺着旋律轨迹飞舞，点按或滑过即兴共鸣）
public enum StageVisualMode: String, CaseIterable, Identifiable, Sendable {
    case orbitalDisc = "转盘"
    case flowingRiver = "曲线"
    case resonanceNebula = "星环"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .orbitalDisc: return "record.circle"
        case .flowingRiver: return "water.waves"
        case .resonanceNebula: return "sparkles"
        }
    }
}

/// 色彩 + 位置 + 几何形状三重无障碍音高编码（色盲友好 & 零乐理直觉识别）：
/// 1(圆点) 2(圆方) 3(三角) 4(棱镜) 5(五星) 6(水滴) 7(星芒) 1↑(双环)
public enum PitchGlyphShape: String, CaseIterable, Sendable {
    case circle
    case roundedSquare
    case triangle
    case diamond
    case star
    case teardrop
    case spark
    case doubleRing

    public static func glyph(forLaneIndex laneIndex: Int) -> PitchGlyphShape {
        switch max(0, min(7, laneIndex)) {
        case 0: return .circle
        case 1: return .roundedSquare
        case 2: return .triangle
        case 3: return .diamond
        case 4: return .star
        case 5: return .teardrop
        case 6: return .spark
        default: return .doubleRing
        }
    }

    public var symbolName: String {
        switch self {
        case .circle: return "圆点"
        case .roundedSquare: return "圆方"
        case .triangle: return "三角"
        case .diamond: return "棱镜"
        case .star: return "五星"
        case .teardrop: return "水滴"
        case .spark: return "星芒"
        case .doubleRing: return "双环"
        }
    }

    /// 绘制于指定矩形区域内的矢量几何路径（在灰度/色盲模式下依然 100% 清晰分辨 8 个音高）。
    public func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) * 0.44
        var p = Path()

        switch self {
        case .circle:
            p.addEllipse(in: CGRect(x: cx - r * 0.85, y: cy - r * 0.85, width: r * 1.7, height: r * 1.7))

        case .roundedSquare:
            let s = r * 1.56
            p.addRoundedRect(
                in: CGRect(x: cx - s * 0.5, y: cy - s * 0.5, width: s, height: s),
                cornerSize: CGSize(width: s * 0.28, height: s * 0.28)
            )

        case .triangle:
            p.move(to: CGPoint(x: cx, y: cy - r * 0.92))
            p.addLine(to: CGPoint(x: cx + r * 0.88, y: cy + r * 0.72))
            p.addLine(to: CGPoint(x: cx - r * 0.88, y: cy + r * 0.72))
            p.closeSubpath()

        case .diamond:
            p.move(to: CGPoint(x: cx, y: cy - r))
            p.addLine(to: CGPoint(x: cx + r * 0.82, y: cy))
            p.addLine(to: CGPoint(x: cx, y: cy + r))
            p.addLine(to: CGPoint(x: cx - r * 0.82, y: cy))
            p.closeSubpath()

        case .star:
            let outer = r
            let inner = r * 0.46
            for i in 0..<10 {
                let angle = -Double.pi / 2.0 + Double(i) * Double.pi / 5.0
                let rad = (i % 2 == 0) ? outer : inner
                let pt = CGPoint(x: cx + CGFloat(cos(angle)) * rad, y: cy + CGFloat(sin(angle)) * rad)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()

        case .teardrop:
            p.move(to: CGPoint(x: cx, y: cy - r))
            p.addCurve(
                to: CGPoint(x: cx, y: cy + r * 0.88),
                control1: CGPoint(x: cx + r * 0.98, y: cy - r * 0.05),
                control2: CGPoint(x: cx + r * 0.88, y: cy + r * 0.88)
            )
            p.addCurve(
                to: CGPoint(x: cx, y: cy - r),
                control1: CGPoint(x: cx - r * 0.88, y: cy + r * 0.88),
                control2: CGPoint(x: cx - r * 0.98, y: cy - r * 0.05)
            )
            p.closeSubpath()

        case .spark:
            let outer = r * 1.05
            let inner = r * 0.34
            for i in 0..<8 {
                let angle = -Double.pi / 2.0 + Double(i) * Double.pi / 4.0
                let rad = (i % 2 == 0) ? outer : inner
                let pt = CGPoint(x: cx + CGFloat(cos(angle)) * rad, y: cy + CGFloat(sin(angle)) * rad)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()

        case .doubleRing:
            let outerR = r * 0.96
            let innerR = r * 0.44
            p.addEllipse(in: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
            p.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
        }

        return p
    }
}

/// 旋转音乐盒星盘（Orbital Turntable）纯几何与极坐标逆映射引擎（100% 纯函数、可单测）
public enum OrbitalGeometry {

    /// 将音符起始时间映射到盘面基准角度（弧度，顺时针从 12 点钟算起）。
    public static func noteBaseAngle(onset: Double, totalDuration: Double) -> Double {
        let safeTotal = max(0.5, totalDuration)
        let norm = max(0.0, onset).truncatingRemainder(dividingBy: safeTotal) / safeTotal
        return norm * 2.0 * Double.pi
    }

    /// 计算当前播放头对应的整个星盘旋转角（弧度）：
    /// 播放时盘面逆时针平稳旋转，使得正在发声的音符正好转到正上方 12 点钟唱针处！
    public static func discRotationRadians(playheadTime: Double?, totalDuration: Double) -> Double {
        guard let t = playheadTime else { return 0.0 }
        let safeTotal = max(0.5, totalDuration)
        return -(max(0.0, t) / safeTotal) * 2.0 * Double.pi
    }

    /// 计算单颗音珠在屏幕上的实际弧度角（-π/2 = 正上方 12 点钟唱针位置）。
    public static func screenAngle(onset: Double, playheadTime: Double?, totalDuration: Double) -> Double {
        return -Double.pi / 2.0
            + noteBaseAngle(onset: onset, totalDuration: totalDuration)
            + discRotationRadians(playheadTime: playheadTime, totalDuration: totalDuration)
    }

    /// 计算 0...7 音阶轨道对应的同心圆半径（0 = 内圈低音 1，7 = 外圈高音 1↑）。
    public static func orbitRadius(laneIndex: Int, innerRadius: CGFloat, outerRadius: CGFloat) -> CGFloat {
        let clamped = CGFloat(max(0, min(7, laneIndex)))
        let t = clamped / 7.0
        return innerRadius + t * max(1, outerRadius - innerRadius)
    }

    /// 极坐标反向命中：根据点按/拖动的半径吸附到允许的音阶轨道（0...7）。
    public static func laneIndex(
        forRadius r: CGFloat,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        pentatonicSafe: Bool
    ) -> Int {
        let span = max(1, outerRadius - innerRadius)
        let norm = max(0.0, min(1.0, (r - innerRadius) / span))
        let raw = Int((norm * 7.0).rounded())
        return XylophoneLane.nearestAllowedIndex(raw, pentatonicSafe: pentatonicSafe)
    }

    /// 极坐标反向命中：根据屏幕触摸点与当前盘面旋转角，反推出对应的乐曲时间点（秒）。
    public static func onset(
        forScreenPoint pt: CGPoint,
        center: CGPoint,
        discRotation: Double,
        totalDuration: Double
    ) -> Double {
        let dx = Double(pt.x - center.x)
        let dy = Double(pt.y - center.y)
        let screenAng = atan2(dy, dx)
        var baseAng = (screenAng + Double.pi / 2.0 - discRotation)
            .truncatingRemainder(dividingBy: 2.0 * Double.pi)
        if baseAng < 0 { baseAng += 2.0 * Double.pi }
        let safeTotal = max(0.5, totalDuration)
        return (baseAng / (2.0 * Double.pi)) * safeTotal
    }
}

/// 流动山河画卷（Flowing Mountain-River Ribbon）固定光束卷轴几何引擎
public enum FlowingRiverGeometry {

    /// 返回当前时间线横向滚动偏移：播放时严格锁死当前发声位置在屏幕固定金光束（anchorX）处，绝不跑出屏幕。
    public static func worldScrollX(playheadTime: Double?, manualScrollX: CGFloat, pxPerSecond: CGFloat) -> CGFloat {
        if let t = playheadTime {
            return max(0, CGFloat(t) * pxPerSecond)
        }
        return max(0, manualScrollX)
    }

    public static func screenX(onset: Double, scrollX: CGFloat, anchorX: CGFloat, pxPerSecond: CGFloat) -> CGFloat {
        anchorX + CGFloat(onset) * pxPerSecond - scrollX
    }

    public static func onset(fromScreenX x: CGFloat, scrollX: CGFloat, anchorX: CGFloat, pxPerSecond: CGFloat) -> Double {
        let px = Double((x - anchorX + scrollX) / max(1, pxPerSecond))
        return max(0.08, px)
    }
}

/// 单指画山坡采样器：把零基础用户随手画的一笔高低起伏曲线，平滑重采样为指定拍数的归一化高度（0...1）。
public enum ContourSketchSampler {

    public static func sampleContour(points: [CGPoint], in size: CGSize, slotCount: Int) -> [Double] {
        guard slotCount > 0 else { return [] }
        guard !points.isEmpty, size.height > 1 else {
            return Array(repeating: 0.4, count: slotCount)
        }
        if points.count == 1 {
            let h = 1.0 - Double(max(0, min(1, points[0].y / size.height)))
            return Array(repeating: h, count: slotCount)
        }

        let sorted = points.sorted { $0.x < $1.x }
        let minX = sorted.first!.x
        let maxX = max(minX + 1.0, sorted.last!.x)

        var out: [Double] = []
        for s in 0..<slotCount {
            let frac = slotCount == 1 ? 0.5 : Double(s) / Double(slotCount - 1)
            let targetX = minX + CGFloat(frac) * (maxX - minX)

            // 线性插值求该横向位置的高度 y
            var yVal = sorted.last!.y
            if targetX <= sorted.first!.x {
                yVal = sorted.first!.y
            } else {
                for i in 0..<(sorted.count - 1) {
                    let a = sorted[i]
                    let b = sorted[i + 1]
                    if targetX >= a.x && targetX <= b.x {
                        let span = max(0.001, b.x - a.x)
                        let t = (targetX - a.x) / span
                        yVal = a.y + (b.y - a.y) * t
                        break
                    }
                }
            }

            let h = 1.0 - Double(max(0.0, min(1.0, yVal / size.height)))
            out.append(h)
        }
        return out
    }
}

/// 星云万花筒（Resonance Nebula）星座纯几何与流星轨迹插值引擎（100% 纯函数、可单测）
public enum ConstellationGeometry {

    public struct CometSnapshot: Equatable, Sendable {
        public let position: CGPoint
        public let activeLaneIndex: Int
        public let nextLaneIndex: Int
        public let progress: Double
    }

    /// 将 0...7 音阶轨道等角放置在圆周上（0 = 正上方 12 点钟 1·Do，顺时针排列）
    public static func starAngle(laneIndex: Int) -> Double {
        let clamped = max(0, min(7, laneIndex))
        return -Double.pi / 2.0 + Double(clamped) * (2.0 * Double.pi / 8.0)
    }

    public static func starPoint(laneIndex: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let ang = starAngle(laneIndex: laneIndex)
        return CGPoint(
            x: center.x + CGFloat(cos(ang)) * radius,
            y: center.y + CGFloat(sin(ang)) * radius
        )
    }

    /// 命中距离触摸点最近且允许点击的星座音高星辰；未落入 `hitRadius` 返回 `nil`
    public static func hitStarLane(
        at point: CGPoint,
        center: CGPoint,
        radius: CGFloat,
        hitRadius: CGFloat = 34,
        pentatonicSafe: Bool
    ) -> Int? {
        var bestLane: Int? = nil
        var bestDist = hitRadius
        for i in 0..<8 {
            if pentatonicSafe && !XylophoneLane.lane(at: i).isPentatonicSafe {
                continue
            }
            let pt = starPoint(laneIndex: i, center: center, radius: radius)
            let d = hypot(point.x - pt.x, point.y - pt.y)
            if d <= bestDist {
                bestDist = d
                bestLane = i
            }
        }
        return bestLane
    }

    /// 根据当前时间返回沿着星座轨迹在两颗音星间优雅滑翔的流星位置（绕开圆心利萨如核心）
    public static func cometSnapshot(
        notes: [NoteBead],
        grooveStrength: Double,
        currentTime: Double,
        center: CGPoint,
        radius: CGFloat
    ) -> CometSnapshot? {
        let sorted = notes.sorted {
            $0.displayOnset(grooveStrength: grooveStrength) < $1.displayOnset(grooveStrength: grooveStrength)
        }
        guard !sorted.isEmpty else { return nil }

        var curIdx = 0
        for (idx, bead) in sorted.enumerated() {
            if bead.displayOnset(grooveStrength: grooveStrength) <= currentTime + 0.0001 {
                curIdx = idx
            } else {
                break
            }
        }

        let curBead = sorted[curIdx]
        let curOnset = curBead.displayOnset(grooveStrength: grooveStrength)
        let curLane = XylophoneLane.laneIndex(degree: curBead.degree, octaveOffset: curBead.octaveOffset)
        let p0 = starPoint(laneIndex: curLane, center: center, radius: radius)

        if curIdx + 1 < sorted.count && currentTime >= curOnset {
            let nextBead = sorted[curIdx + 1]
            let nextOnset = nextBead.displayOnset(grooveStrength: grooveStrength)
            let nextLane = XylophoneLane.laneIndex(degree: nextBead.degree, octaveOffset: nextBead.octaveOffset)
            let p1 = starPoint(laneIndex: nextLane, center: center, radius: radius)
            let span = max(0.08, nextOnset - curOnset)
            let rawP = max(0.0, min(1.0, (currentTime - curOnset) / span))
            let s = rawP * rawP * (3.0 - 2.0 * rawP)

            let ctrl = CGPoint(
                x: (p0.x + p1.x) * 0.39 + center.x * 0.22,
                y: (p0.y + p1.y) * 0.39 + center.y * 0.22
            )
            let oneMinusS = CGFloat(1.0 - s)
            let cs = CGFloat(s)
            let pos = CGPoint(
                x: oneMinusS * oneMinusS * p0.x + 2.0 * oneMinusS * cs * ctrl.x + cs * cs * p1.x,
                y: oneMinusS * oneMinusS * p0.y + 2.0 * oneMinusS * cs * ctrl.y + cs * cs * p1.y
            )
            return CometSnapshot(position: pos, activeLaneIndex: curLane, nextLaneIndex: nextLane, progress: rawP)
        }

        let progress = currentTime < curOnset ? 0.0 : 1.0
        return CometSnapshot(position: p0, activeLaneIndex: curLane, nextLaneIndex: curLane, progress: progress)
    }
}

/// 闭眼夜灯触觉剧场音高磁吸迟滞映射器（Schmitt 迟滞防抖：在零视觉盯着屏幕滑动时，绝不因手指轻微颤动而在相邻音高之间反复跳音）。
public enum TactileFieldMapper {

    /// 把屏幕纵向触摸点转换为从下到上的归一化高度（0.0 = 最底端低音，1.0 = 最顶端高音）
    public static func rawNormalizedY(
        locationY: CGFloat,
        height: CGFloat,
        paddingRatio: CGFloat = 0.08
    ) -> Double {
        let safeH = max(1.0, height)
        let pad = safeH * max(0.0, min(0.30, paddingRatio))
        let usable = max(1.0, safeH - pad * 2.0)
        let norm = 1.0 - Double((locationY - pad) / usable)
        return max(0.0, min(1.0, norm))
    }

    /// 带迟滞边界的音阶吸附：只有跨过半格再加上 `hysteresis` 死区后才会切换到下一阶梯，给闭眼手指清晰稳重的「机械棘轮感」。
    public static func snappedLaneIndex(
        normalizedY: Double,
        previousLaneIndex: Int?,
        pentatonicSafe: Bool,
        hysteresis: Double = 0.24
    ) -> Int {
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: pentatonicSafe)
        guard allowed.count > 1 else { return allowed.first ?? 0 }

        let clampedY = max(0.0, min(1.0, normalizedY))
        let posFloat = clampedY * Double(allowed.count - 1)
        let safeHysteresis = max(0.0, min(0.45, hysteresis))

        if let prev = previousLaneIndex, let prevPos = allowed.firstIndex(of: prev) {
            if abs(posFloat - Double(prevPos)) < (0.5 + safeHysteresis) {
                return prev
            }
        }

        let targetPos = max(0, min(allowed.count - 1, Int(posFloat.rounded())))
        return allowed[targetPos]
    }

    /// 返回指定音阶轨道在触觉场中的磁吸中心归一化高度 `[0, 1]`
    public static func magneticDetentNormalizedY(laneIndex: Int, pentatonicSafe: Bool) -> Double {
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: pentatonicSafe)
        guard allowed.count > 1 else { return 0.5 }
        let snapped = XylophoneLane.nearestAllowedIndex(laneIndex, pentatonicSafe: pentatonicSafe)
        let pos = allowed.firstIndex(of: snapped) ?? 0
        return Double(pos) / Double(allowed.count - 1)
    }
}
