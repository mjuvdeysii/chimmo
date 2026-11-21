import SwiftUI

/// 每次音珠发声时在画布与水面上激起的物理涟漪与飞珠轨迹。
public struct VisualImpulse: Identifiable, Sendable {
    public let id: UUID
    public let birth: TimeInterval
    public let degree: Int
    public let octaveOffset: Int
    public let xNorm: Double // 0...1 画布横向归一化位置

    public init(
        id: UUID = UUID(),
        birth: TimeInterval = Date().timeIntervalSinceReferenceDate,
        degree: Int,
        octaveOffset: Int = 0,
        xNorm: Double
    ) {
        self.id = id
        self.birth = birth
        self.degree = degree
        self.octaveOffset = octaveOffset
        self.xNorm = max(0.05, min(0.95, xNorm))
    }
}

/// 活体纸上声学手账 + 真实可托举物理水面（60fps TimelineView 驱动）：
/// - 上半部（天空/纸卷）：点按下方七只咩哞或直接用手指在空中滑动，陶珠从咩哞头顶跃入空中、漾开同心声波、拉出流畅旋律弧与震颤引力琴弦；
/// - 下半部（物理水面）：手指直接上下拖动水面即可「涨潮/退潮」控制和声丰满度，左右轻拂水面即可「换水色」切换现代和声情绪，每颗音珠都会在水面砸出波峰与水中倒影。
public struct GravityScrollCanvas: View {
    public let document: MelodyDocument
    public let palette: ChimmoPalette
    @Binding public var waterLevel: Double
    public let playheadTime: Double?
    public let impulses: [VisualImpulse]
    public let onSelectGhost: (UUID, GhostCandidate) -> Void
    public let onDragBeadDegree: (UUID, Int, Int) -> Void
    public let onTapBead: (NoteBead) -> Void
    public let onPaintSkyDegree: (Int, Int, Double) -> Void
    public let onSwipeWaterProfile: (Int) -> Void
    public let onTapBlankPaper: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var waterDragStartLevel: Double? = nil
    @State private var waterDragStartX: CGFloat? = nil
    @State private var didTriggerWaterSwipe: Bool = false
    @State private var lastPaintedDegree: Int? = nil

    public init(
        document: MelodyDocument,
        palette: ChimmoPalette,
        waterLevel: Binding<Double>,
        playheadTime: Double?,
        impulses: [VisualImpulse],
        onSelectGhost: @escaping (UUID, GhostCandidate) -> Void,
        onDragBeadDegree: @escaping (UUID, Int, Int) -> Void,
        onTapBead: @escaping (NoteBead) -> Void,
        onPaintSkyDegree: @escaping (Int, Int, Double) -> Void,
        onSwipeWaterProfile: @escaping (Int) -> Void,
        onTapBlankPaper: @escaping () -> Void
    ) {
        self.document = document
        self.palette = palette
        self._waterLevel = waterLevel
        self.playheadTime = playheadTime
        self.impulses = impulses
        self.onSelectGhost = onSelectGhost
        self.onDragBeadDegree = onDragBeadDegree
        self.onTapBead = onTapBead
        self.onPaintSkyDegree = onPaintSkyDegree
        self.onSwipeWaterProfile = onSwipeWaterProfile
        self.onTapBlankPaper = onTapBlankPaper
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let size = geo.size
                let totalSec = max(3.2, document.totalDuration)
                let padX: CGFloat = 24
                let usableW = max(120, size.width - padX * 2)
                let waterTopY = waterSurfaceY(height: size.height, level: waterLevel)

                ZStack {
                    // 1. 60fps 活体声学画卷 + 物理水面渲染层
                    Canvas { ctx, canvasSize in
                        drawAmbientAir(ctx: &ctx, size: canvasSize, now: now)
                        drawPaperGravityLines(ctx: &ctx, size: canvasSize)
                        drawInteractiveWater(
                            ctx: &ctx,
                            size: canvasSize,
                            waterTopY: waterTopY,
                            padX: padX,
                            usableW: usableW,
                            totalSec: totalSec,
                            now: now
                        )
                        drawMelodyArcsAndStrings(
                            ctx: &ctx,
                            size: canvasSize,
                            waterTopY: waterTopY,
                            padX: padX,
                            usableW: usableW,
                            totalSec: totalSec,
                            now: now
                        )
                        drawImpulsesAndFlyingPearls(
                            ctx: &ctx,
                            size: canvasSize,
                            waterTopY: waterTopY,
                            now: now
                        )
                        if let t = playheadTime {
                            let px = padX + CGFloat(min(1.0, max(0.0, t / totalSec))) * usableW
                            drawPlayheadBeam(ctx: &ctx, x: px, height: canvasSize.height)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleCanvasTouch(value: value, size: size, waterTopY: waterTopY)
                            }
                            .onEnded { value in
                                let dist = hypot(value.translation.width, value.translation.height)
                                if dist < 6 && value.startLocation.y < waterTopY - 18 {
                                    onTapBlankPaper()
                                }
                                waterDragStartLevel = nil
                                waterDragStartX = nil
                                didTriggerWaterSwipe = false
                                lastPaintedDegree = nil
                            }
                    )

                    // 2. 水面波峰上的直接操控把手（一眼看懂水面可上下拉、左右拂）
                    waterCrestHandle
                        .position(x: size.width * 0.5, y: min(size.height - 18, max(44, waterTopY + 16)))
                        .allowsHitTesting(false)

                    // 3. 交互陶珠与幽灵备选珠（控件即对象）
                    ForEach(document.notes) { bead in
                        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
                        let bx = padX + CGFloat(onset / totalSec) * usableW
                        let by = yPosition(degree: bead.degree, octave: bead.octaveOffset, height: size.height)

                        ForEach(bead.ghostCandidates) { ghost in
                            let gy = yPosition(degree: ghost.degree, octave: ghost.octaveOffset, height: size.height)
                            Button {
                                onSelectGhost(bead.id, ghost)
                            } label: {
                                Circle()
                                    .strokeBorder(
                                        ChimmoMember.from(degree: ghost.degree).bodyColor.opacity(0.9),
                                        style: StrokeStyle(lineWidth: 1.8, dash: [3, 2.5])
                                    )
                                    .background(Circle().fill(palette.paper.opacity(0.82)))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .position(x: bx + 17, y: gy)
                            .accessibilityLabel("修正为 \(ghost.degree)号 \(ChimmoMember.from(degree: ghost.degree).chineseName)")
                        }

                        beadInteractiveControl(bead: bead, canvasHeight: size.height, now: now)
                            .position(x: bx, y: by)
                    }
                }
            }
        }
    }

    // MARK: - Water Crest Pill Indicator

    private var waterCrestHandle: some View {
        let levelText: String = {
            if waterLevel < 0.08 { return "水面已退潮（上拉托起和声）" }
            if waterLevel < 0.35 { return "\(document.harmonyProfile.label) · 浅水低音托底" }
            if waterLevel < 0.72 { return "\(document.harmonyProfile.label) · 温柔琶音伴奏" }
            return "\(document.harmonyProfile.label) · 深水琶音+星光泛音"
        }()

        return HStack(spacing: 6) {
            Image(systemName: "water.waves")
                .font(.system(size: 11, weight: .semibold))
            Text(levelText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
            Text("· 上下拉水 / 左右换色")
                .font(.system(size: 10))
                .opacity(0.78)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(palette.paper.opacity(palette.isNight ? 0.62 : 0.76))
                .overlay(Capsule().strokeBorder(waterTint.opacity(0.45), lineWidth: 0.9))
        )
        .foregroundStyle(palette.primaryInk)
    }

    private var waterTint: Color {
        switch document.harmonyProfile {
        case .feltSun:
            return palette.isNight ? Color(hex: 0xE8BD6B) : Color(hex: 0xC88A32)
        case .clearWater:
            return palette.isNight ? Color(hex: 0x4FD8CB) : Color(hex: 0x16857B)
        case .filmGlow:
            return palette.isNight ? Color(hex: 0x9B82F3) : Color(hex: 0x6B5B95)
        }
    }

    // MARK: - Direct Manipulation Touch Handler (Water Drag / Sky Paint)

    private func handleCanvasTouch(value: DragGesture.Value, size: CGSize, waterTopY: CGFloat) {
        let startY = value.startLocation.y
        // 落在水面及水面向上 28pt 范围内 → 直接用手托举/压低水面，或左右拂水换和声色温！
        if startY >= waterTopY - 28 || waterDragStartLevel != nil {
            if waterDragStartLevel == nil {
                waterDragStartLevel = waterLevel
                waterDragStartX = value.startLocation.x
                didTriggerWaterSwipe = false
            }
            let baseLevel = waterDragStartLevel ?? waterLevel
            let deltaLevel = Double(-value.translation.height / max(120, size.height * 0.52))
            waterLevel = max(0.0, min(1.0, baseLevel + deltaLevel))

            if !didTriggerWaterSwipe,
               let sx = waterDragStartX,
               abs(value.location.x - sx) > 54,
               abs(value.translation.width) > abs(value.translation.height) * 1.3 {
                didTriggerWaterSwipe = true
                let dir = value.location.x > sx ? 1 : -1
                onSwipeWaterProfile(dir)
            }
            return
        }

        // 落在上方天空区域滑动 → 直接在纸面上抚摸/点画音珠！
        let (deg, oct) = degreeAndOctave(forY: value.location.y, height: size.height)
        if lastPaintedDegree != deg {
            lastPaintedDegree = deg
            let xNorm = Double(max(0.06, min(0.94, value.location.x / max(1, size.width))))
            onPaintSkyDegree(deg, oct, xNorm)
        }
    }

    // MARK: - Interactive Ceramic Bead Control

    private func beadInteractiveControl(bead: NoteBead, canvasHeight: CGFloat, now: TimeInterval) -> some View {
        let member = bead.member
        let isTense = member.isTensionDegree
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        let dur = bead.displayDuration(grooveStrength: document.grooveStrength)

        let isActivePlay = playheadTime.map { t in
            t >= onset - 0.04 && t <= onset + max(0.18, dur)
        } ?? false

        let isFutureNote = playheadTime.map { t in
            t < onset - 0.04
        } ?? false

        let fillColor: Color = (palette.isNight && member == .corllo)
            ? Color(hex: 0xEFE7D8)
            : (palette.isNight && member == .tinki ? palette.tensionFilament : member.bodyColor)

        let pulse: CGFloat = (!reduceMotion && isActivePlay)
            ? 1.18 + CGFloat(sin(now * 14.0)) * 0.07
            : 1.0

        return ZStack {
            // 唱到该音珠时的温暖呼吸光晕
            if isActivePlay {
                Circle()
                    .fill(fillColor.opacity(palette.isNight ? 0.38 : 0.26))
                    .frame(width: 34, height: 34)
            }

            if isTense {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fillColor.opacity(isFutureNote ? 0.45 : 1.0))
                    .frame(width: 15, height: 15)
                    .rotationEffect(.degrees(45))
            } else {
                Circle()
                    .fill(fillColor.opacity(isFutureNote ? 0.45 : 1.0))
                    .frame(width: 17, height: 17)
                    .overlay {
                        if member == .corllo && !palette.isNight {
                            Circle().stroke(member.accentColor, lineWidth: 1.6)
                        } else {
                            // 釉面微高光点
                            Circle()
                                .fill(Color.white.opacity(isFutureNote ? 0.25 : 0.65))
                                .frame(width: 4.5, height: 4.5)
                                .offset(x: -3, y: -3)
                        }
                    }
            }
        }
        .scaleEffect(pulse)
        .frame(width: 36, height: 36)
        .contentShape(Circle())
        .onTapGesture {
            onTapBead(bead)
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    let (newDeg, newOct) = degreeAndOctave(forY: value.location.y, height: canvasHeight)
                    if newDeg != bead.degree || newOct != bead.octaveOffset {
                        onDragBeadDegree(bead.id, newDeg, newOct)
                    }
                }
        )
        .accessibilityElement()
        .accessibilityLabel("\(bead.degree)号 \(member.chineseName)，\(member.roleLabel)")
        .accessibilityValue(isTense ? "悬停张力音" : "稳定音")
        .accessibilityHint("轻点试听，上下拖动可调整音高")
    }

    // MARK: - 1. Ambient Daylight / Night-Lamp Air

    private func drawAmbientAir(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        if palette.isNight {
            // 夜灯舞台底部的呼吸暖琥珀光晕 + 缓缓升起的金色萤火微粒
            let breath = reduceMotion ? 0.5 : (0.5 + 0.5 * sin(now * 0.7))
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.85)
            let glowGrad = Gradient(colors: [
                palette.nightLampGold.opacity(0.11 + breath * 0.05),
                .clear
            ])
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(glowGrad, center: center, startRadius: 10, endRadius: size.width * 0.75)
            )

            guard !reduceMotion else { return }
            for i in 0..<14 {
                let seed = Double(i) * 19.37
                let speed = 11.0 + Double(i % 5) * 3.5
                let y = size.height - ((now * speed + seed * 17.0).truncatingRemainder(dividingBy: Double(size.height)))
                let x = (CGFloat((i * 73) % 100) / 100.0) * size.width + CGFloat(sin(now * 0.9 + seed)) * 14.0
                let alpha = sin((y / Double(size.height)) * .pi) * 0.38
                let r: CGFloat = (i % 3 == 0) ? 2.6 : 1.8
                let rect = CGRect(x: x - r, y: CGFloat(y) - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(palette.nightLampGold.opacity(max(0, alpha))))
            }
        } else {
            // 日光纸面右上方的柔和阳光光晕 + 随微风缓慢飘过的花粉微粒
            let sunCenter = CGPoint(x: size.width * 0.82, y: 18)
            let sunGrad = Gradient(colors: [
                Color(hex: 0xFFF9E8).opacity(0.75),
                .clear
            ])
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(sunGrad, center: sunCenter, startRadius: 8, endRadius: size.width * 0.7)
            )

            guard !reduceMotion else { return }
            for i in 0..<10 {
                let seed = Double(i) * 23.1
                let speed = 14.0 + Double(i % 4) * 4.0
                let x = ((now * speed + seed * 29.0).truncatingRemainder(dividingBy: Double(size.width + 40))) - 20.0
                let y = Double(size.height) * (0.12 + Double((i * 37) % 70) / 100.0) + sin(now * 0.8 + seed) * 10.0
                let r: CGFloat = (i % 2 == 0) ? 2.4 : 1.7
                let rect = CGRect(x: CGFloat(x) - r, y: CGFloat(y) - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(palette.harmonyWash.opacity(0.16)))
            }
        }
    }

    // MARK: - 2. Paper Gravity Lines

    private func drawPaperGravityLines(ctx: inout GraphicsContext, size: CGSize) {
        for deg in 1...7 {
            let y = yPosition(degree: deg, octave: 0, height: size.height)
            var p = Path()
            p.move(to: CGPoint(x: 16, y: y))
            p.addLine(to: CGPoint(x: size.width - 16, y: y))
            if deg == 1 {
                ctx.stroke(p, with: .color(palette.homeAnchor.opacity(palette.isNight ? 0.48 : 0.36)), lineWidth: 1.8)
            } else if deg == 5 {
                ctx.stroke(p, with: .color(palette.harmonyWash.opacity(0.24)), lineWidth: 1.1)
            } else {
                ctx.stroke(p, with: .color(palette.divider), lineWidth: 0.75)
            }
        }
    }

    // MARK: - 3. Real Interactive Harmonic Water Body (60fps Wave Physics + Reflections)

    private func drawInteractiveWater(
        ctx: inout GraphicsContext,
        size: CGSize,
        waterTopY: CGFloat,
        padX: CGFloat,
        usableW: CGFloat,
        totalSec: Double,
        now: TimeInterval
    ) {
        let tint = waterTint
        let steps = 56
        var waterPath = Path()
        var crestPath = Path()

        for i in 0...steps {
            let frac = Double(i) / Double(steps)
            let x = CGFloat(frac) * size.width

            // 基础呼吸波浪 + 每个发声音珠砸在水面上的真实扩散水波
            var dy: Double = 0
            if !reduceMotion {
                dy += sin(frac * 7.5 + now * 2.1) * (1.8 + waterLevel * 2.4)
                dy += cos(frac * 13.0 - now * 1.6) * (1.0 + waterLevel * 1.5)

                for imp in impulses {
                    let age = now - imp.birth
                    guard age >= 0 && age < 1.8 else { continue }
                    let dist = abs(frac - imp.xNorm)
                    let waveFront = age * 0.48
                    let spread = abs(dist - waveFront)
                    if spread < 0.16 {
                        let env = exp(-age * 2.1) * cos((spread / 0.16) * .pi * 0.5)
                        dy += sin((dist - waveFront) * 52.0) * 8.5 * env
                    }
                }
            }

            let y = waterTopY + CGFloat(dy)
            if i == 0 {
                waterPath.move(to: CGPoint(x: 0, y: size.height))
                waterPath.addLine(to: CGPoint(x: 0, y: y))
                crestPath.move(to: CGPoint(x: 0, y: y))
            } else {
                waterPath.addLine(to: CGPoint(x: x, y: y))
                crestPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        waterPath.addLine(to: CGPoint(x: size.width, y: size.height))
        waterPath.closeSubpath()

        // 水体渐变填充
        let topAlpha = (palette.isNight ? 0.28 : 0.20) * (0.25 + 0.75 * waterLevel)
        let bottomAlpha = (palette.isNight ? 0.46 : 0.34) * (0.25 + 0.75 * waterLevel)
        let waterGrad = Gradient(colors: [
            tint.opacity(topAlpha),
            tint.opacity(bottomAlpha)
        ])
        ctx.fill(
            waterPath,
            with: .linearGradient(
                waterGrad,
                startPoint: CGPoint(x: size.width * 0.5, y: waterTopY),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height)
            )
        )

        // 水下和声倒影光柱（当水位托起时，每颗音珠在水下映出柔和的根音/和声水影）
        if waterLevel >= 0.08 {
            for bead in document.notes {
                let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
                let dur = bead.displayDuration(grooveStrength: document.grooveStrength)
                let bx = padX + CGFloat(onset / totalSec) * usableW
                let bw = max(18, CGFloat(dur / totalSec) * usableW)

                let isCurrent = playheadTime.map { $0 >= onset - 0.05 && $0 <= onset + dur + 0.1 } ?? false
                let pillarColor = bead.member.isTensionDegree ? palette.tensionFilament : tint
                let alpha = (isCurrent ? 0.38 : 0.14) * waterLevel

                let pillarRect = CGRect(
                    x: bx - 4,
                    y: waterTopY + 4,
                    width: min(36, bw),
                    height: max(12, size.height - waterTopY - 8)
                )
                let pillarGrad = Gradient(colors: [pillarColor.opacity(alpha), .clear])
                ctx.fill(
                    Path(roundedRect: pillarRect, cornerRadius: 8),
                    with: .linearGradient(
                        pillarGrad,
                        startPoint: CGPoint(x: bx, y: waterTopY + 4),
                        endPoint: CGPoint(x: bx, y: size.height)
                    )
                )
            }
        }

        // 水面波峰流光丝线
        ctx.stroke(
            crestPath,
            with: .color(tint.opacity(palette.isNight ? 0.78 : 0.62)),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
        )
    }

    // MARK: - 4. Flowing Calligraphic Melody Arcs & Vibrating Harp Strings

    private func drawMelodyArcsAndStrings(
        ctx: inout GraphicsContext,
        size: CGSize,
        waterTopY: CGFloat,
        padX: CGFloat,
        usableW: CGFloat,
        totalSec: Double,
        now: TimeInterval
    ) {
        let notes = document.notes
        guard !notes.isEmpty else { return }

        let homeY = yPosition(degree: 1, octave: 0, height: size.height)

        // 1. 优美抛物线旋律连弧（大跳拱起高弧，级进如溪流平缓）
        if notes.count > 1 {
            for i in 0..<(notes.count - 1) {
                let a = notes[i]
                let b = notes[i + 1]
                let ax = padX + CGFloat(a.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                let ay = yPosition(degree: a.degree, octave: a.octaveOffset, height: size.height)
                let bx = padX + CGFloat(b.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                let by = yPosition(degree: b.degree, octave: b.octaveOffset, height: size.height)

                let stepJump = abs((b.degree + b.octaveOffset * 7) - (a.degree + a.octaveOffset * 7))
                let archLift = CGFloat(min(38, stepJump * 6))
                let midX = (ax + bx) * 0.5
                let midY = min(ay, by) - archLift

                var arc = Path()
                arc.move(to: CGPoint(x: ax, y: ay))
                arc.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: midX, y: midY))

                let isPlayed = playheadTime.map { $0 >= a.displayOnset(grooveStrength: document.grooveStrength) } ?? true
                let strokeAlpha = isPlayed ? (palette.isNight ? 0.55 : 0.42) : 0.16
                ctx.stroke(
                    arc,
                    with: .color(a.member.bodyColor.opacity(strokeAlpha)),
                    style: StrokeStyle(lineWidth: isPlayed ? 2.2 : 1.3, lineCap: .round)
                )
            }
        }

        // 2. 呼吸余影 + 竖琴引力弦（连接音珠与水面/主音地平线）
        for (idx, bead) in notes.enumerated() {
            let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
            let dur = bead.displayDuration(grooveStrength: document.grooveStrength)
            let x = padX + CGFloat(onset / totalSec) * usableW
            let y = yPosition(degree: bead.degree, octave: bead.octaveOffset, height: size.height)
            let tailW = max(16, CGFloat(dur / totalSec) * usableW)

            let isCurrent = playheadTime.map { $0 >= onset - 0.04 && $0 <= onset + max(0.2, dur) } ?? false
            let member = bead.member
            let trailColor = (palette.isNight && member == .tinki) ? palette.tensionFilament : member.bodyColor

            // 呼吸余影长尾
            var tail = Path()
            tail.move(to: CGPoint(x: x, y: y))
            tail.addLine(to: CGPoint(x: min(size.width - 14, x + tailW), y: y))
            let tailGrad = Gradient(colors: [trailColor.opacity(isCurrent ? 0.65 : 0.36), .clear])
            ctx.stroke(
                tail,
                with: .linearGradient(tailGrad, startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + tailW, y: y)),
                style: StrokeStyle(lineWidth: isCurrent ? 10 : 7, lineCap: .round)
            )

            // 当水位托起时，正在发声的音珠向水面投下柔和的竖琴共鸣弦
            if waterLevel >= 0.12 && (isCurrent || member.isTensionDegree) {
                let vib: CGFloat = (!reduceMotion && isCurrent)
                    ? CGFloat(sin(now * 34.0 + Double(idx))) * 7.5
                    : 4.0
                let targetY = member.isTensionDegree ? homeY : max(y + 12, waterTopY)
                var harp = Path()
                harp.move(to: CGPoint(x: x, y: y))
                harp.addQuadCurve(
                    to: CGPoint(x: x, y: targetY),
                    control: CGPoint(x: x + vib, y: (y + targetY) * 0.5)
                )
                let stringColor = member.isTensionDegree ? palette.tensionFilament : waterTint
                ctx.stroke(
                    harp,
                    with: .color(stringColor.opacity(isCurrent ? 0.85 : 0.48)),
                    style: StrokeStyle(
                        lineWidth: isCurrent ? 1.9 : 1.3,
                        dash: member.isTensionDegree ? [4, 3] : []
                    )
                )
            }
        }
    }

    // MARK: - 5. Blooming Sound Ripples & Rising Pearls from the 7 Chimmos

    private func drawImpulsesAndFlyingPearls(
        ctx: inout GraphicsContext,
        size: CGSize,
        waterTopY: CGFloat,
        now: TimeInterval
    ) {
        for imp in impulses {
            let age = now - imp.birth
            guard age >= 0 && age < 1.35 else { continue }

            let member = ChimmoMember.from(degree: imp.degree)
            let color = (palette.isNight && member == .corllo)
                ? Color(hex: 0xEFE7D8)
                : (palette.isNight ? member.nightGlowColor : member.bodyColor)

            let targetX = CGFloat(imp.xNorm) * size.width
            let targetY = yPosition(degree: imp.degree, octave: imp.octaveOffset, height: size.height)

            // 前 0.26 秒：一颗发光音珠从下方对应咩哞头顶跃入空中画布！
            if !reduceMotion && age < 0.26 {
                let p = age / 0.26
                let eased = 1.0 - pow(1.0 - p, 3.0)
                let startX = (CGFloat(imp.degree) - 0.5) / 7.0 * size.width
                let startY = size.height - 4.0
                let curX = startX + (targetX - startX) * CGFloat(eased)
                let curY = startY + (targetY - startY) * CGFloat(eased)

                var comet = Path()
                comet.move(to: CGPoint(x: startX, y: startY))
                comet.addQuadCurve(
                    to: CGPoint(x: curX, y: curY),
                    control: CGPoint(x: (startX + curX) * 0.5, y: min(startY, curY) - 18)
                )
                ctx.stroke(comet, with: .color(color.opacity(0.48 * (1.0 - p))), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                let r: CGFloat = 6.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: curX - r, y: curY - r, width: r * 2, height: r * 2)),
                    with: .color(color)
                )
            }

            // 绽放双层同心声波涟漪（像雨滴落在静水/宣纸上）
            for ring in 0..<2 {
                let ringAge = age - Double(ring) * 0.12
                guard ringAge > 0 else { continue }
                let progress = min(1.0, ringAge / 1.15)
                let radius = 8.0 + CGFloat(progress) * (imp.degree == 1 ? 54.0 : 38.0)
                let alpha = pow(1.0 - progress, 1.8) * 0.62
                let rect = CGRect(x: targetX - radius, y: targetY - radius, width: radius * 2, height: radius * 2)
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(color.opacity(alpha)),
                    style: StrokeStyle(lineWidth: ring == 0 ? 1.8 : 1.1)
                )
            }
        }
    }

    private func drawPlayheadBeam(ctx: inout GraphicsContext, x: CGFloat, height: CGFloat) {
        var line = Path()
        line.move(to: CGPoint(x: x, y: 10))
        line.addLine(to: CGPoint(x: x, y: height - 10))
        ctx.stroke(
            line,
            with: .color(palette.melodyTerracotta.opacity(0.55)),
            style: StrokeStyle(lineWidth: 1.6, dash: [4, 4])
        )
    }

    // MARK: - Coordinate Helpers

    private func waterSurfaceY(height: CGFloat, level: Double) -> CGFloat {
        let clamped = CGFloat(max(0.0, min(1.0, level)))
        let minY = height - 28 // 退潮底线
        let maxY = height * 0.42 // 涨潮高水位
        return minY - clamped * (minY - maxY)
    }

    private func yPosition(degree: Int, octave: Int, height: CGFloat) -> CGFloat {
        let topPad: CGFloat = 24
        let bottomPad: CGFloat = 46
        let usableH = max(60, height - topPad - bottomPad)
        let linearStep = CGFloat(degree - 1 + octave * 7)
        let normalized = max(0, min(1, (linearStep + 2.0) / 11.0))
        return height - bottomPad - normalized * usableH
    }

    private func degreeAndOctave(forY y: CGFloat, height: CGFloat) -> (Int, Int) {
        let topPad: CGFloat = 24
        let bottomPad: CGFloat = 46
        let usableH = max(60, height - topPad - bottomPad)
        let normalized = max(0, min(1, (height - bottomPad - y) / usableH))
        let rawStep = Int((normalized * 11.0 - 2.0).rounded())
        let clamped = max(-2, min(9, rawStep))
        let oct = Int(floor(Double(clamped) / 7.0))
        let deg = clamped - oct * 7 + 1
        return (max(1, min(7, deg)), max(-1, min(1, oct)))
    }
}
