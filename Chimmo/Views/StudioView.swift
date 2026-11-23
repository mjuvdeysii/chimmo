import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum ChimmoTab: Int, Hashable, Sendable {
    case board = 0
    case musicBox = 1
}

@MainActor
public final class StudioViewModel: ObservableObject {
    @Published public var document: MelodyDocument = SpecimenLibrary.saintSaensTheSwan
    @Published public var appearance: AppearancePreference = .auto
    @Published public var melodyVoice: MelodyVoice = .singingCello
    @Published public var accompanimentTexture: AccompanimentTexture = .swanRipple
    @Published public var chordPreset: ChordProgressionPreset = .autoMatch
    @Published public var chordOverrides: [Int: DiatonicChord] = [:]
    @Published public var pentatonicSafe: Bool = false // 默认载入圣桑《天鹅》含7音，敲新节奏时自动打开安心5音
    @Published public var followGlowActive: Bool = false
    @Published public var followGlowIndex: Int = 0
    @Published public var smartHintActive: Bool = false
    @Published public var isTappingRhythm: Bool = false
    @Published public var liveTapTimestamps: [TimeInterval] = []
    @Published public var isPlaying: Bool = false
    @Published public var playheadTime: Double? = nil
    @Published public var activeDegrees: Set<Int> = []
    @Published public var activeLaneIndices: Set<Int> = []
    @Published public var latestDegree: Int? = 1
    @Published public var selectedBeadID: UUID? = nil
    @Published public var impulses: [VisualImpulse] = []
    @Published public var statusToast: String? = nil
    @Published public var canUndo: Bool = false
    @Published public var currentSavedEntryID: UUID? = nil

    public let synth: FeltPianoSynth
    public let capturePipeline: HumCapturePipeline
    public let notebook: MelodyNotebookStore

    private let router = HalfDuplexAudioRouter()
    private var undoStack: [MelodyDocument] = []
    private var playbackTask: Task<Void, Never>?
    private var contextEchoTask: Task<Void, Never>?
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

    public init(notebookStore: MelodyNotebookStore? = nil) {
        let s = FeltPianoSynth(router: router)
        self.synth = s
        self.capturePipeline = HumCapturePipeline(router: router, synth: s)
        self.notebook = notebookStore ?? MelodyNotebookStore()
        self.pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(SpecimenLibrary.saintSaensTheSwan)
    }

    // MARK: - Inline Wooden Rhythm Drum Capture (Live Beat Pillars on Roll)

    public func startRhythmTap() {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        smartHintActive = false
        selectedBeadID = nil
        liveTapTimestamps.removeAll()
        isTappingRhythm = true
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        showToast("不用管音高，按脑海里的快慢轻敲下方木鼓")
    }

    public func recordRhythmDrumTap() {
        let now = Date().timeIntervalSinceReferenceDate
        if liveTapTimestamps.count >= 16 {
            liveTapTimestamps.removeFirst()
        }
        liveTapTimestamps.append(now)
        let isFirst = liveTapTimestamps.count == 1
        AcousticHapticsEngine.shared.playBeatTap(isStrong: isFirst)
        let hz = document.scaleMode.frequencyHz(rootMIDI: 60, degree: isFirst ? 1 : 5, octaveOffset: 0)
        synth.playNote(frequency: hz, velocity: isFirst ? 0.54 : 0.36, decay: 0.42, timbre: .liquidHarp)
    }

    public func resetRhythmTaps() {
        liveTapTimestamps.removeAll()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
    }

    public func cancelRhythmTap() {
        isTappingRhythm = false
        liveTapTimestamps.removeAll()
    }

    public func commitRhythmTaps() {
        stopPlayback()
        isTappingRhythm = false
        pushUndo()
        currentSavedEntryID = nil
        chordOverrides.removeAll()
        if chordPreset == .off { chordPreset = .autoMatch }

        let rawNotes: [NoteBead]
        if liveTapTimestamps.count < 2 {
            // 未敲满 2 下时提供 6 拍舒展呼吸示范节奏，马上能玩选山坡和调木琴
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

        // 敲新节奏默认开启「安心5音」并先给一座温柔的拱桥轮廓，用户可一键换 4 座山坡或哼走势或点左侧木琴精调！
        pentatonicSafe = true
        let archNotes = XylophoneRollEngine.applyHill(.arch, to: rawNotes, pentatonicSafe: true)
        document = MelodyDocument(
            title: "脑放纸带 #\(notebook.entries.count + 1)",
            subtitle: "点「山坡」或「哼走势」大调轮廓，再点左侧木琴条逐拍精调",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: archNotes,
            isSpecimen: false,
            preferredTexture: accompanimentTexture,
            preferredVoice: melodyVoice
        )
        selectedBeadID = document.notes.first?.id
        smartHintActive = true
        AcousticHapticsEngine.shared.playResolutionExhale()
        showToast("已定型 \(archNotes.count) 拍！先试试上方 4 座「山坡」或「哼高低走势」")
        togglePlayback()
    }

    // MARK: - Rainbow Wooden Xylophone Interaction & Context Echo (前后连听)

    public func strikeXylophoneLane(_ lane: XylophoneLane) {
        flashLane(lane.index, degree: lane.degree)

        // 模式 1：亮灯跟弹（Follow-the-Glow，像《摸索台灯》木琴玩具一样跟着亮灯敲！）
        if followGlowActive && followGlowIndex < document.notes.count {
            let target = document.notes[followGlowIndex]
            let targetLane = XylophoneLane.laneIndex(degree: target.degree, octaveOffset: target.octaveOffset)
            if lane.index == targetLane {
                let hz = document.scaleMode.frequencyHz(
                    rootMIDI: document.rootMIDI,
                    degree: target.degree,
                    octaveOffset: target.octaveOffset
                )
                synth.playNote(
                    frequency: hz,
                    velocity: 0.64,
                    decay: max(1.1, target.rawDuration * 1.55),
                    timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice)
                )
                if let ch = TheoryLensEngine.chord(at: target.rawOnset, in: chordSpans) {
                    synth.playDiatonicChord(
                        rootMIDI: document.rootMIDI,
                        mode: document.scaleMode,
                        chord: ch,
                        texture: accompanimentTexture,
                        spanDuration: 1.35,
                        intensity: 0.62
                    )
                }
                AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.56)
                followGlowIndex += 1
                if followGlowIndex >= document.notes.count {
                    AcousticHapticsEngine.shared.playResolutionExhale()
                    followGlowIndex = 0
                    showToast("✨ 整首跟弹完成！再敲一遍，或点「退出跟弹」自由改写")
                }
            } else {
                // 敲了旁边别的木条也会自然发声，绝不冷冰冰报错，温柔提示亮灯条
                let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: lane.degree, octaveOffset: lane.octaveOffset)
                synth.playNote(frequency: hz, velocity: 0.45, decay: 1.0, timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice))
                AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
                let expected = XylophoneLane.lane(at: targetLane)
                showToast("跟着亮暖金灯的「\(expected.digitLabel)」条敲哦")
            }
            return
        }

        // 模式 2：正在调某一拍的音高（点左侧木琴条立刻改这拍 + 自动「前后连听」！）
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
            AcousticHapticsEngine.shared.playBeatTap(isStrong: lane.index == 0 || lane.index == 7)
            playContextEcho(upToIndex: idx)
            return
        }

        // 模式 3：纯粹像实体木琴一样自由划奏玩耍
        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: lane.degree, octaveOffset: lane.octaveOffset)
        synth.playNote(frequency: hz, velocity: 0.60, decay: 1.45, timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice))
        AcousticHapticsEngine.shared.playBeatTap(isStrong: lane.index == 0 || lane.index == 7)
    }

    /// 创意 A 核心：「前后连听」—— 调第 N 拍时自动把「前两拍 → 这一拍」连着唱一遍，人耳 0.2 秒就能听出高了还是低了！
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
                self.flashLane(laneIdx, degree: bead.degree)
                self.playheadTime = bead.displayOnset(grooveStrength: self.document.grooveStrength)

                self.synth.playNote(
                    frequency: hz,
                    velocity: isTarget ? 0.68 : 0.44,
                    decay: isTarget ? 1.55 : 0.72,
                    timbre: voiceTimbre
                )

                if !isTarget {
                    let next = slice[offset + 1]
                    let rawGap = next.rawOnset - bead.rawOnset
                    let crispGap = max(0.20, min(0.46, rawGap))
                    try? await Task.sleep(nanoseconds: UInt64(crispGap * 1_000_000_000))
                }
            }
            try? await Task.sleep(nanoseconds: 420_000_000)
            if !Task.isCancelled && !self.isPlaying {
                self.playheadTime = nil
            }
        }
    }

    // MARK: - 4 Hill Templates, Optometrist 3-Bar Hints, Relative Contour Hum & Flexible Bead Edits

    public func applyHillTemplate(_ template: MelodyHillTemplate) {
        guard !document.notes.isEmpty else { return }
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        pushUndo()
        if document.isSpecimen {
            document.isSpecimen = false
            document.title = "\(document.title) · 山坡变奏"
        }
        document.notes = XylophoneRollEngine.applyHill(template, to: document.notes, pentatonicSafe: pentatonicSafe)
        if selectedBeadID == nil {
            selectedBeadID = document.notes.first?.id
        }
        AcousticHapticsEngine.shared.playSeedBloom()
        showToast("已换成「\(template.label)」山坡 · 试听看看最像哪段，再微调 1～2 拍")
        togglePlayback()
    }

    public func toggleSmartPitchHints() {
        smartHintActive.toggle()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        if smartHintActive {
            if selectedBeadID == nil {
                selectedBeadID = document.notes.first?.id
            }
            showToast("💡 左侧已点亮 3 根最搭的木琴条，点点听哪个最像脑海里那声")
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
            AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.6)
            showToast("✨ 跟着左侧发暖金光的木琴条敲，按你的节奏亲自演奏")
        }
    }

    public func togglePentatonicSafe() {
        pentatonicSafe.toggle()
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        showToast(
            pentatonicSafe
                ? "🎋 已开启安心 5 音：收起 4 和 7，怎么点都自然顺耳"
                : "🎼 已解锁全部 8 根彩虹木琴条（含 4 与 7 的情感张力）"
        )
    }

    public func selectBead(_ id: UUID, playContext: Bool = true) {
        selectedBeadID = id
        if playContext, let idx = document.notes.firstIndex(where: { $0.id == id }) {
            playContextEcho(upToIndex: idx)
        }
    }

    public func stepSelectedBeat(delta: Int) {
        guard !document.notes.isEmpty else { return }
        let cur = selectedBeadID.flatMap { id in document.notes.firstIndex { $0.id == id } } ?? 0
        let next = max(0, min(document.notes.count - 1, cur + delta))
        selectedBeadID = document.notes[next].id
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        playContextEcho(upToIndex: next)
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
        flashLane(lane.index, degree: lane.degree)
        if playSinglePreview {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: lane.index == 0 || lane.index == 7)
            let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: lane.degree, octaveOffset: lane.octaveOffset)
            synth.playNote(frequency: hz, velocity: 0.56, decay: 0.85, timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice))
        }
    }

    public func updateBeatTiming(beadID: UUID, newOnset: Double) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        document.notes[idx].rawOnset = max(0.08, newOnset)
        if document.notes[idx].quantizedOnset != nil {
            document.notes[idx].quantizedOnset = max(0.08, newOnset)
        }
        document.notes.sort { $0.rawOnset < $1.rawOnset }
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
                    // 后面拍子温柔右移 0.42 秒腾出空位
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
            selectedBeadID = newBead.id
            if let newIdx = document.notes.firstIndex(where: { $0.id == newBead.id }) {
                playContextEcho(upToIndex: newIdx)
            }
            showToast("已插入 1 拍，点左侧木琴条选它的高低")
        } else {
            triggerLadderMember(.taono, octaveOffset: 0)
        }
    }

    // MARK: - Relative Hum Contour (创意 G: 只听高低走势、无视跑调)

    public func startHumCapture() {
        stopPlayback()
        contextEchoTask?.cancel()
        followGlowActive = false
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        capturePipeline.startRecording()
        showToast(document.notes.isEmpty ? "轻轻哼出脑海里的旋律，哼完再点一次" : "不管跑不跑调，按拍子哼出大概高低起伏就行！")
    }

    public func finishRelativeContourHum() {
        Task {
            if !document.notes.isEmpty {
                // 已有敲好的节奏：只抽取相对高低走势贴合上去，保留 100% 原始节奏！
                if let heights = await capturePipeline.stopAndExtractRelativeContour(slotCount: document.notes.count) {
                    pushUndo()
                    if document.isSpecimen {
                        document.isSpecimen = false
                        document.title = "脑放纸带 #\(notebook.entries.count + 1)"
                    }
                    document.notes = XylophoneRollEngine.applyRelativeContour(
                        to: document.notes,
                        normalizedHeights: heights,
                        pentatonicSafe: pentatonicSafe
                    )
                    selectedBeadID = document.notes.first?.id
                    AcousticHapticsEngine.shared.playResolutionExhale()
                    showToast("已按你的哼唱高低贴好台阶！微调 1～2 拍就完美")
                    togglePlayback()
                } else if !capturePipeline.statusMessage.isEmpty {
                    showToast(capturePipeline.statusMessage)
                }
            } else {
                // 空白画板：直接录成新旋律珠
                if let snapped = await capturePipeline.stopAndTranscribe(preferredMode: nil), !snapped.notes.isEmpty {
                    pushUndo()
                    currentSavedEntryID = nil
                    chordOverrides.removeAll()
                    document = MelodyDocument(
                        title: "轻哼纸带 #\(notebook.entries.count + 1)",
                        subtitle: "点选音珠可继续在木琴画板上精修",
                        rootMIDI: 60,
                        scaleMode: snapped.mode,
                        harmonyProfile: document.harmonyProfile,
                        grooveStrength: 0.0,
                        notes: snapped.notes,
                        isSpecimen: false,
                        preferredTexture: accompanimentTexture,
                        preferredVoice: melodyVoice
                    )
                    pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(document)
                    selectedBeadID = document.notes.first?.id
                    AcousticHapticsEngine.shared.playResolutionExhale()
                    showToast("捉住 \(snapped.notes.count) 颗哼唱音珠！")
                    togglePlayback()
                } else if !capturePipeline.statusMessage.isEmpty {
                    showToast(capturePipeline.statusMessage)
                }
            }
        }
    }

    // MARK: - Core Actions (Preserves 100% Unit-Test Compatibility)

    public func setScaleMode(_ mode: ScaleMode) {
        guard document.scaleMode != mode else { return }
        pushUndo()
        document.scaleMode = mode
        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.5)
        let hz = mode.frequencyHz(rootMIDI: document.rootMIDI, degree: 3, octaveOffset: 0)
        synth.playNote(frequency: hz, velocity: 0.58, decay: 1.4, timbre: FeltPianoSynth.Timbre.from(voice: melodyVoice))
        showToast(mode.isMinorFlavored ? "🌙 切换为「微酸温柔」夜曲色彩" : "☀️ 切换为「晴朗温暖」色彩")
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
        let bead = NoteBead(degree: degree, octaveOffset: octaveOffset, rawOnset: clampedTime, rawDuration: 0.48)
        document.notes.append(bead)
        document.notes.sort { $0.rawOnset < $1.rawOnset }
        selectedBeadID = bead.id

        if let idx = document.notes.firstIndex(where: { $0.id == bead.id }) {
            playContextEcho(upToIndex: idx)
        }
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
        playContextEcho(upToIndex: idx)
        showToast(delta > 0 ? "这拍拖音变长啦" : "这拍变得更利落")
    }

    public func deleteSelectedBead() {
        guard let targetID = selectedBeadID,
              let idx = document.notes.firstIndex(where: { $0.id == targetID }) else { return }
        pushUndo()
        document.notes.remove(at: idx)
        if document.notes.isEmpty {
            selectedBeadID = nil
        } else {
            selectedBeadID = document.notes[min(idx, document.notes.count - 1)].id
        }
        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
        showToast("已删掉这一拍")
    }

    public func cycleSpanChord(spanIndex: Int) {
        let spans = chordSpans
        guard let currentSpan = spans.first(where: { $0.id == spanIndex }) else { return }
        let next = currentSpan.chord.nextChord()
        chordOverrides[spanIndex] = next
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
        showToast(preset == .off ? "已关闭伴奏托底，只听纯净单旋律" : "已开启温柔和声伴奏")
    }

    public func setAccompanimentTexture(_ texture: AccompanimentTexture) {
        accompanimentTexture = texture
        if chordPreset == .off { chordPreset = .autoMatch }
        showToast("伴奏水波：\(texture.label)")
    }

    public func setMelodyVoice(_ voice: MelodyVoice) {
        melodyVoice = voice
        let hz = document.scaleMode.frequencyHz(rootMIDI: document.rootMIDI, degree: 3, octaveOffset: 0)
        synth.playNote(frequency: hz, velocity: 0.62, decay: 1.5, timbre: FeltPianoSynth.Timbre.from(voice: voice))
        showToast("主乐器已换为：\(voice.label)")
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
            title: "新脑放纸带",
            subtitle: "点下方「敲下脑海节奏」，或直接在画板上落珠",
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
        showToast("新空白纸带已铺好，点「敲下脑海节奏」开始！")
    }

    public func openSpecimen(_ specimen: MelodyDocument, autoPlay: Bool = true) {
        stopPlayback()
        contextEchoTask?.cancel()
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
        if autoPlay { togglePlayback() }
    }

    public func openSpecimenForFollowGlow(_ specimen: MelodyDocument) {
        openSpecimen(specimen, autoPlay: false)
        selectedBeadID = nil
        followGlowActive = true
        followGlowIndex = 0
        showToast("✨ 跟着左侧发暖金光的木琴条敲，演奏《\(specimen.title)》")
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
        chordPreset = entry.chordPreset
        chordOverrides = entry.chordOverrides
        accompanimentTexture = entry.accompanimentTexture ?? entry.document.preferredTexture ?? .swanRipple
        melodyVoice = entry.document.preferredVoice ?? .singingCello
        pentatonicSafe = !XylophoneRollEngine.requiresSevenScale(entry.document)
        if autoPlay { togglePlayback() }
    }

    public func saveCurrentToNotebook(moodSticker: String? = nil) {
        guard !document.notes.isEmpty else {
            showToast("先敲下几拍脑放，再收进音乐盒吧")
            return
        }
        var docToSave = document
        if docToSave.isSpecimen || docToSave.title == "新脑放纸带" || docToSave.title == "指尖即兴" {
            docToSave.title = "脑放纸带 #\(notebook.entries.count + 1)"
        }
        docToSave.isSpecimen = false
        docToSave.preferredTexture = accompanimentTexture
        docToSave.preferredVoice = melodyVoice

        let saved = notebook.save(
            document: docToSave,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            moodSticker: moodSticker ?? (document.scaleMode.isMinorFlavored ? "🌙 温柔夜曲" : "🌈 彩虹木琴"),
            summaryNote: currentInsight.headline,
            existingEntryID: currentSavedEntryID
        )
        currentSavedEntryID = saved.id
        document = saved.document
        AcousticHapticsEngine.shared.playResolutionExhale()
        showToast("已贴进「音乐盒」：\(saved.document.title)")
    }

    // MARK: - Playback Sequencer

    public func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }
        guard !document.notes.isEmpty else {
            strikeXylophoneLane(XylophoneLane.allLanes[0])
            return
        }
        contextEchoTask?.cancel()
        synth.ensureRunning()
        isPlaying = true

        playbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled && self.isPlaying {
                let total = self.document.totalDuration
                let sorted = self.document.notes.sorted {
                    $0.displayOnset(grooveStrength: self.document.grooveStrength) < $1.displayOnset(grooveStrength: self.document.grooveStrength)
                }

                let startDate = Date()
                var nextNoteIdx = 0
                var lastTriggeredSpanID: Int = -1

                while !Task.isCancelled && self.isPlaying {
                    let elapsed = Date().timeIntervalSince(startDate)
                    self.playheadTime = elapsed

                    let spans = self.chordSpans
                    if let currentSpan = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }),
                       currentSpan.id != lastTriggeredSpanID {
                        lastTriggeredSpanID = currentSpan.id
                        self.synth.playDiatonicChord(
                            rootMIDI: self.document.rootMIDI,
                            mode: self.document.scaleMode,
                            chord: currentSpan.chord,
                            texture: self.accompanimentTexture,
                            spanDuration: currentSpan.endTime - currentSpan.startTime,
                            intensity: 0.78
                        )
                    }

                    while nextNoteIdx < sorted.count &&
                            sorted[nextNoteIdx].displayOnset(grooveStrength: self.document.grooveStrength) <= elapsed {
                        let bead = sorted[nextNoteIdx]
                        let dur = bead.displayDuration(grooveStrength: self.document.grooveStrength)
                        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                        self.flashLane(laneIdx, degree: bead.degree, holdSeconds: max(0.22, min(0.50, dur * 0.85)))

                        let hz = self.document.scaleMode.frequencyHz(
                            rootMIDI: self.document.rootMIDI,
                            degree: bead.degree,
                            octaveOffset: bead.octaveOffset
                        )
                        self.synth.playNote(
                            frequency: hz,
                            velocity: 0.62,
                            decay: max(1.0, dur * 1.45),
                            brightness: 0.96,
                            timbre: FeltPianoSynth.Timbre.from(voice: self.melodyVoice)
                        )
                        nextNoteIdx += 1
                    }

                    if elapsed >= total { break }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }

                if Task.isCancelled || !self.isPlaying { break }
                try? await Task.sleep(nanoseconds: 420_000_000)
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
        activeLaneIndices.removeAll()
    }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        stopPlayback()
        document = prev
        selectedBeadID = document.notes.first?.id
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
            subtitle: "在木琴画板上自由编织脑放",
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

    private func flashLane(_ laneIdx: Int, degree: Int, holdSeconds: Double = 0.28) {
        latestDegree = degree
        activeDegrees.insert(degree)
        activeLaneIndices.insert(laneIdx)
        let holdNs = UInt64(holdSeconds * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: holdNs)
            self?.activeDegrees.remove(degree)
            self?.activeLaneIndices.remove(laneIdx)
        }
    }

    private func playSingleNoteWithChord(degree: Int, octaveOffset: Int, atTime: Double, xNorm: Double) {
        let laneIdx = XylophoneLane.laneIndex(degree: degree, octaveOffset: octaveOffset)
        flashLane(laneIdx, degree: degree)
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
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled {
                self?.statusToast = nil
            }
        }
    }
}

/// 咩哞 v0.6 极简实体玩具入口：
/// 砍掉 80% 弥漫抽象菜单，打开即用「木琴画板」与「音乐盒」双标签极简架构。
public struct StudioView: View {
    @StateObject private var vm = StudioViewModel()
    @Environment(\.colorScheme) private var systemScheme

    @State private var selectedTab: ChimmoTab = .board
    @State private var showAbout: Bool = false

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
            XylophoneRollBoardView(
                vm: vm,
                palette: palette,
                onOpenAbout: {
                    showAbout = true
                }
            )
            .tabItem {
                Label("木琴画板", systemImage: "pianokeys")
            }
            .tag(ChimmoTab.board)

            MusicBoxShelfView(
                palette: palette,
                synth: vm.synth,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                onLoadSavedToBoard: { entry in
                    vm.openSavedEntry(entry, autoPlay: true)
                    selectedTab = .board
                },
                onPlayAlongSpecimen: { spec in
                    vm.openSpecimenForFollowGlow(spec)
                    selectedTab = .board
                },
                onEditSpecimenOnBoard: { spec in
                    vm.openSpecimen(spec, autoPlay: true)
                    selectedTab = .board
                },
                onStartNewTap: {
                    selectedTab = .board
                    vm.startRhythmTap()
                }
            )
            .tabItem {
                Label("音乐盒", systemImage: "music.note.list")
            }
            .tag(ChimmoTab.musicBox)
        }
        .tint(palette.homeAnchor)
        .preferredColorScheme(vm.appearance == .auto ? nil : (isNight ? .dark : .light))
        .sheet(isPresented: $showAbout) {
            AboutSheetView(
                palette: palette,
                currentDocument: vm.document,
                cradleEnabled: vm.cradleEnabled
            )
        }
    }
}
