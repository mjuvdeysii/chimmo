import SwiftUI

/// 零能耗静态手抄陶纸声学桌面背景层（无全屏持续 `TimelineView` 重绘）：
/// 结合斜向工作室窗光 / 夜灯暖钨丝光晕、四周微暗角景深与 120 颗确定性宣纸矿物微粒/纤维肌理，
/// 让主画布与木琴独享 120Hz 算力的同时呈现实体桌面材质触感。
public struct AmbientPaperBackdrop: View {
    public let palette: ChimmoPalette
    public var accentTint: Color?

    public init(palette: ChimmoPalette, accentTint: Color? = nil) {
        self.palette = palette
        self.accentTint = accentTint
    }

    public var body: some View {
        let tint = accentTint ?? palette.homeAnchor
        ZStack {
            palette.paper

            if palette.isNight {
                RadialGradient(
                    colors: [
                        palette.nightLampGold.opacity(0.18),
                        tint.opacity(0.08),
                        .clear
                    ],
                    center: UnitPoint(x: 0.50, y: 0.16),
                    startRadius: 10,
                    endRadius: 430
                )

                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.32)],
                    center: .center,
                    startRadius: 180,
                    endRadius: 560
                )
            } else {
                RadialGradient(
                    colors: [
                        Color(hex: 0xFFE3A6).opacity(0.30),
                        tint.opacity(0.08),
                        .clear
                    ],
                    center: UnitPoint(x: 0.86, y: 0.06),
                    startRadius: 12,
                    endRadius: 500
                )

                // 斜向柔和工作室窗光束
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.30),
                        tint.opacity(0.05),
                        Color(hex: 0xD8C6A8).opacity(0.14)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }

            // 静态确定性手抄陶纸矿物微粒与微纤维纹理
            Canvas { ctx, size in
                let w = max(1, size.width)
                let h = max(1, size.height)
                let speckDark = palette.isNight ? Color.white.opacity(0.045) : Color(hex: 0x5A4832).opacity(0.055)
                let speckWarm = palette.isNight ? palette.nightLampGold.opacity(0.055) : Color.white.opacity(0.38)
                let fiberInk = palette.isNight ? Color.white.opacity(0.028) : Color(hex: 0x7A654A).opacity(0.045)

                for i in 0..<120 {
                    let s1 = Double((i * 73 + 19) % 997) / 997.0
                    let s2 = Double((i * 137 + 53) % 991) / 991.0
                    let s3 = Double((i * 41 + 7) % 89) / 89.0
                    let px = CGFloat(s1) * w
                    let py = CGFloat(s2) * h
                    let r = CGFloat(0.55 + s3 * 0.70)
                    let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(i % 3 == 0 ? speckWarm : speckDark))

                    if i % 5 == 0 {
                        let ang = CGFloat(s3 * Double.pi)
                        let len = CGFloat(4.5 + s1 * 5.5)
                        var fiber = Path()
                        fiber.move(to: CGPoint(x: px, y: py))
                        fiber.addLine(to: CGPoint(x: px + cos(ang) * len, y: py + sin(ang) * len))
                        ctx.stroke(fiber, with: .color(fiberInk), lineWidth: 0.65)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.55), value: palette.isNight)
    }
}
