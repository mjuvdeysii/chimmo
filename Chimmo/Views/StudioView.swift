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
    /// 物理水面高度（0.0 退潮清唱 ... 1.0 深水琶音+星光泛音）
    @Published public var waterLevel: Double = 0.64
    @Published public var layerFilter: AudioLayerFilter = .full
    @Published public var slowMotion: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var playheadTime: Double? = nil
    @Published public var activeDegrees: Set<Int> = []
    @Published public var latestDegree: Int? = 1
    @Published public var impulses: [VisualImpulse] = []
    @Published public var bannerNote: String = "直接点滑下方七只咩哞、上下拉动水面涨退潮，或按住「轻哼捉珠」"
    @Published public var canUndo: Bool = false
    @Published public var tapCount: Int = 0

    public var cradleEnabled: Bool {
        get { waterLevel >= 0.08 }
        set { waterLevel = newValue ? 0.64 : 0.0 }
    }

    public let capturePipeline: HumCapturePipeline

    private let router = HalfDuplexAudioRouter()
    private let synth: FeltPianoSynth
    private var undoStack: [MelodyDocument] = []
    private var playbackTask: Task<Void, Never>?
    private var tapTimestamps: [Double] = []
    private var lastFreeNoteTime: Date?
    private var hasAutoBloomedOnAppear: Bool = false

    public static let featuredQuickSpecimens: [MelodyDocument] = [
        SpecimenLibrary.summerSuspension,
        SpecimenLibrary.bachPreludeSeed,
        SpecimenLibrary.tinkiResolution,
        SpecimenLibrary.satieGymnopedieSeed,
        SpecimenLibrary.rainyChromaticWalk,
        SpecimenLibrary.pachelbelCanonGround
    ]

    public init() {
        let s = FeltPianoSynth(router: router)
        self.synth = s
        self.capturePipeline = HumCapturePipeline(router: router, synth: s)
    }

    // MARK: - First-Launch Welcome Auto-Bloom

    public func triggerWelcomeBloomIfNeeded() {
        guard !hasAutoBloomedOnAppear else { return }
        hasAutoBloomedOnAppear = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard let self, !self.isPlaying, !self.capturePipeline.isRecording else { return }
            self.bannerNote = self.document.composerInsight ?? "试着上下拖动水面听和声涨落，或直接点按下方七只咩哞"
            self.togglePlayback()
        }
    }

    // MARK: - Live Play & Direct Tactile Creation

    public func triggerMember(_ member: ChimmoMember, octaveOffset: Int = 0, customXNorm: Double? = nil) {
        stopPlayback()
        fireHaptic(style: member.degree == 1 ? .medium : .light)

        // 如果当前在看预置标本，用户一点七小只，立刻无缝切入属于用户自己的「指尖即兴」画卷，让每一次点击都在空中绽放陶珠！
        if document.isSpecimen {
            pushUndo()
            document = MelodyDocument(
                title: "指尖即兴",
                subtitle: "点滑七只咩哞或直接在纸面空中划过",
                rootMIDI: document.rootMIDI,
                scaleMode: document.scaleMode,
                harmonyProfile: document.harmonyProfile,
                grooveStrength: 0.0,
                notes: [],
                isSpecimen: false
            )
            lastFreeNoteTime = nil
        }

        let now = Date()
        let gap = lastFreeNoteTime.map { min(1.1, max(0.26, now.timeIntervalSince($0))) } ?? 0.0
        lastFreeNoteTime = now

        // 若连续弹奏超过 14 颗音珠，自动向左温柔滚动腾出画布空间，像无尽八音盒纸带一样可一直弹下去
        if document.notes.count >= 14 {
            document.notes.removeFirst()
            if let firstOnset = document.notes.first?.rawOnset, firstOnset > 0 {
                for idx in document.notes.indices {
                    document.notes[idx].rawOnset = max(0, document.notes[idx].rawOnset - firstOnset)
                }
            }
        }

        let nextOnset: Double
        if let last = document.notes.last {
            nextOnset = last.rawOnset + max(0.30, gap)
        } else {
            nextOnset = 0.15
        }

        let newBead = NoteBead(
            degree: member.degree,
            octaveOffset: octaveOffset,
            rawOnset: nextOnset,
            rawDuration: 0.52
        )
        document.notes.append(newBead)

        let totalSec = max(3.2, document.totalDuration)
        let xNorm = customXNorm ?? min(0.92, max(0.08, nextOnset / totalSec))
        playSingleMember(member, octaveOffset: octaveOffset, xNorm: xNorm)

        bannerNote = "\(member.degree)·\(member.chineseName)（\(member.roleLabel)）跃入画布 · 上下拉动水面可改变伴奏层次"
    }

    public func paintSkyDegree(degree: Int, octaveOffset: Int, xNorm: Double) {
        let member = ChimmoMember.from(degree: degree)
        triggerMember(member, octaveOffset: octaveOffset, customXNorm: xNorm)
    }

    public func startBlankCanvas() {
        stopPlayback()
        pushUndo()
        document = MelodyDocument(
            title: "指尖即兴",
            subtitle: "点滑七只咩哞、划过天空，或按住「轻哼捉珠」",
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
        impulses.removeAll()
        bannerNote = "空白声学画卷已铺好：点滑下方七只咩哞，看音珠跃入空中并激起水面涟漪"
    }

    public func selectSpecimen(_ specimen: MelodyDocument) {
        stopPlayback()
        pushUndo()
        document = specimen
        tapTimestamps.removeAll()
        tapCount = 0
        if waterLevel < 0.25 {
            waterLevel = 0.64
        }
        bannerNote = specimen.composerInsight ?? specimen.subtitle
        togglePlayback()
    }

    public func borrowHarmony(profile: HarmonyProfile, mode: ScaleMode) {
        pushUndo()
        document.harmonyProfile = profile
        document.scaleMode = mode
        if waterLevel < 0.35 {
            waterLevel = 0.64
        }
        synth.playWaterRipplePreview(rootMIDI: document.rootMIDI, mode: mode, profile: profile)
        bannerNote = "已换上「\(profile.label) · \(mode.label)」水面和声"
    }

    public func toggleScaleMode() {
        pushUndo()
        document.scaleMode = (document.scaleMode == .brightMajor) ? .wistfulMinor : .brightMajor
        fireHaptic(style: .soft)
        playSingleMember(.plokko, octaveOffset: 0, xNorm: 3.5 / 7.0)
        bannerNote = document.scaleMode == .brightMajor
            ? "晴朗大调：3·拍咯双耳轻扬，天空与水面豁然开朗"
            : "微酸小调：3·拍咯双耳微垂，同一段旋律染上思念色彩"
    }

    public func cycleHarmonyProfile() {
        swipeWaterProfile(direction: 1)
    }

    public func swipeWaterProfile(direction: Int) {
        pushUndo()
        let all = HarmonyProfile.allCases
        if let idx = all.firstIndex(of: document.harmonyProfile) {
            let nextIdx = (idx + (direction >= 0 ? 1 : all.count - 1)) % all.count
            document.harmonyProfile = all[nextIdx]
        }
        if waterLevel < 0.32 {
            waterLevel = 0.58
        }
        fireHaptic(style: .soft)
        synth.playWaterRipplePreview(
            rootMIDI: document.rootMIDI,
            mode: document.scaleMode,
            profile: document.harmonyProfile
        )
        spawnImpulse(degree: 5, octaveOffset: 0, xNorm: 0.5)
        bannerNote = "水色已拂为「\(document.harmonyProfile.label)」：\(document.harmonyProfile.subtitle)"
    }

    // MARK: - Bead & Ghost Editing

    public func applyGhost(beadID: UUID, ghost: GhostCandidate) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        pushUndo()
        document.notes[idx].degree = ghost.degree
        document.notes[idx].octaveOffset = ghost.octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        fireHaptic(style: .rigid)
        let member = ChimmoMember.from(degree: ghost.degree)
        let onset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleMember(member, octaveOffset: ghost.octaveOffset, xNorm: xNorm)
        bannerNote = "已吸附至 \(ghost.degree)·\(member.chineseName)"
    }

    public func updateBeadPitch(beadID: UUID, degree: Int, octaveOffset: Int) {
        guard let idx = document.notes.firstIndex(where: { $0.id == beadID }) else { return }
        if document.notes[idx].degree == degree && document.notes[idx].octaveOffset == octaveOffset { return }
        pushUndo()
        document.notes[idx].degree = degree
        document.notes[idx].octaveOffset = octaveOffset
        document.notes[idx].ghostCandidates.removeAll()
        fireHaptic(style: .soft)
        let member = ChimmoMember.from(degree: degree)
        let onset = document.notes[idx].displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleMember(member, octaveOffset: octaveOffset, xNorm: xNorm)
        bannerNote = "拖动音珠至 \(degree)·\(member.chineseName)（\(member.roleLabel)）"
    }

    public func previewBead(_ bead: NoteBead) {
        let onset = bead.displayOnset(grooveStrength: document.grooveStrength)
        let xNorm = onset / max(3.2, document.totalDuration)
        playSingleMember(bead.member, octaveOffset: bead.octaveOffset, xNorm: xNorm)
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
            bannerNote = "已对齐心跳约 \(Int(aligned.bpm.rounded())) BPM"
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
                    subtitle: "\(snapped.mode.label) · 轻点或上下拖动音珠可微调",
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

    // MARK: - Looping Playback Sequencer

    public func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }
        guard !document.notes.isEmpty else {
            // 如果当前是空画布，点播放自动来一段温暖的三音和弦欢迎礼，引导用户开玩
            triggerMember(.taono)
            return
        }
        synth.ensureRunning()
        isPlaying = true
        tapTimestamps.removeAll()
        tapCount = 0

        playbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled && self.isPlaying {
                let speed = self.slowMotion ? 0.5 : 1.0
                let total = self.document.totalDuration
                let totalCanvasSec = max(3.2, total)
                let sorted = self.document.notes.sorted {
                    $0.displayOnset(grooveStrength: self.document.grooveStrength) < $1.displayOnset(grooveStrength: self.document.grooveStrength)
                }

                let startDate = Date()
                var nextIndex = 0

                while !Task.isCancelled && self.isPlaying {
                    let elapsed = Date().timeIntervalSince(startDate) * speed
                    self.playheadTime = elapsed

                    while nextIndex < sorted.count &&
                            sorted[nextIndex].displayOnset(grooveStrength: self.document.grooveStrength) <= elapsed {
                        let bead = sorted[nextIndex]
                        let onset = bead.displayOnset(grooveStrength: self.document.grooveStrength)
                        let dur = bead.displayDuration(grooveStrength: self.document.grooveStrength) / speed
                        let xNorm = min(0.94, max(0.06, onset / totalCanvasSec))
                        self.performScheduledBead(bead, durationSec: dur, xNorm: xNorm)
                        nextIndex += 1
                    }

                    if elapsed >= total {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps playhead
                }

                if Task.isCancelled || !self.isPlaying {
                    break
                }
                // 乐句尾声留出 0.42 秒温柔呼吸，然后无缝循环，方便用户边听边拉动水面与切换晴雨调式
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

    private func spawnImpulse(degree: Int, octaveOffset: Int, xNorm: Double) {
        let now = Date().timeIntervalSinceReferenceDate
        impulses.removeAll { now - $0.birth > 2.0 }
        impulses.append(
            VisualImpulse(
                birth: now,
                degree: degree,
                octaveOffset: octaveOffset,
                xNorm: xNorm
            )
        )
    }

    private func performScheduledBead(_ bead: NoteBead, durationSec: Double, xNorm: Double) {
        let member = bead.member
        latestDegree = member.degree
        spawnImpulse(degree: bead.degree, octaveOffset: bead.octaveOffset, xNorm: xNorm)

        if layerFilter != .harmonyOnly {
            let hz = document.scaleMode.frequencyHz(
                rootMIDI: document.rootMIDI,
                degree: bead.degree,
                octaveOffset: bead.octaveOffset
            )
            synth.playNote(frequency: hz, velocity: 0.56, decay: max(0.95, durationSec * 1.45), brightness: 0.94)
        }
        if waterLevel >= 0.08 && layerFilter != .melodyOnly {
            let voicing = document.harmonyProfile.voicing(for: bead.degree)
            synth.playWaterCradle(
                rootMIDI: document.rootMIDI,
                mode: document.scaleMode,
                voicing: voicing,
                waterLevel: waterLevel
            )
        }

        activeDegrees.insert(member.degree)
        let holdNs = UInt64(max(0.20, min(0.58, durationSec * 0.85)) * 1_000_000_000)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: holdNs)
            self?.activeDegrees.remove(member.degree)
        }
    }

    private func playSingleMember(_ member: ChimmoMember, octaveOffset: Int, xNorm: Double) {
        latestDegree = member.degree
        spawnImpulse(degree: member.degree, octaveOffset: octaveOffset, xNorm: xNorm)

        let hz = document.scaleMode.frequencyHz(
            rootMIDI: document.rootMIDI,
            degree: member.degree,
            octaveOffset: octaveOffset
        )
        synth.playNote(frequency: hz, velocity: 0.58, decay: 1.65, brightness: 0.94)
        if waterLevel >= 0.08 && layerFilter != .melodyOnly {
            let voicing = document.harmonyProfile.voicing(for: member.degree)
            synth.playWaterCradle(
                rootMIDI: document.rootMIDI,
                mode: document.scaleMode,
                voicing: voicing,
                waterLevel: waterLevel
            )
        }
        activeDegrees.insert(member.degree)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
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
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 顶部一键曲目与自由弹唱画卷胶囊条 + 实时一句话心法提示
                topPlayRibbonAndInsight

                // 2. 中央 60fps 活体声学画卷 + 可直接上下拉动/左右拂色的物理水面
                GravityScrollCanvas(
                    document: vm.document,
                    palette: palette,
                    waterLevel: $vm.waterLevel,
                    playheadTime: vm.playheadTime,
                    impulses: vm.impulses,
                    onSelectGhost: { id, ghost in vm.applyGhost(beadID: id, ghost: ghost) },
                    onDragBeadDegree: { id, deg, oct in vm.updateBeadPitch(beadID: id, degree: deg, octaveOffset: oct) },
                    onTapBead: { bead in vm.previewBead(bead) },
                    onPaintSkyDegree: { deg, oct, xNorm in vm.paintSkyDegree(degree: deg, octaveOffset: oct, xNorm: xNorm) },
                    onSwipeWaterProfile: { dir in vm.swipeWaterProfile(direction: dir) },
                    onTapBlankPaper: { vm.recordTapAlongBeat() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 3. 底部七只咩哞实体木架舞台（24fps 连续呼吸、眨眼、互相转头看正在唱歌的同伴）
                TroupeShelfView(
                    palette: palette,
                    isMinor: vm.document.scaleMode == .wistfulMinor,
                    activeDegrees: vm.activeDegrees,
                    latestDegree: vm.latestDegree,
                    listeningTilt: vm.capturePipeline.isRecording ? (vm.capturePipeline.inputLevel - 0.35) : 0,
                    onTriggerMember: { member in vm.triggerMember(member) }
                )

                // 4. 极简三大直觉主控：循环听 / 轻哼捉珠 / 拍咯晴雨切换
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
                        Label("全部 16 首", systemImage: "music.note.list")
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
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("清空画布自由弹唱")

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
            .sheet(isPresented: $showSpecimens) {
                SpecimenSheetView(
                    palette: palette,
                    currentSpecimenID: vm.document.id,
                    onSelectSpecimen: { spec in vm.selectSpecimen(spec) },
                    onBorrowHarmony: { profile, mode in vm.borrowHarmony(profile: profile, mode: mode) }
                )
            }
            .sheet(isPresented: $showAbout) {
                AboutSheetView(
                    palette: palette,
                    currentDocument: vm.document,
                    cradleEnabled: vm.cradleEnabled
                )
            }
            .onAppear {
                vm.triggerWelcomeBloomIfNeeded()
            }
        }
        .preferredColorScheme(vm.appearance == .auto ? nil : (isNight ? .dark : .light))
    }

    // MARK: - Subviews

    private var topPlayRibbonAndInsight: some View {
        VStack(alignment: .leading, spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 自由弹唱胶囊
                    let isFree = !vm.document.isSpecimen
                    Button {
                        vm.startBlankCanvas()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 11))
                            Text("自由弹唱")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isFree ? palette.melodyTerracotta : palette.shelfSurface)
                        )
                        .foregroundStyle(isFree ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                    }

                    // 精选一步直达曲目胶囊
                    ForEach(StudioViewModel.featuredQuickSpecimens) { spec in
                        let isSelected = vm.document.isSpecimen && vm.document.title == spec.title
                        Button {
                            vm.selectSpecimen(spec)
                        } label: {
                            Text(spec.title)
                                .font(.caption.weight(isSelected ? .semibold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(isSelected ? palette.homeAnchor : palette.shelfSurface)
                                )
                                .foregroundStyle(isSelected ? (palette.isNight ? Color(hex: 0x102026) : .white) : palette.primaryInk)
                        }
                    }

                    Button {
                        showSpecimens = true
                    } label: {
                        Text("全部 16 首…")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().strokeBorder(palette.divider, lineWidth: 1))
                            .foregroundStyle(palette.secondaryInk)
                    }
                }
                .padding(.horizontal, 14)
            }

            HStack(spacing: 8) {
                Text(vm.bannerNote)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Button(vm.slowMotion ? "0.5× 慢镜" : "1.0×") {
                    vm.slowMotion.toggle()
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(palette.shelfSurface))
                .foregroundStyle(vm.slowMotion ? palette.homeAnchor : palette.secondaryInk)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private var bottomControlDock: some View {
        HStack(spacing: 14) {
            // 1. 左侧：循环试听 / 暂停
            Button {
                vm.togglePlayback()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(vm.isPlaying ? "暂停" : "循环听")
                        .font(.caption2.weight(.medium))
                }
                .frame(width: 64, height: 50)
                .foregroundStyle(palette.homeAnchor)
            }
            .accessibilityLabel(vm.isPlaying ? "暂停循环播放" : "循环试听当前画布")

            Spacer()

            // 2. 中央核心按钮：轻哼捉珠
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
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(vm.capturePipeline.isRecording ? palette.tensionFilament : palette.melodyTerracotta)
                )
                .foregroundStyle(palette.isNight && !vm.capturePipeline.isRecording ? Color(hex: 0x1B2245) : .white)
                .scaleEffect(vm.capturePipeline.isRecording ? 1.0 + CGFloat(vm.capturePipeline.inputLevel) * 0.08 : 1.0)
            }
            .accessibilityLabel(vm.capturePipeline.isRecording ? "结束哼唱并凝结成陶珠" : "开始轻哼捕捉脑海旋律")

            Spacer()

            // 3. 右侧：3号拍咯一键晴雨（大调/小调）切换
            Button {
                vm.toggleScaleMode()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: vm.document.scaleMode == .brightMajor ? "sun.max.fill" : "cloud.rain.fill")
                        .font(.title3)
                    Text(vm.document.scaleMode == .brightMajor ? "晴朗大调" : "微酸小调")
                        .font(.caption2.weight(.medium))
                }
                .frame(width: 64, height: 50)
                .foregroundStyle(ChimmoMember.plokko.bodyColor)
            }
            .accessibilityLabel("切换晴朗大调与微酸小调，观察 3 号拍咯双耳姿态与旋律情绪变化")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(palette.paper)
    }
}
