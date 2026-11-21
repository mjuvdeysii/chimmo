import Foundation

/// 16 首 100% 版权自洁的可拆解编曲标本库（8 首自编公版古典 + 8 首自有版权现代编曲技法）。
public enum SpecimenLibrary {

    public static let all: [MelodyDocument] = [
        // 8 首自有版权现代编曲技法标本
        summerSuspension,
        tinkiResolution,
        rainyChromaticWalk,
        teardropSlashBass,
        midnightCoastCityPop,
        bittersweetDaylight,
        teaHousePentatonic,
        stardustCounterpoint,
        // 8 首团队自编公版古典标本
        bachPreludeSeed,
        bachInventionDialogue,
        satieGymnopedieSeed,
        debussyMoonlightMist,
        chopinNocturneSigh,
        pachelbelCanonGround,
        mozartTwinkleVariation,
        beethovenEliseResolve
    ]

    // MARK: - B. 自有版权现代技法（8 首）

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

    public static let tinkiResolution: MelodyDocument = makeSpecimen(
        title: "叮尖回家",
        subtitle: "导音 7→1 张力与释放 · 电影微光",
        category: "现代编曲技法",
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

    public static let rainyChromaticWalk: MelodyDocument = makeSpecimen(
        title: "雨后半音",
        subtitle: "微酸小调下的 3 号拍咯 · 电影微光",
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

    public static let midnightCoastCityPop: MelodyDocument = makeSpecimen(
        title: "午夜海岸",
        subtitle: "City Pop 2-5-1 九和弦漫步 · 电影微光",
        category: "现代编曲技法",
        insight: "从 2 号豆叩滑向 5 号壳咯再落回 1 号陶诺——2-5-1 是现代都市流行乐最经典的顺滑转弯。",
        mode: .brightMajor,
        harmony: .filmGlow,
        bpm: 94,
        steps: [
            (2, 0, 1.0), (4, 0, 1.0), (6, 0, 1.5), (5, 0, 1.5),
            (7, 0, 1.0), (2, 1, 1.0), (1, 1, 1.5), (3, 0, 1.5),
            (2, 0, 1.0), (5, 0, 1.5), (1, 0, 2.5)
        ]
    )

    public static let bittersweetDaylight: MelodyDocument = makeSpecimen(
        title: "白昼微酸",
        subtitle: "大调主歌落向 6 号钵莫 · 毛毡暖阳",
        category: "现代编曲技法",
        insight: "明明是晴朗大调，结尾却不回 1 号陶诺，而是轻轻落在 6 号钵莫怀里，留下一丝没说完的余味。",
        mode: .brightMajor,
        harmony: .feltSun,
        bpm: 88,
        steps: [
            (1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.5), (5, 0, 1.5),
            (6, 0, 1.0), (5, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
            (3, 0, 1.0), (5, 0, 1.0), (6, 0, 2.5)
        ]
    )

    public static let teaHousePentatonic: MelodyDocument = makeSpecimen(
        title: "留白茶室",
        subtitle: "东方五声线条配现代 add9 · 透明水波",
        category: "现代编曲技法",
        insight: "全程避开 4 号与 7 号两个紧绷半音，只用 1-2-3-5-6 五只小偶，就能织出怎么弹都不撞音的东方意境。",
        mode: .brightMajor,
        harmony: .clearWater,
        bpm: 76,
        steps: [
            (5, 0, 1.5), (6, 0, 1.0), (1, 1, 2.0),
            (6, 0, 1.0), (5, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
            (1, 0, 1.5), (2, 0, 1.0), (3, 0, 1.5), (5, 0, 1.5), (1, 0, 2.5)
        ]
    )

    public static let stardustCounterpoint: MelodyDocument = makeSpecimen(
        title: "星尘对话",
        subtitle: "高低八度问答呼应 · 透明水波",
        category: "现代编曲技法",
        insight: "高音区的问句与中音区的答句彼此接力，让单条旋律线也听得出两个人对话的空间层次。",
        mode: .brightMajor,
        harmony: .clearWater,
        bpm: 84,
        steps: [
            (1, 1, 1.0), (7, 0, 1.0), (5, 0, 1.5),
            (1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.5),
            (6, 0, 1.0), (5, 0, 1.0), (4, 0, 1.0), (3, 0, 1.5),
            (2, 0, 1.5), (1, 0, 2.5)
        ]
    )

    // MARK: - A. 自编公版古典（8 首）

    public static let bachPreludeSeed: MelodyDocument = makeSpecimen(
        title: "前奏曲光瀑",
        subtitle: "巴赫 BWV 846 阶梯分解 · 毛毡暖阳",
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

    public static let bachInventionDialogue: MelodyDocument = makeSpecimen(
        title: "创意曲追逐",
        subtitle: "巴赫 BWV 772 动机攀升 · 毛毡暖阳",
        category: "自编公版古典",
        insight: "1-2-3-4-2-3-1 的短小动机像拾级而上的脚步，先在主音出发，随后在 5 号属音高处原样回响。",
        mode: .brightMajor,
        harmony: .feltSun,
        bpm: 96,
        steps: [
            (1, 0, 0.6), (2, 0, 0.6), (3, 0, 0.6), (4, 0, 0.6),
            (2, 0, 0.6), (3, 0, 0.6), (1, 0, 1.2),
            (5, 0, 0.6), (6, 0, 0.6), (7, 0, 0.6), (1, 1, 0.6),
            (6, 0, 0.6), (7, 0, 0.6), (5, 0, 1.8)
        ]
    )

    public static let satieGymnopedieSeed: MelodyDocument = makeSpecimen(
        title: "慢摆吉诺佩蒂",
        subtitle: "萨蒂三拍子留白与大七悬浮 · 透明水波",
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

    public static let debussyMoonlightMist: MelodyDocument = makeSpecimen(
        title: "月光下沉线",
        subtitle: "德彪西式三度缓落 · 透明水波",
        category: "自编公版古典",
        insight: "从高处 1 号与 6 号缓步滑落到 5 号与 3 号，像月光透过云层一层层铺在静水面上。",
        mode: .brightMajor,
        harmony: .clearWater,
        bpm: 68,
        steps: [
            (1, 1, 1.5), (6, 0, 1.5), (5, 0, 1.0), (4, 0, 1.0), (5, 0, 1.5),
            (3, 0, 1.5), (2, 0, 1.0), (3, 0, 1.0), (1, 0, 2.5)
        ]
    )

    public static let chopinNocturneSigh: MelodyDocument = makeSpecimen(
        title: "夜曲长叹",
        subtitle: "肖邦式小调级进与大跳 · 电影微光",
        category: "自编公版古典",
        insight: "先在 5-4-3-2 之间低声叹息，紧接着向上大跳撑开情绪张力，再缓缓回落归家。",
        mode: .wistfulMinor,
        harmony: .filmGlow,
        bpm: 74,
        steps: [
            (5, 0, 1.5), (4, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
            (1, 0, 1.0), (5, 0, 2.0), (4, 0, 1.0), (3, 0, 1.5),
            (2, 0, 1.5), (1, 0, 2.5)
        ]
    )

    public static let pachelbelCanonGround: MelodyDocument = makeSpecimen(
        title: "卡农回环",
        subtitle: "帕赫贝尔式八步稳固阶梯 · 毛毡暖阳",
        category: "自编公版古典",
        insight: "3-2-1-7-6-5-6-7——这条流传三百年的黄金骨架也是无数现代流行金曲的共同地基。",
        mode: .brightMajor,
        harmony: .feltSun,
        bpm: 82,
        steps: [
            (3, 0, 1.5), (2, 0, 1.5), (1, 0, 1.5), (7, -1, 1.5),
            (6, -1, 1.5), (5, -1, 1.5), (6, -1, 1.5), (7, -1, 1.5),
            (1, 0, 2.5)
        ]
    )

    public static let mozartTwinkleVariation: MelodyDocument = makeSpecimen(
        title: "小星星引力",
        subtitle: "莫扎特 K.265 五度跳跃与级进回落 · 毛毡暖阳",
        category: "自编公版古典",
        insight: "最简单的童谣藏着最标准的引力法则：1 跳到 5 打开空间，6 往上探一步马上落回 5，再由 4-3-2-1 一步步走回家。",
        mode: .brightMajor,
        harmony: .feltSun,
        bpm: 98,
        steps: [
            (1, 0, 1.0), (1, 0, 1.0), (5, 0, 1.0), (5, 0, 1.0),
            (6, 0, 1.0), (6, 0, 1.0), (5, 0, 2.0),
            (4, 0, 1.0), (4, 0, 1.0), (3, 0, 1.0), (3, 0, 1.0),
            (2, 0, 1.0), (2, 0, 1.0), (1, 0, 2.0)
        ]
    )

    public static let beethovenEliseResolve: MelodyDocument = makeSpecimen(
        title: "爱丽丝摇摆",
        subtitle: "贝多芬式半音微颤与小调归宿 · 电影微光",
        category: "自编公版古典",
        insight: "高处两颗相邻音珠轻轻往复摇晃制造悬念，随后分解三和弦自下而上托起，稳稳落回主音。",
        mode: .wistfulMinor,
        harmony: .filmGlow,
        bpm: 92,
        steps: [
            (5, 0, 0.6), (4, 0, 0.6), (5, 0, 0.6), (4, 0, 0.6),
            (5, 0, 0.6), (2, 0, 0.6), (4, 0, 0.6), (3, 0, 0.6), (1, 0, 1.6),
            (3, -1, 0.6), (6, -1, 0.6), (1, 0, 0.6), (2, 0, 1.6),
            (3, 0, 0.6), (2, 0, 0.6), (1, 0, 2.0)
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
