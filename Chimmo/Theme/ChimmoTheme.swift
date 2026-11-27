import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Mie & Mou warm acoustic kiln aesthetic palette:
/// Cotton paper & indigo night ink, tactile ceramic accents, and WCAG AA (>= 4.5:1) contrast pairs.
public struct ChimmoPalette: Sendable {
    public let isNight: Bool

    // Paper & Surface Layering
    public let paper: Color
    public let cardSurface: Color
    public let primaryInk: Color
    public let secondaryInk: Color
    public let divider: Color

    // Acoustic Accents (WCAG AA checked against paper & cardSurface)
    public let homeAnchor: Color
    public let harmonyWash: Color
    public let nightLampGold: Color

    // Tactile Surface & Landscape Materials
    public let cartoonOutline: Color
    public let storybookHillBack: Color
    public let storybookHillFront: Color

    public var prominentFill: Color {
        isNight ? Color(hex: 0xF29476) : Color(hex: 0xA63C28)
    }

    public var celadonAccent: Color {
        isNight ? Color(hex: 0x7ECBC5) : Color(hex: 0x2B6865)
    }

    public var insetStageSurface: Color {
        isNight ? Color(hex: 0x161E3C) : Color(hex: 0xF3ECE0)
    }

    public var stageBoardSurface: Color {
        isNight ? Color(hex: 0x182143) : Color(hex: 0xFDF9F3)
    }

    /// True OLED black backdrop for Night Lamp Sanctuary.
    public var nightLampBackdrop: Color { Color(hex: 0x000000) }

    public static func elevationShadowColor(
        isNight: Bool,
        dayOpacity: Double = 0.08,
        nightOpacity: Double = 0.24
    ) -> Color {
        isNight
            ? Color(hex: 0x040712).opacity(nightOpacity)
            : Color(hex: 0x3D2E21).opacity(dayOpacity)
    }

    public func elevationShadow(dayOpacity: Double = 0.08, nightOpacity: Double = 0.24) -> Color {
        Self.elevationShadowColor(isNight: isNight, dayOpacity: dayOpacity, nightOpacity: nightOpacity)
    }

    /// High-contrast label ink placed atop prominent filled accent buttons (dark ink on night pastel accents).
    public var contrastInkOnAccent: Color {
        isNight ? Color(hex: 0x0E1326) : Color(hex: 0xFFFFFF)
    }

    public init(isNight: Bool) {
        self.isNight = isNight
        if isNight {
            self.paper = Color(hex: 0x0E1326)
            self.cardSurface = Color(hex: 0x1E2646)
            self.primaryInk = Color(hex: 0xF4EEE2)
            self.secondaryInk = Color(hex: 0xC6CEE8)
            self.divider = Color(hex: 0xF4EEE2).opacity(0.14)

            self.homeAnchor = Color(hex: 0xF29476)
            self.harmonyWash = Color(hex: 0xBAA3FF)
            self.nightLampGold = Color(hex: 0xFFB84D)

            self.cartoonOutline = Color(hex: 0xD8DFF4)
            self.storybookHillBack = Color(hex: 0x192347)
            self.storybookHillFront = Color(hex: 0x141C38)
        } else {
            self.paper = Color(hex: 0xFBF7F0)
            self.cardSurface = Color(hex: 0xFFFDF8)
            self.primaryInk = Color(hex: 0x1C1D19)
            self.secondaryInk = Color(hex: 0x4E4A42)
            self.divider = Color(hex: 0x1C1D19).opacity(0.11)

            self.homeAnchor = Color(hex: 0xA63C28)
            self.harmonyWash = Color(hex: 0x6246A8)
            // Darkened amber for >= 5.5:1 WCAG AA contrast on light paper, cardSurface & tinted pills
            self.nightLampGold = Color(hex: 0x7D4806)

            self.cartoonOutline = Color(hex: 0x1C1D19)
            self.storybookHillBack = Color(hex: 0xECE1CE)
            self.storybookHillFront = Color(hex: 0xE2D3BC)
        }
    }
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init(lightHex: UInt32, darkHex: UInt32, alpha: Double = 1.0) {
        #if os(iOS)
        self.init(
            uiColor: UIColor { traits in
                let hex = (traits.userInterfaceStyle == .dark) ? darkHex : lightHex
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                    green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                    blue: CGFloat(hex & 0xFF) / 255.0,
                    alpha: alpha
                )
            }
        )
        #else
        self.init(hex: lightHex, alpha: alpha)
        #endif
    }
}
