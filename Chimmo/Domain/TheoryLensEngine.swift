import SwiftUI

/// 真实的半音音高几何映射：让 3-4 与 7-1↑ 的「半音窄缝」肉眼可见，切换大/小调时 3/6/7 级真实下移半音。
public enum ScalePitchGeometry {
    /// 相对主音 1 Do 的真实半音位置（支持 -1, 0, +1 八度）
    public static func semitoneOffset(degree: Int, octaveOffset: Int, mode: ScaleMode) -> Int {
        let clampedDeg = max(1, min(7, degree))
        let base = mode.semitoneOffsets[clampedDeg - 1]
        return base + octaveOffset * 12
    }

    /// 归一化到 [0, 1]（0 = 底部低音界，1 = 顶部高音界），默认显示区间为 [-5, 14] 共 19 个半音，
    /// 完整包容低音 5↓/6↓/7↓（如《爱之梦》《天鹅湖》《肖邦夜曲》）到高音 1↑/2↑。
    public static func normalizedY(semitone: Int, minSemitone: Int = -5, maxSemitone: Int = 14) -> CGFloat {
        let span = CGFloat(max(1, maxSemitone - minSemitone))
        let clamped = CGFloat(max(minSemitone, min(maxSemitone, semitone)))
        return (clamped - CGFloat(minSemitone)) / span
    }

    public static func normalizedY(degree: Int, octaveOffset: Int, mode: ScaleMode) -> CGFloat {
        let semi = semitoneOffset(degree: degree, octaveOffset: octaveOffset, mode: mode)
        return normalizedY(semitone: semi)
    }

    /// 根据画布 Y 坐标反推最接近的调内 (degree, octaveOffset)
    public static func nearestDegreeAndOctave(
        normalizedFromBottom: CGFloat,
        mode: ScaleMode,
        minSemitone: Int = -5,
        maxSemitone: Int = 14
    ) -> (degree: Int, octaveOffset: Int) {
        let targetSemi = Double(minSemitone) + Double(max(0, min(1, normalizedFromBottom))) * Double(maxSemitone - minSemitone)
        var bestDeg = 1
        var bestOct = 0
        var bestDist = Double.greatestFiniteMagnitude

        for oct in -1...1 {
            for deg in 1...7 {
                let s = Double(semitoneOffset(degree: deg, octaveOffset: oct, mode: mode))
                if s < Double(minSemitone) - 0.5 || s > Double(maxSemitone) + 0.5 { continue }
                let dist = abs(s - targetSemi)
                if dist < bestDist {
                    bestDist = dist
                    bestDeg = deg
                    bestOct = oct
                }
            }
        }
        return (bestDeg, bestOct)
    }

    /// 两个相邻音之间的真实半音数与零基础友好的中文音程名
    public static func intervalDescription(from a: NoteBead, to b: NoteBead, mode: ScaleMode) -> (semitones: Int, shortLabel: String) {
        let sa = semitoneOffset(degree: a.degree, octaveOffset: a.octaveOffset, mode: mode)
        let sb = semitoneOffset(degree: b.degree, octaveOffset: b.octaveOffset, mode: mode)
        let diff = abs(sb - sa)
        let label: String
        switch diff {
        case 0: label = "同音"
        case 1: label = "半音"
        case 2: label = "全音"
        case 3: label = "小三度"
        case 4: label = "大三度"
        case 5: label = "纯四度"
        case 6: label = "增四度"
        case 7: label = "纯五度"
        case 8, 9: label = "六度"
        case 10, 11: label = "七度"
        case 12: label = "八度"
        default: label = "大跨度"
        }
        return (diff, label)
    }
}

/// 真实可透视的调内基础和弦（用于照亮画布上对应的 3 条音高泳道光带）
public enum DiatonicChord: String, CaseIterable, Codable, Sendable, Identifiable {
    case I
    case ii
    case iii
    case IV
    case V
    case vi

    public var id: String { rawValue }

    /// 罗马级数标记
    public var roman: String { rawValue }

    /// 和弦根音音级
    public var rootDegree: Int {
        switch self {
        case .I: return 1
        case .ii: return 2
        case .iii: return 3
        case .IV: return 4
        case .V: return 5
        case .vi: return 6
        }
    }

    /// 构成该三和弦的 3 个调内音级（会在画布上亮起对应的 3 条和弦泳道光带！）
    public var chordToneDegrees: [Int] {
        switch self {
        case .I: return [1, 3, 5]
        case .ii: return [2, 4, 6]
        case .iii: return [3, 5, 7]
        case .IV: return [4, 6, 1]
        case .V: return [5, 7, 2]
        case .vi: return [6, 1, 3]
        }
    }

    public var tonesFormula: String {
        chordToneDegrees.map(String.init).joined(separator: "·")
    }

    public var moodTitle: String {
        switch self {
        case .I: return "归家稳定"
        case .ii: return "轻步过渡"
        case .iii: return "温柔微光"
        case .IV: return "宽阔托举"
        case .V: return "张力推力"
        case .vi: return "怀旧微酸"
        }
    }

    public var shortMoodGlyph: String {
        switch self {
        case .I: return "归家"
        case .ii: return "漫步"
        case .iii: return "微光"
        case .IV: return "托举"
        case .V: return "推力"
        case .vi: return "怀旧"
        }
    }

    public func color(isNight: Bool) -> Color {
        switch self {
        case .I: return isNight ? Color(hex: 0xFF7582) : Color(hex: 0xF25563)
        case .ii: return isNight ? Color(hex: 0xFFA959) : Color(hex: 0xF7882F)
        case .iii: return isNight ? Color(hex: 0xFF74A6) : Color(hex: 0xE64980)
        case .IV: return isNight ? Color(hex: 0x38E4B7) : Color(hex: 0x12B886)
        case .V: return isNight ? Color(hex: 0x5CB3FF) : Color(hex: 0x228BE6)
        case .vi: return isNight ? Color(hex: 0xA98BFF) : Color(hex: 0x7950F2)
        }
    }

    public func nextChord() -> DiatonicChord {
        let all = DiatonicChord.allCases
        guard let idx = all.firstIndex(of: self) else { return .I }
        return all[(idx + 1) % all.count]
    }
}

/// 真实大师左手伴奏织体（Texture）：同一套和弦，不同弹法就能瞬间听出圣桑水波、肖邦圆舞或东亚夏日治愈感！
public enum AccompanimentTexture: String, CaseIterable, Codable, Sendable, Identifiable {
    case swanRipple   // 天鹅水波：圣桑式细腻上下流动分解琶音
    case feltWaltz    // 圆舞呼吸：三拍子低音落地 + 轻盈双和弦托举（李斯特/肖邦/萨蒂）
    case summerGlass  // 夏日清风：开放九度透明钢琴 + 钢片琴高音星光泛音
    case pureChorale  // 柔和长音：清澈稳定三和弦长音，最适合零基础听辨和弦内音

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .swanRipple: return "天鹅水波"
        case .feltWaltz: return "圆舞呼吸"
        case .summerGlass: return "夏日清风"
        case .pureChorale: return "柔和长音"
        }
    }

    public var subtitle: String {
        switch self {
        case .swanRipple: return "圣桑式流淌的波浪分解琶音，像湖面划过羽翼"
        case .feltWaltz: return "低音轻落 + 轻盈摇曳的三拍子浪漫呼吸"
        case .summerGlass: return "东亚治愈电影般的透明九和弦 + 八音盒泛音"
        case .pureChorale: return "最纯净的三音叠加，清晰听出每个和弦骨架"
        }
    }

    public var iconName: String {
        switch self {
        case .swanRipple: return "water.waves"
        case .feltWaltz: return "wind"
        case .summerGlass: return "sparkles"
        case .pureChorale: return "circle.grid.3x3.fill"
        }
    }
}

/// 播放名曲时随进度条实时浮现的「电影字幕级逐句导赏」，让乐盲在听见的瞬间立刻看懂作曲家的巧思。
public struct GuidedStoryMoment: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public let timeFraction: Double // 0.0 ... 1.0
    public let badge: String
    public let caption: String

    public init(id: Int, timeFraction: Double, badge: String, caption: String) {
        self.id = id
        self.timeFraction = max(0, min(1, timeFraction))
        self.badge = badge
        self.caption = caption
    }
}

/// 预设常见现代/经典和弦进行模板（可一键为旋律更换底层光带）
public enum ChordProgressionPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case autoMatch
    case classicPop   // I - V - vi - IV (卡农/黄金流行)
    case summerFloat  // IV - V - iii - vi (日系/现代悬浮)
    case warmStory    // I - vi - IV - V (温暖叙事)
    case off          // 关闭伴奏，纯单音清唱

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .autoMatch: return "智能配和弦"
        case .classicPop: return "黄金 1-5-6-4"
        case .summerFloat: return "夏风 4-5-3-6"
        case .warmStory: return "暖叙 1-6-4-5"
        case .off: return "纯清唱"
        }
    }

    public var sequence: [DiatonicChord] {
        switch self {
        case .autoMatch: return [.I, .IV, .V, .I]
        case .classicPop: return [.I, .V, .vi, .IV]
        case .summerFloat: return [.IV, .V, .iii, .vi]
        case .warmStory: return [.I, .vi, .IV, .V]
        case .off: return []
        }
    }
}

/// 时间轴上的一个和弦光带区间
public struct ChordSpan: Identifiable, Equatable, Sendable {
    public let id: Int
    public let startTime: Double
    public let endTime: Double
    public let chord: DiatonicChord

    public init(id: Int, startTime: Double, endTime: Double, chord: DiatonicChord) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.chord = chord
    }
}

/// 面向零基础的实时乐理解读结果
public struct MelodyTheoryInsight: Equatable, Sendable {
    public let headline: String
    public let detail: String
    public let tryNextTip: String
    public let inChordRatio: Double
    public let highlightedTags: [String]
}

public enum TheoryLensEngine {

    /// 为当前旋律自动划分 4 个视觉清晰的和弦光带区间（支持用户手动覆写任意一拍的和弦）
    public static func buildChordSpans(
        document: MelodyDocument,
        preset: ChordProgressionPreset,
        overrides: [Int: DiatonicChord] = [:]
    ) -> [ChordSpan] {
        guard preset != .off else { return [] }

        let total = max(3.2, document.totalDuration)
        let spanCount = 4
        let step = total / Double(spanCount)
        var spans: [ChordSpan] = []

        for i in 0..<spanCount {
            let s = Double(i) * step
            let e = Double(i + 1) * step
            let chord: DiatonicChord
            if let custom = overrides[i] {
                chord = custom
            } else if preset == .autoMatch {
                chord = inferBestChord(in: document, from: s, to: e, spanIndex: i, totalSpans: spanCount)
            } else {
                let seq = preset.sequence
                chord = seq[i % max(1, seq.count)]
            }
            spans.append(ChordSpan(id: i, startTime: s, endTime: e, chord: chord))
        }
        return spans
    }

    /// 根据区间内的旋律音级自动挑选包含最多旋律音的调内三和弦
    private static func inferBestChord(
        in document: MelodyDocument,
        from start: Double,
        to end: Double,
        spanIndex: Int,
        totalSpans: Int
    ) -> DiatonicChord {
        let notesInSpan = document.notes.filter { bead in
            let t = bead.displayOnset(grooveStrength: document.grooveStrength)
            return t >= start - 0.05 && t < end
        }

        if notesInSpan.isEmpty {
            let fallback: [DiatonicChord] = [.I, .IV, .V, .I]
            return fallback[spanIndex % fallback.count]
        }

        let candidates: [DiatonicChord] = [.I, .IV, .V, .vi, .ii, .iii]
        var bestChord: DiatonicChord = .I
        var bestScore = -1.0

        for cand in candidates {
            var score = 0.0
            for note in notesInSpan {
                if cand.chordToneDegrees.contains(note.degree) {
                    score += 2.0
                    if note.degree == cand.rootDegree {
                        score += 0.6
                    }
                }
            }
            // 结尾小节自然偏爱 I 或 vi 落点
            if spanIndex == totalSpans - 1 && (cand == .I || cand == .vi) {
                score += 0.5
            }
            if score > bestScore {
                bestScore = score
                bestChord = cand
            }
        }
        return bestChord
    }

    /// 查找任意时刻对应的和弦
    public static func chord(at time: Double, in spans: [ChordSpan]) -> DiatonicChord? {
        spans.first(where: { time >= $0.startTime - 0.01 && time < $0.endTime + 0.01 })?.chord
            ?? spans.last?.chord
    }

    /// 对任意旋律（包括用户自己哼唱或点出的旋律）生成零门槛、有启发性的乐理解读
    public static func analyze(document: MelodyDocument, spans: [ChordSpan]) -> MelodyTheoryInsight {
        let notes = document.notes.sorted {
            $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
        }
        guard !notes.isEmpty else {
            return MelodyTheoryInsight(
                headline: "空白音阶画卷已铺开",
                detail: "点左侧的咩哞小偶、直接点画布，或按住「轻哼捉珠」把脑海里的旋律唱出来。",
                tryNextTip: "先点几下左侧的 1·陶诺、3·拍咯、5·壳咯，听听发光泳道里的和谐感！",
                inChordRatio: 1.0,
                highlightedTags: [document.scaleMode.label]
            )
        }

        // 1. 统计和弦内音比例
        var inChordCount = 0
        for bead in notes {
            let t = bead.displayOnset(grooveStrength: document.grooveStrength)
            if let ch = chord(at: t, in: spans), ch.chordToneDegrees.contains(bead.degree) {
                inChordCount += 1
            }
        }
        let ratio = spans.isEmpty ? 1.0 : Double(inChordCount) / Double(notes.count)

        // 2. 找出最大音程跳跃与半音牵引次数
        var maxSemi = 0
        var maxJumpText = ""
        var semitoneSteps = 0
        if notes.count > 1 {
            for i in 0..<(notes.count - 1) {
                let info = ScalePitchGeometry.intervalDescription(from: notes[i], to: notes[i + 1], mode: document.scaleMode)
                if info.semitones == 1 { semitoneSteps += 1 }
                if info.semitones > maxSemi {
                    maxSemi = info.semitones
                    maxJumpText = "\(notes[i].degree)→\(notes[i + 1].degree)（\(info.shortLabel)）"
                }
            }
        }

        // 3. 尾音归宿解读
        let last = notes.last!
        let endingDesc: String
        let tip: String
        switch last.degree {
        case 1:
            endingDesc = "落回 1·陶诺（主音）收尾，像句号一样稳稳回家。"
            tip = "试着点底部和弦卡片，把最后一个和弦换成 vi，听听「伪终止」的电影余韵！"
        case 6:
            endingDesc = "停在 6·钵莫（La）上，带有一丝温柔未完的怀旧微酸。"
            tip = "试着把最后一颗音珠拖到 1·陶诺，对比「怀旧余味」和「完全回家」的区别。"
        case 5:
            endingDesc = "停在 5·壳咯（Sol），像抛向天空的一个问号，期待下一句回应。"
            tip = "在末尾补一颗 1·陶诺，听听问答瞬间闭合的畅快感！"
        case 7:
            endingDesc = "悬在 7·叮尖（导音）上紧绷着，离高音 1 仅差半步！"
            tip = "把最后的 7·叮尖往上轻推半格到高音 1，亲耳感受「导音解决」的释然。"
        case 4:
            endingDesc = "停在 4·呜嘟（Fa），离 3·拍咯只有半音，带着悬浮的微风感。"
            tip = "再加一颗 3·拍咯轻轻落下，这就是影视配乐最常用的「四度叹息」。"
        default:
            endingDesc = "收在 \(last.degree)·\(last.member.chineseName)（\(last.member.roleLabel)），保持着轻轻行走的呼吸。"
            tip = "点击画布底部的和弦光带卡片，试试不同和弦如何改写同一条旋律的情绪！"
        }

        var tags: [String] = [document.scaleMode.label]
        if maxSemi >= 5 { tags.append("亮点大跳 \(maxJumpText)") }
        if semitoneSteps > 0 { tags.append("含 \(semitoneSteps) 处半音牵引") }
        if !spans.isEmpty { tags.append("光带内音 \(Int((ratio * 100).rounded()))%") }

        let headline: String
        if let customInsight = document.composerInsight, document.isSpecimen {
            headline = customInsight
        } else if maxSemi >= 5 {
            headline = "有张力的旋律线条：出现 \(maxJumpText) 跳跃，\(endingDesc)"
        } else {
            headline = "流畅级进的旋律：\(endingDesc)"
        }

        let detail = spans.isEmpty
            ? "当前为纯清唱视图；切回「智能配和弦」即可点亮和弦泳道光带，看清每个音与和声的关系。"
            : "共有 \(inChordCount)/\(notes.count) 颗音珠稳稳落在发光的和弦泳道内（和弦内音），泳道外的音珠则为旋律增添色彩。"

        return MelodyTheoryInsight(
            headline: headline,
            detail: detail,
            tryNextTip: tip,
            inChordRatio: ratio,
            highlightedTags: tags
        )
    }
}
