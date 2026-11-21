import Foundation

/// 声学频率比物理映射：把两个音之间的音程翻译成利萨如波纹整数比、和谐度与自然哲学语言。
public struct HarmonicRatioDescriptor: Equatable, Sendable {
    public let semitones: Int
    public let ratioA: Int
    public let ratioB: Int
    public let ratioText: String
    public let intervalName: String
    public let consonance: Double // 0.0 (强烈摩擦) ... 1.0 (完美静止对称)
    public let poeticEssence: String
    public let isTense: Bool
}

public enum HarmonicRatioPhysics {
    /// 计算任意两个调内音级之间的声学频率比与几何对称特征
    public static func analyze(melodyDegree: Int, rootDegree: Int, mode: ScaleMode) -> HarmonicRatioDescriptor {
        let mSemi = mode.semitoneOffsets[max(0, min(6, melodyDegree - 1))]
        let rSemi = mode.semitoneOffsets[max(0, min(6, rootDegree - 1))]
        var diff = (mSemi - rSemi) % 12
        if diff < 0 { diff += 12 }
        return descriptor(forSemitones: diff)
    }

    /// 供物理实验室连续滑块与工作台实时共鸣花使用的 12 半音完整物理比例表
    public static func descriptor(forSemitones semitones: Int) -> HarmonicRatioDescriptor {
        let s = max(0, min(12, semitones))
        switch s {
        case 0:
            return .init(semitones: 0, ratioA: 1, ratioB: 1, ratioText: "1 : 1", intervalName: "同度合一", consonance: 1.0, poeticEssence: "两道声波完全重合，如镜面般绝对安宁。", isTense: false)
        case 1:
            return .init(semitones: 1, ratioA: 16, ratioB: 15, ratioText: "16 : 15", intervalName: "小二度 · 半音摩擦", consonance: 0.10, poeticEssence: "波形高频推搡产生拍频颤抖——张力渴望迈半步归于静止。", isTense: true)
        case 2:
            return .init(semitones: 2, ratioA: 9, ratioB: 8, ratioText: "9 : 8", intervalName: "大二度 · 轻步微光", consonance: 0.42, poeticEssence: "微微错开的步履，给旋律带出清风般的悬浮感。", isTense: false)
        case 3:
            return .init(semitones: 3, ratioA: 6, ratioB: 5, ratioText: "6 : 5", intervalName: "小三度 · 温柔微酸", consonance: 0.78, poeticEssence: "6 与 5 织出深情对称结，是浪漫夜曲与思念的数学底座。", isTense: false)
        case 4:
            return .init(semitones: 4, ratioA: 5, ratioB: 4, ratioText: "5 : 4", intervalName: "大三度 · 晴空微笑", consonance: 0.85, poeticEssence: "5 与 4 严密闭合为五瓣暖阳花，明朗而温暖。", isTense: false)
        case 5:
            return .init(semitones: 5, ratioA: 4, ratioB: 3, ratioText: "4 : 3", intervalName: "纯四度 · 清风托举", consonance: 0.88, poeticEssence: "开阔通透的四度空间，像托举起一片夏日云海。", isTense: false)
        case 6:
            return .init(semitones: 6, ratioA: 7, ratioB: 5, ratioText: "7 : 5", intervalName: "三全音 · 梦境悬崖", consonance: 0.22, poeticEssence: "把八度正切一半的失重感，充满电影悬念与魔幻微光。", isTense: true)
        case 7:
            return .init(semitones: 7, ratioA: 3, ratioB: 2, ratioText: "3 : 2", intervalName: "纯五度 · 宇宙骨架", consonance: 0.96, poeticEssence: "毕达哥拉斯发现的宇宙第一和谐比例，辽阔、笃定、无瑕。", isTense: false)
        case 8:
            return .init(semitones: 8, ratioA: 8, ratioB: 5, ratioText: "8 : 5", intervalName: "小六度 · 深情仰望", consonance: 0.72, poeticEssence: "浪漫派最催泪的大跨度，像远望星空时的温柔叹息。", isTense: false)
        case 9:
            return .init(semitones: 9, ratioA: 5, ratioB: 3, ratioText: "5 : 3", intervalName: "大六度 · 羽翼舒展", consonance: 0.82, poeticEssence: "李斯特《爱之梦》与肖邦夜曲开篇同款，温暖而辽阔。", isTense: false)
        case 10:
            return .init(semitones: 10, ratioA: 9, ratioB: 5, ratioText: "9 : 5", intervalName: "小七度 · 暮色微醺", consonance: 0.50, poeticEssence: "带一丝暖橘爵士微醺感，比尖锐导音更柔和自在。", isTense: false)
        case 11:
            return .init(semitones: 11, ratioA: 15, ratioB: 8, ratioText: "15 : 8", intervalName: "大七度 · 星光将落", consonance: 0.28, poeticEssence: "离高音八度只差一根发丝的距离，既晶莹又紧绷着想回家。", isTense: true)
        default:
            return .init(semitones: 12, ratioA: 2, ratioB: 1, ratioText: "2 : 1", intervalName: "纯八度 · 完美镜像", consonance: 1.0, poeticEssence: "振速恰好翻倍，波峰严丝合缝，是同一颗灵魂在更高楼层的重逢。", isTense: false)
        }
    }
}

/// 3 音种子分形生长法则（把短短几秒钟的脑放火花，用巴赫与圣桑的几何哲学折出完整乐章）
public enum MotifGrowthOperation: String, CaseIterable, Identifiable, Sendable {
    case climbSequence      // 🌱 爬楼模进（原样搬高一层）
    case waterMirror        // 🪞 水面倒影（上下翻转对称）
    case tearfulSuspension  // 💧 迟到半秒（4→3 延留催泪收束）
    case fullFourPhrasePoem // ✨ 四句成诗（起·承·转·合完整乐章）

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .climbSequence: return "爬楼模进"
        case .waterMirror: return "水面倒影"
        case .tearfulSuspension: return "迟到半秒"
        case .fullFourPhrasePoem: return "四句成诗"
        }
    }

    public var iconName: String {
        switch self {
        case .climbSequence: return "chart.line.uptrend.xyaxis"
        case .waterMirror: return "arrow.up.arrow.down.circle.fill"
        case .tearfulSuspension: return "drop.fill"
        case .fullFourPhrasePoem: return "wand.and.stars"
        }
    }

    public var philosophyNote: String {
        switch self {
        case .climbSequence: return "保留你的旋律形状，整体搬高一层楼再讲一遍，情绪自然层层推进。"
        case .waterMirror: return "对着水面把你的旋律上下翻个身——往上走变成往下落，天然对称如巴赫。"
        case .tearfulSuspension: return "故意让旋律在 4·呜嘟 上多赖半秒，摩擦出淡淡鼻酸再滑落到 3→1 回家。"
        case .fullFourPhrasePoem: return "只用你这颗小种子，按「起·破土 → 承·攀爬 → 转·倒影 → 合·迟到归家」长成完整小诗！"
        }
    }
}

public enum MotifOrigamiEngine {

    /// 提取画布里的原始小种子（最多取前 4 颗珠，若为空则给出 1-3-5 默认晨光种子）
    public static func extractSeed(from notes: [NoteBead]) -> [NoteBead] {
        let sorted = notes.sorted { $0.rawOnset < $1.rawOnset }
        if sorted.isEmpty {
            return [
                NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.12, rawDuration: 0.48, phraseTag: "起·种子"),
                NoteBead(degree: 3, octaveOffset: 0, rawOnset: 0.62, rawDuration: 0.48, phraseTag: "起·种子"),
                NoteBead(degree: 5, octaveOffset: 0, rawOnset: 1.12, rawDuration: 0.62, phraseTag: "起·种子")
            ]
        }
        return Array(sorted.prefix(min(4, sorted.count)))
    }

    public static func grow(notes: [NoteBead], operation: MotifGrowthOperation) -> [NoteBead] {
        let seed = extractSeed(from: notes)
        let baseNotes = notes.isEmpty ? seed : notes.sorted { $0.rawOnset < $1.rawOnset }

        // 归一化种子的相对时间步长，确保生长出的乐句节奏均匀有呼吸
        let seedStart = seed.first?.rawOnset ?? 0
        let seedSteps: [(linear: Int, relTime: Double, dur: Double)] = seed.enumerated().map { idx, b in
            let lin = b.octaveOffset * 7 + (b.degree - 1)
            let rel = (idx == 0) ? 0.0 : max(0.32 * Double(idx), min(1.8, b.rawOnset - seedStart))
            return (lin, rel, max(0.32, min(0.85, b.rawDuration)))
        }
        let seedSpan = (seedSteps.last.map { $0.relTime + $0.dur } ?? 1.2) + 0.22

        switch operation {
        case .climbSequence:
            let existing = tagIfNeeded(baseNotes, defaultTag: "起·种子")
            let cursor = (existing.last.map { $0.rawOnset + $0.rawDuration } ?? 0) + 0.20
            let climbed = seedSteps.map { step -> NoteBead in
                let (d, o) = decodeLinear(step.linear + 1)
                return NoteBead(
                    degree: d,
                    octaveOffset: o,
                    rawOnset: cursor + step.relTime,
                    rawDuration: step.dur,
                    phraseTag: "承·爬楼"
                )
            }
            return trimToPlayableLimit(existing + climbed)

        case .waterMirror:
            let existing = tagIfNeeded(baseNotes, defaultTag: "起·种子")
            let cursor = (existing.last.map { $0.rawOnset + $0.rawDuration } ?? 0) + 0.20
            let pivot = seedSteps.last?.linear ?? 4
            let anchor0 = seedSteps.first?.linear ?? 0
            let mirrored = seedSteps.map { step -> NoteBead in
                let deltaFromStart = step.linear - anchor0
                let (d, o) = decodeLinear(pivot - deltaFromStart)
                return NoteBead(
                    degree: d,
                    octaveOffset: o,
                    rawOnset: cursor + step.relTime,
                    rawDuration: step.dur,
                    phraseTag: "转·倒影"
                )
            }
            return trimToPlayableLimit(existing + mirrored)

        case .tearfulSuspension:
            let existing = tagIfNeeded(baseNotes, defaultTag: "起·种子")
            let cursor = (existing.last.map { $0.rawOnset + $0.rawDuration } ?? 0) + 0.16
            // 经典 4→3 延留迟到（4 拉长 0.92s 制造酸楚摩擦，再滑落 3 → 2 → 1 归家）
            let cadence: [NoteBead] = [
                NoteBead(degree: 4, octaveOffset: 0, rawOnset: cursor, rawDuration: 0.90, phraseTag: "合·迟到半秒"),
                NoteBead(degree: 3, octaveOffset: 0, rawOnset: cursor + 0.92, rawDuration: 0.56, phraseTag: "合·融化"),
                NoteBead(degree: 1, octaveOffset: 0, rawOnset: cursor + 1.50, rawDuration: 1.05, phraseTag: "合·归家")
            ]
            return trimToPlayableLimit(existing + cadence)

        case .fullFourPhrasePoem:
            var poem: [NoteBead] = []
            // 1. 起 · 破土种子
            for step in seedSteps {
                let (d, o) = decodeLinear(step.linear)
                poem.append(NoteBead(degree: d, octaveOffset: o, rawOnset: 0.12 + step.relTime, rawDuration: step.dur, phraseTag: "起·种子"))
            }
            // 2. 承 · 向上爬楼推进
            let t2 = 0.12 + seedSpan
            for step in seedSteps {
                let (d, o) = decodeLinear(step.linear + 1)
                poem.append(NoteBead(degree: d, octaveOffset: o, rawOnset: t2 + step.relTime, rawDuration: step.dur, phraseTag: "承·爬楼"))
            }
            // 3. 转 · 水面镜像悬停
            let t3 = t2 + seedSpan
            let pivot = (seedSteps.last?.linear ?? 4) + 1
            let anchor0 = seedSteps.first?.linear ?? 0
            for step in seedSteps {
                let (d, o) = decodeLinear(pivot - (step.linear - anchor0))
                poem.append(NoteBead(degree: d, octaveOffset: o, rawOnset: t3 + step.relTime, rawDuration: step.dur, phraseTag: "转·倒影"))
            }
            // 4. 合 · 半秒延留深情归家
            let t4 = t3 + seedSpan
            poem.append(NoteBead(degree: 4, octaveOffset: 0, rawOnset: t4, rawDuration: 0.88, phraseTag: "合·迟到半秒"))
            poem.append(NoteBead(degree: 3, octaveOffset: 0, rawOnset: t4 + 0.90, rawDuration: 0.52, phraseTag: "合·融化"))
            poem.append(NoteBead(degree: 1, octaveOffset: 0, rawOnset: t4 + 1.44, rawDuration: 1.15, phraseTag: "合·归家"))
            return poem
        }
    }

    private static func tagIfNeeded(_ notes: [NoteBead], defaultTag: String) -> [NoteBead] {
        notes.map { b in
            if b.phraseTag != nil { return b }
            var copy = b
            copy.phraseTag = defaultTag
            return copy
        }
    }

    private static func decodeLinear(_ linear: Int) -> (degree: Int, octave: Int) {
        let clamped = max(-3, min(8, linear)) // 低音 5↓ 到 高音 2↑
        let oct = Int(floor(Double(clamped) / 7.0))
        let deg = clamped - oct * 7 + 1
        return (max(1, min(7, deg)), max(-1, min(1, oct)))
    }

    private static func trimToPlayableLimit(_ notes: [NoteBead]) -> [NoteBead] {
        guard notes.count > 22 else { return notes }
        return Array(notes.suffix(22))
    }
}

/// 影子对位副旋律节点（巴赫复调与留白对话哲学：当主旋律停在长音或呼吸间隙时，水下浮现温柔的回声对答）
public struct CounterpointNote: Identifiable, Equatable, Sendable {
    public let id: Int
    public let degree: Int
    public let octaveOffset: Int
    public let onset: Double
    public let duration: Double
}

public enum CounterpointShadowEngine {
    /// 为任意旋律实时编织一条不抢戏、遵循反向/三六度和谐法则的「影子大提琴/竖琴对位线」
    public static func generateShadowVoice(document: MelodyDocument, spans: [ChordSpan]) -> [CounterpointNote] {
        let notes = document.notes.sorted {
            $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
        }
        guard notes.count >= 2 else { return [] }

        var result: [CounterpointNote] = []
        var nextID = 0

        for i in 0..<notes.count {
            let cur = notes[i]
            let curOnset = cur.displayOnset(grooveStrength: document.grooveStrength)
            let curDur = cur.displayDuration(grooveStrength: document.grooveStrength)
            let nextOnset = (i + 1 < notes.count)
                ? notes[i + 1].displayOnset(grooveStrength: document.grooveStrength)
                : (curOnset + curDur + 0.45)
            let gap = nextOnset - curOnset

            // 只在留白呼吸空间（≥ 0.65 秒）或每两颗音的中间点悄悄接话，遵循「太极互补」不喧宾夺主
            guard gap >= 0.62 || (i % 2 == 1 && gap >= 0.42) else { continue }

            let replyTime = curOnset + min(0.55, gap * 0.48)
            let activeChord = TheoryLensEngine.chord(at: replyTime, in: spans) ?? .I

            // 挑选与主旋律错开、且属于当前和弦的下方三度/六度和声对位音
            let preferredTone = activeChord.chordToneDegrees.first(where: { $0 != cur.degree }) ?? activeChord.rootDegree
            let replyOctave = (cur.octaveOffset > 0 || preferredTone > cur.degree) ? -1 : 0

            result.append(
                CounterpointNote(
                    id: nextID,
                    degree: preferredTone,
                    octaveOffset: replyOctave,
                    onset: replyTime,
                    duration: max(0.38, min(0.95, gap * 0.62))
                )
            )
            nextID += 1
        }
        return result
    }
}
