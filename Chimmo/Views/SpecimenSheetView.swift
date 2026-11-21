import SwiftUI

/// 可拆解编曲标本抽屉：支持打开整首赏析，或把它的现代水面和声色温一键借给自己的脑放旋律。
public struct SpecimenSheetView: View {
    public let palette: ChimmoPalette
    public let currentSpecimenID: UUID
    public let onSelectSpecimen: (MelodyDocument) -> Void
    public let onBorrowHarmony: (HarmonyProfile, ScaleMode) -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        palette: ChimmoPalette,
        currentSpecimenID: UUID,
        onSelectSpecimen: @escaping (MelodyDocument) -> Void,
        onBorrowHarmony: @escaping (HarmonyProfile, ScaleMode) -> Void
    ) {
        self.palette = palette
        self.currentSpecimenID = currentSpecimenID
        self.onSelectSpecimen = onSelectSpecimen
        self.onBorrowHarmony = onBorrowHarmony
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("内置标本均为公版原谱自编或原创现代编曲技法骨架，零版权隐患。点开任意一首可拆解独奏，或借走它的水面和声。")
                        .font(.footnote)
                        .foregroundStyle(palette.secondaryInk)
                        .padding(.horizontal, 4)

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
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(palette.homeAnchor.opacity(0.14)))
                                                .foregroundStyle(palette.homeAnchor)
                                        }
                                    }
                                    Text(spec.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryInk)
                                }
                                Spacer()
                                if spec.id == currentSpecimenID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(palette.homeAnchor)
                                }
                            }

                            if let insight = spec.composerInsight {
                                Text(insight)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.primaryInk.opacity(0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 10) {
                                Button("打开赏析") {
                                    onSelectSpecimen(spec)
                                    dismiss()
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)

                                Button("借用和声色温") {
                                    onBorrowHarmony(spec.harmonyProfile, spec.scaleMode)
                                    dismiss()
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().strokeBorder(palette.divider, lineWidth: 1))
                                .foregroundStyle(palette.primaryInk)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.shelfSurface)
                        )
                    }
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("编曲标本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
