import SwiftUI

/// Tab 0 · 今日：对标 Headspace Today 空气感极简旅程架构，告别“乐理作业”，3 秒进入今日脑波状态。
public struct TodayJourneyView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette
    public let onOpenField: () -> Void
    public let onOpenExplore: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var activeFilterSheet: ShelfFilter? = nil

    private enum ShelfFilter: String, Identifiable {
        case recents
        case favorites
        var id: String { rawValue }
    }

    public init(
        vm: ResonanceViewModel,
        palette: ChimmoPalette,
        onOpenField: @escaping () -> Void = {},
        onOpenExplore: @escaping () -> Void = {}
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenField = onOpenField
        self.onOpenExplore = onOpenExplore
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var journeySteps: [ResonancePreset] {
        ResonanceKinematics.dailyJourneySteps(forHour: currentHour)
    }

    private var topRecommendation: ResonancePreset {
        let favoriteBand = vm.stats.favoriteBand ?? .theta
        return ResonancePreset.all.first { $0.band == favoriteBand && $0.id != journeySteps.first?.id }
            ?? ResonancePreset.all[3]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                curvedSkyHeader

                VStack(alignment: .leading, spacing: 22) {
                    quickShortcutPills

                    essentialsJourneySection

                    personalizeAndRecommendSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
        }
        .background(palette.paper.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(item: $activeFilterSheet) { kind in
            presetDrawerSheet(kind: kind)
        }
    }

    // MARK: - 1. Headspace-Inspired Curved Sky Banner

    private var curvedSkyHeader: some View {
        let bannerCopy = ResonanceKinematics.timeOfDayBanner(forHour: currentHour)
        let skyTop = palette.isNight ? Color(hex: 0x0B1028) : Color(hex: 0x62A8F2)
        let skyBot = palette.isNight ? Color(hex: 0x1B2650) : Color(hex: 0x9DD0FF)

        return ZStack(alignment: .bottom) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [skyTop, skyBot], startPoint: .top, endPoint: .bottom)

                // 柔和云朵/月影装饰（零噪点纯平涂）
                Canvas { ctx, size in
                    let w = size.width
                    let h = size.height
                    if palette.isNight {
                        for (idx, pt) in [(0.16, 0.34), (0.34, 0.24), (0.62, 0.28), (0.82, 0.38)].enumerated() {
                            let r: CGFloat = idx.isMultiple(of: 2) ? 2.2 : 1.5
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: w * pt.0 - r, y: h * pt.1 - r, width: r * 2, height: r * 2)),
                                with: .color(palette.nightLampGold.opacity(0.65))
                            )
                        }
                    } else {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: -w * 0.08, y: h * 0.56, width: w * 0.44, height: h * 0.50)),
                            with: .color(Color.white.opacity(0.45))
                        )
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: w * 0.72, y: h * 0.52, width: w * 0.38, height: h * 0.48)),
                            with: .color(Color.white.opacity(0.45))
                        )
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: w * 0.26, y: h * 0.28, width: 42, height: 18)),
                            with: .color(Color.white.opacity(0.32))
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                // 顶部快捷状态键（耳机提示 + 闭眼夜灯直通）
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: vm.isHeadphonesConnected ? "headphones" : "speaker.wave.2.fill")
                            .font(.caption.weight(.bold))
                        Text(vm.isHeadphonesConnected ? "双耳差频" : "外放等时")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(palette.isNight ? palette.primaryInk : Color(hex: 0x102A43))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill((palette.isNight ? palette.cardSurface : Color.white).opacity(reduceTransparency ? 0.96 : 0.80))
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(vm.isHeadphonesConnected ? "当前已连接耳机，使用立体声双耳差频" : "当前外放模式，使用等时声波共振")

                    Button {
                        vm.openNightLampSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill((palette.isNight ? palette.cardSurface : Color.white).opacity(reduceTransparency ? 0.96 : 0.85))
                                .frame(width: 38, height: 38)
                            Image(systemName: "lamp.desk.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.isNight ? palette.nightLampGold : palette.homeAnchor)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                    .accessibilityLabel("打开闭眼夜灯触觉场")
                    .accessibilityHint("进入低亮度零刺激夜间盲操声音场")
                }
                .padding(.top, 56)
                .padding(.trailing, 18)
            }
            .frame(height: 158)

            // 弧形切底接入纯棉纸底板 + 咩哞静卧剪影
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerCopy.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(bannerCopy.subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .padding(.leading, 18)
                .padding(.bottom, 4)

                Spacer(minLength: 8)

                LivingChimmoDuoBadgeView(
                    isNight: palette.isNight,
                    accentColor: vm.selectedBand.accentColor(isNight: palette.isNight),
                    melodyActive: vm.isBedPlaying,
                    cowAwake: vm.isBedPlaying
                )
                .frame(width: 56, height: 38)
                .padding(.trailing, 20)
                .padding(.bottom, 2)
                .accessibilityHidden(true)
            }
            .padding(.top, 16)
            .background(
                CurvedTopArchShape()
                    .fill(palette.paper)
            )
            .offset(y: 1)
        }
    }

    // MARK: - 2. Quick Pills (最近 · 收藏)

    private var quickShortcutPills: some View {
        HStack(spacing: 10) {
            shortcutPill(
                title: "最近共振",
                symbol: "clock.fill",
                count: vm.stats.recentPresetIDs.count
            ) {
                activeFilterSheet = .recents
            }

            shortcutPill(
                title: "我的收藏",
                symbol: "heart.fill",
                count: vm.stats.favoritePresetIDs.count
            ) {
                activeFilterSheet = .favorites
            }

            Spacer(minLength: 0)
        }
    }

    private func shortcutPill(title: String, symbol: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(palette.homeAnchor)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(palette.shelfSurface)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityLabel("\(title)，\(count) 项")
        .accessibilityHint("轻点查看或直接开启声波配方")
    }

    // MARK: - 3. Headspace "Your Essentials" 3-Step Vertical Journey

    private var essentialsJourneySection: some View {
        let heroPreset = journeySteps.first ?? ResonancePreset.all[0]
        return VStack(alignment: .leading, spacing: 14) {
            Text("今日脑波旅程")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryInk)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                // Step 1: 暖阳 Hero 大卡
                journeyRow(isCurrent: true, isLast: false) {
                    todayHeroCard(preset: heroPreset)
                }

                // Step 2: 90秒颅内战栗瞬时释放
                journeyRow(isCurrent: false, isLast: false) {
                    quietStepButton(
                        title: "90 秒颅内战栗释放 · 长按蓄力与绽放",
                        symbol: "bolt.heart.fill",
                        tint: palette.homeAnchor
                    ) {
                        vm.focusFrissonGuideOnFieldAppear = true
                        onOpenField()
                    }
                }

                // Step 3: 3秒轻哼迷走同频
                journeyRow(isCurrent: false, isLast: true) {
                    quietStepButton(
                        title: "3 秒轻哼同频按摩 · 锁住你的声音根频",
                        symbol: "mic.fill",
                        tint: palette.celadonAccent
                    ) {
                        vm.focusHumGuideOnFieldAppear = true
                        onOpenField()
                    }
                }
            }
        }
    }

    private func journeyRow<Content: View>(isCurrent: Bool, isLast: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? palette.homeAnchor : palette.cardSurface)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isCurrent ? palette.homeAnchor : palette.divider,
                                lineWidth: 2.2
                            )
                    )
                    .frame(width: 14, height: 14)

                if !isLast {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(width: 2)
                        .frame(minHeight: 34, maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 16)
            .accessibilityHidden(true)

            content()
        }
    }

    private func todayHeroCard(preset: ResonancePreset) -> some View {
        let isActive = vm.activePreset?.id == preset.id && vm.isBedPlaying
        let warmStart = palette.isNight ? Color(hex: 0x3A2D18) : Color(hex: 0xFFD43B)
        let warmEnd = palette.isNight ? Color(hex: 0x5B3C1A) : Color(hex: 0xFF9F1C)
        let heroInk = palette.isNight ? palette.primaryInk : Color(hex: 0x1C1D19)
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous)

        return ZStack(alignment: .topTrailing) {
            Button {
                if isActive {
                    vm.stopBedPlayback()
                } else {
                    vm.startPreset(preset)
                    onOpenField()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: preset.band.symbolName)
                                .font(.caption.weight(.bold))
                            Text("\(preset.band.shortCode) · \(String(format: "%.1f", preset.beatHz)) Hz")
                                .font(.caption.weight(.heavy).monospacedDigit())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(palette.isNight ? 0.14 : 0.72)))

                        Text(preset.title)
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(preset.washKind.title) · \(preset.durationMinutes) 分钟")
                            .font(.subheadline.weight(.semibold))
                            .opacity(0.84)

                        Text(isActive ? "正在共振 · 点此收起或查看声场" : "轻点立即进入今日声波")
                            .font(.caption.weight(.bold))
                            .opacity(0.75)
                    }
                    .foregroundStyle(heroInk)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 4)
                }
                .padding(18)
                .frame(minHeight: 132)
                .background {
                    ZStack(alignment: .bottomTrailing) {
                        LinearGradient(colors: [warmStart, warmEnd], startPoint: .topLeading, endPoint: .bottomTrailing)

                        // Headspace 标志性暖光微笑弧线剪影
                        Canvas { ctx, size in
                            let cx = size.width * 0.88
                            let cy = size.height * 0.76
                            let outerR: CGFloat = 68
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)),
                                with: .color(Color.white.opacity(palette.isNight ? 0.12 : 0.24))
                            )
                            let eyeStroke = StrokeStyle(lineWidth: 2.6, lineCap: .round)
                            let ink = heroInk.opacity(0.75)
                            for dx in [-18.0, 2.0] {
                                var closedEye = Path()
                                closedEye.move(to: CGPoint(x: cx + dx - 16, y: cy - 12))
                                closedEye.addQuadCurve(
                                    to: CGPoint(x: cx + dx - 4, y: cy - 12),
                                    control: CGPoint(x: cx + dx - 10, y: cy - 4)
                                )
                                ctx.stroke(closedEye, with: .color(ink), style: eyeStroke)
                            }
                            var smile = Path()
                            smile.move(to: CGPoint(x: cx - 32, y: cy + 4))
                            smile.addQuadCurve(to: CGPoint(x: cx - 2, y: cy + 4), control: CGPoint(x: cx - 17, y: cy + 18))
                            ctx.stroke(smile, with: .color(ink), style: eyeStroke)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                    .clipShape(shape)
                }
                .shadow(color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.30), radius: 10, y: 5)
                .contentShape(shape)
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
            .accessibilityLabel("\(preset.title)，\(preset.subtitle)，\(preset.durationMinutes) 分钟")
            .accessibilityValue(isActive ? "正在播放" : "")
            .accessibilityHint("轻点开启今日脑波并打开共振舞台")

            Button {
                vm.stats.toggleFavoritePreset(preset.id)
                if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
            } label: {
                let fav = vm.stats.isFavorite(preset.id)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(palette.isNight ? 0.18 : 0.72))
                        .frame(width: 34, height: 34)
                    Image(systemName: fav ? "heart.fill" : "heart")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(fav ? palette.homeAnchor : heroInk.opacity(0.75))
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel(vm.stats.isFavorite(preset.id) ? "取消收藏今日推荐" : "收藏今日推荐")
            .accessibilityHint("将这套脑波配方保存或移出我的收藏")
        }
    }

    private func quietStepButton(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk.opacity(0.65))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                    .fill(palette.shelfSurface)
            )
            .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
        .accessibilityHint("轻点进入对应声波体感引导")
    }

    // MARK: - 4. Personalize & Top Recommendation

    private var personalizeAndRecommendSection: some View {
        let rec = topRecommendation
        let recPlaying = vm.activePreset?.id == rec.id && vm.isBedPlaying
        let recAccent = rec.band.accentColor(isNight: palette.isNight)

        return VStack(alignment: .leading, spacing: 14) {
            Text("挑一个合拍的状态")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryInk)
                .accessibilityAddTraits(.isHeader)

            Button(action: onOpenExplore) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(palette.paper)
                            .frame(width: 34, height: 34)
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.bassRibbon)
                    }
                    Text("逛逛全部脑波频段与声景乐章")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryInk)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous)
                        .fill(palette.shelfSurface)
                )
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityHint("切换至探索页面查看四大脑波状态与战栗乐章")

            // Top Recommendation Card
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                        .fill(recAccent.opacity(palette.isNight ? 0.28 : 0.16))
                    ChimmoFigureView(
                        member: rec.band == .theta ? .taono : (rec.band == .delta ? .bomo : .udo),
                        isNight: palette.isNight,
                        isMinor: false,
                        isSinging: recPlaying,
                        time: 0
                    )
                    .scaleEffect(0.86)
                }
                .frame(width: 70, height: 70)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("此刻精选推荐")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(recAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(palette.paper))

                    Text(rec.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("\(rec.band.shortCode) · \(rec.durationMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if recPlaying {
                        vm.stopBedPlayback()
                    } else {
                        vm.startPreset(rec)
                        onOpenField()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(palette.bassRibbon)
                            .frame(width: 44, height: 44)
                        Image(systemName: recPlaying ? "stop.fill" : "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.4))
                .accessibilityLabel(recPlaying ? "停止 \(rec.title)" : "播放推荐 \(rec.title)")
                .accessibilityHint("轻点立即启动此精选脑波声场")
            }
            .padding(14)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    // MARK: - 5. Recent & Favorites Drawer Sheet

    private func presetDrawerSheet(kind: ShelfFilter) -> some View {
        let items: [ResonancePreset] = {
            switch kind {
            case .recents:
                return vm.stats.recentPresetIDs.compactMap { id in
                    ResonancePreset.all.first(where: { $0.id == id })
                }
            case .favorites:
                return ResonancePreset.all.filter { vm.stats.favoritePresetIDs.contains($0.id) }
            }
        }()

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            LivingChimmoDuoBadgeView(
                                isNight: palette.isNight,
                                accentColor: palette.homeAnchor,
                                melodyActive: false,
                                cowAwake: false
                            )
                            .frame(width: 72, height: 48)

                            Text(kind == .recents ? "还没有最近开启的声波记录" : "还没有收藏声波配方")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)

                            Text("先试试推荐的今日心流，觉得顺耳随时点爱心收进来。")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryInk)
                                .multilineTextAlignment(.center)

                            Button("开启今日推荐") {
                                let hero = journeySteps.first ?? ResonancePreset.all[0]
                                activeFilterSheet = nil
                                vm.startPreset(hero)
                                onOpenField()
                            }
                            .buttonStyle(.chimmoVinyl(palette: palette, tint: palette.homeAnchor, prominent: true))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                    } else {
                        ForEach(items) { preset in
                            Button {
                                activeFilterSheet = nil
                                vm.startPreset(preset)
                                onOpenField()
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(preset.band.accentColor(isNight: palette.isNight))
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(palette.primaryInk)
                                        Text(preset.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryInk)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(preset.band.accentColor(isNight: palette.isNight))
                                }
                                .padding(14)
                                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                            }
                            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                        }
                    }
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle(kind == .recents ? "最近共振" : "我的收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { activeFilterSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CurvedTopArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: 18))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: 18),
            control: CGPoint(x: rect.midX, y: -12)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
