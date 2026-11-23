import Foundation
import SwiftUI

/// 五色天光调式光谱（严格遵循五度圈明暗顺序，每相邻两片天空只挪动 1 只咩哞半步！）：
/// 云端失重 (#4) -> 晴空晨光 (标准大调) -> 落日余晖 (b7) -> 森林晨雾 (b3 #6 b7) -> 暮色夜曲 (自然小调 b3 b6 b7)
public enum ScaleMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case cloudLydian      // 云端失重（Lydian: #4 梦境悬浮）
    case brightMajor      // 晴空晨光（Ionian: 标准大调）
    case goldenMixolydian // 落日余晖（Mixolydian: b7 暖橘公路电影）
    case forestDorian     // 森林晨雾（Dorian: b3 #6 微雨透阳光）
    case wistfulMinor     // 暮色夜曲（Aeolian: 自然小调）

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .cloudLydian: return "梦幻"
        case .brightMajor: return "明亮"
        case .goldenMixolydian: return "温暖"
        case .forestDorian: return "清新"
        case .wistfulMinor: return "忧郁"
        }
    }

    public var shortSkyLabel: String {
        switch self {
        case .cloudLydian: return "梦幻"
        case .brightMajor: return "明亮"
        case .goldenMixolydian: return "温暖"
        case .forestDorian: return "清新"
        case .wistfulMinor: return "忧郁"
        }
    }

    public var iconName: String {
        switch self {
        case .cloudLydian: return "sparkles"
        case .brightMajor: return "sun.max.fill"
        case .goldenMixolydian: return "sunset.fill"
        case .forestDorian: return "leaf.fill"
        case .wistfulMinor: return "cloud.rain.fill"
        }
    }

    /// 专业乐理原名（仅在「音乐家母语镜」或顿悟卡片里轻柔揭晓）
    public var theoryName: String {
        switch self {
        case .cloudLydian: return "Lydian 利底亚 (#4)"
        case .brightMajor: return "Major 自然大调"
        case .goldenMixolydian: return "Mixolydian 混合利底亚 (b7)"
        case .forestDorian: return "Dorian 多利亚 (b3 还原6)"
        case .wistfulMinor: return "Minor 自然小调 (b3 b6 b7)"
        }
    }

    /// 一句话说明当前调式的情绪特点
    public var skyPhilosophy: String {
        switch self {
        case .cloudLydian: return "轻盈漂浮，带一点梦幻感"
        case .brightMajor: return "开朗明快，最常见的大调"
        case .goldenMixolydian: return "松弛暖和，像傍晚散步"
        case .forestDorian: return "微淡忧郁里透着一点亮色"
        case .wistfulMinor: return "深沉抒情，经典小调"
        }
    }

    public var isMinorFlavored: Bool {
        self == .forestDorian || self == .wistfulMinor
    }

    /// 相对主音 Do = 0 的 7 阶半音偏移
    public var semitoneOffsets: [Int] {
        switch self {
        case .cloudLydian:      return [0, 2, 4, 6, 7, 9, 11]
        case .brightMajor:      return [0, 2, 4, 5, 7, 9, 11]
        case .goldenMixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .forestDorian:     return [0, 2, 3, 5, 7, 9, 10]
        case .wistfulMinor:     return [0, 2, 3, 5, 7, 8, 10]
        }
    }

    /// 与相邻天光对应的极光天色（让画布背景随五色天光呼吸流转）
    public func skyAuroraColor(isNight: Bool) -> Color {
        switch self {
        case .cloudLydian:      return isNight ? Color(hex: 0x74C0FC) : Color(hex: 0x4DABF7)
        case .brightMajor:      return isNight ? Color(hex: 0x38E4C0) : Color(hex: 0x12B886)
        case .goldenMixolydian: return isNight ? Color(hex: 0xFFA94D) : Color(hex: 0xF76707)
        case .forestDorian:     return isNight ? Color(hex: 0x63E6BE) : Color(hex: 0x0CA678)
        case .wistfulMinor:     return isNight ? Color(hex: 0x9775FA) : Color(hex: 0x7048E8)
        }
    }

    public func midiNote(rootMIDI: Int, degree: Int, octaveOffset: Int = 0) -> Int {
        let idx = max(0, min(6, degree - 1))
        return rootMIDI + semitoneOffsets[idx] + octaveOffset * 12
    }

    public func frequencyHz(rootMIDI: Int, degree: Int, octaveOffset: Int = 0) -> Double {
        let midi = Double(midiNote(rootMIDI: rootMIDI, degree: degree, octaveOffset: octaveOffset))
        return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }
}

/// 主旋律乐器声色（让圣桑《天鹅》拥有真实大提琴歌唱感、李斯特拥有音乐厅毛毡钢琴、钟声拥有星光钢片琴）
public enum MelodyVoice: String, CaseIterable, Codable, Sendable, Identifiable {
    case singingCello  // 歌唱大提琴（带温柔揉弦与弓弦起音）
    case concertPiano  // 音乐厅毛毡钢琴（温润双弦立体声）
    case liquidHarp    // 湖面竖琴（清澈拨弦泛音）
    case celestaGlass  // 星光钢片琴（剔透八音盒钟琴）

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .singingCello: return "大提琴"
        case .concertPiano: return "钢琴"
        case .liquidHarp: return "竖琴"
        case .celestaGlass: return "八音盒"
        }
    }

    public var iconName: String {
        switch self {
        case .singingCello: return "music.mic"
        case .concertPiano: return "pianokeys"
        case .liquidHarp: return "water.waves"
        case .celestaGlass: return "sparkles"
        }
    }
}

/// 三层无障碍认知翻译透镜（同一张画布自由切换感知语言，永不拿术语筑墙）：
/// 1. 诗意直觉镜（纯情绪与光影，零数字零术语）
/// 2. 逻辑哲学镜（实时利萨如波纹对称花 + 种子折纸架构 + 延留张力丝 + 掌心触觉）
/// 3. 音乐家母语镜（真实半音窄缝 + Do-Ti 唱名 + 音程弧标 + 和弦内/外音标注）
public enum CognitiveLens: String, CaseIterable, Codable, Sendable, Identifiable {
    case poetic     // 诗意直觉
    case philosophy // 逻辑哲学
    case musician   // 音乐母语

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .poetic: return "诗意直觉"
        case .philosophy: return "逻辑哲学"
        case .musician: return "音乐母语"
        }
    }

    public var shortLabel: String {
        switch self {
        case .poetic: return "诗意"
        case .philosophy: return "哲学"
        case .musician: return "乐理"
        }
    }

    public var iconName: String {
        switch self {
        case .poetic: return "leaf.fill"
        case .philosophy: return "atom"
        case .musician: return "music.note"
        }
    }
}

public struct ChordVoicing: Sendable, Equatable {
    public let label: String
    public let bassDegree: Int
    public let bassOctave: Int
    public let upperDegrees: [Int]
    public let isHighTension: Bool

    public init(label: String, bassDegree: Int, bassOctave: Int = -1, upperDegrees: [Int], isHighTension: Bool = false) {
        self.label = label
        self.bassDegree = bassDegree
        self.bassOctave = bassOctave
        self.upperDegrees = upperDegrees
        self.isHighTension = isHighTension
    }
}

/// 三种现代开放声部排列的水面托底和声
public enum HarmonyProfile: String, CaseIterable, Codable, Sendable, Identifiable {
    case feltSun    // 毛毡暖阳：add9 / maj7
    case clearWater // 透明水波：sus2 / 四度悬浮
    case filmGlow   // 电影微光：6 级微酸 / 斜杠低音

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .feltSun: return "毛毡暖阳"
        case .clearWater: return "透明水波"
        case .filmGlow: return "电影微光"
        }
    }

    public var subtitle: String {
        switch self {
        case .feltSun: return "温暖明亮的 add9 与大七开放排列"
        case .clearWater: return "清澈的 sus2 与四度悬浮织体"
        case .filmGlow: return "带微酸 6 级与斜杠贝斯的银幕情绪"
        }
    }

    public func voicing(for degree: Int) -> ChordVoicing {
        let d = max(1, min(7, degree))
        switch self {
        case .feltSun:
            switch d {
            case 1: return ChordVoicing(label: "归家暖阳 · I add9", bassDegree: 1, upperDegrees: [5, 2, 3])
            case 2: return ChordVoicing(label: "轻步前行 · ii9", bassDegree: 2, upperDegrees: [6, 3, 4])
            case 3: return ChordVoicing(label: "暖光过渡 · iii7", bassDegree: 3, upperDegrees: [5, 7, 2])
            case 4: return ChordVoicing(label: "宽阔悬浮 · IV maj7", bassDegree: 4, upperDegrees: [1, 3, 6])
            case 5: return ChordVoicing(label: "遥望晴空 · V add9", bassDegree: 5, upperDegrees: [2, 6, 7])
            case 6: return ChordVoicing(label: "温柔余韵 · vi7", bassDegree: 6, upperDegrees: [3, 5, 1])
            default: return ChordVoicing(label: "导音紧绷 · V7/7", bassDegree: 5, upperDegrees: [7, 2, 4], isHighTension: true)
            }
        case .clearWater:
            switch d {
            case 1: return ChordVoicing(label: "静水倒影 · I sus2", bassDegree: 1, upperDegrees: [5, 2, 5])
            case 2: return ChordVoicing(label: "清浅涟漪 · ii7 sus4", bassDegree: 2, upperDegrees: [5, 1, 6])
            case 3: return ChordVoicing(label: "微风斜影 · I/3", bassDegree: 3, upperDegrees: [5, 1, 2])
            case 4: return ChordVoicing(label: "夏风四度 · IV maj9", bassDegree: 4, upperDegrees: [1, 5, 3])
            case 5: return ChordVoicing(label: "云端悬停 · V sus4", bassDegree: 5, upperDegrees: [1, 4, 2], isHighTension: true)
            case 6: return ChordVoicing(label: "透明怀旧 · vi9", bassDegree: 6, upperDegrees: [3, 7, 2])
            default: return ChordVoicing(label: "水波收束 · V/7", bassDegree: 7, upperDegrees: [5, 2, 4], isHighTension: true)
            }
        case .filmGlow:
            switch d {
            case 1: return ChordVoicing(label: "余温归处 · I maj7", bassDegree: 1, upperDegrees: [5, 7, 3])
            case 2: return ChordVoicing(label: "街灯斜影 · V/2", bassDegree: 2, upperDegrees: [5, 7, 4])
            case 3: return ChordVoicing(label: "银幕微酸 · iii7", bassDegree: 3, upperDegrees: [7, 2, 5])
            case 4: return ChordVoicing(label: "慢行托举 · IV add9", bassDegree: 4, upperDegrees: [1, 5, 6])
            case 5: return ChordVoicing(label: "回望转折 · V/7", bassDegree: 7, upperDegrees: [5, 2, 3], isHighTension: true)
            case 6: return ChordVoicing(label: "深夜独白 · vi11", bassDegree: 6, upperDegrees: [3, 5, 2])
            default: return ChordVoicing(label: "悬崖欲落 · vii°/5", bassDegree: 5, upperDegrees: [7, 4, 6], isHighTension: true)
            }
        }
    }
}

public struct GhostCandidate: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let degree: Int
    public let octaveOffset: Int

    public init(id: UUID = UUID(), degree: Int, octaveOffset: Int) {
        self.id = id
        self.degree = degree
        self.octaveOffset = octaveOffset
    }
}

/// 单颗纸上陶珠。严格保留原始自由呼吸时间轴（rawOnset/rawDuration），并支持记录分形生长角色（起·承·转·合 / 延留迟到）。
public struct NoteBead: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var degree: Int
    public var octaveOffset: Int
    public var rawOnset: Double
    public var rawDuration: Double
    public var quantizedOnset: Double?
    public var quantizedDuration: Double?
    public var confidence: Double
    public var ghostCandidates: [GhostCandidate]
    public var phraseTag: String?

    public init(
        id: UUID = UUID(),
        degree: Int,
        octaveOffset: Int = 0,
        rawOnset: Double,
        rawDuration: Double,
        quantizedOnset: Double? = nil,
        quantizedDuration: Double? = nil,
        confidence: Double = 1.0,
        ghostCandidates: [GhostCandidate] = [],
        phraseTag: String? = nil
    ) {
        self.id = id
        self.degree = max(1, min(7, degree))
        self.octaveOffset = max(-1, min(1, octaveOffset))
        self.rawOnset = max(0, rawOnset)
        self.rawDuration = max(0.08, rawDuration)
        self.quantizedOnset = quantizedOnset
        self.quantizedDuration = quantizedDuration
        self.confidence = confidence
        self.ghostCandidates = ghostCandidates
        self.phraseTag = phraseTag
    }

    public var member: ChimmoMember { ChimmoMember.from(degree: degree) }

    public func displayOnset(grooveStrength: Double) -> Double {
        guard let q = quantizedOnset else { return rawOnset }
        let t = max(0, min(1, grooveStrength))
        return rawOnset + (q - rawOnset) * t
    }

    public func displayDuration(grooveStrength: Double) -> Double {
        guard let q = quantizedDuration else { return rawDuration }
        let t = max(0, min(1, grooveStrength))
        return max(0.08, rawDuration + (q - rawDuration) * t)
    }
}

/// 每次音珠发声时在画布与声盘上激起的物理涟漪与飞珠轨迹。
public struct VisualImpulse: Identifiable, Sendable {
    public let id: UUID
    public let birth: TimeInterval
    public let degree: Int
    public let octaveOffset: Int
    public let xNorm: Double

    public init(
        id: UUID = UUID(),
        birth: TimeInterval = Date().timeIntervalSinceReferenceDate,
        degree: Int,
        octaveOffset: Int = 0,
        xNorm: Double
    ) {
        self.id = id
        self.birth = birth
        self.degree = degree
        self.octaveOffset = octaveOffset
        self.xNorm = max(0.05, min(0.95, xNorm))
    }
}

public struct MelodyDocument: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    public var rootMIDI: Int
    public var scaleMode: ScaleMode
    public var harmonyProfile: HarmonyProfile
    public var grooveStrength: Double
    public var estimatedBPM: Double
    public var notes: [NoteBead]
    public var isSpecimen: Bool
    public var specimenCategory: String?
    public var composerInsight: String?
    public var preferredTexture: AccompanimentTexture?
    public var preferredVoice: MelodyVoice?
    public var guidedMoments: [GuidedStoryMoment]?

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        rootMIDI: Int = 60,
        scaleMode: ScaleMode = .brightMajor,
        harmonyProfile: HarmonyProfile = .feltSun,
        grooveStrength: Double = 0.0,
        estimatedBPM: Double = 92.0,
        notes: [NoteBead] = [],
        isSpecimen: Bool = false,
        specimenCategory: String? = nil,
        composerInsight: String? = nil,
        preferredTexture: AccompanimentTexture? = nil,
        preferredVoice: MelodyVoice? = nil,
        guidedMoments: [GuidedStoryMoment]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.rootMIDI = rootMIDI
        self.scaleMode = scaleMode
        self.harmonyProfile = harmonyProfile
        self.grooveStrength = grooveStrength
        self.estimatedBPM = estimatedBPM
        self.notes = notes
        self.isSpecimen = isSpecimen
        self.specimenCategory = specimenCategory
        self.composerInsight = composerInsight
        self.preferredTexture = preferredTexture
        self.preferredVoice = preferredVoice
        self.guidedMoments = guidedMoments
    }

    public var totalDuration: Double {
        let lastEnd = notes.map { $0.displayOnset(grooveStrength: grooveStrength) + $0.displayDuration(grooveStrength: grooveStrength) }.max() ?? 0
        return max(2.0, lastEnd + 0.5)
    }

    public func activeGuidedMoment(at time: Double?) -> GuidedStoryMoment? {
        guard let moments = guidedMoments, !moments.isEmpty else { return nil }
        guard let t = time else { return moments.first }
        let frac = max(0, min(1, t / max(1.0, totalDuration)))
        return moments.last(where: { $0.timeFraction <= frac + 0.02 }) ?? moments.first
    }
}
