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
        case .I: return "稳定"
        case .ii: return "过渡"
        case .iii: return "微亮"
        case .IV: return "开阔"
        case .V: return "推高"
        case .vi: return "柔和"
        }
    }

    public var shortMoodGlyph: String {
        switch self {
        case .I: return "稳定"
        case .ii: return "过渡"
        case .iii: return "微亮"
        case .IV: return "开阔"
        case .V: return "推高"
        case .vi: return "柔和"
        }
    }

    public func colorHex(isNight: Bool) -> UInt32 {
        switch self {
        case .I: return isNight ? 0xFF7582 : 0xC93848
        case .ii: return isNight ? 0xFFA959 : 0xB8560A
        case .iii: return isNight ? 0xFF74A6 : 0xBE2E66
        case .IV: return isNight ? 0x38E4B7 : 0x0E7E5D
        case .V: return isNight ? 0x5CB3FF : 0x1B6EC2
        case .vi: return isNight ? 0xA98BFF : 0x6941D6
        }
    }

    public func color(isNight: Bool) -> Color {
        Color(hex: colorHex(isNight: isNight))
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
        case .swanRipple: return "流动琶音"
        case .feltWaltz: return "三拍圆舞"
        case .summerGlass: return "清透和弦"
        case .pureChorale: return "柔和长音"
        }
    }

    public var subtitle: String {
        switch self {
        case .swanRipple: return "柔和流动的分解和弦"
        case .feltWaltz: return "轻快摇曳的三拍子伴奏"
        case .summerGlass: return "干净通透的柔和伴奏"
        case .pureChorale: return "平稳托底的三和弦长音"
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
        self.timeFraction = timeFraction.isFinite ? max(0.0, min(1.0, timeFraction)) : 0.0
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
                headline: "空白画布",
                detail: "直接点画面或下方彩条加音，也可以用写旋律功能录音或敲节奏。",
                tryNextTip: "先点几下 1、3、5 听听基础音的和谐感。",
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

        // 2. 找出最大音程跳跃与半音次数
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

        // 3. 尾音收束解读
        let last = notes.last!
        let endingDesc: String
        let tip: String
        switch last.degree {
        case 1:
            endingDesc = "收在 1 (Do)，听起来平稳完整。"
            tip = "点一下外圈色环，可以换不同的和弦风格。"
        case 6:
            endingDesc = "停在 6 (La)，有一点淡淡的回味感。"
            tip = "把最后一颗音拉到 1 (Do)，对比两种结尾的感觉。"
        case 5:
            endingDesc = "停在 5 (Sol)，像把句子留了一点悬念。"
            tip = "在结尾补一个 1 (Do)，整句会立刻安定下来。"
        case 7:
            endingDesc = "停在 7 (Si)，差半步就能落回高音 1。"
            tip = "把最后的 7 往上推到高音 1，听听释放的感觉。"
        case 4:
            endingDesc = "停在 4 (Fa)，带一点轻轻落下的倾向。"
            tip = "后面接一颗 3 (Mi) 会很自然。"
        default:
            endingDesc = "停在第 \(last.degree) 音，留着轻松的延续感。"
            tip = "拖动任意音珠，就能实时调整高低和拍子。"
        }

        var tags: [String] = [document.scaleMode.label]
        if maxSemi >= 5 { tags.append("大跨度 \(maxJumpText)") }
        if semitoneSteps > 0 { tags.append("含 \(semitoneSteps) 处半音") }
        if !spans.isEmpty { tags.append("协和音 \(Int((ratio * 100).rounded()))%") }

        let headline: String
        if let customInsight = document.composerInsight, document.isSpecimen {
            headline = customInsight
        } else if maxSemi >= 5 {
            headline = "起伏丰富的旋律线条（\(maxJumpText)），\(endingDesc)"
        } else {
            headline = "流畅自然的旋律线条，\(endingDesc)"
        }

        let detail = spans.isEmpty
            ? "当前仅播放单旋律；在声音设置里开启伴奏即可加上和弦衬托。"
            : "共有 \(inChordCount)/\(notes.count) 个音落在伴奏和弦内，其余音带来色彩变化。"

        return MelodyTheoryInsight(
            headline: headline,
            detail: detail,
            tryNextTip: tip,
            inChordRatio: ratio,
            highlightedTags: tags
        )
    }
}
