import SwiftUI

/// 咩哞 · Chimmo 0.3 年轻明亮双态视觉体系：晴空奶白纸面 + 午夜星云清蓝。
/// 保留高对比可读性（WCAG 2.1 正文 ≥ 4.5:1），整体更轻盈、鲜活、现代。
public enum AppearancePreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case auto
    case daylight
    case nightLamp

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return "自动"
        case .daylight: return "晴空"
        case .nightLamp: return "星夜"
        }
    }
}

public struct ChimmoPalette: Sendable {
    public let isNight: Bool

    // Stage & typography
    public let paper: Color
    public let shelfSurface: Color
    public let cardSurface: Color
    public let primaryInk: Color
    public let secondaryInk: Color
    public let divider: Color

    // Semantic music encoding (Fresh, youthful, energetic)
    public let homeAnchor: Color       // Fresh Mint-Teal (#0CA678 / #38E4C0)
    public let bassRibbon: Color       // Crisp Azure (#228BE6 / #63B3FF)
    public let harmonyWash: Color      // Dreamy Iris-Violet (#7950F2 / #A98BFF)
    public let melodyTerracotta: Color // Vivid Coral-Pop (#FF5A5F / #FF7A7E)
    public let tensionFilament: Color  // Juicy Tangerine-Amber (#F06529 / #FFB24D)
    public let nightLampGold: Color    // Sunny Lemon-Gold (#F5B82E / #FFE066)

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x10172A)
            self.shelfSurface = Color(hex: 0x18223D)
            self.cardSurface = Color(hex: 0x1E2947)
            self.primaryInk = Color(hex: 0xF4F7FF)
            self.secondaryInk = Color(hex: 0x9BA9C9)
            self.divider = Color(hex: 0xE2ECFF).opacity(0.11)
            self.homeAnchor = Color(hex: 0x38E4C0)
            self.bassRibbon = Color(hex: 0x63B3FF)
            self.harmonyWash = Color(hex: 0xA98BFF)
            self.melodyTerracotta = Color(hex: 0xFF7A7E)
            self.tensionFilament = Color(hex: 0xFFB24D)
            self.nightLampGold = Color(hex: 0xFFE066)
        } else {
            self.paper = Color(hex: 0xF7F9FE)
            self.shelfSurface = Color(hex: 0xEEF3FB)
            self.cardSurface = Color(hex: 0xFFFFFF)
            self.primaryInk = Color(hex: 0x182135)
            self.secondaryInk = Color(hex: 0x5A6680)
            self.divider = Color(hex: 0x182135).opacity(0.08)
            self.homeAnchor = Color(hex: 0x0B9970)
            self.bassRibbon = Color(hex: 0x228BE6)
            self.harmonyWash = Color(hex: 0x7048E8)
            self.melodyTerracotta = Color(hex: 0xF24E5B)
            self.tensionFilament = Color(hex: 0xE8590C)
            self.nightLampGold = Color(hex: 0xE6A100)
        }
    }
}

public extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
