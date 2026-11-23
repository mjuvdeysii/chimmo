import SwiftUI

/// 咩哞 v0.6 Tab 2：「音乐盒」—— 我的脑放打孔纸带（胶带明信片）+ 28 首公版/原创名曲打孔卡（一键塞进木琴画板「亮灯跟弹」或自由改写）
public struct MusicBoxShelfView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onLoadSavedToBoard: (SavedMelodyEntry) -> Void
    public let onPlayAlongSpecimen: (MelodyDocument) -> Void
    public let onEditSpecimenOnBoard: (MelodyDocument) -> Void
    public let onStartNewTap: () -> Void

    @State private var selectedSegment: Int = 0 // 0 = 我的纸带, 1 = 28 首名曲卡
    @State private var selectedCategory: String = "全部"
    @State private var playingEntryID: UUID? = nil
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
                    Picker("音乐盒", selection: $selectedSegment) {
                        Text("我的纸带 (\(notebook.entries.count))").tag(0)
                        Text("28 首名曲卡").tag(1)
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
                        VStack(spacing: 16) {
                            if selectedSegment == 0 {
                                myPaperRollsSection
                            } else {
                                masterpieceCardsSection
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("音乐盒")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stopInlinePlay() }
        }
    }

    // MARK: - 1. My Saved Taped Paper Rolls

    @ViewBuilder
    private var myPaperRollsSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 14) {
                ChimmoFigureView(
                    member: .taono,
                    isNight: palette.isNight,
                    isMinor: false,
                    isSinging: false,
                    time: 0,
                    listeningTilt: 0
                )
                .frame(width: 60, height: 60)

                Text("第一张脑放打孔纸带正等着你")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)

                Text("去木琴画板敲下脑海里的节奏、选座山坡或用左侧木琴条调出旋律，点右上角书签就会贴着纸胶带收进这里。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .multilineTextAlignment(.center)

                Button {
                    onStartNewTap()
                } label: {
                    Label("去木琴画板敲一段节奏", systemImage: "hand.tap.fill")
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
                tapedRollCard(entry: entry, index: idx)
            }

            Text("所有打孔纸带 100% 安静保存在本机，永不上传")
                .font(.caption2)
                .foregroundStyle(palette.secondaryInk)
                .padding(.top, 4)
        }
    }

    private func tapedRollCard(entry: SavedMelodyEntry, index: Int) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let tilt: Double = (index % 2 == 0) ? -0.8 : 0.8
        let dateStr = entry.updatedAt.formatted(date: .abbreviated, time: .shortened)

        return ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(entry.moodSticker ?? "🎵 彩虹木琴")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(palette.shelfSurface))
                                .foregroundStyle(palette.primaryInk)
                            Text(dateStr)
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryInk)
                        }
                        Text(entry.document.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    Spacer()
                    Text("\(entry.document.notes.count) 拍")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.homeAnchor)
                }

                RainbowPunchPreview(document: entry.document, isNight: palette.isNight, bg: palette.shelfSurface)
                    .frame(height: 52)

                HStack(spacing: 8) {
                    Button {
                        if isPlayingThis { stopInlinePlay() } else { playInline(entry) }
                    } label: {
                        Label(isPlayingThis ? "停一下" : "纸上听", systemImage: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopInlinePlay()
                        onLoadSavedToBoard(entry)
                    } label: {
                        Label("放回木琴板改", systemImage: "pianokeys")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.25 : 0.06), radius: 10, y: 4)
            )
            .rotationEffect(.degrees(tilt))

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(palette.nightLampGold.opacity(palette.isNight ? 0.36 : 0.28))
                .frame(width: 54, height: 14)
                .rotationEffect(.degrees(-tilt * 2.0))
                .offset(y: -5)
        }
        .padding(.top, 5)
    }

    private func playInline(_ entry: SavedMelodyEntry) {
        stopInlinePlay()
        playingEntryID = entry.id
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
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            if !Task.isCancelled { playingEntryID = nil }
        }
    }

    private func stopInlinePlay() {
        inlinePlayTask?.cancel()
        inlinePlayTask = nil
        playingEntryID = nil
    }

    // MARK: - 2. 28 Masterpiece Punch Cards (Follow-the-Glow or Remix on Xylophone Board)

    private var masterpieceCardsSection: some View {
        ForEach(filteredSpecimens) { spec in
            let voice = spec.preferredVoice ?? .concertPiano
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(spec.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Text(voice.label)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(palette.shelfSurface))
                                .foregroundStyle(palette.secondaryInk)
                        }
                        Text(spec.subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    Spacer()
                    if spec.id == currentDocumentID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.homeAnchor)
                    }
                }

                RainbowPunchPreview(document: spec, isNight: palette.isNight, bg: palette.shelfSurface)
                    .frame(height: 40)

                if let insight = spec.composerInsight {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(palette.primaryInk.opacity(0.86))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button {
                        stopInlinePlay()
                        onPlayAlongSpecimen(spec)
                    } label: {
                        Label("亮灯跟弹", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopInlinePlay()
                        onEditSpecimenOnBoard(spec)
                    } label: {
                        Label("放上画板改写", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.04), radius: 8, y: 3)
            )
        }
    }
}

private struct RainbowPunchPreview: View {
    let document: MelodyDocument
    let isNight: Bool
    let bg: Color

    var body: some View {
        Canvas { ctx, size in
            let notes = document.notes.sorted { $0.rawOnset < $1.rawOnset }
            guard !notes.isEmpty else { return }
            let total = max(2.2, document.totalDuration)
            let padX: CGFloat = 10
            let usableW = max(20, size.width - padX * 2)

            var pts: [(CGPoint, Color)] = []
            for bead in notes {
                let x = padX + CGFloat(bead.rawOnset / total) * usableW
                let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
                let y = size.height - 6 - (CGFloat(laneIdx) / 7.0) * (size.height - 12)
                let col = XylophoneLane.lane(at: laneIdx).barColor(isNight: isNight)
                pts.append((CGPoint(x: x, y: y), col))
            }

            if pts.count > 1 {
                var p = Path()
                p.move(to: pts[0].0)
                for i in 1..<pts.count {
                    p.addLine(to: pts[i].0)
                }
                ctx.stroke(p, with: .color(Color.gray.opacity(0.28)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }

            for (pt, col) in pts {
                let rect = CGRect(x: pt.x - 4.5, y: pt.y - 3.2, width: 9.0, height: 6.4)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3.2), with: .color(col))
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg.opacity(0.75)))
    }
}
