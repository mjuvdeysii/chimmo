import SwiftUI

/// 继承《摸索台灯》成长册温度的「胶带明信片脑放手账册」+「28 首公版名曲藏书架」：
/// 每段记下来的脑放都是一张贴着半透明胶带、微微倾斜的纸上明信片，带着心情贴纸、旋律山水线与利萨如共振小印章，点一下就能直接在纸面上唱给你听。
public struct SoundPostcardBookView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onOpenSavedInWorkbench: (SavedMelodyEntry) -> Void
    public let onOpenPeelerForSpecimen: (MelodyDocument) -> Void
    public let onOpenSpecimenInWorkbench: (MelodyDocument) -> Void
    public let onStartNewCapture: () -> Void

    @State private var selectedSegment: Int = 0 // 0 = 我的胶带手账册, 1 = 28 首名曲藏书架
    @State private var selectedCategory: String = "全部"
    @State private var playingEntryID: UUID? = nil
    @State private var inlinePlayTask: Task<Void, Never>? = nil

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        notebook: MelodyNotebookStore,
        currentDocumentID: UUID,
        onOpenSavedInWorkbench: @escaping (SavedMelodyEntry) -> Void,
        onOpenPeelerForSpecimen: @escaping (MelodyDocument) -> Void,
        onOpenSpecimenInWorkbench: @escaping (MelodyDocument) -> Void,
        onStartNewCapture: @escaping () -> Void
    ) {
        self.palette = palette
        self.synth = synth
        self.notebook = notebook
        self.currentDocumentID = currentDocumentID
        self.onOpenSavedInWorkbench = onOpenSavedInWorkbench
        self.onOpenPeelerForSpecimen = onOpenPeelerForSpecimen
        self.onOpenSpecimenInWorkbench = onOpenSpecimenInWorkbench
        self.onStartNewCapture = onStartNewCapture
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
                    Picker("书页", selection: $selectedSegment) {
                        Text("脑放手账 (\(notebook.entries.count))").tag(0)
                        Text("名曲藏书 (\(SpecimenLibrary.all.count))").tag(1)
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
                        VStack(spacing: 18) {
                            if selectedSegment == 0 {
                                postcardJournalSection
                            } else {
                                masterpieceShelfSection
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("手账册与名曲")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stopInlinePlay() }
        }
    }

    // MARK: - 1. Taped Sound Postcards (《摸索台灯》成长册美学)

    @ViewBuilder
    private var postcardJournalSection: some View {
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
                .frame(width: 64, height: 64)

                Text("第一张声音明信片正等着你")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                Text("无论是在「剥洋葱」里改写的一段《天鹅》变奏、睡前「闭眼夜灯」摸出的几颗音，还是随时轻哼的脑放，都会贴着胶带收进这本手账里。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .multilineTextAlignment(.center)

                Button {
                    onStartNewCapture()
                } label: {
                    Label("去记下第一段脑放", systemImage: "waveform")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
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
                tapedPostcard(entry: entry, index: idx)
            }

            Text("故事仍在继续 · 所有旋律仅安静保存在本机")
                .font(.caption2)
                .foregroundStyle(palette.secondaryInk)
                .padding(.top, 4)
        }
    }

    private func tapedPostcard(entry: SavedMelodyEntry, index: Int) -> some View {
        let isPlayingThis = playingEntryID == entry.id
        let tex = entry.accompanimentTexture ?? .swanRipple
        let tilt: Double = (index % 2 == 0) ? -0.9 : 0.9
        let dateStr = entry.updatedAt.formatted(date: .abbreviated, time: .shortened)

        return ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(entry.moodSticker ?? "🦢 湖畔微风")
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

                    // 右上角迷你利萨如声学印章
                    LissajousWaveView(
                        ratioA: 3,
                        ratioB: 2,
                        consonance: 0.95,
                        accentColor: palette.homeAnchor,
                        isNight: palette.isNight,
                        compact: true
                    )
                    .frame(width: 34, height: 34)
                }

                // 纸上旋律山水画
                PostcardContourArt(document: entry.document, palette: palette)
                    .frame(height: 54)

                if !entry.summaryNote.isEmpty {
                    Text(entry.summaryNote)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button {
                        if isPlayingThis {
                            stopInlinePlay()
                        } else {
                            playPostcardInline(entry)
                        }
                    } label: {
                        Label(isPlayingThis ? "停一下" : "在纸上听", systemImage: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }

                    Button {
                        stopInlinePlay()
                        onOpenSavedInWorkbench(entry)
                    } label: {
                        Label("展开工作台", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }

                    Spacer()

                    Text(tex.label)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)

                    Button(role: .destructive) {
                        if isPlayingThis { stopInlinePlay() }
                        notebook.delete(id: entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                            .padding(6)
                    }
                    .accessibilityLabel("删除 \(entry.document.title)")
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.28 : 0.07), radius: 10, y: 4)
            )
            .rotationEffect(.degrees(tilt))

            // 顶部半透明纸胶带（复刻《摸索台灯》成长册照片胶带手感！）
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(palette.nightLampGold.opacity(palette.isNight ? 0.36 : 0.28))
                .frame(width: 56, height: 15)
                .rotationEffect(.degrees(-tilt * 2.2))
                .offset(y: -6)
        }
        .padding(.top, 6)
    }

    private func playPostcardInline(_ entry: SavedMelodyEntry) {
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

    // MARK: - 2. 28 Copyright-Clean Masterpieces Shelf

    private var masterpieceShelfSection: some View {
        ForEach(filteredSpecimens) { spec in
            let tex = spec.preferredTexture ?? .swanRipple
            let voice = spec.preferredVoice ?? .concertPiano

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(spec.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Text("\(voice.label) · \(tex.label)")
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

                PostcardContourArt(document: spec, palette: palette)
                    .frame(height: 38)

                if let insight = spec.composerInsight {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(palette.primaryInk.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button {
                        stopInlinePlay()
                        onOpenPeelerForSpecimen(spec)
                    } label: {
                        Label("剥洋葱倒拆玩", systemImage: "square.stack.3d.up.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }

                    Button {
                        stopInlinePlay()
                        onOpenSpecimenInWorkbench(spec)
                    } label: {
                        Label("工作台透视", systemImage: "eye.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.shelfSurface))
                            .foregroundStyle(palette.primaryInk)
                    }
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

private struct PostcardContourArt: View {
    let document: MelodyDocument
    let palette: ChimmoPalette

    var body: some View {
        Canvas { ctx, size in
            let notes = document.notes.sorted {
                $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
            }
            guard !notes.isEmpty else { return }
            let total = max(2.0, document.totalDuration)
            let padX: CGFloat = 10
            let usableW = max(20, size.width - padX * 2)

            var pts: [(CGPoint, Color)] = []
            for bead in notes {
                let x = padX + CGFloat(bead.displayOnset(grooveStrength: document.grooveStrength) / total) * usableW
                let normY = ScalePitchGeometry.normalizedY(degree: bead.degree, octaveOffset: bead.octaveOffset, mode: document.scaleMode)
                let y = size.height - 7 - normY * (size.height - 14)
                let col = palette.isNight ? bead.member.nightGlowColor : bead.member.bodyColor
                pts.append((CGPoint(x: x, y: y), col))
            }

            if pts.count > 1 {
                var path = Path()
                path.move(to: pts[0].0)
                for i in 1..<pts.count {
                    let p0 = pts[i - 1].0
                    let p1 = pts[i].0
                    path.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) * 0.5, y: min(p0.y, p1.y) - 6))
                }
                ctx.stroke(path, with: .color(palette.homeAnchor.opacity(0.45)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }

            for (pt, col) in pts {
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3.6, y: pt.y - 3.6, width: 7.2, height: 7.2)), with: .color(col))
            }
        }
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(palette.shelfSurface.opacity(0.75)))
    }
}
