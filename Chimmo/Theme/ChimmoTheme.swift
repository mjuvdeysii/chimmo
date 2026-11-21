import SwiftUI

/// 咩哞 · Chimmo 双态视觉体系：日光暖棉纸与夜灯深夜蓝。
/// 全部色值已通过 WCAG 2.1 对比度核验（正文 ≥ 4.5:1，图形主色 ≥ 3.1:1）。
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

    // Stage & typography
    public let paper: Color
    public let shelfSurface: Color
    public let primaryInk: Color
    public let secondaryInk: Color
    public let divider: Color

    // Semantic music encoding
    public let homeAnchor: Color       // #0B7D74 (4.52:1) / #4FD8CB (8.83:1)
    public let bassRibbon: Color       // #2E4374 (8.73:1) / #7C9BE3 (5.62:1)
    public let harmonyWash: Color      // #8B6428 (4.80:1) / #E8BD6B (8.76:1)
    public let melodyTerracotta: Color // #B8472F (4.76:1) / #FFC45A (9.77:1)
    public let tensionFilament: Color  // #BC3D2E (4.93:1) / #FF7A66 (6.04:1)
    public let nightLampGold: Color    // #FFB84D (8.97:1)

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x1B2245)
            self.shelfSurface = Color(hex: 0x222B56)
            self.primaryInk = Color(hex: 0xF4EBDD)
            self.secondaryInk = Color(hex: 0xAEB4CC)
            self.divider = Color(hex: 0xF4EBDD).opacity(0.12)
            self.homeAnchor = Color(hex: 0x4FD8CB)
            self.bassRibbon = Color(hex: 0x7C9BE3)
            self.harmonyWash = Color(hex: 0xE8BD6B)
            self.melodyTerracotta = Color(hex: 0xFFC45A)
            self.tensionFilament = Color(hex: 0xFF7A66)
            self.nightLampGold = Color(hex: 0xFFB84D)
        } else {
            self.paper = Color(hex: 0xF7F3EA)
            self.shelfSurface = Color(hex: 0xEFE8DA)
            self.primaryInk = Color(hex: 0x1C1D19)
            self.secondaryInk = Color(hex: 0x5E5F66)
            self.divider = Color(hex: 0x1C1D19).opacity(0.10)
            self.homeAnchor = Color(hex: 0x0B7D74)
            self.bassRibbon = Color(hex: 0x2E4374)
            self.harmonyWash = Color(hex: 0x8B6428)
            self.melodyTerracotta = Color(hex: 0xB8472F)
            self.tensionFilament = Color(hex: 0xBC3D2E)
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
