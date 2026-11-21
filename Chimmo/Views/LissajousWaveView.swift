import SwiftUI

/// 60fps 声波对称利萨如花纹（Lissajous / Cymatic Resonance）：
/// 直观呈现「和谐 = 简单整数比的几何静止，张力 = 复杂频率比的高频拍频摩擦」，
/// 可作为工作台右上角「实时物理显微镜」，也可全屏展示于哲学体验馆。
public struct LissajousWaveView: View {
    public let ratioA: Double
    public let ratioB: Double
    public let consonance: Double // 0.0 (剧烈颤抖) ... 1.0 (绝对静止对称)
    public let accentColor: Color
    public let isNight: Bool
    public let compact: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        ratioA: Double,
        ratioB: Double,
        consonance: Double,
        accentColor: Color,
        isNight: Bool,
        compact: Bool = false
    ) {
        self.ratioA = ratioA
        self.ratioB = ratioB
        self.consonance = max(0, min(1, consonance))
        self.accentColor = accentColor
        self.isNight = isNight
        self.compact = compact
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width * 0.5
                let cy = size.height * 0.5
                let ampX = size.width * (compact ? 0.36 : 0.34)
                let ampY = size.height * (compact ? 0.36 : 0.34)

                let tension = 1.0 - consonance
                let phaseSpeed = 0.35 + tension * 2.2
                let phase = reduceMotion ? 0.45 : (now * phaseSpeed)
                let shake: CGFloat = reduceMotion ? 0 : CGFloat(tension * sin(now * 44.0) * (compact ? 1.8 : 4.0))

                // 外圈微光晕
                let glowRad = min(size.width, size.height) * 0.44
                let glowGrad = Gradient(colors: [
                    accentColor.opacity(isNight ? 0.22 : 0.16),
                    .clear
                ])
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - glowRad, y: cy - glowRad, width: glowRad * 2, height: glowRad * 2)),
                    with: .radialGradient(glowGrad, center: CGPoint(x: cx, y: cy), startRadius: 2, endRadius: glowRad)
                )

                // 声波干涉路径
                let steps = compact ? 160 : 380
                var path = Path()
                for i in 0...steps {
                    let u = (Double(i) / Double(steps)) * Double.pi * 2.0
                    let x = cx + shake + CGFloat(sin(ratioA * u + phase)) * ampX
                    let y = cy + CGFloat(sin(ratioB * u)) * ampY
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                // 底层柔和发光晕染线 + 表层清亮主丝线
                ctx.stroke(
                    path,
                    with: .color(accentColor.opacity(0.32)),
                    style: StrokeStyle(lineWidth: compact ? 3.5 : 6.0, lineCap: .round, lineJoin: .round)
                )
                ctx.stroke(
                    path,
                    with: .color(accentColor.opacity(0.95)),
                    style: StrokeStyle(lineWidth: compact ? 1.5 : 2.3, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
