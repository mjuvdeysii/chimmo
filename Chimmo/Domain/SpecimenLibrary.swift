import Foundation

/// 28-piece public-domain classical & original acoustic chamber specimen library,
/// localized dynamically via Localizable.xcstrings (`spec_<keyPrefix>_{title,sub,cat,insight}`).
public enum SpecimenLibrary {

    public static var all: [MelodyDocument] {
        [
            // I. Romantic Classics (7 Public Domain)
            saintSaensTheSwan,
            lisztLiebestraum,
            lisztConsolation3,
            lisztCampanellaTheme,
            tchaikovskySwanLake,
            chopinNocturneOp9No2,
            schubertSerenade,

            // II. Baroque & Classical Masters (7 Public Domain)
            bachPreludeSeed,
            bachAirOnGString,
            bachMinuetInG,
            bachCelloSuite1Prelude,
            bachInventionDialogue,
            pachelbelCanonGround,
            mozartTwinkleVariation,

            // III. Impressionism, Nocturnes & Sonatas (6 Public Domain)
            dvorakGoingHome,
            debussyClairDeLune,
            debussyFlaxenHair,
            satieGymnopedieSeed,
            beethovenMoonlight1,
            beethovenEliseResolve,

            // IV. 100% Original Acoustic Atelier Studies (8 Originals)
            summerSuspension,
            teaHousePentatonic,
            tinkiResolution,
            rainyChromaticWalk,
            midnightCoastCityPop,
            bittersweetDaylight,
            teardropSlashBass,
            stardustCounterpoint
        ]
    }

    // MARK: - I. Romantic Classics

    public static var saintSaensTheSwan: MelodyDocument {
        makeSpecimen(
            keyPrefix: "swan",
            defaultTitle: "天鹅 · 圣桑",
            defaultSubtitle: "圣桑《动物狂欢节》1886 公版 · 流动水波与深情大跳",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "左手用细腻的水波琵音铺开镜面湖水，大提琴先从高处 1↑→7→3 滑入湖心，再从 4→5→6 缓缓扬起飞向高音 1↑。",
            rootMIDI: 55,
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
            ]
        )
    }

    public static var lisztLiebestraum: MelodyDocument {
        makeSpecimen(
            keyPrefix: "liebestraum",
            defaultTitle: "爱之梦 · 李斯特",
            defaultSubtitle: "李斯特《爱之梦》No.3 1850 公版 · 六度深情仰望",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "开头从低处 5↓ 一跃大跳六度到 3·拍咯，反复轻唤同一颗音后，轻轻叹息落回 1·陶诺，像在夜风里倾诉心事。",
            rootMIDI: 56,
            mode: .brightMajor,
            harmony: .filmGlow,
            texture: .swanRipple,
            bpm: 72,
            steps: [
                (5, -1, 1.0), (3, 0, 1.5), (3, 0, 0.75), (3, 0, 0.75),
                (3, 0, 1.0), (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 1.5),
                (5, -1, 1.0), (4, 0, 1.5), (4, 0, 0.75), (5, 0, 0.75),
                (6, 0, 1.25), (5, 0, 1.0), (3, 0, 1.25), (2, 0, 1.0), (1, 0, 2.25)
            ]
        )
    }

    public static var lisztConsolation3: MelodyDocument {
        makeSpecimen(
            keyPrefix: "consolation3",
            defaultTitle: "安慰曲 · 李斯特",
            defaultSubtitle: "李斯特《安慰曲》No.3 1850 公版 · 如歌夜曲",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "只在 5-3-2-1 之间像轻抚琴键般歌唱，底下的水波琵音让每个长音都泛着柔和微光。",
            rootMIDI: 61,
            mode: .brightMajor,
            harmony: .clearWater,
            texture: .swanRipple,
            bpm: 64,
            steps: [
                (5, 0, 2.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.0),
                (6, -1, 1.0), (1, 0, 1.0), (2, 0, 1.5), (3, 0, 1.5),
                (5, 0, 2.0), (6, 0, 1.0), (5, 0, 1.0), (4, 0, 1.0), (3, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var lisztCampanellaTheme: MelodyDocument {
        makeSpecimen(
            keyPrefix: "campanella",
            defaultTitle: "钟 · 李斯特",
            defaultSubtitle: "李斯特《帕格尼尼练习曲·钟》1851 公版 · 灵动铃音",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "小调里的钟声跳跃：高处的 5·壳咯像清脆银铃反复敲响，另一条声音在下面灵巧穿梭。",
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
            ]
        )
    }

    public static var tchaikovskySwanLake: MelodyDocument {
        makeSpecimen(
            keyPrefix: "swan_lake",
            defaultTitle: "天鹅湖 · 柴可夫斯基",
            defaultSubtitle: "柴可夫斯基《天鹅湖》场景主题 1876 公版 · 宿命小调",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "用微酸小调 5→1-2-3-4-5 勾勒出月夜下的宿命感，大提琴线条绵长深沉。",
            rootMIDI: 59,
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
            ]
        )
    }

    public static var chopinNocturneOp9No2: MelodyDocument {
        makeSpecimen(
            keyPrefix: "chopin_nocturne",
            defaultTitle: "降E大调夜曲 · 肖邦",
            defaultSubtitle: "肖邦 Op.9 No.2 1832 公版 · 浪漫派圆舞夜色",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "圆舞呼吸左手伴奏：一拍沉稳低音，两拍轻柔上浮，托着右手 5↓→3 的大六度优雅起飞。",
            rootMIDI: 63,
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .feltWaltz,
            bpm: 74,
            steps: [
                (5, -1, 1.0), (3, 0, 2.0), (2, 0, 0.75), (3, 0, 0.75), (2, 0, 0.75), (1, 0, 1.5),
                (5, -1, 1.0), (3, 0, 1.0), (1, 1, 2.0), (7, 0, 0.75), (6, 0, 0.75), (5, 0, 1.5),
                (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.5)
            ]
        )
    }

    public static var schubertSerenade: MelodyDocument {
        makeSpecimen(
            keyPrefix: "schubert_serenade",
            defaultTitle: "小夜曲 · 舒伯特",
            defaultSubtitle: "舒伯特《天鹅之歌》小夜曲 1828 公版 · 窗下叹息",
            era: .romantic,
            defaultCategory: "圣桑·李斯特·浪漫派",
            defaultInsight: "三个快音轻轻一转再向上仰起（5-6-5→1↑），像在夜色窗下欲言又止的轻声问候。",
            rootMIDI: 62,
            mode: .wistfulMinor,
            harmony: .filmGlow,
            texture: .feltWaltz,
            bpm: 82,
            steps: [
                (5, 0, 0.5), (6, 0, 0.5), (5, 0, 0.5), (1, 1, 1.5), (5, 0, 1.25),
                (4, 0, 0.5), (5, 0, 0.5), (4, 0, 0.5), (6, 0, 1.5), (4, 0, 1.25),
                (3, 0, 1.0), (5, 0, 1.0), (4, 0, 0.75), (3, 0, 0.75), (2, 0, 1.0), (1, 0, 2.5)
            ]
        )
    }

    // MARK: - II. Baroque & Classical Masters

    public static var bachPreludeSeed: MelodyDocument {
        makeSpecimen(
            keyPrefix: "bach_prelude",
            defaultTitle: "C大调前奏曲 · 巴赫",
            defaultSubtitle: "巴赫 BWV 846 1722 公版 · 黄金和弦阶梯",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "把和弦里的音一颗颗拆开往上爬（1-3-5-1↑），像晶莹的水晶楼梯。",
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .pureChorale,
            bpm: 104,
            steps: [
                (1, 0, 0.75), (3, 0, 0.75), (5, 0, 0.75), (1, 1, 0.75),
                (2, 0, 0.75), (4, 0, 0.75), (6, 0, 0.75), (1, 1, 0.75),
                (7, -1, 0.75), (2, 0, 0.75), (5, 0, 0.75), (7, 0, 0.75),
                (1, 0, 0.75), (3, 0, 0.75), (5, 0, 0.75), (1, 1, 2.0)
            ]
        )
    }

    public static var bachAirOnGString: MelodyDocument {
        makeSpecimen(
            keyPrefix: "bach_air",
            defaultTitle: "G弦上的咏叹调 · 巴赫",
            defaultSubtitle: "巴赫 BWV 1068 约1730 公版 · 长音如丝的呼吸",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "开头用一颗极长的 3·拍咯定住时光，随后 4-2-7↓-1 像丝绸般蜿蜒落下。",
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .swanRipple,
            voice: .singingCello,
            bpm: 64,
            steps: [
                (3, 0, 3.0), (3, 0, 0.75), (4, 0, 0.75), (2, 0, 1.0),
                (7, -1, 1.0), (1, 0, 1.25), (6, -1, 1.0), (5, -1, 1.5),
                (4, 0, 1.5), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 1.0), (7, -1, 1.0), (1, 0, 2.5)
            ]
        )
    }

    public static var bachMinuetInG: MelodyDocument {
        makeSpecimen(
            keyPrefix: "bach_minuet",
            defaultTitle: "G大调小步舞曲 · 巴赫",
            defaultSubtitle: "BWV Anh.114 1725 公版 · 轻快三拍子舞步",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "5 跳下 1 后一口气沿楼梯走到 5，跳两下 1 点地，再迈向高音 1↑——节奏明快对称。",
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
            ]
        )
    }

    public static var bachCelloSuite1Prelude: MelodyDocument {
        makeSpecimen(
            keyPrefix: "bach_cello",
            defaultTitle: "无伴奏大提琴前奏曲 · 巴赫",
            defaultSubtitle: "巴赫 BWV 1007 约1720 公版 · 一人分饰两角的波浪",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "在 1→5→3 的宽幅波浪里，低音当和声根基，高音连成隐藏旋律。",
            rootMIDI: 55,
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
            ]
        )
    }

    public static var bachInventionDialogue: MelodyDocument {
        makeSpecimen(
            keyPrefix: "bach_invention",
            defaultTitle: "二部创意曲 · 巴赫",
            defaultSubtitle: "巴赫 BWV 772 1723 公版 · 动机攀升与回声",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "把 1-2-3-4-2-3-1 短动机当成木积木，先在低处摆一遍，再搬到属音 5 高处原样复刻。",
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .pureChorale,
            bpm: 96,
            steps: [
                (1, 0, 0.6), (2, 0, 0.6), (3, 0, 0.6), (4, 0, 0.6),
                (2, 0, 0.6), (3, 0, 0.6), (1, 0, 1.2),
                (5, 0, 0.6), (6, 0, 0.6), (7, 0, 0.6), (1, 1, 0.6),
                (6, 0, 0.6), (7, 0, 0.6), (5, 0, 1.8)
            ]
        )
    }

    public static var pachelbelCanonGround: MelodyDocument {
        makeSpecimen(
            keyPrefix: "pachelbel_canon",
            defaultTitle: "D大调卡农 · 帕赫贝尔",
            defaultSubtitle: "帕赫贝尔 约1680 公版 · 流传三百年的黄金骨架",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "3-2-1-7↓-6↓-5↓-6↓-7↓——稳步下沉再轻轻回扬的骨架，古典与现代共鸣的经典地基。",
            rootMIDI: 62,
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .swanRipple,
            bpm: 80,
            steps: [
                (3, 0, 1.5), (2, 0, 1.5), (1, 0, 1.5), (7, -1, 1.5),
                (6, -1, 1.5), (5, -1, 1.5), (6, -1, 1.5), (7, -1, 1.5),
                (1, 0, 2.5)
            ]
        )
    }

    public static var mozartTwinkleVariation: MelodyDocument {
        makeSpecimen(
            keyPrefix: "mozart_twinkle",
            defaultTitle: "小星星引力 · 莫扎特",
            defaultSubtitle: "莫扎特 K.265 1781 公版 · 五度大跳与级进回家",
            era: .classical,
            defaultCategory: "巴赫·古典名作",
            defaultInsight: "1→5 纯五度瞬间打开视野，6 往上一探立刻回 5，再沿 4-3-2-1 一步步走回家。",
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .pureChorale,
            bpm: 100,
            steps: [
                (1, 0, 1.0), (1, 0, 1.0), (5, 0, 1.0), (5, 0, 1.0),
                (6, 0, 1.0), (6, 0, 1.0), (5, 0, 2.0),
                (4, 0, 1.0), (4, 0, 1.0), (3, 0, 1.0), (3, 0, 1.0),
                (2, 0, 1.0), (2, 0, 1.0), (1, 0, 2.0)
            ]
        )
    }

    // MARK: - III. Impressionism, Nocturnes & Sonatas

    public static var dvorakGoingHome: MelodyDocument {
        makeSpecimen(
            keyPrefix: "dvorak_home",
            defaultTitle: "念故乡 · 德沃夏克",
            defaultSubtitle: "《自新大陆》第二乐章 1893 公版 · 柔和五声音阶",
            era: .romantic,
            defaultCategory: "印象·民族与夜曲",
            defaultInsight: "全曲只用 1-2-3-5 四颗核心音高，避开紧绷的 4 和 7，写出辽阔温暖的田野夜色。",
            rootMIDI: 61,
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
            ]
        )
    }

    public static var debussyClairDeLune: MelodyDocument {
        makeSpecimen(
            keyPrefix: "debussy_clair",
            defaultTitle: "月光 · 德彪西",
            defaultSubtitle: "德彪西《贝加莫组曲》1890 公版 · 印象派月雾",
            era: .romantic,
            defaultCategory: "印象·民族与夜曲",
            defaultInsight: "高处的 1↑ 与 6 缓步滑落到 5 与 3，像月光透过云层一层层融在水里。",
            rootMIDI: 61,
            mode: .brightMajor,
            harmony: .clearWater,
            texture: .swanRipple,
            bpm: 64,
            steps: [
                (1, 1, 1.75), (6, 0, 1.75), (5, 0, 1.0), (4, 0, 1.0), (5, 0, 1.5),
                (3, 0, 1.5), (2, 0, 1.0), (3, 0, 1.0), (2, 0, 1.25), (1, 0, 2.5)
            ]
        )
    }

    public static var debussyFlaxenHair: MelodyDocument {
        makeSpecimen(
            keyPrefix: "debussy_flaxen",
            defaultTitle: "亚麻色头发的少女 · 德彪西",
            defaultSubtitle: "德彪西《前奏曲》1910 公版 · 五声暖阳",
            era: .romantic,
            defaultCategory: "印象·民族与夜曲",
            defaultInsight: "从 6→3→2→1 的五声柔和弧线起步，清澈得像阳光照在金色麦田上。",
            rootMIDI: 61,
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .summerGlass,
            bpm: 72,
            steps: [
                (6, 0, 1.5), (3, 0, 1.0), (2, 0, 1.0), (1, 0, 1.5),
                (2, 0, 1.0), (3, 0, 1.0), (6, 0, 1.5), (5, 0, 1.25),
                (3, 0, 1.0), (2, 0, 1.0), (1, 0, 2.5)
            ]
        )
    }

    public static var satieGymnopedieSeed: MelodyDocument {
        makeSpecimen(
            keyPrefix: "satie_gymnopedie",
            defaultTitle: "吉诺佩蒂 No.1 · 萨蒂",
            defaultSubtitle: "萨蒂 1888 公版 · 三拍子留白美学",
            era: .romantic,
            defaultCategory: "印象·民族与夜曲",
            defaultInsight: "好的编曲一半是留白：每颗音珠拖出绵长余影，让圆舞和弦在空隙里安静呼吸。",
            rootMIDI: 62,
            mode: .brightMajor,
            harmony: .clearWater,
            texture: .feltWaltz,
            bpm: 72,
            steps: [
                (3, 0, 1.5), (5, 0, 1.5), (4, 0, 1.5), (3, 0, 1.5),
                (2, 0, 1.5), (1, 0, 1.5), (2, 0, 1.5), (3, 0, 1.5),
                (6, -1, 2.5), (1, 0, 2.5)
            ]
        )
    }

    public static var beethovenMoonlight1: MelodyDocument {
        makeSpecimen(
            keyPrefix: "beethoven_moonlight",
            defaultTitle: "月光奏鸣曲 · 贝多芬",
            defaultSubtitle: "贝多芬 Op.27 No.2 1801 公版 · 深邃小调独白",
            era: .romantic,
            defaultCategory: "印象·民族与夜曲",
            defaultInsight: "上方旋律几乎只在同一颗 5 上低声重复，靠底下悄悄滑动的小调水波推动情绪前进。",
            rootMIDI: 61,
            mode: .wistfulMinor,
            harmony: .filmGlow,
            texture: .swanRipple,
            bpm: 64,
            steps: [
                (5, 0, 1.75), (5, 0, 0.75), (5, 0, 2.0),
                (6, 0, 1.75), (6, 0, 1.75),
                (5, 0, 1.25), (4, 0, 1.25), (3, 0, 1.5), (2, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var beethovenEliseResolve: MelodyDocument {
        makeSpecimen(
            keyPrefix: "beethoven_elise",
            defaultTitle: "致爱丽丝 · 贝多芬",
            defaultSubtitle: "贝多芬 WoO 59 1810 公版 · 灵巧摇摆与分解托起",
            era: .romantic,
            defaultCategory: "印象·民族与夜曲",
            defaultInsight: "高处两颗相邻音珠轻轻往复摇摆制造悬念，再由分解三和弦自下而上托起归主。",
            rootMIDI: 57,
            mode: .wistfulMinor,
            harmony: .filmGlow,
            texture: .feltWaltz,
            bpm: 94,
            steps: [
                (5, 0, 0.6), (4, 0, 0.6), (5, 0, 0.6), (4, 0, 0.6),
                (5, 0, 0.6), (2, 0, 0.6), (4, 0, 0.6), (3, 0, 0.6), (1, 0, 1.6),
                (3, -1, 0.6), (6, -1, 0.6), (1, 0, 0.6), (2, 0, 1.6),
                (3, 0, 0.6), (2, 0, 0.6), (1, 0, 2.0)
            ]
        )
    }

    // MARK: - IV. 100% Original Acoustic Atelier Studies

    public static var summerSuspension: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_summer",
            defaultTitle: "夏风四度（原创）",
            defaultSubtitle: "原创现代舒缓风 · 4-5-3-6 透明加九悬浮进行",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "用透明 add9 钢琴搭配 4-5-3-6 悬浮进行，旋律停在 6·钵莫生出柔和微光余韵。",
            mode: .brightMajor,
            harmony: .clearWater,
            texture: .summerGlass,
            bpm: 84,
            steps: [
                (4, 0, 1.5), (5, 0, 1.0), (3, 0, 1.5), (6, 0, 2.0),
                (4, 0, 1.0), (5, 0, 1.0), (1, 1, 1.5), (7, 0, 1.0), (5, 0, 1.5),
                (4, 0, 1.0), (3, 0, 1.0), (2, 0, 1.0), (5, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var teaHousePentatonic: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_slope",
            defaultTitle: "晴空草坡（原创）",
            defaultSubtitle: "原创东亚电影舒缓风 · 五声音阶 + 四度透明钢琴",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "只用温润的 1-2-3-5-6 五声音阶画弧线，配以开放九度透明钢琴，透亮清澈。",
            mode: .brightMajor,
            harmony: .clearWater,
            texture: .summerGlass,
            bpm: 78,
            steps: [
                (5, 0, 1.5), (6, 0, 1.0), (1, 1, 2.0),
                (6, 0, 1.0), (5, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
                (1, 0, 1.5), (2, 0, 1.0), (3, 0, 1.5), (5, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var tinkiResolution: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_tinki",
            defaultTitle: "叮尖回家（原创）",
            defaultSubtitle: "原创声学示范 · 导音 7→1↑ 张力与释然",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "7·叮尖踮起脚尖拉紧半音张力，下一拍落到高音 1↑ 时瞬间舒展和声涟漪。",
            mode: .brightMajor,
            harmony: .filmGlow,
            texture: .summerGlass,
            bpm: 80,
            steps: [
                (1, 0, 1.5), (3, 0, 1.0), (5, 0, 1.5),
                (4, 0, 1.5), (3, 0, 1.5),
                (6, 0, 1.5), (7, 0, 2.25), (1, 1, 2.5)
            ]
        )
    }

    public static var rainyChromaticWalk: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_rain",
            defaultTitle: "雨后街角（原创）",
            defaultSubtitle: "原创微酸小调 · 3·拍咯降半音的电影氛围",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "降半音的小调 3·拍咯伴随 5-4-3-2 湿润下行，带来安静绵长的雨夜色彩。",
            mode: .wistfulMinor,
            harmony: .filmGlow,
            texture: .swanRipple,
            bpm: 82,
            steps: [
                (1, 0, 1.25), (2, 0, 0.75), (3, 0, 2.0),
                (5, 0, 1.25), (4, 0, 0.75), (3, 0, 1.5), (2, 0, 1.0),
                (6, -1, 1.5), (7, -1, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var midnightCoastCityPop: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_coast",
            defaultTitle: "午夜海岸（原创）",
            defaultSubtitle: "原创都市夜色 · 2-5-1 顺滑转弯",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "从 2·豆叩滑向 5·壳咯再落回 1·陶诺，展现现代都市和声的丝滑转弯。",
            mode: .brightMajor,
            harmony: .filmGlow,
            texture: .summerGlass,
            bpm: 92,
            steps: [
                (2, 0, 1.0), (4, 0, 1.0), (6, 0, 1.5), (5, 0, 1.5),
                (7, 0, 1.0), (2, 1, 1.0), (1, 1, 1.5), (3, 0, 1.5),
                (2, 0, 1.0), (5, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var bittersweetDaylight: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_bittersweet",
            defaultTitle: "白昼微酸（原创）",
            defaultSubtitle: "原创大调余韵 · 结尾不回 1 而落在 6",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "晴朗大调结尾刻意不回 1·陶诺，轻轻停在 6·钵莫怀里留下悠长余韵。",
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .summerGlass,
            bpm: 86,
            steps: [
                (1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.5), (5, 0, 1.5),
                (6, 0, 1.0), (5, 0, 1.0), (3, 0, 1.5), (2, 0, 1.5),
                (3, 0, 1.0), (5, 0, 1.0), (6, 0, 2.5)
            ]
        )
    }

    public static var teardropSlashBass: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_stairs",
            defaultTitle: "慢行楼梯（原创）",
            defaultSubtitle: "原创下行低音 · 旋律不动、和弦下沉",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "上方旋律绕着 5 和 3 轻轻盘旋，底下的和弦光带一步步往下沉。",
            mode: .brightMajor,
            harmony: .feltSun,
            texture: .feltWaltz,
            bpm: 78,
            steps: [
                (5, 0, 1.5), (3, 0, 1.5), (5, 0, 1.0), (7, 0, 1.5),
                (5, 0, 1.5), (6, 0, 1.5), (4, 0, 1.5), (3, 0, 1.5),
                (2, 0, 1.5), (5, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    public static var stardustCounterpoint: MelodyDocument {
        makeSpecimen(
            keyPrefix: "orig_stardust",
            defaultTitle: "星尘对话（原创）",
            defaultSubtitle: "原创高低八度问答 · 单旋律也能听出空间感",
            era: .original,
            defaultCategory: "原创舒缓风",
            defaultInsight: "高音区的问句与中音区的答句彼此接力，营造空间对谈般的轻盈立体感。",
            mode: .brightMajor,
            harmony: .clearWater,
            texture: .summerGlass,
            bpm: 84,
            steps: [
                (1, 1, 1.0), (7, 0, 1.0), (5, 0, 1.5),
                (1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.5),
                (6, 0, 1.0), (5, 0, 1.0), (4, 0, 1.0), (3, 0, 1.5),
                (2, 0, 1.5), (1, 0, 2.5)
            ]
        )
    }

    // MARK: - Builder

    private static func makeSpecimen(
        keyPrefix: String,
        defaultTitle: String,
        defaultSubtitle: String,
        era: SpecimenEra,
        defaultCategory: String,
        defaultInsight: String,
        rootMIDI: Int = 60,
        mode: ScaleMode,
        harmony: HarmonyProfile,
        texture: AccompanimentTexture,
        voice: MelodyVoice = .concertPiano,
        bpm: Double,
        steps: [(Int, Int, Double)]
    ) -> MelodyDocument {
        let bundle = Bundle.main
        let title = bundle.localizedString(forKey: "spec_\(keyPrefix)_title", value: defaultTitle, table: nil)
        let subtitle = bundle.localizedString(forKey: "spec_\(keyPrefix)_sub", value: defaultSubtitle, table: nil)
        let category = bundle.localizedString(forKey: "spec_\(keyPrefix)_cat", value: defaultCategory, table: nil)
        let insight = bundle.localizedString(forKey: "spec_\(keyPrefix)_insight", value: defaultInsight, table: nil)

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
                confidence: 1.0
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
            specimenEra: era,
            specimenCategory: category,
            composerInsight: insight,
            preferredTexture: texture,
            preferredVoice: voice
        )
    }
}
