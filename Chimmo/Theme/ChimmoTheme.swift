import SwiftUI

/// 咩哞 · Chimmo 窑陶 × 蜂蜡桦木 × 拉丝黄铜高定双态材质体系：
/// - 日光：暖窑象牙宣纸（#F4EDE0）× 蜂蜡桦木托盘 × 哑光暖瓷（#FBF7EE）× 拉丝黄铜（#C88F2D）；
/// - 夜灯：深夜天鹅绒靛蓝（#0E142C）× 烟熏胡桃木 × 暖钨丝琥珀（#FFB94E）× 月白文字（#F5ECDD）；
/// - 体积感与鲜活釉彩只留给哑光窑陶小偶与声学琴块本身。
public enum AppearancePreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case auto
    case daylight
    case nightLamp

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return "自动"
        case .daylight: return "浅色"
        case .nightLamp: return "深色"
        }
    }
}

public struct ChimmoPalette: Sendable {
    public let isNight: Bool

    // Paper & ink (WCAG 2.1 ≥ 4.5:1 solid inks, never washed-out translucent secondary)
    public let paper: Color
    public let shelfSurface: Color
    public let cardSurface: Color
    public let primaryInk: Color
    public let secondaryInk: Color
    public let divider: Color

    // Family-harmonized youthful accents
    public let homeAnchor: Color       // 家族蓝绿强调色 (#0E766E / #53DFCF)
    public let bassRibbon: Color       // 晴空清蓝 (#257BD4 / #66B5FF)
    public let harmonyWash: Color      // 鸢尾柔紫 (#6C4AD6 / #B39BFF)
    public let melodyTerracotta: Color // 鲜活珊瑚 (#E64B58 / #FF7B82)
    public let tensionFilament: Color  // 暖橘张力 (#DE5B18 / #FFB34D)
    public let nightLampGold: Color    // 暖钨丝琥珀 (#C88F2D / #FFB94E)

    // Physical kiln-ceramic, wood resonator tray & brushed brass primitives
    public let woodTrayTop: Color
    public let woodTrayBottom: Color
    public let brassHairline: Color
    public let glazeHighlight: Color
    public let recessShadow: Color

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x0E142C)
            self.shelfSurface = Color(hex: 0x172042)
            self.cardSurface = Color(hex: 0x1D274E)
            self.primaryInk = Color(hex: 0xF5ECDD)
            self.secondaryInk = Color(hex: 0xA7B0CE)
            self.divider = Color(hex: 0xF5ECDD).opacity(0.11)
            self.homeAnchor = Color(hex: 0x53DFCF)
            self.bassRibbon = Color(hex: 0x66B5FF)
            self.harmonyWash = Color(hex: 0xB39BFF)
            self.melodyTerracotta = Color(hex: 0xFF7B82)
            self.tensionFilament = Color(hex: 0xFFB34D)
            self.nightLampGold = Color(hex: 0xFFB94E)
            self.woodTrayTop = Color(hex: 0x22294A)
            self.woodTrayBottom = Color(hex: 0x131934)
            self.brassHairline = Color(hex: 0xE5AA4A)
            self.glazeHighlight = Color.white.opacity(0.14)
            self.recessShadow = Color.black.opacity(0.42)
        } else {
            self.paper = Color(hex: 0xF4EDE0)
            self.shelfSurface = Color(hex: 0xE7DEC9)
            self.cardSurface = Color(hex: 0xFBF7EE)
            self.primaryInk = Color(hex: 0x1E1B16)
            self.secondaryInk = Color(hex: 0x635B4F)
            self.divider = Color(hex: 0x1E1B16).opacity(0.09)
            self.homeAnchor = Color(hex: 0x0E766E)
            self.bassRibbon = Color(hex: 0x257BD4)
            self.harmonyWash = Color(hex: 0x6C4AD6)
            self.melodyTerracotta = Color(hex: 0xE64B58)
            self.tensionFilament = Color(hex: 0xDE5B18)
            self.nightLampGold = Color(hex: 0xC88F2D)
            self.woodTrayTop = Color(hex: 0xDFCFAF)
            self.woodTrayBottom = Color(hex: 0xC7B08A)
            self.brassHairline = Color(hex: 0xC88F2D)
            self.glazeHighlight = Color.white.opacity(0.78)
            self.recessShadow = Color(hex: 0x3A2E1E).opacity(0.14)
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
