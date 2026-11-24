import SwiftUI

/// 扁平卡通童书绘本全画幅背景舞台（零拟物、零无意义留白、零高耗能 60Hz 重绘）：
/// 用明快平涂纸艺云朵、角落小太阳 / 夜灯新月星辰、双层童话小山坡与星点音阶符号铺陈完整绘本语境。
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

            Canvas { ctx, size in
                let w = max(1, size.width)
                let h = max(1, size.height)
                let outline = palette.cartoonOutline.opacity(palette.isNight ? 0.32 : 0.22)
                let lineStroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

                // 1. 顶部绘本角落太阳（日光）或新月星辰（夜灯）
                if palette.isNight {
                    let moonCenter = CGPoint(x: w * 0.86, y: h * 0.11)
                    var crescent = Path()
                    crescent.addArc(center: moonCenter, radius: 22, startAngle: .degrees(30), endAngle: .degrees(290), clockwise: false)
                    crescent.addQuadCurve(
                        to: CGPoint(x: moonCenter.x + 22 * cos(30 * .pi / 180), y: moonCenter.y + 22 * sin(30 * .pi / 180)),
                        control: CGPoint(x: moonCenter.x - 4, y: moonCenter.y - 2)
                    )
                    ctx.fill(crescent, with: .color(palette.nightLampGold.opacity(0.82)))
                    ctx.stroke(crescent, with: .color(outline), style: lineStroke)

                    let starPts: [CGPoint] = [
                        CGPoint(x: w * 0.14, y: h * 0.10),
                        CGPoint(x: w * 0.28, y: h * 0.16),
                        CGPoint(x: w * 0.68, y: h * 0.08),
                        CGPoint(x: w * 0.74, y: h * 0.18),
                        CGPoint(x: w * 0.92, y: h * 0.24)
                    ]
                    for (idx, sp) in starPts.enumerated() {
                        drawPaperStar(ctx: &ctx, center: sp, radius: idx.isMultiple(of: 2) ? 6.5 : 4.5, color: palette.nightLampGold.opacity(0.68))
                    }
                } else {
                    let sunCenter = CGPoint(x: w * 0.87, y: h * 0.10)
                    let sunDisc = Path(ellipseIn: CGRect(x: sunCenter.x - 22, y: sunCenter.y - 22, width: 44, height: 44))
                    ctx.fill(sunDisc, with: .color(palette.storybookButter))
                    ctx.stroke(sunDisc, with: .color(outline), style: lineStroke)
                    for i in 0..<8 {
                        let ang = Double(i) * Double.pi / 4.0
                        let p0 = CGPoint(x: sunCenter.x + CGFloat(cos(ang)) * 28, y: sunCenter.y + CGFloat(sin(ang)) * 28)
                        let p1 = CGPoint(x: sunCenter.x + CGFloat(cos(ang)) * 36, y: sunCenter.y + CGFloat(sin(ang)) * 36)
                        var ray = Path()
                        ray.move(to: p0)
                        ray.addLine(to: p1)
                        ctx.stroke(ray, with: .color(palette.brassHairline.opacity(0.55)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                }

                // 2. 扁平纸艺云朵（消灭上半屏空白边缘）
                drawPaperCloud(
                    ctx: &ctx,
                    center: CGPoint(x: w * 0.18, y: h * 0.14),
                    scale: 0.95,
                    fill: palette.cardSurface.opacity(palette.isNight ? 0.18 : 0.78),
                    outline: outline
                )
                drawPaperCloud(
                    ctx: &ctx,
                    center: CGPoint(x: w * 0.60, y: h * 0.13),
                    scale: 0.72,
                    fill: palette.cardSurface.opacity(palette.isNight ? 0.14 : 0.65),
                    outline: outline
                )

                // 3. 点缀调性音符微星（呼应当前调式情绪色）
                for i in 0..<18 {
                    let fx = Double((i * 73 + 11) % 97) / 97.0
                    let fy = 0.22 + Double((i * 47 + 23) % 58) / 100.0
                    let r: CGFloat = i.isMultiple(of: 3) ? 3.2 : 2.0
                    let pt = CGPoint(x: CGFloat(fx) * w, y: CGFloat(fy) * h)
                    let dot = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
                    ctx.fill(dot, with: .color(i.isMultiple(of: 4) ? tint.opacity(0.26) : palette.nightLampGold.opacity(0.24)))
                }

                // 4. 下半幅双层扁平卡通起伏山坡（平涂水粉 + 清晰绘本轮廓线）
                drawStorybookHillBand(
                    ctx: &ctx,
                    size: size,
                    baseTopRatio: 0.66,
                    amplitude: 0.16,
                    phaseShift: 0.4,
                    fill: palette.storybookHillBack,
                    outline: outline
                )
                drawStorybookHillBand(
                    ctx: &ctx,
                    size: size,
                    baseTopRatio: 0.78,
                    amplitude: 0.14,
                    phaseShift: 2.1,
                    fill: palette.storybookHillFront,
                    outline: outline
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.35), value: palette.isNight)
    }

    private func drawPaperCloud(
        ctx: inout GraphicsContext,
        center: CGPoint,
        scale: CGFloat,
        fill: Color,
        outline: Color
    ) {
        var cloud = Path()
        cloud.addRoundedRect(
            in: CGRect(x: center.x - 36 * scale, y: center.y - 6 * scale, width: 72 * scale, height: 22 * scale),
            cornerSize: CGSize(width: 11 * scale, height: 11 * scale)
        )
        cloud.addEllipse(in: CGRect(x: center.x - 24 * scale, y: center.y - 20 * scale, width: 32 * scale, height: 28 * scale))
        cloud.addEllipse(in: CGRect(x: center.x - 4 * scale, y: center.y - 16 * scale, width: 28 * scale, height: 24 * scale))
        ctx.fill(cloud, with: .color(fill))
        ctx.stroke(cloud, with: .color(outline), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }

    private func drawPaperStar(ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        var star = Path()
        let inner = radius * 0.36
        for i in 0..<8 {
            let ang = Double(i) * Double.pi / 4.0
            let r = i.isMultiple(of: 2) ? radius : inner
            let pt = CGPoint(x: center.x + CGFloat(cos(ang)) * r, y: center.y + CGFloat(sin(ang)) * r)
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(color))
    }

    private func drawStorybookHillBand(
        ctx: inout GraphicsContext,
        size: CGSize,
        baseTopRatio: CGFloat,
        amplitude: Double,
        phaseShift: Double,
        fill: Color,
        outline: Color
    ) {
        let profile = StorybookIllustrationLayout.rollingHillProfile(
            sampleCount: 16,
            amplitude: amplitude,
            phaseShift: phaseShift
        )
        guard !profile.isEmpty else { return }
        let bandHeight = size.height * 0.26
        let topAnchor = size.height * baseTopRatio

        var ridge = Path()
        for (idx, pt) in profile.enumerated() {
            let canvasPt = CGPoint(
                x: CGFloat(pt.xFraction) * size.width,
                y: topAnchor + CGFloat(pt.yFraction - 0.5) * bandHeight
            )
            if idx == 0 {
                ridge.move(to: canvasPt)
            } else {
                ridge.addLine(to: canvasPt)
            }
        }

        var area = ridge
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()

        ctx.fill(area, with: .color(fill))
        ctx.stroke(ridge, with: .color(outline), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }
}
