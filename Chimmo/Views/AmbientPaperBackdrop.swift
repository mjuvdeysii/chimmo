import SwiftUI

/// 「摸索台灯」同宇宙声学画纸背景（纯棉纸/深靛夜纸 + 柔和分区采光光洗 / 暖灯琥珀微光 + 静谧低山坡）：
/// 支持系统「减弱透明度」与「减弱动态效果」，并将全部视觉重心让位给前景主角卡片与七声小偶。
public struct AmbientPaperBackdrop: View {
    public let palette: ChimmoPalette
    public var accentTint: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(palette: ChimmoPalette, accentTint: Color? = nil) {
        self.palette = palette
        self.accentTint = accentTint
    }

    public var body: some View {
        let glowTint = accentTint ?? palette.homeAnchor
        ZStack {
            palette.paper

            if !reduceTransparency {
                if palette.isNight {
                    RadialGradient(
                        colors: [
                            palette.nightLampGold.opacity(0.24),
                            palette.nightLampGold.opacity(0.07),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.88, y: 0.04),
                        startRadius: 0,
                        endRadius: 460
                    )
                    RadialGradient(
                        colors: [
                            glowTint.opacity(0.11),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.08, y: 0.88),
                        startRadius: 0,
                        endRadius: 340
                    )
                } else {
                    LinearGradient(
                        stops: [
                            .init(color: glowTint.opacity(0.13), location: 0.0),
                            .init(color: glowTint.opacity(0.04), location: 0.28),
                            .init(color: .clear, location: 0.56)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [glowTint.opacity(0.10), Color.clear],
                        center: UnitPoint(x: 0.90, y: 0.02),
                        startRadius: 0,
                        endRadius: 340
                    )
                }
            }

            Canvas { ctx, size in
                let w = max(1, size.width)
                let h = max(1, size.height)

                drawStorybookHillBand(
                    ctx: &ctx,
                    width: w,
                    height: h,
                    baseTopRatio: 0.82,
                    amplitude: 0.08,
                    phaseShift: 0.4,
                    fill: palette.storybookHillBack.opacity(palette.isNight ? 0.36 : 0.40)
                )
                drawStorybookHillBand(
                    ctx: &ctx,
                    width: w,
                    height: h,
                    baseTopRatio: 0.89,
                    amplitude: 0.07,
                    phaseShift: 2.1,
                    fill: palette.storybookHillFront.opacity(palette.isNight ? 0.46 : 0.52)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: palette.isNight)
    }

    private func drawStorybookHillBand(
        ctx: inout GraphicsContext,
        width: CGFloat,
        height: CGFloat,
        baseTopRatio: CGFloat,
        amplitude: Double,
        phaseShift: Double,
        fill: Color
    ) {
        let profile = StorybookIllustrationLayout.rollingHillProfile(
            sampleCount: 16,
            amplitude: amplitude,
            phaseShift: phaseShift
        )
        guard let first = profile.first else { return }
        let bandHeight = height * 0.22
        let topAnchor = height * baseTopRatio

        let mapped = profile.map { pt in
            CGPoint(
                x: CGFloat(pt.xFraction) * width,
                y: topAnchor + CGFloat(pt.yFraction - 0.5) * bandHeight
            )
        }

        var area = Path()
        area.move(to: CGPoint(x: 0, y: height))
        area.addLine(to: CGPoint(x: CGFloat(first.xFraction) * width, y: mapped[0].y))
        for i in 1..<mapped.count {
            let prev = mapped[i - 1]
            let curr = mapped[i]
            let mid = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
            area.addQuadCurve(to: mid, control: prev)
        }
        if let last = mapped.last {
            area.addLine(to: last)
        }
        area.addLine(to: CGPoint(x: width, y: height))
        area.closeSubpath()

        ctx.fill(area, with: .color(fill))
    }
}
