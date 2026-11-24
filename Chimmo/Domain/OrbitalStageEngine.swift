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

/// 无字交互声光引导几何算法（以光弧牵引、空盘呼吸圈与径向调音标尺取代文字说教）。
public enum PreLinguisticGuideGeometry {

    /// 跟灯弹模式下，从画布上发光音符引向底部对应彩虹琴条的光桥曲线控制点。
    public static func followLightBridgePath(
        from stagePoint: CGPoint,
        toLaneIndex laneIndex: Int,
        canvasSize: CGSize
    ) -> (start: CGPoint, control: CGPoint, end: CGPoint) {
        let clampedLane = max(0, min(7, laneIndex))
        let safeW = max(1.0, canvasSize.width)
        let safeH = max(1.0, canvasSize.height)
        let end = CGPoint(
            x: (CGFloat(clampedLane) + 0.5) / 8.0 * safeW,
            y: safeH - 2.0
        )
        let control = CGPoint(
            x: stagePoint.x * 0.38 + end.x * 0.62,
            y: min(safeH - 4.0, (stagePoint.y + end.y) * 0.54 + 14.0)
        )
        return (stagePoint, control, end)
    }

    /// 空画布轻柔呼吸同心环（按半径升序排列，随相位扩展渐隐）。
    public static func emptyCanvasPulseRadii(
        phase: Double,
        maxRadius: CGFloat
    ) -> [(radius: CGFloat, opacity: Double)] {
        let safeR = max(1.0, maxRadius)
        let rings: [(radius: CGFloat, opacity: Double)] = (0..<3).map { idx in
            let shifted = (phase + Double(idx) / 3.0).truncatingRemainder(dividingBy: 1.0)
            let p = shifted < 0 ? shifted + 1.0 : shifted
            let radius = safeR * CGFloat(0.24 + p * 0.76)
            let opacity = max(0.0, min(1.0, (1.0 - p) * 0.45))
            return (radius, opacity)
        }
        return rings.sorted { $0.radius < $1.radius }
    }

    /// 选中音符后沿半径方向延展的滑轨端点（直观示意上下拖拽改音高）。
    public static func selectionTractionTicks(
        center: CGPoint,
        angle: Double,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> (inner: CGPoint, outer: CGPoint) {
        let cosA = CGFloat(cos(angle))
        let sinA = CGFloat(sin(angle))
        let inner = CGPoint(x: center.x + cosA * innerRadius, y: center.y + sinA * innerRadius)
        let outer = CGPoint(x: center.x + cosA * outerRadius, y: center.y + sinA * outerRadius)
        return (inner, outer)
    }

    /// 音高坐标系视觉结构锚轨：`1` (0/7) 与 `5` (4) 作为主音/属音空间锚点给予略厚线条权重，帮助零乐理与色弱者一瞬辨认音高位置。
    public static func isStructuralAnchorLane(_ laneIndex: Int) -> Bool {
        laneIndex == 0 || laneIndex == 4 || laneIndex == 7
    }
}

/// 彩虹琴键纵向触控表达映射器：顶部清亮强劲、底部轻柔温润，零文字直觉控制力度与涟漪大小。
public enum ExpressiveTouchMapper {
    public struct TouchDynamics: Equatable, Sendable {
        public let velocity: Double
        public let brightness: Double
        public let rippleScale: Double

        public init(velocity: Double, brightness: Double, rippleScale: Double) {
            self.velocity = velocity
            self.brightness = brightness
            self.rippleScale = rippleScale
        }
    }

    public static func dynamics(normalizedY: Double) -> TouchDynamics {
        let clampedY = max(0.0, min(1.0, normalizedY))
        let energy = 1.0 - clampedY
        return TouchDynamics(
            velocity: 0.36 + energy * 0.48,
            brightness: 0.64 + energy * 0.54,
            rippleScale: 0.72 + energy * 0.56
        )
    }
}

/// 星环微揉弦与共鸣延音物理映射器：按住星辰轻微左右晃动触发 ±24 音分乐感揉弦，同时以根音泛音共鸣托底。
public enum HarmonicVibratoMapper {
    public struct VibratoState: Equatable, Sendable {
        public let frequencyHz: Double
        public let sympatheticHz: Double
        public let centsOffset: Double
        public let swellGain: Double

        public init(frequencyHz: Double, sympatheticHz: Double, centsOffset: Double, swellGain: Double) {
            self.frequencyHz = frequencyHz
            self.sympatheticHz = sympatheticHz
            self.centsOffset = centsOffset
            self.swellGain = swellGain
        }
    }

    public static func vibratoState(
        dxFromStar: CGFloat,
        dyFromStar: CGFloat,
        radius: CGFloat,
        baseHz: Double,
        anchorHz: Double
    ) -> VibratoState {
        let safeR = max(8.0, Double(radius))
        let dxNorm = max(-1.0, min(1.0, Double(dxFromStar) / safeR))
        let cents = dxNorm * 24.0
        let pitchFactor = pow(2.0, cents / 1200.0)
        let distNorm = max(0.0, min(1.0, hypot(Double(dxFromStar), Double(dyFromStar)) / safeR))
        let freqHz = max(40.0, baseHz) * pitchFactor
        let sympHz = max(40.0, anchorHz)
        let gain = 0.08 + distNorm * 0.12
        return VibratoState(
            frequencyHz: freqHz,
            sympatheticHz: sympHz,
            centsOffset: cents,
            swellGain: gain
        )
    }
}

/// 棱镜音程丝线几何美学映射器：依据两音符间跨越的音阶跨度动态调制连线线宽、外光晕与透光率（大跳明亮生辉、级进轻盈流淌）。
public enum IntervalSilkStyle {
    public struct SegmentMetrics: Equatable, Sendable {
        public let laneSpan: Int
        public let isExpressiveLeap: Bool
        public let coreWidth: CGFloat
        public let glowWidth: CGFloat
        public let coreOpacity: Double
        public let glowOpacity: Double

        public init(
            laneSpan: Int,
            isExpressiveLeap: Bool,
            coreWidth: CGFloat,
            glowWidth: CGFloat,
            coreOpacity: Double,
            glowOpacity: Double
        ) {
            self.laneSpan = laneSpan
            self.isExpressiveLeap = isExpressiveLeap
            self.coreWidth = coreWidth
            self.glowWidth = glowWidth
            self.coreOpacity = coreOpacity
            self.glowOpacity = glowOpacity
        }
    }

    public static func metrics(fromLane: Int, toLane: Int, isNight: Bool) -> SegmentMetrics {
        let clampedFrom = max(0, min(7, fromLane))
        let clampedTo = max(0, min(7, toLane))
        let span = abs(clampedTo - clampedFrom)
        let isLeap = span >= 3
        let coreW: CGFloat = span >= 5 ? 2.8 : (isLeap ? 2.4 : 1.8)
        let glowW: CGFloat = isLeap ? coreW * 2.8 : 0.0
        let coreOp = isNight ? (isLeap ? 0.68 : 0.46) : (isLeap ? 0.62 : 0.40)
        let glowOp = isLeap ? (isNight ? 0.24 : 0.18) : 0.0
        return SegmentMetrics(
            laneSpan: span,
            isExpressiveLeap: isLeap,
            coreWidth: coreW,
            glowWidth: glowW,
            coreOpacity: coreOp,
            glowOpacity: glowOp
        )
    }
}

/// 活体哼唱轮廓滤波与归一化器：带自适应噪声门限、三点中值去毛刺与稳态中心化，让哼唱丝带既灵动跟音又抗底噪跳变。
public enum LivePitchContourFilter {
    public static func adaptiveNoiseFloorRMS(peakRMS: Double) -> Double {
        guard peakRMS.isFinite, peakRMS > 0 else { return 0.004 }
        return max(0.004, peakRMS * 0.12)
    }

    public static func medianSmooth(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }
        var out = values
        for i in 1..<(values.count - 1) {
            let a = values[i - 1], b = values[i], c = values[i + 1]
            if a.isFinite && b.isFinite && c.isFinite {
                out[i] = [a, b, c].sorted()[1]
            }
        }
        return out
    }

    public static func normalizeSemitoneTrace(_ rawSemitones: [Double]) -> [Double] {
        let valid = rawSemitones.filter { $0.isFinite }
        guard !valid.isEmpty else { return [] }
        let smoothed = medianSmooth(valid)
        guard let lo = smoothed.min(), let hi = smoothed.max() else { return [] }
        let span = hi - lo
        if span < 0.8 {
            return Array(repeating: 0.48, count: smoothed.count)
        }
        let effSpan = max(4.0, span)
        let mid = (lo + hi) * 0.5
        return smoothed.map { val in
            let norm = 0.5 + (val - mid) / effSpan
            return max(0.08, min(0.92, norm))
        }
    }

    public static func frameRMS(mono16kSamples: [Float], frameCount: Int, hopSize: Int) -> [Double] {
        guard frameCount > 0, !mono16kSamples.isEmpty else { return [] }
        let n = mono16kSamples.count
        var result = [Double](repeating: 0.0, count: frameCount)
        let halfWin = max(64, hopSize)
        for f in 0..<frameCount {
            let center = f * hopSize
            let lo = max(0, center - halfWin)
            let hi = min(n, center + halfWin)
            guard hi > lo else { continue }
            var sumSq = 0.0
            for idx in lo..<hi {
                let s = Double(mono16kSamples[idx])
                sumSq += s * s
            }
            result[f] = sqrt(sumSq / Double(hi - lo))
        }
        return result
    }

    public static func extractVoicedSemitones(
        pitchHz: [Double],
        confidence: [Double],
        frameRMS: [Double]
    ) -> [Double] {
        let peak = frameRMS.filter { $0.isFinite }.max() ?? 0.0
        let gate = adaptiveNoiseFloorRMS(peakRMS: peak)
        var voiced: [Double] = []
        voiced.reserveCapacity(pitchHz.count)
        for i in 0..<pitchHz.count {
            let hz = pitchHz[i]
            let conf = i < confidence.count ? confidence[i] : 1.0
            let rms = i < frameRMS.count ? frameRMS[i] : peak
            if hz.isFinite && hz > 65.0 && conf >= 0.32 && rms >= gate {
                voiced.append(12.0 * log2(hz / 110.0))
            }
        }
        return medianSmooth(voiced)
    }
}

/// 闭眼滑音长按呼吸延音节拍标尺：按停留时长映射三档脉冲门槛，帮助闭眼与视障用户用触觉雕塑长音与短音。
public enum TactileSustainStage {
    public struct Stage: Equatable, Sendable {
        public let tier: Int
        public let haloScale: CGFloat
        public let targetDuration: Double
        public let label: String
    }

    public static func stage(forHeldSeconds held: Double) -> Stage {
        let safeHeld = held.isFinite ? max(0.0, held) : 0.0
        if safeHeld >= 1.40 {
            return Stage(tier: 3, haloScale: 1.78, targetDuration: 1.65, label: "延音")
        } else if safeHeld >= 0.90 {
            return Stage(tier: 2, haloScale: 1.50, targetDuration: 1.15, label: "长音")
        } else if safeHeld >= 0.45 {
            return Stage(tier: 1, haloScale: 1.24, targetDuration: 0.65, label: "一拍")
        } else {
            return Stage(tier: 0, haloScale: 1.00, targetDuration: 0.38, label: "短音")
        }
    }
}

/// 调式声学空间气候档案：按 5 种情绪风格动态微调空间混响湿度、音板温暖阻尼与立体声展宽。
public struct AcousticSpaceProfile: Equatable, Sendable {
    public let reverbWetMix: Float
    public let warmthDamping: Double
    public let stereoSpread: Double

    public init(reverbWetMix: Float, warmthDamping: Double, stereoSpread: Double) {
        self.reverbWetMix = reverbWetMix
        self.warmthDamping = warmthDamping
        self.stereoSpread = stereoSpread
    }

    public static func profile(for mode: ScaleMode) -> AcousticSpaceProfile {
        switch mode {
        case .cloudLydian:
            return AcousticSpaceProfile(reverbWetMix: 38.0, warmthDamping: 0.94, stereoSpread: 1.22)
        case .brightMajor:
            return AcousticSpaceProfile(reverbWetMix: 22.0, warmthDamping: 1.08, stereoSpread: 1.00)
        case .goldenMixolydian:
            return AcousticSpaceProfile(reverbWetMix: 27.0, warmthDamping: 0.90, stereoSpread: 1.06)
        case .forestDorian:
            return AcousticSpaceProfile(reverbWetMix: 31.0, warmthDamping: 0.98, stereoSpread: 1.12)
        case .wistfulMinor:
            return AcousticSpaceProfile(reverbWetMix: 35.0, warmthDamping: 0.86, stereoSpread: 1.14)
        }
    }
}

/// 音画同步全息空间声像映射器：让旋律在「转盘 / 曲线 / 星环」上的当前几何方位直接映射为左右双耳立体声像。
public enum AcousticSpatialPanMapper {
    public static func pan(forBeatOnset onset: Double, totalDuration: Double, visualMode: StageVisualMode) -> Double {
        guard onset.isFinite && totalDuration.isFinite && totalDuration > 0.05 else {
            return 0.0
        }
        let progress = max(0.0, min(1.0, onset / totalDuration))
        let angle = OrbitalGeometry.noteBaseAngle(onset: onset, totalDuration: totalDuration)
        let raw: Double
        switch visualMode {
        case .orbitalDisc:
            raw = sin(angle) * 0.44
        case .flowingRiver:
            raw = (progress * 2.0 - 1.0) * 0.48
        case .resonanceNebula:
            raw = cos(angle) * 0.36 + sin(angle * 2.0) * 0.14
        }
        return max(-0.58, min(0.58, raw))
    }
}

/// 跨音高琴弦物理阻尼律：低音共鸣箱温暖绵长，高音琴弦短促清透、空气高频吸收略快（无音频线程开销，在触发时预计算）。
public enum PitchScaledAcousticEnvelope {
    public static func scaledDecay(baseDecay: Double, frequency: Double) -> Double {
        let safeDecay = baseDecay.isFinite ? max(0.25, min(4.8, baseDecay)) : 1.5
        let safeFreq = frequency.isFinite ? max(40.0, min(4800.0, frequency)) : 261.63
        let factor = max(0.58, min(1.38, pow(261.63 / safeFreq, 0.28)))
        return max(0.22, min(5.4, safeDecay * factor))
    }

    public static func highFrequencyAirAbsorption(frequency: Double) -> Double {
        let safeFreq = frequency.isFinite ? max(40.0, min(4800.0, frequency)) : 261.63
        return max(0.68, min(1.18, pow(261.63 / safeFreq, 0.16)))
    }
}

/// 底栏 8 键彩虹琴条纵向微推表现映射：保持 8pt 点击/横滑死区，超过死区按垂直位移映射水银微光柱高度与柔和弦乐揉弦偏移。
public enum KeyRibbonExpressionMapper {
    public struct Expression: Equatable, Sendable {
        public let isVibratoActive: Bool
        public let mercuryFraction: Double
        public let vibratoDX: CGFloat
        public let vibratoDY: CGFloat
    }

    public static func expression(verticalOffsetPt: CGFloat, barHeightPt: CGFloat) -> Expression {
        guard verticalOffsetPt.isFinite, abs(verticalOffsetPt) > 8.0 else {
            return Expression(isVibratoActive: false, mercuryFraction: 0.0, vibratoDX: 0.0, vibratoDY: 0.0)
        }
        let usableSpan = max(18.0, Double(barHeightPt.isFinite ? barHeightPt : 62.0) * 0.65)
        let norm = max(-1.0, min(1.0, Double(-verticalOffsetPt) / usableSpan))
        let mercury = max(0.18, min(1.0, 0.22 + abs(norm) * 0.78))
        let dx = CGFloat(norm * 22.0)
        let dy = CGFloat(abs(norm) * 10.0)
        return Expression(isVibratoActive: true, mercuryFraction: mercury, vibratoDX: dx, vibratoDY: dy)
    }
}

/// 单指手绘声画笔映射器：把画线轨迹实时转化为当前调式安全音高、双耳空间声像与防连响节流信号，让手指一边画线一边唱出旋律。
public enum SketchPitchBrushMapper {
    public static let minimumTriggerIntervalSeconds: Double = 0.055

    public static func laneIndex(normalizedTopToBottomY: Double, pentatonicSafe: Bool) -> Int {
        let clampedY = normalizedTopToBottomY.isFinite ? max(0.0, min(1.0, normalizedTopToBottomY)) : 0.5
        let ascending = 1.0 - clampedY
        let rawLane = max(0, min(7, Int((ascending * 7.0).rounded())))
        return XylophoneLane.nearestAllowedIndex(rawLane, pentatonicSafe: pentatonicSafe)
    }

    public static func spatialPan(normalizedX: Double) -> Double {
        let clampedX = normalizedX.isFinite ? max(0.0, min(1.0, normalizedX)) : 0.5
        return (clampedX * 2.0 - 1.0) * 0.46
    }

    public static func shouldTrigger(lastTriggerTime: Double, now: Double) -> Bool {
        guard now.isFinite else { return false }
        if !lastTriggerTime.isFinite || lastTriggerTime <= 0 { return true }
        return (now - lastTriggerTime) >= minimumTriggerIntervalSeconds
    }
}

/// 无损弹性节拍吸附引擎：在不改动原始自由时间轴（rawOnset/rawDuration）的基础上估算舒适律动网格并生成转盘辐射拍线。
public enum GrooveAlignmentEngine {
    public static func estimatedBeatStep(for notes: [NoteBead]) -> Double {
        let sorted = notes.sorted { $0.rawOnset < $1.rawOnset }
        guard sorted.count >= 2 else { return 0.36 }
        var gaps: [Double] = []
        gaps.reserveCapacity(sorted.count - 1)
        for i in 1..<sorted.count {
            let g = sorted[i].rawOnset - sorted[i - 1].rawOnset
            if g.isFinite && g >= 0.08 {
                gaps.append(g)
            }
        }
        guard !gaps.isEmpty else { return 0.36 }
        let ordered = gaps.sorted()
        let mid = ordered[ordered.count / 2]
        return max(0.18, min(0.72, mid))
    }

    public static func populateQuantizedTargets(for notes: [NoteBead]) -> [NoteBead] {
        guard notes.count >= 2 else { return notes }
        let baseStep = estimatedBeatStep(for: notes)
        let grid = max(0.10, baseStep * 0.5)
        let sorted = notes.sorted { $0.rawOnset < $1.rawOnset }
        let anchor = max(0.08, sorted[0].rawOnset)
        var out: [NoteBead] = []
        out.reserveCapacity(sorted.count)
        var prevSnapped = -1.0

        for (idx, var bead) in sorted.enumerated() {
            let candidate = anchor + ((bead.rawOnset - anchor) / grid).rounded() * grid
            var snapped = max(0.08, candidate)
            if idx > 0 {
                snapped = max(prevSnapped + 0.10, snapped)
            }
            prevSnapped = snapped
            let snappedDur = max(0.16, min(2.40, max(1.0, (bead.rawDuration / grid).rounded()) * grid))
            bead.quantizedOnset = snapped
            bead.quantizedDuration = snappedDur
            out.append(bead)
        }
        return out
    }

    public static func beatSpokeAngles(totalDuration: Double, grooveStrength: Double, beatStep: Double) -> [Double] {
        guard totalDuration.isFinite && totalDuration > 0.4,
              grooveStrength.isFinite && grooveStrength > 0.05 else {
            return []
        }
        let step = max(0.22, min(1.0, beatStep.isFinite ? beatStep : 0.36))
        let count = max(4, min(24, Int((totalDuration / step).rounded())))
        return (0..<count).map { Double($0) / Double(count) * 2.0 * Double.pi }
    }

    public static func beatTimestamps(totalDuration: Double, grooveStrength: Double, beatStep: Double) -> [Double] {
        guard totalDuration.isFinite && totalDuration > 0.4,
              grooveStrength.isFinite && grooveStrength > 0.05 else {
            return []
        }
        let step = max(0.22, min(1.0, beatStep.isFinite ? beatStep : 0.36))
        let count = max(4, min(24, Int((totalDuration / step).rounded())))
        let spacing = totalDuration / Double(count)
        return (0..<count).map { Double($0) * spacing }
    }
}

/// 音区胸腔移调辅助：在不破坏简谱级数前提下将主音基准限制在舒适听觉音区（48...72 MIDI）。
public enum RootTranspositionHelper {
    public static let minMIDI: Int = 48
    public static let maxMIDI: Int = 72
    public static let presetOffsets: [Int] = [-5, -2, 0, 2, 5]

    public static func clampedRootMIDI(_ midi: Int) -> Int {
        max(minMIDI, min(maxMIDI, midi))
    }

    public static func compactLabel(forRootMIDI midi: Int) -> String {
        let delta = clampedRootMIDI(midi) - 60
        if delta == 0 { return "0" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }

    public static func accessibilityLabel(forRootMIDI midi: Int) -> String {
        let delta = clampedRootMIDI(midi) - 60
        if delta == 0 { return "原调" }
        return delta > 0 ? "升高 \(delta) 半音" : "降低 \(-delta) 半音"
    }
}

/// 闭眼滑音草稿乐句排拍与试听时长辅助：保证任意插入、单拍删改后时序紧密连贯，绝不残留断裂空洞。
public enum NightLampPhraseHelper {
    public static func nextOnset(after beads: [NoteBead]) -> Double {
        guard let last = beads.last else { return 0.14 }
        return last.rawOnset + max(0.36, last.rawDuration + 0.08)
    }

    public static func repackSequentialTimings(_ beads: [NoteBead]) -> [NoteBead] {
        var result: [NoteBead] = []
        result.reserveCapacity(beads.count)
        for bead in beads {
            var next = bead
            next.rawOnset = nextOnset(after: result)
            next.quantizedOnset = nil
            result.append(next)
        }
        return result
    }

    public static func removingBead(at index: Int, from beads: [NoteBead]) -> [NoteBead] {
        guard beads.indices.contains(index) else { return beads }
        var copy = beads
        copy.remove(at: index)
        return repackSequentialTimings(copy)
    }

    public static func totalAuditionDuration(of beads: [NoteBead]) -> Double {
        guard let last = beads.last else { return 0.0 }
        return max(0.6, last.rawOnset + last.rawDuration + 0.25)
    }

    public static func normalizedDurationRatio(for duration: Double) -> Double {
        guard duration.isFinite else { return 0.25 }
        let clamped = max(0.28, min(1.85, duration))
        return (clamped - 0.28) / (1.85 - 0.28)
    }

    public static func chipVisualWidth(forDuration duration: Double) -> CGFloat {
        let ratio = normalizedDurationRatio(for: duration)
        return 46.0 + CGFloat(ratio) * 52.0
    }
}

/// 星环星辰命中偏心距力学映射：正中星心奏出饱满清亮共鸣，掠过星缘发出温柔轻声余韵。
public enum StarHitDynamicsMapper {
    public static func hitDynamics(distancePt: CGFloat, hitRadius: CGFloat) -> (velocity: Double, brightness: Double) {
        let safeR = max(8.0, Double(hitRadius.isFinite ? hitRadius : 36.0))
        let safeDist = max(0.0, Double(distancePt.isFinite ? distancePt : 0.0))
        let closeness = max(0.0, min(1.0, 1.0 - safeDist / safeR))
        let velocity = 0.42 + closeness * 0.36
        let brightness = 0.78 + closeness * 0.34
        return (velocity, brightness)
    }
}

/// 8 键木琴琴席左右立体声摆位与木质共鸣箱泛音弦耦合：单手点触琴键即可唤醒自然声场宽度与纯五度/八度微共鸣。
public enum SympatheticResonanceMapper {
    public struct ResonanceSpec: Sendable, Equatable {
        public let keyPan: Double
        public let overtoneHz: Double
        public let overtoneVelocity: Double
        public let overtonePan: Double
        public let sympatheticLaneIndex: Int
    }

    public static func keyBenchPan(laneIndex: Int, stereoSpread: Double = 1.0) -> Double {
        let idx = max(0, min(7, laneIndex))
        let spread = max(0.60, min(1.35, stereoSpread.isFinite ? stereoSpread : 1.0))
        let raw = (Double(idx) / 3.5 - 1.0) * 0.46 * spread
        return max(-0.64, min(0.64, raw))
    }

    public static func compute(
        laneIndex: Int,
        baseHz: Double,
        velocity: Double,
        stereoSpread: Double = 1.0,
        pentatonicSafe: Bool = false
    ) -> ResonanceSpec {
        let idx = max(0, min(7, laneIndex))
        let keyPan = keyBenchPan(laneIndex: idx, stereoSpread: stereoSpread)
        let diatonicPartners = [7, 5, 6, 7, 0, 1, 2, 0]
        var symLane = diatonicPartners[idx]
        if pentatonicSafe && symLane == 6 {
            // 五音模式下 7 Si 不发声，改以主音 1 Do 作为温和共鸣键
            symLane = 0
        }

        guard baseHz.isFinite, baseHz >= 40.0, velocity.isFinite else {
            return ResonanceSpec(
                keyPan: keyPan,
                overtoneHz: 220.0,
                overtoneVelocity: 0.0,
                overtonePan: -keyPan * 0.45,
                sympatheticLaneIndex: symLane
            )
        }

        let safeVel = max(0.0, min(1.0, velocity))
        let rawOvertone = baseHz < 440.0 ? baseHz * 1.5 : baseHz * 0.5
        let clampedHz = max(65.0, min(1800.0, rawOvertone))
        let overtoneVel = safeVel >= 0.36 ? min(0.14, max(0.05, safeVel * 0.18)) : 0.0
        return ResonanceSpec(
            keyPan: keyPan,
            overtoneHz: clampedHz,
            overtoneVelocity: overtoneVel,
            overtonePan: -keyPan * 0.45,
            sympatheticLaneIndex: symLane
        )
    }
}

/// 盲人/零基础乐句级跨步导航与开头速览拍数估算：按和弦分句一键跃迁，无需逐拍繁琐滑动。
public enum PhraseNavigationMapper {
    public static func nextPhraseBeatIndex(
        notes: [NoteBead],
        spans: [ChordSpan],
        grooveStrength: Double,
        currentBeatIndex: Int?,
        delta: Int
    ) -> Int? {
        guard !notes.isEmpty else { return nil }
        let cur = max(0, min(notes.count - 1, currentBeatIndex ?? 0))
        let stepDir = delta >= 0 ? 1 : -1

        if spans.count > 1 {
            let curTime = notes[cur].displayOnset(grooveStrength: grooveStrength)
            let curSpanIdx = spans.firstIndex { curTime >= $0.startTime && curTime < $0.endTime } ?? 0
            let nextSpanIdx = max(0, min(spans.count - 1, curSpanIdx + stepDir))
            let targetSpan = spans[nextSpanIdx]
            if let inSpan = notes.firstIndex(where: {
                let onset = $0.displayOnset(grooveStrength: grooveStrength)
                return onset >= targetSpan.startTime - 0.02 && onset < targetSpan.endTime
            }) {
                return inSpan
            }
            if let nearest = notes.enumerated().min(by: {
                abs($0.element.displayOnset(grooveStrength: grooveStrength) - targetSpan.startTime)
                    < abs($1.element.displayOnset(grooveStrength: grooveStrength) - targetSpan.startTime)
            })?.offset {
                return nearest
            }
        }
        return max(0, min(notes.count - 1, cur + stepDir * 4))
    }

    public static func openingPreviewCount(for notes: [NoteBead]) -> Int {
        min(4, notes.count)
    }
}

/// 节奏鼓双声部强弱声像与动态间距柱映射：让「拍节奏」像敲真手鼓般自带重拍胸腔感与长短时距轮廓。
public enum RhythmDrumAccentMapper {
    public struct TapVoice: Sendable, Equatable {
        public let degree: Int
        public let velocity: Double
        public let pan: Double
        public let isDownbeat: Bool
    }

    public struct BarMetric: Sendable, Equatable {
        public let widthPt: CGFloat
        public let heightPt: CGFloat
        public let isDownbeat: Bool
    }

    public static func tapVoice(forTapIndex tapIndex: Int) -> TapVoice {
        let idx = max(0, tapIndex)
        switch idx % 4 {
        case 0:
            return TapVoice(degree: 1, velocity: 0.58, pan: 0.0, isDownbeat: true)
        case 2:
            return TapVoice(degree: 5, velocity: 0.44, pan: 0.18, isDownbeat: false)
        case 1:
            return TapVoice(degree: 3, velocity: 0.38, pan: -0.18, isDownbeat: false)
        default:
            return TapVoice(degree: 3, velocity: 0.36, pan: 0.14, isDownbeat: false)
        }
    }

    public static func barVisualMetrics(timestamps: [TimeInterval]) -> [BarMetric] {
        guard !timestamps.isEmpty else { return [] }
        return timestamps.indices.map { i in
            let isDownbeat = (i % 4 == 0)
            let rawGap: Double
            if i + 1 < timestamps.count {
                let diff = timestamps[i + 1] - timestamps[i]
                rawGap = diff.isFinite ? diff : 0.42
            } else if i > 0 {
                let diff = timestamps[i] - timestamps[i - 1]
                rawGap = diff.isFinite ? diff : 0.42
            } else {
                rawGap = 0.42
            }
            let clampedGap = max(0.14, min(1.40, rawGap))
            let widthPt = CGFloat(8.0 + ((clampedGap - 0.14) / 1.26) * 18.0)
            let heightPt: CGFloat = isDownbeat ? 30.0 : (i % 4 == 2 ? 23.0 : 18.0)
            return BarMetric(widthPt: widthPt, heightPt: heightPt, isDownbeat: isDownbeat)
        }
    }
}

/// 音符微调磁吸与安全避让计算器：支持逐拍前后微调不撞音，开启律动后拖拽顺滑吸附 120ms 节拍刻度。
public enum BeatTimingNudgeHelper {
    public static func nudgedOnset(
        notes: [NoteBead],
        targetIndex: Int,
        rawDelta: Double,
        grooveStrength: Double
    ) -> Double {
        guard notes.indices.contains(targetIndex) else { return 0.08 }
        let sorted = notes.enumerated().sorted { $0.element.rawOnset < $1.element.rawOnset }
        let sortedPos = sorted.firstIndex(where: { $0.offset == targetIndex }) ?? 0
        let current = sorted[sortedPos].element.rawOnset
        let safeDelta = rawDelta.isFinite ? rawDelta : 0.0
        let baseMin = sortedPos > 0 ? sorted[sortedPos - 1].element.rawOnset + 0.09 : 0.08
        let lowerBound = max(0.08, baseMin)
        let upperBound = sortedPos + 1 < sorted.count ? max(lowerBound, sorted[sortedPos + 1].element.rawOnset - 0.09) : 600.0
        var candidate = max(lowerBound, min(upperBound, current + safeDelta))
        if grooveStrength.isFinite && grooveStrength > 0.35 && abs(safeDelta) > 0.001 {
            let snapped = (candidate / 0.12).rounded() * 0.12
            if snapped >= lowerBound && snapped <= upperBound && abs(snapped - current) >= 0.04 {
                candidate = snapped
            }
        }
        return candidate
    }

    public static func dragGridSnapOnset(
        rawOnset: Double,
        grooveStrength: Double,
        gridStep: Double = 0.12
    ) -> (onset: Double, gridBucket: Int) {
        let safeOnset = max(0.08, rawOnset.isFinite ? rawOnset : 0.08)
        let step = max(0.06, gridStep.isFinite ? gridStep : 0.12)
        let nearestBucket = Int((safeOnset / step).rounded())
        let snapped = max(0.08, Double(nearestBucket) * step)
        let alpha = (grooveStrength.isFinite && grooveStrength > 0.25) ? min(0.85, grooveStrength) : 0.0
        let blended = safeOnset * (1.0 - alpha) + snapped * alpha
        return (blended, nearestBucket)
    }
}

/// 曲库卡片与预览使用的微型旋律走势采样器（把任意长度乐曲压缩为平滑有序的归一化轮廓采样点）。
public enum MelodySparklineMapper {
    public struct SparklineSample: Equatable, Sendable {
        public let xNorm: Double
        public let yNorm: Double
        public let laneIndex: Int

        public init(xNorm: Double, yNorm: Double, laneIndex: Int) {
            self.xNorm = xNorm
            self.yNorm = yNorm
            self.laneIndex = laneIndex
        }
    }

    public static func samples(for document: MelodyDocument, maxPoints: Int = 24) -> [SparklineSample] {
        guard !document.notes.isEmpty else { return [] }
        let safeCap = max(4, min(64, maxPoints))
        let groove = document.grooveStrength.isFinite ? max(0.0, min(1.0, document.grooveStrength)) : 0.0
        let sorted = document.notes.sorted {
            $0.displayOnset(grooveStrength: groove) < $1.displayOnset(grooveStrength: groove)
        }

        let picked: [NoteBead]
        if sorted.count <= safeCap {
            picked = sorted
        } else {
            var indices: [Int] = []
            indices.reserveCapacity(safeCap)
            for i in 0..<safeCap {
                let frac = Double(i) / Double(safeCap - 1)
                let idx = max(0, min(sorted.count - 1, Int((frac * Double(sorted.count - 1)).rounded())))
                if indices.last != idx {
                    indices.append(idx)
                }
            }
            if indices.last != sorted.count - 1 {
                indices.append(sorted.count - 1)
            }
            picked = indices.map { sorted[$0] }
        }

        if picked.count == 1 {
            let bead = picked[0]
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let yNorm = max(0.0, min(1.0, Double(laneIdx) / 7.0))
            return [SparklineSample(xNorm: 0.5, yNorm: yNorm, laneIndex: laneIdx)]
        }

        let firstOnset = picked.first!.displayOnset(grooveStrength: groove)
        let lastOnset = picked.last!.displayOnset(grooveStrength: groove)
        let span = (lastOnset.isFinite && firstOnset.isFinite && (lastOnset - firstOnset) > 0.02)
            ? (lastOnset - firstOnset)
            : nil

        return picked.enumerated().map { idx, bead in
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let yNorm = max(0.0, min(1.0, Double(laneIdx) / 7.0))
            let rawX: Double
            if let span {
                let t = bead.displayOnset(grooveStrength: groove)
                rawX = t.isFinite ? (t - firstOnset) / span : Double(idx) / Double(picked.count - 1)
            } else {
                rawX = Double(idx) / Double(picked.count - 1)
            }
            let clampedX = rawX.isFinite ? max(0.0, min(1.0, rawX)) : 0.0
            return SparklineSample(xNorm: clampedX, yNorm: yNorm, laneIndex: laneIdx)
        }
    }
}

/// 声音调色台的声学可视化图谱：把「咩 · 主旋律音色」画成真实物理包络波形，把「哞 · 伴奏织体」画成节奏音点矩阵。
public enum AcousticSignatureGeometry {
    public struct PatternDot: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let radiusScale: Double

        public init(x: Double, y: Double, radiusScale: Double) {
            self.x = x
            self.y = y
            self.radiusScale = radiusScale
        }
    }

    public static func voiceEnvelopePoints(for voice: MelodyVoice) -> [Double] {
        switch voice {
        case .singingCello:
            // 弓弦渐入 + 饱满持续 + 柔和双频揉弦波动
            return [0.08, 0.24, 0.52, 0.78, 0.90, 0.84, 0.92, 0.83, 0.90, 0.80, 0.86, 0.74, 0.64, 0.50, 0.36, 0.22, 0.12]
        case .concertPiano:
            // 毛毡木槌瞬态峰 + 自然木质共鸣平滑衰变
            return [0.16, 0.96, 0.90, 0.78, 0.68, 0.59, 0.51, 0.44, 0.38, 0.33, 0.28, 0.24, 0.20, 0.17, 0.14, 0.11, 0.09]
        case .liquidHarp:
            // 清澈拨弦锐利起音 + 清透谐波涟漪落音
            return [0.18, 0.98, 0.74, 0.56, 0.60, 0.44, 0.36, 0.38, 0.28, 0.23, 0.24, 0.18, 0.15, 0.13, 0.10, 0.08, 0.06]
        case .celestaGlass:
            // 八音盒金属音栓晶透双峰闪光脉冲
            return [0.22, 1.00, 0.62, 0.40, 0.58, 0.36, 0.24, 0.34, 0.20, 0.15, 0.19, 0.12, 0.10, 0.09, 0.07, 0.06, 0.05]
        }
    }

    public static func accompanimentPatternDots(for texture: AccompanimentTexture) -> [PatternDot] {
        switch texture {
        case .swanRipple:
            // 细腻上下波浪分解琶音
            return [
                PatternDot(x: 0.12, y: 0.22, radiusScale: 1.05),
                PatternDot(x: 0.24, y: 0.46, radiusScale: 0.82),
                PatternDot(x: 0.36, y: 0.74, radiusScale: 0.90),
                PatternDot(x: 0.48, y: 0.50, radiusScale: 0.78),
                PatternDot(x: 0.60, y: 0.26, radiusScale: 1.00),
                PatternDot(x: 0.72, y: 0.52, radiusScale: 0.84),
                PatternDot(x: 0.84, y: 0.78, radiusScale: 0.92),
                PatternDot(x: 0.92, y: 0.56, radiusScale: 0.76)
            ]
        case .feltWaltz:
            // 1 强低音落地 + 2/3 轻盈双和弦抬举（三拍圆舞）
            return [
                PatternDot(x: 0.15, y: 0.20, radiusScale: 1.18),
                PatternDot(x: 0.32, y: 0.62, radiusScale: 0.82),
                PatternDot(x: 0.32, y: 0.82, radiusScale: 0.74),
                PatternDot(x: 0.46, y: 0.62, radiusScale: 0.80),
                PatternDot(x: 0.46, y: 0.82, radiusScale: 0.72),
                PatternDot(x: 0.64, y: 0.20, radiusScale: 1.12),
                PatternDot(x: 0.80, y: 0.62, radiusScale: 0.82),
                PatternDot(x: 0.80, y: 0.82, radiusScale: 0.74)
            ]
        case .summerGlass:
            // 交错悬浮开放九度与高音微光点
            return [
                PatternDot(x: 0.16, y: 0.26, radiusScale: 0.95),
                PatternDot(x: 0.30, y: 0.72, radiusScale: 0.88),
                PatternDot(x: 0.44, y: 0.48, radiusScale: 0.92),
                PatternDot(x: 0.58, y: 0.84, radiusScale: 1.04),
                PatternDot(x: 0.72, y: 0.32, radiusScale: 0.90),
                PatternDot(x: 0.86, y: 0.68, radiusScale: 0.86)
            ]
        case .pureChorale:
            // 稳重齐整柱式三和弦竖列
            return [
                PatternDot(x: 0.24, y: 0.24, radiusScale: 1.00),
                PatternDot(x: 0.24, y: 0.50, radiusScale: 0.96),
                PatternDot(x: 0.24, y: 0.76, radiusScale: 0.96),
                PatternDot(x: 0.52, y: 0.24, radiusScale: 1.00),
                PatternDot(x: 0.52, y: 0.50, radiusScale: 0.96),
                PatternDot(x: 0.52, y: 0.76, radiusScale: 0.96),
                PatternDot(x: 0.80, y: 0.24, radiusScale: 1.00),
                PatternDot(x: 0.80, y: 0.50, radiusScale: 0.96),
                PatternDot(x: 0.80, y: 0.76, radiusScale: 0.96)
            ]
        }
    }
}

/// 「写旋律 · 更多」扩写双曲线对比预览几何（左半原形虚线 vs 右半变形彩色实线）。
public enum MotifMorphPreviewGeometry {
    public struct PreviewCurves: Equatable, Sendable {
        public let seedPoints: [Double]
        public let morphedPoints: [Double]

        public init(seedPoints: [Double], morphedPoints: [Double]) {
            self.seedPoints = seedPoints
            self.morphedPoints = morphedPoints
        }
    }

    public static func curves(for operation: MotifGrowthOperation) -> PreviewCurves {
        switch operation {
        case .climbSequence:
            return PreviewCurves(
                seedPoints: [0.20, 0.44, 0.32],
                morphedPoints: [0.46, 0.76, 0.62, 0.88]
            )
        case .waterMirror:
            return PreviewCurves(
                seedPoints: [0.24, 0.72, 0.52],
                morphedPoints: [0.76, 0.28, 0.48, 0.22]
            )
        case .tearfulSuspension:
            return PreviewCurves(
                seedPoints: [0.30, 0.62, 0.82],
                morphedPoints: [0.64, 0.64, 0.42, 0.20]
            )
        case .fullFourPhrasePoem:
            return PreviewCurves(
                seedPoints: [0.22, 0.50, 0.36],
                morphedPoints: [0.48, 0.76, 0.58, 0.86, 0.44, 0.24]
            )
        }
    }
}

/// 开头三音直拖彩色音高推子映射（将垂直手势归一化高度映射到 -3...+3 变奏级数与音高轨道色）。
public enum SeedPitchFaderMapper {
    public static func shift(forNormalizedTopToBottomY normY: Double) -> Int {
        guard normY.isFinite else { return 0 }
        let clamped = max(0.0, min(1.0, normY))
        let value = Int(((1.0 - clamped) * 6.0 - 3.0).rounded())
        return max(-3, min(3, value))
    }

    public static func normalizedFillHeight(forShift shift: Int) -> Double {
        let clamped = max(-3, min(3, shift))
        return 0.14 + (Double(clamped + 3) / 6.0) * 0.86
    }

    public static func resolvedLaneIndex(document: MelodyDocument, noteIndex: Int, shift: Int) -> Int {
        let safeIdx = max(0, min(2, noteIndex))
        let defaultDegrees = [1, 3, 5]
        let sourceNotes = document.notes.isEmpty ? SpecimenLibrary.saintSaensTheSwan.notes : document.notes
        let (baseDeg, baseOct): (Int, Int) = sourceNotes.indices.contains(safeIdx)
            ? (sourceNotes[safeIdx].degree, sourceNotes[safeIdx].octaveOffset)
            : (defaultDegrees[safeIdx], 0)
        let linear = baseOct * 7 + (baseDeg - 1) + max(-3, min(3, shift))
        let clamped = max(-3, min(8, linear))
        let newOct = Int(floor(Double(clamped) / 7.0))
        let newDeg = max(1, min(7, clamped - newOct * 7 + 1))
        let safeOct = max(-1, min(1, newOct))
        return XylophoneLane.laneIndex(degree: newDeg, octaveOffset: safeOct)
    }
}

/// 主舞台「哞 · 4 幕和声彩色轨」与声音面板「5 档和弦条码」几何映射。
public enum HarmonyCurtainStripMapper {
    public struct CurtainSegment: Identifiable, Equatable, Sendable {
        public let spanID: Int
        public let chord: DiatonicChord
        public let fractionWidth: Double
        public let romanLabel: String

        public var id: Int { spanID }

        public init(spanID: Int, chord: DiatonicChord, fractionWidth: Double, romanLabel: String) {
            self.spanID = spanID
            self.chord = chord
            self.fractionWidth = fractionWidth
            self.romanLabel = romanLabel
        }
    }

    /// 把不规则长度的 4 幕和弦区间归一化为严格和为 1.0 且不低于最小热区比例的分段（防 NaN 与零宽）。
    public static func segments(from spans: [ChordSpan], totalDuration: Double) -> [CurtainSegment] {
        guard !spans.isEmpty else { return [] }
        let safeTotal = (totalDuration.isFinite && totalDuration > 0.05) ? totalDuration : 2.0
        let rawWidths: [Double] = spans.map { span in
            let d = span.endTime - span.startTime
            let safeD = (d.isFinite && d > 0.01) ? d : (safeTotal / Double(spans.count))
            return max(0.12, min(0.65, safeD / safeTotal))
        }
        let sum = max(0.001, rawWidths.reduce(0, +))
        return zip(spans, rawWidths).map { span, w in
            CurtainSegment(
                spanID: span.id,
                chord: span.chord,
                fractionWidth: w / sum,
                romanLabel: span.chord.roman
            )
        }
    }

    public static func shortPresetTag(for preset: ChordProgressionPreset) -> String {
        switch preset {
        case .autoMatch: return "智能"
        case .classicPop: return "1564"
        case .summerFloat: return "4536"
        case .warmStory: return "1645"
        case .off: return "休息"
        }
    }
}

/// 曲库顶部分类图标短标映射：把超长中文分类标题收敛为单屏均分无溢出图标短标，消除横向盲扫滚动。
public enum LibraryCategoryBadgeMapper {
    public struct CategoryBadge: Identifiable, Equatable, Sendable {
        public let rawCategory: String
        public let shortLabel: String
        public let iconName: String

        public var id: String { rawCategory }

        public init(rawCategory: String, shortLabel: String, iconName: String) {
            self.rawCategory = rawCategory
            self.shortLabel = shortLabel
            self.iconName = iconName
        }
    }

    public static func badge(for rawCategory: String) -> CategoryBadge {
        switch rawCategory {
        case "全部":
            return CategoryBadge(rawCategory: rawCategory, shortLabel: "全部", iconName: "square.grid.2x2.fill")
        case "圣桑·李斯特·浪漫派":
            return CategoryBadge(rawCategory: rawCategory, shortLabel: "浪漫", iconName: "wind")
        case "巴赫·古典名作":
            return CategoryBadge(rawCategory: rawCategory, shortLabel: "古典", iconName: "building.columns.fill")
        case "印象·民族与夜曲":
            return CategoryBadge(rawCategory: rawCategory, shortLabel: "夜曲", iconName: "moon.stars.fill")
        case "原创夏日治愈风":
            return CategoryBadge(rawCategory: rawCategory, shortLabel: "原创", iconName: "sun.haze.fill")
        default:
            let prefix = String(rawCategory.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2))
            return CategoryBadge(
                rawCategory: rawCategory,
                shortLabel: prefix.isEmpty ? "曲目" : prefix,
                iconName: "music.note"
            )
        }
    }

    public static func badges(for categories: [String] = SpecimenLibrary.categories) -> [CategoryBadge] {
        categories.map(badge(for:))
    }
}

