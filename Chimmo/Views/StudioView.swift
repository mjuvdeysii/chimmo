import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum AudioLayerFilter: String, CaseIterable, Identifiable, Sendable {
    case full
    case melodyOnly
    case harmonyOnly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .full: return "完整合奏"
        case .melodyOnly: return "单听旋律"
        case .harmonyOnly: return "单听水面"
        }
    }
}

@MainActor
public final class StudioViewModel: ObservableObject {
    @Published public var document: MelodyDocument = SpecimenLibrary.summerSuspension
    @Published public var appearance: AppearancePreference = .auto
    @Published public var cradleEnabled: Bool = true
    @Published public var layerFilter: AudioLayerFilter = .full
    @Published public var slowMotion: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var playheadTime: Double? = nil
    @Published public var activeDegrees: Set<Int> = []
    @Published public var bannerNote: String = "点按下方七只咩哞，或按住「轻哼捉珠」把脑海里的旋律唱出来"
    @Published public var canUndo: Bool = false
    @Published public var tapCount: Int = 0

    public let capturePipeline: HumCapturePipeline

    private let router = HalfDuplexAudioRouter()
    private let synth: FeltPianoSynth
    private var undoStack: [MelodyDocument] = []
    private var playbackTask: Task<Void, Never>?
    private var tapTimestamps: [Double] = []
    private var lastFreeNoteTime: Date?

    public init() {
        let s = FeltPianoSynth(router: router)
        self.synth = s
        self.capturePipeline = HumCapturePipeline(router: router, synth: s)
    }

    // MARK: - Live Play & Free Creation

    public func triggerMember(_ member: ChimmoMember, appendIfFree: Bool = true) {
        stopPlayback()
        fireHaptic(style: member.degree == 1 ? .medium : .light)
        playSingleMember(member, octaveOffset: 0)

        if appendIfFree && !document.isSpecimen {
            let now = Date()
            let gap = lastFreeNoteTime.map { min(1.4, max(0.28, now.timeIntervalSince($0))) } ?? 0.0
            let nextOnset: Double
            if let last = document.notes.last {
                nextOnset = last.rawOnset + max(0.32, gap)
            } else {
                nextOnset = 0.0
            }
            lastFreeNoteTime = now
            pushUndo()
            document.notes.append(
                NoteBead(degree: member.degree, octaveOffset: 0, rawOnset: nextOnset, rawDuration: 0.48)
            )
            bannerNote = "已记下 \(member.degree)号 \(member.chineseName)（共 \(document.notes.count) 颗陶珠）"
        }
    }

    public func startBlankCanvas() {
        stopPlayback()
        pushUndo()
        document = MelodyDocument(
            title: "新的脑放草图",
            subtitle: "轻哼或点按七只咩哞",
            rootMIDI: 60,
            scaleMode: document.scaleMode,
            harmonyProfile: document.harmonyProfile,
            grooveStrength: 0.0,
            notes: [],
            isSpecimen: false
        )
        lastFreeNoteTime = nil
        tapTimestamps.removeAll()
        tapCount = 0
        bannerNote = "空白手账已铺好：按住「轻哼捉珠」或直接点按下方七只咩哞"
    }

    public func selectSpecimen(_ specimen: MelodyDocument) {
        stopPlayback()
        pushUndo()
        document = specimen
        tapTimestamps.removeAll()
        tapCount = 0
        bannerNote = specimen.composerInsight ?? specimen.subtitle
        togglePlayback()
    }

    public func borrowHarmony(profile: HarmonyProfile, mode: ScaleMode) {
        pushUndo()
        document.harmonyProfile = profile
        document.scaleMode = mode
        cradleEnabled = true
        bannerNote = "已换上「\(profile.label) · \(mode.label)」水面和声"
    }

    public func toggleScaleMode() {
        pushUndo()
        document.scaleMode = (document.scaleMode == .brightMajor) ? .wistfulMinor : .brightMajor
        playSingleMember(.plokko, octaveOffset: 0)
        bannerNote = document.scaleMode == .brightMajor
            ? "晴朗大调：3 号拍咯双耳轻扬"
            : "微酸小调：3 号拍咯双耳微垂，感受同一旋律的情绪变化"
    }

    public func cycleHarmonyProfile() {
        pushUndo()
        let all = HarmonyProfile.allCases
        if let idx = all.firstIndex(of: document.harmonyProfile) {
            document.harmonyProfile = all[(idx + 1) % all.count]
        }
        cradleEnabled = true
        bannerNote = "水面色温：\(document.harmonyProfile.label)（\(document.harmonyProfile.subtitle)）"
    }

    // MARK: - Bead & Ghost Editing

    public func applyGhost(beadID: UUID, ghost: GhostCandidate) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        pushUndo()
        document.notes[idx].degree = ghost.degree
        document.notes[idx].octaveOffset = ghost.octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        fireHaptic(style: .rigid)
        playSingleMember(ChimmoMember.from(degree: ghost.degree), octaveOffset: ghost.octaveOffset)
        bannerNote = "已吸附至 \(ghost.degree)号 \(ChimmoMember.from(degree: ghost.degree).chineseName)"
    }

    public func updateBeadPitch(beadID: UUID, degree: Int, octaveOffset: Int) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        if document.notes[idx].degree == degree && document.notes[idx].octaveOffset == octaveOffset { return }
        pushUndo()
        document.notes[idx].degree = degree
        document.notes[idx].octaveOffset = octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        fireHaptic(style: .soft)
        playSingleMember(ChimmoMember.from(degree: degree), octaveOffset: octaveOffset)
    }

    public func previewBead(_ bead: NoteBead) {
        playSingleMember(bead.member, octaveOffset: bead.octaveOffset)
    }

    // MARK: - Tap-Along Beat Alignment (边听边拍定重拍)

    public func recordTapAlongBeat() {
        guard isPlaying, let t = playheadTime else { return }
        fireHaptic(style: .soft)
        tapTimestamps.append(t)
        tapCount = tapTimestamps.count
        if tapTimestamps.count >= 4,
           let aligned = ScaleGravityEngine.applyTapAlongGrid(notes: document.notes, tapTimestamps: tapTimestamps) {
            pushUndo()
            document.estimatedBPM = aligned.bpm
            document.notes = aligned.alignedNotes
            document.grooveStrength = 0.65
            tapTimestamps.removeAll()
            tapCount = 0
            bannerNote = "已对齐心跳约 \(Int(aligned.bpm.rounded())) BPM（可拖动归整焦距随时退回原始呼吸）"
        } else {
            bannerNote = "边听边轻拍空白纸面找重拍（\(tapCount)/4）"
        }
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
                document = MelodyDocument(
                    title: "刚哼出的旋律",
                    subtitle: "\(snapped.mode.label) · 轻点幽灵珠可一指微修",
                    rootMIDI: snapped.rootMIDI,
                    scaleMode: snapped.mode,
                    harmonyProfile: document.harmonyProfile,
                    grooveStrength: 0.0,
                    notes: snapped.notes,
                    isSpecimen: false
                )
                bannerNote = capturePipeline.statusMessage
                togglePlayback()
            } else if !capturePipeline.statusMessage.isEmpty {
                bannerNote = capturePipeline.statusMessage
            }
        }
    }

    // MARK: - Playback Sequencer

    public func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }
        guard !document.notes.isEmpty else {
            bannerNote = "画布还是空的，先轻哼一句或选一首标本吧"
            return
        }
        synth.ensureRunning()
        isPlaying = true
        tapTimestamps.removeAll()
        tapCount = 0

        let speed = slowMotion ? 0.5 : 1.0
        let total = document.totalDuration
        let sorted = document.notes.sorted {
            $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
        }

        playbackTask = Task { [weak self] in
            guard let self else { return }
            let startDate = Date()
            var nextIndex = 0

            while !Task.isCancelled && self.isPlaying {
                let elapsed = Date().timeIntervalSince(startDate) * speed
                self.playheadTime = elapsed

                while nextIndex < sorted.count &&
                        sorted[nextIndex].displayOnset(grooveStrength: self.document.grooveStrength) <= elapsed {
                    let bead = sorted[nextIndex]
                    let dur = bead.displayDuration(grooveStrength: self.document.grooveStrength) / speed
                    self.performScheduledBead(bead, durationSec: dur)
                    nextIndex += 1
                }

                if elapsed >= total {
                    break
                }
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps playhead
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
        bannerNote = "已撤销上一步"
    }

    // MARK: - Internals

    private func pushUndo() {
        undoStack.append(document)
        if undoStack.count > 25 { undoStack.removeFirst() }
        canUndo = true
    }

    private func performScheduledBead(_ bead: NoteBead, durationSec: Double) {
        let member = bead.member
        if layerFilter != .harmonyOnly {
            let hz = document.scaleMode.frequencyHz(
                rootMIDI: document.rootMIDI,
                degree: bead.degree,
                octaveOffset: bead.octaveOffset
            )
            synth.playNote(frequency: hz, velocity: 0.56, decay: max(0.8, durationSec * 1.4), brightness: 0.92)
        }
        if cradleEnabled && layerFilter != .melodyOnly {
            let voicing = document.harmonyProfile.voicing(for: bead.degree)
            synth.playChord(rootMIDI: document.rootMIDI, mode: document.scaleMode, voicing: voicing, intensity: 0.9)
        }

        activeDegrees.insert(member.degree)
        let holdNs = UInt64(max(0.18, min(0.55, durationSec * 0.85)) * 1_000_000_000)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: holdNs)
            self?.activeDegrees.remove(member.degree)
        }
    }

    private func playSingleMember(_ member: ChimmoMember, octaveOffset: Int) {
        let hz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: member.degree,
            octaveOffset: octaveOffset
        )
        synth.playNote(frequency: hz, velocity: 0.58, decay: 1.5, brightness: 0.92)
        if cradleEnabled && layerFilter != .melodyOnly {
            let voicing = document.harmonyProfile.voicing(for: member.degree)
            synth.playChord(rootMIDI: document.rootMIDI, mode: document.scaleMode, voicing: voicing, intensity: 0.85)
        }
        activeDegrees.insert(member.degree)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            self?.activeDegrees.remove(member.degree)
        }
    }

    private func fireHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
        #endif
    }
}

public struct StudioView: View {
    @StateObject private var vm = StudioViewModel()
    @Environment(\.colorScheme) private var systemScheme
    @State private var showSpecimens = false

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
        NavigationStack {
            VStack(spacing: 0) {
                // 标题与编曲洞察条
                headerStrip

                // 中央纸上声学手账画布（占主视觉舞台）
                GravityScrollCanvas(
                    document: vm.document,
                    palette: palette,
                    cradleEnabled: vm.cradleEnabled,
                    playheadTime: vm.playheadTime,
                    onSelectGhost: { id, ghost in vm.applyGhost(beadID: id, ghost: ghost) },
                    onDragBeadDegree: { id, deg, oct in vm.updateBeadPitch(beadID: id, degree: deg, octaveOffset: oct) },
                    onTapBead: { bead in vm.previewBead(bead) },
                    onTapBlankPaper: { vm.recordTapAlongBeat() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 轻薄状态与归整焦距条
                statusAndGrooveBar

                // 底部七只咩哞实体木架舞台
                TroupeShelfView(
                    palette: palette,
                    isMinor: vm.document.scaleMode == .wistfulMinor,
                    activeDegrees: vm.activeDegrees,
                    listeningTilt: vm.capturePipeline.isRecording ? (vm.capturePipeline.inputLevel - 0.35) : 0,
                    onTriggerMember: { member in vm.triggerMember(member) }
                )

                // 底部主操作胶囊栏（按住轻哼 / 播放 / 水面和声 / 拆轨独奏）
                bottomControlDock
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("咩哞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSpecimens = true
                    } label: {
                        Label("标本", systemImage: "music.note.list")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if vm.canUndo {
                        Button {
                            vm.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .accessibilityLabel("撤销")
                    }
                    Button {
                        vm.startBlankCanvas()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建空白草图")

                    Button {
                        let next: AppearancePreference = isNight ? .daylight : .nightLamp
                        vm.appearance = next
                    } label: {
                        Image(systemName: isNight ? "sun.max" : "lamp.desk")
                    }
                    .accessibilityLabel(isNight ? "切换日光纸面" : "切换夜灯舞台")
                }
            }
            .sheet(isPresented: $showSpecimens) {
                SpecimenSheetView(
                    palette: palette,
                    currentSpecimenID: vm.document.id,
                    onSelectSpecimen: { spec in vm.selectSpecimen(spec) },
                    onBorrowHarmony: { profile, mode in vm.borrowHarmony(profile: profile, mode: mode) }
                )
            }
        }
        .preferredColorScheme(vm.appearance == .auto ? nil : (isNight ? .dark : .light))
    }

    // MARK: - Subviews

    private var headerStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(vm.document.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryInk)
                Spacer()
                Button(vm.document.scaleMode.label) {
                    vm.toggleScaleMode()
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(palette.shelfSurface))
                .foregroundStyle(palette.primaryInk)

                Button(vm.document.harmonyProfile.label) {
                    vm.cycleHarmonyProfile()
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(vm.cradleEnabled ? palette.harmonyWash.opacity(0.22) : palette.shelfSurface))
                .foregroundStyle(vm.cradleEnabled ? palette.harmonyWash : palette.secondaryInk)
            }

            Text(vm.bannerNote)
                .font(.caption)
                .foregroundStyle(palette.secondaryInk)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private var statusAndGrooveBar: some View {
        HStack(spacing: 12) {
            // 编曲家拆轨独奏切换
            Picker("声部视图", selection: $vm.layerFilter) {
                ForEach(AudioLayerFilter.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 210)

            Spacer()

            Button(vm.slowMotion ? "0.5× 慢放" : "1.0× 原速") {
                vm.slowMotion.toggle()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(vm.slowMotion ? palette.homeAnchor : palette.secondaryInk)

            if vm.document.notes.contains(where: { $0.quantizedOnset != nil }) {
                HStack(spacing: 4) {
                    Text("呼吸")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                    Slider(value: $vm.document.grooveStrength, in: 0...1)
                        .frame(width: 68)
                        .tint(palette.homeAnchor)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var bottomControlDock: some View {
        HStack(spacing: 14) {
            // 托起水面开关
            Button {
                vm.cradleEnabled.toggle()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: vm.cradleEnabled ? "water.waves" : "water.waves.slash")
                        .font(.title3)
                    Text("水面")
                        .font(.caption2)
                }
                .frame(width: 56, height: 50)
                .foregroundStyle(vm.cradleEnabled ? palette.harmonyWash : palette.secondaryInk)
            }
            .accessibilityLabel(vm.cradleEnabled ? "关闭水面和声" : "托起水面和声")

            Spacer()

            // 核心主按钮：按住轻哼捉珠
            Button {
                if vm.capturePipeline.isRecording {
                    vm.finishHumCapture()
                } else {
                    vm.startHumCapture()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.capturePipeline.isRecording ? "stop.fill" : "waveform")
                        .font(.headline)
                    Text(vm.capturePipeline.isRecording ? "唱完了" : "轻哼捉珠")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(vm.capturePipeline.isRecording ? palette.tensionFilament : palette.melodyTerracotta)
                )
                .foregroundStyle(palette.isNight && !vm.capturePipeline.isRecording ? Color(hex: 0x1B2245) : .white)
                .scaleEffect(vm.capturePipeline.isRecording ? 1.0 + CGFloat(vm.capturePipeline.inputLevel) * 0.08 : 1.0)
            }
            .accessibilityLabel(vm.capturePipeline.isRecording ? "结束哼唱并凝结成陶珠" : "开始轻哼捕捉脑海旋律")

            Spacer()

            // 播放 / 停止按钮
            Button {
                vm.togglePlayback()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: vm.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(vm.isPlaying ? "停止" : "试听")
                        .font(.caption2)
                }
                .frame(width: 56, height: 50)
                .foregroundStyle(palette.homeAnchor)
            }
            .accessibilityLabel(vm.isPlaying ? "停止试听" : "试听当前旋律")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(palette.paper)
    }
}
