import SwiftUI

/// 咩哞 · Chimmo 0.5 家族正典双态视觉体系（继承《摸索台灯》与《Mosto》三层法则，并保留年轻清亮的现代明度）：
/// - 日光：清亮暖白纸面（#F8F9FC）+ 纯白纸片（#FFFFFF）+ 柔和投影 + 背景阳光光柱与轻飘微粒；
/// - 夜灯：家族统一深夜蓝（#1B2245）+ 暖琥珀微光（#FFB84D）+ 月白文字（#F4EBDD），深夜不刺眼；
/// - 体积感与鲜活色彩只留给哑光七只咩哞与声学教具本身。
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
    public let homeAnchor: Color       // 家族蓝绿强调色 (#0B7D74 / #4FD8CB)
    public let bassRibbon: Color       // 晴空清蓝 (#228BE6 / #63B3FF)
    public let harmonyWash: Color      // 鸢尾柔紫 (#7048E8 / #A98BFF)
    public let melodyTerracotta: Color // 鲜活珊瑚 (#F24E5B / #FF7A7E)
    public let tensionFilament: Color  // 暖橘张力 (#E8590C / #FFB24D)
    public let nightLampGold: Color    // Otto 同款台灯暖金 (#D99E32 / #FFB84D)

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x1B2245)
            self.shelfSurface = Color(hex: 0x222B56)
            self.cardSurface = Color(hex: 0x26305E)
            self.primaryInk = Color(hex: 0xF4EBDD)
            self.secondaryInk = Color(hex: 0xAEB4CC)
            self.divider = Color(hex: 0xF4EBDD).opacity(0.11)
            self.homeAnchor = Color(hex: 0x4FD8CB)
            self.bassRibbon = Color(hex: 0x63B3FF)
            self.harmonyWash = Color(hex: 0xB197FC)
            self.melodyTerracotta = Color(hex: 0xFF7A7E)
            self.tensionFilament = Color(hex: 0xFFB24D)
            self.nightLampGold = Color(hex: 0xFFB84D)
        } else {
            self.paper = Color(hex: 0xF8F9FC)
            self.shelfSurface = Color(hex: 0xEEF2F8)
            self.cardSurface = Color(hex: 0xFFFFFF)
            self.primaryInk = Color(hex: 0x1C1D19)
            self.secondaryInk = Color(hex: 0x5E5F66)
            self.divider = Color(hex: 0x1C1D19).opacity(0.08)
            self.homeAnchor = Color(hex: 0x0B7D74)
            self.bassRibbon = Color(hex: 0x228BE6)
            self.harmonyWash = Color(hex: 0x7048E8)
            self.melodyTerracotta = Color(hex: 0xF24E5B)
            self.tensionFilament = Color(hex: 0xE8590C)
            self.nightLampGold = Color(hex: 0xD99E32)
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
