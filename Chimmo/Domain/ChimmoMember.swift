import SwiftUI

/// 咩哞七小只（调内 1–7 音级正典，采用鲜活年轻的彩虹陶釉色板 + 形状/数字/名称三重无障碍编码）。
public enum ChimmoMember: Int, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case taono = 1  // 1 · 家 (Do)   - 珊瑚红陶钟（1-3-5 核心）
    case doko = 2   // 2 · 迈步 (Re) - 鲜橘小木鱼
    case plokko = 3 // 3 · 晴雨 (Mi) - 莓果粉不倒翁（1-3-5 核心）
    case udo = 4    // 4 · 悬步 (Fa) - 薄荷青小陶笛
    case corllo = 5 // 5 · 远望 (Sol)- 晴空蓝螺旋贝（1-3-5 核心）
    case bomo = 6   // 6 · 怀旧 (La) - 鸢尾紫小手碟
    case tinki = 7  // 7 · 踮脚 (Ti) - 暖阳黄小陀螺

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
        case .taono: return "家"
        case .doko: return "迈步"
        case .plokko: return "晴雨"
        case .udo: return "悬步"
        case .corllo: return "远望"
        case .bomo: return "怀旧"
        case .tinki: return "踮脚"
        }
    }

    public var voiceOverSummary: String {
        switch self {
        case .taono: return "1 Do，主音"
        case .doko: return "2 Re"
        case .plokko: return "3 Mi，决定明亮或忧郁"
        case .udo: return "4 Fa"
        case .corllo: return "5 Sol"
        case .bomo: return "6 La，抒情音"
        case .tinki: return "7 Si，倾向回到 1"
        }
    }

    public var bodyHex: UInt32 {
        switch self {
        case .taono: return 0xF25563  // 活力珊瑚红
        case .doko: return 0xF7882F   // 清爽鲜橘
        case .plokko: return 0xE64980 // 亮莓果粉
        case .udo: return 0x12B886    // 鲜薄荷青
        case .corllo: return 0x228BE6 // 晴空清蓝
        case .bomo: return 0x7950F2   // 梦幻鸢尾紫
        case .tinki: return 0xE59900  // 向日葵暖金
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
        case .taono: return 0xFF7582
        case .doko: return 0xFFA959
        case .plokko: return 0xFF74A6
        case .udo: return 0x38E4B7
        case .corllo: return 0x5CB3FF
        case .bomo: return 0xA98BFF
        case .tinki: return 0xFFD94A
        }
    }

    public var bodyColor: Color { Color(hex: bodyHex) }
    public var accentColor: Color { Color(hex: accentHex) }
    public var nightGlowColor: Color { Color(hex: nightGlowHex) }

    /// 1·3·5 主三和弦核心位。
    public var isTriadPillar: Bool {
        self == .taono || self == .plokko || self == .corllo
    }

    /// 4 级（向 3 下行牵引）与 7 级（向高八度 1 强烈上行牵引）为天然张力音级。
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
