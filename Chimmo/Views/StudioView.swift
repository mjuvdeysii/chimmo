import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum ChimmoTab: Int, Hashable, Sendable {
    case workbench = 0
    case journey = 1
    case notebook = 2
}

@MainActor
public final class StudioViewModel: ObservableObject {
    @Published public var document: MelodyDocument = SpecimenLibrary.saintSaensTheSwan
    @Published public var appearance: AppearancePreference = .auto
    @Published public var chordPreset: ChordProgressionPreset = .autoMatch
    @Published public var chordOverrides: [Int: DiatonicChord] = [:]
    @Published public var accompanimentTexture: AccompanimentTexture = .swanRipple
    @Published public var showTheoryLens: Bool = true
    @Published public var slowMotion: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var playheadTime: Double? = nil
    @Published public var activeDegrees: Set<Int> = []
    @Published public var latestDegree: Int? = 1
    @Published public var selectedBeadID: UUID? = nil
    @Published public var impulses: [VisualImpulse] = []
    @Published public var statusToast: String? = nil
    @Published public var canUndo: Bool = false
    @Published public var currentSavedEntryID: UUID? = nil
    @Published public var completedChapters: Set<Int>

    public let synth: FeltPianoSynth
    public let capturePipeline: HumCapturePipeline
    public let notebook: MelodyNotebookStore

    private let router = HalfDuplexAudioRouter()
    private var undoStack: [MelodyDocument] = []
    private var playbackTask: Task<Void, Never>?
    private var lastFreeNoteTime: Date?
    private var toastTask: Task<Void, Never>?

    public var chordSpans: [ChordSpan] {
        TheoryLensEngine.buildChordSpans(
            document: document,
            preset: chordPreset,
            overrides: chordOverrides
        )
    }

    public var currentInsight: MelodyTheoryInsight {
        TheoryLensEngine.analyze(document: document, spans: chordSpans)
    }

    public var cradleEnabled: Bool {
        chordPreset != .off
    }

    public init(notebookStore: MelodyNotebookStore? = nil) {
        let s = FeltPianoSynth(router: router)
        self.synth = s
        self.capturePipeline = HumCapturePipeline(router: router, synth: s)
        self.notebook = notebookStore ?? MelodyNotebookStore()
        let savedDone = UserDefaults.standard.array(forKey: "chimmo_completed_chapters") as? [Int] ?? []
        self.completedChapters = Set(savedDone)
    }

    // MARK: - Direct Tactile Ladder & Canvas Editing

    public func triggerLadderMember(_ member: ChimmoMember, octaveOffset: Int = 0) {
        stopPlayback()
        fireHaptic(style: member.degree == 1 ? .medium : .light)

        if document.isSpecimen {
            forkIntoFreeDraft()
        }

        let now = Date()
        let gap = lastFreeNoteTime.map { min(1.0, max(0.28, now.timeIntervalSince($0))) } ?? 0.0
        lastFreeNoteTime = now

        let nextOnset: Double
        if let last = document.notes.last {
            nextOnset = last.rawOnset + max(0.32, gap)
        } else {
            nextOnset = 0.15
        }

        if document.notes.count >= 18 {
            document.notes.removeFirst()
            if let firstOnset = document.notes.first?.rawOnset, firstOnset > 0 {
                for idx in document.notes.indices {
                    document.notes[idx].rawOnset = max(0, document.notes[idx].rawOnset - firstOnset)
                }
            }
        }

        pushUndo()
        let bead = NoteBead(degree: member.degree, octaveOffset: octaveOffset, rawOnset: nextOnset, rawDuration: 0.50)
        document.notes.append(bead)
        selectedBeadID = bead.id

        let totalSec = max(3.2, document.totalDuration)
        let xNorm = min(0.94, max(0.06, nextOnset / totalSec))
        playSingleNoteWithChord(degree: member.degree, octaveOffset: octaveOffset, atTime: nextOnset, xNorm: xNorm)
    }

    public func placeNoteOnCanvas(degree: Int, octaveOffset: Int, atTime: Double) {
        stopPlayback()
        fireHaptic(style: .light)

        if document.isSpecimen {
            forkIntoFreeDraft()
        }

        let clampedTime = max(0.08, atTime)
        pushUndo()
        let bead = NoteBead(degree: degree, octaveOffset: octaveOffset, rawOnset: clampedTime, rawDuration: 0.50)
        document.notes.append(bead)
        document.notes.sort { $0.rawOnset < $1.rawOnset }
        selectedBeadID = bead.id

        let totalSec = max(3.2, document.totalDuration)
        let xNorm = min(0.94, max(0.06, clampedTime / totalSec))
        playSingleNoteWithChord(degree: degree, octaveOffset: octaveOffset, atTime: clampedTime, xNorm: xNorm)
    }

    public func adjustSelectedBeadDuration(delta: Double) {
        guard let targetID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == targetID }) else { return }
        pushUndo()
        let next = max(0.16, min(2.4, document.notes[idx].rawDuration + delta))
        document.notes[idx].rawDuration = next
        if document.notes[idx].quantizedDuration != nil {
            document.notes[idx].quantizedDuration = next
        }
        fireHaptic(style: .soft)
        previewBead(document.notes[idx])
        showToast(delta > 0 ? "音珠呼吸已拉长" : "音珠已变短促")
    }

    public func deleteSelectedBead() {
        guard let targetID = selectedBeadID else { return }
        pushUndo()
        document.notes.removeAll { $0.id == targetID }
        selectedBeadID = nil
        fireHaptic(style: .light)
        showToast("已删去该音珠")
    }

    public func cycleSpanChord(spanIndex: Int) {
        let spans = chordSpans
        guard let currentSpan = spans.first(where: { $0.id == spanIndex }) else { return }
        let next = currentSpan.chord.nextChord()
        chordOverrides[spanIndex] = next
        fireHaptic(style: .soft)
        synth.playDiatonicChord(
            rootMIDI: document.rootMIDI,
            mode: document.scaleMode,
            chord: next,
            texture: accompanimentTexture,
            spanDuration: max(1.0, currentSpan.endTime - currentSpan.startTime),
            intensity: 0.88
        )
        showToast("第 \(spanIndex + 1) 小节和弦已换为 \(next.roman)（\(next.tonesFormula) · \(next.moodTitle)）")
    }

    public func setChordPreset(_ preset: ChordProgressionPreset) {
        chordPreset = preset
        chordOverrides.removeAll()
        if let firstChord = chordSpans.first?.chord {
            synth.playDiatonicChord(
                rootMIDI: document.rootMIDI,
                mode: document.scaleMode,
                chord: firstChord,
                texture: accompanimentTexture,
                intensity: 0.84
            )
        }
        showToast("和弦光带：\(preset.label)")
    }

    public func setAccompanimentTexture(_ texture: AccompanimentTexture) {
        accompanimentTexture = texture
        if chordPreset == .off { chordPreset = .autoMatch }
        if let firstChord = chordSpans.first?.chord {
            synth.playDiatonicChord(
                rootMIDI: document.rootMIDI,
                mode: document.scaleMode,
                chord: firstChord,
                texture: texture,
                spanDuration: 1.4,
                intensity: 0.88
            )
        }
        showToast("左手伴奏织体：\(texture.label)（\(texture.subtitle)）")
    }

    public func toggleScaleMode() {
        pushUndo()
        document.scaleMode = (document.scaleMode == .brightMajor) ? .wistfulMinor : .brightMajor
        fireHaptic(style: .soft)
        playSingleNoteWithChord(degree: 3, octaveOffset: 0, atTime: 0.2, xNorm: 0.45)
        showToast(
            document.scaleMode == .brightMajor
                ? "☀️ 晴空大调：3·拍咯上移半格，感受明朗暖意"
                : "🌧 微雨小调：3·拍咯下移半格（♭3），染上电影思念"
        )
    }

    public func startBlankCanvas(preferredTexture: AccompanimentTexture? = nil, preferredMode: ScaleMode? = nil) {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        if let tex = preferredTexture {
            accompanimentTexture = tex
        }
        if chordPreset == .off { chordPreset = .autoMatch }
        document = MelodyDocument(
            title: "新脑放草图",
            subtitle: "轻哼、点左侧阶梯，或直接在画布点绘",
            rootMIDI: 60,
            scaleMode: preferredMode ?? document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false,
            preferredTexture: accompanimentTexture
        )
        lastFreeNoteTime = nil
        impulses.removeAll()
        showToast("已用「\(accompanimentTexture.label)」铺好空白卷轴，轻哼或点绘即可开始！")
    }

    public func openSpecimen(_ specimen: MelodyDocument) {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        chordPreset = .autoMatch
        accompanimentTexture = specimen.preferredTexture ?? .swanRipple
        document = specimen
        showTheoryLens = true
        togglePlayback()
    }

    public func openSavedEntry(_ entry: SavedMelodyEntry) {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = entry.id
        selectedBeadID = nil
        document = entry.document
        chordPreset = entry.chordPreset
        chordOverrides = entry.chordOverrides
        accompanimentTexture = entry.accompanimentTexture ?? entry.document.preferredTexture ?? .swanRipple
        togglePlayback()
    }

    public func saveCurrentToNotebook() {
        guard !document.notes.isEmpty else {
            showToast("先哼一句或点几颗音珠，再存入乐思本吧")
            return
        }
        var docToSave = document
        if docToSave.isSpecimen || docToSave.title == "新脑放草图" || docToSave.title == "指尖即兴" {
            docToSave.title = "脑放记录 #\(notebook.entries.count + 1)"
        }
        docToSave.isSpecimen = false
        docToSave.preferredTexture = accompanimentTexture

        let saved = notebook.save(
            document: docToSave,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            summaryNote: currentInsight.headline,
            existingEntryID: currentSavedEntryID
        )
        currentSavedEntryID = saved.id
        document = saved.document
        fireHaptic(style: .medium)
        showToast("已存入「乐思本」：\(saved.document.title)")
    }

    // MARK: - Bead & Ghost Editing

    public func applyGhost(beadID: UUID, ghost: GhostCandidate) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        pushUndo()
        document.notes[idx].degree = ghost.degree
        document.notes[idx].octaveOffset = ghost.octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        selectedBeadID = beadID
        fireHaptic(style: .rigid)
        let onset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleNoteWithChord(degree: ghost.degree, octaveOffset: ghost.octaveOffset, atTime: onset, xNorm: xNorm)
    }

    public func updateBeadPitch(beadID: UUID, degree: Int, octaveOffset: Int) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        if document.notes[idx].degree == degree && document.notes[idx].octaveOffset == octaveOffset { return }
        pushUndo()
        document.notes[idx].degree = degree
        document.notes[idx].octaveOffset = octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        selectedBeadID = beadID
        fireHaptic(style: .soft)
        let onset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleNoteWithChord(degree: degree, octaveOffset: octaveOffset, atTime: onset, xNorm: xNorm)
    }

    public func previewBead(_ bead: NoteBead) {
        selectedBeadID = bead.id
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleNoteWithChord(degree: bead.degree, octaveOffset: bead.octaveOffset, atTime: onset, xNorm: xNorm)
    }

    // MARK: - Hum Capture

    public func startHumCapture() {
        stopPlayback()
        fireHaptic(style: .medium)
        capturePipeline.startRecording()
    }

    public func finishHumCapture() {
        Task {
            if let snapped = await capturePipeline.stopAndTranscribe(preferredMode: nil), !snapped.notes.isEmpty {
                pushUndo()
                currentSavedEntryID = nil
                selectedBeadID = nil
                chordOverrides.removeAll()
                chordPreset = .autoMatch
                document = MelodyDocument(
                    title: "刚哼出的脑放 #\(notebook.entries.count + 1)",
                    subtitle: "\(snapped.mode.label) · 试试切换「天鹅水波」或「夏日清风」伴奏！",
                    rootMIDI: snapped.rootMIDI,
                    scaleMode: snapped.mode,
                    harmonyProfile: document.harmonyProfile,
                    grooveStrength: 0.0,
                    notes: snapped.notes,
                    isSpecimen: false,
                    preferredTexture: accompanimentTexture
                )
                showTheoryLens = true
                showToast("捉住 \(snapped.notes.count) 颗音珠！已为你配上「\(accompanimentTexture.label)」伴奏")
                togglePlayback()
            } else if !capturePipeline.statusMessage.isEmpty {
                showToast(capturePipeline.statusMessage)
            }
        }
    }

    // MARK: - Looping Playback Sequencer

    public func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }
        guard !document.notes.isEmpty else {
            triggerLadderMember(.taono, octaveOffset: 0)
            return
        }
        synth.ensureRunning()
        isPlaying = true

        playbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled && self.isPlaying {
                let speed = self.slowMotion ? 0.6 : 1.0
                let total = self.document.totalDuration
                let totalCanvasSec = max(3.2, total)
                let sorted = self.document.notes.sorted {
                    $0.displayOnset(grooveStrength: self.document.grooveStrength) < $1.displayOnset(grooveStrength: self.document.grooveStrength)
                }

                let startDate = Date()
                var nextNoteIdx = 0
                var lastTriggeredSpanID: Int = -1

                while !Task.isCancelled && self.isPlaying {
                    let elapsed = Date().timeIntervalSince(startDate) * speed
                    self.playheadTime = elapsed

                    let spans = self.chordSpans
                    if let currentSpan = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }),
                       currentSpan.id != lastTriggeredSpanID {
                        lastTriggeredSpanID = currentSpan.id
                        let spanDur = (currentSpan.endTime - currentSpan.startTime) / speed
                        self.synth.playDiatonicChord(
                            rootMIDI: self.document.rootMIDI,
                            mode: self.document.scaleMode,
                            chord: currentSpan.chord,
                            texture: self.accompanimentTexture,
                            spanDuration: spanDur,
                            intensity: 0.82
                        )
                    }

                    while nextNoteIdx < sorted.count &&
                            sorted[nextNoteIdx].displayOnset(grooveStrength: self.document.grooveStrength) <= elapsed {
                        let bead = sorted[nextNoteIdx]
                        let onset = bead.displayOnset(grooveStrength: self.document.grooveStrength)
                        let dur = bead.displayDuration(grooveStrength: self.document.grooveStrength) / speed
                        let xNorm = min(0.94, max(0.06, onset / totalCanvasSec))
                        self.performScheduledBead(bead, durationSec: dur, xNorm: xNorm)
                        nextNoteIdx += 1
                    }

                    if elapsed >= total {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }

                if Task.isCancelled || !self.isPlaying { break }
                try? await Task.sleep(nanoseconds: 450_000_000)
            }

            if !Task.isCancelled {
                self.stopPlayback()
            }
        }
    }

    public func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        playheadTime = nil
        activeDegrees.removeAll()
    }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        stopPlayback()
        document = prev
        selectedBeadID = nil
        canUndo = !undoStack.isEmpty
        showToast("已撤销上一步")
    }

    // MARK: - Internals

    private func forkIntoFreeDraft() {
        pushUndo()
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        document = MelodyDocument(
            title: "指尖即兴",
            subtitle: "点左侧阶梯或画布任意处即可写音",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false,
            preferredTexture: accompanimentTexture
        )
        lastFreeNoteTime = nil
    }

    private func pushUndo() {
        undoStack.append(document)
        if undoStack.count > 25 { undoStack.removeFirst() }
        canUndo = true
    }

    private func spawnImpulse(degree: Int, octaveOffset: Int, xNorm: Double) {
        let now = Date().timeIntervalSinceReferenceDate
        impulses.removeAll { now - $0.birth > 1.8 }
        impulses.append(VisualImpulse(birth: now, degree: degree, octaveOffset: octaveOffset, xNorm: xNorm))
    }

    private func performScheduledBead(_ bead: NoteBead, durationSec: Double, xNorm: Double) {
        let member = bead.member
        latestDegree = member.degree
        spawnImpulse(degree: bead.degree, octaveOffset: bead.octaveOffset, xNorm: xNorm)

        let hz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: bead.degree,
            octaveOffset: bead.octaveOffset
        )
        synth.playNote(frequency: hz, velocity: 0.62, decay: max(1.05, durationSec * 1.45), brightness: 0.96)

        activeDegrees.insert(member.degree)
        let holdNs = UInt64(max(0.20, min(0.55, durationSec * 0.85)) * 1_000_000_000)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: holdNs)
            self?.activeDegrees.remove(member.degree)
        }
    }

    private func playSingleNoteWithChord(degree: Int, octaveOffset: Int, atTime: Double, xNorm: Double) {
        let member = ChimmoMember.from(degree: degree)
        latestDegree = member.degree
        spawnImpulse(degree: degree, octaveOffset: octaveOffset, xNorm: xNorm)

        let hz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: degree,
            octaveOffset: octaveOffset
        )
        synth.playNote(frequency: hz, velocity: 0.62, decay: 1.65, brightness: 0.96)

        if let ch = TheoryLensEngine.chord(at: atTime, in: chordSpans) {
            synth.playDiatonicChord(
                rootMIDI: document.rootMIDI,
                mode: document.scaleMode,
                chord: ch,
                texture: accompanimentTexture,
                spanDuration: 1.15,
                intensity: 0.52
            )
        }

        activeDegrees.insert(member.degree)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            self?.activeDegrees.remove(member.degree)
        }
    }

    private func showToast(_ text: String) {
        statusToast = text
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                self?.statusToast = nil
            }
        }
    }

    private func fireHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
        #endif
    }
}

/// 咩哞 0.3 主入口：创作工作台 · 8 关音律启蒙馆 · 28 首公版名曲与脑放乐思本
public struct StudioView: View {
    @StateObject private var vm = StudioViewModel()
    @Environment(\.colorScheme) private var systemScheme
    @State private var selectedTab: ChimmoTab = .workbench
    @State private var showAbout = false

    public init() {}

    private var isNight: Bool {
        switch vm.appearance {
        case .auto: return systemScheme == .dark
        case .daylight: return false
        case .nightLamp: return true
        }
    }

    private var palette: ChimmoPalette { ChimmoPalette(isNight: isNight) }

    public var body: some View {
        TabView(selection: $selectedTab) {
            workbenchTab
                .tabItem {
                    Label("创作", systemImage: "waveform.path.ecg")
                }
                .tag(ChimmoTab.workbench)

            TheoryJourneyView(
                palette: palette,
                synth: vm.synth,
                completedChapters: $vm.completedChapters,
                onJumpToCapture: {
                    vm.startBlankCanvas()
                    selectedTab = .workbench
                },
                onOpenSwanMasterpiece: {
                    vm.openSpecimen(SpecimenLibrary.saintSaensTheSwan)
                    selectedTab = .workbench
                }
            )
            .tabItem {
                Label("启蒙", systemImage: "sparkles")
            }
            .tag(ChimmoTab.journey)

            NotebookAndLibraryView(
                palette: palette,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                onOpenSavedEntry: { entry in
                    vm.openSavedEntry(entry)
                    selectedTab = .workbench
                },
                onOpenSpecimen: { spec in
                    vm.openSpecimen(spec)
                    selectedTab = .workbench
                },
                onBorrowStyleToCreate: { tex, mode in
                    vm.startBlankCanvas(preferredTexture: tex, preferredMode: mode)
                    selectedTab = .workbench
                },
                onStartNewMelody: {
                    vm.startBlankCanvas()
                    selectedTab = .workbench
                }
            )
            .tabItem {
                Label("名曲与记录", systemImage: "music.note.list")
            }
            .tag(ChimmoTab.notebook)
        }
        .tint(palette.homeAnchor)
        .preferredColorScheme(vm.appearance == .auto ? nil : (isNight ? .dark : .light))
    }

    // MARK: - Tab 1: Workbench

    private var workbenchTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                theoryInsightBanner

                HarmonicLadderCanvas(
                    document: vm.document,
                    chordSpans: vm.chordSpans,
                    palette: palette,
                    showTheoryLens: vm.showTheoryLens,
                    playheadTime: vm.playheadTime,
                    activeDegrees: vm.activeDegrees,
                    latestDegree: vm.latestDegree,
                    selectedBeadID: vm.selectedBeadID,
                    impulses: vm.impulses,
                    onTriggerLadderMember: { member, oct in vm.triggerLadderMember(member, octaveOffset: oct) },
                    onTapCanvasPitch: { deg, oct, t in vm.placeNoteOnCanvas(degree: deg, octaveOffset: oct, atTime: t) },
                    onSelectGhost: { id, ghost in vm.applyGhost(beadID: id, ghost: ghost) },
                    onDragBeadPitch: { id, deg, oct in vm.updateBeadPitch(beadID: id, degree: deg, octaveOffset: oct) },
                    onTapBead: { bead in vm.previewBead(bead) },
                    onCycleSpanChord: { idx in vm.cycleSpanChord(spanIndex: idx) },
                    onAdjustSelectedDuration: { delta in vm.adjustSelectedBeadDuration(delta: delta) },
                    onDeleteSelectedBead: { vm.deleteSelectedBead() },
                    onDismissSelection: { vm.selectedBeadID = nil }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                workbenchControlDock
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle(vm.document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        vm.showTheoryLens.toggle()
                    } label: {
                        Image(systemName: vm.showTheoryLens ? "eye.fill" : "eye.slash")
                    }
                    .accessibilityLabel(vm.showTheoryLens ? "隐藏乐理透视与字幕" : "开启乐理透视与字幕")

                    if vm.canUndo {
                        Button {
                            vm.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .accessibilityLabel("撤销")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        vm.saveCurrentToNotebook()
                    } label: {
                        Image(systemName: vm.currentSavedEntryID != nil ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel("保存当前旋律到我的脑放记录")

                    Button {
                        vm.startBlankCanvas()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建空白音阶画卷")

                    Button {
                        let next: AppearancePreference = isNight ? .daylight : .nightLamp
                        vm.appearance = next
                    } label: {
                        Image(systemName: isNight ? "sun.max" : "moon.stars")
                    }
                    .accessibilityLabel(isNight ? "切换晴空浅色" : "切换星夜深色")

                    Button {
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("关于咩哞与导出 MIDI")
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutSheetView(
                    palette: palette,
                    currentDocument: vm.document,
                    cradleEnabled: vm.cradleEnabled
                )
            }
        }
    }

    private var theoryInsightBanner: some View {
        let insight = vm.currentInsight

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Label(vm.accompanimentTexture.label, systemImage: vm.accompanimentTexture.iconName)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(palette.bassRibbon.opacity(0.15)))
                            .foregroundStyle(palette.bassRibbon)

                        ForEach(insight.highlightedTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(palette.homeAnchor.opacity(0.14)))
                                .foregroundStyle(palette.homeAnchor)
                        }
                    }
                }

                if vm.completedChapters.count < TheoryChapter.allCases.count {
                    Button {
                        vm.stopPlayback()
                        selectedTab = .journey
                    } label: {
                        Text("启蒙 \(vm.completedChapters.count)/8 →")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(palette.melodyTerracotta.opacity(0.15)))
                            .foregroundStyle(palette.melodyTerracotta)
                    }
                }
            }

            Text(vm.statusToast ?? insight.headline)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.primaryInk)
                .lineLimit(2)

            if vm.statusToast == nil {
                Text("💡 \(insight.tryNextTip)")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.cardSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private var workbenchControlDock: some View {
        HStack(spacing: 10) {
            // 1. 循环试听 / 暂停
            Button {
                vm.togglePlayback()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(vm.isPlaying ? "暂停" : "试听")
                        .font(.caption2.weight(.semibold))
                }
                .frame(width: 50, height: 48)
                .foregroundStyle(palette.homeAnchor)
            }
            .accessibilityLabel(vm.isPlaying ? "暂停试听" : "循环试听")

            // 2. 晴空大调 / 微雨小调切换
            Button {
                vm.toggleScaleMode()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.document.scaleMode == .brightMajor ? "sun.max.fill" : "cloud.rain.fill")
                        .font(.title3)
                    Text(vm.document.scaleMode == .brightMajor ? "大调" : "小调")
                        .font(.caption2.weight(.semibold))
                }
                .frame(width: 46, height: 48)
                .foregroundStyle(ChimmoMember.plokko.bodyColor)
            }
            .accessibilityLabel("切换大调与小调")

            Spacer()

            // 3. 中央主操作：轻哼捉珠
            Button {
                if vm.capturePipeline.isRecording {
                    vm.finishHumCapture()
                } else {
                    vm.startHumCapture()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: vm.capturePipeline.isRecording ? "stop.fill" : "waveform")
                        .font(.headline)
                    Text(vm.capturePipeline.isRecording ? "唱完了" : "轻哼捉珠")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(vm.capturePipeline.isRecording ? palette.tensionFilament : palette.melodyTerracotta)
                )
                .foregroundStyle(.white)
                .scaleEffect(vm.capturePipeline.isRecording ? 1.0 + CGFloat(vm.capturePipeline.inputLevel) * 0.08 : 1.0)
            }
            .accessibilityLabel(vm.capturePipeline.isRecording ? "结束哼唱并凝结成音珠" : "开始轻哼捕捉脑海旋律")

            Spacer()

            // 4. 大师织体（天鹅水波 / 圆舞 / 夏日清风）+ 和弦光带预设菜单
            Menu {
                Section("左手伴奏织体（一键变身大师风）") {
                    ForEach(AccompanimentTexture.allCases) { tex in
                        Button {
                            vm.setAccompanimentTexture(tex)
                        } label: {
                            if vm.accompanimentTexture == tex {
                                Label(tex.label, systemImage: "checkmark")
                            } else {
                                Label(tex.label, systemImage: tex.iconName)
                            }
                        }
                    }
                }
                Section("和弦光带进行") {
                    ForEach(ChordProgressionPreset.allCases) { preset in
                        Button {
                            vm.setChordPreset(preset)
                        } label: {
                            if vm.chordPreset == preset {
                                Label(preset.label, systemImage: "checkmark")
                            } else {
                                Text(preset.label)
                            }
                        }
                    }
                }
                Section("播放速度") {
                    Button {
                        vm.slowMotion.toggle()
                    } label: {
                        Label(vm.slowMotion ? "恢复原速 (1.0×)" : "慢镜拆解 (0.6×)", systemImage: "tortoise")
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.accompanimentTexture.iconName)
                        .font(.title3)
                    Text("织体")
                        .font(.caption2.weight(.semibold))
                }
                .frame(width: 50, height: 48)
                .foregroundStyle(vm.chordPreset == .off ? palette.secondaryInk : palette.bassRibbon)
            }
            .accessibilityLabel("切换左手伴奏织体与和弦光带进行")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.cardSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}
