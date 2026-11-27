import SwiftUI

/// Sound Library Tab (Tab 2):
/// Live circadian greeting, 12 acoustic scene tiles, 8 single-tap frisson capsules,
/// and direct NavigationLink into the 28-specimen offline archive (single NavigationStack).
public struct AcousticLibraryView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette

    @State private var searchText: String = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var currentHour: Int = Calendar.current.component(.hour, from: Date())
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase

    public enum LibraryFilter: String, CaseIterable, Identifiable {
        case all
        case favorites
        case morning
        case afternoon
        case evening
        case midnight

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .all: return String(localized: "lib_filter_all", defaultValue: "全部场景")
            case .favorites: return String(localized: "lib_filter_fav", defaultValue: "已收藏")
            case .morning: return String(localized: "lib_filter_morning", defaultValue: "晨间")
            case .afternoon: return String(localized: "lib_filter_afternoon", defaultValue: "午后")
            case .evening: return String(localized: "lib_filter_evening", defaultValue: "傍晚")
            case .midnight: return String(localized: "lib_filter_midnight", defaultValue: "深夜")
            }
        }
    }

    public init(vm: ResonanceViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    private var filteredPresets: [ResonancePreset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ResonancePreset.all.filter { preset in
            switch selectedFilter {
            case .all: break
            case .favorites:
                if !vm.stats.isFavorite(preset.id) { return false }
            case .morning:
                if preset.hourWindow != .morning { return false }
            case .afternoon:
                if preset.hourWindow != .afternoon { return false }
            case .evening:
                if preset.hourWindow != .evening { return false }
            case .midnight:
                if preset.hourWindow != .midnight { return false }
            }
            if !query.isEmpty {
                return preset.title.localizedCaseInsensitiveContains(query)
                    || preset.subtitle.localizedCaseInsensitiveContains(query)
                    || preset.band.title.localizedCaseInsensitiveContains(query)
                    || preset.band.chineseSubtitle.localizedCaseInsensitiveContains(query)
            }
            return true
        }
    }

    private var filteredCapsules: [FrissonCapsule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return FrissonCapsule.all.filter { cap in
            if query.isEmpty { return true }
            return cap.title.localizedCaseInsensitiveContains(query)
                || cap.subtitle.localizedCaseInsensitiveContains(query)
                || cap.frissonNote.localizedCaseInsensitiveContains(query)
                || cap.badgeTag.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        let accent = vm.selectedBand.accentColor(isNight: palette.isNight)

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette, tint: accent)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        circadianBanner(accent: accent)

                        filterStrip(accent: accent)

                        presetsSection(accent: accent)

                        frissonCapsulesSection(accent: accent)

                        archiveEntryCard(accent: accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(String(localized: "tab_library", defaultValue: "声库"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String(localized: "lib_search_prompt", defaultValue: "搜索白昼声场或室内乐胶囊")
            )
            .onAppear {
                currentHour = Calendar.current.component(.hour, from: Date())
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    currentHour = Calendar.current.component(.hour, from: Date())
                }
            }
        }
    }

    private func circadianBanner(accent: Color) -> some View {
        let banner = ResonanceKinematics.timeOfDayBanner(forHour: currentHour)
        let recommended = ResonanceKinematics.recommendedPresets(forHour: currentHour).first

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ChimmoDuoBadgeView(
                    isNight: palette.isNight,
                    accentColor: accent,
                    melodyActive: vm.isResonancePlaying || vm.isSpecimenPlaying,
                    cowAwake: vm.isResonancePlaying
                )
                .frame(width: 48, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(banner.subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let recommended {
                let active = (vm.activePreset?.id == recommended.id && vm.isResonancePlaying)
                Button {
                    if active {
                        vm.pauseResonancePlayback()
                    } else {
                        vm.startPreset(recommended)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: active ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                        Text(active
                             ? String(format: String(localized: "lib_playing_preset_fmt", defaultValue: "正在聆听：%@"), recommended.title)
                             : String(format: String(localized: "lib_quick_start_fmt", defaultValue: "一键开启此刻建议：%@"), recommended.title))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .lineLimit(type.isAccessibilitySize ? 3 : 2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.chimmoVinyl(palette: palette, tint: recommended.band.accentColor(isNight: palette.isNight), prominent: active))
                .accessibilityValue(active ? String(localized: "state_playing", defaultValue: "正在播放") : "")
            }
        }
        .padding(16)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: accent)
    }

    private func filterStrip(accent: Color) -> some View {
        ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
            ForEach(LibraryFilter.allCases) { item in
                let selected = (selectedFilter == item)
                Button {
                    selectedFilter = item
                } label: {
                    Text(item.label)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                }
                .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: selected))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func presetsSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: String(localized: "lib_section_presets", defaultValue: "时间声景配方"),
                detail: String(format: String(localized: "lib_count_fmt", defaultValue: "%lld 组"), filteredPresets.count),
                isNight: palette.isNight,
                tint: accent
            )

            if filteredPresets.isEmpty {
                Text(selectedFilter == .favorites
                     ? String(localized: "lib_empty_favorites", defaultValue: "轻点任意声景卡片右上角的心形图标，即可收集常听配方。")
                     : String(localized: "lib_empty_search", defaultValue: "没有匹配该关键词的声景"))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
            } else {
                let columns = type >= .xxLarge
                    ? [GridItem(.flexible())]
                    : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredPresets) { preset in
                        presetTile(preset)
                    }
                }
            }
        }
    }

    private func presetTile(_ preset: ResonancePreset) -> some View {
        let cardAccent = preset.band.accentColor(isNight: palette.isNight)
        let active = (vm.activePreset?.id == preset.id && vm.isResonancePlaying)
        let fav = vm.stats.isFavorite(preset.id)

        return ZStack(alignment: .topTrailing) {
            Button {
                if active {
                    vm.pauseResonancePlayback()
                } else {
                    vm.startPreset(preset)
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cardAccent)
                            .frame(width: 9, height: 9)
                        Text(preset.band.title)
                            .font(.system(.caption2, design: .rounded).weight(.heavy))
                            .foregroundStyle(cardAccent)
                        Spacer(minLength: 36)
                    }
                    .frame(minHeight: 30)

                    Text(preset.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(type.isAccessibilitySize ? 3 : 2)
                        .multilineTextAlignment(.leading)

                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(type.isAccessibilitySize ? 4 : 2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    HStack {
                        Text(String(format: String(localized: "lib_mins_hint_fmt", defaultValue: "建议 %lld 分钟"), preset.durationHintMinutes))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(palette.secondaryInk)
                        Spacer()
                        Image(systemName: active ? "pause.circle.fill" : "play.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(active ? cardAccent : palette.secondaryInk)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
                .padding(14)
                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: active ? cardAccent : nil)
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel(String(format: String(localized: "vo_pair_fmt", defaultValue: "%@ · %@"), preset.title, preset.subtitle))
            .accessibilityValue(active ? String(localized: "state_playing", defaultValue: "正在播放") : "")

            Button {
                vm.stats.toggleFavoritePreset(preset.id)
                if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
            } label: {
                Image(systemName: fav ? "heart.fill" : "heart")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(fav ? palette.homeAnchor : palette.secondaryInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
            .accessibilityLabel(fav
                                ? String(localized: "lib_unfav_vo", defaultValue: "取消收藏该声景")
                                : String(localized: "lib_fav_vo", defaultValue: "收藏该声景"))
        }
    }

    @ViewBuilder
    private func frissonCapsulesSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: String(localized: "lib_section_capsules", defaultValue: "和声战栗胶囊"),
                detail: String(localized: "lib_capsules_detail", defaultValue: "单点即听 · 离线室内乐"),
                isNight: palette.isNight,
                tint: palette.harmonyWash
            )

            if filteredCapsules.isEmpty {
                Text(String(localized: "lib_empty_capsules", defaultValue: "没有匹配该关键词的室内乐胶囊"))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredCapsules) { cap in
                        let playing = (vm.activeCapsule?.id == cap.id && vm.isSpecimenPlaying)
                        Button {
                            vm.toggleCapsule(cap)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(playing ? accent : palette.insetStageSurface)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: playing ? "pause.fill" : "play.fill")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(playing ? palette.contrastInkOnAccent : accent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    if type >= .xxLarge {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(cap.title)
                                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                                .foregroundStyle(palette.primaryInk)
                                            capsuleBadge(cap.badgeTag, accent: accent)
                                        }
                                    } else {
                                        HStack(spacing: 6) {
                                            Text(cap.title)
                                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                                .foregroundStyle(palette.primaryInk)
                                            capsuleBadge(cap.badgeTag, accent: accent)
                                        }
                                    }
                                    Text(cap.frissonNote)
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryInk)
                                        .lineLimit(type.isAccessibilitySize ? 4 : 2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 4)
                            }
                            .padding(12)
                            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: playing ? accent : nil)
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                        .accessibilityLabel(String(format: String(localized: "vo_pair_fmt", defaultValue: "%@ · %@"), cap.title, cap.frissonNote))
                        .accessibilityValue(playing ? String(localized: "state_playing", defaultValue: "正在播放") : "")
                    }
                }
            }
        }
    }

    private func capsuleBadge(_ text: String, accent: Color) -> some View {
        let increased = (contrast == .increased)
        let strokeAlpha = increased ? 0.85 : (reduceTransparency ? 0.65 : 0.45)
        let strokeW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: false, reduceTransparency: reduceTransparency, increasedContrast: increased)

        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.primaryInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(palette.insetStageSurface)
                    .overlay(Capsule().strokeBorder(accent.opacity(strokeAlpha), lineWidth: strokeW))
            )
    }

    private func archiveEntryCard(accent: Color) -> some View {
        NavigationLink {
            SpecimenArchiveSheet(vm: vm, palette: palette)
        } label: {
            HStack(spacing: 12) {
                ChimmoCraftMark(.soundLibrary, color: accent)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "lib_archive_link_title", defaultValue: "古典公版与原创室乐全集（28 首）"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(String(localized: "lib_archive_link_sub", defaultValue: "按时代浏览、检索并试听全套钢琴、大提琴与竖琴微声学范例"))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
            }
            .padding(16)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: accent)
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
    }
}
