import QuartzCore
import SwiftUI

/// 咩哞 v0.10 Tab 2：「唱片馆」—— 我的旋转脑放唱片 + 28 首公版/原创名曲黑胶馆（支持跟弹、放上声盘、借天光与黑胶明信片分享）
public struct MusicBoxShelfView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onLoadSavedToBoard: (SavedMelodyEntry) -> Void
    public let onPlayAlongSpecimen: (MelodyDocument) -> Void
    public let onEditSpecimenOnBoard: (MelodyDocument) -> Void
    public let onBorrowAtmosphere: (MelodyDocument) -> Void
    public let onShareSavedEntry: (SavedMelodyEntry) -> Void
    public let onStartNewTap: () -> Void
    public let onWillPlayInline: () -> Void

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
        onBorrowAtmosphere: @escaping (MelodyDocument) -> Void = { _ in },
        onShareSavedEntry: @escaping (SavedMelodyEntry) -> Void = { _ in },
        onStartNewTap: @escaping () -> Void,
        onWillPlayInline: @escaping () -> Void = {}
    ) {
        self.palette = palette
        self.synth = synth
        self.notebook = notebook
        self.currentDocumentID = currentDocumentID
        self.onLoadSavedToBoard = onLoadSavedToBoard
        self.onPlayAlongSpecimen = onPlayAlongSpecimen
        self.onEditSpecimenOnBoard = onEditSpecimenOnBoard
        self.onBorrowAtmosphere = onBorrowAtmosphere
        self.onShareSavedEntry = onShareSavedEntry
        self.onStartNewTap = onStartNewTap
        self.onWillPlayInline = onWillPlayInline
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
                    Picker("曲库", selection: $selectedSegment) {
                        Text("我的作品 (\(notebook.entries.count))").tag(0)
                        Text("经典曲库 (28)").tag(1)
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
            .navigationTitle("曲库")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stopInlinePlay() }
        }
    }

    // MARK: - 1. My Saved Spinning Discs

    @ViewBuilder
    private var mySavedDiscsSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(palette.shelfSurface)
                        .frame(width: 72, height: 72)
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(palette.homeAnchor)
                }

                Text("暂无作品")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)

                Button {
                    onStartNewTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 56, height: 42)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("去写一段")
            }
            .padding(26)
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
        }
    }

    private func savedDiscCard(entry: SavedMelodyEntry, index: Int) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let dateStr = entry.updatedAt.formatted(date: .abbreviated, time: .shortened)

        return HStack(spacing: 14) {
            ZStack {
                MiniOrbitalDiscPreview(
                    document: entry.document,
                    isNight: palette.isNight,
                    isSpinning: isPlayingThis && !reduceMotion,
                    spinStartTime: inlinePlayStart
                )
                .frame(width: 74, height: 74)

                Circle()
                    .fill(palette.cardSurface.opacity(0.88))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.homeAnchor)
                    )
            }
            .onTapGesture {
                if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isPlayingThis ? "停止试听 \(entry.document.title)" : "试听 \(entry.document.title)")
            .accessibilityAction {
                if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.document.scaleMode.skyAuroraColor(isNight: palette.isNight))
                        .frame(width: 7, height: 7)
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
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 28)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlayingThis ? "停止试听" : "试听")

                    Button {
                        stopInlinePlay()
                        onLoadSavedToBoard(entry)
                    } label: {
                        Image(systemName: "record.circle")
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 28)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("在主舞台打开 \(entry.document.title)")

                    Spacer()

                    Button {
                        onShareSavedEntry(entry)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.homeAnchor)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("分享 \(entry.document.title)")

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
        playInlineDocument(
            entry.document,
            id: entry.id,
            chordPreset: entry.chordPreset,
            chordOverrides: entry.chordOverrides,
            texture: entry.accompanimentTexture
        )
    }

    private func playInlineDocument(
        _ doc: MelodyDocument,
        id: UUID,
        chordPreset: ChordProgressionPreset,
        chordOverrides: [Int: DiatonicChord],
        texture: AccompanimentTexture?
    ) {
        stopInlinePlay()
        onWillPlayInline()
        synth.ensureRunning()
        playingEntryID = id
        inlinePlayStart = CACurrentMediaTime()
        let spans = TheoryLensEngine.buildChordSpans(document: doc, preset: chordPreset, overrides: chordOverrides)
        let tex = texture ?? doc.preferredTexture ?? .swanRipple
        let voice = FeltPianoSynth.Timbre.from(voice: doc.preferredVoice ?? .singingCello)

        inlinePlayTask = Task { @MainActor in
            let sorted = doc.notes.sorted { $0.rawOnset < $1.rawOnset }
            let start = Date()
            var nextIdx = 0
            var lastSpan = -1
            let total = doc.totalDuration

            while !Task.isCancelled && playingEntryID == id {
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
            if !Task.isCancelled && playingEntryID == id {
                playingEntryID = nil
            }
        }
    }

    private func stopInlinePlay() {
        inlinePlayTask?.cancel()
        inlinePlayTask = nil
        playingEntryID = nil
    }

    // MARK: - 2. 28 Playable Masterpiece Vinyl Cards (Zero Essay Clutter)

    private var masterpieceDiscsSection: some View {
        ForEach(filteredSpecimens) { spec in
            let voice = spec.preferredVoice ?? .concertPiano
            let isPlayingThis = playingEntryID == spec.id
            let modeColor = spec.scaleMode.skyAuroraColor(isNight: palette.isNight)

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    MiniOrbitalDiscPreview(
                        document: spec,
                        isNight: palette.isNight,
                        isSpinning: isPlayingThis && !reduceMotion,
                        spinStartTime: inlinePlayStart
                    )
                    .frame(width: 72, height: 72)

                    Circle()
                        .fill(palette.cardSurface.opacity(0.88))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isPlayingThis ? palette.nightLampGold : palette.homeAnchor)
                        )
                }
                .onTapGesture {
                    if isPlayingThis {
                        stopInlinePlay()
                    } else {
                        playInlineDocument(
                            spec,
                            id: spec.id,
                            chordPreset: .autoMatch,
                            chordOverrides: [:],
                            texture: spec.preferredTexture
                        )
                    }
                }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isPlayingThis ? "停止试听 \(spec.title)" : "试听 \(spec.title)")
                .accessibilityAction {
                    if isPlayingThis {
                        stopInlinePlay()
                    } else {
                        playInlineDocument(
                            spec,
                            id: spec.id,
                            chordPreset: .autoMatch,
                            chordOverrides: [:],
                            texture: spec.preferredTexture
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
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

                    HStack(spacing: 8) {
                        Button {
                            if isPlayingThis {
                                stopInlinePlay()
                            } else {
                                playInlineDocument(
                                    spec,
                                    id: spec.id,
                                    chordPreset: .autoMatch,
                                    chordOverrides: [:],
                                    texture: spec.preferredTexture
                                )
                            }
                        } label: {
                            Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                .font(.caption.weight(.bold))
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(isPlayingThis ? palette.nightLampGold : palette.homeAnchor))
                                .foregroundStyle((isPlayingThis || palette.isNight) ? Color(hex: 0x1B2245) : .white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPlayingThis ? "停止试听" : "试听 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onPlayAlongSpecimen(spec)
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(palette.nightLampGold.opacity(0.18)))
                                .foregroundStyle(palette.nightLampGold)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("跟灯弹 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onEditSpecimenOnBoard(spec)
                        } label: {
                            Image(systemName: "record.circle")
                                .font(.caption.weight(.bold))
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(palette.shelfSurface))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("在主舞台打开 \(spec.title)")

                        Button {
                            stopInlinePlay()
                            onBorrowAtmosphere(spec)
                        } label: {
                            ChimmoCraftMark(.atmosphereHorizon, color: modeColor)
                                .frame(width: 13, height: 13)
                                .frame(width: 34, height: 28)
                                .background(Capsule().fill(modeColor.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("套用 \(spec.title) 风格")
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
