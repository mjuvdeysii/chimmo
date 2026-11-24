import QuartzCore
import SwiftUI

/// 咩哞 v0.35.0 Tab 2：「黑胶唱片工坊」—— 窑陶黑胶陈列木柜、实景斜角封套滑出唱盘与黄铜落针交互
public struct MusicBoxShelfView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onLoadSavedToBoard: (SavedMelodyEntry) -> Void
    public let onPlayAlongSpecimen: (MelodyDocument) -> Void
    public let onEditSpecimenOnBoard: (MelodyDocument) -> Void
    public let onBorrowAtmosphere: (MelodyDocument) -> Void
    public let onShareSavedEntry: (SavedMelodyEntry) -> Void
    public let onStartNewTap: () -> Void
    public let onWillPlayInline: () -> Void
    public let onRenameSavedEntry: (UUID, String) -> Void
    public let onDuplicateSavedEntry: (UUID) -> Void
    public let onDeleteSavedEntry: ((UUID) -> Void)?

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

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        notebook: MelodyNotebookStore,
        currentDocumentID: UUID,
        onLoadSavedToBoard: @escaping (SavedMelodyEntry) -> Void,
        onPlayAlongSpecimen: @escaping (MelodyDocument) -> Void,
        onEditSpecimenOnBoard: @escaping (MelodyDocument) -> Void,
        onBorrowAtmosphere: @escaping (MelodyDocument) -> Void = { _ in },
        onShareSavedEntry: @escaping (SavedMelodyEntry) -> Void = { _ in },
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
        self.onLoadSavedToBoard = onLoadSavedToBoard
        self.onPlayAlongSpecimen = onPlayAlongSpecimen
        self.onEditSpecimenOnBoard = onEditSpecimenOnBoard
        self.onBorrowAtmosphere = onBorrowAtmosphere
        self.onShareSavedEntry = onShareSavedEntry
        self.onStartNewTap = onStartNewTap
        self.onWillPlayInline = onWillPlayInline
        self.onRenameSavedEntry = onRenameSavedEntry
        self.onDuplicateSavedEntry = onDuplicateSavedEntry
        self.onDeleteSavedEntry = onDeleteSavedEntry
        self._selectedSegment = State(initialValue: notebook.entries.isEmpty ? 1 : 0)
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
                    accentTint: selectedMoodFilter?.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 8) {
                    boutiqueConsoleHeader
                        .padding(.horizontal, 12)
                        .padding(.top, 4)

                    boutiqueSegmentRail
                        .padding(.horizontal, 12)

                    if selectedSegment == 1 || !notebook.entries.isEmpty {
                        boutiqueFilterCabinet
                            .padding(.horizontal, 12)
                    }

                    ScrollView {
                        VStack(spacing: 10) {
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
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 18)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - 0. Boutique Record Cabinet Chrome

    private var boutiqueConsoleHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ChimmoCraftBadge(
                    .vinylSeal,
                    accent: palette.brassHairline,
                    surface: palette.cardSurface,
                    size: 32
                )

                Text("唱片工坊")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)

                LivingChimmoDuoBadgeView(
                    isNight: palette.isNight,
                    accentColor: selectedMoodFilter?.skyAuroraColor(isNight: palette.isNight) ?? palette.homeAnchor,
                    melodyActive: playingEntryID != nil,
                    cowAwake: true
                )
                .frame(width: 38, height: 24)
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5, weight: .bold))
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
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: 158)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.cartoonShadow)
                        .offset(y: 2)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.cardSurface)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.cartoonOutline.opacity(palette.isNight ? 0.68 : 0.85), lineWidth: 1.8)
                }
            )
            .accessibilityLabel("搜索曲库作品")
        }
    }

    private var boutiqueSegmentRail: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 16)

            HStack(spacing: 6) {
                shelfTabButton(
                    title: "我的黑胶",
                    countText: "\(notebook.entries.count)",
                    icon: "opticaldisc.fill",
                    isSelected: selectedSegment == 0
                ) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedSegment = 0
                    }
                    AcousticHapticsEngine.shared.playScrubTick()
                }

                shelfTabButton(
                    title: "名曲殿堂",
                    countText: "\(SpecimenLibrary.all.count)",
                    icon: "music.quarternote.3",
                    isSelected: selectedSegment == 1
                ) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedSegment = 1
                    }
                    AcousticHapticsEngine.shared.playScrubTick()
                }
            }
            .padding(5)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 16, showCornerPins: false)
        }
        .frame(height: 48)
    }

    private func shelfTabButton(
        title: String,
        countText: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(isSelected ? palette.homeAnchor : palette.secondaryInk)

                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(isSelected ? palette.primaryInk : palette.secondaryInk)

                Text(countText)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            isSelected ? palette.homeAnchor.opacity(0.18) : palette.divider
                        )
                    )
                    .foregroundStyle(isSelected ? palette.homeAnchor : palette.secondaryInk)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(countText)")
        .accessibilityValue(isSelected ? "已选中" : "")
    }

    private var boutiqueFilterCabinet: some View {
        ZStack {
            ChimmoWoodResonatorTray(palette: palette, cornerRadius: 18)

            VStack(spacing: 7) {
                if selectedSegment == 1 {
                    HStack(spacing: 6) {
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
                                VStack(spacing: 3) {
                                    Image(systemName: badge.iconName)
                                        .font(.system(size: 11.5, weight: .bold))
                                    Text(badge.shortLabel)
                                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    ChimmoKilnPillButtonSurface(
                                        palette: palette,
                                        accent: palette.homeAnchor,
                                        isActive: active,
                                        cornerRadius: 11
                                    )
                                )
                                .foregroundStyle(active ? palette.primaryInk : palette.secondaryInk)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("分类 \(badge.rawCategory)")
                            .accessibilityValue(active ? "已选中" : "")
                        }
                    }

                    StorybookScallopDivider(
                        color: palette.cartoonOutline.opacity(palette.isNight ? 0.34 : 0.24),
                        stepWidth: 16
                    )
                    .frame(height: 5)
                }

                HStack(spacing: 9) {
                    ForEach(ScaleMode.allCases) { mode in
                        let isSel = selectedMoodFilter == mode
                        let aurora = mode.skyAuroraColor(isNight: palette.isNight)
                        Button {
                            toggleMoodFilter(mode)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(palette.cartoonShadow)
                                    .frame(width: 34, height: 34)
                                    .offset(y: isSel ? 1.5 : 2.5)

                                Circle()
                                    .fill(isSel ? aurora : palette.cardSurface)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().strokeBorder(
                                            palette.cartoonOutline.opacity(palette.isNight ? 0.78 : 0.88),
                                            lineWidth: isSel ? 2.1 : 1.6
                                        )
                                    )

                                Image(systemName: mode.iconName)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(isSel ? (palette.isNight ? Color(hex: 0x0E142C) : .white) : aurora)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("筛选\(mode.label)风格")
                        .accessibilityValue(isSel ? "已选中" : "")
                    }

                    if hasActiveFilter {
                        Button {
                            resetAllFilters()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(palette.cartoonShadow)
                                    .frame(width: 32, height: 32)
                                    .offset(y: 2)
                                Circle()
                                    .fill(palette.storybookButter)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle().strokeBorder(palette.cartoonOutline, lineWidth: 1.7)
                                    )
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(palette.primaryInk)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("重置全部筛选")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(9)

            ChimmoBrassFrameAccent(palette: palette, cornerRadius: 18, showCornerPins: true)
        }
    }

    // MARK: - 1. My Saved Vinyl Sleeves Section

    @ViewBuilder
    private var mySavedDiscsSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 12) {
                StorybookScallopDivider(
                    color: palette.cartoonOutline.opacity(palette.isNight ? 0.48 : 0.35),
                    stepWidth: 14
                )
                .frame(height: 6)

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

                Text("唱片架暂无作品")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(palette.cardSurface)
                            .overlay(Capsule().strokeBorder(palette.cartoonOutline, lineWidth: 1.6))
                    )

                Button {
                    onStartNewTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.heavy))
                        Text("刻录首张黑胶")
                            .font(.subheadline.weight(.heavy))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(palette.cartoonShadow)
                                .offset(y: 3.5)
                            Capsule()
                                .fill(palette.homeAnchor)
                            Capsule()
                                .strokeBorder(palette.cartoonOutline, lineWidth: 2.0)
                        }
                    )
                    .foregroundStyle(palette.isNight ? Color(hex: 0x0E142C) : .white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("去写一段")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(palette.cartoonShadow)
                        .offset(y: 3.5)
                    StorybookCartoonSceneBackground(
                        palette: palette,
                        accentTint: palette.homeAnchor,
                        hillHeightRatio: 0.44,
                        showsSkyMotifs: true
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    ChimmoBrassFrameAccent(palette: palette, cornerRadius: 22, showCornerPins: true)
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

            Text("暂无匹配唱片")
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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    ChimmoKilnPillButtonSurface(palette: palette, accent: palette.homeAnchor, isActive: true, cornerRadius: 16)
                )
                .foregroundStyle(palette.homeAnchor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重置全部筛选")
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.cartoonShadow)
                    .offset(y: 3)
                StorybookCartoonSceneBackground(
                    palette: palette,
                    accentTint: selectedMoodFilter?.skyAuroraColor(isNight: palette.isNight),
                    hillHeightRatio: 0.42,
                    showsSkyMotifs: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                ChimmoBrassFrameAccent(palette: palette, cornerRadius: 20, showCornerPins: true)
            }
        )
    }

    private func savedDiscCard(entry: SavedMelodyEntry) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let isCurrent = entry.document.id == currentDocumentID
        let entryModeColor = entry.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let entryVoice = entry.document.preferredVoice ?? .singingCello

        return HStack(spacing: 12) {
            VinylBoutiqueSleeveThumb(
                document: entry.document,
                palette: palette,
                isPlaying: isPlayingThis,
                reduceMotion: reduceMotion,
                spinStartTime: inlinePlayStart,
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

                    Button {
                        renameTargetID = entry.id
                        renameDraftText = entry.document.title
                        showRenameAlert = true
                    } label: {
                        Text(entry.document.title)
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("轻点重命名作品")

                    Spacer(minLength: 4)

                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.brassHairline)
                            .accessibilityLabel("当前正放在主舞台")
                    }

                    HStack(spacing: 3) {
                        Image(systemName: entryVoice.iconName)
                            .font(.system(size: 9.5, weight: .bold))
                        Text("\(entry.document.notes.count)")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(palette.shelfSurface))
                    .foregroundStyle(palette.secondaryInk)
                }

                MiniMelodySparkline(
                    document: entry.document,
                    isNight: palette.isNight,
                    isPlaying: isPlayingThis
                )
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.shelfSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.cartoonOutline.opacity(0.32), lineWidth: 1.2)
                        )
                )

                HStack(spacing: 8) {
                    Button {
                        stopInlinePlay()
                        onLoadSavedToBoard(entry)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "record.circle")
                                .font(.caption.weight(.bold))
                            Text("上台")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(
                            Capsule()
                                .fill(palette.storybookMint)
                                .overlay(Capsule().strokeBorder(palette.cartoonOutline.opacity(0.80), lineWidth: 1.5))
                        )
                        .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("在主舞台打开 \(entry.document.title)")

                    Spacer()

                    Button {
                        stopInlinePlay()
                        onShareSavedEntry(entry)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.homeAnchor)
                            .frame(width: 30, height: 28)
                            .background(
                                Circle()
                                    .fill(palette.cardSurface)
                                    .overlay(Circle().strokeBorder(palette.cartoonOutline.opacity(0.65), lineWidth: 1.4))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("分享 \(entry.document.title)")

                    Button(role: .destructive) {
                        if isPlayingThis { stopInlinePlay() }
                        if let onDeleteSavedEntry {
                            onDeleteSavedEntry(entry.id)
                        } else {
                            notebook.delete(id: entry.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.secondaryInk)
                            .frame(width: 30, height: 28)
                            .background(
                                Circle()
                                    .fill(palette.cardSurface)
                                    .overlay(Circle().strokeBorder(palette.cartoonOutline.opacity(0.55), lineWidth: 1.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除 \(entry.document.title)")
                }
            }
        }
        .padding(12)
        .background(
            ChimmoKilnPillButtonSurface(
                palette: palette,
                accent: isPlayingThis ? entryModeColor : (isCurrent ? palette.brassHairline : nil),
                isActive: isPlayingThis || isCurrent,
                cornerRadius: 20
            )
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: isPlayingThis)
        .contextMenu {
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
            Button(role: .destructive) {
                if isPlayingThis { stopInlinePlay() }
                if let onDeleteSavedEntry {
                    onDeleteSavedEntry(entry.id)
                } else {
                    notebook.delete(id: entry.id)
                }
            } label: {
                Label("删除", systemImage: "trash")
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

    // MARK: - 2. 28 Playable Masterpiece Vinyl Boutique Sleeves

    private var masterpieceDiscsSection: some View {
        ForEach(filteredSpecimens) { spec in
            let voice = spec.preferredVoice ?? .concertPiano
            let isPlayingThis = playingEntryID == spec.id
            let isCurrent = spec.id == currentDocumentID
            let modeColor = spec.scaleMode.skyAuroraColor(isNight: palette.isNight)

            HStack(alignment: .center, spacing: 12) {
                VinylBoutiqueSleeveThumb(
                    document: spec,
                    palette: palette,
                    isPlaying: isPlayingThis,
                    reduceMotion: reduceMotion,
                    spinStartTime: inlinePlayStart
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

                        Image(systemName: voice.iconName)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.secondaryInk)
                    }

                    MiniMelodySparkline(
                        document: spec,
                        isNight: palette.isNight,
                        isPlaying: isPlayingThis
                    )
                    .frame(height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.shelfSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(palette.cartoonOutline.opacity(0.32), lineWidth: 1.2)
                            )
                    )

                    HStack(spacing: 8) {
                        Button {
                            stopInlinePlay()
                            onPlayAlongSpecimen(spec)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.bold))
                                Text("跟灯")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                Capsule()
                                    .fill(palette.storybookButter)
                                    .overlay(Capsule().strokeBorder(palette.cartoonOutline.opacity(0.80), lineWidth: 1.5))
                            )
                            .foregroundStyle(palette.primaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("跟灯弹 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onEditSpecimenOnBoard(spec)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "record.circle")
                                    .font(.caption.weight(.bold))
                                Text("上台")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                Capsule()
                                    .fill(palette.cardSurface)
                                    .overlay(Capsule().strokeBorder(palette.cartoonOutline.opacity(0.70), lineWidth: 1.4))
                            )
                            .foregroundStyle(palette.primaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("在主舞台打开 \(spec.title)")

                        Spacer(minLength: 0)

                        Button {
                            stopInlinePlay()
                            onBorrowAtmosphere(spec)
                        } label: {
                            ChimmoCraftMark(.atmosphereHorizon, color: modeColor)
                                .frame(width: 13, height: 13)
                                .frame(width: 34, height: 28)
                                .background(
                                    Capsule()
                                        .fill(palette.cardSurface)
                                        .overlay(Capsule().strokeBorder(modeColor, lineWidth: 1.5))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("套用 \(spec.title) 风格")
                    }
                }
            }
            .padding(12)
            .background(
                ChimmoKilnPillButtonSurface(
                    palette: palette,
                    accent: isPlayingThis ? modeColor : (isCurrent ? palette.brassHairline : nil),
                    isActive: isPlayingThis || isCurrent,
                    cornerRadius: 20
                )
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: isPlayingThis)
        }
    }
}

/// 扁平卡通绘本唱片封套 × 半露转盘 × 轻快漫画唱臂缩略图组件（零拟物渐变与模糊投影，内置曲目主角小偶）
private struct VinylBoutiqueSleeveThumb: View {
    let document: MelodyDocument
    let palette: ChimmoPalette
    let isPlaying: Bool
    let reduceMotion: Bool
    let spinStartTime: Double
    var chordPreset: ChordProgressionPreset = .autoMatch
    var chordOverrides: [Int: DiatonicChord] = [:]
    let onTogglePlay: () -> Void

    private var tonearmState: VinylBoutiqueKinematics.TonearmState {
        VinylBoutiqueKinematics.state(isPlaying: isPlaying, reduceMotion: reduceMotion)
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
        let ink = palette.cartoonOutline

        Button {
            onTogglePlay()
        } label: {
            ZStack(alignment: .leading) {
                // 1. 滑动半露的转盘与中央播放圆帽
                ZStack {
                    MiniOrbitalDiscPreview(
                        document: document,
                        isNight: palette.isNight,
                        isPlaying: isPlaying,
                        reduceMotion: reduceMotion,
                        spinStartTime: spinStartTime,
                        chordPreset: chordPreset,
                        chordOverrides: chordOverrides
                    )
                    .frame(width: 62, height: 62)

                    Circle()
                        .fill(palette.cardSurface)
                        .overlay(Circle().strokeBorder(ink.opacity(0.85), lineWidth: 1.5))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isPlaying ? palette.nightLampGold : palette.homeAnchor)
                        )
                }
                .offset(x: tonearmState.discPeekOffsetX)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.78),
                    value: isPlaying
                )

                // 2. 扁平卡通绘本唱片封套（硬朗无模糊投影 + 书脊色条 + 草坡边饰 + 曲目主角小偶）
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(palette.cartoonShadow)
                        .offset(x: 2, y: placement.shadowOffsetY)

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                isPlaying ? modeColor : ink.opacity(palette.isNight ? 0.72 : 0.88),
                                lineWidth: isPlaying ? 2.1 : 1.7
                            )
                    )

                    // 左侧书脊色带
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(modeColor)
                        .frame(width: 4.5, height: 54)
                        .padding(.leading, 4)

                    VStack(spacing: 5) {
                        // 顶缘和声条码
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

                        // 封套中央主角小偶 + 定音图腾章
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hero.bodyHex).opacity(palette.isNight ? 0.34 : 0.24))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle().strokeBorder(ink.opacity(0.65), lineWidth: 1.2)
                                    )

                                ChimmoCartoonKeyBuddyView(
                                    member: hero,
                                    outlineColor: ink,
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
                                        .overlay(Circle().strokeBorder(ink.opacity(0.72), lineWidth: 1.0))
                                )
                                .offset(x: 5, y: 3)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 62, height: 66)

                // 3. 右上角扁平暖墨小唱臂
                Canvas { ctx, size in
                    let pivot = CGPoint(x: size.width - 7, y: 8)
                    let tip = CGPoint(x: size.width - 15, y: 31)
                    var arm = Path()
                    arm.move(to: pivot)
                    arm.addLine(to: tip)
                    ctx.stroke(
                        arm,
                        with: .color(ink),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: pivot.x - 3.4, y: pivot.y - 3.4, width: 6.8, height: 6.8)),
                        with: .color(palette.nightLampGold)
                    )
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: pivot.x - 3.4, y: pivot.y - 3.4, width: 6.8, height: 6.8)),
                        with: .color(ink),
                        lineWidth: 1.1
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: tip.x - 2.5, y: tip.y - 2.5, width: 5.0, height: 5.0)),
                        with: .color(isPlaying ? palette.nightLampGold : palette.storybookButter)
                    )
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: tip.x - 2.5, y: tip.y - 2.5, width: 5.0, height: 5.0)),
                        with: .color(ink),
                        lineWidth: 1.0
                    )
                }
                .frame(width: 92, height: 70)
                .rotationEffect(
                    .degrees(tonearmState.tonearmAngleDeg),
                    anchor: UnitPoint(x: 0.92, y: 0.11)
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.74),
                    value: isPlaying
                )
                .allowsHitTesting(false)
            }
            .frame(width: 94, height: 70, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "停止试听 \(document.title)" : "试听 \(document.title)")
    }
}

/// 迷你陶瓷星盘唱片缩略图（试听播放时同步转动、点亮正在唱出的音符并沿盘缘推进和弦彩环与金弧进度）
private struct MiniOrbitalDiscPreview: View {
    let document: MelodyDocument
    let isNight: Bool
    let isPlaying: Bool
    let reduceMotion: Bool
    let spinStartTime: Double
    private let cachedSpans: [ChordSpan]

    init(
        document: MelodyDocument,
        isNight: Bool,
        isPlaying: Bool,
        reduceMotion: Bool,
        spinStartTime: Double,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:]
    ) {
        self.document = document
        self.isNight = isNight
        self.isPlaying = isPlaying
        self.reduceMotion = reduceMotion
        self.spinStartTime = spinStartTime
        self.cachedSpans = TheoryLensEngine.buildChordSpans(
            document: document,
            preset: chordPreset,
            overrides: chordOverrides
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { _ in
            let now = CACurrentMediaTime()
            let total = max(1.0, document.totalDuration)
            let elapsed = isPlaying ? max(0.0, now - spinStartTime) : 0.0
            let progress = isPlaying ? StageTransportRingMapper.loopProgress(currentTime: elapsed, totalDuration: total) : 0.0
            let rot: Double = (isPlaying && !reduceMotion) ? -(elapsed / total) * 2.0 * Double.pi : 0.0

            Canvas { ctx, size in
                let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let maxR = min(size.width, size.height) * 0.455
                let discRect = CGRect(x: c.x - maxR, y: c.y - maxR, width: maxR * 2, height: maxR * 2)
                let discBg = isNight ? Color(hex: 0x161E44) : Color(hex: 0xFFFDF7)
                let rimCol = isNight ? Color(hex: 0xFFB94E) : Color(hex: 0x231B15)

                ctx.fill(Path(ellipseIn: discRect), with: .color(discBg))
                ctx.stroke(Path(ellipseIn: discRect), with: .color(rimCol), lineWidth: 1.8)

                if !cachedSpans.isEmpty {
                    let rimArcR = maxR - 0.8
                    for span in cachedSpans {
                        let a0 = -Double.pi / 2.0 + (span.startTime / total) * 2.0 * Double.pi + rot + 0.04
                        let a1 = -Double.pi / 2.0 + (span.endTime / total) * 2.0 * Double.pi + rot - 0.04
                        guard a1 > a0 else { continue }
                        var arc = Path()
                        arc.addArc(center: c, radius: rimArcR, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                        let activeSpan = isPlaying && elapsed >= span.startTime && elapsed < span.endTime
                        let spanCol = span.chord.color(isNight: isNight)
                        ctx.stroke(
                            arc,
                            with: .color(spanCol.opacity(activeSpan ? 0.90 : 0.42)),
                            style: StrokeStyle(lineWidth: activeSpan ? 2.4 : 1.5, lineCap: .round)
                        )
                    }
                }

                for ring in [0.46, 0.66, 0.84] {
                    let rr = maxR * CGFloat(ring)
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                        with: .color(Color.gray.opacity(0.18)),
                        lineWidth: 0.6
                    )
                }

                let groove = document.grooveStrength
                let notes = document.notes.sorted { $0.displayOnset(grooveStrength: groove) < $1.displayOnset(grooveStrength: groove) }
                let innerR = maxR * 0.30
                let outerR = maxR * 0.88
                var pts: [(pt: CGPoint, col: Color, laneIdx: Int, onset: Double, dur: Double)] = []
                for bead in notes {
                    let onset = bead.displayOnset(grooveStrength: groove)
                    let dur = bead.displayDuration(grooveStrength: groove)
                    let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                    let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: innerR, outerRadius: outerR)
                    let ang = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: onset, totalDuration: total) + rot
                    let pt = CGPoint(x: c.x + CGFloat(cos(ang)) * r, y: c.y + CGFloat(sin(ang)) * r)
                    let col = XylophoneLane.lane(at: laneIdx).barColor(isNight: isNight)
                    pts.append((pt, col, laneIdx, onset, dur))
                }

                if pts.count > 1 {
                    for i in 1..<pts.count {
                        let a = pts[i - 1]
                        let b = pts[i]
                        var seg = Path()
                        seg.move(to: a.pt)
                        seg.addLine(to: b.pt)
                        let style = IntervalSilkStyle.metrics(fromLane: a.laneIdx, toLane: b.laneIdx, isNight: isNight)
                        ctx.stroke(
                            seg,
                            with: .color(b.col.opacity(style.coreOpacity * 0.72)),
                            style: StrokeStyle(lineWidth: max(1.1, style.coreWidth * 0.58), lineCap: .round)
                        )
                    }
                }

                for item in pts {
                    let durWin = max(0.18, item.dur * 0.85)
                    let isActive = isPlaying && elapsed >= item.onset && elapsed < item.onset + durWin
                    if isActive {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: item.pt.x - 5.2, y: item.pt.y - 5.2, width: 10.4, height: 10.4)),
                            with: .color(Color(hex: 0xFFB84D).opacity(0.45))
                        )
                    }
                    let dotR: CGFloat = isActive ? 3.3 : 2.5
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: item.pt.x - dotR, y: item.pt.y - dotR, width: dotR * 2, height: dotR * 2)),
                        with: .color(isActive ? Color(hex: 0xFFB84D) : item.col)
                    )
                }

                let hubR = maxR * 0.22
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2)),
                    with: .color(Color(hex: 0xC88F2D).opacity(0.88))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - 1.4, y: c.y - 1.4, width: 2.8, height: 2.8)),
                    with: .color(Color.white.opacity(0.72))
                )

                if isPlaying && progress > 0.002 {
                    let ringR = maxR + 1.2
                    var arc = Path()
                    arc.addArc(
                        center: c,
                        radius: ringR,
                        startAngle: .radians(-Double.pi / 2.0),
                        endAngle: .radians(-Double.pi / 2.0 + progress * 2.0 * Double.pi),
                        clockwise: false
                    )
                    ctx.stroke(arc, with: .color(Color(hex: 0xFFB84D).opacity(0.28)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    ctx.stroke(arc, with: .color(Color(hex: 0xFFB84D).opacity(0.92)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }
        }
    }
}

/// 微型旋律高低走势彩线（在曲库唱片卡片上直接看懂每首旋律的轮廓起伏，无需文字解释）。
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
