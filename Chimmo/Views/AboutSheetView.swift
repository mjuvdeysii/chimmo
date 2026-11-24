import QuartzCore
import SwiftUI

/// 明信片、立体声音频与标准 MIDI 导出请求载体
public struct VinylPostcardRequest: Identifiable, Sendable {
    public let id: UUID
    public let document: MelodyDocument
    public let chordPreset: ChordProgressionPreset
    public let chordOverrides: [Int: DiatonicChord]
    public let accompanimentTexture: AccompanimentTexture
    public let melodyVoice: MelodyVoice?
    public let shadowEnabled: Bool
    public let playbackRate: Double
    public let headline: String?
    public let visualMode: StageVisualMode

    public init(
        id: UUID = UUID(),
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        accompanimentTexture: AccompanimentTexture = .swanRipple,
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        playbackRate: Double = 1.0,
        headline: String? = nil,
        visualMode: StageVisualMode = .orbitalDisc
    ) {
        self.id = id
        self.document = document
        self.chordPreset = chordPreset
        self.chordOverrides = chordOverrides
        self.accompanimentTexture = accompanimentTexture
        self.melodyVoice = melodyVoice
        self.shadowEnabled = shadowEnabled
        self.playbackRate = playbackRate
        self.headline = headline
        self.visualMode = visualMode
    }
}

/// 离线扁平卡通黑胶星轨明信片、可播音频 & 标准 MIDI 分享抽屉（零 Emoji，零模糊投影，童书绘本印刷体验）
public struct VinylPostcardShareSheet: View {
    public let palette: ChimmoPalette
    public let request: VinylPostcardRequest

    @Environment(\.dismiss) private var dismiss
    @State private var useNightCard: Bool
    @State private var selectedMode: StageVisualMode
    @State private var exportedPNGURL: URL?
    @State private var exportedWAVURL: URL?
    @State private var isRenderingWAV: Bool = false
    @State private var exportedMIDIURL: URL?
    @State private var showJianpuStrip: Bool = false

    public init(palette: ChimmoPalette, request: VinylPostcardRequest) {
        self.palette = palette
        self.request = request
        self._useNightCard = State(initialValue: palette.isNight)
        self._selectedMode = State(initialValue: request.visualMode)
    }

    private var snapshot: VinylPostcardSnapshot {
        VinylPostcardSnapshot(
            document: request.document,
            chordPreset: request.chordPreset,
            chordOverrides: request.chordOverrides,
            melodyVoice: request.melodyVoice,
            shadowEnabled: request.shadowEnabled,
            isNight: useNightCard,
            headline: request.headline,
            visualMode: selectedMode,
            includeJianpuStrip: showJianpuStrip
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: request.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                ScrollView {
                    VStack(spacing: 12) {
                        // 扁平卡通日夜纸卡片 + 三态画境切换 + 简谱印记开关（消除透明热区穿透）
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                ForEach([false, true], id: \.self) { nightFlag in
                                    let active = useNightCard == nightFlag
                                    Button {
                                        useNightCard = nightFlag
                                        AcousticHapticsEngine.shared.playScrubTick()
                                    } label: {
                                        Image(systemName: nightFlag ? "moon.stars.fill" : "sun.max.fill")
                                            .font(.system(size: 12.5, weight: .bold))
                                            .frame(width: 38, height: 34)
                                            .background(Capsule().fill(active ? palette.homeAnchor : Color.clear))
                                            .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x0E142C) : .white) : palette.secondaryInk)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                                    .accessibilityLabel(nightFlag ? "深色明信片" : "浅色明信片")
                                    .accessibilityValue(active ? "已选中" : "")
                                }
                            }
                            .padding(3)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(palette.cartoonShadow)
                                        .offset(y: 1.5)
                                    Capsule()
                                        .fill(palette.cardSurface)
                                    Capsule()
                                        .strokeBorder(palette.cartoonOutline.opacity(palette.isNight ? 0.60 : 0.78), lineWidth: 1.4)
                                }
                            )
                            .contentShape(Capsule())
                            .fixedSize()

                            Spacer(minLength: 4)

                            HStack(spacing: 2) {
                                ForEach(StageVisualMode.allCases) { mode in
                                    let active = selectedMode == mode
                                    Button {
                                        selectedMode = mode
                                    } label: {
                                        Image(systemName: mode.iconName)
                                            .font(.system(size: 12.5, weight: .bold))
                                            .frame(width: 36, height: 34)
                                            .background(Capsule().fill(active ? palette.homeAnchor : Color.clear))
                                            .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x0E142C) : .white) : palette.secondaryInk)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                                    .accessibilityLabel("\(mode.rawValue)样式")
                                }
                            }
                            .padding(3)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(palette.cartoonShadow)
                                        .offset(y: 1.5)
                                    Capsule()
                                        .fill(palette.cardSurface)
                                    Capsule()
                                        .strokeBorder(palette.cartoonOutline.opacity(palette.isNight ? 0.60 : 0.78), lineWidth: 1.4)
                                }
                            )
                            .contentShape(Capsule())
                            .fixedSize()

                            Button {
                                showJianpuStrip.toggle()
                                AcousticHapticsEngine.shared.playScrubTick()
                            } label: {
                                Image(systemName: "textformat.123")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        ChimmoKilnPillButtonSurface(
                                            palette: palette,
                                            accent: palette.homeAnchor,
                                            isActive: showJianpuStrip,
                                            cornerRadius: 14
                                        )
                                    )
                                    .foregroundStyle(showJianpuStrip ? palette.homeAnchor : palette.secondaryInk)
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("在明信片显示简谱音符")
                            .accessibilityValue(showJianpuStrip ? "已开启" : "已关闭")
                        }
                        .padding(.horizontal, 14)

                        // 等比缩放呈现 540x680 扁平卡通绘本明信片预览（硬朗无模糊位移阴影 + 暖墨描边）
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.cartoonShadow)
                                .frame(width: 270, height: 340)
                                .offset(x: 4, y: 5)

                            VinylPostcardCanvasView(snapshot: snapshot)
                                .scaleEffect(0.5)
                                .frame(width: 270, height: 340)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(palette.cartoonOutline, lineWidth: 2.0)
                                )
                        }

                        HStack(spacing: 10) {
                            if let pngURL = exportedPNGURL {
                                ShareLink(item: pngURL) {
                                    VStack(spacing: 5) {
                                        ChimmoCraftMark(
                                            .vinylSeal,
                                            color: palette.isNight ? Color(hex: 0x0E142C) : .white
                                        )
                                        .frame(width: 18, height: 18)
                                        Text("PNG")
                                            .font(.caption.weight(.heavy).monospaced())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.cartoonShadow)
                                                .offset(y: 3)
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.homeAnchor)
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(palette.cartoonOutline, lineWidth: 1.8)
                                        }
                                    )
                                    .foregroundStyle(palette.isNight ? Color(hex: 0x0E142C) : .white)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.8))
                                .accessibilityLabel("分享图片 PNG")
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(StorybookQuietCardSurface(palette: palette, cornerRadius: 16))
                            }

                            if let wavURL = exportedWAVURL {
                                ShareLink(item: wavURL) {
                                    VStack(spacing: 5) {
                                        Image(systemName: "waveform")
                                            .font(.subheadline.weight(.bold))
                                        Text("WAV")
                                            .font(.caption.weight(.heavy).monospaced())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.cartoonShadow)
                                                .offset(y: 3)
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.storybookButter)
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(palette.cartoonOutline, lineWidth: 1.8)
                                        }
                                    )
                                    .foregroundStyle(palette.primaryInk)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.8))
                                .accessibilityLabel("分享立体声音频 WAV")
                            } else if isRenderingWAV {
                                VStack(spacing: 5) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("WAV")
                                        .font(.caption.weight(.heavy).monospaced())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(StorybookQuietCardSurface(palette: palette, cornerRadius: 16))
                                .foregroundStyle(palette.secondaryInk)
                            } else {
                                VStack(spacing: 5) {
                                    Image(systemName: "waveform")
                                        .font(.subheadline.weight(.semibold))
                                    Text("WAV")
                                        .font(.caption.weight(.heavy).monospaced())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(StorybookQuietCardSurface(palette: palette, cornerRadius: 16))
                                .foregroundStyle(palette.secondaryInk.opacity(0.6))
                            }

                            if let midiURL = exportedMIDIURL {
                                ShareLink(item: midiURL) {
                                    VStack(spacing: 5) {
                                        Image(systemName: "pianokeys")
                                            .font(.subheadline.weight(.semibold))
                                        Text("MIDI")
                                            .font(.caption.weight(.heavy).monospaced())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.cartoonShadow)
                                                .offset(y: 3)
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.storybookMint)
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(palette.cartoonOutline, lineWidth: 1.8)
                                        }
                                    )
                                    .foregroundStyle(palette.primaryInk)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.8))
                                .accessibilityLabel("导出 MIDI")
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(StorybookQuietCardSurface(palette: palette, cornerRadius: 16))
                            }
                        }
                        .padding(.horizontal, 14)

                        HStack(spacing: 8) {
                            ChimmoCartoonKeyBuddyView(
                                member: snapshot.heroMember,
                                outlineColor: palette.cartoonOutline,
                                isSinging: true,
                                isMinor: request.document.scaleMode.isMinorFlavored
                            )
                            .frame(width: 24, height: 20)

                            Label("本机离线印制 · \(snapshot.heroMember.chineseName)守护", systemImage: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(palette.homeAnchor.opacity(palette.isNight ? 0.20 : 0.12))
                        )
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("分享作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                refreshFiles()
            }
            .task(id: request.id) {
                isRenderingWAV = true
                let req = request
                let url = await Task.detached(priority: .userInitiated) {
                    try? StudioAudioExporter.writeTemporaryWAVFile(
                        document: req.document,
                        chordPreset: req.chordPreset,
                        chordOverrides: req.chordOverrides,
                        accompanimentTexture: req.accompanimentTexture,
                        melodyVoice: req.melodyVoice,
                        shadowEnabled: req.shadowEnabled,
                        playbackRate: req.playbackRate,
                        visualMode: req.visualMode
                    )
                }.value
                if !Task.isCancelled {
                    exportedWAVURL = url
                    isRenderingWAV = false
                }
            }
            .onChange(of: useNightCard) { _, _ in
                refreshPostcardOnly()
            }
            .onChange(of: selectedMode) { _, _ in
                refreshPostcardOnly()
            }
            .onChange(of: showJianpuStrip) { _, _ in
                refreshPostcardOnly()
            }
        }
        .presentationDetents([.large])
    }

    private func refreshPostcardOnly() {
        exportedPNGURL = try? VinylPostcardExporter.writeTemporaryPostcardFile(
            document: request.document,
            chordPreset: request.chordPreset,
            chordOverrides: request.chordOverrides,
            melodyVoice: request.melodyVoice,
            shadowEnabled: request.shadowEnabled,
            isNight: useNightCard,
            headline: request.headline,
            visualMode: selectedMode,
            includeJianpuStrip: showJianpuStrip
        )
    }

    private func refreshFiles() {
        refreshPostcardOnly()
        exportedMIDIURL = try? MIDIExporter.writeTemporaryMIDIFile(
            document: request.document,
            includeHarmonyCradle: request.chordPreset != .off,
            melodyVoice: request.melodyVoice,
            includeShadowCounterpoint: request.shadowEnabled,
            chordPreset: request.chordPreset,
            chordOverrides: request.chordOverrides
        )
    }
}

/// 应用内「关于与隐私承诺」页（互动「咩 × 哞」二重奏小剧场 + 统一分享直达 + 可折叠合规声明）。
public struct AboutSheetView: View {
    public let palette: ChimmoPalette
    public let currentDocument: MelodyDocument
    public let cradleEnabled: Bool
    public let chordPreset: ChordProgressionPreset
    public let chordOverrides: [Int: DiatonicChord]
    public let accompanimentTexture: AccompanimentTexture
    public let melodyVoice: MelodyVoice?
    public let shadowEnabled: Bool
    public let playbackRate: Double
    public let visualMode: StageVisualMode
    public let onAuditionDuo: (ChimmoDuoCharacter) -> Void
    public let onAuditionMember: (ChimmoMember) -> Void
    public let onOpenSharePostcard: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var auditioningDuo: ChimmoDuoCharacter? = nil
    @State private var duoResetTask: Task<Void, Never>? = nil
    @State private var focusedMemberDegree: Int? = nil
    @State private var lastSweptDegree: Int? = nil
    @State private var memberResetTask: Task<Void, Never>? = nil
    @State private var showLegalDetails: Bool = false

    public init(
        palette: ChimmoPalette,
        currentDocument: MelodyDocument,
        cradleEnabled: Bool,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        accompanimentTexture: AccompanimentTexture = .swanRipple,
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        playbackRate: Double = 1.0,
        visualMode: StageVisualMode = .orbitalDisc,
        onAuditionDuo: @escaping (ChimmoDuoCharacter) -> Void = { _ in },
        onAuditionMember: @escaping (ChimmoMember) -> Void = { _ in },
        onOpenSharePostcard: (() -> Void)? = nil
    ) {
        self.palette = palette
        self.currentDocument = currentDocument
        self.cradleEnabled = cradleEnabled
        self.chordPreset = chordPreset
        self.chordOverrides = chordOverrides
        self.accompanimentTexture = accompanimentTexture
        self.melodyVoice = melodyVoice
        self.shadowEnabled = shadowEnabled
        self.playbackRate = playbackRate
        self.visualMode = visualMode
        self.onAuditionDuo = onAuditionDuo
        self.onAuditionMember = onAuditionMember
        self.onOpenSharePostcard = onOpenSharePostcard
    }

    private func triggerDuoAudition(_ character: ChimmoDuoCharacter) {
        onAuditionDuo(character)
        auditioningDuo = character
        duoResetTask?.cancel()
        duoResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            if !Task.isCancelled && auditioningDuo == character {
                auditioningDuo = nil
            }
        }
    }

    private func triggerMemberAudition(_ member: ChimmoMember) {
        onAuditionMember(member)
        focusedMemberDegree = member.degree
        memberResetTask?.cancel()
        memberResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            if !Task.isCancelled && focusedMemberDegree == member.degree {
                focusedMemberDegree = nil
            }
        }
    }

    public var body: some View {
        let skyColor = currentDocument.scaleMode.skyAuroraColor(isNight: palette.isNight)

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: skyColor
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // 扁平卡通「咩 × 哞」双子声学剧场 + 七只音阶小偶草原合唱舞台
                        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
                            let phaseTime = reduceMotion ? 0.0 : CACurrentMediaTime()
                            let sheepGaze: Double = {
                                if let deg = focusedMemberDegree { return Double(deg - 4) / 3.0 }
                                return auditioningDuo == .mou ? 0.65 : 0.0
                            }()
                            let cowGaze: Double = {
                                if let deg = focusedMemberDegree { return Double(deg - 4) / 3.0 }
                                return auditioningDuo == .mie ? -0.65 : 0.0
                            }()

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    ForEach(ChimmoDuoCharacter.allCases) { character in
                                        let active = auditioningDuo == character
                                        Button {
                                            triggerDuoAudition(character)
                                        } label: {
                                            VStack(spacing: 8) {
                                                Group {
                                                    if character == .mie {
                                                        ChimmoSheepView(
                                                            isNight: palette.isNight,
                                                            accentColor: skyColor,
                                                            isSinging: active,
                                                            phaseTime: phaseTime,
                                                            gazeBias: sheepGaze
                                                        )
                                                    } else {
                                                        ChimmoCowView(
                                                            isNight: palette.isNight,
                                                            accentColor: skyColor,
                                                            isAwake: true,
                                                            isPlaying: active,
                                                            phaseTime: phaseTime,
                                                            gazeBias: cowGaze
                                                        )
                                                    }
                                                }
                                                .frame(width: 68, height: 56)

                                                HStack(spacing: 4) {
                                                    Text(character.chineseName)
                                                        .font(.subheadline.weight(.heavy))
                                                        .foregroundStyle(palette.primaryInk)
                                                    Text("· \(character.roleShort)")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(palette.secondaryInk)
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .overlay(alignment: .topTrailing) {
                                                Image(systemName: "speaker.wave.2.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(active ? skyColor : palette.secondaryInk.opacity(0.75))
                                                    .padding(8)
                                            }
                                            .background(
                                                ChimmoKilnPillButtonSurface(
                                                    palette: palette,
                                                    accent: skyColor,
                                                    isActive: active,
                                                    cornerRadius: 16
                                                )
                                            )
                                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                                        .accessibilityLabel(character.accessibilityLabel)
                                        .accessibilityHint("轻点试听专属声部")
                                    }
                                }

                                GeometryReader { geo in
                                    let itemW = max(1.0, geo.size.width / 7.0)
                                    let figScale = min(0.92, max(0.66, itemW / 50.0))
                                    ZStack(alignment: .bottom) {
                                        Capsule()
                                            .fill(palette.storybookHillFront)
                                            .overlay(Capsule().strokeBorder(palette.cartoonOutline, lineWidth: 1.6))
                                            .frame(height: 10)
                                            .padding(.horizontal, 6)
                                            .offset(y: -3)

                                        HStack(spacing: 0) {
                                            ForEach(ChimmoMember.allCases) { member in
                                                let isSinging = focusedMemberDegree == member.degree
                                                let memberCol = palette.isNight ? member.nightGlowColor : member.bodyColor
                                                Button {
                                                    triggerMemberAudition(member)
                                                } label: {
                                                    VStack(spacing: 1) {
                                                        ChimmoFigureView(
                                                            member: member,
                                                            isNight: palette.isNight,
                                                            isMinor: currentDocument.scaleMode.isMinorFlavored,
                                                            isSinging: isSinging,
                                                            focusedDegree: focusedMemberDegree,
                                                            time: phaseTime,
                                                            listeningTilt: 0
                                                        )
                                                        .scaleEffect(figScale, anchor: .bottom)
                                                        .frame(width: itemW, height: 52)

                                                        Circle()
                                                            .fill(memberCol.opacity(isSinging ? 1.0 : 0.85))
                                                            .overlay(Circle().strokeBorder(palette.cartoonOutline, lineWidth: 1.0))
                                                            .frame(width: 6, height: 6)
                                                    }
                                                    .frame(width: itemW, height: 64, alignment: .bottom)
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("\(member.degree) \(member.chineseName) \(member.solfege)")
                                                .accessibilityHint("轻点试听音级")
                                                .accessibilityAction {
                                                    triggerMemberAudition(member)
                                                }
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(
                                            DragGesture(minimumDistance: 6)
                                                .onChanged { val in
                                                    guard abs(val.translation.width) >= abs(val.translation.height) else { return }
                                                    let idx = max(0, min(6, Int(floor((val.location.x / max(1.0, geo.size.width)) * 7.0))))
                                                    let member = ChimmoMember.from(degree: idx + 1)
                                                    if lastSweptDegree != member.degree {
                                                        lastSweptDegree = member.degree
                                                        triggerMemberAudition(member)
                                                    }
                                                }
                                                .onEnded { _ in
                                                    lastSweptDegree = nil
                                                }
                                        )
                                    }
                                }
                                .frame(height: 66)

                                HStack(spacing: 8) {
                                    Text("咩哞 · Chimmo")
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(palette.primaryInk)
                                    Spacer()
                                    Text("离线声学绘本音乐盒")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(palette.secondaryInk)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                ZStack {
                                    StorybookCartoonSceneBackground(
                                        palette: palette,
                                        accentTint: skyColor,
                                        hillHeightRatio: 0.34,
                                        showsSkyMotifs: true
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(palette.cartoonOutline.opacity(palette.isNight ? 0.24 : 0.18), lineWidth: 1.2)
                                }
                            )
                        }

                        if let onShare = onOpenSharePostcard {
                            Button(action: onShare) {
                                HStack(spacing: 10) {
                                    ChimmoCraftMark(
                                        .vinylSeal,
                                        color: palette.isNight ? Color(hex: 0x0E142C) : .white
                                    )
                                    .frame(width: 18, height: 18)

                                    Text("分享当前作品")
                                        .font(.subheadline.weight(.heavy))

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Image(systemName: "photo")
                                        Image(systemName: "waveform")
                                        Image(systemName: "pianokeys")
                                    }
                                    .font(.caption2.weight(.bold))
                                    .opacity(0.90)

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.heavy))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(palette.cartoonShadow)
                                            .offset(y: 3)
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(palette.homeAnchor)
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(palette.cartoonOutline, lineWidth: 2.0)
                                    }
                                )
                                .foregroundStyle(palette.isNight ? Color(hex: 0x0E142C) : .white)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.8))
                        }

                        // 隐私承诺与可折叠开源/版权说明（100% 保留合规文本但不视觉刷屏）
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.homeAnchor)
                                Text("100% 本机离线 · 零联网 · 零广告")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(palette.primaryInk)
                            }

                            Rectangle()
                                .fill(palette.divider)
                                .frame(height: 1)

                            DisclosureGroup("隐私与开源版权说明", isExpanded: $showLegalDetails) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("100% 本机离线运行：无需登录、不联网、无广告、不上传任何录音。")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryInk)
                                    Text("• 动态规划音符切分算法移植自开源项目 SwiftF0 (lars76/swift-f0, MIT License)。\n• 内置 20 首古典名曲（圣桑《天鹅》、李斯特《爱之梦》《安慰曲》《钟》、巴赫《前奏曲》《G弦上的咏叹调》《小步舞曲》《大提琴组曲》、柴可夫斯基《天鹅湖》、德彪西、肖邦、德沃夏克、萨蒂、贝多芬、舒伯特、帕赫贝尔、莫扎特等）均为作者逝世逾百年的全球公有领域乐谱独立编配。\n• 内置 8 首夏日治愈与现代技法曲目均为本项目 100% 原创，不含任何受版权保护的现代影视/流行作品旋律。")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryInk)
                                }
                                .padding(.top, 8)
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            StorybookQuietCardSurface(
                                palette: palette,
                                cornerRadius: 18
                            )
                        )
                    }
                    .padding(14)
                }
            }
            .navigationTitle("关于咩哞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onDisappear {
                duoResetTask?.cancel()
                duoResetTask = nil
                memberResetTask?.cancel()
                memberResetTask = nil
            }
        }
    }
}
