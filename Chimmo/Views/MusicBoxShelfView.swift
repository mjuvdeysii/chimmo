import QuartzCore
import SwiftUI

/// 咩哞 v0.45.0 Tab 2：「绘本曲谱书架」—— 扁平卡通精装绘本封面、轻翻奶油书页、丝带书签与主舞台直连交互
public struct MusicBoxShelfView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let navigationTitleText: String?
    public let showsDismissButton: Bool
    public let onLoadSavedToBoard: (SavedMelodyEntry) -> Void
    public let onPlaySavedInShowcase: ((SavedMelodyEntry) -> Void)?
    public let onPlayAlongSpecimen: (MelodyDocument) -> Void
    public let onEditSpecimenOnBoard: (MelodyDocument) -> Void
    public let onBorrowAtmosphere: (MelodyDocument) -> Void
    public let onShareSavedEntry: (SavedMelodyEntry) -> Void
    public let onForkSpecimenToCreate: ((MelodyDocument) -> Void)?
    public let onStartNewTap: () -> Void
    public let onWillPlayInline: () -> Void
    public let onRenameSavedEntry: (UUID, String) -> Void
    public let onDuplicateSavedEntry: (UUID) -> Void
    public let onDeleteSavedEntry: ((UUID) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSegment: Int = 1 // 有保存作品优先看 0，否则看名曲殿堂 1
    @State private var selectedCategory: String = "全部"
    @State private var selectedMoodFilter: ScaleMode? = nil
    @State private var searchText: String = ""
    @State private var playingEntryID: UUID? = nil
    @State private var inlinePlayStart: Double = 0
    @State private var inlinePlayTask: Task<Void, Never>? = nil
    @State private var renameTargetID: UUID? = nil
    @State private var renameDraftText: String = ""
    @State private var showRenameAlert: Bool = false
    @State private var isSearchExpanded: Bool = false

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        notebook: MelodyNotebookStore,
        currentDocumentID: UUID,
        initialSegment: Int? = nil,
        navigationTitleText: String? = nil,
        showsDismissButton: Bool = false,
        onLoadSavedToBoard: @escaping (SavedMelodyEntry) -> Void,
        onPlaySavedInShowcase: ((SavedMelodyEntry) -> Void)? = nil,
        onPlayAlongSpecimen: @escaping (MelodyDocument) -> Void,
        onEditSpecimenOnBoard: @escaping (MelodyDocument) -> Void,
        onBorrowAtmosphere: @escaping (MelodyDocument) -> Void = { _ in },
        onShareSavedEntry: @escaping (SavedMelodyEntry) -> Void = { _ in },
        onForkSpecimenToCreate: ((MelodyDocument) -> Void)? = nil,
        onStartNewTap: @escaping () -> Void,
        onWillPlayInline: @escaping () -> Void = {},
        onRenameSavedEntry: @escaping (UUID, String) -> Void = { _, _ in },
        onDuplicateSavedEntry: @escaping (UUID) -> Void = { _ in },
        onDeleteSavedEntry: ((UUID) -> Void)? = nil
    ) {
        self.palette = palette
        self.synth = synth
        self.notebook = notebook
        self.currentDocumentID = currentDocumentID
        self.navigationTitleText = navigationTitleText
        self.showsDismissButton = showsDismissButton
        self.onLoadSavedToBoard = onLoadSavedToBoard
        self.onPlaySavedInShowcase = onPlaySavedInShowcase
        self.onPlayAlongSpecimen = onPlayAlongSpecimen
        self.onEditSpecimenOnBoard = onEditSpecimenOnBoard
        self.onBorrowAtmosphere = onBorrowAtmosphere
        self.onShareSavedEntry = onShareSavedEntry
        self.onForkSpecimenToCreate = onForkSpecimenToCreate
        self.onStartNewTap = onStartNewTap
        self.onWillPlayInline = onWillPlayInline
        self.onRenameSavedEntry = onRenameSavedEntry
        self.onDuplicateSavedEntry = onDuplicateSavedEntry
        self.onDeleteSavedEntry = onDeleteSavedEntry
        let resolvedSeg = initialSegment ?? (notebook.entries.isEmpty ? 1 : 0)
        self._selectedSegment = State(initialValue: max(0, min(1, resolvedSeg)))
    }

    private var filteredSpecimens: [MelodyDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return SpecimenLibrary.all.filter { spec in
            let catOK = (selectedCategory == "全部") || (spec.specimenCategory == selectedCategory)
            let moodOK = (selectedMoodFilter == nil) || (spec.scaleMode == selectedMoodFilter)
            let searchOK = query.isEmpty || spec.title.localizedCaseInsensitiveContains(query)
            return catOK && moodOK && searchOK
        }
    }

    private var filteredSavedEntries: [SavedMelodyEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return notebook.entries.filter { entry in
            let moodOK = (selectedMoodFilter == nil) || (entry.document.scaleMode == selectedMoodFilter)
            let searchOK = query.isEmpty || entry.document.title.localizedCaseInsensitiveContains(query)
            return moodOK && searchOK
        }
    }

    private var hasActiveFilter: Bool {
        selectedMoodFilter != nil || (selectedSegment == 1 && selectedCategory != "全部") || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resetAllFilters() {
        searchText = ""
        selectedCategory = "全部"
        selectedMoodFilter = nil
        AcousticHapticsEngine.shared.playScrubTick()
    }

    private func toggleMoodFilter(_ mode: ScaleMode) {
        if selectedMoodFilter == mode {
            selectedMoodFilter = nil
        } else {
            selectedMoodFilter = mode
            let hasMatchInCurrentCat = SpecimenLibrary.all.contains {
                $0.scaleMode == mode && (selectedCategory == "全部" || $0.specimenCategory == selectedCategory)
            }
            if !hasMatchInCurrentCat {
                selectedCategory = "全部"
            }
            synth.ensureRunning()
            synth.applySpaceProfile(AcousticSpaceProfile.profile(for: mode))
            let degs = mode.signaturePreviewDegrees
            for (idx, deg) in degs.enumerated() {
                let hz = mode.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                synth.playNote(
                    frequency: hz,
                    velocity: 0.44,
                    decay: 1.0,
                    brightness: 0.94,
                    timbre: .liquidHarp,
                    delaySeconds: Double(idx) * 0.055,
                    pan: Double(idx - 1) * 0.12
                )
            }
        }
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: selectedMoodFilter?.skyAuroraColor(isNight: palette.isNight) ?? palette.nightLampGold
                )

                VStack(spacing: 10) {
                    boutiqueCompactTopBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    if isSearchExpanded || !searchText.isEmpty {
                        boutiqueInlineSearchBar
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                    }

                    if selectedSegment == 1 || !notebook.entries.isEmpty {
                        boutiqueCompactFilterRibbon
                            .padding(.horizontal, 16)
                    }

                    ScrollView {
                        VStack(spacing: 12) {
                            if selectedSegment == 0 {
                                mySavedDiscsSection
                            } else {
                                if filteredSpecimens.isEmpty {
                                    filteredEmptyPlaceholder
                                } else {
                                    masterpieceDiscsSection
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                    }
                }
            }
            .modifier(
                ShelfNavigationChromeModifier(
                    title: navigationTitleText,
                    showsDismissButton: showsDismissButton,
                    onClose: {
                        stopInlinePlay()
                        dismiss()
                    }
                )
            )
            .onChange(of: selectedSegment) { _, _ in
                stopInlinePlay()
            }
            .onChange(of: selectedCategory) { _, _ in
                if let pid = playingEntryID,
                   selectedSegment == 1,
                   !filteredSpecimens.contains(where: { $0.id == pid }) {
                    stopInlinePlay()
                }
            }
            .onChange(of: selectedMoodFilter) { _, _ in
                if let pid = playingEntryID {
                    let visible = (selectedSegment == 0)
                        ? filteredSavedEntries.contains(where: { $0.id == pid })
                        : filteredSpecimens.contains(where: { $0.id == pid })
                    if !visible {
                        stopInlinePlay()
                    }
                }
            }
            .onDisappear { stopInlinePlay() }
            .alert("作品名称", isPresented: $showRenameAlert) {
                TextField("", text: $renameDraftText)
                Button("确定") {
                    if let targetID = renameTargetID {
                        onRenameSavedEntry(targetID, renameDraftText)
                    }
                    renameTargetID = nil
                }
                Button("取消", role: .cancel) {
                    renameTargetID = nil
                }
            }
        }
    }

    // MARK: - 0. Compact Two-Row Shelf Header (Low-Noise Affordance Separation)

    private var boutiqueCompactTopBar: some View {
        let searchActive = isSearchExpanded || !searchText.isEmpty
        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                shelfTabButton(
                    title: "我的曲本",
                    countText: "\(notebook.entries.count)",
                    icon: "book.closed.fill",
                    isSelected: selectedSegment == 0
                ) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedSegment = 0
                    }
                    AcousticHapticsEngine.shared.playScrubTick()
                }

                shelfTabButton(
                    title: "绘本名曲",
                    countText: "\(SpecimenLibrary.all.count)",
                    icon: "books.vertical.fill",
                    isSelected: selectedSegment == 1
                ) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedSegment = 1
                    }
                    AcousticHapticsEngine.shared.playScrubTick()
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                    .fill(palette.shelfSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                            .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                    )
            )
            .frame(height: 44)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    if searchActive {
                        searchText = ""
                        isSearchExpanded = false
                    } else {
                        isSearchExpanded = true
                    }
                }
                AcousticHapticsEngine.shared.playScrubTick()
            } label: {
                ZStack {
                    Circle()
                        .fill(searchActive ? palette.prominentFill : palette.cardSurface)
                        .frame(width: 36, height: 36)
                        .shadow(
                            color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.24),
                            radius: 3,
                            y: 1.5
                        )
                        .overlay(
                            Circle().strokeBorder(
                                searchActive ? palette.prominentFill : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                lineWidth: 0.9
                            )
                        )
                    Image(systemName: searchActive ? "xmark" : "magnifyingglass")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(searchActive ? Color.white : palette.primaryInk)
                }
                .frame(width: 40, height: 40)
                .contentShape(Circle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel(searchActive ? "关闭并清除搜索" : "展开曲库搜索")
        }
    }

    private var boutiqueInlineSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryInk)

            TextField("搜索曲名", text: $searchText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryInk)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryInk.opacity(0.75))
                        .frame(
                            width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                            height: StorybookAffordanceMetrics.compactToolMinHitDimension
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.divider, lineWidth: 1.0)
                )
        )
        .accessibilityLabel("搜索曲库作品")
    }

    private func shelfTabButton(
        title: String,
        countText: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? palette.homeAnchor : palette.secondaryInk)

                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(isSelected ? palette.primaryInk : palette.secondaryInk)
                    .lineLimit(1)

                Text(countText)
                    .font(.system(.caption2, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(isSelected ? palette.homeAnchor : palette.secondaryInk)
            }
            .frame(maxWidth: .infinity)
            .frame(height: StorybookAffordanceMetrics.compactToolMinHitDimension)
            .background(
                Group {
                    if isSelected {
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.homeAnchor,
                            isActive: true,
                            cornerRadius: 12
                        )
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
        .accessibilityLabel("\(title) \(countText)")
        .accessibilityValue(isSelected ? "已选中" : "")
    }

    private var boutiqueCompactFilterRibbon: some View {
        ChimmoFlowRow(spacing: 7, lineSpacing: 7) {
            if selectedSegment == 1 {
                ForEach(LibraryCategoryBadgeMapper.badges()) { badge in
                    let active = selectedCategory == badge.rawCategory
                    Button {
                        selectedCategory = badge.rawCategory
                        if badge.rawCategory != "全部",
                           let mood = selectedMoodFilter,
                           !SpecimenLibrary.all.contains(where: { $0.specimenCategory == badge.rawCategory && $0.scaleMode == mood }) {
                            selectedMoodFilter = nil
                        }
                        AcousticHapticsEngine.shared.playScrubTick()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: badge.iconName)
                                .font(.caption2.weight(.bold))
                            Text(badge.shortLabel)
                                .font(.system(.caption2, design: .rounded).weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(
                            ChimmoKilnPillButtonSurface(
                                palette: palette,
                                accent: palette.homeAnchor,
                                isActive: active,
                                cornerRadius: 14
                            )
                        )
                        .foregroundStyle(active ? palette.primaryInk : palette.secondaryInk)
                        .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                    .accessibilityLabel("分类 \(badge.rawCategory)")
                    .accessibilityValue(active ? "已选中" : "")
                }
            }

            ForEach(ScaleMode.allCases) { mode in
                let isSel = selectedMoodFilter == mode
                let aurora = mode.skyAuroraColor(isNight: palette.isNight)
                Button {
                    toggleMoodFilter(mode)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isSel ? aurora : palette.cardSurface)
                            .frame(width: 32, height: 32)
                            .shadow(
                                color: isSel
                                    ? aurora.opacity(0.28)
                                    : palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.22),
                                radius: 3,
                                y: 1.5
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    isSel ? aurora : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                    lineWidth: isSel ? 1.4 : 0.9
                                )
                            )

                        Image(systemName: mode.iconName)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(isSel ? palette.contrastInkOnAccent : aurora)
                    }
                    .frame(
                        width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                        height: StorybookAffordanceMetrics.compactToolMinHitDimension
                    )
                    .contentShape(Circle())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel("筛选\(mode.label)风格")
                .accessibilityValue(isSel ? "已选中" : "")
            }

            if hasActiveFilter {
                Button {
                    resetAllFilters()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2.weight(.bold))
                        Text("重置")
                            .font(.system(.caption2, design: .rounded).weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.nightLampGold,
                            isActive: true,
                            cornerRadius: 14
                        )
                    )
                    .foregroundStyle(palette.primaryInk)
                    .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel("重置全部筛选")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. My Saved Vinyl Sleeves Section

    @ViewBuilder
    private var mySavedDiscsSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 12) {
                HStack(alignment: .bottom, spacing: 10) {
                    ChimmoFigureView(
                        member: .taono,
                        isNight: palette.isNight,
                        isMinor: false,
                        isSinging: false,
                        focusedDegree: 1,
                        time: 0,
                        listeningTilt: 0
                    )
                    .frame(width: 34, height: 42)

                    LivingChimmoDuoBadgeView(
                        isNight: palette.isNight,
                        accentColor: palette.homeAnchor,
                        melodyActive: false,
                        cowAwake: true
                    )
                    .frame(width: 92, height: 60)

                    ChimmoFigureView(
                        member: .plokko,
                        isNight: palette.isNight,
                        isMinor: false,
                        isSinging: false,
                        focusedDegree: nil,
                        time: 0,
                        listeningTilt: 0
                    )
                    .frame(width: 34, height: 42)

                    ChimmoFigureView(
                        member: .corllo,
                        isNight: palette.isNight,
                        isMinor: false,
                        isSinging: false,
                        focusedDegree: nil,
                        time: 0,
                        listeningTilt: 0
                    )
                    .frame(width: 34, height: 42)
                }

                Text("书架暂无曲本")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(palette.primaryInk)

                Button {
                    onStartNewTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("写下第一首曲子")
                    }
                }
                .buttonStyle(.chimmoVinyl(palette: palette, prominent: true))
                .accessibilityLabel("去写一段")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    StorybookCartoonSceneBackground(
                        palette: palette,
                        accentTint: palette.homeAnchor,
                        hillHeightRatio: 0.44,
                        showsSkyMotifs: true
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(palette.divider, lineWidth: 1.0)
                }
            )
        } else if filteredSavedEntries.isEmpty {
            filteredEmptyPlaceholder
        } else {
            ForEach(Array(filteredSavedEntries.enumerated()), id: \.element.id) { _, entry in
                savedDiscCard(entry: entry)
            }
        }
    }

    private var filteredEmptyPlaceholder: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 10) {
                LivingChimmoDuoBadgeView(
                    isNight: palette.isNight,
                    accentColor: palette.secondaryInk,
                    melodyActive: false,
                    cowAwake: false
                )
                .frame(width: 72, height: 48)

                ChimmoFigureView(
                    member: .bomo,
                    isNight: palette.isNight,
                    isMinor: true,
                    isSinging: false,
                    focusedDegree: nil,
                    time: 0,
                    listeningTilt: 0
                )
                .frame(width: 34, height: 42)
            }

            Text("暂无匹配曲目")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(palette.primaryInk)

            Button {
                resetAllFilters()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.heavy))
                    Text("重置筛选")
                        .font(.caption.weight(.heavy))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .background(
                    ChimmoKilnPillButtonSurface(palette: palette, accent: palette.homeAnchor, isActive: true, cornerRadius: 21)
                )
                .foregroundStyle(palette.homeAnchor)
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 2.0))
            .accessibilityLabel("重置全部筛选")
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                StorybookCartoonSceneBackground(
                    palette: palette,
                    accentTint: selectedMoodFilter?.skyAuroraColor(isNight: palette.isNight),
                    hillHeightRatio: 0.42,
                    showsSkyMotifs: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: 1.0)
            }
        )
    }

    private func savedDiscCard(entry: SavedMelodyEntry) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let isCurrent = entry.document.id == currentDocumentID
        let entryModeColor = entry.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let entryVoice = entry.document.preferredVoice ?? .singingCello

        return HStack(spacing: 12) {
            StorybookSongbookCoverThumb(
                document: entry.document,
                palette: palette,
                isPlaying: isPlayingThis,
                reduceMotion: reduceMotion,
                chordPreset: entry.chordPreset,
                chordOverrides: entry.chordOverrides
            ) {
                if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entryModeColor)
                        .frame(width: 7, height: 7)

                    Text(entry.document.title)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.brassHairline)
                            .accessibilityLabel("当前正位于舞台")
                    }

                    Text("\(entryVoice.label) · \(entry.document.notes.count)音")
                        .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                MiniMelodySparkline(
                    document: entry.document,
                    isNight: palette.isNight,
                    isPlaying: isPlayingThis
                )
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.shelfSurface.opacity(0.75))
                )

                HStack(spacing: 6) {
                    if let onPlaySavedInShowcase {
                        Button {
                            stopInlinePlay()
                            onPlaySavedInShowcase(entry)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.caption2.weight(.bold))
                                Text("聆听")
                                    .font(.system(.caption, design: .rounded).weight(.heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(
                                ChimmoKilnPillButtonSurface(
                                    palette: palette,
                                    accent: palette.celadonAccent,
                                    isActive: true,
                                    cornerRadius: 17
                                )
                            )
                            .foregroundStyle(palette.primaryInk)
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("在聆听区播放 \(entry.document.title)")
                    }

                    Button {
                        stopInlinePlay()
                        onLoadSavedToBoard(entry)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.line")
                                .font(.caption.weight(.bold))
                            Text(onPlaySavedInShowcase != nil ? "编辑" : "打开编辑")
                                .font(.system(.caption, design: .rounded).weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .background(
                            ChimmoKilnPillButtonSurface(
                                palette: palette,
                                accent: onPlaySavedInShowcase != nil ? palette.homeAnchor : palette.celadonAccent,
                                isActive: onPlaySavedInShowcase == nil,
                                cornerRadius: 17
                            )
                        )
                        .foregroundStyle(palette.primaryInk)
                        .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                    .accessibilityLabel("在创作区打开编辑 \(entry.document.title)")

                    Spacer()

                    Menu {
                        Button {
                            renameTargetID = entry.id
                            renameDraftText = entry.document.title
                            showRenameAlert = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button {
                            onDuplicateSavedEntry(entry.id)
                        } label: {
                            Label("复制副本", systemImage: "plus.square.on.square")
                        }
                        Button {
                            stopInlinePlay()
                            onShareSavedEntry(entry)
                        } label: {
                            Label("分享导出", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive) {
                            if isPlayingThis { stopInlinePlay() }
                            if let onDeleteSavedEntry {
                                onDeleteSavedEntry(entry.id)
                            } else {
                                notebook.delete(id: entry.id)
                            }
                        } label: {
                            Label("删除作品", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(palette.cardSurface)
                                    .overlay(
                                        Circle().strokeBorder(
                                            palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                            lineWidth: 0.9
                                        )
                                    )
                                    .shadow(
                                        color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.20),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            )
                            .frame(
                                minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                            )
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("管理作品 \(entry.document.title)")
                }
            }
        }
        .padding(12)
        .background(
            StorybookQuietCardSurface(
                palette: palette,
                accent: isPlayingThis ? entryModeColor : (isCurrent ? palette.brassHairline : nil),
                isHighlighted: isPlayingThis || isCurrent,
                cornerRadius: 20
            )
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: isPlayingThis)
        .contextMenu {
            if let onPlaySavedInShowcase {
                Button {
                    stopInlinePlay()
                    onPlaySavedInShowcase(entry)
                } label: {
                    Label("在聆听区播放", systemImage: "play.fill")
                }
            }
            Button {
                stopInlinePlay()
                onLoadSavedToBoard(entry)
            } label: {
                Label("打开编辑", systemImage: "pencil.line")
            }
            Button {
                stopInlinePlay()
                onShareSavedEntry(entry)
            } label: {
                Label("分享导出", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button {
                renameTargetID = entry.id
                renameDraftText = entry.document.title
                showRenameAlert = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            Button {
                onDuplicateSavedEntry(entry.id)
            } label: {
                Label("复制副本", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(role: .destructive) {
                if isPlayingThis { stopInlinePlay() }
                if let onDeleteSavedEntry {
                    onDeleteSavedEntry(entry.id)
                } else {
                    notebook.delete(id: entry.id)
                }
            } label: {
                Label("删除作品", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "重命名") {
            renameTargetID = entry.id
            renameDraftText = entry.document.title
            showRenameAlert = true
        }
        .accessibilityAction(named: "复制副本") {
            onDuplicateSavedEntry(entry.id)
        }
        .accessibilityAction(named: "分享导出") {
            stopInlinePlay()
            onShareSavedEntry(entry)
        }
        .accessibilityAction(named: "删除作品") {
            if isPlayingThis { stopInlinePlay() }
            if let onDeleteSavedEntry {
                onDeleteSavedEntry(entry.id)
            } else {
                notebook.delete(id: entry.id)
            }
        }
    }

    private func playInline(_ entry: SavedMelodyEntry) {
        playInlineDocument(
            entry.document,
            id: entry.id,
            chordPreset: entry.chordPreset,
            chordOverrides: entry.chordOverrides,
            texture: entry.accompanimentTexture
        )
    }

    private func playInlineDocument(
        _ doc: MelodyDocument,
        id: UUID,
        chordPreset: ChordProgressionPreset,
        chordOverrides: [Int: DiatonicChord],
        texture: AccompanimentTexture?
    ) {
        stopInlinePlay()
        guard !doc.notes.isEmpty else { return }
        onWillPlayInline()
        synth.ensureRunning()
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: doc.scaleMode))
        playingEntryID = id
        inlinePlayStart = CACurrentMediaTime()
        let spans = TheoryLensEngine.buildChordSpans(document: doc, preset: chordPreset, overrides: chordOverrides)
        let tex = texture ?? doc.preferredTexture ?? .swanRipple
        let voice = FeltPianoSynth.Timbre.from(voice: doc.preferredVoice ?? .singingCello)

        inlinePlayTask = Task { @MainActor in
            let groove = doc.grooveStrength
            let sorted = doc.notes.sorted { $0.displayOnset(grooveStrength: groove) < $1.displayOnset(grooveStrength: groove) }
            let start = Date()
            var nextIdx = 0
            var lastSpan = -1
            let total = max(0.5, doc.totalDuration)

            while !Task.isCancelled && playingEntryID == id {
                let elapsed = Date().timeIntervalSince(start)
                if let sp = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }), sp.id != lastSpan {
                    lastSpan = sp.id
                    synth.playDiatonicChord(
                        rootMIDI: doc.rootMIDI,
                        mode: doc.scaleMode,
                        chord: sp.chord,
                        texture: tex,
                        spanDuration: sp.endTime - sp.startTime,
                        intensity: 0.72
                    )
                }
                while nextIdx < sorted.count && sorted[nextIdx].displayOnset(grooveStrength: groove) <= elapsed {
                    let b = sorted[nextIdx]
                    let onset = b.displayOnset(grooveStrength: groove)
                    let dur = b.displayDuration(grooveStrength: groove)
                    let bLaneIdx = XylophoneLane.laneIndex(degree: b.degree, octaveOffset: b.octaveOffset)
                    let bLane = XylophoneLane.lane(at: bLaneIdx)
                    AcousticHapticsEngine.shared.playPlaybackNotePulse(
                        laneIndex: bLaneIdx,
                        isHome: b.degree == 1,
                        isTension: bLane.member.isTensionDegree,
                        isDownbeat: nextIdx == 0 || nextIdx % 4 == 0
                    )
                    let hz = doc.scaleMode.frequencyHz(rootMIDI: doc.rootMIDI, degree: b.degree, octaveOffset: b.octaveOffset)
                    let pan = AcousticSpatialPanMapper.pan(forBeatOnset: onset, totalDuration: total, visualMode: .orbitalDisc)
                    synth.playNote(frequency: hz, velocity: 0.60, decay: max(1.0, dur * 1.4), timbre: voice, pan: pan)
                    nextIdx += 1
                }
                if elapsed >= total { break }
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            if !Task.isCancelled && playingEntryID == id {
                playingEntryID = nil
            }
        }
    }

    private func stopInlinePlay() {
        inlinePlayTask?.cancel()
        inlinePlayTask = nil
        playingEntryID = nil
    }

    // MARK: - 2. 28 Playable Masterpiece Storybook Songbook Covers

    private var masterpieceDiscsSection: some View {
        ForEach(filteredSpecimens) { spec in
            let voice = spec.preferredVoice ?? .concertPiano
            let isPlayingThis = playingEntryID == spec.id
            let isCurrent = spec.id == currentDocumentID
            let modeColor = spec.scaleMode.skyAuroraColor(isNight: palette.isNight)

            HStack(alignment: .center, spacing: 12) {
                StorybookSongbookCoverThumb(
                    document: spec,
                    palette: palette,
                    isPlaying: isPlayingThis,
                    reduceMotion: reduceMotion
                ) {
                    if isPlayingThis {
                        stopInlinePlay()
                    } else {
                        playInlineDocument(
                            spec,
                            id: spec.id,
                            chordPreset: .autoMatch,
                            chordOverrides: [:],
                            texture: spec.preferredTexture
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(modeColor)
                            .frame(width: 6.5, height: 6.5)

                        Text(spec.title)
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if isCurrent {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.brassHairline)
                                .accessibilityLabel("当前正放在主舞台")
                        }

                        Text("\(voice.label) · \(spec.notes.count)音")
                            .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
                            .foregroundStyle(palette.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    MiniMelodySparkline(
                        document: spec,
                        isNight: palette.isNight,
                        isPlaying: isPlayingThis
                    )
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.shelfSurface.opacity(0.75))
                    )

                    HStack(spacing: 6) {
                        Button {
                            stopInlinePlay()
                            onEditSpecimenOnBoard(spec)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.caption2.weight(.bold))
                                Text("聆听")
                                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(
                                ChimmoKilnPillButtonSurface(
                                    palette: palette,
                                    accent: palette.celadonAccent,
                                    isActive: true,
                                    cornerRadius: 17
                                )
                            )
                            .foregroundStyle(palette.primaryInk)
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("在聆听区播放 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onPlayAlongSpecimen(spec)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption2.weight(.bold))
                                Text("跟灯")
                                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(
                                ChimmoKilnPillButtonSurface(
                                    palette: palette,
                                    accent: palette.nightLampGold,
                                    isActive: true,
                                    cornerRadius: 17
                                )
                            )
                            .foregroundStyle(palette.primaryInk)
                            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("跟灯弹 \(spec.title)")

                        if let onForkSpecimenToCreate {
                            Button {
                                stopInlinePlay()
                                onForkSpecimenToCreate(spec)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.caption2.weight(.bold))
                                    Text("改编")
                                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                                        .lineLimit(1)
                                        .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                                }
                                .padding(.horizontal, 11)
                                .frame(height: 34)
                                .background(
                                    ChimmoKilnPillButtonSurface(
                                        palette: palette,
                                        accent: palette.homeAnchor,
                                        isActive: false,
                                        cornerRadius: 17
                                    )
                                )
                                .foregroundStyle(palette.primaryInk)
                                .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                                .contentShape(Capsule())
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("改编 \(spec.title)")
                        }

                        Spacer(minLength: 0)

                        Button {
                            stopInlinePlay()
                            onBorrowAtmosphere(spec)
                        } label: {
                            ChimmoCraftMark(.atmosphereHorizon, color: modeColor)
                                .frame(width: 13, height: 13)
                                .frame(width: 34, height: 34)
                                .background(
                                    ChimmoKilnPillButtonSurface(
                                        palette: palette,
                                        accent: modeColor,
                                        isActive: false,
                                        cornerRadius: 17
                                    )
                                )
                                .frame(
                                    minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                                    minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                        .accessibilityLabel("套用 \(spec.title) 风格")
                    }
                }
            }
            .padding(12)
            .background(
                StorybookQuietCardSurface(
                    palette: palette,
                    accent: isPlayingThis ? modeColor : (isCurrent ? palette.brassHairline : nil),
                    isHighlighted: isPlayingThis || isCurrent,
                    cornerRadius: 20
                )
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: isPlayingThis)
            .contextMenu {
                Button {
                    stopInlinePlay()
                    onEditSpecimenOnBoard(spec)
                } label: {
                    Label("在聆听区播放", systemImage: "play.fill")
                }
                Button {
                    stopInlinePlay()
                    onPlayAlongSpecimen(spec)
                } label: {
                    Label("跟灯弹", systemImage: "sparkles")
                }
                if let onForkSpecimenToCreate {
                    Button {
                        stopInlinePlay()
                        onForkSpecimenToCreate(spec)
                    } label: {
                        Label("改编创作", systemImage: "wand.and.stars")
                    }
                }
                Button {
                    stopInlinePlay()
                    onBorrowAtmosphere(spec)
                } label: {
                    Label("套用风格", systemImage: "paintpalette")
                }
            }
            .modifier(
                SpecimenCardAccessibilityActions(
                    onListen: {
                        stopInlinePlay()
                        onEditSpecimenOnBoard(spec)
                    },
                    onPlayAlong: {
                        stopInlinePlay()
                        onPlayAlongSpecimen(spec)
                    },
                    onBorrowAtmosphere: {
                        stopInlinePlay()
                        onBorrowAtmosphere(spec)
                    },
                    onFork: onForkSpecimenToCreate.map { fork in
                        {
                            stopInlinePlay()
                            fork(spec)
                        }
                    }
                )
            )
        }
    }
}

/// 扁平卡通绘本曲本封面 × 探出奶油乐谱书页 × 丝带书签 × 一键试听章（零黑胶、零机械唱臂，内置曲目主角小偶）
private struct StorybookSongbookCoverThumb: View {
    let document: MelodyDocument
    let palette: ChimmoPalette
    let isPlaying: Bool
    let reduceMotion: Bool
    var chordPreset: ChordProgressionPreset = .autoMatch
    var chordOverrides: [Int: DiatonicChord] = [:]
    let onTogglePlay: () -> Void

    private var bookState: StorybookWreathAndSongbookKinematics.BookCoverState {
        StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: isPlaying, reduceMotion: reduceMotion)
    }

    var body: some View {
        let modeColor = document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let spans = TheoryLensEngine.buildChordSpans(
            document: document,
            preset: chordPreset,
            overrides: chordOverrides
        )
        let firstLaneIdx = document.notes.first.map {
            XylophoneLane.laneIndex(degree: $0.degree, octaveOffset: $0.octaveOffset)
        } ?? 0
        let hero = StorybookPostcardAndShelfKinematics.heroMember(for: document)
        let placement = StorybookPostcardAndShelfKinematics.sleevePlacement(
            isPlaying: isPlaying,
            hero: hero,
            isMinor: document.scaleMode.isMinorFlavored,
            reduceMotion: reduceMotion
        )
        let ink = palette.primaryInk
        let pageHairline = ink.opacity(palette.isNight ? 0.22 : 0.14)

        Button {
            onTogglePlay()
        } label: {
            ZStack(alignment: .topLeading) {
                // 1. 探出封底的奶油乐谱书页（试听翻开露出更多乐谱横线）
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(palette.storybookButter)
                    .overlay(
                        VStack(alignment: .trailing, spacing: 5) {
                            ForEach(0..<3, id: \.self) { lineIdx in
                                Capsule()
                                    .fill(ink.opacity(0.24))
                                    .frame(width: lineIdx == 1 ? 14 : 18, height: 1.6)
                            }
                        }
                        .padding(.trailing, 5)
                        .padding(.vertical, 12),
                        alignment: .trailing
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(pageHairline, lineWidth: 1.1)
                    )
                    .frame(width: 58, height: 64)
                    .offset(x: bookState.pagePeekOffsetX, y: 2)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78),
                        value: isPlaying
                    )

                // 2. 右上方顺滑垂落的绘本丝带书签
                UnevenRoundedRectangle(
                    topLeadingRadius: 2,
                    bottomLeadingRadius: 5,
                    bottomTrailingRadius: 5,
                    topTrailingRadius: 2
                )
                .fill(isPlaying ? palette.nightLampGold : modeColor)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 2,
                        bottomLeadingRadius: 5,
                        bottomTrailingRadius: 5,
                        topTrailingRadius: 2
                    )
                    .strokeBorder(ink.opacity(palette.isNight ? 0.24 : 0.16), lineWidth: 1.0)
                )
                .frame(width: 11, height: 18 + bookState.bookmarkDropY)
                .offset(x: 47, y: -2 + bookState.bookmarkDropY * 0.45)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.76),
                    value: isPlaying
                )

                // 3. 软胶绘本精装封面（柔和投影 + 缝线书脊 + 4 幕色带 + 草坡 + 主角小偶）
                ZStack(alignment: .leading) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(palette.cardSurface)

                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(modeColor.opacity(palette.isNight ? 0.24 : 0.14))

                        Canvas { ctx, size in
                            let profile = StorybookIllustrationLayout.rollingHillProfile(
                                sampleCount: 10,
                                amplitude: 0.20,
                                phaseShift: 0.6
                            )
                            guard let first = profile.first else { return }
                            let baseTop = size.height * 0.66
                            var hill = Path()
                            hill.move(to: CGPoint(x: 0, y: size.height))
                            hill.addLine(to: CGPoint(x: CGFloat(first.xFraction) * size.width, y: baseTop + CGFloat(first.yFraction - 0.5) * 14))
                            for i in 1..<profile.count {
                                let p0 = CGPoint(x: CGFloat(profile[i - 1].xFraction) * size.width, y: baseTop + CGFloat(profile[i - 1].yFraction - 0.5) * 14)
                                let p1 = CGPoint(x: CGFloat(profile[i].xFraction) * size.width, y: baseTop + CGFloat(profile[i].yFraction - 0.5) * 14)
                                hill.addQuadCurve(to: CGPoint(x: (p0.x + p1.x) * 0.5, y: (p0.y + p1.y) * 0.5), control: p0)
                            }
                            hill.addLine(to: CGPoint(x: size.width, y: size.height))
                            hill.closeSubpath()
                            ctx.fill(hill, with: .color(palette.storybookHillFront))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .shadow(
                        color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.30),
                        radius: 3.5,
                        x: 1,
                        y: placement.shadowOffsetY * 0.75
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                isPlaying ? modeColor : palette.divider,
                                lineWidth: isPlaying ? 1.8 : 1.0
                            )
                    )

                    // 左侧绘本缝线书脊
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(modeColor)
                        .frame(width: 4.5, height: 54)
                        .padding(.leading, 4)

                    VStack(spacing: 5) {
                        HStack(spacing: 2) {
                            ForEach(spans.prefix(4)) { sp in
                                Capsule()
                                    .fill(sp.chord.color(isNight: palette.isNight))
                                    .frame(height: 2.8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 7)

                        Spacer(minLength: 0)

                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(hero.bodyColor.opacity(palette.isNight ? 0.34 : 0.24))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle().strokeBorder(ink.opacity(palette.isNight ? 0.26 : 0.18), lineWidth: 1.0)
                                    )

                                ChimmoCartoonKeyBuddyView(
                                    member: hero,
                                    outlineColor: ink.opacity(0.78),
                                    isSinging: isPlaying,
                                    isMinor: document.scaleMode.isMinorFlavored
                                )
                                .frame(width: 24, height: 20)
                                .offset(y: placement.buddyOffsetY)
                                .rotationEffect(.degrees(placement.buddyTiltDegrees))
                            }

                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: firstLaneIdx))
                                .frame(width: 8.5, height: 8.5)
                                .foregroundStyle(modeColor)
                                .padding(2.5)
                                .background(
                                    Circle()
                                        .fill(palette.cardSurface)
                                        .overlay(Circle().strokeBorder(ink.opacity(palette.isNight ? 0.28 : 0.20), lineWidth: 0.9))
                                )
                                .offset(x: 5, y: 3)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 64, height: 68)
                .rotationEffect(.degrees(bookState.coverTiltDegrees), anchor: .bottomLeading)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78),
                    value: isPlaying
                )

                // 4. 右下角清晰试听/暂停印章按钮
                Circle()
                    .fill(isPlaying ? palette.nightLampGold : palette.cardSurface)
                    .overlay(Circle().strokeBorder(ink.opacity(palette.isNight ? 0.34 : 0.24), lineWidth: 1.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isPlaying ? palette.contrastInkOnHighlight : palette.homeAnchor)
                    )
                    .offset(x: 52, y: 48)
            }
            .frame(width: 78, height: 74, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
        .accessibilityLabel(isPlaying ? "停止试听 \(document.title)" : "试听 \(document.title)")
    }
}

/// 微型旋律高低走势彩线（在绘本曲谱卡片上直接看懂每首旋律的轮廓起伏，无需文字解释）。
private struct MiniMelodySparkline: View {
    let document: MelodyDocument
    let isNight: Bool
    let isPlaying: Bool
    private let cachedSamples: [MelodySparklineMapper.SparklineSample]

    init(document: MelodyDocument, isNight: Bool, isPlaying: Bool) {
        self.document = document
        self.isNight = isNight
        self.isPlaying = isPlaying
        self.cachedSamples = MelodySparklineMapper.samples(for: document, maxPoints: 22)
    }

    var body: some View {
        Canvas { ctx, size in
            guard !cachedSamples.isEmpty else { return }
            let padX: CGFloat = 6
            let padY: CGFloat = 4
            let w = max(1, size.width - padX * 2)
            let h = max(1, size.height - padY * 2)

            let pts: [(pt: CGPoint, col: Color)] = cachedSamples.map { sample in
                let px = padX + CGFloat(sample.xNorm) * w
                let py = padY + (1.0 - CGFloat(sample.yNorm)) * h
                let col = XylophoneLane.lane(at: sample.laneIndex).barColor(isNight: isNight)
                return (CGPoint(x: px, y: py), col)
            }

            if pts.count > 1 {
                for i in 1..<pts.count {
                    let a = pts[i - 1]
                    let b = pts[i]
                    var seg = Path()
                    seg.move(to: a.pt)
                    seg.addLine(to: b.pt)
                    ctx.stroke(
                        seg,
                        with: .color(b.col.opacity(isPlaying ? 0.95 : 0.72)),
                        style: StrokeStyle(lineWidth: isPlaying ? 2.1 : 1.6, lineCap: .round)
                    )
                }
            }

            for item in pts {
                let r: CGFloat = isPlaying ? 2.0 : 1.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: item.pt.x - r, y: item.pt.y - r, width: r * 2, height: r * 2)),
                    with: .color(item.col.opacity(isPlaying ? 0.96 : 0.78))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ShelfNavigationChromeModifier: ViewModifier {
    let title: String?
    let showsDismissButton: Bool
    let onClose: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if title != nil || showsDismissButton {
            content
                .navigationTitle(title ?? "曲本")
                .navigationBarTitleDisplayMode(showsDismissButton ? .inline : .large)
                .toolbar {
                    if showsDismissButton {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭", action: onClose)
                        }
                    }
                }
        } else {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct SpecimenCardAccessibilityActions: ViewModifier {
    let onListen: () -> Void
    let onPlayAlong: () -> Void
    let onBorrowAtmosphere: () -> Void
    let onFork: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = content
            .accessibilityAction(named: "在聆听区播放", onListen)
            .accessibilityAction(named: "跟灯弹", onPlayAlong)
            .accessibilityAction(named: "套用风格", onBorrowAtmosphere)
        if let onFork {
            base.accessibilityAction(named: "改编创作", onFork)
        } else {
            base
        }
    }
}
