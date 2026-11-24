import QuartzCore
import SwiftUI

/// 咩哞 v0.10 旗舰三态声画主舞台：
/// - 模式 A「星盘」：音乐盒式旋转同心声盘，盘面随旋律顺滑旋转，外环悬浮四幕情绪中文锚词，支持巴赫影子月亮对位、单指手摇搓盘、拖珠改音、外环换和声；
/// - 模式 B「山河」：28% 处固定金光束，整片旋律山河与湖面倒影平滑向左流淌，永远停留在视线中心；
/// - 模式 C「星云」：8 颗星辰环绕中央利萨如谐振星核，金色彗星沿旋律星座划过，单指点按或滑过星辰即兴共鸣；
/// - 零乐理三重无障碍编码：颜色 + 轨道高低 + 8 种纯几何矢量图腾（圆点/圆方/三角/棱镜/五星/水滴/星芒/双环），辅以 CoreHaptics 掌心音乐触觉与 VoiceOver 语义读音。
public struct OrbitalStageView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenAbout: () -> Void
    public let onOpenSharePostcard: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showDreamSheet: Bool = false
    @State private var showMoodSheet: Bool = false
    @State private var showRenameAlert: Bool = false
    @State private var renameDraft: String = ""
    @State private var rippleWakeActive: Bool = false
    @State private var rippleWakeTask: Task<Void, Never>? = nil
    @State private var duoGreetingPulse: Bool = false
    @State private var duoGreetingTask: Task<Void, Never>? = nil

    // 手势交互态（仅局部瞬态，绝不触发重排版死循环）
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
    @State private var struckRibbonLane: Int? = nil
    @State private var ribbonDragAnchorY: CGFloat? = nil
    @State private var ribbonMercuryLevel: Double = 0.0
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

    public init(
        vm: StudioViewModel,
        palette: ChimmoPalette,
        onOpenAbout: @escaping () -> Void,
        onOpenSharePostcard: @escaping () -> Void = {}
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenAbout = onOpenAbout
        self.onOpenSharePostcard = onOpenSharePostcard
    }

    private var selectedBeatIndex: Int? {
        guard let id = vm.selectedBeadID else { return nil }
        return vm.document.notes.firstIndex { $0.id == id }
    }

    private var targetFollowLaneIndex: Int? {
        guard vm.followGlowActive,
              vm.followGlowIndex < vm.document.notes.count else { return nil }
        let b = vm.document.notes[vm.followGlowIndex]
        return XylophoneLane.laneIndex(degree: b.degree, octaveOffset: b.octaveOffset)
    }

    private var smartHintByLane: [Int: SmartPitchHint] {
        guard vm.smartHintActive else { return [:] }
        return Dictionary(uniqueKeysWithValues: vm.smartHints.map { ($0.laneIndex, $0) })
    }

    private var shouldRunCanvasTimeline: Bool {
        !reduceMotion && (vm.isPlaying || rippleWakeActive || isActivelyDraggingStage || vm.activeVibratoLane != nil || !vm.activeLaneIndices.isEmpty)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 8) {
                    topStageHeader
                        .padding(.horizontal, 14)

                    heroStageContainer
                        .padding(.horizontal, 14)

                    if !vm.followGlowActive && !vm.document.notes.isEmpty {
                        StageHarmonyRibbonView(
                            vm: vm,
                            palette: palette,
                            reduceMotion: reduceMotion
                        ) {
                            wakeRippleTimeline()
                        }
                        .padding(.horizontal, 14)
                    }

                    if selectedBeatIndex != nil && !vm.isPlaying && !vm.followGlowActive {
                        compactSelectionPill
                            .padding(.horizontal, 14)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    rainbowKeyRibbon
                        .padding(.horizontal, 14)

                    bottomGlassDock
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                }
                .padding(.top, 2)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        vm.auditionDuoGreeting()
                        duoGreetingPulse = true
                        duoGreetingTask?.cancel()
                        duoGreetingTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 520_000_000)
                            if !Task.isCancelled {
                                duoGreetingPulse = false
                            }
                        }
                    } label: {
                        let crownGaze = Double((vm.latestDegree ?? 4) - 4) / 3.0
                        LivingChimmoDuoBadgeView(
                            isNight: palette.isNight,
                            accentColor: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight),
                            melodyActive: !vm.activeLaneIndices.isEmpty || duoGreetingPulse,
                            cowAwake: vm.cradleEnabled,
                            gazeBias: crownGaze
                        )
                        .frame(width: 38, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("咩哞双子问候")
                    .accessibilityHint("轻点试听小羊与小牛和音")
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    if vm.canUndo {
                        Button {
                            vm.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .accessibilityLabel("撤销上一步")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        vm.saveCurrentToNotebook()
                    } label: {
                        Image(systemName: vm.currentSavedEntryID != nil ? "bookmark.fill" : "bookmark")
                            .symbolEffect(.bounce, value: vm.lastSavedPulse)
                    }
                    .accessibilityLabel("保存到我的曲库")

                    Button {
                        onOpenSharePostcard()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("分享作品图片、音频与 MIDI")

                    Button {
                        onOpenAbout()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("关于与隐私承诺")
                }
            }
            .alert("作品名称", isPresented: $showRenameAlert) {
                TextField("", text: $renameDraft)
                Button("确定") {
                    vm.renameCurrentSong(renameDraft)
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showDreamSheet) {
                DreamCaptureSheet(vm: vm, palette: palette)
            }
            .sheet(isPresented: $showMoodSheet) {
                MoodAndSoundSheet(vm: vm, palette: palette)
            }
            .onChange(of: vm.latestDegree) { _, _ in
                wakeRippleTimeline()
            }
            .onChange(of: vm.followGlowIndex) { _, _ in
                wakeRippleTimeline()
            }
            .onChange(of: vm.document.id) { _, _ in
                manualRiverScrollX = 0
                vm.endStarVibrato()
                wakeRippleTimeline()
            }
            .onChange(of: vm.visualMode) { _, _ in
                struckNebulaLane = nil
                struckRibbonLane = nil
                ribbonDragAnchorY = nil
                ribbonMercuryLevel = 0.0
                vm.endStarVibrato()
            }
            .onChange(of: vm.followGlowActive) { _, _ in
                struckRibbonLane = nil
                ribbonDragAnchorY = nil
                ribbonMercuryLevel = 0.0
                vm.endStarVibrato()
            }
            .onDisappear {
                struckNebulaLane = nil
                struckRibbonLane = nil
                ribbonDragAnchorY = nil
                ribbonMercuryLevel = 0.0
                vm.endStarVibrato()
            }
            .onAppear {
                if vm.requestOpenDreamSheet {
                    showDreamSheet = true
                    vm.requestOpenDreamSheet = false
                }
            }
            .onChange(of: vm.requestOpenDreamSheet) { _, shouldOpen in
                if shouldOpen {
                    showDreamSheet = true
                    vm.requestOpenDreamSheet = false
                }
            }
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

    // MARK: - 1. Minimal Floating Header + Pure-Icon Mode Switcher

    private var topStageHeader: some View {
        HStack(spacing: 10) {
            Button {
                renameDraft = vm.document.title
                showRenameAlert = true
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight))
                        .frame(width: 8, height: 8)

                    Text(vm.document.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("作品名称 \(vm.document.title)")
            .accessibilityHint("轻点重命名当前旋律")

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                ForEach(StageVisualMode.allCases) { mode in
                    let active = vm.visualMode == mode
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                            vm.visualMode = mode
                        }
                    } label: {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 12.5, weight: .bold))
                            .frame(width: 30, height: 26)
                            .background(
                                Capsule().fill(active ? palette.homeAnchor : Color.clear)
                            )
                            .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.secondaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换到\(mode.rawValue)视图")
                }
            }
            .fixedSize()
            .padding(3)
            .background(Capsule().fill(palette.cardSurface.opacity(palette.isNight ? 0.85 : 0.92)))
            .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.18 : 0.05), radius: 6, y: 2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    // MARK: - 2. Hero Stage Container (Orbital Disc OR Flowing River OR Resonance Nebula)

    private var heroStageContainer: some View {
        let boardBg = palette.isNight ? Color(hex: 0x121936) : Color(hex: 0xFAF6EE)
        let activeCurtainColor: Color? = (vm.cradleEnabled && (vm.isPlaying || vm.selectedBeadID != nil))
            ? vm.chordSpans.first(where: { $0.id == vm.activeChordSpanID })?.chord.color(isNight: palette.isNight)
            : nil
        let borderCol = activeCurtainColor?.opacity(palette.isNight ? 0.50 : 0.44)
            ?? (palette.isNight ? palette.nightLampGold.opacity(0.20) : Color(hex: 0xCBB18D).opacity(0.32))
        let stageShadowCol = activeCurtainColor?.opacity(palette.isNight ? 0.34 : 0.16)
            ?? palette.primaryInk.opacity(palette.isNight ? 0.28 : 0.07)

        return GeometryReader { geo in
            ZStack {
                stageInteractiveCanvas
                    .modifier(StagePlaybackNavigationActions(vm: vm))
                    .modifier(StageBeatEditActions(vm: vm))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                if !isActivelyDraggingStage {
                                    isActivelyDraggingStage = true
                                }
                                switch vm.visualMode {
                                case .orbitalDisc:
                                    handleOrbitalDragChanged(val, in: geo.size)
                                case .flowingRiver:
                                    handleRiverDragChanged(val, in: geo.size)
                                case .resonanceNebula:
                                    handleNebulaDragChanged(val, in: geo.size)
                                }
                            }
                            .onEnded { val in
                                isActivelyDraggingStage = false
                                switch vm.visualMode {
                                case .orbitalDisc:
                                    handleOrbitalDragEnded(val, in: geo.size)
                                case .flowingRiver:
                                    handleRiverDragEnded(val, in: geo.size)
                                case .resonanceNebula:
                                    handleNebulaDragEnded(val, in: geo.size)
                                }
                            }
                    )

                if vm.document.notes.isEmpty {
                    LivingChimmoDuoBadgeView(
                        isNight: palette.isNight,
                        accentColor: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight),
                        melodyActive: false,
                        cowAwake: vm.cradleEnabled
                    )
                    .frame(width: 78, height: 50)
                    .opacity(palette.isNight ? 0.44 : 0.38)
                    .allowsHitTesting(false)

                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Button {
                                vm.plantDuoStarterMotif()
                            } label: {
                                Label("咩哞起音", systemImage: "sparkles")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(palette.homeAnchor))
                                    .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("生成咩哞示范短句")

                            Button {
                                showDreamSheet = true
                            } label: {
                                Label("写旋律", systemImage: "wand.and.stars")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(palette.cardSurface.opacity(0.94))
                                            .overlay(Capsule().strokeBorder(palette.divider, lineWidth: 1.0))
                                    )
                                    .foregroundStyle(palette.primaryInk)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("打开写旋律面板")
                        }
                        .padding(.bottom, 12)
                    }
                }

                // 顶部极简声学状态标（无文字堆砌；展示伴唱、倍速、音区移调与律动状态，及麦克风异常提示）
                VStack {
                    HStack(alignment: .top) {
                        if vm.shadowCounterpointEnabled
                            || abs(vm.playbackRate - 1.0) > 0.01
                            || vm.document.rootMIDI != 60
                            || vm.document.grooveStrength > 0.08 {
                            activeFeaturesOverlay
                        }
                        Spacer(minLength: 8)
                    }
                    if let errorMsg = vm.statusToast {
                        Text(errorMsg)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(palette.melodyTerracotta.opacity(0.92)))
                            .transition(.opacity)
                    }
                    Spacer()
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(boardBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(borderCol, lineWidth: activeCurtainColor != nil ? 1.8 : 1.2)
            )
            .shadow(color: stageShadowCol, radius: activeCurtainColor != nil ? 18 : 14, y: 5)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: vm.activeChordSpanID)
        }
        .frame(minHeight: 220, maxHeight: .infinity)
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
            showMoodSheet = true
        } label: {
            HStack(spacing: 6) {
                if vm.shadowCounterpointEnabled {
                    ChimmoCraftMark(.counterpointMoons, color: Color(hex: 0x4EA8DE))
                        .frame(width: 12, height: 12)
                }
                if abs(vm.playbackRate - 1.0) > 0.01 {
                    HStack(spacing: 3) {
                        ChimmoCraftMark(.tempoDial, color: palette.nightLampGold)
                            .frame(width: 11, height: 11)
                        Text(String(format: "%.2g×", vm.playbackRate))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(palette.nightLampGold)
                }
                if vm.document.rootMIDI != 60 {
                    HStack(spacing: 2) {
                        Image(systemName: "tuningfork")
                            .font(.system(size: 9, weight: .bold))
                        Text(RootTranspositionHelper.compactLabel(forRootMIDI: vm.document.rootMIDI))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(palette.harmonyWash)
                }
                if vm.document.grooveStrength > 0.08 {
                    Image(systemName: "metronome")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(palette.homeAnchor)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(palette.cardSurface.opacity(palette.isNight ? 0.85 : 0.92))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开声音设置调整伴唱、音区与节奏")
    }

    // MARK: - 2A. Orbital Turntable Disc Rendering

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

        // 2. 实体窑陶 / 深夜黑胶转盘盘面 + 顶部工作室柔光高光 + 22 道同心微音槽 + 12 刻度旋转锚点
        let platterRect = CGRect(
            x: m.center.x - m.platterRadius,
            y: m.center.y - m.platterRadius,
            width: m.platterRadius * 2,
            height: m.platterRadius * 2
        )
        let shadowRect = platterRect.offsetBy(dx: 0, dy: 6)
        ctx.fill(
            Path(ellipseIn: shadowRect),
            with: .color(Color.black.opacity(palette.isNight ? 0.44 : 0.10))
        )

        let discGrad = Gradient(colors: palette.isNight
            ? [Color(hex: 0x222D61), Color(hex: 0x131A3C)]
            : [Color(hex: 0xFFFFFF), Color(hex: 0xF1E8D9)]
        )
        ctx.fill(
            Path(ellipseIn: platterRect),
            with: .radialGradient(
                discGrad,
                center: CGPoint(x: m.center.x - m.platterRadius * 0.24, y: m.center.y - m.platterRadius * 0.28),
                startRadius: 8,
                endRadius: m.platterRadius * 1.18
            )
        )

        // 顶部柔和光泽穹顶高光
        let sheenGrad = Gradient(colors: [
            Color.white.opacity(palette.isNight ? 0.08 : 0.55),
            .clear
        ])
        ctx.fill(
            Path(ellipseIn: platterRect),
            with: .radialGradient(
                sheenGrad,
                center: CGPoint(x: m.center.x - m.platterRadius * 0.35, y: m.center.y - m.platterRadius * 0.40),
                startRadius: 2,
                endRadius: m.platterRadius * 0.95
            )
        )

        // 22 道细微同心声学刻槽，打造黑胶与手工陶盘质感
        let grooveStart = m.innerRadius * 0.94
        let grooveEnd = m.outerRadius * 1.04
        for g in 0..<22 {
            let gr = grooveStart + (CGFloat(g) / 21.0) * (grooveEnd - grooveStart)
            let gRect = CGRect(x: m.center.x - gr, y: m.center.y - gr, width: gr * 2, height: gr * 2)
            ctx.stroke(
                Path(ellipseIn: gRect),
                with: .color((palette.isNight ? Color.white : Color(hex: 0x6B5237)).opacity(0.055)),
                lineWidth: 0.65
            )
        }

        // 外缘桦木 / 烟熏胡桃木框与内倒角阴影
        let innerBevelRect = platterRect.insetBy(dx: 3.0, dy: 3.0)
        ctx.stroke(
            Path(ellipseIn: innerBevelRect),
            with: .color(Color.black.opacity(palette.isNight ? 0.28 : 0.06)),
            lineWidth: 1.5
        )
        let rimColor = palette.isNight ? Color(hex: 0x524036).opacity(0.75) : Color(hex: 0xD2B48C).opacity(0.85)
        ctx.stroke(Path(ellipseIn: platterRect), with: .color(rimColor), lineWidth: 3.4)
        if acoustic.rmsEnergy > 0.01 {
            ctx.stroke(
                Path(ellipseIn: platterRect),
                with: .color(palette.nightLampGold.opacity(acoustic.rmsEnergy * 0.36)),
                lineWidth: 3.4 + CGFloat(acoustic.rmsEnergy) * 2.5
            )
        }

        // 12 枚随盘面同转的极简节拍刻度（让任何缓慢旋律的旋转与声学共鸣一目了然）
        for tick in 0..<12 {
            let ta = -Double.pi / 2.0 + Double(tick) * (Double.pi / 6.0) + discRot
            let r0 = m.platterRadius * (tick % 3 == 0 ? 0.932 : 0.950)
            let r1 = m.platterRadius * 0.980
            var tp = Path()
            tp.move(to: CGPoint(x: m.center.x + CGFloat(cos(ta)) * r0, y: m.center.y + CGFloat(sin(ta)) * r0))
            tp.addLine(to: CGPoint(x: m.center.x + CGFloat(cos(ta)) * r1, y: m.center.y + CGFloat(sin(ta)) * r1))
            let baseOp = tick % 3 == 0 ? 0.72 : 0.35
            ctx.stroke(
                tp,
                with: .color((tick % 3 == 0 ? palette.nightLampGold : palette.secondaryInk).opacity(min(1.0, baseOp + acoustic.rmsEnergy * 0.22))),
                style: StrokeStyle(lineWidth: tick % 3 == 0 ? 1.8 : 1.1, lineCap: .round)
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

        // 节拍律动辐射引力线（仅当开启「微稳/整齐」律动吸附时温柔显影，随转盘共转）
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

        // 5.4 选中音符的径向调音滑轨（无字提示沿半径拖移可切换音高）
        if !vm.isPlaying,
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

            let isSelected = vm.selectedBeadID == item.bead.id
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

            // 玻璃陶瓷高光点
            let specR = orbR * 0.38
            let specRect = CGRect(
                x: item.pt.x - orbR * 0.48,
                y: item.pt.y - orbR * 0.56,
                width: specR * 1.4,
                height: specR * 0.9
            )
            ctx.fill(Path(ellipseIn: specRect), with: .color(.white.opacity(isFollowPassed ? 0.16 : 0.34)))
            ctx.stroke(Path(ellipseIn: orbRect), with: .color(.white.opacity(0.58)), lineWidth: 1.0)

            // 色盲友好八音阶几何矢量图腾
            let glyphSize = orbR * 1.15
            let glyphRect = CGRect(x: item.pt.x - glyphSize * 0.5, y: item.pt.y - glyphSize * 0.5, width: glyphSize, height: glyphSize)
            let glyphPath = PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: glyphRect)
            ctx.fill(glyphPath, with: .color(.white.opacity(0.96)), style: FillStyle(eoFill: true))
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
                    with: .color(Color(hex: 0x7EC8E3).opacity(isShadowSinging ? 0.34 : 0.10)),
                    style: StrokeStyle(lineWidth: 0.9, dash: [2, 3])
                )
                drawCrescentMoonOrb(
                    ctx: &ctx,
                    center: sPt,
                    radius: isShadowSinging ? 9.5 : 7.4,
                    color: Color(hex: 0x7EC8E3),
                    isGlowing: isShadowSinging
                )
            }
        }

        // 6. 中央利萨如谐振花纹玻璃圆心（实时映照当前声学和谐比例与实时响度呼吸）
        drawCenterMandalaHub(ctx: &ctx, center: m.center, hubRadius: m.innerRadius * 0.76, mediaNow: mediaNow, acoustic: acoustic)

        // 7. 12 点钟黄铜唱针与声波涟漪绽放 + 跟灯弹光桥
        if vm.followGlowActive,
           let targetLane = targetFollowLaneIndex,
           let targetPt = followTargetPt {
            drawFollowLightBridge(ctx: &ctx, from: targetPt, toLaneIndex: targetLane, canvasSize: size)
        }
        drawRipplesOnDisc(ctx: &ctx, metrics: m, discRot: discRot, needleAngle: needleAngle, mediaNow: mediaNow)
        drawTonearmNeedle(ctx: &ctx, metrics: m, needleAngle: needleAngle, isPlaying: vm.isPlaying, mediaNow: mediaNow)
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
        let c0 = XylophoneLane.lane(at: fromLane).barColor(isNight: palette.isNight)
        let c1 = XylophoneLane.lane(at: toLane).barColor(isNight: palette.isNight)
        let style = IntervalSilkStyle.metrics(fromLane: fromLane, toLane: toLane, isNight: palette.isNight)
        if style.glowWidth > 0 {
            let glowOp = min(0.55, style.glowOpacity + extraEnergy * 0.14)
            let glowGrad = Gradient(colors: [c0.opacity(glowOp), c1.opacity(glowOp)])
            ctx.stroke(
                path,
                with: .linearGradient(glowGrad, startPoint: startPt, endPoint: endPt),
                style: StrokeStyle(lineWidth: style.glowWidth * widthScale + CGFloat(extraEnergy) * 2.5, lineCap: .round)
            )
        }
        let coreOp = min(1.0, style.coreOpacity + extraEnergy * 0.20)
        let coreGrad = Gradient(colors: [c0.opacity(coreOp), c1.opacity(coreOp)])
        ctx.stroke(
            path,
            with: .linearGradient(coreGrad, startPoint: startPt, endPoint: endPt),
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
        let hubGrad = Gradient(colors: palette.isNight
            ? [Color(hex: 0xFFB84D).opacity(0.32), Color(hex: 0x242F63)]
            : [Color(hex: 0xFFE3A3).opacity(0.65), Color(hex: 0xF5E7CE)]
        )
        ctx.fill(
            Path(ellipseIn: hubRect),
            with: .radialGradient(hubGrad, center: center, startRadius: 2, endRadius: hubRadius)
        )
        ctx.stroke(Path(ellipseIn: hubRect), with: .color(palette.nightLampGold.opacity(0.55)), lineWidth: 1.5)

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

        // 中心黄铜轴心点
        let pinRect = CGRect(x: center.x - 4.2, y: center.y - 4.2, width: 8.4, height: 8.4)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(palette.nightLampGold))
        ctx.stroke(Path(ellipseIn: pinRect), with: .color(.white.opacity(0.65)), lineWidth: 0.8)
    }

    private func drawRipplesOnDisc(ctx: inout GraphicsContext, metrics: OrbitalMetrics, discRot: Double, needleAngle: Double, mediaNow: Double) {
        let active = vm.rippleBus.activeEvents(at: mediaNow)
        for ev in active {
            let age = mediaNow - ev.birthMediaTime
            let prog = max(0.0, min(1.0, age / 0.90))
            let rOrbit = OrbitalGeometry.orbitRadius(laneIndex: ev.laneIndex, innerRadius: metrics.innerRadius, outerRadius: metrics.outerRadius)
            let ang = vm.isPlaying ? needleAngle : (-Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: ev.onset, totalDuration: max(0.5, vm.document.totalDuration)) + discRot)
            let pt = CGPoint(x: metrics.center.x + CGFloat(cos(ang)) * rOrbit, y: metrics.center.y + CGFloat(sin(ang)) * rOrbit)
            let col = Color(hex: ev.colorHex)

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

    private func drawTonearmNeedle(ctx: inout GraphicsContext, metrics: OrbitalMetrics, needleAngle: Double, isPlaying: Bool, mediaNow: Double) {
        // 物理弹簧微颤：仅主旋律音珠触及唱针 0.18 秒内激发轻微阻尼微震
        var kickOffset: CGFloat = 0
        if !reduceMotion, let newest = vm.rippleBus.events.last(where: { !$0.isShadow }) {
            let age = mediaNow - newest.birthMediaTime
            if age >= 0 && age < 0.18 {
                kickOffset = CGFloat(sin(age * 35.0) * exp(-age * 14.0) * 3.5)
            }
        }

        // 12 点钟发光读取线（把盘上每一圈的同心点连向轴心，极高清晰度）
        let innerEdge = CGPoint(
            x: metrics.center.x + CGFloat(cos(needleAngle)) * (metrics.innerRadius * 0.85),
            y: metrics.center.y + CGFloat(sin(needleAngle)) * (metrics.innerRadius * 0.85)
        )
        let outerEdge = CGPoint(
            x: metrics.center.x + CGFloat(cos(needleAngle)) * (metrics.outerRadius + 10),
            y: metrics.center.y + CGFloat(sin(needleAngle)) * (metrics.outerRadius + 10)
        )
        var beam = Path()
        beam.move(to: innerEdge)
        beam.addLine(to: outerEdge)
        ctx.stroke(
            beam,
            with: .color(palette.nightLampGold.opacity(isPlaying ? 0.92 : 0.58)),
            style: StrokeStyle(lineWidth: isPlaying ? 3.0 : 2.0, lineCap: .round)
        )

        // 右上方斜插而下的双层拉丝黄铜唱臂
        let pivot = CGPoint(
            x: metrics.center.x + metrics.platterRadius * 0.78,
            y: max(24.0, metrics.center.y - metrics.platterRadius * 1.24)
        )
        let stylusHead = CGPoint(
            x: metrics.center.x + CGFloat(cos(needleAngle)) * (metrics.outerRadius + 8) + kickOffset,
            y: metrics.center.y + CGFloat(sin(needleAngle)) * (metrics.outerRadius + 8)
        )
        var arm = Path()
        arm.move(to: pivot)
        arm.addLine(to: stylusHead)
        ctx.stroke(
            arm,
            with: .color(Color(hex: 0x8B6118).opacity(0.55)),
            style: StrokeStyle(lineWidth: 5.2, lineCap: .round)
        )
        ctx.stroke(
            arm,
            with: .color(palette.nightLampGold.opacity(0.98)),
            style: StrokeStyle(lineWidth: 2.3, lineCap: .round)
        )

        let pivotCap = CGRect(x: pivot.x - 6.0, y: pivot.y - 6.0, width: 12, height: 12)
        ctx.fill(Path(ellipseIn: pivotCap), with: .color(palette.nightLampGold.opacity(0.95)))
        ctx.stroke(Path(ellipseIn: pivotCap), with: .color(.white.opacity(0.65)), lineWidth: 1.0)

        let headDot = CGRect(x: stylusHead.x - 4.8, y: stylusHead.y - 4.8, width: 9.6, height: 9.6)
        ctx.fill(Path(ellipseIn: headDot), with: .color(palette.nightLampGold))
        ctx.stroke(Path(ellipseIn: headDot), with: .color(.white.opacity(0.85)), lineWidth: 1.0)
    }

    // MARK: - 2B. Flowing Mountain-River Canvas Rendering

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

            let grad = Gradient(colors: [
                palette.homeAnchor.opacity(palette.isNight ? 0.24 : 0.18),
                palette.homeAnchor.opacity(0.02)
            ])
            ctx.fill(
                mountainFill,
                with: .linearGradient(grad, startPoint: CGPoint(x: 0, y: lay.padV), endPoint: CGPoint(x: 0, y: size.height))
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

            // 湖面倒影轮廓（让《天鹅》等抒情曲线呈现在静水湖面之上）
            let horizonY = size.height - lay.padV * 0.8
            var mirrorCurve = Path()
            mirrorCurve.move(to: CGPoint(x: pts[0].pt.x, y: horizonY + (horizonY - pts[0].pt.y) * 0.18))
            for i in 1..<pts.count {
                let p0 = pts[i - 1].pt
                let p1 = pts[i].pt
                let m0y = horizonY + (horizonY - p0.y) * 0.18
                let m1y = horizonY + (horizonY - p1.y) * 0.18
                let midX = (p0.x + p1.x) * 0.5
                mirrorCurve.addCurve(to: CGPoint(x: p1.x, y: m1y), control1: CGPoint(x: midX, y: m0y), control2: CGPoint(x: midX, y: m1y))
            }
            ctx.stroke(mirrorCurve, with: .color(palette.homeAnchor.opacity(0.14)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
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
            let isSelected = vm.selectedBeadID == item.bead.id
            let isFollowCur = vm.followGlowActive && vm.followGlowIndex == item.idx
            let isSingingNow: Bool = {
                guard let ct = currentTime else { return false }
                return ct >= onset - 0.04 && ct <= onset + max(0.18, dur * 0.9)
            }()

            if isSelected && !vm.isPlaying && !vm.followGlowActive {
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
            let tailStart = CGPoint(x: item.pt.x, y: tailCenterY)
            let tailEnd = CGPoint(x: item.pt.x + tailW, y: tailCenterY)
            if isSingingNow {
                let glowRect = CGRect(x: item.pt.x, y: tailCenterY - 5.5, width: tailW, height: 11.0)
                ctx.fill(
                    Path(roundedRect: glowRect, cornerRadius: 5.5),
                    with: .linearGradient(
                        Gradient(colors: [col.opacity(0.34), .clear]),
                        startPoint: tailStart,
                        endPoint: tailEnd
                    )
                )
            }
            let tailH: CGFloat = isSingingNow ? 6.8 : 5.4
            let tailRect = CGRect(x: item.pt.x, y: tailCenterY - tailH * 0.5, width: tailW, height: tailH)
            ctx.fill(
                Path(roundedRect: tailRect, cornerRadius: tailH * 0.5),
                with: .linearGradient(
                    Gradient(colors: [col.opacity(isSingingNow ? 0.88 : 0.62), col.opacity(0.08)]),
                    startPoint: tailStart,
                    endPoint: tailEnd
                )
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
            ctx.stroke(Path(ellipseIn: orbRect), with: .color(.white.opacity(0.6)), lineWidth: 1.0)

            let gs = orbR * 1.15
            let gRect = CGRect(x: item.pt.x - gs * 0.5, y: item.pt.y - gs * 0.5, width: gs, height: gs)
            ctx.fill(PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: gRect), with: .color(.white.opacity(0.96)), style: FillStyle(eoFill: true))
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
                    color: Color(hex: 0x7EC8E3),
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
        beam.move(to: CGPoint(x: lay.anchorX, y: 12))
        beam.addLine(to: CGPoint(x: lay.anchorX, y: size.height - 12))
        let beamHaloAlpha = (vm.isPlaying ? 0.24 : 0.12) + acoustic.shimmerEnergy * 0.26
        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(beamHaloAlpha)), lineWidth: 9.0 + CGFloat(acoustic.shimmerEnergy) * 6.0)
        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(vm.isPlaying ? 0.94 : 0.52)), lineWidth: 2.6)

        for ev in vm.rippleBus.activeEvents(at: mediaNow) {
            let age = mediaNow - ev.birthMediaTime
            let prog = max(0, min(1, age / 0.85))
            let y = lay.padV + (CGFloat(7 - ev.laneIndex) + 0.5) * lay.rowH + (ev.isShadow ? 10.0 : 0.0)
            let x = vm.isPlaying ? lay.anchorX : FlowingRiverGeometry.screenX(onset: ev.onset, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let col = Color(hex: ev.colorHex)
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
        let nebulaGrad = Gradient(colors: [
            activeChordColor.opacity((palette.isNight ? 0.24 : 0.14) + acoustic.rmsEnergy * 0.14),
            activeChordColor.opacity(0.03),
            Color.clear
        ])
        let auraExpandR = nm.ringRadius * (1.38 + CGFloat(acoustic.warmthEnergy) * 0.16)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: nm.center.x - auraExpandR,
                y: nm.center.y - auraExpandR,
                width: auraExpandR * 2,
                height: auraExpandR * 2
            )),
            with: .radialGradient(nebulaGrad, center: nm.center, startRadius: 6, endRadius: auraExpandR)
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
        let hubBg = Gradient(colors: palette.isNight
            ? [Color(hex: 0xFFB84D).opacity(0.24), Color(hex: 0x1D2754)]
            : [Color(hex: 0xFFE6AC).opacity(0.60), Color(hex: 0xF7ECDA)]
        )
        ctx.fill(
            Path(ellipseIn: hubRect),
            with: .radialGradient(hubBg, center: nm.center, startRadius: 4, endRadius: nm.hubRadius)
        )
        ctx.stroke(Path(ellipseIn: hubRect), with: .color(palette.nightLampGold.opacity(0.50)), lineWidth: 1.5)
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
                    with: .color(Color(hex: 0x7EC8E3).opacity(fade * 0.85)),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                )
                drawCrescentMoonOrb(
                    ctx: &ctx,
                    center: shadowPt,
                    radius: 10.5,
                    color: Color(hex: 0x7EC8E3),
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
            let col = Color(hex: ev.colorHex)
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
            ctx.fill(
                PitchGlyphShape.glyph(forLaneIndex: laneIdx).path(in: gRect),
                with: .color(.white.opacity(isMuted ? 0.45 : 0.96)),
                style: FillStyle(eoFill: true)
            )
            let digitTxt = Text(lane.digitLabel)
                .font(.system(size: starR > 19 ? 11 : 9.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(isMuted ? 0.5 : 0.98))
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

            // 1) 命中已有音珠？
            if !vm.followGlowActive {
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

            // 逆时针拨动唱盘 = 把后面的音符拉向 12 点钟唱针（时间向前推进）
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
            if let curIdx = vm.document.notes.firstIndex(where: { $0.id == beadID }) {
                vm.playContextEcho(upToIndex: curIdx)
            }

        case .scrub:
            if moveDist <= 8 {
                if vm.followGlowActive, let targetLane = targetFollowLaneIndex {
                    vm.strikeXylophoneLane(XylophoneLane.lane(at: targetLane))
                } else {
                    let dist = hypot(val.location.x - m.center.x, val.location.y - m.center.y)
                    if dist >= m.innerRadius * 0.80 && dist <= m.platterRadius * 0.95 {
                        let laneIdx = OrbitalGeometry.laneIndex(forRadius: dist, innerRadius: m.innerRadius, outerRadius: m.outerRadius, pentatonicSafe: vm.pentatonicSafe)
                        let lane = XylophoneLane.lane(at: laneIdx)
                        let onset = OrbitalGeometry.onset(forScreenPoint: val.location, center: m.center, discRotation: discRot, totalDuration: total)
                        vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: onset)
                    } else {
                        vm.selectedBeadID = nil
                    }
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

    /// 真实黑胶手推惯性滑行（松手后按指数阻尼滑行约 0.35 秒，滑过音珠自然响起）。
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

            if !vm.followGlowActive {
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
            if let idx = vm.document.notes.firstIndex(where: { $0.id == beadID }) {
                vm.playContextEcho(upToIndex: idx)
            }

        case .scrub:
            if moveDist <= 8 {
                if vm.followGlowActive, let targetLane = targetFollowLaneIndex {
                    vm.strikeXylophoneLane(XylophoneLane.lane(at: targetLane))
                } else {
                    let rowFromTop = max(0, min(7, Int(floor((val.location.y - lay.padV) / max(1, lay.rowH)))))
                    let snapped = XylophoneLane.nearestAllowedIndex(7 - rowFromTop, pentatonicSafe: vm.pentatonicSafe)
                    let lane = XylophoneLane.lane(at: snapped)
                    let targetOnset = FlowingRiverGeometry.onset(fromScreenX: val.location.x, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
                    vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: targetOnset)
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
                if vm.document.notes.isEmpty && !vm.followGlowActive {
                    let lane = XylophoneLane.lane(at: laneIdx)
                    vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: 0.16)
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

    // MARK: - 3. Compact Zero-Overflow Visual Selection Dock

    private var compactSelectionPill: some View {
        let idx = selectedBeatIndex ?? 0
        let total = vm.document.notes.count
        let selectedBead = vm.document.notes.indices.contains(idx) ? vm.document.notes[idx] : nil
        let selectedLane = selectedBead.map { XylophoneLane.lane(at: XylophoneLane.laneIndex(degree: $0.degree, octaveOffset: $0.octaveOffset)) }

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                if let lane = selectedLane {
                    HStack(spacing: 4) {
                        PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                            .frame(width: 10, height: 10)
                        Text(lane.digitLabel)
                            .font(.caption2.weight(.heavy).monospacedDigit())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(lane.barColor(isNight: palette.isNight)))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                    if let bead = selectedBead {
                        let durFrac = max(0.18, min(1.0, NightLampPhraseHelper.normalizedDurationRatio(for: bead.rawDuration)))
                        let laneCol = lane.barColor(isNight: palette.isNight)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(palette.shelfSurface)
                                .frame(width: 28, height: 5)
                            Capsule()
                                .fill(laneCol.opacity(0.88))
                                .frame(width: 28 * CGFloat(durFrac), height: 5)
                        }
                        .accessibilityHidden(true)
                    }
                }

                Button {
                    vm.stepSelectedBeat(delta: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 26)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(idx > 0 ? palette.primaryInk : palette.secondaryInk.opacity(0.35))
                }
                .disabled(idx <= 0)
                .buttonStyle(.plain)
                .accessibilityLabel("上一拍")

                Text("\(idx + 1)/\(total)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.primaryInk)
                    .frame(minWidth: 32)

                Button {
                    vm.stepSelectedBeat(delta: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 26)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(idx + 1 < total ? palette.homeAnchor : palette.secondaryInk.opacity(0.35))
                }
                .disabled(idx + 1 >= total)
                .buttonStyle(.plain)
                .accessibilityLabel("下一拍")

                Spacer(minLength: 4)

                Button {
                    vm.toggleSmartPitchHints()
                } label: {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 26)
                        .background(Capsule().fill(vm.smartHintActive ? palette.nightLampGold : palette.nightLampGold.opacity(0.18)))
                        .foregroundStyle(vm.smartHintActive ? Color(hex: 0x1B2245) : palette.nightLampGold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("推荐音高")

                Button {
                    vm.selectedBeadID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(palette.shelfSurface))
                        .foregroundStyle(palette.secondaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消选中当前音符")
            }

            HStack(spacing: 6) {
                Button {
                    vm.adjustSelectedBeadDuration(delta: -0.18)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("缩短音符")

                Button {
                    vm.adjustSelectedBeadDuration(delta: 0.22)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("延长音符")

                Button {
                    vm.nudgeSelectedBeadTiming(delta: -0.10)
                } label: {
                    Image(systemName: "arrow.left.to.line")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("提前一格")

                Button {
                    vm.nudgeSelectedBeadTiming(delta: 0.10)
                } label: {
                    Image(systemName: "arrow.right.to.line")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("延后一格")

                Button {
                    vm.insertBeatAfterSelected()
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(palette.bassRibbon.opacity(0.18)))
                        .foregroundStyle(palette.bassRibbon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("插入一拍")

                Button {
                    vm.deleteSelectedBead()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Capsule().fill(palette.melodyTerracotta.opacity(0.15)))
                        .foregroundStyle(palette.melodyTerracotta)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除当前音符")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.20 : 0.06), radius: 8, y: 2)
        )
    }

    // MARK: - 4. Tactile 8-Key Montessori Rainbow Ribbon (Glissando + Colorblind Glyphs)

    private var rainbowKeyRibbon: some View {
        let hints = smartHintByLane
        let chordDegrees = vm.activeChordToneDegrees

        return GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(XylophoneLane.allLanes) { lane in
                    let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
                    let isFollowTarget = targetFollowLaneIndex == lane.index
                    let hint = hints[lane.index]
                    let isChordResonant = !isMuted && !isFollowTarget && hint == nil && chordDegrees.contains(lane.degree)
                    let isPlayingThis = vm.activeLaneIndices.contains(lane.index) || struckRibbonLane == lane.index
                    let isSympathetic = !isMuted && !isPlayingThis && vm.sympatheticLaneIndices.contains(lane.index)
                    let barH = CGFloat(58 - lane.index * 2) // 左侧低音更高厚，右侧高音渐趋精巧
                    let col = lane.barColor(isNight: palette.isNight)

                    VStack(spacing: 3) {
                        PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white.opacity(0.95))

                        Text(lane.digitLabel)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isMuted ? barH - 6 : barH)
                    .background(
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [col.opacity(0.95), col],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            // 顶部窑陶釉面高光条
                            Capsule()
                                .fill(Color.white.opacity(palette.isNight ? 0.16 : 0.28))
                                .frame(height: 3.5)
                                .padding(.horizontal, 6)
                                .padding(.top, 3)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                (isFollowTarget || hint != nil)
                                    ? palette.nightLampGold
                                    : (isSympathetic
                                        ? Color.white.opacity(palette.isNight ? 0.45 : 0.70)
                                        : Color.white.opacity(palette.isNight ? 0.16 : 0.36)),
                                lineWidth: (isFollowTarget || hint != nil) ? 2.5 : (isSympathetic ? 1.5 : 0.9)
                            )
                    )
                    .overlay(alignment: .top) {
                        if isFollowTarget || hint != nil {
                            Circle()
                                .fill(palette.nightLampGold)
                                .frame(width: 5.5, height: 5.5)
                                .shadow(color: palette.nightLampGold.opacity(0.85), radius: 3)
                                .offset(y: -3.5)
                        } else if isSympathetic {
                            Circle()
                                .fill(Color.white.opacity(0.75))
                                .frame(width: 4, height: 4)
                                .shadow(color: .white.opacity(0.7), radius: 3)
                                .offset(y: -2.5)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        ZStack(alignment: .bottom) {
                            if struckRibbonLane == lane.index && ribbonMercuryLevel > 0.05 {
                                Capsule()
                                    .fill(Color.white.opacity(0.62))
                                    .frame(width: 5, height: max(8, barH * CGFloat(ribbonMercuryLevel) * 0.72))
                                    .padding(.bottom, 5)
                            }
                            if isChordResonant {
                                Capsule()
                                    .fill(Color.white.opacity(palette.isNight ? 0.55 : 0.72))
                                    .frame(width: 14, height: 3)
                                    .padding(.bottom, 4)
                            }
                        }
                    }
                    .shadow(
                        color: (isFollowTarget || hint != nil)
                            ? palette.nightLampGold.opacity(0.70)
                            : col.opacity(isPlayingThis ? 0.55 : 0.14),
                        radius: (isFollowTarget || hint != nil || isPlayingThis) ? 8 : 2,
                        y: isPlayingThis ? 0.5 : 2.5
                    )
                    .offset(y: isPlayingThis ? 2.5 : (isFollowTarget ? -5.0 : (hint != nil ? -2.5 : 0)))
                    .scaleEffect(isPlayingThis ? 0.94 : (isFollowTarget ? 1.06 : 1.0))
                    .opacity(isMuted ? 0.24 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.65), value: isPlayingThis)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isFollowTarget)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: isSympathetic)
                    .accessibilityElement()
                    .accessibilityLabel("\(lane.member.voiceOverSummary)")
                    .accessibilityValue(isFollowTarget ? "当前亮灯" : (isChordResonant ? "和谐音" : ""))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        vm.strikeXylophoneLane(lane)
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
                            wakeRippleTimeline()
                            vm.strikeXylophoneLane(lane, touchIntensity: dyn.velocity, touchBrightness: dyn.brightness)
                        } else if !vm.followGlowActive && vm.selectedBeadID == nil,
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
                                wakeRippleTimeline()
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
        .frame(height: 62)
    }

    // MARK: - 5. Minimal 3-Action Liquid Glass Bottom Dock

    private var bottomGlassDock: some View {
        HStack(spacing: 12) {
            // 1. 旋转播放 / 暂停开关
            Button {
                vm.togglePlayback()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.bold))
                    .frame(width: 50, height: 50)
                    .background(
                        Circle().fill(vm.isPlaying ? palette.homeAnchor : palette.cardSurface)
                    )
                    .foregroundStyle(
                        vm.isPlaying
                            ? (palette.isNight ? Color(hex: 0x1B2245) : .white)
                            : palette.homeAnchor
                    )
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.06), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vm.isPlaying ? "暂停旋转播放" : "开始旋转播放")

            // 2. 中央主键：纯粹雕塑感图标（录音时显示声波停止，跟灯时显示紧凑进度，常态纯粹创作图标）
            Button {
                if vm.capturePipeline.isRecording {
                    vm.finishRelativeContourHum()
                } else if vm.followGlowActive {
                    vm.toggleFollowGlow()
                } else {
                    showDreamSheet = true
                }
            } label: {
                Group {
                    if vm.capturePipeline.isRecording {
                        HStack(spacing: 8) {
                            ChimmoCraftMark(.humWave, color: .white)
                                .frame(width: 18, height: 18)
                            Image(systemName: "stop.fill")
                                .font(.subheadline.weight(.bold))
                        }
                    } else if vm.followGlowActive {
                        let cur = min(vm.followGlowIndex + 1, max(1, vm.document.notes.count))
                        let total = max(1, vm.document.notes.count)
                        HStack(spacing: 7) {
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.bold))
                            Text("\(cur)/\(total)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                        }
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.title3.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule().fill(
                        vm.capturePipeline.isRecording
                            ? palette.melodyTerracotta
                            : (vm.followGlowActive ? palette.nightLampGold : palette.homeAnchor)
                    )
                )
                .foregroundStyle(
                    vm.capturePipeline.isRecording
                        ? .white
                        : ((vm.followGlowActive || palette.isNight) ? Color(hex: 0x1B2245) : .white)
                )
                .shadow(color: palette.homeAnchor.opacity(0.28), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                vm.capturePipeline.isRecording
                    ? "停止哼唱"
                    : (vm.followGlowActive ? "退出跟灯弹" : "创作旋律")
            )

            // 3. 情绪天空与乐器音色开关
            Button {
                showMoodSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: vm.document.scaleMode.iconName)
                        .font(.title3.weight(.bold))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(palette.cardSurface))
                        .foregroundStyle(vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight))
                        .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.06), radius: 8, y: 2)

                    if vm.pentatonicSafe {
                        Circle()
                            .fill(Color(hex: 0x2F9E44))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(palette.cardSurface, lineWidth: 1.5))
                            .offset(x: -3, y: 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("五音模式与声音设置")
        }
    }
}

/// 「咩 × 哞」声学调色台（少字可视化控制台：雕塑开关垫 + 均分五色极光带 + 音色物理包络波形 + 伴奏点阵图谱）
private struct MoodAndSoundSheet: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var auditionVoice: MelodyVoice? = nil
    @State private var auditionTexture: AccompanimentTexture? = nil
    @State private var auditionStartTime: Double = 0
    @State private var auditionResetTask: Task<Void, Never>? = nil

    private func triggerAudition(voice: MelodyVoice? = nil, texture: AccompanimentTexture? = nil) {
        auditionStartTime = CACurrentMediaTime()
        if let voice {
            auditionVoice = voice
            auditionTexture = nil
        } else if let texture {
            auditionTexture = texture
            auditionVoice = nil
        }
        auditionResetTask?.cancel()
        auditionResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            if !Task.isCancelled {
                auditionVoice = nil
                auditionTexture = nil
            }
        }
    }

    private func appearanceIcon(for pref: AppearancePreference) -> String {
        switch pref {
        case .auto: return "circle.lefthalf.filled"
        case .daylight: return "sun.max.fill"
        case .nightLamp: return "moon.stars.fill"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    appearanceStrip
                    ceramicToggleConsole
                    auroraScaleModeStrip
                    tempoGroovePitchConsole
                    mieVoiceEnvelopeSection
                    mouAccompanimentSection
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // 0. 昼夜外观（纯图标三态）
    private var appearanceStrip: some View {
        HStack(spacing: 8) {
            ForEach(AppearancePreference.allCases) { pref in
                let active = vm.appearance == pref
                Button {
                    vm.appearance = pref
                    AcousticHapticsEngine.shared.playScrubTick()
                } label: {
                    Image(systemName: appearanceIcon(for: pref))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pref.label)
            }
        }
        .padding(5)
        .background(Capsule().fill(palette.shelfSurface.opacity(0.70)))
    }

    // 1. 三枚雕塑陶瓷开关垫（取代系统 Toggle 长行列表）
    private var ceramicToggleConsole: some View {
        HStack(spacing: 8) {
            ceramicPad(
                symbol: .pentatonicArc,
                shortLabel: "五音",
                accessibilityTitle: "五音模式",
                isOn: vm.pentatonicSafe,
                activeColor: Color(hex: 0x2F9E44)
            ) {
                vm.togglePentatonicSafe()
            }

            ceramicPad(
                symbol: .counterpointMoons,
                shortLabel: "伴唱",
                accessibilityTitle: "自动伴唱",
                isOn: vm.shadowCounterpointEnabled,
                activeColor: Color(hex: 0x4EA8DE)
            ) {
                vm.toggleShadowCounterpoint()
            }

            ceramicPad(
                symbol: .hapticPulse,
                shortLabel: "震动",
                accessibilityTitle: "节拍震动",
                isOn: vm.musicHapticsEnabled,
                activeColor: palette.nightLampGold
            ) {
                vm.toggleMusicHaptics()
            }
        }
    }

    private func ceramicPad(
        symbol: ChimmoCraftSymbol,
        shortLabel: String,
        accessibilityTitle: String,
        isOn: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    Circle()
                        .fill(isOn ? activeColor : palette.secondaryInk.opacity(0.24))
                        .frame(width: 6, height: 6)
                }

                ChimmoCraftMark(
                    symbol,
                    color: isOn ? activeColor : palette.secondaryInk
                )
                .frame(width: 22, height: 22)

                Text(shortLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isOn ? palette.primaryInk : palette.secondaryInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOn ? activeColor.opacity(palette.isNight ? 0.18 : 0.10) : palette.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isOn ? activeColor.opacity(0.65) : Color.clear, lineWidth: 1.4)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }

    // 2. 五色极光调式共鸣带（单行均分 5 列，消除 3+2 孤儿分裂）
    private var auroraScaleModeStrip: some View {
        HStack(spacing: 6) {
            ForEach(ScaleMode.allCases) { mode in
                let selected = vm.document.scaleMode == mode
                let skyCol = mode.skyAuroraColor(isNight: palette.isNight)
                Button {
                    vm.setScaleMode(mode)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: mode.iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(skyCol)

                        Capsule()
                            .fill(skyCol.opacity(selected ? 0.96 : 0.42))
                            .frame(height: 3.5)
                            .padding(.horizontal, 6)

                        Text(mode.shortSkyLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? skyCol.opacity(palette.isNight ? 0.16 : 0.10) : palette.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(selected ? skyCol : Color.clear, lineWidth: 1.6)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.label)风格")
                .accessibilityValue(selected ? "已选中" : "")
            }
        }
    }

    // 3. 倍速 × 节拍疏密点阵 × 音区高度标尺
    private var tempoGroovePitchConsole: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ChimmoCraftMark(.tempoDial, color: palette.secondaryInk)
                    .frame(width: 15, height: 15)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                ForEach([0.65, 0.85, 1.0, 1.25], id: \.self) { rate in
                    let active = abs(vm.playbackRate - rate) < 0.04
                    let label = rate == 1.0 ? "1×" : String(format: "%.2g×", rate)
                    Button {
                        vm.setPlaybackRate(rate)
                    } label: {
                        Text(label)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
                            .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("播放速度 \(label)")
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "metronome")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                ForEach([(0.0, "自由", 0), (0.5, "微稳", 1), (1.0, "整齐", 2)], id: \.0) { val, label, tier in
                    let active = abs(vm.document.grooveStrength - val) < 0.25
                    Button {
                        vm.setGrooveStrength(val)
                    } label: {
                        GrooveDotPatternView(
                            tier: tier,
                            color: active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk
                        )
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("节奏\(label)")
                    .accessibilityValue(active ? "已选中" : "")
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "tuningfork")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                ForEach(Array(RootTranspositionHelper.presetOffsets.enumerated()), id: \.element) { idx, offset in
                    let targetMIDI = 60 + offset
                    let active = vm.document.rootMIDI == targetMIDI
                    let barWidth = CGFloat(10 + idx * 3)
                    Button {
                        vm.setRootMIDI(targetMIDI)
                    } label: {
                        VStack(spacing: 3) {
                            Text(RootTranspositionHelper.compactLabel(forRootMIDI: targetMIDI))
                                .font(.caption2.weight(.bold).monospacedDigit())
                            Capsule()
                                .fill(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white).opacity(0.85) : palette.homeAnchor.opacity(0.45))
                                .frame(width: barWidth, height: 2.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("音区\(RootTranspositionHelper.accessibilityLabel(forRootMIDI: targetMIDI))")
                    .accessibilityValue(active ? "已选中" : "")
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface.opacity(0.60)))
    }

    // 4. 「咩 · 音色」声学物理包络曲线区
    private var mieVoiceEnvelopeSection: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        return TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
            let now = CACurrentMediaTime()
            let phaseTime = reduceMotion ? 0.0 : now
            let isMieActive = (auditionVoice != nil) || vm.isPlaying
            let sweep: Double? = (auditionVoice != nil && !reduceMotion)
                ? AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: now - auditionStartTime)
                : nil

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        vm.auditionDuoCharacter(.mie)
                        triggerAudition(voice: vm.melodyVoice)
                    } label: {
                        ChimmoSheepView(
                            isNight: palette.isNight,
                            accentColor: skyColor,
                            isSinging: isMieActive,
                            phaseTime: phaseTime,
                            gazeBias: auditionVoice != nil ? 0.45 : 0.0
                        )
                        .frame(width: 34, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("小羊咩，试听主旋律")

                    Text("咩 · 音色")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(MelodyVoice.allCases) { v in
                        let active = vm.melodyVoice == v
                        let fgColor = active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk
                        let waveColor = active ? fgColor : palette.homeAnchor
                        Button {
                            vm.setMelodyVoice(v)
                            triggerAudition(voice: v)
                        } label: {
                            HStack(spacing: 8) {
                                VoiceEnvelopeSparkView(
                                    points: AcousticSignatureGeometry.voiceEnvelopePoints(for: v),
                                    color: waveColor,
                                    filled: active,
                                    sweepProgress: auditionVoice == v ? sweep : nil
                                )
                                .frame(width: 44, height: 20)

                                Text(v.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(fgColor)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(active ? palette.homeAnchor : palette.cardSurface)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(v.label)音色")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }
            }
        }
    }

    // 5. 「哞 · 伴奏」和弦进行的声学条码与伴奏织体点阵区（消灭全站最后一枚原生 Toggle）
    private var mouAccompanimentSection: some View {
        let skyColor = vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
        return TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { _ in
            let now = CACurrentMediaTime()
            let phaseTime = reduceMotion ? 0.0 : now
            let isMouPulsing = (auditionTexture != nil) || vm.isPlaying
            let sweep: Double? = (auditionTexture != nil && !reduceMotion)
                ? AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: now - auditionStartTime)
                : nil

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Button {
                        if !vm.cradleEnabled {
                            vm.setChordPreset(.autoMatch)
                        }
                        vm.auditionDuoCharacter(.mou)
                        triggerAudition(texture: vm.accompanimentTexture)
                    } label: {
                        ChimmoCowView(
                            isNight: palette.isNight,
                            accentColor: skyColor,
                            isAwake: vm.cradleEnabled,
                            isPlaying: isMouPulsing,
                            phaseTime: phaseTime,
                            gazeBias: auditionTexture != nil ? -0.35 : 0.0
                        )
                        .frame(width: 34, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("小牛哞，试听低音伴奏")

                    Text("哞 · 伴奏")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)

                    Spacer()
                }

                ChordPresetBarcodeStrip(vm: vm, palette: palette)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(AccompanimentTexture.allCases) { tex in
                        let active = vm.cradleEnabled && vm.accompanimentTexture == tex
                        let fgColor = active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk
                        let dotColor = active ? fgColor : palette.bassRibbon
                        let dots = AcousticSignatureGeometry.accompanimentPatternDots(for: tex)
                        let activeDot = (auditionTexture == tex && sweep != nil)
                            ? AcousticSignatureAnimationHelper.activeIndex(progress: sweep!, itemCount: dots.count)
                            : nil
                        Button {
                            vm.setAccompanimentTexture(tex)
                            triggerAudition(texture: tex)
                        } label: {
                            HStack(spacing: 8) {
                                AccompanimentDotPatternView(
                                    dots: dots,
                                    color: dotColor,
                                    activeDotIndex: activeDot
                                )
                                .frame(width: 44, height: 20)

                                Text(tex.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(fgColor)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(active ? palette.bassRibbon : palette.cardSurface)
                            )
                            .opacity(vm.cradleEnabled ? 1.0 : 0.56)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tex.label)伴奏")
                        .accessibilityValue(active ? "已选中" : "")
                    }
                }
            }
        }
    }
}

private struct GrooveDotPatternView: View {
    let tier: Int
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let cy = size.height * 0.5
            if tier >= 2 {
                for frac in [0.16, 0.39, 0.61, 0.84] {
                    let x = size.width * CGFloat(frac)
                    var bar = Path()
                    bar.move(to: CGPoint(x: x, y: 2))
                    bar.addLine(to: CGPoint(x: x, y: size.height - 2))
                    ctx.stroke(bar, with: .color(color.opacity(0.32)), lineWidth: 1.0)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2.3, y: cy - 2.3, width: 4.6, height: 4.6)), with: .color(color))
                }
            } else if tier == 1 {
                let pts: [(Double, Double)] = [(0.16, 0.42), (0.39, 0.58), (0.61, 0.44), (0.84, 0.56)]
                for p in pts {
                    let pt = CGPoint(x: size.width * CGFloat(p.0), y: size.height * CGFloat(p.1))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.2, y: pt.y - 2.2, width: 4.4, height: 4.4)), with: .color(color))
                }
            } else {
                let pts: [(Double, Double)] = [(0.14, 0.72), (0.36, 0.28), (0.65, 0.75), (0.86, 0.34)]
                for p in pts {
                    let pt = CGPoint(x: size.width * CGFloat(p.0), y: size.height * CGFloat(p.1))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.2, y: pt.y - 2.2, width: 4.4, height: 4.4)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct VoiceEnvelopeSparkView: View {
    let points: [Double]
    let color: Color
    let filled: Bool
    var sweepProgress: Double? = nil

    var body: some View {
        Canvas { ctx, size in
            guard points.count > 1 else { return }
            let padX: CGFloat = 2
            let padY: CGFloat = 2
            let w = max(1, size.width - padX * 2)
            let h = max(1, size.height - padY * 2)

            var line = Path()
            var area = Path()
            for (idx, v) in points.enumerated() {
                let x = padX + (CGFloat(idx) / CGFloat(points.count - 1)) * w
                let y = padY + (1.0 - CGFloat(max(0.0, min(1.0, v)))) * h
                if idx == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                    area.move(to: CGPoint(x: x, y: size.height - padY))
                    area.addLine(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                    area.addLine(to: CGPoint(x: x, y: y))
                }
            }
            area.addLine(to: CGPoint(x: size.width - padX, y: size.height - padY))
            area.closeSubpath()

            ctx.fill(area, with: .color(color.opacity(filled ? 0.24 : 0.14)))
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

            if let sweep = sweepProgress,
               let idx = AcousticSignatureAnimationHelper.activeIndex(progress: sweep, itemCount: points.count) {
                let x = padX + (CGFloat(idx) / CGFloat(points.count - 1)) * w
                let y = padY + (1.0 - CGFloat(max(0.0, min(1.0, points[idx])))) * h
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 3.6, y: y - 3.6, width: 7.2, height: 7.2)),
                    with: .color(color.opacity(0.32))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AccompanimentDotPatternView: View {
    let dots: [AcousticSignatureGeometry.PatternDot]
    let color: Color
    var activeDotIndex: Int? = nil

    var body: some View {
        Canvas { ctx, size in
            let padX: CGFloat = 4
            let padY: CGFloat = 3
            let w = max(1, size.width - padX * 2)
            let h = max(1, size.height - padY * 2)
            for (idx, dot) in dots.enumerated() {
                let px = padX + CGFloat(dot.x) * w
                let py = padY + (1.0 - CGFloat(dot.y)) * h
                let isActive = activeDotIndex == idx
                let r = CGFloat(2.0 * dot.radiusScale * (isActive ? 1.55 : 1.0))
                if isActive {
                    let haloR = r + 2.2
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - haloR, y: py - haloR, width: haloR * 2, height: haloR * 2)),
                        with: .color(color.opacity(0.30))
                    )
                }
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                    with: .color(color.opacity(isActive ? 1.0 : 0.85))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

/// 主舞台「哞 · 四幕彩色和声触控轨」：跨星盘/山河/星云三态一致的四幕和弦切分交互带。
private struct StageHarmonyRibbonView: View {
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
                    Capsule()
                        .fill(vm.cradleEnabled ? palette.bassRibbon.opacity(palette.isNight ? 0.22 : 0.14) : palette.cardSurface)
                        .overlay(
                            Capsule().strokeBorder(
                                vm.cradleEnabled ? palette.bassRibbon.opacity(0.45) : palette.divider,
                                lineWidth: 1.0
                            )
                        )
                    ChimmoCowView(
                        isNight: palette.isNight,
                        accentColor: skyCol,
                        isAwake: vm.cradleEnabled,
                        isPlaying: vm.isPlaying
                    )
                    .frame(width: 24, height: 18)
                }
                .frame(width: 36, height: 24)
            }
            .buttonStyle(.plain)
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
                                Text(seg.romanLabel)
                                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(isActive ? .white : segCol)
                                    .frame(width: segW, height: 24)
                                    .background(
                                        Capsule()
                                            .fill(isActive ? segCol : segCol.opacity(palette.isNight ? 0.20 : 0.12))
                                            .overlay(
                                                Capsule().strokeBorder(
                                                    segCol.opacity(isActive ? 0.95 : 0.36),
                                                    lineWidth: isActive ? 1.4 : 0.9
                                                )
                                            )
                                    )
                                    .shadow(color: isActive ? segCol.opacity(0.32) : .clear, radius: 4, y: 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("第 \(seg.spanID + 1) 幕和弦 \(seg.romanLabel) \(seg.chord.moodTitle)")
                            .accessibilityHint("轻点切换和弦进行")
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: vm.activeChordSpanID)
                }
                .frame(height: 24)
            } else {
                Button {
                    vm.setChordPreset(.autoMatch)
                } label: {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(palette.secondaryInk.opacity(0.20))
                                .frame(maxWidth: .infinity)
                                .frame(height: 3.5)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background(Capsule().fill(palette.cardSurface.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开启智能和弦伴奏")
            }
        }
    }
}

/// 声音面板 5 档可视化和弦进行彩色条码卡（4 色小音块直观区分经典和弦走向）。
private struct ChordPresetBarcodeStrip: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette

    private let orderedPresets: [ChordProgressionPreset] = [
        .off, .autoMatch, .classicPop, .summerFloat, .warmStory
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedPresets) { preset in
                let selected = vm.chordPreset == preset
                let tag = HarmonyCurtainStripMapper.shortPresetTag(for: preset)
                let colors: [Color] = preset.sequence.map { $0.color(isNight: palette.isNight) }

                Button {
                    vm.setChordPreset(preset)
                } label: {
                    VStack(spacing: 4) {
                        if colors.isEmpty {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk.opacity(0.65))
                                .frame(height: 8)
                        } else {
                            HStack(spacing: 2) {
                                ForEach(Array(colors.enumerated()), id: \.offset) { _, col in
                                    Capsule()
                                        .fill(col.opacity(selected ? 0.96 : 0.62))
                                        .frame(height: 4.5)
                                }
                            }
                            .padding(.horizontal, 5)
                            .frame(height: 8)
                        }

                        Text(tag)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(selected ? palette.primaryInk : palette.secondaryInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? palette.bassRibbon.opacity(palette.isNight ? 0.22 : 0.13) : palette.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? palette.bassRibbon : Color.clear, lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.label)
                .accessibilityValue(selected ? "已选中" : "")
            }
        }
    }
}

private struct StagePlaybackNavigationActions: ViewModifier {
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
            .accessibilityAction(named: "升高一音") {
                vm.shiftSelectedBeadPitch(delta: 1)
            }
            .accessibilityAction(named: "降低一音") {
                vm.shiftSelectedBeadPitch(delta: -1)
            }
    }
}

private struct StageBeatEditActions: ViewModifier {
    @ObservedObject var vm: StudioViewModel

    private func ensureSelectedBeat() {
        if vm.selectedBeadID == nil {
            vm.selectedBeadID = vm.document.notes.first?.id
        }
    }

    func body(content: Content) -> some View {
        content
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
    }
}
