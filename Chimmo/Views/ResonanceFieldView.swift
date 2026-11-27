import QuartzCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Primary Acoustic Resonance Field View:
/// Interactive standing-wave vessel, matched-geometry band switcher,
/// tactile frisson charge release, hum calibration sheet, wash mixer, and async postcard export.
public struct ResonanceFieldView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette

    @Namespace private var bandNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.scenePhase) private var scenePhase

    @GestureState private var isDraggingDialGesture: Bool = false
    @State private var dragStartBeatHz: Double? = nil
    @State private var isWashSheetPresented: Bool = false
    @State private var burstStartTime: TimeInterval = 0.0
    @State private var isBurstAnimating: Bool = false
    @State private var burstStopTask: Task<Void, Never>? = nil
    @State private var accumulatedPhaseTime: Double = 0.0
    @State private var animResumeDate: Date? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var heroHzMetric: CGFloat = 46

    public init(vm: ResonanceViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    private var bandAccent: Color {
        vm.selectedBand.accentColor(isNight: palette.isNight)
    }

    private var isForegroundUnoccluded: Bool {
        scenePhase == .active
            && vm.selectedTab == .field
            && !vm.isNightLampPresented
            && !vm.isHumSheetPresented
            && !vm.isCardSharePresented
            && !isWashSheetPresented
    }

    private var isVesselAnimating: Bool {
        !reduceMotion
            && isForegroundUnoccluded
            && (vm.isResonancePlaying || vm.isFrissonCharging || isDraggingDialGesture || isBurstAnimating)
    }

    public var body: some View {
        ZStack {
            AmbientPaperBackdrop(palette: palette, tint: bandAccent, bandAccent: bandAccent)

            GeometryReader { geo in
                let compactScreen = type >= .xxLarge || geo.size.height < 540
                Group {
                    if compactScreen {
                        ScrollView(showsIndicators: false) {
                            mainColumn(availableHeight: 248)
                                .padding(.horizontal, 18)
                                .padding(.top, 10)
                                .padding(.bottom, 22)
                        }
                    } else {
                        VStack(spacing: 0) {
                            headerBar
                            if vm.isSpecimenPlaying {
                                activeSpecimenBanner
                                    .padding(.top, 8)
                            }
                            Spacer(minLength: 6)
                            heroResonanceVessel(availableHeight: max(206, min(330, geo.size.height * 0.40)))
                            Spacer(minLength: 8)
                            bandSelectorRow
                            Spacer(minLength: 10)
                            transportAndFrissonRow
                            Spacer(minLength: 10)
                            utilityStrip
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .sheet(isPresented: $isWashSheetPresented) {
            WashTextureDrawerSheet(vm: vm, palette: palette)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if isVesselAnimating && animResumeDate == nil {
                animResumeDate = Date()
            }
        }
        .onDisappear {
            burstStopTask?.cancel()
            burstStopTask = nil
            isBurstAnimating = false
            if let start = animResumeDate {
                accumulatedPhaseTime += max(0.0, Date().timeIntervalSince(start))
                animResumeDate = nil
            }
        }
        .onChange(of: isVesselAnimating) { _, animating in
            if animating {
                if animResumeDate == nil {
                    animResumeDate = Date()
                }
            } else if let start = animResumeDate {
                accumulatedPhaseTime += max(0.0, Date().timeIntervalSince(start))
                animResumeDate = nil
            }
        }
        .onChange(of: vm.frissonBurstPulse) { _, _ in
            burstStartTime = CACurrentMediaTime()
            isBurstAnimating = true
            burstStopTask?.cancel()
            burstStopTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_050_000_000)
                guard !Task.isCancelled else { return }
                isBurstAnimating = false
            }
        }
        .onChange(of: isDraggingDialGesture) { _, dragging in
            if !dragging {
                dragStartBeatHz = nil
            }
        }
    }

    @ViewBuilder
    private func mainColumn(availableHeight: CGFloat) -> some View {
        VStack(spacing: 14) {
            headerBar
            if vm.isSpecimenPlaying {
                activeSpecimenBanner
            }
            heroResonanceVessel(availableHeight: availableHeight)
            bandSelectorRow
            transportAndFrissonRow
            utilityStrip
        }
    }

    // MARK: - Active Specimen Pill (Clarifies Chamber Playback when arriving from Library MiniBar)

    private var activeSpecimenBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.caption.weight(.bold))
                .foregroundStyle(bandAccent)

            Text(String(format: String(localized: "field_specimen_banner_fmt", defaultValue: "室内乐播放中：%@"), vm.activeMasterTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryInk)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                vm.stopSpecimenPlayback()
            } label: {
                Image(systemName: "pause.circle.fill")
                    .font(.title3)
                    .foregroundStyle(bandAccent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
            .accessibilityLabel(String(localized: "action_pause_specimen", defaultValue: "暂停室乐试听"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(minHeight: 44)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.inner, tint: bandAccent)
    }

    // MARK: - 2-Corner Accessible Header

    private var headerBar: some View {
        let increased = (contrast == .increased)
        let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: false, reduceTransparency: reduceTransparency, increasedContrast: increased)
        let borderOpacity = StorybookSurfaceClarityPolicy.subtleBorderOpacity(isNight: palette.isNight, reduceTransparency: reduceTransparency, increasedContrast: increased)

        return HStack(spacing: 10) {
            routeStatusBadge

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button {
                    vm.isNightLampPresented = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(palette.cardSurface)
                            .frame(width: 44, height: 44)
                            .shadow(color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.24), radius: 5, y: 2)
                            .overlay(Circle().strokeBorder(palette.primaryInk.opacity(borderOpacity), lineWidth: borderW))
                        ChimmoCraftMark(.nightLampHalo, color: palette.nightLampGold)
                            .frame(width: 21, height: 21)
                    }
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                .accessibilityLabel(String(localized: "field_night_lamp_vo", defaultValue: "开启琥珀夜灯暗屏模式"))

                Button {
                    vm.isCardSharePresented = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(palette.cardSurface)
                            .frame(width: 44, height: 44)
                            .shadow(color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.24), radius: 5, y: 2)
                            .overlay(Circle().strokeBorder(palette.primaryInk.opacity(borderOpacity), lineWidth: borderW))
                        ChimmoCraftMark(.cardSeal, color: bandAccent)
                            .frame(width: 20, height: 20)
                    }
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                .accessibilityLabel(String(localized: "field_share_card_vo", defaultValue: "生成今日声波共振卡片"))
            }
        }
    }

    private var routeStatusBadge: some View {
        Button {
            vm.refreshHeadphonesState()
            vm.triggerTactileClick(index: vm.selectedBand.bandIndex)
        } label: {
            HStack(spacing: 8) {
                LivingChimmoDuoBadgeView(
                    isNight: palette.isNight,
                    accentColor: bandAccent,
                    melodyActive: vm.isResonancePlaying,
                    cowAwake: vm.isResonancePlaying,
                    isActiveOnScreen: isForegroundUnoccluded
                )
                .frame(width: 34, height: 22)

                HStack(spacing: 5) {
                    ChimmoCraftMark(
                        .speakerHeadphones,
                        color: vm.isHeadphonesConnected ? bandAccent : palette.secondaryInk
                    )
                    .frame(width: 14, height: 14)

                    Text(vm.pureAmbientWashOnly
                         ? String(localized: "wash_pure_badge", defaultValue: "纯自然声床")
                         : (vm.isHeadphonesConnected
                            ? String(localized: "route_headphones", defaultValue: "双耳差频")
                            : String(localized: "route_speaker", defaultValue: "外放微脉动")))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: ChimmoAffordance.minHitTarget)
            .chimmoAtelierCard(palette: palette, radius: 22, tint: vm.isHeadphonesConnected ? bandAccent : nil)
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
        .accessibilityLabel(
            vm.pureAmbientWashOnly
                ? String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲")
                : (vm.isHeadphonesConnected
                    ? String(localized: "route_headphones_vo", defaultValue: "当前已连接立体声耳机，呈现双耳差频声场")
                    : String(localized: "route_speaker_vo", defaultValue: "当前外放模式，切换柔和等时声波脉动"))
        )
        .accessibilityHint(String(localized: "route_refresh_vo_hint", defaultValue: "轻点确认当前耳机或外放输出模式"))
    }

    // MARK: - Hero Resonance Vessel

    private func heroResonanceVessel(availableHeight: CGFloat) -> some View {
        let increased = (contrast == .increased)
        let highClarity = reduceTransparency || increased
        let clampedHzSize = max(36, min(62, heroHzMetric))
        let shouldAnimate = isVesselAnimating

        return TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 60.0, paused: !shouldAnimate)) { timeline in
            let delta = shouldAnimate ? (animResumeDate.map { max(0.0, timeline.date.timeIntervalSince($0)) } ?? 0.0) : 0.0
            let now = accumulatedPhaseTime + delta
            let env = vm.isResonancePlaying ? vm.synth.currentAcousticEnvelope() : .silent
            let scale = ResonanceKinematics.orbPulseScale(
                phaseTime: now,
                beatHz: vm.beatHz,
                energy: env.rmsEnergy,
                frissonCharge: vm.frissonCharge,
                reduceMotion: reduceMotion || !shouldAnimate
            )
            let breath = ResonanceKinematics.breathGuidePhase(at: now, reduceMotion: reduceMotion || !shouldAnimate)
            let burstProgress: Double = {
                guard isBurstAnimating, burstStartTime > 0, !reduceMotion else { return 0.0 }
                let dt = CACurrentMediaTime() - burstStartTime
                return (dt >= 0 && dt < 0.95) ? dt / 0.95 : 0.0
            }()

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous)
                        .fill(highClarity ? palette.cardSurface : palette.stageBoardSurface.opacity(palette.isNight ? 0.85 : 0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous)
                                .strokeBorder(
                                    bandAccent.opacity(increased ? 0.88 : (vm.isResonancePlaying ? 0.34 : 0.18)),
                                    lineWidth: StorybookSurfaceClarityPolicy.borderLineWidth(isActive: vm.isResonancePlaying, reduceTransparency: reduceTransparency, increasedContrast: increased)
                                )
                        )
                        .shadow(color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.30), radius: 14, y: 5)

                    // Standing wave Chladni harmonic vector geometry, perimeter scrub gauge & frisson shockwave
                    Canvas { ctx, size in
                        let w = size.width
                        let h = size.height
                        let cx = w * 0.5
                        let cy = h * 0.46
                        let baseR = min(w, h) * 0.25 * scale
                        let lobes = 4 + vm.selectedBand.bandIndex * 2

                        for ring in 0..<4 {
                            let rBase = baseR + CGFloat(ring) * 18.0
                            let amp = CGFloat(4.5 - Double(ring) * 0.8) + CGFloat(env.shimmerEnergy * 4.5)
                            let phaseOffset = now * (0.45 + Double(ring) * 0.2)
                            var p = Path()
                            let steps = 96
                            for s in 0...steps {
                                let theta = CGFloat(s) / CGFloat(steps) * CGFloat.pi * 2.0
                                let wave = sin(theta * CGFloat(lobes) + CGFloat(phaseOffset)) * amp
                                let r = rBase + wave
                                let pt = CGPoint(x: cx + cos(theta) * r, y: cy + sin(theta) * r)
                                if s == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                            p.closeSubpath()
                            let alpha = (vm.isResonancePlaying ? 0.38 : 0.18) - Double(ring) * 0.06
                            ctx.stroke(p, with: .color(bandAccent.opacity(max(0.05, alpha))), lineWidth: ring == 0 ? 2.2 : 1.3)
                        }

                        if isDraggingDialGesture && !vm.pureAmbientWashOnly {
                            let gaugeR = min(min(w, h) * 0.44, baseR + 62.0)
                            let startDeg = 160.0
                            let sweepDeg = 220.0
                            let norm = ResonanceKinematics.normalizedDialPosition(forBeatHz: vm.beatHz)

                            var track = Path()
                            track.addArc(
                                center: CGPoint(x: cx, y: cy),
                                radius: gaugeR,
                                startAngle: .degrees(startDeg),
                                endAngle: .degrees(startDeg + sweepDeg),
                                clockwise: false
                            )
                            ctx.stroke(track, with: .color(bandAccent.opacity(0.20)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                            var activeArc = Path()
                            activeArc.addArc(
                                center: CGPoint(x: cx, y: cy),
                                radius: gaugeR,
                                startAngle: .degrees(startDeg),
                                endAngle: .degrees(startDeg + sweepDeg * norm),
                                clockwise: false
                            )
                            ctx.stroke(activeArc, with: .color(bandAccent.opacity(0.75)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                            for tickHz in [4.0, 8.0, 14.0] {
                                let tNorm = ResonanceKinematics.normalizedDialPosition(forBeatHz: tickHz)
                                let rad = CGFloat((startDeg + sweepDeg * tNorm) * Double.pi / 180.0)
                                let innerPt = CGPoint(x: cx + cos(rad) * (gaugeR - 4.5), y: cy + sin(rad) * (gaugeR - 4.5))
                                let outerPt = CGPoint(x: cx + cos(rad) * (gaugeR + 4.5), y: cy + sin(rad) * (gaugeR + 4.5))
                                var tick = Path()
                                tick.move(to: innerPt)
                                tick.addLine(to: outerPt)
                                ctx.stroke(tick, with: .color(palette.secondaryInk.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                            }

                            let knobRad = CGFloat((startDeg + sweepDeg * norm) * Double.pi / 180.0)
                            let knobCenter = CGPoint(x: cx + cos(knobRad) * gaugeR, y: cy + sin(knobRad) * gaugeR)
                            ctx.fill(Path(ellipseIn: CGRect(x: knobCenter.x - 5.5, y: knobCenter.y - 5.5, width: 11, height: 11)), with: .color(bandAccent))
                            ctx.fill(Path(ellipseIn: CGRect(x: knobCenter.x - 2.2, y: knobCenter.y - 2.2, width: 4.4, height: 4.4)), with: .color(palette.cardSurface))
                        }

                        if burstProgress > 0.001 && burstProgress < 1.0 {
                            let burstR = baseR * 0.65 + CGFloat(burstProgress) * min(w, h) * 0.38
                            let burstAlpha = (1.0 - burstProgress) * 0.65
                            ctx.stroke(
                                Path(ellipseIn: CGRect(x: cx - burstR, y: cy - burstR, width: burstR * 2, height: burstR * 2)),
                                with: .color(palette.nightLampGold.opacity(burstAlpha)),
                                style: StrokeStyle(lineWidth: 3.4 * (1.0 - CGFloat(burstProgress) * 0.5), lineCap: .round)
                            )
                        }

                        if vm.frissonCharge > 0.01 {
                            let chargeR = baseR * 0.72
                            var arc = Path()
                            arc.addArc(
                                center: CGPoint(x: cx, y: cy),
                                radius: chargeR,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(-90 + 360 * vm.frissonCharge),
                                clockwise: false
                            )
                            ctx.stroke(arc, with: .color(palette.nightLampGold), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))
                        }
                    }
                    .allowsHitTesting(false)

                    VStack(spacing: 6) {
                        Spacer(minLength: 10)

                        VStack(spacing: 3) {
                            Text(vm.pureAmbientWashOnly
                                 ? vm.washKind.title
                                 : String(format: "%.1f Hz", vm.beatHz))
                                .font(.system(size: vm.pureAmbientWashOnly ? max(28, clampedHzSize * 0.65) : clampedHzSize, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(palette.primaryInk)
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)

                            Text(vm.pureAmbientWashOnly
                                 ? String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲")
                                 : "\(vm.selectedBand.title) · \(vm.selectedBand.chineseSubtitle)")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(bandAccent)

                            if vm.matchedHumHz == nil && !vm.pureAmbientWashOnly {
                                Text(vm.activePreset?.title ?? String(format: String(localized: "field_carrier_fmt", defaultValue: "载波 %.0f Hz · %@"), vm.carrierHz, vm.washKind.title))
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(palette.secondaryInk)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(vm.isResonancePlaying ? bandAccent : palette.secondaryInk.opacity(0.4))
                                .frame(width: 7, height: 7)
                            Text(
                                vm.isResonancePlaying
                                    ? breath.label
                                    : (vm.pureAmbientWashOnly
                                        ? String(localized: "field_pure_wash_hint", defaultValue: "纯自然声床模式 · 轻点下方声床按钮可恢复声波脉冲")
                                        : String(localized: "field_dial_drag_hint", defaultValue: "左右轻拖表盘微调声波频率 (1.5–42 Hz)"))
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(palette.secondaryInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 14)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(minHeight: availableHeight)
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .updating($isDraggingDialGesture) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            guard !vm.pureAmbientWashOnly else { return }
                            let anchorHz = dragStartBeatHz ?? vm.beatHz
                            if dragStartBeatHz == nil {
                                dragStartBeatHz = anchorHz
                            }
                            let deltaHz = Double(value.translation.width) * 0.14
                            let next = ResonanceKinematics.clampedBeatHz(anchorHz + deltaHz)
                            let rounded = (next * 2.0).rounded() / 2.0
                            if abs(rounded - vm.beatHz) >= 0.49 {
                                vm.updateInteractiveDial(beatHz: rounded)
                            }
                        }
                        .onEnded { _ in
                            dragStartBeatHz = nil
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "field_dial_vo_label", defaultValue: "声波共鸣表盘"))
                .accessibilityValue(
                    vm.pureAmbientWashOnly
                        ? "\(vm.washKind.title)，\(String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲"))，\(vm.isResonancePlaying ? String(localized: "state_playing", defaultValue: "正在播放") : String(localized: "state_paused", defaultValue: "已暂停"))"
                        : String(
                            format: String(localized: "field_dial_vo_value", defaultValue: "%.1f 赫兹，%@，%@"),
                            vm.beatHz,
                            vm.selectedBand.title,
                            vm.isResonancePlaying ? String(localized: "state_playing", defaultValue: "正在播放") : String(localized: "state_paused", defaultValue: "已暂停")
                        )
                )
                .accessibilityAdjustableAction { dir in
                    guard !vm.pureAmbientWashOnly else { return }
                    let delta = dir == .increment ? 0.5 : -0.5
                    vm.updateInteractiveDial(beatHz: ResonanceKinematics.clampedBeatHz(vm.beatHz + delta))
                }
                .accessibilityAction(
                    named: String(localized: "field_clear_hum_vo", defaultValue: "清除个人轻哼定频")
                ) {
                    if vm.matchedHumHz != nil {
                        vm.clearMatchedHum()
                    }
                }

                // Matched Hum chip placed outside `.accessibilityElement(children: .ignore)` with a full 44x44pt VoiceOver & tap target
                if let customHz = vm.matchedHumHz {
                    HStack(spacing: 8) {
                        Text(String(format: String(localized: "field_hum_badge_fmt", defaultValue: "轻哼同频 %.0f Hz"), customHz))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(palette.primaryInk)
                            .padding(.leading, 14)

                        Button {
                            vm.clearMatchedHum()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryInk)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                        .accessibilityLabel(String(localized: "field_clear_hum_vo", defaultValue: "清除个人轻哼定频"))
                    }
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.inner, tint: bandAccent)
                }
            }
        }
    }

    // MARK: - 4-Band Kiln Selector (Adapts to 2x2 at AX1-AX5)

    @ViewBuilder
    private var bandSelectorRow: some View {
        let increased = (contrast == .increased)
        let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: false, reduceTransparency: reduceTransparency, increasedContrast: increased)
        let borderOpacity = StorybookSurfaceClarityPolicy.subtleBorderOpacity(isNight: palette.isNight, reduceTransparency: reduceTransparency, increasedContrast: increased)

        let cards = ForEach(BrainwaveBand.allCases) { band in
            let selected = (vm.selectedBand == band)
            let color = band.accentColor(isNight: palette.isNight)

            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72)) {
                    vm.selectBand(band, startPlayingIfIdle: true)
                }
            } label: {
                VStack(spacing: 2) {
                    Text(band.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(selected ? palette.contrastInkOnAccent : palette.primaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(band.chineseSubtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(selected ? palette.contrastInkOnAccent.opacity(0.92) : palette.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background {
                    ZStack {
                        if selected {
                            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                                .fill(color)
                                .matchedGeometryEffect(id: "ActiveBandPill", in: bandNamespace)
                                .shadow(color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.30), radius: 6, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                                        .strokeBorder(increased ? palette.primaryInk : Color.clear, lineWidth: increased ? 2.0 : 0)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                                .fill(palette.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                                        .strokeBorder(palette.primaryInk.opacity(borderOpacity), lineWidth: borderW)
                                )
                        }
                    }
                }
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel(String(format: String(localized: "band_pill_vo_fmt", defaultValue: "%@，%@，%@"), band.title, band.chineseSubtitle, band.hzRangeLabel))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        if type >= .xxLarge {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                cards
            }
        } else {
            HStack(spacing: 8) {
                cards
            }
        }
    }

    // MARK: - Primary Play/Pause & Frisson Charge Control

    @ViewBuilder
    private var transportAndFrissonRow: some View {
        let playButton = Button {
            vm.toggleResonancePlayback()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: vm.isResonancePlaying ? "pause.fill" : "play.fill")
                    .font(.body.weight(.bold))
                Text(vm.isResonancePlaying
                     ? String(localized: "action_pause", defaultValue: "暂停声场")
                     : String(localized: "action_start", defaultValue: "开启共鸣"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.chimmoVinyl(palette: palette, tint: bandAccent, prominent: true, large: true))
        .accessibilityLabel(vm.isResonancePlaying
                            ? String(localized: "action_pause_sound", defaultValue: "暂停声场")
                            : String(localized: "action_play_sound", defaultValue: "开启声场"))

        if type >= .xxLarge {
            VStack(spacing: 10) {
                playButton
                frissonHoldButton.frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 12) {
                playButton
                frissonHoldButton
            }
        }
    }

    @ViewBuilder
    private func frissonLabelContent(textColor: Color, active: Bool) -> some View {
        ZStack {
            Text(String(localized: "frisson_hold_btn", defaultValue: "按住释怀"))
                .opacity(0)
                .accessibilityHidden(true)
            Text(String(localized: "frisson_charging", defaultValue: "蓄力释怀..."))
                .opacity(0)
                .accessibilityHidden(true)
            Text(active
                 ? String(localized: "frisson_charging", defaultValue: "蓄力释怀...")
                 : String(localized: "frisson_hold_btn", defaultValue: "按住释怀"))
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .foregroundStyle(textColor)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    private var frissonHoldButton: some View {
        let active = vm.isFrissonCharging
        let increased = (contrast == .increased)
        let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: active, reduceTransparency: reduceTransparency, increasedContrast: increased)

        return ZStack {
            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                .fill(palette.cardSurface)
                .overlay(frissonLabelContent(textColor: palette.primaryInk, active: active))

            if vm.frissonCharge > 0.005 {
                RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                    .fill(palette.nightLampGold)
                    .overlay(frissonLabelContent(textColor: palette.contrastInkOnAccent, active: active))
                    .mask(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(width: proxy.size.width * CGFloat(max(0.0, min(1.0, vm.frissonCharge))))
                        }
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                .strokeBorder(active ? palette.nightLampGold : bandAccent.opacity(increased ? 0.90 : 0.45), lineWidth: borderW)
        )
        .frame(minWidth: 112, minHeight: 50)
        .fixedSize(horizontal: type < .xxLarge, vertical: true)
        .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous))
        .onLongPressGesture(
            minimumDuration: 1.45,
            maximumDistance: 28,
            perform: {},
            onPressingChanged: { pressing in
                if pressing {
                    vm.beginFrissonHold()
                } else {
                    vm.releaseFrissonHold()
                }
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "frisson_vo_label", defaultValue: "声学和声张力释放"))
        .accessibilityHint(String(localized: "frisson_vo_hint", defaultValue: "长按蓄力后松手，释放柔和室内乐泛音涟漪"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            vm.releaseFrissonBloom(charged: 0.88)
        }
    }

    // MARK: - Utility Strip (Hum Match + Wash Drawer + Sleep Timer)

    private var utilityStrip: some View {
        ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
            Button {
                vm.isHumSheetPresented = true
            } label: {
                HStack(spacing: 6) {
                    ChimmoCraftMark(.humWave, color: bandAccent)
                        .frame(width: 16, height: 16)
                    Text(String(localized: "field_btn_hum", defaultValue: "轻哼找同频"))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .lineLimit(type.isAccessibilitySize ? 2 : 1)
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.chimmoVinyl(palette: palette, tint: bandAccent, prominent: false))

            washMenuButton

            sleepTimerMenuButton
        }
    }

    private var washMenuButton: some View {
        let washLabel = vm.pureAmbientWashOnly
            ? String(localized: "wash_pure_badge", defaultValue: "纯自然声床")
            : vm.washKind.title

        return Button {
            isWashSheetPresented = true
        } label: {
            HStack(spacing: 6) {
                ChimmoCraftMark(.washDroplet, color: palette.secondaryInk)
                    .frame(width: 15, height: 15)
                Text(washLabel)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(type.isAccessibilitySize ? 2 : 1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: ChimmoAffordance.minHitTarget)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.inner)
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel(String(localized: "field_wash_vo", defaultValue: "调节自然声床与窑陶暖泛音"))
        .accessibilityValue(washLabel)
    }

    private var sleepTimerMenuButton: some View {
        let timerActive = (vm.sleepTimerMinutes != nil && vm.sleepRemainingSeconds > 0)
        let labelText: String = {
            if timerActive {
                let mins = max(1, (vm.sleepRemainingSeconds + 59) / 60)
                return String(format: String(localized: "field_timer_rem_fmt", defaultValue: "约 %lld 分后渐弱"), mins)
            }
            return String(localized: "field_timer_off", defaultValue: "睡眠定时")
        }()

        return Menu {
            ForEach([15, 30, 45, 60], id: \.self) { mins in
                Button {
                    vm.setSleepTimer(minutes: mins)
                } label: {
                    let title = String(format: String(localized: "timer_menu_mins_fmt", defaultValue: "%lld 分钟后渐弱停止"), mins)
                    if vm.sleepTimerMinutes == mins {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
            if vm.sleepTimerMinutes != nil {
                Divider()
                Button(role: .destructive) {
                    vm.setSleepTimer(minutes: nil)
                } label: {
                    Text(String(localized: "timer_menu_cancel", defaultValue: "取消睡眠定时"))
                }
            }
        } label: {
            HStack(spacing: 6) {
                ChimmoCraftMark(.sleepTimer, color: timerActive ? bandAccent : palette.secondaryInk)
                    .frame(width: 15, height: 15)
                Text(labelText)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(timerActive ? bandAccent : palette.primaryInk)
                    .lineLimit(type.isAccessibilitySize ? 2 : 1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: ChimmoAffordance.minHitTarget)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.inner, tint: timerActive ? bandAccent : nil)
        }
        .accessibilityLabel(String(localized: "field_timer_vo", defaultValue: "设置睡前渐弱关机定时"))
        .accessibilityValue(labelText)
    }
}

// MARK: - Live Hum Capture & Root Calibration Sheet (Observes HumCapturePipeline directly)

struct HumResonanceSheet: View {
    @ObservedObject var vm: ResonanceViewModel
    @ObservedObject var capturePipeline: HumCapturePipeline
    let palette: ChimmoPalette
    @Environment(\.dismiss) private var dismiss

    private let quickPresets: [(hz: Double, key: String, fallback: String)] = [
        (131.0, "hum_preset_low", "131 Hz 深男低音"),
        (174.0, "hum_preset_warm", "174 Hz 中性暖嗓"),
        (220.0, "hum_preset_soft", "220 Hz 柔和女声"),
        (256.0, "hum_preset_bright", "256 Hz 清亮轻声")
    ]

    var body: some View {
        let accent = vm.selectedBand.accentColor(isNight: palette.isNight)

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette, tint: accent)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "hum_sheet_intro", defaultValue: "轻轻哼 2–3 秒任意舒缓单音，本机离线采集基频后将合成器载波调谐至你的自然共鸣音高。"))
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: accent)

                        // Live Audio Waveform & Pitch Trace Meter (updates reactively via capturePipeline)
                        VStack(spacing: 10) {
                            Canvas { ctx, size in
                                let w = size.width
                                let h = size.height
                                let trace = capturePipeline.livePitchTrace
                                let midY = h * 0.5

                                var baseline = Path()
                                baseline.move(to: CGPoint(x: 10, y: midY))
                                baseline.addLine(to: CGPoint(x: w - 10, y: midY))
                                ctx.stroke(baseline, with: .color(palette.divider), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                                if trace.count >= 2 {
                                    var curve = Path()
                                    for (idx, val) in trace.enumerated() {
                                        let x = 12 + (w - 24) * CGFloat(idx) / CGFloat(max(1, trace.count - 1))
                                        let y = h - (14 + CGFloat(val) * (h - 28))
                                        if idx == 0 { curve.move(to: CGPoint(x: x, y: y)) } else { curve.addLine(to: CGPoint(x: x, y: y)) }
                                    }
                                    ctx.stroke(curve, with: .color(accent), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
                                } else {
                                    let barCount = 18
                                    let level = capturePipeline.isRecording ? capturePipeline.inputLevel : 0.08
                                    for b in 0..<barCount {
                                        let frac = CGFloat(b) / CGFloat(barCount - 1)
                                        let env = sin(frac * .pi)
                                        let bh = max(6.0, (h - 24) * CGFloat(level) * env)
                                        let bx = 14 + frac * (w - 28)
                                        let rect = CGRect(x: bx - 2.5, y: midY - bh * 0.5, width: 5, height: bh)
                                        ctx.fill(Capsule().path(in: rect), with: .color(accent.opacity(capturePipeline.isRecording ? 0.78 : 0.25)))
                                    }
                                }
                            }
                            .frame(height: 82)
                            .background(RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous).fill(palette.insetStageSurface))
                            .accessibilityHidden(true)

                            if !capturePipeline.statusMessage.isEmpty {
                                Text(capturePipeline.statusMessage)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(palette.homeAnchor)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if let msg = vm.humMatchMessage {
                                Text(msg)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(accent)
                            }

                            HStack(spacing: 10) {
                                if capturePipeline.isRecording {
                                    Button {
                                        Task {
                                            let matched = await vm.finishHumResonance()
                                            if matched {
                                                dismiss()
                                            }
                                        }
                                    } label: {
                                        Text(String(localized: "hum_btn_finish", defaultValue: "完成锁定同频"))
                                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: true))

                                    Button {
                                        vm.cancelHumCapture()
                                    } label: {
                                        Text(String(localized: "action_cancel", defaultValue: "取消"))
                                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    }
                                    .buttonStyle(.chimmoVinyl(palette: palette, tint: palette.secondaryInk, prominent: false))
                                } else {
                                    Button {
                                        vm.beginHumCalibration()
                                    } label: {
                                        Label(
                                            capturePipeline.isStartingCapture
                                                ? String(localized: "hum_btn_starting", defaultValue: "正在准备麦克风...")
                                                : String(localized: "hum_btn_start", defaultValue: "开始捕捉轻哼"),
                                            systemImage: "mic.fill"
                                        )
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: true))
                                    .disabled(capturePipeline.isStartingCapture)
                                }
                            }
                        }
                        .padding(14)
                        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "hum_quick_vocal_header", defaultValue: "常用人声定频参考（无需麦克风）"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.secondaryInk)

                            ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
                                ForEach(quickPresets, id: \.hz) { preset in
                                    Button {
                                        vm.applyQuickHumPresetHz(preset.hz)
                                        dismiss()
                                    } label: {
                                        Text(Bundle.main.localizedString(forKey: preset.key, value: preset.fallback, table: nil))
                                            .font(.system(.caption, design: .rounded).weight(.bold))
                                    }
                                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: false))
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(String(localized: "hum_sheet_title", defaultValue: "轻哼找同频"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action_done", defaultValue: "完成")) {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onDisappear {
                if capturePipeline.isRecording || capturePipeline.isStartingCapture {
                    vm.cancelHumCapture()
                }
            }
        }
    }
}

// MARK: - Async PNG Resonance Postcard Share Sheet (Single Render Pass + Stable Date)

struct ResonanceCardShareSheet: View {
    @ObservedObject var vm: ResonanceViewModel
    let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var type
    @State private var generatedDate: Date = Date()
    @State private var renderedImage: UIImage? = nil
    @State private var exportedURL: URL? = nil
    @State private var feedbackMessage: String? = nil
    @State private var isSavingPhotos: Bool = false

    private var spec: ResonanceCardExporter.Spec {
        ResonanceCardExporter.Spec(
            band: vm.selectedBand,
            beatHz: vm.beatHz,
            carrierHz: vm.carrierHz,
            washKind: vm.washKind,
            presetTitle: vm.activeMasterTitle,
            totalMinutes: vm.stats.snapshot.totalMinutes,
            isNight: palette.isNight,
            generatedDate: generatedDate,
            pureAmbientWashOnly: vm.pureAmbientWashOnly
        )
    }

    var body: some View {
        let accent = vm.selectedBand.accentColor(isNight: palette.isNight)

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette, tint: accent)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Group {
                            if let img = renderedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.36), radius: 14, y: 6)
                                    .accessibilityLabel(
                                        vm.pureAmbientWashOnly
                                            ? "\(vm.washKind.title) · \(String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲"))"
                                            : String(format: String(localized: "card_preview_vo_fmt", defaultValue: "今日共鸣明信片预览，%@ %.1f 赫兹，%@"), vm.selectedBand.title, vm.beatHz, vm.activeMasterTitle)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(palette.cardSurface)
                                    .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
                                    .overlay(ProgressView().tint(accent))
                            }
                        }
                        .frame(maxHeight: 420)

                        if let feedbackMessage {
                            Text(feedbackMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                                .multilineTextAlignment(.center)
                        }

                        actionButtons(accent: accent)
                    }
                    .padding(18)
                }
            }
            .navigationTitle(String(localized: "card_sheet_title", defaultValue: "今日共振明信片"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action_done", defaultValue: "完成")) {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .task(id: spec) {
                let currentSpec = spec
                let img = await ResonanceCardExporter.renderCardImage(spec: currentSpec)
                guard !Task.isCancelled else { return }
                renderedImage = img
                do {
                    exportedURL = try await ResonanceCardExporter.writePNGFile(
                        from: img,
                        band: currentSpec.band,
                        date: currentSpec.generatedDate
                    )
                } catch {
                    feedbackMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(accent: Color) -> some View {
        let saveBtn = Button {
            guard let img = renderedImage, !isSavingPhotos else { return }
            isSavingPhotos = true
            Task {
                do {
                    try await ResonanceCardExporter.saveImageToPhotos(img)
                    feedbackMessage = String(localized: "card_saved_ok", defaultValue: "已保存高清 PNG 明信片到手机相册")
                } catch {
                    feedbackMessage = error.localizedDescription
                }
                isSavingPhotos = false
            }
        } label: {
            Label(
                isSavingPhotos
                    ? String(localized: "card_saving", defaultValue: "保存中...")
                    : String(localized: "card_save_photos", defaultValue: "存入相册"),
                systemImage: "square.and.arrow.down"
            )
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: true))
        .disabled(renderedImage == nil || isSavingPhotos)

        let shareSlot: AnyView = {
            if let url = exportedURL {
                return AnyView(
                    ShareLink(item: url) {
                        Label(String(localized: "card_share_btn", defaultValue: "分享卡片"), systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: false))
                )
            } else {
                return AnyView(
                    Button {} label: {
                        Label(String(localized: "card_share_btn", defaultValue: "分享卡片"), systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: false))
                    .disabled(true)
                )
            }
        }()

        if type >= .xxLarge {
            VStack(spacing: 10) {
                saveBtn
                shareSlot
            }
        } else {
            HStack(spacing: 12) {
                saveBtn
                shareSlot
            }
        }
    }
}

// MARK: - Wash Texture, Unmodulated Mode & Overtone Depth Drawer Sheet

struct WashTextureDrawerSheet: View {
    @ObservedObject var vm: ResonanceViewModel
    let palette: ChimmoPalette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let accent = vm.selectedBand.accentColor(isNight: palette.isNight)
        let noisePct = Int((vm.noiseGain / 0.24 * 100.0).rounded())
        let warmthPct = Int((vm.overtoneWarmth * 100.0).rounded())

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette, tint: accent)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(vm.washKind.companionNote)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: accent)

                        ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
                            ForEach(AcousticWashKind.allCases) { kind in
                                let selected = (vm.washKind == kind)
                                Button {
                                    vm.applyWashKind(kind)
                                } label: {
                                    Text(kind.title)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                }
                                .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: selected))
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }

                        Toggle(isOn: $vm.pureAmbientWashOnly) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "wash_pure_toggle_title", defaultValue: "纯自然声床（零声波脉冲）"))
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Text(String(localized: "wash_pure_toggle_sub", defaultValue: "仅聆听棕红雨声与粉红溪风环境声床，完全关闭双耳差频与等时脉动"))
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(accent)
                        .padding(16)
                        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: vm.pureAmbientWashOnly ? accent : nil)

                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(localized: "wash_slider_noise", defaultValue: "自然声床湿度"))
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(palette.primaryInk)
                                    Spacer()
                                    Text("\(noisePct)%")
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(accent)
                                }
                                Slider(
                                    value: Binding(
                                        get: { vm.noiseGain },
                                        set: { vm.setNoiseGain($0) }
                                    ),
                                    in: 0.0...0.24
                                )
                                .tint(accent)
                                .accessibilityLabel(String(localized: "wash_slider_noise", defaultValue: "自然声床湿度"))
                                .accessibilityValue("\(noisePct)%")
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(localized: "wash_slider_warmth", defaultValue: "窑陶泛音温度"))
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(palette.primaryInk)
                                    Spacer()
                                    Text("\(warmthPct)%")
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(accent)
                                }
                                Slider(
                                    value: Binding(
                                        get: { vm.overtoneWarmth },
                                        set: { vm.setOvertoneWarmth($0) }
                                    ),
                                    in: 0.0...1.0
                                )
                                .tint(accent)
                                .accessibilityLabel(String(localized: "wash_slider_warmth", defaultValue: "窑陶泛音温度"))
                                .accessibilityValue("\(warmthPct)%")
                            }
                        }
                        .padding(16)
                        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                    }
                    .padding(18)
                }
            }
            .navigationTitle(String(localized: "wash_drawer_title", defaultValue: "自然声床与暖泛音"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action_done", defaultValue: "完成")) {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}
