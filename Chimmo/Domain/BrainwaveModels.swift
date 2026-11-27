import Foundation
import QuartzCore
import SwiftUI

/// Four foundational acoustic entrainment frequency bands.
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
        case .delta: return "Delta"
        case .theta: return "Theta"
        case .alpha: return "Alpha"
        case .gamma: return "Gamma"
        }
    }

    public var chineseSubtitle: String {
        switch self {
        case .delta: return String(localized: "band_sub_delta", defaultValue: "深睡休整")
        case .theta: return String(localized: "band_sub_theta", defaultValue: "浅眠冥想")
        case .alpha: return String(localized: "band_sub_alpha", defaultValue: "松弛心流")
        case .gamma: return String(localized: "band_sub_gamma", defaultValue: "清澈聚焦")
        }
    }

    public var hzRangeLabel: String {
        switch self {
        case .delta: return "1.5–4 Hz"
        case .theta: return "4–8 Hz"
        case .alpha: return "8–14 Hz"
        case .gamma: return "38–42 Hz"
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
        case .gamma: return 32.0
        }
    }

    public var maxBeatHz: Double {
        switch self {
        case .delta: return 4.0
        case .theta: return 8.0
        case .alpha: return 14.0
        case .gamma: return 42.0
        }
    }

    public var sensoryDescription: String {
        switch self {
        case .delta:
            return String(localized: "band_desc_delta", defaultValue: "极缓沉稳的深空脉冲，配合厚重棕红底噪，像在棉布夜色里慢慢落定。")
        case .theta:
            return String(localized: "band_desc_theta", defaultValue: "温软漂浮的摇篮摆频，搭配手工陶窑泛音，适合放空与入睡前过渡。")
        case .alpha:
            return String(localized: "band_desc_alpha", defaultValue: "松弛平顺的日光松弛节律，在保持头脑清醒的同时卸下紧绷节奏。")
        case .gamma:
            return String(localized: "band_desc_gamma", defaultValue: "40 Hz 明澈高频稳态微振，配合海盐微光颗粒感，唤醒清晰专注力。")
        }
    }

    public var scaleModeEquivalent: ScaleMode {
        switch self {
        case .delta: return .wistfulMinor
        case .theta: return .forestDorian
        case .alpha: return .goldenMixolydian
        case .gamma: return .cloudLydian
        }
    }

    public var iconName: String {
        switch self {
        case .delta: return "moon.stars"
        case .theta: return "wind"
        case .alpha: return "circle.dotted.and.circle"
        case .gamma: return "sparkles"
        }
    }

    /// WCAG AA verified band colors against light shelfSurface and dark backgrounds.
    public func accentColor(isNight: Bool) -> Color {
        switch (self, isNight) {
        case (.delta, false): return Color(hex: 0x6246A8)
        case (.delta, true): return Color(hex: 0xBAA3FF)
        case (.theta, false): return Color(hex: 0xA63C28)
        case (.theta, true): return Color(hex: 0xF29476)
        case (.alpha, false): return Color(hex: 0x2B6865)
        case (.alpha, true): return Color(hex: 0x7ECBC5)
        case (.gamma, false): return Color(hex: 0x256291)
        case (.gamma, true): return Color(hex: 0x78BAFA)
        }
    }

    public var accentHexLight: UInt32 {
        switch self {
        case .delta: return 0x6246A8
        case .theta: return 0xA63C28
        case .alpha: return 0x2B6865
        case .gamma: return 0x256291
        }
    }

    public var accentHexNight: UInt32 {
        switch self {
        case .delta: return 0xBAA3FF
        case .theta: return 0xF29476
        case .alpha: return 0x7ECBC5
        case .gamma: return 0x78BAFA
        }
    }
}

/// Offline ambient acoustic wash bed color.
public enum AcousticWashKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case rainBrown
    case breezePink
    case kilnOvertone
    case mistWhite

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rainBrown: return String(localized: "wash_rain_brown", defaultValue: "檐雨棕红")
        case .breezePink: return String(localized: "wash_breeze_pink", defaultValue: "溪风粉红")
        case .kilnOvertone: return String(localized: "wash_kiln_overtone", defaultValue: "陶窑泛音")
        case .mistWhite: return String(localized: "wash_mist_white", defaultValue: "海盐微雾")
        }
    }

    public var noiseGain: Double {
        switch self {
        case .rainBrown: return 0.14
        case .breezePink: return 0.10
        case .kilnOvertone: return 0.06
        case .mistWhite: return 0.12
        }
    }

    public var noiseColor: Double {
        switch self {
        case .rainBrown: return 0.08
        case .breezePink: return 0.36
        case .kilnOvertone: return 0.24
        case .mistWhite: return 0.72
        }
    }

    public var overtoneWarmth: Double {
        switch self {
        case .rainBrown: return 0.45
        case .breezePink: return 0.56
        case .kilnOvertone: return 0.88
        case .mistWhite: return 0.42
        }
    }

    public var companionNote: String {
        switch self {
        case .rainBrown: return String(localized: "wash_note_rain", defaultValue: "绵密低沉的暖褐雨床，适合遮蔽日常环境杂音。")
        case .breezePink: return String(localized: "wash_note_breeze", defaultValue: "贴近自然溪流的柔粉噪声，透气而不压迫。")
        case .kilnOvertone: return String(localized: "wash_note_kiln", defaultValue: "丰富五度泛音共鸣叠加极淡微噪声，温润包覆感。")
        case .mistWhite: return String(localized: "wash_note_mist", defaultValue: "更轻亮的海雾颗粒感，配 40 Hz Gamma 最透彻。")
        }
    }
}

/// Curated circadian soundscapes covering all 4 bands (12 total presets).
public struct ResonancePreset: Identifiable, Equatable, Codable, Sendable {
    public enum HourWindow: String, Codable, Sendable {
        case morning
        case afternoon
        case evening
        case midnight
    }

    public let id: String
    public let titleKey: String
    public let defaultTitle: String
    public let subtitleKey: String
    public let defaultSubtitle: String
    public let band: BrainwaveBand
    public let beatHz: Double
    public let carrierHz: Double
    public let washKind: AcousticWashKind
    public let hourWindow: HourWindow
    public let durationHintMinutes: Int

    public var title: String {
        Bundle.main.localizedString(forKey: titleKey, value: defaultTitle, table: nil)
    }

    public var subtitle: String {
        Bundle.main.localizedString(forKey: subtitleKey, value: defaultSubtitle, table: nil)
    }

    public static let all: [ResonancePreset] = [
        ResonancePreset(
            id: "alpha_morning_dew",
            titleKey: "preset_alpha_morning_dew_title", defaultTitle: "朝露晴空 · 10 Hz",
            subtitleKey: "preset_alpha_morning_dew_sub", defaultSubtitle: "清晨唤醒，明快不躁的 Alpha 心流声场",
            band: .alpha, beatHz: 10.0, carrierHz: 216.0, washKind: .breezePink, hourWindow: .morning, durationHintMinutes: 15
        ),
        ResonancePreset(
            id: "gamma_clear_desk",
            titleKey: "preset_gamma_clear_desk_title", defaultTitle: "木桌清澈 · 40 Hz",
            subtitleKey: "preset_gamma_clear_desk_sub", defaultSubtitle: "早晨阅读与创作前的明晰高频专注锚",
            band: .gamma, beatHz: 40.0, carrierHz: 256.0, washKind: .mistWhite, hourWindow: .morning, durationHintMinutes: 25
        ),
        ResonancePreset(
            id: "alpha_ceramic_porch",
            titleKey: "preset_alpha_ceramic_porch_title", defaultTitle: "陶檐微风 · 9 Hz",
            subtitleKey: "preset_alpha_ceramic_porch_sub", defaultSubtitle: "微暖五度泛音托住轻松呼吸感",
            band: .alpha, beatHz: 9.0, carrierHz: 204.0, washKind: .kilnOvertone, hourWindow: .morning, durationHintMinutes: 20
        ),
        ResonancePreset(
            id: "alpha_afternoon_tea",
            titleKey: "preset_alpha_afternoon_tea_title", defaultTitle: "午后茶雾 · 10.5 Hz",
            subtitleKey: "preset_alpha_afternoon_tea_sub", defaultSubtitle: "松弛平顺节奏，柔和化开午间困意与杂念",
            band: .alpha, beatHz: 10.5, carrierHz: 216.0, washKind: .kilnOvertone, hourWindow: .afternoon, durationHintMinutes: 20
        ),
        ResonancePreset(
            id: "theta_nap_hammock",
            titleKey: "preset_theta_nap_hammock_title", defaultTitle: "日光午睡 · 6 Hz",
            subtitleKey: "preset_theta_nap_hammock_sub", defaultSubtitle: "20 分钟浅眠小憩，轻盈落回温软怀抱",
            band: .theta, beatHz: 6.0, carrierHz: 174.0, washKind: .breezePink, hourWindow: .afternoon, durationHintMinutes: 20
        ),
        ResonancePreset(
            id: "gamma_laser_atelier",
            titleKey: "preset_gamma_laser_atelier_title", defaultTitle: "静默工坊 · 40 Hz",
            subtitleKey: "preset_gamma_laser_atelier_sub", defaultSubtitle: "高频稳态脉动，隔绝纷扰进入深度心流",
            band: .gamma, beatHz: 40.0, carrierHz: 264.0, washKind: .breezePink, hourWindow: .afternoon, durationHintMinutes: 30
        ),
        ResonancePreset(
            id: "theta_twilight_kiln",
            titleKey: "preset_theta_twilight_kiln_title", defaultTitle: "暮色熄窑 · 5.5 Hz",
            subtitleKey: "preset_theta_twilight_kiln_sub", defaultSubtitle: "傍晚卸下疲惫，温暖陶音缓慢降噪过渡",
            band: .theta, beatHz: 5.5, carrierHz: 174.0, washKind: .kilnOvertone, hourWindow: .evening, durationHintMinutes: 25
        ),
        ResonancePreset(
            id: "theta_rain_eaves",
            titleKey: "preset_theta_rain_eaves_title", defaultTitle: "棉檐晚雨 · 4.8 Hz",
            subtitleKey: "preset_theta_rain_eaves_sub", defaultSubtitle: "绵密棕红雨声包覆轻哼泛音，进入睡意准备",
            band: .theta, beatHz: 4.8, carrierHz: 164.0, washKind: .rainBrown, hourWindow: .evening, durationHintMinutes: 30
        ),
        ResonancePreset(
            id: "alpha_reading_lamp",
            titleKey: "preset_alpha_reading_lamp_title", defaultTitle: "纸灯夜读 · 8.5 Hz",
            subtitleKey: "preset_alpha_reading_lamp_sub", defaultSubtitle: "柔和慢速 Alpha，陪你翻完睡前最后一章",
            band: .alpha, beatHz: 8.5, carrierHz: 196.0, washKind: .kilnOvertone, hourWindow: .evening, durationHintMinutes: 20
        ),
        ResonancePreset(
            id: "delta_deep_cotton",
            titleKey: "preset_delta_deep_cotton_title", defaultTitle: "深眠棉云 · 2.5 Hz",
            subtitleKey: "preset_delta_deep_cotton_sub", defaultSubtitle: "2.5 Hz 极缓深波 + 136.1 Hz 暖底，整夜安稳伴眠",
            band: .delta, beatHz: 2.5, carrierHz: 136.1, washKind: .rainBrown, hourWindow: .midnight, durationHintMinutes: 45
        ),
        ResonancePreset(
            id: "delta_velvet_night",
            titleKey: "preset_delta_velvet_night_title", defaultTitle: "暗夜零噪 · 1.8 Hz",
            subtitleKey: "preset_delta_velvet_night_sub", defaultSubtitle: "贴近夜晚舒缓慢波节律的极轻低鸣，暗屏低眩光伴睡",
            band: .delta, beatHz: 1.8, carrierHz: 128.0, washKind: .rainBrown, hourWindow: .midnight, durationHintMinutes: 60
        ),
        ResonancePreset(
            id: "theta_dream_drift",
            titleKey: "preset_theta_dream_drift_title", defaultTitle: "浮梦半醒 · 4.2 Hz",
            subtitleKey: "preset_theta_dream_drift_sub", defaultSubtitle: "停留在浅睡临界线上的柔软波动与远景呼吸",
            band: .theta, beatHz: 4.2, carrierHz: 152.0, washKind: .kilnOvertone, hourWindow: .midnight, durationHintMinutes: 35
        )
    ]
}

/// Curated acoustic frisson tension-and-release capsules built from public-domain classics & originals.
public struct FrissonCapsule: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let frissonNote: String
    public let specimen: MelodyDocument

    public var badgeTag: String {
        switch specimen.scaleMode {
        case .cloudLydian: return String(localized: "mode_tag_dreamy", defaultValue: "梦幻悬浮")
        case .brightMajor: return String(localized: "mode_tag_bright", defaultValue: "明朗暖春")
        case .goldenMixolydian: return String(localized: "mode_tag_sunset", defaultValue: "余晖飘逸")
        case .forestDorian: return String(localized: "mode_tag_mist", defaultValue: "深林微雾")
        case .wistfulMinor: return String(localized: "mode_tag_night", defaultValue: "深邃夜曲")
        }
    }

    public init(
        id: String,
        titleKey: String,
        defaultTitle: String,
        subtitleKey: String,
        defaultSubtitle: String,
        noteKey: String,
        defaultNote: String,
        specimen: MelodyDocument
    ) {
        self.id = id
        self.title = Bundle.main.localizedString(forKey: titleKey, value: defaultTitle, table: nil)
        self.subtitle = Bundle.main.localizedString(forKey: subtitleKey, value: defaultSubtitle, table: nil)
        self.frissonNote = Bundle.main.localizedString(forKey: noteKey, value: defaultNote, table: nil)
        self.specimen = specimen
    }

    public static var all: [FrissonCapsule] {
        [
            FrissonCapsule(
                id: "the_swan",
                titleKey: "cap_swan_title", defaultTitle: "天鹅 · 圣桑",
                subtitleKey: "cap_swan_sub", defaultSubtitle: "大提琴长弧线条与竖琴水波",
                noteKey: "cap_swan_note", defaultNote: "高音弧线停悬再滑回主音，制造温柔饱满的心跳释放感。",
                specimen: SpecimenLibrary.saintSaensTheSwan
            ),
            FrissonCapsule(
                id: "claire_de_lune",
                titleKey: "cap_claire_title", defaultTitle: "月光 · 德彪西",
                subtitleKey: "cap_claire_sub", defaultSubtitle: "夜色弥散与七度回望",
                noteKey: "cap_claire_note", defaultNote: "朦胧七和弦与长呼吸延留相接，带来月光铺满纸面的起皮战栗。",
                specimen: SpecimenLibrary.debussyClairDeLune
            ),
            FrissonCapsule(
                id: "gymnopedie",
                titleKey: "cap_gymno_title", defaultTitle: "吉诺佩蒂 · 萨蒂",
                subtitleKey: "cap_gymno_sub", defaultSubtitle: "大七和弦慢速摇摆与留白",
                noteKey: "cap_gymno_note", defaultNote: "大七度交替摇晃配合长片断停顿，是减压慢释然的代表质感。",
                specimen: SpecimenLibrary.satieGymnopedieSeed
            ),
            FrissonCapsule(
                id: "air_on_g",
                titleKey: "cap_airg_title", defaultTitle: "G弦咏叹 · 巴赫",
                subtitleKey: "cap_airg_sub", defaultSubtitle: "低音步进下的延留解放",
                noteKey: "cap_airg_note", defaultNote: "稳定低音阶梯下走遇上高音留音解决，构建古典建筑般的壮阔感。",
                specimen: SpecimenLibrary.bachAirOnGString
            ),
            FrissonCapsule(
                id: "consolation_3",
                titleKey: "cap_consolation_title", defaultTitle: "安慰曲 · 李斯特",
                subtitleKey: "cap_consolation_sub", defaultSubtitle: "温润和弦托举下的高八度释怀",
                noteKey: "cap_consolation_note", defaultNote: "反复堆积温柔张力后在尾音舒展平复，常用于触发长舒一口气的体验。",
                specimen: SpecimenLibrary.lisztConsolation3
            ),
            FrissonCapsule(
                id: "summer_suspension",
                titleKey: "cap_summer_title", defaultTitle: "夏风四度（原创）",
                subtitleKey: "cap_summer_sub", defaultSubtitle: "4-5-3-6 透明 add9 悬浮进行",
                noteKey: "cap_summer_note", defaultNote: "清亮九音和弦把旋律托在半空，再稳稳收拢回主调家门。",
                specimen: SpecimenLibrary.summerSuspension
            ),
            FrissonCapsule(
                id: "midnight_coast",
                titleKey: "cap_coast_title", defaultTitle: "夜海电车（原创）",
                subtitleKey: "cap_coast_sub", defaultSubtitle: "七和弦微斜与蓝调轻落",
                noteKey: "cap_coast_note", defaultNote: "轻快切分与暖融和声交织，像夜晚海岸列车驶过灯火时的愉悦微振。",
                specimen: SpecimenLibrary.midnightCoastCityPop
            ),
            FrissonCapsule(
                id: "stardust_counterpoint",
                titleKey: "cap_stardust_title", defaultTitle: "星尘卡农（原创）",
                subtitleKey: "cap_stardust_sub", defaultSubtitle: "复调织体交错绽放",
                noteKey: "cap_stardust_note", defaultNote: "双声部一呼一应攀升到泛音高点，像抬头看见星空一下子展开。",
                specimen: SpecimenLibrary.stardustCounterpoint
            )
        ]
    }
}

/// Acoustic resonance math & safety kinematics.
public enum ResonanceKinematics {
    public static func clampedBeatHz(_ hz: Double) -> Double {
        guard hz.isFinite else { return 10.0 }
        return max(1.5, min(42.0, hz))
    }

    public static func normalizedDialPosition(forBeatHz hz: Double) -> Double {
        let c = clampedBeatHz(hz)
        if c <= 14.0 {
            return ((c - 1.5) / (14.0 - 1.5)) * 0.72
        }
        return 0.72 + ((c - 14.0) / (42.0 - 14.0)) * 0.28
    }

    public static func beatHz(forNormalizedDialPosition norm: Double) -> Double {
        let clamped = norm.isFinite ? max(0.0, min(1.0, norm)) : 0.0
        let raw: Double
        if clamped <= 0.72 {
            raw = 1.5 + (clamped / 0.72) * (14.0 - 1.5)
        } else {
            raw = 14.0 + ((clamped - 0.72) / 0.28) * (42.0 - 14.0)
        }
        return (raw * 2.0).rounded() / 2.0
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
        return (
            left: max(40.0, safeCarrier - safeBeat * 0.5),
            right: safeCarrier + safeBeat * 0.5
        )
    }

    public static func foldHumFrequencyToCarrier(_ rawHz: Double) -> Double {
        guard rawHz.isFinite, rawHz > 20.0 else { return 174.0 }
        var hz = rawHz
        while hz < 120.0 { hz *= 2.0 }
        while hz > 260.0 { hz *= 0.5 }
        return max(120.0, min(260.0, hz))
    }

    public static func timeOfDayWindow(forHour hour: Int) -> ResonancePreset.HourWindow {
        let h = ((hour % 24) + 24) % 24
        switch h {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<22: return .evening
        default: return .midnight
        }
    }

    public static func timeOfDayBanner(forHour hour: Int) -> (title: String, subtitle: String) {
        switch timeOfDayWindow(forHour: hour) {
        case .morning:
            return (
                String(localized: "tod_morning_title", defaultValue: "晨光清澈 · 唤醒心流"),
                String(localized: "tod_morning_sub", defaultValue: "此刻推荐 Alpha 10 Hz 或 Gamma 40 Hz，轻盈进入白昼秩序")
            )
        case .afternoon:
            return (
                String(localized: "tod_afternoon_title", defaultValue: "午间留白 · 重启精力"),
                String(localized: "tod_afternoon_sub", defaultValue: "此刻推荐 6 Hz 午休漂浮或 40 Hz 静默专注")
            )
        case .evening:
            return (
                String(localized: "tod_evening_title", defaultValue: "暮色降温 · 卸下喧嚣"),
                String(localized: "tod_evening_sub", defaultValue: "此刻推荐 Theta 4.8–5.5 Hz 与陶窑暖声床慢慢过渡")
            )
        case .midnight:
            return (
                String(localized: "tod_midnight_title", defaultValue: "夜色沉落 · 安稳伴眠"),
                String(localized: "tod_midnight_sub", defaultValue: "此刻推荐 Delta 1.8–2.5 Hz 与纯黑夜灯柔和低眩光")
            )
        }
    }

    public static func recommendedPresets(forHour hour: Int) -> [ResonancePreset] {
        let win = timeOfDayWindow(forHour: hour)
        let primary = ResonancePreset.all.filter { $0.hourWindow == win }
        if primary.isEmpty {
            return Array(ResonancePreset.all.prefix(3))
        }
        return primary
    }

    public static func orbPulseScale(
        phaseTime: Double,
        beatHz: Double,
        energy: Double,
        frissonCharge: Double,
        reduceMotion: Bool
    ) -> CGFloat {
        let e = energy.isFinite ? max(0.0, min(1.0, energy)) : 0.0
        let f = frissonCharge.isFinite ? max(0.0, min(1.0, frissonCharge)) : 0.0
        guard !reduceMotion else {
            return CGFloat(1.0 + e * 0.025 + f * 0.05)
        }
        let safeT = phaseTime.isFinite ? phaseTime : 0.0
        let visualHz = min(4.2, max(0.6, beatHz * 0.25))
        let slowBreath = sin(safeT * 2.0 * Double.pi * 0.11)
        let ripple = sin(safeT * 2.0 * Double.pi * visualHz)
        let scale = 1.0 + 0.036 * slowBreath + 0.018 * ripple * max(0.3, e) + f * 0.09
        return CGFloat(max(0.88, min(1.16, scale)))
    }

    public static func breathGuidePhase(at time: Double, reduceMotion: Bool) -> (label: String, progress: Double) {
        if reduceMotion {
            return (String(localized: "breath_steady", defaultValue: "跟着缓拍深呼吸"), 0.5)
        }
        let cycle = 9.0
        let t = time.isFinite ? time.truncatingRemainder(dividingBy: cycle) : 0.0
        let wrapped = t < 0 ? t + cycle : t
        if wrapped < 4.0 {
            return (String(localized: "breath_inhale", defaultValue: "缓缓吸气"), wrapped / 4.0)
        } else {
            return (String(localized: "breath_exhale", defaultValue: "慢慢呼气"), (wrapped - 4.0) / 5.0)
        }
    }

    public static func gentleCompanionMessage(
        totalMinutes: Int,
        frissonCount: Int,
        favoriteBand: BrainwaveBand
    ) -> String {
        if totalMinutes <= 0 {
            return String(localized: "companion_first_welcome", defaultValue: "戴上耳机或放在枕边，咩哞陪你开启第一段安静共鸣。")
        }
        if frissonCount > 0 {
            return String(
                format: String(localized: "companion_with_frisson", defaultValue: "已陪你安静停留 %lld 分钟 · 捕捉到 %lld 次温柔心流战栗。"),
                totalMinutes,
                frissonCount
            )
        }
        return String(
            format: String(localized: "companion_minutes_band", defaultValue: "已陪你安静停留 %lld 分钟 · 你最常停在 %@ 声场。"),
            totalMinutes,
            favoriteBand.title
        )
    }
}

/// Offline-only local resonance history store with throttled persistence & corruption clamping.
@MainActor
public final class ResonanceStatsStore: ObservableObject {
    public struct Snapshot: Codable, Equatable, Sendable {
        public var totalMinutes: Int
        public var sessionsCompleted: Int
        public var frissonReleasesCount: Int
        public var bandMinutes: [String: Int]
        public var recentPresetIDs: [String]
        public var favoritePresetIDs: [String]

        public static let empty = Snapshot(
            totalMinutes: 0,
            sessionsCompleted: 0,
            frissonReleasesCount: 0,
            bandMinutes: [:],
            recentPresetIDs: [],
            favoritePresetIDs: []
        )

        public func sanitized() -> Snapshot {
            var cleanBand: [String: Int] = [:]
            for band in BrainwaveBand.allCases {
                let raw = bandMinutes[band.rawValue] ?? 0
                cleanBand[band.rawValue] = max(0, min(500_000, raw))
            }
            return Snapshot(
                totalMinutes: max(0, min(500_000, totalMinutes)),
                sessionsCompleted: max(0, min(100_000, sessionsCompleted)),
                frissonReleasesCount: max(0, min(100_000, frissonReleasesCount)),
                bandMinutes: cleanBand,
                recentPresetIDs: Array(recentPresetIDs.prefix(12)),
                favoritePresetIDs: Array(favoritePresetIDs.prefix(24))
            )
        }
    }

    @Published public private(set) var snapshot: Snapshot
    private let preferences: UserDefaults
    private let storageKey = "app.chimmo.resonance.stats.v2"
    private var accumulatedSecondsByBand: [BrainwaveBand: Double] = [:]
    private var lastPersistTimestamp: TimeInterval = 0
    private var isDirty: Bool = false

    public init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        if let data = preferences.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.snapshot = decoded.sanitized()
        } else {
            self.snapshot = .empty
        }
    }

    public var favoriteBand: BrainwaveBand {
        var bestBand: BrainwaveBand = .alpha
        var bestMinutes = 0
        for band in BrainwaveBand.allCases {
            let mins = snapshot.bandMinutes[band.rawValue] ?? 0
            if mins > bestMinutes {
                bestMinutes = mins
                bestBand = band
            }
        }
        return bestBand
    }

    public func recordResonanceSeconds(_ seconds: TimeInterval, band: BrainwaveBand) {
        guard seconds.isFinite, seconds > 0, seconds <= 3600 else { return }
        let updated = (accumulatedSecondsByBand[band] ?? 0) + seconds
        accumulatedSecondsByBand[band] = updated
        if updated >= 60.0 {
            let wholeMinutes = max(0, min(60, Int((updated / 60.0).rounded(.down))))
            accumulatedSecondsByBand[band] = updated - Double(wholeMinutes) * 60.0
            snapshot.totalMinutes = min(500_000, snapshot.totalMinutes + wholeMinutes)
            let prev = snapshot.bandMinutes[band.rawValue] ?? 0
            snapshot.bandMinutes[band.rawValue] = min(500_000, prev + wholeMinutes)
            isDirty = true
            persistThrottled()
        }
    }

    public func recordSessionCompleted(band: BrainwaveBand) {
        snapshot.sessionsCompleted = min(100_000, snapshot.sessionsCompleted + 1)
        let prev = snapshot.bandMinutes[band.rawValue] ?? 0
        snapshot.bandMinutes[band.rawValue] = max(1, min(500_000, prev))
        isDirty = true
        flush()
    }

    public func recordFrissonPeak() {
        snapshot.frissonReleasesCount = min(100_000, snapshot.frissonReleasesCount + 1)
        isDirty = true
        flush()
    }

    public func recordRecentPreset(_ presetID: String) {
        var next = snapshot.recentPresetIDs.filter { $0 != presetID }
        next.insert(presetID, at: 0)
        if next.count > 6 {
            next = Array(next.prefix(6))
        }
        snapshot.recentPresetIDs = next
        isDirty = true
        flush()
    }

    public func toggleFavoritePreset(_ presetID: String) {
        if let idx = snapshot.favoritePresetIDs.firstIndex(of: presetID) {
            snapshot.favoritePresetIDs.remove(at: idx)
        } else {
            snapshot.favoritePresetIDs.append(presetID)
        }
        isDirty = true
        flush()
    }

    public func isFavorite(_ presetID: String) -> Bool {
        snapshot.favoritePresetIDs.contains(presetID)
    }

    public func flush() {
        guard isDirty else { return }
        persistNow()
    }

    public func resetAllStats() {
        let keptFavorites = snapshot.favoritePresetIDs
        accumulatedSecondsByBand.removeAll()
        snapshot = Snapshot(
            totalMinutes: 0,
            sessionsCompleted: 0,
            frissonReleasesCount: 0,
            bandMinutes: [:],
            recentPresetIDs: [],
            favoritePresetIDs: keptFavorites
        )
        if keptFavorites.isEmpty {
            isDirty = false
            preferences.removeObject(forKey: storageKey)
        } else {
            persistNow()
        }
    }

    private func persistThrottled() {
        let now = CACurrentMediaTime()
        if lastPersistTimestamp == 0 || (now - lastPersistTimestamp) >= 15.0 {
            persistNow()
        }
    }

    private func persistNow() {
        let clean = snapshot.sanitized()
        snapshot = clean
        if let data = try? JSONEncoder().encode(clean) {
            preferences.set(data, forKey: storageKey)
        }
        lastPersistTimestamp = CACurrentMediaTime()
        isDirty = false
    }
}
