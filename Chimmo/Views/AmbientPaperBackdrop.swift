import SwiftUI

/// Ambient cotton paper / indigo night sky canvas with gentle circadian horizon hills.
public struct AmbientPaperBackdrop: View {
    public let palette: ChimmoPalette
    public var tint: Color?
    public var bandAccent: Color?

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(palette: ChimmoPalette, tint: Color? = nil, bandAccent: Color? = nil) {
        self.palette = palette
        self.tint = tint
        self.bandAccent = bandAccent
    }

    public var body: some View {
        let highClarity = reduceTransparency || contrast == .increased
        ZStack {
            palette.paper.ignoresSafeArea()

            // Subtle upper ceramic atmosphere wash (disabled when Reduce Transparency / Increase Contrast is enabled)
            if StorybookSurfaceClarityPolicy.showsTranslucentTintWash(reduceTransparency: highClarity) {
                GeometryReader { geo in
                    let w = max(1, geo.size.width)
                    let h = max(1, geo.size.height)
                    let washColor = bandAccent ?? tint ?? (palette.isNight ? palette.nightLampGold : palette.homeAnchor)

                    RadialGradient(
                        colors: [
                            washColor.opacity(palette.isNight ? 0.14 : 0.08),
                            Color.clear
                        ],
                        center: .init(x: 0.5, y: 0.24),
                        startRadius: 12,
                        endRadius: max(w, h) * 0.56
                    )
                    .ignoresSafeArea()
                }
            }

            // Subtle cotton-paper mineral grain & rolling hills near bottom edge
            Canvas { ctx, size in
                let w = max(1, size.width)
                let h = max(1, size.height)
                let ridgeInk = contrast == .increased ? palette.primaryInk.opacity(0.32) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.10)

                if !highClarity {
                    let speckColor = palette.primaryInk.opacity(palette.isNight ? 0.032 : 0.026)
                    for idx in 0..<84 {
                        let hx = UInt64((idx &* 2654435761) & 0xFFFF)
                        let hy = UInt64(((idx &+ 37) &* 2246822519) & 0xFFFF)
                        let x = (CGFloat(hx) / 65535.0) * w
                        let y = (CGFloat(hy) / 65535.0) * h
                        let r: CGFloat = idx.isMultiple(of: 3) ? 1.4 : 0.9
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(speckColor))
                    }
                }

                drawKilnHillBand(
                    ctx: &ctx,
                    width: w,
                    height: h,
                    yFrac: palette.isNight ? 0.875 : 0.86,
                    amplitude: 0.13,
                    phase: 0.5,
                    fill: palette.storybookHillBack.opacity(palette.isNight ? 0.55 : 0.65),
                    outline: ridgeInk
                )
                drawKilnHillBand(
                    ctx: &ctx,
                    width: w,
                    height: h,
                    yFrac: palette.isNight ? 0.925 : 0.915,
                    amplitude: 0.10,
                    phase: 1.75,
                    fill: palette.storybookHillFront.opacity(palette.isNight ? 0.72 : 0.82),
                    outline: ridgeInk
                )
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private func drawKilnHillBand(
        ctx: inout GraphicsContext,
        width: CGFloat,
        height: CGFloat,
        yFrac: CGFloat,
        amplitude: Double,
        phase: Double,
        fill: Color,
        outline: Color
    ) {
        let profile = KilnLandscapeGeometry.rollingHillProfile(
            sampleCount: 16,
            amplitude: amplitude,
            phaseShift: phase
        )
        guard let first = profile.first else { return }
        let topOffset = height * yFrac
        let bandHeight: CGFloat = 40
        let mapped = profile.map { pt in
            CGPoint(x: CGFloat(pt.xFraction) * width, y: topOffset + CGFloat(pt.yFraction - 0.5) * bandHeight)
        }

        var fillPath = Path()
        fillPath.move(to: CGPoint(x: 0, y: height))
        fillPath.addLine(to: CGPoint(x: CGFloat(first.xFraction) * width, y: mapped[0].y))

        var ridgePath = Path()
        ridgePath.move(to: mapped[0])

        for i in 1..<mapped.count {
            let prev = mapped[i - 1]
            let curr = mapped[i]
            let mid = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
            fillPath.addQuadCurve(to: mid, control: prev)
            ridgePath.addQuadCurve(to: mid, control: prev)
        }
        if let last = mapped.last {
            fillPath.addLine(to: last)
            ridgePath.addLine(to: last)
        }
        fillPath.addLine(to: CGPoint(x: width, y: height))
        fillPath.closeSubpath()

        ctx.fill(fillPath, with: .color(fill))
        ctx.stroke(ridgePath, with: .color(outline), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }
}
