import SwiftUI

/// 「乐思本 & 28 首公版名曲透视库」：
/// 1. 本机离线保存并回看自己轻哼或点绘出来的「脑放旋律卡片」；
/// 2. 按作曲家与风格分类浏览 20 首全球公有领域古典名曲（圣桑《天鹅》、李斯特、巴赫、柴可夫斯基、德彪西、肖邦、德沃夏克、萨蒂、贝多芬、舒伯特等）+ 8 首原创夏日治愈风技法示范。
public struct NotebookAndLibraryView: View {
    public let palette: ChimmoPalette
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onOpenSavedEntry: (SavedMelodyEntry) -> Void
    public let onOpenSpecimen: (MelodyDocument) -> Void
    public let onBorrowStyleToCreate: (AccompanimentTexture, ScaleMode) -> Void
    public let onStartNewMelody: () -> Void

    @State private var selectedSegment: Int = 1 // 默认直接展示精彩名曲库，或一键切到我的脑放记录
    @State private var selectedCategory: String = "全部"

    public init(
        palette: ChimmoPalette,
        notebook: MelodyNotebookStore,
        currentDocumentID: UUID,
        onOpenSavedEntry: @escaping (SavedMelodyEntry) -> Void,
        onOpenSpecimen: @escaping (MelodyDocument) -> Void,
        onBorrowStyleToCreate: @escaping (AccompanimentTexture, ScaleMode) -> Void,
        onStartNewMelody: @escaping () -> Void
    ) {
        self.palette = palette
        self.notebook = notebook
        self.currentDocumentID = currentDocumentID
        self.onOpenSavedEntry = onOpenSavedEntry
        self.onOpenSpecimen = onOpenSpecimen
        self.onBorrowStyleToCreate = onBorrowStyleToCreate
        self.onStartNewMelody = onStartNewMelody
    }

    private var filteredSpecimens: [MelodyDocument] {
        if selectedCategory == "全部" {
            return SpecimenLibrary.all
        }
        return SpecimenLibrary.all.filter { $0.specimenCategory == selectedCategory }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图", selection: $selectedSegment) {
                    Text("我的脑放 (\(notebook.entries.count))").tag(0)
                    Text("名曲透视库 (\(SpecimenLibrary.all.count))").tag(1)
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
                                        .background(
                                            Capsule().fill(active ? palette.homeAnchor : palette.cardSurface)
                                        )
                                        .foregroundStyle(active ? (palette.isNight ? Color(hex: 0x0E1726) : .white) : palette.primaryInk)
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
                            savedEntriesSection
                        } else {
                            specimenLibrarySection
                        }
                    }
                    .padding(16)
                }
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("乐思本与名曲")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Saved User Melodies

    @ViewBuilder
    private var savedEntriesSection: some View {
        if notebook.entries.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "music.quarternote.3")
                    .font(.largeTitle)
                    .foregroundStyle(palette.homeAnchor)
                Text("还没有存下的脑放旋律")
                    .font(.headline)
                    .foregroundStyle(palette.primaryInk)
                Text("在「创作」页轻轻哼出一段旋律、或在画布上点绘出音珠后，点右上角书签即可把它连同和弦与织体一起保存在本机。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .multilineTextAlignment(.center)
                Button {
                    onStartNewMelody()
                } label: {
                    Label("去记录第一段脑放", systemImage: "waveform")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(palette.melodyTerracotta))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.cardSurface))
        } else {
            ForEach(notebook.entries) { entry in
                let tex = entry.accompanimentTexture ?? .swanRipple
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.document.title)
                                .font(.headline)
                                .foregroundStyle(palette.primaryInk)
                            Text("\(entry.document.scaleMode.label) · \(entry.document.notes.count) 颗音珠 · \(tex.label)")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            notebook.delete(id: entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                                .padding(8)
                        }
                        .accessibilityLabel("删除 \(entry.document.title)")
                    }

                    MiniContourThumbnail(document: entry.document, palette: palette)
                        .frame(height: 44)

                    if !entry.summaryNote.isEmpty {
                        Text(entry.summaryNote)
                            .font(.caption)
                            .foregroundStyle(palette.primaryInk.opacity(0.85))
                            .lineLimit(2)
                    }

                    Button {
                        onOpenSavedEntry(entry)
                    } label: {
                        Label("打开继续编辑与试听", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
            }
        }
    }

    // MARK: - 28 Curated Public-Domain & Original Pieces

    private var specimenLibrarySection: some View {
        ForEach(filteredSpecimens) { spec in
            let tex = spec.preferredTexture ?? .swanRipple
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(spec.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Label(tex.label, systemImage: tex.iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(palette.bassRibbon.opacity(0.14)))
                                .foregroundStyle(palette.bassRibbon)
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

                MiniContourThumbnail(document: spec, palette: palette)
                    .frame(height: 36)

                if let insight = spec.composerInsight {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(palette.primaryInk.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button {
                        onOpenSpecimen(spec)
                    } label: {
                        Label("打开透视导赏", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                    }

                    Button {
                        onBorrowStyleToCreate(tex, spec.scaleMode)
                    } label: {
                        Label("用「\(tex.label)」去创作", systemImage: "wand.and.stars")
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(palette.divider, lineWidth: 1)
                    )
            )
        }
    }
}

private struct MiniContourThumbnail: View {
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
                let y = size.height - 6 - normY * (size.height - 12)
                let col = palette.isNight ? bead.member.nightGlowColor : bead.member.bodyColor
                pts.append((CGPoint(x: x, y: y), col))
            }

            if pts.count > 1 {
                var path = Path()
                path.move(to: pts[0].0)
                for i in 1..<pts.count {
                    path.addLine(to: pts[i].0)
                }
                ctx.stroke(path, with: .color(palette.bassRibbon.opacity(0.42)), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }

            for (pt, col) in pts {
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3.5, y: pt.y - 3.5, width: 7, height: 7)), with: .color(col))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.shelfSurface.opacity(0.75)))
    }
}
