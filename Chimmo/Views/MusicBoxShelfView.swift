import QuartzCore
import SwiftUI

/// 咩哞 v0.10 Tab 2：「唱片馆」—— 我的旋转脑放唱片 + 28 首公版/原创名曲黑胶馆（支持跟弹、放上声盘、借天光与黑胶明信片分享）
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSegment: Int = 1 // 默认也可在我的唱片(0)与28首名曲(1)间秒切；有保存作品自动先看0
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
        onDuplicateSavedEntry: @escaping (UUID) -> Void = { _ in }
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
                AmbientPaperBackdrop(palette: palette)

                VStack(spacing: 0) {
                    Picker("曲库", selection: $selectedSegment) {
                        Text("我的作品 (\(notebook.entries.count))").tag(0)
                        Text("经典曲库 (28)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if selectedSegment == 1 || !notebook.entries.isEmpty {
                        VStack(spacing: 7) {
                            if selectedSegment == 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(SpecimenLibrary.categories, id: \.self) { cat in
                                            let active = selectedCategory == cat
                                            Button {
                                                selectedCategory = cat
                                                if cat != "全部",
                                                   let mood = selectedMoodFilter,
                                                   !SpecimenLibrary.all.contains(where: { $0.specimenCategory == cat && $0.scaleMode == mood }) {
                                                    selectedMoodFilter = nil
                                                }
                                            } label: {
                                                Text(cat)
                                                    .font(.caption.weight(active ? .bold : .medium))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
                                                    .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ScaleMode.allCases) { mode in
                                        let isSel = selectedMoodFilter == mode
                                        let aurora = mode.skyAuroraColor(isNight: palette.isNight)
                                        Button {
                                            toggleMoodFilter(mode)
                                        } label: {
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(aurora)
                                                    .frame(width: 8, height: 8)
                                                Text(mode.shortSkyLabel)
                                                    .font(.caption2.weight(isSel ? .bold : .medium))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(isSel ? aurora.opacity(0.24) : palette.cardSurface))
                                            .overlay(
                                                Capsule().strokeBorder(isSel ? aurora : Color.clear, lineWidth: 1.2)
                                            )
                                            .foregroundStyle(isSel ? aurora : palette.secondaryInk)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("筛选\(mode.label)风格")
                                        .accessibilityValue(isSel ? "已选中" : "")
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    ScrollView {
                        VStack(spacing: 14) {
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
                        .padding(16)
                    }
                }
            }
            .navigationTitle("曲库")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索曲名")
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

    // MARK: - 1. My Saved Spinning Discs

    @ViewBuilder
    private var mySavedDiscsSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(palette.shelfSurface)
                        .frame(width: 72, height: 72)
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(palette.homeAnchor)
                }

                Text("暂无作品")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)

                Button {
                    onStartNewTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 56, height: 42)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("去写一段")
            }
            .padding(26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.05), radius: 12, y: 4)
            )
        } else if filteredSavedEntries.isEmpty {
            filteredEmptyPlaceholder
        } else {
            ForEach(Array(filteredSavedEntries.enumerated()), id: \.element.id) { idx, entry in
                savedDiscCard(entry: entry, index: idx)
            }
        }
    }

    private var filteredEmptyPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.secondaryInk)
            Text("暂无匹配曲目")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.secondaryInk)
            Button {
                searchText = ""
                selectedCategory = "全部"
                selectedMoodFilter = nil
                AcousticHapticsEngine.shared.playScrubTick()
            } label: {
                Text("重置筛选")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(palette.cardSurface))
                    .foregroundStyle(palette.homeAnchor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }

    private func savedDiscCard(entry: SavedMelodyEntry, index: Int) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let dateStr = entry.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let entryModeColor = entry.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let entryVoice = entry.document.preferredVoice ?? .singingCello

        return HStack(spacing: 14) {
            ZStack {
                MiniOrbitalDiscPreview(
                    document: entry.document,
                    isNight: palette.isNight,
                    isPlaying: isPlayingThis,
                    reduceMotion: reduceMotion,
                    spinStartTime: inlinePlayStart,
                    chordPreset: entry.chordPreset,
                    chordOverrides: entry.chordOverrides
                )
                .frame(width: 74, height: 74)

                Circle()
                    .fill(palette.cardSurface.opacity(0.88))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isPlayingThis ? palette.nightLampGold : palette.homeAnchor)
                    )
            }
            .onTapGesture {
                if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isPlayingThis ? "停止试听 \(entry.document.title)" : "试听 \(entry.document.title)")
            .accessibilityAction {
                if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entryModeColor)
                        .frame(width: 7, height: 7)
                    Text(dateStr)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(entryVoice.label) · \(entry.document.notes.count) 音")
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.secondaryInk)
                }

                Button {
                    renameTargetID = entry.id
                    renameDraftText = entry.document.title
                    showRenameAlert = true
                } label: {
                    Text(entry.document.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("轻点重命名作品")

                HStack(spacing: 8) {
                    Button {
                        if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
                    } label: {
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 28)
                            .background(Capsule().fill(isPlayingThis ? palette.nightLampGold : palette.homeAnchor))
                            .foregroundStyle((isPlayingThis || palette.isNight) ? Color(hex: 0x1B2245) : .white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlayingThis ? "停止试听" : "试听")

                    Button {
                        stopInlinePlay()
                        onLoadSavedToBoard(entry)
                    } label: {
                        Image(systemName: "record.circle")
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 28)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("在主舞台打开 \(entry.document.title)")

                    Spacer()

                    Button {
                        onShareSavedEntry(entry)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.homeAnchor)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("分享 \(entry.document.title)")

                    Button(role: .destructive) {
                        if isPlayingThis { stopInlinePlay() }
                        notebook.delete(id: entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除 \(entry.document.title)")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(
                    color: isPlayingThis
                        ? entryModeColor.opacity(palette.isNight ? 0.34 : 0.16)
                        : palette.primaryInk.opacity(palette.isNight ? 0.25 : 0.06),
                    radius: isPlayingThis ? 13 : 10,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isPlayingThis ? entryModeColor.opacity(0.60) : Color.clear, lineWidth: 1.5)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: isPlayingThis)
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
                notebook.delete(id: entry.id)
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

    // MARK: - 2. 28 Playable Masterpiece Vinyl Cards (Zero Essay Clutter)

    private var masterpieceDiscsSection: some View {
        ForEach(filteredSpecimens) { spec in
            let voice = spec.preferredVoice ?? .concertPiano
            let isPlayingThis = playingEntryID == spec.id
            let modeColor = spec.scaleMode.skyAuroraColor(isNight: palette.isNight)

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    MiniOrbitalDiscPreview(
                        document: spec,
                        isNight: palette.isNight,
                        isPlaying: isPlayingThis,
                        reduceMotion: reduceMotion,
                        spinStartTime: inlinePlayStart
                    )
                    .frame(width: 72, height: 72)

                    Circle()
                        .fill(palette.cardSurface.opacity(0.88))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isPlayingThis ? palette.nightLampGold : palette.homeAnchor)
                        )
                }
                .onTapGesture {
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
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isPlayingThis ? "停止试听 \(spec.title)" : "试听 \(spec.title)")
                .accessibilityAction {
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(spec.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)
                        Text(voice.label)
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.secondaryInk)
                        Spacer()
                        if spec.id == currentDocumentID {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(palette.homeAnchor)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
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
                        } label: {
                            Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                .font(.caption.weight(.bold))
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(isPlayingThis ? palette.nightLampGold : palette.homeAnchor))
                                .foregroundStyle((isPlayingThis || palette.isNight) ? Color(hex: 0x1B2245) : .white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPlayingThis ? "停止试听" : "试听 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onPlayAlongSpecimen(spec)
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(palette.nightLampGold.opacity(0.18)))
                                .foregroundStyle(palette.nightLampGold)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("跟灯弹 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onEditSpecimenOnBoard(spec)
                        } label: {
                            Image(systemName: "record.circle")
                                .font(.caption.weight(.bold))
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(palette.shelfSurface))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("在主舞台打开 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onBorrowAtmosphere(spec)
                        } label: {
                            ChimmoCraftMark(.atmosphereHorizon, color: modeColor)
                                .frame(width: 13, height: 13)
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(modeColor.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("套用 \(spec.title) 风格")
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(
                        color: isPlayingThis
                            ? modeColor.opacity(palette.isNight ? 0.34 : 0.16)
                            : palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.04),
                        radius: isPlayingThis ? 13 : 8,
                        y: 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isPlayingThis ? modeColor.opacity(0.60) : Color.clear, lineWidth: 1.5)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: isPlayingThis)
        }
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
            let progress = isPlaying ? min(1.0, elapsed / total) : 0.0
            let rot: Double = (isPlaying && !reduceMotion) ? -(elapsed / total) * 2.0 * Double.pi : 0.0

            Canvas { ctx, size in
                let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let maxR = min(size.width, size.height) * 0.455
                let discRect = CGRect(x: c.x - maxR, y: c.y - maxR, width: maxR * 2, height: maxR * 2)
                let discBg = isNight ? Color(hex: 0x1E2754) : Color(hex: 0xF7F1E4)
                let rimCol = isNight ? Color(hex: 0x564337) : Color(hex: 0xD3B78F)

                ctx.fill(Path(ellipseIn: discRect), with: .color(discBg))
                ctx.stroke(Path(ellipseIn: discRect), with: .color(rimCol.opacity(0.7)), lineWidth: 1.8)

                // 盘缘四幕彩环（预缓存 ChordSpan 零高频重建）
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

                // 淡淡纹路
                for ring in [0.46, 0.66, 0.84] {
                    let rr = maxR * CGFloat(ring)
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                        with: .color(Color.gray.opacity(0.16)),
                        lineWidth: 0.6
                    )
                }

                // 音符星座与棱镜音程渐变丝线
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
                            with: .linearGradient(
                                Gradient(colors: [a.col.opacity(style.coreOpacity * 0.62), b.col.opacity(style.coreOpacity * 0.62)]),
                                startPoint: a.pt,
                                endPoint: b.pt
                            ),
                            style: StrokeStyle(lineWidth: max(0.9, style.coreWidth * 0.55), lineCap: .round)
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

                // 暖金圆心
                let hubR = maxR * 0.22
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2)),
                    with: .color(Color(hex: 0xE5A93B).opacity(0.85))
                )

                // 外圈试听推进进度金弧
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
