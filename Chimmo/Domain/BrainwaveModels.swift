import Foundation
import SwiftUI

/// V2.0 四大声波脑波节律频段（严格遵循非医疗声学放松与感官艺术表述，零医疗宣称）。
public enum BrainwaveBand: String, CaseIterable, Identifiable, Codable, Sendable {
    case delta
    case theta
    case alpha
    case gamma

    public var id: String { rawValue }

    public var bandIndex: Int {
        switch self {
        case .delta: return 0
        case .theta: return 1
        case .alpha: return 2
        case .gamma: return 3
        }
    }

    public var title: String {
        switch self {
        case .delta: return "深潜入眠"
        case .theta: return "漂浮放空"
        case .alpha: return "丝滑心流"
        case .gamma: return "灵感通透"
        }
    }

    public var englishTag: String {
        switch self {
        case .delta: return "Delta · 2.5 Hz"
        case .theta: return "Theta · 6.0 Hz"
        case .alpha: return "Alpha · 10.0 Hz"
        case .gamma: return "Gamma · 40.0 Hz"
        }
    }

    public var shortCode: String {
        switch self {
        case .delta: return "Delta"
        case .theta: return "Theta"
        case .alpha: return "Alpha"
        case .gamma: return "Gamma"
        }
    }

    public var somaticHook: String {
        switch self {
        case .delta: return "沉入安静夜海"
        case .theta: return "给思绪松绑放空"
        case .alpha: return "温和专注而不紧绷"
        case .gamma: return "清醒敏锐的通透时刻"
        }
    }

    public var shortDescription: String {
        switch self {
        case .delta: return "1.5–4 Hz 极缓深波配暖雨低音床，适合临睡卸下防备、安静窝进被窝。"
        case .theta: return "4–8 Hz 柔和梦境摆波与窑陶泛音，适合午后闭眼发呆与白日放空。"
        case .alpha: return "8–13 Hz 明亮平稳双耳节律，陪伴阅读、手账与沉浸却不焦躁的心流。"
        case .gamma: return "30–42 Hz 清冽澄明微光频段，在灵感堵塞时轻拍一下昏沉的大脑。"
        }
    }

    public var defaultBeatHz: Double {
        switch self {
        case .delta: return 2.5
        case .theta: return 6.0
        case .alpha: return 10.0
        case .gamma: return 40.0
        }
    }

    public var defaultCarrierHz: Double {
        switch self {
        case .delta: return 136.1
        case .theta: return 174.0
        case .alpha: return 216.0
        case .gamma: return 256.0
        }
    }

    public var minBeatHz: Double {
        switch self {
        case .delta: return 1.5
        case .theta: return 4.0
        case .alpha: return 8.0
        case .gamma: return 30.0
        }
    }

    public var maxBeatHz: Double {
        switch self {
        case .delta: return 4.0
        case .theta: return 8.0
        case .alpha: return 13.0
        case .gamma: return 42.0
        }
    }

    public var defaultNoiseGain: Double {
        switch self {
        case .delta: return 0.11
        case .theta: return 0.09
        case .alpha: return 0.07
        case .gamma: return 0.04
        }
    }

    public var defaultNoiseColor: Double {
        switch self {
        case .delta: return 0.12
        case .theta: return 0.28
        case .alpha: return 0.45
        case .gamma: return 0.70
        }
    }

    public var symbolName: String {
        switch self {
        case .delta: return "moon.stars.fill"
        case .theta: return "cloud.fill"
        case .alpha: return "water.waves"
        case .gamma: return "sparkles"
        }
    }

    public func accentColor(isNight: Bool) -> Color {
        let palette = ChimmoPalette(isNight: isNight)
        switch self {
        case .delta: return palette.harmonyWash
        case .theta: return palette.homeAnchor
        case .alpha: return palette.celadonAccent
        case .gamma: return palette.bassRibbon
        }
    }

    public var accessibilitySummary: String {
        "\(title)，\(englishTag)，\(somaticHook)"
    }
}

/// 声床质地（决定与双耳载波融为一体的暖噪声底与泛音厚度）
public enum AcousticWashKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case rainBrown
    case breezePink
    case kilnOvertone
    case pureWave

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rainBrown: return "棕红暖雨"
        case .breezePink: return "粉红微风"
        case .kilnOvertone: return "窑陶泛音"
        case .pureWave: return "纯净双波"
        }
    }

    public var subtitle: String {
        switch self {
        case .rainBrown: return "像隔窗听见远远落下的低频暖雨，松软包裹耳朵"
        case .breezePink: return "清透轻盈的粉色松风底噪，抚平环境杂音"
        case .kilnOvertone: return "低噪加倍呈现纯五度与八度暖泛音，适合闭眼轻哼"
        case .pureWave: return "极简双耳正弦与柔和低八度托底，纯粹感最直接"
        }
    }

    public var symbolName: String {
        switch self {
        case .rainBrown: return "cloud.rain.fill"
        case .breezePink: return "wind"
        case .kilnOvertone: return "tuningfork"
        case .pureWave: return "waveform"
        }
    }

    public var noiseGain: Double {
        switch self {
        case .rainBrown: return 0.12
        case .breezePink: return 0.09
        case .kilnOvertone: return 0.05
        case .pureWave: return 0.0
        }
    }

    public var noiseColor: Double {
        switch self {
        case .rainBrown: return 0.14
        case .breezePink: return 0.68
        case .kilnOvertone: return 0.30
        case .pureWave: return 0.25
        }
    }

    public var overtoneWarmth: Double {
        switch self {
        case .rainBrown: return 0.56
        case .breezePink: return 0.48
        case .kilnOvertone: return 0.88
        case .pureWave: return 0.34
        }
    }
}

/// 12 套精选离线声波配方（对齐今日分时旅程与探索页瞬间直达场景）。
public struct ResonancePreset: Identifiable, Equatable, Codable, Sendable {
    public enum HourWindow: String, Codable, Sendable {
        case morning
        case afternoon
        case evening
        case night
        case any
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let band: BrainwaveBand
    public let beatHz: Double
    public let carrierHz: Double
    public let washKind: AcousticWashKind
    public let durationMinutes: Int
    public let tagline: String
    public let hourWindow: HourWindow

    public init(
        id: String,
        title: String,
        subtitle: String,
        band: BrainwaveBand,
        beatHz: Double,
        carrierHz: Double,
        washKind: AcousticWashKind,
        durationMinutes: Int,
        tagline: String,
        hourWindow: HourWindow
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.band = band
        self.beatHz = beatHz
        self.carrierHz = carrierHz
        self.washKind = washKind
        self.durationMinutes = durationMinutes
        self.tagline = tagline
        self.hourWindow = hourWindow
    }

    public static let all: [ResonancePreset] = [
        ResonancePreset(
            id: "morning-alpha-flow",
            title: "晨光清澈心流",
            subtitle: "10.0 Hz Alpha · 粉红微风",
            band: .alpha,
            beatHz: 10.0,
            carrierHz: 216.0,
            washKind: .breezePink,
            durationMinutes: 15,
            tagline: "不用急着振作，先让大脑泡在一阵清风里温和醒来。",
            hourWindow: .morning
        ),
        ResonancePreset(
            id: "morning-gamma-spark",
            title: "灵感擦亮一瞬",
            subtitle: "40.0 Hz Gamma · 纯净双波",
            band: .gamma,
            beatHz: 40.0,
            carrierHz: 256.0,
            washKind: .pureWave,
            durationMinutes: 5,
            tagline: "思绪卡壳的时候，用一束澄明快波给念头透透气。",
            hourWindow: .morning
        ),
        ResonancePreset(
            id: "afternoon-alpha-deep",
            title: "午后专注白纸",
            subtitle: "11.2 Hz Alpha · 棕红暖雨",
            band: .alpha,
            beatHz: 11.2,
            carrierHz: 224.0,
            washKind: .rainBrown,
            durationMinutes: 25,
            tagline: "像在暖雨天坐进窗边单人沙发，手边的事自然推着走。",
            hourWindow: .afternoon
        ),
        ResonancePreset(
            id: "afternoon-theta-drift",
            title: "午后三点放空云",
            subtitle: "6.0 Hz Theta · 窑陶泛音",
            band: .theta,
            beatHz: 6.0,
            carrierHz: 174.0,
            washKind: .kilnOvertone,
            durationMinutes: 10,
            tagline: "合法停止高效运转十分钟，允许脑袋变成松软云朵。",
            hourWindow: .afternoon
        ),
        ResonancePreset(
            id: "evening-theta-unhook",
            title: "傍晚卸下重担",
            subtitle: "5.2 Hz Theta · 棕红暖雨",
            band: .theta,
            beatHz: 5.2,
            carrierHz: 164.0,
            washKind: .rainBrown,
            durationMinutes: 15,
            tagline: "把白天的碎片悬念留在门外，让双波温柔拖住节奏。",
            hourWindow: .evening
        ),
        ResonancePreset(
            id: "evening-alpha-warm",
            title: "暮色橘灯手账",
            subtitle: "8.5 Hz Alpha · 窑陶泛音",
            band: .alpha,
            beatHz: 8.5,
            carrierHz: 196.0,
            washKind: .kilnOvertone,
            durationMinutes: 15,
            tagline: "贴近 Theta 边缘的低频 Alpha，暖得像傍晚刚亮起小灯。",
            hourWindow: .evening
        ),
        ResonancePreset(
            id: "night-delta-anchor",
            title: "零重力深夜入眠",
            subtitle: "2.5 Hz Delta · 棕红暖雨",
            band: .delta,
            beatHz: 2.5,
            carrierHz: 136.1,
            washKind: .rainBrown,
            durationMinutes: 30,
            tagline: "极慢 2.5 Hz 潮汐呼吸配合暖雨低音床，陪你稳稳离线。",
            hourWindow: .night
        ),
        ResonancePreset(
            id: "night-delta-velvet",
            title: "深靛天鹅绒微光",
            subtitle: "1.8 Hz Delta · 纯净双波",
            band: .delta,
            beatHz: 1.8,
            carrierHz: 128.0,
            washKind: .pureWave,
            durationMinutes: 30,
            tagline: "接近静止的超低频包裹，给容易惊醒的夜留一片纯黑平静。",
            hourWindow: .night
        ),
        ResonancePreset(
            id: "any-theta-rainhouse",
            title: "屋檐远雨放空室",
            subtitle: "6.5 Hz Theta · 棕红暖雨",
            band: .theta,
            beatHz: 6.5,
            carrierHz: 184.0,
            washKind: .rainBrown,
            durationMinutes: 15,
            tagline: "随时开启的声学防空洞，隔开杂音和多余信息流。",
            hourWindow: .any
        ),
        ResonancePreset(
            id: "any-alpha-reading",
            title: "一页安静长书",
            subtitle: "9.5 Hz Alpha · 粉红微风",
            band: .alpha,
            beatHz: 9.5,
            carrierHz: 210.0,
            washKind: .breezePink,
            durationMinutes: 30,
            tagline: "不抢走注意力的清薄声床，让视线和呼吸自然合拍。",
            hourWindow: .any
        ),
        ResonancePreset(
            id: "any-gamma-clarity",
            title: "清晨通透重启",
            subtitle: "36.0 Hz Gamma · 粉红微风",
            band: .gamma,
            beatHz: 36.0,
            carrierHz: 244.0,
            washKind: .breezePink,
            durationMinutes: 10,
            tagline: "比纯 40 Hz 更温柔一分的轻快醒神频段。",
            hourWindow: .any
        ),
        ResonancePreset(
            id: "any-theta-cradle",
            title: "窑陶五度和鸣床",
            subtitle: "4.8 Hz Theta · 窑陶泛音",
            band: .theta,
            beatHz: 4.8,
            carrierHz: 152.0,
            washKind: .kilnOvertone,
            durationMinutes: 20,
            tagline: "用纯五度天然泛音替代冷冰电子音，体感柔和丰润。",
            hourWindow: .any
        )
    ]
}

/// 探索页精选「颅内战栗 · 声波乐章胶囊」（升维收纳 SpecimenLibrary 中最易诱发鸡皮疙瘩张力释放的 8 首代表作）。
public struct FrissonCapsule: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let frissonHighlight: String
    public let durationText: String
    public let companionBand: BrainwaveBand
    public let specimen: MelodyDocument

    public static let all: [FrissonCapsule] = [
        FrissonCapsule(
            id: "swan-glide",
            title: "天鹅入水 · 大跳与回落",
            subtitle: "圣桑 · 1886 公版重编",
            frissonHighlight: "4->5->6->1↑ 仰颈弧线配流动竖琴波纹",
            durationText: "约 1 分钟循环",
            companionBand: .alpha,
            specimen: SpecimenLibrary.saintSaensTheSwan
        ),
        FrissonCapsule(
            id: "clair-suspension",
            title: "银白月光 · 四度微亮",
            subtitle: "德彪西 · 1890 公版重编",
            frissonHighlight: "3->1 轻落之间留白微颤，空气瞬间变凉爽",
            durationText: "约 1 分钟循环",
            companionBand: .theta,
            specimen: SpecimenLibrary.debussyClairDeLune
        ),
        FrissonCapsule(
            id: "satie-float",
            title: "吉诺佩蒂 · 慢速漂浮",
            subtitle: "萨蒂 · 1888 公版重编",
            frissonHighlight: "大七和弦轻悬在地面两寸之上，怎么听都不急",
            durationText: "约 1 分钟循环",
            companionBand: .theta,
            specimen: SpecimenLibrary.satieGymnopedieSeed
        ),
        FrissonCapsule(
            id: "bach-exhale",
            title: "G弦咏叹 · 阶梯长呼",
            subtitle: "巴赫 · 巴洛克公版重编",
            frissonHighlight: "低音步步下行托起长高音，胸腔跟着一起松气",
            durationText: "约 1 分钟循环",
            companionBand: .alpha,
            specimen: SpecimenLibrary.bachAirOnGString
        ),
        FrissonCapsule(
            id: "liszt-halo",
            title: "安慰曲 · 长音光环",
            subtitle: "李斯特 · 1850 公版重编",
            frissonHighlight: "长停留音把水波琶音变成环绕头顶的温度场",
            durationText: "约 1 分钟循环",
            companionBand: .theta,
            specimen: SpecimenLibrary.lisztConsolation3
        ),
        FrissonCapsule(
            id: "summer-fourth",
            title: "夏风四度 · 悬而未落",
            subtitle: "Chimmo 原创和声技法",
            frissonHighlight: "4-5-3-6 悬浮进行触发轻微失重般的酥麻预期",
            durationText: "约 45 秒循环",
            companionBand: .alpha,
            specimen: SpecimenLibrary.summerSuspension
        ),
        FrissonCapsule(
            id: "midnight-city",
            title: "午夜海岸 · 霓虹七音",
            subtitle: "Chimmo 原创都市夜声",
            frissonHighlight: "2-5-1 透明九和弦折射微醺夜晚光泽",
            durationText: "约 45 秒循环",
            companionBand: .alpha,
            specimen: SpecimenLibrary.midnightCoastCityPop
        ),
        FrissonCapsule(
            id: "stardust-mirror",
            title: "星尘对话 · 镜像对位",
            subtitle: "Chimmo 原创双声部",
            frissonHighlight: "两束声线一升一降拉开立体声宽度，脑海瞬间变大",
            durationText: "约 45 秒循环",
            companionBand: .gamma,
            specimen: SpecimenLibrary.stardustCounterpoint
        )
    ]
}

/// 纯函数脑波与触觉运动学引擎（100% 确定性可单测）。
public enum ResonanceKinematics {
    public static func clampedBeatHz(_ hz: Double) -> Double {
        guard hz.isFinite else { return BrainwaveBand.alpha.defaultBeatHz }
        return max(1.5, min(42.0, hz))
    }

    public static func band(forBeatHz beatHz: Double) -> BrainwaveBand {
        guard beatHz.isFinite else { return .alpha }
        if beatHz < 4.0 { return .delta }
        if beatHz < 8.0 { return .theta }
        if beatHz < 20.0 { return .alpha }
        return .gamma
    }

    public static func binauralFrequencies(carrierHz: Double, beatHz: Double) -> (left: Double, right: Double) {
        let safeCarrier = carrierHz.isFinite ? max(80.0, min(440.0, carrierHz)) : 216.0
        let safeBeat = clampedBeatHz(beatHz)
        let left = max(40.0, safeCarrier - safeBeat * 0.5)
        let right = max(40.0, safeCarrier + safeBeat * 0.5)
        return (left, right)
    }

    /// 把任意人声轻哼基频按纯八度温和折叠至最舒适、最富共鸣的脑波载波带（120–260 Hz）。
    public static func foldHumFrequencyToCarrier(_ rawHz: Double) -> Double {
        guard rawHz.isFinite, rawHz > 20.0 else { return 174.0 }
        var folded = rawHz
        var guardSteps = 0
        while folded < 120.0 && guardSteps < 8 {
            folded *= 2.0
            guardSteps += 1
        }
        while folded > 260.0 && guardSteps < 8 {
            folded *= 0.5
            guardSteps += 1
        }
        return max(120.0, min(260.0, folded))
    }

    public static func timeOfDayWindow(forHour hour: Int) -> ResonancePreset.HourWindow {
        let h = ((hour % 24) + 24) % 24
        switch h {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<22: return .evening
        default: return .night
        }
    }

    public static func timeOfDayBanner(forHour hour: Int) -> (title: String, subtitle: String) {
        switch timeOfDayWindow(forHour: hour) {
        case .morning:
            return ("早安，先顺着呼吸醒来", "轻拍一下即可进入今天的第一段清醒声波")
        case .afternoon:
            return ("午后，给大脑留一块留白", "放空几分钟，或是沉入平稳专注的心流")
        case .evening:
            return ("傍晚，把紧绷交给水波", "用温热泛音和掌心触觉慢慢卸下一天的疲劳")
        case .night, .any:
            return ("夜深了，放心把手机交给安静", "极缓 Delta 低波与暖雨声床，陪你软软滑入夜色")
        }
    }

    /// 今日 3 步脑波旅程配方：步骤 1 为当前时段 Hero 主卡，步骤 2/3 衔接状态过渡。
    public static func dailyJourneySteps(forHour hour: Int) -> [ResonancePreset] {
        let window = timeOfDayWindow(forHour: hour)
        let all = ResonancePreset.all
        let first = all.first(where: { $0.hourWindow == window }) ?? all[0]
        let second = all.first(where: { $0.id == "afternoon-theta-drift" && $0.id != first.id })
            ?? all.first(where: { $0.band == .theta && $0.id != first.id })
            ?? all[1]
        let third: ResonancePreset = {
            if window == .night || window == .evening {
                return all.first(where: { $0.id == "night-delta-anchor" && $0.id != first.id }) ?? all[6]
            }
            return all.first(where: { $0.id == "evening-alpha-warm" && $0.id != first.id }) ?? all[5]
        }()
        return [first, second, third]
    }

    /// 共振球呼吸缩放系数（严格遵守 `accessibilityReduceMotion`）。
    public static func orbPulseScale(
        phaseTime: Double,
        beatHz: Double,
        energy: Double,
        frissonCharge: Double,
        reduceMotion: Bool
    ) -> CGFloat {
        let safeCharge = frissonCharge.isFinite ? max(0.0, min(1.0, frissonCharge)) : 0.0
        if reduceMotion {
            return CGFloat(1.0 - safeCharge * 0.04)
        }
        let t = phaseTime.isFinite ? max(0.0, phaseTime) : 0.0
        let safeEnergy = energy.isFinite ? max(0.0, min(1.0, energy)) : 0.0
        // 将高频 Gamma 视觉摆动折算到护眼温柔区间（0.25–1.8 Hz）
        let visualHz = min(1.8, max(0.24, clampedBeatHz(beatHz) * 0.09))
        let wave = sin(t * 2.0 * Double.pi * visualHz)
        let breathAmp = 0.025 + safeEnergy * 0.045
        let squeeze = safeCharge * 0.09
        return CGFloat(max(0.84, min(1.14, 1.0 + wave * breathAmp - squeeze)))
    }

    /// 10 秒舒缓呼吸引导节律（4 秒柔和吸气 0->1 + 6 秒缓慢呼气 1->0；减弱动态下稳态返回 0.5）。
    public static func breathGuidePhase(
        at time: Double,
        reduceMotion: Bool
    ) -> (progress: Double, isInhaling: Bool, label: String) {
        if reduceMotion {
            return (0.5, true, "平稳呼吸")
        }
        let safeTime = time.isFinite ? max(0.0, time) : 0.0
        let cycle = 10.0
        let local = safeTime.truncatingRemainder(dividingBy: cycle)
        if local < 4.0 {
            let p = local / 4.0
            let eased = 0.5 - 0.5 * cos(Double.pi * p)
            return (eased, true, "吸气 4 秒")
        } else {
            let p = (local - 4.0) / 6.0
            let eased = 0.5 + 0.5 * cos(Double.pi * p)
            return (eased, false, "呼气 6 秒")
        }
    }

    /// 温柔无说教陪伴短语（绝不使用断签警告或打卡鞭策）。
    public static func gentleCompanionMessage(
        totalMinutes: Int,
        frissonCount: Int,
        favoriteBand: BrainwaveBand?
    ) -> String {
        if totalMinutes <= 0 && frissonCount <= 0 {
            return "不用连续打卡，也不用赶任何进度。今天哪怕只戴上耳机发呆三分钟，就已经是送给大脑的一场安静假期。"
        }
        if let fav = favoriteBand {
            if frissonCount > 0 {
                return "你最常在「\(fav.title)」频段里安顿思绪，已经收藏过 \(frissonCount) 次声波绽放。随时回来喘口气，咩哞一直都在。"
            }
            return "「\(fav.title)」是最常接住你的频道。疲惫的时候不用勉强振作，让声波替你先把肩颈放下来。"
        }
        return "无论过了多久再打开，这里没有倒扣的进度条，只有随时为你亮起的温热共鸣。"
    }
}

/// 离线脑波沉淀记录存储（仅本机 UserDefaults，支持测试注入隔离）。
@MainActor
public final class ResonanceStatsStore: ObservableObject {
    private static let totalSecondsKey = "chimmo.v2.stats.totalSeconds"
    private static let sessionsKey = "chimmo.v2.stats.sessions"
    private static let frissonCountKey = "chimmo.v2.stats.frissonCount"
    private static let bandCountsKey = "chimmo.v2.stats.bandCounts"
    private static let recentIDsKey = "chimmo.v2.stats.recentIDs"
    private static let favoriteIDsKey = "chimmo.v2.stats.favoriteIDs"
    private static let firstUseKey = "chimmo.v2.stats.firstUse"

    @Published public private(set) var totalResonanceSeconds: TimeInterval
    @Published public private(set) var sessionsCompleted: Int
    @Published public private(set) var frissonPeakCount: Int
    @Published public private(set) var bandUsageCounts: [String: Int]
    @Published public private(set) var recentPresetIDs: [String]
    @Published public private(set) var favoritePresetIDs: Set<String>
    @Published public private(set) var firstUseTimestamp: TimeInterval

    private let defaults: UserDefaults?

    public init(preferences: UserDefaults? = nil) {
        self.defaults = preferences
        if let defs = preferences {
            self.totalResonanceSeconds = max(0, defs.double(forKey: Self.totalSecondsKey))
            self.sessionsCompleted = max(0, defs.integer(forKey: Self.sessionsKey))
            self.frissonPeakCount = max(0, defs.integer(forKey: Self.frissonCountKey))
            self.bandUsageCounts = (defs.dictionary(forKey: Self.bandCountsKey) as? [String: Int]) ?? [:]
            self.recentPresetIDs = defs.stringArray(forKey: Self.recentIDsKey) ?? []
            self.favoritePresetIDs = Set(defs.stringArray(forKey: Self.favoriteIDsKey) ?? [])
            let storedFirst = defs.double(forKey: Self.firstUseKey)
            if storedFirst > 0 {
                self.firstUseTimestamp = storedFirst
            } else {
                let now = Date().timeIntervalSince1970
                defs.set(now, forKey: Self.firstUseKey)
                self.firstUseTimestamp = now
            }
        } else {
            self.totalResonanceSeconds = 0
            self.sessionsCompleted = 0
            self.frissonPeakCount = 0
            self.bandUsageCounts = [:]
            self.recentPresetIDs = []
            self.favoritePresetIDs = []
            self.firstUseTimestamp = Date().timeIntervalSince1970
        }
    }

    public var totalMinutes: Int {
        Int((totalResonanceSeconds / 60.0).rounded(.down))
    }

    public var favoriteBand: BrainwaveBand? {
        guard let bestKey = bandUsageCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        return BrainwaveBand(rawValue: bestKey)
    }

    public var firstUseFormattedDate: String {
        let date = Date(timeIntervalSince1970: firstUseTimestamp)
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return "\(y) 年 \(m) 月相遇"
    }

    public func recordResonanceSeconds(_ seconds: TimeInterval, band: BrainwaveBand) {
        guard seconds.isFinite, seconds > 0 else { return }
        totalResonanceSeconds += seconds
        bandUsageCounts[band.rawValue, default: 0] += 1
        persist()
    }

    public func recordSessionCompleted(band: BrainwaveBand) {
        sessionsCompleted += 1
        bandUsageCounts[band.rawValue, default: 0] += 2
        persist()
    }

    public func recordFrissonPeak() {
        frissonPeakCount += 1
        persist()
    }

    public func recordRecentPreset(_ presetID: String) {
        recentPresetIDs.removeAll { $0 == presetID }
        recentPresetIDs.insert(presetID, at: 0)
        if recentPresetIDs.count > 12 {
            recentPresetIDs = Array(recentPresetIDs.prefix(12))
        }
        persist()
    }

    public func toggleFavoritePreset(_ presetID: String) {
        if favoritePresetIDs.contains(presetID) {
            favoritePresetIDs.remove(presetID)
        } else {
            favoritePresetIDs.insert(presetID)
        }
        persist()
    }

    public func isFavorite(_ presetID: String) -> Bool {
        favoritePresetIDs.contains(presetID)
    }

    private func persist() {
        guard let defs = defaults else { return }
        defs.set(totalResonanceSeconds, forKey: Self.totalSecondsKey)
        defs.set(sessionsCompleted, forKey: Self.sessionsKey)
        defs.set(frissonPeakCount, forKey: Self.frissonCountKey)
        defs.set(bandUsageCounts, forKey: Self.bandCountsKey)
        defs.set(recentPresetIDs, forKey: Self.recentIDsKey)
        defs.set(Array(favoritePresetIDs), forKey: Self.favoriteIDsKey)
    }
}
