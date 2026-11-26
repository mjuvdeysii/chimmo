import QuartzCore
import SwiftUI

/// Tab 0 · 声场：咩哞原创活体窑陶共振工作台（双耳差频 / 无耳机等时 / 和声战栗 / 3秒轻哼同频）。
public struct ResonanceFieldView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showHumSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showBreathGuide: Bool = true
    @State private var showBurstWave: Bool = false
    @State private var burstTask: Task<Void, Never>? = nil

    // 手势交互拆解（轻点播停 / 横滑无级调频 / 长按蓄力战栗）
    @State private var orbDragStartBeat: Double? = nil
    @State private var orbMovedHorizontally: Bool = false
    @State private var orbHoldTask: Task<Void, Never>? = nil
    @State private var orbHoldEngaged: Bool = false

    public init(vm: ResonanceViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    private var bandAccent: Color {
        vm.selectedBand.accentColor(isNight: palette.isNight)
    }

    public var body: some View {
        ZStack {
            AmbientPaperBackdrop(palette: palette, accentTint: bandAccent)

            ScrollView {
                VStack(spacing: 16) {
                    topTelemetryHeader

                    bandSelectorRow

                    livingOrbStage

                    interactionGuideLine

                    primaryControlDock

                    washTextureDeck
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            if vm.focusHumGuideOnFieldAppear {
                vm.focusHumGuideOnFieldAppear = false
                showHumSheet = true
            }
        }
        .onChange(of: vm.focusHumGuideOnFieldAppear) { _, shouldOpen in
            if shouldOpen {
                vm.focusHumGuideOnFieldAppear = false
                showHumSheet = true
            }
        }
        .onChange(of: vm.frissonBurstSequence) { _, _ in
            guard !reduceMotion else { return }
            showBurstWave = true
            burstTask?.cancel()
            burstTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 650_000_000)
                if !Task.isCancelled {
                    showBurstWave = false
                }
            }
        }
        .onDisappear {
            orbHoldTask?.cancel()
            orbHoldTask = nil
            burstTask?.cancel()
            burstTask = nil
        }
        .sheet(isPresented: $showHumSheet, onDismiss: {
            if vm.isHumCapturing {
                vm.cancelHumResonance()
            }
        }) {
            HumResonanceSheet(vm: vm, palette: palette)
        }
        .sheet(isPresented: $showShareSheet) {
            ResonanceShareCardSheet(vm: vm, palette: palette)
        }
    }

    // MARK: - 1. Top Telemetry Header

    private var topTelemetryHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    ChimmoResonanceBead(size: 10, isNight: palette.isNight, tint: bandAccent)
                    Text(vm.selectedBand.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(String(format: "%.1f Hz", vm.beatHz))
                        .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
                        .foregroundStyle(bandAccent)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                let baseDesc = vm.matchedHumHz != nil
                    ? "人声基频锁频 \(Int(vm.carrierHz.rounded())) Hz"
                    : "载波 \(Int(vm.carrierHz.rounded())) Hz · \(vm.isHeadphonesConnected ? "立体声双耳" : "等时包裹")"
                Text(baseDesc)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 4)

            Button {
                vm.openNightLampSheet = true
            } label: {
                ChimmoCraftMark(
                    .nightLampHalo,
                    color: palette.isNight ? palette.nightLampGold : palette.primaryInk,
                    secondaryColor: palette.secondaryInk
                )
                .frame(width: 18, height: 18)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(palette.cardSurface)
                        .overlay(Circle().strokeBorder(palette.divider, lineWidth: 1.0))
                )
                .contentShape(Circle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel("打开闭眼夜灯零光台")
            .accessibilityHint("进入纯黑防蓝光触觉音场")

            Button {
                showBreathGuide.toggle()
                if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
            } label: {
                Image(systemName: showBreathGuide ? "lungs.fill" : "lungs")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(showBreathGuide ? palette.contrastInkOnAccent : palette.primaryInk)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(showBreathGuide ? palette.celadonAccent : palette.cardSurface)
                            .overlay(Circle().strokeBorder(showBreathGuide ? palette.celadonAccent : palette.divider, lineWidth: 1.0))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel(showBreathGuide ? "关闭呼吸引导环" : "开启 4 秒吸气 6 秒呼气引导环")
            .accessibilityHint("随声波节奏引导舒缓深呼吸")

            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(palette.cardSurface)
                            .overlay(Circle().strokeBorder(palette.divider, lineWidth: 1.0))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel("生成脑波共振纪念卡")
            .accessibilityHint("制作当前频率的离线高清纪念卡")

            Menu {
                ForEach([0, 5, 15, 30], id: \.self) { mins in
                    Button {
                        vm.setTimerMinutes(mins)
                    } label: {
                        HStack {
                            Text(mins == 0 ? "持续播放" : "\(mins) 分钟自动淡出")
                            if vm.timerMinutes == mins {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.caption.weight(.bold))
                    Text(timerPillLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(palette.primaryInk)
                .padding(.horizontal, 10)
                .frame(minHeight: 40)
                .background(
                    Capsule()
                        .fill(palette.cardSurface)
                        .overlay(Capsule().strokeBorder(palette.divider, lineWidth: 1.0))
                )
                .contentShape(Capsule())
            }
            .accessibilityLabel("定时设置，\(timerPillLabel)")
            .accessibilityHint("选择声场自动温柔淡出的时长")
        }
    }

    private var timerPillLabel: String {
        if let rem = vm.remainingSeconds, vm.isBedPlaying {
            let m = rem / 60
            let s = rem % 60
            return String(format: "%d:%02d", m, s)
        }
        return vm.timerMinutes == 0 ? "不限" : "\(vm.timerMinutes)分"
    }

    // MARK: - 2. 4-Band Quick Switcher

    private var bandSelectorRow: some View {
        HStack(spacing: 8) {
            ForEach(BrainwaveBand.allCases) { band in
                let active = vm.selectedBand == band
                let tint = band.accentColor(isNight: palette.isNight)
                Button {
                    vm.selectBand(band, autoPlay: true)
                } label: {
                    VStack(spacing: 2) {
                        Text(band.shortCode)
                            .font(.caption.weight(.heavy))
                        Text(band.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .foregroundStyle(active ? palette.contrastInkOnAccent : palette.primaryInk)
                    .background(
                        RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                            .fill(active ? tint : palette.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                            .strokeBorder(active ? tint : palette.divider, lineWidth: 1.0)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                .accessibilityLabel(band.accessibilitySummary)
                .accessibilityValue(active ? "已选中" : "")
                .accessibilityHint("切换至此脑波频段")
            }
        }
    }

    // MARK: - 3. Living Resonance Orb (Tap / Horizontal Scrub / Hold-Release Frisson)

    private var livingOrbStage: some View {
        let shouldAnimate = !reduceMotion && (vm.isBedPlaying || vm.isHoldingFrisson || showBurstWave)
        let interval = reduceMotion ? (1.0 / 15.0) : (1.0 / 60.0)
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous)

        return GeometryReader { geo in
            let w = max(200, geo.size.width)
            let orbDiameter = min(216, max(168, w * 0.56))

            TimelineView(.animation(minimumInterval: interval, paused: !shouldAnimate)) { timeline in
                let env = vm.studioVM.synth.currentAcousticEnvelope()
                let phaseTime = timeline.date.timeIntervalSinceReferenceDate
                let breath = ResonanceKinematics.breathGuidePhase(at: phaseTime, reduceMotion: reduceMotion || !shouldAnimate)
                let pulseScale = ResonanceKinematics.orbPulseScale(
                    phaseTime: phaseTime,
                    beatHz: vm.beatHz,
                    energy: env.rmsEnergy,
                    frissonCharge: vm.frissonCharge,
                    reduceMotion: reduceMotion
                )

                ZStack {
                    shape
                        .fill(palette.stageBoardSurface)

                    // 有机驻波流体光晕 + 4s/6s 舒缓呼吸环画布
                    Canvas { ctx, size in
                        let cx = size.width * 0.5
                        let cy = size.height * 0.5
                        let maxR = min(size.width, size.height) * 0.46
                        let charge = vm.frissonCharge

                        if showBreathGuide && vm.isBedPlaying && !vm.isHoldingFrisson {
                            let breathR = maxR * CGFloat(0.66 + breath.progress * 0.28)
                            let breathRect = CGRect(x: cx - breathR, y: cy - breathR, width: breathR * 2, height: breathR * 2)
                            ctx.stroke(
                                Path(ellipseIn: breathRect),
                                with: .color(palette.celadonAccent.opacity(0.28 + breath.progress * 0.16)),
                                style: StrokeStyle(lineWidth: 2.0, dash: [6, 5])
                            )
                        }

                        let segments = 88
                        for ringIdx in 0..<3 {
                            let baseRatio = 0.52 + CGFloat(ringIdx) * 0.15
                            let squeeze = CGFloat(charge) * (0.14 - CGFloat(ringIdx) * 0.02)
                            let harmonicAmp = shouldAnimate
                                ? (0.018 + env.warmthEnergy * 0.032 + env.shimmerEnergy * 0.020)
                                : 0.0
                            let lobes = Double(ringIdx + 3)

                            var ringPath = Path()
                            for step in 0...segments {
                                let theta = (Double(step) / Double(segments)) * Double.pi * 2.0
                                let waveOffset = harmonicAmp * cos(theta * lobes + phaseTime * (1.1 + Double(ringIdx) * 0.45))
                                let r = maxR * max(0.30, baseRatio - squeeze + CGFloat(waveOffset))
                                let pt = CGPoint(x: cx + CGFloat(cos(theta)) * r, y: cy + CGFloat(sin(theta)) * r)
                                if step == 0 {
                                    ringPath.move(to: pt)
                                } else {
                                    ringPath.addLine(to: pt)
                                }
                            }
                            ringPath.closeSubpath()

                            let opacity = (0.16 + Double(charge) * 0.30 + env.shimmerEnergy * 0.12) * (1.0 - Double(ringIdx) * 0.22)
                            ctx.stroke(
                                ringPath,
                                with: .color(bandAccent.opacity(opacity)),
                                style: StrokeStyle(lineWidth: ringIdx == 0 ? 2.2 : 1.4, lineCap: .round, lineJoin: .round)
                            )
                        }

                        if showBurstWave {
                            for bIdx in 0..<2 {
                                let burstR = maxR * (0.86 + CGFloat(bIdx) * 0.11)
                                ctx.stroke(
                                    Path(ellipseIn: CGRect(x: cx - burstR, y: cy - burstR, width: burstR * 2, height: burstR * 2)),
                                    with: .color(palette.nightLampGold.opacity(0.68 - Double(bIdx) * 0.24)),
                                    style: StrokeStyle(lineWidth: bIdx == 0 ? 3.2 : 2.0)
                                )
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    // 中心活体共振核心
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        bandAccent.opacity(palette.isNight ? 0.48 : 0.24),
                                        bandAccent.opacity(palette.isNight ? 0.16 : 0.08)
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: orbDiameter * 0.52
                                )
                            )
                            .frame(width: orbDiameter, height: orbDiameter)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        vm.isHoldingFrisson ? palette.nightLampGold : bandAccent.opacity(0.55),
                                        lineWidth: vm.isHoldingFrisson ? 3.0 : 1.8
                                    )
                            )

                        VStack(spacing: 8) {
                            LivingChimmoDuoBadgeView(
                                isNight: palette.isNight,
                                accentColor: bandAccent,
                                melodyActive: vm.isBedPlaying || vm.isHoldingFrisson,
                                cowAwake: vm.isBedPlaying || vm.isHoldingFrisson
                            )
                            .frame(width: 72, height: 48)
                            .accessibilityHidden(true)

                            Text(orbCenterHeadline)
                                .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
                                .foregroundStyle(palette.primaryInk)

                            Text(showBreathGuide && vm.isBedPlaying && !vm.isHoldingFrisson ? breath.label : orbCenterSubline)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(showBreathGuide && vm.isBedPlaying && !vm.isHoldingFrisson ? palette.celadonAccent : palette.secondaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .padding(.horizontal, 16)
                    }
                    .scaleEffect(pulseScale)
                    .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: vm.isHoldingFrisson)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(shape)
                .overlay(
                    shape
                        .strokeBorder(
                            vm.focusFrissonGuideOnFieldAppear ? palette.nightLampGold : palette.divider,
                            lineWidth: vm.focusFrissonGuideOnFieldAppear ? 2.0 : 1.0
                        )
                )
                .shadow(color: palette.elevationShadow(dayOpacity: 0.10, nightOpacity: 0.26), radius: 12, y: 5)
                .contentShape(shape)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            if orbDragStartBeat == nil {
                                orbDragStartBeat = vm.beatHz
                                orbMovedHorizontally = false
                                orbHoldEngaged = false
                                orbHoldTask?.cancel()
                                orbHoldTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 160_000_000)
                                    guard !Task.isCancelled, !orbMovedHorizontally, orbDragStartBeat != nil else { return }
                                    orbHoldEngaged = true
                                    vm.focusFrissonGuideOnFieldAppear = false
                                    vm.beginFrissonHold()
                                }
                            }
                            let dx = val.translation.width
                            if abs(dx) > 16 {
                                if !orbMovedHorizontally {
                                    orbMovedHorizontally = true
                                    orbHoldTask?.cancel()
                                    if orbHoldEngaged {
                                        orbHoldEngaged = false
                                        vm.cancelFrissonHold()
                                    }
                                }
                                let startB = orbDragStartBeat ?? vm.beatHz
                                let spanFraction = Double(dx / max(180.0, w))
                                let target = startB + spanFraction * 36.0
                                vm.tuneBeatFrequency(target, carrierOffsetNorm: spanFraction)
                            }
                        }
                        .onEnded { _ in
                            orbHoldTask?.cancel()
                            orbHoldTask = nil
                            let wasHold = orbHoldEngaged
                            let didScrub = orbMovedHorizontally
                            orbDragStartBeat = nil
                            orbMovedHorizontally = false
                            orbHoldEngaged = false

                            if wasHold {
                                vm.releaseFrissonHold()
                            } else if !didScrub {
                                vm.toggleBedPlayback()
                            }
                        }
                )
                .accessibilityElement()
                .accessibilityLabel("活体脑波共振球，当前 \(vm.selectedBand.title) \(String(format: "%.1f", vm.beatHz)) 赫兹")
                .accessibilityValue(vm.isBedPlaying ? "正在共振，\(vm.currentSubline)" : "已暂停")
                .accessibilityHint("轻点播停，上下调节频率，或通过转子动作触发一次颅内战栗")
                .accessibilityAdjustableAction { direction in
                    let step = vm.beatHz < 12.0 ? 0.5 : 2.0
                    switch direction {
                    case .increment:
                        vm.tuneBeatFrequency(vm.beatHz + step)
                    case .decrement:
                        vm.tuneBeatFrequency(vm.beatHz - step)
                    @unknown default:
                        break
                    }
                }
                .accessibilityAction(named: "触发一次颅内战栗") {
                    vm.releaseFrissonHold()
                }
            }
        }
        .frame(height: 278)
    }

    private var orbCenterHeadline: String {
        if vm.isHoldingFrisson {
            return "正在蓄力 \(Int((vm.frissonCharge * 100).rounded()))%"
        }
        return String(format: "%.1f Hz · %@", vm.beatHz, vm.selectedBand.shortCode)
    }

    private var orbCenterSubline: String {
        if vm.isHoldingFrisson {
            return "松手即刻绽放颅内波峰"
        }
        return vm.isBedPlaying ? vm.selectedBand.somaticHook : "轻点开启 · 按住体验战栗"
    }

    // MARK: - 4. Single-Line Clear Guide

    private var interactionGuideLine: some View {
        let copy: String = {
            if let matched = vm.matchedHumHz {
                return "已锁住你的自然声纹 \(Int(matched.rounded())) Hz · 轻点球体播停，按住不放再松手触发战栗"
            }
            if vm.focusFrissonGuideOnFieldAppear {
                return "长按上方共振球或下方战栗键约 1.5 秒再松手，感受和声瀑布从头顶敞开"
            }
            return "轻点播停 · 左右轻滑无级调频 · 长按松手触发颅内战栗"
        }()

        return Text(copy)
            .font(.caption)
            .foregroundStyle(palette.secondaryInk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 5. Clean Primary Control Dock

    private var primaryControlDock: some View {
        HStack(spacing: 12) {
            // Left: Dedicated Press-Hold-Release Frisson Trigger
            Text(vm.isHoldingFrisson ? "松手绽放" : "按住战栗")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(vm.isHoldingFrisson ? palette.contrastInkOnAccent : palette.primaryInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    Capsule()
                        .fill(vm.isHoldingFrisson ? palette.nightLampGold : palette.cardSurface)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    vm.isHoldingFrisson ? palette.nightLampGold : palette.divider,
                                    lineWidth: 1.2
                                )
                        )
                )
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !vm.isHoldingFrisson {
                                vm.beginFrissonHold()
                            }
                        }
                        .onEnded { _ in
                            vm.releaseFrissonHold()
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("颅内战栗蓄力键")
                .accessibilityHint("轻点或长按蓄力后触发和声泛音瀑布绽放")
                .accessibilityAction {
                    vm.releaseFrissonHold()
                }

            // Center: Primary Play/Stop Orb Button
            Button {
                vm.toggleBedPlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(bandAccent)
                        .frame(width: 58, height: 58)
                        .shadow(color: palette.elevationShadow(dayOpacity: 0.20, nightOpacity: 0.36), radius: 10, y: 4)
                    Image(systemName: vm.isBedPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.contrastInkOnAccent)
                }
                .frame(width: 62, height: 62)
                .contentShape(Circle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.6))
            .accessibilityLabel(vm.isBedPlaying ? "暂停脑波声场" : "播放脑波声场")
            .accessibilityHint("控制当前离线脑波声床的开始与暂停")

            // Right: 3-Second Hum Resonance Trigger
            Button {
                showHumSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "mic.fill")
                        .font(.caption.weight(.bold))
                    Text("轻哼同频")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(palette.primaryInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    Capsule()
                        .fill(palette.cardSurface)
                        .overlay(Capsule().strokeBorder(palette.celadonAccent.opacity(0.45), lineWidth: 1.2))
                )
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.3))
            .accessibilityLabel("3 秒轻哼同频按摩")
            .accessibilityHint("轻哼一声，让声波自动对齐你的声带基频")
        }
    }

    // MARK: - 6. Acoustic Wash Texture & Warmth Sliders

    private var washTextureDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: "声床质地",
                detail: vm.washKind.title,
                isNight: palette.isNight,
                tint: palette.celadonAccent
            )

            ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
                ForEach(AcousticWashKind.allCases) { kind in
                    let active = vm.washKind == kind
                    Button {
                        vm.applyWashKind(kind)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: kind.symbolName)
                                .font(.caption.weight(.bold))
                            Text(kind.title)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .foregroundStyle(active ? palette.contrastInkOnAccent : palette.primaryInk)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(
                            Capsule()
                                .fill(active ? palette.celadonAccent : palette.shelfSurface)
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                    .accessibilityLabel("\(kind.title)，\(kind.subtitle)")
                    .accessibilityValue(active ? "已选中" : "")
                    .accessibilityHint("切换脑波背景声床质地")
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("雨风声床")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryInk)
                        .frame(width: 62, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { vm.noiseGain },
                            set: { vm.updateNoiseGain($0) }
                        ),
                        in: 0.0...0.22
                    )
                    .tint(palette.celadonAccent)
                    .accessibilityLabel("暖色噪声声床音量")
                }

                HStack(spacing: 10) {
                    Text("窑陶泛音")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryInk)
                        .frame(width: 62, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { vm.overtoneWarmth },
                            set: { vm.updateOvertoneWarmth($0) }
                        ),
                        in: 0.10...1.0
                    )
                    .tint(bandAccent)
                    .accessibilityLabel("纯五度与低八度泛音温暖度")
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }
}

/// 3 秒轻哼迷走同频浮层（含拒绝麦克风权限时的零阻断常用基频快捷入口）
private struct HumResonanceSheet: View {
    @ObservedObject var vm: ResonanceViewModel
    let palette: ChimmoPalette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    LivingChimmoDuoBadgeView(
                        isNight: palette.isNight,
                        accentColor: palette.celadonAccent,
                        melodyActive: vm.isHumCapturing,
                        cowAwake: vm.isHumCapturing
                    )
                    .frame(width: 82, height: 54)
                    .accessibilityHidden(true)

                    Text(vm.isHumCapturing ? "正在倾听你的声音……" : "闭眼轻哼 3 秒，解锁你的专属频率")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .multilineTextAlignment(.center)

                    Text("不需要唱歌，也不用管音准——只需放松呼气时轻声「嗯——」一声，咩哞会锁住你声带的自然频率，生成包裹头腔的五度和鸣与脑波声床。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // 主录音操作键
                Button {
                    if vm.isHumCapturing {
                        Task {
                            await vm.finishHumResonance()
                            if vm.matchedHumHz != nil {
                                dismiss()
                            }
                        }
                    } else {
                        vm.startHumResonance()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.isHumCapturing ? "waveform.badge.checkmark" : "mic.fill")
                            .font(.body.weight(.bold))
                        Text(vm.isHumCapturing ? "停下来生成同频声场" : "开始轻哼捕捉")
                            .font(.body.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    .chimmoVinyl(
                        palette: palette,
                        tint: vm.isHumCapturing ? palette.homeAnchor : palette.celadonAccent,
                        prominent: true,
                        large: true
                    )
                )
                .accessibilityHint("再次轻点结束采集，并自动为你调出同频声波")

                if !vm.humStatusHint.isEmpty {
                    Text(vm.humStatusHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.homeAnchor)
                        .multilineTextAlignment(.center)
                }

                // 麦克风未开或安静环境直接选人声共振基频
                VStack(alignment: .leading, spacing: 10) {
                    Text("或直接套用柔和人声基频（无需开麦）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)

                    HStack(spacing: 8) {
                        fallbackRootButton(title: "低沉 136 Hz", hz: 136.1)
                        fallbackRootButton(title: "温润 174 Hz", hz: 174.0)
                        fallbackRootButton(title: "清澈 216 Hz", hz: 216.0)
                    }
                }
                .padding(14)
                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("轻哼同频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        vm.cancelHumResonance()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func fallbackRootButton(title: String, hz: Double) -> some View {
        Button {
            vm.applyFallbackVoiceRoot(hz: hz, label: title)
            dismiss()
        } label: {
            Text(title)
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(palette.primaryInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
                .background(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous).fill(palette.shelfSurface))
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
    }
}
