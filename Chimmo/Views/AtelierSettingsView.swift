import SwiftUI

/// Tab 2 · 工坊：咩哞原创窑陶工坊与声学设置（窑陶品牌铭牌 / 纪念卡导出 / 角色试音与夜灯 / 外观三联画布 / 偏好与非医疗合规声明）。
public struct AtelierSettingsView: View {
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.2.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(
                    palette: palette,
                    accentTint: palette.harmonyWash
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        atelierBrandCard

                        atelierToolsCard

                        appearanceSwatchCard

                        acousticPreferencesCard

                        safetyAndLegalHub
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("工坊")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showShareCard) {
                ResonanceShareCardSheet(vm: vm, palette: palette)
            }
        }
    }

    // MARK: - 1. Kiln-Ceramic Atelier Brand Crest & Share Card

    private var atelierBrandCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                SettingsBrandMarkView(isNight: palette.isNight)
                    .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text("咩哞 · Mie & Mou")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .accessibilityAddTraits(.isHeader)

                    Text("100% 离线脑波共振与窑陶声学工坊")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryInk)

                    ChimmoFlowRow(spacing: 6, lineSpacing: 5) {
                        atelierBadge(
                            text: "累计 \(vm.stats.totalMinutes) 分钟",
                            symbol: "waveform",
                            tint: palette.celadonAccent
                        )
                        atelierBadge(
                            text: "和声绽放 \(vm.stats.frissonPeakCount) 次",
                            symbol: "sparkles",
                            tint: palette.homeAnchor
                        )
                        atelierBadge(
                            text: "v\(appVersion)",
                            symbol: "checkmark.shield.fill",
                            tint: palette.nightLampGold
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showShareCard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                    Text("导出 1080×1350 离线共振纪念卡")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(palette.primaryInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
                .background(
                    RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                        .fill(palette.shelfSurface)
                )
                .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityHint("在本地渲染并保存或分享当前频率的高清纪念卡 PNG")
        }
        .padding(16)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    private func atelierBadge(text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(palette.isNight ? tint : tint.mix(with: palette.primaryInk, by: 0.20))
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(palette.isNight ? 0.16 : 0.10))
        )
    }

    // MARK: - 2. Original Kiln Acoustic Tools

    private var atelierToolsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "窑陶声学家族与夜灯",
                isNight: palette.isNight,
                tint: palette.homeAnchor
            )

            VStack(spacing: 0) {
                NavigationLink {
                    CharacterSoundTestView(
                        palette: palette,
                        scaleMode: vm.studioVM.document.scaleMode,
                        cradleEnabled: vm.studioVM.cradleEnabled,
                        onAuditionDuo: { vm.studioVM.auditionDuoCharacter($0) },
                        onAuditionMember: { vm.studioVM.auditionChimmoMember($0) }
                    )
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                                .fill(palette.storybookButter)
                                .frame(width: 40, height: 40)
                            ChimmoFigureView(
                                member: .taono,
                                isNight: palette.isNight,
                                isMinor: false,
                                isSinging: false,
                                time: 0
                            )
                            .scaleEffect(0.72)
                            .frame(width: 34, height: 34)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("咩哞与七声小偶试音台")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("轻触试听双子星与 1–7 音级窑陶原音")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryInk)
                        }

                        Spacer(minLength: 4)

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
                .accessibilityHint("进入双子咩哞与七声小偶互动试音页面")

                Divider().opacity(0.45).padding(.leading, 66)

                Button {
                    vm.openNightLampSheet = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: ChimmoRadius.tile, style: .continuous)
                                .fill(palette.nightLampBackdrop)
                                .frame(width: 40, height: 40)
                            ChimmoCraftMark(
                                .nightLampHalo,
                                color: palette.nightLampGold,
                                secondaryColor: Color(hex: 0xF2E2C4).opacity(0.72)
                            )
                            .frame(width: 20, height: 20)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("闭眼夜灯零光盲操")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("熄灯纯黑低亮度防蓝光滑奏音脊")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryInk)
                        }

                        Spacer(minLength: 4)

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
                .accessibilityHint("进入纯黑夜灯触觉声场")
            }
            .clipShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    // MARK: - 3. Daylight / Night Lamp / Auto Canvas Preview

    private var appearanceSwatchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ChimmoResonanceBead(size: 10, isNight: palette.isNight, tint: palette.nightLampGold)
                Text("画布外观")
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
                    .accessibilityHint("切换日间棉纸、夜间星灯或跟随系统外观")
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

    // MARK: - 4. Acoustic & Tactile Preferences

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

    // MARK: - 5. Guideline 1.4.1 Acoustic Safety & Legal Compliance Hub

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
                Text("「轻哼同频」功能完全在设备本地实时处理人声基频，不录音留存、不联网传输；即使不开启麦克风权限，也可以直接选择预设共振基频继续使用。如需关闭震动，可随时在「工坊 -> 掌心脑波触觉脉动」一键关闭。")
                    .font(.subheadline)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("声学安全与说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
