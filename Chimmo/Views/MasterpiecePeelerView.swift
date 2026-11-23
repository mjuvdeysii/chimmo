import SwiftUI

/// 名曲「剥洋葱倒拆 + 换种重生」引擎：
/// 反直觉地从 100% 大师成品（圣桑《天鹅》、巴赫、李斯特等）一层层剥回最初的 3 颗火种音，
/// 并允许零基础用户改掉任意 1 颗火种再拉回 100%，瞬间长出属于自己的大师风格变奏！
public enum MasterpieceOnionEngine {

    public enum NoteLayer: Int, Sendable {
        case seed = 0      // 最初 3 颗核心火种（10% 以上始终可见，支持亲手改音！）
        case skeleton = 1  // 骨干旋律节点（35% 以上可见）
        case ornament = 2  // 灵动过渡与装饰（65% 以上可见）
    }

    public static func layer(forIndex index: Int, totalCount: Int) -> NoteLayer {
        guard totalCount > 0 else { return .seed }
        if index < 3 { return .seed }
        if index == totalCount - 1 { return .skeleton }
        let strideStep = max(2, totalCount / 6)
        return (index % strideStep == 0) ? .skeleton : .ornament
    }

    /// 把用户对最初 3 颗火种音所做的音高微调（seedShifts[0..2]），按分形呼应优雅传播到整首名曲，生成专属变奏！
    public static func applySeedShifts(document: MelodyDocument, shifts: [Int]) -> MelodyDocument {
        guard !shifts.allSatisfy({ $0 == 0 }) else { return document }
        var copy = document
        let s = [
            shifts.indices.contains(0) ? shifts[0] : 0,
            shifts.indices.contains(1) ? shifts[1] : 0,
            shifts.indices.contains(2) ? shifts[2] : 0
        ]

        copy.notes = document.notes.enumerated().map { idx, bead in
            var b = bead
            let shift: Int
            if idx < 3 {
                shift = s[idx]
            } else if idx == document.notes.count - 1 {
                // 保持结尾稳稳归家不漂移
                shift = 0
            } else {
                // 让后续乐句周期性呼应用户的火种变化，听起来既保留原曲气质又长出新旋律！
                shift = s[idx % 3]
            }

            if shift != 0 {
                let linear = b.octaveOffset * 7 + (b.degree - 1) + shift
                let clamped = max(-3, min(8, linear))
                let newOct = Int(floor(Double(clamped) / 7.0))
                let newDeg = clamped - newOct * 7 + 1
                b.degree = max(1, min(7, newDeg))
                b.octaveOffset = max(-1, min(1, newOct))
            }
            return b
        }
        copy.title = "\(document.title) · 我的变奏"
        copy.isSpecimen = false
        return copy
    }
}

/// 剥洋葱倒拆与换种重生全屏剧场（继承《摸索台灯》纸面极简美学 + 呼吸余影动效）
public struct MasterpiecePeelerView: View {
    public let initialPiece: MelodyDocument
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    public let onSaveVariationToBook: (MelodyDocument, AccompanimentTexture, String) -> Void
    public let onOpenInWorkbench: (MelodyDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentPiece: MelodyDocument
    @State private var peelDepth: Double = 1.0 // 1.0 = 100% 大师成品, 0.1 = 3 音火种
    @State private var seedShifts: [Int] = [0, 0, 0]
    @State private var isPlaying: Bool = false
    @State private var playheadTime: Double? = nil
    @State private var activeNoteIndex: Int? = nil
    @State private var afterimages: [PeelAfterimage] = []
    @State private var playTask: Task<Void, Never>? = nil
    @State private var savedBanner: String? = nil

    private struct PeelAfterimage: Identifiable {
        let id = UUID()
        let birth: TimeInterval
        let xFrac: CGFloat
        let yNorm: CGFloat
        let color: Color
    }

    private static let featuredPeelPieces: [MelodyDocument] = [
        SpecimenLibrary.saintSaensTheSwan,
        SpecimenLibrary.lisztLiebestraum,
        SpecimenLibrary.bachPreludeSeed,
        SpecimenLibrary.tchaikovskySwanLake,
        SpecimenLibrary.dvorakGoingHome,
        SpecimenLibrary.summerSuspension
    ]

    public init(
        initialPiece: MelodyDocument,
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        onSaveVariationToBook: @escaping (MelodyDocument, AccompanimentTexture, String) -> Void,
        onOpenInWorkbench: @escaping (MelodyDocument) -> Void
    ) {
        self.initialPiece = initialPiece
        self.palette = palette
        self.synth = synth
        self.onSaveVariationToBook = onSaveVariationToBook
        self.onOpenInWorkbench = onOpenInWorkbench
        self._currentPiece = State(initialValue: initialPiece)
    }

    private var recomposedDocument: MelodyDocument {
        MasterpieceOnionEngine.applySeedShifts(document: currentPiece, shifts: seedShifts)
    }

    private var hasSeedMutation: Bool {
        seedShifts.contains { $0 != 0 }
    }

    private var layerTitle: String {
        if peelDepth >= 0.78 { return "100% 大师完整织体（主旋律 + 湖面水波 + 影子对话）" }
        if peelDepth >= 0.50 { return "65% 褪去华丽伴奏（听见纯粹线条与和弦底色）" }
        if peelDepth >= 0.26 { return "35% 抽离核心骨干（名曲其实只站在这 6 颗支柱上）" }
        return "10% 最初 3 颗火种（点下方圆珠改 1 颗音，再拉回 100%！）"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette, accentTint: currentPiece.scaleMode.skyAuroraColor(isNight: palette.isNight))

                VStack(spacing: 14) {
                    // 顶部一键切换精选名曲（极简纸片胶囊）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.featuredPeelPieces) { piece in
                                let sel = piece.title == currentPiece.title
                                Button {
                                    stopPlayback()
                                    currentPiece = piece
                                    seedShifts = [0, 0, 0]
                                    peelDepth = 1.0
                                    savedBanner = nil
                                    startPlayback()
                                } label: {
                                    Text(piece.title)
                                        .font(.caption.weight(sel ? .bold : .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(sel ? palette.homeAnchor : palette.cardSurface))
                                        .foregroundStyle(sel ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // 中央纸上声学舞台（含余影呼吸与 3 音火种高光）
                    peelerStageCard
                        .padding(.horizontal, 16)

                    // 核心交互：剥洋葱单指滑轨（100% <-> 10%）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(layerTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Spacer()
                            Text("\(Int((peelDepth * 100).rounded()))%")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(palette.homeAnchor)
                        }

                        Slider(value: $peelDepth, in: 0.10...1.0)
                            .tint(palette.homeAnchor)

                        HStack {
                            Text("🔥 3音火种")
                            Spacer()
                            Text("🦴 骨干")
                            Spacer()
                            Text("🌊 去水波")
                            Spacer()
                            Text("✨ 完整成品")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.cardSurface)
                            .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.04), radius: 8, y: 3)
                    )
                    .padding(.horizontal, 16)

                    // 改写最初 3 颗火种面板（随时改 1 颗，拉回 100% 瞬间重生！）
                    seedMutationPanel
                        .padding(.horizontal, 16)

                    if let msg = savedBanner {
                        Text(msg)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.homeAnchor)
                    }

                    // 底部极简控制栏
                    HStack(spacing: 12) {
                        Button {
                            if isPlaying { stopPlayback() } else { startPlayback() }
                        } label: {
                            Label(isPlaying ? "暂停" : "播放感受", systemImage: isPlaying ? "pause.fill" : "play.fill")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                        }

                        Button {
                            let doc = recomposedDocument
                            let tex = currentPiece.preferredTexture ?? .swanRipple
                            onSaveVariationToBook(doc, tex, hasSeedMutation ? "✨ 我的名曲变奏" : "🦢 湖畔微风")
                            AcousticHapticsEngine.shared.playResolutionExhale()
                            savedBanner = "已贴进你的「脑放手账册」！"
                        } label: {
                            Label(hasSeedMutation ? "把我的变奏贴进手账" : "收藏到胶带手账", systemImage: "bookmark.fill")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(palette.cardSurface))
                                .foregroundStyle(palette.primaryInk)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .padding(.top, 8)
            }
            .navigationTitle("剥洋葱听懂大师")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") {
                        stopPlayback()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("工作台精修") {
                        stopPlayback()
                        onOpenInWorkbench(recomposedDocument)
                    }
                }
            }
            .onAppear { startPlayback() }
            .onDisappear { stopPlayback() }
        }
    }

    // MARK: - Paper Stage with Acoustic Afterimage (余影)

    private var peelerStageCard: some View {
        let doc = recomposedDocument
        let totalSec = max(3.0, doc.totalDuration)

        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.22 : 0.05), radius: 12, y: 4)

                Canvas { ctx, size in
                    let padX: CGFloat = 22
                    let usableW = max(80, size.width - padX * 2)

                    // 1. 水波伴奏背景波浪（随 peelDepth 在 60%~100% 之间温柔渐显/褪去）
                    let waterAlpha = max(0, min(1, (peelDepth - 0.55) / 0.35))
                    if waterAlpha > 0.02 {
                        for wave in 0..<2 {
                            var wp = Path()
                            for i in 0...44 {
                                let f = Double(i) / 44.0
                                let x = CGFloat(f) * size.width
                                let baseY = size.height * (0.74 + Double(wave) * 0.08)
                                let dy = reduceMotion ? 0 : sin(f * 8.0 + now * (1.8 + Double(wave) * 0.5)) * 6.0
                                let pt = CGPoint(x: x, y: CGFloat(baseY + dy))
                                if i == 0 { wp.move(to: pt) } else { wp.addLine(to: pt) }
                            }
                            ctx.stroke(
                                wp,
                                with: .color(palette.bassRibbon.opacity(0.24 * waterAlpha)),
                                style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                            )
                        }
                    }

                    // 2. 余影（Acoustic Afterimage：像呼吸雾气一样轻微放大并向上消散，0.85 秒）
                    for img in afterimages {
                        let age = now - img.birth
                        guard age >= 0 && age < 0.88 else { continue }
                        let p = age / 0.88
                        let x = padX + img.xFrac * usableW
                        let y = size.height - 26 - img.yNorm * (size.height - 54) - CGFloat(p * 18.0)
                        let r: CGFloat = 10.0 + CGFloat(p * 12.0)
                        let alpha = pow(1.0 - p, 1.8) * 0.42
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(img.color.opacity(alpha))
                        )
                    }

                    // 3. 旋律连线与按剥离层级显隐的音珠
                    var visiblePts: [(CGPoint, Color, Bool, Int)] = []
                    for (idx, bead) in doc.notes.enumerated() {
                        let layer = MasterpieceOnionEngine.layer(forIndex: idx, totalCount: doc.notes.count)
                        let vis = visibilityAlpha(for: layer)
                        guard vis > 0.05 else { continue }

                        let x = padX + CGFloat(bead.rawOnset / totalSec) * usableW
                        let normY = ScalePitchGeometry.normalizedY(degree: bead.degree, octaveOffset: bead.octaveOffset, mode: doc.scaleMode)
                        let y = size.height - 26 - normY * (size.height - 54)
                        let col = (palette.isNight ? bead.member.nightGlowColor : bead.member.bodyColor).opacity(vis)
                        visiblePts.append((CGPoint(x: x, y: y), col, layer == .seed, idx))
                    }

                    if visiblePts.count > 1 {
                        var path = Path()
                        path.move(to: visiblePts[0].0)
                        for i in 1..<visiblePts.count {
                            let p0 = visiblePts[i - 1].0
                            let p1 = visiblePts[i].0
                            path.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) * 0.5, y: min(p0.y, p1.y) - 10))
                        }
                        ctx.stroke(path, with: .color(palette.homeAnchor.opacity(0.45)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }

                    for (pt, col, isSeed, idx) in visiblePts {
                        let isCur = activeNoteIndex == idx
                        let r: CGFloat = isSeed ? (isCur ? 12.5 : 10.5) : (isCur ? 9.5 : 7.0)
                        if isSeed {
                            ctx.stroke(
                                Path(ellipseIn: CGRect(x: pt.x - r - 4, y: pt.y - r - 4, width: (r + 4) * 2, height: (r + 4) * 2)),
                                with: .color(palette.nightLampGold.opacity(0.85)),
                                lineWidth: 1.8
                            )
                        }
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(col))
                    }

                    // 播放指针
                    if let t = playheadTime {
                        let px = padX + CGFloat(min(1.0, max(0.0, t / totalSec))) * usableW
                        var line = Path()
                        line.move(to: CGPoint(x: px, y: 14))
                        line.addLine(to: CGPoint(x: px, y: size.height - 14))
                        ctx.stroke(line, with: .color(palette.melodyTerracotta.opacity(0.6)), lineWidth: 1.6)
                    }
                }

                // 顶部轻盈一句话导赏
                VStack {
                    if let moment = currentPiece.activeGuidedMoment(at: playheadTime) {
                        HStack(spacing: 6) {
                            Text(moment.badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                            Text(moment.caption)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.primaryInk)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var seedMutationPanel: some View {
        let doc = recomposedDocument
        let seeds = Array(doc.notes.prefix(3))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🔥 改写最初 3 颗火种（改完再把滑轨拉回 100% 听听奇迹！）")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                Spacer()
                if hasSeedMutation {
                    Button("还原原曲") {
                        seedShifts = [0, 0, 0]
                        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.homeAnchor)
                }
            }

            HStack(spacing: 10) {
                ForEach(0..<seeds.count, id: \.self) { idx in
                    let b = seeds[idx]
                    let m = b.member
                    let col = palette.isNight ? m.nightGlowColor : m.bodyColor

                    HStack(spacing: 6) {
                        Button {
                            mutateSeed(idx, delta: -1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(palette.secondaryInk)
                        }

                        VStack(spacing: 1) {
                            Text("火种\(idx + 1)")
                                .font(.system(size: 9))
                                .foregroundStyle(palette.secondaryInk)
                            Text("\(b.degree)·\(m.chineseName)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(col)
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            mutateSeed(idx, delta: 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(col)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 13).fill(palette.shelfSurface))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardSurface)
        )
    }

    private func mutateSeed(_ idx: Int, delta: Int) {
        guard seedShifts.indices.contains(idx) else { return }
        seedShifts[idx] = max(-2, min(2, seedShifts[idx] + delta))
        savedBanner = nil
        AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        let doc = recomposedDocument
        if doc.notes.indices.contains(idx) {
            let b = doc.notes[idx]
            let hz = doc.scaleMode.frequencyHz(rootMIDI: doc.rootMIDI, degree: b.degree, octaveOffset: b.octaveOffset)
            let v = doc.preferredVoice ?? .singingCello
            synth.playNote(frequency: hz, velocity: 0.62, decay: 1.3, timbre: FeltPianoSynth.Timbre.from(voice: v))
        }
    }

    private func visibilityAlpha(for layer: MasterpieceOnionEngine.NoteLayer) -> Double {
        switch layer {
        case .seed:
            return 1.0
        case .skeleton:
            return peelDepth >= 0.26 ? 1.0 : 0.14
        case .ornament:
            return peelDepth >= 0.50 ? 1.0 : 0.08
        }
    }

    // MARK: - Onion-Aware Live Sequencer

    private func startPlayback() {
        stopPlayback()
        isPlaying = true

        playTask = Task { @MainActor in
            while !Task.isCancelled && isPlaying {
                let doc = recomposedDocument
                let spans = TheoryLensEngine.buildChordSpans(document: doc, preset: .autoMatch)
                let shadows = CounterpointShadowEngine.generateShadowVoice(document: doc, spans: spans)
                let total = doc.totalDuration
                let voiceTimbre = FeltPianoSynth.Timbre.from(voice: currentPiece.preferredVoice ?? .singingCello)
                let tex = currentPiece.preferredTexture ?? .swanRipple

                let start = Date()
                var nextNote = 0
                var nextShadow = 0
                var lastSpan = -1

                while !Task.isCancelled && isPlaying {
                    let elapsed = Date().timeIntervalSince(start)
                    playheadTime = elapsed

                    // 左手织体随剥离度真实渐弱（65% 以下切纯净长音，35% 以下静音只听骨感旋律！）
                    if let sp = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }), sp.id != lastSpan {
                        lastSpan = sp.id
                        if peelDepth >= 0.50 {
                            let useTex: AccompanimentTexture = peelDepth >= 0.76 ? tex : .pureChorale
                            synth.playDiatonicChord(
                                rootMIDI: doc.rootMIDI,
                                mode: doc.scaleMode,
                                chord: sp.chord,
                                texture: useTex,
                                spanDuration: sp.endTime - sp.startTime,
                                intensity: 0.78 * peelDepth
                            )
                        }
                    }

                    while nextNote < doc.notes.count && doc.notes[nextNote].rawOnset <= elapsed {
                        let b = doc.notes[nextNote]
                        let layer = MasterpieceOnionEngine.layer(forIndex: nextNote, totalCount: doc.notes.count)
                        let shouldSound = (layer == .seed)
                            || (layer == .skeleton && peelDepth >= 0.26)
                            || (layer == .ornament && peelDepth >= 0.50)

                        if shouldSound {
                            activeNoteIndex = nextNote
                            let hz = doc.scaleMode.frequencyHz(rootMIDI: doc.rootMIDI, degree: b.degree, octaveOffset: b.octaveOffset)
                            synth.playNote(frequency: hz, velocity: 0.62, decay: max(1.0, b.rawDuration * 1.45), timbre: voiceTimbre)
                            spawnAfterimage(bead: b, doc: doc, totalSec: max(3.0, total))
                        }
                        nextNote += 1
                    }

                    // 影子对位仅在 80% 以上完整织体时温柔浮现
                    if peelDepth >= 0.80 {
                        while nextShadow < shadows.count && shadows[nextShadow].onset <= elapsed {
                            let sh = shadows[nextShadow]
                            let hz = doc.scaleMode.frequencyHz(rootMIDI: doc.rootMIDI, degree: sh.degree, octaveOffset: sh.octaveOffset)
                            synth.playNote(frequency: hz, velocity: 0.28, decay: max(0.85, sh.duration * 1.3), timbre: .celesta)
                            nextShadow += 1
                        }
                    }

                    if elapsed >= total { break }
                    try? await Task.sleep(nanoseconds: 18_000_000)
                }

                if Task.isCancelled || !isPlaying { break }
                try? await Task.sleep(nanoseconds: 420_000_000)
            }
        }
    }

    private func spawnAfterimage(bead: NoteBead, doc: MelodyDocument, totalSec: Double) {
        let now = Date().timeIntervalSinceReferenceDate
        afterimages.removeAll { now - $0.birth > 0.95 }
        let xFrac = CGFloat(min(1.0, max(0.0, bead.rawOnset / totalSec)))
        let yNorm = ScalePitchGeometry.normalizedY(degree: bead.degree, octaveOffset: bead.octaveOffset, mode: doc.scaleMode)
        let col = palette.isNight ? bead.member.nightGlowColor : bead.member.bodyColor
        afterimages.append(PeelAfterimage(birth: now, xFrac: xFrac, yNorm: yNorm, color: col))
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        playheadTime = nil
        activeNoteIndex = nil
    }
}
