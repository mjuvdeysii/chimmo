import QuartzCore
import SwiftUI

/// 咩哞 v0.7 Tab 2：「唱片馆」—— 我的旋转脑放唱片 + 28 首公版/原创名曲黑胶馆（一键放上星盘亮灯跟弹或改写）
public struct MusicBoxShelfView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onLoadSavedToBoard: (SavedMelodyEntry) -> Void
    public let onPlayAlongSpecimen: (MelodyDocument) -> Void
    public let onEditSpecimenOnBoard: (MelodyDocument) -> Void
    public let onStartNewTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSegment: Int = 1 // 默认也可在我的唱片(0)与28首名曲(1)间秒切；有保存作品自动先看0
    @State private var selectedCategory: String = "全部"
    @State private var playingEntryID: UUID? = nil
    @State private var inlinePlayStart: Double = 0
    @State private var inlinePlayTask: Task<Void, Never>? = nil

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        notebook: MelodyNotebookStore,
        currentDocumentID: UUID,
        onLoadSavedToBoard: @escaping (SavedMelodyEntry) -> Void,
        onPlayAlongSpecimen: @escaping (MelodyDocument) -> Void,
        onEditSpecimenOnBoard: @escaping (MelodyDocument) -> Void,
        onStartNewTap: @escaping () -> Void
    ) {
        self.palette = palette
        self.synth = synth
        self.notebook = notebook
        self.currentDocumentID = currentDocumentID
        self.onLoadSavedToBoard = onLoadSavedToBoard
        self.onPlayAlongSpecimen = onPlayAlongSpecimen
        self.onEditSpecimenOnBoard = onEditSpecimenOnBoard
        self.onStartNewTap = onStartNewTap
        self._selectedSegment = State(initialValue: notebook.entries.isEmpty ? 1 : 0)
    }

    private var filteredSpecimens: [MelodyDocument] {
        if selectedCategory == "全部" { return SpecimenLibrary.all }
        return SpecimenLibrary.all.filter { $0.specimenCategory == selectedCategory }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette)

                VStack(spacing: 0) {
                    Picker("唱片馆", selection: $selectedSegment) {
                        Text("我的唱片 (\(notebook.entries.count))").tag(0)
                        Text("28 首名曲盘").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if selectedSegment == 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SpecimenLibrary.categories, id: \.self) { cat in
                                    let active = selectedCategory == cat
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        Text(cat)
                                            .font(.caption.weight(active ? .bold : .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(active ? palette.homeAnchor : palette.cardSurface))
                                            .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    }

                    ScrollView {
                        VStack(spacing: 14) {
                            if selectedSegment == 0 {
                                mySavedDiscsSection
                            } else {
                                masterpieceDiscsSection
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("唱片馆")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stopInlinePlay() }
        }
    }

    // MARK: - 1. My Saved Spinning Discs

    @ViewBuilder
    private var mySavedDiscsSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(palette.shelfSurface)
                        .frame(width: 72, height: 72)
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(palette.homeAnchor)
                }

                Text("第一张旋转脑放唱片正等着你")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)

                Text("去星盘画板敲下节奏、一指画座山坡或随口轻哼，点右上角书签就会收进这里，随时在唱片上转动重温。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .multilineTextAlignment(.center)

                Button {
                    onStartNewTap()
                } label: {
                    Label("去声盘敲一段节奏", systemImage: "hand.tap.fill")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.05), radius: 12, y: 4)
            )
        } else {
            ForEach(Array(notebook.entries.enumerated()), id: \.element.id) { idx, entry in
                savedDiscCard(entry: entry, index: idx)
            }

            Text("所有脑放唱片 100% 安静保存在本机，永不上传")
                .font(.caption2)
                .foregroundStyle(palette.secondaryInk)
                .padding(.top, 4)
        }
    }

    private func savedDiscCard(entry: SavedMelodyEntry, index: Int) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let dateStr = entry.updatedAt.formatted(date: .abbreviated, time: .shortened)

        return HStack(spacing: 14) {
            // 旋转迷你唱片预览（播放时平滑转动！）
            MiniOrbitalDiscPreview(
                document: entry.document,
                isNight: palette.isNight,
                isSpinning: isPlayingThis && !reduceMotion,
                spinStartTime: inlinePlayStart
            )
            .frame(width: 78, height: 78)
            .onTapGesture {
                if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(entry.moodSticker ?? "◎ 星轨唱片")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                    Text(dateStr)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(1)
                }

                Text(entry.document.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Button {
                        if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
                    } label: {
                        Label(isPlayingThis ? "停" : "试听", systemImage: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopInlinePlay()
                        onLoadSavedToBoard(entry)
                    } label: {
                        Label("放上声盘", systemImage: "record.circle")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(role: .destructive) {
                        if isPlayingThis { stopInlinePlay() }
                        notebook.delete(id: entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除 \(entry.document.title)")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.25 : 0.06), radius: 10, y: 4)
        )
    }

    private func playInline(_ entry: SavedMelodyEntry) {
        stopInlinePlay()
        playingEntryID = entry.id
        inlinePlayStart = CACurrentMediaTime()
        let doc = entry.document
        let spans = TheoryLensEngine.buildChordSpans(document: doc, preset: entry.chordPreset, overrides: entry.chordOverrides)
        let tex = entry.accompanimentTexture ?? doc.preferredTexture ?? .swanRipple
        let voice = FeltPianoSynth.Timbre.from(voice: doc.preferredVoice ?? .singingCello)

        inlinePlayTask = Task { @MainActor in
            let sorted = doc.notes.sorted { $0.rawOnset < $1.rawOnset }
            let start = Date()
            var nextIdx = 0
            var lastSpan = -1
            let total = doc.totalDuration

            while !Task.isCancelled && playingEntryID == entry.id {
                let elapsed = Date().timeIntervalSince(start)
                if let sp = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }), sp.id != lastSpan {
                    lastSpan = sp.id
                    synth.playDiatonicChord(
                        rootMIDI: doc.rootMIDI,
                        mode: doc.scaleMode,
                        chord: sp.chord,
                        texture: tex,
                        spanDuration: sp.endTime - sp.startTime,
                        intensity: 0.72
                    )
                }
                while nextIdx < sorted.count && sorted[nextIdx].rawOnset <= elapsed {
                    let b = sorted[nextIdx]
                    let hz = doc.scaleMode.frequencyHz(rootMIDI: doc.rootMIDI, degree: b.degree, octaveOffset: b.octaveOffset)
                    synth.playNote(frequency: hz, velocity: 0.60, decay: max(1.0, b.rawDuration * 1.4), timbre: voice)
                    nextIdx += 1
                }
                if elapsed >= total { break }
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            if !Task.isCancelled { playingEntryID = nil }
        }
    }

    private func stopInlinePlay() {
        inlinePlayTask?.cancel()
        inlinePlayTask = nil
        playingEntryID = nil
    }

    // MARK: - 2. 28 Masterpiece Disc Cards

    private var masterpieceDiscsSection: some View {
        ForEach(filteredSpecimens) { spec in
            let voice = spec.preferredVoice ?? .concertPiano
            HStack(alignment: .center, spacing: 14) {
                MiniOrbitalDiscPreview(
                    document: spec,
                    isNight: palette.isNight,
                    isSpinning: false,
                    spinStartTime: 0
                )
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(spec.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)
                        Text(voice.label)
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.secondaryInk)
                        Spacer()
                        if spec.id == currentDocumentID {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(palette.homeAnchor)
                        }
                    }

                    if let insight = spec.composerInsight {
                        Text(insight)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Button {
                            stopInlinePlay()
                            onPlayAlongSpecimen(spec)
                        } label: {
                            Label("亮灯跟弹", systemImage: "sparkles")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            stopInlinePlay()
                            onEditSpecimenOnBoard(spec)
                        } label: {
                            Label("放上声盘", systemImage: "record.circle")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(palette.shelfSurface))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.04), radius: 8, y: 3)
            )
        }
    }
}

/// 迷你陶瓷星盘唱片缩略图（试听播放时同步转动）
private struct MiniOrbitalDiscPreview: View {
    let document: MelodyDocument
    let isNight: Bool
    let isSpinning: Bool
    let spinStartTime: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isSpinning)) { _ in
            let now = CACurrentMediaTime()
            let total = max(1.0, document.totalDuration)
            let rot: Double = isSpinning ? -((now - spinStartTime) / total) * 2.0 * Double.pi : 0.0

            Canvas { ctx, size in
                let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let maxR = min(size.width, size.height) * 0.47
                let discRect = CGRect(x: c.x - maxR, y: c.y - maxR, width: maxR * 2, height: maxR * 2)
                let discBg = isNight ? Color(hex: 0x1E2754) : Color(hex: 0xF7F1E4)
                let rimCol = isNight ? Color(hex: 0x564337) : Color(hex: 0xD3B78F)

                ctx.fill(Path(ellipseIn: discRect), with: .color(discBg))
                ctx.stroke(Path(ellipseIn: discRect), with: .color(rimCol.opacity(0.7)), lineWidth: 1.8)

                // 淡淡纹路
                for ring in [0.46, 0.66, 0.84] {
                    let rr = maxR * CGFloat(ring)
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                        with: .color(Color.gray.opacity(0.16)),
                        lineWidth: 0.6
                    )
                }

                // 音珠星座
                let notes = document.notes.sorted { $0.rawOnset < $1.rawOnset }
                let innerR = maxR * 0.30
                let outerR = maxR * 0.88
                var pts: [(CGPoint, Color)] = []
                for bead in notes {
                    let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                    let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: innerR, outerRadius: outerR)
                    let ang = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: bead.rawOnset, totalDuration: total) + rot
                    let pt = CGPoint(x: c.x + CGFloat(cos(ang)) * r, y: c.y + CGFloat(sin(ang)) * r)
                    let col = XylophoneLane.lane(at: laneIdx).barColor(isNight: isNight)
                    pts.append((pt, col))
                }

                if pts.count > 1 {
                    var p = Path()
                    p.move(to: pts[0].0)
                    for i in 1..<pts.count { p.addLine(to: pts[i].0) }
                    ctx.stroke(p, with: .color(Color.gray.opacity(0.28)), lineWidth: 1.0)
                }

                for (pt, col) in pts {
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.6, y: pt.y - 2.6, width: 5.2, height: 5.2)), with: .color(col))
                }

                // 暖金圆心
                let hubR = maxR * 0.22
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2)),
                    with: .color(Color(hex: 0xE5A93B).opacity(0.85))
                )
            }
        }
    }
}
