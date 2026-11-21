import SwiftUI

/// 咩哞 2.0 核心舞台：左侧「真实全音/半音间距」七小只竖排阶梯 + 右侧「和弦泳道光带」声学卷轴。
/// 让零基础用户肉眼看见：
/// 1. 为什么 3-4 和 7-1↑ 挨得特别近（真实半音间距），切换大/小调时 3/6/7 号真实滑下半音；
/// 2. 什么是和弦（底部每个和弦会把对应的 3 条音高泳道照亮成水彩光带，音珠踩进光带 = 和谐，跨出光带 = 色彩/张力）；
/// 3. 脑海里哼出或点出的旋律轮廓清清楚楚，每颗珠子都能上下拖拽修音、点击试听、或轻点底部和弦卡片实时换伴奏。
public struct HarmonicLadderCanvas: View {
    public let document: MelodyDocument
    public let chordSpans: [ChordSpan]
    public let palette: ChimmoPalette
    public let showTheoryLens: Bool
    public let playheadTime: Double?
    public let activeDegrees: Set<Int>
    public let latestDegree: Int?
    public let impulses: [VisualImpulse]

    public let onTriggerLadderMember: (ChimmoMember, Int) -> Void
    public let onTapCanvasPitch: (Int, Int, Double) -> Void
    public let onSelectGhost: (UUID, GhostCandidate) -> Void
    public let onDragBeadPitch: (UUID, Int, Int) -> Void
    public let onTapBead: (NoteBead) -> Void
    public let onCycleSpanChord: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastLadderStepKey: String? = nil

    private let ladderWidth: CGFloat = 68
    private let chordStripHeight: CGFloat = 44

    public init(
        document: MelodyDocument,
        chordSpans: [ChordSpan],
        palette: ChimmoPalette,
        showTheoryLens: Bool,
        playheadTime: Double?,
        activeDegrees: Set<Int>,
        latestDegree: Int?,
        impulses: [VisualImpulse],
        onTriggerLadderMember: @escaping (ChimmoMember, Int) -> Void,
        onTapCanvasPitch: @escaping (Int, Int, Double) -> Void,
        onSelectGhost: @escaping (UUID, GhostCandidate) -> Void,
        onDragBeadPitch: @escaping (UUID, Int, Int) -> Void,
        onTapBead: @escaping (NoteBead) -> Void,
        onCycleSpanChord: @escaping (Int) -> Void
    ) {
        self.document = document
        self.chordSpans = chordSpans
        self.palette = palette
        self.showTheoryLens = showTheoryLens
        self.playheadTime = playheadTime
        self.activeDegrees = activeDegrees
        self.latestDegree = latestDegree
        self.impulses = impulses
        self.onTriggerLadderMember = onTriggerLadderMember
        self.onTapCanvasPitch = onTapCanvasPitch
        self.onSelectGhost = onSelectGhost
        self.onDragBeadPitch = onDragBeadPitch
        self.onTapBead = onTapBead
        self.onCycleSpanChord = onCycleSpanChord
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let stageH = max(180, geo.size.height - chordStripHeight)
                let scrollW = max(140, geo.size.width - ladderWidth)
                let totalSec = max(3.2, document.totalDuration)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // 1. 左侧：真实全音/半音不等距的七小只竖排阶梯
                        leftPitchLadder(stageHeight: stageH, now: now)
                            .frame(width: ladderWidth, height: stageH)

                        // 2. 右侧：60fps 和弦泳道光带 + 旋律轮廓交互卷轴
                        rightHarmonicScroll(width: scrollW, height: stageH, totalSec: totalSec, now: now)
                            .frame(width: scrollW, height: stageH)
                    }

                    // 3. 底部：可一键点击切换的 4 格「和弦光带切换条」
                    bottomChordRibbon(scrollWidth: scrollW)
                        .frame(height: chordStripHeight)
                }
            }
        }
    }

    // MARK: - 1. Left True-Semitone Pitch Ladder (1 Do -> 1↑ High Do)

    private struct LadderStep: Identifiable {
        let id: String
        let degree: Int
        let octave: Int
        let badge: String
    }

    private var ladderSteps: [LadderStep] {
        [
            LadderStep(id: "1-0", degree: 1, octave: 0, badge: "1"),
            LadderStep(id: "2-0", degree: 2, octave: 0, badge: "2"),
            LadderStep(id: "3-0", degree: 3, octave: 0, badge: "3"),
            LadderStep(id: "4-0", degree: 4, octave: 0, badge: "4"),
            LadderStep(id: "5-0", degree: 5, octave: 0, badge: "5"),
            LadderStep(id: "6-0", degree: 6, octave: 0, badge: "6"),
            LadderStep(id: "7-0", degree: 7, octave: 0, badge: "7"),
            LadderStep(id: "1-1", degree: 1, octave: 1, badge: "1↑")
        ]
    }

    private func leftPitchLadder(stageHeight: CGFloat, now: TimeInterval) -> some View {
        let isMinor = document.scaleMode == .wistfulMinor

        return ZStack {
            // 阶梯柔和底色
            palette.shelfSurface.opacity(palette.isNight ? 0.85 : 0.72)

            // 半音紧邻括号提示（大调：3-4 与 7-1↑；小调：2-3 与 5-6）
            if showTheoryLens {
                let halfPairs: [(Int, Int, Int, Int)] = isMinor
                    ? [(2, 0, 3, 0), (5, 0, 6, 0)]
                    : [(3, 0, 4, 0), (7, 0, 1, 1)]

                ForEach(0..<halfPairs.count, id: \.self) { idx in
                    let p = halfPairs[idx]
                    let yLow = pitchY(degree: p.0, octave: p.1, height: stageHeight)
                    let yHigh = pitchY(degree: p.2, octave: p.3, height: stageHeight)
                    let midY = (yLow + yHigh) * 0.5
                    let gap = max(8, abs(yLow - yHigh))

                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(palette.tensionFilament.opacity(0.85))
                            .frame(width: 2.5, height: max(10, gap - 2))
                        Text("半")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(palette.tensionFilament)
                    }
                    .position(x: ladderWidth - 9, y: midY)
                    .allowsHitTesting(false)
                }
            }

            // 8 个阶梯小偶（1~7 + 高音 1↑），严格按真实半音坐标站立，切换大小调时真实丝滑移动！
            ForEach(ladderSteps) { step in
                let member = ChimmoMember.from(degree: step.degree)
                let y = pitchY(degree: step.degree, octave: step.octave, height: stageHeight)
                let isSinging = activeDegrees.contains(step.degree)
                let color = (palette.isNight && member == .corllo)
                    ? Color(hex: 0xEFE7D8)
                    : (palette.isNight ? member.nightGlowColor : member.bodyColor)

                HStack(spacing: 4) {
                    // 迷你窑陶小偶头像（带呼吸与笑眼）
                    ZStack {
                        Circle()
                            .fill(color.opacity(isSinging ? 1.0 : 0.88))
                            .frame(width: isSinging ? 22 : 18, height: isSinging ? 22 : 18)
                            .overlay {
                                if member == .corllo && !palette.isNight {
                                    Circle().strokeBorder(member.accentColor, lineWidth: 1.4)
                                }
                            }
                            .shadow(color: isSinging ? color.opacity(0.5) : .clear, radius: 5)

                        // 迷你双眼（3·拍咯小调时微垂提示）
                        if isSinging {
                            HStack(spacing: 3) {
                                Capsule().fill(Color(hex: 0x261C15)).frame(width: 3, height: 1.5)
                                Capsule().fill(Color(hex: 0x261C15)).frame(width: 3, height: 1.5)
                            }
                        } else {
                            HStack(spacing: 3.5) {
                                Circle().fill(Color(hex: 0x261C15)).frame(width: 2.3, height: 2.3)
                                Circle().fill(Color(hex: 0x261C15)).frame(width: 2.3, height: 2.3)
                            }
                            .offset(y: (member == .plokko && isMinor) ? 1.2 : -0.5)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(step.badge)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(isSinging ? color : palette.primaryInk)
                        Text(member.chineseName)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(palette.secondaryInk)
                    }
                }
                .position(x: 27, y: y)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: document.scaleMode)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(palette.divider).frame(width: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let (deg, oct) = degreeAndOctave(forY: value.location.y, height: stageHeight)
                    let key = "\(deg)-\(oct)"
                    if lastLadderStepKey != key {
                        lastLadderStepKey = key
                        onTriggerLadderMember(ChimmoMember.from(degree: deg), oct)
                    }
                }
                .onEnded { _ in
                    lastLadderStepKey = nil
                }
        )
        .accessibilityElement()
        .accessibilityLabel("左侧音阶阶梯，包含 1 陶诺到高音 1 陶诺，按真实全音半音间距排列")
        .accessibilityHint("上下点按或滑动可弹奏并向画布添加音珠")
    }

    // MARK: - 2. Right Illuminated Harmonic Scroll

    private func rightHarmonicScroll(width: CGFloat, height: CGFloat, totalSec: Double, now: TimeInterval) -> some View {
        let padX: CGFloat = 18
        let usableW = max(100, width - padX * 2)

        return ZStack {
            Canvas { ctx, size in
                drawBeatBreathColumns(ctx: &ctx, size: size)
                drawIlluminatedChordLanes(ctx: &ctx, size: size, totalSec: totalSec, padX: padX, usableW: usableW, now: now)
                drawTrueSemitoneLines(ctx: &ctx, size: size)
                drawMelodyArcsAndIntervals(ctx: &ctx, size: size, totalSec: totalSec, padX: padX, usableW: usableW, now: now)
                drawSoundRipples(ctx: &ctx, size: size, now: now)

                if let t = playheadTime {
                    let px = padX + CGFloat(min(1.0, max(0.0, t / totalSec))) * usableW
                    drawPlayhead(ctx: &ctx, x: px, height: size.height)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let (deg, oct) = degreeAndOctave(forY: location.y, height: height)
                let xFrac = Double(max(0.0, min(1.0, (location.x - padX) / max(1, usableW))))
                let targetTime = xFrac * totalSec
                onTapCanvasPitch(deg, oct, targetTime)
            }

            // 音程弧线微标签（仅在透视镜开启且存在半音或≥纯四度大跳时轻柔浮现）
            if showTheoryLens && document.notes.count > 1 {
                let sorted = document.notes.sorted {
                    $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
                }
                ForEach(0..<(sorted.count - 1), id: \.self) { i in
                    let a = sorted[i]
                    let b = sorted[i + 1]
                    let info = ScalePitchGeometry.intervalDescription(from: a, to: b, mode: document.scaleMode)
                    if info.semitones == 1 || info.semitones >= 5 {
                        let ax = padX + CGFloat(a.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                        let ay = pitchY(degree: a.degree, octave: a.octaveOffset, height: height)
                        let bx = padX + CGFloat(b.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                        let by = pitchY(degree: b.degree, octave: b.octaveOffset, height: height)
                        let midX = (ax + bx) * 0.5
                        let midY = min(ay, by) - 16

                        Text(info.shortLabel)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(palette.paper.opacity(palette.isNight ? 0.84 : 0.90))
                            )
                            .foregroundStyle(info.semitones == 1 ? palette.tensionFilament : palette.homeAnchor)
                            .position(x: midX, y: max(12, midY))
                            .allowsHitTesting(false)
                    }
                }
            }

            // 交互陶珠与幽灵备选珠
            ForEach(document.notes) { bead in
                let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
                let bx = padX + CGFloat(onset / totalSec) * usableW
                let by = pitchY(degree: bead.degree, octave: bead.octaveOffset, height: height)
                let activeChord = TheoryLensEngine.chord(at: onset, in: chordSpans)
                let inChord = activeChord.map { $0.chordToneDegrees.contains(bead.degree) } ?? true

                ForEach(bead.ghostCandidates) { ghost in
                    let gy = pitchY(degree: ghost.degree, octave: ghost.octaveOffset, height: height)
                    Button {
                        onSelectGhost(bead.id, ghost)
                    } label: {
                        Circle()
                            .strokeBorder(
                                ChimmoMember.from(degree: ghost.degree).bodyColor.opacity(0.92),
                                style: StrokeStyle(lineWidth: 1.8, dash: [3, 2.5])
                            )
                            .background(Circle().fill(palette.paper.opacity(0.85)))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .position(x: bx + 18, y: gy)
                    .accessibilityLabel("吸附到 \(ghost.degree)号 \(ChimmoMember.from(degree: ghost.degree).chineseName)")
                }

                beadNode(bead: bead, inChord: inChord, stageHeight: height, now: now)
                    .position(x: bx, y: by)
                    .animation(.spring(response: 0.42, dampingFraction: 0.78), value: document.scaleMode)
            }
        }
    }

    // MARK: - 3. Bottom Interactive Chord Ribbon (1-Tap Reharmonization)

    private func bottomChordRibbon(scrollWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 左侧小标签说明
            VStack(spacing: 1) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11))
                Text("和弦光带")
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(palette.secondaryInk)
            .frame(width: ladderWidth, height: chordStripHeight)
            .background(palette.shelfSurface)
            .overlay(alignment: .trailing) {
                Rectangle().fill(palette.divider).frame(width: 1)
            }

            if chordSpans.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path")
                        .font(.caption)
                    Text("纯单音清唱模式（底部可重新点亮和弦光带）")
                        .font(.caption2)
                }
                .foregroundStyle(palette.secondaryInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.shelfSurface.opacity(0.55))
            } else {
                HStack(spacing: 6) {
                    ForEach(chordSpans) { span in
                        let isCurrent = playheadTime.map { $0 >= span.startTime && $0 < span.endTime } ?? false
                        let tint = span.chord.color(isNight: palette.isNight)

                        Button {
                            onCycleSpanChord(span.id)
                        } label: {
                            VStack(spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(span.chord.roman)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                    Text(span.chord.tonesFormula)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .opacity(0.85)
                                }
                                Text(span.chord.moodTitle)
                                    .font(.system(size: 9, weight: .regular))
                                    .opacity(0.82)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(tint.opacity(isCurrent ? (palette.isNight ? 0.36 : 0.24) : (palette.isNight ? 0.16 : 0.11)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(tint.opacity(isCurrent ? 0.9 : 0.35), lineWidth: isCurrent ? 1.5 : 0.8)
                                    )
                            )
                            .foregroundStyle(isCurrent ? palette.primaryInk : tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(span.id + 1) 小节和弦 \(span.chord.roman)，组成音 \(span.chord.tonesFormula)，\(span.chord.moodTitle)")
                        .accessibilityHint("轻点可切换其他和弦，实时改变上方发光泳道与伴奏色彩")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: scrollWidth, height: chordStripHeight)
                .background(palette.shelfSurface.opacity(0.45))
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    // MARK: - Interactive Ceramic Bead Node

    private func beadNode(bead: NoteBead, inChord: Bool, stageHeight: CGFloat, now: TimeInterval) -> some View {
        let member = bead.member
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        let dur = bead.displayDuration(grooveStrength: document.grooveStrength)

        let isActive = playheadTime.map { t in
            t >= onset - 0.04 && t <= onset + max(0.18, dur)
        } ?? false

        let isFuture = playheadTime.map { t in
            t < onset - 0.04
        } ?? false

        let fillColor: Color = (palette.isNight && member == .corllo)
            ? Color(hex: 0xEFE7D8)
            : (palette.isNight ? member.nightGlowColor : member.bodyColor)

        let pulse: CGFloat = (!reduceMotion && isActive)
            ? 1.18 + CGFloat(sin(now * 14.0)) * 0.06
            : 1.0

        return ZStack {
            // 踩在发光和弦泳道内的「和谐暖光圈」
            if inChord && !chordSpans.isEmpty {
                Circle()
                    .fill(fillColor.opacity(isActive ? 0.38 : 0.16))
                    .frame(width: isActive ? 34 : 25, height: isActive ? 34 : 25)
            } else if !inChord && showTheoryLens {
                // 跨出和弦光带的「色彩/张力外音虚线环」
                Circle()
                    .strokeBorder(palette.tensionFilament.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, dash: [3, 2.5]))
                    .frame(width: 24, height: 24)
            }

            if member.isTensionDegree {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fillColor.opacity(isFuture ? 0.45 : 1.0))
                    .frame(width: 15, height: 15)
                    .rotationEffect(.degrees(45))
            } else {
                Circle()
                    .fill(fillColor.opacity(isFuture ? 0.45 : 1.0))
                    .frame(width: 17, height: 17)
                    .overlay {
                        if member == .corllo && !palette.isNight {
                            Circle().strokeBorder(member.accentColor, lineWidth: 1.6)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(isFuture ? 0.25 : 0.65))
                                .frame(width: 4.5, height: 4.5)
                                .offset(x: -3, y: -3)
                        }
                    }
            }

            if showTheoryLens {
                Text("\(bead.degree)")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle((!palette.isNight && member == .corllo) ? Color(hex: 0x261C15) : (palette.isNight ? Color(hex: 0x151B36) : .white))
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
                    let (newDeg, newOct) = degreeAndOctave(forY: value.location.y, height: stageHeight)
                    if newDeg != bead.degree || newOct != bead.octaveOffset {
                        onDragBeadPitch(bead.id, newDeg, newOct)
                    }
                }
        )
        .accessibilityElement()
        .accessibilityLabel("\(bead.degree)号 \(member.chineseName)，\(inChord ? "和弦内音" : "和弦外色彩音")")
        .accessibilityHint("轻点试听，上下拖动可沿真实半音阶梯调整音高")
    }

    // MARK: - Canvas Drawing Layers

    private func drawBeatBreathColumns(ctx: inout GraphicsContext, size: CGSize) {
        let cols = 4
        let colW = size.width / CGFloat(cols)
        for i in 0..<cols {
            if i % 2 == 1 {
                let rect = CGRect(x: CGFloat(i) * colW, y: 0, width: colW, height: size.height)
                ctx.fill(
                    Path(rect),
                    with: .color(palette.primaryInk.opacity(palette.isNight ? 0.035 : 0.028))
                )
            }
            if i > 0 {
                var sep = Path()
                sep.move(to: CGPoint(x: CGFloat(i) * colW, y: 0))
                sep.addLine(to: CGPoint(x: CGFloat(i) * colW, y: size.height))
                ctx.stroke(sep, with: .color(palette.divider), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
            }
        }
    }

    /// 核心无障碍可视化：精准照亮每个和弦所对应的 3 条真实音高泳道！
    private func drawIlluminatedChordLanes(
        ctx: inout GraphicsContext,
        size: CGSize,
        totalSec: Double,
        padX: CGFloat,
        usableW: CGFloat,
        now: TimeInterval
    ) {
        guard !chordSpans.isEmpty else { return }
        let bandHalfH: CGFloat = max(7.0, size.height / 34.0)

        for span in chordSpans {
            let x0 = (span.id == 0) ? 0 : (padX + CGFloat(span.startTime / totalSec) * usableW)
            let x1 = (span.id == chordSpans.count - 1) ? size.width : (padX + CGFloat(span.endTime / totalSec) * usableW)
            let spanW = max(12, x1 - x0)

            let isCurrent = playheadTime.map { $0 >= span.startTime && $0 < span.endTime } ?? false
            let tint = span.chord.color(isNight: palette.isNight)
            let breathe = (!reduceMotion && isCurrent) ? (0.04 * sin(now * 5.0)) : 0.0

            // 淡淡的整列色温氛围底光
            let colAlpha = (isCurrent ? (palette.isNight ? 0.10 : 0.07) : (palette.isNight ? 0.03 : 0.02)) + breathe
            ctx.fill(
                Path(CGRect(x: x0, y: 0, width: spanW, height: size.height)),
                with: .color(tint.opacity(max(0, colAlpha)))
            )

            // 精准照亮该和弦的 3 条音高泳道（含高八度 1↑ 当根音/组成音包含 1 时）
            var laneTargets: [(Int, Int)] = span.chord.chordToneDegrees.map { ($0, 0) }
            if span.chord.chordToneDegrees.contains(1) {
                laneTargets.append((1, 1))
            }

            let laneAlpha = (isCurrent ? (palette.isNight ? 0.34 : 0.25) : (palette.isNight ? 0.17 : 0.13)) + breathe
            for (deg, oct) in laneTargets {
                let y = pitchY(degree: deg, octave: oct, height: size.height)
                let rect = CGRect(
                    x: x0 + 3,
                    y: y - bandHalfH,
                    width: max(8, spanW - 6),
                    height: bandHalfH * 2
                )
                let laneGrad = Gradient(colors: [
                    tint.opacity(max(0, laneAlpha * 0.72)),
                    tint.opacity(max(0, laneAlpha)),
                    tint.opacity(max(0, laneAlpha * 0.72))
                ])
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: bandHalfH),
                    with: .linearGradient(
                        laneGrad,
                        startPoint: CGPoint(x: rect.minX, y: y),
                        endPoint: CGPoint(x: rect.maxX, y: y)
                    )
                )
            }
        }
    }

    private func drawTrueSemitoneLines(ctx: inout GraphicsContext, size: CGSize) {
        let rows: [(Int, Int)] = [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (1, 1)]
        for (deg, oct) in rows {
            let y = pitchY(degree: deg, octave: oct, height: size.height)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))

            if deg == 1 {
                ctx.stroke(p, with: .color(palette.homeAnchor.opacity(palette.isNight ? 0.44 : 0.34)), lineWidth: 1.5)
            } else if deg == 5 {
                ctx.stroke(p, with: .color(palette.harmonyWash.opacity(0.24)), lineWidth: 1.0)
            } else {
                ctx.stroke(p, with: .color(palette.divider), lineWidth: 0.65)
            }
        }
    }

    private func drawMelodyArcsAndIntervals(
        ctx: inout GraphicsContext,
        size: CGSize,
        totalSec: Double,
        padX: CGFloat,
        usableW: CGFloat,
        now: TimeInterval
    ) {
        let notes = document.notes.sorted {
            $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
        }
        guard !notes.isEmpty else { return }

        // 1. 优美抛物线旋律连弧
        if notes.count > 1 {
            for i in 0..<(notes.count - 1) {
                let a = notes[i]
                let b = notes[i + 1]
                let ax = padX + CGFloat(a.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                let ay = pitchY(degree: a.degree, octave: a.octaveOffset, height: size.height)
                let bx = padX + CGFloat(b.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                let by = pitchY(degree: b.degree, octave: b.octaveOffset, height: size.height)

                let semiJump = ScalePitchGeometry.intervalDescription(from: a, to: b, mode: document.scaleMode).semitones
                let archLift = CGFloat(min(30, semiJump * 3))
                let midX = (ax + bx) * 0.5
                let midY = min(ay, by) - archLift

                var arc = Path()
                arc.move(to: CGPoint(x: ax, y: ay))
                arc.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: midX, y: midY))

                let isPlayed = playheadTime.map { $0 >= a.displayOnset(grooveStrength: document.grooveStrength) } ?? true
                let color = (palette.isNight ? a.member.nightGlowColor : a.member.bodyColor)
                ctx.stroke(
                    arc,
                    with: .color(color.opacity(isPlayed ? 0.58 : 0.20)),
                    style: StrokeStyle(lineWidth: isPlayed ? 2.2 : 1.3, lineCap: .round)
                )
            }
        }

        // 2. 音珠呼吸拖尾 + 真实半音张力牵引丝（7→1↑，4→3）
        for bead in notes {
            let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
            let dur = bead.displayDuration(grooveStrength: document.grooveStrength)
            let x = padX + CGFloat(onset / totalSec) * usableW
            let y = pitchY(degree: bead.degree, octave: bead.octaveOffset, height: size.height)
            let tailW = max(14, CGFloat(dur / totalSec) * usableW)

            let isCurrent = playheadTime.map { $0 >= onset - 0.04 && $0 <= onset + max(0.18, dur) } ?? false
            let color = palette.isNight ? bead.member.nightGlowColor : bead.member.bodyColor

            var tail = Path()
            tail.move(to: CGPoint(x: x, y: y))
            tail.addLine(to: CGPoint(x: min(size.width - 8, x + tailW), y: y))
            let tailGrad = Gradient(colors: [color.opacity(isCurrent ? 0.72 : 0.36), .clear])
            ctx.stroke(
                tail,
                with: .linearGradient(tailGrad, startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + tailW, y: y)),
                style: StrokeStyle(lineWidth: isCurrent ? 10 : 6.5, lineCap: .round)
            )

            // 透视镜开启时，7·叮尖向高音 1↑ 拉紧向上牵引弦，4·呜嘟向 3·拍咯拉出向下牵引弦
            if showTheoryLens && bead.member.isTensionDegree {
                let targetY: CGFloat
                if bead.degree == 7 {
                    targetY = pitchY(degree: 1, octave: bead.octaveOffset + 1, height: size.height)
                } else {
                    targetY = pitchY(degree: 3, octave: bead.octaveOffset, height: size.height)
                }
                let vib: CGFloat = (!reduceMotion && isCurrent) ? CGFloat(sin(now * 32.0)) * 5.0 : 3.0
                var pull = Path()
                pull.move(to: CGPoint(x: x, y: y))
                pull.addQuadCurve(to: CGPoint(x: x, y: targetY), control: CGPoint(x: x + vib, y: (y + targetY) * 0.5))
                ctx.stroke(
                    pull,
                    with: .color(palette.tensionFilament.opacity(isCurrent ? 0.9 : 0.55)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3.5, 2.5])
                )
            }
        }
    }

    private func drawSoundRipples(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        for imp in impulses {
            let age = now - imp.birth
            guard age >= 0 && age < 1.25 else { continue }
            let member = ChimmoMember.from(degree: imp.degree)
            let color = palette.isNight ? member.nightGlowColor : member.bodyColor
            let x = CGFloat(imp.xNorm) * size.width
            let y = pitchY(degree: imp.degree, octave: imp.octaveOffset, height: size.height)

            let progress = min(1.0, age / 1.15)
            let radius = 10.0 + CGFloat(progress) * 44.0
            let alpha = pow(1.0 - progress, 1.8) * 0.65
            ctx.stroke(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha)),
                style: StrokeStyle(lineWidth: 1.7)
            )
        }
    }

    private func drawPlayhead(ctx: inout GraphicsContext, x: CGFloat, height: CGFloat) {
        var line = Path()
        line.move(to: CGPoint(x: x, y: 6))
        line.addLine(to: CGPoint(x: x, y: height - 6))
        ctx.stroke(
            line,
            with: .color(palette.melodyTerracotta.opacity(0.68)),
            style: StrokeStyle(lineWidth: 1.8)
        )
    }

    // MARK: - Coordinate Mapping (True Semitone Geometry)

    private func pitchY(degree: Int, octave: Int, height: CGFloat) -> CGFloat {
        let topPad: CGFloat = 20
        let bottomPad: CGFloat = 20
        let usableH = max(60, height - topPad - bottomPad)
        let norm = ScalePitchGeometry.normalizedY(degree: degree, octaveOffset: octave, mode: document.scaleMode)
        return height - bottomPad - norm * usableH
    }

    private func degreeAndOctave(forY y: CGFloat, height: CGFloat) -> (Int, Int) {
        let topPad: CGFloat = 20
        let bottomPad: CGFloat = 20
        let usableH = max(60, height - topPad - bottomPad)
        let normFromBottom = max(0, min(1, (height - bottomPad - y) / usableH))
        return ScalePitchGeometry.nearestDegreeAndOctave(normalizedFromBottom: normFromBottom, mode: document.scaleMode)
    }
}
