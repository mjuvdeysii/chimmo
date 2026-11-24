import QuartzCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 闭眼夜灯触觉剧场（Zero-Vision OLED 夜间摸音创作空间）：
/// - 全屏低亮度深曜夜幕，指尖在磁吸迟滞音阶脊线上滑动寻音（跨越台阶触发细腻 Core Haptics 触感与柔声试音），
/// - 找到满意的那颗音后松手立刻落音（在最终停留音阶上停留跨越节拍分界时激发温柔脉搏与光环扩展），全程无需盯住屏幕或辨认小按钮。
public struct NightLampTactileSheet: View {
    @ObservedObject public var vm: StudioViewModel
    public let onCommitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var localPentatonicSafe: Bool
    @State private var currentHoverLane: Int? = nil
    @State private var touchPoint: CGPoint? = nil
    @State private var touchStartTime: Double = 0
    @State private var sustainTier: Int = 0
    @State private var sustainPollTask: Task<Void, Never>? = nil
    @State private var capturedBeads: [NoteBead] = []
    @State private var voiceOverLanePos: Int = 0
    @State private var auditioningIndex: Int? = nil
    @State private var auditionTask: Task<Void, Never>? = nil

    public init(vm: StudioViewModel, onCommitted: @escaping () -> Void = {}) {
        self.vm = vm
        self.onCommitted = onCommitted
        self._localPentatonicSafe = State(initialValue: vm.pentatonicSafe)
    }

    public var body: some View {
        ZStack {
            Color(hex: 0x070B1A).ignoresSafeArea()

            VStack(spacing: 14) {
                topBar
                tactilePad
                capturedStrip
                bottomControls
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(!capturedBeads.isEmpty)
        .onDisappear {
            stopSustainPulseWatcher()
            stopAudition()
        }
    }

    private var topBar: some View {
        let activeMember: ChimmoMember = {
            if let lane = currentHoverLane {
                return XylophoneLane.lane(at: lane).member
            }
            if let last = capturedBeads.last {
                return ChimmoMember.from(degree: last.degree)
            }
            return .udo
        }()

        return HStack(spacing: 10) {
            ChimmoCraftBadge(
                .nightLampHalo,
                accent: Color(hex: 0xFFB94E),
                surface: Color(hex: 0x162048),
                size: 38
            )

            LivingChimmoDuoBadgeView(
                isNight: true,
                accentColor: Color(hex: 0xFFB94E),
                melodyActive: currentHoverLane != nil || auditioningIndex != nil,
                cowAwake: vm.cradleEnabled
            )
            .frame(width: 34, height: 22)

            HStack(spacing: 6) {
                ChimmoCartoonKeyBuddyView(
                    member: activeMember,
                    outlineColor: Color(hex: 0xFFB94E),
                    isSinging: currentHoverLane != nil || auditioningIndex != nil,
                    isMinor: vm.document.scaleMode.isMinorFlavored
                )
                .frame(width: 22, height: 18)

                Text(localPentatonicSafe ? "五音夜灯" : "八音夜灯")
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF5ECDD))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: 0x162048))
                    .overlay(
                        Capsule().strokeBorder(Color(hex: 0xFFB94E).opacity(0.68), lineWidth: 1.6)
                    )
            )

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x03050F))
                        .frame(width: 36, height: 36)
                        .offset(y: 2.5)
                    Circle()
                        .fill(Color(hex: 0x1D2856))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Color(hex: 0xFFB94E).opacity(0.75), lineWidth: 1.8))
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Color(hex: 0xF5ECDD))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
    }

    private var tactilePad: some View {
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: localPentatonicSafe)
        let currentPos = max(0, min(allowed.count - 1, voiceOverLanePos))
        let focusedMember = XylophoneLane.lane(at: allowed[currentPos]).member

        return GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: 0x0B112B))

                // 扁平卡通夜空星月 + 低对比双层夜山坡（OLED 友好低刺激背景，零渐变）
                Canvas { ctx, size in
                    let w = max(1, size.width)
                    let h = max(1, size.height)
                    let goldInk = Color(hex: 0xFFB94E)

                    for star in StorybookNightLampInclusivityKinematics.starPositions(count: 8) {
                        let sx = star.xFraction * w
                        let sy = star.yFraction * h
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: sx - star.radius, y: sy - star.radius, width: star.radius * 2, height: star.radius * 2)),
                            with: .color(goldInk.opacity(0.32))
                        )
                    }

                    let mr: CGFloat = 13.0
                    let mx = w - 34.0
                    let my: CGFloat = 34.0
                    var moon = Path()
                    let mTop = CGPoint(x: mx + mr * 0.3, y: my - mr * 0.85)
                    let mBot = CGPoint(x: mx + mr * 0.3, y: my + mr * 0.85)
                    moon.move(to: mTop)
                    moon.addCurve(to: mBot, control1: CGPoint(x: mx - mr * 1.05, y: my - mr * 0.48), control2: CGPoint(x: mx - mr * 1.05, y: my + mr * 0.48))
                    moon.addCurve(to: mTop, control1: CGPoint(x: mx - mr * 0.22, y: my + mr * 0.36), control2: CGPoint(x: mx - mr * 0.22, y: my - mr * 0.36))
                    moon.closeSubpath()
                    ctx.fill(moon, with: .color(goldInk.opacity(0.45)))

                    let backProfile = StorybookIllustrationLayout.rollingHillProfile(sampleCount: 14, amplitude: 0.20, phaseShift: 0.4)
                    if let first = backProfile.first {
                        let baseTop = h * 0.84
                        var hill = Path()
                        hill.move(to: CGPoint(x: 0, y: h))
                        hill.addLine(to: CGPoint(x: CGFloat(first.xFraction) * w, y: baseTop + CGFloat(first.yFraction - 0.5) * 32))
                        for i in 1..<backProfile.count {
                            let p0 = CGPoint(x: CGFloat(backProfile[i - 1].xFraction) * w, y: baseTop + CGFloat(backProfile[i - 1].yFraction - 0.5) * 32)
                            let p1 = CGPoint(x: CGFloat(backProfile[i].xFraction) * w, y: baseTop + CGFloat(backProfile[i].yFraction - 0.5) * 32)
                            hill.addQuadCurve(to: CGPoint(x: (p0.x + p1.x) * 0.5, y: (p0.y + p1.y) * 0.5), control: p0)
                        }
                        hill.addLine(to: CGPoint(x: w, y: h))
                        hill.closeSubpath()
                        ctx.fill(hill, with: .color(Color(hex: 0x121A3D)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color(hex: 0xFFB94E).opacity(0.68), lineWidth: 2.0)
                    .allowsHitTesting(false)

                // 低刺激磁吸音脊线：夜晚柔和不刺眼，供余光、摸音与色盲图腾定位
                ForEach(allowed, id: \.self) { laneIdx in
                    let lane = XylophoneLane.lane(at: laneIdx)
                    let normY = TactileFieldMapper.magneticDetentNormalizedY(
                        laneIndex: laneIdx,
                        pentatonicSafe: localPentatonicSafe
                    )
                    let pad = geo.size.height * 0.08
                    let usable = max(1.0, geo.size.height - pad * 2.0)
                    let yPos = pad + CGFloat(1.0 - normY) * usable
                    let isHover = currentHoverLane == laneIdx
                    let ridgeCol = isHover ? Color(hex: 0xFFB94E) : lane.barColor(isNight: true).opacity(0.55)

                    HStack(spacing: 8) {
                        Capsule()
                            .fill(ridgeCol.opacity(isHover ? 0.96 : 0.30))
                            .frame(height: isHover ? 4.0 : 1.8)

                        HStack(spacing: 4) {
                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIdx))
                                .frame(width: isHover ? 12 : 9, height: isHover ? 12 : 9)
                                .foregroundStyle(ridgeCol.opacity(isHover ? 1.0 : 0.78))

                            Text(lane.digitLabel)
                                .font(.system(size: isHover ? 14 : 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(ridgeCol.opacity(isHover ? 1.0 : 0.78))
                        }
                        .frame(width: 46, alignment: .trailing)
                    }
                    .padding(.horizontal, 18)
                    .position(x: geo.size.width * 0.5, y: yPos)
                }

                // 跟随指尖的扁平卡通暖琥珀星光同心环（零模糊渐变）
                if let pt = touchPoint {
                    let hoverColor = currentHoverLane.map { XylophoneLane.lane(at: $0).barColor(isNight: true) } ?? Color(hex: 0xFFB94E)
                    let heldSeconds = max(0.0, CACurrentMediaTime() - touchStartTime)
                    let beaconDiameter = StorybookNightLampInclusivityKinematics.haloDiameter(
                        sustainTier: sustainTier,
                        heldSeconds: heldSeconds,
                        reduceMotion: reduceMotion
                    )

                    ZStack {
                        Circle()
                            .fill(hoverColor.opacity(0.24))
                            .frame(width: beaconDiameter * 1.45, height: beaconDiameter * 1.45)

                        Circle()
                            .fill(hoverColor)
                            .overlay(Circle().strokeBorder(Color(hex: 0x0A0F24), lineWidth: 2.2))
                            .frame(width: 24, height: 24)

                        if sustainTier >= 1 {
                            ForEach(1...min(3, sustainTier), id: \.self) { ringTier in
                                let ringDiameter: CGFloat = 46.0 + CGFloat(ringTier) * 26.0
                                Circle()
                                    .strokeBorder(
                                        Color(hex: 0xFFB94E).opacity(ringTier == sustainTier ? 0.88 : 0.42),
                                        lineWidth: ringTier == 3 ? 2.2 : 1.5
                                    )
                                    .frame(width: ringDiameter, height: ringDiameter)
                            }
                        }
                    }
                    .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.78), value: sustainTier)
                    .position(pt)
                    .allowsHitTesting(false)
                } else {
                    VStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: 0xFFB94E))
                            .overlay(Circle().strokeBorder(Color(hex: 0x0A0F24), lineWidth: 1.5))
                            .frame(width: 10, height: 10)
                        Capsule()
                            .fill(Color(hex: 0xFFB94E).opacity(0.55))
                            .frame(width: 4, height: 52)
                        Circle()
                            .fill(Color(hex: 0x53DFCF))
                            .overlay(Circle().strokeBorder(Color(hex: 0x0A0F24), lineWidth: 1.5))
                            .frame(width: 10, height: 10)
                    }
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        touchPoint = val.location
                        let normY = TactileFieldMapper.rawNormalizedY(locationY: val.location.y, height: geo.size.height)
                        let snapped = TactileFieldMapper.snappedLaneIndex(
                            normalizedY: normY,
                            previousLaneIndex: currentHoverLane,
                            pentatonicSafe: localPentatonicSafe
                        )
                        if currentHoverLane == nil {
                            stopAudition()
                            touchStartTime = CACurrentMediaTime()
                            currentHoverLane = snapped
                            previewTactileLane(snapped)
                            restartSustainPulseWatcher()
                        } else if snapped != currentHoverLane {
                            // 切换到新音高时重置停留计时，确保音符时长严格反映最终定音的停留长度
                            touchStartTime = CACurrentMediaTime()
                            currentHoverLane = snapped
                            previewTactileLane(snapped)
                            restartSustainPulseWatcher()
                        }
                    }
                    .onEnded { val in
                        stopSustainPulseWatcher()
                        let normY = TactileFieldMapper.rawNormalizedY(locationY: val.location.y, height: geo.size.height)
                        let finalLane = currentHoverLane ?? TactileFieldMapper.snappedLaneIndex(
                            normalizedY: normY,
                            previousLaneIndex: nil,
                            pentatonicSafe: localPentatonicSafe
                        )
                        let heldDuration = max(0.28, min(1.85, CACurrentMediaTime() - touchStartTime))
                        commitTactileBead(laneIndex: finalLane, duration: heldDuration)
                        currentHoverLane = nil
                        touchPoint = nil
                        sustainTier = 0
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("闭眼滑音夜灯画布")
            .accessibilityValue(
                StorybookNightLampInclusivityKinematics.accessibilityCanvasValue(
                    currentMember: focusedMember,
                    capturedCount: capturedBeads.count
                )
            )
            .accessibilityHint("上下轻扫切换音高预览，使用转子记录短音或长音，也可以单指滑动停留松手落音")
            .accessibilityAdjustableAction { direction in
                let maxIdx = max(0, allowed.count - 1)
                switch direction {
                case .increment:
                    voiceOverLanePos = min(maxIdx, voiceOverLanePos + 1)
                case .decrement:
                    voiceOverLanePos = max(0, voiceOverLanePos - 1)
                @unknown default:
                    break
                }
                let laneIdx = allowed[max(0, min(maxIdx, voiceOverLanePos))]
                previewTactileLane(laneIdx)
            }
            .accessibilityAction(named: "记录短音") {
                let safePos = max(0, min(allowed.count - 1, voiceOverLanePos))
                let shortDur = TactileSustainStage.stage(forHeldSeconds: 0.20).targetDuration
                commitTactileBead(laneIndex: allowed[safePos], duration: shortDur)
            }
            .accessibilityAction(named: "记录长音") {
                let safePos = max(0, min(allowed.count - 1, voiceOverLanePos))
                let longDur = TactileSustainStage.stage(forHeldSeconds: 1.00).targetDuration
                commitTactileBead(laneIndex: allowed[safePos], duration: longDur)
            }
            .accessibilityAction(named: "试听已录旋律") {
                toggleAudition()
            }
            .accessibilityAction(named: "撤销上一音") {
                guard !capturedBeads.isEmpty else { return }
                stopAudition()
                capturedBeads.removeLast()
                AcousticHapticsEngine.shared.playScrubTick()
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var capturedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if capturedBeads.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { dot in
                            Circle()
                                .fill(Color(hex: 0xFFB94E).opacity(dot == 1 ? 0.55 : 0.30))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0x162048))
                            .overlay(Capsule().strokeBorder(Color(hex: 0xFFB94E).opacity(0.35), lineWidth: 1.4))
                    )
                } else {
                    ForEach(Array(capturedBeads.enumerated()), id: \.element.id) { idx, bead in
                        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                        let lane = XylophoneLane.lane(at: laneIdx)
                        let isAuditioning = auditioningIndex == idx
                        let chipFill = isAuditioning
                            ? Color(hex: 0xFFB84D).opacity(0.38)
                            : lane.barColor(isNight: true).opacity(idx == capturedBeads.count - 1 ? 0.34 : 0.20)
                        let chipStroke = isAuditioning
                            ? Color(hex: 0xFFB84D)
                            : lane.barColor(isNight: true).opacity(0.65)
                        let chipWidth = NightLampPhraseHelper.chipVisualWidth(forDuration: bead.rawDuration)
                        let durRatio = NightLampPhraseHelper.normalizedDurationRatio(for: bead.rawDuration)
                        Button {
                            stopAudition()
                            previewCapturedBead(bead, index: idx)
                        } label: {
                            VStack(spacing: 2.5) {
                                HStack(spacing: 5) {
                                    PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIdx))
                                        .frame(width: 9, height: 9)
                                    Text(lane.digitLabel)
                                        .font(.caption.weight(.heavy).monospacedDigit())
                                }
                                Capsule()
                                    .fill(chipStroke.opacity(0.85))
                                    .frame(width: max(12, chipWidth * 0.56 * CGFloat(0.35 + durRatio * 0.65)), height: 2.2)
                            }
                            .frame(minWidth: chipWidth)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(chipFill))
                            .overlay(
                                Capsule().strokeBorder(chipStroke, lineWidth: isAuditioning ? 1.8 : 1.0)
                            )
                            .foregroundStyle(Color(hex: 0xF4EBDD))
                            .scaleEffect(isAuditioning && !reduceMotion ? 1.08 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                removeCapturedBead(at: idx)
                            } label: {
                                Label("删除此音", systemImage: "trash")
                            }
                        }
                        .accessibilityLabel("\(lane.digitLabel) \(lane.solfege)")
                        .accessibilityHint("轻点试听单音，长按或使用转子可删除")
                        .accessibilityAction(named: "删除此音") {
                            removeCapturedBead(at: idx)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 38)
    }

    private var bottomControls: some View {
        HStack(spacing: 10) {
            Button {
                guard !capturedBeads.isEmpty else { return }
                stopAudition()
                capturedBeads.removeLast()
                AcousticHapticsEngine.shared.playScrubTick()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x03050F))
                        .frame(width: 44, height: 44)
                        .offset(y: 2.5)
                    Circle()
                        .fill(Color(hex: 0x162048))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Color(hex: 0xFFB94E).opacity(capturedBeads.isEmpty ? 0.28 : 0.72), lineWidth: 1.8))
                    Image(systemName: "arrow.uturn.backward")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(capturedBeads.isEmpty ? Color(hex: 0x5B6482) : Color(hex: 0xF5ECDD))
                }
            }
            .disabled(capturedBeads.isEmpty)
            .buttonStyle(.plain)
            .accessibilityLabel("撤销")

            Button {
                toggleAudition()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x03050F))
                        .frame(width: 44, height: 44)
                        .offset(y: 2.5)
                    Circle()
                        .fill(auditioningIndex != nil ? Color(hex: 0xFFB94E) : Color(hex: 0x162048))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Color(hex: 0xFFB94E).opacity(capturedBeads.isEmpty ? 0.28 : 0.85), lineWidth: 1.8))
                    Image(systemName: auditioningIndex != nil ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(
                            capturedBeads.isEmpty
                                ? Color(hex: 0x5B6482)
                                : (auditioningIndex != nil ? Color(hex: 0x0E142C) : Color(hex: 0xFFB94E))
                        )
                }
            }
            .disabled(capturedBeads.isEmpty)
            .buttonStyle(.plain)
            .accessibilityLabel(auditioningIndex != nil ? "停止试听" : "试听已录旋律")

            Button {
                localPentatonicSafe.toggle()
                AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
            } label: {
                HStack(spacing: 5) {
                    ChimmoCraftMark(
                        .pentatonicArc,
                        color: localPentatonicSafe ? Color(hex: 0x53DFCF) : Color(hex: 0xF5ECDD)
                    )
                    .frame(width: 15, height: 15)
                    Text(localPentatonicSafe ? "5" : "8")
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    ZStack {
                        Capsule()
                            .fill(Color(hex: 0x03050F))
                            .offset(y: 2.5)
                        Capsule()
                            .fill(localPentatonicSafe ? Color(hex: 0x162C46) : Color(hex: 0x162048))
                        Capsule()
                            .strokeBorder(localPentatonicSafe ? Color(hex: 0x53DFCF) : Color(hex: 0xFFB94E).opacity(0.65), lineWidth: 1.8)
                    }
                )
                .foregroundStyle(localPentatonicSafe ? Color(hex: 0x53DFCF) : Color(hex: 0xF5ECDD))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localPentatonicSafe ? "五音模式" : "八音模式")

            Button {
                guard !capturedBeads.isEmpty else { return }
                stopAudition()
                stopSustainPulseWatcher()
                vm.applyNightLampPhrase(capturedBeads, pentatonicSafe: localPentatonicSafe)
                dismiss()
                onCommitted()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.heavy))
                    if !capturedBeads.isEmpty {
                        Text("\(capturedBeads.count)")
                            .font(.subheadline.weight(.heavy).monospacedDigit())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    ZStack {
                        Capsule()
                            .fill(Color(hex: 0x03050F))
                            .offset(y: 3)
                        Capsule()
                            .fill(capturedBeads.isEmpty ? Color(hex: 0x1D2856) : Color(hex: 0xFFB94E))
                        Capsule()
                            .strokeBorder(Color(hex: 0xFFB94E).opacity(capturedBeads.isEmpty ? 0.32 : 1.0), lineWidth: 2.0)
                    }
                )
                .foregroundStyle(capturedBeads.isEmpty ? Color(hex: 0x7E87A3) : Color(hex: 0x0E142C))
            }
            .disabled(capturedBeads.isEmpty)
            .buttonStyle(.plain)
            .accessibilityLabel("完成并试听")
        }
    }

    private func previewTactileLane(_ laneIndex: Int) {
        vm.synth.ensureRunning()
        let lane = XylophoneLane.lane(at: laneIndex)
        let member = lane.member
        AcousticHapticsEngine.shared.playPitchTouch(
            laneIndex: laneIndex,
            isHome: lane.degree == 1,
            isTension: member.isTensionDegree
        )
        let hz = vm.document.scaleMode.frequencyHz(
            rootMIDI: vm.document.rootMIDI,
            degree: lane.degree,
            octaveOffset: lane.octaveOffset
        )
        vm.synth.playNote(
            frequency: hz,
            velocity: 0.44,
            decay: 0.9,
            timbre: FeltPianoSynth.Timbre.from(voice: vm.melodyVoice)
        )
    }

    private func restartSustainPulseWatcher() {
        sustainPollTask?.cancel()
        sustainTier = 0
        sustainPollTask = Task { @MainActor in
            while !Task.isCancelled {
                guard touchPoint != nil else { break }
                let held = CACurrentMediaTime() - touchStartTime
                let nextStage = TactileSustainStage.stage(forHeldSeconds: held)
                if nextStage.tier > sustainTier {
                    sustainTier = nextStage.tier
                    AcousticHapticsEngine.shared.playBeatTap(isStrong: nextStage.tier == 3)
                }
                if sustainTier >= 3 { break }
                try? await Task.sleep(nanoseconds: 65_000_000)
            }
        }
    }

    private func stopSustainPulseWatcher() {
        sustainPollTask?.cancel()
        sustainPollTask = nil
    }

    private func previewCapturedBead(_ bead: NoteBead, index: Int) {
        vm.synth.ensureRunning()
        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
        let lane = XylophoneLane.lane(at: laneIdx)
        AcousticHapticsEngine.shared.playPlaybackNotePulse(
            laneIndex: laneIdx,
            isHome: lane.degree == 1,
            isTension: lane.member.isTensionDegree,
            isDownbeat: index == 0
        )
        let totalDur = NightLampPhraseHelper.totalAuditionDuration(of: capturedBeads)
        let pan = AcousticSpatialPanMapper.pan(
            forBeatOnset: bead.rawOnset,
            totalDuration: max(0.8, totalDur),
            visualMode: vm.visualMode
        )
        let hz = vm.document.scaleMode.frequencyHz(
            rootMIDI: vm.document.rootMIDI,
            degree: bead.degree,
            octaveOffset: bead.octaveOffset
        )
        vm.synth.playNote(
            frequency: hz,
            velocity: 0.56,
            decay: max(0.8, bead.rawDuration * 1.35),
            timbre: FeltPianoSynth.Timbre.from(voice: vm.melodyVoice),
            pan: pan
        )
    }

    private func removeCapturedBead(at index: Int) {
        stopAudition()
        capturedBeads = NightLampPhraseHelper.removingBead(at: index, from: capturedBeads)
        AcousticHapticsEngine.shared.playScrubTick()
    }

    private func stopAudition() {
        auditionTask?.cancel()
        auditionTask = nil
        auditioningIndex = nil
    }

    private func toggleAudition() {
        if auditionTask != nil || auditioningIndex != nil {
            stopAudition()
            AcousticHapticsEngine.shared.playScrubTick()
            return
        }
        let snapshot = capturedBeads
        guard !snapshot.isEmpty else { return }
        stopSustainPulseWatcher()
        auditionTask = Task { @MainActor in
            for (idx, bead) in snapshot.enumerated() {
                if idx > 0 {
                    let gapSec = max(0.18, min(1.8, bead.rawOnset - snapshot[idx - 1].rawOnset))
                    try? await Task.sleep(nanoseconds: UInt64(gapSec * 1_000_000_000))
                }
                guard !Task.isCancelled else { break }
                auditioningIndex = idx
                previewCapturedBead(bead, index: idx)
            }
            if !Task.isCancelled {
                let tailSec = max(0.32, min(0.95, (snapshot.last?.rawDuration ?? 0.4) * 0.75))
                try? await Task.sleep(nanoseconds: UInt64(tailSec * 1_000_000_000))
            }
            if !Task.isCancelled {
                auditioningIndex = nil
                auditionTask = nil
            }
        }
    }

    private func commitTactileBead(laneIndex: Int, duration: Double) {
        stopAudition()
        let lane = XylophoneLane.lane(at: laneIndex)
        if capturedBeads.count >= 20 {
            capturedBeads.removeFirst()
            capturedBeads = NightLampPhraseHelper.repackSequentialTimings(capturedBeads)
        }
        let nextOnset = NightLampPhraseHelper.nextOnset(after: capturedBeads)
        let bead = NoteBead(
            degree: lane.degree,
            octaveOffset: lane.octaveOffset,
            rawOnset: nextOnset,
            rawDuration: duration
        )
        capturedBeads.append(bead)
        AcousticHapticsEngine.shared.playBeatTap(isStrong: lane.degree == 1)
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: "已记录 \(lane.digitLabel) \(lane.solfege)")
        #endif
    }
}
