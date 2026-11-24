import QuartzCore
import SwiftUI

/// 咩哞「欣赏」互动赏析与跟灯引导主舞台（纯赏析 · 防误改名曲 · 明确区分欣赏与创作空间）：
/// - 顶栏左上为醒目「切换曲目」选择器（彻底告别误导性左上重命名）；
/// - 舞台仅呈现静谧绘本边框（零阴影错觉）+ 右上山坡/花环/星环视图切换；
/// - 下方配安静分幕导览条（「试听此段」明确按钮化）、可自由伴奏七小只彩键、以及「播放 / 跟灯弹 / 去改编」三键控制台。
public struct OrbitalStageView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenAbout: () -> Void
    public let onOpenSharePostcard: () -> Void
    public let onForkToCreate: (() -> Void)?
    public let onShareSavedEntry: ((SavedMelodyEntry) -> Void)?
    public let onOpenSavedInCreate: ((SavedMelodyEntry) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSongPicker: Bool = false
    @State private var showMoodSheet: Bool = false
    @State private var wakeSignal: Int = 0

    public init(
        vm: StudioViewModel,
        palette: ChimmoPalette,
        onOpenAbout: @escaping () -> Void,
        onOpenSharePostcard: @escaping () -> Void = {},
        onForkToCreate: (() -> Void)? = nil,
        onShareSavedEntry: ((SavedMelodyEntry) -> Void)? = nil,
        onOpenSavedInCreate: ((SavedMelodyEntry) -> Void)? = nil
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenAbout = onOpenAbout
        self.onOpenSharePostcard = onOpenSharePostcard
        self.onForkToCreate = onForkToCreate
        self.onShareSavedEntry = onShareSavedEntry
        self.onOpenSavedInCreate = onOpenSavedInCreate
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 10) {
                    showcaseCrownHeader
                        .padding(.horizontal, 16)

                    StageCanvasPanel(
                        vm: vm,
                        palette: palette,
                        allowsEditing: false,
                        reduceMotion: reduceMotion,
                        wakeSignal: wakeSignal,
                        onOpenSoundSheet: {
                            showMoodSheet = true
                        },
                        emptyOverlay: {
                        Button {
                            showSongPicker = true
                        } label: {
                            Label("挑选一首名曲", systemImage: "books.vertical.fill")
                        }
                        .buttonStyle(.chimmoVinyl(palette: palette, tint: palette.prominentFill, prominent: true))
                    })
                    .padding(.horizontal, 16)

                    if !vm.followGlowActive,
                       let chip = StorybookGuidedMomentKinematics.chipModel(
                        moment: vm.activeGuidedMoment,
                        document: vm.document
                       ) {
                        showcaseGuideBar(chip: chip)
                            .padding(.horizontal, 16)
                    }

                    StageChoirKeyboardBar(
                        vm: vm,
                        palette: palette,
                        reduceMotion: reduceMotion,
                        onWakeTimeline: {
                            wakeSignal &+= 1
                        },
                        onKeyStrike: { lane, vel, bright in
                            vm.auditionShowcaseLane(lane, touchIntensity: vel, touchBrightness: bright)
                        }
                    )
                    .padding(.horizontal, 16)

                    showcaseBottomDock
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
                .padding(.top, 4)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSongPicker) {
                MusicBoxShelfView(
                    palette: palette,
                    synth: vm.synth,
                    notebook: vm.notebook,
                    currentDocumentID: vm.document.id,
                    initialSegment: 1,
                    navigationTitleText: "选择曲目",
                    showsDismissButton: true,
                    onLoadSavedToBoard: { entry in
                        showSongPicker = false
                        if let onOpenSavedInCreate {
                            onOpenSavedInCreate(entry)
                        } else {
                            vm.openSavedEntry(entry, autoPlay: true)
                        }
                    },
                    onPlaySavedInShowcase: { entry in
                        showSongPicker = false
                        vm.openSavedEntry(entry, autoPlay: true)
                    },
                    onPlayAlongSpecimen: { spec in
                        showSongPicker = false
                        vm.openSpecimenForFollowGlow(spec)
                    },
                    onEditSpecimenOnBoard: { spec in
                        showSongPicker = false
                        vm.openSpecimen(spec, autoPlay: true)
                    },
                    onBorrowAtmosphere: { spec in
                        showSongPicker = false
                        vm.borrowHarmonyAtmosphere(from: spec)
                    },
                    onShareSavedEntry: { entry in
                        showSongPicker = false
                        if let onShareSavedEntry {
                            onShareSavedEntry(entry)
                        } else {
                            onOpenSharePostcard()
                        }
                    },
                    onForkSpecimenToCreate: { spec in
                        showSongPicker = false
                        vm.openSpecimen(spec, autoPlay: false)
                        if let onFork = onForkToCreate {
                            onFork()
                        } else {
                            vm.forkCurrentShowcaseIntoCreate()
                        }
                    },
                    onStartNewTap: {
                        showSongPicker = false
                        if let onFork = onForkToCreate {
                            onFork()
                        } else {
                            vm.triggerNewCreationFromShelf()
                        }
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
            }
            .sheet(isPresented: $showMoodSheet) {
                SoundPaletteBoxSheet(vm: vm, palette: palette)
            }
        }
    }

    // MARK: - 1. Showcase Crown Header (Top-Left Song Picker + Tune + Share)

    private var showcaseCrownHeader: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)

        return HStack(spacing: 8) {
            Button {
                vm.stopPlayback()
                showSongPicker = true
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(skyColor)
                        .frame(width: 9, height: 9)

                    Text(vm.document.title)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 42)
                .background(
                    ChimmoKilnPillButtonSurface(
                        palette: palette,
                        accent: skyColor,
                        isActive: false,
                        cornerRadius: 21
                    )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("切换曲目，当前《\(vm.document.title)》")
            .accessibilityHint("轻点打开曲库挑选经典乐曲")

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button {
                    showMoodSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.footnote.weight(.bold))
                        Text("调音")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                    }
                    .padding(.horizontal, 11)
                    .frame(minHeight: 40)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: skyColor,
                            isActive: false,
                            cornerRadius: 20
                        )
                    )
                    .foregroundStyle(palette.primaryInk)
                    .contentShape(Capsule())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel("打开声音调色盒")

                Button {
                    onOpenSharePostcard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.footnote.weight(.bold))
                        Text("分享")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                    }
                    .padding(.horizontal, 11)
                    .frame(minHeight: 40)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.homeAnchor,
                            isActive: false,
                            cornerRadius: 20
                        )
                    )
                    .foregroundStyle(palette.primaryInk)
                    .contentShape(Capsule())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel("分享当前作品图片、音频或 MIDI")
            }
            .fixedSize()
        }
    }

    // MARK: - 2. Quiet Storybook Guide Bar (Clear Separation Between Card Info & Audition Action)

    private func showcaseGuideBar(chip: StorybookGuidedMomentKinematics.MomentChipModel) -> some View {
        let chapterNav = StorybookGuidedMomentKinematics.chapterNavigation(for: vm.activeGuidedMoment, in: vm.document)

        return HStack(spacing: 8) {
            ChimmoCartoonKeyBuddyView(
                member: chip.spotlightMember,
                outlineColor: palette.primaryInk.opacity(0.76),
                isSinging: vm.isPlaying,
                isMinor: vm.document.scaleMode.isMinorFlavored
            )
            .frame(width: 24, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(chip.badge)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let nav = chapterNav, nav.totalCount > 1 {
                        Text(nav.progressLabel)
                            .font(.system(.caption2, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(palette.secondaryInk)
                    }
                }

                Text(chip.caption)
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                if let nav = chapterNav, nav.totalCount > 1 {
                    guideChapterStepButton(
                        systemName: "chevron.left",
                        enabled: nav.canStepPrevious,
                        accessibilityLabel: "上一幕故事"
                    ) {
                        vm.stepGuidedMoment(delta: -1)
                        wakeSignal &+= 1
                    }

                    guideChapterStepButton(
                        systemName: "chevron.right",
                        enabled: nav.canStepNext,
                        accessibilityLabel: "下一幕故事"
                    ) {
                        vm.stepGuidedMoment(delta: 1)
                        wakeSignal &+= 1
                    }
                }

                Button {
                    if let activeMoment = vm.activeGuidedMoment {
                        vm.jumpToGuidedMoment(activeMoment, autoPlay: true)
                    } else {
                        vm.scrubToTime(chip.targetOnsetSeconds, triggerNotes: true)
                        vm.endScrubbing()
                        vm.togglePlayback()
                    }
                    wakeSignal &+= 1
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.caption2.weight(.bold))
                        Text("试听此段")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.nightLampGold,
                            isActive: true,
                            cornerRadius: 20
                        )
                    )
                    .foregroundStyle(palette.primaryInk)
                    .contentShape(Capsule())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                .accessibilityLabel("从头试听 \(chip.badge)")
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    private func guideChapterStepButton(
        systemName: String,
        enabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(palette.cardSurface)
                    .frame(width: 32, height: 32)
                    .shadow(
                        color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.24),
                        radius: 2.5,
                        y: 1.5
                    )
                    .overlay(
                        Circle().strokeBorder(
                            palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                            lineWidth: 0.9
                        )
                    )
                Image(systemName: systemName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(enabled ? palette.primaryInk : palette.secondaryInk.opacity(0.35))
            }
            .frame(
                width: StorybookAffordanceMetrics.compactToolMinHitDimension,
                height: StorybookAffordanceMetrics.compactToolMinHitDimension
            )
            .contentShape(Circle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.48)
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 3. Showcase 3-Control Dock (Play / Follow-Glow / Fork to Create)

    private var showcaseBottomDock: some View {
        HStack(spacing: 8) {
            Button {
                vm.togglePlayback()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text(vm.isPlaying ? "暂停" : "播放")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    ChimmoKilnPillButtonSurface(
                        palette: palette,
                        accent: palette.celadonAccent,
                        isActive: vm.isPlaying,
                        cornerRadius: 23
                    )
                )
                .foregroundStyle(palette.primaryInk)
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel(vm.isPlaying ? "暂停播放" : "开始播放")
            .accessibilityHint("播放或暂停当前欣赏乐段，支持空格键控制")
            .storybookKeyboardShortcut(KeyboardShortcut(.space, modifiers: []), enabled: vm.activeSpace == .showcase)

            Button {
                vm.toggleFollowGlow()
            } label: {
                let isFollow = vm.followGlowActive
                let followFill = isFollow ? palette.nightLampGold : palette.prominentFill
                HStack(spacing: 6) {
                    Image(systemName: isFollow ? "xmark" : "sparkles")
                        .font(.subheadline.weight(.bold))
                    Text(
                        isFollow
                            ? "\(min(vm.followGlowIndex + 1, max(1, vm.document.notes.count)))/\(max(1, vm.document.notes.count))"
                            : "跟灯弹"
                    )
                    .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    Capsule()
                        .fill(followFill)
                        .shadow(
                            color: followFill.opacity(palette.isNight ? 0.34 : 0.24),
                            radius: 5,
                            y: 2.5
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(palette.isNight ? 0.16 : 0.35), lineWidth: 1.0)
                        )
                )
                .foregroundStyle(isFollow ? palette.contrastInkOnHighlight : .white)
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel(vm.followGlowActive ? "退出跟灯弹" : "开启跟灯弹")

            Button {
                if let onFork = onForkToCreate {
                    onFork()
                } else {
                    vm.forkCurrentShowcaseIntoCreate()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption.weight(.bold))
                    Text("去改编")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    ChimmoKilnPillButtonSurface(
                        palette: palette,
                        accent: palette.homeAnchor,
                        isActive: false,
                        cornerRadius: 23
                    )
                )
                .foregroundStyle(palette.primaryInk)
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("复制这首曲子到创作区改编")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.stage)
    }
}

/// 共享三态绘本声画舞台面板（支持 Showcase 只读赏析与 Create 自由编写两种严格隔离模式）。
internal struct StageCanvasPanel<EmptyOverlay: View>: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette
    let allowsEditing: Bool
    let reduceMotion: Bool
    let wakeSignal: Int
    let onOpenSoundSheet: () -> Void
    let onUserDidEdit: () -> Void
    @ViewBuilder let emptyOverlay: () -> EmptyOverlay

    @State private var rippleWakeActive: Bool = false
    @State private var rippleWakeTask: Task<Void, Never>? = nil
    @State private var discInteractionMode: DiscDragMode = .none
    @State private var draggingBeadID: UUID? = nil
    @State private var dragStartPoint: CGPoint = .zero
    @State private var dragStartOnset: Double = 0
    @State private var dragDidPushUndo: Bool = false
    @State private var scrubAnchorAngle: Double = 0
    @State private var scrubAnchorTime: Double = 0
    @State private var lastDragAngle: Double = 0
    @State private var lastBeadTimeGridBucket: Int? = nil

    @State private var manualRiverScrollX: CGFloat = 0
    @State private var riverStartScrollX: CGFloat = 0
    @State private var struckNebulaLane: Int? = nil
    @State private var nebulaHoldCenter: CGPoint = .zero
    @State private var isActivelyDraggingStage: Bool = false
    @State private var scrubTick: Int = 0
    @State private var lastScrubTimestamp: Double = 0
    @State private var lastScrubVelocity: Double = 0
    @State private var coastTask: Task<Void, Never>? = nil

    private enum DiscDragMode {
        case none
        case bead(UUID)
        case scrub
        case chordRing(Int)
        case centerHub
    }

    init(
        vm: StudioViewModel,
        palette: ChimmoPalette,
        allowsEditing: Bool,
        reduceMotion: Bool,
        wakeSignal: Int = 0,
        onOpenSoundSheet: @escaping () -> Void = {},
        onUserDidEdit: @escaping () -> Void = {},
        @ViewBuilder emptyOverlay: @escaping () -> EmptyOverlay = { EmptyView() }
    ) {
        self.vm = vm
        self.palette = palette
        self.allowsEditing = allowsEditing
        self.reduceMotion = reduceMotion
        self.wakeSignal = wakeSignal
        self.onOpenSoundSheet = onOpenSoundSheet
        self.onUserDidEdit = onUserDidEdit
        self.emptyOverlay = emptyOverlay
    }

    private var selectedBeatIndex: Int? {
        guard allowsEditing, let id = vm.selectedBeadID else { return nil }
        return vm.document.notes.firstIndex { $0.id == id }
    }

    private var targetFollowLaneIndex: Int? {
        guard vm.followGlowActive,
              vm.followGlowIndex < vm.document.notes.count else { return nil }
        let b = vm.document.notes[vm.followGlowIndex]
        return XylophoneLane.laneIndex(degree: b.degree, octaveOffset: b.octaveOffset)
    }

    private var smartHintByLane: [Int: SmartPitchHint] {
        guard allowsEditing && vm.smartHintActive else { return [:] }
        return Dictionary(uniqueKeysWithValues: vm.smartHints.map { ($0.laneIndex, $0) })
    }

    private var shouldRunCanvasTimeline: Bool {
        !reduceMotion && (vm.isPlaying || rippleWakeActive || isActivelyDraggingStage || vm.activeVibratoLane != nil || !vm.activeLaneIndices.isEmpty)
    }

    var body: some View {
        let boardBg = palette.stageBoardSurface
        let activeCurtainColor: Color? = (vm.cradleEnabled && (vm.isPlaying || (allowsEditing && vm.selectedBeadID != nil)))
            ? vm.chordSpans.first(where: { $0.id == vm.activeChordSpanID })?.chord.color(isNight: palette.isNight)
            : nil

        return GeometryReader { geo in
            let innerSize = geo.size
            ZStack {
                stageInteractiveCanvas
                    .modifier(StagePlaybackNavigationActions(vm: vm))
                    .modifier(StageBeatEditActions(vm: vm, isEnabled: allowsEditing))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                if !isActivelyDraggingStage {
                                    isActivelyDraggingStage = true
                                }
                                switch vm.visualMode {
                                case .orbitalDisc:
                                    handleOrbitalDragChanged(val, in: innerSize)
                                case .flowingRiver:
                                    handleRiverDragChanged(val, in: innerSize)
                                case .resonanceNebula:
                                    handleNebulaDragChanged(val, in: innerSize)
                                }
                            }
                            .onEnded { val in
                                isActivelyDraggingStage = false
                                switch vm.visualMode {
                                case .orbitalDisc:
                                    handleOrbitalDragEnded(val, in: innerSize)
                                case .flowingRiver:
                                    handleRiverDragEnded(val, in: innerSize)
                                case .resonanceNebula:
                                    handleNebulaDragEnded(val, in: innerSize)
                                }
                            }
                    )

                if vm.document.notes.isEmpty {
                    emptyOverlay()
                }

                // 顶部左：声学状态按钮 + 右：三态视窗切换仪（零阴影画布静谧相框）
                VStack(spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        if vm.shadowCounterpointEnabled
                            || abs(vm.playbackRate - 1.0) > 0.01
                            || vm.document.rootMIDI != 60
                            || vm.document.grooveStrength > 0.08 {
                            activeFeaturesOverlay
                        }
                        Spacer(minLength: 4)
                        modeReliefPillSwitcher
                    }
                    if let errorMsg = vm.statusToast {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2.weight(.bold))
                            Text(errorMsg)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.prominentFill)
                        )
                        .transition(.opacity)
                    }
                    Spacer()
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous)
                    .fill(boardBg)
                    .shadow(
                        color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.28),
                        radius: 8,
                        y: 4
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ChimmoRadius.stage, style: .continuous)
                    .strokeBorder(
                        (activeCurtainColor ?? palette.primaryInk).opacity(
                            activeCurtainColor != nil ? 0.55 : (palette.isNight ? 0.12 : 0.08)
                        ),
                        lineWidth: activeCurtainColor != nil ? 1.6 : 1.0
                    )
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: vm.activeChordSpanID)
        }
        .frame(minHeight: 220, maxHeight: .infinity)
        .onChange(of: wakeSignal) { _, _ in
            wakeRippleTimeline()
        }
        .onChange(of: vm.latestDegree) { _, _ in
            wakeRippleTimeline()
        }
        .onChange(of: vm.followGlowIndex) { _, _ in
            wakeRippleTimeline()
        }
        .onChange(of: vm.document.id) { _, _ in
            manualRiverScrollX = 0
            coastTask?.cancel()
            coastTask = nil
            rippleWakeTask?.cancel()
            rippleWakeTask = nil
            vm.endStarVibrato()
            wakeRippleTimeline()
        }
        .onChange(of: vm.visualMode) { _, _ in
            struckNebulaLane = nil
            vm.endStarVibrato()
        }
        .onChange(of: vm.followGlowActive) { _, _ in
            vm.endStarVibrato()
        }
        .onDisappear {
            struckNebulaLane = nil
            vm.endStarVibrato()
            rippleWakeTask?.cancel()
            rippleWakeTask = nil
            coastTask?.cancel()
            coastTask = nil
            rippleWakeActive = false
        }
    }

    private func wakeRippleTimeline() {
        guard !reduceMotion else { return }
        rippleWakeActive = true
        rippleWakeTask?.cancel()
        rippleWakeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            if !Task.isCancelled {
                rippleWakeActive = false
            }
        }
    }

    private var modeReliefPillSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(StageVisualMode.displayOrder) { mode in
                let active = vm.visualMode == mode
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                        vm.visualMode = mode
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                            .font(.caption.weight(.bold))
                        if active {
                            Text(mode.storybookLabel)
                                .font(.system(.caption2, design: .rounded).weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(StorybookAffordanceMetrics.compactPillMinimumScaleFactor)
                        }
                    }
                    .padding(.horizontal, active ? 10 : 9)
                    .frame(minWidth: active ? 62 : 38, minHeight: 36)
                    .background(
                        Capsule().fill(active ? palette.prominentFill : Color.clear)
                    )
                    .foregroundStyle(active ? Color.white : palette.secondaryInk)
                    .frame(
                        minWidth: active ? 62 : StorybookAffordanceMetrics.compactToolMinHitDimension,
                        minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                .accessibilityLabel("切换到\(mode.storybookLabel)视图")
            }
        }
        .fixedSize()
        .padding(3)
        .background(
            Capsule()
                .fill(palette.cardSurface)
                .shadow(
                    color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.24),
                    radius: 4,
                    y: 2
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                            lineWidth: 0.9
                        )
                )
        )
        .contentShape(Capsule())
    }

    private var stageInteractiveCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldRunCanvasTimeline)) { _ in
            let mediaNow = CACurrentMediaTime()
            let _ = scrubTick
            Canvas { ctx, size in
                switch vm.visualMode {
                case .orbitalDisc:
                    drawOrbitalDiscCanvas(ctx: &ctx, size: size, mediaNow: mediaNow)
                case .flowingRiver:
                    drawFlowingRiverCanvas(ctx: &ctx, size: size, mediaNow: mediaNow)
                case .resonanceNebula:
                    drawResonanceNebulaCanvas(ctx: &ctx, size: size, mediaNow: mediaNow)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(vm.stageAccessibilitySummary)
        .accessibilityAdjustableAction { direction in
            guard allowsEditing else { return }
            switch direction {
            case .increment:
                if selectedBeatIndex == nil, let first = vm.document.notes.first {
                    vm.selectBead(first.id, playContext: true)
                } else {
                    vm.stepSelectedBeat(delta: 1)
                }
            case .decrement:
                if selectedBeatIndex == nil, let first = vm.document.notes.first {
                    vm.selectBead(first.id, playContext: true)
                } else {
                    vm.stepSelectedBeat(delta: -1)
                }
            @unknown default:
                break
            }
        }
    }

    private var activeFeaturesOverlay: some View {
        Button {
            onOpenSoundSheet()
        } label: {
            HStack(spacing: 6) {
                if vm.shadowCounterpointEnabled {
                    ChimmoCraftMark(.counterpointMoons, color: palette.counterpointMoon)
                        .frame(width: 12, height: 12)
                }
                if abs(vm.playbackRate - 1.0) > 0.01 {
                    HStack(spacing: 3) {
                        ChimmoCraftMark(.tempoDial, color: palette.nightLampGold)
                            .frame(width: 11, height: 11)
                        Text(String(format: "%.2g×", vm.playbackRate))
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(palette.nightLampGold)
                }
                if vm.document.rootMIDI != 60 {
                    HStack(spacing: 2) {
                        Image(systemName: "tuningfork")
                            .font(.caption2.weight(.bold))
                        Text(RootTranspositionHelper.compactLabel(forRootMIDI: vm.document.rootMIDI))
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(palette.harmonyWash)
                }
                if vm.document.grooveStrength > 0.08 {
                    Image(systemName: "metronome")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.homeAnchor)
                }
                Image(systemName: "slider.horizontal.3")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
            .background(
                Capsule()
                    .fill(palette.cardSurface)
                    .shadow(
                        color: palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.24),
                        radius: 4,
                        y: 2
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                lineWidth: 0.9
                            )
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
        .accessibilityLabel("打开声音设置调整伴唱、音区与节奏")
    }

    // MARK: - 2A. Minimalist Storybook Music-Box Wreath Rendering

    private struct OrbitalMetrics {
        let center: CGPoint
        let haloRadius: CGFloat
        let platterRadius: CGFloat
        let innerRadius: CGFloat
        let outerRadius: CGFloat
    }

    private func orbitalMetrics(for size: CGSize) -> OrbitalMetrics {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
        let maxR = min(size.width, size.height) * 0.432
        let haloRadius = maxR * 0.98
        let platterRadius = maxR * 0.89
        let innerRadius = platterRadius * 0.31
        let outerRadius = platterRadius * 0.90
        return OrbitalMetrics(
            center: center,
            haloRadius: haloRadius,
            platterRadius: platterRadius,
            innerRadius: innerRadius,
            outerRadius: outerRadius
        )
    }

    private func drawOrbitalDiscCanvas(ctx: inout GraphicsContext, size: CGSize, mediaNow: Double) {
        let m = orbitalMetrics(for: size)
        let acoustic = currentAcousticEnvelope
        let total = max(0.5, vm.document.totalDuration)
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let rotTurns = vm.clock.continuousRotationTurns(at: mediaNow)
        let discRot: Double = reduceMotion ? 0.0 : (currentTime != nil ? -(rotTurns * 2.0 * Double.pi) : 0.0)
        let needleAngle: Double = (reduceMotion && currentTime != nil)
            ? (-Double.pi / 2.0 + ((currentTime! / total) * 2.0 * Double.pi))
            : (-Double.pi / 2.0)

        // 1. 外环 4 幕彩色情绪光弧 + 珍珠锚点（无悬浮文字干扰）
        let spans = vm.chordSpans
        if !spans.isEmpty {
            for span in spans {
                let a0 = -Double.pi / 2.0 + (span.startTime / total) * 2.0 * Double.pi + discRot + 0.03
                let a1 = -Double.pi / 2.0 + (span.endTime / total) * 2.0 * Double.pi + discRot - 0.03
                guard a1 > a0 else { continue }
                let isCurrentSpan = (span.id == vm.activeChordSpanID) && (currentTime != nil)
                var arc = Path()
                arc.addArc(center: m.center, radius: m.haloRadius, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                let col = span.chord.color(isNight: palette.isNight)
                if isCurrentSpan {
                    ctx.stroke(
                        arc,
                        with: .color(col.opacity(0.24)),
                        style: StrokeStyle(lineWidth: 11.0, lineCap: .round)
                    )
                }
                ctx.stroke(
                    arc,
                    with: .color(col.opacity(isCurrentSpan ? 0.94 : 0.34)),
                    style: StrokeStyle(lineWidth: isCurrentSpan ? 6.0 : 3.2, lineCap: .round)
                )

                let midA = (a0 + a1) * 0.5
                let pearlPt = CGPoint(
                    x: m.center.x + CGFloat(cos(midA)) * m.haloRadius,
                    y: m.center.y + CGFloat(sin(midA)) * m.haloRadius
                )
                let pearlR: CGFloat = isCurrentSpan ? 3.5 : 2.1
                let pearlRect = CGRect(x: pearlPt.x - pearlR, y: pearlPt.y - pearlR, width: pearlR * 2, height: pearlR * 2)
                ctx.fill(Path(ellipseIn: pearlRect), with: .color(isCurrentSpan ? .white : col.opacity(0.75)))
                if isCurrentSpan {
                    ctx.stroke(Path(ellipseIn: pearlRect), with: .color(col), lineWidth: 1.4)
                }
            }
        }

        // 2. 窑纸软胶童书音乐盒花环底盘（零黑胶刻槽、零节拍外圈刻度、柔和接触光影）
        let platterRect = CGRect(
            x: m.center.x - m.platterRadius,
            y: m.center.y - m.platterRadius,
            width: m.platterRadius * 2,
            height: m.platterRadius * 2
        )
        let shadowRect = platterRect.offsetBy(dx: 0, dy: 3.0)
        ctx.fill(
            Path(ellipseIn: shadowRect),
            with: .color(palette.elevationShadow(dayOpacity: 0.09, nightOpacity: 0.28))
        )

        ctx.fill(
            Path(ellipseIn: platterRect),
            with: .color(palette.cardSurface)
        )

        // 柔和发丝级外缘描边 + 轻声响起微暖金呼吸
        ctx.stroke(
            Path(ellipseIn: platterRect),
            with: .color(palette.isNight ? palette.nightLampGold.opacity(0.28) : palette.primaryInk.opacity(0.14)),
            lineWidth: 1.4
        )
        if acoustic.rmsEnergy > 0.01 {
            ctx.stroke(
                Path(ellipseIn: platterRect),
                with: .color(palette.nightLampGold.opacity(acoustic.rmsEnergy * 0.34)),
                lineWidth: 2.8 + CGFloat(acoustic.rmsEnergy) * 2.2
            )
        }

        // 12 点钟外圈固定暖金菱形定锚点
        let dCenter = CGPoint(x: m.center.x, y: m.center.y - m.platterRadius - 3.0)
        var diamond = Path()
        diamond.move(to: CGPoint(x: dCenter.x, y: dCenter.y - 4.5))
        diamond.addLine(to: CGPoint(x: dCenter.x + 4.0, y: dCenter.y))
        diamond.addLine(to: CGPoint(x: dCenter.x, y: dCenter.y + 4.5))
        diamond.addLine(to: CGPoint(x: dCenter.x - 4.0, y: dCenter.y))
        diamond.closeSubpath()
        ctx.fill(diamond, with: .color(palette.nightLampGold.opacity(0.92)))

        // 节拍律动辐射引力线（仅当开启「微稳/整齐」律动吸附时温柔显影，随花环共转）
        if vm.document.grooveStrength > 0.08 {
            let beatStep = GrooveAlignmentEngine.estimatedBeatStep(for: vm.document.notes)
            let spokes = GrooveAlignmentEngine.beatSpokeAngles(
                totalDuration: total,
                grooveStrength: vm.document.grooveStrength,
                beatStep: beatStep
            )
            for (idx, baseAng) in spokes.enumerated() {
                let ang = -Double.pi / 2.0 + baseAng + discRot
                let isMajor = idx % 4 == 0
                let rIn = m.innerRadius * 0.96
                let rOut = m.outerRadius * 1.03
                var spoke = Path()
                spoke.move(to: CGPoint(x: m.center.x + CGFloat(cos(ang)) * rIn, y: m.center.y + CGFloat(sin(ang)) * rIn))
                spoke.addLine(to: CGPoint(x: m.center.x + CGFloat(cos(ang)) * rOut, y: m.center.y + CGFloat(sin(ang)) * rOut))
                ctx.stroke(
                    spoke,
                    with: .color(palette.nightLampGold.opacity(vm.document.grooveStrength * (palette.isNight ? (isMajor ? 0.24 : 0.12) : (isMajor ? 0.22 : 0.11)))),
                    style: StrokeStyle(lineWidth: isMajor ? 1.2 : 0.65, lineCap: .round)
                )
            }
        }

        // 3. 8 条同心彩虹音高轨道
        for laneIdx in 0..<8 {
            let lane = XylophoneLane.lane(at: laneIdx)
            let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
            let ringRect = CGRect(x: m.center.x - r, y: m.center.y - r, width: r * 2, height: r * 2)
            let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
            let isActiveLane = vm.activeLaneIndices.contains(laneIdx)
            let isFollowTarget = targetFollowLaneIndex == laneIdx
            let col = lane.barColor(isNight: palette.isNight)

            let isAnchor = PreLinguisticGuideGeometry.isStructuralAnchorLane(laneIdx)
            let baseW: CGFloat = laneIdx == 0 ? 1.55 : (isAnchor ? 1.25 : 0.85)
            let lineW: CGFloat = (isActiveLane || isFollowTarget) ? 2.4 : baseW
            let baseAlpha: Double = isAnchor ? (palette.isNight ? 0.34 : 0.38) : (palette.isNight ? 0.22 : 0.24)
            let alpha: Double = isMuted ? 0.14 : ((isActiveLane || isFollowTarget) ? 0.85 : baseAlpha)

            if isMuted {
                ctx.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(col.opacity(alpha)),
                    style: StrokeStyle(lineWidth: 0.9, dash: [3, 4])
                )
            } else {
                ctx.stroke(Path(ellipseIn: ringRect), with: .color(col.opacity(alpha)), lineWidth: lineW)
            }
        }

        // 4. 张力引力指示小刻度（4→3 向内吸附，7→1↑ 向外归家）
        if !vm.pentatonicSafe {
            drawOrbitalTensionTick(ctx: &ctx, center: m.center, radius: OrbitalGeometry.orbitRadius(laneIndex: 3, innerRadius: m.innerRadius, outerRadius: m.outerRadius), inward: true, color: XylophoneLane.lane(at: 3).barColor(isNight: palette.isNight))
            drawOrbitalTensionTick(ctx: &ctx, center: m.center, radius: OrbitalGeometry.orbitRadius(laneIndex: 6, innerRadius: m.innerRadius, outerRadius: m.outerRadius), inward: false, color: XylophoneLane.lane(at: 6).barColor(isNight: palette.isNight))
        }

        // 4.5 空画布呼吸引导环（静态温柔金圈邀请轻触落音，零文字说明）
        if notesIsEmptyPlaceholder(notes: vm.document.notes) {
            for ring in PreLinguisticGuideGeometry.emptyCanvasPulseRadii(phase: 0.28, maxRadius: m.outerRadius * 0.85) {
                let rRect = CGRect(x: m.center.x - ring.radius, y: m.center.y - ring.radius, width: ring.radius * 2, height: ring.radius * 2)
                ctx.stroke(
                    Path(ellipseIn: rRect),
                    with: .color(palette.nightLampGold.opacity(ring.opacity * 0.72)),
                    style: StrokeStyle(lineWidth: 1.6, dash: [4, 6])
                )
            }
        }

        // 5. 音符星座连线 + 音珠时长尾弧 + 三重无障碍音珠本体
        let notes = vm.document.notes.sorted {
            $0.displayOnset(grooveStrength: vm.document.grooveStrength) < $1.displayOnset(grooveStrength: vm.document.grooveStrength)
        }
        var jewelData: [(idx: Int, bead: NoteBead, pt: CGPoint, laneIdx: Int, angle: Double, r: CGFloat)] = []

        for (idx, bead) in notes.enumerated() {
            let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let ang = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: onset, totalDuration: total) + discRot
            let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
            let pt = CGPoint(x: m.center.x + CGFloat(cos(ang)) * r, y: m.center.y + CGFloat(sin(ang)) * r)
            jewelData.append((idx, bead, pt, laneIdx, ang, r))
        }

        if jewelData.count > 1 {
            for i in 1..<jewelData.count {
                let d0 = jewelData[i - 1]
                let d1 = jewelData[i]
                let p0 = d0.pt
                let p1 = d1.pt
                let mid = CGPoint(
                    x: (p0.x + p1.x) * 0.5 + (m.center.x - (p0.x + p1.x) * 0.5) * 0.14,
                    y: (p0.y + p1.y) * 0.5 + (m.center.y - (p0.y + p1.y) * 0.5) * 0.14
                )
                var seg = Path()
                seg.move(to: p0)
                seg.addQuadCurve(to: p1, control: mid)
                strokeChromaticSegment(
                    ctx: &ctx,
                    path: seg,
                    startPt: p0,
                    endPt: p1,
                    fromLane: d0.laneIdx,
                    toLane: d1.laneIdx,
                    extraEnergy: acoustic.rmsEnergy
                )
            }
        }

        // 5.4 选中音符的径向调音滑轨（仅创作编辑模式显示，避免赏析经典时误导）
        if allowsEditing,
           !vm.isPlaying,
           !vm.followGlowActive,
           let selID = vm.selectedBeadID,
           let selEntry = jewelData.first(where: { $0.bead.id == selID }) {
            let ticks = PreLinguisticGuideGeometry.selectionTractionTicks(
                center: m.center,
                angle: selEntry.angle,
                innerRadius: m.innerRadius,
                outerRadius: m.outerRadius
            )
            var rail = Path()
            rail.move(to: ticks.inner)
            rail.addLine(to: ticks.outer)
            ctx.stroke(
                rail,
                with: .color(palette.nightLampGold.opacity(0.65)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])
            )
            for endpoint in [ticks.inner, ticks.outer] {
                let dotRect = CGRect(x: endpoint.x - 2.6, y: endpoint.y - 2.6, width: 5.2, height: 5.2)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(palette.nightLampGold.opacity(0.88)))
            }
        }

        // 5.5 验光师 3 选 1 智慧亮环（选中某一拍且开启亮灯帮找时，在同一角度上点亮 3 条候选轨道）
        if vm.smartHintActive,
           let selID = vm.selectedBeadID,
           let selEntry = jewelData.first(where: { $0.bead.id == selID }) {
            for hint in vm.smartHints {
                let hr = OrbitalGeometry.orbitRadius(laneIndex: hint.laneIndex, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
                let hPt = CGPoint(x: m.center.x + CGFloat(cos(selEntry.angle)) * hr, y: m.center.y + CGFloat(sin(selEntry.angle)) * hr)
                let hRect = CGRect(x: hPt.x - 10, y: hPt.y - 10, width: 20, height: 20)
                ctx.stroke(Path(ellipseIn: hRect), with: .color(palette.nightLampGold.opacity(0.95)), lineWidth: 2.2)
                ctx.fill(Path(ellipseIn: hRect), with: .color(palette.nightLampGold.opacity(0.24)))
            }
        }

        var followTargetPt: CGPoint? = nil
        for item in jewelData {
            if vm.followGlowActive && item.idx == vm.followGlowIndex {
                followTargetPt = item.pt
            }
            let lane = XylophoneLane.lane(at: item.laneIdx)
            let col = lane.barColor(isNight: palette.isNight)
            let dur = item.bead.displayDuration(grooveStrength: vm.document.grooveStrength)
            let onset = item.bead.displayOnset(grooveStrength: vm.document.grooveStrength)

            let isSelected = allowsEditing && vm.selectedBeadID == item.bead.id
            let isFollowCur = vm.followGlowActive && vm.followGlowIndex == item.idx
            let isFollowPassed = vm.followGlowActive && item.idx < vm.followGlowIndex
            let isSingingNow: Bool = {
                guard let ct = currentTime else { return false }
                return ct >= onset - 0.04 && ct <= onset + max(0.18, dur * 0.9)
            }()

            // 时长尾弧（双层柔和发光拖尾，直观看见长音与短音）
            let arcSpan = min(Double.pi * 0.45, max(0.06, (dur / total) * 2.0 * Double.pi * 0.78))
            var tailArc = Path()
            tailArc.addArc(
                center: m.center,
                radius: item.r,
                startAngle: .radians(item.angle),
                endAngle: .radians(item.angle + arcSpan),
                clockwise: false
            )
            ctx.stroke(
                tailArc,
                with: .color(col.opacity(isFollowPassed ? 0.14 : (isSingingNow ? 0.36 : 0.22))),
                style: StrokeStyle(lineWidth: isSingingNow ? 10.5 : 7.5, lineCap: .round)
            )
            ctx.stroke(
                tailArc,
                with: .color(col.opacity(isFollowPassed ? 0.28 : 0.80)),
                style: StrokeStyle(lineWidth: isSingingNow ? 5.5 : 3.8, lineCap: .round)
            )

            // 音珠主圆球（外柔光晕 + 釉面陶瓷本体 + 顶部玻璃反光月牙 + 色盲几何图腾）
            let orbR: CGFloat = (isSingingNow || isFollowCur) ? 12.6 : (isSelected ? 11.6 : 9.6)
            let orbRect = CGRect(x: item.pt.x - orbR, y: item.pt.y - orbR, width: orbR * 2, height: orbR * 2)

            if isSingingNow || isFollowCur {
                let bloomR = orbR + 7.0
                let bloomRect = CGRect(x: item.pt.x - bloomR, y: item.pt.y - bloomR, width: bloomR * 2, height: bloomR * 2)
                ctx.fill(
                    Path(ellipseIn: bloomRect),
                    with: .color((isFollowCur ? palette.nightLampGold : col).opacity(0.32))
                )
            }

            if isSingingNow || isFollowCur || isSelected {
                let haloR = orbR + 4.5
                let haloRect = CGRect(x: item.pt.x - haloR, y: item.pt.y - haloR, width: haloR * 2, height: haloR * 2)
                ctx.stroke(
                    Path(ellipseIn: haloRect),
                    with: .color((isFollowCur ? palette.nightLampGold : palette.primaryInk).opacity(0.9)),
                    lineWidth: 2.0
                )
            }

            ctx.fill(Path(ellipseIn: orbRect), with: .color(col.opacity(isFollowPassed ? 0.45 : 1.0)))
            ctx.stroke(
                Path(ellipseIn: orbRect),
                with: .color(palette.primaryInk.opacity(isFollowPassed ? 0.18 : (palette.isNight ? 0.34 : 0.24))),
                lineWidth: 1.2
            )

            // 色盲友好八音阶几何矢量图腾
            let glyphSize = orbR * 1.15
            let glyphRect = CGRect(x: item.pt.x - glyphSize * 0.5, y: item.pt.y - glyphSize * 0.5, width: glyphSize, height: glyphSize)
            let glyphPath = PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: glyphRect)
            let glyphInk = XylophoneLane.lane(at: item.laneIdx).barForegroundColor(isNight: palette.isNight)
            ctx.fill(glyphPath, with: .color(glyphInk.opacity(0.94)), style: FillStyle(eoFill: true))
        }

        // 5.8 巴赫影子月亮对位副音珠（在主旋律留白处轻声对话，呈半透明银蓝新月浮在内偏轨道）
        if vm.shadowCounterpointEnabled {
            for shadow in vm.shadowNotes {
                let sLaneIdx = XylophoneLane.laneIndex(degree: shadow.degree, octaveOffset: shadow.octaveOffset)
                let sAng = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: shadow.onset, totalDuration: total) + discRot
                let baseR = OrbitalGeometry.orbitRadius(laneIndex: sLaneIdx, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
                let sRadius = max(m.innerRadius * 0.90, baseR - 6.0)
                let sPt = CGPoint(x: m.center.x + CGFloat(cos(sAng)) * sRadius, y: m.center.y + CGFloat(sin(sAng)) * sRadius)
                let isShadowSinging: Bool = {
                    guard let ct = currentTime else { return false }
                    return ct >= shadow.onset - 0.04 && ct <= shadow.onset + max(0.20, shadow.duration * 0.9)
                }()

                var tether = Path()
                tether.move(to: m.center)
                tether.addLine(to: sPt)
                ctx.stroke(
                    tether,
                    with: .color(palette.counterpointMoon.opacity(isShadowSinging ? 0.34 : 0.10)),
                    style: StrokeStyle(lineWidth: 0.9, dash: [2, 3])
                )
                drawCrescentMoonOrb(
                    ctx: &ctx,
                    center: sPt,
                    radius: isShadowSinging ? 9.5 : 7.4,
                    color: palette.counterpointMoon,
                    isGlowing: isShadowSinging
                )
            }
        }

        // 6. 中央利萨如谐振花纹玻璃圆心（实时映照当前声学和谐比例与实时响度呼吸）
        drawCenterMandalaHub(ctx: &ctx, center: m.center, hubRadius: m.innerRadius * 0.76, mediaNow: mediaNow, acoustic: acoustic)

        // 7. 12 点钟金色书签丝带阅读指针与声波涟漪绽放 + 跟灯弹光桥
        if vm.followGlowActive,
           let targetLane = targetFollowLaneIndex,
           let targetPt = followTargetPt {
            drawFollowLightBridge(ctx: &ctx, from: targetPt, toLaneIndex: targetLane, canvasSize: size)
        }
        drawRipplesOnDisc(ctx: &ctx, metrics: m, discRot: discRot, needleAngle: needleAngle, mediaNow: mediaNow)
        drawWreathBookmarkPointer(ctx: &ctx, metrics: m, needleAngle: needleAngle, isPlaying: vm.isPlaying, mediaNow: mediaNow)
    }

    private var currentAcousticEnvelope: AcousticEnvelopeSnapshot {
        reduceMotion ? .silent : vm.synth.currentAcousticEnvelope()
    }

    private func notesIsEmptyPlaceholder(notes: [NoteBead]) -> Bool {
        notes.isEmpty
    }

    private func strokeChromaticSegment(
        ctx: inout GraphicsContext,
        path: Path,
        startPt: CGPoint,
        endPt: CGPoint,
        fromLane: Int,
        toLane: Int,
        widthScale: CGFloat = 1.0,
        extraEnergy: Double = 0.0
    ) {
        let c1 = XylophoneLane.lane(at: toLane).barColor(isNight: palette.isNight)
        let style = IntervalSilkStyle.metrics(fromLane: fromLane, toLane: toLane, isNight: palette.isNight)
        if style.glowWidth > 0 {
            let glowOp = min(0.55, style.glowOpacity + extraEnergy * 0.14)
            ctx.stroke(
                path,
                with: .color(c1.opacity(glowOp)),
                style: StrokeStyle(lineWidth: style.glowWidth * widthScale + CGFloat(extraEnergy) * 2.5, lineCap: .round)
            )
        }
        let coreOp = min(1.0, style.coreOpacity + extraEnergy * 0.20)
        ctx.stroke(
            path,
            with: .color(c1.opacity(coreOp)),
            style: StrokeStyle(lineWidth: style.coreWidth * widthScale, lineCap: .round)
        )
    }

    private func drawFollowLightBridge(
        ctx: inout GraphicsContext,
        from stagePoint: CGPoint,
        toLaneIndex laneIndex: Int,
        canvasSize: CGSize
    ) {
        let bridge = PreLinguisticGuideGeometry.followLightBridgePath(
            from: stagePoint,
            toLaneIndex: laneIndex,
            canvasSize: canvasSize
        )
        var path = Path()
        path.move(to: bridge.start)
        path.addQuadCurve(to: bridge.end, control: bridge.control)
        ctx.stroke(
            path,
            with: .color(palette.nightLampGold.opacity(0.24)),
            style: StrokeStyle(lineWidth: 7.0, lineCap: .round)
        )
        ctx.stroke(
            path,
            with: .color(palette.nightLampGold.opacity(0.92)),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [5, 5])
        )
        let tipRect = CGRect(x: bridge.end.x - 4.0, y: bridge.end.y - 4.0, width: 8.0, height: 8.0)
        ctx.fill(Path(ellipseIn: tipRect), with: .color(palette.nightLampGold))
    }

    private func drawCrescentMoonOrb(
        ctx: inout GraphicsContext,
        center: CGPoint,
        radius r: CGFloat,
        color: Color,
        isGlowing: Bool
    ) {
        if isGlowing {
            let glowR = r + 5.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)),
                with: .color(color.opacity(0.28))
            )
        }
        var crescent = Path()
        let topTip = CGPoint(x: center.x + r * 0.35, y: center.y - r * 0.86)
        let botTip = CGPoint(x: center.x + r * 0.35, y: center.y + r * 0.86)
        crescent.move(to: topTip)
        crescent.addCurve(
            to: botTip,
            control1: CGPoint(x: center.x - r * 1.05, y: center.y - r * 0.55),
            control2: CGPoint(x: center.x - r * 1.05, y: center.y + r * 0.55)
        )
        crescent.addCurve(
            to: topTip,
            control1: CGPoint(x: center.x - r * 0.20, y: center.y + r * 0.42),
            control2: CGPoint(x: center.x - r * 0.20, y: center.y - r * 0.42)
        )
        crescent.closeSubpath()

        ctx.fill(crescent, with: .color(color.opacity(isGlowing ? 0.94 : 0.72)))
        ctx.stroke(crescent, with: .color(.white.opacity(isGlowing ? 0.88 : 0.52)), lineWidth: 0.9)
    }

    private func drawLissajousWave(
        ctx: inout GraphicsContext,
        center: CGPoint,
        amplitude: CGFloat,
        mediaNow: Double,
        acoustic: AcousticEnvelopeSnapshot = .silent,
        glowWidth: CGFloat = 4.0,
        coreWidth: CGFloat = 1.5
    ) {
        let phys = vm.activeHarmonyPhysics
        let tension = 1.0 - phys.consonance
        let phase = reduceMotion ? 0.45 : mediaNow * (0.45 + tension * 2.0)
        let modAmp = amplitude * (1.0 + CGFloat(acoustic.rmsEnergy) * 0.24)
        var wave = Path()
        let steps = 110
        for i in 0...steps {
            let u = (Double(i) / Double(steps)) * Double.pi * 2.0
            let x = center.x + CGFloat(sin(Double(phys.ratioA) * u + phase)) * modAmp
            let y = center.y + CGFloat(sin(Double(phys.ratioB) * u)) * modAmp
            if i == 0 { wave.move(to: CGPoint(x: x, y: y)) } else { wave.addLine(to: CGPoint(x: x, y: y)) }
        }
        let lineCol = phys.isTense ? palette.tensionFilament : palette.homeAnchor
        let modGlowW = glowWidth + CGFloat(acoustic.shimmerEnergy) * 3.8
        ctx.stroke(
            wave,
            with: .color(lineCol.opacity(0.28 + acoustic.shimmerEnergy * 0.22)),
            style: StrokeStyle(lineWidth: modGlowW, lineCap: .round)
        )
        ctx.stroke(wave, with: .color(lineCol.opacity(0.90)), style: StrokeStyle(lineWidth: coreWidth, lineCap: .round))
    }

    private func drawOrbitalTensionTick(ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, inward: Bool, color: Color) {
        let ang = -Double.pi * 0.25
        let pt = CGPoint(x: center.x + CGFloat(cos(ang)) * radius, y: center.y + CGFloat(sin(ang)) * radius)
        let dir: CGFloat = inward ? -7 : 7
        var p = Path()
        p.move(to: pt)
        p.addLine(to: CGPoint(x: pt.x + CGFloat(cos(ang)) * dir, y: pt.y + CGFloat(sin(ang)) * dir))
        ctx.stroke(p, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private func drawCenterMandalaHub(
        ctx: inout GraphicsContext,
        center: CGPoint,
        hubRadius: CGFloat,
        mediaNow: Double,
        acoustic: AcousticEnvelopeSnapshot = .silent
    ) {
        if acoustic.warmthEnergy > 0.01 {
            let auraR = hubRadius + 4.0 + CGFloat(acoustic.warmthEnergy) * 9.0
            let auraRect = CGRect(x: center.x - auraR, y: center.y - auraR, width: auraR * 2, height: auraR * 2)
            ctx.stroke(
                Path(ellipseIn: auraRect),
                with: .color(palette.nightLampGold.opacity(acoustic.warmthEnergy * 0.28)),
                lineWidth: 2.2 + CGFloat(acoustic.warmthEnergy) * 3.2
            )
        }

        let hubRect = CGRect(x: center.x - hubRadius, y: center.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2)
        ctx.fill(
            Path(ellipseIn: hubRect),
            with: .color(palette.storybookButter)
        )
        ctx.stroke(
            Path(ellipseIn: hubRect),
            with: .color(palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.14)),
            lineWidth: 1.3
        )

        // 利萨如实时波纹花（随声压实时呼吸）
        drawLissajousWave(ctx: &ctx, center: center, amplitude: hubRadius * 0.56, mediaNow: mediaNow, acoustic: acoustic)

        // 暂停态提示可轻点圆心起转
        if !vm.isPlaying && !vm.followGlowActive && !vm.document.notes.isEmpty {
            let triR = hubRadius * 0.22
            var playTri = Path()
            playTri.move(to: CGPoint(x: center.x - triR * 0.55, y: center.y - triR * 0.8))
            playTri.addLine(to: CGPoint(x: center.x + triR * 0.95, y: center.y))
            playTri.addLine(to: CGPoint(x: center.x - triR * 0.55, y: center.y + triR * 0.8))
            playTri.closeSubpath()
            ctx.fill(playTri, with: .color(palette.nightLampGold.opacity(0.32)))
        }

        // 中心软胶暖金轴心点
        let pinRect = CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9.0, height: 9.0)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(palette.nightLampGold))
        ctx.stroke(Path(ellipseIn: pinRect), with: .color(palette.primaryInk.opacity(palette.isNight ? 0.45 : 0.35)), lineWidth: 1.2)
    }

    private func drawRipplesOnDisc(ctx: inout GraphicsContext, metrics: OrbitalMetrics, discRot: Double, needleAngle: Double, mediaNow: Double) {
        let active = vm.rippleBus.activeEvents(at: mediaNow)
        for ev in active {
            let age = mediaNow - ev.birthMediaTime
            let prog = max(0.0, min(1.0, age / 0.90))
            let rOrbit = OrbitalGeometry.orbitRadius(laneIndex: ev.laneIndex, innerRadius: metrics.innerRadius, outerRadius: metrics.outerRadius)
            let ang = vm.isPlaying ? needleAngle : (-Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: ev.onset, totalDuration: max(0.5, vm.document.totalDuration)) + discRot)
            let pt = CGPoint(x: metrics.center.x + CGFloat(cos(ang)) * rOrbit, y: metrics.center.y + CGFloat(sin(ang)) * rOrbit)
            let col = ev.isShadow ? palette.counterpointMoon : Color(hex: ev.colorHex)

            let dynScale: CGFloat = ev.isShadow ? 1.0 : CGFloat(0.72 + ev.intensity * 0.56)
            for ring in 0..<2 {
                let ringR = (ev.isShadow ? 6.0 : 8.0) + CGFloat(prog) * ((ev.isShadow ? 24.0 : 36.0 * dynScale) + CGFloat(ring) * 12.0)
                let rect = CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2)
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(col.opacity((1.0 - prog) * (ev.isShadow ? 0.48 : (ring == 0 ? 0.72 : 0.36)))),
                    lineWidth: ev.isShadow ? 1.5 : 2.0
                )
            }

            // 零堆分配星尘迸溅微粒（主音珠发声时迸溅 8 颗微粒，随击打力度放大扩散范围）
            if !reduceMotion && !ev.isShadow {
                let baseSeed = ev.birthMediaTime * 13.7 + Double(ev.laneIndex) * 2.3
                for pIdx in 0..<8 {
                    let pAng = baseSeed + Double(pIdx) * (Double.pi * 2.0 / 8.0)
                    let pDist = (10.0 + prog * (28.0 + Double(pIdx % 3) * 9.0)) * Double(dynScale)
                    let px = pt.x + CGFloat(cos(pAng) * pDist)
                    let py = pt.y + CGFloat(sin(pAng) * pDist)
                    let pr: CGFloat = (pIdx % 2 == 0) ? 2.2 : 1.5
                    let pAlpha = (1.0 - prog) * 0.85
                    let pCol = (pIdx % 3 == 0) ? palette.nightLampGold : col
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                        with: .color(pCol.opacity(pAlpha))
                    )
                }
            }
        }
    }

    private func drawWreathBookmarkPointer(ctx: inout GraphicsContext, metrics: OrbitalMetrics, needleAngle: Double, isPlaying: Bool, mediaNow: Double) {
        // 绘本轻跳回应：仅主旋律音珠经过阅读丝线 0.18 秒内激发轻微阻尼弹跳
        var kickOffset: CGFloat = 0
        if !reduceMotion, let newest = vm.rippleBus.events.last(where: { !$0.isShadow }) {
            let age = mediaNow - newest.birthMediaTime
            if age >= 0 && age < 0.18 {
                kickOffset = CGFloat(sin(age * 35.0) * exp(-age * 14.0) * 3.0)
            }
        }

        // 12 点钟发光书签读取线（极简轻盈，告别厚重唱臂机械）
        let innerEdge = CGPoint(
            x: metrics.center.x + CGFloat(cos(needleAngle)) * (metrics.innerRadius * 0.85),
            y: metrics.center.y + CGFloat(sin(needleAngle)) * (metrics.innerRadius * 0.85)
        )
        let outerEdge = CGPoint(
            x: metrics.center.x + CGFloat(cos(needleAngle)) * (metrics.outerRadius + 9) + kickOffset * 0.45,
            y: metrics.center.y + CGFloat(sin(needleAngle)) * (metrics.outerRadius + 9)
        )
        var beam = Path()
        beam.move(to: innerEdge)
        beam.addLine(to: outerEdge)
        ctx.stroke(
            beam,
            with: .color(palette.nightLampGold.opacity(isPlaying ? 0.94 : 0.62)),
            style: StrokeStyle(lineWidth: isPlaying ? 3.0 : 2.1, lineCap: .round)
        )

        // 顶端小书签星章（扁平暖墨描边 + 奶油金填充，轻巧标注当前聆听时刻）
        let starCenter = CGPoint(
            x: metrics.center.x + CGFloat(cos(needleAngle)) * (metrics.outerRadius + 13) + kickOffset * 0.6,
            y: metrics.center.y + CGFloat(sin(needleAngle)) * (metrics.outerRadius + 13)
        )
        let starR: CGFloat = 7.2
        let starInner: CGFloat = 3.1
        var star = Path()
        for idx in 0..<8 {
            let ang = Double(idx) * (Double.pi / 4.0)
            let rad = (idx % 2 == 0) ? starR : starInner
            let pt = CGPoint(x: starCenter.x + CGFloat(cos(ang)) * rad, y: starCenter.y + CGFloat(sin(ang)) * rad)
            if idx == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        let inkOutline = palette.primaryInk.opacity(palette.isNight ? 0.38 : 0.28)
        ctx.fill(star, with: .color(palette.nightLampGold))
        ctx.stroke(star, with: .color(inkOutline), lineWidth: 1.2)
    }

    // MARK: - 2B. Full-Width Storybook Hill Score Canvas Rendering

    private func riverLayout(for size: CGSize) -> (anchorX: CGFloat, pxPerSec: CGFloat, padV: CGFloat, rowH: CGFloat, totalDur: Double) {
        let totalDur = max(3.6, vm.document.totalDuration + 0.5)
        let anchorX = size.width * 0.28
        let pxPerSec = max(78.0, (size.width - 48.0) / CGFloat(min(totalDur, 5.4)))
        let padV: CGFloat = 22.0
        let usableH = max(140.0, size.height - padV * 2.0)
        let rowH = usableH / 8.0
        return (anchorX, pxPerSec, padV, rowH, totalDur)
    }

    private func drawFlowingRiverCanvas(ctx: inout GraphicsContext, size: CGSize, mediaNow: Double) {
        let lay = riverLayout(for: size)
        let acoustic = currentAcousticEnvelope
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let scrollX = FlowingRiverGeometry.worldScrollX(
            playheadTime: currentTime,
            manualScrollX: manualRiverScrollX,
            pxPerSecond: lay.pxPerSec
        )

        // 0. 绘本远景柔和草坡剪影（无描边，烘托童书山坡阅读气氛）
        let backProfile = StorybookIllustrationLayout.rollingHillProfile(
            sampleCount: 14,
            amplitude: 0.14,
            phaseShift: 0.5
        )
        if backProfile.count > 1 {
            let hillTop = size.height * 0.72
            var backHill = Path()
            backHill.move(to: CGPoint(x: 0, y: size.height))
            for pt in backProfile {
                let hx = CGFloat(pt.xFraction) * size.width
                let hy = hillTop + CGFloat(pt.yFraction - 0.5) * 32.0
                backHill.addLine(to: CGPoint(x: hx, y: hy))
            }
            backHill.addLine(to: CGPoint(x: size.width, y: size.height))
            backHill.closeSubpath()
            ctx.fill(
                backHill,
                with: .color(palette.storybookHillBack.opacity(palette.isNight ? 0.55 : 0.65))
            )
        }

        // 1. 4 幕和声天光色带背景 + 顶部彩色天际帽条（对齐星盘外环与下方 4 幕色带）
        for span in vm.chordSpans {
            let x0 = FlowingRiverGeometry.screenX(onset: span.startTime, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let x1 = FlowingRiverGeometry.screenX(onset: span.endTime, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let rect = CGRect(x: x0, y: 0, width: max(0, x1 - x0), height: size.height)
            let isCurrent = span.id == vm.activeChordSpanID && currentTime != nil
            let spanCol = span.chord.color(isNight: palette.isNight)
            ctx.fill(Path(rect), with: .color(spanCol.opacity(isCurrent ? 0.12 : 0.045)))

            let capW = max(0, x1 - x0 - 4)
            if capW > 2 {
                let capRect = CGRect(x: x0 + 2, y: 2, width: capW, height: 3.5)
                ctx.fill(
                    Path(roundedRect: capRect, cornerRadius: 1.75),
                    with: .color(spanCol.opacity(isCurrent ? 0.92 : 0.45))
                )
            }
        }

        // 1.5 节拍律动对齐竖线（当开启微稳/整齐模式时随旋律滚动显现）
        if vm.document.grooveStrength > 0.08 {
            let beatStep = GrooveAlignmentEngine.estimatedBeatStep(for: vm.document.notes)
            let stamps = GrooveAlignmentEngine.beatTimestamps(
                totalDuration: max(0.5, vm.document.totalDuration),
                grooveStrength: vm.document.grooveStrength,
                beatStep: beatStep
            )
            for (idx, ts) in stamps.enumerated() {
                let bx = FlowingRiverGeometry.screenX(onset: ts, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
                guard bx >= -4 && bx <= size.width + 4 else { continue }
                let isMajor = idx % 4 == 0
                var bar = Path()
                bar.move(to: CGPoint(x: bx, y: lay.padV * 0.6))
                bar.addLine(to: CGPoint(x: bx, y: size.height - lay.padV * 0.6))
                ctx.stroke(
                    bar,
                    with: .color(palette.nightLampGold.opacity(vm.document.grooveStrength * (isMajor ? 0.24 : 0.11))),
                    style: StrokeStyle(lineWidth: isMajor ? 1.2 : 0.7, dash: isMajor ? [] : [3, 4])
                )
            }
        }

        // 2. 8 条彩色地平线阶梯轨（1 / 5 结构定锚略厚，助零乐理与色弱一眼定位）
        for rowFromTop in 0..<8 {
            let laneIdx = 7 - rowFromTop
            let lane = XylophoneLane.lane(at: laneIdx)
            let y = lay.padV + (CGFloat(rowFromTop) + 0.5) * lay.rowH
            let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
            let isAnchor = PreLinguisticGuideGeometry.isStructuralAnchorLane(laneIdx)
            let col = lane.barColor(isNight: palette.isNight)
            var track = Path()
            track.move(to: CGPoint(x: 0, y: y))
            track.addLine(to: CGPoint(x: size.width, y: y))
            let baseW: CGFloat = isMuted ? 0.7 : (laneIdx == 0 ? 1.60 : (isAnchor ? 1.32 : 0.95))
            let baseAlpha: Double = isMuted ? 0.10 : (isAnchor ? 0.38 : 0.24)
            ctx.stroke(
                track,
                with: .color(col.opacity(baseAlpha)),
                style: StrokeStyle(lineWidth: baseW, dash: isMuted ? [3, 4] : [])
            )
        }

        // 3. 山河剪影轮廓 + 音珠宝石
        let notes = vm.document.notes.sorted {
            $0.displayOnset(grooveStrength: vm.document.grooveStrength) < $1.displayOnset(grooveStrength: vm.document.grooveStrength)
        }
        var pts: [(idx: Int, bead: NoteBead, pt: CGPoint, laneIdx: Int)] = []
        for (idx, bead) in notes.enumerated() {
            let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let x = FlowingRiverGeometry.screenX(onset: onset, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let y = lay.padV + (CGFloat(7 - laneIdx) + 0.5) * lay.rowH
            pts.append((idx, bead, CGPoint(x: x, y: y), laneIdx))
        }

        if pts.count > 1 {
            var curve = Path()
            curve.move(to: pts[0].pt)
            for i in 1..<pts.count {
                let p0 = pts[i - 1].pt
                let p1 = pts[i].pt
                let midX = (p0.x + p1.x) * 0.5
                curve.addCurve(to: p1, control1: CGPoint(x: midX, y: p0.y), control2: CGPoint(x: midX, y: p1.y))
            }

            var mountainFill = curve
            mountainFill.addLine(to: CGPoint(x: pts.last!.pt.x, y: size.height))
            mountainFill.addLine(to: CGPoint(x: pts.first!.pt.x, y: size.height))
            mountainFill.closeSubpath()

            ctx.fill(
                mountainFill,
                with: .color(palette.storybookHillFront.opacity(palette.isNight ? 0.52 : 0.62))
            )
            if acoustic.rmsEnergy > 0.01 {
                ctx.stroke(
                    curve,
                    with: .color(palette.homeAnchor.opacity(0.14 + acoustic.rmsEnergy * 0.24)),
                    style: StrokeStyle(lineWidth: 5.5 + CGFloat(acoustic.rmsEnergy) * 5.0, lineCap: .round)
                )
            }
            for i in 1..<pts.count {
                let d0 = pts[i - 1]
                let d1 = pts[i]
                let midX = (d0.pt.x + d1.pt.x) * 0.5
                var seg = Path()
                seg.move(to: d0.pt)
                seg.addCurve(to: d1.pt, control1: CGPoint(x: midX, y: d0.pt.y), control2: CGPoint(x: midX, y: d1.pt.y))
                strokeChromaticSegment(
                    ctx: &ctx,
                    path: seg,
                    startPt: d0.pt,
                    endPt: d1.pt,
                    fromLane: d0.laneIdx,
                    toLane: d1.laneIdx,
                    widthScale: 1.15,
                    extraEnergy: acoustic.rmsEnergy
                )
            }
        }

        var followTargetPt: CGPoint? = nil
        for item in pts {
            if vm.followGlowActive && item.idx == vm.followGlowIndex {
                followTargetPt = item.pt
            }
            let lane = XylophoneLane.lane(at: item.laneIdx)
            let col = lane.barColor(isNight: palette.isNight)
            let onset = item.bead.displayOnset(grooveStrength: vm.document.grooveStrength)
            let dur = item.bead.displayDuration(grooveStrength: vm.document.grooveStrength)
            let isSelected = allowsEditing && vm.selectedBeadID == item.bead.id
            let isFollowCur = vm.followGlowActive && vm.followGlowIndex == item.idx
            let isSingingNow: Bool = {
                guard let ct = currentTime else { return false }
                return ct >= onset - 0.04 && ct <= onset + max(0.18, dur * 0.9)
            }()

            if allowsEditing && !vm.isPlaying && !vm.followGlowActive && vm.selectedBeadID == item.bead.id {
                var rail = Path()
                rail.move(to: CGPoint(x: item.pt.x, y: lay.padV + 0.5 * lay.rowH))
                rail.addLine(to: CGPoint(x: item.pt.x, y: lay.padV + 7.5 * lay.rowH))
                ctx.stroke(
                    rail,
                    with: .color(palette.nightLampGold.opacity(0.62)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])
                )
            }

            let tailW = max(14.0, CGFloat(dur) * lay.pxPerSec * 0.85)
            let tailCenterY = item.pt.y
            if isSingingNow {
                let glowRect = CGRect(x: item.pt.x, y: tailCenterY - 5.5, width: tailW, height: 11.0)
                ctx.fill(
                    Path(roundedRect: glowRect, cornerRadius: 5.5),
                    with: .color(col.opacity(0.24))
                )
            }
            let tailH: CGFloat = isSingingNow ? 6.8 : 5.4
            let tailRect = CGRect(x: item.pt.x, y: tailCenterY - tailH * 0.5, width: tailW, height: tailH)
            ctx.fill(
                Path(roundedRect: tailRect, cornerRadius: tailH * 0.5),
                with: .color(col.opacity(isSingingNow ? 0.78 : 0.45))
            )

            let orbR: CGFloat = (isSingingNow || isFollowCur) ? 12.5 : (isSelected ? 11.5 : 9.6)
            let orbRect = CGRect(x: item.pt.x - orbR, y: item.pt.y - orbR, width: orbR * 2, height: orbR * 2)
            if isSingingNow || isFollowCur {
                let bloomR = orbR + 6.0
                ctx.fill(
                    Path(ellipseIn: CGRect(x: item.pt.x - bloomR, y: item.pt.y - bloomR, width: bloomR * 2, height: bloomR * 2)),
                    with: .color((isFollowCur ? palette.nightLampGold : col).opacity(0.30))
                )
            }
            if isSingingNow || isSelected || isFollowCur {
                let hr = orbR + 4.5
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: item.pt.x - hr, y: item.pt.y - hr, width: hr * 2, height: hr * 2)),
                    with: .color((isFollowCur ? palette.nightLampGold : palette.primaryInk).opacity(0.92)),
                    lineWidth: 2.0
                )
            }
            ctx.fill(Path(ellipseIn: orbRect), with: .color(col))
            ctx.stroke(
                Path(ellipseIn: orbRect),
                with: .color(palette.primaryInk.opacity(palette.isNight ? 0.34 : 0.24)),
                lineWidth: 1.2
            )

            let gs = orbR * 1.15
            let gRect = CGRect(x: item.pt.x - gs * 0.5, y: item.pt.y - gs * 0.5, width: gs, height: gs)
            let glyphInk = XylophoneLane.lane(at: item.laneIdx).barForegroundColor(isNight: palette.isNight)
            ctx.fill(PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: gRect), with: .color(glyphInk.opacity(0.94)), style: FillStyle(eoFill: true))
        }

        // 3.5 巴赫影子月亮对位副音珠（浮在山河主珠下方轻声回响）
        if vm.shadowCounterpointEnabled {
            for shadow in vm.shadowNotes {
                let sLaneIdx = XylophoneLane.laneIndex(degree: shadow.degree, octaveOffset: shadow.octaveOffset)
                let sx = FlowingRiverGeometry.screenX(onset: shadow.onset, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
                guard sx >= -24 && sx <= size.width + 24 else { continue }
                let sy = lay.padV + (CGFloat(7 - sLaneIdx) + 0.5) * lay.rowH + 10.0
                let isShadowSinging: Bool = {
                    guard let ct = currentTime else { return false }
                    return ct >= shadow.onset - 0.04 && ct <= shadow.onset + max(0.20, shadow.duration * 0.9)
                }()
                drawCrescentMoonOrb(
                    ctx: &ctx,
                    center: CGPoint(x: sx, y: sy),
                    radius: isShadowSinging ? 8.8 : 6.8,
                    color: palette.counterpointMoon,
                    isGlowing: isShadowSinging
                )
            }
        }

        // 4. 28% 处固定金光游标与声波涟漪 + 跟灯弹光桥 + 星尘微粒
        if vm.followGlowActive,
           let targetLane = targetFollowLaneIndex,
           let targetPt = followTargetPt {
            drawFollowLightBridge(ctx: &ctx, from: targetPt, toLaneIndex: targetLane, canvasSize: size)
        }
        var beam = Path()
        beam.move(to: CGPoint(x: lay.anchorX, y: 14))
        beam.addLine(to: CGPoint(x: lay.anchorX, y: size.height - 12))
        let beamHaloAlpha = (vm.isPlaying ? 0.24 : 0.12) + acoustic.shimmerEnergy * 0.26
        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(beamHaloAlpha)), lineWidth: 9.0 + CGFloat(acoustic.shimmerEnergy) * 6.0)
        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(vm.isPlaying ? 0.94 : 0.52)), lineWidth: 2.6)

        // 书签星章帽标（与花环模式 12 点钟书签星相呼应）
        let capCenter = CGPoint(x: lay.anchorX, y: 14.0)
        let starOuter: CGFloat = 6.8
        let starInner: CGFloat = 2.9
        var starCap = Path()
        for idx in 0..<8 {
            let ang = Double(idx) * (Double.pi / 4.0)
            let rad = (idx % 2 == 0) ? starOuter : starInner
            let pt = CGPoint(x: capCenter.x + CGFloat(cos(ang)) * rad, y: capCenter.y + CGFloat(sin(ang)) * rad)
            if idx == 0 { starCap.move(to: pt) } else { starCap.addLine(to: pt) }
        }
        starCap.closeSubpath()
        ctx.fill(starCap, with: .color(palette.nightLampGold))
        ctx.stroke(starCap, with: .color(palette.primaryInk.opacity(palette.isNight ? 0.45 : 0.35)), lineWidth: 1.2)

        for ev in vm.rippleBus.activeEvents(at: mediaNow) {
            let age = mediaNow - ev.birthMediaTime
            let prog = max(0, min(1, age / 0.85))
            let y = lay.padV + (CGFloat(7 - ev.laneIndex) + 0.5) * lay.rowH + (ev.isShadow ? 10.0 : 0.0)
            let x = vm.isPlaying ? lay.anchorX : FlowingRiverGeometry.screenX(onset: ev.onset, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let col = ev.isShadow ? palette.counterpointMoon : Color(hex: ev.colorHex)
            let dynScale: CGFloat = ev.isShadow ? 1.0 : CGFloat(0.72 + ev.intensity * 0.56)
            let r = (ev.isShadow ? 6.0 : 8.0) + CGFloat(prog) * (ev.isShadow ? 22.0 : 34.0 * dynScale)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(col.opacity((1.0 - prog) * (ev.isShadow ? 0.50 : 0.72))),
                lineWidth: ev.isShadow ? 1.5 : 2.0
            )
            if !reduceMotion && !ev.isShadow {
                let baseSeed = ev.birthMediaTime * 11.3 + Double(ev.laneIndex) * 1.9
                for pIdx in 0..<8 {
                    let pAng = baseSeed + Double(pIdx) * (Double.pi * 2.0 / 8.0)
                    let pDist = (9.0 + prog * (24.0 + Double(pIdx % 3) * 8.0)) * Double(dynScale)
                    let px = x + CGFloat(cos(pAng) * pDist)
                    let py = y + CGFloat(sin(pAng) * pDist)
                    let pr: CGFloat = (pIdx % 2 == 0) ? 2.0 : 1.4
                    let pCol = (pIdx % 3 == 0) ? palette.nightLampGold : col
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                        with: .color(pCol.opacity((1.0 - prog) * 0.82))
                    )
                }
            }
        }
    }

    // MARK: - 2B-bis. Resonance Nebula Kaleidoscope Canvas Rendering

    private func nebulaMetrics(for size: CGSize) -> (center: CGPoint, ringRadius: CGFloat, hubRadius: CGFloat) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.53)
        let ringRadius = min(size.width, size.height) * 0.365
        let hubRadius = ringRadius * 0.56
        return (center, ringRadius, hubRadius)
    }

    private func drawResonanceNebulaCanvas(ctx: inout GraphicsContext, size: CGSize, mediaNow: Double) {
        let nm = nebulaMetrics(for: size)
        let acoustic = currentAcousticEnvelope
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let spans = vm.chordSpans

        // 1. 当前幕情绪天光星云光晕背景（随真实音频 RMS 与温暖度呼吸舒展）
        let activeChordColor: Color = {
            if let ct = currentTime, let sp = spans.first(where: { ct >= $0.startTime && ct < $0.endTime }) {
                return sp.chord.color(isNight: palette.isNight)
            }
            if let sp = spans.first(where: { $0.id == vm.activeChordSpanID }) {
                return sp.chord.color(isNight: palette.isNight)
            }
            return vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        }()
        let auraExpandR = nm.ringRadius * (1.28 + CGFloat(acoustic.warmthEnergy) * 0.14)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: nm.center.x - auraExpandR,
                y: nm.center.y - auraExpandR,
                width: auraExpandR * 2,
                height: auraExpandR * 2
            )),
            with: .color(activeChordColor.opacity((palette.isNight ? 0.14 : 0.09) + acoustic.rmsEnergy * 0.08))
        )

        // 2. 外圈星轨与 8 条谐振星弦辐条
        let ringRect = CGRect(
            x: nm.center.x - nm.ringRadius,
            y: nm.center.y - nm.ringRadius,
            width: nm.ringRadius * 2,
            height: nm.ringRadius * 2
        )
        ctx.stroke(
            Path(ellipseIn: ringRect),
            with: .color(palette.secondaryInk.opacity(palette.isNight ? 0.18 : 0.14)),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 6])
        )

        for laneIdx in 0..<8 {
            let lane = XylophoneLane.lane(at: laneIdx)
            let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
            let sPt = ConstellationGeometry.starPoint(laneIndex: laneIdx, center: nm.center, radius: nm.ringRadius)
            let isLit = vm.activeLaneIndices.contains(laneIdx) || targetFollowLaneIndex == laneIdx
            var spoke = Path()
            spoke.move(to: nm.center)
            spoke.addLine(to: sPt)
            ctx.stroke(
                spoke,
                with: .color(lane.barColor(isNight: palette.isNight).opacity(isMuted ? 0.08 : (isLit ? 0.62 : 0.20))),
                style: StrokeStyle(lineWidth: isLit ? 2.2 : 1.0, dash: isMuted ? [2, 4] : [])
            )
        }

        // 3. 旋律星座连线（用弧线连起曲谱在 8 颗星辰间的星际漫游）
        let notes = vm.document.notes.sorted {
            $0.displayOnset(grooveStrength: vm.document.grooveStrength) < $1.displayOnset(grooveStrength: vm.document.grooveStrength)
        }
        if notes.count > 1 {
            for i in 1..<notes.count {
                let lPrev = XylophoneLane.laneIndex(degree: notes[i - 1].degree, octaveOffset: notes[i - 1].octaveOffset)
                let lCur = XylophoneLane.laneIndex(degree: notes[i].degree, octaveOffset: notes[i].octaveOffset)
                let p0 = ConstellationGeometry.starPoint(laneIndex: lPrev, center: nm.center, radius: nm.ringRadius)
                let p1 = ConstellationGeometry.starPoint(laneIndex: lCur, center: nm.center, radius: nm.ringRadius)
                let ctrl = CGPoint(
                    x: (p0.x + p1.x) * 0.39 + nm.center.x * 0.22,
                    y: (p0.y + p1.y) * 0.39 + nm.center.y * 0.22
                )
                var seg = Path()
                seg.move(to: p0)
                seg.addQuadCurve(to: p1, control: ctrl)
                strokeChromaticSegment(
                    ctx: &ctx,
                    path: seg,
                    startPt: p0,
                    endPt: p1,
                    fromLane: lPrev,
                    toLane: lCur,
                    extraEnergy: acoustic.rmsEnergy
                )
            }
        }

        // 4. 中央大尺度利萨如谐振星核
        if acoustic.warmthEnergy > 0.01 {
            let glowR = nm.hubRadius + 5.0 + CGFloat(acoustic.warmthEnergy) * 10.0
            ctx.stroke(
                Path(ellipseIn: CGRect(x: nm.center.x - glowR, y: nm.center.y - glowR, width: glowR * 2, height: glowR * 2)),
                with: .color(palette.nightLampGold.opacity(acoustic.warmthEnergy * 0.26)),
                lineWidth: 2.4 + CGFloat(acoustic.warmthEnergy) * 3.0
            )
        }
        let hubRect = CGRect(
            x: nm.center.x - nm.hubRadius,
            y: nm.center.y - nm.hubRadius,
            width: nm.hubRadius * 2,
            height: nm.hubRadius * 2
        )
        ctx.fill(
            Path(ellipseIn: hubRect),
            with: .color(palette.storybookButter)
        )
        ctx.stroke(
            Path(ellipseIn: hubRect),
            with: .color(palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.14)),
            lineWidth: 1.3
        )
        drawLissajousWave(
            ctx: &ctx,
            center: nm.center,
            amplitude: nm.hubRadius * 0.62,
            mediaNow: mediaNow,
            acoustic: acoustic,
            glowWidth: 5.0,
            coreWidth: 1.8
        )

        if !vm.isPlaying && !vm.followGlowActive && !vm.document.notes.isEmpty {
            let triR = nm.hubRadius * 0.22
            var playTri = Path()
            playTri.move(to: CGPoint(x: nm.center.x - triR * 0.52, y: nm.center.y - triR * 0.78))
            playTri.addLine(to: CGPoint(x: nm.center.x + triR * 0.92, y: nm.center.y))
            playTri.addLine(to: CGPoint(x: nm.center.x - triR * 0.52, y: nm.center.y + triR * 0.78))
            playTri.closeSubpath()
            ctx.fill(playTri, with: .color(palette.nightLampGold.opacity(0.36)))
        }

        // 5. 流星轨迹（播放/搓盘时，金色彗星在星座星辰间顺滑飞舞，身后拖拽 5 颗微尘尾迹）
        let comet = currentTime.flatMap {
            ConstellationGeometry.cometSnapshot(
                notes: notes,
                grooveStrength: vm.document.grooveStrength,
                currentTime: $0,
                center: nm.center,
                radius: nm.ringRadius
            )
        }

        // 5.5 影子对位银蓝双星连弦（主星与影子新月之间亮起温柔和声弧弦）
        if vm.shadowCounterpointEnabled,
           let shadowEv = vm.rippleBus.lastShadowEvent {
            let age = mediaNow - shadowEv.birthMediaTime
            if age >= 0 && age <= 1.1 {
                let fade = 1.0 - (age / 1.1)
                let shadowPt = ConstellationGeometry.starPoint(laneIndex: shadowEv.laneIndex, center: nm.center, radius: nm.ringRadius)
                let mainAnchor = comet?.position ?? ConstellationGeometry.starPoint(
                    laneIndex: notes.first.map { XylophoneLane.laneIndex(degree: $0.degree, octaveOffset: $0.octaveOffset) } ?? 0,
                    center: nm.center,
                    radius: nm.ringRadius
                )
                var duetArc = Path()
                duetArc.move(to: mainAnchor)
                duetArc.addQuadCurve(
                    to: shadowPt,
                    control: CGPoint(
                        x: (mainAnchor.x + shadowPt.x) * 0.36 + nm.center.x * 0.28,
                        y: (mainAnchor.y + shadowPt.y) * 0.36 + nm.center.y * 0.28
                    )
                )
                ctx.stroke(
                    duetArc,
                    with: .color(palette.counterpointMoon.opacity(fade * 0.85)),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                )
                drawCrescentMoonOrb(
                    ctx: &ctx,
                    center: shadowPt,
                    radius: 10.5,
                    color: palette.counterpointMoon,
                    isGlowing: true
                )
            }
        }

        if let c = comet {
            let p0 = ConstellationGeometry.starPoint(laneIndex: c.activeLaneIndex, center: nm.center, radius: nm.ringRadius)
            for tailIdx in 1...5 {
                let backT = max(0.0, 1.0 - Double(tailIdx) * 0.14)
                let tx = p0.x + (c.position.x - p0.x) * CGFloat(backT)
                let ty = p0.y + (c.position.y - p0.y) * CGFloat(backT)
                let tr = CGFloat(5.2 - Double(tailIdx) * 0.75)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: tx - tr, y: ty - tr, width: tr * 2, height: tr * 2)),
                    with: .color(palette.nightLampGold.opacity(max(0.15, 0.72 - Double(tailIdx) * 0.12)))
                )
            }
            let auraR: CGFloat = 13.0
            ctx.fill(
                Path(ellipseIn: CGRect(x: c.position.x - auraR, y: c.position.y - auraR, width: auraR * 2, height: auraR * 2)),
                with: .color(palette.nightLampGold.opacity(0.32))
            )
            let coreR: CGFloat = 6.2
            ctx.fill(
                Path(ellipseIn: CGRect(x: c.position.x - coreR, y: c.position.y - coreR, width: coreR * 2, height: coreR * 2)),
                with: .color(palette.nightLampGold)
            )
        }

        // 6. 星波涟漪与 8 颗釉面陶瓷星座星辰（含色盲图腾 + 清晰数字 + 声波扩散环）
        let activeRipples = vm.rippleBus.activeEvents(at: mediaNow)
        for ev in activeRipples {
            let age = mediaNow - ev.birthMediaTime
            let prog = max(0.0, min(1.0, age / 0.85))
            let pt = ConstellationGeometry.starPoint(laneIndex: ev.laneIndex, center: nm.center, radius: nm.ringRadius)
            let col = ev.isShadow ? palette.counterpointMoon : Color(hex: ev.colorHex)
            let dynScale: CGFloat = ev.isShadow ? 1.0 : CGFloat(0.72 + ev.intensity * 0.56)
            let rr = 18.0 + CGFloat(prog) * (ev.isShadow ? 24.0 : 34.0 * dynScale)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)),
                with: .color(col.opacity((1.0 - prog) * 0.76)),
                lineWidth: ev.isShadow ? 1.8 : 2.5
            )
        }

        let hints = smartHintByLane
        let chordDegrees = vm.activeChordToneDegrees
        for laneIdx in 0..<8 {
            let lane = XylophoneLane.lane(at: laneIdx)
            let col = lane.barColor(isNight: palette.isNight)
            let pt = ConstellationGeometry.starPoint(laneIndex: laneIdx, center: nm.center, radius: nm.ringRadius)
            let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
            let isFollowTarget = targetFollowLaneIndex == laneIdx
            let isCometHome = comet?.activeLaneIndex == laneIdx && currentTime != nil
            let isVibrating = vm.activeVibratoLane == laneIdx
            let isLit = vm.activeLaneIndices.contains(laneIdx) || struckNebulaLane == laneIdx || isFollowTarget || isCometHome || isVibrating
            let hasHint = hints[laneIdx] != nil
            let isChordResonant = !isMuted && !isFollowTarget && !hasHint && chordDegrees.contains(lane.degree)

            let starR: CGFloat = isLit ? 22.0 : (isMuted ? 14.5 : 18.0)
            let starRect = CGRect(x: pt.x - starR, y: pt.y - starR, width: starR * 2, height: starR * 2)

            if isVibrating && !reduceMotion {
                let pulseWave = CGFloat(0.5 + 0.5 * sin(mediaNow * 11.0))
                for ringIdx in 0..<2 {
                    let ringR = starR + 6.5 + CGFloat(ringIdx) * 6.0 + pulseWave * 4.0
                    let rRect = CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2)
                    ctx.stroke(
                        Path(ellipseIn: rRect),
                        with: .color(palette.nightLampGold.opacity(ringIdx == 0 ? 0.72 : 0.36)),
                        lineWidth: ringIdx == 0 ? 1.8 : 1.2
                    )
                }
            }

            if isChordResonant {
                var symArc = Path()
                symArc.addArc(
                    center: pt,
                    radius: starR + 3.8,
                    startAngle: .degrees(36),
                    endAngle: .degrees(144),
                    clockwise: false
                )
                ctx.stroke(
                    symArc,
                    with: .color(Color.white.opacity(palette.isNight ? 0.58 : 0.78)),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
            }

            if isLit || hasHint {
                let haloR = starR + 6.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pt.x - haloR, y: pt.y - haloR, width: haloR * 2, height: haloR * 2)),
                    with: .color((isFollowTarget || hasHint || isVibrating ? palette.nightLampGold : col).opacity(0.32))
                )
            }

            ctx.fill(Path(ellipseIn: starRect), with: .color(col.opacity(isMuted ? 0.25 : 0.96)))
            ctx.stroke(
                Path(ellipseIn: starRect),
                with: .color((isFollowTarget || hasHint) ? palette.nightLampGold : Color.white.opacity(0.65)),
                lineWidth: (isFollowTarget || hasHint) ? 2.4 : 1.1
            )

            // 色盲几何图腾 + 清晰唱名数字双排刻画在星辰中心
            let gSize = starR * 0.72
            let gRect = CGRect(x: pt.x - gSize * 0.5, y: pt.y - starR * 0.44 - gSize * 0.25, width: gSize, height: gSize)
            let starInk = lane.barForegroundColor(isNight: palette.isNight)
            ctx.fill(
                PitchGlyphShape.glyph(forLaneIndex: laneIdx).path(in: gRect),
                with: .color(starInk.opacity(isMuted ? 0.45 : 0.96)),
                style: FillStyle(eoFill: true)
            )
            let digitTxt = Text(lane.digitLabel)
                .font(.system(size: starR > 19 ? 11 : 9.5, weight: .heavy, design: .rounded))
                .foregroundStyle(starInk.opacity(isMuted ? 0.5 : 0.98))
            ctx.draw(digitTxt, at: CGPoint(x: pt.x, y: pt.y + starR * 0.42), anchor: .center)
        }

        if vm.followGlowActive, let targetLane = targetFollowLaneIndex {
            let starPt = ConstellationGeometry.starPoint(laneIndex: targetLane, center: nm.center, radius: nm.ringRadius)
            drawFollowLightBridge(ctx: &ctx, from: starPt, toLaneIndex: targetLane, canvasSize: size)
        }
    }

    // MARK: - 2C. Unified Canvas Gestures (Orbital & Flowing River)

    private func handleOrbitalDragChanged(_ val: DragGesture.Value, in size: CGSize) {
        let m = orbitalMetrics(for: size)
        let mediaNow = CACurrentMediaTime()
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let rotTurns = vm.clock.continuousRotationTurns(at: mediaNow)
        let discRot: Double = reduceMotion ? 0.0 : (currentTime != nil ? -(rotTurns * 2.0 * Double.pi) : 0.0)
        let total = max(0.5, vm.document.totalDuration)

        if case .none = discInteractionMode {
            coastTask?.cancel()
            coastTask = nil
            dragStartPoint = val.startLocation
            dragDidPushUndo = false

            let dx = val.startLocation.x - m.center.x
            let dy = val.startLocation.y - m.center.y
            let dist = hypot(dx, dy)

            // 1) 命中已有音珠？（仅创作模式允许选中和拖拽音珠）
            if allowsEditing && !vm.followGlowActive {
                for bead in vm.document.notes {
                    let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
                    let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                    let ang = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: onset, totalDuration: total) + discRot
                    let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
                    let bPt = CGPoint(x: m.center.x + CGFloat(cos(ang)) * r, y: m.center.y + CGFloat(sin(ang)) * r)
                    if hypot(val.startLocation.x - bPt.x, val.startLocation.y - bPt.y) <= 24 {
                        discInteractionMode = .bead(bead.id)
                        draggingBeadID = bead.id
                        dragStartOnset = onset
                        vm.selectBead(bead.id, playContext: false)
                        return
                    }
                }
            }

            // 2) 命中圆心谐振核心？
            if dist < m.innerRadius * 0.84 {
                discInteractionMode = .centerHub
                return
            }

            // 3) 命中外环和声弧？
            if dist >= m.platterRadius * 0.91 && dist <= m.haloRadius * 1.14 {
                let clickedOnset = OrbitalGeometry.onset(forScreenPoint: val.startLocation, center: m.center, discRotation: discRot, totalDuration: total)
                if let span = vm.chordSpans.first(where: { clickedOnset >= $0.startTime && clickedOnset < $0.endTime }) {
                    discInteractionMode = .chordRing(span.id)
                    return
                }
            }

            // 4) 进入手摇搓盘模式（如果滑出 >6pt 则手摇播放，轻点则种珠）
            discInteractionMode = .scrub
            let ang = atan2(Double(dy), Double(dx))
            scrubAnchorAngle = ang
            lastDragAngle = ang
            scrubAnchorTime = currentTime ?? 0.0
            lastScrubTimestamp = mediaNow
            lastScrubVelocity = 0.0
        }

        switch discInteractionMode {
        case .bead(let beadID):
            let moveDist = hypot(val.location.x - dragStartPoint.x, val.location.y - dragStartPoint.y)
            guard moveDist > 6 else { return }
            if !dragDidPushUndo {
                dragDidPushUndo = true
                vm.beginBeadEdit()
            }
            let r = hypot(val.location.x - m.center.x, val.location.y - m.center.y)
            let laneIdx = OrbitalGeometry.laneIndex(forRadius: r, innerRadius: m.innerRadius, outerRadius: m.outerRadius, pentatonicSafe: vm.pentatonicSafe)
            let lane = XylophoneLane.lane(at: laneIdx)
            vm.updateBeadToLane(beadID: beadID, lane: lane, playSinglePreview: true)

            let startAng = atan2(Double(dragStartPoint.y - m.center.y), Double(dragStartPoint.x - m.center.x))
            let curAng = atan2(Double(val.location.y - m.center.y), Double(val.location.x - m.center.x))
            var dAng = curAng - startAng
            if dAng > Double.pi { dAng -= 2 * Double.pi }
            if dAng < -Double.pi { dAng += 2 * Double.pi }
            if abs(dAng) > 0.06 {
                let dt = (dAng / (2.0 * Double.pi)) * total
                let snapped = BeatTimingNudgeHelper.dragGridSnapOnset(
                    rawOnset: dragStartOnset + dt,
                    grooveStrength: vm.document.grooveStrength
                )
                if lastBeadTimeGridBucket != snapped.gridBucket {
                    lastBeadTimeGridBucket = snapped.gridBucket
                    AcousticHapticsEngine.shared.playScrubTick()
                }
                vm.updateBeatTiming(beadID: beadID, newOnset: snapped.onset)
            }

        case .scrub:
            let moveDist = hypot(val.location.x - dragStartPoint.x, val.location.y - dragStartPoint.y)
            guard moveDist > 8 else { return }
            let dx = Double(val.location.x - m.center.x)
            let dy = Double(val.location.y - m.center.y)
            let curAng = atan2(dy, dx)
            var step = curAng - lastDragAngle
            if step > Double.pi { step -= 2 * Double.pi }
            if step < -Double.pi { step += 2 * Double.pi }
            lastDragAngle = curAng

            let dtTime = -(step / (2.0 * Double.pi)) * total
            let wallDt = max(0.008, mediaNow - lastScrubTimestamp)
            lastScrubTimestamp = mediaNow
            let instVel = dtTime / wallDt
            lastScrubVelocity = lastScrubVelocity * 0.55 + instVel * 0.45

            // 逆时针拨动花环 = 把后面的音符拉向 12 点钟书签星（时间向前推进）
            scrubAnchorTime += dtTime
            if scrubAnchorTime < 0 { scrubAnchorTime += total }
            scrubAnchorTime = scrubAnchorTime.truncatingRemainder(dividingBy: total)
            vm.scrubToTime(scrubAnchorTime, triggerNotes: true)
            scrubTick &+= 1

        default:
            break
        }
    }

    private func handleOrbitalDragEnded(_ val: DragGesture.Value, in size: CGSize) {
        let m = orbitalMetrics(for: size)
        let moveDist = hypot(val.location.x - dragStartPoint.x, val.location.y - dragStartPoint.y)
        let total = max(0.5, vm.document.totalDuration)
        let mediaNow = CACurrentMediaTime()
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let rotTurns = vm.clock.continuousRotationTurns(at: mediaNow)
        let discRot: Double = reduceMotion ? 0.0 : (currentTime != nil ? -(rotTurns * 2.0 * Double.pi) : 0.0)

        switch discInteractionMode {
        case .centerHub:
            if moveDist < 12 {
                vm.togglePlayback()
            }

        case .chordRing(let spanID):
            if moveDist < 12 {
                vm.cycleSpanChord(spanIndex: spanID)
            }

        case .bead(let beadID):
            draggingBeadID = nil
            dragDidPushUndo = false
            lastBeadTimeGridBucket = nil
            onUserDidEdit()
            if let curIdx = vm.document.notes.firstIndex(where: { $0.id == beadID }) {
                vm.playContextEcho(upToIndex: curIdx)
            }

        case .scrub:
            if moveDist <= 8 {
                if vm.followGlowActive, let targetLane = targetFollowLaneIndex {
                    vm.strikeXylophoneLane(XylophoneLane.lane(at: targetLane))
                } else if allowsEditing {
                    let dist = hypot(val.location.x - m.center.x, val.location.y - m.center.y)
                    if dist >= m.innerRadius * 0.80 && dist <= m.platterRadius * 0.95 {
                        let laneIdx = OrbitalGeometry.laneIndex(forRadius: dist, innerRadius: m.innerRadius, outerRadius: m.outerRadius, pentatonicSafe: vm.pentatonicSafe)
                        let lane = XylophoneLane.lane(at: laneIdx)
                        let onset = OrbitalGeometry.onset(forScreenPoint: val.location, center: m.center, discRotation: discRot, totalDuration: total)
                        vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: onset)
                        onUserDidEdit()
                    } else {
                        vm.selectedBeadID = nil
                    }
                } else {
                    vm.togglePlayback()
                }
            } else {
                let releaseVelocity = lastScrubVelocity
                if !reduceMotion && abs(releaseVelocity) > 0.45 {
                    startVinylMomentumCoast(initialVelocity: max(-8.0, min(8.0, releaseVelocity)), fromTime: scrubAnchorTime, totalDuration: total)
                } else {
                    vm.endScrubbing()
                }
            }

        case .none:
            break
        }
        discInteractionMode = .none
    }

    /// 手拨花环的柔和阻尼惯性滑行（松手后按指数阻尼滑行约 0.35 秒，滑过音珠自然响起）。
    private func startVinylMomentumCoast(initialVelocity: Double, fromTime: Double, totalDuration: Double) {
        coastTask?.cancel()
        wakeRippleTimeline()
        coastTask = Task { @MainActor in
            var t = fromTime
            var vel = initialVelocity
            let stepSec = 0.032
            for _ in 0..<11 {
                if Task.isCancelled || vm.isPlaying { break }
                t += vel * stepSec
                if t < 0 { t += totalDuration }
                t = t.truncatingRemainder(dividingBy: totalDuration)
                vm.scrubToTime(t, triggerNotes: true)
                scrubTick &+= 1
                vel *= 0.72
                if abs(vel) < 0.12 { break }
                try? await Task.sleep(nanoseconds: 32_000_000)
            }
            if !Task.isCancelled {
                vm.endScrubbing()
                coastTask = nil
            }
        }
    }

    private func handleRiverDragChanged(_ val: DragGesture.Value, in size: CGSize) {
        let lay = riverLayout(for: size)
        let mediaNow = CACurrentMediaTime()
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let scrollX = FlowingRiverGeometry.worldScrollX(playheadTime: currentTime, manualScrollX: manualRiverScrollX, pxPerSecond: lay.pxPerSec)

        if case .none = discInteractionMode {
            coastTask?.cancel()
            coastTask = nil
            dragStartPoint = val.startLocation
            dragDidPushUndo = false
            riverStartScrollX = scrollX

            if allowsEditing && !vm.followGlowActive {
                for bead in vm.document.notes {
                    let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
                    let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                    let bx = FlowingRiverGeometry.screenX(onset: onset, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
                    let by = lay.padV + (CGFloat(7 - laneIdx) + 0.5) * lay.rowH
                    if hypot(val.startLocation.x - bx, val.startLocation.y - by) <= 24 {
                        discInteractionMode = .bead(bead.id)
                        draggingBeadID = bead.id
                        dragStartOnset = onset
                        vm.selectBead(bead.id, playContext: false)
                        return
                    }
                }
            }
            discInteractionMode = .scrub
        }

        switch discInteractionMode {
        case .bead(let beadID):
            let moveDist = hypot(val.location.x - dragStartPoint.x, val.location.y - dragStartPoint.y)
            guard moveDist > 6 else { return }
            if !dragDidPushUndo {
                dragDidPushUndo = true
                vm.beginBeadEdit()
            }
            let rowFromTop = max(0, min(7, Int(floor((val.location.y - lay.padV) / max(1, lay.rowH)))))
            let snapped = XylophoneLane.nearestAllowedIndex(7 - rowFromTop, pentatonicSafe: vm.pentatonicSafe)
            vm.updateBeadToLane(beadID: beadID, lane: XylophoneLane.lane(at: snapped), playSinglePreview: true)

            let dx = val.location.x - dragStartPoint.x
            if abs(dx) > 10 {
                let snapped = BeatTimingNudgeHelper.dragGridSnapOnset(
                    rawOnset: dragStartOnset + Double(dx / lay.pxPerSec),
                    grooveStrength: vm.document.grooveStrength
                )
                if lastBeadTimeGridBucket != snapped.gridBucket {
                    lastBeadTimeGridBucket = snapped.gridBucket
                    AcousticHapticsEngine.shared.playScrubTick()
                }
                vm.updateBeatTiming(beadID: beadID, newOnset: snapped.onset)
            }

        case .scrub:
            let dx = val.location.x - dragStartPoint.x
            guard abs(dx) > 8 else { return }
            let maxScroll = max(0, CGFloat(lay.totalDur) * lay.pxPerSec - size.width * 0.4)
            let nextScroll = max(0, min(maxScroll, riverStartScrollX - dx))
            manualRiverScrollX = nextScroll
            let targetTime = Double(nextScroll / lay.pxPerSec)
            vm.scrubToTime(targetTime, triggerNotes: true)
            scrubTick &+= 1

        default:
            break
        }
    }

    private func handleRiverDragEnded(_ val: DragGesture.Value, in size: CGSize) {
        let lay = riverLayout(for: size)
        let moveDist = hypot(val.location.x - dragStartPoint.x, val.location.y - dragStartPoint.y)
        let mediaNow = CACurrentMediaTime()
        let scrollX = FlowingRiverGeometry.worldScrollX(playheadTime: vm.clock.currentTime(at: mediaNow), manualScrollX: manualRiverScrollX, pxPerSecond: lay.pxPerSec)

        switch discInteractionMode {
        case .bead(let beadID):
            draggingBeadID = nil
            dragDidPushUndo = false
            lastBeadTimeGridBucket = nil
            onUserDidEdit()
            if let idx = vm.document.notes.firstIndex(where: { $0.id == beadID }) {
                vm.playContextEcho(upToIndex: idx)
            }

        case .scrub:
            if moveDist <= 8 {
                if vm.followGlowActive, let targetLane = targetFollowLaneIndex {
                    vm.strikeXylophoneLane(XylophoneLane.lane(at: targetLane))
                } else if allowsEditing {
                    let rowFromTop = max(0, min(7, Int(floor((val.location.y - lay.padV) / max(1, lay.rowH)))))
                    let snapped = XylophoneLane.nearestAllowedIndex(7 - rowFromTop, pentatonicSafe: vm.pentatonicSafe)
                    let lane = XylophoneLane.lane(at: snapped)
                    let targetOnset = FlowingRiverGeometry.onset(fromScreenX: val.location.x, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
                    vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: targetOnset)
                    onUserDidEdit()
                } else {
                    vm.togglePlayback()
                }
            } else {
                vm.endScrubbing()
            }

        default:
            break
        }
        discInteractionMode = .none
    }

    private func handleNebulaDragChanged(_ val: DragGesture.Value, in size: CGSize) {
        let nm = nebulaMetrics(for: size)
        if case .none = discInteractionMode {
            dragStartPoint = val.startLocation
            let dist = hypot(val.startLocation.x - nm.center.x, val.startLocation.y - nm.center.y)
            if dist < nm.hubRadius * 0.92 {
                discInteractionMode = .centerHub
                return
            }
            discInteractionMode = .bead(UUID())
        }

        guard case .bead = discInteractionMode else { return }
        if let laneIdx = ConstellationGeometry.hitStarLane(
            at: val.location,
            center: nm.center,
            radius: nm.ringRadius,
            hitRadius: 36,
            pentatonicSafe: vm.pentatonicSafe && !vm.followGlowActive
        ) {
            if struckNebulaLane != laneIdx {
                vm.endStarVibrato()
                struckNebulaLane = laneIdx
                let hitPt = ConstellationGeometry.starPoint(laneIndex: laneIdx, center: nm.center, radius: nm.ringRadius)
                nebulaHoldCenter = hitPt
                let distPt = hypot(val.location.x - hitPt.x, val.location.y - hitPt.y)
                let dyn = StarHitDynamicsMapper.hitDynamics(distancePt: distPt, hitRadius: 36.0)
                wakeRippleTimeline()
                if allowsEditing && vm.document.notes.isEmpty && !vm.followGlowActive {
                    let lane = XylophoneLane.lane(at: laneIdx)
                    vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: 0.16)
                    onUserDidEdit()
                } else {
                    vm.strikeXylophoneLane(
                        XylophoneLane.lane(at: laneIdx),
                        touchIntensity: dyn.velocity,
                        touchBrightness: dyn.brightness
                    )
                }
            } else if !vm.followGlowActive {
                let dx = val.location.x - nebulaHoldCenter.x
                let dy = val.location.y - nebulaHoldCenter.y
                if hypot(dx, dy) > 6.0 {
                    vm.beginOrUpdateStarVibrato(laneIndex: laneIdx, dx: dx, dy: dy, hitRadius: 36.0)
                    wakeRippleTimeline()
                }
            }
        } else {
            struckNebulaLane = nil
            vm.endStarVibrato()
        }
    }

    private func handleNebulaDragEnded(_ val: DragGesture.Value, in size: CGSize) {
        let moveDist = hypot(val.location.x - dragStartPoint.x, val.location.y - dragStartPoint.y)
        if case .centerHub = discInteractionMode, moveDist < 14 {
            vm.togglePlayback()
        }
        struckNebulaLane = nil
        vm.endStarVibrato()
        discInteractionMode = .none
    }
}

/// 共享绘本七小只彩虹互动琴键带（赏析区用于即兴伴奏或跟灯弹，创作区用于点击写入与换音，完全消除无障碍与手势复用代码）。
internal struct StageChoirKeyboardBar: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette
    let reduceMotion: Bool
    var showsSmartHints: Bool = false
    let onWakeTimeline: () -> Void
    let onKeyStrike: (XylophoneLane, Double, Double) -> Void

    @State private var struckRibbonLane: Int? = nil
    @State private var ribbonDragAnchorY: CGFloat? = nil
    @State private var ribbonMercuryLevel: Double = 0.0

    private var targetFollowLaneIndex: Int? {
        guard vm.followGlowActive,
              vm.followGlowIndex < vm.document.notes.count else { return nil }
        let b = vm.document.notes[vm.followGlowIndex]
        return XylophoneLane.laneIndex(degree: b.degree, octaveOffset: b.octaveOffset)
    }

    private var smartHintByLane: [Int: SmartPitchHint] {
        guard showsSmartHints && vm.smartHintActive else { return [:] }
        return Dictionary(uniqueKeysWithValues: vm.smartHints.map { ($0.laneIndex, $0) })
    }

    var body: some View {
        let hints = smartHintByLane
        let chordDegrees = vm.activeChordToneDegrees
        let isMinor = vm.document.scaleMode.isMinorFlavored

        return ZStack {
            StorybookQuietCardSurface(palette: palette, cornerRadius: 18)

            // 绘本草地彩带基底（代替金属导轨）
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.storybookHillFront.opacity(0.72))
                    .frame(height: 18)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 7)
            .allowsHitTesting(false)

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(XylophoneLane.allLanes) { lane in
                        let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
                        let isFollowTarget = targetFollowLaneIndex == lane.index
                        let hint = hints[lane.index]
                        let isChordResonant = !isMuted && !isFollowTarget && hint == nil && chordDegrees.contains(lane.degree)
                        let isPlayingThis = vm.activeLaneIndices.contains(lane.index) || struckRibbonLane == lane.index
                        let isSympathetic = !isMuted && !isPlayingThis && vm.sympatheticLaneIndices.contains(lane.index)
                        let elev = KilnKeyPhysics.elevation(
                            isPressed: isPlayingThis,
                            isFollowTarget: isFollowTarget || hint != nil,
                            isMuted: isMuted
                        )
                        let buddyPose = StorybookIllustrationLayout.keyBuddyPose(
                            for: lane.member,
                            isSinging: isPlayingThis || isSympathetic || isFollowTarget,
                            isMinor: isMinor,
                            reduceMotion: reduceMotion
                        )
                        let baseH = CGFloat(66 - lane.index * 2)
                        let barH = isMuted ? max(38, baseH - 6) : baseH
                        let col = lane.barColor(isNight: palette.isNight)
                        let keyInk = lane.barForegroundColor(isNight: palette.isNight)
                        let keyBorder: Color = (isFollowTarget || hint != nil)
                            ? palette.nightLampGold
                            : (isSympathetic ? Color.white.opacity(0.82) : Color.white.opacity(palette.isNight ? 0.14 : 0.45))

                        VStack(spacing: 2) {
                            ChimmoCartoonKeyBuddyView(
                                member: lane.member,
                                outlineColor: palette.isNight ? palette.figureContourInk : palette.primaryInk.opacity(0.72),
                                isSinging: buddyPose.showSingingSmile,
                                isMinor: isMinor
                            )
                            .frame(width: 24, height: 18)
                            .rotationEffect(.degrees(buddyPose.earTiltDegrees))
                            .offset(y: buddyPose.popOffsetY)

                            PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                                .frame(width: 10.5, height: 10.5)
                                .foregroundStyle(keyInk.opacity(0.92))

                            Text(lane.digitLabel)
                                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(keyInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: barH)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(col)
                                    .shadow(
                                        color: palette.isNight
                                            ? Color.black.opacity(isPlayingThis ? 0.16 : 0.30)
                                            : col.opacity(isPlayingThis ? 0.14 : 0.28),
                                        radius: isPlayingThis ? 1.5 : 3.5,
                                        y: isPlayingThis ? 0.8 : 2.5
                                    )
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(palette.isNight ? 0.08 : 0.22), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(
                                    keyBorder,
                                    lineWidth: (isFollowTarget || hint != nil) ? 2.2 : (isSympathetic ? 1.6 : 1.0)
                                )
                        )
                        .overlay(alignment: .top) {
                            if isFollowTarget || hint != nil {
                                Circle()
                                    .fill(palette.nightLampGold)
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.0))
                                    .frame(width: 7.5, height: 7.5)
                                    .offset(y: -4.5)
                            } else if isSympathetic {
                                Circle()
                                    .fill(Color.white)
                                    .overlay(Circle().strokeBorder(col.opacity(0.65), lineWidth: 1.0))
                                    .frame(width: 5.5, height: 5.5)
                                    .offset(y: -3.5)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            ZStack(alignment: .bottom) {
                                if struckRibbonLane == lane.index && ribbonMercuryLevel > 0.05 {
                                    Capsule()
                                        .fill(keyInk.opacity(0.72))
                                        .frame(width: 5, height: max(8, barH * CGFloat(ribbonMercuryLevel) * 0.60))
                                        .padding(.bottom, 4)
                                }
                                if isChordResonant {
                                    Capsule()
                                        .fill(keyInk.opacity(palette.isNight ? 0.70 : 0.68))
                                        .frame(width: 14, height: 3.0)
                                        .padding(.bottom, 3)
                                }
                            }
                        }
                        .offset(y: elev.pressOffsetY)
                        .scaleEffect(isPlayingThis ? 0.96 : (isFollowTarget ? 1.04 : 1.0))
                        .opacity(isMuted ? 0.28 : 1.0)
                        .animation(reduceMotion ? nil : .spring(response: 0.19, dampingFraction: 0.68), value: isPlayingThis)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isFollowTarget)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: isSympathetic)
                        .accessibilityElement()
                        .accessibilityLabel("\(lane.member.voiceOverSummary)")
                        .accessibilityValue(isFollowTarget ? "当前亮灯" : (isChordResonant ? "和谐音" : ""))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            onWakeTimeline()
                            onKeyStrike(lane, 0.60, 0.96)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let w = max(1, geo.size.width)
                            let h = max(1, geo.size.height)
                            let idx = max(0, min(7, Int(floor((val.location.x / w) * 8.0))))
                            if struckRibbonLane != idx {
                                vm.endStarVibrato()
                                ribbonMercuryLevel = 0.0
                                ribbonDragAnchorY = val.location.y
                                let lane = XylophoneLane.lane(at: idx)
                                if vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive {
                                    struckRibbonLane = nil
                                    return
                                }
                                struckRibbonLane = idx
                                let normY = Double(max(0, min(1, val.location.y / h)))
                                let dyn = ExpressiveTouchMapper.dynamics(normalizedY: normY)
                                onWakeTimeline()
                                onKeyStrike(lane, dyn.velocity, dyn.brightness)
                            } else if !vm.followGlowActive && !showsSmartHints && vm.selectedBeadID == nil,
                                      let anchorY = ribbonDragAnchorY {
                                let lane = XylophoneLane.lane(at: idx)
                                if vm.pentatonicSafe && !lane.isPentatonicSafe {
                                    return
                                }
                                let expr = KeyRibbonExpressionMapper.expression(
                                    verticalOffsetPt: val.location.y - anchorY,
                                    barHeightPt: h
                                )
                                ribbonMercuryLevel = expr.mercuryFraction
                                if expr.isVibratoActive {
                                    onWakeTimeline()
                                    vm.beginOrUpdateStarVibrato(
                                        laneIndex: idx,
                                        dx: expr.vibratoDX,
                                        dy: expr.vibratoDY,
                                        hitRadius: 26.0
                                    )
                                } else {
                                    vm.endStarVibrato()
                                }
                            }
                        }
                        .onEnded { _ in
                            struckRibbonLane = nil
                            ribbonDragAnchorY = nil
                            ribbonMercuryLevel = 0.0
                            vm.endStarVibrato()
                        }
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .frame(height: 86)
        .onChange(of: vm.document.id) { _, _ in
            struckRibbonLane = nil
            ribbonDragAnchorY = nil
            ribbonMercuryLevel = 0.0
        }
    }
}

/// 主舞台「哞 · 四幕彩色和声触控轨」：扁平卡通童书平涂和弦交互带。
internal struct StageHarmonyRibbonView: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette
    let reduceMotion: Bool
    let onWakeTimeline: () -> Void

    var body: some View {
        let skyCol = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        let segments = HarmonyCurtainStripMapper.segments(
            from: vm.chordSpans,
            totalDuration: vm.document.totalDuration
        )

        HStack(spacing: 6) {
            Button {
                let nextPreset: ChordProgressionPreset = vm.cradleEnabled ? .off : .autoMatch
                vm.setChordPreset(nextPreset)
            } label: {
                ZStack {
                    ChimmoKilnPillButtonSurface(
                        palette: palette,
                        accent: palette.bassRibbon,
                        isActive: vm.cradleEnabled,
                        cornerRadius: 17
                    )
                    ChimmoCowView(
                        isNight: palette.isNight,
                        accentColor: skyCol,
                        isAwake: vm.cradleEnabled,
                        isPlaying: vm.isPlaying
                    )
                    .frame(width: 24, height: 18)
                }
                .frame(width: 44, height: 34)
                .frame(
                    minWidth: 44,
                    minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                )
                .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel(vm.cradleEnabled ? "关闭小牛哞伴奏" : "开启小牛哞伴奏")
            .accessibilityValue(vm.cradleEnabled ? "已开启" : "纯清唱")

            if vm.cradleEnabled && !segments.isEmpty {
                GeometryReader { geo in
                    let spacingTotal = CGFloat(max(0, segments.count - 1)) * 5.0
                    let usableW = max(12.0, geo.size.width - spacingTotal)
                    HStack(spacing: 5) {
                        ForEach(segments) { seg in
                            let isActive = (vm.activeChordSpanID == seg.spanID) && (vm.isPlaying || vm.selectedBeadID != nil)
                            let segCol = seg.chord.color(isNight: palette.isNight)
                            let segW = max(4.0, usableW * CGFloat(seg.fractionWidth))

                            Button {
                                vm.cycleSpanChord(spanIndex: seg.spanID)
                                onWakeTimeline()
                            } label: {
                                ZStack {
                                    Capsule()
                                        .fill(isActive ? segCol : palette.cardSurface)
                                        .shadow(
                                            color: palette.elevationShadow(dayOpacity: 0.08, nightOpacity: 0.22),
                                            radius: 3,
                                            y: 1.5
                                        )
                                        .overlay(
                                            Capsule().fill(isActive ? Color.clear : segCol.opacity(palette.isNight ? 0.18 : 0.10))
                                        )
                                        .overlay(
                                            Capsule().strokeBorder(
                                                isActive ? Color.white.opacity(0.35) : segCol.opacity(0.45),
                                                lineWidth: 1.1
                                            )
                                        )
                                    HStack(spacing: 3) {
                                        Text(seg.romanLabel)
                                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        if segW >= 54 {
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 7.5, weight: .bold))
                                                .opacity(0.72)
                                        } else if segW >= 36 {
                                            Circle()
                                                .fill(isActive ? palette.contrastInkOnAccent.opacity(0.85) : segCol.opacity(0.75))
                                                .frame(width: 3.5, height: 3.5)
                                        }
                                    }
                                    .foregroundStyle(isActive ? palette.contrastInkOnAccent : segCol)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .frame(width: segW, height: 34)
                                .frame(
                                    minWidth: segW,
                                    minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                                )
                                .contentShape(Capsule())
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                            .accessibilityLabel("第 \(seg.spanID + 1) 幕和弦 \(seg.romanLabel) \(seg.chord.moodTitle)")
                            .accessibilityHint("轻点切换和弦进行")
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: vm.activeChordSpanID)
                }
                .frame(height: StorybookAffordanceMetrics.compactToolMinHitDimension)
            } else {
                Button {
                    vm.setChordPreset(.autoMatch)
                } label: {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(palette.secondaryInk.opacity(0.24))
                                .frame(maxWidth: .infinity)
                                .frame(height: 4.0)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        ChimmoKilnPillButtonSurface(
                            palette: palette,
                            accent: palette.bassRibbon,
                            isActive: false,
                            cornerRadius: 17
                        )
                    )
                    .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                    .contentShape(Capsule())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
                .accessibilityLabel("开启智能和弦伴奏")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(palette.shelfSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08), lineWidth: 0.9)
                )
        )
    }
}

internal struct StagePlaybackNavigationActions: ViewModifier {
    @ObservedObject var vm: StudioViewModel

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: vm.isPlaying ? "暂停" : "播放") {
                vm.togglePlayback()
            }
            .accessibilityAction(named: "试听开头") {
                vm.previewOpeningPhrase()
            }
            .accessibilityAction(named: "跳到下一句") {
                vm.stepPhrase(delta: 1)
            }
            .accessibilityAction(named: "跳到上一句") {
                vm.stepPhrase(delta: -1)
            }
    }
}

internal struct StageBeatEditActions: ViewModifier {
    @ObservedObject var vm: StudioViewModel
    let isEnabled: Bool

    private func ensureSelectedBeat() {
        if vm.selectedBeadID == nil {
            vm.selectedBeadID = vm.document.notes.first?.id
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityAction(named: "升高一音") {
                    vm.shiftSelectedBeadPitch(delta: 1)
                }
                .accessibilityAction(named: "降低一音") {
                    vm.shiftSelectedBeadPitch(delta: -1)
                }
                .accessibilityAction(named: "延长当前拍") {
                    ensureSelectedBeat()
                    vm.adjustSelectedBeadDuration(delta: 0.22)
                }
                .accessibilityAction(named: "缩短当前拍") {
                    ensureSelectedBeat()
                    vm.adjustSelectedBeadDuration(delta: -0.18)
                }
                .accessibilityAction(named: "提前微调") {
                    ensureSelectedBeat()
                    vm.nudgeSelectedBeadTiming(delta: -0.10)
                }
                .accessibilityAction(named: "延后微调") {
                    ensureSelectedBeat()
                    vm.nudgeSelectedBeadTiming(delta: 0.10)
                }
                .accessibilityAction(named: "插入一拍") {
                    vm.insertBeatAfterSelected()
                }
                .accessibilityAction(named: "删除当前拍") {
                    vm.deleteSelectedBead()
                }
        } else {
            content
        }
    }
}
