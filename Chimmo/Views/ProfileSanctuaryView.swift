import SwiftUI

/// Tab 3 · 我的：对标 Airbnb Profile × Headspace Profile × 摸索台灯商业级洁净架构。
/// 包含：弧形天幕双子星身份卡 / Airbnb 三项沉淀卡 / 反焦虑无说教文案 / 双列图鉴与夜灯微卡 / 外观三联预览 / 声学安全与法务中心。
public struct ProfileSanctuaryView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette
    public let onOpenField: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showShareCard: Bool = false

    public init(
        vm: ResonanceViewModel,
        palette: ChimmoPalette,
        onOpenField: @escaping () -> Void = {}
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenField = onOpenField
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rainbowProfileBanner

                    VStack(alignment: .leading, spacing: 20) {
                        airbnbStatsCard

                        gentleCompanionCard

                        pairedDioramaCards

                        appearanceSwatchCard

                        acousticPreferencesCard

                        safetyAndLegalHub
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 34)
                }
            }
            .background(palette.paper.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showShareCard) {
                ResonanceShareCardSheet(vm: vm, palette: palette)
            }
        }
    }

    // MARK: - 1. Headspace Rainbow/Sunset Top Banner + Centered Chimmo Avatar

    private var rainbowProfileBanner: some View {
        let arcTop = palette.isNight ? Color(hex: 0x212A4C) : Color(hex: 0xFF7B29)
        let arcMid = palette.isNight ? Color(hex: 0x352E5B) : Color(hex: 0xFFA927)
        let arcBot = palette.isNight ? Color(hex: 0x4E3F35) : Color(hex: 0xFFD43B)

        return VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        arcTop.frame(height: 54)
                        arcMid.frame(height: 26)
                        arcBot.frame(height: 28)
                    }
                    .overlay(alignment: .bottom) {
                        ProfileTopArchCut()
                            .fill(palette.paper)
                            .frame(height: 32)
                            .offset(y: 1)
                    }

                    NavigationLink {
                        CharacterSoundTestView(
                            palette: palette,
                            scaleMode: vm.studioVM.document.scaleMode,
                            cradleEnabled: vm.studioVM.cradleEnabled,
                            onAuditionDuo: { vm.studioVM.auditionDuoCharacter($0) },
                            onAuditionMember: { vm.studioVM.auditionChimmoMember($0) }
                        )
                    } label: {
                        ZStack {
                            Circle()
                                .fill(palette.cardSurface)
                                .frame(width: 40, height: 40)
                                .shadow(color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.30), radius: 6, y: 2)
                            Image(systemName: "tuningfork")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                    .padding(.top, 52)
                    .padding(.trailing, 18)
                    .accessibilityLabel("声音家族角色试音台")
                    .accessibilityHint("轻点认识并试听双子咩哞与七声音阶小偶")
                }

                // 居中大头像圈（LivingChimmoDuoBadgeView）
                ZStack {
                    Circle()
                        .fill(palette.paper)
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(palette.storybookButter)
                        .frame(width: 84, height: 84)
                    LivingChimmoDuoBadgeView(
                        isNight: palette.isNight,
                        accentColor: palette.homeAnchor,
                        melodyActive: vm.isBedPlaying,
                        cowAwake: vm.isBedPlaying
                    )
                    .frame(width: 68, height: 46)
                }
                .offset(y: 20)
                .accessibilityHidden(true)
            }
            .padding(.bottom, 18)

            VStack(spacing: 3) {
                Text("咩哞 · Mie & Mou")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .accessibilityAddTraits(.isHeader)

                Text("声波共振与感官放松 · \(vm.stats.firstUseFormattedDate)")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryInk)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 2. Airbnb Elevated Stats Card

    private var airbnbStatsCard: some View {
        let favBand = vm.stats.favoriteBand

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(palette.storybookMint)
                            .frame(width: 84, height: 84)
                        ChimmoFigureView(
                            member: favBand == .theta ? .taono : (favBand == .delta ? .bomo : .udo),
                            isNight: palette.isNight,
                            isMinor: false,
                            isSinging: vm.isBedPlaying,
                            time: 0
                        )
                        .scaleEffect(0.95)
                    }
                    .accessibilityHidden(true)

                    Text("100% 离线本机")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.celadonAccent)
                }
                .frame(width: 112)

                VStack(alignment: .leading, spacing: 10) {
                    statLine(value: "\(vm.stats.totalMinutes)", label: "累计共振分钟")
                    Divider().opacity(0.45)
                    statLine(value: "\(vm.stats.frissonPeakCount)", label: "颅内战栗次数")
                    Divider().opacity(0.45)
                    statLine(value: favBand?.shortCode ?? "探索中", label: "最合拍频段")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showShareCard = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                    Text("生成我的脑波共振纪念卡")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(palette.primaryInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 40)
                .background(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous).fill(palette.shelfSurface))
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityHint("离线渲染高清共振纪念卡片并通过系统菜单保存或分享")
        }
        .padding(18)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    private func statLine(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(palette.primaryInk)
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 3. Anti-Anxiety Companion Card

    private var gentleCompanionCard: some View {
        let copy = ResonanceKinematics.gentleCompanionMessage(
            totalMinutes: vm.stats.totalMinutes,
            frissonCount: vm.stats.frissonPeakCount,
            favoriteBand: vm.stats.favoriteBand
        )

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.homeAnchor.opacity(palette.isNight ? 0.25 : 0.14))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(45))
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.homeAnchor)
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("不打卡的陪伴")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .accessibilityAddTraits(.isHeader)

                Text(copy)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    // MARK: - 4. Airbnb 2-Column Tactile Diorama Tiles

    private var pairedDioramaCards: some View {
        let cols: [GridItem] = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: cols, spacing: 12) {
            NavigationLink {
                CharacterSoundTestView(
                    palette: palette,
                    scaleMode: vm.studioVM.document.scaleMode,
                    cradleEnabled: vm.studioVM.cradleEnabled,
                    onAuditionDuo: { vm.studioVM.auditionDuoCharacter($0) },
                    onAuditionMember: { vm.studioVM.auditionChimmoMember($0) }
                )
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Spacer()
                        Text("图鉴")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(palette.bassRibbon))
                    }

                    HStack(spacing: 4) {
                        ChimmoFigureView(member: .taono, isNight: palette.isNight, isMinor: false, isSinging: false)
                            .scaleEffect(0.75)
                            .frame(width: 34, height: 34)
                        ChimmoFigureView(member: .plokko, isNight: palette.isNight, isMinor: false, isSinging: false)
                            .scaleEffect(0.75)
                            .frame(width: 34, height: 34)
                        ChimmoFigureView(member: .corllo, isNight: palette.isNight, isMinor: false, isSinging: false)
                            .scaleEffect(0.75)
                            .frame(width: 34, height: 34)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .accessibilityHidden(true)

                    Text("声学角色家族")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text("轻触试听双子与七声")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel("声学角色家族，轻触试听双子与七声小偶")

            Button {
                vm.openNightLampSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Spacer()
                        Text("盲操")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(palette.harmonyWash))
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                            .fill(palette.nightLampBackdrop)
                        HStack(spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(.title3)
                                .foregroundStyle(palette.nightLampGold)
                            Image(systemName: "hand.draw.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .frame(height: 52)
                    .accessibilityHidden(true)

                    Text("闭眼夜灯模式")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text("熄灯低亮度防蓝光滑奏")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel("闭眼夜灯模式，熄灯低亮度防蓝光滑奏")
        }
    }

    // MARK: - 5. Moss & Otto Twin Appearance Swatches

    private var appearanceSwatchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ChimmoResonanceBead(size: 10, isNight: palette.isNight, tint: palette.nightLampGold)
                Text("外观")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(vm.studioVM.appearance.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.homeAnchor)
            }

            let columns: [GridItem] = dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AppearancePreference.allCases) { pref in
                    let active = vm.studioVM.appearance == pref
                    Button {
                        vm.studioVM.appearance = pref
                        if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
                    } label: {
                        appearanceTile(for: pref, active: active)
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                    .accessibilityLabel("外观 \(pref.label)")
                    .accessibilityValue(active ? "已选中" : "")
                    .accessibilityHint("选择日间棉纸、夜间星灯或跟随系统")
                }
            }
        }
        .padding(14)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    private func appearanceTile(for pref: AppearancePreference, active: Bool) -> some View {
        let day = ChimmoPalette(isNight: false)
        let night = ChimmoPalette(isNight: true)
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)

        return ZStack(alignment: .bottom) {
            Group {
                switch pref {
                case .daylight:
                    day.paper
                case .nightLamp:
                    night.paper
                case .auto:
                    HStack(spacing: 0) {
                        day.paper
                        night.paper
                    }
                }
            }
            .frame(height: 58)
            .clipShape(shape)

            Text(pref.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(pref == .nightLamp ? night.primaryInk : (pref == .daylight ? day.primaryInk : palette.primaryInk))
                .padding(.horizontal, 10)
                .padding(.vertical, 3.5)
                .background(Capsule().fill((pref == .nightLamp ? night.cardSurface : (pref == .daylight ? day.cardSurface : palette.cardSurface)).opacity(0.92)))
                .padding(.bottom, 6)

            if active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.homeAnchor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(5)
            }
        }
        .overlay(
            shape.strokeBorder(active ? palette.homeAnchor : palette.divider, lineWidth: active ? 2.0 : 1.0)
        )
        .contentShape(shape)
    }

    // MARK: - 6. Acoustic Preferences Card

    private var acousticPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "声波与触觉偏好",
                isNight: palette.isNight,
                tint: palette.celadonAccent
            )

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    prefCircle(symbol: "iphone.radiowaves.left.and.right", tint: palette.homeAnchor)
                    Toggle(isOn: $vm.hapticsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("掌心脑波触觉脉动")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("调频刻度与战栗松手时伴随细腻物理触感")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }
                    }
                    .tint(palette.homeAnchor)
                }
                .padding(14)

                Divider().opacity(0.45).padding(.leading, 56)

                HStack(spacing: 12) {
                    prefCircle(symbol: "lock.rotation", tint: palette.bassRibbon)
                    Toggle(isOn: $vm.backgroundAudioEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("锁屏继续收听声场")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("熄屏放空或入眠时保持脑波与暖雨声床播放")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }
                    }
                    .tint(palette.bassRibbon)
                }
                .padding(14)

                Divider().opacity(0.45).padding(.leading, 56)

                HStack(spacing: 12) {
                    prefCircle(symbol: vm.isHeadphonesConnected ? "headphones" : "speaker.wave.2.fill", tint: palette.celadonAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isHeadphonesConnected ? "已佩戴耳机 · 立体声双耳差频" : "未接耳机 · 自动等时声波共振")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryInk)
                        Text(vm.isHeadphonesConnected ? "左右耳分别接收微小频率差，体感知觉最立体" : "插上耳机体验纯正左右耳差频；外放时亦会自动补充轻脉动")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                    }
                }
                .padding(14)
            }
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    private func prefCircle(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.opacity(palette.isNight ? 0.24 : 0.14))
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    // MARK: - 7. Guideline 1.4.1 Acoustic Safety & Legal Compliance Hub

    private var safetyAndLegalHub: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "安全、隐私与合规声明",
                detail: "v\(appVersion) (\(appBuild))",
                isNight: palette.isNight,
                tint: palette.harmonyWash
            )

            VStack(spacing: 0) {
                NavigationLink {
                    ChimmoAcousticSafetyView()
                } label: {
                    hubRow(
                        title: "声学安全与非医疗声明",
                        subtitle: "本应用为声学放松与感官艺术体验，非医疗器械",
                        symbol: "ear.badge.checkmark",
                        tint: palette.homeAnchor
                    )
                }
                .buttonStyle(.plain)

                Divider().opacity(0.45).padding(.leading, 56)

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .privacy)
                } label: {
                    hubRow(
                        title: "隐私政策（100% 本机离线）",
                        subtitle: "零账号、零联网上传、零第三方追踪",
                        symbol: "hand.raised.fill",
                        tint: palette.celadonAccent
                    )
                }
                .buttonStyle(.plain)

                Divider().opacity(0.45).padding(.leading, 56)

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .terms)
                } label: {
                    hubRow(
                        title: "使用条款",
                        subtitle: "权利与离线运行免责说明",
                        symbol: "doc.text.fill",
                        tint: palette.nightLampGold
                    )
                }
                .buttonStyle(.plain)

                Divider().opacity(0.45).padding(.leading, 56)

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .licenses)
                } label: {
                    hubRow(
                        title: "开源许可与声库鸣谢",
                        subtitle: "SwiftF0 MIT · 28 首自洁乐章",
                        symbol: "books.vertical.fill",
                        tint: palette.harmonyWash
                    )
                }
                .buttonStyle(.plain)

                if let siteURL = URL(string: "https://mjuvdeysii.github.io/chimmo/") {
                    Divider().opacity(0.45).padding(.leading, 56)
                    Link(destination: siteURL) {
                        hubExternalRow(title: "官方网站与支持", symbol: "globe", tint: palette.bassRibbon)
                    }
                    .accessibilityHint("在浏览器中打开")
                }

                if let issuesURL = URL(string: "https://github.com/mjuvdeysii/chimmo/issues") {
                    Divider().opacity(0.45).padding(.leading, 56)
                    Link(destination: issuesURL) {
                        hubExternalRow(title: "公测问题反馈", symbol: "bubble.left.and.text.bubble.right", tint: palette.homeAnchor)
                    }
                    .accessibilityHint("在浏览器中打开")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    private func hubRow(title: String, subtitle: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            prefCircle(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryInk)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryInk.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func hubExternalRow(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            prefCircle(symbol: symbol, tint: tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryInk)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryInk.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct ProfileTopArchCut: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: -rect.height * 0.45)
        )
        p.closeSubpath()
        return p
    }
}

/// 声学安全与非医疗声明页面（符合 Apple Guideline 1.4.1 审核规范）。
public struct ChimmoAcousticSafetyView: View {
    public init() {}

    public var body: some View {
        List {
            Section("1. 非医疗声明（重要）") {
                Text("咩哞（Mie & Mou）是一款纯粹用于声学放松、专注氛围与感官艺术体验的离线声音工具。本应用不属于医疗器械，不收集生理指标，也不提供任何疾病预防、诊断、治疗或临床康复效果（包括但不限于失眠症、焦虑症或注意力缺陷等）。")
                    .font(.subheadline)
            }

            Section("2. 双耳差频与安全舒适音量") {
                Text("当您佩戴立体声耳机时，应用会向左右耳发送频率略有差异的轻柔声波；未连接耳机时则自动转为温和的等时声床共振。应用内核内置柔和限幅器保护，但仍请您始终调节至舒适、清晰的聆听音量，避免长时间过响收听。")
                    .font(.subheadline)
            }

            Section("3. 驾驶与专心操作场景提示") {
                Text("请勿在驾驶车辆、操作机械或需要高度警觉的公共安全环境中闭眼聆听深度 Delta / Theta 放松声场。")
                    .font(.subheadline)
            }

            Section("4. 麦克风与物理触觉控制") {
                Text("「轻哼同频」功能完全在设备本地实时处理人声基频，不录音留存、不联网传输；即使不开启麦克风权限，也可以直接选择预设共振基频继续使用。如需关闭震动，可随时在「我的 -> 掌心脑波触觉脉动」一键关闭。")
                    .font(.subheadline)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("声学安全与说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
