import SwiftUI

/// 继承《摸索台灯》的「日光与夜灯空气背景层」：
/// 严格置于所有卡片与文字之下，绝不干扰阅读；开启「减弱动态效果」时自动静止。
/// - 日光：右上方三束缓慢呼吸的柔和日光光柱 + 随微风从左向右缓飘的蒲公英花粉微粒（15fps 轻能耗）；
/// - 夜灯：深夜蓝纸面 + 底部/顶部暖琥珀台灯呼吸光晕 + 缓缓上升的金色星屑。
public struct AmbientPaperBackdrop: View {
    public let palette: ChimmoPalette
    public var accentTint: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(palette: ChimmoPalette, accentTint: Color? = nil) {
        self.palette = palette
        self.accentTint = accentTint
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.paper))

                if palette.isNight {
                    drawNightLampAir(ctx: &ctx, size: size, now: now)
                } else {
                    drawDaylightAir(ctx: &ctx, size: size, now: now)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawDaylightAir(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let tint = accentTint ?? palette.homeAnchor
        // 右上方三束缓慢呼吸的日光光柱
        let breath = reduceMotion ? 0.5 : (0.5 + 0.5 * sin(now * 0.45))
        let sunOrigin = CGPoint(x: size.width * 0.92, y: -12)
        for ray in 0..<3 {
            let spread = CGFloat(ray) * 0.24
            var p = Path()
            p.move(to: sunOrigin)
            p.addLine(to: CGPoint(x: size.width * (0.18 + spread), y: size.height * 0.58))
            p.addLine(to: CGPoint(x: size.width * (0.36 + spread), y: size.height * 0.62))
            p.closeSubpath()
            let alpha = (0.045 + breath * 0.025) * (1.0 - Double(ray) * 0.18)
            ctx.fill(p, with: .color(Color(hex: 0xFFE6A7).opacity(alpha)))
        }

        // 极淡的顶部天色浸染
        let topGrad = Gradient(colors: [tint.opacity(0.06), .clear])
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.42)),
            with: .linearGradient(topGrad, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.42))
        )

        guard !reduceMotion else { return }
        // 蒲公英种子与主题花瓣（17–32 秒缓飘过一屏，位于卡片之下）
        for i in 0..<11 {
            let seed = Double(i) * 31.7
            let speed = 13.0 + Double(i % 4) * 4.5
            let x = ((now * speed + seed * 29.0).truncatingRemainder(dividingBy: Double(size.width + 48))) - 24.0
            let y = Double(size.height) * (0.10 + Double((i * 41) % 76) / 100.0) + sin(now * 0.55 + seed) * 14.0
            let r: CGFloat = (i % 3 == 0) ? 3.2 : 2.1
            let col = (i % 2 == 0) ? tint.opacity(0.18) : Color(hex: 0xF5B82E).opacity(0.22)
            ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(x) - r, y: CGFloat(y) - r, width: r * 2, height: r * 2)), with: .color(col))
        }
    }

    private func drawNightLampAir(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        // Otto 同款台灯暖琥珀光晕（缓慢呼吸，绝不刺眼）
        let breath = reduceMotion ? 0.5 : (0.5 + 0.5 * sin(now * 0.55))
        let lampCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.18)
        let lampGrad = Gradient(colors: [
            palette.nightLampGold.opacity(0.12 + breath * 0.05),
            (accentTint ?? palette.homeAnchor).opacity(0.04),
            .clear
        ])
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(lampGrad, center: lampCenter, startRadius: 8, endRadius: size.width * 0.85)
        )

        guard !reduceMotion else { return }
        // 缓缓上升的暖金台灯微光粒
        for i in 0..<12 {
            let seed = Double(i) * 23.9
            let speed = 9.0 + Double(i % 4) * 3.0
            let y = Double(size.height) - ((now * speed + seed * 19.0).truncatingRemainder(dividingBy: Double(size.height)))
            let x = (CGFloat((i * 67 + 11) % 94) / 100.0) * size.width + CGFloat(sin(now * 0.7 + seed)) * 12.0
            let alpha = sin((y / Double(size.height)) * Double.pi) * 0.34
            let r: CGFloat = (i % 3 == 0) ? 2.5 : 1.7
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: CGFloat(y) - r, width: r * 2, height: r * 2)),
                with: .color(palette.nightLampGold.opacity(max(0, alpha)))
            )
        }
    }
}
