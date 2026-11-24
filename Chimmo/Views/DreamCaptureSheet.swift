import QuartzCore
import SwiftUI

/// 零乐理 3 秒「捕梦创作」抽屉：
/// - 1) 拍节奏 · 画山坡：先按脑海里的快慢轻敲木鼓，再单指画一条起伏山坡（或一键套用 4 座山坡），五音不全也能一次写对；
/// - 2) 随口轻哼：不管跑不跑调，只听你的相对高低起伏自动排上星盘；
/// - 3) 魔法 · 跟弹 · 夜灯剧场：随时进入闭眼夜灯触觉剧场、跟着亮灯体验名曲，或铺开一张全新的安心 5 音画布。
public struct DreamCaptureSheet: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var modeTab: Int = 0
    @State private var drumScale: CGFloat = 1.0
    @State private var drumShockwaveScale: CGFloat = 1.0
    @State private var drumShockwaveOpacity: Double = 0.0
    @State private var sketchPoints: [CGPoint] = []
    @State private var sketchSize: CGSize = CGSize(width: 300, height: 140)
    @State private var seedShifts: [Int] = [0, 0, 0]
    @State private var showNightLampTheater: Bool = false
    @State private var lastBrushLane: Int? = nil
    @State private var lastBrushTime: Double = 0
    @State private var brushNormX: Double? = nil
    @State private var brushNormY: Double? = nil

    public init(vm: StudioViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("创作方式", selection: $modeTab) {
                    Text("节奏").tag(0)
                    Text("哼唱").tag(1)
                    Text("更多").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 16) {
                        if modeTab == 0 {
                            rhythmAndSketchSection
                        } else if modeTab == 1 {
                            forgivingHumSection
                        } else {
                            followAndBlankSection
                        }
                    }
                    .padding(16)
                }
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("写旋律")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if vm.isTappingRhythm {
                            vm.cancelRhythmTap()
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: modeTab) { _, _ in
            lastBrushLane = nil
            lastBrushTime = 0
            brushNormX = nil
            brushNormY = nil
        }
        .onDisappear {
            lastBrushLane = nil
            lastBrushTime = 0
            brushNormX = nil
            brushNormY = nil
            if vm.isTappingRhythm {
                vm.cancelRhythmTap()
            }
        }
        .fullScreenCover(isPresented: $showNightLampTheater) {
            NightLampTactileSheet(vm: vm) {
                dismiss()
            }
        }
    }

    // MARK: - Tab 0: Sculptural Drum Pad + Ghost-Wave Sketch Canvas + Pure Curve Presets

    private var dreamDuoReactiveHeader: some View {
        let skyCol = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let reaction = DreamBrushKinematics.reaction(
            brushNormalizedY: brushNormY,
            brushNormalizedX: brushNormX,
            tapCount: vm.liveTapTimestamps.count
        )
        return TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
            let phaseTime = reduceMotion ? 0.0 : CACurrentMediaTime()
            HStack(spacing: 12) {
                ChimmoSheepView(
                    isNight: palette.isNight,
                    accentColor: skyCol,
                    isSinging: reaction.sheepSinging,
                    tiltProgress: reaction.sheepTiltProgress,
                    phaseTime: phaseTime,
                    gazeBias: reaction.sheepGazeBias
                )
                .frame(width: 34, height: 28)

                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { idx in
                        let active = !vm.liveTapTimestamps.isEmpty && reaction.beatCycleIndex == idx
                        let isDownbeatDot = idx == 0
                        Circle()
                            .fill(
                                active
                                    ? (isDownbeatDot ? palette.nightLampGold : palette.homeAnchor)
                                    : palette.secondaryInk.opacity(isDownbeatDot ? 0.34 : 0.18)
                            )
                            .frame(
                                width: active ? (isDownbeatDot ? 9 : 7.5) : 5.5,
                                height: active ? (isDownbeatDot ? 9 : 7.5) : 5.5
                            )
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.65),
                                value: vm.liveTapTimestamps.count
                            )
                    }
                }
                .frame(maxWidth: .infinity)

                ChimmoCowView(
                    isNight: palette.isNight,
                    accentColor: skyCol,
                    isAwake: vm.cradleEnabled,
                    isPlaying: reaction.cowBeatHighlight,
                    phaseTime: phaseTime,
                    gazeBias: brushNormY != nil ? -0.45 : 0.0
                )
                .frame(width: 34, height: 28)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.shelfSurface.opacity(0.65)))
        }
        .accessibilityHidden(true)
    }

    private var rhythmAndSketchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            dreamDuoReactiveHeader
            // A. 雕塑感敲节奏鼓面（无文字说明，支持 4 拍重音/次重音环震波与动态时距柱）
            VStack(spacing: 10) {
                Button {
                    if !vm.isTappingRhythm {
                        vm.startRhythmTap()
                    }
                    vm.recordRhythmDrumTap()
                    drumScale = 0.94
                    withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.6)) {
                        drumScale = 1.0
                    }
                    if !reduceMotion {
                        drumShockwaveScale = 0.85
                        drumShockwaveOpacity = 0.55
                        withAnimation(.easeOut(duration: 0.38)) {
                            drumShockwaveScale = 1.42
                            drumShockwaveOpacity = 0.0
                        }
                    }
                } label: {
                    let barMetrics = RhythmDrumAccentMapper.barVisualMetrics(timestamps: vm.liveTapTimestamps)
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(palette.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(palette.homeAnchor.opacity(0.42), lineWidth: 1.6)
                            )

                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .strokeBorder(palette.nightLampGold.opacity(drumShockwaveOpacity), lineWidth: 2.0)
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(drumShockwaveScale)
                                Circle()
                                    .strokeBorder(palette.nightLampGold.opacity(0.24), lineWidth: 1.5)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .strokeBorder(palette.homeAnchor.opacity(0.32), lineWidth: 1.2)
                                    .frame(width: 48, height: 48)
                                ChimmoCraftBadge(
                                    .drumPulse,
                                    accent: palette.nightLampGold,
                                    surface: palette.shelfSurface,
                                    size: 42
                                )
                            }

                            if barMetrics.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(0..<4, id: \.self) { idx in
                                        Circle()
                                            .fill(palette.homeAnchor.opacity(idx == 0 ? 0.55 : 0.22))
                                            .frame(width: idx == 0 ? 9 : 6.5, height: idx == 0 ? 9 : 6.5)
                                    }
                                }
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .bottom, spacing: 4) {
                                        ForEach(Array(barMetrics.enumerated()), id: \.offset) { idx, bar in
                                            let isLatest = idx == barMetrics.count - 1
                                            let barColor = bar.isDownbeat ? palette.nightLampGold : palette.homeAnchor
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(barColor.opacity(isLatest ? 1.0 : 0.70))
                                                .frame(width: bar.widthPt, height: bar.heightPt)
                                        }
                                    }
                                }
                                .padding(.trailing, 54)
                            }

                            Spacer(minLength: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if !vm.liveTapTimestamps.isEmpty {
                            Text("\(vm.liveTapTimestamps.count)")
                                .font(.caption.weight(.heavy).monospacedDigit())
                                .foregroundStyle(palette.homeAnchor)
                                .padding(.trailing, 14)
                                .padding(.bottom, 10)
                        }
                    }
                    .scaleEffect(drumScale)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    if !vm.liveTapTimestamps.isEmpty {
                        HStack(spacing: 6) {
                            if vm.liveTapTimestamps.count >= 2 {
                                Button {
                                    vm.commitRhythmTaps()
                                    dismiss()
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .padding(6)
                                        .background(Circle().fill(palette.shelfSurface))
                                        .foregroundStyle(palette.homeAnchor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("按当前节奏生成旋律")
                            }
                            Button {
                                vm.resetRhythmTaps()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption2.weight(.bold))
                                    .padding(7)
                                    .background(Circle().fill(palette.shelfSurface))
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("重敲节奏")
                        }
                        .padding(8)
                    }
                }
                .accessibilityLabel("敲击鼓面输入节奏")
                .accessibilityAction(named: "按当前节奏生成旋律") {
                    if vm.liveTapTimestamps.count >= 2 {
                        vm.commitRhythmTaps()
                        dismiss()
                    }
                }
            }

            // B. 单指画线板（虚线呼吸导引波形，零文字说明）
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(palette.divider, lineWidth: 1.2)
                        )

                    if sketchPoints.isEmpty {
                        Canvas { ctx, size in
                            let padX: CGFloat = 28
                            let w = max(1, size.width - padX * 2)
                            let midY = size.height * 0.52
                            let amp = size.height * 0.24
                            var ghost = Path()
                            let steps = 40
                            for i in 0...steps {
                                let t = Double(i) / Double(steps)
                                let x = padX + CGFloat(t) * w
                                let y = midY - CGFloat(sin(t * Double.pi * 2.0 - 0.35)) * amp
                                if i == 0 { ghost.move(to: CGPoint(x: x, y: y)) }
                                else { ghost.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            ctx.stroke(
                                ghost,
                                with: .color(palette.homeAnchor.opacity(0.32)),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 7])
                            )
                            let startPt = CGPoint(x: padX, y: midY - CGFloat(sin(-0.35)) * amp)
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: startPt.x - 5.5, y: startPt.y - 5.5, width: 11, height: 11)),
                                with: .color(palette.nightLampGold.opacity(0.75))
                            )
                        }
                        .allowsHitTesting(false)
                    } else {
                        Canvas { ctx, size in
                            var path = Path()
                            path.move(to: sketchPoints[0])
                            for pt in sketchPoints.dropFirst() {
                                path.addLine(to: pt)
                            }
                            let inkGrad = Gradient(colors: [
                                palette.homeAnchor,
                                palette.nightLampGold,
                                palette.melodyTerracotta
                            ])
                            let sPt = CGPoint(x: 0, y: size.height * 0.5)
                            let ePt = CGPoint(x: size.width, y: size.height * 0.5)
                            ctx.stroke(
                                path,
                                with: .linearGradient(
                                    Gradient(colors: [
                                        palette.homeAnchor.opacity(0.22),
                                        palette.nightLampGold.opacity(0.26),
                                        palette.melodyTerracotta.opacity(0.24)
                                    ]),
                                    startPoint: sPt,
                                    endPoint: ePt
                                ),
                                style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round)
                            )
                            ctx.stroke(
                                path,
                                with: .linearGradient(inkGrad, startPoint: sPt, endPoint: ePt),
                                style: StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round)
                            )
                            if let tip = sketchPoints.last {
                                ctx.fill(
                                    Path(ellipseIn: CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12)),
                                    with: .color(palette.nightLampGold.opacity(0.35))
                                )
                                ctx.fill(
                                    Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)),
                                    with: .color(.white.opacity(0.95))
                                )
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            sketchSize = geo.size
                            let clamped = CGPoint(
                                x: max(0, min(geo.size.width, val.location.x)),
                                y: max(0, min(geo.size.height, val.location.y))
                            )
                            if sketchPoints.isEmpty {
                                sketchPoints = [clamped]
                            } else if hypot(clamped.x - sketchPoints.last!.x, clamped.y - sketchPoints.last!.y) > 4 {
                                sketchPoints.append(clamped)
                            }
                            let normY = Double(clamped.y / max(1, geo.size.height))
                            let normX = Double(clamped.x / max(1, geo.size.width))
                            brushNormX = normX
                            brushNormY = normY
                            let brushLane = SketchPitchBrushMapper.laneIndex(
                                normalizedTopToBottomY: normY,
                                pentatonicSafe: vm.pentatonicSafe
                            )
                            let now = Date().timeIntervalSinceReferenceDate
                            if brushLane != lastBrushLane && SketchPitchBrushMapper.shouldTrigger(lastTriggerTime: lastBrushTime, now: now) {
                                lastBrushLane = brushLane
                                lastBrushTime = now
                                let lane = XylophoneLane.lane(at: brushLane)
                                let hz = vm.document.scaleMode.frequencyHz(
                                    rootMIDI: vm.document.rootMIDI,
                                    degree: lane.degree,
                                    octaveOffset: lane.octaveOffset
                                )
                                let pan = SketchPitchBrushMapper.spatialPan(normalizedX: normX)
                                vm.synth.playNote(
                                    frequency: hz,
                                    velocity: 0.34,
                                    decay: 0.58,
                                    brightness: 0.92,
                                    timbre: FeltPianoSynth.Timbre.from(voice: vm.melodyVoice),
                                    pan: pan
                                )
                                AcousticHapticsEngine.shared.playPitchTouch(
                                    laneIndex: brushLane,
                                    isHome: lane.degree == 1,
                                    isTension: lane.member.isTensionDegree
                                )
                            }
                        }
                        .onEnded { _ in
                            lastBrushLane = nil
                            lastBrushTime = 0
                            brushNormX = nil
                            brushNormY = nil
                            if sketchPoints.count < 2 && vm.liveTapTimestamps.count < 2 {
                                sketchPoints.removeAll()
                                return
                            }
                            let targetSlots = max(6, vm.liveTapTimestamps.count >= 2 ? vm.liveTapTimestamps.count : max(6, vm.document.notes.count))
                            let heights = ContourSketchSampler.sampleContour(points: sketchPoints, in: geo.size, slotCount: targetSlots)
                            if vm.liveTapTimestamps.count >= 2 {
                                vm.commitRhythmTaps(withDrawnHeights: heights)
                            } else {
                                vm.applyDrawnHillContour(heights)
                            }
                            dismiss()
                        }
                )
                .overlay(alignment: .topTrailing) {
                    if !sketchPoints.isEmpty {
                        Button {
                            sketchPoints.removeAll()
                            lastBrushLane = nil
                            lastBrushTime = 0
                            brushNormX = nil
                            brushNormY = nil
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2.weight(.bold))
                                .padding(7)
                                .background(Circle().fill(palette.shelfSurface))
                                .foregroundStyle(palette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel("重画线条")
                    }
                }
            }
            .frame(height: 138)
            .accessibilityLabel("单指绘制高低旋律线")
            .accessibilityHint("也可使用下方预设旋律弧线或进入闭眼滑音逐音录制")

            // C. 纯曲线预设起伏（2×2 矢量曲线卡，与 Tab 2 统一端珠与二字短标语法）
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(MelodyHillTemplate.allCases) { hill in
                    Button {
                        if vm.liveTapTimestamps.count >= 2 {
                            vm.commitRhythmTaps()
                        }
                        vm.applyHillTemplate(hill)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            DreamMiniHillShape(
                                profile: hill.previewProfile,
                                color: palette.homeAnchor,
                                tipColor: palette.nightLampGold
                            )
                            .frame(width: 82, height: 26)
                            Text(hill.shortLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(palette.cardSurface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hill.label)
                }
            }
        }
    }

    // MARK: - Tab 1: Audio-Reactive Hum Capture (Zero Instruction Paragraphs)

    private var forgivingHumSection: some View {
        let level = CGFloat(vm.capturePipeline.inputLevel)
        let isRec = vm.capturePipeline.isRecording
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let earTilt = isRec ? min(1.0, max(-1.0, (Double(level) - 0.14) * 1.4)) : 0.0

        return VStack(spacing: 18) {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
                ChimmoSheepView(
                    isNight: palette.isNight,
                    accentColor: skyColor,
                    isSinging: isRec && level > 0.06,
                    tiltProgress: earTilt,
                    phaseTime: reduceMotion ? 0.0 : CACurrentMediaTime(),
                    gazeBias: isRec ? 0.35 : 0.0
                )
            }
            .frame(width: 56, height: 46)

            ZStack {
                Circle()
                    .strokeBorder(
                        (isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.18),
                        lineWidth: 1.5
                    )
                    .frame(width: 148, height: 148)
                    .scaleEffect(1.0 + level * 0.25)

                Circle()
                    .fill((isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.14))
                    .frame(width: 118, height: 118)
                    .scaleEffect(1.0 + level * 0.35)

                Button {
                    if isRec {
                        vm.finishRelativeContourHum()
                        dismiss()
                    } else {
                        vm.startHumCapture()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRec ? palette.melodyTerracotta : palette.homeAnchor)
                            .frame(width: 82, height: 82)
                            .shadow(color: (isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.32), radius: 12, y: 4)

                        Image(systemName: isRec ? "stop.fill" : "mic.fill")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRec ? "停止录音" : "开始哼唱录音")
            }

            liveVocalPitchStage(isRec: isRec, level: level, trace: vm.capturePipeline.livePitchTrace)

            HStack(spacing: 14) {
                humReferenceBead(degree: 1, laneIndex: 0, voiceLabel: "试听主音 1 Do 定调")
                humReferenceBead(degree: 5, laneIndex: 4, voiceLabel: "试听属音 5 Sol 定调")
            }

            if !vm.capturePipeline.statusMessage.isEmpty {
                Text(vm.capturePipeline.statusMessage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.melodyTerracotta)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.cardSurface))
    }

    private func humReferenceBead(degree: Int, laneIndex: Int, voiceLabel: String) -> some View {
        let lane = XylophoneLane.lane(at: laneIndex)
        let col = lane.barColor(isNight: palette.isNight)
        return Button {
            vm.previewHumReference(degree: degree)
        } label: {
            HStack(spacing: 6) {
                PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIndex))
                    .frame(width: 11, height: 11)
                    .foregroundStyle(col)
                Text(lane.digitLabel)
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(palette.primaryInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(col.opacity(palette.isNight ? 0.18 : 0.12))
                    .overlay(Capsule().strokeBorder(col.opacity(0.45), lineWidth: 1.0))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceLabel)
    }

    private func liveVocalPitchStage(isRec: Bool, level: CGFloat, trace: [Double]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.shelfSurface.opacity(0.65))

            if isRec && trace.count >= 2 {
                Canvas { ctx, size in
                    let padX: CGFloat = 14
                    let padY: CGFloat = 10
                    let w = max(1, size.width - padX * 2)
                    let h = max(1, size.height - padY * 2)

                    for row in [0.25, 0.50, 0.75] {
                        let gy = padY + CGFloat(row) * h
                        var line = Path()
                        line.move(to: CGPoint(x: padX, y: gy))
                        line.addLine(to: CGPoint(x: size.width - padX, y: gy))
                        ctx.stroke(
                            line,
                            with: .color(palette.divider.opacity(0.45)),
                            style: StrokeStyle(lineWidth: 0.7, dash: [3, 4])
                        )
                    }

                    let pts: [CGPoint] = trace.enumerated().map { idx, norm in
                        let tx = CGFloat(idx) / CGFloat(max(1, trace.count - 1))
                        let clampedNorm = CGFloat(max(0.0, min(1.0, norm)))
                        return CGPoint(
                            x: padX + tx * w,
                            y: padY + (1.0 - clampedNorm) * h
                        )
                    }

                    var path = Path()
                    path.move(to: pts[0])
                    for i in 1..<pts.count {
                        let prev = pts[i - 1]
                        let cur = pts[i]
                        let mid = CGPoint(x: (prev.x + cur.x) * 0.5, y: (prev.y + cur.y) * 0.5)
                        path.addQuadCurve(to: mid, control: prev)
                        if i == pts.count - 1 {
                            path.addLine(to: cur)
                        }
                    }

                    let startPt = CGPoint(x: padX, y: size.height * 0.5)
                    let endPt = CGPoint(x: size.width - padX, y: size.height * 0.5)
                    let glowGrad = Gradient(colors: [
                        palette.homeAnchor.opacity(0.22),
                        palette.nightLampGold.opacity(0.26),
                        palette.melodyTerracotta.opacity(0.24)
                    ])
                    ctx.stroke(
                        path,
                        with: .linearGradient(glowGrad, startPoint: startPt, endPoint: endPt),
                        style: StrokeStyle(lineWidth: 8.5, lineCap: .round, lineJoin: .round)
                    )

                    let coreGrad = Gradient(colors: [
                        palette.homeAnchor,
                        palette.nightLampGold,
                        palette.melodyTerracotta
                    ])
                    ctx.stroke(
                        path,
                        with: .linearGradient(coreGrad, startPoint: startPt, endPoint: endPt),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )

                    if let tip = pts.last {
                        let outerRect = CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12)
                        let innerRect = CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)
                        ctx.fill(Path(ellipseIn: outerRect), with: .color(palette.nightLampGold.opacity(0.32)))
                        ctx.fill(Path(ellipseIn: innerRect), with: .color(.white.opacity(0.95)))
                    }
                }
            } else {
                HStack(spacing: 7) {
                    ForEach(0..<7, id: \.self) { idx in
                        let weight = 1.0 - abs(Double(idx) - 3.0) * 0.18
                        let h = isRec
                            ? max(8.0, CGFloat(8.0 + Double(level) * 34.0 * weight))
                            : CGFloat(10.0 + weight * 10.0)
                        Capsule()
                            .fill((isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(isRec ? 0.88 : 0.35))
                            .frame(width: 5, height: h)
                            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.7), value: h)
                    }
                }
            }
        }
        .frame(height: 64)
        .accessibilityHidden(true)
    }

    // MARK: - Tab 2: Compact Action Tiles + Visual Seed Bars

    private func shortMotifLabel(_ op: MotifGrowthOperation) -> String {
        switch op {
        case .climbSequence: return "升高"
        case .waterMirror: return "倒影"
        case .tearfulSuspension: return "收尾"
        case .fullFourPhrasePoem: return "扩四句"
        }
    }

    private var followAndBlankSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部三联紧凑动作卡
            HStack(spacing: 10) {
                Button {
                    showNightLampTheater = true
                } label: {
                    VStack(spacing: 8) {
                        ChimmoCraftBadge(
                            .nightLampHalo,
                            accent: Color(hex: 0xFFB84D),
                            surface: Color(hex: 0x1B244B),
                            size: 38
                        )
                        Text("闭眼滑音")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: 0xF4EBDD))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(hex: 0x121A37))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color(hex: 0xFFB84D).opacity(0.35), lineWidth: 1.0)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if !vm.followGlowActive {
                        vm.toggleFollowGlow()
                    }
                    dismiss()
                } label: {
                    VStack(spacing: 8) {
                        ChimmoCraftBadge(
                            .followBeacon,
                            accent: palette.nightLampGold,
                            surface: palette.shelfSurface,
                            size: 38
                        )
                        Text("跟灯弹")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
                }
                .buttonStyle(.plain)

                Button {
                    vm.startBlankCanvas()
                    dismiss()
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.homeAnchor.opacity(0.14))
                                .frame(width: 38, height: 38)
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.homeAnchor)
                        }
                        Text("新画布")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
                }
                .buttonStyle(.plain)
            }

            // 扩写旋律 2×2 双曲线可视变形卡片（左半虚线原曲 vs 右半彩色生长曲线）
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(MotifGrowthOperation.allCases) { op in
                    Button {
                        vm.growCurrentWithOrigami(op)
                        dismiss()
                    } label: {
                        MotifMorphPreviewCard(
                            operation: op,
                            shortTitle: shortMotifLabel(op),
                            palette: palette
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(op.label)
                    .accessibilityHint(op.philosophyNote)
                }
            }

            // 开头三音直拖彩色陶瓷音高推子（单指上下滑动实时耳返试听）
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { idx in
                        SeedPitchFaderColumn(
                            index: idx,
                            shift: $seedShifts[idx],
                            document: vm.document,
                            palette: palette
                        ) { nextShift in
                            vm.previewSeedShift(index: idx, shift: nextShift)
                        }
                    }
                }

                HStack(spacing: 8) {
                    if seedShifts != [0, 0, 0] {
                        Button {
                            seedShifts = [0, 0, 0]
                            AcousticHapticsEngine.shared.playScrubTick()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption.weight(.bold))
                                .padding(12)
                                .background(Circle().fill(palette.cardSurface))
                                .foregroundStyle(palette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("重置变奏")
                    }

                    Button {
                        let applied = seedShifts == [0, 0, 0] ? [1, -1, 2] : seedShifts
                        vm.applyMasterpieceSeedShifts(applied)
                        dismiss()
                    } label: {
                        Label("变奏", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("生成变奏")
                }
            }
        }
    }
}

private struct DreamMiniHillShape: View {
    let profile: [Double]
    let color: Color
    var tipColor: Color = .clear

    var body: some View {
        Canvas { ctx, size in
            guard profile.count > 1 else { return }
            var p = Path()
            var lastPt: CGPoint = .zero
            for (idx, h) in profile.enumerated() {
                let x = 3.0 + CGFloat(idx) / CGFloat(profile.count - 1) * max(1, size.width - 6.0)
                let y = size.height - 3.0 - CGFloat(h) * max(1, size.height - 6.0)
                let pt = CGPoint(x: x, y: y)
                if idx == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                lastPt = pt
            }
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            if tipColor != .clear {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: lastPt.x - 2.6, y: lastPt.y - 2.6, width: 5.2, height: 5.2)),
                    with: .color(tipColor)
                )
            }
        }
    }
}

private struct MotifMorphPreviewCard: View {
    let operation: MotifGrowthOperation
    let shortTitle: String
    let palette: ChimmoPalette

    var body: some View {
        let curves = MotifMorphPreviewGeometry.curves(for: operation)
        VStack(spacing: 7) {
            Canvas { ctx, size in
                let padX: CGFloat = 8
                let padY: CGFloat = 5
                let w = max(1, size.width - padX * 2)
                let h = max(1, size.height - padY * 2)

                let seedW = w * 0.34
                let morphStartX = padX + w * 0.44
                let morphW = w * 0.56

                var seedPath = Path()
                for (i, val) in curves.seedPoints.enumerated() {
                    let tx = curves.seedPoints.count > 1 ? CGFloat(i) / CGFloat(curves.seedPoints.count - 1) : 0.5
                    let px = padX + tx * seedW
                    let py = padY + CGFloat(1.0 - val) * h
                    if i == 0 { seedPath.move(to: CGPoint(x: px, y: py)) } else { seedPath.addLine(to: CGPoint(x: px, y: py)) }
                }
                ctx.stroke(
                    seedPath,
                    with: .color(palette.secondaryInk.opacity(0.48)),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: [3, 3])
                )

                var morphPath = Path()
                var endPt: CGPoint? = nil
                for (i, val) in curves.morphedPoints.enumerated() {
                    let tx = curves.morphedPoints.count > 1 ? CGFloat(i) / CGFloat(curves.morphedPoints.count - 1) : 0.5
                    let px = morphStartX + tx * morphW
                    let py = padY + CGFloat(1.0 - val) * h
                    let pt = CGPoint(x: px, y: py)
                    if i == 0 { morphPath.move(to: pt) } else { morphPath.addLine(to: pt) }
                    endPt = pt
                }
                ctx.stroke(
                    morphPath,
                    with: .color(palette.homeAnchor),
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                )

                if let tip = endPt {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: tip.x - 2.6, y: tip.y - 2.6, width: 5.2, height: 5.2)),
                        with: .color(palette.nightLampGold)
                    )
                }
            }
            .frame(height: 28)
            .accessibilityHidden(true)

            Text(shortTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.primaryInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(palette.cardSurface))
    }
}

private struct SeedPitchFaderColumn: View {
    let index: Int
    @Binding var shift: Int
    let document: MelodyDocument
    let palette: ChimmoPalette
    let onChangedShift: (Int) -> Void

    var body: some View {
        let laneIdx = SeedPitchFaderMapper.resolvedLaneIndex(document: document, noteIndex: index, shift: shift)
        let lane = XylophoneLane.lane(at: laneIdx)
        let laneCol = lane.barColor(isNight: palette.isNight)
        let normLevel = CGFloat(Double(shift + 3) / 6.0)
        let shiftText = shift == 0 ? "0" : (shift > 0 ? "+\(shift)" : "\(shift)")

        VStack(spacing: 6) {
            GeometryReader { geo in
                let trackH = max(44, geo.size.height - 16)
                let centerX = geo.size.width * 0.5
                let thumbY: CGFloat = 8 + (1.0 - normLevel) * trackH
                let fillH = max(12, CGFloat(SeedPitchFaderMapper.normalizedFillHeight(forShift: shift)) * trackH)

                ZStack {
                    // 中央归零参考刻度线
                    Capsule()
                        .fill(palette.divider)
                        .frame(width: 28, height: 1.5)
                        .position(x: centerX, y: 8 + trackH * 0.5)

                    // 轨道底槽与彩色填充条
                    Capsule()
                        .fill(palette.shelfSurface)
                        .frame(width: 10, height: trackH)
                        .position(x: centerX, y: 8 + trackH * 0.5)

                    Capsule()
                        .fill(laneCol.opacity(shift == 0 ? 0.50 : 0.85))
                        .frame(width: 10, height: fillH)
                        .position(x: centerX, y: 8 + trackH - fillH * 0.5)

                    // 7 档侧边细微刻点
                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { step in
                            Circle()
                                .fill(step == 3 ? palette.secondaryInk.opacity(0.60) : palette.secondaryInk.opacity(0.24))
                                .frame(width: step == 3 ? 3.2 : 2.0, height: step == 3 ? 3.2 : 2.0)
                            if step < 6 { Spacer(minLength: 0) }
                        }
                    }
                    .frame(height: trackH)
                    .position(x: centerX - 14, y: 8 + trackH * 0.5)

                    // 彩色窑陶滑动帽 + 色盲几何图腾
                    Circle()
                        .fill(laneCol)
                        .frame(width: 22, height: 22)
                        .overlay(
                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                                .frame(width: 9.5, height: 9.5)
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1.0))
                        .shadow(color: laneCol.opacity(0.35), radius: 4, y: 1.5)
                        .position(x: centerX, y: thumbY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let normY = Double((val.location.y - 8) / max(1, trackH))
                            let nextShift = SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: normY)
                            if nextShift != shift {
                                shift = nextShift
                                onChangedShift(nextShift)
                            }
                        }
                )
            }
            .frame(height: 86)

            Text(shiftText)
                .font(.caption2.weight(.heavy).monospacedDigit())
                .foregroundStyle(shift == 0 ? palette.secondaryInk : laneCol)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(palette.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(shift == 0 ? Color.clear : laneCol.opacity(0.45), lineWidth: 1.2)
                )
        )
        .accessibilityElement()
        .accessibilityLabel("第 \(index + 1) 音变奏")
        .accessibilityValue("\(shiftText)，\(lane.digitLabel) \(lane.solfege)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let next = min(3, shift + 1)
                if next != shift {
                    shift = next
                    onChangedShift(next)
                }
            case .decrement:
                let next = max(-3, shift - 1)
                if next != shift {
                    shift = next
                    onChangedShift(next)
                }
            @unknown default:
                break
            }
        }
    }
}
