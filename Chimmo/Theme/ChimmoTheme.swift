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

    // Flat cartoon storybook card & ink-border primitives
    public let woodTrayTop: Color
    public let woodTrayBottom: Color
    public let brassHairline: Color
    public let glazeHighlight: Color
    public let recessShadow: Color
    public let cartoonOutline: Color
    public let cartoonShadow: Color
    public let storybookButter: Color
    public let storybookMint: Color
    public let storybookHillBack: Color
    public let storybookHillFront: Color

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x0E142C)
            self.shelfSurface = Color(hex: 0x162048)
            self.cardSurface = Color(hex: 0x1D2856)
            self.primaryInk = Color(hex: 0xF5ECDD)
            self.secondaryInk = Color(hex: 0xB3BEDC)
            self.divider = Color(hex: 0xF5ECDD).opacity(0.14)
            self.homeAnchor = Color(hex: 0x53DFCF)
            self.bassRibbon = Color(hex: 0x66B5FF)
            self.harmonyWash = Color(hex: 0xB39BFF)
            self.melodyTerracotta = Color(hex: 0xFF7B82)
            self.tensionFilament = Color(hex: 0xFFB34D)
            self.nightLampGold = Color(hex: 0xFFB94E)
            self.woodTrayTop = Color(hex: 0x172149)
            self.woodTrayBottom = Color(hex: 0x172149)
            self.brassHairline = Color(hex: 0xFFB94E)
            self.glazeHighlight = Color(hex: 0xFFB94E).opacity(0.28)
            self.recessShadow = Color(hex: 0x040714).opacity(0.65)
            self.cartoonOutline = Color(hex: 0xFFB94E)
            self.cartoonShadow = Color(hex: 0x040714).opacity(0.72)
            self.storybookButter = Color(hex: 0x2B2952)
            self.storybookMint = Color(hex: 0x162C46)
            self.storybookHillBack = Color(hex: 0x18234C)
            self.storybookHillFront = Color(hex: 0x213063)
        } else {
            self.paper = Color(hex: 0xF4EDE0)
            self.shelfSurface = Color(hex: 0xEDE1CA)
            self.cardSurface = Color(hex: 0xFFFDF7)
            self.primaryInk = Color(hex: 0x231B15)
            self.secondaryInk = Color(hex: 0x5E5245)
            self.divider = Color(hex: 0x231B15).opacity(0.12)
            self.homeAnchor = Color(hex: 0x0E766E)
            self.bassRibbon = Color(hex: 0x257BD4)
            self.harmonyWash = Color(hex: 0x6C4AD6)
            self.melodyTerracotta = Color(hex: 0xE64B58)
            self.tensionFilament = Color(hex: 0xDE5B18)
            self.nightLampGold = Color(hex: 0xE59900)
            self.woodTrayTop = Color(hex: 0xEFE4CF)
            self.woodTrayBottom = Color(hex: 0xEFE4CF)
            self.brassHairline = Color(hex: 0xC88F2D)
            self.glazeHighlight = Color(hex: 0x231B15).opacity(0.18)
            self.recessShadow = Color(hex: 0x231B15).opacity(0.16)
            self.cartoonOutline = Color(hex: 0x231B15)
            self.cartoonShadow = Color(hex: 0x231B15).opacity(0.18)
            self.storybookButter = Color(hex: 0xFFE49E)
            self.storybookMint = Color(hex: 0xD8F1E7)
            self.storybookHillBack = Color(hex: 0xE6D7BC)
            self.storybookHillFront = Color(hex: 0xD7E6D8)
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
