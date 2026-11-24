import SwiftUI

/// 咩哞 · Chimmo 声学双子星（Mie & Mou）：
/// - 「咩 · Mie」：轻盈云朵瓷小羊，头生螺旋卷羊角，掌管高音主旋律与跟唱律动；
/// - 「哞 · Mou」：沉稳可可陶小牛，头戴新月黄铜牛角，掌管低音根音与和声伴奏。
public enum ChimmoDuoCharacter: String, CaseIterable, Identifiable, Sendable {
    case mie // 咩（羊叫声 · 主旋律高音）
    case mou // 哞（牛叫声 · 低音伴奏和声）

    public var id: String { rawValue }

    public var chineseName: String {
        switch self {
        case .mie: return "咩"
        case .mou: return "哞"
        }
    }

    public var englishName: String {
        switch self {
        case .mie: return "Mie"
        case .mou: return "Mou"
        }
    }

    public var roleShort: String {
        switch self {
        case .mie: return "主旋律"
        case .mou: return "伴奏"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .mie: return "小羊咩，主旋律"
        case .mou: return "小牛哞，低音伴奏"
        }
    }

    public var signatureDegree: Int {
        switch self {
        case .mie: return 5
        case .mou: return 1
        }
    }

    public var signatureOctave: Int {
        switch self {
        case .mie: return 0
        case .mou: return -1
        }
    }
}

/// 纯值驱动的双子实时陪伴姿态快照（100% 可单测、严格尊重减弱动态效果）。
public struct ChimmoDuoCompanionState: Equatable, Sendable {
    public let sheepBouncePt: CGFloat
    public let sheepEarWiggleDeg: Double
    public let cowBreathScale: CGFloat
    public let cowSleeping: Bool
    public let cowGlowOpacity: Double

    public init(
        sheepBouncePt: CGFloat,
        sheepEarWiggleDeg: Double,
        cowBreathScale: CGFloat,
        cowSleeping: Bool,
        cowGlowOpacity: Double
    ) {
        self.sheepBouncePt = sheepBouncePt
        self.sheepEarWiggleDeg = sheepEarWiggleDeg
        self.cowBreathScale = cowBreathScale
        self.cowSleeping = cowSleeping
        self.cowGlowOpacity = cowGlowOpacity
    }

    public static func compute(
        melodyActive: Bool,
        cowAwake: Bool,
        isPlaying: Bool,
        reduceMotion: Bool
    ) -> ChimmoDuoCompanionState {
        let sleeping = !cowAwake
        let glow = cowAwake ? (isPlaying ? 0.85 : 0.48) : 0.0
        if reduceMotion {
            return ChimmoDuoCompanionState(
                sheepBouncePt: 0.0,
                sheepEarWiggleDeg: 0.0,
                cowBreathScale: 1.0,
                cowSleeping: sleeping,
                cowGlowOpacity: glow
            )
        }
        return ChimmoDuoCompanionState(
            sheepBouncePt: melodyActive ? -3.2 : 0.0,
            sheepEarWiggleDeg: melodyActive ? 7.5 : 0.0,
            cowBreathScale: (cowAwake && isPlaying) ? 1.04 : 1.0,
            cowSleeping: sleeping,
            cowGlowOpacity: glow
        )
    }
}

/// 实时呼吸、错峰眨眼、声部视线跟随与小憩呼吸弧的纯值运动学快照（100% 可单测、严格尊重减弱动态效果）。
public struct ChimmoDuoMotionKinematics: Equatable, Sendable {
    public let sheepBreathY: CGFloat
    public let sheepBreathScaleY: CGFloat
    public let sheepBlinkClosed: Bool
    public let cowBreathY: CGFloat
    public let cowBreathScale: CGFloat
    public let cowBlinkClosed: Bool
    public let sleepArcProgress: Double
    public let gazeOffsetX: CGFloat

    public init(
        sheepBreathY: CGFloat,
        sheepBreathScaleY: CGFloat,
        sheepBlinkClosed: Bool,
        cowBreathY: CGFloat,
        cowBreathScale: CGFloat,
        cowBlinkClosed: Bool,
        sleepArcProgress: Double,
        gazeOffsetX: CGFloat
    ) {
        self.sheepBreathY = sheepBreathY
        self.sheepBreathScaleY = sheepBreathScaleY
        self.sheepBlinkClosed = sheepBlinkClosed
        self.cowBreathY = cowBreathY
        self.cowBreathScale = cowBreathScale
        self.cowBlinkClosed = cowBlinkClosed
        self.sleepArcProgress = sleepArcProgress
        self.gazeOffsetX = gazeOffsetX
    }

    public static func compute(
        phaseTime: Double,
        melodyActive: Bool,
        cowAwake: Bool,
        isPlaying: Bool,
        gazeBias: Double = 0.0,
        reduceMotion: Bool
    ) -> ChimmoDuoMotionKinematics {
        let safeTime = phaseTime.isFinite ? max(0.0, phaseTime) : 0.0
        let safeGaze = gazeBias.isFinite ? max(-1.0, min(1.0, gazeBias)) : 0.0

        if reduceMotion || safeTime <= 0.0001 {
            return ChimmoDuoMotionKinematics(
                sheepBreathY: 0.0,
                sheepBreathScaleY: 1.0,
                sheepBlinkClosed: false,
                cowBreathY: 0.0,
                cowBreathScale: 1.0,
                cowBlinkClosed: false,
                sleepArcProgress: 0.0,
                gazeOffsetX: reduceMotion ? 0.0 : CGFloat(safeGaze)
            )
        }

        let sheepWave = sin(safeTime * (2.0 * Double.pi / 2.9))
        let sheepBreathY = CGFloat(-1.25 * sheepWave)
        let sheepBreathScaleY = CGFloat(1.0 + 0.018 * sheepWave)
        let sheepBlinkLocal = safeTime.truncatingRemainder(dividingBy: 4.7)
        let sheepBlinkClosed = !melodyActive && sheepBlinkLocal >= 0.0 && sheepBlinkLocal < 0.13

        let cowWave = sin(safeTime * (2.0 * Double.pi / 3.8) + 1.1)
        let cowBreathY = CGFloat(-0.95 * cowWave)
        let cowBreathScale = CGFloat(1.0 + ((cowAwake && isPlaying) ? 0.024 : 0.014) * cowWave)
        let cowBlinkLocal = (safeTime + 2.15).truncatingRemainder(dividingBy: 5.6)
        let cowBlinkClosed = cowAwake && cowBlinkLocal >= 0.0 && cowBlinkLocal < 0.13

        let sleepArcProgress = cowAwake ? 0.0 : (safeTime.truncatingRemainder(dividingBy: 3.2) / 3.2)

        return ChimmoDuoMotionKinematics(
            sheepBreathY: sheepBreathY,
            sheepBreathScaleY: sheepBreathScaleY,
            sheepBlinkClosed: sheepBlinkClosed,
            cowBreathY: cowBreathY,
            cowBreathScale: cowBreathScale,
            cowBlinkClosed: cowBlinkClosed,
            sleepArcProgress: sleepArcProgress,
            gazeOffsetX: CGFloat(safeGaze)
        )
    }
}

/// 「咩 · Mie」云朵瓷小羊矢量绘制组件（支持任意缩放与离线 ImageRenderer 渲染）。
public struct ChimmoSheepView: View {
    public let isNight: Bool
    public let accentColor: Color
    public var isSinging: Bool = false
    public var tiltProgress: Double = 0.0
    public var phaseTime: Double = 0.0
    public var gazeBias: Double = 0.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isNight: Bool,
        accentColor: Color,
        isSinging: Bool = false,
        tiltProgress: Double = 0.0,
        phaseTime: Double = 0.0,
        gazeBias: Double = 0.0
    ) {
        self.isNight = isNight
        self.accentColor = accentColor
        self.isSinging = isSinging
        self.tiltProgress = tiltProgress
        self.phaseTime = phaseTime
        self.gazeBias = gazeBias
    }

    public var body: some View {
        let clampedTilt = tiltProgress.isFinite ? max(-1.0, min(1.0, tiltProgress)) : 0.0
        let state = ChimmoDuoCompanionState.compute(
            melodyActive: isSinging,
            cowAwake: true,
            isPlaying: isSinging,
            reduceMotion: reduceMotion
        )
        let kin = ChimmoDuoMotionKinematics.compute(
            phaseTime: phaseTime,
            melodyActive: isSinging,
            cowAwake: true,
            isPlaying: isSinging,
            gazeBias: gazeBias,
            reduceMotion: reduceMotion
        )

        Canvas { ctx, size in
            drawSheep(ctx: &ctx, size: size, state: state, kin: kin)
        }
        .scaleEffect(x: 1.0, y: kin.sheepBreathScaleY, anchor: .bottom)
        .offset(y: state.sheepBouncePt + kin.sheepBreathY)
        .rotationEffect(.degrees(clampedTilt * 9.0 + state.sheepEarWiggleDeg * 0.35), anchor: .bottom)
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.62), value: isSinging)
        .accessibilityHidden(true)
    }

    private func drawSheep(
        ctx: inout GraphicsContext,
        size: CGSize,
        state: ChimmoDuoCompanionState,
        kin: ChimmoDuoMotionKinematics
    ) {
        let w = size.width
        let h = size.height
        let s = min(w, h)
        let cx = w * 0.5
        let cy = h * 0.54
        let lw = max(1.1, s * 0.055)

        // 接地投影
        let shadowRect = CGRect(x: cx - s * 0.28, y: cy + s * 0.34, width: s * 0.56, height: s * 0.11)
        ctx.fill(
            Path(ellipseIn: shadowRect),
            with: .color(Color.black.opacity(isNight ? 0.34 : 0.12))
        )

        // 唱响外环微光
        if isSinging {
            let haloR = s * 0.46
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - haloR, y: cy - haloR, width: haloR * 2, height: haloR * 2)),
                with: .color(accentColor.opacity(0.45)),
                lineWidth: max(1.0, lw * 0.75)
            )
        }

        // 柔垂双耳
        let earColor = isNight ? Color(hex: 0xD8CCB8) : Color(hex: 0xE7DDD0)
        let earStroke = isNight ? Color(hex: 0x7A736E) : Color(hex: 0xB8AD9E)
        let wiggleRad: Double = state.sheepEarWiggleDeg * (Double.pi / 180.0) * 0.35
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            let ex = cx + sx * s * 0.34
            let ey = cy - s * 0.04
            let earRect = CGRect(x: ex - s * 0.10, y: ey - s * 0.06, width: s * 0.20, height: s * 0.12)
            let angleRad = CGFloat(side * 0.32 + wiggleRad * side)
            let earRot = CGAffineTransform(translationX: ex, y: ey)
                .rotated(by: angleRad)
                .translatedBy(x: -ex, y: -ey)
            let earPath = Path(ellipseIn: earRect).applying(earRot)
            ctx.fill(earPath, with: .color(earColor))
            ctx.stroke(earPath, with: .color(earStroke.opacity(0.65)), lineWidth: max(0.8, lw * 0.55))
        }

        // 云朵瓷小羊身体（三瓣蓬松轮廓）
        let woolFill = isNight ? Color(hex: 0xEDE4D5) : Color(hex: 0xFFFBF3)
        let woolStroke = isNight ? Color(hex: 0x9C9488) : Color(hex: 0xC8BCAC)
        let cloudPuffs: [CGRect] = [
            CGRect(x: cx - s * 0.31, y: cy - s * 0.16, width: s * 0.38, height: s * 0.38),
            CGRect(x: cx - s * 0.07, y: cy - s * 0.16, width: s * 0.38, height: s * 0.38),
            CGRect(x: cx - s * 0.25, y: cy - s * 0.32, width: s * 0.50, height: s * 0.44),
            CGRect(x: cx - s * 0.29, y: cy - s * 0.08, width: s * 0.58, height: s * 0.44)
        ]
        for puff in cloudPuffs {
            ctx.fill(Path(ellipseIn: puff), with: .color(woolFill))
        }
        let mainBodyRect = CGRect(x: cx - s * 0.30, y: cy - s * 0.27, width: s * 0.60, height: s * 0.58)
        ctx.stroke(
            Path(ellipseIn: mainBodyRect),
            with: .color(woolStroke.opacity(0.45)),
            lineWidth: max(0.8, lw * 0.50)
        )

        // 暖杏陶面部椭圆
        let faceFill = isNight ? Color(hex: 0xD9C8B4) : Color(hex: 0xF3E6D4)
        let faceRect = CGRect(x: cx - s * 0.19, y: cy - s * 0.16, width: s * 0.38, height: s * 0.31)
        ctx.fill(Path(ellipseIn: faceRect), with: .color(faceFill))

        // 螺旋卷羊角（左、右对称声学高音卷涡）
        let hornColor = isSinging ? accentColor : (isNight ? Color(hex: 0xFFB84D) : Color(hex: 0xD99E32))
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            var horn = Path()
            horn.move(to: CGPoint(x: cx + sx * s * 0.08, y: cy - s * 0.25))
            horn.addCurve(
                to: CGPoint(x: cx + sx * s * 0.30, y: cy - s * 0.24),
                control1: CGPoint(x: cx + sx * s * 0.14, y: cy - s * 0.44),
                control2: CGPoint(x: cx + sx * s * 0.34, y: cy - s * 0.40)
            )
            horn.addCurve(
                to: CGPoint(x: cx + sx * s * 0.18, y: cy - s * 0.22),
                control1: CGPoint(x: cx + sx * s * 0.27, y: cy - s * 0.14),
                control2: CGPoint(x: cx + sx * s * 0.17, y: cy - s * 0.16)
            )
            ctx.stroke(
                horn,
                with: .color(hornColor),
                style: StrokeStyle(lineWidth: lw * 1.15, lineCap: .round, lineJoin: .round)
            )
            if isSinging {
                for waveIdx in 0..<2 {
                    let waveR = s * (0.14 + CGFloat(waveIdx) * 0.075)
                    let centerPt = CGPoint(x: cx + sx * s * 0.30, y: cy - s * 0.32)
                    var waveArc = Path()
                    let startDeg = side < 0 ? 135.0 : -45.0
                    let endDeg = side < 0 ? 225.0 : 45.0
                    waveArc.addArc(
                        center: centerPt,
                        radius: waveR,
                        startAngle: .degrees(startDeg),
                        endAngle: .degrees(endDeg),
                        clockwise: false
                    )
                    ctx.stroke(
                        waveArc,
                        with: .color(accentColor.opacity(waveIdx == 0 ? 0.42 : 0.20)),
                        style: StrokeStyle(lineWidth: max(0.9, lw * 0.55), lineCap: .round)
                    )
                }
            }
        }

        // 上釉圆眼 / 自然眨眼 / 陶醉弯笑眼（零台词零嘴型）
        let inkColor = Color(hex: 0x1C1D19)
        let eyeY = cy - s * 0.03
        let eyeDX = s * 0.095
        let gazeShiftX = kin.gazeOffsetX * s * 0.022
        for side in [-1.0, 1.0] {
            let ex = cx + CGFloat(side) * eyeDX
            if isSinging {
                var smileArc = Path()
                smileArc.move(to: CGPoint(x: ex - s * 0.038, y: eyeY + s * 0.015))
                smileArc.addQuadCurve(
                    to: CGPoint(x: ex + s * 0.038, y: eyeY + s * 0.015),
                    control: CGPoint(x: ex, y: eyeY - s * 0.038)
                )
                ctx.stroke(
                    smileArc,
                    with: .color(inkColor),
                    style: StrokeStyle(lineWidth: max(1.1, lw * 0.78), lineCap: .round)
                )
            } else if kin.sheepBlinkClosed {
                var blinkLine = Path()
                blinkLine.move(to: CGPoint(x: ex - s * 0.038, y: eyeY))
                blinkLine.addLine(to: CGPoint(x: ex + s * 0.038, y: eyeY))
                ctx.stroke(
                    blinkLine,
                    with: .color(inkColor),
                    style: StrokeStyle(lineWidth: max(1.1, lw * 0.76), lineCap: .round)
                )
            } else {
                let er = max(1.5, s * 0.042)
                let gx = ex + gazeShiftX
                ctx.fill(
                    Path(ellipseIn: CGRect(x: gx - er, y: eyeY - er, width: er * 2, height: er * 2)),
                    with: .color(inkColor)
                )
                let hr = max(0.6, er * 0.34)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: gx - er * 0.45, y: eyeY - er * 0.55, width: hr * 2, height: hr * 2)),
                    with: .color(Color.white.opacity(0.92))
                )
            }
        }

        // 腮红与精致踏脚小蹄
        let cheekColor = isSinging ? accentColor.opacity(0.45) : Color(hex: 0xE87A82).opacity(0.32)
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            let chx = cx + sx * s * 0.135
            let chy = cy + s * 0.045
            let cr = s * 0.035
            ctx.fill(Path(ellipseIn: CGRect(x: chx - cr, y: chy - cr, width: cr * 2, height: cr * 2)), with: .color(cheekColor))

            let fx = cx + sx * s * 0.115
            let fy = cy + s * 0.30
            ctx.fill(
                Path(ellipseIn: CGRect(x: fx - s * 0.055, y: fy - s * 0.035, width: s * 0.11, height: s * 0.07)),
                with: .color(Color(hex: 0x5B4A42))
            )
        }
    }
}

/// 「哞 · Mou」可可陶小牛矢量绘制组件（伴奏开启睁眼共鸣、伴奏关闭安静闭眼小憩）。
public struct ChimmoCowView: View {
    public let isNight: Bool
    public let accentColor: Color
    public var isAwake: Bool = true
    public var isPlaying: Bool = false
    public var phaseTime: Double = 0.0
    public var gazeBias: Double = 0.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isNight: Bool,
        accentColor: Color,
        isAwake: Bool = true,
        isPlaying: Bool = false,
        phaseTime: Double = 0.0,
        gazeBias: Double = 0.0
    ) {
        self.isNight = isNight
        self.accentColor = accentColor
        self.isAwake = isAwake
        self.isPlaying = isPlaying
        self.phaseTime = phaseTime
        self.gazeBias = gazeBias
    }

    public var body: some View {
        let state = ChimmoDuoCompanionState.compute(
            melodyActive: false,
            cowAwake: isAwake,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion
        )
        let kin = ChimmoDuoMotionKinematics.compute(
            phaseTime: phaseTime,
            melodyActive: false,
            cowAwake: isAwake,
            isPlaying: isPlaying,
            gazeBias: gazeBias,
            reduceMotion: reduceMotion
        )

        Canvas { ctx, size in
            drawCow(ctx: &ctx, size: size, state: state, kin: kin)
        }
        .scaleEffect(state.cowBreathScale * kin.cowBreathScale)
        .offset(y: kin.cowBreathY)
        .opacity(isAwake ? 1.0 : 0.78)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isAwake)
        .accessibilityHidden(true)
    }

    private func drawCow(
        ctx: inout GraphicsContext,
        size: CGSize,
        state: ChimmoDuoCompanionState,
        kin: ChimmoDuoMotionKinematics
    ) {
        let w = size.width
        let h = size.height
        let s = min(w, h)
        let cx = w * 0.5
        let cy = h * 0.56
        let lw = max(1.1, s * 0.055)

        // 接地投影
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - s * 0.32, y: cy + s * 0.32, width: s * 0.64, height: s * 0.11)),
            with: .color(Color.black.opacity(isNight ? 0.36 : 0.14))
        )

        // 发声 / 伴奏唤醒微光环
        if state.cowGlowOpacity > 0.05 && isPlaying {
            let haloR = s * 0.45
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - haloR, y: cy - haloR * 0.96, width: haloR * 2, height: haloR * 1.92)),
                with: .color(accentColor.opacity(state.cowGlowOpacity * 0.48)),
                lineWidth: max(1.0, lw * 0.78)
            )
        }

        // 两侧圆润牛耳
        let bodyColor = isNight ? Color(hex: 0x4E426E) : Color(hex: 0x8F5F4E)
        let bodyRim = isNight ? Color(hex: 0x7A6BA3) : Color(hex: 0x694235)
        for side in [-1.0, 1.0] {
            let ex = cx + CGFloat(side) * s * 0.34
            let ey = cy - s * 0.12
            let earRect = CGRect(x: ex - s * 0.095, y: ey - s * 0.055, width: s * 0.19, height: s * 0.11)
            ctx.fill(Path(ellipseIn: earRect), with: .color(bodyColor))
            ctx.stroke(Path(ellipseIn: earRect), with: .color(bodyRim.opacity(0.6)), lineWidth: max(0.8, lw * 0.45))
        }

        // 敦厚可可窑陶身躯
        let bodyRect = CGRect(x: cx - s * 0.33, y: cy - s * 0.25, width: s * 0.66, height: s * 0.57)
        let bodyPath = RoundedRectangle(cornerRadius: s * 0.28, style: .continuous).path(in: bodyRect)
        ctx.fill(bodyPath, with: .color(bodyColor))
        ctx.stroke(bodyPath, with: .color(bodyRim.opacity(0.55)), lineWidth: max(0.8, lw * 0.48))

        // 象牙黄铜新月弯牛角（呼应和声摇篮与音叉弧）
        let hornFill = isAwake ? (isNight ? Color(hex: 0xFFD275) : Color(hex: 0xF3E4CB)) : Color(hex: 0xB8AE9E).opacity(0.75)
        let hornEdge = isAwake ? (isNight ? Color(hex: 0xD99E32) : Color(hex: 0xB98532)) : Color(hex: 0x8F867A).opacity(0.6)
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            var horn = Path()
            horn.move(to: CGPoint(x: cx + sx * s * 0.11, y: cy - s * 0.23))
            horn.addQuadCurve(
                to: CGPoint(x: cx + sx * s * 0.28, y: cy - s * 0.40),
                control: CGPoint(x: cx + sx * s * 0.25, y: cy - s * 0.26)
            )
            horn.addQuadCurve(
                to: CGPoint(x: cx + sx * s * 0.17, y: cy - s * 0.21),
                control: CGPoint(x: cx + sx * s * 0.20, y: cy - s * 0.32)
            )
            horn.closeSubpath()
            ctx.fill(horn, with: .color(hornFill))
            ctx.stroke(horn, with: .color(hornEdge), lineWidth: max(0.8, lw * 0.45))
        }

        // 宽厚奶油鼻吻椭圆与鼻点
        let snoutFill = isNight ? Color(hex: 0xDFD0BE) : Color(hex: 0xF6EBDD)
        let snoutRect = CGRect(x: cx - s * 0.22, y: cy + s * 0.01, width: s * 0.44, height: s * 0.23)
        ctx.fill(Path(ellipseIn: snoutRect), with: .color(snoutFill))
        let nostrilCol = Color(hex: 0x5A3D34)
        for side in [-1.0, 1.0] {
            let nx = cx + CGFloat(side) * s * 0.085
            let ny = cy + s * 0.115
            let nr = max(1.0, s * 0.025)
            ctx.fill(Path(ellipseIn: CGRect(x: nx - nr, y: ny - nr * 0.8, width: nr * 2, height: nr * 1.6)), with: .color(nostrilCol))
        }

        // 眼睛（唤醒时温厚圆眼 / 错峰眨眼 / 伴奏关闭时静谧闭眼弧）
        let eyeY = cy - s * 0.08
        let eyeDX = s * 0.11
        let inkColor = Color(hex: 0x1C1D19)
        let gazeShiftX = kin.gazeOffsetX * s * 0.022
        for side in [-1.0, 1.0] {
            let ex = cx + CGFloat(side) * eyeDX
            if !isAwake {
                var sleepArc = Path()
                sleepArc.move(to: CGPoint(x: ex - s * 0.038, y: eyeY - s * 0.008))
                sleepArc.addQuadCurve(
                    to: CGPoint(x: ex + s * 0.038, y: eyeY - s * 0.008),
                    control: CGPoint(x: ex, y: eyeY + s * 0.034)
                )
                ctx.stroke(
                    sleepArc,
                    with: .color(Color(hex: 0xEFE7DC).opacity(0.9)),
                    style: StrokeStyle(lineWidth: max(1.0, lw * 0.72), lineCap: .round)
                )
            } else if kin.cowBlinkClosed {
                var blinkLine = Path()
                blinkLine.move(to: CGPoint(x: ex - s * 0.038, y: eyeY))
                blinkLine.addLine(to: CGPoint(x: ex + s * 0.038, y: eyeY))
                ctx.stroke(
                    blinkLine,
                    with: .color(inkColor),
                    style: StrokeStyle(lineWidth: max(1.0, lw * 0.74), lineCap: .round)
                )
            } else {
                let er = max(1.5, s * 0.043)
                let gx = ex + gazeShiftX
                ctx.fill(
                    Path(ellipseIn: CGRect(x: gx - er, y: eyeY - er, width: er * 2, height: er * 2)),
                    with: .color(inkColor)
                )
                let hr = max(0.6, er * 0.34)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: gx - er * 0.45, y: eyeY - er * 0.55, width: hr * 2, height: hr * 2)),
                    with: .color(Color.white.opacity(0.92))
                )
            }
        }

        // 小憩纯矢量漂浮呼吸弧（无字母气泡，仅以柔和月弧表达均匀吐息）
        if !isAwake && kin.sleepArcProgress > 0.01 {
            for arcIdx in 0..<2 {
                let localProg = (kin.sleepArcProgress + Double(arcIdx) * 0.45).truncatingRemainder(dividingBy: 1.0)
                let fade = sin(localProg * Double.pi)
                let bx = cx + s * (0.28 + CGFloat(arcIdx) * 0.06)
                let by = cy - s * (0.34 + CGFloat(localProg) * 0.14)
                let arcHalfW = s * (0.042 + CGFloat(arcIdx) * 0.015)
                var breathArc = Path()
                breathArc.move(to: CGPoint(x: bx - arcHalfW, y: by))
                breathArc.addQuadCurve(
                    to: CGPoint(x: bx + arcHalfW, y: by),
                    control: CGPoint(x: bx, y: by - s * 0.045)
                )
                let arcColor = isNight ? Color(hex: 0xEFE7DC) : accentColor
                ctx.stroke(
                    breathArc,
                    with: .color(arcColor.opacity(0.55 * fade)),
                    style: StrokeStyle(lineWidth: max(0.9, lw * 0.52), lineCap: .round)
                )
            }
        }

        // 稳重双蹄
        let hoofColor = isNight ? Color(hex: 0x261E38) : Color(hex: 0x452B23)
        for side in [-1.0, 1.0] {
            let hx = cx + CGFloat(side) * s * 0.145
            let hy = cy + s * 0.30
            ctx.fill(
                Path(ellipseIn: CGRect(x: hx - s * 0.065, y: hy - s * 0.035, width: s * 0.13, height: s * 0.07)),
                with: .color(hoofColor)
            )
        }
    }
}

/// 紧凑双子徽章（「咩」在左轻盈、「哞」在右稳重；纯静态 Canvas 排版，安全用于顶栏、空画布与明信片离线截图）。
public struct ChimmoDuoBadgeView: View {
    public let isNight: Bool
    public let accentColor: Color
    public var melodyActive: Bool = false
    public var cowAwake: Bool = true
    public var phaseTime: Double = 0.0
    public var gazeBias: Double = 0.0

    public init(
        isNight: Bool,
        accentColor: Color,
        melodyActive: Bool = false,
        cowAwake: Bool = true,
        phaseTime: Double = 0.0,
        gazeBias: Double = 0.0
    ) {
        self.isNight = isNight
        self.accentColor = accentColor
        self.melodyActive = melodyActive
        self.cowAwake = cowAwake
        self.phaseTime = phaseTime
        self.gazeBias = gazeBias
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let itemW = w * 0.54
            let itemH = h * 0.94

            ZStack(alignment: .bottom) {
                ChimmoCowView(
                    isNight: isNight,
                    accentColor: accentColor,
                    isAwake: cowAwake,
                    isPlaying: melodyActive && cowAwake,
                    phaseTime: phaseTime,
                    gazeBias: gazeBias
                )
                .frame(width: itemW, height: itemH)
                .offset(x: w * 0.20, y: 0)

                ChimmoSheepView(
                    isNight: isNight,
                    accentColor: accentColor,
                    isSinging: melodyActive,
                    phaseTime: phaseTime,
                    gazeBias: gazeBias
                )
                .frame(width: itemW, height: itemH)
                .offset(x: -w * 0.20, y: -h * 0.03)
            }
            .frame(width: w, height: h)
        }
        .accessibilityHidden(true)
    }
}
