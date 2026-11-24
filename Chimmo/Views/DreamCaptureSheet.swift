import QuartzCore
import SwiftUI

/// 咩哞 v0.36.0 「捕梦工坊」实体窑陶创作工作台（零 Emoji · 少字多可视化 · 黄铜 × 蜂蜡桦木 × 模拟 VU 声压表）
/// - 0) 节奏画室：双子响应监视窗 + 蜂蜡桦木木鼓台 + 带音阶标尺线的单指手绘声画托盘 + 2×2 窑陶浮雕山坡卡；
/// - 1) 轻哼电台：带物理黄铜指针 `AnalogHumVUMeterView`（由 `HumVUMeterKinematics` 驱动）+ Sculpted 广播麦按钮 + 内凹音高示波窗 + 1/5 定音珠；
/// - 2) 折纸工坊：夜灯剧场 / 跟灯 / 新画布硬件三联卡 + 双曲线变形成长卡 + 装入木盒的三通道声学变奏推子台。
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

    public init(vm: StudioViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
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

    private var currentTabSymbol: ChimmoCraftSymbol {
        switch modeTab {
        case 0: return .drumPulse
        case 1: return .humWave
        default: return .origamiPrism
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 12) {
                    workbenchCrownHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    workbenchModeRail
                        .padding(.horizontal, 16)

                    ScrollView {
                        VStack(spacing: 14) {
                            if modeTab == 0 {
                                rhythmAndSketchSection
                            } else if modeTab == 1 {
                                forgivingHumSection
                            } else {
                                followAndBlankSection
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 22)
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

    // MARK: - 0. Bespoke Kiln Workbench Chrome

    private var workbenchCrownHeader: some View {
        let skyCol = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let isRec = vm.capturePipeline.isRecording
        return HStack(spacing: 10) {
            HStack(spacing: 8) {
                ChimmoCraftBadge(
                    currentTabSymbol,
                    accent: palette.brassHairline,
                    surface: palette.cardSurface,
                    size: 32
                )

                Text("捕梦工坊")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)

                ChimmoEditorialPill(
                    text: isRec ? "收音中" : vm.document.scaleMode.label,
                    accent: isRec ? palette.melodyTerracotta : skyCol,
                    surface: palette.cardSurface,
                    textColor: isRec ? palette.melodyTerracotta : palette.primaryInk
                )
            }

            Spacer(minLength: 4)

            Button {
                stopActiveCaptureSessions()
                dismiss()
            } label: {
                Text("完成")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.brassHairline,
                            isActive: false,
                            cornerRadius: 17
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成创作")
        }
    }

    private var workbenchModeRail: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            HStack(spacing: 6) {
                workbenchTabButton(
                    index: 0,
                    title: "节奏画室",
                    symbol: .drumPulse,
                    accent: palette.homeAnchor
                )
                workbenchTabButton(
                    index: 1,
                    title: "轻哼电台",
                    symbol: .humWave,
                    accent: palette.nightLampGold
                )
                workbenchTabButton(
                    index: 2,
                    title: "折纸工坊",
                    symbol: .origamiPrism,
                    accent: palette.harmonyWash
                )
            }
            .padding(5)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: false)
        }
        .frame(height: 50)
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
            HStack(spacing: 6) {
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
            .frame(height: 38)
            .background(
                Group {
                    if isSelected {
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: accent,
                            isActive: true,
                            cornerRadius: 13
                        )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Tab 0: Brass Monitor + Kiln Drum Machine + Stave Parchment Sketch Pad + Curve Presets

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
                                .overlay(
                                    Circle()
                                        .strokeBorder(palette.brassHairline.opacity(active ? 0.7 : 0.22), lineWidth: 0.7)
                                )
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.65),
                                    value: vm.liveTapTimestamps.count
                                )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.cardSurface.opacity(palette.isNight ? 0.85 : 0.92))
                            .overlay(Capsule().strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.9))
                    )
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
                .padding(.vertical, 7)

                ChimmoBrassFrameAccent(palette: palette, cornerRadius: 16, showCornerPins: false)
            }
        }
        .accessibilityHidden(true)
    }

    private var rhythmAndSketchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            dreamDuoReactiveHeader
            drumMachineModule
            parchmentSketchTrayModule
            hillPresetGrid
        }
    }

    private var drumMachineModule: some View {
        let barMetrics = RhythmDrumAccentMapper.barVisualMetrics(timestamps: vm.liveTapTimestamps)
        let hasTaps = !vm.liveTapTimestamps.isEmpty

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 22)

            Button {
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
                    withAnimation(.easeOut(duration: 0.38)) {
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
                        cornerRadius: 16
                    )

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .strokeBorder(palette.nightLampGold.opacity(drumShockwaveOpacity), lineWidth: 2.2)
                                .frame(width: 60, height: 60)
                                .scaleEffect(drumShockwaveScale)
                            Circle()
                                .strokeBorder(palette.brassHairline.opacity(0.45), lineWidth: 1.4)
                                .frame(width: 58, height: 58)
                            Circle()
                                .strokeBorder(palette.homeAnchor.opacity(0.32), lineWidth: 1.1)
                                .frame(width: 48, height: 48)
                            ChimmoCraftBadge(
                                .drumPulse,
                                accent: palette.nightLampGold,
                                surface: palette.shelfSurface,
                                size: 42
                            )
                        }

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(palette.isNight ? Color(hex: 0x0B1024) : Color(hex: 0xEFE6D4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(palette.brassHairline.opacity(0.28), lineWidth: 0.9)
                                )

                            if barMetrics.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(0..<4, id: \.self) { idx in
                                        Circle()
                                            .fill(palette.homeAnchor.opacity(idx == 0 ? 0.65 : 0.28))
                                            .frame(width: idx == 0 ? 9.5 : 6.5, height: idx == 0 ? 9.5 : 6.5)
                                    }
                                }
                                .padding(.horizontal, 14)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .bottom, spacing: 4) {
                                        ForEach(Array(barMetrics.enumerated()), id: \.offset) { idx, bar in
                                            let isLatest = idx == barMetrics.count - 1
                                            let barColor = bar.isDownbeat ? palette.nightLampGold : palette.homeAnchor
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(barColor.opacity(isLatest ? 1.0 : 0.74))
                                                .frame(width: bar.widthPt, height: bar.heightPt)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                }
                                .padding(.trailing, 48)
                            }
                        }
                        .frame(height: 52)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if hasTaps {
                        Text("\(vm.liveTapTimestamps.count)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(palette.primaryInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule()
                                    .fill(palette.cardSurface)
                                    .overlay(Capsule().strokeBorder(palette.brassHairline.opacity(0.45), lineWidth: 0.8))
                            )
                            .padding(.trailing, 18)
                            .padding(.bottom, 14)
                    }
                }
                .scaleEffect(drumScale)
            }
            .buttonStyle(.plain)
            .padding(8)
            .overlay(alignment: .topTrailing) {
                if hasTaps {
                    HStack(spacing: 6) {
                        if vm.liveTapTimestamps.count >= 2 {
                            Button {
                                vm.commitRhythmTaps()
                                dismiss()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .padding(6.5)
                                    .background(
                                        Circle()
                                            .fill(palette.cardSurface)
                                            .overlay(Circle().strokeBorder(palette.homeAnchor.opacity(0.45), lineWidth: 0.9))
                                    )
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
                                .background(
                                    Circle()
                                        .fill(palette.cardSurface)
                                        .overlay(Circle().strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.8))
                                )
                                .foregroundStyle(palette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("重敲节奏")
                    }
                    .padding(14)
                }
            }
            .accessibilityLabel("敲击鼓面输入节奏")
            .accessibilityAction(named: "按当前节奏生成旋律") {
                if vm.liveTapTimestamps.count >= 2 {
                    vm.commitRhythmTaps()
                    dismiss()
                }
            }

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 22, showCornerPins: true)
        }
    }

    private var parchmentSketchTrayModule: some View {
        let staveLaneIndices = vm.pentatonicSafe ? [0, 1, 2, 4, 5] : Array(0...7)

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 22)

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [palette.recessShadow, palette.brassHairline.opacity(0.28)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.1
                                )
                        )

                    // 五声 / 八度校准标尺线 + 左缘色块锚点（零文字说教的高低视觉参考）
                    Canvas { ctx, size in
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
                                style: StrokeStyle(lineWidth: laneIdx == 0 ? 0.9 : 0.7, dash: laneIdx == 0 ? [] : [3, 5])
                            )
                            let laneCol = XylophoneLane.lane(at: laneIdx).barColor(isNight: palette.isNight)
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: padX - 4, y: y - 2.3, width: 4.6, height: 4.6)),
                                with: .color(laneCol.opacity(0.72))
                            )
                        }
                    }
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
                                with: .color(palette.homeAnchor.opacity(0.36)),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 7])
                            )
                            let startPt = CGPoint(x: padX, y: midY - CGFloat(sin(-0.35)) * amp)
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: startPt.x - 5.5, y: startPt.y - 5.5, width: 11, height: 11)),
                                with: .color(palette.nightLampGold.opacity(0.85))
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
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2.weight(.bold))
                                .padding(7)
                                .background(
                                    Circle()
                                        .fill(palette.shelfSurface)
                                        .overlay(Circle().strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.8))
                                )
                                .foregroundStyle(palette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel("重画线条")
                    }
                }
            }
            .padding(8)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 22, showCornerPins: true)
        }
        .frame(height: 152)
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hill.label)
            }
        }
    }

    // MARK: - Tab 1: Warm Analog Broadcast Console + VU Meter

    private var forgivingHumSection: some View {
        let rawLevel = vm.capturePipeline.inputLevel
        let level = CGFloat(rawLevel)
        let isRec = vm.capturePipeline.isRecording
        let vuReading = HumVUMeterKinematics.reading(inputLevel: rawLevel, isRecording: isRec)
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let earTilt = isRec ? min(1.0, max(-1.0, (Double(level) - 0.14) * 1.4)) : 0.0

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 24)

            VStack(spacing: 15) {
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

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isRec ? palette.melodyTerracotta : palette.brassHairline.opacity(0.6))
                            .frame(width: 7, height: 7)
                        Text("声压表")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(palette.cardSurface)
                            .overlay(Capsule().strokeBorder(palette.brassHairline.opacity(0.35), lineWidth: 0.9))
                    )
                }

                AnalogHumVUMeterView(
                    reading: vuReading,
                    palette: palette,
                    reduceMotion: reduceMotion
                )

                ZStack {
                    Circle()
                        .strokeBorder(
                            (isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.18),
                            lineWidth: 1.5
                        )
                        .frame(width: 132, height: 132)
                        .scaleEffect(1.0 + level * 0.22)

                    Circle()
                        .fill((isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.13))
                        .frame(width: 106, height: 106)
                        .scaleEffect(1.0 + level * 0.30)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [palette.brassHairline.opacity(0.85), palette.brassHairline.opacity(0.30)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.2
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
                        ZStack {
                            Circle()
                                .fill(isRec ? palette.melodyTerracotta : palette.homeAnchor)
                                .frame(width: 76, height: 76)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.60), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1.4
                                        )
                                )
                                .shadow(
                                    color: (isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(0.35),
                                    radius: 10,
                                    y: 3
                                )

                            Image(systemName: isRec ? "stop.fill" : "mic.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
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
            .padding(16)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 24, showCornerPins: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func humReferenceBead(degree: Int, laneIndex: Int, voiceLabel: String) -> some View {
        let lane = XylophoneLane.lane(at: laneIndex)
        let col = lane.barColor(isNight: palette.isNight)
        return Button {
            vm.previewHumReference(degree: degree)
        } label: {
            HStack(spacing: 7) {
                PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIndex))
                    .frame(width: 11, height: 11)
                    .foregroundStyle(col)
                Text(lane.digitLabel)
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(palette.primaryInk)
                Circle()
                    .fill(palette.brassHairline.opacity(0.70))
                    .frame(width: 4, height: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ChimmoKilnPillButtonSurface(
                    palette: palette,
                    accent: col,
                    isActive: false,
                    cornerRadius: 16
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceLabel)
    }

    private func liveVocalPitchStage(isRec: Bool, level: CGFloat, trace: [Double]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.isNight ? Color(hex: 0x0B1024) : Color(hex: 0xEFE6D4))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.9)
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
                            with: .color(palette.divider.opacity(0.55)),
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
                            .fill((isRec ? palette.melodyTerracotta : palette.homeAnchor).opacity(isRec ? 0.88 : 0.38))
                            .frame(width: 5, height: h)
                            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.7), value: h)
                    }
                }
            }
        }
        .frame(height: 64)
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
                    VStack(spacing: 8) {
                        ChimmoCraftBadge(
                            .nightLampHalo,
                            accent: Color(hex: 0xFFB94E),
                            surface: Color(hex: 0x1B244B),
                            size: 38
                        )
                        Text("闭眼滑音")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color(hex: 0xF5ECDD))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x172042), Color(hex: 0x0E142C)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color(hex: 0xFFB94E).opacity(0.42), lineWidth: 1.1)
                        }
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
                }
                .buttonStyle(.plain)
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
                    }
                    .buttonStyle(.plain)
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
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption.weight(.bold))
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(palette.cardSurface)
                                            .overlay(Circle().strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.9))
                                    )
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
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    Capsule()
                                        .fill(palette.homeAnchor)
                                        .overlay(
                                            Capsule().strokeBorder(palette.brassHairline.opacity(0.45), lineWidth: 1.0)
                                        )
                                )
                                .foregroundStyle(palette.isNight ? Color(hex: 0x0E142C) : .white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("生成变奏")
                    }
                }
                .padding(12)

                ChimmoBrassFrameAccent(palette: palette, cornerRadius: 20, showCornerPins: true)
            }
        }
    }
}

/// 轻哼电台模拟黄铜指针 VU 声压表（9 档刻度弧 + 拉丝黄铜摆针 + 9 段实时灯条）
private struct AnalogHumVUMeterView: View {
    let reading: HumVUMeterKinematics.MeterReading
    let palette: ChimmoPalette
    let reduceMotion: Bool

    var body: some View {
        let faceTop = palette.isNight ? Color(hex: 0x161E40) : Color(hex: 0xFBF7EE)
        let faceBottom = palette.isNight ? Color(hex: 0x101630) : Color(hex: 0xF2E9D7)
        let angle = reading.needleAngleDegrees
        let activeSegs = reading.activeSegments

        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [faceTop, faceBottom], startPoint: .top, endPoint: .bottom))

                if palette.isNight {
                    RadialGradient(
                        colors: [Color(hex: 0xFFB94E).opacity(0.18), .clear],
                        center: .bottom,
                        startRadius: 4,
                        endRadius: 90
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Canvas { ctx, size in
                    let pivot = CGPoint(x: size.width * 0.5, y: size.height - 6)
                    let radius = min(size.width * 0.40, size.height - 14)

                    // 刻度主弧线
                    var arcPath = Path()
                    arcPath.addArc(
                        center: pivot,
                        radius: radius,
                        startAngle: .degrees(-134),
                        endAngle: .degrees(-46),
                        clockwise: false
                    )
                    ctx.stroke(
                        arcPath,
                        with: .color(palette.brassHairline.opacity(0.50)),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )

                    // 9 档扇形刻度（末 2 档进入热区珊瑚色）
                    let ticks = 9
                    for i in 0..<ticks {
                        let frac = Double(i) / Double(ticks - 1)
                        let deg = -44.0 + frac * 88.0
                        let rad = (deg - 90.0) * Double.pi / 180.0
                        let rIn = radius - (i % 2 == 0 ? 7.0 : 4.5)
                        let rOut = radius + 2.0
                        let p1 = CGPoint(x: pivot.x + CGFloat(cos(rad)) * rIn, y: pivot.y + CGFloat(sin(rad)) * rIn)
                        let p2 = CGPoint(x: pivot.x + CGFloat(cos(rad)) * rOut, y: pivot.y + CGFloat(sin(rad)) * rOut)
                        var tick = Path()
                        tick.move(to: p1)
                        tick.addLine(to: p2)
                        let tickCol = i >= 7 ? palette.melodyTerracotta : palette.secondaryInk.opacity(0.75)
                        ctx.stroke(tick, with: .color(tickCol), style: StrokeStyle(lineWidth: i % 2 == 0 ? 1.5 : 1.0, lineCap: .round))
                    }

                    // 拉丝黄铜摆针
                    let needleRad = (angle - 90.0) * Double.pi / 180.0
                    let tip = CGPoint(
                        x: pivot.x + CGFloat(cos(needleRad)) * (radius - 2),
                        y: pivot.y + CGFloat(sin(needleRad)) * (radius - 2)
                    )
                    var needle = Path()
                    needle.move(to: pivot)
                    needle.addLine(to: tip)
                    let needleCol = reading.isHot ? palette.melodyTerracotta : palette.brassHairline
                    ctx.stroke(needle, with: .color(needleCol), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                    // 黄铜枢轴铆钉帽
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: pivot.x - 5.5, y: pivot.y - 5.5, width: 11, height: 11)),
                        with: .color(palette.brassHairline)
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: pivot.x - 2.2, y: pivot.y - 2.2, width: 4.4, height: 4.4)),
                        with: .color(.white.opacity(0.85))
                    )
                }
                .animation(reduceMotion ? nil : .spring(response: 0.14, dampingFraction: 0.72), value: angle)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [palette.recessShadow, palette.brassHairline.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            }
            .frame(height: 62)

            // 9 段实时灯条阵列
            HStack(spacing: 4) {
                ForEach(0..<9, id: \.self) { idx in
                    let lit = idx < activeSegs
                    let segCol: Color = idx >= 7
                        ? palette.melodyTerracotta
                        : (idx >= 5 ? palette.nightLampGold : palette.homeAnchor)
                    Capsule()
                        .fill(lit ? segCol : palette.divider.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4.5)
                }
            }
            .padding(.horizontal, 6)
        }
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

            ctx.fill(
                areaPath,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.18), .clear]),
                    startPoint: CGPoint(x: size.width * 0.5, y: 0),
                    endPoint: CGPoint(x: size.width * 0.5, y: size.height)
                )
            )
            ctx.stroke(strokePath, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            ctx.fill(
                Path(ellipseIn: CGRect(x: firstPt.x - 2.0, y: firstPt.y - 2.0, width: 4.0, height: 4.0)),
                with: .color(color.opacity(0.85))
            )
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.shelfSurface.opacity(palette.isNight ? 0.42 : 0.50))

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

        VStack(spacing: 6) {
            GeometryReader { geo in
                let trackH = max(44, geo.size.height - 16)
                let centerX = geo.size.width * 0.5
                let thumbY: CGFloat = 8 + (1.0 - normLevel) * trackH
                let fillH = max(12, CGFloat(SeedPitchFaderMapper.normalizedFillHeight(forShift: shift)) * trackH)

                ZStack {
                    // 黄铜归零中心凹槽刻度线
                    Capsule()
                        .fill(palette.brassHairline.opacity(0.50))
                        .frame(width: 28, height: 1.5)
                        .position(x: centerX, y: 8 + trackH * 0.5)

                    // 精密机加工轨槽
                    Capsule()
                        .fill(palette.isNight ? Color(hex: 0x0B1024) : Color(hex: 0xE2D5BE))
                        .overlay(Capsule().strokeBorder(palette.recessShadow, lineWidth: 0.9))
                        .frame(width: 11, height: trackH)
                        .position(x: centerX, y: 8 + trackH * 0.5)

                    Capsule()
                        .fill(laneCol.opacity(shift == 0 ? 0.55 : 0.88))
                        .frame(width: 11, height: fillH)
                        .position(x: centerX, y: 8 + trackH - fillH * 0.5)

                    // 7 档侧边细微黄铜刻点
                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { step in
                            Circle()
                                .fill(step == 3 ? palette.brassHairline.opacity(0.80) : palette.secondaryInk.opacity(0.28))
                                .frame(width: step == 3 ? 3.4 : 2.0, height: step == 3 ? 3.4 : 2.0)
                            if step < 6 { Spacer(minLength: 0) }
                        }
                    }
                    .frame(height: trackH)
                    .position(x: centerX - 15, y: 8 + trackH * 0.5)

                    // 彩色窑陶滑动帽 + 釉面亮边 + 色盲几何图腾
                    Circle()
                        .fill(laneCol)
                        .frame(width: 23, height: 23)
                        .overlay(
                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                                .frame(width: 9.5, height: 9.5)
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.85), palette.brassHairline.opacity(0.45)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                        )
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
