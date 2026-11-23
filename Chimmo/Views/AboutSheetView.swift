import SwiftUI

/// 明信片与标准 MIDI 导出请求载体
public struct VinylPostcardRequest: Identifiable, Sendable {
    public let id: UUID
    public let document: MelodyDocument
    public let chordPreset: ChordProgressionPreset
    public let chordOverrides: [Int: DiatonicChord]
    public let melodyVoice: MelodyVoice?
    public let shadowEnabled: Bool
    public let headline: String?
    public let visualMode: StageVisualMode

    public init(
        id: UUID = UUID(),
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        headline: String? = nil,
        visualMode: StageVisualMode = .orbitalDisc
    ) {
        self.id = id
        self.document = document
        self.chordPreset = chordPreset
        self.chordOverrides = chordOverrides
        self.melodyVoice = melodyVoice
        self.shadowEnabled = shadowEnabled
        self.headline = headline
        self.visualMode = visualMode
    }
}

/// 离线黑胶星轨明信片 & 标准 MIDI 分享抽屉（零 Emoji，纯粹的窑陶 × 黄铜版画展示体验）
public struct VinylPostcardShareSheet: View {
    public let palette: ChimmoPalette
    public let request: VinylPostcardRequest

    @Environment(\.dismiss) private var dismiss
    @State private var useNightCard: Bool
    @State private var selectedMode: StageVisualMode
    @State private var exportedPNGURL: URL?
    @State private var exportedMIDIURL: URL?

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
            visualMode: selectedMode
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 浅色 / 深色 + 三态画境切换（纯图标，零说明）
                    HStack(spacing: 10) {
                        Picker("图片样式", selection: $useNightCard) {
                            Text("浅色").tag(false)
                            Text("深色").tag(true)
                        }
                        .pickerStyle(.segmented)

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
                    }
                    .padding(.horizontal, 16)

                    // 等比缩放呈现 540x680 卡片预览
                    VinylPostcardCanvasView(snapshot: snapshot)
                        .scaleEffect(0.5)
                        .frame(width: 270, height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(useNightCard ? 0.36 : 0.14), radius: 16, y: 8)

                    VStack(spacing: 10) {
                        if let pngURL = exportedPNGURL {
                            ShareLink(item: pngURL) {
                                HStack(spacing: 8) {
                                    ChimmoCraftMark(
                                        .vinylSeal,
                                        color: palette.isNight ? Color(hex: 0x151B36) : .white
                                    )
                                    .frame(width: 17, height: 17)
                                    Text("分享图片 (PNG)")
                                        .font(.subheadline.weight(.bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x151B36) : .white)
                            }
                            .buttonStyle(.plain)
                        }

                        if let midiURL = exportedMIDIURL {
                            ShareLink(item: midiURL) {
                                HStack(spacing: 8) {
                                    Image(systemName: "pianokeys")
                                        .font(.subheadline.weight(.semibold))
                                    Text("导出 MIDI (.mid)")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(palette.cardSurface))
                                .overlay(Capsule().strokeBorder(palette.divider, lineWidth: 1.0))
                                .foregroundStyle(palette.primaryInk)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Text("图片和 MIDI 均在本机离线生成，不联网")
                        .font(.caption2)
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
            .onChange(of: useNightCard) { _, _ in
                refreshPostcardOnly()
            }
            .onChange(of: selectedMode) { _, _ in
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
            visualMode: selectedMode
        )
    }

    private func refreshFiles() {
        refreshPostcardOnly()
        exportedMIDIURL = try? MIDIExporter.writeTemporaryMIDIFile(
            document: request.document,
            includeHarmonyCradle: request.chordPreset != .off
        )
    }
}

/// 应用内「关于与隐私承诺」页（完全离线可查阅，同时提供高清 PNG 明信片与标准 .mid 导出入口）。
public struct AboutSheetView: View {
    public let palette: ChimmoPalette
    public let currentDocument: MelodyDocument
    public let cradleEnabled: Bool
    public let chordPreset: ChordProgressionPreset
    public let chordOverrides: [Int: DiatonicChord]
    public let melodyVoice: MelodyVoice?
    public let shadowEnabled: Bool
    public let visualMode: StageVisualMode

    @Environment(\.dismiss) private var dismiss
    @State private var exportedMIDIURL: URL?
    @State private var exportedPNGURL: URL?

    public init(
        palette: ChimmoPalette,
        currentDocument: MelodyDocument,
        cradleEnabled: Bool,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        visualMode: StageVisualMode = .orbitalDisc
    ) {
        self.palette = palette
        self.currentDocument = currentDocument
        self.cradleEnabled = cradleEnabled
        self.chordPreset = chordPreset
        self.chordOverrides = chordOverrides
        self.melodyVoice = melodyVoice
        self.shadowEnabled = shadowEnabled
        self.visualMode = visualMode
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 品牌与七小只卡片
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ChimmoCraftBadge(
                                .vinylSeal,
                                accent: palette.homeAnchor,
                                surface: palette.cardSurface,
                                size: 34
                            )
                            Text("咩哞 · Chimmo")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                        }
                        Text("不用懂五线谱，也能用转盘、曲线、哼唱和触觉把脑海里的旋律记下来。")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface))

                    // 离线导出图片与 MIDI
                    VStack(alignment: .leading, spacing: 10) {
                        Text("导出当前作品")
                            .font(.headline)
                            .foregroundStyle(palette.primaryInk)
                        Text("可导出图片分享给朋友，或导出标准 MIDI 文件导入 GarageBand / Logic Pro 继续编曲。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)

                        HStack(spacing: 10) {
                            if let pngURL = exportedPNGURL {
                                ShareLink(item: pngURL) {
                                    Label("分享图片", systemImage: "photo.on.rectangle")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(palette.homeAnchor))
                                        .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                                }
                            } else {
                                Button {
                                    exportedPNGURL = try? VinylPostcardExporter.writeTemporaryPostcardFile(
                                        document: currentDocument,
                                        chordPreset: cradleEnabled ? chordPreset : .off,
                                        chordOverrides: chordOverrides,
                                        melodyVoice: melodyVoice,
                                        shadowEnabled: shadowEnabled,
                                        isNight: palette.isNight,
                                        visualMode: visualMode
                                    )
                                } label: {
                                    Label("生成图片 (.png)", systemImage: "photo")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(palette.homeAnchor))
                                        .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                                }
                                .buttonStyle(.plain)
                            }

                            if let url = exportedMIDIURL {
                                ShareLink(item: url) {
                                    Label("分享 .mid", systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(palette.cardSurface))
                                        .foregroundStyle(palette.primaryInk)
                                }
                            } else {
                                Button {
                                    exportedMIDIURL = try? MIDIExporter.writeTemporaryMIDIFile(
                                        document: currentDocument,
                                        includeHarmonyCradle: cradleEnabled
                                    )
                                } label: {
                                    Label("生成 MIDI", systemImage: "pianokeys")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(palette.cardSurface))
                                        .foregroundStyle(palette.primaryInk)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface))

                    // 隐私承诺与开源致谢
                    VStack(alignment: .leading, spacing: 8) {
                        Text("隐私说明")
                            .font(.headline)
                            .foregroundStyle(palette.primaryInk)
                        Text("100% 本机离线运行：无需登录、不联网、无广告、不上传任何录音。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)

                        Divider().overlay(palette.divider).padding(.vertical, 4)

                        Text("开源许可与 100% 版权自洁说明")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryInk)
                        Text("• 动态规划音符切分算法移植自开源项目 SwiftF0 (lars76/swift-f0, MIT License)。\n• 内置 20 首古典名曲（圣桑《天鹅》、李斯特《爱之梦》《安慰曲》《钟》、巴赫《前奏曲》《G弦上的咏叹调》《小步舞曲》《大提琴组曲》、柴可夫斯基《天鹅湖》、德彪西、肖邦、德沃夏克、萨蒂、贝多芬、舒伯特、帕赫贝尔、莫扎特等）均为作者逝世逾百年的全球公有领域乐谱独立编配。\n• 内置 8 首夏日治愈与现代技法曲目均为本项目 100% 原创，不含任何受版权保护的现代影视/流行作品旋律。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
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
