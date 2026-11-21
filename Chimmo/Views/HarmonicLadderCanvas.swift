import SwiftUI

/// 咩哞 0.4 全感官活体声学舞台：
/// - 随「五色天光」动态呼吸的极光天幕背景；
/// - 左侧「真实全音/半音不等距」七小只阶梯（在 5 种调式天空下自动实时迁移红标「半」字窄缝！）；
/// - 三层无障碍认知透镜（🌿诗意直觉 ⇄ 💠逻辑哲学 ⇄ 🎼音乐母语）；
/// - 💠哲学镜实时浮现「利萨如声波对称显微镜」与「起·承·转·合」种子折纸标牌；
/// - 可选叠加「👥 影子对位副旋律」透明光珠；
/// - 底部可一键切换的 4 格「和弦光带卡片」。
public struct HarmonicLadderCanvas: View {
    public let document: MelodyDocument
    public let chordSpans: [ChordSpan]
    public let shadowNotes: [CounterpointNote]
    public let shadowEnabled: Bool
    public let cognitiveLens: CognitiveLens
    public let palette: ChimmoPalette
    public let playheadTime: Double?
    public let activeDegrees: Set<Int>
    public let latestDegree: Int?
    public let selectedBeadID: UUID?
    public let impulses: [VisualImpulse]

    public let onTriggerLadderMember: (ChimmoMember, Int) -> Void
    public let onTapCanvasPitch: (Int, Int, Double) -> Void
    public let onSelectGhost: (UUID, GhostCandidate) -> Void
    public let onDragBeadPitch: (UUID, Int, Int) -> Void
    public let onTapBead: (NoteBead) -> Void
    public let onCycleSpanChord: (Int) -> Void
    public let onAdjustSelectedDuration: (Double) -> Void
    public let onDeleteSelectedBead: () -> Void
    public let onDismissSelection: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastLadderStepKey: String? = nil

    private let ladderWidth: CGFloat = 72
    private let chordStripHeight: CGFloat = 46

    public init(
        document: MelodyDocument,
        chordSpans: [ChordSpan],
        shadowNotes: [CounterpointNote] = [],
        shadowEnabled: Bool = false,
        cognitiveLens: CognitiveLens = .philosophy,
        palette: ChimmoPalette,
        playheadTime: Double?,
        activeDegrees: Set<Int>,
        latestDegree: Int?,
        selectedBeadID: UUID? = nil,
        impulses: [VisualImpulse],
        onTriggerLadderMember: @escaping (ChimmoMember, Int) -> Void,
        onTapCanvasPitch: @escaping (Int, Int, Double) -> Void,
        onSelectGhost: @escaping (UUID, GhostCandidate) -> Void,
        onDragBeadPitch: @escaping (UUID, Int, Int) -> Void,
        onTapBead: @escaping (NoteBead) -> Void,
        onCycleSpanChord: @escaping (Int) -> Void,
        onAdjustSelectedDuration: @escaping (Double) -> Void = { _ in },
        onDeleteSelectedBead: @escaping () -> Void = {},
        onDismissSelection: @escaping () -> Void = {}
    ) {
        self.document = document
        self.chordSpans = chordSpans
        self.shadowNotes = shadowNotes
        self.shadowEnabled = shadowEnabled
        self.cognitiveLens = cognitiveLens
        self.palette = palette
        self.playheadTime = playheadTime
        self.activeDegrees = activeDegrees
        self.latestDegree = latestDegree
        self.selectedBeadID = selectedBeadID
        self.impulses = impulses
        self.onTriggerLadderMember = onTriggerLadderMember
        self.onTapCanvasPitch = onTapCanvasPitch
        self.onSelectGhost = onSelectGhost
        self.onDragBeadPitch = onDragBeadPitch
        self.onTapBead = onTapBead
        self.onCycleSpanChord = onCycleSpanChord
        self.onAdjustSelectedDuration = onAdjustSelectedDuration
        self.onDeleteSelectedBead = onDeleteSelectedBead
        self.onDismissSelection = onDismissSelection
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
                        leftPitchLadder(stageHeight: stageH)
                            .frame(width: ladderWidth, height: stageH)

                        rightHarmonicScroll(width: scrollW, height: stageH, totalSec: totalSec, now: now)
                            .frame(width: scrollW, height: stageH)
                    }

                    bottomChordRibbon(scrollWidth: scrollW)
                        .frame(height: chordStripHeight)
                }
            }
        }
    }

    // MARK: - 1. Left True-Semitone Pitch Ladder (Dynamic half-steps across ALL 5 Modal Skies!)

    private struct LadderStep: Identifiable {
        let id: String
        let degree: Int
        let octave: Int
        let badge: String
        let isSecondaryLow: Bool
    }

    private var ladderSteps: [LadderStep] {
        [
            LadderStep(id: "5--1", degree: 5, octave: -1, badge: "5↓", isSecondaryLow: true),
            LadderStep(id: "1-0", degree: 1, octave: 0, badge: "1", isSecondaryLow: false),
            LadderStep(id: "2-0", degree: 2, octave: 0, badge: "2", isSecondaryLow: false),
            LadderStep(id: "3-0", degree: 3, octave: 0, badge: "3", isSecondaryLow: false),
            LadderStep(id: "4-0", degree: 4, octave: 0, badge: "4", isSecondaryLow: false),
            LadderStep(id: "5-0", degree: 5, octave: 0, badge: "5", isSecondaryLow: false),
            LadderStep(id: "6-0", degree: 6, octave: 0, badge: "6", isSecondaryLow: false),
            LadderStep(id: "7-0", degree: 7, octave: 0, badge: "7", isSecondaryLow: false),
            LadderStep(id: "1-1", degree: 1, octave: 1, badge: "1↑", isSecondaryLow: false)
        ]
    }

    /// 动态计算当前 5 色天光下的真实「半音紧邻阶梯对」（例如云端 Lydian 是 #4-5 与 7-1↑，森林 Dorian 是 2-3 与 6-7！）
    private var dynamicHalfStepPairs: [(Int, Int, Int, Int)] {
        let seq: [(Int, Int)] = [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (1, 1)]
        var pairs: [(Int, Int, Int, Int)] = []
        for i in 0..<(seq.count - 1) {
            let s0 = ScalePitchGeometry.semitoneOffset(degree: seq[i].0, octaveOffset: seq[i].1, mode: document.scaleMode)
            let s1 = ScalePitchGeometry.semitoneOffset(degree: seq[i + 1].0, octaveOffset: seq[i + 1].1, mode: document.scaleMode)
            if s1 - s0 == 1 {
                pairs.append((seq[i].0, seq[i].1, seq[i + 1].0, seq[i + 1].1))
            }
        }
        return pairs
    }

    private func leftPitchLadder(stageHeight: CGFloat) -> some View {
        let isMinorish = document.scaleMode.isMinorFlavored

        return ZStack {
            palette.shelfSurface.opacity(palette.isNight ? 0.92 : 0.84)

            // 动态半音窄缝提示（哲学镜与乐理镜可见；诗意镜隐去文字保持纯粹）
            if cognitiveLens != .poetic {
                ForEach(0..<dynamicHalfStepPairs.count, id: \.self) { idx in
                    let p = dynamicHalfStepPairs[idx]
                    let yLow = pitchY(degree: p.0, octave: p.1, height: stageHeight)
                    let yHigh = pitchY(degree: p.2, octave: p.3, height: stageHeight)
                    let midY = (yLow + yHigh) * 0.5
                    let gap = max(8, abs(yLow - yHigh))

                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(palette.tensionFilament.opacity(0.92))
                            .frame(width: 2.5, height: max(9, gap - 2))
                        Text(cognitiveLens == .musician ? "半" : "窄")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(palette.tensionFilament)
                    }
                    .position(x: ladderWidth - 9, y: midY)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.42, dampingFraction: 0.78), value: document.scaleMode)
                }
            }

            ForEach(ladderSteps) { step in
                let member = ChimmoMember.from(degree: step.degree)
                let y = pitchY(degree: step.degree, octave: step.octave, height: stageHeight)
                let isSinging = activeDegrees.contains(step.degree)
                let color = palette.isNight ? member.nightGlowColor : member.bodyColor

                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(step.isSecondaryLow ? 0.55 : (isSinging ? 1.0 : 0.92)))
                            .frame(width: step.isSecondaryLow ? 14 : (isSinging ? 21 : 17), height: step.isSecondaryLow ? 14 : (isSinging ? 21 : 17))
                            .shadow(color: isSinging ? color.opacity(0.6) : .clear, radius: 6)

                        if !step.isSecondaryLow {
                            if isSinging {
                                HStack(spacing: 2.5) {
                                    Capsule().fill(Color.white).frame(width: 3, height: 1.4)
                                    Capsule().fill(Color.white).frame(width: 3, height: 1.4)
                                }
                            } else {
                                HStack(spacing: 3) {
                                    Circle().fill(Color.white.opacity(0.95)).frame(width: 2.3, height: 2.3)
                                    Circle().fill(Color.white.opacity(0.95)).frame(width: 2.3, height: 2.3)
                                }
                                .offset(y: (member == .plokko && isMinorish) ? 1.2 : -0.4)
                            }
                        }
                    }

                    // 三层无障碍认知透镜分别呈现不同语言！
                    VStack(alignment: .leading, spacing: 0) {
                        switch cognitiveLens {
                        case .poetic:
                            Text(step.isSecondaryLow ? "低望" : member.roleLabel)
                                .font(.system(size: step.isSecondaryLow ? 9 : 10, weight: .bold))
                                .foregroundStyle(isSinging ? color : palette.primaryInk)
                            if !step.isSecondaryLow {
                                Text(member.chineseName)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(palette.secondaryInk)
                            }
                        case .philosophy:
                            Text(step.isSecondaryLow ? "5↓" : "\(step.badge)·\(member.roleLabel)")
                                .font(.system(size: step.isSecondaryLow ? 9 : 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isSinging ? color : palette.primaryInk)
                        case .musician:
                            Text(step.isSecondaryLow ? "5↓" : "\(step.badge) \(member.solfege)")
                                .font(.system(size: step.isSecondaryLow ? 9 : 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isSinging ? color : palette.primaryInk)
                            if !step.isSecondaryLow {
                                Text(member.chineseName)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(palette.secondaryInk)
                            }
                        }
                    }
                }
                .position(x: 30, y: y)
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
        .accessibilityLabel("左侧真实半音阶梯，当前天光 \(document.scaleMode.label)")
        .accessibilityHint("点按或上下滑动可弹奏并写入音珠")
    }

    // MARK: - 2. Right Living Aurora Harmonic Scroll

    private func rightHarmonicScroll(width: CGFloat, height: CGFloat, totalSec: Double, now: TimeInterval) -> some View {
        let padX: CGFloat = 18
        let usableW = max(100, width - padX * 2)
        let skyTint = document.scaleMode.skyAuroraColor(isNight: palette.isNight)

        // 计算当前正在发声的音符与当前和弦根音之间的物理比例（供右上角实时利萨如显微镜使用）
        let currentChordRoot: Int = {
            if let t = playheadTime, let ch = TheoryLensEngine.chord(at: t, in: chordSpans) {
                return ch.rootDegree
            }
            return chordSpans.first?.chord.rootDegree ?? 1
        }()
        let liveDegree = latestDegree ?? document.notes.first?.degree ?? 1
        let livePhysics = HarmonicRatioPhysics.analyze(melodyDegree: liveDegree, rootDegree: currentChordRoot, mode: document.scaleMode)

        return ZStack {
            // 活体五色天光极光底幕
            LinearGradient(
                colors: [
                    skyTint.opacity(palette.isNight ? 0.16 : 0.11),
                    palette.paper.opacity(0.0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .animation(.easeInOut(duration: 0.45), value: document.scaleMode)

            Canvas { ctx, size in
                drawBeatBreathColumns(ctx: &ctx, size: size)
                drawIlluminatedChordLanes(ctx: &ctx, size: size, totalSec: totalSec, padX: padX, usableW: usableW, now: now)
                drawTrueSemitoneLines(ctx: &ctx, size: size)
                if shadowEnabled {
                    drawShadowCounterpointLayer(ctx: &ctx, size: size, totalSec: totalSec, padX: padX, usableW: usableW)
                }
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

            // 音程弧线标注（仅在「🎼 音乐母语」镜开启）
            if cognitiveLens == .musician && document.notes.count > 1 {
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
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(palette.cardSurface.opacity(0.92)))
                            .foregroundStyle(info.semitones == 1 ? palette.tensionFilament : palette.homeAnchor)
                            .position(x: midX, y: max(14, midY))
                            .allowsHitTesting(false)
                    }
                }
            }

            // 种子折纸架构标牌（起·承·转·合，在哲学镜与乐理镜呈现）
            if cognitiveLens != .poetic {
                let taggedStarts = uniquePhraseTagMarkers(totalSec: totalSec, padX: padX, usableW: usableW)
                ForEach(taggedStarts, id: \.tag) { item in
                    Text(item.tag)
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.harmonyWash.opacity(0.18)))
                        .foregroundStyle(palette.harmonyWash)
                        .position(x: max(36, min(width - 36, item.x)), y: height - 14)
                        .allowsHitTesting(false)
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
                                ChimmoMember.from(degree: ghost.degree).bodyColor.opacity(0.95),
                                style: StrokeStyle(lineWidth: 1.8, dash: [3, 2.5])
                            )
                            .background(Circle().fill(palette.cardSurface.opacity(0.9)))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .position(x: bx + 18, y: gy)
                    .accessibilityLabel("修正为 \(ghost.degree)号 \(ChimmoMember.from(degree: ghost.degree).chineseName)")
                }

                beadNode(bead: bead, inChord: inChord, isSelected: bead.id == selectedBeadID, stageHeight: height, now: now)
                    .position(x: bx, y: by)
                    .animation(.spring(response: 0.42, dampingFraction: 0.78), value: document.scaleMode)
            }

            // 💠 逻辑哲学镜专属：右上角实时「利萨如声波对称显微镜」+ 顶部电影字幕导赏
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    if cognitiveLens != .poetic, let moment = document.activeGuidedMoment(at: playheadTime) {
                        HStack(spacing: 6) {
                            Text(moment.badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(palette.bassRibbon))
                                .foregroundStyle(.white)
                            Text(moment.caption)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.primaryInk)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.cardSurface.opacity(palette.isNight ? 0.90 : 0.94))
                                .shadow(color: palette.primaryInk.opacity(0.08), radius: 8, y: 2)
                        )
                        .animation(.easeInOut(duration: 0.25), value: moment.id)
                    }

                    Spacer(minLength: 4)

                    if cognitiveLens == .philosophy {
                        VStack(spacing: 2) {
                            LissajousWaveView(
                                ratioA: Double(livePhysics.ratioA),
                                ratioB: Double(livePhysics.ratioB),
                                consonance: livePhysics.consonance,
                                accentColor: livePhysics.isTense ? palette.melodyTerracotta : palette.homeAnchor,
                                isNight: palette.isNight,
                                compact: true
                            )
                            .frame(width: 44, height: 44)
                            Text(livePhysics.ratioText)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(livePhysics.isTense ? palette.melodyTerracotta : palette.homeAnchor)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.cardSurface.opacity(palette.isNight ? 0.88 : 0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(palette.divider, lineWidth: 0.9)
                                )
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .allowsHitTesting(false)

                Spacer()

                // 底部悬浮「已选中音珠快捷精修胶囊」
                if selectedBeadID != nil && !document.isSpecimen {
                    HStack(spacing: 10) {
                        Button {
                            onAdjustSelectedDuration(-0.18)
                        } label: {
                            Label("变短", systemImage: "minus.circle")
                                .font(.caption2.weight(.semibold))
                        }
                        Button {
                            onAdjustSelectedDuration(0.22)
                        } label: {
                            Label("拉长", systemImage: "plus.circle")
                                .font(.caption2.weight(.semibold))
                        }
                        Divider().frame(height: 14)
                        Button(role: .destructive) {
                            onDeleteSelectedBead()
                        } label: {
                            Label("删除", systemImage: "trash")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.melodyTerracotta)
                        }
                        Button {
                            onDismissSelection()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(palette.cardSurface.opacity(0.96))
                            .overlay(Capsule().strokeBorder(palette.divider, lineWidth: 1))
                            .shadow(color: palette.primaryInk.opacity(0.10), radius: 8, y: 3)
                    )
                    .foregroundStyle(palette.primaryInk)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func uniquePhraseTagMarkers(totalSec: Double, padX: CGFloat, usableW: CGFloat) -> [(tag: String, x: CGFloat)] {
        var seen: Set<String> = []
        var items: [(String, CGFloat)] = []
        for b in document.notes.sorted(by: { $0.rawOnset < $1.rawOnset }) {
            if let t = b.phraseTag, !seen.contains(t) {
                seen.insert(t)
                let x = padX + CGFloat(b.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                items.append((t, x))
            }
        }
        return items
    }

    // MARK: - 3. Bottom Interactive Chord Ribbon

    private func bottomChordRibbon(scrollWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 1) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11))
                Text(cognitiveLens == .poetic ? "脚下光影" : "和弦光带")
                    .font(.system(size: 9.5, weight: .bold))
            }
            .foregroundStyle(palette.homeAnchor)
            .frame(width: ladderWidth, height: chordStripHeight)
            .background(palette.shelfSurface)
            .overlay(alignment: .trailing) {
                Rectangle().fill(palette.divider).frame(width: 1)
            }

            if chordSpans.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path")
                        .font(.caption)
                    Text("纯单音清唱模式（点右下角「声音」可重新点亮和弦光带）")
                        .font(.caption2)
                }
                .foregroundStyle(palette.secondaryInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.shelfSurface.opacity(0.6))
            } else {
                HStack(spacing: 6) {
                    ForEach(chordSpans) { span in
                        let isCurrent = playheadTime.map { $0 >= span.startTime && $0 < span.endTime } ?? false
                        let tint = span.chord.color(isNight: palette.isNight)

                        Button {
                            onCycleSpanChord(span.id)
                        } label: {
                            VStack(spacing: 1) {
                                if cognitiveLens == .poetic {
                                    Text(span.chord.moodTitle)
                                        .font(.system(size: 11.5, weight: .bold))
                                } else {
                                    HStack(spacing: 4) {
                                        Text(span.chord.roman)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                        Text(span.chord.tonesFormula)
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .opacity(0.85)
                                    }
                                    Text(span.chord.moodTitle)
                                        .font(.system(size: 9, weight: .medium))
                                        .opacity(0.82)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(tint.opacity(isCurrent ? (palette.isNight ? 0.36 : 0.24) : (palette.isNight ? 0.14 : 0.10)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(tint.opacity(isCurrent ? 0.95 : 0.32), lineWidth: isCurrent ? 1.6 : 0.8)
                                    )
                            )
                            .foregroundStyle(isCurrent ? palette.primaryInk : tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(span.id + 1) 小节 \(span.chord.moodTitle)，和弦 \(span.chord.roman)")
                        .accessibilityHint("轻点可切换其他和弦，实时听见情绪关系变化")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(width: scrollWidth, height: chordStripHeight)
                .background(palette.shelfSurface.opacity(0.5))
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    // MARK: - Interactive Ceramic Bead Node

    private func beadNode(bead: NoteBead, inChord: Bool, isSelected: Bool, stageHeight: CGFloat, now: TimeInterval) -> some View {
        let member = bead.member
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        let dur = bead.displayDuration(grooveStrength: document.grooveStrength)

        let isActive = playheadTime.map { t in
            t >= onset - 0.04 && t <= onset + max(0.18, dur)
        } ?? false

        let isFuture = playheadTime.map { t in
            t < onset - 0.04
        } ?? false

        let fillColor: Color = palette.isNight ? member.nightGlowColor : member.bodyColor
        let pulse: CGFloat = (!reduceMotion && isActive)
            ? 1.20 + CGFloat(sin(now * 14.0)) * 0.06
            : (isSelected ? 1.12 : 1.0)

        return ZStack {
            if isSelected {
                Circle()
                    .strokeBorder(palette.primaryInk.opacity(0.78), lineWidth: 2.0)
                    .frame(width: 28, height: 28)
            } else if inChord && !chordSpans.isEmpty {
                Circle()
                    .fill(fillColor.opacity(isActive ? 0.40 : 0.16))
                    .frame(width: isActive ? 36 : 25, height: isActive ? 36 : 25)
            } else if !inChord && cognitiveLens != .poetic {
                Circle()
                    .strokeBorder(palette.tensionFilament.opacity(0.88), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                    .frame(width: 24, height: 24)
            }

            if member.isTensionDegree {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(fillColor.opacity(isFuture ? 0.45 : 1.0))
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(45))
            } else {
                Circle()
                    .fill(fillColor.opacity(isFuture ? 0.45 : 1.0))
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(isFuture ? 0.22 : 0.55))
                            .frame(width: 4.5, height: 4.5)
                            .offset(x: -3.5, y: -3.5)
                    }
            }

            if cognitiveLens == .musician {
                Text("\(bead.degree)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
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
        .accessibilityLabel("\(bead.degree)号 \(member.chineseName) \(member.solfege)，\(inChord ? "和弦内音" : "色彩张力音")")
        .accessibilityHint("轻点试听与精修时长，上下拖动调整音高")
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
                    with: .color(palette.bassRibbon.opacity(palette.isNight ? 0.04 : 0.028))
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

    private func drawIlluminatedChordLanes(
        ctx: inout GraphicsContext,
        size: CGSize,
        totalSec: Double,
        padX: CGFloat,
        usableW: CGFloat,
        now: TimeInterval
    ) {
        guard !chordSpans.isEmpty else { return }
        let bandHalfH: CGFloat = max(6.5, size.height / 36.0)

        for span in chordSpans {
            let x0 = (span.id == 0) ? 0 : (padX + CGFloat(span.startTime / totalSec) * usableW)
            let x1 = (span.id == chordSpans.count - 1) ? size.width : (padX + CGFloat(span.endTime / totalSec) * usableW)
            let spanW = max(12, x1 - x0)

            let isCurrent = playheadTime.map { $0 >= span.startTime && $0 < span.endTime } ?? false
            let tint = span.chord.color(isNight: palette.isNight)
            let breathe = (!reduceMotion && isCurrent) ? (0.04 * sin(now * 5.0)) : 0.0

            let colAlpha = (isCurrent ? (palette.isNight ? 0.10 : 0.065) : (palette.isNight ? 0.025 : 0.018)) + breathe
            ctx.fill(
                Path(CGRect(x: x0, y: 0, width: spanW, height: size.height)),
                with: .color(tint.opacity(max(0, colAlpha)))
            )

            var laneTargets: [(Int, Int)] = span.chord.chordToneDegrees.map { ($0, 0) }
            if span.chord.chordToneDegrees.contains(1) { laneTargets.append((1, 1)) }
            if span.chord.chordToneDegrees.contains(5) { laneTargets.append((5, -1)) }

            let laneAlpha = (isCurrent ? (palette.isNight ? 0.34 : 0.24) : (palette.isNight ? 0.16 : 0.12)) + breathe
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
        let rows: [(Int, Int)] = [(5, -1), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (1, 1)]
        for (deg, oct) in rows {
            let y = pitchY(degree: deg, octave: oct, height: size.height)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))

            if deg == 1 {
                ctx.stroke(p, with: .color(palette.homeAnchor.opacity(palette.isNight ? 0.45 : 0.36)), lineWidth: 1.5)
            } else if deg == 5 && oct == 0 {
                ctx.stroke(p, with: .color(palette.bassRibbon.opacity(0.24)), lineWidth: 1.0)
            } else {
                ctx.stroke(p, with: .color(palette.divider), lineWidth: 0.65)
            }
        }
    }

    /// 透明的「巴赫式影子对位副旋律」光轨（在留白间隙里温柔接唱）
    private func drawShadowCounterpointLayer(
        ctx: inout GraphicsContext,
        size: CGSize,
        totalSec: Double,
        padX: CGFloat,
        usableW: CGFloat
    ) {
        guard !shadowNotes.isEmpty else { return }
        var prevPt: CGPoint? = nil
        for sh in shadowNotes {
            let x = padX + CGFloat(sh.onset / totalSec) * usableW
            let y = pitchY(degree: sh.degree, octave: sh.octaveOffset, height: size.height)
            let pt = CGPoint(x: x, y: y)
            let isCur = playheadTime.map { $0 >= sh.onset - 0.04 && $0 <= sh.onset + sh.duration } ?? false

            if let prev = prevPt {
                var p = Path()
                p.move(to: prev)
                p.addQuadCurve(to: pt, control: CGPoint(x: (prev.x + pt.x) * 0.5, y: max(prev.y, pt.y) + 12))
                ctx.stroke(p, with: .color(palette.harmonyWash.opacity(0.35)), style: StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
            }
            prevPt = pt

            let r: CGFloat = isCur ? 7.5 : 5.0
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(palette.harmonyWash.opacity(isCur ? 0.92 : 0.50))
            )
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

        if notes.count > 1 {
            for i in 0..<(notes.count - 1) {
                let a = notes[i]
                let b = notes[i + 1]
                let ax = padX + CGFloat(a.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                let ay = pitchY(degree: a.degree, octave: a.octaveOffset, height: size.height)
                let bx = padX + CGFloat(b.displayOnset(grooveStrength: document.grooveStrength) / totalSec) * usableW
                let by = pitchY(degree: b.degree, octave: b.octaveOffset, height: size.height)

                let semiJump = ScalePitchGeometry.intervalDescription(from: a, to: b, mode: document.scaleMode).semitones
                let archLift = CGFloat(min(28.0, Double(semiJump) * 2.8))
                let midX = (ax + bx) * 0.5
                let midY = min(ay, by) - archLift

                var arc = Path()
                arc.move(to: CGPoint(x: ax, y: ay))
                arc.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: midX, y: midY))

                let isPlayed = playheadTime.map { $0 >= a.displayOnset(grooveStrength: document.grooveStrength) } ?? true
                let color = palette.isNight ? a.member.nightGlowColor : a.member.bodyColor
                ctx.stroke(
                    arc,
                    with: .color(color.opacity(isPlayed ? 0.65 : 0.22)),
                    style: StrokeStyle(lineWidth: isPlayed ? 2.4 : 1.3, lineCap: .round)
                )
            }
        }

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
            let tailGrad = Gradient(colors: [color.opacity(isCurrent ? 0.74 : 0.38), .clear])
            ctx.stroke(
                tail,
                with: .linearGradient(tailGrad, startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + tailW, y: y)),
                style: StrokeStyle(lineWidth: isCurrent ? 10 : 6.5, lineCap: .round)
            )

            if cognitiveLens != .poetic && bead.member.isTensionDegree {
                let targetY: CGFloat = (bead.degree == 7)
                    ? pitchY(degree: 1, octave: bead.octaveOffset + 1, height: size.height)
                    : pitchY(degree: 3, octave: bead.octaveOffset, height: size.height)
                let vib: CGFloat = (!reduceMotion && isCurrent) ? CGFloat(sin(now * 32.0)) * 5.0 : 3.0
                var pull = Path()
                pull.move(to: CGPoint(x: x, y: y))
                pull.addQuadCurve(to: CGPoint(x: x, y: targetY), control: CGPoint(x: x + vib, y: (y + targetY) * 0.5))
                ctx.stroke(
                    pull,
                    with: .color(palette.tensionFilament.opacity(isCurrent ? 0.92 : 0.55)),
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
            let radius = 10.0 + CGFloat(progress) * 46.0
            let alpha = pow(1.0 - progress, 1.8) * 0.65
            ctx.stroke(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha)),
                style: StrokeStyle(lineWidth: 1.8)
            )
        }
    }

    private func drawPlayhead(ctx: inout GraphicsContext, x: CGFloat, height: CGFloat) {
        var line = Path()
        line.move(to: CGPoint(x: x, y: 6))
        line.addLine(to: CGPoint(x: x, y: height - 6))
        ctx.stroke(
            line,
            with: .color(palette.melodyTerracotta.opacity(0.75)),
            style: StrokeStyle(lineWidth: 2.0)
        )
    }

    // MARK: - Coordinate Mapping (True Semitone Geometry)

    private func pitchY(degree: Int, octave: Int, height: CGFloat) -> CGFloat {
        let topPad: CGFloat = 22
        let bottomPad: CGFloat = 18
        let usableH = max(60, height - topPad - bottomPad)
        let norm = ScalePitchGeometry.normalizedY(degree: degree, octaveOffset: octave, mode: document.scaleMode)
        return height - bottomPad - norm * usableH
    }

    private func degreeAndOctave(forY y: CGFloat, height: CGFloat) -> (Int, Int) {
        let topPad: CGFloat = 22
        let bottomPad: CGFloat = 18
        let usableH = max(60, height - topPad - bottomPad)
        let normFromBottom = max(0, min(1, (height - bottomPad - y) / usableH))
        return ScalePitchGeometry.nearestDegreeAndOctave(normalizedFromBottom: normFromBottom, mode: document.scaleMode)
    }
}
