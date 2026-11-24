import SwiftUI

/// 咩哞 · Chimmo｜「摸索台灯」同宇宙声学衍生材质体系（窑陶暖纸 × 哑光软胶 × 琥珀夜灯）：
/// - 日光：摸索同源棉纸（#FBF7F0）× 亚麻米底（#F2EBE0）× 纯净纸卡（#FFFFFF）× 窑陶主锚点（#C4513A）；
/// - 夜灯：台灯同源深靛夜纸（#0E1430）× 夜空纸卡（#19213F）× 琥珀暖灯（#FFB547）× 月白文字（#F2E2C4）；
/// - 将浓墨重边褪去，回归轻盈安静的绘本纸感与软胶立体接触光，让七声小偶与乐谱舞台自己发光。
public enum AppearancePreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case auto
    case daylight
    case nightLamp

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return "自动"
        case .daylight: return "日光"
        case .nightLamp: return "夜灯"
        }
    }
}

public struct ChimmoPalette: Sendable {
    public let isNight: Bool

    // Paper & ink (Mossling universe cotton paper & starry night indigo, WCAG >= 4.5:1 solid inks)
    public let paper: Color
    public let shelfSurface: Color
    public let cardSurface: Color
    public let primaryInk: Color
    public let secondaryInk: Color
    public let divider: Color

    // Chimmo signature accents (Kiln Terracotta + Celadon + Otto Lamp Amber)
    public let homeAnchor: Color       // 窑陶赤釉主色 (#C4513A / #F08A6C)
    public let bassRibbon: Color       // 钴蓝低音线 (#3577A8 / #6EB4F2)
    public let harmonyWash: Color      // 紫苑和声 (#6F54B8 / #B39BFF)
    public let melodyTerracotta: Color // 陶诺赤陶 (#C4513A / #F08A6C)
    public let tensionFilament: Color  // 暖橙张力 (#D96B27 / #FFB34D)
    public let nightLampGold: Color    // 台灯琥珀金 (#CF8420 / #FFB547)

    // Soft-vinyl atelier card & subtle ink primitives (backward-compatible properties)
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

    /// 实心主操作键深底色（确保白色文字对比度在日夜双态下均 >= 4.7:1）
    public var prominentFill: Color {
        isNight ? Color(hex: 0xC4513A) : Color(hex: 0xB8442E)
    }

    /// 呜嘟影青瓷辅助强调色（创作工坊与和声微饰专属）
    public var celadonAccent: Color {
        isNight ? Color(hex: 0x7EC8C3) : Color(hex: 0x3D7A77)
    }

    /// 捕梦工坊与声音调色盒内嵌微舞台底色（与棉纸/深靛纸卡自然衔接，消除散落硬编码）
    public var insetStageSurface: Color {
        isNight ? Color(hex: 0x131B38) : Color(hex: 0xF7EFE2)
    }

    /// 主舞台乐谱画布洁净底面（日光极浅米白 / 夜灯深靛黑，避免视线疲劳）
    public var stageBoardSurface: Color {
        isNight ? Color(hex: 0x101733) : Color(hex: 0xFFFDF7)
    }

    /// 巴赫影子月亮对位声部专属银月蓝（日光增强至 >= 4.6:1 可读对比，夜灯呈现温润银蓝月光）
    public static func counterpointMoonHex(isNight: Bool) -> UInt32 {
        isNight ? 0x7EC8E3 : 0x2E7DB2
    }

    public var counterpointMoon: Color {
        Color(hex: Self.counterpointMoonHex(isNight: isNight))
    }

    /// 闭眼夜灯 Zero-Vision OLED 全屏底幕与夜空触觉板阶层
    public var nightLampBackdrop: Color { Color(hex: 0x070B1A) }
    public var nightLampPadSurface: Color { Color(hex: 0x0B112B) }
    public var nightLampHillSurface: Color { Color(hex: 0x121A3D) }

    /// 窑纸软胶接触投影单源公式（日光暖棕 #7A5230，夜灯静谧黑）
    public static func elevationShadowColor(
        isNight: Bool,
        dayOpacity: Double = 0.09,
        nightOpacity: Double = 0.24
    ) -> Color {
        isNight ? Color.black.opacity(nightOpacity) : Color(hex: 0x7A5230).opacity(dayOpacity)
    }

    public func elevationShadow(dayOpacity: Double = 0.09, nightOpacity: Double = 0.24) -> Color {
        Self.elevationShadowColor(isNight: isNight, dayOpacity: dayOpacity, nightOpacity: nightOpacity)
    }

    /// 高亮主题色填充上的前景色（夜灯落深靛 paper 避免刺眼，日光落纯白）
    public var contrastInkOnAccent: Color {
        isNight ? paper : .white
    }

    /// 柔光高亮底面上的高对比前景色（夜灯落深靛 paper，日光落墨黑 primaryInk）
    public var contrastInkOnHighlight: Color {
        isNight ? paper : primaryInk
    }

    /// 绘本陶偶头饰统一暖黄柔光色
    public static var warmButterHighlight: Color {
        Color(hex: 0xFFE49E)
    }

    /// 绘本陶偶雕塑轮廓深色（仅用于主角/小偶陶瓷线稿）
    public var figureContourInk: Color {
        isNight ? Color(hex: 0x0A0F24) : Color(hex: 0x231B15)
    }

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x0E1430)
            self.shelfSurface = Color(hex: 0x212A4C)
            self.cardSurface = Color(hex: 0x19213F)
            self.primaryInk = Color(hex: 0xF2E2C4)
            self.secondaryInk = Color(hex: 0xB8BED4)
            self.divider = Color(hex: 0xF2E2C4).opacity(0.12)
            self.homeAnchor = Color(hex: 0xF08A6C)
            self.bassRibbon = Color(hex: 0x6EB4F2)
            self.harmonyWash = Color(hex: 0xB39BFF)
            self.melodyTerracotta = Color(hex: 0xF08A6C)
            self.tensionFilament = Color(hex: 0xFFB34D)
            self.nightLampGold = Color(hex: 0xFFB547)
            self.woodTrayTop = Color(hex: 0x1E2748)
            self.woodTrayBottom = Color(hex: 0x161E3B)
            self.brassHairline = Color(hex: 0xFFB547)
            self.glazeHighlight = Color(hex: 0xFFB547).opacity(0.22)
            self.recessShadow = Color.black.opacity(0.32)
            self.cartoonOutline = Color(hex: 0xFFB547)
            self.cartoonShadow = Color.black.opacity(0.26)
            self.storybookButter = Color(hex: 0x2A2D4F)
            self.storybookMint = Color(hex: 0x1D334A)
            self.storybookHillBack = Color(hex: 0x151D40)
            self.storybookHillFront = Color(hex: 0x1B2650)
        } else {
            self.paper = Color(hex: 0xFBF7F0)
            self.shelfSurface = Color(hex: 0xF2EBE0)
            self.cardSurface = Color(hex: 0xFFFFFF)
            self.primaryInk = Color(hex: 0x1C1D19)
            self.secondaryInk = Color(hex: 0x4D4E55)
            self.divider = Color(hex: 0x1C1D19).opacity(0.10)
            self.homeAnchor = Color(hex: 0xC4513A)
            self.bassRibbon = Color(hex: 0x3577A8)
            self.harmonyWash = Color(hex: 0x6F54B8)
            self.melodyTerracotta = Color(hex: 0xC4513A)
            self.tensionFilament = Color(hex: 0xD96B27)
            self.nightLampGold = Color(hex: 0xCF8420)
            self.woodTrayTop = Color(hex: 0xF4ECE0)
            self.woodTrayBottom = Color(hex: 0xEFE6D8)
            self.brassHairline = Color(hex: 0xC4513A)
            self.glazeHighlight = Color.white.opacity(0.88)
            self.recessShadow = Color(hex: 0x7A5230).opacity(0.11)
            self.cartoonOutline = Color(hex: 0x1C1D19)
            self.cartoonShadow = Color(hex: 0x7A5230).opacity(0.12)
            self.storybookButter = Color(hex: 0xFCF0D5)
            self.storybookMint = Color(hex: 0xE6F2EE)
            self.storybookHillBack = Color(hex: 0xEFE6D8)
            self.storybookHillFront = Color(hex: 0xE5ECE5)
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
