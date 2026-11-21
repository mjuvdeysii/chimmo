import SwiftUI

/// 「乐思本 & 名曲透视库」：
/// 1. 保存并回看自己轻哼或点绘出来的「脑放旋律卡片」（带彩色旋律缩略波形与乐理标签）；
/// 2. 随时打开 16 首版权自洁的经典与现代名曲，在「和弦光带 + 音程透视镜」下看懂编曲家思路。
public struct NotebookAndLibraryView: View {
    public let palette: ChimmoPalette
    @ObservedObject public var notebook: MelodyNotebookStore
    public let currentDocumentID: UUID
    public let onOpenSavedEntry: (SavedMelodyEntry) -> Void
    public let onOpenSpecimen: (MelodyDocument) -> Void
    public let onStartNewMelody: () -> Void

    @State private var selectedSegment: Int = 0 // 0 = 我的乐思本, 1 = 名曲透视库 (16 首)

    public init(
        palette: ChimmoPalette,
        notebook: MelodyNotebookStore,
        currentDocumentID: UUID,
        onOpenSavedEntry: @escaping (SavedMelodyEntry) -> Void,
        onOpenSpecimen: @escaping (MelodyDocument) -> Void,
        onStartNewMelody: @escaping () -> Void
    ) {
        self.palette = palette
        self.notebook = notebook
        self.currentDocumentID = currentDocumentID
        self.onOpenSavedEntry = onOpenSavedEntry
        self.onOpenSpecimen = onOpenSpecimen
        self.onStartNewMelody = onStartNewMelody
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图", selection: $selectedSegment) {
                    Text("我的脑放记录 (\(notebook.entries.count))").tag(0)
                    Text("名曲透视库 (16)").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

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
                Text("在「创作」页轻轻哼出一段旋律、或在画布上点绘出音珠后，点右上角「存入乐思本」，它就会变成一张专属声学卡片保存在本机。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .multilineTextAlignment(.center)
                Button {
                    onStartNewMelody()
                } label: {
                    Label("去记录第一段脑放", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(palette.melodyTerracotta))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.shelfSurface))
        } else {
            ForEach(notebook.entries) { entry in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.document.title)
                                .font(.headline)
                                .foregroundStyle(palette.primaryInk)
                            Text("\(entry.document.scaleMode.label) · \(entry.document.notes.count) 颗音珠 · \(entry.chordPreset.label)")
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

                    // 迷你彩色旋律轮廓缩略图
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
                        Label("在工作台打开编辑与试听", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface))
            }
        }
    }

    // MARK: - 16 Curated Specimens

    private var specimenLibrarySection: some View {
        ForEach(SpecimenLibrary.all) { spec in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(spec.title)
                                .font(.headline)
                                .foregroundStyle(palette.primaryInk)
                            if let cat = spec.specimenCategory {
                                Text(cat)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(palette.homeAnchor.opacity(0.14)))
                                    .foregroundStyle(palette.homeAnchor)
                            }
                        }
                        Text(spec.subtitle)
                            .font(.caption)
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

                Button {
                    onOpenSpecimen(spec)
                } label: {
                    Label("打开和弦光带透视", systemImage: "eye.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface))
        }
    }
}

/// 迷你彩色旋律轮廓缩略图：让每首保存的脑放和名曲都有独一无二的「视觉签名」。
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
                ctx.stroke(path, with: .color(palette.homeAnchor.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }

            for (pt, col) in pts {
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3.5, y: pt.y - 3.5, width: 7, height: 7)), with: .color(col))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.paper.opacity(0.65)))
    }
}
