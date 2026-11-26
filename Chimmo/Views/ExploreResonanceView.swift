import SwiftUI

/// Tab 2 · 探索：对标 Headspace Explore 状态直达构图（2x2 脑波格 + 闭眼夜灯精选卡 + 颅内战栗声波乐章胶囊 + 离线声景配方 + 原典乐谱曲本入口）。
public struct ExploreResonanceView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette
    public let onOpenField: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText: String = ""
    @State private var showFullSpecimenShelf: Bool = false

    public init(
        vm: ResonanceViewModel,
        palette: ChimmoPalette,
        onOpenField: @escaping () -> Void = {}
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenField = onOpenField
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredCapsules: [FrissonCapsule] {
        guard !normalizedQuery.isEmpty else { return FrissonCapsule.all }
        return FrissonCapsule.all.filter {
            $0.title.lowercased().contains(normalizedQuery)
                || $0.subtitle.lowercased().contains(normalizedQuery)
                || $0.frissonHighlight.lowercased().contains(normalizedQuery)
        }
    }

    private var filteredPresets: [ResonancePreset] {
        guard !normalizedQuery.isEmpty else { return ResonancePreset.all }
        return ResonancePreset.all.filter {
            $0.title.lowercased().contains(normalizedQuery)
                || $0.subtitle.lowercased().contains(normalizedQuery)
                || $0.tagline.lowercased().contains(normalizedQuery)
                || $0.band.shortCode.lowercased().contains(normalizedQuery)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerAndSearch

                if normalizedQuery.isEmpty {
                    stateQuickGrid
                    featuredNightLampBanner
                }

                frissonCapsulesSection

                offlinePresetsSection

                archiveMusicShelfEntry
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 34)
        }
        .background(palette.paper.ignoresSafeArea())
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

    // MARK: - 1. Header & Clean Search Bar

    private var headerAndSearch: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("探索")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryInk)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.secondaryInk)
                    .accessibilityHidden(true)

                TextField("搜索脑波、暖雨、德彪西或乐章", text: $searchText)
                    .font(.subheadline)
                    .foregroundStyle(palette.primaryInk)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            .background(
                Capsule()
                    .fill(palette.shelfSurface)
            )
        }
    }

    // MARK: - 2. Headspace 2x2 State Grid

    private var stateQuickGrid: some View {
        let cols: [GridItem] = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        let orderedBands: [BrainwaveBand] = [.theta, .delta, .alpha, .gamma]

        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(orderedBands) { band in
                let tint = band.accentColor(isNight: palette.isNight)
                let isPlayingBand = vm.isBedPlaying && vm.selectedBand == band
                Button {
                    vm.selectBand(band, autoPlay: true)
                    onOpenField()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(tint.opacity(palette.isNight ? 0.28 : 0.16))
                                .frame(width: 34, height: 34)
                            Image(systemName: band.symbolName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(tint)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(band.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Text(band.shortCode)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.secondaryInk)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 62)
                    .background(
                        RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                            .fill(palette.shelfSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                            .strokeBorder(isPlayingBand ? tint : Color.clear, lineWidth: 1.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                .accessibilityLabel(band.accessibilitySummary)
                .accessibilityHint("轻点立即启动并进入共振声场")
            }
        }
    }

    // MARK: - 3. Featured Dark Emerald / Night Lamp Tactile Sanctuary Banner

    private var featuredNightLampBanner: some View {
        let bgFill = palette.isNight ? Color(hex: 0x132E26) : Color(hex: 0x165B3A)
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous)

        return VStack(alignment: .leading, spacing: 10) {
            Text("特别体验")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryInk)
                .accessibilityAddTraits(.isHeader)

            Button {
                vm.openNightLampSheet = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("零光盲操模式")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Color(hex: 0x114B30))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white))

                        Text("闭眼夜灯触觉场")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)

                        Text("熄灯前也不用盯住屏幕——单指沿夜空音脊滑寻松弛低音，凭震动感受声波起伏。")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.86))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 极简拱门月夜向量插画（致敬 Headspace Featured 构图）
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(hex: 0xFFB547))
                            .frame(width: 68, height: 82)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(Color(hex: 0x1C1D19), lineWidth: 2.0)
                            )
                        Circle()
                            .fill(Color(hex: 0x7950F2))
                            .frame(width: 24, height: 24)
                            .offset(x: 24, y: -32)
                        VStack(spacing: 4) {
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: 0x1C1D19)).frame(width: 4, height: 4)
                                Circle().fill(Color(hex: 0x1C1D19)).frame(width: 4, height: 4)
                            }
                            .padding(.bottom, 18)
                        }
                        .frame(height: 82)
                    }
                    .accessibilityHidden(true)
                }
                .padding(18)
                .background(shape.fill(bgFill))
                .shadow(color: palette.elevationShadow(dayOpacity: 0.16, nightOpacity: 0.34), radius: 10, y: 5)
                .contentShape(shape)
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("闭眼夜灯触觉场，零光盲操模式")
            .accessibilityHint("轻点进入深夜纯黑防蓝光触觉音场")
        }
    }

    // MARK: - 4. Frisson Musical Capsules (升维收纳 8 首声波乐章胶囊)

    private var frissonCapsulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: "颅内战栗 · 声波乐章",
                detail: "8 首高张力释放精选",
                isNight: palette.isNight,
                tint: palette.homeAnchor
            )

            if filteredCapsules.isEmpty {
                emptySearchCard
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
                                    .frame(width: 52, height: 52)
                                Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(tint)
                            }
                            .frame(width: 52, height: 52)
                            .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous))
                        }
                        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                        .accessibilityLabel(isPlayingThis ? "停止播放 \(capsule.title)" : "试听 \(capsule.title)")
                        .accessibilityHint("通过离线室内乐合成器循环播放这首和声乐章")

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

    // MARK: - 5. Offline Acoustic Presets

    private var offlinePresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: "声景与双耳配方",
                detail: "\(filteredPresets.count) 套离线预设",
                isNight: palette.isNight,
                tint: palette.celadonAccent
            )

            ForEach(filteredPresets) { preset in
                let isPlayingThis = vm.activePreset?.id == preset.id && vm.isBedPlaying
                let tint = preset.band.accentColor(isNight: palette.isNight)
                let fav = vm.stats.isFavorite(preset.id)

                HStack(spacing: 12) {
                    Button {
                        vm.startPreset(preset)
                        onOpenField()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(tint)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Text("\(preset.subtitle) · \(preset.durationMinutes) 分钟")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(tint)
                                    .lineLimit(1)

                                Text(preset.tagline)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryInk)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.title)，\(preset.subtitle)")
                    .accessibilityValue(isPlayingThis ? "正在播放" : "")
                    .accessibilityHint("开启此离线脑波配方并前往共振舞台")

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
                    .accessibilityHint("添加到我的收藏列表")
                }
                .padding(14)
                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: isPlayingThis ? tint : nil)
            }
        }
    }

    // MARK: - 6. Full Archive Shelf Disclosure Entry

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
                    Text("查看公版古典与自研声学曲库及本地创作草稿")
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

    private var emptySearchCard: some View {
        Text("没有找到匹配「\(searchText)」的声波乐章，换个词试试。")
            .font(.subheadline)
            .foregroundStyle(palette.secondaryInk)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }
}
