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

/// 系统「减弱透明度（Reduce Transparency）」与「增强对比度（Increase Contrast）」双轨表面清晰度策略：
/// 开启任一项视觉辅助后，消除装饰性高光玻璃层与低对比度半透明色洗，转为实底纸面与明确轮廓边线。
public enum StorybookSurfaceClarityPolicy: Sendable {
    public static func showsSpecularSheen(reduceTransparency: Bool, increasedContrast: Bool) -> Bool {
        !reduceTransparency && !increasedContrast
    }

    public static func showsTranslucentTintWash(reduceTransparency: Bool) -> Bool {
        !reduceTransparency
    }

    public static func quietTagFillOpacity(isNight: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> Double {
        if reduceTransparency || increasedContrast {
            return isNight ? 0.30 : 0.18
        }
        return isNight ? 0.16 : 0.10
    }

    public static func pillActiveFillOpacity(isNight: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> Double {
        if reduceTransparency || increasedContrast {
            return isNight ? 0.42 : 0.26
        }
        return isNight ? 0.28 : 0.16
    }

    public static func borderLineWidth(isActive: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> CGFloat {
        if increasedContrast {
            return isActive ? 2.0 : 1.5
        }
        if reduceTransparency {
            return isActive ? 1.6 : 1.25
        }
        return isActive ? 1.3 : 1.0
    }

    public static func subtleBorderOpacity(isNight: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> Double {
        if increasedContrast {
            return isNight ? 0.56 : 0.44
        }
        if reduceTransparency {
            return isNight ? 0.32 : 0.24
        }
        return isNight ? 0.14 : 0.09
    }
}

/// 纯净编辑部质感胶囊标签（去框去阴影：柔彩底色 + 几何微点 + 精密字体）
public struct ChimmoEditorialPill: View {
    public let text: String
    public let accent: Color
    public let surface: Color
    public let textColor: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(text: String, accent: Color, surface: Color, textColor: Color) {
        self.text = text
        self.accent = accent
        self.surface = surface
        self.textColor = textColor
    }

    public var body: some View {
        let increased = colorSchemeContrast == .increased
        let highClarity = reduceTransparency || increased
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)

        HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: 5.5, height: 5.5)
            Text(text)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            shape
                .fill(highClarity ? surface : surface.opacity(0.65))
                .overlay {
                    if StorybookSurfaceClarityPolicy.showsTranslucentTintWash(reduceTransparency: reduceTransparency) {
                        shape.fill(accent.opacity(0.12))
                    }
                }
                .overlay {
                    if highClarity {
                        shape.strokeBorder(
                            accent.opacity(increased ? 0.75 : 0.48),
                            lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(
                                isActive: false,
                                reduceTransparency: reduceTransparency,
                                increasedContrast: increased
                            )
                        )
                    }
                }
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

/// 扁平哑光工坊安静托盘容器（柔和亚麻/夜靛底盘 + 极轻细边，绝不抢戏）
public struct ChimmoWoodResonatorTray: View {
    public let palette: ChimmoPalette
    public var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(palette: ChimmoPalette, cornerRadius: CGFloat = ChimmoRadius.inner) {
        self.palette = palette
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let increased = colorSchemeContrast == .increased
        ZStack {
            shape
                .fill(palette.woodTrayTop)

            shape
                .strokeBorder(
                    palette.primaryInk.opacity(
                        StorybookSurfaceClarityPolicy.subtleBorderOpacity(
                            isNight: palette.isNight,
                            reduceTransparency: reduceTransparency,
                            increasedContrast: increased
                        )
                    ),
                    lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(
                        isActive: false,
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increased
                    )
                )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 扁平轻描边边框（极细收口线，兼容历史调用）
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
            .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.09), lineWidth: 1.0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 哑光软胶可交互按键表面（去掉厚重卡通黑边框与硬色块，改以柔和接触阴影与顶部受光亮边呈现）
public struct ChimmoKilnPillButtonSurface: View {
    public let palette: ChimmoPalette
    public var accent: Color?
    public var isActive: Bool
    public var isPressed: Bool
    public var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
        let increased = colorSchemeContrast == .increased
        let highClarity = reduceTransparency || increased
        let lineWidth = StorybookSurfaceClarityPolicy.borderLineWidth(
            isActive: isActive,
            reduceTransparency: reduceTransparency,
            increasedContrast: increased
        )
        let fillCol = isActive
            ? activeTint.opacity(
                StorybookSurfaceClarityPolicy.pillActiveFillOpacity(
                    isNight: palette.isNight,
                    reduceTransparency: reduceTransparency,
                    increasedContrast: increased
                )
            )
            : palette.cardSurface
        let rimColor: Color = isActive
            ? activeTint.opacity(palette.isNight ? 0.72 : 0.52)
            : (palette.isNight ? palette.nightLampGold.opacity(0.16) : Color.white.opacity(0.88))
        let shadowColor: Color = isActive
            ? (palette.isNight ? Color.black.opacity(0.28) : activeTint.opacity(0.20))
            : palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.18)

        ZStack {
            if isActive && highClarity {
                shape.fill(palette.cardSurface)
            }

            shape
                .fill(fillCol)
                .shadow(color: shadowColor, radius: isPressed ? 1.5 : 3.5, y: isPressed ? 0.8 : 2.0)

            if StorybookSurfaceClarityPolicy.showsSpecularSheen(
                reduceTransparency: reduceTransparency,
                increasedContrast: increased
            ) {
                shape
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(palette.isNight ? 0.05 : 0.35), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }

            if highClarity {
                shape
                    .strokeBorder(
                        isActive
                            ? activeTint.opacity(increased ? 0.92 : 0.78)
                            : palette.primaryInk.opacity(
                                StorybookSurfaceClarityPolicy.subtleBorderOpacity(
                                    isNight: palette.isNight,
                                    reduceTransparency: reduceTransparency,
                                    increasedContrast: increased
                                )
                            ),
                        lineWidth: lineWidth
                    )
            } else {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [rimColor, palette.primaryInk.opacity(palette.isNight ? 0.10 : 0.07)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: lineWidth
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 静态展示纸卡表面（与摸索台灯 `PrintCard` 一脉相承：纯净棉纸/夜纸 + 柔和顶部微光 + 轻量暖接触阴影）
public struct StorybookQuietCardSurface: View {
    public let palette: ChimmoPalette
    public var accent: Color?
    public var isHighlighted: Bool
    public var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(
        palette: ChimmoPalette,
        accent: Color? = nil,
        isHighlighted: Bool = false,
        cornerRadius: CGFloat = ChimmoRadius.card
    ) {
        self.palette = palette
        self.accent = accent
        self.isHighlighted = isHighlighted
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let activeTint = accent ?? palette.homeAnchor
        let increased = colorSchemeContrast == .increased
        let highClarity = reduceTransparency || increased

        ZStack {
            shape
                .fill(palette.cardSurface)
                .shadow(
                    color: palette.elevationShadow(dayOpacity: 0.10, nightOpacity: 0.24),
                    radius: 7,
                    y: 3.5
                )

            if isHighlighted && StorybookSurfaceClarityPolicy.showsTranslucentTintWash(reduceTransparency: reduceTransparency) {
                shape
                    .fill(activeTint.opacity(palette.isNight ? 0.14 : 0.08))
            }

            shape
                .strokeBorder(
                    isHighlighted
                        ? activeTint.opacity(highClarity ? (increased ? 0.92 : 0.78) : 0.55)
                        : (
                            highClarity
                                ? palette.primaryInk.opacity(
                                    StorybookSurfaceClarityPolicy.subtleBorderOpacity(
                                        isNight: palette.isNight,
                                        reduceTransparency: reduceTransparency,
                                        increasedContrast: increased
                                    )
                                )
                                : (palette.isNight ? Color.white.opacity(0.08) : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.08))
                        ),
                    lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(
                        isActive: isHighlighted,
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increased
                    )
                )
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
        let increased = colorSchemeContrast == .increased
        let highClarity = reduceTransparency || increased
        let tagShape = RoundedRectangle(cornerRadius: 6, style: .continuous)

        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            tagShape
                .fill(
                    tint.opacity(
                        StorybookSurfaceClarityPolicy.quietTagFillOpacity(
                            isNight: isNight,
                            reduceTransparency: reduceTransparency,
                            increasedContrast: increased
                        )
                    )
                )
                .overlay {
                    if highClarity {
                        tagShape.strokeBorder(tint.opacity(increased ? 0.75 : 0.45), lineWidth: 1.0)
                    }
                }
        )
    }
}

/// 柔和软胶按键物理挤压回弹（严格尊重系统「减弱动态效果」）
public struct StorybookTactileButtonStyle: ButtonStyle {
    public var sinkY: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(sinkY: CGFloat = 1.5) {
        self.sinkY = sinkY
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .offset(y: pressed ? sinkY : 0)
            .scaleEffect(x: pressed ? 1.015 : 1.0, y: pressed ? 0.96 : 1.0, anchor: .bottom)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.60), value: configuration.isPressed)
    }
}

/// 摸索台灯同宇宙嵌套圆角尺度：由外到内递减（舞台 -> 卡片 -> 内衬 -> 方块 -> 微标）
public enum ChimmoRadius {
    public static let stage: CGFloat = 28
    public static let card: CGFloat = 22
    public static let inner: CGFloat = 16
    public static let tile: CGFloat = 14
    public static let chip: CGFloat = 10
}

/// 咩哞章节锚点窑陶共鸣珠（对应摸索台灯的 `GoldBead`，以陶诺赤陶与夜灯暖金呈现声学个性）
public struct ChimmoResonanceBead: View {
    public var size: CGFloat
    public var isNight: Bool
    public var tint: Color?

    public init(size: CGFloat = 10, isNight: Bool = false, tint: Color? = nil) {
        self.size = size
        self.isNight = isNight
        self.tint = tint
    }

    public var body: some View {
        let beadTheme = ChimmoPalette(isNight: isNight)
        let core = tint ?? (isNight ? beadTheme.nightLampGold : beadTheme.homeAnchor)
        ZStack {
            Circle()
                .fill(core)
            Circle()
                .fill(Color.white.opacity(isNight ? 0.55 : 0.72))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(x: -size * 0.16, y: -size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 同宇宙章节标题行：左嵌声学窑陶共鸣珠，支持无障碍大字号垂直自动折行
public struct ChimmoSectionTitle: View {
    public let title: String
    public var detail: String?
    public var isNight: Bool
    public var tint: Color?
    @Environment(\.dynamicTypeSize) private var type

    public init(
        title: String,
        detail: String? = nil,
        isNight: Bool = false,
        tint: Color? = nil
    ) {
        self.title = title
        self.detail = detail
        self.isNight = isNight
        self.tint = tint
    }

    public var body: some View {
        let sectionTheme = ChimmoPalette(isNight: isNight)
        let secondaryInk = sectionTheme.secondaryInk
        let primaryInk = sectionTheme.primaryInk
        Group {
            if type.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        ChimmoResonanceBead(size: 10, isNight: isNight, tint: tint)
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(primaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ChimmoResonanceBead(size: 10, isNight: isNight, tint: tint)
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(primaryInk)
                    Spacer()
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(secondaryInk)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 自适应折行标签排布容器（彻底取代 `ScrollView(.horizontal)`，零横竖手势冲突与边缘截断）
public struct ChimmoFlowRow: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat

    public init(spacing: CGFloat = 7, lineSpacing: CGFloat = 7) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0
        var maxUsedW: CGFloat = 0

        for size in sizes {
            if x > 0 && x + size.width > maxW {
                x = 0
                y += lineH + lineSpacing
                lineH = 0
            }
            maxUsedW = max(maxUsedW, x + size.width)
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
        let resolvedW = maxW.isFinite ? maxW : maxUsedW
        return CGSize(width: resolvedW, height: y + lineH)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var x = bounds.minX
        var y = bounds.minY
        var lineH: CGFloat = 0

        for (subview, size) in zip(subviews, sizes) {
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineH + lineSpacing
                lineH = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
    }
}

/// 摸索台灯同源 `PrintCard` 纸卡修饰符：暖白棉纸 / 深靛夜纸 + 柔和顶部受光沿 + 单层温和接触影
public struct ChimmoAtelierCardModifier: ViewModifier {
    public let palette: ChimmoPalette
    public var radius: CGFloat
    public var tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(palette: ChimmoPalette, radius: CGFloat = ChimmoRadius.card, tint: Color? = nil) {
        self.palette = palette
        self.radius = radius
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = palette.isNight
        let increased = colorSchemeContrast == .increased
        let highClarity = reduceTransparency || increased
        let shadowColor = palette.elevationShadow(dayOpacity: 0.10, nightOpacity: 0.24)
        let rimTop: Color = dark
            ? palette.nightLampGold.opacity(0.16)
            : Color.white.opacity(0.92)

        return content
            .background {
                ZStack {
                    palette.cardSurface
                    if let tint, StorybookSurfaceClarityPolicy.showsTranslucentTintWash(reduceTransparency: reduceTransparency) {
                        LinearGradient(
                            colors: [tint.opacity(dark ? 0.14 : 0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if tint == nil, StorybookSurfaceClarityPolicy.showsSpecularSheen(
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increased
                    ) {
                        LinearGradient(
                            colors: [Color.white.opacity(dark ? 0.04 : 0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .clipShape(shape)
            }
            .clipShape(shape)
            .background {
                shape
                    .fill(palette.cardSurface)
                    .shadow(color: shadowColor, radius: dark ? 7 : 8, y: 4)
            }
            .overlay {
                Group {
                    if highClarity {
                        shape
                            .strokeBorder(
                                (tint ?? palette.primaryInk).opacity(
                                    tint != nil
                                        ? (increased ? 0.78 : 0.55)
                                        : StorybookSurfaceClarityPolicy.subtleBorderOpacity(
                                            isNight: dark,
                                            reduceTransparency: reduceTransparency,
                                            increasedContrast: increased
                                        )
                                ),
                                lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(
                                    isActive: tint != nil,
                                    reduceTransparency: reduceTransparency,
                                    increasedContrast: increased
                                )
                            )
                    } else {
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    stops: dark
                                        ? [.init(color: rimTop, location: 0),
                                           .init(color: .white.opacity(0.05), location: 0.32),
                                           .init(color: Color.black.opacity(0.20), location: 1)]
                                        : [.init(color: rimTop, location: 0),
                                           .init(color: .white.opacity(0.22), location: 0.38),
                                           .init(color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.08), location: 1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.0
                            )
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(shape)
    }
}

/// 摸索台灯同源 `VinylButton` 哑光软胶按键（实心强调态 / 柔和着色态，温和接触影 + 物理下压回弹）
public struct ChimmoVinylButtonStyle: ButtonStyle {
    public let palette: ChimmoPalette
    public var tint: Color?
    public var prominent: Bool
    public var large: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(
        palette: ChimmoPalette,
        tint: Color? = nil,
        prominent: Bool = false,
        large: Bool = false
    ) {
        self.palette = palette
        self.tint = tint
        self.prominent = prominent
        self.large = large
    }

    public func makeBody(configuration: Configuration) -> some View {
        let dark = palette.isNight
        let pressed = configuration.isPressed
        let increased = colorSchemeContrast == .increased
        let highClarity = reduceTransparency || increased
        let resolvedTint = tint ?? (prominent ? palette.prominentFill : palette.homeAnchor)
        let bodyFill: Color = prominent
            ? resolvedTint
            : resolvedTint.opacity(
                highClarity
                    ? StorybookSurfaceClarityPolicy.pillActiveFillOpacity(
                        isNight: dark,
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increased
                    )
                    : (dark ? 0.24 : 0.14)
            )
        let inkColor: Color = prominent
            ? .white
            : (dark ? resolvedTint : resolvedTint.mix(with: palette.primaryInk, by: 0.22))
        let shape = Capsule(style: .continuous)
        let shadowColor: Color = prominent
            ? (dark ? Color.black.opacity(0.34) : resolvedTint.opacity(0.26))
            : palette.elevationShadow(dayOpacity: 0.10, nightOpacity: 0.18)
        let rimTop: Color = dark
            ? palette.nightLampGold.opacity(prominent ? 0.22 : 0.14)
            : Color.white.opacity(0.84)

        return configuration.label
            .font((large ? Font.body : Font.subheadline).weight(.semibold))
            .foregroundStyle(inkColor)
            .padding(.horizontal, large ? 20 : 14)
            .padding(.vertical, large ? 13 : 9)
            .frame(minHeight: large ? 48 : 44)
            .background {
                ZStack {
                    if !prominent && highClarity {
                        shape.fill(palette.cardSurface)
                    }

                    shape
                        .fill(bodyFill)
                        .shadow(color: shadowColor, radius: pressed ? 1.5 : (prominent ? 6 : 3), y: pressed ? 0.8 : (prominent ? 3 : 2))

                    if StorybookSurfaceClarityPolicy.showsSpecularSheen(
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increased
                    ) {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(prominent ? 0.10 : (dark ? 0.05 : 0.40)), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }

                    if highClarity {
                        shape
                            .strokeBorder(
                                prominent
                                    ? (dark ? palette.nightLampGold.opacity(0.65) : palette.primaryInk.opacity(0.35))
                                    : resolvedTint.opacity(increased ? 0.85 : 0.55),
                                lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(
                                    isActive: prominent,
                                    reduceTransparency: reduceTransparency,
                                    increasedContrast: increased
                                )
                            )
                    } else {
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [rimTop, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.0
                            )
                    }
                }
            }
            .contentShape(shape)
            .opacity(enabled ? (pressed && reduceMotion ? 0.78 : 1.0) : 0.45)
            .offset(y: !reduceMotion && pressed ? 1.5 : 0)
            .scaleEffect(
                x: !reduceMotion && pressed ? 1.02 : 1.0,
                y: !reduceMotion && pressed ? 0.95 : 1.0,
                anchor: .bottom
            )
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.56), value: pressed)
    }
}

public extension View {
    func chimmoAtelierCard(
        palette: ChimmoPalette,
        radius: CGFloat = ChimmoRadius.card,
        tint: Color? = nil
    ) -> some View {
        modifier(ChimmoAtelierCardModifier(palette: palette, radius: radius, tint: tint))
    }
}

public extension ButtonStyle where Self == ChimmoVinylButtonStyle {
    static func chimmoVinyl(
        palette: ChimmoPalette,
        tint: Color? = nil,
        prominent: Bool = false,
        large: Bool = false
    ) -> ChimmoVinylButtonStyle {
        ChimmoVinylButtonStyle(palette: palette, tint: tint, prominent: prominent, large: large)
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
                ctx.fill(Circle().path(in: bobble), with: .color(ChimmoPalette.warmButterHighlight))
                ctx.stroke(Circle().path(in: bobble), with: .color(ink), style: stroke)
            case .bomo:
                let cap = CGRect(x: cx - 5.2, y: cy - 7.5, width: 10.4, height: 3.6)
                ctx.fill(Capsule().path(in: cap), with: .color(ChimmoPalette.warmButterHighlight))
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
            let outline = palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.10)

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
