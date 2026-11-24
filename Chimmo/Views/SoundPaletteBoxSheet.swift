import QuartzCore
import SwiftUI

/// 童书声音调色木盒（Best Kids' Book Design × 窑陶蜂蜡桦木拉丝黄铜硬件调音台）：
/// - 顶部：一体式黄铜外观平衡仪 + 木框标题冠徽；
/// - 核心舞台：内凹声学示波窗 × 活体「咩 × 1·3·5 三音小偶 × 哞」实体木架，实时响应音色、移调、节拍与调式晴雨；
/// - 实体控制区：机械黄铜拨杆三连开关、五色极光调式木槽、倍速/节拍/音区三层混音柜，以及「咩 · 音色」与「哞 · 伴奏」双木盒。
public struct SoundPaletteBoxSheet: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeChannel: SoundBoxAuditionChannel? = nil
    @State private var auditionVoice: MelodyVoice? = nil
    @State private var auditionTexture: AccompanimentTexture? = nil
    @State private var auditionStartTime: Double = 0
    @State private var auditionResetTask: Task<Void, Never>? = nil

    public init(vm: StudioViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    private func triggerAudition(
        _ channel: SoundBoxAuditionChannel,
        voice: MelodyVoice? = nil,
        texture: AccompanimentTexture? = nil
    ) {
        auditionStartTime = CACurrentMediaTime()
        activeChannel = channel
        auditionVoice = voice
        auditionTexture = texture
        auditionResetTask?.cancel()
        auditionResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            if !Task.isCancelled {
                activeChannel = nil
                auditionVoice = nil
                auditionTexture = nil
            }
        }
    }

    private func appearanceIcon(for pref: AppearancePreference) -> String {
        switch pref {
        case .auto: return "circle.lefthalf.filled"
        case .daylight: return "sun.max.fill"
        case .nightLamp: return "moon.stars.fill"
        }
    }

    public var body: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: skyColor
                )

                VStack(spacing: 10) {
                    soundBoxCrownHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            soundBoxDioramaOscilloscope
                            brassToggleSwitchBank
                            auroraScalePaletteBox
                            tempoGroovePitchCabinet
                            mieVoiceCabinet
                            mouAccompanimentCabinet
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 22)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                auditionResetTask?.cancel()
                auditionResetTask = nil
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 1. Crown Header with Inline Brass Appearance Dial

    private var soundBoxCrownHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ChimmoCraftBadge(
                    .atmosphereHorizon,
                    accent: palette.brassHairline,
                    surface: palette.cardSurface,
                    size: 32
                )

                Text("声音调色盒")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                ForEach(AppearancePreference.allCases) { pref in
                    let active = vm.appearance == pref
                    Button {
                        vm.appearance = pref
                        AcousticHapticsEngine.shared.playScrubTick()
                    } label: {
                        Image(systemName: appearanceIcon(for: pref))
                            .font(.system(size: 11.5, weight: .bold))
                            .frame(width: 28, height: 26)
                            .background(
                                Capsule().fill(active ? palette.homeAnchor : Color.clear)
                            )
                            .foregroundStyle(
                                active
                                    ? (palette.isNight ? Color(hex: 0x0E142C) : .white)
                                    : palette.secondaryInk
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pref.label)
                    .accessibilityValue(active ? "已选中" : "")
                }
            }
            .fixedSize()
            .padding(3)
            .background(
                ChimmoKilnPillButtonSurface(
                    palette: palette,
                    accent: palette.brassHairline,
                    isActive: false,
                    cornerRadius: 16
                )
            )

            Button {
                auditionResetTask?.cancel()
                auditionResetTask = nil
                dismiss()
            } label: {
                Text("完成")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .padding(.horizontal, 13)
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
            .accessibilityLabel("完成声音设置")
        }
    }

    // MARK: - 2. Recessed Diorama Oscilloscope + Mie / 1-3-5 Triad / Mou Shelf

    private var soundBoxDioramaOscilloscope: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let recessBg = palette.isNight ? Color(hex: 0x0A0F24) : Color(hex: 0xEFE6D4)
        let focusedDeg = SoundPaletteBoxKinematics.triadFocusDegree(for: activeChannel)
        let shelfFigures: [ChimmoMember] = [.taono, .plokko, .corllo]

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 22)

            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
                let now = CACurrentMediaTime()
                let phaseTime = reduceMotion ? 0.0 : now
                let isMieSinging = vm.isPlaying
                    || activeChannel == .voice
                    || activeChannel == .scale
                    || activeChannel == .pitch
                    || activeChannel == .tempo
                    || activeChannel == .character(5)
                let isMouPulsing = vm.isPlaying
                    || activeChannel == .texture
                    || activeChannel == .chord
                    || activeChannel == .character(1)
                let sweep: Double? = (activeChannel != nil && !reduceMotion)
                    ? AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: now - auditionStartTime)
                    : nil
                let samples = SoundPaletteBoxKinematics.oscilloscopeSamples(
                    for: vm.melodyVoice,
                    rootMIDI: vm.document.rootMIDI,
                    playbackRate: vm.playbackRate,
                    phase: reduceMotion ? 0.0 : phaseTime * 2.4,
                    sampleCount: 28
                )

                VStack(spacing: 4) {
                    SoundBoxOscilloscopeWindow(
                        samples: samples,
                        waveColor: skyColor,
                        brassColor: palette.brassHairline,
                        sweepProgress: sweep
                    )
                    .frame(height: 36)

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [palette.woodTrayTop, palette.woodTrayBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(palette.brassHairline.opacity(0.35), lineWidth: 0.7)
                            )
                            .frame(height: 6)
                            .padding(.horizontal, 6)

                        HStack(alignment: .bottom, spacing: 6) {
                            Button {
                                vm.auditionDuoCharacter(.mie)
                                triggerAudition(.character(5))
                            } label: {
                                ChimmoSheepView(
                                    isNight: palette.isNight,
                                    accentColor: skyColor,
                                    isSinging: isMieSinging,
                                    phaseTime: phaseTime,
                                    gazeBias: focusedDeg.map { Double($0 - 4) / 3.0 } ?? 0.25
                                )
                                .frame(width: 38, height: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("小羊咩，试听高音主旋律")

                            ForEach(shelfFigures) { member in
                                let isMemberSinging = vm.isPlaying
                                    ? (vm.latestDegree == member.degree)
                                    : (focusedDeg == member.degree)
                                Button {
                                    vm.auditionChimmoMember(member)
                                    triggerAudition(.character(member.degree))
                                } label: {
                                    ChimmoFigureView(
                                        member: member,
                                        isNight: palette.isNight,
                                        isMinor: vm.document.scaleMode.isMinorFlavored,
                                        isSinging: isMemberSinging,
                                        focusedDegree: focusedDeg,
                                        time: phaseTime,
                                        listeningTilt: 0
                                    )
                                    .scaleEffect(0.66, anchor: .bottom)
                                    .frame(width: 36, height: 42, alignment: .bottom)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(member.degree) \(member.chineseName) \(member.solfege)")
                                .accessibilityHint("轻点试听音级")
                            }

                            Button {
                                if !vm.cradleEnabled {
                                    vm.setChordPreset(.autoMatch)
                                }
                                vm.auditionDuoCharacter(.mou)
                                triggerAudition(.character(1))
                            } label: {
                                ChimmoCowView(
                                    isNight: palette.isNight,
                                    accentColor: skyColor,
                                    isAwake: vm.cradleEnabled,
                                    isPlaying: isMouPulsing && vm.cradleEnabled,
                                    phaseTime: phaseTime,
                                    gazeBias: focusedDeg.map { Double($0 - 4) / 3.0 } ?? -0.25
                                )
                                .frame(width: 38, height: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("小牛哞，试听低音伴奏")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                    }
                    .frame(height: 50)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(recessBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [palette.recessShadow, palette.brassHairline.opacity(0.32)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.1
                                )
                        )
                )
                .padding(8)
            }

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 22, showCornerPins: true)
        }
        .frame(height: 118)
        .shadow(color: palette.recessShadow, radius: 10, y: 3)
    }

    // MARK: - 3. Brass Toggle Switch Bank

    private var brassToggleSwitchBank: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            HStack(spacing: 8) {
                brassToggleSwitchPad(
                    symbol: .pentatonicArc,
                    shortLabel: "五音",
                    accessibilityTitle: "五音模式",
                    isOn: vm.pentatonicSafe,
                    activeColor: Color(hex: 0x2F9E44)
                ) {
                    vm.togglePentatonicSafe()
                    triggerAudition(.pitch)
                }

                brassToggleSwitchPad(
                    symbol: .counterpointMoons,
                    shortLabel: "伴唱",
                    accessibilityTitle: "自动伴唱",
                    isOn: vm.shadowCounterpointEnabled,
                    activeColor: Color(hex: 0x4EA8DE)
                ) {
                    vm.toggleShadowCounterpoint()
                    triggerAudition(.voice)
                }

                brassToggleSwitchPad(
                    symbol: .hapticPulse,
                    shortLabel: "震动",
                    accessibilityTitle: "节拍震动",
                    isOn: vm.musicHapticsEnabled,
                    activeColor: palette.nightLampGold
                ) {
                    vm.toggleMusicHaptics()
                    triggerAudition(.groove)
                }
            }
            .padding(8)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: false)
        }
    }

    private func brassToggleSwitchPad(
        symbol: ChimmoCraftSymbol,
        shortLabel: String,
        accessibilityTitle: String,
        isOn: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        let lever = SoundPaletteBoxKinematics.toggleLeverState(isOn: isOn, reduceMotion: reduceMotion)

        return Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.isNight ? Color(hex: 0x0A0F24) : Color(hex: 0xE6D8BE))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.brassHairline.opacity(0.45), lineWidth: 0.9)
                        )
                        .frame(width: 12, height: 28)

                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isOn ? palette.nightLampGold : palette.cardSurface,
                                    palette.brassHairline.opacity(isOn ? 0.95 : 0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .strokeBorder(palette.glazeHighlight, lineWidth: 0.7)
                        )
                        .frame(width: 10, height: 12)
                        .offset(y: CGFloat(6.0 - lever.travelFraction * 12.0))
                        .rotationEffect(.degrees(lever.tiltDegrees))
                        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.66), value: isOn)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        ChimmoCraftMark(
                            symbol,
                            color: isOn ? activeColor : palette.secondaryInk
                        )
                        .frame(width: 17, height: 17)

                        Circle()
                            .fill(activeColor.opacity(lever.lampGlowOpacity))
                            .frame(width: 5.5, height: 5.5)
                            .shadow(color: isOn ? activeColor.opacity(0.65) : .clear, radius: 3)
                    }

                    Text(shortLabel)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(isOn ? palette.primaryInk : palette.secondaryInk)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                ChimmoKilnPillButtonSurface(
                    palette: palette,
                    accent: isOn ? activeColor : nil,
                    isActive: isOn,
                    cornerRadius: 13
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }

    // MARK: - 4. Five-Color Aurora Scale Wood Tray

    private var auroraScalePaletteBox: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            HStack(spacing: 6) {
                ForEach(ScaleMode.allCases) { mode in
                    let selected = vm.document.scaleMode == mode
                    let skyCol = mode.skyAuroraColor(isNight: palette.isNight)
                    Button {
                        vm.setScaleMode(mode)
                        triggerAudition(.scale)
                    } label: {
                        VStack(spacing: 5) {
                            Circle()
                                .fill(selected ? palette.brassHairline : palette.brassHairline.opacity(0.28))
                                .frame(width: 3.5, height: 3.5)

                            Image(systemName: mode.iconName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(skyCol)

                            Capsule()
                                .fill(skyCol.opacity(selected ? 0.96 : 0.42))
                                .frame(height: 3.5)
                                .padding(.horizontal, 6)

                            Text(mode.shortSkyLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            ChimmoKilnPillButtonSurface(
                                palette: palette,
                                accent: skyCol,
                                isActive: selected,
                                cornerRadius: 13
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(mode.label)风格")
                    .accessibilityValue(selected ? "已选中" : "")
                }
            }
            .padding(8)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: false)
        }
    }

    // MARK: - 5. Tempo x Groove x Pitch Mixing Cabinet

    private var tempoGroovePitchCabinet: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    ChimmoCraftMark(.tempoDial, color: palette.brassHairline)
                        .frame(width: 15, height: 15)
                        .frame(width: 22)
                        .accessibilityHidden(true)

                    ForEach([0.65, 0.85, 1.0, 1.25], id: \.self) { rate in
                        let active = abs(vm.playbackRate - rate) < 0.04
                        let label = rate == 1.0 ? "1×" : String(format: "%.2g×", rate)
                        Button {
                            vm.setPlaybackRate(rate)
                            triggerAudition(.tempo)
                        } label: {
                            Text(label)
                                .font(.caption.weight(.bold).monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(active ? palette.homeAnchor : palette.cardSurface)
                                )
                                .foregroundStyle(
                                    active
                                        ? (palette.isNight ? Color(hex: 0x0E142C) : .white)
                                        : palette.primaryInk
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("播放速度 \(label)")
                    }
                }

                Rectangle()
                    .fill(palette.brassHairline.opacity(0.24))
                    .frame(height: 0.75)

                HStack(spacing: 6) {
                    Image(systemName: "metronome")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.brassHairline)
                        .frame(width: 22)
                        .accessibilityHidden(true)

                    ForEach([(0.0, "自由", 0), (0.5, "微稳", 1), (1.0, "整齐", 2)], id: \.0) { val, label, tier in
                        let active = abs(vm.document.grooveStrength - val) < 0.25
                        Button {
                            vm.setGrooveStrength(val)
                            triggerAudition(.groove)
                        } label: {
                            GrooveDotPatternView(
                                tier: tier,
                                color: active ? (palette.isNight ? Color(hex: 0x0E142C) : .white) : palette.primaryInk
                            )
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(active ? palette.homeAnchor : palette.cardSurface)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("节奏\(label)")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }

                Rectangle()
                    .fill(palette.brassHairline.opacity(0.24))
                    .frame(height: 0.75)

                HStack(spacing: 6) {
                    Image(systemName: "tuningfork")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.brassHairline)
                        .frame(width: 22)
                        .accessibilityHidden(true)

                    ForEach(Array(RootTranspositionHelper.presetOffsets.enumerated()), id: \.element) { idx, offset in
                        let targetMIDI = 60 + offset
                        let active = vm.document.rootMIDI == targetMIDI
                        let barWidth = CGFloat(10 + idx * 3)
                        Button {
                            vm.setRootMIDI(targetMIDI)
                            triggerAudition(.pitch)
                        } label: {
                            VStack(spacing: 3) {
                                Text(RootTranspositionHelper.compactLabel(forRootMIDI: targetMIDI))
                                    .font(.caption2.weight(.bold).monospacedDigit())
                                Capsule()
                                    .fill(
                                        active
                                            ? (palette.isNight ? Color(hex: 0x0E142C) : .white).opacity(0.85)
                                            : palette.homeAnchor.opacity(0.45)
                                    )
                                    .frame(width: barWidth, height: 2.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(active ? palette.homeAnchor : palette.cardSurface)
                            )
                            .foregroundStyle(
                                active
                                    ? (palette.isNight ? Color(hex: 0x0E142C) : .white)
                                    : palette.primaryInk
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("音区\(RootTranspositionHelper.accessibilityLabel(forRootMIDI: targetMIDI))")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }
            }
            .padding(10)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: false)
        }
    }

    // MARK: - 6. Mie Melody Voice Cabinet

    private var mieVoiceCabinet: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
                let now = CACurrentMediaTime()
                let sweep: Double? = (auditionVoice != nil && !reduceMotion)
                    ? AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: now - auditionStartTime)
                    : nil

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            vm.auditionDuoCharacter(.mie)
                            triggerAudition(.voice, voice: vm.melodyVoice)
                        } label: {
                            HStack(spacing: 6) {
                                ChimmoCraftMark(.humWave, color: skyColor)
                                    .frame(width: 15, height: 15)
                                Text("咩 · 音色")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .foregroundStyle(palette.primaryInk)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(palette.cardSurface.opacity(0.92))
                                    .overlay(Capsule().strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.8))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("小羊咩，试听主旋律")

                        Spacer()

                        Text(vm.melodyVoice.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryInk)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(MelodyVoice.allCases) { v in
                            let active = vm.melodyVoice == v
                            let fgColor = active ? (palette.isNight ? Color(hex: 0x0E142C) : .white) : palette.primaryInk
                            let waveColor = active ? fgColor : palette.homeAnchor
                            Button {
                                vm.setMelodyVoice(v)
                                triggerAudition(.voice, voice: v)
                            } label: {
                                HStack(spacing: 8) {
                                    VoiceEnvelopeSparkView(
                                        points: AcousticSignatureGeometry.voiceEnvelopePoints(for: v),
                                        color: waveColor,
                                        filled: active,
                                        sweepProgress: auditionVoice == v ? sweep : nil
                                    )
                                    .frame(width: 44, height: 20)

                                    Text(v.label)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(fgColor)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(active ? palette.homeAnchor : palette.cardSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .strokeBorder(
                                                    active ? palette.glazeHighlight : palette.brassHairline.opacity(0.22),
                                                    lineWidth: 0.9
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(v.label)音色")
                            .accessibilityValue(active ? "已选中" : "")
                        }
                    }
                }
                .padding(11)
            }

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: true)
        }
    }

    // MARK: - 7. Mou Accompaniment & Chord Barcode Cabinet

    private var mouAccompanimentCabinet: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
                let now = CACurrentMediaTime()
                let sweep: Double? = (auditionTexture != nil && !reduceMotion)
                    ? AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: now - auditionStartTime)
                    : nil

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Button {
                            if !vm.cradleEnabled {
                                vm.setChordPreset(.autoMatch)
                            }
                            vm.auditionDuoCharacter(.mou)
                            triggerAudition(.texture, texture: vm.accompanimentTexture)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(vm.cradleEnabled ? palette.bassRibbon : palette.secondaryInk.opacity(0.35))
                                    .frame(width: 6.5, height: 6.5)
                                Text("哞 · 伴奏")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .foregroundStyle(palette.primaryInk)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(palette.cardSurface.opacity(0.92))
                                    .overlay(Capsule().strokeBorder(palette.brassHairline.opacity(0.32), lineWidth: 0.8))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("小牛哞，试听低音伴奏")

                        Spacer()

                        Text(vm.cradleEnabled ? vm.accompanimentTexture.label : "休息")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryInk)
                    }

                    ChordPresetBarcodeStrip(vm: vm, palette: palette) {
                        triggerAudition(.chord)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(AccompanimentTexture.allCases) { tex in
                            let active = vm.cradleEnabled && vm.accompanimentTexture == tex
                            let fgColor = active ? (palette.isNight ? Color(hex: 0x0E142C) : .white) : palette.primaryInk
                            let dotColor = active ? fgColor : palette.bassRibbon
                            let dots = AcousticSignatureGeometry.accompanimentPatternDots(for: tex)
                            let activeDot = (auditionTexture == tex && sweep != nil)
                                ? AcousticSignatureAnimationHelper.activeIndex(progress: sweep!, itemCount: dots.count)
                                : nil
                            Button {
                                vm.setAccompanimentTexture(tex)
                                triggerAudition(.texture, texture: tex)
                            } label: {
                                HStack(spacing: 8) {
                                    AccompanimentDotPatternView(
                                        dots: dots,
                                        color: dotColor,
                                        activeDotIndex: activeDot
                                    )
                                    .frame(width: 44, height: 20)

                                    Text(tex.label)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(fgColor)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(active ? palette.bassRibbon : palette.cardSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .strokeBorder(
                                                    active ? palette.glazeHighlight : palette.brassHairline.opacity(0.22),
                                                    lineWidth: 0.9
                                                )
                                        )
                                )
                                .opacity(vm.cradleEnabled ? 1.0 : 0.56)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(tex.label)伴奏")
                            .accessibilityValue(active ? "已选中" : "")
                        }
                    }
                }
                .padding(11)
            }

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: true)
        }
    }
}

// MARK: - Helper Subviews

private struct SoundBoxOscilloscopeWindow: View {
    let samples: [Double]
    let waveColor: Color
    let brassColor: Color
    var sweepProgress: Double? = nil

    var body: some View {
        Canvas { ctx, size in
            let w = max(1, size.width)
            let h = max(1, size.height)

            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 4, y: h * 0.5))
            centerLine.addLine(to: CGPoint(x: w - 4, y: h * 0.5))
            ctx.stroke(centerLine, with: .color(brassColor.opacity(0.28)), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))

            guard samples.count > 1 else { return }
            let padX: CGFloat = 6
            let padY: CGFloat = 4
            let usableW = max(1, w - padX * 2)
            let usableH = max(1, h - padY * 2)

            let pts: [CGPoint] = samples.enumerated().map { idx, val in
                let x = padX + (CGFloat(idx) / CGFloat(samples.count - 1)) * usableW
                let y = padY + (1.0 - CGFloat(max(0.0, min(1.0, val)))) * usableH
                return CGPoint(x: x, y: y)
            }

            var curve = Path()
            curve.move(to: pts[0])
            for i in 1..<pts.count {
                let prev = pts[i - 1]
                let cur = pts[i]
                let mid = CGPoint(x: (prev.x + cur.x) * 0.5, y: (prev.y + cur.y) * 0.5)
                curve.addQuadCurve(to: mid, control: prev)
            }
            if let last = pts.last {
                curve.addLine(to: last)
            }

            ctx.stroke(curve, with: .color(waveColor.opacity(0.28)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            ctx.stroke(curve, with: .color(waveColor.opacity(0.95)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            if let sweep = sweepProgress,
               let activeIdx = AcousticSignatureAnimationHelper.activeIndex(progress: sweep, itemCount: pts.count) {
                let activePt = pts[activeIdx]
                ctx.fill(
                    Path(ellipseIn: CGRect(x: activePt.x - 4.5, y: activePt.y - 4.5, width: 9.0, height: 9.0)),
                    with: .color(brassColor.opacity(0.36))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: activePt.x - 2.6, y: activePt.y - 2.6, width: 5.2, height: 5.2)),
                    with: .color(brassColor)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GrooveDotPatternView: View {
    let tier: Int
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let cy = size.height * 0.5
            if tier >= 2 {
                for frac in [0.16, 0.39, 0.61, 0.84] {
                    let x = size.width * CGFloat(frac)
                    var bar = Path()
                    bar.move(to: CGPoint(x: x, y: 2))
                    bar.addLine(to: CGPoint(x: x, y: size.height - 2))
                    ctx.stroke(bar, with: .color(color.opacity(0.32)), lineWidth: 1.0)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2.3, y: cy - 2.3, width: 4.6, height: 4.6)), with: .color(color))
                }
            } else if tier == 1 {
                let pts: [(Double, Double)] = [(0.16, 0.42), (0.39, 0.58), (0.61, 0.44), (0.84, 0.56)]
                for p in pts {
                    let pt = CGPoint(x: size.width * CGFloat(p.0), y: size.height * CGFloat(p.1))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.2, y: pt.y - 2.2, width: 4.4, height: 4.4)), with: .color(color))
                }
            } else {
                let pts: [(Double, Double)] = [(0.14, 0.72), (0.36, 0.28), (0.65, 0.75), (0.86, 0.34)]
                for p in pts {
                    let pt = CGPoint(x: size.width * CGFloat(p.0), y: size.height * CGFloat(p.1))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.2, y: pt.y - 2.2, width: 4.4, height: 4.4)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct VoiceEnvelopeSparkView: View {
    let points: [Double]
    let color: Color
    let filled: Bool
    var sweepProgress: Double? = nil

    var body: some View {
        Canvas { ctx, size in
            guard points.count > 1 else { return }
            let padX: CGFloat = 2
            let padY: CGFloat = 2
            let w = max(1, size.width - padX * 2)
            let h = max(1, size.height - padY * 2)

            var line = Path()
            var area = Path()
            for (idx, v) in points.enumerated() {
                let x = padX + (CGFloat(idx) / CGFloat(points.count - 1)) * w
                let y = padY + (1.0 - CGFloat(max(0.0, min(1.0, v)))) * h
                if idx == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                    area.move(to: CGPoint(x: x, y: size.height - padY))
                    area.addLine(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                    area.addLine(to: CGPoint(x: x, y: y))
                }
            }
            area.addLine(to: CGPoint(x: size.width - padX, y: size.height - padY))
            area.closeSubpath()

            ctx.fill(area, with: .color(color.opacity(filled ? 0.24 : 0.14)))
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

            if let sweep = sweepProgress,
               let idx = AcousticSignatureAnimationHelper.activeIndex(progress: sweep, itemCount: points.count) {
                let x = padX + (CGFloat(idx) / CGFloat(points.count - 1)) * w
                let y = padY + (1.0 - CGFloat(max(0.0, min(1.0, points[idx])))) * h
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 3.6, y: y - 3.6, width: 7.2, height: 7.2)),
                    with: .color(color.opacity(0.32))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AccompanimentDotPatternView: View {
    let dots: [AcousticSignatureGeometry.PatternDot]
    let color: Color
    var activeDotIndex: Int? = nil

    var body: some View {
        Canvas { ctx, size in
            let padX: CGFloat = 4
            let padY: CGFloat = 3
            let w = max(1, size.width - padX * 2)
            let h = max(1, size.height - padY * 2)
            for (idx, dot) in dots.enumerated() {
                let px = padX + CGFloat(dot.x) * w
                let py = padY + (1.0 - CGFloat(dot.y)) * h
                let isActive = activeDotIndex == idx
                let r = CGFloat(2.0 * dot.radiusScale * (isActive ? 1.55 : 1.0))
                if isActive {
                    let haloR = r + 2.2
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - haloR, y: py - haloR, width: haloR * 2, height: haloR * 2)),
                        with: .color(color.opacity(0.30))
                    )
                }
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                    with: .color(color.opacity(isActive ? 1.0 : 0.85))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ChordPresetBarcodeStrip: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette
    let onSelect: () -> Void

    private let orderedPresets: [ChordProgressionPreset] = [
        .off, .autoMatch, .classicPop, .summerFloat, .warmStory
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedPresets) { preset in
                let selected = vm.chordPreset == preset
                let tag = HarmonyCurtainStripMapper.shortPresetTag(for: preset)
                let colors: [Color] = preset.sequence.map { $0.color(isNight: palette.isNight) }

                Button {
                    vm.setChordPreset(preset)
                    onSelect()
                } label: {
                    VStack(spacing: 4) {
                        if colors.isEmpty {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk.opacity(0.65))
                                .frame(height: 8)
                        } else {
                            HStack(spacing: 2) {
                                ForEach(Array(colors.enumerated()), id: \.offset) { _, col in
                                    Capsule()
                                        .fill(col.opacity(selected ? 0.96 : 0.62))
                                        .frame(height: 4.5)
                                }
                            }
                            .padding(.horizontal, 5)
                            .frame(height: 8)
                        }

                        Text(tag)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? palette.bassRibbon.opacity(palette.isNight ? 0.22 : 0.13) : palette.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? palette.brassHairline : Color.clear, lineWidth: 1.3)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.label)
                .accessibilityValue(selected ? "已选中" : "")
            }
        }
    }
}
