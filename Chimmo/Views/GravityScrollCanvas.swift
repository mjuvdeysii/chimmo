import SwiftUI

/// 纸上声学手账画布（方向 A）：
/// 7 阶纸面盲压引力线 + 水面和声水晕 + 陶珠呼吸余影 + 赤陶张力虚线（色盲双编码）+ 幽灵备选珠一指吸附与上下微拖修音。
public struct GravityScrollCanvas: View {
    public let document: MelodyDocument
    public let palette: ChimmoPalette
    public let cradleEnabled: Bool
    public let playheadTime: Double?
    public let onSelectGhost: (UUID, GhostCandidate) -> Void
    public let onDragBeadDegree: (UUID, Int, Int) -> Void
    public let onTapBead: (NoteBead) -> Void
    public let onTapBlankPaper: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggingBeadID: UUID?

    public init(
        document: MelodyDocument,
        palette: ChimmoPalette,
        cradleEnabled: Bool,
        playheadTime: Double?,
        onSelectGhost: @escaping (UUID, GhostCandidate) -> Void,
        onDragBeadDegree: @escaping (UUID, Int, Int) -> Void,
        onTapBead: @escaping (NoteBead) -> Void,
        onTapBlankPaper: @escaping () -> Void
    ) {
        self.document = document
        self.palette = palette
        self.cradleEnabled = cradleEnabled
        self.playheadTime = playheadTime
        self.onSelectGhost = onSelectGhost
        self.onDragBeadDegree = onDragBeadDegree
        self.onTapBead = onTapBead
        self.onTapBlankPaper = onTapBlankPaper
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let totalSec = max(3.5, document.totalDuration)
            let padX: CGFloat = 22
            let usableW = max(120, size.width - padX * 2)

            ZStack {
                // 纸面与非交互层（零 glassEffect，纯 120Hz Canvas 绘制）
                Canvas { ctx, canvasSize in
                    drawPaperGrid(ctx: &ctx, size: canvasSize)
                    if cradleEnabled {
                        drawHarmonyWashes(ctx: &ctx, size: canvasSize, padX: padX, usableW: usableW, totalSec: totalSec)
                    }
                    drawMelodyContourAndTrails(ctx: &ctx, size: canvasSize, padX: padX, usableW: usableW, totalSec: totalSec)
                    if let t = playheadTime {
                        let px = padX + CGFloat(min(1.0, max(0.0, t / totalSec))) * usableW
                        var line = Path()
                        line.move(to: CGPoint(x: px, y: 12))
                        line.addLine(to: CGPoint(x: px, y: canvasSize.height - 12))
                        ctx.stroke(
                            line,
                            with: .color(palette.melodyTerracotta.opacity(0.65)),
                            style: StrokeStyle(lineWidth: 1.8, dash: [4, 4])
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapBlankPaper()
                }

                // 交互音珠与幽灵备选珠热区（控件即对象）
                ForEach(document.notes) { bead in
                    let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
                    let bx = padX + CGFloat(onset / totalSec) * usableW
                    let by = yPosition(degree: bead.degree, octave: bead.octaveOffset, height: size.height)

                    // 幽灵备选珠（一指点击直接修正哼唱跑偏）
                    ForEach(bead.ghostCandidates) { ghost in
                        let gy = yPosition(degree: ghost.degree, octave: ghost.octaveOffset, height: size.height)
                        Button {
                            onSelectGhost(bead.id, ghost)
                        } label: {
                            Circle()
                                .strokeBorder(
                                    ChimmoMember.from(degree: ghost.degree).bodyColor.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 1.8, dash: [3, 2.5])
                                )
                                .background(Circle().fill(palette.paper.opacity(0.75)))
                                .frame(width: 17, height: 17)
                        }
                        .buttonStyle(.plain)
                        .position(x: bx + 16, y: gy)
                        .accessibilityLabel("修正为 \(ghost.degree)号 \(ChimmoMember.from(degree: ghost.degree).chineseName)")
                    }

                    // 可直接点击试听或上下拖拽改音级的实心陶珠
                    beadInteractiveControl(bead: bead, canvasHeight: size.height)
                        .position(x: bx, y: by)
                }
            }
        }
    }

    // MARK: - Interactive Bead Control

    private func beadInteractiveControl(bead: NoteBead, canvasHeight: CGFloat) -> some View {
        let member = bead.member
        let isTense = member.isTensionDegree
        let isActivePlay = playheadTime.map { t in
            let s = bead.displayOnset(grooveStrength: document.grooveStrength)
            let e = s + bead.displayDuration(grooveStrength: document.grooveStrength)
            return t >= s && t <= e
        } ?? false

        let fillColor: Color = (palette.isNight && member == .corllo)
            ? Color(hex: 0xEFE7D8)
            : (palette.isNight && member == .tinki ? palette.tensionFilament : member.bodyColor)

        return ZStack {
            if isTense {
                // 菱形棱晶 = 张力音（色盲双重几何编码）
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: isActivePlay ? 18 : 14, height: isActivePlay ? 18 : 14)
                    .rotationEffect(.degrees(45))
            } else {
                Circle()
                    .fill(fillColor)
                    .frame(width: isActivePlay ? 20 : 16, height: isActivePlay ? 20 : 16)
                    .overlay {
                        if member == .corllo && !palette.isNight {
                            Circle().stroke(member.accentColor, lineWidth: 1.6)
                        }
                    }
            }
        }
        .frame(width: 34, height: 34)
        .contentShape(Circle())
        .onTapGesture {
            onTapBead(bead)
        }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    draggingBeadID = bead.id
                    let (newDeg, newOct) = degreeAndOctave(forY: value.location.y, height: canvasHeight)
                    if newDeg != bead.degree || newOct != bead.octaveOffset {
                        onDragBeadDegree(bead.id, newDeg, newOct)
                    }
                }
                .onEnded { _ in
                    draggingBeadID = nil
                }
        )
        .accessibilityElement()
        .accessibilityLabel("\(bead.degree)号 \(member.chineseName)，\(member.roleLabel)")
        .accessibilityValue(isTense ? "悬停张力音" : "稳定音")
        .accessibilityHint("轻点试听，上下拖动可调整音高")
    }

    // MARK: - Canvas Drawing Passes

    private func drawPaperGrid(ctx: inout GraphicsContext, size: CGSize) {
        for deg in 1...7 {
            let y = yPosition(degree: deg, octave: 0, height: size.height)
            var p = Path()
            p.move(to: CGPoint(x: 12, y: y))
            p.addLine(to: CGPoint(x: size.width - 12, y: y))
            if deg == 1 {
                ctx.stroke(p, with: .color(palette.homeAnchor.opacity(palette.isNight ? 0.45 : 0.36)), lineWidth: 1.8)
            } else if deg == 5 {
                ctx.stroke(p, with: .color(palette.harmonyWash.opacity(0.24)), lineWidth: 1.1)
            } else {
                ctx.stroke(p, with: .color(palette.divider), lineWidth: 0.8)
            }
        }
    }

    private func drawHarmonyWashes(
        ctx: inout GraphicsContext,
        size: CGSize,
        padX: CGFloat,
        usableW: CGFloat,
        totalSec: Double
    ) {
        for bead in document.notes {
            let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
            let dur = bead.displayDuration(grooveStrength: document.grooveStrength)
            let x = padX + CGFloat(onset / totalSec) * usableW
            let w = max(24, CGFloat(dur / totalSec) * usableW)
            let voicing = document.harmonyProfile.voicing(for: bead.degree)

            let washColor: Color
            if voicing.isHighTension {
                washColor = palette.tensionFilament
            } else if bead.degree == 6 || bead.degree == 2 {
                washColor = palette.bassRibbon
            } else {
                washColor = palette.harmonyWash
            }

            let washRect = CGRect(x: x, y: size.height - 76, width: w + 10, height: 76)
            let grad = Gradient(colors: [.clear, washColor.opacity(palette.isNight ? 0.28 : 0.20)])
            ctx.fill(
                Path(roundedRect: washRect, cornerRadius: 12),
                with: .linearGradient(grad, startPoint: CGPoint(x: x, y: size.height - 76), endPoint: CGPoint(x: x, y: size.height))
            )
        }
    }

    private func drawMelodyContourAndTrails(
        ctx: inout GraphicsContext,
        size: CGSize,
        padX: CGFloat,
        usableW: CGFloat,
        totalSec: Double
    ) {
        guard !document.notes.isEmpty else { return }

        // 连贯旋律轮廓丝线
        var contour = Path()
        for (idx, bead) in document.notes.enumerated() {
            let x = padX + CGFloat(bead.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
            let y = yPosition(degree: bead.degree, octave: bead.octaveOffset, height: size.height)
            if idx == 0 {
                contour.move(to: CGPoint(x: x, y: y))
            } else {
                contour.addLine(to: CGPoint(x: x, y: y))
            }
        }
        ctx.stroke(contour, with: .color(palette.primaryInk.opacity(0.16)), lineWidth: 1.4)

        // 呼吸余影（Afterimage）与 L2 张力弦丝
        for bead in document.notes {
            let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
            let dur = bead.displayDuration(grooveStrength: document.grooveStrength)
            let x = padX + CGFloat(onset / totalSec) * usableW
            let y = yPosition(degree: bead.degree, octave: bead.octaveOffset, height: size.height)
            let tailW = max(14, CGFloat(dur / totalSec) * usableW)

            let member = bead.member
            let trailColor = (palette.isNight && member == .tinki) ? palette.tensionFilament : member.bodyColor
            var tail = Path()
            tail.move(to: CGPoint(x: x, y: y))
            tail.addLine(to: CGPoint(x: min(size.width - 12, x + tailW), y: y))
            let tailGrad = Gradient(colors: [trailColor.opacity(0.42), .clear])
            ctx.stroke(
                tail,
                with: .linearGradient(tailGrad, startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + tailW, y: y)),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )

            // 4 号与 7 号张力虚线指向解决目标
            if member.isTensionDegree {
                let targetOct = member == .tinki ? min(1, bead.octaveOffset + 1) : bead.octaveOffset
                let targetY = yPosition(degree: member.resolutionTargetDegree, octave: targetOct, height: size.height)
                var tensionPath = Path()
                tensionPath.move(to: CGPoint(x: x, y: y))
                tensionPath.addQuadCurve(
                    to: CGPoint(x: x + 10, y: targetY),
                    control: CGPoint(x: x + (reduceMotion ? 5 : 14), y: (y + targetY) * 0.5)
                )
                ctx.stroke(
                    tensionPath,
                    with: .color(palette.tensionFilament.opacity(0.82)),
                    style: StrokeStyle(lineWidth: 1.6, dash: [4, 3])
                )
            }
        }
    }

    // MARK: - Coordinate Mapping

    private func yPosition(degree: Int, octave: Int, height: CGFloat) -> CGFloat {
        let topPad: CGFloat = 24
        let bottomPad: CGFloat = 30
        let usableH = max(60, height - topPad - bottomPad)
        let linearStep = CGFloat(degree - 1 + octave * 7)
        let normalized = max(0, min(1, (linearStep + 2.0) / 11.0))
        return height - bottomPad - normalized * usableH
    }

    private func degreeAndOctave(forY y: CGFloat, height: CGFloat) -> (Int, Int) {
        let topPad: CGFloat = 24
        let bottomPad: CGFloat = 30
        let usableH = max(60, height - topPad - bottomPad)
        let normalized = max(0, min(1, (height - bottomPad - y) / usableH))
        let rawStep = Int((normalized * 11.0 - 2.0).rounded())
        let clamped = max(-2, min(9, rawStep))
        let oct = Int(floor(Double(clamped) / 7.0))
        let deg = clamped - oct * 7 + 1
        return (max(1, min(7, deg)), max(-1, min(1, oct)))
    }
}
