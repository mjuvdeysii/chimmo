import QuartzCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum StudioSpace: String, CaseIterable, Identifiable, Sendable {
    case showcase
    case create
    public var id: String { rawValue }
}

public enum ChimmoTab: Int, Hashable, CaseIterable, Sendable {
    case showcase = 0   // 聆听
    case create = 1     // 创作
    case songbook = 2   // 曲本
    case settings = 3   // 工坊

    public static let board: ChimmoTab = .showcase
    public static let musicBox: ChimmoTab = .songbook
}

public struct StageRippleEvent: Sendable {
    public let birthMediaTime: Double
    public let laneIndex: Int
    public let degree: Int
    public let onset: Double
    public let colorHex: UInt32
    public let isShadow: Bool
    public let intensity: Double
}

/// 零视图重绘的高频涟漪总线（Canvas 直接按 `CACurrentMediaTime()` 读取，不触发 SwiftUI 视图树重排）。
@MainActor
public final class StageRippleBus {
    public private(set) var events: [StageRippleEvent] = []
    public private(set) var lastLanePulseTime: [Int: Double] = [:]
    public private(set) var lastShadowEvent: StageRippleEvent? = nil

    public init() {}

    public func emit(
        laneIndex: Int,
        degree: Int,
        onset: Double,
        colorHex: UInt32,
        isShadow: Bool = false,
        intensity: Double = 0.65,
        at mediaTime: Double = CACurrentMediaTime()
    ) {
        events.removeAll { mediaTime - $0.birthMediaTime > 0.95 }
        let ev = StageRippleEvent(
            birthMediaTime: mediaTime,
            laneIndex: laneIndex,
            degree: degree,
            onset: onset,
            colorHex: colorHex,
            isShadow: isShadow,
            intensity: max(0.30, min(1.0, intensity))
        )
        events.append(ev)
        if isShadow {
            lastShadowEvent = ev
        } else {
            lastLanePulseTime[laneIndex] = mediaTime
        }
    }

    public func hasRecentRipples(at mediaTime: Double = CACurrentMediaTime()) -> Bool {
        events.contains { mediaTime - $0.birthMediaTime <= 0.95 }
    }

    public func activeEvents(at mediaTime: Double) -> [StageRippleEvent] {
        events.filter {
            let age = mediaTime - $0.birthMediaTime
            return age >= 0 && age <= 0.95
        }
    }
}

@MainActor
public final class StudioViewModel: ObservableObject {
    private static let appearancePrefKey = "chimmo.pref.appearance"
    private static let visualModePrefKey = "chimmo.pref.visualMode"
    private static let musicHapticsPrefKey = "chimmo.pref.musicHaptics"

    @Published public var document: MelodyDocument = SpecimenLibrary.saintSaensTheSwan
    @Published public var appearance: AppearancePreference = .auto {
        didSet {
            preferences?.set(appearance.rawValue, forKey: Self.appearancePrefKey)
        }
    }
    @Published public var visualMode: StageVisualMode = .flowingRiver {
        didSet {
            preferences?.set(visualMode.rawValue, forKey: Self.visualModePrefKey)
        }
    }
    @Published public var melodyVoice: MelodyVoice = .singingCello
    @Published public var accompanimentTexture: AccompanimentTexture = .swanRipple
    @Published public var chordPreset: ChordProgressionPreset = .autoMatch
    @Published public var chordOverrides: [Int: DiatonicChord] = [:]
    @Published public var pentatonicSafe: Bool = false
    @Published public var shadowCounterpointEnabled: Bool = false
    @Published public var musicHapticsEnabled: Bool = true {
        didSet {
            preferences?.set(musicHapticsEnabled, forKey: Self.musicHapticsPrefKey)
        }
    }
    @Published public var playbackRate: Double = 1.0
    @Published public var followGlowActive: Bool = false
    @Published public var followGlowIndex: Int = 0
    @Published public var smartHintActive: Bool = false
    @Published public var isTappingRhythm: Bool = false
    @Published public var requestOpenDreamSheet: Bool = false
    @Published public var liveTapTimestamps: [TimeInterval] = []
    @Published public var isPlaying: Bool = false
    @Published public var playheadTime: Double? = nil
    @Published public var activeDegrees: Set<Int> = []
    @Published public var activeLaneIndices: Set<Int> = []
    @Published public var sympatheticLaneIndices: Set<Int> = []
    @Published public var latestDegree: Int? = 1
    @Published public var selectedBeadID: UUID? = nil
    @Published public var impulses: [VisualImpulse] = []
    @Published public var statusToast: String? = nil
    @Published public var canUndo: Bool = false
    @Published public var currentSavedEntryID: UUID? = nil
    @Published public var lastSavedPulse: Int = 0
    @Published public var activeVibratoLane: Int? = nil
    @Published public var activeSpace: StudioSpace = .showcase
    @Published public var hasUnsavedCreationChanges: Bool = false

    @Published public var activeChordSpanID: Int = 0
    @Published public var activeGuidedMoment: GuidedStoryMoment? = SpecimenLibrary.saintSaensTheSwan.guidedMoments?.first
    @Published public var activeHarmonyPhysics: HarmonicRatioDescriptor = HarmonicRatioPhysics.analyze(
        melodyDegree: 1,
        rootDegree: 1,
        mode: .brightMajor
    )

    public let synth: FeltPianoSynth
    public let capturePipeline: HumCapturePipeline
    public let notebook: MelodyNotebookStore
    public let clock = PlaybackClock()
    public let rippleBus = StageRippleBus()

    private struct WorkspaceSnapshot {
        var document: MelodyDocument
        var chordPreset: ChordProgressionPreset
        var chordOverrides: [Int: DiatonicChord]
        var accompanimentTexture: AccompanimentTexture
        var melodyVoice: MelodyVoice
        var pentatonicSafe: Bool
        var shadowCounterpointEnabled: Bool
        var playbackRate: Double
        var selectedBeadID: UUID?
        var currentSavedEntryID: UUID?
        var undoStack: [MelodyDocument]
        var activeGuidedMoment: GuidedStoryMoment?
        var hasUnsavedChanges: Bool
    }

    private let router = HalfDuplexAudioRouter()
    private let preferences: UserDefaults?
    private var undoStack: [MelodyDocument] = []
    private var showcaseSnapshot: WorkspaceSnapshot?
    private var creationSnapshot: WorkspaceSnapshot?
    private var playbackTask: Task<Void, Never>?
    private var contextEchoTask: Task<Void, Never>?
    private var previewArpeggioTask: Task<Void, Never>?
    private var lastFreeNoteTime: Date?
    private var toastTask: Task<Void, Never>?
    private var lastScrubTime: Double? = nil
    private var lastSympatheticTriggerMediaTime: Double = 0

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

    /// 当前伴奏和弦对应的 3 个调内共鸣音级（供底部琴键底部显示柔和白金微光，零文字和声引导）
    public var activeChordToneDegrees: Set<Int> {
        guard cradleEnabled && !followGlowActive else { return [] }
        let spans = chordSpans
        let current = spans.first(where: { $0.id == activeChordSpanID }) ?? spans.first
        guard let span = current else { return [] }
        return Set(span.chord.chordToneDegrees)
    }

    public var shadowNotes: [CounterpointNote] {
        CounterpointShadowEngine.generateShadowVoice(document: document, spans: chordSpans)
    }

    public func toggleShadowCounterpoint() {
        shadowCounterpointEnabled.toggle()
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.45)
    }

    public func toggleMusicHaptics() {
        musicHapticsEnabled.toggle()
        if musicHapticsEnabled {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        }
    }

    public func triggerNewCreationFromShelf() {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        requestOpenDreamSheet = true
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    private func captureWorkspaceSnapshot() -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            melodyVoice: melodyVoice,
            pentatonicSafe: pentatonicSafe,
            shadowCounterpointEnabled: shadowCounterpointEnabled,
            playbackRate: playbackRate,
            selectedBeadID: selectedBeadID,
            currentSavedEntryID: currentSavedEntryID,
            undoStack: undoStack,
            activeGuidedMoment: activeGuidedMoment,
            hasUnsavedChanges: hasUnsavedCreationChanges
        )
    }

    private func restoreWorkspaceSnapshot(_ snap: WorkspaceSnapshot) {
        document = snap.document
        chordPreset = snap.chordPreset
        chordOverrides = snap.chordOverrides
        accompanimentTexture = snap.accompanimentTexture
        melodyVoice = snap.melodyVoice
        pentatonicSafe = snap.pentatonicSafe
        shadowCounterpointEnabled = snap.shadowCounterpointEnabled
        playbackRate = snap.playbackRate
        selectedBeadID = snap.selectedBeadID
        currentSavedEntryID = snap.currentSavedEntryID
        undoStack = snap.undoStack
        canUndo = !undoStack.isEmpty
        activeGuidedMoment = snap.activeGuidedMoment
        hasUnsavedCreationChanges = snap.hasUnsavedChanges
        clock.updateTotalDuration(document.totalDuration)
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: document.scaleMode))
        activeChordSpanID = 0
        if let first = document.notes.first {
            let t = first.displayOnset(grooveStrength: document.grooveStrength)
            updateHarmonyDescriptor(for: first.degree, at: t)
        }
    }

    public func switchSpace(to target: StudioSpace) {
        guard target != activeSpace else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        smartHintActive = false
        isTappingRhythm = false

        switch activeSpace {
        case .showcase:
            showcaseSnapshot = captureWorkspaceSnapshot()
        case .create:
            creationSnapshot = captureWorkspaceSnapshot()
        }

        activeSpace = target
        switch target {
        case .showcase:
            if let snap = showcaseSnapshot {
                restoreWorkspaceSnapshot(snap)
            } else {
                openSpecimen(SpecimenLibrary.saintSaensTheSwan, autoPlay: false)
            }
        case .create:
            if let snap = creationSnapshot {
                restoreWorkspaceSnapshot(snap)
            } else {
                let defaultDoc = MelodyDocument(
                    title: "我的旋律 #\(notebook.entries.count + 1)",
                    subtitle: "自由创作",
                    rootMIDI: 60,
                    scaleMode: .brightMajor,
                    harmonyProfile: .feltSun,
                    grooveStrength: 0.0,
                    notes: [],
                    isSpecimen: false,
                    preferredTexture: accompanimentTexture,
                    preferredVoice: melodyVoice
                )
                restoreWorkspaceSnapshot(
                    WorkspaceSnapshot(
                        document: defaultDoc,
                        chordPreset: .autoMatch,
                        chordOverrides: [:],
                        accompanimentTexture: accompanimentTexture,
                        melodyVoice: melodyVoice,
                        pentatonicSafe: true,
                        shadowCounterpointEnabled: false,
                        playbackRate: 1.0,
                        selectedBeadID: nil,
                        currentSavedEntryID: nil,
                        undoStack: [],
                        activeGuidedMoment: nil,
                        hasUnsavedChanges: false
                    )
                )
            }
        }
    }

    public func forkCurrentShowcaseIntoCreate() {
        stopPlayback()
        contextEchoTask?.cancel()
        if activeSpace == .showcase {
            showcaseSnapshot = captureWorkspaceSnapshot()
        }

        let clonedNotes = document.notes.map {
            NoteBead(
                degree: $0.degree,
                octaveOffset: $0.octaveOffset,
                rawOnset: $0.rawOnset,
                rawDuration: $0.rawDuration
            )
        }
        let clonedDoc = MelodyDocument(
            title: "\(document.title) · 改编",
            subtitle: "改编自经典曲目",
            rootMIDI: document.rootMIDI,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: document.grooveStrength,
            notes: clonedNotes,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        let createSnap = WorkspaceSnapshot(
            document: clonedDoc,
            chordPreset: chordPreset == .off ? .autoMatch : chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            melodyVoice: melodyVoice,
            pentatonicSafe: !XylophoneRollEngine.requiresSevenScale(clonedDoc),
            shadowCounterpointEnabled: shadowCounterpointEnabled,
            playbackRate: playbackRate,
            selectedBeadID: nil,
            currentSavedEntryID: nil,
            undoStack: [],
            activeGuidedMoment: nil,
            hasUnsavedChanges: !clonedNotes.isEmpty
        )
        creationSnapshot = createSnap
        activeSpace = .create
        followGlowActive = false
        smartHintActive = false
        isTappingRhythm = false
        restoreWorkspaceSnapshot(createSnap)
        AcousticHapticsEngine.shared.playSeedBloom()
    }

    public func auditionShowcaseLane(
        _ lane: XylophoneLane,
        touchIntensity: Double = 0.60,
        touchBrightness: Double = 0.96
    ) {
        if followGlowActive {
            strikeXylophoneLane(lane, touchIntensity: touchIntensity, touchBrightness: touchBrightness)
            return
        }
        if selectedBeadID != nil {
            selectedBeadID = nil
        }
        strikeXylophoneLane(lane, touchIntensity: touchIntensity, touchBrightness: touchBrightness)
    }

    public func appendOrReplaceNoteFromCreateKey(
        _ lane: XylophoneLane,
        touchIntensity: Double = 0.62,
        touchBrightness: Double = 0.96
    ) {
        if followGlowActive {
            strikeXylophoneLane(lane, touchIntensity: touchIntensity, touchBrightness: touchBrightness)
            return
        }
        if selectedBeadID != nil {
            strikeXylophoneLane(lane, touchIntensity: touchIntensity, touchBrightness: touchBrightness)
        } else {
            triggerLadderMember(lane.member, octaveOffset: lane.octaveOffset)
            selectedBeadID = nil
        }
        markCreationDirtyIfNeeded()
    }

    public func plantCreationStarter(_ seed: CreationStarterSeed) {
        stopPlayback()
        contextEchoTask?.cancel()
        pushUndo()
        followGlowActive = false
        followGlowIndex = 0
        smartHintActive = false
        isTappingRhythm = false
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        if chordPreset == .off { chordPreset = .autoMatch }

        let starterDoc = MelodyDocument(
            title: "\(seed.titlePrefix) #\(notebook.entries.count + 1)",
            subtitle: "点音符或琴键继续续写",
            rootMIDI: document.rootMIDI,
            scaleMode: seed.recommendedScaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: seed.notes,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        document = starterDoc
        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(starterDoc)
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: starterDoc.scaleMode))
        clock.updateTotalDuration(starterDoc.totalDuration)
        selectedBeadID = nil
        activeGuidedMoment = nil
        hasUnsavedCreationChanges = true
        if activeSpace == .create {
            creationSnapshot = captureWorkspaceSnapshot()
        }
        AcousticHapticsEngine.shared.playSeedBloom()
        togglePlayback()
    }

    public func jumpToGuidedMoment(_ moment: GuidedStoryMoment, autoPlay: Bool = true) {
        if isPlaying {
            stopPlayback()
        }
        contextEchoTask?.cancel()
        followGlowActive = false
        activeGuidedMoment = moment

        let total = document.totalDuration
        let safeFrac = moment.timeFraction.isFinite ? max(0.0, min(1.0, moment.timeFraction)) : 0.0
        let targetTime = max(0.0, min(total, total * safeFrac))
        clock.updateTotalDuration(total)
        clock.setScrubTime(targetTime)
        updateContextMetrics(at: targetTime)
        AcousticHapticsEngine.shared.playScrubTick()

        if autoPlay && !document.notes.isEmpty {
            togglePlayback()
        }
    }

    public func stepGuidedMoment(delta: Int) {
        guard delta != 0,
              let nav = StorybookGuidedMomentKinematics.chapterNavigation(for: activeGuidedMoment, in: document) else {
            return
        }
        let target = delta < 0 ? nav.previousMoment : nav.nextMoment
        guard let target else {
            AcousticHapticsEngine.shared.playScrubTick()
            return
        }
        jumpToGuidedMoment(target, autoPlay: true)
    }

    public func auditionCurrentCreation() {
        if isPlaying {
            stopPlayback()
            return
        }
        guard !document.notes.isEmpty else {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
            return
        }
        selectedBeadID = nil
        clock.setScrubTime(0.0)
        togglePlayback()
    }

    public func auditionDuoCharacter(_ character: ChimmoDuoCharacter) {
        synth.ensureRunning()
        previewArpeggioTask?.cancel()
        let mode = document.scaleMode
        let rootMIDI = document.rootMIDI
        switch character {
        case .mie:
            let timbre = FeltPianoSynth.Timbre.from(voice: melodyVoice)
            let hzLow = mode.frequencyHz(rootMIDI: rootMIDI, degree: 5, octaveOffset: 0)
            let hzHigh = mode.frequencyHz(rootMIDI: rootMIDI, degree: 1, octaveOffset: 1)
            AcousticHapticsEngine.shared.playPitchTouch(laneIndex: 4, isHome: false, isTension: false)
            synth.playNote(frequency: hzLow, velocity: 0.56, decay: 0.85, brightness: 0.98, timbre: timbre, pan: -0.14)
            previewArpeggioTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 95_000_000)
                guard let self, !Task.isCancelled else { return }
                self.synth.playNote(frequency: hzHigh, velocity: 0.64, decay: 1.25, brightness: 1.04, timbre: timbre, pan: 0.16)
            }
        case .mou:
            let bassHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: 1, octaveOffset: -1)
            AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
            synth.playNote(frequency: bassHz, velocity: 0.56, decay: 1.25, brightness: 0.86, timbre: .warmBass, pan: -0.10)
            synth.playDiatonicChord(
                rootMIDI: rootMIDI,
                mode: mode,
                chord: .I,
                texture: accompanimentTexture,
                spanDuration: 1.15,
                intensity: 0.72
            )
        }
    }

    public func auditionDuoGreeting() {
        synth.ensureRunning()
        previewArpeggioTask?.cancel()
        let mode = document.scaleMode
        let rootMIDI = document.rootMIDI
        let sheepHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: 5, octaveOffset: 0)
        let cowHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: 1, octaveOffset: -1)
        let sheepTimbre = FeltPianoSynth.Timbre.from(voice: melodyVoice)
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.42)
        synth.playNote(frequency: sheepHz, velocity: 0.48, decay: 0.90, brightness: 0.96, timbre: sheepTimbre, pan: -0.16)
        previewArpeggioTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard let self, !Task.isCancelled else { return }
            self.synth.playNote(frequency: cowHz, velocity: 0.50, decay: 1.25, brightness: 0.86, timbre: .warmBass, pan: 0.16)
        }
    }

    public func plantDuoStarterMotif() {
        stopPlayback()
        contextEchoTask?.cancel()
        pushUndo()
        followGlowActive = false
        smartHintActive = false
        isTappingRhythm = false
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        pentatonicSafe = true
        if chordPreset == .off { chordPreset = .autoMatch }

        let starterNotes = [
            NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.16, rawDuration: 0.42),
            NoteBead(degree: 3, octaveOffset: 0, rawOnset: 0.62, rawDuration: 0.42),
            NoteBead(degree: 5, octaveOffset: 0, rawOnset: 1.08, rawDuration: 0.56),
            NoteBead(degree: 6, octaveOffset: 0, rawOnset: 1.70, rawDuration: 0.42),
            NoteBead(degree: 5, octaveOffset: 0, rawOnset: 2.18, rawDuration: 0.88)
        ]
        document = MelodyDocument(
            title: "咩哞灵感 #\(notebook.entries.count + 1)",
            subtitle: "点音符或彩条微调",
            rootMIDI: document.rootMIDI,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: starterNotes,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = document.notes.first?.id
        activeGuidedMoment = nil
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playSeedBloom()
        togglePlayback()
    }

    public func auditionChimmoMember(_ member: ChimmoMember) {
        synth.ensureRunning()
        let laneIdx = max(0, min(6, member.degree - 1))
        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: member.degree, octaveOffset: 0)
        let pan = SympatheticResonanceMapper.keyBenchPan(
            laneIndex: laneIdx,
            stereoSpread: synth.currentSpaceProfile().stereoSpread
        )
        synth.playNote(
            frequency: hz,
            velocity: 0.60,
            decay: 1.15,
            brightness: 0.96,
            timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice),
            pan: pan
        )
        AcousticHapticsEngine.shared.playPitchTouch(
            laneIndex: laneIdx,
            isHome: member.degree == 1,
            isTension: member.isTensionDegree
        )
    }

    public func previewHumReference(degree: Int) {
        let safeDeg = max(1, min(7, degree))
        synth.ensureRunning()
        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: safeDeg, octaveOffset: 0)
        let laneIdx = XylophoneLane.laneIndex(degree: safeDeg, octaveOffset: 0)
        let lane = XylophoneLane.lane(at: laneIdx)
        AcousticHapticsEngine.shared.playPitchTouch(
            laneIndex: laneIdx,
            isHome: safeDeg == 1,
            isTension: lane.member.isTensionDegree
        )
        synth.playNote(
            frequency: hz,
            velocity: 0.56,
            decay: 1.25,
            brightness: 0.94,
            timbre: .liquidHarp,
            pan: safeDeg == 1 ? -0.10 : 0.10
        )
    }

    public func setPlaybackRate(_ rate: Double) {
        let clamped = max(0.5, min(1.6, rate))
        playbackRate = clamped
        clock.setRate(clamped)
        AcousticHapticsEngine.shared.playScrubTick()

        if !isPlaying {
            synth.ensureRunning()
            previewArpeggioTask?.cancel()
            let gapSec = max(0.24, min(0.70, 0.42 / clamped))
            let mode = document.scaleMode
            let rootMIDI = document.rootMIDI
            let voice = FeltPianoSynth.Timbre.from(voice: melodyVoice)
            let h1 = mode.frequencyHz(rootMIDI: rootMIDI, degree: 1, octaveOffset: 0)
            let h5 = mode.frequencyHz(rootMIDI: rootMIDI, degree: 5, octaveOffset: 0)
            synth.playNote(frequency: h1, velocity: 0.44, decay: 0.72, timbre: voice, pan: -0.14)
            previewArpeggioTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(gapSec * 1_000_000_000))
                guard let self, !Task.isCancelled, !self.isPlaying else { return }
                AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
                self.synth.playNote(frequency: h5, velocity: 0.50, decay: 0.90, timbre: voice, pan: 0.14)
            }
        }
    }

    public var smartHints: [SmartPitchHint] {
        guard smartHintActive,
              let selID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == selID }) else {
            return []
        }
        return XylophoneRollEngine.suggestThreeLanes(
            forBeatIndex: idx,
            in: document.notes,
            pentatonicSafe: pentatonicSafe
        )
    }

    public init(notebookStore: MelodyNotebookStore? = nil, preferences: UserDefaults? = nil) {
        self.preferences = preferences
        if let prefs = preferences {
            if let rawApp = prefs.string(forKey: Self.appearancePrefKey),
               let parsed = AppearancePreference(rawValue: rawApp) {
                self.appearance = parsed
            }
            if let rawMode = prefs.string(forKey: Self.visualModePrefKey),
               let parsed = StageVisualMode(rawValue: rawMode) {
                self.visualMode = parsed
            }
            if prefs.object(forKey: Self.musicHapticsPrefKey) != nil {
                self.musicHapticsEnabled = prefs.bool(forKey: Self.musicHapticsPrefKey)
            }
        }
        let s = FeltPianoSynth(router: router)
        self.synth = s
        self.capturePipeline = HumCapturePipeline(router: router, synth: s)
        self.notebook = notebookStore ?? MelodyNotebookStore()
        self.pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(SpecimenLibrary.saintSaensTheSwan)
        self.clock.updateTotalDuration(SpecimenLibrary.saintSaensTheSwan.totalDuration)
        s.applySpaceProfile(AcousticSpaceProfile.profile(for: SpecimenLibrary.saintSaensTheSwan.scaleMode))
    }

    // MARK: - Manual Hand-Crank / Vinyl Scrubbing

    public func scrubToTime(_ targetTime: Double, triggerNotes: Bool = true) {
        if isPlaying {
            stopPlayback()
        }
        contextEchoTask?.cancel()
        let total = max(0.5, document.totalDuration)
        let clamped = max(0.0, min(total, targetTime))
        clock.updateTotalDuration(total)
        clock.setScrubTime(clamped)

        if let prev = lastScrubTime, triggerNotes {
            let sorted = document.notes.sorted {
                $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
            }
            for bead in sorted {
                let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
                let crossedForward = (prev <= onset && clamped > onset)
                let crossedBackward = (prev >= onset && clamped < onset)
                let wrapped = abs(clamped - prev) > total * 0.5
                if !wrapped && (crossedForward || crossedBackward) {
                    triggerScrubBead(bead, at: onset)
                }
            }
        }
        lastScrubTime = clamped
        updateContextMetrics(at: clamped)
    }

    public func endScrubbing() {
        lastScrubTime = nil
    }

    private func triggerScrubBead(_ bead: NoteBead, at onset: Double) {
        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
        let lane = XylophoneLane.lane(at: laneIdx)
        rippleBus.emit(laneIndex: laneIdx, degree: bead.degree, onset: onset, colorHex: lane.member.bodyHex)
        flashLane(laneIdx, degree: bead.degree, holdSeconds: 0.24)
        let hz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: bead.degree,
            octaveOffset: bead.octaveOffset
        )
        synth.playNote(
            frequency: hz,
            velocity: 0.56,
            decay: max(0.75, bead.displayDuration(grooveStrength: document.grooveStrength) * 1.15),
            timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice)
        )
        AcousticHapticsEngine.shared.playScrubTick()
        updateHarmonyDescriptor(for: bead.degree, at: onset)
    }

    // MARK: - Inline Rhythm Drum & 1-Finger Hill Sketch

    public func startRhythmTap() {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        smartHintActive = false
        selectedBeadID = nil
        liveTapTimestamps.removeAll()
        isTappingRhythm = true
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
    }

    public func recordRhythmDrumTap() {
        synth.ensureRunning()
        let now = Date().timeIntervalSinceReferenceDate
        if liveTapTimestamps.count >= 16 {
            liveTapTimestamps.removeFirst()
        }
        liveTapTimestamps.append(now)
        let tapIdx = max(0, liveTapTimestamps.count - 1)
        let voice = RhythmDrumAccentMapper.tapVoice(forTapIndex: tapIdx)
        AcousticHapticsEngine.shared.playBeatTap(isStrong: voice.isDownbeat)
        let hz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: voice.degree,
            octaveOffset: 0
        )
        synth.playNote(
            frequency: hz,
            velocity: voice.velocity,
            decay: voice.isDownbeat ? 0.56 : 0.38,
            timbre: .liquidHarp,
            pan: voice.pan
        )
    }

    public func resetRhythmTaps() {
        liveTapTimestamps.removeAll()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public func cancelRhythmTap() {
        isTappingRhythm = false
        liveTapTimestamps.removeAll()
    }

    public func commitRhythmTaps(withDrawnHeights heights: [Double]? = nil) {
        stopPlayback()
        isTappingRhythm = false
        pushUndo()
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        if chordPreset == .off { chordPreset = .autoMatch }

        let rawNotes: [NoteBead]
        if liveTapTimestamps.count < 2 {
            let defaults: [Double] = [0.15, 0.62, 1.08, 1.65, 2.20, 2.82]
            rawNotes = defaults.enumerated().map { idx, t in
                let nextT = idx + 1 < defaults.count ? defaults[idx + 1] : t + 0.72
                return NoteBead(degree: 3, rawOnset: t, rawDuration: max(0.30, (nextT - t) * 0.88))
            }
        } else {
            let t0 = liveTapTimestamps[0]
            var rels = liveTapTimestamps.map { max(0.0, $0 - t0) }
            if let last = rels.last, last > 8.0 {
                let scale = 7.6 / last
                rels = rels.map { $0 * scale }
            }
            rawNotes = rels.enumerated().map { idx, t in
                let nextT = idx + 1 < rels.count ? rels[idx + 1] : t + 0.68
                let dur = max(0.22, min(1.45, (nextT - t) * 0.90))
                return NoteBead(degree: 3, rawOnset: 0.14 + t, rawDuration: dur)
            }
        }
        liveTapTimestamps.removeAll()

        pentatonicSafe = true
        let shapedNotes: [NoteBead]
        if let drawn = heights, !drawn.isEmpty {
            shapedNotes = XylophoneRollEngine.applyRelativeContour(
                to: rawNotes,
                normalizedHeights: drawn,
                pentatonicSafe: true
            )
        } else {
            shapedNotes = XylophoneRollEngine.applyHill(.arch, to: rawNotes, pentatonicSafe: true)
        }

        document = MelodyDocument(
            title: "我的旋律 #\(notebook.entries.count + 1)",
            subtitle: "点音符或下方彩条可微调",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: shapedNotes,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = document.notes.first?.id
        smartHintActive = true
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playResolutionExhale()
        togglePlayback()
    }

    /// 单指画山坡塑形：把零基础用户一笔画出的高低曲线直接贴合到当前节奏拍子上（若画板为空，则自动生成 8 拍呼吸韵律）。
    public func applyDrawnHillContour(_ normalizedHeights: [Double]) {
        guard !normalizedHeights.isEmpty else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        isTappingRhythm = false
        pushUndo()

        let baseNotes: [NoteBead]
        if document.notes.isEmpty {
            let count = max(4, min(12, normalizedHeights.count))
            baseNotes = (0..<count).map { idx in
                let onset = 0.14 + Double(idx) * 0.46
                let dur = (idx == count - 1) ? 0.68 : 0.40
                return NoteBead(degree: 3, rawOnset: onset, rawDuration: dur)
            }
            pentatonicSafe = true
        } else {
            baseNotes = document.notes
        }

        let shaped = XylophoneRollEngine.applyRelativeContour(
            to: baseNotes,
            normalizedHeights: normalizedHeights,
            pentatonicSafe: pentatonicSafe
        )

        if document.isSpecimen || document.notes.isEmpty {
            currentSavedEntryID = nil
            chordOverrides.removeAll()
            document = MelodyDocument(
                title: "手绘旋律 #\(notebook.entries.count + 1)",
                subtitle: "手画线条生成的旋律",
                rootMIDI: document.isSpecimen ? 60 : document.rootMIDI,
                scaleMode: document.scaleMode,
                harmonyProfile: document.harmonyProfile,
                grooveStrength: 0.0,
                notes: shaped,
                isSpecimen: false,
                preferredTexture: accompanimentTexture,
                preferredVoice: melodyVoice
            )
        } else {
            document.notes = shaped
        }

        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = document.notes.first?.id
        smartHintActive = false
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playSeedBloom()
        togglePlayback()
    }

    // MARK: - Rainbow Touch Ribbon & Context Echo

    public func strikeXylophoneLane(
        _ lane: XylophoneLane,
        touchIntensity: Double = 0.60,
        touchBrightness: Double = 0.96
    ) {
        flashLane(lane.index, degree: lane.degree)
        let member = lane.member
        let vel = max(0.32, min(0.90, touchIntensity))
        let bright = max(0.55, min(1.25, touchBrightness))

        let onset = 0.0
        let spread = synth.currentSpaceProfile().stereoSpread
        let benchPan = SympatheticResonanceMapper.keyBenchPan(laneIndex: lane.index, stereoSpread: spread)
        let currentT = clock.currentTime() ?? 0.0
        if followGlowActive && followGlowIndex < document.notes.count {
            let target = document.notes[followGlowIndex]
            let targetLane = XylophoneLane.laneIndex(degree: target.degree, octaveOffset: target.octaveOffset)
            let beadOnset = target.displayOnset(grooveStrength: document.grooveStrength)

            if lane.index == targetLane {
                let hz = document.scaleMode.frequencyHz(
                    rootMIDI: document.rootMIDI,
                    degree: target.degree,
                    octaveOffset: target.octaveOffset
                )
                synth.playNote(
                    frequency: hz,
                    velocity: min(0.92, vel + 0.05),
                    decay: max(1.1, target.rawDuration * 1.55),
                    brightness: bright,
                    timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice),
                    pan: benchPan
                )
                if let ch = TheoryLensEngine.chord(at: beadOnset, in: chordSpans) {
                    synth.playDiatonicChord(
                        rootMIDI: document.rootMIDI,
                        mode: document.scaleMode,
                        chord: ch,
                        texture: accompanimentTexture,
                        spanDuration: 1.35,
                        intensity: 0.62
                    )
                }
                rippleBus.emit(laneIndex: lane.index, degree: target.degree, onset: beadOnset, colorHex: member.bodyHex, intensity: vel)
                updateHarmonyDescriptor(for: target.degree, at: beadOnset)
                AcousticHapticsEngine.shared.playConsonantGlow(intensity: Float(max(0.42, min(0.88, vel))))

                followGlowIndex += 1
                if followGlowIndex >= document.notes.count {
                    AcousticHapticsEngine.shared.playResolutionExhale()
                    followGlowIndex = 0
                    if let first = document.notes.first {
                        clock.setScrubTime(first.displayOnset(grooveStrength: document.grooveStrength))
                    }
                } else {
                    let next = document.notes[followGlowIndex]
                    let nextOnset = next.displayOnset(grooveStrength: document.grooveStrength)
                    clock.setScrubTime(nextOnset)
                }
            } else {
                let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: lane.degree, octaveOffset: lane.octaveOffset)
                let softVel = max(0.32, vel * 0.78)
                synth.playNote(
                    frequency: hz,
                    velocity: softVel,
                    decay: 1.0,
                    brightness: bright,
                    timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice),
                    pan: benchPan
                )
                rippleBus.emit(laneIndex: lane.index, degree: lane.degree, onset: onset, colorHex: member.bodyHex, intensity: softVel)
                AcousticHapticsEngine.shared.playExpressivePitchTouch(
                    laneIndex: lane.index,
                    velocity: softVel,
                    isHome: lane.degree == 1,
                    isTension: member.isTensionDegree
                )
            }
            return
        }

        // 模式 2：正在调选中拍子的音高（立刻改高 + 自动「前后连听」！）
        if let selID = selectedBeadID,
           let idx = document.notes.firstIndex(where: { $0.id == selID }) {
            stopPlayback()
            pushUndo()
            if document.isSpecimen {
                document.isSpecimen = false
                document.title = "\(document.title) · 我的改写"
            }
            document.notes[idx].degree = lane.degree
            document.notes[idx].octaveOffset = lane.octaveOffset
            document.notes[idx].ghostCandidates.removeAll()
            hasUnsavedCreationChanges = true
            let noteOnset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
            rippleBus.emit(laneIndex: lane.index, degree: lane.degree, onset: noteOnset, colorHex: member.bodyHex, intensity: vel)
            AcousticHapticsEngine.shared.playExpressivePitchTouch(
                laneIndex: lane.index,
                velocity: vel,
                isHome: lane.degree == 1,
                isTension: member.isTensionDegree
            )
            updateContextMetrics(at: noteOnset)
            updateHarmonyDescriptor(for: lane.degree, at: noteOnset)
            playContextEcho(upToIndex: idx)
            return
        }

        // 模式 3：纯粹自由演奏（左右立体声琴席摆位 + 木质共鸣箱五度/八度微共鸣 + 涟漪与谐振）
        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: lane.degree, octaveOffset: lane.octaveOffset)
        let sym = SympatheticResonanceMapper.compute(
            laneIndex: lane.index,
            baseHz: hz,
            velocity: vel,
            stereoSpread: spread,
            pentatonicSafe: pentatonicSafe
        )
        synth.playNote(
            frequency: hz,
            velocity: vel,
            decay: 1.45,
            brightness: bright,
            timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice),
            pan: sym.keyPan
        )
        let mediaNow = CACurrentMediaTime()
        if sym.overtoneVelocity > 0.0 && (mediaNow - lastSympatheticTriggerMediaTime) >= 0.075 {
            lastSympatheticTriggerMediaTime = mediaNow
            synth.playNote(
                frequency: sym.overtoneHz,
                velocity: sym.overtoneVelocity,
                decay: 1.75,
                brightness: 0.62,
                timbre: .feltPiano,
                delaySeconds: 0.026,
                pan: sym.overtonePan
            )
            flashSympatheticLane(sym.sympatheticLaneIndex)
        }
        rippleBus.emit(laneIndex: lane.index, degree: lane.degree, onset: currentT, colorHex: member.bodyHex, intensity: vel)
        AcousticHapticsEngine.shared.playExpressivePitchTouch(
            laneIndex: lane.index,
            velocity: vel,
            isHome: lane.degree == 1,
            isTension: member.isTensionDegree
        )
        updateHarmonyDescriptor(for: lane.degree, at: currentT)
    }

    /// 星环模式按住星辰并轻微揉晃时开启实时微揉弦与主音泛音共鸣。
    public func beginOrUpdateStarVibrato(laneIndex: Int, dx: CGFloat, dy: CGFloat, hitRadius: CGFloat) {
        guard !followGlowActive else { return }
        let clampedLane = max(0, min(7, laneIndex))
        let lane = XylophoneLane.lane(at: clampedLane)
        if pentatonicSafe && !lane.isPentatonicSafe {
            return
        }
        let baseHz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: lane.degree,
            octaveOffset: lane.octaveOffset
        )
        let anchorHz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: 1,
            octaveOffset: 0
        )
        let vib = HarmonicVibratoMapper.vibratoState(
            dxFromStar: dx,
            dyFromStar: dy,
            radius: hitRadius,
            baseHz: baseHz,
            anchorHz: anchorHz
        )
        activeVibratoLane = clampedLane
        synth.setContinuousPair(hzA: vib.frequencyHz, hzB: vib.sympatheticHz, gain: vib.swellGain)
        if musicHapticsEnabled {
            AcousticHapticsEngine.shared.playVibratoShimmerTick(intensity: 0.45 + vib.swellGain)
        }
    }

    public func endStarVibrato() {
        if activeVibratoLane != nil {
            activeVibratoLane = nil
        }
        synth.stopContinuousPair()
    }

    /// 「前后连听」：调第 N 拍时把「前两拍 → 这一拍」连着唱一遍，人耳 0.2 秒就能听出高了还是低了！
    public func playContextEcho(upToIndex targetIdx: Int) {
        stopPlayback()
        contextEchoTask?.cancel()
        guard document.notes.indices.contains(targetIdx) else { return }

        let startIdx = max(0, targetIdx - 2)
        let slice = Array(document.notes[startIdx...targetIdx])
        let mode = document.scaleMode
        let rootMIDI = document.rootMIDI
        let voiceTimbre = FeltPianoSynth.Timbre.from(voice: melodyVoice)

        contextEchoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (offset, bead) in slice.enumerated() {
                if Task.isCancelled { return }
                let isTarget = (offset == slice.count - 1)
                let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: bead.degree, octaveOffset: bead.octaveOffset)
                let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                let lane = XylophoneLane.lane(at: laneIdx)
                let onset = bead.displayOnset(grooveStrength: self.document.grooveStrength)

                self.flashLane(laneIdx, degree: bead.degree)
                self.clock.setScrubTime(onset)
                self.rippleBus.emit(laneIndex: laneIdx, degree: bead.degree, onset: onset, colorHex: lane.member.bodyHex)
                self.updateHarmonyDescriptor(for: bead.degree, at: onset)

                let pan = AcousticSpatialPanMapper.pan(
                    forBeatOnset: onset,
                    totalDuration: self.document.totalDuration,
                    visualMode: self.visualMode
                )
                self.synth.playNote(
                    frequency: hz,
                    velocity: isTarget ? 0.68 : 0.44,
                    decay: isTarget ? 1.55 : 0.72,
                    timbre: voiceTimbre,
                    pan: pan
                )

                if !isTarget {
                    let next = slice[offset + 1]
                    let rawGap = next.rawOnset - bead.rawOnset
                    let crispGap = max(0.20, min(0.46, rawGap))
                    try? await Task.sleep(nanoseconds: UInt64(crispGap * 1_000_000_000))
                }
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            if !Task.isCancelled && !self.isPlaying && !self.followGlowActive {
                self.clock.setScrubTime(nil)
            }
        }
    }

    // MARK: - Hills, Smart Hints, Follow-the-Glow & Bead Edits

    public func applyHillTemplate(_ template: MelodyHillTemplate) {
        guard !document.notes.isEmpty else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 变奏"
        }
        document.notes = XylophoneRollEngine.applyHill(template, to: document.notes, pentatonicSafe: pentatonicSafe)
        clock.updateTotalDuration(document.totalDuration)
        if selectedBeadID == nil {
            selectedBeadID = document.notes.first?.id
        }
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playSeedBloom()
        togglePlayback()
    }

    /// 旋律折纸生长：把短短几颗音珠一键生长成起·承·转·合完整乐章（爬楼 / 倒影 / 延留迟到 / 四句成诗）。
    public func growCurrentWithOrigami(_ operation: MotifGrowthOperation) {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        isTappingRhythm = false
        pushUndo()

        let grown = MotifOrigamiEngine.grow(notes: document.notes, operation: operation)
        if document.isSpecimen || document.notes.isEmpty {
            currentSavedEntryID = nil
            chordOverrides.removeAll()
            document = MelodyDocument(
                title: "扩展旋律 · \(operation.label)",
                subtitle: operation.philosophyNote,
                rootMIDI: 60,
                scaleMode: document.scaleMode,
                harmonyProfile: document.harmonyProfile,
                grooveStrength: 0.0,
                notes: grown,
                isSpecimen: false,
                preferredTexture: accompanimentTexture,
                preferredVoice: melodyVoice
            )
        } else {
            document.notes = grown
        }

        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(document)
        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = document.notes.first?.id
        smartHintActive = false
        activeGuidedMoment = nil
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playSeedBloom()
        togglePlayback()
    }

    /// 名曲 3 颗火种微调重生：改掉前 3 颗火种音，即刻生出专属个人风格的大师变奏。
    public func applyMasterpieceSeedShifts(_ shifts: [Int]) {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        isTappingRhythm = false
        pushUndo()

        let baseDoc = document.notes.isEmpty ? SpecimenLibrary.saintSaensTheSwan : document
        let varied = MasterpieceOnionEngine.applySeedShifts(document: baseDoc, shifts: shifts)
        currentSavedEntryID = nil
        document = varied
        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(varied)
        clock.updateTotalDuration(varied.totalDuration)
        selectedBeadID = varied.notes.first?.id
        smartHintActive = false
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playResolutionExhale()
        togglePlayback()
    }

    /// 在「更多 · 变奏」调节开头三音高度柱时即点即响试听音高变化。
    public func previewSeedShift(index: Int, shift: Int) {
        guard index >= 0 && index < 3 else { return }
        synth.ensureRunning()
        let baseDoc = document.notes.isEmpty ? SpecimenLibrary.saintSaensTheSwan : document
        let defaultDegrees = [1, 3, 5]
        let (baseDeg, baseOct): (Int, Int) = baseDoc.notes.indices.contains(index)
            ? (baseDoc.notes[index].degree, baseDoc.notes[index].octaveOffset)
            : (defaultDegrees[index], 0)
        let linear = baseOct * 7 + (baseDeg - 1) + shift
        let clamped = max(-3, min(8, linear))
        let newOct = Int(floor(Double(clamped) / 7.0))
        let newDeg = max(1, min(7, clamped - newOct * 7 + 1))
        let safeOct = max(-1, min(1, newOct))
        let hz = baseDoc.scaleMode.frequencyHz(
            rootMIDI: baseDoc.rootMIDI,
            degree: newDeg,
            octaveOffset: safeOct
        )
        let laneIdx = XylophoneLane.laneIndex(degree: newDeg, octaveOffset: safeOct)
        let lane = XylophoneLane.lane(at: laneIdx)
        let pan = Double(index - 1) * 0.24
        synth.playNote(
            frequency: hz,
            velocity: 0.56,
            decay: 0.95,
            timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice),
            pan: pan
        )
        AcousticHapticsEngine.shared.playPitchTouch(
            laneIndex: laneIdx,
            isHome: newDeg == 1,
            isTension: lane.member.isTensionDegree
        )
    }

    /// 将「闭眼夜灯触觉剧场」录下的星珠序列贴到星盘并立刻旋转试听。
    public func applyNightLampPhrase(_ beads: [NoteBead], pentatonicSafe safe: Bool) {
        guard !beads.isEmpty else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        isTappingRhythm = false
        pushUndo()
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        if chordPreset == .off { chordPreset = .autoMatch }

        pentatonicSafe = safe
        document = MelodyDocument(
            title: "闭眼滑音 #\(notebook.entries.count + 1)",
            subtitle: "通过滑动震动录下的旋律",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: beads,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = document.notes.first?.id
        smartHintActive = false
        activeGuidedMoment = nil
        hasUnsavedCreationChanges = true
        AcousticHapticsEngine.shared.playResolutionExhale()
        togglePlayback()
    }

    /// 从任意名曲「借天光」：保留自己的旋律线条不变，披上大师名曲的天光调式、水波织体与主奏乐器。
    public func borrowHarmonyAtmosphere(from specimen: MelodyDocument) {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        isTappingRhythm = false

        if document.notes.isEmpty {
            openSpecimen(specimen, autoPlay: true)
            return
        }

        pushUndo()
        document.scaleMode = specimen.scaleMode
        document.harmonyProfile = specimen.harmonyProfile
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: specimen.scaleMode))
        if let tex = specimen.preferredTexture {
            accompanimentTexture = tex
            document.preferredTexture = tex
        } else {
            document.preferredTexture = accompanimentTexture
        }
        if let voice = specimen.preferredVoice {
            melodyVoice = voice
            document.preferredVoice = voice
        } else {
            document.preferredVoice = melodyVoice
        }
        chordPreset = .autoMatch
        chordOverrides.removeAll()

        if document.isSpecimen {
            document.isSpecimen = false
            currentSavedEntryID = nil
            if !document.title.contains("新风格") {
                document.title = "\(document.title) · 新风格"
            }
        }
        if activeSpace == .create || !document.isSpecimen {
            hasUnsavedCreationChanges = true
        }
        activeGuidedMoment = nil
        AcousticHapticsEngine.shared.playResolutionExhale()
        togglePlayback()
    }

    public func toggleSmartPitchHints() {
        smartHintActive.toggle()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        if smartHintActive && selectedBeadID == nil {
            selectedBeadID = document.notes.first?.id
        }
    }

    public func toggleFollowGlow() {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive.toggle()
        followGlowIndex = 0
        if followGlowActive {
            selectedBeadID = nil
            smartHintActive = false
            if let first = document.notes.first {
                clock.setScrubTime(first.displayOnset(grooveStrength: document.grooveStrength))
            }
            AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.6)
        } else {
            clock.setScrubTime(nil)
        }
    }

    public func togglePentatonicSafe() {
        pentatonicSafe.toggle()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public func selectBead(_ id: UUID, playContext: Bool = true) {
        selectedBeadID = id
        if let idx = document.notes.firstIndex(where: { $0.id == id }) {
            let bead = document.notes[idx]
            let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
            updateContextMetrics(at: onset)
            updateHarmonyDescriptor(for: bead.degree, at: onset)
            if playContext {
                playContextEcho(upToIndex: idx)
            }
        }
    }

    public var stageAccessibilitySummary: String {
        var parts: [String] = []
        if document.notes.isEmpty {
            parts.append("空白画布")
        } else {
            parts.append("\(document.title)，\(visualMode.rawValue)，\(document.notes.count) 个音")
        }
        if let selID = selectedBeadID,
           let idx = document.notes.firstIndex(where: { $0.id == selID }) {
            let bead = document.notes[idx]
            let lane = XylophoneLane.lane(at: XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset))
            let durText = String(format: "%.1f秒", bead.rawDuration)
            parts.append("第 \(idx + 1) 拍，\(lane.digitLabel) \(lane.solfege)，\(durText)")
            let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
            let spans = chordSpans
            if let spanIdx = spans.firstIndex(where: { onset >= $0.startTime && onset < $0.endTime }) {
                parts.append("第 \(spanIdx + 1)/\(spans.count) 句，\(spans[spanIdx].chord.moodTitle)")
            }
        }
        if isPlaying {
            parts.append("正在播放")
        }
        return parts.joined(separator: "，")
    }

    public func stepSelectedBeat(delta: Int) {
        guard !document.notes.isEmpty else { return }
        let cur = selectedBeadID.flatMap { id in document.notes.firstIndex { $0.id == id } } ?? 0
        let next = max(0, min(document.notes.count - 1, cur + delta))
        selectedBeadID = document.notes[next].id
        let onset = document.notes[next].displayOnset(grooveStrength: document.grooveStrength)
        updateContextMetrics(at: onset)
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        playContextEcho(upToIndex: next)
    }

    public func stepPhrase(delta: Int) {
        guard !document.notes.isEmpty else { return }
        let curIdx = selectedBeadID.flatMap { id in document.notes.firstIndex { $0.id == id } }
        guard let nextIdx = PhraseNavigationMapper.nextPhraseBeatIndex(
            notes: document.notes,
            spans: chordSpans,
            grooveStrength: document.grooveStrength,
            currentBeatIndex: curIdx,
            delta: delta
        ) else { return }
        let bead = document.notes[nextIdx]
        selectedBeadID = bead.id
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        updateContextMetrics(at: onset)
        updateHarmonyDescriptor(for: bead.degree, at: onset)
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        playContextEcho(upToIndex: nextIdx)
    }

    public func previewOpeningPhrase() {
        stopPlayback()
        contextEchoTask?.cancel()
        let count = PhraseNavigationMapper.openingPreviewCount(for: document.notes)
        guard count > 0 else {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
            return
        }
        let slice = Array(document.notes.prefix(count))
        let mode = document.scaleMode
        let rootMIDI = document.rootMIDI
        let groove = document.grooveStrength
        let voiceTimbre = FeltPianoSynth.Timbre.from(voice: melodyVoice)
        let spans = chordSpans
        let totalDur = document.totalDuration
        let cradle = cradleEnabled
        let texture = accompanimentTexture
        let visual = visualMode

        contextEchoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (idx, bead) in slice.enumerated() {
                if Task.isCancelled { return }
                let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: bead.degree, octaveOffset: bead.octaveOffset)
                let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                let lane = XylophoneLane.lane(at: laneIdx)
                let onset = bead.displayOnset(grooveStrength: groove)
                let dur = bead.displayDuration(grooveStrength: groove)

                self.flashLane(laneIdx, degree: bead.degree, holdSeconds: max(0.18, min(0.45, dur * 0.85)))
                self.clock.setScrubTime(onset)
                self.rippleBus.emit(laneIndex: laneIdx, degree: bead.degree, onset: onset, colorHex: lane.member.bodyHex)
                self.updateContextMetrics(at: onset)
                self.updateHarmonyDescriptor(for: bead.degree, at: onset)
                if self.musicHapticsEnabled {
                    AcousticHapticsEngine.shared.playPlaybackNotePulse(
                        laneIndex: laneIdx,
                        isHome: bead.degree == 1,
                        isTension: lane.member.isTensionDegree,
                        isDownbeat: idx == 0
                    )
                }

                let pan = AcousticSpatialPanMapper.pan(
                    forBeatOnset: onset,
                    totalDuration: totalDur,
                    visualMode: visual
                )
                self.synth.playNote(
                    frequency: hz,
                    velocity: idx == 0 ? 0.66 : 0.58,
                    decay: max(0.75, dur * 1.35),
                    timbre: voiceTimbre,
                    pan: pan
                )
                if idx == 0, cradle, let ch = TheoryLensEngine.chord(at: onset, in: spans) {
                    self.synth.playDiatonicChord(
                        rootMIDI: rootMIDI,
                        mode: mode,
                        chord: ch,
                        texture: texture,
                        spanDuration: 1.6,
                        intensity: 0.55
                    )
                }
                if idx + 1 < slice.count {
                    let nextOnset = slice[idx + 1].displayOnset(grooveStrength: groove)
                    let gap = max(0.22, min(0.75, nextOnset - onset))
                    try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
                }
            }
            try? await Task.sleep(nanoseconds: 550_000_000)
            if !Task.isCancelled && !self.isPlaying && !self.followGlowActive {
                self.clock.setScrubTime(nil)
            }
        }
    }

    public func shiftSelectedBeadPitch(delta: Int) {
        guard delta != 0, !document.notes.isEmpty else { return }
        if selectedBeadID == nil, let first = document.notes.first {
            selectedBeadID = first.id
            playContextEcho(upToIndex: 0)
            return
        }
        guard let selID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == selID }) else { return }
        let bead = document.notes[idx]
        let curLane = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
        let allowed = XylophoneLane.allowedIndices(pentatonicSafe: pentatonicSafe)
        guard !allowed.isEmpty else { return }
        let curPos = allowed.firstIndex(of: curLane)
            ?? allowed.enumerated().min(by: { abs($0.element - curLane) < abs($1.element - curLane) })?.offset
            ?? 0
        let nextPos = max(0, min(allowed.count - 1, curPos + delta))
        let nextLaneIdx = allowed[nextPos]
        guard nextLaneIdx != curLane else { return }

        beginBeadEdit()
        let lane = XylophoneLane.lane(at: nextLaneIdx)
        updateBeadToLane(beadID: bead.id, lane: lane, playSinglePreview: false)
        playContextEcho(upToIndex: idx)
        AcousticHapticsEngine.shared.playPitchTouch(
            laneIndex: lane.index,
            isHome: lane.degree == 1,
            isTension: lane.member.isTensionDegree
        )
    }

    public func beginBeadEdit() {
        pushUndo()
    }

    public func updateBeadToLane(beadID: UUID, lane: XylophoneLane, playSinglePreview: Bool) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        if document.notes[idx].degree == lane.degree && document.notes[idx].octaveOffset == lane.octaveOffset {
            return
        }
        stopPlayback()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 我的改写"
        }
        document.notes[idx].degree = lane.degree
        document.notes[idx].octaveOffset = lane.octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        hasUnsavedCreationChanges = true
        let onset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        flashLane(lane.index, degree: lane.degree)
        rippleBus.emit(laneIndex: lane.index, degree: lane.degree, onset: onset, colorHex: lane.member.bodyHex)
        updateHarmonyDescriptor(for: lane.degree, at: onset)
        if playSinglePreview {
            AcousticHapticsEngine.shared.playPitchTouch(laneIndex: lane.index, isHome: lane.degree == 1, isTension: lane.member.isTensionDegree)
            let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: lane.degree, octaveOffset: lane.octaveOffset)
            synth.playNote(frequency: hz, velocity: 0.56, decay: 0.85, timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice))
        }
    }

    public func updateBeatTiming(beadID: UUID, newOnset: Double) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        stopPlayback()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 我的改写"
        }
        let clampedOnset = max(0.08, newOnset.isFinite ? newOnset : 0.08)
        document.notes[idx].rawOnset = clampedOnset
        if document.notes[idx].quantizedOnset != nil {
            document.notes[idx].quantizedOnset = clampedOnset
        }
        document.notes.sort { $0.rawOnset < $1.rawOnset }
        hasUnsavedCreationChanges = true
        clock.updateTotalDuration(document.totalDuration)
        if let updated = document.notes.first(where: { $0.id == beadID }) {
            let displayT = updated.displayOnset(grooveStrength: document.grooveStrength)
            updateContextMetrics(at: displayT)
            updateHarmonyDescriptor(for: updated.degree, at: displayT)
        }
    }

    public func insertBeatAfterSelected() {
        stopPlayback()
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 我的改写"
        }
        if let selID = selectedBeadID,
           let idx = document.notes.firstIndex(where: { $0.id == selID }) {
            let cur = document.notes[idx]
            let nextOnset: Double
            if idx + 1 < document.notes.count {
                let gap = document.notes[idx + 1].rawOnset - cur.rawOnset
                if gap >= 0.34 {
                    nextOnset = cur.rawOnset + gap * 0.5
                } else {
                    for j in (idx + 1)..<document.notes.count {
                        document.notes[j].rawOnset += 0.42
                    }
                    nextOnset = cur.rawOnset + 0.42
                }
            } else {
                nextOnset = cur.rawOnset + max(0.45, cur.rawDuration)
            }
            let newBead = NoteBead(degree: cur.degree, octaveOffset: cur.octaveOffset, rawOnset: nextOnset, rawDuration: 0.42)
            document.notes.append(newBead)
            document.notes.sort { $0.rawOnset < $1.rawOnset }
            hasUnsavedCreationChanges = true
            clock.updateTotalDuration(document.totalDuration)
            selectedBeadID = newBead.id
            if let newIdx = document.notes.firstIndex(where: { $0.id == newBead.id }) {
                playContextEcho(upToIndex: newIdx)
            }
        } else {
            triggerLadderMember(.taono, octaveOffset: 0)
        }
    }

    // MARK: - Relative Hum Contour

    public func startHumCapture() {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        capturePipeline.startRecording()
    }

    public func cancelHumCapture() {
        capturePipeline.cancelRecording()
    }

    public func finishRelativeContourHum() {
        Task {
            if !document.notes.isEmpty {
                if let heights = await capturePipeline.stopAndExtractRelativeContour(slotCount: document.notes.count) {
                    pushUndo()
                    if document.isSpecimen {
                        document.isSpecimen = false
                        document.title = "我的旋律 #\(notebook.entries.count + 1)"
                    }
                    document.notes = XylophoneRollEngine.applyRelativeContour(
                        to: document.notes,
                        normalizedHeights: heights,
                        pentatonicSafe: pentatonicSafe
                    )
                    clock.updateTotalDuration(document.totalDuration)
                    selectedBeadID = document.notes.first?.id
                    hasUnsavedCreationChanges = true
                    AcousticHapticsEngine.shared.playResolutionExhale()
                    togglePlayback()
                } else if !capturePipeline.statusMessage.isEmpty {
                    showToast(capturePipeline.statusMessage)
                }
            } else {
                if let snapped = await capturePipeline.stopAndTranscribe(preferredMode: nil), !snapped.notes.isEmpty {
                    pushUndo()
                    currentSavedEntryID = nil
                    chordOverrides.removeAll()
                    document = MelodyDocument(
                        title: "哼唱旋律 #\(notebook.entries.count + 1)",
                        subtitle: "点画布上的音即可微调",
                        rootMIDI: 60,
                        scaleMode: snapped.mode,
                        harmonyProfile: document.harmonyProfile,
                        grooveStrength: 0.0,
                        notes: snapped.notes,
                        isSpecimen: false,
                        preferredTexture: accompanimentTexture,
                        preferredVoice: melodyVoice
                    )
                    clock.updateTotalDuration(document.totalDuration)
                    pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(document)
                    selectedBeadID = document.notes.first?.id
                    hasUnsavedCreationChanges = true
                    AcousticHapticsEngine.shared.playResolutionExhale()
                    togglePlayback()
                } else if !capturePipeline.statusMessage.isEmpty {
                    showToast(capturePipeline.statusMessage)
                }
            }
        }
    }

    // MARK: - Core Actions (Preserves 100% Unit-Test Compatibility)

    public func setScaleMode(_ mode: ScaleMode) {
        if document.scaleMode != mode {
            pushUndo()
            document.scaleMode = mode
            if activeSpace == .create && !document.notes.isEmpty {
                hasUnsavedCreationChanges = true
            }
        }
        synth.ensureRunning()
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: mode))
        previewArpeggioTask?.cancel()
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.5)

        let degrees = mode.signaturePreviewDegrees
        let rootMIDI = document.rootMIDI
        let timbre = FeltPianoSynth.Timbre.from(voice: melodyVoice)
        let shouldShimmer = cradleEnabled
        let tex = accompanimentTexture

        if shouldShimmer {
            synth.playDiatonicChord(
                rootMIDI: rootMIDI,
                mode: mode,
                chord: .I,
                texture: tex,
                spanDuration: 1.15,
                intensity: 0.52
            )
        }
        if let firstDeg = degrees.first {
            let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: firstDeg, octaveOffset: 0)
            synth.playNote(frequency: hz, velocity: 0.56, decay: 1.05, timbre: timbre)
        }
        let rest = Array(degrees.dropFirst())
        if !rest.isEmpty {
            previewArpeggioTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for (offset, deg) in rest.enumerated() {
                    try? await Task.sleep(nanoseconds: 105_000_000)
                    if Task.isCancelled { return }
                    let isLast = offset == rest.count - 1
                    let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: 0)
                    self.synth.playNote(
                        frequency: hz,
                        velocity: isLast ? 0.62 : 0.52,
                        decay: isLast ? 1.35 : 0.95,
                        timbre: timbre
                    )
                }
            }
        }
    }

    public func triggerLadderMember(_ member: ChimmoMember, octaveOffset: Int = 0) {
        stopPlayback()
        if member.isTensionDegree {
            AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.45)
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
        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = bead.id
        hasUnsavedCreationChanges = true

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
        let bead = NoteBead(degree: degree, octaveOffset: octaveOffset, rawOnset: clampedTime, rawDuration: 0.48)
        document.notes.append(bead)
        document.notes.sort { $0.rawOnset < $1.rawOnset }
        clock.updateTotalDuration(document.totalDuration)
        selectedBeadID = bead.id
        hasUnsavedCreationChanges = true

        if let idx = document.notes.firstIndex(where: { $0.id == bead.id }) {
            playContextEcho(upToIndex: idx)
        }
    }

    public func adjustSelectedBeadDuration(delta: Double) {
        guard delta.isFinite else { return }
        guard let targetID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == targetID }) else { return }
        stopPlayback()
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 我的改写"
        }
        let next = max(0.16, min(2.4, document.notes[idx].rawDuration + delta))
        document.notes[idx].rawDuration = next
        if document.notes[idx].quantizedDuration != nil {
            document.notes[idx].quantizedDuration = next
        }
        hasUnsavedCreationChanges = true
        clock.updateTotalDuration(document.totalDuration)
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        playContextEcho(upToIndex: idx)
    }

    public func nudgeSelectedBeadTiming(delta: Double) {
        guard let targetID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == targetID }) else { return }
        stopPlayback()
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 我的改写"
        }
        let nextOnset = BeatTimingNudgeHelper.nudgedOnset(
            notes: document.notes,
            targetIndex: idx,
            rawDelta: delta,
            grooveStrength: document.grooveStrength
        )
        document.notes[idx].rawOnset = nextOnset
        if document.notes[idx].quantizedOnset != nil {
            document.notes[idx].quantizedOnset = nextOnset
        }
        hasUnsavedCreationChanges = true
        clock.updateTotalDuration(document.totalDuration)
        let displayT = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        updateContextMetrics(at: displayT)
        updateHarmonyDescriptor(for: document.notes[idx].degree, at: displayT)
        AcousticHapticsEngine.shared.playScrubTick()
        playContextEcho(upToIndex: idx)
    }

    public func deleteSelectedBead() {
        guard let targetID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == targetID }) else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 我的改写"
        }
        document.notes.remove(at: idx)
        clock.updateTotalDuration(document.totalDuration)
        if document.notes.isEmpty {
            selectedBeadID = nil
            smartHintActive = false
            activeChordSpanID = 0
            hasUnsavedCreationChanges = false
        } else {
            selectedBeadID = document.notes[min(idx, document.notes.count - 1)].id
            hasUnsavedCreationChanges = true
        }
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public func cycleSpanChord(spanIndex: Int) {
        let spans = chordSpans
        guard let currentSpan = spans.first(where: { $0.id == spanIndex }) else { return }
        let next = currentSpan.chord.nextChord()
        chordOverrides[spanIndex] = next
        activeChordSpanID = spanIndex
        markCreationDirtyIfNeeded()
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.5)
        synth.playDiatonicChord(
            rootMIDI: document.rootMIDI,
            mode: document.scaleMode,
            chord: next,
            texture: accompanimentTexture,
            spanDuration: max(1.0, currentSpan.endTime - currentSpan.startTime),
            intensity: 0.85
        )
    }

    public func setChordPreset(_ preset: ChordProgressionPreset) {
        chordPreset = preset
        chordOverrides.removeAll()
        previewArpeggioTask?.cancel()
        markCreationDirtyIfNeeded()
        if preset == .off {
            AcousticHapticsEngine.shared.playScrubTick()
            return
        }
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.40)
        guard !isPlaying else { return }
        synth.ensureRunning()
        let spans = chordSpans
        let firstChord = spans.first?.chord ?? preset.sequence.first ?? .I
        let mode = document.scaleMode
        let rootMIDI = document.rootMIDI
        let tex = accompanimentTexture
        synth.playDiatonicChord(
            rootMIDI: rootMIDI,
            mode: mode,
            chord: firstChord,
            texture: tex,
            spanDuration: 1.0,
            intensity: 0.70
        )
        if let secondChord = spans.dropFirst().first?.chord ?? preset.sequence.dropFirst().first {
            previewArpeggioTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 340_000_000)
                guard let self, !Task.isCancelled, !self.isPlaying, self.chordPreset == preset else { return }
                self.synth.playDiatonicChord(
                    rootMIDI: rootMIDI,
                    mode: mode,
                    chord: secondChord,
                    texture: tex,
                    spanDuration: 1.1,
                    intensity: 0.68
                )
            }
        }
    }

    public func setAccompanimentTexture(_ texture: AccompanimentTexture) {
        synth.ensureRunning()
        accompanimentTexture = texture
        document.preferredTexture = texture
        if chordPreset == .off { chordPreset = .autoMatch }
        markCreationDirtyIfNeeded()
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.35)
        synth.playDiatonicChord(
            rootMIDI: document.rootMIDI,
            mode: document.scaleMode,
            chord: .I,
            texture: texture,
            spanDuration: 1.35,
            intensity: 0.78
        )
    }

    public func setMelodyVoice(_ voice: MelodyVoice) {
        synth.ensureRunning()
        melodyVoice = voice
        document.preferredVoice = voice
        markCreationDirtyIfNeeded()
        previewArpeggioTask?.cancel()
        let timbre = FeltPianoSynth.Timbre.from(voice: voice)
        let mode = document.scaleMode
        let rootMIDI = document.rootMIDI
        let hz1 = mode.frequencyHz(rootMIDI: rootMIDI, degree: 1, octaveOffset: 0)
        synth.playNote(frequency: hz1, velocity: 0.58, decay: 1.15, timbre: timbre)
        previewArpeggioTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard let self, !Task.isCancelled else { return }
            let hz5 = mode.frequencyHz(rootMIDI: rootMIDI, degree: 5, octaveOffset: 0)
            self.synth.playNote(frequency: hz5, velocity: 0.64, decay: 1.45, timbre: timbre)
        }
    }

    public func setRootMIDI(_ midi: Int) {
        let clamped = RootTranspositionHelper.clampedRootMIDI(midi)
        if document.rootMIDI != clamped {
            pushUndo()
            document.rootMIDI = clamped
            markCreationDirtyIfNeeded()
        }
        synth.ensureRunning()
        previewArpeggioTask?.cancel()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: clamped == 60)
        let timbre = FeltPianoSynth.Timbre.from(voice: melodyVoice)
        let mode = document.scaleMode
        let hz1 = mode.frequencyHz(rootMIDI: clamped, degree: 1, octaveOffset: 0)
        synth.playNote(frequency: hz1, velocity: 0.58, decay: 1.15, timbre: timbre, pan: -0.08)
        previewArpeggioTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 95_000_000)
            guard let self, !Task.isCancelled else { return }
            let hz5 = mode.frequencyHz(rootMIDI: clamped, degree: 5, octaveOffset: 0)
            self.synth.playNote(frequency: hz5, velocity: 0.62, decay: 1.35, timbre: timbre, pan: 0.10)
        }
    }

    public func setGrooveStrength(_ strength: Double) {
        let clamped = strength.isFinite ? max(0.0, min(1.0, strength)) : 0.0
        if abs(document.grooveStrength - clamped) > 0.001 {
            pushUndo()
            if activeSpace == .create && !document.notes.isEmpty {
                hasUnsavedCreationChanges = true
            }
        }
        if clamped > 0.01 {
            document.notes = GrooveAlignmentEngine.populateQuantizedTargets(for: document.notes)
        }
        document.grooveStrength = clamped
        clock.updateTotalDuration(document.totalDuration)
        AcousticHapticsEngine.shared.playScrubTick()
    }

    public func startBlankCanvas() {
        stopPlayback()
        contextEchoTask?.cancel()
        pushUndo()
        followGlowActive = false
        smartHintActive = false
        isTappingRhythm = false
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        pentatonicSafe = true
        if chordPreset == .off { chordPreset = .autoMatch }
        document = MelodyDocument(
            title: "我的旋律 #\(notebook.entries.count + 1)",
            subtitle: "自由创作",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        hasUnsavedCreationChanges = false
        clock.updateTotalDuration(document.totalDuration)
        activeGuidedMoment = nil
        lastFreeNoteTime = nil
        if activeSpace == .create {
            creationSnapshot = captureWorkspaceSnapshot()
        }
    }

    public func openSpecimen(_ specimen: MelodyDocument, autoPlay: Bool = true) {
        stopPlayback()
        contextEchoTask?.cancel()
        if activeSpace == .create {
            creationSnapshot = captureWorkspaceSnapshot()
            activeSpace = .showcase
        }
        pushUndo()
        followGlowActive = false
        followGlowIndex = 0
        smartHintActive = false
        isTappingRhythm = false
        currentSavedEntryID = nil
        selectedBeadID = specimen.notes.first?.id
        chordOverrides.removeAll()
        chordPreset = .autoMatch
        accompanimentTexture = specimen.preferredTexture ?? .swanRipple
        melodyVoice = specimen.preferredVoice ?? .concertPiano
        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(specimen)
        document = specimen
        hasUnsavedCreationChanges = false
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: specimen.scaleMode))
        clock.updateTotalDuration(specimen.totalDuration)
        activeGuidedMoment = specimen.guidedMoments?.first
        showcaseSnapshot = captureWorkspaceSnapshot()
        if autoPlay { togglePlayback() }
    }

    public func openSpecimenForFollowGlow(_ specimen: MelodyDocument) {
        openSpecimen(specimen, autoPlay: false)
        selectedBeadID = nil
        followGlowActive = true
        followGlowIndex = 0
        if let first = specimen.notes.first {
            clock.setScrubTime(first.displayOnset(grooveStrength: specimen.grooveStrength))
        }
        showcaseSnapshot = captureWorkspaceSnapshot()
    }

    public func openSavedEntry(_ entry: SavedMelodyEntry, autoPlay: Bool = true) {
        stopPlayback()
        contextEchoTask?.cancel()
        pushUndo()
        followGlowActive = false
        followGlowIndex = 0
        smartHintActive = false
        isTappingRhythm = false
        currentSavedEntryID = entry.id
        selectedBeadID = entry.document.notes.first?.id
        document = entry.document
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: entry.document.scaleMode))
        clock.updateTotalDuration(entry.document.totalDuration)
        chordPreset = entry.chordPreset
        chordOverrides = entry.chordOverrides
        accompanimentTexture = entry.accompanimentTexture ?? entry.document.preferredTexture ?? .swanRipple
        melodyVoice = entry.document.preferredVoice ?? .singingCello
        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(entry.document)
        activeGuidedMoment = nil
        hasUnsavedCreationChanges = false
        if activeSpace == .create {
            creationSnapshot = captureWorkspaceSnapshot()
        } else {
            showcaseSnapshot = captureWorkspaceSnapshot()
        }
        if autoPlay { togglePlayback() }
    }

    public func openSavedEntryInCreate(_ entry: SavedMelodyEntry, autoPlay: Bool = false) {
        if activeSpace == .showcase {
            showcaseSnapshot = captureWorkspaceSnapshot()
        }
        activeSpace = .create
        openSavedEntry(entry, autoPlay: autoPlay)
        selectedBeadID = nil
        creationSnapshot = captureWorkspaceSnapshot()
    }

    public func saveCurrentToNotebook(moodSticker: String? = nil) {
        guard !document.notes.isEmpty else {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
            return
        }
        var docToSave = document
        if docToSave.isSpecimen || docToSave.title == "空白画布" || docToSave.title == "即兴创作" || docToSave.title == "新脑放星盘" || docToSave.title == "指尖即兴" {
            docToSave.title = "我的作品 #\(notebook.entries.count + 1)"
        }
        docToSave.isSpecimen = false
        docToSave.preferredTexture = accompanimentTexture
        docToSave.preferredVoice = melodyVoice

        let saved = notebook.save(
            document: docToSave,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            moodSticker: moodSticker ?? (document.scaleMode.isMinorFlavored ? "抒情" : "我的作品"),
            summaryNote: currentInsight.headline,
            existingEntryID: currentSavedEntryID
        )
        currentSavedEntryID = saved.id
        document = saved.document
        hasUnsavedCreationChanges = false
        lastSavedPulse &+= 1
        if activeSpace == .create {
            creationSnapshot = captureWorkspaceSnapshot()
        }
        AcousticHapticsEngine.shared.playResolutionExhale()
        if !isPlaying {
            synth.ensureRunning()
            let mode = document.scaleMode
            let rootMIDI = document.rootMIDI
            let homeHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: 1, octaveOffset: 0)
            let fifthHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: 5, octaveOffset: 0)
            synth.playNote(
                frequency: homeHz,
                velocity: 0.36,
                decay: 0.85,
                brightness: 0.92,
                timbre: .liquidHarp,
                delaySeconds: 0.0,
                pan: -0.10
            )
            synth.playNote(
                frequency: fifthHz,
                velocity: 0.42,
                decay: 1.15,
                brightness: 0.96,
                timbre: .liquidHarp,
                delaySeconds: 0.075,
                pan: 0.10
            )
        }
    }

    public func renameCurrentSong(_ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            AcousticHapticsEngine.shared.playScrubTick()
            return
        }
        document.title = trimmed
        document.isSpecimen = false
        if let savedID = currentSavedEntryID {
            notebook.rename(id: savedID, newTitle: trimmed)
        } else if !document.notes.isEmpty {
            hasUnsavedCreationChanges = true
        }
        if activeSpace == .create {
            creationSnapshot = captureWorkspaceSnapshot()
        }
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public func renameSavedEntry(id: UUID, newTitle: String) {
        guard let updated = notebook.rename(id: id, newTitle: newTitle) else {
            AcousticHapticsEngine.shared.playScrubTick()
            return
        }
        if currentSavedEntryID == id {
            document.title = updated.document.title
        }
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public func duplicateSavedEntry(id: UUID) {
        if notebook.duplicate(id: id) != nil {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        }
    }

    public func deleteSavedEntry(id: UUID) {
        notebook.delete(id: id)
        if currentSavedEntryID == id {
            currentSavedEntryID = nil
        }
        AcousticHapticsEngine.shared.playScrubTick()
    }

    // MARK: - Playback Sequencer (Zero 60Hz SwiftUI Invalidation)

    public func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }
        guard !document.notes.isEmpty else {
            strikeXylophoneLane(XylophoneLane.allLanes[0])
            return
        }
        followGlowActive = false
        contextEchoTask?.cancel()
        synth.ensureRunning()

        let total = document.totalDuration
        let startOffset: Double
        if let scrub = clock.scrubTime, scrub < total - 0.15 {
            startOffset = scrub
        } else {
            startOffset = 0.0
        }

        clock.setRate(playbackRate)
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: document.scaleMode))
        clock.start(totalDuration: total, from: startOffset)
        isPlaying = true

        playbackTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let sorted = self.document.notes.sorted {
                $0.displayOnset(grooveStrength: self.document.grooveStrength) < $1.displayOnset(grooveStrength: self.document.grooveStrength)
            }
            let sortedShadows = CounterpointShadowEngine.generateShadowVoice(
                document: self.document,
                spans: self.chordSpans
            ).sorted { $0.onset < $1.onset }

            let totalDuration = self.document.totalDuration
            var nextNoteIdx = sorted.firstIndex(where: { $0.displayOnset(grooveStrength: self.document.grooveStrength) >= startOffset - 0.02 }) ?? sorted.count
            var nextShadowIdx = sortedShadows.firstIndex(where: { $0.onset >= startOffset - 0.02 }) ?? sortedShadows.count
            var lastTriggeredSpanID = -1
            var prevElapsed = startOffset

            while !Task.isCancelled && self.isPlaying {
                let elapsed = self.clock.currentTime() ?? 0.0

                // 检测自然循环跨过零点，无缝衔接下一圈音符
                if elapsed + 0.25 < prevElapsed {
                    nextNoteIdx = 0
                    nextShadowIdx = 0
                    lastTriggeredSpanID = -1
                }
                prevElapsed = elapsed

                let rateScale = 1.0 / max(0.5, self.playbackRate)
                let spans = self.chordSpans
                if let currentSpan = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }),
                   currentSpan.id != lastTriggeredSpanID {
                    lastTriggeredSpanID = currentSpan.id
                    if self.activeChordSpanID != currentSpan.id {
                        self.activeChordSpanID = currentSpan.id
                    }
                    self.synth.playDiatonicChord(
                        rootMIDI: self.document.rootMIDI,
                        mode: self.document.scaleMode,
                        chord: currentSpan.chord,
                        texture: self.accompanimentTexture,
                        spanDuration: (currentSpan.endTime - currentSpan.startTime) * rateScale,
                        intensity: 0.78
                    )
                    if self.musicHapticsEnabled {
                        AcousticHapticsEngine.shared.playChordShiftBreath()
                    }
                }

                if let nextMoment = self.document.activeGuidedMoment(at: elapsed),
                   nextMoment.id != self.activeGuidedMoment?.id {
                    self.activeGuidedMoment = nextMoment
                }

                while nextNoteIdx < sorted.count &&
                        sorted[nextNoteIdx].displayOnset(grooveStrength: self.document.grooveStrength) <= elapsed {
                    let bead = sorted[nextNoteIdx]
                    let onset = bead.displayOnset(grooveStrength: self.document.grooveStrength)
                    let dur = bead.displayDuration(grooveStrength: self.document.grooveStrength)
                    let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                    let lane = XylophoneLane.lane(at: laneIdx)

                    self.rippleBus.emit(
                        laneIndex: laneIdx,
                        degree: bead.degree,
                        onset: onset,
                        colorHex: lane.member.bodyHex
                    )
                    self.flashLane(laneIdx, degree: bead.degree, holdSeconds: max(0.16, min(0.45, dur * 0.85 * rateScale)))
                    self.updateHarmonyDescriptor(for: bead.degree, at: onset)

                    if self.musicHapticsEnabled {
                        let isDownbeat = (nextNoteIdx == 0) || (nextNoteIdx % 4 == 0)
                        AcousticHapticsEngine.shared.playPlaybackNotePulse(
                            laneIndex: laneIdx,
                            isHome: bead.degree == 1,
                            isTension: lane.member.isTensionDegree,
                            isDownbeat: isDownbeat
                        )
                    }

                    let hz = self.document.scaleMode.frequencyHz(
                        rootMIDI: self.document.rootMIDI,
                        degree: bead.degree,
                        octaveOffset: bead.octaveOffset
                    )
                    let pan = AcousticSpatialPanMapper.pan(
                        forBeatOnset: onset,
                        totalDuration: totalDuration,
                        visualMode: self.visualMode
                    )
                    self.synth.playNote(
                        frequency: hz,
                        velocity: 0.62,
                        decay: max(0.85, dur * 1.45 * rateScale),
                        brightness: 0.96,
                        timbre: FeltPianoSynth.Timbre.from(voice: self.melodyVoice),
                        pan: pan
                    )
                    nextNoteIdx += 1
                }

                while nextShadowIdx < sortedShadows.count && sortedShadows[nextShadowIdx].onset <= elapsed {
                    let shadow = sortedShadows[nextShadowIdx]
                    nextShadowIdx += 1
                    guard self.shadowCounterpointEnabled else { continue }
                    let sLaneIdx = XylophoneLane.laneIndex(degree: shadow.degree, octaveOffset: shadow.octaveOffset)
                    self.rippleBus.emit(
                        laneIndex: sLaneIdx,
                        degree: shadow.degree,
                        onset: shadow.onset,
                        colorHex: 0x7EC8E3,
                        isShadow: true
                    )
                    let sHz = self.document.scaleMode.frequencyHz(
                        rootMIDI: self.document.rootMIDI,
                        degree: shadow.degree,
                        octaveOffset: shadow.octaveOffset
                    )
                    let sPan = -AcousticSpatialPanMapper.pan(
                        forBeatOnset: shadow.onset,
                        totalDuration: totalDuration,
                        visualMode: self.visualMode
                    ) * 0.65
                    let duetTimbre: FeltPianoSynth.Timbre = (self.melodyVoice == .liquidHarp) ? .celesta : .liquidHarp
                    self.synth.playNote(
                        frequency: sHz,
                        velocity: 0.36,
                        decay: max(0.85, shadow.duration * rateScale * 1.35),
                        brightness: 0.85,
                        timbre: duetTimbre,
                        pan: sPan
                    )
                }

                // 25ms 调度步进：高节拍精度且不向 SwiftUI 广播逐帧重排
                try? await Task.sleep(nanoseconds: 25_000_000)
                if Task.isCancelled || !self.isPlaying { break }
                if elapsed >= totalDuration && nextNoteIdx >= sorted.count {
                    // 等待 clock 自然走完呼吸尾隙并自动回零进入下一圈
                    continue
                }
            }
        }
    }

    public func stopPlayback() {
        previewArpeggioTask?.cancel()
        previewArpeggioTask = nil
        endStarVibrato()
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        clock.stop()
        playheadTime = nil
        activeDegrees.removeAll()
        activeLaneIndices.removeAll()
        sympatheticLaneIndices.removeAll()
    }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        document = prev
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: prev.scaleMode))
        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(prev)
        clock.updateTotalDuration(prev.totalDuration)
        selectedBeadID = document.notes.first?.id
        canUndo = !undoStack.isEmpty
        if activeSpace == .create {
            hasUnsavedCreationChanges = !document.notes.isEmpty
            creationSnapshot = captureWorkspaceSnapshot()
        }
        AcousticHapticsEngine.shared.playScrubTick()
        if let first = document.notes.first {
            let onset = first.displayOnset(grooveStrength: document.grooveStrength)
            updateContextMetrics(at: onset)
            updateHarmonyDescriptor(for: first.degree, at: onset)
        } else {
            activeChordSpanID = 0
        }
    }

    // MARK: - Internals

    private func markCreationDirtyIfNeeded() {
        guard activeSpace == .create else { return }
        if !document.notes.isEmpty {
            hasUnsavedCreationChanges = true
        }
        creationSnapshot = captureWorkspaceSnapshot()
    }

    private func updateContextMetrics(at time: Double) {
        if let sp = chordSpans.first(where: { time >= $0.startTime && time < $0.endTime }),
           sp.id != activeChordSpanID {
            activeChordSpanID = sp.id
        }
        if let m = document.activeGuidedMoment(at: time), m.id != activeGuidedMoment?.id {
            activeGuidedMoment = m
        }
    }

    private func updateHarmonyDescriptor(for degree: Int, at time: Double) {
        let rootDeg = TheoryLensEngine.chord(at: time, in: chordSpans)?.rootDegree ?? 1
        let desc = HarmonicRatioPhysics.analyze(melodyDegree: degree, rootDegree: rootDeg, mode: document.scaleMode)
        if desc != activeHarmonyPhysics {
            activeHarmonyPhysics = desc
        }
    }

    private func forkIntoFreeDraft() {
        pushUndo()
        currentSavedEntryID = nil
        selectedBeadID = nil
        chordOverrides.removeAll()
        document = MelodyDocument(
            title: "即兴创作",
            subtitle: "自由写旋律",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        clock.updateTotalDuration(document.totalDuration)
        activeGuidedMoment = nil
        lastFreeNoteTime = nil
    }

    private func pushUndo() {
        undoStack.append(document)
        if undoStack.count > 25 { undoStack.removeFirst() }
        canUndo = true
    }

    private func flashLane(_ laneIdx: Int, degree: Int, holdSeconds: Double = 0.28) {
        if latestDegree != degree {
            latestDegree = degree
        }
        activeDegrees.insert(degree)
        activeLaneIndices.insert(laneIdx)
        let holdNs = UInt64(holdSeconds * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: holdNs)
            self?.activeDegrees.remove(degree)
            self?.activeLaneIndices.remove(laneIdx)
        }
    }

    private func flashSympatheticLane(_ laneIdx: Int, holdSeconds: Double = 0.24) {
        sympatheticLaneIndices.insert(laneIdx)
        let holdNs = UInt64(holdSeconds * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: holdNs)
            self?.sympatheticLaneIndices.remove(laneIdx)
        }
    }

    private func playSingleNoteWithChord(degree: Int, octaveOffset: Int, atTime: Double, xNorm: Double) {
        let laneIdx = XylophoneLane.laneIndex(degree: degree, octaveOffset: octaveOffset)
        let lane = XylophoneLane.lane(at: laneIdx)
        flashLane(laneIdx, degree: degree)
        rippleBus.emit(laneIndex: laneIdx, degree: degree, onset: atTime, colorHex: lane.member.bodyHex)
        updateHarmonyDescriptor(for: degree, at: atTime)

        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: degree, octaveOffset: octaveOffset)
        synth.playNote(frequency: hz, velocity: 0.62, decay: 1.5, timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice))
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

/// 咩哞：四标签纯血叙事工坊架构（「聆听」绘本舞台 / 「创作」自由工坊 / 「曲本」离线乐谱库 / 「工坊」声学与外观设定）。
public struct StudioView: View {
    @StateObject private var vm = StudioViewModel(preferences: .standard)
    @Environment(\.colorScheme) private var systemScheme

    @State private var selectedTab: ChimmoTab = .showcase
    @State private var showAbout: Bool = false
    @State private var postcardTarget: VinylPostcardRequest? = nil
    @State private var deferredPostcardTask: Task<Void, Never>? = nil

    public init() {}

    private var isNight: Bool {
        switch vm.appearance {
        case .auto: return systemScheme == .dark
        case .daylight: return false
        case .nightLamp: return true
        }
    }

    private var palette: ChimmoPalette { ChimmoPalette(isNight: isNight) }

    private func makePostcardRequest(headline: String? = nil) -> VinylPostcardRequest {
        VinylPostcardRequest(
            document: vm.document,
            chordPreset: vm.chordPreset,
            chordOverrides: vm.chordOverrides,
            accompanimentTexture: vm.accompanimentTexture,
            melodyVoice: vm.melodyVoice,
            shadowEnabled: vm.shadowCounterpointEnabled,
            playbackRate: vm.playbackRate,
            headline: headline ?? vm.currentInsight.headline,
            visualMode: vm.visualMode
        )
    }

    private func makePostcardRequest(for entry: SavedMelodyEntry) -> VinylPostcardRequest {
        VinylPostcardRequest(
            document: entry.document,
            chordPreset: entry.chordPreset,
            chordOverrides: entry.chordOverrides,
            accompanimentTexture: entry.accompanimentTexture ?? entry.document.preferredTexture ?? .swanRipple,
            melodyVoice: entry.document.preferredVoice,
            shadowEnabled: false,
            playbackRate: 1.0,
            headline: entry.summaryNote.isEmpty ? nil : entry.summaryNote,
            visualMode: vm.visualMode
        )
    }

    private func presentPostcardAfterSheetDismiss(_ req: VinylPostcardRequest) {
        deferredPostcardTask?.cancel()
        deferredPostcardTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 320_000_000)
            if !Task.isCancelled {
                postcardTarget = req
            }
        }
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: ChimmoTab.showcase) {
                OrbitalStageView(
                    vm: vm,
                    palette: palette,
                    onOpenAbout: {
                        selectedTab = .settings
                    },
                    onOpenSharePostcard: {
                        postcardTarget = makePostcardRequest()
                    },
                    onForkToCreate: {
                        vm.forkCurrentShowcaseIntoCreate()
                        selectedTab = .create
                    },
                    onShareSavedEntry: { entry in
                        presentPostcardAfterSheetDismiss(makePostcardRequest(for: entry))
                    },
                    onOpenSavedInCreate: { entry in
                        vm.openSavedEntryInCreate(entry, autoPlay: false)
                        selectedTab = .create
                    }
                )
            } label: {
                Label("聆听", systemImage: selectedTab == .showcase ? "music.note.house.fill" : "music.note.house")
            }

            Tab(value: ChimmoTab.create) {
                CreateStudioView(
                    vm: vm,
                    palette: palette,
                    onOpenSharePostcard: {
                        postcardTarget = makePostcardRequest()
                    },
                    onOpenShowcaseSpecimen: { spec, followGlow in
                        vm.switchSpace(to: .showcase)
                        if followGlow {
                            vm.openSpecimenForFollowGlow(spec)
                        } else {
                            vm.openSpecimen(spec, autoPlay: true)
                        }
                        selectedTab = .showcase
                    },
                    onShareSavedEntry: { entry in
                        presentPostcardAfterSheetDismiss(makePostcardRequest(for: entry))
                    },
                    onOpenSavedInShowcase: { entry in
                        vm.switchSpace(to: .showcase)
                        vm.openSavedEntry(entry, autoPlay: true)
                        selectedTab = .showcase
                    }
                )
            } label: {
                Label("创作", systemImage: "wand.and.stars")
            }

            Tab(value: ChimmoTab.songbook) {
                MusicBoxShelfView(
                    palette: palette,
                    synth: vm.synth,
                    notebook: vm.notebook,
                    currentDocumentID: vm.document.id,
                    navigationTitleText: "曲本",
                    showsDismissButton: false,
                    onLoadSavedToBoard: { entry in
                        vm.switchSpace(to: .create)
                        vm.openSavedEntryInCreate(entry, autoPlay: false)
                        selectedTab = .create
                    },
                    onPlaySavedInShowcase: { entry in
                        vm.switchSpace(to: .showcase)
                        vm.openSavedEntry(entry, autoPlay: true)
                        selectedTab = .showcase
                    },
                    onPlayAlongSpecimen: { spec in
                        vm.switchSpace(to: .showcase)
                        vm.openSpecimenForFollowGlow(spec)
                        selectedTab = .showcase
                    },
                    onEditSpecimenOnBoard: { spec in
                        vm.switchSpace(to: .showcase)
                        vm.openSpecimen(spec, autoPlay: true)
                        selectedTab = .showcase
                    },
                    onBorrowAtmosphere: { spec in
                        if vm.activeSpace == .create {
                            vm.borrowHarmonyAtmosphere(from: spec)
                            selectedTab = .create
                        } else {
                            vm.switchSpace(to: .showcase)
                            vm.borrowHarmonyAtmosphere(from: spec)
                            selectedTab = .showcase
                        }
                    },
                    onShareSavedEntry: { entry in
                        postcardTarget = makePostcardRequest(for: entry)
                    },
                    onForkSpecimenToCreate: { spec in
                        vm.switchSpace(to: .showcase)
                        vm.openSpecimen(spec, autoPlay: false)
                        vm.forkCurrentShowcaseIntoCreate()
                        selectedTab = .create
                    },
                    onStartNewTap: {
                        vm.switchSpace(to: .create)
                        vm.requestOpenDreamSheet = true
                        selectedTab = .create
                    },
                    onWillPlayInline: {
                        vm.stopPlayback()
                    },
                    onRenameSavedEntry: { id, newTitle in
                        vm.renameSavedEntry(id: id, newTitle: newTitle)
                    },
                    onDuplicateSavedEntry: { id in
                        vm.duplicateSavedEntry(id: id)
                    },
                    onDeleteSavedEntry: { id in
                        vm.deleteSavedEntry(id: id)
                    }
                )
            } label: {
                Label("曲本", systemImage: selectedTab == .songbook ? "books.vertical.fill" : "books.vertical")
            }

            Tab(value: ChimmoTab.settings) {
                SettingsView(
                    vm: vm,
                    palette: palette,
                    onOpenSharePostcard: {
                        postcardTarget = makePostcardRequest()
                    }
                )
            } label: {
                Label("工坊", systemImage: selectedTab == .settings ? "square.grid.2x2.fill" : "square.grid.2x2")
            }
        }
        .tint(palette.homeAnchor)
        .fontDesign(.rounded)
        .modifier(OptionalAppearanceModifier(preference: vm.appearance))
        .onChange(of: selectedTab) { _, nextTab in
            switch nextTab {
            case .showcase:
                vm.switchSpace(to: .showcase)
            case .create:
                vm.switchSpace(to: .create)
            case .songbook, .settings:
                vm.stopPlayback()
            }
        }
        .onChange(of: vm.requestOpenDreamSheet) { _, shouldOpen in
            if shouldOpen {
                vm.switchSpace(to: .create)
                selectedTab = .create
            }
        }
        .task {
            // 首帧绘制完约 180ms 后异步预热后台音频引擎，兼具瞬时开屏与首次点按零延迟发声
            try? await Task.sleep(nanoseconds: 180_000_000)
            vm.synth.ensureRunning()
        }
        .sheet(isPresented: $showAbout) {
            AboutSheetView(
                palette: palette,
                currentDocument: vm.document,
                cradleEnabled: vm.cradleEnabled,
                chordPreset: vm.chordPreset,
                chordOverrides: vm.chordOverrides,
                accompanimentTexture: vm.accompanimentTexture,
                melodyVoice: vm.melodyVoice,
                shadowEnabled: vm.shadowCounterpointEnabled,
                playbackRate: vm.playbackRate,
                visualMode: vm.visualMode,
                onAuditionDuo: { character in
                    vm.auditionDuoCharacter(character)
                },
                onAuditionMember: { member in
                    vm.auditionChimmoMember(member)
                },
                onOpenSharePostcard: {
                    let req = makePostcardRequest()
                    showAbout = false
                    deferredPostcardTask?.cancel()
                    deferredPostcardTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 320_000_000)
                        if !Task.isCancelled {
                            postcardTarget = req
                        }
                    }
                }
            )
        }
        .sheet(item: $postcardTarget) { req in
            VinylPostcardShareSheet(palette: palette, request: req)
        }
        .onDisappear {
            deferredPostcardTask?.cancel()
            deferredPostcardTask = nil
        }
    }
}

private struct OptionalAppearanceModifier: ViewModifier {
    let preference: AppearancePreference

    @ViewBuilder
    func body(content: Content) -> some View {
        switch preference {
        case .auto:
            content
        case .daylight:
            content.preferredColorScheme(.light)
        case .nightLamp:
            content.preferredColorScheme(.dark)
        }
    }
}
