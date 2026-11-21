import SwiftUI

/// 零音准门槛脑放捕手：「先敲心跳 · 再抹坡度」（认知解耦无障碍设计）
/// 彻底解放五音不全或在公共场合不方便开口唱歌的人：
/// - 第 1 步（只管节奏）：把脑海里那句旋律的节奏拍子直接敲在玻璃鼓面上，无需管音高；
/// - 第 2 步（只管起伏）：用一根手指顺着脑海里的上下坡度轻轻一抹，所有心跳点瞬间吸附成清澈优美的旋律！
public struct RhythmContourCaptureSheet: View {
    public let palette: ChimmoPalette
    public let scaleMode: ScaleMode
    public let voice: MelodyVoice
    public let texture: AccompanimentTexture
    public let synth: FeltPianoSynth
    public let onCommitMelody: ([NoteBead], Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 1 // 1 = 敲心跳, 2 = 抹坡度
    @State private var tapTimestamps: [TimeInterval] = []
    @State private var beatNodes: [CapturedNode] = []
    @State private var pentatonicSafe: Bool = true
    @State private var drumRippleScale: CGFloat = 1.0
    @State private var brushTrail: [CGPoint] = []
    @State private var previewTask: Task<Void, Never>? = nil
    @State private var activePreviewIndex: Int? = nil

    private struct CapturedNode: Identifiable {
        let id = UUID()
        var onset: Double
        var duration: Double
        var degree: Int
        var octaveOffset: Int
    }

    public init(
        palette: ChimmoPalette,
        scaleMode: ScaleMode,
        voice: MelodyVoice,
        texture: AccompanimentTexture,
        synth: FeltPianoSynth,
        onCommitMelody: @escaping ([NoteBead], Bool) -> Void
    ) {
        self.palette = palette
        self.scaleMode = scaleMode
        self.voice = voice
        self.texture = texture
        self.synth = synth
        self.onCommitMelody = onCommitMelody
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 两步清晰引导指示器
                HStack(spacing: 8) {
                    stepPill(index: 1, title: "① 先敲心跳（不管音高）")
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                    stepPill(index: 2, title: "② 一指抹出上下坡度")
                }
                .padding(.top, 8)

                if step == 1 {
                    stepOneRhythmDrum
                } else {
                    stepTwoContourBrush
                }
            }
            .padding(16)
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("敲拍画坡 · 零门槛记脑放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        previewTask?.cancel()
                        dismiss()
                    }
                }
            }
            .onDisappear { previewTask?.cancel() }
        }
    }

    private func stepPill(index: Int, title: String) -> some View {
        let active = step == index
        return Text(title)
            .font(.caption.weight(active ? .bold : .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
            .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x0E1726) : .white) : palette.secondaryInk)
    }

    // MARK: - Step 1: Heartbeat Glass Drum

    private var stepOneRhythmDrum: some View {
        VStack(spacing: 16) {
            Text("不用开口、不用怕跑调！闭上眼回想脑海里的那句旋律，顺着它的节奏长短，在下面这面光感鼓面上随手敲出 3～12 下。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // 发光玻璃心跳鼓面
            Button {
                recordTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    palette.homeAnchor.opacity(0.32),
                                    palette.bassRibbon.opacity(0.14),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 118
                            )
                        )
                        .frame(width: 230, height: 230)
                        .scaleEffect(drumRippleScale)

                    Circle()
                        .fill(palette.cardSurface)
                        .frame(width: 174, height: 174)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [palette.homeAnchor, palette.bassRibbon],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                        .shadow(color: palette.homeAnchor.opacity(0.22), radius: 16, y: 6)

                    VStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.largeTitle)
                            .foregroundStyle(palette.homeAnchor)
                        Text(tapTimestamps.isEmpty ? "轻敲这里记录心跳" : "已敲下 \(tapTimestamps.count) 颗心跳")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("按脑海里的快慢随手点")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                }
            }
            .buttonStyle(.plain)

            // 已敲出的时间心跳预览条
            if !tapTimestamps.isEmpty {
                HStack(spacing: 6) {
                    ForEach(0..<tapTimestamps.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == 0 ? palette.melodyTerracotta : palette.homeAnchor)
                            .frame(width: idx == 0 ? 12 : 9, height: idx == 0 ? 12 : 9)
                    }
                }
                .padding(.vertical, 6)
            }

            Spacer()

            HStack(spacing: 12) {
                if !tapTimestamps.isEmpty {
                    Button("重敲") {
                        tapTimestamps.removeAll()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(palette.cardSurface))
                    .foregroundStyle(palette.secondaryInk)
                }

                Button {
                    advanceToContourStep()
                } label: {
                    Text(tapTimestamps.count >= 2 ? "下一步：抹出高低坡度 →" : "先敲至少 2 下心跳（或直接用 6 拍示范）")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                }
            }
        }
    }

    private func recordTap() {
        let now = Date().timeIntervalSinceReferenceDate
        if tapTimestamps.count >= 14 {
            tapTimestamps.removeFirst()
        }
        tapTimestamps.append(now)

        let isFirst = tapTimestamps.count == 1
        AcousticHapticsEngine.shared.playBeatTap(isStrong: isFirst)
        let hz = scaleMode.frequencyHz(rootMIDI: 60, degree: isFirst ? 1 : 5, octaveOffset: 0)
        synth.playNote(frequency: hz, velocity: isFirst ? 0.52 : 0.36, decay: 0.45, timbre: .liquidHarp)

        drumRippleScale = 1.15
        withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
            drumRippleScale = 1.0
        }
    }

    private func advanceToContourStep() {
        if tapTimestamps.count < 2 {
            // 若用户想直接体验抹坡度，给出舒展的 6 颗默认呼吸心跳点
            let defaultOnsets: [Double] = [0.12, 0.58, 1.04, 1.62, 2.15, 2.75]
            beatNodes = defaultOnsets.enumerated().map { idx, t in
                let nextT = idx + 1 < defaultOnsets.count ? defaultOnsets[idx + 1] : t + 0.72
                return CapturedNode(onset: t, duration: max(0.32, (nextT - t) * 0.9), degree: 3, octaveOffset: 0)
            }
        } else {
            let t0 = tapTimestamps[0]
            var rels = tapTimestamps.map { max(0.0, $0 - t0) }
            // 防止总时长过短或过长，自然压缩至 2.2~7.5 秒舒适阅读区间
            if let last = rels.last, last > 7.5 {
                let scale = 7.2 / last
                rels = rels.map { $0 * scale }
            }
            beatNodes = rels.enumerated().map { idx, t in
                let nextT = idx + 1 < rels.count ? rels[idx + 1] : t + 0.68
                let dur = max(0.24, min(1.4, (nextT - t) * 0.92))
                return CapturedNode(onset: 0.12 + t, duration: dur, degree: 3, octaveOffset: 0)
            }
        }
        step = 2
    }

    // MARK: - Step 2: One-Finger Pitch Contour Brush

    private var stepTwoContourBrush: some View {
        let total = max(2.4, (beatNodes.last.map { $0.onset + $0.duration } ?? 2.4) + 0.4)

        return VStack(spacing: 12) {
            Text("节奏已经稳稳锁好啦！现在把手指放上去，顺着脑海里的高低走势从左向右一抹，所有音珠会自动吸附成动听旋律。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)
                .multilineTextAlignment(.center)

            // 🎋 五声安全网开关（零基础彻底防跑调防撞音！）
            Toggle(isOn: $pentatonicSafe) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(palette.homeAnchor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("五声安全护网（1·2·3·5·6 怎么抹都绝不难听）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("关闭后解锁全部 7 音，可抹出 4 与 7 的半音戏剧张力")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                }
            }
            .tint(palette.homeAnchor)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.cardSurface))

            // 交互抹坡度画布
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let padX: CGFloat = 24
                let usableW = max(80, w - padX * 2)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(palette.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(palette.divider, lineWidth: 1)
                        )

                    Canvas { ctx, size in
                        // 背景温柔海拔线
                        let rows = pentatonicSafe ? [1, 2, 3, 5, 6] : [1, 2, 3, 4, 5, 6, 7]
                        for deg in rows {
                            let y = yPos(degree: deg, octave: 0, height: size.height)
                            var p = Path()
                            p.move(to: CGPoint(x: 14, y: y))
                            p.addLine(to: CGPoint(x: size.width - 14, y: y))
                            ctx.stroke(p, with: .color(deg == 1 ? palette.homeAnchor.opacity(0.35) : palette.divider), lineWidth: deg == 1 ? 1.4 : 0.7)
                        }

                        // 连接所有心跳音珠的优美弧线
                        let pts: [CGPoint] = beatNodes.map { node in
                            let x = padX + CGFloat(node.onset / total) * usableW
                            let y = yPos(degree: node.degree, octave: node.octaveOffset, height: size.height)
                            return CGPoint(x: x, y: y)
                        }

                        // 垂直节奏支柱
                        for pt in pts {
                            var stem = Path()
                            stem.move(to: CGPoint(x: pt.x, y: size.height - 14))
                            stem.addLine(to: pt)
                            ctx.stroke(stem, with: .color(palette.divider), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }

                        if pts.count > 1 {
                            var curve = Path()
                            curve.move(to: pts[0])
                            for i in 1..<pts.count {
                                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) * 0.5, y: min(pts[i - 1].y, pts[i].y) - 10)
                                curve.addQuadCurve(to: pts[i], control: mid)
                            }
                            ctx.stroke(curve, with: .color(palette.homeAnchor.opacity(0.7)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                        }

                        // 手指抹过的高光轨迹
                        if brushTrail.count > 1 {
                            var trail = Path()
                            trail.move(to: brushTrail[0])
                            for p in brushTrail.dropFirst() { trail.addLine(to: p) }
                            ctx.stroke(trail, with: .color(palette.melodyTerracotta.opacity(0.55)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }

                        // 音珠本体
                        for (idx, node) in beatNodes.enumerated() {
                            let pt = pts[idx]
                            let m = ChimmoMember.from(degree: node.degree)
                            let col = palette.isNight ? m.nightGlowColor : m.bodyColor
                            let isAct = activePreviewIndex == idx
                            let r: CGFloat = isAct ? 13 : 10
                            if isAct {
                                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 20, y: pt.y - 20, width: 40, height: 40)), with: .color(col.opacity(0.28)))
                            }
                            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(col))
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            brushTrail.append(val.location)
                            if brushTrail.count > 45 { brushTrail.removeFirst() }
                            let targetTime = Double(max(0, min(1, (val.location.x - padX) / usableW))) * total
                            let (deg, oct) = nearestAllowedPitch(y: val.location.y, height: h)

                            if let idx = beatNodes.indices.min(by: { abs(beatNodes[$0].onset - targetTime) < abs(beatNodes[$1].onset - targetTime) }),
                               abs(beatNodes[idx].onset - targetTime) < max(0.32, total * 0.14) {
                                if beatNodes[idx].degree != deg || beatNodes[idx].octaveOffset != oct {
                                    beatNodes[idx].degree = deg
                                    beatNodes[idx].octaveOffset = oct
                                    AcousticHapticsEngine.shared.playBeatTap(isStrong: deg == 1)
                                    let hz = scaleMode.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: oct)
                                    synth.playNote(frequency: hz, velocity: 0.56, decay: 1.1, timbre: FeltPianoSynth.Timbre.from(voice: voice))
                                }
                            }
                        }
                        .onEnded { _ in
                            brushTrail.removeAll()
                            playPreview()
                        }
                )
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                Button {
                    step = 1
                } label: {
                    Text("← 重敲节奏")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(palette.cardSurface))
                        .foregroundStyle(palette.secondaryInk)
                }

                Button {
                    playPreview()
                } label: {
                    Label("试听", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(palette.bassRibbon.opacity(0.16)))
                        .foregroundStyle(palette.bassRibbon)
                }

                Button {
                    previewTask?.cancel()
                    let beads = beatNodes.map {
                        NoteBead(
                            degree: $0.degree,
                            octaveOffset: $0.octaveOffset,
                            rawOnset: $0.onset,
                            rawDuration: $0.duration,
                            phraseTag: "起·脑放"
                        )
                    }
                    onCommitMelody(beads, false)
                    dismiss()
                } label: {
                    Text("放入工作台 →")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                }
            }
        }
    }

    private func playPreview() {
        previewTask?.cancel()
        let nodes = beatNodes
        let mode = scaleMode
        let v = voice
        let tex = texture
        previewTask = Task { @MainActor in
            guard let first = nodes.first else { return }
            synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: .I, texture: tex, spanDuration: 1.6, intensity: 0.72)
            for (idx, n) in nodes.enumerated() {
                if Task.isCancelled { return }
                let delay = idx == 0 ? 0.0 : max(0.12, n.onset - nodes[idx - 1].onset)
                if idx > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                if Task.isCancelled { return }
                activePreviewIndex = idx
                let hz = mode.frequencyHz(rootMIDI: 60, degree: n.degree, octaveOffset: n.octaveOffset)
                synth.playNote(frequency: hz, velocity: 0.60, decay: max(0.9, n.duration * 1.4), timbre: FeltPianoSynth.Timbre.from(voice: v))
                if idx == nodes.count / 2 {
                    synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: .IV, texture: tex, spanDuration: 1.4, intensity: 0.68)
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(max(0.4, first.duration) * 1_000_000_000))
            activePreviewIndex = nil
        }
    }

    private func yPos(degree: Int, octave: Int, height: CGFloat) -> CGFloat {
        let pad: CGFloat = 24
        let norm = ScalePitchGeometry.normalizedY(degree: degree, octaveOffset: octave, mode: scaleMode)
        return height - pad - norm * max(40, height - pad * 2)
    }

    private func nearestAllowedPitch(y: CGFloat, height: CGFloat) -> (Int, Int) {
        let pad: CGFloat = 24
        let normFromBottom = max(0, min(1, (height - pad - y) / max(40, height - pad * 2)))
        let raw = ScalePitchGeometry.nearestDegreeAndOctave(normalizedFromBottom: normFromBottom, mode: scaleMode)
        guard pentatonicSafe else { return raw }
        let safeDeg: Int
        switch raw.degree {
        case 4: safeDeg = 3
        case 7: safeDeg = 6
        default: safeDeg = raw.degree
        }
        return (safeDeg, raw.octaveOffset)
    }
}
