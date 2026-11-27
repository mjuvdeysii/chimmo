import SwiftUI

/// Bespoke minimalist kiln ceramic symbol primitives rendered directly with SwiftUI vector paths.
public enum ChimmoCraftSymbol: String, CaseIterable, Sendable {
    case soundLibrary
    case nightLampHalo
    case humWave
    case appearanceDial
    case cardSeal
    case sleepTimer
    case frissonSeed
    case washDroplet
    case speakerHeadphones
}

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
            let lw = max(1.4, s * 0.088)
            let style = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            let accent = secondaryColor ?? color.opacity(0.45)

            switch symbol {
            case .soundLibrary:
                let box = s * 0.31
                let gap = s * 0.07
                let rects = [
                    CGRect(x: cx - box - gap * 0.5, y: cy - box - gap * 0.5, width: box, height: box),
                    CGRect(x: cx + gap * 0.5, y: cy - box - gap * 0.5, width: box, height: box),
                    CGRect(x: cx - box - gap * 0.5, y: cy + gap * 0.5, width: box, height: box),
                    CGRect(x: cx + gap * 0.5, y: cy + gap * 0.5, width: box, height: box)
                ]
                for (idx, r) in rects.enumerated() {
                    let p = RoundedRectangle(cornerRadius: s * 0.09, style: .continuous).path(in: r)
                    if idx == 0 {
                        ctx.fill(p, with: .color(color))
                    } else {
                        ctx.stroke(p, with: .color(idx == 3 ? accent : color), style: style)
                    }
                }

            case .nightLampHalo:
                let r = s * 0.30
                var moon = Path()
                let top = CGPoint(x: cx + r * 0.28, y: cy - r * 0.88)
                let bot = CGPoint(x: cx + r * 0.28, y: cy + r * 0.88)
                moon.move(to: top)
                moon.addCurve(to: bot, control1: CGPoint(x: cx - r * 1.05, y: cy - r * 0.45), control2: CGPoint(x: cx - r * 1.05, y: cy + r * 0.45))
                moon.addCurve(to: top, control1: CGPoint(x: cx - r * 0.18, y: cy + r * 0.35), control2: CGPoint(x: cx - r * 0.18, y: cy - r * 0.35))
                moon.closeSubpath()
                ctx.fill(moon, with: .color(color))
                let haloR = s * 0.42
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: cx - haloR, y: cy - haloR, width: haloR * 2, height: haloR * 2)),
                    with: .color(accent),
                    style: StrokeStyle(lineWidth: lw * 0.8, lineCap: .round, dash: [lw * 1.5, lw * 2.2])
                )

            case .humWave:
                var wave = Path()
                let steps = 16
                for idx in 0...steps {
                    let u = CGFloat(idx) / CGFloat(steps)
                    let x = cx - s * 0.38 + u * s * 0.76
                    let env = sin(u * .pi)
                    let y = cy - sin(u * .pi * 2.5) * s * 0.24 * env
                    if idx == 0 { wave.move(to: CGPoint(x: x, y: y)) } else { wave.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(wave, with: .color(color), style: style)
                let dotR = s * 0.08
                ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)), with: .color(accent))

            case .appearanceDial:
                let r = s * 0.34
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                var half = Path()
                half.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                half.closeSubpath()
                ctx.fill(half, with: .color(color))
                ctx.stroke(Path(ellipseIn: rect), with: .color(color), style: style)

            case .cardSeal:
                let rect = CGRect(x: cx - s * 0.30, y: cy - s * 0.36, width: s * 0.60, height: s * 0.72)
                ctx.stroke(RoundedRectangle(cornerRadius: s * 0.12, style: .continuous).path(in: rect), with: .color(color), style: style)
                let orbR = s * 0.13
                ctx.fill(Path(ellipseIn: CGRect(x: cx - orbR, y: cy - orbR - s * 0.04, width: orbR * 2, height: orbR * 2)), with: .color(accent))
                var line = Path()
                line.move(to: CGPoint(x: cx - s * 0.16, y: cy + s * 0.19))
                line.addLine(to: CGPoint(x: cx + s * 0.16, y: cy + s * 0.19))
                ctx.stroke(line, with: .color(color), style: style)

            case .sleepTimer:
                let r = s * 0.34
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(color), style: style)
                var hand = Path()
                hand.move(to: CGPoint(x: cx, y: cy - r * 0.54))
                hand.addLine(to: CGPoint(x: cx, y: cy))
                hand.addLine(to: CGPoint(x: cx + r * 0.42, y: cy + r * 0.22))
                ctx.stroke(hand, with: .color(color), style: style)

            case .frissonSeed:
                for idx in 0..<4 {
                    let angle = CGFloat(idx) * .pi * 0.5
                    let px = cx + cos(angle) * s * 0.18
                    let py = cy + sin(angle) * s * 0.18
                    let pr = s * 0.15
                    ctx.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(idx.isMultiple(of: 2) ? color : accent))
                }
                let cr = s * 0.10
                ctx.fill(Path(ellipseIn: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2)), with: .color(color))

            case .washDroplet:
                var drop = Path()
                drop.move(to: CGPoint(x: cx, y: cy - s * 0.36))
                drop.addCurve(
                    to: CGPoint(x: cx + s * 0.25, y: cy + s * 0.10),
                    control1: CGPoint(x: cx + s * 0.14, y: cy - s * 0.14),
                    control2: CGPoint(x: cx + s * 0.25, y: cy - s * 0.02)
                )
                drop.addArc(
                    center: CGPoint(x: cx, y: cy + s * 0.10),
                    radius: s * 0.25,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: false
                )
                drop.addCurve(
                    to: CGPoint(x: cx, y: cy - s * 0.36),
                    control1: CGPoint(x: cx - s * 0.25, y: cy - s * 0.02),
                    control2: CGPoint(x: cx - s * 0.14, y: cy - s * 0.14)
                )
                drop.closeSubpath()
                ctx.fill(drop, with: .color(accent))
                ctx.stroke(drop, with: .color(color), style: style)
                var ripple = Path()
                ripple.move(to: CGPoint(x: cx - s * 0.32, y: cy + s * 0.38))
                ripple.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.32, y: cy + s * 0.38),
                    control: CGPoint(x: cx, y: cy + s * 0.30)
                )
                ctx.stroke(ripple, with: .color(color), style: style)

            case .speakerHeadphones:
                var arch = Path()
                arch.addArc(center: CGPoint(x: cx, y: cy + s * 0.04), radius: s * 0.30, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                ctx.stroke(arch, with: .color(color), style: style)
                let cupW = s * 0.16
                let cupH = s * 0.28
                let leftCup = RoundedRectangle(cornerRadius: s * 0.06, style: .continuous).path(in: CGRect(x: cx - s * 0.36, y: cy - s * 0.02, width: cupW, height: cupH))
                let rightCup = RoundedRectangle(cornerRadius: s * 0.06, style: .continuous).path(in: CGRect(x: cx + s * 0.20, y: cy - s * 0.02, width: cupW, height: cupH))
                ctx.fill(leftCup, with: .color(color))
                ctx.fill(rightCup, with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

/// System Increase Contrast & Reduce Transparency clarity helper.
public enum StorybookSurfaceClarityPolicy: Sendable {
    public static func showsTranslucentTintWash(reduceTransparency: Bool) -> Bool {
        !reduceTransparency
    }

    public static func borderLineWidth(isActive: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> CGFloat {
        if increasedContrast {
            return isActive ? 2.2 : 1.75
        }
        if reduceTransparency {
            return isActive ? 1.8 : 1.25
        }
        return isActive ? 1.5 : 1.0
    }

    public static func subtleBorderOpacity(isNight: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> Double {
        if increasedContrast {
            return isNight ? 0.42 : 0.34
        }
        if reduceTransparency {
            return isNight ? 0.24 : 0.18
        }
        return isNight ? 0.14 : 0.11
    }
}

/// Nested radius scale descending cleanly from stage to tile.
public enum ChimmoRadius {
    public static let stage: CGFloat = 28
    public static let card: CGFloat = 22
    public static let inner: CGFloat = 16
    public static let tile: CGFloat = 14
    public static let chip: CGFloat = 10
}

public enum ChimmoAffordance {
    public static let minHitTarget: CGFloat = 44
}

/// Tactile micro-scale and vertical depression feedback honoring Reduce Motion.
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
            .scaleEffect(pressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed && reduceMotion ? 0.78 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.64), value: configuration.isPressed)
    }
}

/// Minimal kiln glaze bead accent for section anchors.
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
            Circle().fill(core)
            Circle()
                .fill(Color.white.opacity(isNight ? 0.45 : 0.68))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(x: -size * 0.16, y: -size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Unified section heading with combined VoiceOver `.isHeader` semantics and AX1-AX5 flow.
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
        Group {
            if type.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        ChimmoResonanceBead(size: 10, isNight: isNight, tint: tint)
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(sectionTheme.primaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(sectionTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        ChimmoResonanceBead(size: 10, isNight: isNight, tint: tint)
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(sectionTheme.primaryInk)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 8)
                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(sectionTheme.secondaryInk)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .center, spacing: 8) {
                            ChimmoResonanceBead(size: 10, isNight: isNight, tint: tint)
                            Text(title)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(sectionTheme.primaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(sectionTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 18)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Flow wrapping chip layout clamped cleanly inside available parent width.
public struct ChimmoFlowRow: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rawWidth = proposal.width ?? .infinity
        let maxW = rawWidth.isFinite ? max(1, rawWidth) : 340
        var rowW: CGFloat = 0
        var rowH: CGFloat = 0
        var totalH: CGFloat = 0
        var maxUsedW: CGFloat = 0

        for subview in subviews {
            let ideal = subview.sizeThatFits(ProposedViewSize(width: maxW, height: nil))
            let cappedW = min(maxW, ideal.width)
            let s = CGSize(width: cappedW, height: ideal.height)
            if rowW > 0 && rowW + spacing + s.width > maxW {
                totalH += rowH + lineSpacing
                maxUsedW = max(maxUsedW, rowW)
                rowW = s.width
                rowH = s.height
            } else {
                rowW = (rowW == 0) ? s.width : (rowW + spacing + s.width)
                rowH = max(rowH, s.height)
            }
        }
        totalH += rowH
        maxUsedW = max(maxUsedW, rowW)
        return CGSize(width: proposal.width ?? maxUsedW, height: max(0, totalH))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = max(1, bounds.width)
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0

        for subview in subviews {
            let ideal = subview.sizeThatFits(ProposedViewSize(width: maxW, height: nil))
            let cappedW = min(maxW, ideal.width)
            let s = CGSize(width: cappedW, height: ideal.height)
            // `x` already includes trailing `spacing` from previous item, so do NOT add `spacing` again.
            if x > bounds.minX && (x - bounds.minX) + s.width > maxW {
                x = bounds.minX
                y += rowH + lineSpacing
                rowH = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: s.width, height: s.height)
            )
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Cotton paper & deep indigo matte kiln card modifier.
public struct ChimmoAtelierCardModifier: ViewModifier {
    public let palette: ChimmoPalette
    public var radius: CGFloat
    public var tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    public init(palette: ChimmoPalette, radius: CGFloat = ChimmoRadius.card, tint: Color? = nil) {
        self.palette = palette
        self.radius = radius
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = palette.isNight
        let increased = (contrast == .increased)
        let borderOpacity = StorybookSurfaceClarityPolicy.subtleBorderOpacity(
            isNight: dark,
            reduceTransparency: reduceTransparency,
            increasedContrast: increased
        )
        let borderWidth = StorybookSurfaceClarityPolicy.borderLineWidth(
            isActive: false,
            reduceTransparency: reduceTransparency,
            increasedContrast: increased
        )
        let cardShadow = palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.26)

        content
            .background {
                shape
                    .fill(palette.cardSurface)
                    .shadow(color: cardShadow, radius: dark ? 10 : 8, y: 3)
                    .overlay {
                        if let tint,
                           StorybookSurfaceClarityPolicy.showsTranslucentTintWash(reduceTransparency: reduceTransparency) {
                            shape.fill(tint.opacity(dark ? 0.14 : 0.07))
                        }
                    }
                    .overlay {
                        shape.strokeBorder(
                            (tint != nil && increased)
                                ? tint!.opacity(0.75)
                                : (dark ? palette.primaryInk.opacity(borderOpacity) : Color(hex: 0x3A2E22).opacity(borderOpacity)),
                            lineWidth: borderWidth
                        )
                    }
            }
            .contentShape(shape)
    }
}

/// Accessible matte-glaze pill button with guaranteed foreground contrast in both light and dark themes.
public struct ChimmoVinylButtonStyle: ButtonStyle {
    public let palette: ChimmoPalette
    public var tint: Color?
    public var prominent: Bool
    public var large: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var enabled

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
        let resolvedTint = tint ?? palette.prominentFill
        let pressed = configuration.isPressed
        let increased = (contrast == .increased)
        let highClarity = reduceTransparency || increased
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)

        let bodyFill: Color = prominent ? resolvedTint : palette.cardSurface

        let labelColor: Color = prominent ? palette.contrastInkOnAccent : palette.primaryInk

        let strokeColor: Color = {
            if prominent {
                return increased ? palette.primaryInk : resolvedTint.opacity(0.45)
            }
            return increased ? resolvedTint.opacity(0.95) : resolvedTint.opacity(dark ? 0.55 : 0.40)
        }()

        let shadowColor = prominent
            ? palette.elevationShadow(dayOpacity: 0.16, nightOpacity: 0.34)
            : palette.elevationShadow(dayOpacity: 0.05, nightOpacity: 0.16)

        configuration.label
            .foregroundStyle(labelColor)
            .padding(.horizontal, large ? 20 : 14)
            .padding(.vertical, large ? 12 : 9)
            .frame(minHeight: large ? 48 : ChimmoAffordance.minHitTarget)
            .background {
                shape
                    .fill(bodyFill)
                    .overlay {
                        if !prominent && !highClarity {
                            shape.fill(resolvedTint.opacity(dark ? 0.12 : 0.07))
                        }
                    }
                    .shadow(color: shadowColor, radius: pressed ? 1.5 : (prominent ? 6 : 2.5), y: pressed ? 0.8 : (prominent ? 3 : 1.5))
                    .overlay {
                        shape.strokeBorder(
                            strokeColor,
                            lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(
                                isActive: prominent,
                                reduceTransparency: reduceTransparency,
                                increasedContrast: increased
                            )
                        )
                    }
            }
            .contentShape(shape)
            .opacity(enabled ? (pressed && reduceMotion ? 0.82 : 1.0) : 0.45)
            .offset(y: !reduceMotion && pressed ? 1.5 : 0)
            .scaleEffect(!reduceMotion && pressed ? 0.975 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: pressed)
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
