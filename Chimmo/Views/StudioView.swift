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
    @Published public var document: MelodyDocument = SpecimenLibrary.summerSuspension
    @Published public var appearance: AppearancePreference = .auto
    @Published public var chordPreset: ChordProgressionPreset = .autoMatch
    @Published public var chordOverrides: [Int: DiatonicChord] = [:]
    @Published public var showTheoryLens: Bool = true
    @Published public var slowMotion: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var playheadTime: Double? = nil
    @Published public var activeDegrees: Set<Int> = []
    @Published public var latestDegree: Int? = 1
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

    /// 点按或滑动左侧「真实半音阶梯」上的任意咩哞
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

        if document.notes.count >= 16 {
            document.notes.removeFirst()
            if let firstOnset = document.notes.first?.rawOnset, firstOnset > 0 {
                for idx in document.notes.indices {
                    document.notes[idx].rawOnset = max(0, document.notes[idx].rawOnset - firstOnset)
                }
            }
        }

        pushUndo()
        document.notes.append(
            NoteBead(degree: member.degree, octaveOffset: octaveOffset, rawOnset: nextOnset, rawDuration: 0.48)
        )

        let totalSec = max(3.2, document.totalDuration)
        let xNorm = min(0.94, max(0.06, nextOnset / totalSec))
        playSingleNoteWithChord(degree: member.degree, octaveOffset: octaveOffset, atTime: nextOnset, xNorm: xNorm)
    }

    /// 在右侧画布空白处点按：直接在对应时间与真实音高处落下一颗陶珠
    public func placeNoteOnCanvas(degree: Int, octaveOffset: Int, atTime: Double) {
        stopPlayback()
        fireHaptic(style: .light)

        if document.isSpecimen {
            forkIntoFreeDraft()
        }

        let clampedTime = max(0.08, atTime)
        pushUndo()
        document.notes.append(
            NoteBead(degree: degree, octaveOffset: octaveOffset, rawOnset: clampedTime, rawDuration: 0.48)
        )
        document.notes.sort { $0.rawOnset < $1.rawOnset }

        let totalSec = max(3.2, document.totalDuration)
        let xNorm = min(0.94, max(0.06, clampedTime / totalSec))
        playSingleNoteWithChord(degree: degree, octaveOffset: octaveOffset, atTime: clampedTime, xNorm: xNorm)
    }

    /// 点击画布底部任意一小节的和弦卡片：立刻换掉该小节的和弦光带并试听新伴奏！
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
            intensity: 0.88
        )
        showToast("第 \(spanIndex + 1) 小节已换为 \(next.roman)（\(next.tonesFormula) · \(next.moodTitle)）")
    }

    public func setChordPreset(_ preset: ChordProgressionPreset) {
        chordPreset = preset
        chordOverrides.removeAll()
        if let firstChord = chordSpans.first?.chord {
            synth.playDiatonicChord(
                rootMIDI: document.rootMIDI,
                mode: document.scaleMode,
                chord: firstChord,
                intensity: 0.80
            )
        }
        showToast("和弦光带：\(preset.label)")
    }

    public func toggleScaleMode() {
        pushUndo()
        document.scaleMode = (document.scaleMode == .brightMajor) ? .wistfulMinor : .brightMajor
        fireHaptic(style: .soft)
        playSingleNoteWithChord(degree: 3, octaveOffset: 0, atTime: 0.2, xNorm: 0.45)
        showToast(
            document.scaleMode == .brightMajor
                ? "晴朗大调：左侧 3·拍咯上移半音，听听明朗色彩"
                : "微酸小调：左侧 3·拍咯下移半音（♭3），感受思念氛围"
        )
    }

    public func startBlankCanvas() {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        if chordPreset == .off { chordPreset = .autoMatch }
        document = MelodyDocument(
            title: "新脑放草图",
            subtitle: "轻哼、点左侧阶梯，或直接在画布点绘",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false
        )
        lastFreeNoteTime = nil
        impulses.removeAll()
        showToast("已铺好空白音阶卷轴")
    }

    public func openSpecimen(_ specimen: MelodyDocument) {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        chordPreset = .autoMatch
        document = specimen
        showTheoryLens = true
        togglePlayback()
    }

    public func openSavedEntry(_ entry: SavedMelodyEntry) {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = entry.id
        document = entry.document
        chordPreset = entry.chordPreset
        chordOverrides = entry.chordOverrides
        togglePlayback()
    }

    /// 把当前脑放旋律保存到本机「乐思本」
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

        let saved = notebook.save(
            document: docToSave,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
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
        fireHaptic(style: .soft)
        let onset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleNoteWithChord(degree: degree, octaveOffset: octaveOffset, atTime: onset, xNorm: xNorm)
    }

    public func previewBead(_ bead: NoteBead) {
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleNoteWithChord(degree: bead.degree, octaveOffset: bead.octaveOffset, atTime: onset, xNorm: xNorm)
    }

    // MARK: - Hum Capture (脑放哼唱自动转谱 + 自动配和弦光带 + 自动解读)

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
                chordOverrides.removeAll()
                chordPreset = .autoMatch
                document = MelodyDocument(
                    title: "刚哼出的脑放 #\(notebook.entries.count + 1)",
                    subtitle: "\(snapped.mode.label) · 拖音珠可微调，点右上角可存进乐思本",
                    rootMIDI: snapped.rootMIDI,
                    scaleMode: snapped.mode,
                    harmonyProfile: document.harmonyProfile,
                    grooveStrength: 0.0,
                    notes: snapped.notes,
                    isSpecimen: false
                )
                showTheoryLens = true
                showToast("捉住 \(snapped.notes.count) 颗音珠，已自动配好和弦光带！")
                togglePlayback()
            } else if !capturePipeline.statusMessage.isEmpty {
                showToast(capturePipeline.statusMessage)
            }
        }
    }

    // MARK: - Looping Playback Sequencer (Synchronized with Chord Spans)

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
                let speed = self.slowMotion ? 0.55 : 1.0
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

                    // 在进入每个新的和弦光带区间时，奏响温暖错落三和弦琶音
                    let spans = self.chordSpans
                    if let currentSpan = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }),
                       currentSpan.id != lastTriggeredSpanID {
                        lastTriggeredSpanID = currentSpan.id
                        self.synth.playDiatonicChord(
                            rootMIDI: self.document.rootMIDI,
                            mode: self.document.scaleMode,
                            chord: currentSpan.chord,
                            intensity: 0.78
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
                try? await Task.sleep(nanoseconds: 400_000_000)
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
        canUndo = !undoStack.isEmpty
        showToast("已撤销上一步")
    }

    // MARK: - Internals

    private func forkIntoFreeDraft() {
        pushUndo()
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        document = MelodyDocument(
            title: "指尖即兴",
            subtitle: "点左侧音阶阶梯或画布任意处即可写音",
            rootMIDI: document.rootMIDI,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false
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
        synth.playNote(frequency: hz, velocity: 0.58, decay: max(0.95, durationSec * 1.4), brightness: 0.95)

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
        synth.playNote(frequency: hz, velocity: 0.60, decay: 1.6, brightness: 0.95)

        if let ch = TheoryLensEngine.chord(at: atTime, in: chordSpans) {
            synth.playDiatonicChord(rootMIDI: document.rootMIDI, mode: document.scaleMode, chord: ch, intensity: 0.58)
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
            try? await Task.sleep(nanoseconds: 2_800_000_000)
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

/// 咩哞 2.0 主入口：三大清晰板块（创作工作台 / 音律启蒙 6 课 / 乐思本与名曲透视库）
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
            // 1. 创作与脑放捕捉工作台（真实半音阶梯 + 和弦泳道光带 + 实时乐理解读）
            workbenchTab
                .tabItem {
                    Label("创作", systemImage: "waveform.path.ecg")
                }
                .tag(ChimmoTab.workbench)

            // 2. 6 关 30 秒互动式音律启蒙微剧场
            TheoryJourneyView(
                palette: palette,
                synth: vm.synth,
                completedChapters: $vm.completedChapters,
                onJumpToCapture: {
                    vm.startBlankCanvas()
                    selectedTab = .workbench
                }
            )
            .tabItem {
                Label("启蒙", systemImage: "sparkles")
            }
            .tag(ChimmoTab.journey)

            // 3. 我的脑放乐思本 + 16 首名曲透视库
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
                onStartNewMelody: {
                    vm.startBlankCanvas()
                    selectedTab = .workbench
                }
            )
            .tabItem {
                Label("乐思本", systemImage: "book.pages")
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
                // 顶部实时乐理解读与新手启蒙引导条
                theoryInsightBanner

                // 核心舞台：左侧真实半音七小只阶梯 + 右侧发光和弦泳道卷轴 + 底部可切换和弦条
                HarmonicLadderCanvas(
                    document: vm.document,
                    chordSpans: vm.chordSpans,
                    palette: palette,
                    showTheoryLens: vm.showTheoryLens,
                    playheadTime: vm.playheadTime,
                    activeDegrees: vm.activeDegrees,
                    latestDegree: vm.latestDegree,
                    impulses: vm.impulses,
                    onTriggerLadderMember: { member, oct in vm.triggerLadderMember(member, octaveOffset: oct) },
                    onTapCanvasPitch: { deg, oct, t in vm.placeNoteOnCanvas(degree: deg, octaveOffset: oct, atTime: t) },
                    onSelectGhost: { id, ghost in vm.applyGhost(beadID: id, ghost: ghost) },
                    onDragBeadPitch: { id, deg, oct in vm.updateBeadPitch(beadID: id, degree: deg, octaveOffset: oct) },
                    onTapBead: { bead in vm.previewBead(bead) },
                    onCycleSpanChord: { idx in vm.cycleSpanChord(spanIndex: idx) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 底部四大直觉主控：循环听 / 轻哼捉珠 / 晴雨大调小调 / 和弦光带模板
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
                    .accessibilityLabel(vm.showTheoryLens ? "隐藏乐理透视标注" : "开启乐理透视标注")

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
                    .accessibilityLabel("保存当前脑放旋律到乐思本")

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
                        Image(systemName: isNight ? "sun.max" : "lamp.desk")
                    }
                    .accessibilityLabel(isNight ? "切换日光纸面" : "切换夜灯舞台")

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
                        Text("音律启蒙 \(vm.completedChapters.count)/6 →")
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(palette.melodyTerracotta.opacity(0.16)))
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
        .background(palette.paper)
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
                        .font(.caption2.weight(.medium))
                }
                .frame(width: 52, height: 48)
                .foregroundStyle(palette.homeAnchor)
            }
            .accessibilityLabel(vm.isPlaying ? "暂停循环试听" : "循环试听当前旋律与和弦光带")

            // 2. 晴朗大调 / 微酸小调切换（直接驱动左侧半音阶梯滑动！）
            Button {
                vm.toggleScaleMode()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.document.scaleMode == .brightMajor ? "sun.max.fill" : "cloud.rain.fill")
                        .font(.title3)
                    Text(vm.document.scaleMode == .brightMajor ? "大调" : "小调")
                        .font(.caption2.weight(.medium))
                }
                .frame(width: 48, height: 48)
                .foregroundStyle(ChimmoMember.plokko.bodyColor)
            }
            .accessibilityLabel("切换晴朗大调与微酸小调")

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
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(vm.capturePipeline.isRecording ? palette.tensionFilament : palette.melodyTerracotta)
                )
                .foregroundStyle(palette.isNight && !vm.capturePipeline.isRecording ? Color(hex: 0x1B2245) : .white)
                .scaleEffect(vm.capturePipeline.isRecording ? 1.0 + CGFloat(vm.capturePipeline.inputLevel) * 0.08 : 1.0)
            }
            .accessibilityLabel(vm.capturePipeline.isRecording ? "结束哼唱并凝结成音珠" : "开始轻哼捕捉脑海旋律")

            Spacer()

            // 4. 和弦光带模板快捷菜单
            Menu {
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
                Divider()
                Button {
                    vm.slowMotion.toggle()
                } label: {
                    Label(vm.slowMotion ? "恢复原速 (1.0×)" : "慢镜拆解 (0.55×)", systemImage: "tortoise")
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title3)
                    Text("光带")
                        .font(.caption2.weight(.medium))
                }
                .frame(width: 52, height: 48)
                .foregroundStyle(vm.chordPreset == .off ? palette.secondaryInk : palette.harmonyWash)
            }
            .accessibilityLabel("切换和弦光带进行或慢速播放")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}
