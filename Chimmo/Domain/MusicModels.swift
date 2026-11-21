import Foundation

public enum ScaleMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case brightMajor
    case wistfulMinor

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .brightMajor: return "晴朗大调"
        case .wistfulMinor: return "微酸小调"
        }
    }

    /// 半音偏移（相对主音 Do = 0）
    public var semitoneOffsets: [Int] {
        switch self {
        case .brightMajor: return [0, 2, 4, 5, 7, 9, 11]
        case .wistfulMinor: return [0, 2, 3, 5, 7, 8, 10]
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

/// 三种现代开放声部排列的水面托底和声（避免老式纯三和弦电子琴土味）。
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

/// 单颗纸上陶珠。严格保留原始自由呼吸时间轴（rawOnset/rawDuration），量化仅作为非破坏性插值层。
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

    public init(
        id: UUID = UUID(),
        degree: Int,
        octaveOffset: Int = 0,
        rawOnset: Double,
        rawDuration: Double,
        quantizedOnset: Double? = nil,
        quantizedDuration: Double? = nil,
        confidence: Double = 1.0,
        ghostCandidates: [GhostCandidate] = []
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
        composerInsight: String? = nil
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
    }

    public var totalDuration: Double {
        let lastEnd = notes.map { $0.displayOnset(grooveStrength: grooveStrength) + $0.displayDuration(grooveStrength: grooveStrength) }.max() ?? 0
        return max(2.0, lastEnd + 0.5)
    }
}
