import SwiftUI

/// Tab 1 · 声库：咩哞原创窑陶声学资料库（四频段窑陶调音座 / 12 套离线配方 / 闭眼夜灯零光台 / 8 首和声战栗乐章 / 28 首典藏曲本）。
public struct AcousticLibraryView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette
    public let onOpenField: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText: String = ""
    @State private var filter: LibraryFilter = .all
    @State private var showFullSpecimenShelf: Bool = false

    private enum LibraryFilter: String, CaseIterable, Identifiable {
        case all
        case favorites
        case delta
        case theta
        case alpha
        case gamma

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "全部"
            case .favorites: return "已收藏"
            case .delta: return "Delta"
            case .theta: return "Theta"
            case .alpha: return "Alpha"
            case .gamma: return "Gamma"
            }
        }

        var bandFilter: BrainwaveBand? {
            switch self {
            case .delta: return .delta
            case .theta: return .theta
            case .alpha: return .alpha
            case .gamma: return .gamma
            case .all, .favorites: return nil
            }
        }
    }

    public init(
        vm: ResonanceViewModel,
        palette: ChimmoPalette,
        onOpenField: @escaping () -> Void = {}
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenField = onOpenField
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var currentHourFeaturedPresetID: String? {
        ResonanceKinematics.recommendedPresets(forHour: currentHour).first?.id
    }

    private var filteredPresets: [ResonancePreset] {
        ResonancePreset.all.filter { preset in
            if filter == .favorites && !vm.stats.isFavorite(preset.id) {
                return false
            }
            if let band = filter.bandFilter, preset.band != band {
                return false
            }
            if normalizedQuery.isEmpty {
                return true
            }
            return preset.title.lowercased().contains(normalizedQuery)
                || preset.subtitle.lowercased().contains(normalizedQuery)
                || preset.tagline.lowercased().contains(normalizedQuery)
                || preset.band.shortCode.lowercased().contains(normalizedQuery)
                || preset.washKind.title.lowercased().contains(normalizedQuery)
        }
    }

    private var filteredCapsules: [FrissonCapsule] {
        FrissonCapsule.all.filter { capsule in
            if let band = filter.bandFilter, capsule.companionBand != band {
                return false
            }
            if normalizedQuery.isEmpty {
                return true
            }
            return capsule.title.lowercased().contains(normalizedQuery)
                || capsule.subtitle.lowercased().contains(normalizedQuery)
                || capsule.frissonHighlight.lowercased().contains(normalizedQuery)
                || capsule.companionBand.shortCode.lowercased().contains(normalizedQuery)
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: vm.selectedBand.accentColor(isNight: palette.isNight)
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        filterChipsRow

                        if normalizedQuery.isEmpty && filter == .all {
                            kilnBandBenchSection
                        }

                        offlinePresetsSection

                        if normalizedQuery.isEmpty && filter == .all {
                            nightLampAtelierBanner
                        }

                        if filter != .favorites || !normalizedQuery.isEmpty {
                            frissonCapsulesSection
                        }

                        archiveMusicShelfEntry
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("声库")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索声景、频段或乐章")
            .sheet(isPresented: $showFullSpecimenShelf) {
                NavigationStack {
                    MusicBoxShelfView(
                        palette: palette,
                        synth: vm.studioVM.synth,
                        notebook: vm.studioVM.notebook,
                        currentDocumentID: vm.studioVM.document.id,
                        navigationTitleText: "全部 28 首声波乐章",
                        showsDismissButton: true,
                        onLoadSavedToBoard: { entry in
                            vm.stopBedPlayback()
                            vm.studioVM.openSavedEntry(entry, autoPlay: true)
                        },
                        onPlaySavedInShowcase: { entry in
                            vm.stopBedPlayback()
                            vm.studioVM.openSavedEntry(entry, autoPlay: true)
                        },
                        onPlayAlongSpecimen: { spec in
                            vm.stopBedPlayback()
                            vm.studioVM.openSpecimen(spec, autoPlay: true)
                        },
                        onEditSpecimenOnBoard: { spec in
                            vm.stopBedPlayback()
                            vm.studioVM.openSpecimen(spec, autoPlay: true)
                        },
                        onStartNewTap: {
                            showFullSpecimenShelf = false
                            vm.focusHumGuideOnFieldAppear = true
                            onOpenField()
                        },
                        onWillPlayInline: {
                            vm.stopAllAudio()
                        }
                    )
                }
            }
        }
    }

    // MARK: - 1. Wrapping Filter Chips (Zero Horizontal Scroll)

    private var filterChipsRow: some View {
        ChimmoFlowRow(spacing: 8, lineSpacing: 8) {
            ForEach(LibraryFilter.allCases) { item in
                let active = filter == item
                let tint = item.bandFilter?.accentColor(isNight: palette.isNight) ?? palette.homeAnchor
                Button {
                    filter = item
                    if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
                } label: {
                    HStack(spacing: 5) {
                        if item == .favorites {
                            Image(systemName: active ? "heart.fill" : "heart")
                                .font(.caption2.weight(.bold))
                        }
                        Text(item.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if item == .favorites && !vm.stats.favoritePresetIDs.isEmpty {
                            Text("\(vm.stats.favoritePresetIDs.count)")
                                .font(.caption2.weight(.heavy).monospacedDigit())
                        }
                    }
                    .foregroundStyle(active ? palette.contrastInkOnAccent : palette.primaryInk)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 38)
                    .background(
                        Capsule(style: .continuous)
                            .fill(active ? tint : palette.shelfSurface)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(active ? tint : palette.divider, lineWidth: 1.0)
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
                .accessibilityLabel("筛选 \(item.title)")
                .accessibilityValue(active ? "已选中" : "")
            }
        }
    }

    // MARK: - 2. Kiln Ceramic 4-Band Bench (Single Card, Four Divided Rows)

    private var kilnBandBenchSection: some View {
        let banner = ResonanceKinematics.timeOfDayBanner(forHour: currentHour)

        return VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "四频段窑陶调音座",
                detail: banner.title,
                isNight: palette.isNight,
                tint: palette.homeAnchor
            )

            VStack(spacing: 0) {
                ForEach(Array(BrainwaveBand.allCases.enumerated()), id: \.element.id) { index, band in
                    let tint = band.accentColor(isNight: palette.isNight)
                    let isPlayingBand = vm.isBedPlaying && vm.selectedBand == band

                    Button {
                        vm.selectBand(band, autoPlay: true)
                        onOpenField()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(tint.opacity(palette.isNight ? 0.24 : 0.14))
                                    .frame(width: 42, height: 42)
                                ChimmoFigureView(
                                    member: kilnMember(for: band),
                                    isNight: palette.isNight,
                                    isMinor: false,
                                    isSinging: isPlayingBand,
                                    time: 0
                                )
                                .scaleEffect(0.72)
                                .frame(width: 36, height: 36)
                            }
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(band.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(palette.primaryInk)
                                    Text(band.englishTag)
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(tint)
                                }
                                Text(band.somaticHook)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if isPlayingBand {
                                ChimmoResonanceBead(size: 10, isNight: palette.isNight, tint: tint)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.secondaryInk.opacity(0.65))
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(band.accessibilitySummary)
                    .accessibilityValue(isPlayingBand ? "正在共振" : "")
                    .accessibilityHint("轻点调谐至此频段并打开声场")

                    if index < BrainwaveBand.allCases.count - 1 {
                        Divider().opacity(0.45).padding(.leading, 68)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    private func kilnMember(for band: BrainwaveBand) -> ChimmoMember {
        switch band {
        case .delta: return .bomo
        case .theta: return .taono
        case .alpha: return .udo
        case .gamma: return .corllo
        }
    }

    // MARK: - 3. Offline Acoustic Presets (12 Curated Kiln Soundscapes)

    private var offlinePresetsSection: some View {
        let featuredID = currentHourFeaturedPresetID

        return VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: "离线声景配方",
                detail: "\(filteredPresets.count) 套",
                isNight: palette.isNight,
                tint: palette.celadonAccent
            )

            if filteredPresets.isEmpty {
                emptyResultCard(
                    message: filter == .favorites && normalizedQuery.isEmpty
                        ? "还没有收藏声景配方，轻点右侧心形即可收入这里。"
                        : "没有找到匹配的声景配方，换个关键词或筛选条件试试。"
                )
            } else {
                ForEach(filteredPresets) { preset in
                    let isPlayingThis = vm.activePreset?.id == preset.id && vm.isBedPlaying
                    let tint = preset.band.accentColor(isNight: palette.isNight)
                    let fav = vm.stats.isFavorite(preset.id)
                    let isHourMatch = preset.id == featuredID

                    HStack(spacing: 12) {
                        Button {
                            vm.startPreset(preset)
                            onOpenField()
                        } label: {
                            HStack(spacing: 12) {
                                ChimmoResonanceBead(size: 12, isNight: palette.isNight, tint: tint)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(preset.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(palette.primaryInk)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.78)

                                        if isHourMatch {
                                            Text("此刻契合")
                                                .font(.caption2.weight(.heavy))
                                                .foregroundStyle(palette.contrastInkOnAccent)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(palette.homeAnchor))
                                        }
                                    }

                                    Text("\(preset.subtitle) · \(preset.durationMinutes) 分钟 · \(preset.washKind.title)")
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(tint)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)

                                    Text(preset.tagline)
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryInk)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(preset.title)，\(preset.subtitle)")
                        .accessibilityValue(isPlayingThis ? "正在播放" : "")
                        .accessibilityHint("启动此离线声景并切换至声场控制台")

                        Button {
                            vm.stats.toggleFavoritePreset(preset.id)
                            if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
                        } label: {
                            Image(systemName: fav ? "heart.fill" : "heart")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(fav ? palette.homeAnchor : palette.secondaryInk)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(fav ? "取消收藏 \(preset.title)" : "收藏 \(preset.title)")
                        .accessibilityHint("添加或移出已收藏声景")
                    }
                    .padding(14)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: isPlayingThis ? tint : nil)
                }
            }
        }
    }

    // MARK: - 4. Native Dark-Indigo Night Lamp Tactile Bench

    private var nightLampAtelierBanner: some View {
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous)
        let moonCream = Color(hex: 0xF2E2C4)

        return VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "夜间零光盲操",
                isNight: palette.isNight,
                tint: palette.nightLampGold
            )

            Button {
                vm.openNightLampSheet = true
            } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ChimmoCraftMark(
                                .nightLampHalo,
                                color: palette.nightLampGold,
                                secondaryColor: moonCream.opacity(0.75)
                            )
                            .frame(width: 22, height: 22)

                            Text("闭眼夜灯触觉场")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(moonCream)
                        }

                        Text("纯黑防蓝光夜空音脊，单指盲滑与细腻触感，熄灯后也不刺眼。")
                            .font(.caption)
                            .foregroundStyle(moonCream.opacity(0.82))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Circle().strokeBorder(palette.nightLampGold.opacity(0.32), lineWidth: 1.2))
                            .frame(width: 70, height: 70)
                        LivingChimmoDuoBadgeView(
                            isNight: true,
                            accentColor: palette.nightLampGold,
                            melodyActive: false,
                            cowAwake: false
                        )
                        .frame(width: 56, height: 38)
                    }
                    .accessibilityHidden(true)
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [palette.nightLampBackdrop, palette.nightLampHillSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(palette.nightLampGold.opacity(0.28), lineWidth: 1.2)
                )
                .shadow(color: palette.elevationShadow(dayOpacity: 0.16, nightOpacity: 0.34), radius: 10, y: 5)
                .contentShape(shape)
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.4))
            .accessibilityLabel("闭眼夜灯触觉场，纯黑防蓝光盲操音脊")
            .accessibilityHint("轻点开启夜间零光触觉声音台")
        }
    }

    // MARK: - 5. Acoustic Frisson Capsules (8 Curated Releases)

    private var frissonCapsulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: "和声战栗乐章",
                detail: "\(filteredCapsules.count) 首精选",
                isNight: palette.isNight,
                tint: palette.bassRibbon
            )

            if filteredCapsules.isEmpty {
                emptyResultCard(message: "没有找到匹配「\(searchText)」的和声乐章，换个词试试。")
            } else {
                ForEach(filteredCapsules) { capsule in
                    let isPlayingThis = vm.activeCapsule?.id == capsule.id && vm.studioVM.isPlaying
                    let tint = capsule.companionBand.accentColor(isNight: palette.isNight)

                    HStack(spacing: 12) {
                        Button {
                            vm.toggleCapsule(capsule)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                                    .fill(tint.opacity(palette.isNight ? 0.24 : 0.14))
                                    .frame(width: 48, height: 48)
                                Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(tint)
                            }
                            .frame(width: 48, height: 48)
                            .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous))
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                        .accessibilityLabel(isPlayingThis ? "停止播放 \(capsule.title)" : "试听 \(capsule.title)")
                        .accessibilityHint("通过离线室内乐合成器播放这段和声乐章")

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(capsule.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                Spacer(minLength: 4)
                                Text(capsule.companionBand.shortCode)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(tint)
                            }

                            Text(capsule.frissonHighlight)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("\(capsule.subtitle) · \(capsule.durationText)")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryInk.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .padding(14)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: isPlayingThis ? tint : nil)
                }
            }
        }
    }

    // MARK: - 6. Full 28-Piece Archive Entry

    private var archiveMusicShelfEntry: some View {
        Button {
            showFullSpecimenShelf = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text("完整声学典藏档案（28 首）")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text("浏览公版古典、自研声学曲库与本地录音笔记")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
            }
            .padding(14)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
            .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityHint("在弹窗中浏览全部 28 首内置声学乐章与个人曲本")
    }

    private func emptyResultCard(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(palette.secondaryInk)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }
}
