import SwiftUI

/// 咩哞 · Chimmo 原创高工艺矢量设计语言（全局零 Emoji，纯粹的窑陶 × 黄铜 × 声学建筑几何体系）
/// 所有功能标识、徽章与音阶图腾均由光学精密比例的矢量化几何路径构成，保持极高辨识度与全色弱/夜灯兼容。
public enum ChimmoCraftSymbol: String, CaseIterable, Sendable {
    case pentatonicArc      // 五音安心保护双弧
    case counterpointMoons  // 巴赫影子双弧月对话
    case hapticPulse        // 掌心声波触觉共振环
    case tempoDial          // 精密节拍呼吸表盘指针
    case nightLampHalo      // 深夜温暖台灯光罩轮廓
    case origamiPrism       // 旋律折纸几何分形菱面
    case seedBloom          // 大师三颗火种同心花
    case followBeacon       // 亮灯跟弹定锚星标
    case atmosphereHorizon  // 五色天光借景地平线
    case vinylSeal          // 绘本曲谱开卷星章印记
    case drumPulse          // 敲拍节奏木鼓双圈
    case humWave            // 轻哼声波对称波纹
    case appearanceDial     // 光暗昼夜半月平衡仪
    case smartLamp          // 验光师三灯亮环指针
}

/// 光学 24×24 网格下的纯几何矢量印记（Calibrated 1.5pt–1.8pt stroke weight, round caps）
public struct ChimmoCraftMark: View {
    public let symbol: ChimmoCraftSymbol
    public var color: Color
    public var secondaryColor: Color?

    public init(_ symbol: ChimmoCraftSymbol, color: Color, secondaryColor: Color? = nil) {
        self.symbol = symbol
        self.color = color
        self.secondaryColor = secondaryColor
    }

    public var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let s = min(w, h)
            let cx = w * 0.5
            let cy = h * 0.5
            let lw = max(1.2, s * 0.082)
            let stroke = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            let accent = secondaryColor ?? color.opacity(0.45)

            switch symbol {
            case .pentatonicArc:
                // 双层同心屏蔽弧 + 内核心圆点（象征 5 音守护结界）
                var outerArc = Path()
                outerArc.addArc(center: CGPoint(x: cx, y: cy), radius: s * 0.39, startAngle: .degrees(215), endAngle: .degrees(-35), clockwise: false)
                ctx.stroke(outerArc, with: .color(color), style: stroke)
                var innerArc = Path()
                innerArc.addArc(center: CGPoint(x: cx, y: cy), radius: s * 0.25, startAngle: .degrees(200), endAngle: .degrees(-20), clockwise: false)
                ctx.stroke(innerArc, with: .color(accent), style: stroke)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - s * 0.09, y: cy - s * 0.09, width: s * 0.18, height: s * 0.18)), with: .color(color))

            case .counterpointMoons:
                // 主声圆盘与影子银月交叠对话
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: cx - s * 0.32, y: cy - s * 0.22, width: s * 0.44, height: s * 0.44)),
                    with: .color(color),
                    style: stroke
                )
                var moon = Path()
                let r = s * 0.22
                let mx = cx + s * 0.16
                let my = cy - s * 0.04
                let top = CGPoint(x: mx + r * 0.35, y: my - r * 0.85)
                let bot = CGPoint(x: mx + r * 0.35, y: my + r * 0.85)
                moon.move(to: top)
                moon.addCurve(to: bot, control1: CGPoint(x: mx - r * 0.95, y: my - r * 0.5), control2: CGPoint(x: mx - r * 0.95, y: my + r * 0.5))
                moon.addCurve(to: top, control1: CGPoint(x: mx - r * 0.2, y: my + r * 0.35), control2: CGPoint(x: mx - r * 0.2, y: my - r * 0.35))
                moon.closeSubpath()
                ctx.fill(moon, with: .color(accent.opacity(0.9)))
                ctx.stroke(moon, with: .color(color), style: StrokeStyle(lineWidth: lw * 0.8, lineCap: .round, lineJoin: .round))

            case .hapticPulse:
                // 中心脉冲垂直轴 + 双侧声波对称振环
                var wave = Path()
                let pts: [(CGFloat, CGFloat)] = [
                    (-0.40, 0.0), (-0.26, 0.0), (-0.16, -0.26), (-0.04, 0.34),
                    (0.08, -0.36), (0.20, 0.22), (0.28, 0.0), (0.40, 0.0)
                ]
                for (idx, p) in pts.enumerated() {
                    let pt = CGPoint(x: cx + p.0 * s, y: cy + p.1 * s)
                    if idx == 0 { wave.move(to: pt) } else { wave.addLine(to: pt) }
                }
                ctx.stroke(wave, with: .color(color), style: stroke)
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: cx - s * 0.42, y: cy - s * 0.42, width: s * 0.84, height: s * 0.84)),
                    with: .color(accent.opacity(0.45)),
                    style: StrokeStyle(lineWidth: lw * 0.72)
                )

            case .tempoDial:
                // 极简精密圆表盘 + 指针弧
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: cx - s * 0.38, y: cy - s * 0.38, width: s * 0.76, height: s * 0.76)),
                    with: .color(color),
                    style: stroke
                )
                var hand = Path()
                hand.move(to: CGPoint(x: cx, y: cy))
                hand.addLine(to: CGPoint(x: cx + s * 0.21, y: cy - s * 0.16))
                ctx.stroke(hand, with: .color(color), style: stroke)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - s * 0.06, y: cy - s * 0.06, width: s * 0.12, height: s * 0.12)), with: .color(color))

            case .nightLampHalo:
                // 雕塑感弧形夜灯与地面微光弧
                var shade = Path()
                shade.move(to: CGPoint(x: cx - s * 0.26, y: cy - s * 0.34))
                shade.addLine(to: CGPoint(x: cx + s * 0.26, y: cy - s * 0.34))
                shade.addLine(to: CGPoint(x: cx + s * 0.36, y: cy - s * 0.02))
                shade.addLine(to: CGPoint(x: cx - s * 0.36, y: cy - s * 0.02))
                shade.closeSubpath()
                ctx.stroke(shade, with: .color(color), style: stroke)

                var stem = Path()
                stem.move(to: CGPoint(x: cx, y: cy - s * 0.02))
                stem.addLine(to: CGPoint(x: cx, y: cy + s * 0.34))
                stem.move(to: CGPoint(x: cx - s * 0.20, y: cy + s * 0.34))
                stem.addLine(to: CGPoint(x: cx + s * 0.20, y: cy + s * 0.34))
                ctx.stroke(stem, with: .color(accent), style: stroke)

            case .origamiPrism:
                // 对称折叠四瓣菱晶（象征起承转合折纸生长）
                var diamond = Path()
                diamond.move(to: CGPoint(x: cx, y: cy - s * 0.40))
                diamond.addLine(to: CGPoint(x: cx + s * 0.36, y: cy))
                diamond.addLine(to: CGPoint(x: cx, y: cy + s * 0.40))
                diamond.addLine(to: CGPoint(x: cx - s * 0.36, y: cy))
                diamond.closeSubpath()
                ctx.stroke(diamond, with: .color(color), style: stroke)

                var cross = Path()
                cross.move(to: CGPoint(x: cx, y: cy - s * 0.40))
                cross.addLine(to: CGPoint(x: cx, y: cy + s * 0.40))
                cross.move(to: CGPoint(x: cx - s * 0.36, y: cy))
                cross.addLine(to: CGPoint(x: cx + s * 0.36, y: cy))
                ctx.stroke(cross, with: .color(accent), style: StrokeStyle(lineWidth: lw * 0.72, lineCap: .round))

            case .seedBloom:
                // 三颗阶梯火种珠 + 光环连线
                let pts = [
                    CGPoint(x: cx - s * 0.25, y: cy + s * 0.16),
                    CGPoint(x: cx, y: cy - s * 0.20),
                    CGPoint(x: cx + s * 0.25, y: cy + s * 0.02)
                ]
                var link = Path()
                link.move(to: pts[0])
                link.addLine(to: pts[1])
                link.addLine(to: pts[2])
                ctx.stroke(link, with: .color(accent), style: stroke)
                for p in pts {
                    let r = s * 0.095
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color))
                }

            case .followBeacon:
                // 四角星芒定锚（亮灯跟弹）
                var star = Path()
                let outer = s * 0.40
                let inner = s * 0.14
                for i in 0..<8 {
                    let ang = -Double.pi / 2.0 + Double(i) * Double.pi / 4.0
                    let r = (i % 2 == 0) ? outer : inner
                    let pt = CGPoint(x: cx + CGFloat(cos(ang)) * r, y: cy + CGFloat(sin(ang)) * r)
                    if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                ctx.stroke(star, with: .color(color), style: stroke)

            case .atmosphereHorizon:
                // 地平线上升起的三层谐波极光弧
                var horizon = Path()
                horizon.move(to: CGPoint(x: cx - s * 0.40, y: cy + s * 0.16))
                horizon.addLine(to: CGPoint(x: cx + s * 0.40, y: cy + s * 0.16))
                ctx.stroke(horizon, with: .color(color), style: stroke)
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx, y: cy + s * 0.14), radius: s * 0.26, startAngle: .degrees(185), endAngle: .degrees(-5), clockwise: false)
                ctx.stroke(arc, with: .color(accent), style: stroke)

            case .vinylSeal:
                // 扁平绘本开卷双页书本与上方旋律四芒星章
                var leftPage = Path()
                leftPage.move(to: CGPoint(x: cx, y: cy + s * 0.24))
                leftPage.addQuadCurve(
                    to: CGPoint(x: cx - s * 0.38, y: cy + s * 0.20),
                    control: CGPoint(x: cx - s * 0.18, y: cy + s * 0.12)
                )
                leftPage.addLine(to: CGPoint(x: cx - s * 0.38, y: cy - s * 0.10))
                leftPage.addQuadCurve(
                    to: CGPoint(x: cx, y: cy - s * 0.04),
                    control: CGPoint(x: cx - s * 0.18, y: cy - s * 0.16)
                )
                leftPage.closeSubpath()
                ctx.stroke(leftPage, with: .color(color), style: stroke)

                var rightPage = Path()
                rightPage.move(to: CGPoint(x: cx, y: cy + s * 0.24))
                rightPage.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.38, y: cy + s * 0.20),
                    control: CGPoint(x: cx + s * 0.18, y: cy + s * 0.12)
                )
                rightPage.addLine(to: CGPoint(x: cx + s * 0.38, y: cy - s * 0.10))
                rightPage.addQuadCurve(
                    to: CGPoint(x: cx, y: cy - s * 0.04),
                    control: CGPoint(x: cx + s * 0.18, y: cy - s * 0.16)
                )
                rightPage.closeSubpath()
                ctx.stroke(rightPage, with: .color(color), style: stroke)

                // 上方四芒旋律星章
                let sc = CGPoint(x: cx, y: cy - s * 0.26)
                let outerR = s * 0.15
                let innerR = s * 0.06
                var star = Path()
                for idx in 0..<8 {
                    let ang = Double(idx) * (Double.pi / 4.0)
                    let rad = (idx % 2 == 0) ? outerR : innerR
                    let pt = CGPoint(x: sc.x + CGFloat(cos(ang)) * rad, y: sc.y + CGFloat(sin(ang)) * rad)
                    if idx == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                ctx.fill(star, with: .color(accent))

            case .drumPulse:
                // 同心敲拍木鼓圆环
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - s * 0.38, y: cy - s * 0.38, width: s * 0.76, height: s * 0.76)), with: .color(color), style: stroke)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - s * 0.15, y: cy - s * 0.15, width: s * 0.30, height: s * 0.30)), with: .color(color))

            case .humWave:
                // 垂直居中的 5 根对称声音能量柱
                let heights: [CGFloat] = [0.28, 0.56, 0.80, 0.50, 0.26]
                for (i, ratio) in heights.enumerated() {
                    let x = cx + CGFloat(i - 2) * s * 0.16
                    let halfH = s * 0.42 * ratio
                    var bar = Path()
                    bar.move(to: CGPoint(x: x, y: cy - halfH))
                    bar.addLine(to: CGPoint(x: x, y: cy + halfH))
                    ctx.stroke(bar, with: .color(i == 2 ? color : accent), style: stroke)
                }

            case .appearanceDial:
                // 昼夜二分光学环
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - s * 0.38, y: cy - s * 0.38, width: s * 0.76, height: s * 0.76)), with: .color(color), style: stroke)
                var half = Path()
                half.addArc(center: CGPoint(x: cx, y: cy), radius: s * 0.24, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                half.closeSubpath()
                ctx.fill(half, with: .color(color))

            case .smartLamp:
                // 3 选 1 亮灯同心聚焦环
                for i in 0..<3 {
                    let r = s * (0.14 + CGFloat(i) * 0.13)
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                        with: .color(i == 1 ? color : accent),
                        style: StrokeStyle(lineWidth: i == 1 ? lw : lw * 0.7)
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 窑陶哑光质地精密图标徽章（替代粗陋 Emoji 的统一高级容器）
public struct ChimmoCraftBadge: View {
    public let symbol: ChimmoCraftSymbol
    public let accent: Color
    public let surface: Color
    public var size: CGFloat

    public init(_ symbol: ChimmoCraftSymbol, accent: Color, surface: Color, size: CGFloat = 36) {
        self.symbol = symbol
        self.accent = accent
        self.surface = surface
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(surface)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .fill(accent.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .strokeBorder(accent.opacity(0.32), lineWidth: 0.85)
                )

            ChimmoCraftMark(symbol, color: accent)
                .frame(width: size * 0.58, height: size * 0.58)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 纯净编辑部质感胶囊标签（去框去阴影：柔彩底色 + 几何微点 + 精密字体）
public struct ChimmoEditorialPill: View {
    public let text: String
    public let accent: Color
    public let surface: Color
    public let textColor: Color

    public init(text: String, accent: Color, surface: Color, textColor: Color) {
        self.text = text
        self.accent = accent
        self.surface = surface
        self.textColor = textColor
    }

    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: 5.5, height: 5.5)
            Text(text)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(surface.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(0.12))
                )
        )
    }
}

/// 色盲友好八音阶几何图腾公用矢量视图
public struct PitchGlyphVectorView: View {
    public let glyph: PitchGlyphShape

    public init(glyph: PitchGlyphShape) {
        self.glyph = glyph
    }

    public var body: some View {
        GeometryReader { geo in
            glyph.path(in: CGRect(origin: .zero, size: geo.size))
                .fill(style: FillStyle(eoFill: true))
        }
    }
}

/// 扁平卡通安静托盘容器（遵守 quietContainer 契约：平涂底色 + 1pt 轻柔细线，零硬阴影，让可交互按钮脱颖而出）
public struct ChimmoWoodResonatorTray: View {
    public let palette: ChimmoPalette
    public var cornerRadius: CGFloat

    public init(palette: ChimmoPalette, cornerRadius: CGFloat = 18) {
        self.palette = palette
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape
                .fill(palette.woodTrayTop)

            shape
                .strokeBorder(palette.cartoonOutline.opacity(palette.isNight ? 0.22 : 0.16), lineWidth: 1.0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 扁平卡通轻描边边框（已废除四角圆钉，统一收敛为柔和单线轮廓）
public struct ChimmoBrassFrameAccent: View {
    public let palette: ChimmoPalette
    public var cornerRadius: CGFloat
    public var showCornerPins: Bool

    public init(palette: ChimmoPalette, cornerRadius: CGFloat, showCornerPins: Bool = false) {
        self.palette = palette
        self.cornerRadius = cornerRadius
        self.showCornerPins = showCornerPins
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(palette.cartoonOutline.opacity(palette.isNight ? 0.40 : 0.30), lineWidth: 1.4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 扁平卡通可交互贴纸按键表面（唯一享有硬朗暖墨描边与无模糊偏移阴影的可点语法）
public struct ChimmoKilnPillButtonSurface: View {
    public let palette: ChimmoPalette
    public var accent: Color?
    public var isActive: Bool
    public var isPressed: Bool
    public var cornerRadius: CGFloat

    public init(
        palette: ChimmoPalette,
        accent: Color? = nil,
        isActive: Bool = false,
        isPressed: Bool = false,
        cornerRadius: CGFloat = 14
    ) {
        self.palette = palette
        self.accent = accent
        self.isActive = isActive
        self.isPressed = isPressed
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let activeTint = accent ?? palette.homeAnchor
        let fillCol = isActive
            ? activeTint.opacity(palette.isNight ? 0.34 : 0.20)
            : palette.cardSurface
        let strokeCol = isActive
            ? activeTint
            : palette.cartoonOutline.opacity(palette.isNight ? 0.56 : 0.80)

        ZStack {
            shape
                .fill(isActive ? activeTint.opacity(palette.isNight ? 0.45 : 0.28) : palette.cartoonShadow)
                .offset(x: 0, y: isPressed ? 0.5 : 2.0)

            shape
                .fill(fillCol)

            shape
                .strokeBorder(strokeCol, lineWidth: isActive ? 1.9 : 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 静态展示容器表面（遵守 quietContainer 契约：零偏移阴影、柔和轻边框，专供非整卡可点的曲目卡与说明卡使用）
public struct StorybookQuietCardSurface: View {
    public let palette: ChimmoPalette
    public var accent: Color?
    public var isHighlighted: Bool
    public var cornerRadius: CGFloat

    public init(
        palette: ChimmoPalette,
        accent: Color? = nil,
        isHighlighted: Bool = false,
        cornerRadius: CGFloat = 18
    ) {
        self.palette = palette
        self.accent = accent
        self.isHighlighted = isHighlighted
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let activeTint = accent ?? palette.homeAnchor
        let borderCol = isHighlighted
            ? activeTint.opacity(0.75)
            : palette.cartoonOutline.opacity(palette.isNight ? 0.24 : 0.18)

        ZStack {
            shape
                .fill(palette.cardSurface)

            if isHighlighted {
                shape
                    .fill(activeTint.opacity(palette.isNight ? 0.14 : 0.08))
            }

            shape
                .strokeBorder(borderCol, lineWidth: 1.2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 无交互只读信息标签（遵守 readOnlyLabel 契约：无描边、无阴影，仅以柔和底色与清晰字号区分）
public struct StorybookQuietTag: View {
    public let text: String
    public var systemImage: String?
    public let tint: Color
    public let textColor: Color
    public let isNight: Bool

    public init(
        text: String,
        systemImage: String? = nil,
        tint: Color,
        textColor: Color,
        isNight: Bool
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.textColor = textColor
        self.isNight = isNight
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(isNight ? 0.16 : 0.10))
        )
    }
}

/// 扁平卡通按键物理按压下沉反馈（严格尊重系统「减弱动态效果」）
public struct StorybookTactileButtonStyle: ButtonStyle {
    public var sinkY: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(sinkY: CGFloat = 1.8) {
        self.sinkY = sinkY
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .offset(y: pressed ? sinkY : 0)
            .scaleEffect(pressed ? 0.985 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

/// 童书扇形波浪分隔彩带（用明快绘本节律代替空白留白）
public struct StorybookScallopDivider: View {
    public let color: Color
    public var stepWidth: CGFloat

    public init(color: Color, stepWidth: CGFloat = 14) {
        self.color = color
        self.stepWidth = stepWidth
    }

    public var body: some View {
        Canvas { ctx, size in
            let w = max(1, size.width)
            let h = max(1, size.height)
            let count = max(4, Int(w / stepWidth))
            let sw = w / CGFloat(count)
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: h * 0.55))
            for i in 0..<count {
                let x0 = CGFloat(i) * sw
                let xMid = x0 + sw * 0.5
                let x1 = x0 + sw
                wave.addQuadCurve(
                    to: CGPoint(x: x1, y: h * 0.55),
                    control: CGPoint(x: xMid, y: i.isMultiple(of: 2) ? h * 0.10 : h * 0.96)
                )
            }
            ctx.stroke(
                wave,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

/// 扁平卡通「琴键小偶」微缩头像：把 7 只咩哞七声音阶性格直接融进每一个按键里（零渐变、清晰墨线、尊重微笑音）
public struct ChimmoCartoonKeyBuddyView: View {
    public let member: ChimmoMember
    public let outlineColor: Color
    public let isSinging: Bool
    public let isMinor: Bool

    public init(
        member: ChimmoMember,
        outlineColor: Color,
        isSinging: Bool,
        isMinor: Bool
    ) {
        self.member = member
        self.outlineColor = outlineColor
        self.isSinging = isSinging
        self.isMinor = isMinor
    }

    public var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w * 0.5
            let cy = h * 0.58
            let ink = outlineColor
            let fill = Color.white.opacity(0.95)
            let stroke = StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)

            switch member {
            case .taono:
                for sx in [-1.0, 1.0] {
                    let ear = CGRect(x: cx + CGFloat(sx) * 4.5 - 2.0, y: cy - 9.5, width: 4.0, height: 6.0)
                    ctx.fill(RoundedRectangle(cornerRadius: 2).path(in: ear), with: .color(fill))
                    ctx.stroke(RoundedRectangle(cornerRadius: 2).path(in: ear), with: .color(ink), style: stroke)
                }
            case .plokko:
                let tilt: CGFloat = isSinging ? -2.2 : (isMinor ? 2.2 : -1.2)
                for sx in [-1.0, 1.0] {
                    let wing = CGRect(x: cx + CGFloat(sx) * 7.8 - 2.4, y: cy - 1.5 + tilt, width: 4.8, height: 3.4)
                    ctx.fill(Capsule().path(in: wing), with: .color(fill))
                    ctx.stroke(Capsule().path(in: wing), with: .color(ink), style: stroke)
                }
            case .corllo:
                let swirl = CGRect(x: cx + 4.5, y: cy - 6.5, width: 5.5, height: 5.5)
                ctx.fill(Circle().path(in: swirl), with: .color(fill))
                ctx.stroke(Circle().path(in: swirl), with: .color(ink), style: stroke)
            case .tinki:
                let bobble = CGRect(x: cx - 2.2, y: cy - 10.2, width: 4.4, height: 4.4)
                ctx.fill(Circle().path(in: bobble), with: .color(Color(hex: 0xFFE49E)))
                ctx.stroke(Circle().path(in: bobble), with: .color(ink), style: stroke)
            case .bomo:
                let cap = CGRect(x: cx - 5.2, y: cy - 7.5, width: 10.4, height: 3.6)
                ctx.fill(Capsule().path(in: cap), with: .color(Color(hex: 0xFFE49E)))
                ctx.stroke(Capsule().path(in: cap), with: .color(ink), style: stroke)
            case .doko, .udo:
                break
            }

            let headW: CGFloat = (member == .bomo) ? 14.5 : (member == .tinki ? 11.5 : 13.0)
            let headH: CGFloat = (member == .tinki) ? 11.5 : 10.2
            let headRect = CGRect(x: cx - headW * 0.5, y: cy - headH * 0.5, width: headW, height: headH)
            let headPath = RoundedRectangle(cornerRadius: headH * 0.48, style: .continuous).path(in: headRect)
            ctx.fill(headPath, with: .color(fill))
            ctx.stroke(headPath, with: .color(ink), style: stroke)

            for sx in [-1.0, 1.0] {
                let ex = cx + CGFloat(sx) * 2.6
                let ey = cy - 0.5
                if isSinging {
                    var arc = Path()
                    arc.move(to: CGPoint(x: ex - 1.3, y: ey + 0.6))
                    arc.addQuadCurve(to: CGPoint(x: ex + 1.3, y: ey + 0.6), control: CGPoint(x: ex, y: ey - 1.4))
                    ctx.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: ex - 1.1, y: ey - 1.1, width: 2.2, height: 2.2)), with: .color(ink))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 扁平卡通童书场景背景层（纯平涂天空、日光太阳射线 / 夜灯新月纸星、双层手绘草坡，零渐变零模糊）。
public struct StorybookCartoonSceneBackground: View {
    public let palette: ChimmoPalette
    public var accentTint: Color?
    public var hillHeightRatio: CGFloat
    public var showsSkyMotifs: Bool

    public init(
        palette: ChimmoPalette,
        accentTint: Color? = nil,
        hillHeightRatio: CGFloat = 0.28,
        showsSkyMotifs: Bool = true
    ) {
        self.palette = palette
        self.accentTint = accentTint
        self.hillHeightRatio = hillHeightRatio
        self.showsSkyMotifs = showsSkyMotifs
    }

    public var body: some View {
        Canvas { ctx, size in
            let w = max(1, size.width)
            let h = max(1, size.height)
            let outline = palette.cartoonOutline.opacity(palette.isNight ? 0.30 : 0.24)

            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.paper))

            if let tint = accentTint {
                let skyWash = Path(CGRect(x: 0, y: 0, width: w, height: h * 0.42))
                ctx.fill(skyWash, with: .color(tint.opacity(palette.isNight ? 0.11 : 0.08)))
            }

            if showsSkyMotifs {
                drawSkyCelestial(ctx: &ctx, w: w, h: h, outline: outline)
                drawPaperCloud(ctx: &ctx, center: CGPoint(x: w * 0.22, y: h * 0.18), scale: min(1.0, w / 340.0), outline: outline)
                drawPaperCloud(ctx: &ctx, center: CGPoint(x: w * 0.80, y: h * 0.23), scale: min(0.86, w / 390.0), outline: outline)
            }

            let bandH = max(24, h * max(0.14, min(0.55, hillHeightRatio)))
            drawRollingHill(
                ctx: &ctx,
                width: w,
                totalHeight: h,
                topOffset: h - bandH * 1.18,
                amplitude: 0.22,
                phaseShift: 0.35,
                fillColor: palette.storybookHillBack,
                outlineColor: outline
            )
            drawRollingHill(
                ctx: &ctx,
                width: w,
                totalHeight: h,
                topOffset: h - bandH * 0.82,
                amplitude: 0.18,
                phaseShift: 2.35,
                fillColor: palette.storybookHillFront,
                outlineColor: outline
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawSkyCelestial(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, outline: Color) {
        let cx = w * 0.86
        let cy = h * 0.12
        let r = min(18.0, min(w, h) * 0.055)

        if palette.isNight {
            var moon = Path()
            let top = CGPoint(x: cx + r * 0.3, y: cy - r * 0.85)
            let bot = CGPoint(x: cx + r * 0.3, y: cy + r * 0.85)
            moon.move(to: top)
            moon.addCurve(
                to: bot,
                control1: CGPoint(x: cx - r * 1.05, y: cy - r * 0.48),
                control2: CGPoint(x: cx - r * 1.05, y: cy + r * 0.48)
            )
            moon.addCurve(
                to: top,
                control1: CGPoint(x: cx - r * 0.22, y: cy + r * 0.36),
                control2: CGPoint(x: cx - r * 0.22, y: cy - r * 0.36)
            )
            moon.closeSubpath()
            ctx.fill(moon, with: .color(palette.nightLampGold))
            ctx.stroke(moon, with: .color(outline), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            for starPt in [CGPoint(x: w * 0.12, y: h * 0.11), CGPoint(x: w * 0.68, y: h * 0.10)] {
                let d = Path(ellipseIn: CGRect(x: starPt.x - 2.6, y: starPt.y - 2.6, width: 5.2, height: 5.2))
                ctx.fill(d, with: .color(palette.nightLampGold))
            }
        } else {
            let sunCenter = CGPoint(x: cx, y: cy)
            let rays = StorybookPostcardAndShelfKinematics.radialRaySegments(
                center: sunCenter,
                innerRadius: r + 3.5,
                outerRadius: r + 9.0,
                rayCount: 8
            )
            for seg in rays {
                var p = Path()
                p.move(to: seg.start)
                p.addLine(to: seg.end)
                ctx.stroke(p, with: .color(palette.nightLampGold), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            }
            let sunRect = CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: sunRect), with: .color(palette.storybookButter))
            ctx.stroke(Path(ellipseIn: sunRect), with: .color(outline), lineWidth: 1.6)
        }
    }

    private func drawPaperCloud(ctx: inout GraphicsContext, center: CGPoint, scale: CGFloat, outline: Color) {
        let s = max(0.55, scale)
        let cw: CGFloat = 46 * s
        let ch: CGFloat = 18 * s
        let left = center.x - cw * 0.5
        let right = center.x + cw * 0.5
        let baseY = center.y + ch * 0.5
        let cloudFill = palette.isNight ? palette.cardSurface.opacity(0.66) : palette.cardSurface

        var cloud = Path()
        cloud.move(to: CGPoint(x: left + 6 * s, y: baseY))
        cloud.addLine(to: CGPoint(x: right - 6 * s, y: baseY))
        cloud.addQuadCurve(to: CGPoint(x: right, y: baseY - 6 * s), control: CGPoint(x: right, y: baseY))
        cloud.addQuadCurve(to: CGPoint(x: right - 12 * s, y: baseY - 12 * s), control: CGPoint(x: right, y: baseY - 13 * s))
        cloud.addQuadCurve(to: CGPoint(x: center.x - 10 * s, y: baseY - 14 * s), control: CGPoint(x: center.x - 1 * s, y: baseY - 22 * s))
        cloud.addQuadCurve(to: CGPoint(x: left, y: baseY - 6 * s), control: CGPoint(x: left, y: baseY - 13 * s))
        cloud.addQuadCurve(to: CGPoint(x: left + 6 * s, y: baseY), control: CGPoint(x: left, y: baseY))
        cloud.closeSubpath()

        ctx.fill(cloud, with: .color(cloudFill))
        ctx.stroke(cloud, with: .color(outline.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }

    private func drawRollingHill(
        ctx: inout GraphicsContext,
        width: CGFloat,
        totalHeight: CGFloat,
        topOffset: CGFloat,
        amplitude: Double,
        phaseShift: Double,
        fillColor: Color,
        outlineColor: Color
    ) {
        let profile = StorybookIllustrationLayout.rollingHillProfile(
            sampleCount: 18,
            amplitude: amplitude,
            phaseShift: phaseShift
        )
        guard let first = profile.first else { return }
        let hillBand: CGFloat = 48
        let mapped = profile.map { pt in
            CGPoint(x: CGFloat(pt.xFraction) * width, y: topOffset + CGFloat(pt.yFraction - 0.5) * hillBand)
        }
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: 0, y: totalHeight))
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
        fillPath.addLine(to: CGPoint(x: width, y: totalHeight))
        fillPath.closeSubpath()

        ctx.fill(fillPath, with: .color(fillColor))
        ctx.stroke(ridgePath, with: .color(outlineColor.opacity(0.52)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }
}

public extension View {
    /// 仅在当前空间激活时挂载硬件键盘快捷键，避免 TabView 跨标签冲突
    @ViewBuilder
    func storybookKeyboardShortcut(_ shortcut: KeyboardShortcut, enabled: Bool) -> some View {
        if enabled {
            self.keyboardShortcut(shortcut)
        } else {
            self
        }
    }
}
