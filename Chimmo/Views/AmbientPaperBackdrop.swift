import SwiftUI

/// 极简降噪扁平卡通童书底纸（零拟物、零杂乱散点与被遮挡碎云）：
/// 仅保留纯净暖棉纸/深夜蓝画布与底部极克制的无描边双层起伏绘本山坡，将全部视觉重心让位给前景主角舞台。
public struct AmbientPaperBackdrop: View {
    public let palette: ChimmoPalette
    public var accentTint: Color?

    public init(palette: ChimmoPalette, accentTint: Color? = nil) {
        self.palette = palette
        self.accentTint = accentTint
    }

    public var body: some View {
        let _ = accentTint
        ZStack {
            palette.paper

            Canvas { ctx, size in
                let w = max(1, size.width)
                let h = max(1, size.height)

                drawStorybookHillBand(
                    ctx: &ctx,
                    width: w,
                    height: h,
                    baseTopRatio: 0.80,
                    amplitude: 0.09,
                    phaseShift: 0.4,
                    fill: palette.storybookHillBack.opacity(palette.isNight ? 0.50 : 0.55)
                )
                drawStorybookHillBand(
                    ctx: &ctx,
                    width: w,
                    height: h,
                    baseTopRatio: 0.88,
                    amplitude: 0.08,
                    phaseShift: 2.1,
                    fill: palette.storybookHillFront.opacity(palette.isNight ? 0.65 : 0.72)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.35), value: palette.isNight)
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
