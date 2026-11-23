import Foundation
import SwiftUI

/// 实体彩虹木琴的 8 根阶梯音条（灵感源自《摸索台灯》蒙氏木琴玩具）：
/// 下长上短、颜色分明，每根木条对应一个直观可见的音高阶梯（1·Do 到 1↑·高音Do）。
public struct XylophoneLane: Identifiable, Equatable, Sendable {
    public let index: Int        // 0 (低音 1) ... 7 (高音 1↑)
    public let degree: Int       // 1...7
    public let octaveOffset: Int // 0 or 1
    public let digitLabel: String
    public let solfege: String
    public let chineseName: String
    public let isPentatonicSafe: Bool
    public let barWidthRatio: CGFloat // 实体木琴下长上短比例
    public let dayHex: UInt32
    public let nightHex: UInt32

    public var id: Int { index }

    public var member: ChimmoMember { ChimmoMember.from(degree: degree) }

    public var glyphLabel: String {
        PitchGlyphShape.glyph(forLaneIndex: index).symbolName
    }

    public func barColor(isNight: Bool) -> Color {
        Color(hex: isNight ? nightHex : dayHex)
    }

    /// 自下而上的 8 根标准蒙氏彩虹木琴条（0 = 最低 1·陶诺，7 = 最高 1↑·陶诺）
    public static let allLanes: [XylophoneLane] = [
        XylophoneLane(index: 0, degree: 1, octaveOffset: 0, digitLabel: "1",  solfege: "Do",  chineseName: "陶诺", isPentatonicSafe: true,  barWidthRatio: 1.00, dayHex: 0xE8534A, nightHex: 0xFF7B72),
        XylophoneLane(index: 1, degree: 2, octaveOffset: 0, digitLabel: "2",  solfege: "Re",  chineseName: "豆叩", isPentatonicSafe: true,  barWidthRatio: 0.94, dayHex: 0xF58A2C, nightHex: 0xFFA94D),
        XylophoneLane(index: 2, degree: 3, octaveOffset: 0, digitLabel: "3",  solfege: "Mi",  chineseName: "拍咯", isPentatonicSafe: true,  barWidthRatio: 0.88, dayHex: 0xEBB31A, nightHex: 0xFFD43B),
        XylophoneLane(index: 3, degree: 4, octaveOffset: 0, digitLabel: "4",  solfege: "Fa",  chineseName: "呜嘟", isPentatonicSafe: false, barWidthRatio: 0.82, dayHex: 0x40B865, nightHex: 0x69DB7C),
        XylophoneLane(index: 4, degree: 5, octaveOffset: 0, digitLabel: "5",  solfege: "Sol", chineseName: "壳咯", isPentatonicSafe: true,  barWidthRatio: 0.77, dayHex: 0x15A6AE, nightHex: 0x4FD8CB),
        XylophoneLane(index: 5, degree: 6, octaveOffset: 0, digitLabel: "6",  solfege: "La",  chineseName: "钵莫", isPentatonicSafe: true,  barWidthRatio: 0.72, dayHex: 0x4C74EB, nightHex: 0x74C0FC),
        XylophoneLane(index: 6, degree: 7, octaveOffset: 0, digitLabel: "7",  solfege: "Si",  chineseName: "叮尖", isPentatonicSafe: false, barWidthRatio: 0.67, dayHex: 0x8F67EB, nightHex: 0xB197FC),
        XylophoneLane(index: 7, degree: 1, octaveOffset: 1, digitLabel: "1↑", solfege: "Do↑", chineseName: "高陶", isPentatonicSafe: true,  barWidthRatio: 0.62, dayHex: 0xF05E7E, nightHex: 0xFF8FA3)
    ]

    /// 视觉上从高到低排布（顶行 1↑ -> 底行 1）
    public static var topToBottom: [XylophoneLane] {
        Array(allLanes.reversed())
    }

    public static func lane(at index: Int) -> XylophoneLane {
        allLanes[max(0, min(allLanes.count - 1, index))]
    }

    /// 把任意音珠（含名曲中跨八度音）映射到最直观对应的木琴条索引（0...7）
    public static func laneIndex(degree: Int, octaveOffset: Int) -> Int {
        let clampedDeg = max(1, min(7, degree))
        if octaveOffset >= 1 {
            return clampedDeg == 1 ? 7 : 7
        }
        return clampedDeg - 1
    }

    /// 返回当前安全网设置下允许使用的木琴条索引（从小到大）
    public static func allowedIndices(pentatonicSafe: Bool) -> [Int] {
        pentatonicSafe ? [0, 1, 2, 4, 5, 7] : Array(0...7)
    }

    /// 将任意木琴条索引吸附到最近的允许索引
    public static func nearestAllowedIndex(_ rawIndex: Int, pentatonicSafe: Bool) -> Int {
        let allowed = allowedIndices(pentatonicSafe: pentatonicSafe)
        return allowed.min(by: { abs($0 - rawIndex) < abs($1 - rawIndex) }) ?? 0
    }
}

/// 敲完节奏后的「4 张旋律山坡快选卡」：
/// 不让零基础用户面对平直空白画布一个个盲猜，而是先像挑滤镜一样选一座最接近脑海轮廓的「山」，再微调 1～2 颗珠子即可！
public enum MelodyHillTemplate: String, CaseIterable, Identifiable, Sendable {
    case climb      // 爬坡扬起
    case arch       // 拱桥起伏
    case gentleFall // 温柔下坡
    case wave       // 轻快波浪

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .climb: return "向上爬"
        case .arch: return "先升后降"
        case .gentleFall: return "缓缓下降"
        case .wave: return "波浪起伏"
        }
    }

    public var shortLabel: String {
        switch self {
        case .climb: return "爬坡"
        case .arch: return "拱桥"
        case .gentleFall: return "下坡"
        case .wave: return "波浪"
        }
    }

    /// 用于卡片上绘制迷你山形预览的 6 个归一化高度点（0...1）
    public var previewProfile: [Double] {
        switch self {
        case .climb: return [0.10, 0.28, 0.45, 0.62, 0.85, 0.72]
        case .arch: return [0.15, 0.48, 0.88, 0.72, 0.40, 0.12]
        case .gentleFall: return [0.92, 0.78, 0.62, 0.46, 0.28, 0.10]
        case .wave: return [0.22, 0.65, 0.35, 0.82, 0.48, 0.18]
        }
    }
}

/// 「验光师 3 选 1 亮灯找音」推荐项：每次只点亮最合理的 3 根木琴条，彻底告别 8 选 1 盲试。
public struct SmartPitchHint: Identifiable, Equatable, Sendable {
    public let laneIndex: Int
    public let badge: String
    public let reason: String

    public var id: Int { laneIndex }

    public init(laneIndex: Int, badge: String, reason: String) {
        self.laneIndex = laneIndex
        self.badge = badge
        self.reason = reason
    }
}

/// 木琴敲画板核心算法引擎（100% 纯函数、离线、可单测）
public enum XylophoneRollEngine {

    /// 1. 把 4 种经典山坡轮廓套用到用户已敲好的节奏拍子上（完整保留每一拍的原始节奏时长！）
    public static func applyHill(
        _ template: MelodyHillTemplate,
        to beads: [NoteBead],
        pentatonicSafe: Bool
    ) -> [NoteBead] {
        guard !beads.isEmpty else { return [] }
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: pentatonicSafe)
        let n = beads.count

        return beads.enumerated().map { idx, bead in
            let t = n <= 1 ? 0.5 : Double(idx) / Double(n - 1)
            let norm: Double
            switch template {
            case .climb:
                // 从稳重底音逐步爬高，最后稍微回稳呼吸
                norm = idx == n - 1 && n >= 4 ? 0.72 : (0.08 + t * 0.88)
            case .arch:
                // 经典起承转合拱桥：中段高起、结尾稳稳归家
                norm = idx == n - 1 && n >= 3 ? 0.0 : (0.12 + sin(t * Double.pi) * 0.84)
            case .gentleFall:
                // 高处起唱、像叹息般温柔落回 1·陶诺
                norm = max(0.0, 0.94 - t * 0.94)
            case .wave:
                // 轻快起伏波浪，尾音柔和收拢
                if idx == n - 1 && n >= 3 {
                    norm = 0.0
                } else {
                    norm = 0.45 + 0.38 * sin(t * Double.pi * 2.15 + 0.3)
                }
            }

            let pickPos = max(0, min(allowed.count - 1, Int((norm * Double(allowed.count - 1)).rounded())))
            let lane = XylophoneLane.lane(at: allowed[pickPos])
            var updated = bead
            updated.degree = lane.degree
            updated.octaveOffset = lane.octaveOffset
            updated.ghostCandidates.removeAll()
            return updated
        }
    }

    /// 2. 「只听高低趋势、不管跑调」的相对轮廓映射：
    /// 把哼唱提取出的每拍相对高低（0.0...1.0）贴合到已敲好的节奏柱上，完全不要求用户唱准绝对音高！
    public static func applyRelativeContour(
        to beads: [NoteBead],
        normalizedHeights: [Double],
        pentatonicSafe: Bool
    ) -> [NoteBead] {
        guard !beads.isEmpty else { return [] }
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: pentatonicSafe)
        guard !allowed.isEmpty else { return beads }

        return beads.enumerated().map { idx, bead in
            let rawH: Double
            if normalizedHeights.isEmpty {
                rawH = 0.35
            } else if idx < normalizedHeights.count {
                rawH = normalizedHeights[idx]
            } else {
                rawH = normalizedHeights.last ?? 0.35
            }
            let clampedH = max(0.0, min(1.0, rawH))
            let pos = max(0, min(allowed.count - 1, Int((clampedH * Double(allowed.count - 1)).rounded())))
            let lane = XylophoneLane.lane(at: allowed[pos])
            var updated = bead
            updated.degree = lane.degree
            updated.octaveOffset = lane.octaveOffset
            updated.ghostCandidates.removeAll()
            return updated
        }
    }

    /// 3. 「验光师 3 选 1 亮灯找音」：
    /// 根据前一颗音的阶梯位置与当前拍在整句中的位置，点亮最合理的 3 根木琴条，帮不懂音阶的人快速锁定脑海里的音！
    public static func suggestThreeLanes(
        forBeatIndex index: Int,
        in beads: [NoteBead],
        pentatonicSafe: Bool
    ) -> [SmartPitchHint] {
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: pentatonicSafe)
        guard !allowed.isEmpty else { return [] }

        // 情况 A：第一拍
        if index <= 0 || beads.isEmpty {
            return [
                SmartPitchHint(laneIndex: 0, badge: "稳起", reason: "从低音 1 开始"),
                SmartPitchHint(laneIndex: 2, badge: "柔和", reason: "从中间音 3 开始"),
                SmartPitchHint(laneIndex: 4, badge: "亮起", reason: "从明亮的 5 开始")
            ]
        }

        // 情况 B：最后一拍
        if index >= beads.count - 1 && beads.count >= 3 {
            return [
                SmartPitchHint(laneIndex: 0, badge: "收尾", reason: "落回 1 结尾"),
                SmartPitchHint(laneIndex: 2, badge: "轻停", reason: "轻停在 3"),
                SmartPitchHint(laneIndex: 4, badge: "留白", reason: "停在 5 留白")
            ]
        }

        // 情况 C：句中任意拍
        let prevBead = beads[max(0, min(beads.count - 1, index - 1))]
        let prevLane = XylophoneLane.nearestAllowedIndex(
            XylophoneLane.laneIndex(degree: prevBead.degree, octaveOffset: prevBead.octaveOffset),
            pentatonicSafe: pentatonicSafe
        )
        let prevPos = allowed.firstIndex(of: prevLane) ?? 0

        var hints: [SmartPitchHint] = []
        var used: Set<Int> = []

        // 1) 往上走一步
        if prevPos + 1 < allowed.count {
            let up = allowed[prevPos + 1]
            hints.append(SmartPitchHint(laneIndex: up, badge: "高一", reason: "比上一拍高一格"))
            used.insert(up)
        }
        // 2) 往下走一步
        if prevPos - 1 >= 0 {
            let down = allowed[prevPos - 1]
            hints.append(SmartPitchHint(laneIndex: down, badge: "低一", reason: "比上一拍低一格"))
            used.insert(down)
        }
        // 3) 跨步或稳住同音
        if prevPos + 2 < allowed.count && hints.count < 3 {
            let leap = allowed[prevPos + 2]
            if !used.contains(leap) {
                hints.append(SmartPitchHint(laneIndex: leap, badge: "跳高", reason: "向上跨高一点"))
                used.insert(leap)
            }
        }
        if hints.count < 3 && !used.contains(prevLane) {
            hints.append(SmartPitchHint(laneIndex: prevLane, badge: "同高", reason: "和上一拍同高"))
            used.insert(prevLane)
        }
        if hints.count < 3 && !used.contains(0) {
            hints.append(SmartPitchHint(laneIndex: 0, badge: "落回", reason: "落回 1 稳住"))
            used.insert(0)
        }

        return Array(hints.prefix(3))
    }

    /// 4. 计算相邻两颗音珠之间的直觉台阶标签（如 `+2↗`、`-1↘`、`=`），让零基础一眼看懂起伏方向
    public static func stepDeltaLabel(from previous: NoteBead, to current: NoteBead) -> String {
        let a = XylophoneLane.laneIndex(degree: previous.degree, octaveOffset: previous.octaveOffset)
        let b = XylophoneLane.laneIndex(degree: current.degree, octaveOffset: current.octaveOffset)
        let diff = b - a
        if diff == 0 { return "=" }
        if diff > 0 { return "+\(diff)↗" }
        return "\(diff)↘"
    }

    /// 5. 检测一首乐曲是否使用了 4 或 7（用于自动决定打开还是关闭「安心5音」护网）
    public static func requiresSevenScale(_ document: MelodyDocument) -> Bool {
        document.notes.contains { $0.degree == 4 || $0.degree == 7 }
    }
}
