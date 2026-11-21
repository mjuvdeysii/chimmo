import SwiftUI

/// 咩哞七小只（调内 1–7 音级正典，见 docs/IP.md）。
public enum ChimmoMember: Int, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case taono = 1  // 1 · 家 (Do)   - 赤陶倒钟共鸣铃（1-3-5 核心）
    case doko = 2   // 2 · 迈步 (Re) - 暖杏陶小木鱼
    case plokko = 3 // 3 · 晴雨 (Mi) - 胭脂珊瑚平衡不倒翁（1-3-5 核心）
    case udo = 4    // 4 · 悬步 (Fa) - 影青瓷小陶笛
    case corllo = 5 // 5 · 远望 (Sol)- 宣瓷螺旋号角贝（1-3-5 核心）
    case bomo = 6   // 6 · 怀旧 (La) - 焙赭陶小手碟
    case tinki = 7  // 7 · 踮脚 (Ti) - 窑赭陶小陀螺尖芽

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
        case .taono: return "1号陶诺，回家主音，稳重落地"
        case .doko: return "2号豆叩，迈步音，轻轻离开家"
        case .plokko: return "3号拍咯，晴雨音，决定大调明朗或小调微酸"
        case .udo: return "4号呜嘟，悬步音，微微向3号靠拢"
        case .corllo: return "5号壳咯，远望支柱，撑起天空"
        case .bomo: return "6号钵莫，怀旧微酸音"
        case .tinki: return "7号叮尖，踮脚张力音，急切想回到1号家"
        }
    }

    public var bodyHex: UInt32 {
        switch self {
        case .taono: return 0xC4513A
        case .doko: return 0xBC6E28
        case .plokko: return 0xCF5B68
        case .udo: return 0x4E8280
        case .corllo: return 0xEFE7D8
        case .bomo: return 0x9A624B
        case .tinki: return 0xB37418
        }
    }

    public var accentHex: UInt32 {
        switch self {
        case .taono: return 0x4A261E
        case .doko: return 0x5A3516
        case .plokko: return 0x3A2C2A
        case .udo: return 0x244241
        case .corllo: return 0xB85D3B
        case .bomo: return 0xE8BD6B
        case .tinki: return 0xFFC45A
        }
    }

    public var nightGlowHex: UInt32 {
        switch self {
        case .taono: return 0xFFB84D
        case .doko: return 0xFFC45A
        case .plokko: return 0xFFC45A
        case .udo: return 0x4FD8CB
        case .corllo: return 0xFFC45A
        case .bomo: return 0xE8BD6B
        case .tinki: return 0xFF7A66
        }
    }

    public var bodyColor: Color { Color(hex: bodyHex) }
    public var accentColor: Color { Color(hex: accentHex) }
    public var nightGlowColor: Color { Color(hex: nightGlowHex) }

    /// 1·3·5 主三和弦核心位（同时作为 29pt App Icon 三人组）。
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
