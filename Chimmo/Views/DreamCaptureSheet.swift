import QuartzCore
import SwiftUI

/// 咩哞「捕梦工坊」扁平卡通 Best Kids' Book Design 绘本创作工作台（零拟物 · 零 Emoji · 深度融合 IP）：
/// - 0) 节奏画室：双子草坡监视窗 + 扁平卡通敲鼓贴纸台 + 带起伏草坡与暖墨标尺线的手绘宣纸托盘 + 2×2 平涂山坡卡；
/// - 1) 轻哼电台：由 `StorybookChoirMeterKinematics` 驱动的「七小只声浪合唱舞台」`StorybookChoirLevelStageView` + 扁平漫画广播麦 + 1/5 IP 定音贴纸；
/// - 2) 折纸工坊：夜晚星空绘本 / 跟灯 / 新画布贴纸三联卡 + 双曲线变形成长卡 + 集成七小只琴偶头像的三通道音高推子。
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
    @State private var seedShifts: [Int] = [0, 0, 0]
    @State private var showNightLampTheater: Bool = false
    @State private var lastBrushLane: Int? = nil
    @State private var lastBrushTime: Double = 0
    @State private var brushNormX: Double? = nil
    @State private var brushNormY: Double? = nil

    public init(vm: StudioViewModel, palette: ChimmoPalette, initialTab: Int = 0) {
        self.vm = vm
        self.palette = palette
        self._modeTab = State(initialValue: max(0, min(2, initialTab)))
    }

    private func stopActiveCaptureSessions(cancelRhythm: Bool = true, cancelHum: Bool = true) {
        if cancelRhythm && vm.isTappingRhythm {
            vm.cancelRhythmTap()
        }
        if cancelHum && vm.capturePipeline.isRecording {
            vm.cancelHumCapture()
        }
    }

    private func resetBrushTracking() {
        lastBrushLane = nil
        lastBrushTime = 0
        brushNormX = nil
        brushNormY = nil
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 8) {
                    workbenchUnifiedTopBar
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    ScrollView {
                        VStack(spacing: 10) {
                            if modeTab == 0 {
                                rhythmAndSketchSection
                            } else if modeTab == 1 {
                                forgivingHumSection
                            } else {
                                followAndBlankSection
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 18)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .onChange(of: modeTab) { _, newTab in
            resetBrushTracking()
            stopActiveCaptureSessions(cancelRhythm: newTab != 0, cancelHum: newTab != 1)
        }
        .onDisappear {
            resetBrushTracking()
            stopActiveCaptureSessions()
        }
        .fullScreenCover(isPresented: $showNightLampTheater) {
            NightLampTactileSheet(vm: vm) {
                dismiss()
            }
        }
    }

    // MARK: - 0. Unified Compact Top Bar (.medium Ready)

    private var workbenchUnifiedTopBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                workbenchTabButton(
                    index: 0,
                    title: "节奏",
                    symbol: .drumPulse,
                    accent: palette.homeAnchor
                )
                workbenchTabButton(
                    index: 1,
                    title: "轻哼",
                    symbol: .humWave,
                    accent: palette.nightLampGold
                )
                workbenchTabButton(
                    index: 2,
                    title: "折纸",
                    symbol: .origamiPrism,
                    accent: palette.harmonyWash
                )
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                    .fill(palette.shelfSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                            .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                    )
            )
            .frame(height: 44)

            Button {
                stopActiveCaptureSessions()
                dismiss()
            } label: {
                Text("完成")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .padding(.horizontal, 13)
                    .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.brassHairline,
                            isActive: false,
                            cornerRadius: 20
                        )
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("完成创作")
        }
        .accessibilityElement(children: .contain)
    }

    private func workbenchTabButton(
        index: Int,
        title: String,
        symbol: ChimmoCraftSymbol,
        accent: Color
    ) -> some View {
        let isSelected = modeTab == index
        return Button {
            guard modeTab != index else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                modeTab = index
            }
            AcousticHapticsEngine.shared.playScrubTick()
        } label: {
            HStack(spacing: 5) {
                ChimmoCraftMark(
                    symbol,
                    color: isSelected ? accent : palette.secondaryInk,
                    secondaryColor: (isSelected ? accent : palette.secondaryInk).opacity(0.45)
                )
                .frame(width: 14, height: 14)

                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(isSelected ? palette.primaryInk : palette.secondaryInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: StorybookAffordanceMetrics.compactToolMinHitDimension)
            .background(
                Group {
                    if isSelected {
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: accent,
                            isActive: true,
                            cornerRadius: 12
                        )
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Tab 0: Duo Monitor + Kiln Drum Machine + Stave Parchment Sketch Pad + Curve Presets

    private var dreamDuoReactiveHeader: some View {
        let skyCol = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let reaction = DreamBrushKinematics.reaction(
            brushNormalizedY: brushNormY,
            brushNormalizedX: brushNormX,
            tapCount: vm.liveTapTimestamps.count
        )
        return TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
            let phaseTime = reduceMotion ? 0.0 : CACurrentMediaTime()
            ZStack {
                ChimmoWoodResonatorTray(palette: palette, cornerRadius: 16)

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

                    HStack(spacing: 7) {
                        ForEach(0..<4, id: \.self) { idx in
                            let active = !vm.liveTapTimestamps.isEmpty && reaction.beatCycleIndex == idx
                            let isDownbeatDot = idx == 0
                            Circle()
                                .fill(
                                    active
                                        ? (isDownbeatDot ? palette.nightLampGold : palette.homeAnchor)
                                        : palette.secondaryInk.opacity(isDownbeatDot ? 0.40 : 0.22)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
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
                .padding(.vertical, 5)
            }
        }
        .accessibilityHidden(true)
    }

    private var rhythmAndSketchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            dreamDuoReactiveHeader
            drumMachineModule
            parchmentSketchTrayModule
            hillPresetGrid
        }
    }

    private var drumMachineModule: some View {
        let barMetrics = RhythmDrumAccentMapper.barVisualMetrics(timestamps: vm.liveTapTimestamps)
        let hasTaps = !vm.liveTapTimestamps.isEmpty

        return Button {
                if !vm.isTappingRhythm {
                    vm.startRhythmTap()
                }
                vm.recordRhythmDrumTap()
                drumScale = 0.965
                withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.6)) {
                    drumScale = 1.0
                }
                if !reduceMotion {
                    drumShockwaveScale = 0.85
                    drumShockwaveOpacity = 0.55
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.38)) {
                        drumShockwaveScale = 1.42
                        drumShockwaveOpacity = 0.0
                    }
                }
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ChimmoKilnPillButtonSurface(
                        palette: palette,
                        accent: palette.homeAnchor,
                        isActive: hasTaps,
                        cornerRadius: 18
                    )

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .strokeBorder(palette.nightLampGold.opacity(drumShockwaveOpacity), lineWidth: 2.4)
                                .frame(width: 56, height: 56)
                                .scaleEffect(drumShockwaveScale)
                            Circle()
                                .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.18 : 0.12), lineWidth: 1.1)
                                .frame(width: 54, height: 54)
                            Circle()
                                .strokeBorder(palette.homeAnchor.opacity(0.45), lineWidth: 1.2)
                                .frame(width: 44, height: 44)
                            ChimmoCraftBadge(
                                .drumPulse,
                                accent: palette.nightLampGold,
                                surface: palette.storybookButter,
                                size: 38
                            )
                        }

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(palette.insetStageSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 1.0)
                                )

                            if barMetrics.isEmpty {
                                HStack(spacing: 8) {
                                    ChimmoCartoonKeyBuddyView(
                                        member: .doko,
                                        outlineColor: palette.primaryInk.opacity(0.76),
                                        isSinging: false,
                                        isMinor: vm.document.scaleMode.isMinorFlavored
                                    )
                                    .frame(width: 24, height: 22)

                                    ForEach(0..<4, id: \.self) { idx in
                                        Circle()
                                            .fill(idx == 0 ? palette.nightLampGold : palette.homeAnchor.opacity(0.65))
                                            .frame(width: idx == 0 ? 10 : 7, height: idx == 0 ? 10 : 7)
                                    }
                                }
                                .padding(.horizontal, 12)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .bottom, spacing: 4) {
                                        ForEach(Array(barMetrics.enumerated()), id: \.offset) { idx, bar in
                                            let isLatest = idx == barMetrics.count - 1
                                            let barColor = bar.isDownbeat ? palette.nightLampGold : palette.homeAnchor
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(barColor.opacity(isLatest ? 1.0 : 0.85))
                                                .frame(width: bar.widthPt, height: bar.heightPt)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                }
                                .padding(.trailing, 48)
                            }
                        }
                        .frame(height: 44)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if hasTaps {
                        Text("\(vm.liveTapTimestamps.count) 拍")
                            .font(.system(.caption2, design: .rounded).weight(.heavy).monospacedDigit())
                            .foregroundStyle(palette.homeAnchor)
                            .padding(.trailing, 16)
                            .padding(.bottom, 10)
                    }
                }
                .scaleEffect(drumScale)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .overlay(alignment: .topTrailing) {
                if hasTaps {
                    HStack(spacing: 6) {
                        if vm.liveTapTimestamps.count >= 2 {
                            Button {
                                vm.commitRhythmTaps()
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(palette.cardSurface)
                                        .frame(width: 32, height: 32)
                                        .shadow(
                                            color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.22),
                                            radius: 3,
                                            y: 1.5
                                        )
                                        .overlay(
                                            Circle().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                                        )
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(palette.homeAnchor)
                                }
                                .frame(
                                    width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                    height: StorybookAffordanceMetrics.compactToolMinHitDimension
                                )
                                .contentShape(Circle())
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("按当前节奏生成旋律")
                        }
                        Button {
                            vm.resetRhythmTaps()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(palette.cardSurface)
                                    .frame(width: 32, height: 32)
                                    .shadow(
                                        color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.22),
                                        radius: 3,
                                        y: 1.5
                                    )
                                    .overlay(
                                        Circle().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                                    )
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            .frame(
                                width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                height: StorybookAffordanceMetrics.compactToolMinHitDimension
                            )
                            .contentShape(Circle())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("重敲节奏")
                    }
                    .padding(10)
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

    private var parchmentSketchTrayModule: some View {
        let staveLaneIndices = vm.pentatonicSafe ? [0, 1, 2, 4, 5] : Array(0...7)

        return GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(
                        color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.22),
                        radius: 6,
                        y: 3
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                            .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 1.0)
                    )

                // 绘本山坡剪影托底 + 五声/八度校准标尺线（消除空白，强化风景感）
                Canvas { ctx, size in
                    var meadow = Path()
                    let baseY = size.height * 0.78
                    meadow.move(to: CGPoint(x: 0, y: baseY + 6))
                    meadow.addQuadCurve(to: CGPoint(x: size.width * 0.52, y: baseY - 4), control: CGPoint(x: size.width * 0.26, y: baseY - 14))
                    meadow.addQuadCurve(to: CGPoint(x: size.width, y: baseY + 4), control: CGPoint(x: size.width * 0.78, y: baseY + 10))
                    var meadowFill = meadow
                    meadowFill.addLine(to: CGPoint(x: size.width, y: size.height))
                    meadowFill.addLine(to: CGPoint(x: 0, y: size.height))
                    meadowFill.closeSubpath()
                    ctx.fill(meadowFill, with: .color(palette.storybookHillFront.opacity(0.70)))
                    ctx.stroke(meadow, with: .color(palette.divider), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

                    let padX: CGFloat = 18
                    let padY: CGFloat = 14
                    let h = max(1, size.height - padY * 2)
                    for laneIdx in staveLaneIndices {
                        let y = padY + (1.0 - CGFloat(laneIdx) / 7.0) * h
                        var line = Path()
                        line.move(to: CGPoint(x: padX + 8, y: y))
                        line.addLine(to: CGPoint(x: size.width - padX, y: y))
                        ctx.stroke(
                            line,
                            with: .color(palette.divider.opacity(laneIdx == 0 ? 0.9 : 0.6)),
                            style: StrokeStyle(lineWidth: laneIdx == 0 ? 1.0 : 0.75, dash: laneIdx == 0 ? [] : [3, 5])
                        )
                        let laneCol = XylophoneLane.lane(at: laneIdx).barColor(isNight: palette.isNight)
                        let beadRect = CGRect(x: padX - 4, y: y - 2.6, width: 5.2, height: 5.2)
                        ctx.fill(Path(ellipseIn: beadRect), with: .color(laneCol))
                        ctx.stroke(Path(ellipseIn: beadRect), with: .color(palette.primaryInk.opacity(palette.isNight ? 0.32 : 0.24)), lineWidth: 0.9)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

                if sketchPoints.isEmpty {
                    Canvas { ctx, size in
                        let padX: CGFloat = 32
                        let w = max(1, size.width - padX * 2)
                        let midY = size.height * 0.52
                        let amp = size.height * 0.23
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
                            with: .color(palette.homeAnchor.opacity(0.55)),
                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [5, 7])
                        )
                        let startPt = CGPoint(x: padX, y: midY - CGFloat(sin(-0.35)) * amp)
                        let startRect = CGRect(x: startPt.x - 5.5, y: startPt.y - 5.5, width: 11, height: 11)
                        ctx.fill(Path(ellipseIn: startRect), with: .color(palette.nightLampGold))
                        ctx.stroke(Path(ellipseIn: startRect), with: .color(palette.primaryInk.opacity(palette.isNight ? 0.38 : 0.28)), lineWidth: 1.2)
                    }
                    .allowsHitTesting(false)
                } else {
                    Canvas { ctx, _ in
                        var path = Path()
                        path.move(to: sketchPoints[0])
                        for pt in sketchPoints.dropFirst() {
                            path.addLine(to: pt)
                        }
                        ctx.stroke(
                            path,
                            with: .color(palette.homeAnchor.opacity(palette.isNight ? 0.28 : 0.18)),
                            style: StrokeStyle(lineWidth: 7.5, lineCap: .round, lineJoin: .round)
                        )
                        ctx.stroke(
                            path,
                            with: .color(palette.homeAnchor),
                            style: StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round)
                        )
                        if let tip = sketchPoints.last {
                            let tipRect = CGRect(x: tip.x - 5.5, y: tip.y - 5.5, width: 11, height: 11)
                            ctx.fill(Path(ellipseIn: tipRect), with: .color(palette.nightLampGold))
                            ctx.stroke(Path(ellipseIn: tipRect), with: .color(palette.primaryInk.opacity(palette.isNight ? 0.38 : 0.28)), lineWidth: 1.2)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
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
                            vm.synth.ensureRunning()
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
                        resetBrushTracking()
                        guard sketchPoints.count >= 2 else {
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
                        resetBrushTracking()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(palette.cardSurface)
                                .frame(width: 32, height: 32)
                                .shadow(
                                    color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.22),
                                    radius: 3,
                                    y: 1.5
                                )
                                .overlay(
                                    Circle().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                                )
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.secondaryInk)
                        }
                        .frame(
                            width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                            height: StorybookAffordanceMetrics.compactToolMinHitDimension
                        )
                        .contentShape(Circle())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                    .padding(8)
                    .accessibilityLabel("重画线条")
                }
            }
        }
        .frame(height: 136)
        .accessibilityLabel("单指绘制高低旋律线")
        .accessibilityHint("也可使用下方预设旋律弧线或进入闭眼滑音逐音录制")
    }

    private var hillPresetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
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
                        .frame(width: 86, height: 28)

                        Text(hill.shortLabel)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.homeAnchor,
                            isActive: false,
                            cornerRadius: 16
                        )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel(hill.label)
            }
        }
    }

    // MARK: - Tab 1: Flat Cartoon Storybook Choir Stage + Comic Broadcast Mic

    private var forgivingHumSection: some View {
        let rawLevel = vm.capturePipeline.inputLevel
        let level = CGFloat(rawLevel)
        let isRec = vm.capturePipeline.isRecording
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let earTilt = isRec ? min(1.0, max(-1.0, (Double(level) - 0.14) * 1.4)) : 0.0

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 22)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
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
                    .frame(width: 46, height: 38)

                    Spacer(minLength: 4)

                    StorybookQuietTag(
                        text: isRec ? "轻哼合唱" : "准备合唱",
                        tint: isRec ? palette.melodyTerracotta : palette.homeAnchor,
                        textColor: palette.primaryInk,
                        isNight: palette.isNight
                    )
                }

                StorybookChoirLevelStageView(
                    inputLevel: rawLevel,
                    isRecording: isRec,
                    palette: palette,
                    isMinor: vm.document.scaleMode.isMinorFlavored,
                    reduceMotion: reduceMotion,
                    livePitchNormalized: vm.capturePipeline.livePitchTrace.last
                )

                ZStack {
                    Circle()
                        .strokeBorder(
                            (isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.28),
                            lineWidth: 2.0
                        )
                        .frame(width: 126, height: 126)
                        .scaleEffect(reduceMotion ? 1.0 : (1.0 + level * 0.22))

                    Circle()
                        .fill((isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.18))
                        .frame(width: 102, height: 102)
                        .scaleEffect(reduceMotion ? 1.0 : (1.0 + level * 0.30))

                    Circle()
                        .strokeBorder(
                            (isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.45),
                            lineWidth: 1.6
                        )
                        .frame(width: 88, height: 88)

                    Button {
                        if isRec {
                            vm.finishRelativeContourHum()
                            dismiss()
                        } else {
                            vm.startHumCapture()
                        }
                    } label: {
                        let micFill = isRec ? palette.melodyTerracotta : palette.prominentFill
                        ZStack {
                            Circle()
                                .fill(micFill)
                                .frame(width: 76, height: 76)
                                .shadow(
                                    color: micFill.opacity(palette.isNight ? 0.34 : 0.28),
                                    radius: 7,
                                    y: 3.5
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.2)
                                )

                            Image(systemName: isRec ? "stop.fill" : "mic.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.8))
                    .accessibilityLabel(isRec ? "停止录音" : "开始哼唱录音")
                }

                liveVocalPitchStage(isRec: isRec, level: level, trace: vm.capturePipeline.livePitchTrace)

                HStack(spacing: 12) {
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
            .padding(14)
        }
        .frame(maxWidth: .infinity)
    }

    private func humReferenceBead(degree: Int, laneIndex: Int, voiceLabel: String) -> some View {
        let lane = XylophoneLane.lane(at: laneIndex)
        let col = lane.barColor(isNight: palette.isNight)
        return Button {
            vm.previewHumReference(degree: degree)
        } label: {
            HStack(spacing: 6) {
                ChimmoCartoonKeyBuddyView(
                    member: degree == 1 ? .taono : .corllo,
                    outlineColor: palette.primaryInk.opacity(0.76),
                    isSinging: false,
                    isMinor: vm.document.scaleMode.isMinorFlavored
                )
                .frame(width: 18, height: 15)

                PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIndex))
                    .frame(width: 11, height: 11)
                    .foregroundStyle(col)

                Text(lane.digitLabel)
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(palette.primaryInk)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
            .background(
                ChimmoKilnPillButtonSurface(
                    palette: palette,
                    accent: col,
                    isActive: false,
                    cornerRadius: 20
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
        .accessibilityLabel(voiceLabel)
    }

    private func liveVocalPitchStage(isRec: Bool, level: CGFloat, trace: [Double]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.insetStageSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 1.0)
                )

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
                            with: .color(palette.divider.opacity(0.65)),
                            style: StrokeStyle(lineWidth: 0.8, dash: [3, 4])
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

                    ctx.stroke(
                        path,
                        with: .color(palette.homeAnchor.opacity(0.22)),
                        style: StrokeStyle(lineWidth: 7.0, lineCap: .round, lineJoin: .round)
                    )
                    ctx.stroke(
                        path,
                        with: .color(palette.homeAnchor),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )

                    if let tip = pts.last {
                        let tipRect = CGRect(x: tip.x - 5.0, y: tip.y - 5.0, width: 10, height: 10)
                        ctx.fill(Path(ellipseIn: tipRect), with: .color(palette.nightLampGold))
                        ctx.stroke(Path(ellipseIn: tipRect), with: .color(palette.primaryInk.opacity(0.32)), lineWidth: 1.2)
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
                            .fill((isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(isRec ? 0.95 : 0.55))
                            .overlay(Capsule().strokeBorder(palette.divider, lineWidth: 0.9))
                            .frame(width: 6, height: h)
                            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.7), value: h)
                    }
                }
            }
        }
        .frame(height: 62)
        .accessibilityHidden(true)
    }

    // MARK: - Tab 2: Origami Atelier + 3-Channel Hardware Mixer

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
            HStack(spacing: 10) {
                Button {
                    stopActiveCaptureSessions()
                    showNightLampTheater = true
                } label: {
                    let lampPalette = ChimmoPalette(isNight: true)
                    VStack(spacing: 8) {
                        ChimmoCraftBadge(
                            .nightLampHalo,
                            accent: lampPalette.nightLampGold,
                            surface: lampPalette.cardSurface,
                            size: 38
                        )
                        Text("闭眼滑音")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(lampPalette.primaryInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(lampPalette.paper)
                            .shadow(color: lampPalette.elevationShadow(dayOpacity: 0.32, nightOpacity: 0.32), radius: 5, y: 2.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(lampPalette.nightLampGold.opacity(0.55), lineWidth: 1.2)
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))

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
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.nightLampGold,
                            isActive: false,
                            cornerRadius: 18
                        )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(vm.document.notes.isEmpty)
                .opacity(vm.document.notes.isEmpty ? 0.45 : 1.0)
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))

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
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.homeAnchor,
                            isActive: false,
                            cornerRadius: 18
                        )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
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
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                    .accessibilityLabel(op.label)
                    .accessibilityHint(op.philosophyNote)
                }
            }

            ZStack {
                ChimmoWoodResonatorTray(palette: palette, cornerRadius: 20)

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
                                ZStack {
                                    Circle()
                                        .fill(palette.cardSurface)
                                        .frame(width: 40, height: 40)
                                        .shadow(
                                            color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.22),
                                            radius: 3.5,
                                            y: 1.5
                                        )
                                        .overlay(
                                            Circle().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                                        )
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(palette.secondaryInk)
                                }
                                .contentShape(Circle())
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("重置变奏")
                        }

                        Button {
                            let applied = seedShifts == [0, 0, 0] ? [1, -1, 2] : seedShifts
                            vm.applyMasterpieceSeedShifts(applied)
                            dismiss()
                        } label: {
                            Label("变奏", systemImage: "wand.and.stars")
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(palette.prominentFill)
                                            .shadow(
                                                color: palette.prominentFill.opacity(palette.isNight ? 0.32 : 0.24),
                                                radius: 5,
                                                y: 2.5
                                            )
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.32), lineWidth: 1.0)
                                    }
                                )
                                .foregroundStyle(Color.white)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.8))
                        .accessibilityLabel("生成变奏")
                    }
                }
                .padding(12)
            }
        }
    }
}

/// 轻哼电台扁平卡通「七小只声浪合唱舞台」（零拟物指针/渐变：平涂云日天际 + 七小只点头助威 + 9 座糖果音山坡）
private struct StorybookChoirLevelStageView: View {
    let inputLevel: Double
    let isRecording: Bool
    let palette: ChimmoPalette
    let isMinor: Bool
    let reduceMotion: Bool
    var livePitchNormalized: Double? = nil

    var body: some View {
        let meter = HumVUMeterKinematics.reading(inputLevel: inputLevel, isRecording: isRecording, totalSegments: 9)
        let bars = StorybookChoirMeterKinematics.hillBars(
            inputLevel: inputLevel,
            isRecording: isRecording,
            barCount: 9,
            reduceMotion: reduceMotion
        )
        let cheering = StorybookChoirMeterKinematics.cheeringBuddyIndices(
            activeSegments: meter.activeSegments,
            totalSegments: 9,
            buddyCount: ChimmoMember.allCases.count
        )
        let focusedBuddyIdx = StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(
            normalizedPitch: livePitchNormalized,
            isRecording: isRecording,
            buddyCount: ChimmoMember.allCases.count
        )
        let skyBg = palette.insetStageSurface

        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(skyBg)

            Canvas { ctx, size in
                let w = max(1, size.width)
                let outline = palette.primaryInk.opacity(palette.isNight ? 0.26 : 0.18)
                if palette.isNight {
                    let moonC = CGPoint(x: w * 0.90, y: 18)
                    var moon = Path()
                    moon.addArc(center: moonC, radius: 7.5, startAngle: .degrees(30), endAngle: .degrees(290), clockwise: false)
                    moon.addQuadCurve(
                        to: CGPoint(x: moonC.x + 7.5 * cos(30 * .pi / 180), y: moonC.y + 7.5 * sin(30 * .pi / 180)),
                        control: CGPoint(x: moonC.x - 1.5, y: moonC.y - 1)
                    )
                    ctx.fill(moon, with: .color(palette.nightLampGold))
                    ctx.stroke(moon, with: .color(outline), lineWidth: 1.0)
                } else {
                    let sunC = CGPoint(x: w * 0.91, y: 18)
                    let sun = Path(ellipseIn: CGRect(x: sunC.x - 7.5, y: sunC.y - 7.5, width: 15, height: 15))
                    ctx.fill(sun, with: .color(palette.storybookButter))
                    ctx.stroke(sun, with: .color(outline), lineWidth: 1.1)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    ForEach(Array(ChimmoMember.allCases.enumerated()), id: \.element.id) { idx, member in
                        let isCheering = cheering.contains(idx)
                        let isPitchSolo = (focusedBuddyIdx == idx)
                        let isSingingBuddy = isPitchSolo || isCheering
                        let hillPop = bars.indices.contains(idx) ? bars[idx].buddyPopOffsetY : 0.0
                        let barCol = XylophoneLane.lane(at: idx).barColor(isNight: palette.isNight)

                        VStack(spacing: 2) {
                            ZStack {
                                if isPitchSolo {
                                    Circle()
                                        .fill(barCol.opacity(palette.isNight ? 0.34 : 0.22))
                                        .frame(width: 28, height: 28)
                                }

                                ChimmoCartoonKeyBuddyView(
                                    member: member,
                                    outlineColor: palette.primaryInk.opacity(0.76),
                                    isSinging: isSingingBuddy,
                                    isMinor: isMinor
                                )
                                .frame(width: 24, height: 20)
                                .scaleEffect(reduceMotion ? 1.0 : (isPitchSolo ? 1.14 : 1.0))
                            }
                            .offset(y: reduceMotion ? 0.0 : (isPitchSolo ? -5.0 : (isCheering ? hillPop : 0.0)))
                            .animation(reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.65), value: isPitchSolo)
                            .animation(reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.65), value: isCheering)

                            Capsule()
                                .fill(isSingingBuddy ? barCol : palette.divider)
                                .frame(width: isPitchSolo ? 18 : 14, height: isPitchSolo ? 4 : 3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(bars, id: \.index) { bar in
                        let fillCol: Color = bar.isLit
                            ? (bar.isPeakZone
                                ? palette.melodyTerracotta
                                : (bar.index >= 5 ? palette.nightLampGold : palette.homeAnchor))
                            : palette.cardSurface
                        let hillH = max(7.0, CGFloat(bar.heightFraction) * 32.0)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(fillCol)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(
                                        palette.primaryInk.opacity(bar.isLit ? 0.35 : 0.12),
                                        lineWidth: bar.isLit ? 1.2 : 0.9
                                    )
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: hillH)
                            .animation(reduceMotion ? nil : .spring(response: 0.14, dampingFraction: 0.72), value: hillH)
                    }
                }
                .frame(height: 34, alignment: .bottom)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 1.0)
        }
        .frame(height: 88)
        .accessibilityHidden(true)
    }
}

private struct DreamMiniHillShape: View {
    let profile: [Double]
    let color: Color
    var tipColor: Color = .clear

    var body: some View {
        Canvas { ctx, size in
            guard profile.count > 1 else { return }
            var strokePath = Path()
            var areaPath = Path()
            var firstPt: CGPoint = .zero
            var lastPt: CGPoint = .zero
            for (idx, h) in profile.enumerated() {
                let x = 3.0 + CGFloat(idx) / CGFloat(profile.count - 1) * max(1, size.width - 6.0)
                let y = size.height - 3.0 - CGFloat(h) * max(1, size.height - 6.0)
                let pt = CGPoint(x: x, y: y)
                if idx == 0 {
                    firstPt = pt
                    strokePath.move(to: pt)
                    areaPath.move(to: CGPoint(x: x, y: size.height - 2.0))
                    areaPath.addLine(to: pt)
                } else {
                    strokePath.addLine(to: pt)
                    areaPath.addLine(to: pt)
                }
                lastPt = pt
            }
            areaPath.addLine(to: CGPoint(x: lastPt.x, y: size.height - 2.0))
            areaPath.closeSubpath()

            ctx.fill(areaPath, with: .color(color.opacity(0.22)))
            ctx.stroke(strokePath, with: .color(color), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            ctx.fill(
                Path(ellipseIn: CGRect(x: firstPt.x - 2.2, y: firstPt.y - 2.2, width: 4.4, height: 4.4)),
                with: .color(color)
            )
            if tipColor != .clear {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: lastPt.x - 2.8, y: lastPt.y - 2.8, width: 5.6, height: 5.6)),
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.shelfSurface.opacity(palette.isNight ? 0.55 : 0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(palette.divider, lineWidth: 1.0)
                    )

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
                        with: .color(palette.secondaryInk.opacity(0.52)),
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
            }
            .frame(height: 32)
            .accessibilityHidden(true)

            Text(shortTitle)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            ChimmoKilnPillButtonSurface(
                palette: palette,
                accent: palette.homeAnchor,
                isActive: false,
                cornerRadius: 16
            )
        )
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

        VStack(spacing: 5) {
            ChimmoCartoonKeyBuddyView(
                member: lane.member,
                outlineColor: palette.primaryInk.opacity(0.76),
                isSinging: shift != 0,
                isMinor: false
            )
            .frame(width: 22, height: 18)

            GeometryReader { geo in
                let trackH = max(44, geo.size.height - 16)
                let centerX = geo.size.width * 0.5
                let thumbY: CGFloat = 8 + (1.0 - normLevel) * trackH
                let fillH = max(12, CGFloat(SeedPitchFaderMapper.normalizedFillHeight(forShift: shift)) * trackH)

                ZStack {
                    Capsule()
                        .fill(palette.primaryInk.opacity(0.24))
                        .frame(width: 28, height: 1.6)
                        .position(x: centerX, y: 8 + trackH * 0.5)

                    Capsule()
                        .fill(palette.insetStageSurface)
                        .overlay(Capsule().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.16 : 0.10), lineWidth: 1.0))
                        .frame(width: 12, height: trackH)
                        .position(x: centerX, y: 8 + trackH * 0.5)

                    Capsule()
                        .fill(laneCol.opacity(shift == 0 ? 0.65 : 0.96))
                        .frame(width: 10, height: fillH)
                        .position(x: centerX, y: 8 + trackH - fillH * 0.5)

                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { step in
                            Circle()
                                .fill(step == 3 ? palette.nightLampGold : palette.primaryInk.opacity(0.24))
                                .frame(width: step == 3 ? 4.0 : 2.2, height: step == 3 ? 4.0 : 2.2)
                            if step < 6 { Spacer(minLength: 0) }
                        }
                    }
                    .frame(height: trackH)
                    .position(x: centerX - 15, y: 8 + trackH * 0.5)

                    Circle()
                        .fill(laneCol)
                        .frame(width: 23, height: 23)
                        .shadow(
                            color: palette.elevationShadow(dayOpacity: 0.16, nightOpacity: 0.28),
                            radius: 3,
                            y: 1.5
                        )
                        .overlay(
                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                                .frame(width: 9.5, height: 9.5)
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.75), lineWidth: 1.2)
                        )
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
            ChimmoKilnPillButtonSurface(
                palette: palette,
                accent: laneCol,
                isActive: shift != 0,
                cornerRadius: 15
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
