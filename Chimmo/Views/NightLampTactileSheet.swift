import QuartzCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 闭眼夜灯触觉剧场（Zero-Vision OLED 夜间摸音创作空间）：
/// - 全屏低亮度深曜夜幕，指尖在磁吸迟滞音阶脊线上滑动寻音（跨越台阶触发细腻 Core Haptics 触感与柔声试音），
/// - 找到满意的那颗音后松手立刻落珠（在最终停留音阶上停留越久，音珠尾音越长），全程无需盯住屏幕或辨认小按钮。
public struct NightLampTactileSheet: View {
    @ObservedObject public var vm: StudioViewModel
    public let onCommitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localPentatonicSafe: Bool
    @State private var currentHoverLane: Int? = nil
    @State private var touchPoint: CGPoint? = nil
    @State private var touchStartTime: Double = 0
    @State private var capturedBeads: [NoteBead] = []
    @State private var voiceOverLanePos: Int = 0

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
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            ChimmoCraftBadge(
                .nightLampHalo,
                accent: Color(hex: 0xFFB84D),
                surface: Color(hex: 0x131B36),
                size: 38
            )

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(hex: 0x192140)))
                    .foregroundStyle(Color(hex: 0xF4EBDD))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
    }

    private var tactilePad: some View {
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: localPentatonicSafe)

        return GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x0C1229), Color(hex: 0x111938)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color(hex: 0xFFB84D).opacity(0.24), lineWidth: 1.2)
                    )

                // 低刺激磁吸音脊线：夜晚柔和不刺眼，依然可供睁眼余光或色盲图腾定位
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
                    let ridgeCol = isHover ? Color(hex: 0xFFB84D) : lane.barColor(isNight: true).opacity(0.45)

                    HStack(spacing: 8) {
                        Capsule()
                            .fill(ridgeCol.opacity(isHover ? 0.90 : 0.25))
                            .frame(height: isHover ? 3.5 : 1.5)

                        HStack(spacing: 4) {
                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIdx))
                                .frame(width: isHover ? 11 : 9, height: isHover ? 11 : 9)
                                .foregroundStyle(ridgeCol.opacity(isHover ? 1.0 : 0.72))

                            Text(lane.digitLabel)
                                .font(.system(size: isHover ? 13 : 10, weight: .bold, design: .rounded))
                                .foregroundStyle(ridgeCol.opacity(isHover ? 1.0 : 0.72))
                        }
                        .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 18)
                    .position(x: geo.size.width * 0.5, y: yPos)
                }

                // 跟随指尖的暖琥珀夜灯光晕（不刺眼、仅照亮指腹周边）
                if let pt = touchPoint {
                    let hoverColor = currentHoverLane.map { XylophoneLane.lane(at: $0).barColor(isNight: true) } ?? Color(hex: 0xFFB84D)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [hoverColor.opacity(0.42), Color(hex: 0xFFB84D).opacity(0.14), .clear],
                                center: .center,
                                startRadius: 6,
                                endRadius: 95
                            )
                        )
                        .frame(width: 190, height: 190)
                        .position(pt)
                        .allowsHitTesting(false)
                } else {
                    VStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: 0xFFB84D).opacity(0.60))
                            .frame(width: 7, height: 7)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xFFB84D).opacity(0.18), Color(hex: 0xFFB84D).opacity(0.55), Color(hex: 0xFFB84D).opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3, height: 52)
                        Circle()
                            .fill(Color(hex: 0xFFB84D).opacity(0.60))
                            .frame(width: 7, height: 7)
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
                            touchStartTime = CACurrentMediaTime()
                            currentHoverLane = snapped
                            previewTactileLane(snapped)
                        } else if snapped != currentHoverLane {
                            // 切换到新音高时重置停留计时，确保音珠时长严格反映最终定音的停留长度
                            touchStartTime = CACurrentMediaTime()
                            currentHoverLane = snapped
                            previewTactileLane(snapped)
                        }
                    }
                    .onEnded { val in
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
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("闭眼滑音画布，已录下 \(capturedBeads.count) 个音")
            .accessibilityValue(XylophoneLane.lane(at: allowed[max(0, min(allowed.count - 1, voiceOverLanePos))]).member.voiceOverSummary)
            .accessibilityHint("上下轻扫切换音高预览，使用转子操作记录这颗音珠，或直接单指滑动松手落珠")
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
            .accessibilityAction(named: "记录这颗音珠") {
                let safePos = max(0, min(allowed.count - 1, voiceOverLanePos))
                commitTactileBead(laneIndex: allowed[safePos], duration: 0.56)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var capturedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if capturedBeads.isEmpty {
                    Rectangle()
                        .fill(Color(hex: 0x222B4E).opacity(0.55))
                        .frame(width: 140, height: 1.5)
                        .padding(.horizontal, 8)
                } else {
                    ForEach(Array(capturedBeads.enumerated()), id: \.element.id) { idx, bead in
                        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                        let lane = XylophoneLane.lane(at: laneIdx)
                        HStack(spacing: 5) {
                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: laneIdx))
                                .frame(width: 9, height: 9)
                            Text(lane.digitLabel)
                                .font(.caption.weight(.heavy).monospacedDigit())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(lane.barColor(isNight: true).opacity(idx == capturedBeads.count - 1 ? 0.34 : 0.20))
                        )
                        .overlay(
                            Capsule().strokeBorder(lane.barColor(isNight: true).opacity(0.65), lineWidth: 1.0)
                        )
                        .foregroundStyle(Color(hex: 0xF4EBDD))
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
                capturedBeads.removeLast()
                AcousticHapticsEngine.shared.playScrubTick()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(hex: 0x192140)))
                    .foregroundStyle(capturedBeads.isEmpty ? Color(hex: 0x5B6482) : Color(hex: 0xF4EBDD))
            }
            .disabled(capturedBeads.isEmpty)
            .buttonStyle(.plain)
            .accessibilityLabel("撤销")

            Button {
                localPentatonicSafe.toggle()
                AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
            } label: {
                HStack(spacing: 5) {
                    ChimmoCraftMark(
                        .pentatonicArc,
                        color: localPentatonicSafe ? Color(hex: 0x69DB7C) : Color(hex: 0xF4EBDD)
                    )
                    .frame(width: 15, height: 15)
                    Text(localPentatonicSafe ? "5" : "8")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Capsule().fill(localPentatonicSafe ? Color(hex: 0x2F9E44).opacity(0.25) : Color(hex: 0x192140)))
                .foregroundStyle(localPentatonicSafe ? Color(hex: 0x69DB7C) : Color(hex: 0xF4EBDD))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localPentatonicSafe ? "五音模式" : "八音模式")

            Button {
                guard !capturedBeads.isEmpty else { return }
                vm.applyNightLampPhrase(capturedBeads, pentatonicSafe: localPentatonicSafe)
                dismiss()
                onCommitted()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                    if !capturedBeads.isEmpty {
                        Text("\(capturedBeads.count)")
                            .font(.subheadline.weight(.heavy).monospacedDigit())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    Capsule().fill(capturedBeads.isEmpty ? Color(hex: 0x242C4A) : Color(hex: 0xFFB84D))
                )
                .foregroundStyle(capturedBeads.isEmpty ? Color(hex: 0x7E87A3) : Color(hex: 0x151B36))
            }
            .disabled(capturedBeads.isEmpty)
            .buttonStyle(.plain)
            .accessibilityLabel("完成并试听")
        }
    }

    private func previewTactileLane(_ laneIndex: Int) {
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

    private func commitTactileBead(laneIndex: Int, duration: Double) {
        let lane = XylophoneLane.lane(at: laneIndex)
        let nextOnset: Double
        if let last = capturedBeads.last {
            nextOnset = last.rawOnset + max(0.36, last.rawDuration + 0.08)
        } else {
            nextOnset = 0.14
        }
        if capturedBeads.count >= 20 {
            capturedBeads.removeFirst()
            if let shift = capturedBeads.first?.rawOnset, shift > 0.14 {
                let delta = shift - 0.14
                for idx in capturedBeads.indices {
                    capturedBeads[idx].rawOnset = max(0.14, capturedBeads[idx].rawOnset - delta)
                }
            }
        }
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
