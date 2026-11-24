import QuartzCore
import SwiftUI

/// 童书声音调色盒（Flat Cartoon Best Kids' Book Design × 咩哞合唱绘本工作台，零拟物）：
/// - 顶部：扁平卡通外观平衡贴纸 + 扇形波浪彩带分隔；
/// - 核心舞台：绘本草坡合唱剧场（平涂天空 + 太阳/新月云朵 + 起伏草坡），声波示波线实时呼应「咩 × 1·3·5 三音小偶 × 哞」；
/// - 控制区：扁平漫画拨片三连开关、五色极光调式卡纸、波浪分隔三层混音盒、以及「咩 · 音色」「哞 · 伴奏」IP 专属卡片。
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

                VStack(spacing: 8) {
                    soundBoxCrownHeader
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 9) {
                            soundBoxDioramaOscilloscope
                            brassToggleSwitchBank
                            auroraScalePaletteBox
                            tempoGroovePitchCabinet
                            mieVoiceCabinet
                            mouAccompanimentCabinet
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 18)
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
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
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
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(
                                Capsule().fill(active ? palette.prominentFill : Color.clear)
                            )
                            .foregroundStyle(active ? Color.white : palette.secondaryInk)
                            .frame(
                                minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                    .accessibilityLabel(pref.label)
                    .accessibilityValue(active ? "已选中" : "")
                }
            }
            .fixedSize()
            .padding(3)
            .background(
                Capsule()
                    .fill(palette.cardSurface)
                    .shadow(
                        color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.22),
                        radius: 3.5,
                        y: 1.5
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                    )
            )
            .contentShape(Capsule())

            Button {
                auditionResetTask?.cancel()
                auditionResetTask = nil
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
            .accessibilityLabel("完成声音设置")
        }
    }

    // MARK: - 2. Compact Storybook Meadow Oscilloscope + Mie / 1-3-5 Triad / Mou Chorus

    private var soundBoxDioramaOscilloscope: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let skyBg = palette.insetStageSurface
        let focusedDeg = SoundPaletteBoxKinematics.triadFocusDegree(for: activeChannel)
        let shelfFigures: [ChimmoMember] = [.taono, .plokko, .corllo]

        return TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
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

            ZStack(alignment: .bottom) {
                Canvas { ctx, size in
                    let w = max(1, size.width)
                    let h = max(1, size.height)
                    let ink = palette.primaryInk.opacity(palette.isNight ? 0.20 : 0.14)

                    if palette.isNight {
                        let moonC = CGPoint(x: w * 0.90, y: 16)
                        var moon = Path()
                        moon.addArc(center: moonC, radius: 8.5, startAngle: .degrees(30), endAngle: .degrees(290), clockwise: false)
                        moon.addQuadCurve(
                            to: CGPoint(x: moonC.x + 8.5 * cos(30 * .pi / 180), y: moonC.y + 8.5 * sin(30 * .pi / 180)),
                            control: CGPoint(x: moonC.x - 1.8, y: moonC.y - 1)
                        )
                        ctx.fill(moon, with: .color(palette.nightLampGold))
                        ctx.stroke(moon, with: .color(ink), lineWidth: 1.1)
                    } else {
                        let sunC = CGPoint(x: w * 0.90, y: 16)
                        let sun = Path(ellipseIn: CGRect(x: sunC.x - 8.5, y: sunC.y - 8.5, width: 17, height: 17))
                        ctx.fill(sun, with: .color(palette.storybookButter))
                        ctx.stroke(sun, with: .color(ink), lineWidth: 1.2)
                        for i in 0..<6 {
                            let a = Double(i) * Double.pi / 3.0
                            var r = Path()
                            r.move(to: CGPoint(x: sunC.x + CGFloat(cos(a)) * 11, y: sunC.y + CGFloat(sin(a)) * 11))
                            r.addLine(to: CGPoint(x: sunC.x + CGFloat(cos(a)) * 14, y: sunC.y + CGFloat(sin(a)) * 14))
                            ctx.stroke(r, with: .color(palette.brassHairline), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        }
                    }

                    var hill = Path()
                    let hillY = h * 0.72
                    hill.move(to: CGPoint(x: 0, y: hillY + 4))
                    hill.addQuadCurve(to: CGPoint(x: w * 0.5, y: hillY - 3), control: CGPoint(x: w * 0.25, y: hillY - 10))
                    hill.addQuadCurve(to: CGPoint(x: w, y: hillY + 2), control: CGPoint(x: w * 0.75, y: hillY + 8))
                    var area = hill
                    area.addLine(to: CGPoint(x: w, y: h))
                    area.addLine(to: CGPoint(x: 0, y: h))
                    area.closeSubpath()
                    ctx.fill(area, with: .color(palette.storybookHillFront))
                    ctx.stroke(hill, with: .color(ink), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

                VStack(spacing: 2) {
                    Button {
                        vm.auditionDuoGreeting()
                        triggerAudition(.voice)
                    } label: {
                        SoundBoxOscilloscopeWindow(
                            samples: samples,
                            waveColor: skyColor,
                            outlineColor: palette.primaryInk.opacity(palette.isNight ? 0.32 : 0.22),
                            dotColor: palette.nightLampGold,
                            sweepProgress: sweep
                        )
                        .frame(height: 28)
                        .frame(maxWidth: .infinity, minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                    .accessibilityLabel("波形示波窗，轻点试听当前音色与双子合奏")

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
                            .frame(width: 36, height: 32)
                            .frame(
                                minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                            )
                            .contentShape(Circle())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
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
                                .scaleEffect(0.62, anchor: .bottom)
                                .frame(width: 34, height: 36, alignment: .bottom)
                                .frame(
                                    minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                    minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                    alignment: .bottom
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
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
                            .frame(width: 36, height: 32)
                            .frame(
                                minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                            )
                            .contentShape(Circle())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("小牛哞，试听低音伴奏")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                    .fill(skyBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                            .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 1.0)
                    )
            )
        }
        .frame(height: 96)
    }

    // MARK: - 3. Flat Cartoon Pull-Tab Toggle Bank

    private var brassToggleSwitchBank: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            HStack(spacing: 8) {
                brassToggleSwitchPad(
                    symbol: .pentatonicArc,
                    shortLabel: "五音",
                    accessibilityTitle: "五音模式",
                    isOn: vm.pentatonicSafe,
                    activeColor: palette.celadonAccent
                ) {
                    vm.togglePentatonicSafe()
                    triggerAudition(.pitch)
                }

                brassToggleSwitchPad(
                    symbol: .counterpointMoons,
                    shortLabel: "伴唱",
                    accessibilityTitle: "自动伴唱",
                    isOn: vm.shadowCounterpointEnabled,
                    activeColor: palette.counterpointMoon
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
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(palette.isNight ? palette.paper : palette.storybookButter.opacity(0.48))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.22 : 0.14), lineWidth: 1.0)
                        )
                        .frame(width: 14, height: 28)

                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(isOn ? activeColor : palette.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.28 : 0.22), lineWidth: 1.0)
                        )
                        .frame(width: 11, height: 13)
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
                            .fill(isOn ? activeColor : palette.divider)
                            .frame(width: 6.5, height: 6.5)
                            .overlay(
                                Circle()
                                    .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.16), lineWidth: 1.0)
                            )
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
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
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
                                .fill(selected ? skyCol : palette.cardSurface)
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.16), lineWidth: 1.0)
                                )

                            Image(systemName: mode.iconName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(skyCol)

                            Capsule()
                                .fill(skyCol.opacity(selected ? 1.0 : 0.60))
                                .frame(height: 4.5)
                                .overlay(Capsule().strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.16), lineWidth: 1.0))
                                .padding(.horizontal, 6)

                            Text(mode.shortSkyLabel)
                                .font(.system(.caption2, design: .rounded).weight(.heavy))
                                .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
                        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                    .accessibilityLabel("\(mode.label)风格")
                    .accessibilityValue(selected ? "已选中" : "")
                }
            }
            .padding(8)
        }
    }

    // MARK: - 5. Tempo x Groove x Pitch Storybook Mixing Box

    private var tempoGroovePitchCabinet: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ChimmoCraftMark(.tempoDial, color: palette.secondaryInk)
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
                                .font(.caption.weight(.heavy).monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                                .background(
                                    Capsule()
                                        .fill(active ? palette.prominentFill : palette.cardSurface)
                                        .shadow(
                                            color: active
                                                ? palette.prominentFill.opacity(palette.isNight ? 0.30 : 0.22)
                                                : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.20),
                                            radius: 3.5,
                                            y: 1.5
                                        )
                                        .overlay(
                                            Capsule().strokeBorder(
                                                active ? Color.white.opacity(0.30) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                                lineWidth: 0.9
                                            )
                                        )
                                )
                                .foregroundStyle(active ? Color.white : palette.primaryInk)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.3))
                        .accessibilityLabel("播放速度 \(label)")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)

                HStack(spacing: 6) {
                    Image(systemName: "metronome")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
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
                                color: active ? Color.white : palette.primaryInk
                            )
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 34)
                            .background(
                                Capsule()
                                    .fill(active ? palette.prominentFill : palette.cardSurface)
                                    .shadow(
                                        color: active
                                            ? palette.prominentFill.opacity(palette.isNight ? 0.30 : 0.22)
                                            : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.20),
                                        radius: 3.5,
                                        y: 1.5
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(
                                            active ? Color.white.opacity(0.30) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                            lineWidth: 0.9
                                        )
                                    )
                            )
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.3))
                        .accessibilityLabel("节奏\(label)")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)

                HStack(spacing: 6) {
                    Image(systemName: "tuningfork")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
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
                                    .font(.caption2.weight(.heavy).monospacedDigit())
                                Capsule()
                                    .fill(active ? Color.white : palette.homeAnchor.opacity(0.65))
                                    .frame(width: barWidth, height: 2.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 34)
                            .background(
                                Capsule()
                                    .fill(active ? palette.prominentFill : palette.cardSurface)
                                    .shadow(
                                        color: active
                                            ? palette.prominentFill.opacity(palette.isNight ? 0.30 : 0.22)
                                            : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.20),
                                        radius: 3.5,
                                        y: 1.5
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(
                                            active ? Color.white.opacity(0.30) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                            lineWidth: 0.9
                                        )
                                    )
                            )
                            .foregroundStyle(active ? Color.white : palette.primaryInk)
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.3))
                        .accessibilityLabel("音区\(RootTranspositionHelper.accessibilityLabel(forRootMIDI: targetMIDI))")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }
            }
            .padding(9)
        }
    }

    // MARK: - 6. Mie Melody Voice Cabinet (Deep IP Fusion)

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
                        HStack(spacing: 6) {
                            ChimmoSheepView(
                                isNight: palette.isNight,
                                accentColor: skyColor,
                                isSinging: auditionVoice != nil || vm.isPlaying,
                                phaseTime: reduceMotion ? 0.0 : now
                            )
                            .frame(width: 24, height: 20)

                            Text("主旋律音色 · \(vm.melodyVoice.label)")
                                .font(.system(.caption, design: .rounded).weight(.heavy))
                                .foregroundStyle(palette.primaryInk)
                                .accessibilityAddTraits(.isHeader)
                        }

                        Spacer()

                        Button {
                            vm.auditionDuoCharacter(.mie)
                            triggerAudition(.voice, voice: vm.melodyVoice)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption2.weight(.bold))
                                Text("试听")
                                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .padding(.horizontal, 11)
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .background(
                                ChimmoKilnPillButtonSurface(
                                    palette: palette,
                                    accent: palette.nightLampGold,
                                    isActive: true,
                                    cornerRadius: 20
                                )
                            )
                            .foregroundStyle(palette.primaryInk)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("试听小羊咩主旋律音色")
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(MelodyVoice.allCases) { v in
                            let active = vm.melodyVoice == v
                            let fgColor = active ? Color.white : palette.primaryInk
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
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(fgColor)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(active ? palette.prominentFill : palette.cardSurface)
                                        .shadow(
                                            color: active
                                                ? palette.prominentFill.opacity(palette.isNight ? 0.30 : 0.22)
                                                : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.20),
                                            radius: 4,
                                            y: 2
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .strokeBorder(
                                                    active ? Color.white.opacity(0.32) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                                    lineWidth: 1.0
                                                )
                                        )
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("\(v.label)音色")
                            .accessibilityValue(active ? "已选中" : "")
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    // MARK: - 7. Mou Accompaniment & Chord Sticker Cabinet (Deep IP Fusion)

    private var mouAccompanimentCabinet: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)

        return ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
                let now = CACurrentMediaTime()
                let sweep: Double? = (auditionTexture != nil && !reduceMotion)
                    ? AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: now - auditionStartTime)
                    : nil

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            ChimmoCowView(
                                isNight: palette.isNight,
                                accentColor: skyColor,
                                isAwake: vm.cradleEnabled,
                                isPlaying: auditionTexture != nil || vm.isPlaying,
                                phaseTime: reduceMotion ? 0.0 : now
                            )
                            .frame(width: 24, height: 20)

                            Text("和声与伴奏 · \(vm.cradleEnabled ? vm.accompanimentTexture.label : "休息")")
                                .font(.system(.caption, design: .rounded).weight(.heavy))
                                .foregroundStyle(palette.primaryInk)
                                .accessibilityAddTraits(.isHeader)
                        }

                        Spacer()

                        Button {
                            if !vm.cradleEnabled {
                                vm.setChordPreset(.autoMatch)
                            }
                            vm.auditionDuoCharacter(.mou)
                            triggerAudition(.texture, texture: vm.accompanimentTexture)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption2.weight(.bold))
                                Text("试听")
                                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .padding(.horizontal, 11)
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .background(
                                ChimmoKilnPillButtonSurface(
                                    palette: palette,
                                    accent: palette.celadonAccent,
                                    isActive: true,
                                    cornerRadius: 20
                                )
                            )
                            .foregroundStyle(palette.primaryInk)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("试听小牛哞低音伴奏")
                    }

                    ChordPresetBarcodeStrip(vm: vm, palette: palette) {
                        triggerAudition(.chord)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(AccompanimentTexture.allCases) { tex in
                            let active = vm.cradleEnabled && vm.accompanimentTexture == tex
                            let fgColor = active ? palette.contrastInkOnAccent : palette.primaryInk
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
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(fgColor)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(active ? palette.bassRibbon : palette.cardSurface)
                                        .shadow(
                                            color: active
                                                ? palette.bassRibbon.opacity(palette.isNight ? 0.28 : 0.22)
                                                : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.20),
                                            radius: 4,
                                            y: 2
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .strokeBorder(
                                                    active ? Color.white.opacity(0.32) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                                    lineWidth: 1.0
                                                )
                                        )
                                )
                                .opacity(vm.cradleEnabled ? 1.0 : 0.65)
                                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("\(tex.label)伴奏")
                            .accessibilityValue(active ? "已选中" : "")
                        }
                    }
                }
                .padding(10)
            }
        }
    }
}

// MARK: - Helper Subviews

private struct SoundBoxOscilloscopeWindow: View {
    let samples: [Double]
    let waveColor: Color
    let outlineColor: Color
    let dotColor: Color
    var sweepProgress: Double? = nil

    var body: some View {
        Canvas { ctx, size in
            let w = max(1, size.width)
            let h = max(1, size.height)

            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 4, y: h * 0.5))
            centerLine.addLine(to: CGPoint(x: w - 4, y: h * 0.5))
            ctx.stroke(centerLine, with: .color(outlineColor.opacity(0.22)), style: StrokeStyle(lineWidth: 1.0, dash: [3, 4]))

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

            ctx.stroke(curve, with: .color(outlineColor.opacity(0.85)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
            ctx.stroke(curve, with: .color(waveColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            if let sweep = sweepProgress,
               let activeIdx = AcousticSignatureAnimationHelper.activeIndex(progress: sweep, itemCount: pts.count) {
                let activePt = pts[activeIdx]
                let dotRect = CGRect(x: activePt.x - 4.0, y: activePt.y - 4.0, width: 8.0, height: 8.0)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                ctx.stroke(Path(ellipseIn: dotRect), with: .color(outlineColor), lineWidth: 1.4)
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
                                .font(.caption2.weight(.bold))
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
                            .font(.system(.caption2, design: .rounded).weight(.heavy).monospacedDigit())
                            .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? palette.bassRibbon.opacity(palette.isNight ? 0.28 : 0.16) : palette.cardSurface)
                            .shadow(
                                color: selected
                                    ? palette.bassRibbon.opacity(palette.isNight ? 0.24 : 0.16)
                                    : palette.elevationShadow(dayOpacity: 0.07, nightOpacity: 0.18),
                                radius: 3,
                                y: 1.5
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        selected ? palette.bassRibbon.opacity(0.75) : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                        lineWidth: selected ? 1.3 : 0.9
                                    )
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel(preset.label)
                .accessibilityValue(selected ? "已选中" : "")
            }
        }
    }
}
