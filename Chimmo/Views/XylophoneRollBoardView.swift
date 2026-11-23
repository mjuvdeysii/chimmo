import SwiftUI

/// 咩哞 v0.6 核心实体玩具：「彩虹木琴 × 音乐盒打孔敲画板」
/// 吸取《摸索台灯》蒙氏木琴玩具的直觉实体感，将「敲下脑海节奏」「选山坡/哼走势/亮灯3选1找音」「前后连听调音」「名曲亮灯跟弹」全部合一到同一块彩虹木琴画板上。
public struct XylophoneRollBoardView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenAbout: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var struckLane: Int? = nil
    @State private var fxRings: [XyloWaveRing] = []
    @State private var draggingBeadID: UUID? = nil
    @State private var dragStartOnset: Double = 0
    @State private var dragStartPoint: CGPoint = .zero
    @State private var dragDidPushUndo: Bool = false
    @State private var drumPulse: CGFloat = 1.0

    private struct XyloWaveRing: Identifiable {
        let id = UUID()
        let birth: TimeInterval
        let laneIndex: Int
        let color: Color
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

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette)

                VStack(spacing: 10) {
                    // 1. 顶部极简曲目与状态栏（含一键「亮灯跟弹」）
                    topStatusStrip
                        .padding(.horizontal, 14)

                    // 2. 中央主角：实体彩虹木琴（左）× 同步音乐盒打孔纸带（右）
                    mainXylophoneAndRollCard
                        .padding(.horizontal, 14)

                    // 3. 灵动辅助条：敲拍态显示实时提示；调音态显示「选山坡 + 哼走势」&「逐拍微调/亮灯帮找」
                    if !vm.isTappingRhythm {
                        hillAndContourStrip
                            .padding(.horizontal, 14)

                        if selectedBeatIndex != nil && !vm.followGlowActive {
                            selectedBeatToolStrip
                                .padding(.horizontal, 14)
                        }
                    }

                    // 4. 底部实体玩具操作台（3 块心情积木 + 敲拍大木鼓 / 试听 / 小陶诺）
                    bottomToyDock
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
                .padding(.top, 6)
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
                    Menu {
                        Section("乐器音色") {
                            ForEach(MelodyVoice.allCases) { v in
                                Button {
                                    vm.setMelodyVoice(v)
                                } label: {
                                    if vm.melodyVoice == v { Label(v.label, systemImage: "checkmark") }
                                    else { Label(v.label, systemImage: v.iconName) }
                                }
                            }
                        }
                        Section("伴奏托底") {
                            Button {
                                vm.setChordPreset(vm.cradleEnabled ? .off : .autoMatch)
                            } label: {
                                Label(vm.cradleEnabled ? "关闭和声伴奏" : "开启温暖伴奏", systemImage: vm.cradleEnabled ? "speaker.slash" : "water.waves")
                            }
                            ForEach(AccompanimentTexture.allCases) { tex in
                                Button {
                                    vm.setAccompanimentTexture(tex)
                                } label: {
                                    if vm.accompanimentTexture == tex { Label(tex.label, systemImage: "checkmark") }
                                    else { Label(tex.label, systemImage: tex.iconName) }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: vm.melodyVoice.iconName)
                    }
                    .accessibilityLabel("切换乐器音色与伴奏")

                    Button {
                        vm.saveCurrentToNotebook()
                    } label: {
                        Image(systemName: vm.currentSavedEntryID != nil ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel("保存到我的音乐盒")

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
        }
    }

    // MARK: - 1. Top Strip

    private var topStatusStrip: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.document.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)

                Text(helperBannerText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(vm.followGlowActive ? palette.nightLampGold : palette.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if !vm.document.notes.isEmpty && !vm.isTappingRhythm {
                Button {
                    vm.toggleFollowGlow()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vm.followGlowActive ? "sparkles" : "lightbulb.fill")
                            .font(.caption2.weight(.bold))
                        Text(vm.followGlowActive ? "退出跟弹" : "亮灯跟弹")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            vm.followGlowActive ? palette.nightLampGold : palette.homeAnchor.opacity(palette.isNight ? 0.25 : 0.14)
                        )
                    )
                    .foregroundStyle(vm.followGlowActive ? Color(hex: 0x1B2245) : palette.homeAnchor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.18 : 0.04), radius: 8, y: 2)
        )
    }

    private var helperBannerText: String {
        if let toast = vm.statusToast { return toast }
        if vm.isTappingRhythm {
            return vm.liveTapTimestamps.isEmpty
                ? "在下方木鼓上随手敲出脑海里的节奏拍子"
                : "已敲下 \(vm.liveTapTimestamps.count) 拍 · 敲完点「定型选山坡」"
        }
        if vm.followGlowActive {
            let cur = min(vm.followGlowIndex + 1, max(1, vm.document.notes.count))
            return "跟着左侧发光彩条敲 · 第 \(cur)/\(vm.document.notes.count) 拍"
        }
        if let idx = selectedBeatIndex {
            return "正在调第 \(idx + 1) 拍 · 点左侧木琴条或上下拖珠，会自动连着前面一起唱给你听"
        }
        return "点左侧彩条直接玩木琴，或点下方「敲节奏」把脑放落到纸带上"
    }

    // MARK: - 2. Split-Synced Wooden Xylophone (Left) + Music-Box Roll (Right)

    private var mainXylophoneAndRollCard: some View {
        let boardBg = palette.isNight ? Color(hex: 0x151D38) : Color(hex: 0xF6F0E4)
        let borderCol = palette.isNight ? palette.nightLampGold.opacity(0.22) : Color(hex: 0xC69A6B).opacity(0.32)

        return GeometryReader { geo in
            let xyloW: CGFloat = 98
            let padV: CGFloat = 10
            let usableH = max(160, geo.size.height - padV * 2)
            let rowH = usableH / 8.0

            HStack(spacing: 0) {
                // 左侧：实体蒙氏 8 根彩虹木琴条（下长上短、双铜钉、支持点按与上下滑奏！）
                woodenXylophoneColumn(width: xyloW, padV: padV, rowH: rowH, totalH: geo.size.height)

                Rectangle()
                    .fill(borderCol)
                    .frame(width: 1)

                // 右侧：1:1 严格对齐的音乐盒打孔纸带画板
                musicBoxRollArea(
                    viewportW: max(120, geo.size.width - xyloW - 1),
                    height: geo.size.height,
                    padV: padV,
                    rowH: rowH
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(boardBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(borderCol, lineWidth: 1.2)
            )
            .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.06), radius: 12, y: 4)
        }
        .frame(maxHeight: .infinity, minHeight: 245)
    }

    private func woodenXylophoneColumn(width: CGFloat, padV: CGFloat, rowH: CGFloat, totalH: CGFloat) -> some View {
        let lanes = XylophoneLane.topToBottom
        let hints = smartHintByLane
        let railColor = palette.isNight ? Color(hex: 0x2E3863) : Color(hex: 0xDEC29B)

        return ZStack {
            // 两条温润山毛榉木琴导轨（致敬《摸索台灯》蒙氏木琴）
            HStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 3).fill(railColor).frame(width: 7)
                RoundedRectangle(cornerRadius: 3).fill(railColor).frame(width: 7)
            }
            .padding(.vertical, padV + 4)

            // 8 根彩虹木琴条（顶行 1↑ 最短，底行 1 最长，向右对齐接入打孔纸带）
            VStack(spacing: 0) {
                ForEach(lanes) { lane in
                    let isMutedSafe = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
                    let isFollowTarget = targetFollowLaneIndex == lane.index
                    let hint = hints[lane.index]
                    let isDimmedByHint = vm.smartHintActive && hint == nil && !vm.followGlowActive
                    let isPlayingThis = vm.activeLaneIndices.contains(lane.index) || struckLane == lane.index

                    let baseBarW = max(50, (width - 10) * lane.barWidthRatio)
                    let barW = hint != nil ? max(baseBarW, width - 16) : baseBarW
                    let barCol = lane.barColor(isNight: palette.isNight)

                    HStack(spacing: 0) {
                        Spacer(minLength: 2)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [barCol.opacity(0.92), barCol],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            (isFollowTarget || hint != nil)
                                                ? palette.nightLampGold
                                                : Color.white.opacity(palette.isNight ? 0.16 : 0.35),
                                            lineWidth: (isFollowTarget || hint != nil) ? 2.6 : 0.9
                                        )
                                )
                                .shadow(
                                    color: (isFollowTarget || hint != nil)
                                        ? palette.nightLampGold.opacity(0.75)
                                        : barCol.opacity(isPlayingThis ? 0.55 : 0.18),
                                    radius: (isFollowTarget || hint != nil || isPlayingThis) ? 8 : 2,
                                    y: 1.5
                                )

                            // 智能亮灯推荐时显示清晰大字提示，常规态显示经典双黄铜钉 + 音级数字
                            if let h = hint {
                                Text(h.badge)
                                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .padding(.horizontal, 4)
                            } else {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(hex: 0xF7DF9C).opacity(0.85))
                                        .frame(width: 4.5, height: 4.5)
                                    Spacer(minLength: 1)
                                    Text(lane.digitLabel)
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer(minLength: 1)
                                    Circle()
                                        .fill(Color(hex: 0xF7DF9C).opacity(0.85))
                                        .frame(width: 4.5, height: 4.5)
                                }
                                .padding(.horizontal, 6)
                            }
                        }
                        .frame(width: barW, height: max(18, rowH - 5))
                        .scaleEffect(isPlayingThis ? 0.94 : (isFollowTarget ? 1.04 : 1.0))
                        .opacity(isMutedSafe ? 0.24 : (isDimmedByHint ? 0.34 : 1.0))
                        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPlayingThis)
                        .animation(.easeInOut(duration: 0.2), value: isFollowTarget)
                    }
                    .padding(.trailing, 5)
                    .frame(height: rowH)
                }
            }
            .padding(.vertical, padV)

            // 敲击涟漪环（仅在轻敲时绽放消散）
            if !reduceMotion && !fxRings.isEmpty {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let now = tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        for ring in fxRings {
                            let age = now - ring.birth
                            guard age >= 0 && age <= 0.55 else { continue }
                            let prog = age / 0.55
                            let rowFromTop = 7 - ring.laneIndex
                            let cy = padV + (CGFloat(rowFromTop) + 0.5) * rowH
                            let cx = size.width * 0.55
                            let r = 10.0 + CGFloat(prog) * 38.0
                            ctx.stroke(
                                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                                with: .color(ring.color.opacity((1.0 - prog) * 0.72)),
                                lineWidth: 2.2
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: totalH)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    let relY = val.location.y - padV
                    let rowFromTop = max(0, min(7, Int(floor(relY / max(1, rowH)))))
                    let laneIndex = 7 - rowFromTop
                    if struckLane != laneIndex {
                        struckLane = laneIndex
                        let lane = XylophoneLane.lane(at: laneIndex)
                        if vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive {
                            return
                        }
                        spawnXyloRing(lane: lane)
                        vm.strikeXylophoneLane(lane)
                    }
                }
                .onEnded { _ in
                    struckLane = nil
                }
        )
    }

    private func spawnXyloRing(lane: XylophoneLane) {
        let now = Date().timeIntervalSinceReferenceDate
        fxRings.removeAll { now - $0.birth > 0.6 }
        fxRings.append(XyloWaveRing(birth: now, laneIndex: lane.index, color: lane.barColor(isNight: palette.isNight)))
    }

    // MARK: - Right Side: Synced Music-Box Punch Roll

    private func musicBoxRollArea(viewportW: CGFloat, height: CGFloat, padV: CGFloat, rowH: CGFloat) -> some View {
        let totalDur = max(3.6, vm.document.totalDuration + 0.5)
        let pxPerSec: CGFloat = max(72.0, (viewportW - 36) / CGFloat(min(totalDur, 5.2)))
        let contentW = max(viewportW, CGFloat(totalDur) * pxPerSec + 44)
        let padX: CGFloat = 20

        return ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    // 1. 8 条与左侧彩虹木琴严丝合缝对齐的柔和色带跑道
                    for rowFromTop in 0..<8 {
                        let laneIdx = 7 - rowFromTop
                        let lane = XylophoneLane.lane(at: laneIdx)
                        let yTop = padV + CGFloat(rowFromTop) * rowH
                        let rect = CGRect(x: 0, y: yTop, width: size.width, height: rowH)
                        let isMuted = vm.pentatonicSafe && !lane.isPentatonicSafe && !vm.followGlowActive
                        let tintAlpha = isMuted ? 0.02 : (laneIdx == 0 ? 0.10 : (palette.isNight ? 0.075 : 0.065))
                        ctx.fill(Path(rect), with: .color(lane.barColor(isNight: palette.isNight).opacity(tintAlpha)))

                        var sep = Path()
                        sep.move(to: CGPoint(x: 0, y: yTop + rowH))
                        sep.addLine(to: CGPoint(x: size.width, y: yTop + rowH))
                        ctx.stroke(sep, with: .color(palette.divider.opacity(0.65)), lineWidth: 0.6)
                    }

                    // 2. 实时敲鼓态：跳动升起的拍子柱
                    if vm.isTappingRhythm {
                        drawLiveTapPillars(ctx: &ctx, size: size, padV: padV, padX: padX, usableH: rowH * 8)
                        return
                    }

                    let notes = vm.document.notes
                    guard !notes.isEmpty else { return }

                    // 3. 垂直拍柱 + 音珠连线 + 台阶数字标签（+2↗ / -1↘ / =）
                    var centers: [CGPoint] = []
                    for bead in notes {
                        let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
                        let x = padX + CGFloat(onset) * pxPerSec
                        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                        let y = padV + (CGFloat(7 - laneIdx) + 0.5) * rowH
                        centers.append(CGPoint(x: x, y: y))

                        var pillar = Path()
                        pillar.move(to: CGPoint(x: x, y: size.height - padV))
                        pillar.addLine(to: CGPoint(x: x, y: y))
                        ctx.stroke(pillar, with: .color(palette.primaryInk.opacity(0.11)), style: StrokeStyle(lineWidth: 1.1, dash: [3, 3]))
                    }

                    if centers.count > 1 {
                        var line = Path()
                        line.move(to: centers[0])
                        for i in 1..<centers.count {
                            let p0 = centers[i - 1]
                            let p1 = centers[i]
                            line.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) * 0.5, y: min(p0.y, p1.y) - 8))
                        }
                        ctx.stroke(line, with: .color(palette.homeAnchor.opacity(0.55)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                        for i in 1..<notes.count {
                            let p0 = centers[i - 1]
                            let p1 = centers[i]
                            if abs(p1.x - p0.x) >= 26 {
                                let label = XylophoneRollEngine.stepDeltaLabel(from: notes[i - 1], to: notes[i])
                                let mid = CGPoint(x: (p0.x + p1.x) * 0.5, y: (p0.y + p1.y) * 0.5 - 11)
                                let resolved = ctx.resolve(
                                    Text(label)
                                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(palette.secondaryInk.opacity(0.9))
                                )
                                ctx.draw(resolved, at: mid, anchor: .center)
                            }
                        }
                    }

                    // 4. 播放光束游标
                    if let t = vm.playheadTime {
                        let px = padX + CGFloat(t) * pxPerSec
                        var beam = Path()
                        beam.move(to: CGPoint(x: px, y: padV))
                        beam.addLine(to: CGPoint(x: px, y: size.height - padV))
                        ctx.stroke(beam, with: .color(palette.nightLampGold.opacity(0.85)), lineWidth: 2.2)
                    }
                }
                .frame(width: contentW, height: height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { val in
                            guard !vm.isTappingRhythm && !vm.followGlowActive else { return }
                            let loc = val.location
                            let rowFromTop = max(0, min(7, Int(floor((loc.y - padV) / max(1, rowH)))))
                            let rawLane = 7 - rowFromTop
                            let snappedLane = XylophoneLane.nearestAllowedIndex(rawLane, pentatonicSafe: vm.pentatonicSafe)
                            let lane = XylophoneLane.lane(at: snappedLane)
                            let targetTime = max(0.10, Double(loc.x - padX) / Double(pxPerSec))
                            vm.placeNoteOnCanvas(degree: lane.degree, octaveOffset: lane.octaveOffset, atTime: targetTime)
                        }
                )

                // 5. 独立可拖拽的音珠木块层（拖拽音珠不与横向滚动冲突，空白处仍可顺滑横滑浏览长名曲！）
                if !vm.isTappingRhythm {
                    ForEach(Array(vm.document.notes.enumerated()), id: \.element.id) { idx, bead in
                        let onset = bead.displayOnset(grooveStrength: vm.document.grooveStrength)
                        let x = padX + CGFloat(onset) * pxPerSec
                        let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                        let lane = XylophoneLane.lane(at: laneIdx)
                        let y = padV + (CGFloat(7 - laneIdx) + 0.5) * rowH
                        let col = lane.barColor(isNight: palette.isNight)
                        let dur = bead.displayDuration(grooveStrength: vm.document.grooveStrength)
                        let barW = max(28.0, min(140.0, CGFloat(dur) * pxPerSec * 0.86))
                        let barH = max(20.0, rowH - 6.0)

                        let isSelected = vm.selectedBeadID == bead.id
                        let isFollowCur = vm.followGlowActive && vm.followGlowIndex == idx
                        let isPlayNow: Bool = {
                            guard let pt = vm.playheadTime else { return false }
                            return pt >= onset && pt <= onset + max(0.18, dur)
                        }()

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(col.opacity((vm.followGlowActive && idx < vm.followGlowIndex) ? 0.42 : 0.96))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            (isFollowCur ? palette.nightLampGold : (isSelected || isPlayNow ? palette.primaryInk : Color.white.opacity(0.3))),
                                            lineWidth: (isFollowCur || isSelected || isPlayNow) ? 2.4 : 0.8
                                        )
                                )
                                .shadow(
                                    color: (isFollowCur ? palette.nightLampGold : col).opacity((isSelected || isFollowCur) ? 0.55 : 0.18),
                                    radius: (isSelected || isFollowCur) ? 6 : 2,
                                    y: 1
                                )

                            Text(bead.octaveOffset < 0 ? "\(lane.digitLabel)↓" : lane.digitLabel)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.leading, 8)
                        }
                        .frame(width: barW, height: barH)
                        .position(x: x - 11 + barW * 0.5, y: y)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("rollCanvas"))
                                .onChanged { val in
                                    guard !vm.followGlowActive else { return }
                                    if draggingBeadID != bead.id {
                                        draggingBeadID = bead.id
                                        dragStartOnset = bead.rawOnset
                                        dragStartPoint = val.location
                                        dragDidPushUndo = false
                                        vm.selectBead(bead.id, playContext: false)
                                    }
                                    let dy = val.location.y - dragStartPoint.y
                                    let dx = val.location.x - dragStartPoint.x
                                    if abs(dy) > 8 {
                                        let rowFromTop = max(0, min(7, Int(floor((val.location.y - padV) / max(1, rowH)))))
                                        let snappedLane = XylophoneLane.nearestAllowedIndex(7 - rowFromTop, pentatonicSafe: vm.pentatonicSafe)
                                        let lane = XylophoneLane.lane(at: snappedLane)
                                        if !dragDidPushUndo {
                                            dragDidPushUndo = true
                                            vm.beginBeadEdit()
                                        }
                                        vm.updateBeadToLane(beadID: bead.id, lane: lane, playSinglePreview: true)
                                    }
                                    if abs(dx) > 16 {
                                        if !dragDidPushUndo {
                                            dragDidPushUndo = true
                                            vm.beginBeadEdit()
                                        }
                                        let newOnset = max(0.08, dragStartOnset + Double(dx) / Double(pxPerSec))
                                        vm.updateBeatTiming(beadID: bead.id, newOnset: newOnset)
                                    }
                                }
                                .onEnded { _ in
                                    guard !vm.followGlowActive else { return }
                                    draggingBeadID = nil
                                    dragDidPushUndo = false
                                    if let curIdx = vm.document.notes.firstIndex(where: { $0.id == bead.id }) {
                                        vm.playContextEcho(upToIndex: curIdx)
                                    }
                                }
                        )
                    }
                }
            }
            .coordinateSpace(name: "rollCanvas")
        }
    }

    private func drawLiveTapPillars(ctx: inout GraphicsContext, size: CGSize, padV: CGFloat, padX: CGFloat, usableH: CGFloat) {
        let count = vm.liveTapTimestamps.count
        guard count > 0 else {
            let prompt = ctx.resolve(
                Text("敲下方木鼓，每一拍会像积木一样立在这里")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryInk)
            )
            ctx.draw(prompt, at: CGPoint(x: size.width * 0.5, y: size.height * 0.5), anchor: .center)
            return
        }

        let t0 = vm.liveTapTimestamps[0]
        let span = max(2.2, (vm.liveTapTimestamps.last ?? t0) - t0 + 0.6)
        let usableW = max(80, size.width - padX * 2)
        for (i, ts) in vm.liveTapTimestamps.enumerated() {
            let x = padX + CGFloat((ts - t0) / span) * usableW
            let barRect = CGRect(x: x - 9, y: padV + usableH * 0.28, width: 18, height: usableH * 0.58)
            ctx.fill(
                Path(roundedRect: barRect, cornerRadius: 9),
                with: .color(palette.homeAnchor.opacity(i == count - 1 ? 0.95 : 0.68))
            )
            let lbl = ctx.resolve(
                Text("\(i + 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            )
            ctx.draw(lbl, at: CGPoint(x: x, y: padV + usableH * 0.42), anchor: .center)
        }
    }

    // MARK: - 3. Instant Hill Templates + Relative Hum Strip & Selected Beat Controls

    private var hillAndContourStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                // 创意 G：「只听高低走势、不管跑调」的哼唱塑坡按钮
                Button {
                    if vm.capturePipeline.isRecording {
                        vm.finishRelativeContourHum()
                    } else {
                        vm.startHumCapture()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vm.capturePipeline.isRecording ? "stop.fill" : "waveform")
                            .font(.caption2.weight(.bold))
                        Text(vm.capturePipeline.isRecording ? "哼好了" : (vm.document.notes.isEmpty ? "轻哼捉珠" : "哼高低走势"))
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            vm.capturePipeline.isRecording ? palette.tensionFilament : palette.melodyTerracotta
                        )
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                if !vm.document.notes.isEmpty {
                    // 创意 D：4 张旋律山坡快选卡（选座山坡再微调！）
                    ForEach(MelodyHillTemplate.allCases) { hill in
                        Button {
                            vm.applyHillTemplate(hill)
                        } label: {
                            HStack(spacing: 5) {
                                MiniHillShape(profile: hill.previewProfile, color: palette.homeAnchor)
                                    .frame(width: 22, height: 12)
                                Text(hill.shortLabel)
                                    .font(.caption2.weight(.bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(palette.cardSurface)
                                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.16 : 0.04), radius: 4, y: 1)
                            )
                            .foregroundStyle(palette.primaryInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var selectedBeatToolStrip: some View {
        let idx = selectedBeatIndex ?? 0
        let total = vm.document.notes.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                // 上一拍 / 下一拍 步进
                Button {
                    vm.stepSelectedBeat(delta: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(palette.cardSurface))
                        .foregroundStyle(idx > 0 ? palette.primaryInk : palette.secondaryInk.opacity(0.4))
                }
                .disabled(idx <= 0)
                .buttonStyle(.plain)

                Text("第 \(idx + 1)/\(total) 拍")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.primaryInk)

                Button {
                    vm.stepSelectedBeat(delta: 1)
                } label: {
                    HStack(spacing: 2) {
                        Text("下拍")
                            .font(.caption2.weight(.bold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(palette.cardSurface))
                    .foregroundStyle(idx + 1 < total ? palette.homeAnchor : palette.secondaryInk.opacity(0.4))
                }
                .disabled(idx + 1 >= total)
                .buttonStyle(.plain)

                // 创意 H：「亮灯帮找」3 选 1 验光师模式
                Button {
                    vm.toggleSmartPitchHints()
                } label: {
                    Label(vm.smartHintActive ? "已亮3灯" : "亮灯帮找", systemImage: "lightbulb.max.fill")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                vm.smartHintActive ? palette.nightLampGold : palette.nightLampGold.opacity(0.18)
                            )
                        )
                        .foregroundStyle(vm.smartHintActive ? Color(hex: 0x1B2245) : palette.nightLampGold)
                }
                .buttonStyle(.plain)

                // 时长微调 + 灵活增删拍
                Button("- 短") { vm.adjustSelectedBeadDuration(delta: -0.18) }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(palette.cardSurface))
                    .foregroundStyle(palette.primaryInk)
                    .buttonStyle(.plain)

                Button("+ 长") { vm.adjustSelectedBeadDuration(delta: 0.22) }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(palette.cardSurface))
                    .foregroundStyle(palette.primaryInk)
                    .buttonStyle(.plain)

                Button("+ 插拍") { vm.insertBeatAfterSelected() }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(palette.bassRibbon.opacity(0.16)))
                    .foregroundStyle(palette.bassRibbon)
                    .buttonStyle(.plain)

                Button {
                    vm.deleteSelectedBead()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(palette.melodyTerracotta.opacity(0.14)))
                        .foregroundStyle(palette.melodyTerracotta)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 4. Bottom Physical Wooden Toy Dock

    private var bottomToyDock: some View {
        VStack(spacing: 10) {
            if vm.isTappingRhythm {
                inlineRhythmDrumPad
            } else {
                // 3 块心情积木 + 右下角静静陪你敲琴的小陶诺
                HStack(spacing: 7) {
                    moodBlockButton(
                        title: "☀️ 晴朗",
                        selected: !vm.document.scaleMode.isMinorFlavored,
                        tint: palette.homeAnchor
                    ) {
                        vm.setScaleMode(.brightMajor)
                    }

                    moodBlockButton(
                        title: "🌙 微酸",
                        selected: vm.document.scaleMode.isMinorFlavored,
                        tint: palette.harmonyWash
                    ) {
                        vm.setScaleMode(.wistfulMinor)
                    }

                    moodBlockButton(
                        title: "🎋 安心5音",
                        selected: vm.pentatonicSafe,
                        tint: Color(hex: 0x2F9E44)
                    ) {
                        vm.togglePentatonicSafe()
                    }

                    Spacer(minLength: 2)

                    // 角落里的小陶诺（永远不说话，只随你敲琴开心眨眼转头）
                    ChimmoFigureView(
                        member: .taono,
                        isNight: palette.isNight,
                        isMinor: vm.document.scaleMode.isMinorFlavored,
                        isSinging: vm.isPlaying || struckLane != nil,
                        focusedDegree: vm.latestDegree,
                        time: 0,
                        listeningTilt: vm.capturePipeline.isRecording ? (vm.capturePipeline.inputLevel - 0.3) : 0
                    )
                    .frame(width: 34, height: 34)
                    .onTapGesture {
                        vm.strikeXylophoneLane(XylophoneLane.allLanes[0])
                    }
                }

                // 主操作行：整句听 · 敲下脑海节奏（大按钮）· 新建
                HStack(spacing: 10) {
                    Button {
                        vm.togglePlayback()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                                .font(.subheadline.weight(.bold))
                            Text(vm.isPlaying ? "停" : "整句听")
                                .font(.subheadline.weight(.bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(palette.cardSurface))
                        .foregroundStyle(palette.homeAnchor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.startRhythmTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.subheadline.weight(.bold))
                            Text("敲下脑海节奏")
                                .font(.subheadline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                        .shadow(color: palette.homeAnchor.opacity(0.28), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.startBlankCanvas()
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(palette.cardSurface))
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新建空白纸带")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.shelfSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.22 : 0.05), radius: 10, y: 3)
        )
    }

    private func moodBlockButton(title: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected ? tint : palette.cardSurface)
                )
                .foregroundStyle(selected ? .white : palette.primaryInk)
        }
        .buttonStyle(.plain)
    }

    /// 底部内联大木鼓（敲拍时眼睛直接看着上方纸带冒出一根根拍柱，绝不跳页！）
    private var inlineRhythmDrumPad: some View {
        VStack(spacing: 10) {
            Button {
                vm.recordRhythmDrumTap()
                drumPulse = 0.94
                withAnimation(.spring(response: 0.24, dampingFraction: 0.6)) {
                    drumPulse = 1.0
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(palette.nightLampGold.opacity(0.24))
                            .frame(width: 52, height: 52)
                        Image(systemName: "hand.tap.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.nightLampGold)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.liveTapTimestamps.isEmpty ? "哒、哒、哒 — 敲出脑海里的节奏" : "已敲下 \(vm.liveTapTimestamps.count) 拍（继续敲或点下方定型）")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("不管音高，只按快慢节奏轻敲这块木鼓")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(palette.homeAnchor.opacity(0.55), lineWidth: 2)
                        )
                )
                .scaleEffect(drumPulse)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button("取消") {
                    vm.cancelRhythmTap()
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Capsule().fill(palette.cardSurface))
                .foregroundStyle(palette.secondaryInk)
                .buttonStyle(.plain)

                if !vm.liveTapTimestamps.isEmpty {
                    Button("重敲") {
                        vm.resetRhythmTaps()
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(palette.cardSurface))
                    .foregroundStyle(palette.primaryInk)
                    .buttonStyle(.plain)
                }

                Button {
                    vm.commitRhythmTaps()
                } label: {
                    Text(vm.liveTapTimestamps.count >= 2 ? "✓ 定型 · 选山坡调高低 →" : "用 6 拍示范体验 →")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MiniHillShape: View {
    let profile: [Double]
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard profile.count > 1 else { return }
            var p = Path()
            for (idx, h) in profile.enumerated() {
                let x = CGFloat(idx) / CGFloat(profile.count - 1) * size.width
                let y = size.height - 1.5 - CGFloat(h) * (size.height - 3.0)
                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
        }
    }
}
