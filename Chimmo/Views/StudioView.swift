import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum ChimmoTab: Int, Hashable, Sendable {
    case workbench = 0
    case philosophy = 1
    case notebook = 2
}

@MainActor
public final class StudioViewModel: ObservableObject {
    @Published public var document: MelodyDocument = SpecimenLibrary.saintSaensTheSwan
    @Published public var appearance: AppearancePreference = .auto
    @Published public var cognitiveLens: CognitiveLens = .philosophy
    @Published public var melodyVoice: MelodyVoice = .singingCello
    @Published public var accompanimentTexture: AccompanimentTexture = .swanRipple
    @Published public var chordPreset: ChordProgressionPreset = .autoMatch
    @Published public var chordOverrides: [Int: DiatonicChord] = [:]
    @Published public var shadowCounterpointEnabled: Bool = false
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
    @Published public var visitedInstallations: Set<Int>

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

    public var shadowNotes: [CounterpointNote] {
        CounterpointShadowEngine.generateShadowVoice(document: document, spans: chordSpans)
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
        let visited = UserDefaults.standard.array(forKey: "chimmo_visited_philosophy") as? [Int] ?? []
        self.visitedInstallations = Set(visited)
    }

    // MARK: - 5-Sky Modal Spectrum & Motif Origami Growth

    public func setScaleMode(_ mode: ScaleMode) {
        guard document.scaleMode != mode else { return }
        pushUndo()
        document.scaleMode = mode
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.55)
        playSingleNoteWithChord(degree: 3, octaveOffset: 0, atTime: 0.2, xNorm: 0.45)
        showToast("\(mode.label)：\(mode.skyPhilosophy)")
    }

    /// 3 音种子折纸生长（把脑海里短短几颗音，按巴赫/圣桑分形哲学一键长成完整乐章！）
    public func applyMotifGrowth(_ operation: MotifGrowthOperation) {
        stopPlayback()
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "种子折纸乐章"
            currentSavedEntryID = nil
        }
        document.notes = MotifOrigamiEngine.grow(notes: document.notes, operation: operation)
        selectedBeadID = nil
        AcousticHapticsEngine.shared.playSeedBloom()
        showToast("\(operation.label)：\(operation.philosophyNote)")
        togglePlayback()
    }

    /// 接收「先敲心跳 · 再抹坡度」零门槛捕手生成的脑放旋律
    public func commitCapturedMelody(beads: [NoteBead], mode: ScaleMode? = nil, titlePrefix: String = "敲拍脑放") {
        stopPlayback()
        guard !beads.isEmpty else { return }
        pushUndo()
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        if chordPreset == .off { chordPreset = .autoMatch }
        document = MelodyDocument(
            title: "\(titlePrefix) #\(notebook.entries.count + 1)",
            subtitle: "试试底部「种子生长」或切换「歌唱大提琴 / 天鹅水波」",
            rootMIDI: 60,
            scaleMode: mode ?? document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: beads,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        AcousticHapticsEngine.shared.playResolutionExhale()
        showToast("已为你记下 \(beads.count) 颗脑放音珠！试着点「四句成诗」让它绽放")
        togglePlayback()
    }

    // MARK: - Direct Tactile Ladder & Canvas Editing

    public func triggerLadderMember(_ member: ChimmoMember, octaveOffset: Int = 0) {
        stopPlayback()
        if member.isTensionDegree {
            AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.48)
        } else {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: member.degree == 1)
        }

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

        if document.notes.count >= 22 {
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
        AcousticHapticsEngine.shared.playBeatTap(isStrong: degree == 1)

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
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        previewBead(document.notes[idx])
        showToast(delta > 0 ? "音珠呼吸已拉长" : "音珠已变短促")
    }

    public func deleteSelectedBead() {
        guard let targetID = selectedBeadID else { return }
        pushUndo()
        document.notes.removeAll { $0.id == targetID }
        selectedBeadID = nil
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        showToast("已删去该音珠")
    }

    public func cycleSpanChord(spanIndex: Int) {
        let spans = chordSpans
        guard let currentSpan = spans.first(where: { $0.id == spanIndex }) else { return }
        let next = currentSpan.chord.nextChord()
        chordOverrides[spanIndex] = next
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.52)
        synth.playDiatonicChord(
            rootMIDI: document.rootMIDI,
            mode: document.scaleMode,
            chord: next,
            texture: accompanimentTexture,
            spanDuration: max(1.0, currentSpan.endTime - currentSpan.startTime),
            intensity: 0.88
        )
        showToast("第 \(spanIndex + 1) 小节脚下光影已换为 \(next.roman)（\(next.moodTitle)）")
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
        showToast("左手伴奏织体：\(texture.label)")
    }

    public func setMelodyVoice(_ voice: MelodyVoice) {
        melodyVoice = voice
        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: 3, octaveOffset: 0)
        synth.playNote(frequency: hz, velocity: 0.62, decay: 1.6, timbre: FeltPianoSynth.Timbre.from(voice: voice))
        showToast("主旋律乐器：\(voice.label)")
    }

    public func toggleShadowCounterpoint() {
        shadowCounterpointEnabled.toggle()
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.5)
        showToast(
            shadowCounterpointEnabled
                ? "👥 已召唤影子对位：当你停在长音喘息时，另一个灵魂在留白里轻声接唱"
                : "已关闭影子对位"
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
            subtitle: "点左侧阶梯、敲拍画坡，或按住「轻哼捉珠」",
            rootMIDI: 60,
            scaleMode: preferredMode ?? document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        lastFreeNoteTime = nil
        impulses.removeAll()
        showToast("空白声学画卷已铺好（当前：\(melodyVoice.label) + \(accompanimentTexture.label)）")
    }

    public func openSpecimen(_ specimen: MelodyDocument) {
        stopPlayback()
        pushUndo()
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        chordPreset = .autoMatch
        accompanimentTexture = specimen.preferredTexture ?? .swanRipple
        melodyVoice = specimen.preferredVoice ?? .concertPiano
        document = specimen
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
        melodyVoice = entry.document.preferredVoice ?? .concertPiano
        togglePlayback()
    }

    public func saveCurrentToNotebook() {
        guard !document.notes.isEmpty else {
            showToast("先哼一句、敲拍画坡或点几颗音珠，再存入乐思本吧")
            return
        }
        var docToSave = document
        if docToSave.isSpecimen || docToSave.title == "新脑放草图" || docToSave.title == "指尖即兴" || docToSave.title == "种子折纸乐章" {
            docToSave.title = "脑放记录 #\(notebook.entries.count + 1)"
        }
        docToSave.isSpecimen = false
        docToSave.preferredTexture = accompanimentTexture
        docToSave.preferredVoice = melodyVoice

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
        AcousticHapticsEngine.shared.playResolutionExhale()
        showToast("已存入「我的脑放」：\(saved.document.title)")
    }

    // MARK: - Bead & Ghost Editing

    public func applyGhost(beadID: UUID, ghost: GhostCandidate) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        pushUndo()
        document.notes[idx].degree = ghost.degree
        document.notes[idx].octaveOffset = ghost.octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        selectedBeadID = beadID
        AcousticHapticsEngine.shared.playResolutionExhale()
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
        if ChimmoMember.from(degree: degree).isTensionDegree {
            AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.45)
        } else {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: degree == 1)
        }
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
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        capturePipeline.startRecording()
    }

    public func finishHumCapture() {
        Task {
            if let snapped = await capturePipeline.stopAndTranscribe(preferredMode: nil), !snapped.notes.isEmpty {
                commitCapturedMelody(beads: snapped.notes, mode: snapped.mode, titlePrefix: "轻哼脑放")
            } else if !capturePipeline.statusMessage.isEmpty {
                showToast(capturePipeline.statusMessage)
            }
        }
    }

    // MARK: - Looping Chamber Ensemble Sequencer (Melody + Texture + Shadow Counterpoint)

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
                let shadows = self.shadowNotes

                let startDate = Date()
                var nextNoteIdx = 0
                var nextShadowIdx = 0
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
                            intensity: 0.80
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

                    if self.shadowCounterpointEnabled {
                        while nextShadowIdx < shadows.count && shadows[nextShadowIdx].onset <= elapsed {
                            let sh = shadows[nextShadowIdx]
                            let hz = self.document.scaleMode.frequencyHz(
                                rootMIDI: self.document.rootMIDI,
                                degree: sh.degree,
                                octaveOffset: sh.octaveOffset
                            )
                            self.synth.playNote(
                                frequency: hz,
                                velocity: 0.30,
                                decay: max(0.85, (sh.duration / speed) * 1.35),
                                brightness: 0.9,
                                timbre: self.melodyVoice == .singingCello ? .celesta : .liquidHarp
                            )
                            nextShadowIdx += 1
                        }
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
            subtitle: "点左侧阶梯、敲拍画坡，或用「种子生长」展开成诗",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
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
        let expressiveVel = min(0.72, 0.56 + (bead.octaveOffset > 0 ? 0.08 : 0.0) + (durationSec > 0.9 ? 0.05 : 0.0))
        synth.playNote(
            frequency: hz,
            velocity: expressiveVel,
            decay: max(1.05, durationSec * 1.48),
            brightness: 0.96,
            timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice)
        )

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
        synth.playNote(
            frequency: hz,
            velocity: 0.62,
            decay: 1.65,
            brightness: 0.96,
            timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice)
        )

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
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            if !Task.isCancelled {
                self?.statusToast = nil
            }
        }
    }
}

/// 咩哞 0.4 主入口：活体声学创作台 · 6 座感官哲学体验馆 · 28 首公版名曲与脑放乐思本
public struct StudioView: View {
    @StateObject private var vm = StudioViewModel()
    @Environment(\.colorScheme) private var systemScheme
    @State private var selectedTab: ChimmoTab = .workbench
    @State private var showDecoupledCapture = false
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

            PhilosophyPavilionView(
                palette: palette,
                synth: vm.synth,
                visitedInstallations: $vm.visitedInstallations,
                onSendOrigamiToWorkbench: { beads, mode in
                    vm.commitCapturedMelody(beads: beads, mode: mode, titlePrefix: "折纸乐章")
                    selectedTab = .workbench
                },
                onOpenSwanInWorkbench: {
                    vm.openSpecimen(SpecimenLibrary.saintSaensTheSwan)
                    selectedTab = .workbench
                },
                onOpenDecoupledCapture: {
                    selectedTab = .workbench
                    showDecoupledCapture = true
                }
            )
            .tabItem {
                Label("哲学馆", systemImage: "atom")
            }
            .tag(ChimmoTab.philosophy)

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

    // MARK: - Tab 1: Living Acoustic Workbench

    private var workbenchTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topSkyAndLensHeader

                HarmonicLadderCanvas(
                    document: vm.document,
                    chordSpans: vm.chordSpans,
                    shadowNotes: vm.shadowNotes,
                    shadowEnabled: vm.shadowCounterpointEnabled,
                    cognitiveLens: vm.cognitiveLens,
                    palette: palette,
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

                if !vm.document.isSpecimen && !vm.document.notes.isEmpty {
                    motifOrigamiQuickStrip
                }

                workbenchControlDock
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle(vm.document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if vm.canUndo {
                        Button {
                            vm.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .accessibilityLabel("撤销")
                    }

                    Button {
                        vm.toggleShadowCounterpoint()
                    } label: {
                        Image(systemName: vm.shadowCounterpointEnabled ? "person.2.wave.2.fill" : "person.2.wave.2")
                            .foregroundStyle(vm.shadowCounterpointEnabled ? palette.harmonyWash : palette.secondaryInk)
                    }
                    .accessibilityLabel(vm.shadowCounterpointEnabled ? "关闭巴赫影子对位副旋律" : "召唤巴赫影子对位副旋律")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        vm.saveCurrentToNotebook()
                    } label: {
                        Image(systemName: vm.currentSavedEntryID != nil ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel("保存当前旋律到我的脑放")

                    Button {
                        vm.startBlankCanvas()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建空白脑放画卷")

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
            .sheet(isPresented: $showDecoupledCapture) {
                RhythmContourCaptureSheet(
                    palette: palette,
                    scaleMode: vm.document.scaleMode,
                    voice: vm.melodyVoice,
                    texture: vm.accompanimentTexture,
                    synth: vm.synth,
                    onCommitMelody: { beads, _ in
                        vm.commitCapturedMelody(beads: beads, titlePrefix: "敲拍脑放")
                    }
                )
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

    private var topSkyAndLensHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(CognitiveLens.allCases) { lens in
                        let sel = vm.cognitiveLens == lens
                        Button {
                            vm.cognitiveLens = lens
                            AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: lens.iconName)
                                    .font(.system(size: 9.5, weight: .bold))
                                Text(lens.shortLabel)
                                    .font(.system(size: 10, weight: sel ? .bold : .medium))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(sel ? palette.homeAnchor : .clear))
                            .foregroundStyle(sel ? (palette.isNight ? Color(hex: 0x0E1726) : .white) : palette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Capsule().fill(palette.shelfSurface))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(ScaleMode.allCases) { sky in
                            let sel = vm.document.scaleMode == sky
                            let tint = sky.skyAuroraColor(isNight: palette.isNight)
                            Button {
                                vm.setScaleMode(sky)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: sky.iconName)
                                        .font(.system(size: 9.5))
                                    Text(sky.shortSkyLabel)
                                        .font(.system(size: 10, weight: sel ? .bold : .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4.5)
                                .background(Capsule().fill(sel ? tint : palette.shelfSurface))
                                .foregroundStyle(sel ? .white : palette.primaryInk)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Text(vm.statusToast ?? vm.currentInsight.headline)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.primaryInk)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.cardSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private var motifOrigamiQuickStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Text("🌱 种子生长")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(palette.homeAnchor)

                ForEach(MotifGrowthOperation.allCases) { op in
                    Button {
                        vm.applyMotifGrowth(op)
                    } label: {
                        Label(op.label, systemImage: op.iconName)
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(palette.cardSurface.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private var workbenchControlDock: some View {
        HStack(spacing: 8) {
            Button {
                vm.togglePlayback()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(vm.isPlaying ? "暂停" : "试听")
                        .font(.caption2.weight(.semibold))
                }
                .frame(width: 48, height: 48)
                .foregroundStyle(palette.homeAnchor)
            }
            .accessibilityLabel(vm.isPlaying ? "暂停试听" : "循环试听当前室内乐")

            Button {
                vm.stopPlayback()
                showDecoupledCapture = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title3)
                    Text("敲拍画坡")
                        .font(.caption2.weight(.semibold))
                }
                .frame(width: 56, height: 48)
                .foregroundStyle(palette.bassRibbon)
            }
            .accessibilityLabel("无需唱歌，先敲心跳再抹坡度记录脑放旋律")

            Spacer()

            Button {
                if vm.capturePipeline.isRecording {
                    vm.finishHumCapture()
                } else {
                    vm.startHumCapture()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.capturePipeline.isRecording ? "stop.fill" : "waveform")
                        .font(.headline)
                    Text(vm.capturePipeline.isRecording ? "唱完了" : "轻哼捉珠")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(vm.capturePipeline.isRecording ? palette.tensionFilament : palette.melodyTerracotta)
                )
                .foregroundStyle(.white)
                .scaleEffect(vm.capturePipeline.isRecording ? 1.0 + CGFloat(vm.capturePipeline.inputLevel) * 0.08 : 1.0)
            }
            .accessibilityLabel(vm.capturePipeline.isRecording ? "结束哼唱并凝结成音珠" : "开始轻哼捕捉脑海旋律")

            Spacer()

            Menu {
                Section("主旋律乐器") {
                    ForEach(MelodyVoice.allCases) { v in
                        Button {
                            vm.setMelodyVoice(v)
                        } label: {
                            if vm.melodyVoice == v {
                                Label(v.label, systemImage: "checkmark")
                            } else {
                                Label(v.label, systemImage: v.iconName)
                            }
                        }
                    }
                }
                Section("左手伴奏织体") {
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
                Section("和弦光带与对位") {
                    Button {
                        vm.toggleShadowCounterpoint()
                    } label: {
                        Label(
                            vm.shadowCounterpointEnabled ? "关闭影子对位副旋律" : "召唤影子对位副旋律",
                            systemImage: vm.shadowCounterpointEnabled ? "checkmark.circle.fill" : "person.2.wave.2"
                        )
                    }
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
                    Image(systemName: vm.melodyVoice.iconName)
                        .font(.title3)
                    Text("声音")
                        .font(.caption2.weight(.semibold))
                }
                .frame(width: 48, height: 48)
                .foregroundStyle(palette.harmonyWash)
            }
            .accessibilityLabel("切换歌唱大提琴等主奏乐器、左手伴奏织体与影子对位")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.cardSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}
