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

/// 离线黑胶星轨明信片、可播音频 & 标准 MIDI 分享抽屉（零 Emoji，纯粹的窑陶 × 黄铜版画展示体验）
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
            ScrollView {
                VStack(spacing: 18) {
                    // 浅色 / 深色（纯日月图标，对齐声音面板） + 三态画境切换 + 可选简谱数字记号
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
                                        .frame(width: 34, height: 28)
                                        .background(Capsule().fill(active ? palette.homeAnchor : Color.clear))
                                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.secondaryInk)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(nightFlag ? "深色明信片" : "浅色明信片")
                                .accessibilityValue(active ? "已选中" : "")
                            }
                        }
                        .fixedSize()
                        .padding(3)
                        .background(Capsule().fill(palette.cardSurface))

                        Spacer(minLength: 4)

                        HStack(spacing: 2) {
                            ForEach(StageVisualMode.allCases) { mode in
                                let active = selectedMode == mode
                                Button {
                                    selectedMode = mode
                                } label: {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 12.5, weight: .bold))
                                        .frame(width: 30, height: 28)
                                        .background(Capsule().fill(active ? palette.homeAnchor : Color.clear))
                                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.secondaryInk)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(mode.rawValue)样式")
                            }
                        }
                        .fixedSize()
                        .padding(3)
                        .background(Capsule().fill(palette.cardSurface))

                        Button {
                            showJianpuStrip.toggle()
                            AcousticHapticsEngine.shared.playScrubTick()
                        } label: {
                            Image(systemName: "textformat.123")
                                .font(.system(size: 12.5, weight: .bold))
                                .frame(width: 34, height: 34)
                                .background(Capsule().fill(showJianpuStrip ? palette.homeAnchor : palette.cardSurface))
                                .foregroundStyle(showJianpuStrip ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("在明信片显示简谱音符")
                        .accessibilityValue(showJianpuStrip ? "已开启" : "已关闭")
                    }
                    .padding(.horizontal, 16)

                    // 等比缩放呈现 540x680 卡片预览
                    VinylPostcardCanvasView(snapshot: snapshot)
                        .scaleEffect(0.5)
                        .frame(width: 270, height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(useNightCard ? 0.36 : 0.14), radius: 16, y: 8)

                    HStack(spacing: 10) {
                        if let pngURL = exportedPNGURL {
                            ShareLink(item: pngURL) {
                                VStack(spacing: 5) {
                                    ChimmoCraftMark(
                                        .vinylSeal,
                                        color: palette.isNight ? Color(hex: 0x151B36) : .white
                                    )
                                    .frame(width: 18, height: 18)
                                    Text("PNG")
                                        .font(.caption.weight(.bold).monospaced())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x151B36) : .white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("分享图片 PNG")
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardSurface))
                        }

                        if let wavURL = exportedWAVURL {
                            ShareLink(item: wavURL) {
                                VStack(spacing: 5) {
                                    Image(systemName: "waveform")
                                        .font(.subheadline.weight(.bold))
                                    Text("WAV")
                                        .font(.caption.weight(.bold).monospaced())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.nightLampGold.opacity(0.18)))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.nightLampGold.opacity(0.45), lineWidth: 1.0))
                                .foregroundStyle(palette.nightLampGold)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("分享立体声音频 WAV")
                        } else if isRenderingWAV {
                            VStack(spacing: 5) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("WAV")
                                    .font(.caption.weight(.bold).monospaced())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardSurface))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.divider, lineWidth: 1.0))
                            .foregroundStyle(palette.secondaryInk)
                        } else {
                            VStack(spacing: 5) {
                                Image(systemName: "waveform")
                                    .font(.subheadline.weight(.semibold))
                                Text("WAV")
                                    .font(.caption.weight(.bold).monospaced())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardSurface))
                            .foregroundStyle(palette.secondaryInk.opacity(0.5))
                        }

                        if let midiURL = exportedMIDIURL {
                            ShareLink(item: midiURL) {
                                VStack(spacing: 5) {
                                    Image(systemName: "pianokeys")
                                        .font(.subheadline.weight(.semibold))
                                    Text("MIDI")
                                        .font(.caption.weight(.bold).monospaced())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardSurface))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.divider, lineWidth: 1.0))
                                .foregroundStyle(palette.primaryInk)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("导出 MIDI")
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardSurface))
                        }
                    }
                    .padding(.horizontal, 16)

                    Label("本机离线生成", systemImage: "lock.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(.vertical, 16)
            }
            .background(palette.paper.ignoresSafeArea())
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
    public let onOpenSharePostcard: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var auditioningDuo: ChimmoDuoCharacter? = nil
    @State private var duoResetTask: Task<Void, Never>? = nil
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

    public var body: some View {
        let skyColor = currentDocument.scaleMode.skyAuroraColor(isNight: palette.isNight)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 交互式「咩 × 哞」双子声学剧场
                    VStack(alignment: .leading, spacing: 12) {
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
                                                    isSinging: active
                                                )
                                            } else {
                                                ChimmoCowView(
                                                    isNight: palette.isNight,
                                                    accentColor: skyColor,
                                                    isAwake: true,
                                                    isPlaying: active
                                                )
                                            }
                                        }
                                        .frame(width: 68, height: 56)

                                        HStack(spacing: 4) {
                                            Text(character.chineseName)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(palette.primaryInk)
                                            Text("· \(character.roleShort)")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(palette.secondaryInk)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(active ? skyColor : palette.secondaryInk.opacity(0.55))
                                            .padding(8)
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(palette.cardSurface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(active ? skyColor : Color.clear, lineWidth: 1.5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(character.accessibilityLabel)
                                .accessibilityHint("轻点试听专属声部")
                            }
                        }

                        HStack(spacing: 8) {
                            Text("咩哞 · Chimmo")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Spacer()
                            Text("离线声学音乐盒")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.secondaryInk)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.shelfSurface))

                    if let onShare = onOpenSharePostcard {
                        Button(action: onShare) {
                            HStack(spacing: 10) {
                                ChimmoCraftMark(
                                    .vinylSeal,
                                    color: palette.isNight ? Color(hex: 0x151B36) : .white
                                )
                                .frame(width: 18, height: 18)

                                Text("分享当前作品 · 图片 / 音频 / MIDI")
                                    .font(.subheadline.weight(.bold))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x151B36) : .white)
                        }
                        .buttonStyle(.plain)
                    }

                    // 隐私承诺与可折叠开源/版权说明（100% 保留合规文本但不视觉刷屏）
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.homeAnchor)
                            Text("100% 本机离线 · 零联网 · 零广告")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                        }

                        Divider().overlay(palette.divider)

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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.primaryInk)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("关于咩哞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
