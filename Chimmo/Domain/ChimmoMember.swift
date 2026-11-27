import SwiftUI

/// Seven kiln ceramic-glaze scale members (1-7) with shape, numeral, and name encodings.
public enum ChimmoMember: Int, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case taono = 1
    case doko = 2
    case plokko = 3
    case udo = 4
    case corllo = 5
    case bomo = 6
    case tinki = 7

    public var id: Int { rawValue }
    public var degree: Int { rawValue }

    public var chineseName: String {
        switch self {
        case .taono: return "陶诺"
        case .doko: return "豆叩"
        case .plokko: return "拍咯"
        case .udo: return "呜嘟"
        case .corllo: return "壳咯"
        case .bomo: return "钵莫"
        case .tinki: return "叮尖"
        }
    }

    public var englishName: String {
        switch self {
        case .taono: return "Taono"
        case .doko: return "Doko"
        case .plokko: return "Plokko"
        case .udo: return "Udo"
        case .corllo: return "Corllo"
        case .bomo: return "Bomo"
        case .tinki: return "Tinki"
        }
    }

    public var localizedName: String {
        switch self {
        case .taono: return String(localized: "member_name_taono", defaultValue: "陶诺")
        case .doko: return String(localized: "member_name_doko", defaultValue: "豆叩")
        case .plokko: return String(localized: "member_name_plokko", defaultValue: "拍咯")
        case .udo: return String(localized: "member_name_udo", defaultValue: "呜嘟")
        case .corllo: return String(localized: "member_name_corllo", defaultValue: "壳咯")
        case .bomo: return String(localized: "member_name_bomo", defaultValue: "钵莫")
        case .tinki: return String(localized: "member_name_tinki", defaultValue: "叮尖")
        }
    }

    public var solfege: String {
        switch self {
        case .taono: return "Do"
        case .doko: return "Re"
        case .plokko: return "Mi"
        case .udo: return "Fa"
        case .corllo: return "Sol"
        case .bomo: return "La"
        case .tinki: return "Ti"
        }
    }

    public var roleLabel: String {
        switch self {
        case .taono: return String(localized: "member_role_taono", defaultValue: "家")
        case .doko: return String(localized: "member_role_doko", defaultValue: "迈步")
        case .plokko: return String(localized: "member_role_plokko", defaultValue: "晴雨")
        case .udo: return String(localized: "member_role_udo", defaultValue: "悬步")
        case .corllo: return String(localized: "member_role_corllo", defaultValue: "远望")
        case .bomo: return String(localized: "member_role_bomo", defaultValue: "怀旧")
        case .tinki: return String(localized: "member_role_tinki", defaultValue: "踮脚")
        }
    }

    public var voiceOverSummary: String {
        switch self {
        case .taono: return String(localized: "member_vo_taono", defaultValue: "1 Do，主音")
        case .doko: return String(localized: "member_vo_doko", defaultValue: "2 Re")
        case .plokko: return String(localized: "member_vo_plokko", defaultValue: "3 Mi，决定明亮或忧郁")
        case .udo: return String(localized: "member_vo_udo", defaultValue: "4 Fa")
        case .corllo: return String(localized: "member_vo_corllo", defaultValue: "5 Sol")
        case .bomo: return String(localized: "member_vo_bomo", defaultValue: "6 La，抒情音")
        case .tinki: return String(localized: "member_vo_tinki", defaultValue: "7 Ti，倾向回到 1")
        }
    }

    public var bodyHex: UInt32 {
        switch self {
        case .taono: return 0xC85042
        case .doko: return 0xC97836
        case .plokko: return 0xB85672
        case .udo: return 0x2F8F76
        case .corllo: return 0x3B74A8
        case .bomo: return 0x7A5EC2
        case .tinki: return 0xC68824
        }
    }

    public var accentHex: UInt32 {
        switch self {
        case .taono: return 0x8F1D28
        case .doko: return 0x8A420A
        case .plokko: return 0x861942
        case .udo: return 0x085E45
        case .corllo: return 0x0F4C8A
        case .bomo: return 0x3F2299
        case .tinki: return 0x7A4E00
        }
    }

    public var nightGlowHex: UInt32 {
        switch self {
        case .taono: return 0xFF7B88
        case .doko: return 0xFFB066
        case .plokko: return 0xFF7AA9
        case .udo: return 0x45E6BB
        case .corllo: return 0x6BB9FF
        case .bomo: return 0xBCA3FF // >= 6.8:1 against dark ink #0E1326
        case .tinki: return 0xFFDF5E
        }
    }

    public var bodyColor: Color { Color(hex: bodyHex) }
    public var accentColor: Color { Color(hex: accentHex) }
    public var nightGlowColor: Color { Color(hex: nightGlowHex) }

    public var isTriadPillar: Bool {
        self == .taono || self == .plokko || self == .corllo
    }

    public var isTensionDegree: Bool {
        self == .udo || self == .tinki
    }

    public var resolutionTargetDegree: Int {
        switch self {
        case .tinki: return 1
        case .udo: return 3
        default: return degree
        }
    }

    public static func from(degree: Int) -> ChimmoMember {
        let clamped = max(1, min(7, degree))
        return ChimmoMember(rawValue: clamped) ?? .taono
    }
}
