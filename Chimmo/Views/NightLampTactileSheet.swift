import QuartzCore
import SwiftUI

/// Pure OLED Night Lamp Acoustic Sanctuary:
/// Pure `#000000` OLED backdrop + ultra-dim warm amber contours + relative blind sweep (1.5–42 Hz), tap & hold bloom gestures.
public struct NightLampTactileSheet: View {
    @ObservedObject public var vm: ResonanceViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var type

    @State private var isPressingPad: Bool = false
    @State private var dragStartNorm: Double? = nil
    @State private var dragBeatPreview: Double? = nil
    @State private var didDragSweep: Bool = false
    @State private var didTriggerHoldBloom: Bool = false
    @State private var holdCharge: Double = 0.0
    @State private var holdChargeTask: Task<Void, Never>? = nil
    @State private var burstStartTime: TimeInterval = 0.0
    @State private var isBurstAnimating: Bool = false
    @State private var burstStopTask: Task<Void, Never>? = nil

    private let lampPalette = ChimmoPalette(isNight: true)
    private let amberGlow = Color(hex: 0xE89B38)
    private let amberDim = Color(hex: 0x996420)
    private let lampSurface = Color.black

    public init(vm: ResonanceViewModel) {
        self.vm = vm
    }

    private var displayedBeatHz: Double {
        dragBeatPreview ?? vm.beatHz
    }

    private var activeBand: BrainwaveBand {
        ResonanceKinematics.band(forBeatHz: displayedBeatHz)
    }

    public var body: some View {
        ZStack {
            lampPalette.nightLampBackdrop.ignoresSafeArea()

            Group {
                if type.isAccessibilitySize {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            topBar
                            sanctuaryCanvas.frame(minHeight: 300)
                            footerQuickControls
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 22)
                    }
                } else {
                    VStack(spacing: 16) {
                        topBar
                        sanctuaryCanvas
                        footerQuickControls
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            holdChargeTask?.cancel()
            holdChargeTask = nil
            burstStopTask?.cancel()
            burstStopTask = nil
            isBurstAnimating = false
            isPressingPad = false
            dragStartNorm = nil
            dragBeatPreview = nil
            holdCharge = 0.0
        }
    }

    private var topBar: some View {
        let increased = (contrast == .increased)
        let borderOpacity = increased ? 0.85 : 0.28
        let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: false, reduceTransparency: reduceTransparency, increasedContrast: increased)

        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                ChimmoCraftMark(.nightLampHalo, color: amberGlow, secondaryColor: amberDim.opacity(0.6))
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "night_lamp_title", defaultValue: "琥珀夜灯暗屏场"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(hex: 0xEFE7DC))
                    if vm.sleepTimerMinutes != nil, vm.sleepRemainingSeconds > 0 {
                        let m = Int64(vm.sleepRemainingSeconds / 60)
                        let s = Int64(vm.sleepRemainingSeconds % 60)
                        Text(String(format: String(localized: "night_lamp_timer_fmt", defaultValue: "渐弱倒计时 %02lld:%02lld"), m, s))
                            .font(.system(.caption2, design: .rounded).monospacedDigit())
                            .foregroundStyle(amberGlow.opacity(0.88))
                    } else {
                        Text(String(localized: "night_lamp_blind_hint", defaultValue: "上下滑动盲调 1.5–42 Hz · 轻点启停 · 长按释放和声"))
                            .font(.caption2)
                            .foregroundStyle(Color(hex: 0xA89F92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(lampSurface)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(amberGlow.opacity(borderOpacity), lineWidth: borderW))
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: 0xEFE7DC))
                }
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.4))
            .accessibilityLabel(String(localized: "night_lamp_close", defaultValue: "关闭琥珀夜灯"))
        }
    }

    private var sanctuaryCanvas: some View {
        let increased = (contrast == .increased)
        let borderOpacity: Double = increased ? (isPressingPad ? 0.95 : 0.65) : (isPressingPad ? 0.38 : 0.20)
        let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: isPressingPad, reduceTransparency: reduceTransparency, increasedContrast: increased)
        let ruleOpacity = increased ? 0.44 : (reduceTransparency ? 0.30 : 0.18)
        let shouldTick = !reduceMotion && (vm.isResonancePlaying || isPressingPad || isBurstAnimating)

        return GeometryReader { geo in
            let h = max(1, geo.size.height)
            let norm = ResonanceKinematics.normalizedDialPosition(forBeatHz: displayedBeatHz)

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(lampSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(amberGlow.opacity(borderOpacity), lineWidth: borderW)
                    )

                TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !shouldTick)) { timeline in
                    let t = shouldTick ? timeline.date.timeIntervalSinceReferenceDate : 0.0
                    let breatheDelta: CGFloat = (!reduceMotion && vm.isResonancePlaying) ? CGFloat(sin(t * 1.4) * 4.5) : 0.0
                    let burstProgress: Double = {
                        guard isBurstAnimating, burstStartTime > 0, !reduceMotion else { return 0.0 }
                        let dt = CACurrentMediaTime() - burstStartTime
                        return (dt >= 0 && dt < 0.95) ? dt / 0.95 : 0.0
                    }()

                    Canvas { ctx, size in
                        let cw = size.width
                        let ch = size.height
                        let indicatorY = ch * (1.0 - (0.14 + norm * 0.72))

                        for stepIdx in 1...3 {
                            let frac = CGFloat(stepIdx) / 4.0
                            let ly = ch * (1.0 - (0.14 + frac * 0.72))
                            var rule = Path()
                            rule.move(to: CGPoint(x: 28, y: ly))
                            rule.addLine(to: CGPoint(x: cw - 28, y: ly))
                            ctx.stroke(rule, with: .color(amberDim.opacity(ruleOpacity)), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                        }

                        let ringR: CGFloat = ((!reduceMotion && isPressingPad) ? 82 : 72) + breatheDelta
                        let beaconCenter = CGPoint(x: cw * 0.5, y: indicatorY)
                        for mult in [1.0, 1.42] as [CGFloat] {
                            let r = ringR * mult
                            let rect = CGRect(x: beaconCenter.x - r, y: beaconCenter.y - r, width: r * 2, height: r * 2)
                            ctx.stroke(
                                Path(ellipseIn: rect),
                                with: .color(amberGlow.opacity(mult == 1.0 ? 0.34 : 0.14)),
                                lineWidth: mult == 1.0 ? 2.0 : 1.2
                            )
                        }

                        if holdCharge > 0.01 {
                            let chargeR = ringR * 0.84
                            var arc = Path()
                            arc.addArc(
                                center: beaconCenter,
                                radius: chargeR,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(-90 + 360 * min(1.0, holdCharge)),
                                clockwise: false
                            )
                            ctx.stroke(arc, with: .color(amberGlow.opacity(0.85)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                        }

                        if burstProgress > 0.001 && burstProgress < 1.0 {
                            let burstR = ringR * 0.65 + CGFloat(burstProgress) * min(cw, ch) * 0.42
                            let burstAlpha = (1.0 - burstProgress) * 0.68
                            ctx.stroke(
                                Path(ellipseIn: CGRect(x: beaconCenter.x - burstR, y: beaconCenter.y - burstR, width: burstR * 2, height: burstR * 2)),
                                with: .color(amberGlow.opacity(burstAlpha)),
                                style: StrokeStyle(lineWidth: 3.0 * (1.0 - CGFloat(burstProgress) * 0.45), lineCap: .round)
                            )
                        }

                        let profile = KilnLandscapeGeometry.rollingHillProfile(sampleCount: 14, amplitude: 0.14, phaseShift: 0.9)
                        if let first = profile.first {
                            var ridge = Path()
                            ridge.move(to: CGPoint(x: CGFloat(first.xFraction) * cw, y: ch * 0.88 + CGFloat(first.yFraction - 0.5) * 24))
                            for pt in profile.dropFirst() {
                                ridge.addLine(to: CGPoint(x: CGFloat(pt.xFraction) * cw, y: ch * 0.88 + CGFloat(pt.yFraction - 0.5) * 24))
                            }
                            ctx.stroke(ridge, with: .color(amberDim.opacity(0.28)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .allowsHitTesting(false)
                }

                VStack(spacing: 10) {
                    ChimmoDuoBadgeView(
                        isNight: true,
                        accentColor: amberGlow,
                        melodyActive: vm.isResonancePlaying,
                        cowAwake: vm.isResonancePlaying
                    )
                    .frame(width: 58, height: 36)
                    .colorMultiply(Color(hex: 0xC88A3B))
                    .opacity(0.62)

                    Text(vm.pureAmbientWashOnly
                         ? vm.washKind.title
                         : String(format: "%.1f Hz", displayedBeatHz))
                        .font(.system(type.isAccessibilitySize ? .title : .largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(amberGlow)

                    Text(vm.pureAmbientWashOnly
                         ? String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲")
                         : "\(activeBand.title) · \(activeBand.chineseSubtitle)")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color(hex: 0xDED3C3))

                    Text(vm.isResonancePlaying
                         ? String(localized: "night_lamp_playing_state", defaultValue: "柔和共鸣中 · 轻点暂停")
                         : String(localized: "night_lamp_paused_state", defaultValue: "已静息 · 轻点开启夜灯声场"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(hex: 0xA89F92))
                        .padding(.top, 4)
                }
                .padding(20)
                .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressingPad {
                            isPressingPad = true
                            didDragSweep = false
                            didTriggerHoldBloom = false
                            dragStartNorm = ResonanceKinematics.normalizedDialPosition(forBeatHz: vm.beatHz)
                            holdCharge = 0.0
                            holdChargeTask?.cancel()
                            holdChargeTask = Task { @MainActor in
                                let startMono = CACurrentMediaTime()
                                while isPressingPad && !didDragSweep && !didTriggerHoldBloom && !Task.isCancelled {
                                    let elapsed = CACurrentMediaTime() - startMono
                                    let progress = min(1.0, elapsed / 0.65)
                                    holdCharge = progress
                                    if progress >= 1.0 {
                                        didTriggerHoldBloom = true
                                        holdCharge = 0.0
                                        vm.releaseFrissonBloom(charged: 0.78)
                                        burstStartTime = CACurrentMediaTime()
                                        isBurstAnimating = true
                                        burstStopTask?.cancel()
                                        burstStopTask = Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 950_000_000)
                                            guard !Task.isCancelled else { return }
                                            isBurstAnimating = false
                                        }
                                        return
                                    }
                                    try? await Task.sleep(nanoseconds: 30_000_000)
                                }
                            }
                        }

                        let dist = hypot(value.translation.width, value.translation.height)
                        if dist > 12 {
                            if !didDragSweep {
                                didDragSweep = true
                                holdChargeTask?.cancel()
                                holdChargeTask = nil
                                holdCharge = 0.0
                            }
                            if !didTriggerHoldBloom && !vm.pureAmbientWashOnly {
                                let baseNorm = dragStartNorm ?? ResonanceKinematics.normalizedDialPosition(forBeatHz: vm.beatHz)
                                let deltaNorm = Double(-value.translation.height) / max(120.0, Double(h) * 0.72)
                                let nextNorm = max(0.0, min(1.0, baseNorm + deltaNorm))
                                let nextHz = ResonanceKinematics.beatHz(forNormalizedDialPosition: nextNorm)
                                dragBeatPreview = nextHz
                                if abs(nextHz - vm.beatHz) >= 0.49 {
                                    vm.updateInteractiveDial(beatHz: nextHz)
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        holdChargeTask?.cancel()
                        holdChargeTask = nil
                        holdCharge = 0.0
                        let shouldToggle = !didDragSweep && !didTriggerHoldBloom
                        isPressingPad = false
                        dragStartNorm = nil
                        dragBeatPreview = nil
                        didDragSweep = false
                        didTriggerHoldBloom = false
                        if shouldToggle {
                            vm.toggleResonancePlayback()
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "night_lamp_pad_vo_label", defaultValue: "夜灯触觉声场盘"))
            .accessibilityValue(
                vm.pureAmbientWashOnly
                    ? "\(vm.washKind.title)，\(String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲"))，\(vm.isResonancePlaying ? String(localized: "state_playing", defaultValue: "正在播放") : String(localized: "state_paused", defaultValue: "已暂停"))"
                    : String(
                        format: String(localized: "night_lamp_pad_vo_value", defaultValue: "%.1f 赫兹，%@，%@"),
                        displayedBeatHz,
                        activeBand.title,
                        vm.isResonancePlaying ? String(localized: "state_playing", defaultValue: "正在播放") : String(localized: "state_paused", defaultValue: "已暂停")
                    )
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                vm.toggleResonancePlayback()
            }
            .accessibilityAction(named: String(localized: "frisson_vo_label", defaultValue: "声学和声张力释放")) {
                vm.releaseFrissonBloom(charged: 0.78)
            }
            .accessibilityAdjustableAction { direction in
                guard !vm.pureAmbientWashOnly else { return }
                let delta = direction == .increment ? 0.5 : -0.5
                vm.updateInteractiveDial(beatHz: ResonanceKinematics.clampedBeatHz(vm.beatHz + delta))
            }
        }
    }

    private var footerQuickControls: some View {
        ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
            amberActionButton(
                title: "Delta 2.5 Hz",
                active: vm.selectedBand == .delta && vm.isResonancePlaying
            ) {
                vm.selectBand(.delta)
            }
            amberActionButton(
                title: "Theta 5.5 Hz",
                active: vm.selectedBand == .theta && vm.isResonancePlaying
            ) {
                vm.selectBand(.theta, startPlayingIfIdle: true)
                vm.updateInteractiveDial(beatHz: 5.5)
            }
            amberActionButton(
                title: vm.sleepTimerMinutes == 15 ? String(localized: "timer_15_active", defaultValue: "15分定时中") : String(localized: "timer_15", defaultValue: "15 分关机"),
                active: vm.sleepTimerMinutes == 15
            ) {
                vm.setSleepTimer(minutes: vm.sleepTimerMinutes == 15 ? nil : 15)
            }
            amberActionButton(
                title: vm.sleepTimerMinutes == 30 ? String(localized: "timer_30_active", defaultValue: "30分定时中") : String(localized: "timer_30", defaultValue: "30 分关机"),
                active: vm.sleepTimerMinutes == 30
            ) {
                vm.setSleepTimer(minutes: vm.sleepTimerMinutes == 30 ? nil : 30)
            }
        }
    }

    private func amberActionButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        let increased = (contrast == .increased)
        let borderOpacity = active ? (increased ? 1.0 : 0.90) : (increased ? 0.72 : 0.28)
        let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: active, reduceTransparency: reduceTransparency, increasedContrast: increased)

        return Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(active ? Color(hex: 0x0A0C12) : Color(hex: 0xE6DAC8))
                .lineLimit(type.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: ChimmoAffordance.minHitTarget)
                .background(
                    Capsule()
                        .fill(active ? amberGlow : lampSurface)
                        .overlay(Capsule().strokeBorder(amberGlow.opacity(borderOpacity), lineWidth: borderW))
                )
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
