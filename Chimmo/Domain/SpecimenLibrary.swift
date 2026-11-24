import Foundation

/// 28 首 100% 版权自洁的世界公版名曲 + 原创夏日治愈技法透视库：
/// - 20 首全球公有领域古典名曲（作者逝世均逾百年，依据原谱独立编配为音级透视图，含圣桑《天鹅》、李斯特×3、巴赫×5、柴可夫斯基《天鹅湖》、德彪西×2、肖邦×2、德沃夏克《念故乡》、萨蒂、贝多芬×2、舒伯特、帕赫贝尔、莫扎特）
/// - 8 首 100% 原创现代与东亚治愈风编曲技法示范（零现代版权作品侵入，纯粹拆解透明九和弦、五声音阶与悬浮进行）
public enum SpecimenLibrary {

    public static let categories: [String] = [
        "全部",
        "圣桑·李斯特·浪漫派",
        "巴赫·古典名作",
        "印象·民族与夜曲",
        "原创夏日治愈风"
    ]

    public static let all: [MelodyDocument] = [
        // 一、圣桑 · 李斯特 · 浪漫派（7 首公版）
        saintSaensTheSwan,
        lisztLiebestraum,
        lisztConsolation3,
        lisztCampanellaTheme,
        tchaikovskySwanLake,
        chopinNocturneOp9No2,
        schubertSerenade,

        // 二、巴赫 · 古典名作（7 首公版）
        bachPreludeSeed,
        bachAirOnGString,
        bachMinuetInG,
        bachCelloSuite1Prelude,
        bachInventionDialogue,
        pachelbelCanonGround,
        mozartTwinkleVariation,

        // 三、印象 · 民族与夜曲（6 首公版）
        dvorakGoingHome,
        debussyClairDeLune,
        debussyFlaxenHair,
        satieGymnopedieSeed,
        beethovenMoonlight1,
        beethovenEliseResolve,

        // 四、原创夏日治愈与现代技法（8 首 100% 原创）
        summerSuspension,
        teaHousePentatonic,
        tinkiResolution,
        rainyChromaticWalk,
        midnightCoastCityPop,
        bittersweetDaylight,
        teardropSlashBass,
        stardustCounterpoint
    ]

    // MARK: - 一、圣桑 · 李斯特 · 浪漫派（公版名曲）

    public static let saintSaensTheSwan: MelodyDocument = makeSpecimen(
        title: "天鹅 · 圣桑",
        subtitle: "圣桑《动物狂欢节》1886 公版 · 流动水波与深情大跳",
        category: "圣桑·李斯特·浪漫派",
        insight: "左手用细腻的「天鹅水波」铺开镜面湖水，大提琴先从高处 1↑→7→3 滑入湖心，再从 4→5→6 缓缓仰起脖颈飞向高音 1↑。",
        rootMIDI: 55, // G3 温暖大提琴音区
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .swanRipple,
        voice: .singingCello,
        bpm: 66,
        steps: [
            (1, 1, 2.0), (7, 0, 1.0), (3, 0, 1.5),
            (6, 0, 1.5), (5, 0, 1.0), (3, 0, 1.5),
            (4, 0, 1.25), (5, 0, 0.75), (6, 0, 1.0), (1, 1, 2.0),
            (7, 0, 1.0), (6, 0, 1.0), (5, 0, 1.5), (3, 0, 1.5),
            (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "天鹅入水", caption: "从高音 1↑ 滑落半音到 7，再优雅下行到 3，左手水波轻轻托住水面。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.34, badge: "扬颈远望", caption: "4→5→6 像羽翼蓄力，一路攀回高音 1↑——这就是画面感极强的「线条弧度」。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.72, badge: "湖面归宁", caption: "4→3→2→1 级进轻落回陶诺，整片湖水归于温柔的平静。")
        ]
    )

    public static let lisztLiebestraum: MelodyDocument = makeSpecimen(
        title: "爱之梦 · 李斯特",
        subtitle: "李斯特《爱之梦》No.3 1850 公版 · 六度深情仰望",
        category: "圣桑·李斯特·浪漫派",
        insight: "开头从低处 5↓ 一跃大跳六度到 3·拍咯，反复轻唤同一颗音后，轻轻叹息落回 1·陶诺，像在夜风里倾诉心事。",
        rootMIDI: 56, // Ab3
        mode: .brightMajor,
        harmony: .filmGlow,
        texture: .swanRipple,
        bpm: 72,
        steps: [
            (5, -1, 1.0), (3, 0, 1.5), (3, 0, 0.75), (3, 0, 0.75),
            (3, 0, 1.0), (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 1.5),
            (5, -1, 1.0), (4, 0, 1.5), (4, 0, 0.75), (5, 0, 0.75),
            (6, 0, 1.25), (5, 0, 1.0), (3, 0, 1.25), (2, 0, 1.0), (1, 0, 2.25)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "深情大跳", caption: "低音 5↓ 直接大跳六度冲上 3·拍咯！大跳是浪漫派瞬间抓心的秘密。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.36, badge: "同音倾诉", caption: "在同一颗 3 上重复轻唤，随后 4→3→2→1 像叹息一样滑落。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.68, badge: "情绪抬升", caption: "第二句把顶点从 3 推高到 6·钵莫，再慢慢归家，形成动人的「高潮弧」。")
        ]
    )

    public static let lisztConsolation3: MelodyDocument = makeSpecimen(
        title: "安慰曲 · 李斯特",
        subtitle: "李斯特《安慰曲》No.3 1850 公版 · 如歌夜曲",
        category: "圣桑·李斯特·浪漫派",
        insight: "李斯特最温柔的一面：没有炫技，只在 5-3-2-1 之间像轻抚琴键般歌唱，底下的水波琶音让每个长音都泛着微光。",
        rootMIDI: 61, // Db4
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .swanRipple,
        bpm: 64,
        steps: [
            (5, 0, 2.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.0),
            (6, -1, 1.0), (1, 0, 1.0), (2, 0, 1.5), (3, 0, 1.5),
            (5, 0, 2.0), (6, 0, 1.0), (5, 0, 1.0), (4, 0, 1.0), (3, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "如歌长音", caption: "先用长长的 5·壳咯定住氛围，再慢悠悠走到 3-2-1。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.55, badge: "水波呼吸", caption: "旋律停在长音时，仔细听左手水波如何填满安静的空白。")
        ]
    )

    public static let lisztCampanellaTheme: MelodyDocument = makeSpecimen(
        title: "钟 · 李斯特",
        subtitle: "李斯特《帕格尼尼练习曲·钟》1851 公版 · 灵动铃音",
        category: "圣桑·李斯特·浪漫派",
        insight: "小调里的钟声跳跃：高处的 5·壳咯像一只清脆银铃反复敲响，另一条声音在下面灵巧地级进穿梭。",
        rootMIDI: 64,
        mode: .wistfulMinor,
        harmony: .filmGlow,
        texture: .summerGlass,
        voice: .celestaGlass,
        bpm: 112,
        steps: [
            (5, 0, 0.75), (1, 1, 0.75), (7, 0, 0.75), (6, 0, 0.75),
            (5, 0, 0.75), (4, 0, 0.75), (3, 0, 0.75), (2, 0, 0.75),
            (1, 0, 1.0), (3, 0, 0.75), (5, 0, 0.75), (1, 1, 1.25),
            (7, 0, 0.75), (5, 0, 0.75), (1, 0, 2.0)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "银铃跃动", caption: "5 跳到高音 1↑ 后一路急转直下，像高塔钟声在夜空回荡。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.58, badge: "分解回弹", caption: "1-3-5-1↑ 分解三和弦瞬间跃起，再利落落地！")
        ]
    )

    public static let tchaikovskySwanLake: MelodyDocument = makeSpecimen(
        title: "天鹅湖 · 柴可夫斯基",
        subtitle: "柴可夫斯基《天鹅湖》场景主题 1876 公版 · 宿命小调",
        category: "圣桑·李斯特·浪漫派",
        insight: "和圣桑的明亮大调《天鹅》形成绝妙对照：同样写天鹅，柴可夫斯基用微酸小调 5→1-2-3-4-5 勾勒出月夜下的宿命感。",
        rootMIDI: 59, // B3
        mode: .wistfulMinor,
        harmony: .filmGlow,
        texture: .swanRipple,
        voice: .singingCello,
        bpm: 84,
        steps: [
            (5, 0, 2.0), (1, 0, 0.75), (2, 0, 0.75), (3, 0, 0.75), (4, 0, 0.75),
            (5, 0, 1.75), (3, 0, 0.75), (5, 0, 1.75), (3, 0, 0.75),
            (5, 0, 1.5), (1, 0, 0.75), (3, 0, 0.75), (1, 0, 0.75),
            (6, -1, 1.0), (3, 0, 1.0), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "月夜起势", caption: "小调 5 独自拉响后，1-2-3-4-5 一口气爬上楼梯，宿命感立刻扑面而来。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.55, badge: "羽翼回旋", caption: "在 5 与 3 之间反复回旋，最后坠向低音 6↓ 再回到 1。")
        ]
    )

    public static let chopinNocturneOp9No2: MelodyDocument = makeSpecimen(
        title: "降E大调夜曲 · 肖邦",
        subtitle: "肖邦 Op.9 No.2 1832 公版 · 浪漫派圆舞夜色",
        category: "圣桑·李斯特·浪漫派",
        insight: "听听经典的「圆舞呼吸」左手伴奏：一拍沉稳低音，两拍轻柔上浮，托着右手 5↓→3 的大六度优雅起飞。",
        rootMIDI: 63, // Eb4
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .feltWaltz,
        bpm: 74,
        steps: [
            (5, -1, 1.0), (3, 0, 2.0), (2, 0, 0.75), (3, 0, 0.75), (2, 0, 0.75), (1, 0, 1.5),
            (5, -1, 1.0), (3, 0, 1.0), (1, 1, 2.0), (7, 0, 0.75), (6, 0, 0.75), (5, 0, 1.5),
            (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "圆舞摇曳", caption: "低音 5↓ 轻跃到 3·拍咯，配着三拍子圆舞呼吸缓缓荡开。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.45, badge: "星夜攀升", caption: "一举跳上高音 1↑，再沿着 7-6-5-4-3-2-1 优雅滑下楼梯。")
        ]
    )

    public static let schubertSerenade: MelodyDocument = makeSpecimen(
        title: "小夜曲 · 舒伯特",
        subtitle: "舒伯特《天鹅之歌》小夜曲 1828 公版 · 窗下叹息",
        category: "圣桑·李斯特·浪漫派",
        insight: "三个快音轻轻一转再向上仰起（5-6-5→1↑），像在夜色窗下欲言又止的轻声问候。",
        rootMIDI: 62, // D4
        mode: .wistfulMinor,
        harmony: .filmGlow,
        texture: .feltWaltz,
        bpm: 82,
        steps: [
            (5, 0, 0.5), (6, 0, 0.5), (5, 0, 0.5), (1, 1, 1.5), (5, 0, 1.25),
            (4, 0, 0.5), (5, 0, 0.5), (4, 0, 0.5), (6, 0, 1.5), (4, 0, 1.25),
            (3, 0, 1.0), (5, 0, 1.0), (4, 0, 0.75), (3, 0, 0.75), (2, 0, 1.0), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "窗下回转", caption: "5-6-5 三个轻快音刚一打转，立刻扬上高音 1↑ 望向夜窗。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.27, badge: "小调回声", caption: "4-5-4 再往 6·钵莫送出一步，微酸小调让夜风更加柔和。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.55, badge: "渐落归宁", caption: "3→5 再随 4-3-2-1 缓缓走低，安静收在窗前月色里。")
        ]
    )

    // MARK: - 二、巴赫 · 古典名作（公版名曲）

    public static let bachPreludeSeed: MelodyDocument = makeSpecimen(
        title: "C大调前奏曲 · 巴赫",
        subtitle: "巴赫 BWV 846 1722 公版 · 黄金和弦阶梯",
        category: "巴赫·古典名作",
        insight: "最伟大的「和弦教科书」：整首曲子几乎没有复杂旋律，全靠把和弦里的音一颗颗拆开往上爬，看音珠如何严丝合缝踩进发光泳道！",
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .pureChorale,
        bpm: 104,
        steps: [
            (1, 0, 0.75), (3, 0, 0.75), (5, 0, 0.75), (1, 1, 0.75),
            (2, 0, 0.75), (4, 0, 0.75), (6, 0, 0.75), (1, 1, 0.75),
            (7, -1, 0.75), (2, 0, 0.75), (5, 0, 0.75), (7, 0, 0.75),
            (1, 0, 0.75), (3, 0, 0.75), (5, 0, 0.75), (1, 1, 2.0)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "拆开 I 和弦", caption: "1-3-5-1↑：巴赫把主和弦的 3 个组成音一颗颗铺成水晶楼梯。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.48, badge: "导音蓄力", caption: "进入 V 和弦（5-7-2），7·叮尖绷紧，推着全曲流回高音 1↑！")
        ]
    )

    public static let bachAirOnGString: MelodyDocument = makeSpecimen(
        title: "G弦上的咏叹调 · 巴赫",
        subtitle: "巴赫 BWV 1068 约1730 公版 · 长音如丝的呼吸",
        category: "巴赫·古典名作",
        insight: "开头用一颗极长的 3·拍咯定住时光，随后 4-2-7↓-1 像丝绸般蜿蜒落下——好旋律不必音符密集，敢留长音才有高级感。",
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .swanRipple,
        voice: .singingCello,
        bpm: 64,
        steps: [
            (3, 0, 3.0), (3, 0, 0.75), (4, 0, 0.75), (2, 0, 1.0),
            (7, -1, 1.0), (1, 0, 1.25), (6, -1, 1.0), (5, -1, 1.5),
            (4, 0, 1.5), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 1.0), (7, -1, 1.0), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "丝绸长音", caption: "3·拍咯稳稳拖长三拍，听底下的和弦光带如何悄悄变换色彩。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.55, badge: "级进滑落", caption: "4-3-2-1-7↓-1 像水珠顺着琴弦缓缓滑回温暖的 1·陶诺。")
        ]
    )

    public static let bachMinuetInG: MelodyDocument = makeSpecimen(
        title: "G大调小步舞曲 · 巴赫",
        subtitle: "BWV Anh.114 1725 公版 · 轻快三拍子舞步",
        category: "巴赫·古典名作",
        insight: "最清脆的入门曲：5 跳下 1 后一口气沿楼梯走到 5，跳两下 1 点地，再迈向高音 1↑——节奏感和音阶爬坡一次看清！",
        rootMIDI: 62,
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .feltWaltz,
        bpm: 112,
        steps: [
            (5, 0, 1.0), (1, 0, 0.5), (2, 0, 0.5), (3, 0, 0.5), (4, 0, 0.5),
            (5, 0, 1.0), (1, 0, 1.0), (1, 0, 1.0),
            (6, 0, 1.0), (4, 0, 0.5), (5, 0, 0.5), (6, 0, 0.5), (7, 0, 0.5),
            (1, 1, 1.0), (1, 0, 1.0), (1, 0, 1.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "楼梯起舞", caption: "1-2-3-4-5 连续上五级楼梯，再轻快点两下 1，像优雅行屈膝礼。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.52, badge: "推向高潮", caption: "4-5-6-7-1↑ 第二次爬得更高，冲到高音 1↑ 完成对称的乐句答句！")
        ]
    )

    public static let bachCelloSuite1Prelude: MelodyDocument = makeSpecimen(
        title: "无伴奏大提琴前奏曲 · 巴赫",
        subtitle: "巴赫 BWV 1007 约1720 公版 · 一人分饰两角的波浪",
        category: "巴赫·古典名作",
        insight: "只有一把大提琴却听出整个乐队？秘密就在 1→5→3 的宽幅波浪里：低音当和声根基，高音连成隐藏旋律！",
        rootMIDI: 55, // G3
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .pureChorale,
        voice: .singingCello,
        bpm: 96,
        steps: [
            (1, 0, 0.6), (5, 0, 0.6), (1, 1, 0.6), (7, 0, 0.6),
            (1, 1, 0.6), (5, 0, 0.6), (3, 0, 0.6), (5, 0, 0.6),
            (1, 0, 0.6), (6, 0, 0.6), (4, 0, 0.6), (3, 0, 0.6),
            (4, 0, 0.6), (6, 0, 0.6), (5, 0, 0.6), (1, 1, 1.8)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "大跳波浪", caption: "1→5→1↑ 在一把大提琴上画出宽阔浪峰，低音顺便托起高音旋律。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.44, badge: "暗潮回折", caption: "跃向 6·钵莫怀抱后轻轻滑回 3·拍咯，音色悄然转暖。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.67, badge: "扬帆登顶", caption: "沿 4-6-5 蓄力推向尾音高音 1↑，单声部也能听出山谷回响。")
        ]
    )

    public static let bachInventionDialogue: MelodyDocument = makeSpecimen(
        title: "二部创意曲 · 巴赫",
        subtitle: "巴赫 BWV 772 1723 公版 · 动机攀升与回声",
        category: "巴赫·古典名作",
        insight: "把 1-2-3-4-2-3-1 这短短 7 颗音当成积木，先在低处摆一遍，再搬到 5 号属音高处原样复制——作曲其实很像搭乐高！",
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .pureChorale,
        bpm: 96,
        steps: [
            (1, 0, 0.6), (2, 0, 0.6), (3, 0, 0.6), (4, 0, 0.6),
            (2, 0, 0.6), (3, 0, 0.6), (1, 0, 1.2),
            (5, 0, 0.6), (6, 0, 0.6), (7, 0, 0.6), (1, 1, 0.6),
            (6, 0, 0.6), (7, 0, 0.6), (5, 0, 1.8)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "乐高起步", caption: "1-2-3-4-2-3-1 七颗小积木在陶诺家门口搭出第一句轻快主题。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.47, badge: "属音攀高", caption: "把整套 5-6-7-1↑ 积木抬高五度原样复刻，像云朵回应山风。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.78, badge: "亮声落定", caption: "尾音停在 5·壳咯远望处，保留巴赫式的清醒对话空间。")
        ]
    )

    public static let pachelbelCanonGround: MelodyDocument = makeSpecimen(
        title: "D大调卡农 · 帕赫贝尔",
        subtitle: "帕赫贝尔 约1680 公版 · 流传三百年的黄金骨架",
        category: "巴赫·古典名作",
        insight: "3-2-1-7↓-6↓-5↓-6↓-7↓——这条稳步下沉再轻轻回扬的骨架，正是无数现代流行金曲背后的共同地基。",
        rootMIDI: 62, // D4
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .swanRipple,
        bpm: 80,
        steps: [
            (3, 0, 1.5), (2, 0, 1.5), (1, 0, 1.5), (7, -1, 1.5),
            (6, -1, 1.5), (5, -1, 1.5), (6, -1, 1.5), (7, -1, 1.5),
            (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "下行阶梯", caption: "3→2→1→7↓ 像沿着阳光照亮的石阶一步步往下漫步。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.41, badge: "黄金兜底", caption: "触底 6↓ 与 5↓ 后再折返 6↓-7↓，正是三百年流行金曲的共通骨架。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.78, badge: "归家定音", caption: "经过 7↓ 轻踮脚尖，最终稳稳落回 1·陶诺家中。")
        ]
    )

    public static let mozartTwinkleVariation: MelodyDocument = makeSpecimen(
        title: "小星星引力 · 莫扎特",
        subtitle: "莫扎特 K.265 1781 公版 · 五度大跳与级进回家",
        category: "巴赫·古典名作",
        insight: "最简单的旋律藏着最标准的引力法则：1→5 纯五度瞬间打开视野，6 往上一探立刻回 5，再沿 4-3-2-1 一步步走回家。",
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .pureChorale,
        bpm: 100,
        steps: [
            (1, 0, 1.0), (1, 0, 1.0), (5, 0, 1.0), (5, 0, 1.0),
            (6, 0, 1.0), (6, 0, 1.0), (5, 0, 2.0),
            (4, 0, 1.0), (4, 0, 1.0), (3, 0, 1.0), (3, 0, 1.0),
            (2, 0, 1.0), (2, 0, 1.0), (1, 0, 2.0)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "五度眨眼", caption: "1·陶诺一下跃上 5·壳咯，就像夜空里第一颗闪烁的星星。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.25, badge: "六级仰望", caption: "6·钵莫向上轻探一格再靠回 5·壳咯身旁，充满温柔张望。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.50, badge: "级进回家", caption: "4-4-3-3-2-2-1 沿着彩色阶梯一步步稳稳走回陶诺的家里。")
        ]
    )

    // MARK: - 三、印象 · 民族与夜曲（公版名曲）

    public static let dvorakGoingHome: MelodyDocument = makeSpecimen(
        title: "念故乡 · 德沃夏克",
        subtitle: "《自新大陆》第二乐章 1893 公版 · 治愈五声音阶",
        category: "印象·民族与夜曲",
        insight: "全曲只用 1-2-3-5 四只咩哞（避开紧绷的 4 和 7），却写出了全人类最催泪的乡愁——五声音阶也是东亚治愈电影配乐的灵魂！",
        rootMIDI: 61, // Db4
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .summerGlass,
        voice: .singingCello,
        bpm: 70,
        steps: [
            (3, 0, 1.5), (5, 0, 0.75), (5, 0, 1.75),
            (3, 0, 1.5), (2, 0, 0.75), (1, 0, 1.75),
            (2, 0, 1.0), (3, 0, 1.0), (5, 0, 1.0), (3, 0, 1.0), (2, 0, 2.0),
            (3, 0, 1.5), (5, 0, 0.75), (5, 0, 1.75),
            (3, 0, 1.5), (2, 0, 0.75), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "纯净五声", caption: "3→5→3→2→1，零半音冲突，听起来像黄昏田野吹来的暖风。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.45, badge: "悬停问句", caption: "乐句轻轻停在 2·豆叩上，像在远方停步回望家乡。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.74, badge: "温柔归家", caption: "同样旋律再唱一遍，这次稳稳落回 1·陶诺，泪点就在这一下！")
        ]
    )

    public static let debussyClairDeLune: MelodyDocument = makeSpecimen(
        title: "月光 · 德彪西",
        subtitle: "德彪西《贝加莫组曲》1890 公版 · 印象派月雾",
        category: "印象·民族与夜曲",
        insight: "德彪西不讲急促节拍，让高处的 1↑ 与 6 缓步滑落到 5 与 3，像月光透过云层一层层融在水里。",
        rootMIDI: 61, // Db4
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .swanRipple,
        bpm: 64,
        steps: [
            (1, 1, 1.75), (6, 0, 1.75), (5, 0, 1.0), (4, 0, 1.0), (5, 0, 1.5),
            (3, 0, 1.5), (2, 0, 1.0), (3, 0, 1.0), (2, 0, 1.25), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "月雾初落", caption: "高音 1↑ 与 6·钵莫缓步垂落，没有急躁节拍，像月光融进水雾。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.49, badge: "轻涟摇曳", caption: "3·拍咯与 2·豆叩轻换脚步，把湖面涟漪一圈圈往远处推开。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.78, badge: "入水静谧", caption: "末音轻停 1·陶诺家中，整片夜空如镜面般温柔静止。")
        ]
    )

    public static let debussyFlaxenHair: MelodyDocument = makeSpecimen(
        title: "亚麻色头发的少女 · 德彪西",
        subtitle: "德彪西《前奏曲》1910 公版 · 五声暖阳",
        category: "印象·民族与夜曲",
        insight: "从 6→3→2→1 的五声柔和弧线起步，清澈得像阳光照在金色麦田上，没有一丝沉重感。",
        rootMIDI: 61,
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .summerGlass,
        bpm: 72,
        steps: [
            (6, 0, 1.5), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 1.5),
            (2, 0, 1.0), (3, 0, 1.0), (6, 0, 1.5), (5, 0, 1.25),
            (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "五声晨光", caption: "6→3→2→1 起步没有半分沉重感，宛如朝阳照亮金色麦田。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.35, badge: "微风扬发", caption: "再由 2-3 轻抬到 6·钵莫与 5·壳咯，留住清晨轻盈呼吸。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.68, badge: "暖阳落怀", caption: "3→2→1 缓慢落定，画面暖融融地融入草坡光线里。")
        ]
    )

    public static let satieGymnopedieSeed: MelodyDocument = makeSpecimen(
        title: "吉诺佩蒂 No.1 · 萨蒂",
        subtitle: "萨蒂 1888 公版 · 三拍子留白美学",
        category: "印象·民族与夜曲",
        insight: "好的编曲一半是留白：每颗音珠拖出绵长余影，让左手的圆舞和弦在空隙里安静呼吸。",
        rootMIDI: 62,
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .feltWaltz,
        bpm: 72,
        steps: [
            (3, 0, 1.5), (5, 0, 1.5), (4, 0, 1.5), (3, 0, 1.5),
            (2, 0, 1.5), (1, 0, 1.5), (2, 0, 1.5), (3, 0, 1.5),
            (6, -1, 2.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "三拍留白", caption: "3-5-4-3 拖出绵长圆舞弧线，让音符之间的空气自己唱歌。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.35, badge: "轻步巡游", caption: "2-1-2-3 随三拍子缓慢踱行，不慌不忙走出极简留白之美。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.70, badge: "深谷回响", caption: "低音 6↓ 深深停顿两拍半再回 1·陶诺，余韵比声响更久。")
        ]
    )

    public static let beethovenMoonlight1: MelodyDocument = makeSpecimen(
        title: "月光奏鸣曲 · 贝多芬",
        subtitle: "贝多芬 Op.27 No.2 1801 公版 · 深邃小调独白",
        category: "印象·民族与夜曲",
        insight: "上方旋律几乎只在同一颗 5 上低声重复，真正推动情绪前进的是底下悄悄滑动的小调水波和弦！",
        rootMIDI: 61,
        mode: .wistfulMinor,
        harmony: .filmGlow,
        texture: .swanRipple,
        bpm: 64,
        steps: [
            (5, 0, 1.75), (5, 0, 0.75), (5, 0, 2.0),
            (6, 0, 1.75), (6, 0, 1.75),
            (5, 0, 1.25), (4, 0, 1.25), (3, 0, 1.5), (2, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "同音独白", caption: "连续三声 5·壳咯克制不动，全靠底下小调水波悄悄推进情绪。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.28, badge: "沉吟微叹", caption: "悄悄推向 6·钵莫驻足回望，仿佛月夜窗前的无声轻叹。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.50, badge: "五级归巢", caption: "5-4-3-2-1 随夜色一口气滑落，稳稳落回小调中心。")
        ]
    )

    public static let beethovenEliseResolve: MelodyDocument = makeSpecimen(
        title: "致爱丽丝 · 贝多芬",
        subtitle: "贝多芬 WoO 59 1810 公版 · 灵巧摇摆与分解托起",
        category: "印象·民族与夜曲",
        insight: "高处两颗相邻音珠轻轻往复摇摆制造悬念，再由分解三和弦自下而上托起，稳稳落回主音。",
        rootMIDI: 57, // A3
        mode: .wistfulMinor,
        harmony: .filmGlow,
        texture: .feltWaltz,
        bpm: 94,
        steps: [
            (5, 0, 0.6), (4, 0, 0.6), (5, 0, 0.6), (4, 0, 0.6),
            (5, 0, 0.6), (2, 0, 0.6), (4, 0, 0.6), (3, 0, 0.6), (1, 0, 1.6),
            (3, -1, 0.6), (6, -1, 0.6), (1, 0, 0.6), (2, 0, 1.6),
            (3, 0, 0.6), (2, 0, 0.6), (1, 0, 2.0)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "灵巧摇摆", caption: "高处 5 与 4 连续轻巧碰面摇摆，像手指在黑键边缘跳舞。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.49, badge: "分解托举", caption: "从低处 3↓-6↓-1 一路向上托起，把小调悬念翻出温柔回响。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.75, badge: "轻落收拍", caption: "3-2-1 紧凑收住尾音，利落又充满古典戏剧魅力。")
        ]
    )

    // MARK: - 四、原创夏日治愈与现代技法（8 首 100% 原创，零版权风险）

    public static let summerSuspension: MelodyDocument = makeSpecimen(
        title: "夏风四度（原创）",
        subtitle: "原创现代治愈风 · 4-5-3-6 透明加九悬浮进行",
        category: "原创夏日治愈风",
        insight: "想写出宫崎骏动画般的夏日治愈感？试试这套完全公开的技法：用「夏日清风」add9 透明钢琴 + 4-5-3-6 悬浮进行，旋律停在 6·钵莫生出淡淡青春怀旧。",
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .summerGlass,
        bpm: 84,
        steps: [
            (4, 0, 1.5), (5, 0, 1.0), (3, 0, 1.5), (6, 0, 2.0),
            (4, 0, 1.0), (5, 0, 1.0), (1, 1, 1.5), (7, 0, 1.0), (5, 0, 1.5),
            (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (5, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "夏日悬浮", caption: "从 4·呜嘟起步而不从 1 起步，立刻营造出微风拂面的开阔感！"),
            GuidedStoryMoment(id: 1, timeFraction: 0.42, badge: "玻璃泛音", caption: "跃上高音 1↑ 时，高音区钢片琴星光泛音点亮整个天空。")
        ]
    )

    public static let teaHousePentatonic: MelodyDocument = makeSpecimen(
        title: "晴空草坡（原创）",
        subtitle: "原创东亚电影治愈风 · 五声音阶 + 四度透明钢琴",
        category: "原创夏日治愈风",
        insight: "东亚治愈配乐最常用的组合：右手只用温润的 1-2-3-5-6 五声音阶画弧线，左手用开放九度透明钢琴，怎么弹都清澈动听！",
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .summerGlass,
        bpm: 78,
        steps: [
            (5, 0, 1.5), (6, 0, 1.0), (1, 1, 2.0),
            (6, 0, 1.0), (5, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
            (1, 0, 1.5), (2, 0, 1.0), (3, 0, 1.5), (5, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "登坡望远", caption: "5-6 借微风一口气跃上高音 1↑，五声音阶清澈如洗。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.26, badge: "林间滑步", caption: "沿着 6-5-3-2 五声草坡轻盈滑落，零半音冲突最松弛。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.54, badge: "归回草坡", caption: "1-2-3-5 绕出一圈暖阳弧线，安稳落回草坡原点。")
        ]
    )

    public static let tinkiResolution: MelodyDocument = makeSpecimen(
        title: "叮尖回家（原创）",
        subtitle: "原创乐理示范 · 导音 7→1↑ 张力与释然",
        category: "原创夏日治愈风",
        insight: "盯住 7·叮尖亮起的那一刻——它踮着脚尖拉紧半音虚线，下一拍落到高音 1↑ 时瞬间舒展涟漪。",
        mode: .brightMajor,
        harmony: .filmGlow,
        texture: .summerGlass,
        bpm: 80,
        steps: [
            (1, 0, 1.5), (3, 0, 1.0), (5, 0, 1.5),
            (4, 0, 1.5), (3, 0, 1.5),
            (6, 0, 1.5), (7, 0, 2.25), (1, 1, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "三和弦站台", caption: "1-3-5 稳稳立在起跑线，声音像风筝还握在手里。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.30, badge: "微步过渡", caption: "4 跳 3 轻晃一下重心，悄悄为最后的升空蓄力。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.53, badge: "导音飞升", caption: "7·叮尖踮起脚尖拉紧半音弦，下一刻冲上高音 1↑ 瞬间释怀！")
        ]
    )

    public static let rainyChromaticWalk: MelodyDocument = makeSpecimen(
        title: "雨后街角（原创）",
        subtitle: "原创微酸小调 · 3·拍咯降半音的电影氛围",
        category: "原创夏日治愈风",
        insight: "切到微酸小调后，3·拍咯的阶梯真实下移半格；播放时试着点底部切回大调，亲耳听同一段旋律瞬间放晴。",
        mode: .wistfulMinor,
        harmony: .filmGlow,
        texture: .swanRipple,
        bpm: 82,
        steps: [
            (1, 0, 1.25), (2, 0, 0.75), (3, 0, 2.0),
            (5, 0, 1.25), (4, 0, 0.75), (3, 0, 1.5), (2, 0, 1.0),
            (6, -1, 1.5), (7, -1, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "雨檐落座", caption: "1-2 轻踩进降半音的小调 3·拍咯，细雨落在街道石板上。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.29, badge: "湿润下行", caption: "5-4-3-2 带着清透水色缓缓下滑，小调光晕慢慢晕开。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.61, badge: "屋檐亮灯", caption: "经过低音 6↓ 与 7↓ 折回 1·陶诺，窗内正好亮起暖灯。")
        ]
    )

    public static let midnightCoastCityPop: MelodyDocument = makeSpecimen(
        title: "午夜海岸（原创）",
        subtitle: "原创都市流行 · 2-5-1 顺滑转弯",
        category: "原创夏日治愈风",
        insight: "从 2·豆叩滑向 5·壳咯再落回 1·陶诺——2-5-1 是现代流行与爵士最经典的丝滑转弯。",
        mode: .brightMajor,
        harmony: .filmGlow,
        texture: .summerGlass,
        bpm: 92,
        steps: [
            (2, 0, 1.0), (4, 0, 1.0), (6, 0, 1.5), (5, 0, 1.5),
            (7, 0, 1.0), (2, 1, 1.0), (1, 1, 1.5), (3, 0, 1.5),
            (2, 0, 1.0), (5, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "夜风起步", caption: "2-4-6-5 从容划出斜线起步，立刻带出夜间海岸律动。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.33, badge: "高台拐弯", caption: "跃过 7-2↑-1↑ 霓虹色彩拐点，海面波光随和弦晃开。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.67, badge: "二五一归位", caption: "经典的 2→5→1 丝滑转弯稳稳刹停回陶诺港湾。")
        ]
    )

    public static let bittersweetDaylight: MelodyDocument = makeSpecimen(
        title: "白昼微酸（原创）",
        subtitle: "原创大调余韵 · 结尾不回 1 而落在 6",
        category: "原创夏日治愈风",
        insight: "明明是晴朗大调，结尾却不回 1·陶诺，而是轻轻落在 6·钵莫怀里，留下一丝没说完的余味。",
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .summerGlass,
        bpm: 86,
        steps: [
            (1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.5), (5, 0, 1.5),
            (6, 0, 1.0), (5, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
            (3, 0, 1.0), (5, 0, 1.0), (6, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "晴日行进", caption: "1-2-3-5 明亮启程，就像午后踩在太阳晒暖的街道上。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.34, badge: "回望驻足", caption: "6-5-3-2 放慢脚步回头张望，甜味里带着一点青春怀旧。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.69, badge: "停在六级", caption: "结尾特意不回 1·陶诺，轻轻停在 6·钵莫怀里留下余韵。")
        ]
    )

    public static let teardropSlashBass: MelodyDocument = makeSpecimen(
        title: "慢行楼梯（原创）",
        subtitle: "原创下行低音 · 旋律不动、和弦下沉",
        category: "原创夏日治愈风",
        insight: "上方旋律绕着 5 和 3 轻轻盘旋，底下的和弦光带一步步往下走楼梯，情绪在不知不觉里沉了下来。",
        mode: .brightMajor,
        harmony: .feltSun,
        texture: .feltWaltz,
        bpm: 78,
        steps: [
            (5, 0, 1.5), (3, 0, 1.5), (5, 0, 1.0), (7, 0, 1.5),
            (5, 0, 1.5), (6, 0, 1.5), (4, 0, 1.5), (3, 0, 1.5),
            (2, 0, 1.5), (5, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "高处轻旋", caption: "上方 5-3-5-7 轻轻盘旋停驻，仿佛雨前静止的暖云。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.32, badge: "楼梯下沉", caption: "5-6-4-3 配上底下逐格下沉的斜杠和弦，心事逐渐变深。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.68, badge: "归于平静", caption: "经过 2→5 短暂托起后，安稳落回 1·陶诺终点。")
        ]
    )

    public static let stardustCounterpoint: MelodyDocument = makeSpecimen(
        title: "星尘对话（原创）",
        subtitle: "原创高低八度问答 · 单旋律也能听出空间感",
        category: "原创夏日治愈风",
        insight: "高音区的问句与中音区的答句彼此接力，让单条旋律线也听得出两个人对话的立体感。",
        mode: .brightMajor,
        harmony: .clearWater,
        texture: .summerGlass,
        bpm: 84,
        steps: [
            (1, 1, 1.0), (7, 0, 1.0), (5, 0, 1.5),
            (1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.5),
            (6, 0, 1.0), (5, 0, 1.0), (4, 0, 1.0), (3, 0, 1.5),
            (2, 0, 1.5), (1, 0, 2.5)
        ],
        guided: [
            GuidedStoryMoment(id: 0, timeFraction: 0.0, badge: "高空发问", caption: "1↑-7-5 先从高八度轻声抛出一句清亮问候。"),
            GuidedStoryMoment(id: 1, timeFraction: 0.23, badge: "中音回应", caption: "低八度的 1-2-3 紧接着温柔接话，唱出空间问答感。"),
            GuidedStoryMoment(id: 2, timeFraction: 0.45, badge: "携手合鸣", caption: "6-5-4-3 并肩下落后经 2→1 会合，像星空与草地对谈。")
        ]
    )

    // MARK: - Builder

    private static func makeSpecimen(
        title: String,
        subtitle: String,
        category: String,
        insight: String,
        rootMIDI: Int = 60,
        mode: ScaleMode,
        harmony: HarmonyProfile,
        texture: AccompanimentTexture,
        voice: MelodyVoice = .concertPiano,
        bpm: Double,
        steps: [(Int, Int, Double)],
        guided: [GuidedStoryMoment]? = nil
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
            rootMIDI: rootMIDI,
            scaleMode: mode,
            harmonyProfile: harmony,
            grooveStrength: 1.0,
            estimatedBPM: bpm,
            notes: beads,
            isSpecimen: true,
            specimenCategory: category,
            composerInsight: insight,
            preferredTexture: texture,
            preferredVoice: voice,
            guidedMoments: guided
        )
    }
}
