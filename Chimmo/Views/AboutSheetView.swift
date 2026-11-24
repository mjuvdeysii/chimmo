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

/// 离线扁平卡通音乐盒花环与山坡绘本明信片、可播音频 & 标准 MIDI 分享抽屉（零 Emoji，零模糊投影，童书绘本印刷体验）
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
                                            .font(.footnote.weight(.bold))
                                            .frame(width: 38, height: 34)
                                            .background(Capsule().fill(active ? palette.prominentFill : Color.clear))
                                            .foregroundStyle(active ? Color.white : palette.secondaryInk)
                                            .frame(
                                                minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                                minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                                            )
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                                    .accessibilityLabel(nightFlag ? "深色明信片" : "浅色明信片")
                                    .accessibilityValue(active ? "已选中" : "")
                                }
                            }
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
                            .fixedSize()

                            Spacer(minLength: 4)

                            HStack(spacing: 2) {
                                ForEach(StageVisualMode.displayOrder) { mode in
                                    let active = selectedMode == mode
                                    Button {
                                        selectedMode = mode
                                    } label: {
                                        Image(systemName: mode.iconName)
                                            .font(.footnote.weight(.bold))
                                            .frame(width: 36, height: 34)
                                            .background(Capsule().fill(active ? palette.prominentFill : Color.clear))
                                            .foregroundStyle(active ? Color.white : palette.secondaryInk)
                                            .frame(
                                                minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                                minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                                            )
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                                    .accessibilityLabel("\(mode.storybookLabel)样式")
                                }
                            }
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
                            .fixedSize()

                            Button {
                                showJianpuStrip.toggle()
                                AcousticHapticsEngine.shared.playScrubTick()
                            } label: {
                                Image(systemName: "textformat.123")
                                    .font(.footnote.weight(.bold))
                                    .frame(
                                        width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                        height: StorybookAffordanceMetrics.compactToolMinHitDimension
                                    )
                                    .background(
                                        ChimmoKilnPillButtonSurface(
                                            palette: palette,
                                            accent: palette.homeAnchor,
                                            isActive: showJianpuStrip,
                                            cornerRadius: 16
                                        )
                                    )
                                    .foregroundStyle(showJianpuStrip ? palette.homeAnchor : palette.secondaryInk)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("在明信片显示简谱音符")
                            .accessibilityValue(showJianpuStrip ? "已开启" : "已关闭")
                        }
                        .padding(.horizontal, 16)

                        // 等比缩放呈现 540x680 绘本明信片预览（柔和接触阴影 + 精致外沿）
                        VinylPostcardCanvasView(snapshot: snapshot)
                            .scaleEffect(0.5)
                            .frame(width: 270, height: 340)
                            .clipShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
                            .shadow(
                                color: palette.elevationShadow(dayOpacity: 0.16, nightOpacity: 0.32),
                                radius: 12,
                                y: 6
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous)
                                    .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 1.0)
                            )

                        HStack(spacing: 10) {
                            if let pngURL = exportedPNGURL {
                                ShareLink(item: pngURL) {
                                    VStack(spacing: 5) {
                                        ChimmoCraftMark(.vinylSeal, color: .white)
                                            .frame(width: 18, height: 18)
                                        Text("PNG")
                                            .font(.caption.weight(.heavy).monospaced())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(palette.prominentFill)
                                                .shadow(
                                                    color: palette.prominentFill.opacity(palette.isNight ? 0.32 : 0.24),
                                                    radius: 5,
                                                    y: 2.5
                                                )
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(Color.white.opacity(palette.isNight ? 0.16 : 0.34), lineWidth: 1.0)
                                        }
                                    )
                                    .foregroundStyle(Color.white)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
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
                                        ChimmoKilnPillButtonSurface(
                                            palette: palette,
                                            accent: palette.nightLampGold,
                                            isActive: true,
                                            cornerRadius: 16
                                        )
                                    )
                                    .foregroundStyle(palette.primaryInk)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
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
                                        ChimmoKilnPillButtonSurface(
                                            palette: palette,
                                            accent: palette.celadonAccent,
                                            isActive: true,
                                            cornerRadius: 16
                                        )
                                    )
                                    .foregroundStyle(palette.primaryInk)
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                                .accessibilityLabel("导出 MIDI")
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(StorybookQuietCardSurface(palette: palette, cornerRadius: 16))
                            }
                        }
                        .padding(.horizontal, 16)

                        HStack(spacing: 8) {
                            ChimmoCartoonKeyBuddyView(
                                member: snapshot.heroMember,
                                outlineColor: palette.primaryInk.opacity(palette.isNight ? 0.65 : 0.72),
                                isSinging: true,
                                isMinor: request.document.scaleMode.isMinorFlavored
                            )
                            .frame(width: 24, height: 20)

                            Label("本机离线印制 · \(snapshot.heroMember.chineseName)守护", systemImage: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
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

/// 应用内「关于与法律承诺」商业规范表单页（保持外部初始化签名向后兼容，内部采用原生 insetGrouped 结构与完整子页面导航）。
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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.68.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.house.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(palette.homeAnchor)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("咩哞 · Chimmo")
                                .font(.headline)
                            Text("100% 本机离线声学音乐绘本")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("版本 \(appVersion) (\(appBuild))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let onShare = onOpenSharePostcard {
                    Section("当前作品") {
                        Button {
                            onShare()
                        } label: {
                            Label("分享导出 (PNG / WAV / MIDI)", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("隐私与法律") {
                    NavigationLink("隐私政策") {
                        ChimmoLegalDocumentView(kind: .privacy)
                    }
                    NavigationLink("使用条款") {
                        ChimmoLegalDocumentView(kind: .terms)
                    }
                    NavigationLink("开源许可与曲目鸣谢") {
                        ChimmoLegalDocumentView(kind: .licenses)
                    }
                }

                Section("角色与官网") {
                    NavigationLink {
                        CharacterSoundTestView(
                            palette: palette,
                            scaleMode: currentDocument.scaleMode,
                            cradleEnabled: cradleEnabled,
                            onAuditionDuo: onAuditionDuo,
                            onAuditionMember: onAuditionMember
                        )
                    } label: {
                        Label("声音角色图鉴", systemImage: "music.mic")
                    }

                    if let url = URL(string: "https://mjuvdeysii.github.io/chimmo/") {
                        Link("官方网站", destination: url)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("关于咩哞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
