import SwiftUI

/// Single-NavigationStack destination listing all 28 curated public-domain & original specimens.
public struct SpecimenArchiveSheet: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette

    @State private var searchText: String = ""
    @State private var selectedEra: EraFilter = .all
    @Environment(\.dynamicTypeSize) private var type

    public enum EraFilter: String, CaseIterable, Identifiable {
        case all
        case classical
        case romantic
        case original

        public var id: String { rawValue }
    }

    public init(vm: ResonanceViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    private var filteredSpecimens: [MelodyDocument] {
        SpecimenLibrary.all.filter { doc in
            switch selectedEra {
            case .all: break
            case .classical:
                if doc.specimenEra != .classical { return false }
            case .romantic:
                if doc.specimenEra != .romantic { return false }
            case .original:
                if doc.specimenEra != .original { return false }
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                return doc.title.localizedCaseInsensitiveContains(query)
                    || doc.subtitle.localizedCaseInsensitiveContains(query)
                    || (doc.specimenCategory?.localizedCaseInsensitiveContains(query) ?? false)
                    || (doc.composerInsight?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return true
        }
    }

    public var body: some View {
        let accent = vm.selectedBand.accentColor(isNight: palette.isNight)

        ZStack {
            AmbientPaperBackdrop(palette: palette, tint: accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    categoryFilterStrip(accent: accent)

                    if filteredSpecimens.isEmpty {
                        Text(String(localized: "archive_empty_search", defaultValue: "没有匹配该关键词的曲目范例"))
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSpecimens) { doc in
                                specimenCard(doc, accent: accent)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle(String(localized: "archive_nav_title", defaultValue: "古典与原创室乐全集"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: String(localized: "archive_search_prompt", defaultValue: "搜索曲名、作曲家或意象")
        )
    }

    private func categoryFilterStrip(accent: Color) -> some View {
        let categories: [(filter: EraFilter, title: String)] = [
            (.all, String(localized: "filter_all", defaultValue: "全部 28 首")),
            (.classical, String(localized: "archive_cat_classical", defaultValue: "古典公版")),
            (.romantic, String(localized: "archive_cat_romantic", defaultValue: "浪漫印象")),
            (.original, String(localized: "archive_cat_original", defaultValue: "原创舒缓"))
        ]
        return ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
            ForEach(categories, id: \.filter) { cat in
                let active = (selectedEra == cat.filter)
                Button {
                    selectedEra = cat.filter
                } label: {
                    Text(cat.title)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                }
                .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: active))
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
    }

    private func specimenCard(_ doc: MelodyDocument, accent: Color) -> some View {
        let isPlayingThis = (vm.activeSpecimen?.id == doc.id && vm.isSpecimenPlaying)
        let modeColor = doc.scaleMode.skyAuroraColor(isNight: palette.isNight)

        return Button {
            vm.toggleSpecimenPlayback(doc)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(isPlayingThis ? accent : modeColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(type.isAccessibilitySize ? 3 : 2)
                            .multilineTextAlignment(.leading)
                        Text(doc.subtitle)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                            .lineLimit(type.isAccessibilitySize ? 4 : 2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(isPlayingThis ? accent : palette.insetStageSurface)
                            .frame(width: 44, height: 44)
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isPlayingThis ? palette.contrastInkOnAccent : palette.primaryInk)
                    }
                }

                if let insight = doc.composerInsight, !insight.isEmpty {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: isPlayingThis ? accent : nil)
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel(String(format: String(localized: "vo_pair_fmt", defaultValue: "%@ · %@"), doc.title, doc.subtitle))
        .accessibilityValue(isPlayingThis ? String(localized: "state_playing", defaultValue: "正在播放") : "")
        .accessibilityHint(isPlayingThis
                           ? String(localized: "archive_pause_hint", defaultValue: "轻点停止试听")
                           : String(localized: "archive_play_hint", defaultValue: "轻点离线合成播放该室内乐片段"))
    }
}
