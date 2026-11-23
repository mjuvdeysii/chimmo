import QuartzCore
import SwiftUI

/// 咩哞 v0.7 旗舰双态声画主舞台：
/// - 模式 A「◎ 星轨星盘」：音乐盒式旋转同心声盘，盘面随旋律顺滑旋转，每个发声的音符转到 12 点钟黄铜唱针下方绽放涟漪，支持单指手摇搓盘、拖珠改音、外环换和声；
/// - 模式 B「〰 流动山河」：28% 处固定金光束，整片旋律山河平滑向左流淌，永远停留在视线中心；
/// - 零乐理三重无障碍编码：颜色 + 轨道高低 + 8 种几何图腾（● ■ ▲ ◆ ★ 💧 ✦ ◎），辅以 CoreHaptics 音高触觉与 VoiceOver 语义读音。
public struct OrbitalStageView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenAbout: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showDreamSheet: Bool = false
    @State private var showMoodSheet: Bool = false
    @State private var rippleWakeActive: Bool = false
    @State private var rippleWakeTask: Task<Void, Never>? = nil

    // 手势交互态（仅局部瞬态，绝不触发重排版死循环）
    @State private var discInteractionMode: DiscDragMode = .none
    @State private var draggingBeadID: UUID? = nil
    @State private var dragStartPoint: CGPoint = .zero
    @State private var dragStartOnset: Double = 0
    @State private var dragDidPushUndo: Bool = false
    @State private var scrubAnchorAngle: Double = 0
    @State private var scrubAnchorTime: Double = 0
    @State private var lastDragAngle: Double = 0

    @State private var manualRiverScrollX: CGFloat = 0
    @State private var riverStartScrollX: CGFloat = 0
    @State private var struckRibbonLane: Int? = nil
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
        onOpenAbout: @escaping () -> Void
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenAbout = onOpenAbout
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
        !reduceMotion && (vm.isPlaying || rippleWakeActive || isActivelyDraggingStage || !vm.activeLaneIndices.isEmpty)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight)
                )

                VStack(spacing: 10) {
                    topStageHeader
                        .padding(.horizontal, 14)

                    heroStageContainer
                        .padding(.horizontal, 14)

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
                .padding(.top, 4)
            }
            .navigationTitle("咩哞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    }
                    .accessibilityLabel("保存到我的唱片馆")

                    Button {
                        vm.appearance = palette.isNight ? .daylight : .nightLamp
                    } label: {
                        Image(systemName: palette.isNight ? "sun.max" : "lamp.desk")
                    }
                    .accessibilityLabel(palette.isNight ? "切换日光纸面" : "切换深夜台灯")

                    Button {
                        onOpenAbout()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("关于与导出 MIDI")
                }
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
                wakeRippleTimeline()
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

    // MARK: - 1. Compact Header + Mode Switcher

    private var topStageHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vm.document.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)

                    Text(vm.document.scaleMode.shortSkyLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight).opacity(0.18)))
                        .foregroundStyle(vm.document.scaleMode.skyAuroraColor(isNight: palette.isNight))
                }

                Text(headerSubtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(vm.followGlowActive ? palette.nightLampGold : palette.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // 星盘 ⇄ 山河 双态切换胶囊
            HStack(spacing: 2) {
                ForEach(StageVisualMode.allCases) { mode in
                    let active = vm.visualMode == mode
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                            vm.visualMode = mode
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 10.5, weight: .bold))
                            Text(mode.rawValue)
                                .font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(active ? palette.homeAnchor : Color.clear)
                        )
                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.secondaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换到\(mode.rawValue)视图")
                }
            }
            .padding(3)
            .background(Capsule().fill(palette.shelfSurface))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.22 : 0.05), radius: 10, y: 3)
        )
    }

    private var headerSubtitle: String {
        if let toast = vm.statusToast { return toast }
        if vm.followGlowActive {
            let cur = min(vm.followGlowIndex + 1, max(1, vm.document.notes.count))
            return "跟着亮金光琴条敲 · 第 \(cur)/\(max(1, vm.document.notes.count)) 拍"
        }
        if vm.isPlaying, let m = vm.activeGuidedMoment {
            return "【\(m.badge)】\(m.caption)"
        }
        if let idx = selectedBeatIndex {
            return "选中第 \(idx + 1) 拍 · 拖珠或点下方彩虹条微调"
        }
        if vm.document.notes.isEmpty {
            return "点圆盘种音珠，或点下方「捕梦创作」敲一段节奏"
        }
        return vm.visualMode == .orbitalDisc
            ? "点▶转动听曲，或用手指拨转声盘"
            : "点▶山河随声流动，或左右滑动"
    }

    // MARK: - 2. Hero Stage Container (Orbital Disc OR Flowing Mountain River)

    private var heroStageContainer: some View {
        let boardBg = palette.isNight ? Color(hex: 0x121936) : Color(hex: 0xFAF6EE)
        let borderCol = palette.isNight ? palette.nightLampGold.opacity(0.20) : Color(hex: 0xCBB18D).opacity(0.32)

        return GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldRunCanvasTimeline)) { _ in
                    let mediaNow = CACurrentMediaTime()
                    let _ = scrubTick
                    Canvas { ctx, size in
                        if vm.visualMode == .orbitalDisc {
                            drawOrbitalDiscCanvas(ctx: &ctx, size: size, mediaNow: mediaNow)
                        } else {
                            drawFlowingRiverCanvas(ctx: &ctx, size: size, mediaNow: mediaNow)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            if !isActivelyDraggingStage {
                                isActivelyDraggingStage = true
                            }
                            if vm.visualMode == .orbitalDisc {
                                handleOrbitalDragChanged(val, in: geo.size)
                            } else {
                                handleRiverDragChanged(val, in: geo.size)
                            }
                        }
                        .onEnded { val in
                            isActivelyDraggingStage = false
                            if vm.visualMode == .orbitalDisc {
                                handleOrbitalDragEnded(val, in: geo.size)
                            } else {
                                handleRiverDragEnded(val, in: geo.size)
                            }
                        }
                )

                // 右上角轻巧声学谐振微标（实时显示当前音程美学，零术语墙）
                harmonyBadgeOverlay
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(boardBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(borderCol, lineWidth: 1.2)
            )
            .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.28 : 0.07), radius: 14, y: 5)
        }
        .frame(minHeight: 255, maxHeight: .infinity)
    }

    private var harmonyBadgeOverlay: some View {
        let phys = vm.activeHarmonyPhysics
        let accent = phys.isTense ? palette.tensionFilament : palette.homeAnchor
        return HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: 6.5, height: 6.5)
            Text(phys.intervalName)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryInk)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(palette.cardSurface.opacity(palette.isNight ? 0.85 : 0.92))
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前音程：\(phys.intervalName)，\(phys.poeticEssence)")
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
        let maxR = min(size.width, size.height) * 0.455
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
        let total = max(0.5, vm.document.totalDuration)
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let rotTurns = vm.clock.continuousRotationTurns(at: mediaNow)
        let discRot: Double = reduceMotion ? 0.0 : (currentTime != nil ? -(rotTurns * 2.0 * Double.pi) : 0.0)
        let needleAngle: Double = (reduceMotion && currentTime != nil)
            ? (-Double.pi / 2.0 + ((currentTime! / total) * 2.0 * Double.pi))
            : (-Double.pi / 2.0)

        // 1. 外环 4 幕和声极光弧（点按外环即可切换每一幕的情绪底色）
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
                ctx.stroke(
                    arc,
                    with: .color(col.opacity(isCurrentSpan ? 0.90 : 0.34)),
                    style: StrokeStyle(lineWidth: isCurrentSpan ? 6.5 : 3.5, lineCap: .round)
                )
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

        // 12 枚随盘面同转的极简节拍刻度（让任何缓慢旋律的旋转都肉眼一目了然）
        for tick in 0..<12 {
            let ta = -Double.pi / 2.0 + Double(tick) * (Double.pi / 6.0) + discRot
            let r0 = m.platterRadius * (tick % 3 == 0 ? 0.932 : 0.950)
            let r1 = m.platterRadius * 0.980
            var tp = Path()
            tp.move(to: CGPoint(x: m.center.x + CGFloat(cos(ta)) * r0, y: m.center.y + CGFloat(sin(ta)) * r0))
            tp.addLine(to: CGPoint(x: m.center.x + CGFloat(cos(ta)) * r1, y: m.center.y + CGFloat(sin(ta)) * r1))
            ctx.stroke(
                tp,
                with: .color((tick % 3 == 0 ? palette.nightLampGold : palette.secondaryInk).opacity(tick % 3 == 0 ? 0.72 : 0.35)),
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

        // 3. 8 条同心彩虹音高轨道
        for laneIdx in 0..<8 {
            let lane = XylophoneLane.lane(at: laneIdx)
            let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
            let ringRect = CGRect(x: m.center.x - r, y: m.center.y - r, width: r * 2, height: r * 2)
            let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
            let isActiveLane = vm.activeLaneIndices.contains(laneIdx)
            let isFollowTarget = targetFollowLaneIndex == laneIdx
            let col = lane.barColor(isNight: palette.isNight)

            let lineW: CGFloat = (isActiveLane || isFollowTarget) ? 2.4 : (laneIdx == 0 ? 1.4 : 0.9)
            let alpha: Double = isMuted ? 0.14 : ((isActiveLane || isFollowTarget) ? 0.85 : (palette.isNight ? 0.24 : 0.28))

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

        // 5. 音符星座连线 + 音珠时长尾弧 + 三重无障碍音珠本体
        let notes = vm.document.notes.sorted {
            $0.displayOnset(grooveStrength: vm.document.grooveStrength) < $1.displayOnset(grooveStrength: vm.document.grooveStrength)
        }
        var jewelPoints: [CGPoint] = []
        var jewelData: [(idx: Int, bead: NoteBead, pt: CGPoint, laneIdx: Int, angle: Double, r: CGFloat)] = []

        for (idx, bead) in notes.enumerated() {
            let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let ang = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: onset, totalDuration: total) + discRot
            let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: m.innerRadius, outerRadius: m.outerRadius)
            let pt = CGPoint(x: m.center.x + CGFloat(cos(ang)) * r, y: m.center.y + CGFloat(sin(ang)) * r)
            jewelPoints.append(pt)
            jewelData.append((idx, bead, pt, laneIdx, ang, r))
        }

        if jewelPoints.count > 1 {
            var line = Path()
            line.move(to: jewelPoints[0])
            for i in 1..<jewelPoints.count {
                let p0 = jewelPoints[i - 1]
                let p1 = jewelPoints[i]
                let mid = CGPoint(
                    x: (p0.x + p1.x) * 0.5 + (m.center.x - (p0.x + p1.x) * 0.5) * 0.14,
                    y: (p0.y + p1.y) * 0.5 + (m.center.y - (p0.y + p1.y) * 0.5) * 0.14
                )
                line.addQuadCurve(to: p1, control: mid)
            }
            ctx.stroke(
                line,
                with: .color(palette.homeAnchor.opacity(palette.isNight ? 0.38 : 0.34)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
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

        for item in jewelData {
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

            // 色盲友好几何图腾（● ■ ▲ ◆ ★ 💧 ✦ ◎）
            let glyphSize = orbR * 1.15
            let glyphRect = CGRect(x: item.pt.x - glyphSize * 0.5, y: item.pt.y - glyphSize * 0.5, width: glyphSize, height: glyphSize)
            let glyphPath = PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: glyphRect)
            ctx.fill(glyphPath, with: .color(.white.opacity(0.96)), style: FillStyle(eoFill: true))
        }

        // 6. 中央利萨如谐振花纹玻璃圆心（实时映照当前声学和谐比例）
        drawCenterMandalaHub(ctx: &ctx, center: m.center, hubRadius: m.innerRadius * 0.76, mediaNow: mediaNow)

        // 7. 12 点钟黄铜唱针与声波涟漪绽放
        drawRipplesOnDisc(ctx: &ctx, metrics: m, discRot: discRot, needleAngle: needleAngle, mediaNow: mediaNow)
        drawTonearmNeedle(ctx: &ctx, metrics: m, needleAngle: needleAngle, isPlaying: vm.isPlaying, mediaNow: mediaNow)
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

    private func drawCenterMandalaHub(ctx: inout GraphicsContext, center: CGPoint, hubRadius: CGFloat, mediaNow: Double) {
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

        // 利萨如实时波纹花（双层柔光 + 清晰主丝线）
        let phys = vm.activeHarmonyPhysics
        let amp = hubRadius * 0.56
        let tension = 1.0 - phys.consonance
        let phase = reduceMotion ? 0.45 : mediaNow * (0.45 + tension * 2.0)
        var wave = Path()
        let steps = 110
        for i in 0...steps {
            let u = (Double(i) / Double(steps)) * Double.pi * 2.0
            let x = center.x + CGFloat(sin(Double(phys.ratioA) * u + phase)) * amp
            let y = center.y + CGFloat(sin(Double(phys.ratioB) * u)) * amp
            if i == 0 { wave.move(to: CGPoint(x: x, y: y)) } else { wave.addLine(to: CGPoint(x: x, y: y)) }
        }
        let lineCol = phys.isTense ? palette.tensionFilament : palette.homeAnchor
        ctx.stroke(wave, with: .color(lineCol.opacity(0.28)), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))
        ctx.stroke(wave, with: .color(lineCol.opacity(0.90)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

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

            for ring in 0..<2 {
                let ringR = 8.0 + CGFloat(prog) * (36.0 + CGFloat(ring) * 14.0)
                let rect = CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2)
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(col.opacity((1.0 - prog) * (ring == 0 ? 0.72 : 0.36))),
                    lineWidth: 2.0
                )
            }

            // 零堆分配星尘迸溅微粒（纯三角函数确定性计算 8 颗向外飘散微粒）
            if !reduceMotion {
                let baseSeed = ev.birthMediaTime * 13.7 + Double(ev.laneIndex) * 2.3
                for pIdx in 0..<8 {
                    let pAng = baseSeed + Double(pIdx) * (Double.pi * 2.0 / 8.0)
                    let pDist = 10.0 + prog * (28.0 + Double(pIdx % 3) * 9.0)
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
        // 物理弹簧微颤：刚触及唱针 0.18 秒内的轻微阻尼微震
        var kickOffset: CGFloat = 0
        if !reduceMotion, let newest = vm.rippleBus.events.last {
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
        let currentTime = vm.clock.currentTime(at: mediaNow)
        let scrollX = FlowingRiverGeometry.worldScrollX(
            playheadTime: currentTime,
            manualScrollX: manualRiverScrollX,
            pxPerSecond: lay.pxPerSec
        )

        // 1. 4 幕和声天光色带背景
        for span in vm.chordSpans {
            let x0 = FlowingRiverGeometry.screenX(onset: span.startTime, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let x1 = FlowingRiverGeometry.screenX(onset: span.endTime, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let rect = CGRect(x: x0, y: 0, width: max(0, x1 - x0), height: size.height)
            let isCurrent = span.id == vm.activeChordSpanID && currentTime != nil
            ctx.fill(Path(rect), with: .color(span.chord.color(isNight: palette.isNight).opacity(isCurrent ? 0.12 : 0.045)))
        }

        // 2. 8 条彩色地平线阶梯轨
        for rowFromTop in 0..<8 {
            let laneIdx = 7 - rowFromTop
            let lane = XylophoneLane.lane(at: laneIdx)
            let y = lay.padV + (CGFloat(rowFromTop) + 0.5) * lay.rowH
            let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
            let col = lane.barColor(isNight: palette.isNight)
            var track = Path()
            track.move(to: CGPoint(x: 0, y: y))
            track.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(
                track,
                with: .color(col.opacity(isMuted ? 0.10 : 0.26)),
                style: StrokeStyle(lineWidth: isMuted ? 0.7 : 1.1, dash: isMuted ? [3, 4] : [])
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
            ctx.stroke(curve, with: .color(palette.homeAnchor.opacity(0.75)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

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

        for item in pts {
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

            let tailW = max(14.0, CGFloat(dur) * lay.pxPerSec * 0.85)
            let tailRect = CGRect(x: item.pt.x, y: item.pt.y - 3.2, width: tailW, height: 6.4)
            ctx.fill(Path(roundedRect: tailRect, cornerRadius: 3.2), with: .color(col.opacity(0.46)))

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

        // 4. 28% 处固定金光游标与声波涟漪 + 零堆分配星尘迸溅微粒
        var beam = Path()
        beam.move(to: CGPoint(x: lay.anchorX, y: 12))
        beam.addLine(to: CGPoint(x: lay.anchorX, y: size.height - 12))
        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(vm.isPlaying ? 0.24 : 0.12)), lineWidth: 9.0)
        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(vm.isPlaying ? 0.94 : 0.52)), lineWidth: 2.6)

        for ev in vm.rippleBus.activeEvents(at: mediaNow) {
            let age = mediaNow - ev.birthMediaTime
            let prog = max(0, min(1, age / 0.85))
            let y = lay.padV + (CGFloat(7 - ev.laneIndex) + 0.5) * lay.rowH
            let x = vm.isPlaying ? lay.anchorX : FlowingRiverGeometry.screenX(onset: ev.onset, scrollX: scrollX, anchorX: lay.anchorX, pxPerSecond: lay.pxPerSec)
            let col = Color(hex: ev.colorHex)
            let r = 8.0 + CGFloat(prog) * 34.0
            ctx.stroke(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(col.opacity((1.0 - prog) * 0.72)),
                lineWidth: 2.0
            )
            if !reduceMotion {
                let baseSeed = ev.birthMediaTime * 11.3 + Double(ev.laneIndex) * 1.9
                for pIdx in 0..<8 {
                    let pAng = baseSeed + Double(pIdx) * (Double.pi * 2.0 / 8.0)
                    let pDist = 9.0 + prog * (24.0 + Double(pIdx % 3) * 8.0)
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
                vm.updateBeatTiming(beadID: beadID, newOnset: max(0.08, dragStartOnset + dt))
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
                vm.updateBeatTiming(beadID: beadID, newOnset: max(0.08, dragStartOnset + Double(dx / lay.pxPerSec)))
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

    // MARK: - 3. Compact Floating Selection Pill

    private var compactSelectionPill: some View {
        let idx = selectedBeatIndex ?? 0
        let total = vm.document.notes.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    vm.stepSelectedBeat(delta: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(idx > 0 ? palette.primaryInk : palette.secondaryInk.opacity(0.35))
                }
                .disabled(idx <= 0)
                .buttonStyle(.plain)

                Text("\(idx + 1)/\(total)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.primaryInk)

                Button {
                    vm.stepSelectedBeat(delta: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(idx + 1 < total ? palette.homeAnchor : palette.secondaryInk.opacity(0.35))
                }
                .disabled(idx + 1 >= total)
                .buttonStyle(.plain)

                Button {
                    vm.toggleSmartPitchHints()
                } label: {
                    Label(vm.smartHintActive ? "3灯开" : "亮3灯", systemImage: "lightbulb.fill")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(vm.smartHintActive ? palette.nightLampGold : palette.nightLampGold.opacity(0.18)))
                        .foregroundStyle(vm.smartHintActive ? Color(hex: 0x1B2245) : palette.nightLampGold)
                }
                .buttonStyle(.plain)

                Button("-短") { vm.adjustSelectedBeadDuration(delta: -0.18) }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(palette.shelfSurface))
                    .foregroundStyle(palette.primaryInk)
                    .buttonStyle(.plain)

                Button("+长") { vm.adjustSelectedBeadDuration(delta: 0.22) }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(palette.shelfSurface))
                    .foregroundStyle(palette.primaryInk)
                    .buttonStyle(.plain)

                Button("+拍") { vm.insertBeatAfterSelected() }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(palette.bassRibbon.opacity(0.18)))
                    .foregroundStyle(palette.bassRibbon)
                    .buttonStyle(.plain)

                Button {
                    vm.deleteSelectedBead()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(palette.melodyTerracotta.opacity(0.15)))
                        .foregroundStyle(palette.melodyTerracotta)
                }
                .buttonStyle(.plain)

                Button {
                    vm.selectedBeadID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .padding(6)
                        .foregroundStyle(palette.secondaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消选中当前音珠")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.20 : 0.06), radius: 8, y: 2)
            )
        }
    }

    // MARK: - 4. Tactile 8-Key Montessori Rainbow Ribbon (Glissando + Colorblind Glyphs)

    private var rainbowKeyRibbon: some View {
        let hints = smartHintByLane

        return GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(XylophoneLane.allLanes) { lane in
                    let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
                    let isFollowTarget = targetFollowLaneIndex == lane.index
                    let hint = hints[lane.index]
                    let isPlayingThis = vm.activeLaneIndices.contains(lane.index) || struckRibbonLane == lane.index
                    let barH = CGFloat(58 - lane.index * 2) // 左侧低音更高厚，右侧高音渐趋精巧
                    let col = lane.barColor(isNight: palette.isNight)

                    VStack(spacing: 3) {
                        PitchGlyphVectorView(glyph: PitchGlyphShape.glyph(forLaneIndex: lane.index))
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white.opacity(0.95))

                        Text(hint != nil ? String(hint!.badge.prefix(2)) : lane.digitLabel)
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
                                    : Color.white.opacity(palette.isNight ? 0.16 : 0.36),
                                lineWidth: (isFollowTarget || hint != nil) ? 2.5 : 0.9
                            )
                    )
                    .shadow(
                        color: (isFollowTarget || hint != nil)
                            ? palette.nightLampGold.opacity(0.70)
                            : col.opacity(isPlayingThis ? 0.55 : 0.14),
                        radius: (isFollowTarget || hint != nil || isPlayingThis) ? 8 : 2,
                        y: isPlayingThis ? 0.5 : 2.5
                    )
                    .offset(y: isPlayingThis ? 2.5 : 0)
                    .scaleEffect(isPlayingThis ? 0.94 : (isFollowTarget ? 1.06 : 1.0))
                    .opacity(isMuted ? 0.24 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.65), value: isPlayingThis)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isFollowTarget)
                    .accessibilityElement()
                    .accessibilityLabel("\(lane.member.voiceOverSummary)")
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
                        let idx = max(0, min(7, Int(floor((val.location.x / w) * 8.0))))
                        if struckRibbonLane != idx {
                            struckRibbonLane = idx
                            let lane = XylophoneLane.lane(at: idx)
                            if vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive {
                                return
                            }
                            wakeRippleTimeline()
                            vm.strikeXylophoneLane(lane)
                        }
                    }
                    .onEnded { _ in
                        struckRibbonLane = nil
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

            // 2. 中央主键：捕梦创作 / 跟弹进度 / 哼唱完成
            Button {
                if vm.capturePipeline.isRecording {
                    vm.finishRelativeContourHum()
                } else if vm.followGlowActive {
                    vm.toggleFollowGlow()
                } else {
                    showDreamSheet = true
                }
            } label: {
                HStack(spacing: 7) {
                    Image(
                        systemName: vm.capturePipeline.isRecording
                            ? "stop.fill"
                            : (vm.followGlowActive ? "sparkles" : "wand.and.stars")
                    )
                    .font(.subheadline.weight(.bold))

                    Text(primaryDockLabel)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
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
            .accessibilityLabel("情绪天光、安心五音与乐器音色")
        }
    }

    private var primaryDockLabel: String {
        if vm.capturePipeline.isRecording {
            return "哼好了 · 贴到声盘"
        }
        if vm.followGlowActive {
            let cur = min(vm.followGlowIndex + 1, max(1, vm.document.notes.count))
            return "跟弹 \(cur)/\(max(1, vm.document.notes.count)) · 退出"
        }
        return "捕梦创作"
    }
}

private struct PitchGlyphVectorView: View {
    let glyph: PitchGlyphShape

    var body: some View {
        GeometryReader { geo in
            glyph.path(in: CGRect(origin: .zero, size: geo.size))
                .fill(style: FillStyle(eoFill: true))
        }
    }
}

/// 精简柔和的情绪天光与乐器配置面板（把所有复杂旋钮收敛到按需抽屉，保持主舞台 100% 呼吸感）
private struct MoodAndSoundSheet: View {
    @ObservedObject var vm: StudioViewModel
    let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 安心 5 音护网开关
                    Button {
                        vm.togglePentatonicSafe()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: vm.pentatonicSafe ? "checkmark.shield.fill" : "shield")
                                .font(.title2)
                                .foregroundStyle(vm.pentatonicSafe ? Color(hex: 0x2F9E44) : palette.secondaryInk)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("🎋 安心 5 音护网")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Text(vm.pentatonicSafe ? "已收起 4 和 7，闭眼乱点也自然好听" : "已解锁全部 8 个彩虹音阶，含 4 与 7 的情感张力")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            Spacer()
                            Text(vm.pentatonicSafe ? "已开启" : "已关闭")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(vm.pentatonicSafe ? Color(hex: 0x2F9E44).opacity(0.18) : palette.shelfSurface))
                                .foregroundStyle(vm.pentatonicSafe ? Color(hex: 0x2F9E44) : palette.secondaryInk)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
                    }
                    .buttonStyle(.plain)

                    // 2. 五色天光情绪光谱
                    VStack(alignment: .leading, spacing: 10) {
                        Text("五色天光情绪")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)

                        ForEach(ScaleMode.allCases) { mode in
                            let selected = vm.document.scaleMode == mode
                            let skyCol = mode.skyAuroraColor(isNight: palette.isNight)
                            Button {
                                vm.setScaleMode(mode)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: mode.iconName)
                                        .font(.title3)
                                        .foregroundStyle(skyCol)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.label)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(palette.primaryInk)
                                        Text(mode.skyPhilosophy)
                                            .font(.caption2)
                                            .foregroundStyle(palette.secondaryInk)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(skyCol)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(palette.cardSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(selected ? skyCol : Color.clear, lineWidth: 1.6)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 3. 主奏乐器 & 伴奏水波
                    VStack(alignment: .leading, spacing: 10) {
                        Text("主奏乐器")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(MelodyVoice.allCases) { v in
                                let active = vm.melodyVoice == v
                                Button {
                                    vm.setMelodyVoice(v)
                                } label: {
                                    Label(v.label, systemImage: v.iconName)
                                        .font(.caption.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(active ? palette.homeAnchor : palette.cardSurface))
                                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("水波和声伴奏")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Spacer()
                            Button(vm.cradleEnabled ? "切为纯清唱" : "开启温暖伴奏") {
                                vm.setChordPreset(vm.cradleEnabled ? .off : .autoMatch)
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.homeAnchor)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(AccompanimentTexture.allCases) { tex in
                                let active = vm.cradleEnabled && vm.accompanimentTexture == tex
                                Button {
                                    vm.setAccompanimentTexture(tex)
                                } label: {
                                    Label(tex.label, systemImage: tex.iconName)
                                        .font(.caption.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(active ? palette.bassRibbon : palette.cardSurface))
                                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("情绪与声色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
