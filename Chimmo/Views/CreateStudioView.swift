import SwiftUI

/// 咩哞专属「创作」自由编曲空间（严格与赏析引导区隔离）：
/// - 独立空白草稿 / 改编草稿上下文，浏览经典名曲绝不覆盖未保存编曲；
/// - 顶部含「作品」抽屉、纯文字标题与保存状态、撤销 / 新建未保存确认 / 更多菜单；
/// - 画布支持点按写入与拖拽音珠、下方四键直观调出哼唱/节奏画线/变奏夜灯/调音色；
/// - 底部配备不可错过的「试听」与「保存作品」双主力触控按钮，告别“找不到保存和试听”。
public struct CreateStudioView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenSharePostcard: () -> Void
    public let onOpenShowcaseSpecimen: (MelodyDocument, Bool) -> Void
    public let onShareSavedEntry: ((SavedMelodyEntry) -> Void)?
    public let onOpenSavedInShowcase: ((SavedMelodyEntry) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showWorksDrawer: Bool = false
    @State private var showDreamSheet: Bool = false
    @State private var dreamInitialTab: Int = 0
    @State private var showSoundSheet: Bool = false
    @State private var showRenameAlert: Bool = false
    @State private var renameDraft: String = ""
    @State private var showDiscardConfirm: Bool = false
    @State private var wakeSignal: Int = 0

    public init(
        vm: StudioViewModel,
        palette: ChimmoPalette,
        onOpenSharePostcard: @escaping () -> Void = {},
        onOpenShowcaseSpecimen: @escaping (MelodyDocument, Bool) -> Void = { _, _ in },
        onShareSavedEntry: ((SavedMelodyEntry) -> Void)? = nil,
        onOpenSavedInShowcase: ((SavedMelodyEntry) -> Void)? = nil
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenSharePostcard = onOpenSharePostcard
        self.onOpenShowcaseSpecimen = onOpenShowcaseSpecimen
        self.onShareSavedEntry = onShareSavedEntry
        self.onOpenSavedInShowcase = onOpenSavedInShowcase
    }

    private var selectedBeatIndex: Int? {
        guard let id = vm.selectedBeadID else { return nil }
        return vm.document.notes.firstIndex { $0.id == id }
    }

    private var draftStatusText: String {
        CreationDraftMetrics.statusLine(
            noteCount: vm.document.notes.count,
            totalDuration: vm.document.totalDuration,
            isSaved: vm.currentSavedEntryID != nil,
            hasUnsavedChanges: vm.hasUnsavedCreationChanges
        )
    }

    private var draftStatusColor: Color {
        if vm.document.notes.isEmpty {
            return palette.secondaryInk
        }
        if vm.hasUnsavedCreationChanges || vm.currentSavedEntryID == nil {
            return palette.nightLampGold
        }
        return palette.homeAnchor
    }

    private var createKeyboardPromptText: String {
        if vm.followGlowActive {
            return "按亮灯小偶跟弹练习"
        }
        if vm.selectedBeadID != nil {
            return "点按琴键修改当前选中音高"
        }
        return "点按七小只琴键写入音符"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 10) {
                    creationTopBar
                        .padding(.horizontal, 16)

                    StageCanvasPanel(
                        vm: vm,
                        palette: palette,
                        allowsEditing: true,
                        reduceMotion: reduceMotion,
                        wakeSignal: wakeSignal,
                        onOpenSoundSheet: {
                            showSoundSheet = true
                        },
                        onUserDidEdit: {
                            vm.hasUnsavedCreationChanges = true
                        },
                        emptyOverlay: {
                            emptyCreationCanvasOverlay
                        }
                    )
                    .padding(.horizontal, 16)

                    if vm.followGlowActive {
                        creationFollowGlowBar
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if let idx = selectedBeatIndex, !vm.isPlaying {
                        compactCreationBeatBar(idx: idx)
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if !vm.document.notes.isEmpty {
                        StageHarmonyRibbonView(
                            vm: vm,
                            palette: palette,
                            reduceMotion: reduceMotion
                        ) {
                            wakeSignal &+= 1
                        }
                        .padding(.horizontal, 16)
                    }

                    creationToolsBar
                        .padding(.horizontal, 16)

                    VStack(spacing: 4) {
                        Text(createKeyboardPromptText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.secondaryInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        StageChoirKeyboardBar(
                            vm: vm,
                            palette: palette,
                            reduceMotion: reduceMotion,
                            showsSmartHints: true,
                            onWakeTimeline: {
                                wakeSignal &+= 1
                            },
                            onKeyStrike: { lane, vel, bright in
                                vm.appendOrReplaceNoteFromCreateKey(
                                    lane,
                                    touchIntensity: vel,
                                    touchBrightness: bright
                                )
                            }
                        )
                    }
                    .padding(.horizontal, 16)

                    creationBottomConsole
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
                .padding(.top, 4)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("重命名作品", isPresented: $showRenameAlert) {
                TextField("作品名称", text: $renameDraft)
                Button("确定") {
                    vm.renameCurrentSong(renameDraft)
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog(
                "当前作品尚未保存，要如何处理？",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("保存并新建") {
                    vm.saveCurrentToNotebook()
                    vm.startBlankCanvas()
                }
                Button("放弃改动并新建", role: .destructive) {
                    vm.startBlankCanvas()
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showWorksDrawer) {
                MusicBoxShelfView(
                    palette: palette,
                    synth: vm.synth,
                    notebook: vm.notebook,
                    currentDocumentID: vm.document.id,
                    initialSegment: 0,
                    navigationTitleText: "我的作品",
                    showsDismissButton: true,
                    onLoadSavedToBoard: { entry in
                        showWorksDrawer = false
                        vm.openSavedEntryInCreate(entry, autoPlay: false)
                    },
                    onPlaySavedInShowcase: onOpenSavedInShowcase.map { callback in
                        { entry in
                            showWorksDrawer = false
                            callback(entry)
                        }
                    },
                    onPlayAlongSpecimen: { spec in
                        showWorksDrawer = false
                        onOpenShowcaseSpecimen(spec, true)
                    },
                    onEditSpecimenOnBoard: { spec in
                        showWorksDrawer = false
                        onOpenShowcaseSpecimen(spec, false)
                    },
                    onBorrowAtmosphere: { spec in
                        showWorksDrawer = false
                        vm.borrowHarmonyAtmosphere(from: spec)
                    },
                    onShareSavedEntry: { entry in
                        showWorksDrawer = false
                        if let onShareSavedEntry {
                            onShareSavedEntry(entry)
                        } else {
                            onOpenSharePostcard()
                        }
                    },
                    onForkSpecimenToCreate: { spec in
                        showWorksDrawer = false
                        vm.openSpecimen(spec, autoPlay: false)
                        vm.forkCurrentShowcaseIntoCreate()
                    },
                    onStartNewTap: {
                        showWorksDrawer = false
                        dreamInitialTab = 0
                        showDreamSheet = true
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
            .sheet(isPresented: $showDreamSheet) {
                DreamCaptureSheet(vm: vm, palette: palette, initialTab: dreamInitialTab)
            }
            .sheet(isPresented: $showSoundSheet) {
                SoundPaletteBoxSheet(vm: vm, palette: palette)
            }
            .onAppear {
                if vm.requestOpenDreamSheet {
                    dreamInitialTab = 0
                    showDreamSheet = true
                    vm.requestOpenDreamSheet = false
                }
            }
            .onChange(of: vm.requestOpenDreamSheet) { _, shouldOpen in
                if shouldOpen {
                    dreamInitialTab = 0
                    showDreamSheet = true
                    vm.requestOpenDreamSheet = false
                }
            }
        }
    }

    // MARK: - 1. Creation Top Bar

    private var creationTopBar: some View {
        return HStack(spacing: 10) {
            Button {
                renameDraft = vm.document.title
                showRenameAlert = true
                AcousticHapticsEngine.shared.playScrubTick()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        ChimmoResonanceBead(
                            size: 9,
                            isNight: palette.isNight,
                            tint: palette.celadonAccent
                        )
                        Text(vm.document.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "pencil.line")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryInk)
                    }

                    Text(draftStatusText)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(draftStatusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.leading, 15)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
            .accessibilityLabel("作品名称 \(vm.document.title)，\(draftStatusText)")
            .accessibilityHint("轻点重命名当前创作作品")

            HStack(spacing: 6) {
                if vm.canUndo {
                    creationCircleButton(
                        systemName: "arrow.uturn.backward",
                        tint: palette.primaryInk,
                        accessibilityLabel: "撤销上一步"
                    ) {
                        vm.undo()
                    }
                    .storybookKeyboardShortcut(KeyboardShortcut("z", modifiers: .command), enabled: vm.activeSpace == .create)
                }

                creationCircleButton(
                    systemName: "plus",
                    tint: palette.homeAnchor,
                    accessibilityLabel: "新建空白作品"
                ) {
                    if vm.hasUnsavedCreationChanges && !vm.document.notes.isEmpty {
                        showDiscardConfirm = true
                    } else {
                        vm.startBlankCanvas()
                    }
                }
                .storybookKeyboardShortcut(KeyboardShortcut("n", modifiers: .command), enabled: vm.activeSpace == .create)

                Menu {
                    Button {
                        showWorksDrawer = true
                    } label: {
                        Label("打开作品集 (\(vm.notebook.entries.count))", systemImage: "books.vertical")
                    }

                    Button {
                        renameDraft = vm.document.title
                        showRenameAlert = true
                    } label: {
                        Label("重命名作品", systemImage: "pencil")
                    }

                    Button {
                        showSoundSheet = true
                    } label: {
                        Label("声音调色盒", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        onOpenSharePostcard()
                    } label: {
                        Label("分享导出 PNG / WAV / MIDI", systemImage: "square.and.arrow.up")
                    }
                    .disabled(vm.document.notes.isEmpty)

                    Divider()

                    Button(role: .destructive) {
                        vm.startBlankCanvas()
                    } label: {
                        Label("清空画布", systemImage: "trash")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(palette.cardSurface)
                            .frame(width: 36, height: 36)
                            .shadow(
                                color: palette.isNight ? Color.black.opacity(0.24) : Color(hex: 0x7A5230).opacity(0.09),
                                radius: 3,
                                y: 1.5
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                        lineWidth: 0.9
                                    )
                            )
                        Image(systemName: "ellipsis")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                }
                .accessibilityLabel("更多创作操作")
            }
            .fixedSize()
        }
    }

    private func creationCircleButton(
        systemName: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(palette.cardSurface)
                    .frame(width: 36, height: 36)
                    .shadow(
                        color: palette.isNight ? Color.black.opacity(0.24) : Color(hex: 0x7A5230).opacity(0.09),
                        radius: 3,
                        y: 1.5
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                lineWidth: 0.9
                            )
                    )
                Image(systemName: systemName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 2. Empty Creation Canvas Overlay

    private var emptyCreationCanvasOverlay: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)

        return ZStack {
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    Canvas { ctx, size in
                        let profile = StorybookIllustrationLayout.rollingHillProfile(
                            sampleCount: 14,
                            amplitude: 0.16,
                            phaseShift: 1.1
                        )
                        guard !profile.isEmpty else { return }
                        var hill = Path()
                        hill.move(to: CGPoint(x: 0, y: size.height))
                        for pt in profile {
                            hill.addLine(
                                to: CGPoint(
                                    x: CGFloat(pt.xFraction) * size.width,
                                    y: size.height * 0.28 + CGFloat(pt.yFraction - 0.5) * size.height * 0.32
                                )
                            )
                        }
                        hill.addLine(to: CGPoint(x: size.width, y: size.height))
                        hill.closeSubpath()
                        ctx.fill(hill, with: .color(palette.storybookHillFront))
                    }
                    .frame(height: 112)

                    HStack(alignment: .bottom, spacing: 10) {
                        ChimmoFigureView(
                            member: .taono,
                            isNight: palette.isNight,
                            isMinor: vm.document.scaleMode.isMinorFlavored,
                            isSinging: false
                        )
                        .scaleEffect(0.84)

                        LivingChimmoDuoBadgeView(
                            isNight: palette.isNight,
                            accentColor: skyColor,
                            melodyActive: false,
                            cowAwake: vm.cradleEnabled
                        )
                        .frame(width: 84, height: 56)

                        ChimmoFigureView(
                            member: .corllo,
                            isNight: palette.isNight,
                            isMinor: vm.document.scaleMode.isMinorFlavored,
                            isSinging: false
                        )
                        .scaleEffect(0.84)
                    }
                    .padding(.bottom, 64)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Spacer()

                Button {
                    dreamInitialTab = 1
                    showDreamSheet = true
                } label: {
                    Label("轻哼一段旋律", systemImage: "mic.fill")
                }
                .buttonStyle(.chimmoVinyl(palette: palette, tint: palette.prominentFill, prominent: true))
                .accessibilityHint("打开轻哼捕捉面板，把脑海里的旋律变成音珠")

                HStack(spacing: 8) {
                    ForEach(CreationStarterSeed.allCases) { seed in
                        Button {
                            vm.plantCreationStarter(seed)
                        } label: {
                            Label(seed.shortLabel, systemImage: seed.iconName)
                                .font(.system(.caption, design: .rounded).weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 40)
                                .background(
                                    ChimmoKilnPillButtonSurface(
                                        palette: palette,
                                        accent: seed.recommendedScaleMode.skyAuroraColor(isNight: palette.isNight),
                                        isActive: false,
                                        cornerRadius: 20
                                    )
                                )
                                .foregroundStyle(palette.primaryInk)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.3))
                        .accessibilityLabel("使用\(seed.shortLabel)起音灵感")
                    }
                }
                .padding(.horizontal, 14)

                Text("或直接轻点画布与下方七小只写音")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryInk)
            }
            .padding(.bottom, 14)
        }
    }

    private var creationFollowGlowBar: some View {
        let totalCount = max(1, vm.document.notes.count)
        let curStep = min(vm.followGlowIndex + 1, totalCount)
        return HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.nightLampGold)

            Text("跟灯练习 · \(curStep)/\(totalCount)")
                .font(.system(.caption, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(palette.primaryInk)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                vm.toggleFollowGlow()
            } label: {
                Text("退出跟灯")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(palette.primaryInk)
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
                    .contentShape(Capsule())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("退出跟灯练习")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.inner)
    }

    // MARK: - 3. Compact Two-Row Selected Beat Editor (Pitch Step + Duration + >= 40pt Hit Targets)

    @ViewBuilder
    private func compactCreationBeatBar(idx: Int) -> some View {
        if vm.document.notes.indices.contains(idx) {
            let bead = vm.document.notes[idx]
            let desc = CreateBeatAdjustmentDescriptor(
                bead: bead,
                index: idx,
                totalCount: vm.document.notes.count,
                pentatonicSafe: vm.pentatonicSafe
            )
            let laneColor = desc.lane.barColor(isNight: palette.isNight)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    beatNavStepButton(
                        systemName: "chevron.left",
                        enabled: desc.canStepPrevious,
                        tint: palette.primaryInk,
                        accessibilityLabel: "上一拍"
                    ) {
                        vm.stepSelectedBeat(delta: -1)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        StorybookQuietTag(
                            text: desc.beatProgressLabel,
                            tint: laneColor,
                            textColor: laneColor,
                            isNight: palette.isNight
                        )

                        StorybookQuietTag(
                            text: desc.pitchSummaryLabel,
                            tint: laneColor,
                            textColor: palette.primaryInk,
                            isNight: palette.isNight
                        )
                    }
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: 4)

                    beatNavStepButton(
                        systemName: "chevron.right",
                        enabled: desc.canStepNext,
                        tint: palette.homeAnchor,
                        accessibilityLabel: "下一拍"
                    ) {
                        vm.stepSelectedBeat(delta: 1)
                    }

                    beatNavStepButton(
                        systemName: "xmark",
                        enabled: true,
                        tint: palette.secondaryInk,
                        accessibilityLabel: "完成单拍调整"
                    ) {
                        vm.selectedBeadID = nil
                    }
                }

                HStack(spacing: 6) {
                    beatToolIconButton(
                        "arrow.down",
                        label: "音高降一格",
                        tint: palette.bassRibbon,
                        enabled: desc.canStepPitchDown
                    ) {
                        vm.shiftSelectedBeadPitch(delta: -1)
                    }
                    beatToolIconButton(
                        "arrow.up",
                        label: "音高升一格",
                        tint: palette.bassRibbon,
                        enabled: desc.canStepPitchUp
                    ) {
                        vm.shiftSelectedBeadPitch(delta: 1)
                    }
                    beatToolIconButton(
                        "minus.circle",
                        label: "缩短音符",
                        tint: palette.primaryInk
                    ) {
                        vm.adjustSelectedBeadDuration(delta: -0.18)
                    }
                    beatToolIconButton(
                        "plus.circle",
                        label: "延长音符",
                        tint: palette.primaryInk
                    ) {
                        vm.adjustSelectedBeadDuration(delta: 0.22)
                    }
                    beatToolIconButton(
                        "plus.square.on.square",
                        label: "插入一拍",
                        tint: palette.homeAnchor
                    ) {
                        vm.insertBeatAfterSelected()
                    }
                    beatToolIconButton(
                        "trash",
                        label: "删除选中音符",
                        tint: palette.melodyTerracotta
                    ) {
                        vm.deleteSelectedBead()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                StorybookQuietCardSurface(palette: palette, cornerRadius: 16)
            )
            .accessibilityElement(children: .contain)
            .accessibilityValue("第 \(desc.beatProgressLabel) 拍 \(desc.pitchSummaryLabel)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    if desc.canStepPitchUp { vm.shiftSelectedBeadPitch(delta: 1) }
                case .decrement:
                    if desc.canStepPitchDown { vm.shiftSelectedBeadPitch(delta: -1) }
                @unknown default:
                    break
                }
            }
        }
    }

    private func beatNavStepButton(
        systemName: String,
        enabled: Bool,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
                .frame(width: 34, height: 34)
                .background(
                    ChimmoKilnPillButtonSurface(palette: palette, accent: tint, isActive: false, cornerRadius: 12)
                )
                .foregroundStyle(enabled ? tint : palette.secondaryInk.opacity(0.35))
                .frame(
                    minWidth: StorybookAffordanceMetrics.compactToolMinHitDimension,
                    minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension
                )
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel(accessibilityLabel)
    }

    private func beatToolIconButton(
        _ systemName: String,
        label: String,
        tint: Color,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: StorybookAffordanceMetrics.compactToolMinHitDimension)
                .background(
                    ChimmoKilnPillButtonSurface(palette: palette, accent: tint, isActive: false, cornerRadius: 12)
                )
                .foregroundStyle(enabled ? tint : palette.secondaryInk.opacity(0.35))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!enabled)
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel(label)
    }

    // MARK: - 4. Creation Quick Tools Strip

    private var creationToolsBar: some View {
        HStack(spacing: 8) {
            creationToolChip(title: "轻哼捕音", icon: "mic.fill", accent: palette.homeAnchor) {
                dreamInitialTab = 1
                showDreamSheet = true
            }
            creationToolChip(title: "节奏灵感", icon: "waveform.path", accent: palette.nightLampGold) {
                dreamInitialTab = 0
                showDreamSheet = true
            }
            creationToolChip(title: "音色和声", icon: "slider.horizontal.3", accent: palette.celadonAccent) {
                showSoundSheet = true
            }
        }
    }

    private func creationToolChip(
        title: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                ChimmoKilnPillButtonSurface(
                    palette: palette,
                    accent: accent,
                    isActive: false,
                    cornerRadius: 14
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
    }

    // MARK: - 5. Bottom Unmissable Audition & Save Console

    private var creationBottomConsole: some View {
        let isEmpty = vm.document.notes.isEmpty
        let needsSave = !isEmpty && (vm.currentSavedEntryID == nil || vm.hasUnsavedCreationChanges)

        return HStack(spacing: 8) {
            Button {
                vm.auditionCurrentCreation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text(vm.isPlaying ? "停止" : "试听")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    ChimmoKilnPillButtonSurface(
                        palette: palette,
                        accent: vm.isPlaying ? palette.nightLampGold : palette.celadonAccent,
                        isActive: vm.isPlaying,
                        cornerRadius: 23
                    )
                )
                .foregroundStyle(palette.primaryInk)
                .contentShape(Capsule())
            }
            .disabled(isEmpty)
            .opacity(isEmpty ? 0.45 : 1.0)
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel(vm.isPlaying ? "停止试听当前创作" : "试听当前创作")
            .accessibilityHint("播放或停止试听当前创作，支持空格键控制")
            .storybookKeyboardShortcut(KeyboardShortcut(.space, modifiers: []), enabled: vm.activeSpace == .create)

            Button {
                vm.saveCurrentToNotebook()
            } label: {
                let saveFill: Color = needsSave
                    ? palette.prominentFill
                    : (isEmpty ? palette.shelfSurface : palette.storybookMint)
                HStack(spacing: 6) {
                    saveStatusIcon(needsSave: needsSave)
                    Text(needsSave || isEmpty ? "保存作品" : "已保存")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    ZStack {
                        Capsule()
                            .fill(saveFill)
                            .shadow(
                                color: needsSave
                                    ? palette.prominentFill.opacity(palette.isNight ? 0.34 : 0.24)
                                    : (palette.isNight ? Color.black.opacity(0.18) : Color(hex: 0x7A5230).opacity(0.08)),
                                radius: needsSave ? 5 : 3,
                                y: 2
                            )
                        Capsule()
                            .strokeBorder(
                                needsSave
                                    ? Color.white.opacity(palette.isNight ? 0.16 : 0.35)
                                    : palette.primaryInk.opacity(palette.isNight ? 0.12 : 0.08),
                                lineWidth: 1.0
                            )
                    }
                )
                .foregroundStyle(needsSave ? Color.white : palette.primaryInk)
                .contentShape(Capsule())
            }
            .disabled(isEmpty)
            .opacity(isEmpty ? 0.48 : 1.0)
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel(needsSave ? "保存作品到我的曲库" : "当前作品已保存")
            .accessibilityHint("保存到我的曲库，支持 Command+S 快捷键")
            .storybookKeyboardShortcut(KeyboardShortcut("s", modifiers: .command), enabled: vm.activeSpace == .create)

            Button {
                onOpenSharePostcard()
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.cardSurface)
                        .frame(width: 44, height: 44)
                        .shadow(
                            color: palette.isNight ? Color.black.opacity(0.24) : Color(hex: 0x7A5230).opacity(0.09),
                            radius: 3.5,
                            y: 2
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                                    lineWidth: 0.9
                                )
                        )
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                }
                .frame(width: 46, height: 46)
                .contentShape(Circle())
            }
            .disabled(isEmpty)
            .opacity(isEmpty ? 0.45 : 1.0)
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("分享导出当前创作作品")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.stage)
    }

    @ViewBuilder
    private func saveStatusIcon(needsSave: Bool) -> some View {
        let symbol = Image(systemName: needsSave ? "square.and.arrow.down.fill" : "checkmark.circle.fill")
            .font(.subheadline.weight(.bold))
        if reduceMotion {
            symbol
        } else {
            symbol.symbolEffect(.bounce, value: vm.lastSavedPulse)
        }
    }
}
