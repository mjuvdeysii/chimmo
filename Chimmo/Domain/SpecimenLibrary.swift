import Foundation

/// 100% 版权自洁的可拆解编曲标本库（V0.1 首发精选 6 首：2 首自编公版古典 + 4 首自有版权现代技法）。
public enum SpecimenLibrary {

    public static let all: [MelodyDocument] = [
        summerSuspension,
        bachPreludeSeed,
        tinkiResolution,
        satieGymnopedieSeed,
        rainyChromaticWalk,
        teardropSlashBass
    ]

    /// 现代技法 1：久石让式 4-5-3-6 四度/九度悬浮骨架（原创）
    public static let summerSuspension: MelodyDocument = makeSpecimen(
        title: "夏风四度",
        subtitle: "4-5-3-6 现代悬浮进行 · 透明水波",
        category: "现代编曲技法",
        insight: "看 4 号呜嘟与 5 号壳咯撑起的透明水晕：旋律并不急着回 1 号家，反而停在 6 号钵莫上生出夏末怀旧感。",
        mode: .brightMajor,
        harmony: .clearWater,
        bpm: 86,
        steps: [
            (4, 0, 1.5), (5, 0, 1.0), (3, 0, 1.5), (6, 0, 2.0),
            (4, 0, 1.0), (5, 0, 1.0), (1, 1, 1.5), (7, 0, 1.0), (5, 0, 1.5),
            (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (5, 0, 1.5), (1, 0, 2.5)
        ]
    )

    /// 公版古典 1：巴赫式分解音级流动骨架（团队自编公版动机）
    public static let bachPreludeSeed: MelodyDocument = makeSpecimen(
        title: "前奏曲光瀑",
        subtitle: "巴赫式阶梯分解 · 毛毡暖阳",
        category: "自编公版古典",
        insight: "每四颗音珠都是一座微型和声阶梯：1-3-5 三人组稳稳托住屋顶，进入 7 号叮尖时纸面拉紧赤陶弦丝。",
        mode: .brightMajor,
        harmony: .feltSun,
        bpm: 108,
        steps: [
            (1, 0, 0.75), (3, 0, 0.75), (5, 0, 0.75), (1, 1, 0.75),
            (7, 0, 0.75), (5, 0, 0.75), (6, 0, 0.75), (4, 0, 0.75),
            (2, 0, 0.75), (4, 0, 0.75), (6, 0, 0.75), (5, 0, 0.75),
            (7, 0, 0.75), (2, 1, 0.75), (1, 1, 2.25)
        ]
    )

    /// 现代技法 2：专门让零基础 10 秒看懂 7→1 张力与解决（原创）
    public static let tinkiResolution: MelodyDocument = makeSpecimen(
        title: "叮尖回家",
        subtitle: "导音 7→1 张力与释放 · 电影微光",
        category: "编曲引力入门",
        insight: "盯住 7 号叮尖亮起的那一刻——他踮着脚尖绷出赤陶虚线，下一拍落到 1 号陶诺时瞬间舒展涟漪。",
        mode: .brightMajor,
        harmony: .filmGlow,
        bpm: 80,
        steps: [
            (1, 0, 1.5), (3, 0, 1.0), (5, 0, 1.5),
            (4, 0, 1.5), (3, 0, 1.5),
            (6, 0, 1.5), (7, 0, 2.25), (1, 1, 2.5)
        ]
    )

    /// 公版古典 2：萨蒂式三拍子清冷大七和声呼吸（团队自编公版氛围动机）
    public static let satieGymnopedieSeed: MelodyDocument = makeSpecimen(
        title: "慢摆吉诺佩蒂",
        subtitle: "三拍子留白与大七悬浮 · 透明水波",
        category: "自编公版古典",
        insight: "好的编曲一半是留白：每颗陶珠拖出绵长余影，让水面和声在空隙里安静呼吸。",
        mode: .brightMajor,
        harmony: .clearWater,
        bpm: 72,
        steps: [
            (3, 0, 1.5), (5, 0, 1.5), (4, 0, 1.5), (3, 0, 1.5),
            (2, 0, 1.5), (1, 0, 1.5), (2, 0, 1.5), (3, 0, 1.5),
            (6, -1, 3.0), (1, 0, 3.0)
        ]
    )

    /// 现代技法 3：微酸小调与 3 号拍咯情绪变换（原创）
    public static let rainyChromaticWalk: MelodyDocument = makeSpecimen(
        title: "雨后微酸",
        subtitle: "自然小调下的 3 号拍咯 · 电影微光",
        category: "现代编曲技法",
        insight: "切到微酸小调后，3 号拍咯的双耳微微垂落；试着点顶部切回晴朗大调，听听同一串音珠如何瞬间放晴。",
        mode: .wistfulMinor,
        harmony: .filmGlow,
        bpm: 84,
        steps: [
            (1, 0, 1.25), (2, 0, 0.75), (3, 0, 2.0),
            (5, 0, 1.25), (4, 0, 0.75), (3, 0, 1.5), (2, 0, 1.0),
            (6, -1, 1.5), (7, -1, 1.5), (1, 0, 2.5)
        ]
    )

    /// 现代技法 4：下行斜杠低音催泪骨架（原创）
    public static let teardropSlashBass: MelodyDocument = makeSpecimen(
        title: "慢行楼梯",
        subtitle: "下行阶梯低音托底 · 毛毡暖阳",
        category: "现代编曲技法",
        insight: "旋律反复绕着 5 号壳咯和 3 号拍咯打转，但底部水面一步步往下走楼梯，情绪就在不知不觉里沉了下来。",
        mode: .brightMajor,
        harmony: .feltSun,
        bpm: 78,
        steps: [
            (5, 0, 1.5), (3, 0, 1.5), (5, 0, 1.0), (7, 0, 1.5),
            (5, 0, 1.5), (6, 0, 1.5), (4, 0, 1.5), (3, 0, 1.5),
            (2, 0, 1.5), (5, 0, 1.5), (1, 0, 2.5)
        ]
    )

    // MARK: - Builder

    private static func makeSpecimen(
        title: String,
        subtitle: String,
        category: String,
        insight: String,
        mode: ScaleMode,
        harmony: HarmonyProfile,
        bpm: Double,
        steps: [(Int, Int, Double)]
    ) -> MelodyDocument {
        let beatSec = 60.0 / bpm
        var cursor = 0.0
        let beads: [NoteBead] = steps.map { deg, oct, beats in
            let dur = beats * beatSec
            let bead = NoteBead(
                degree: deg,
                octaveOffset: oct,
                rawOnset: cursor,
                rawDuration: dur,
                quantizedOnset: cursor,
                quantizedDuration: dur,
                confidence: 1.0,
                ghostCandidates: []
            )
            cursor += dur
            return bead
        }

        return MelodyDocument(
            title: title,
            subtitle: subtitle,
            rootMIDI: 60,
            scaleMode: mode,
            harmonyProfile: harmony,
            grooveStrength: 1.0,
            estimatedBPM: bpm,
            notes: beads,
            isSpecimen: true,
            specimenCategory: category,
            composerInsight: insight
        )
    }
}
