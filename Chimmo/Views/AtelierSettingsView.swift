import SwiftUI

/// Kiln Atelier Tab (Tab 3):
/// Listening insights, unified appearance & haptics controls, 7-member encyclopedia, and legal disclosures.
public struct AtelierSettingsView: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette

    @State private var showResetConfirmation: Bool = false
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    public init(vm: ResonanceViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2.0"
        return String(format: String(localized: "atelier_version_fmt", defaultValue: "咩哞 · Mie & Mou %@ · 100%% 本地离线"), short)
    }

    public var body: some View {
        let accent = vm.selectedBand.accentColor(isNight: palette.isNight)

        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette, tint: accent)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        listeningSummaryCard(accent: accent)

                        appearanceAndHapticsSection(accent: accent)

                        guildAndComplianceSection(accent: accent)

                        footerCrest
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(String(localized: "tab_atelier", defaultValue: "工坊"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Listening Summary Card

    private func listeningSummaryCard(accent: Color) -> some View {
        let snap = vm.stats.snapshot
        let reflection = ResonanceKinematics.gentleCompanionMessage(
            totalMinutes: snap.totalMinutes,
            frissonCount: snap.frissonReleasesCount,
            favoriteBand: vm.stats.favoriteBand
        )

        return VStack(alignment: .leading, spacing: 14) {
            ChimmoSectionTitle(
                title: String(localized: "atelier_summary_title", defaultValue: "聆听留痕"),
                detail: String(localized: "atelier_local_only", defaultValue: "仅存本机"),
                isNight: palette.isNight,
                tint: accent
            )

            Text(reflection)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if type >= .xxLarge {
                VStack(spacing: 8) {
                    statTile(value: "\(snap.totalMinutes)", label: String(localized: "stat_minutes", defaultValue: "专注分钟"), accent: accent)
                    statTile(value: "\(snap.sessionsCompleted)", label: String(localized: "stat_sessions", defaultValue: "完整伴眠"), accent: palette.celadonAccent)
                    statTile(value: "\(snap.frissonReleasesCount)", label: String(localized: "stat_frisson", defaultValue: "战栗释怀"), accent: palette.nightLampGold)
                }

                VStack(spacing: 10) {
                    Button {
                        vm.isCardSharePresented = true
                    } label: {
                        HStack(spacing: 6) {
                            ChimmoCraftMark(.cardSeal, color: palette.contrastInkOnAccent)
                                .frame(width: 15, height: 15)
                            Text(String(localized: "atelier_share_card", defaultValue: "生成今日明信片"))
                        }
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: true))

                    Button {
                        vm.isNightLampPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            ChimmoCraftMark(.nightLampHalo, color: palette.nightLampGold)
                                .frame(width: 15, height: 15)
                            Text(String(localized: "atelier_open_lamp", defaultValue: "琥珀夜灯"))
                        }
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chimmoVinyl(palette: palette, tint: palette.nightLampGold, prominent: false))
                }
            } else {
                HStack(spacing: 10) {
                    statTile(value: "\(snap.totalMinutes)", label: String(localized: "stat_minutes", defaultValue: "专注分钟"), accent: accent)
                    statTile(value: "\(snap.sessionsCompleted)", label: String(localized: "stat_sessions", defaultValue: "完整伴眠"), accent: palette.celadonAccent)
                    statTile(value: "\(snap.frissonReleasesCount)", label: String(localized: "stat_frisson", defaultValue: "战栗释怀"), accent: palette.nightLampGold)
                }

                HStack(spacing: 10) {
                    Button {
                        vm.isCardSharePresented = true
                    } label: {
                        HStack(spacing: 6) {
                            ChimmoCraftMark(.cardSeal, color: palette.contrastInkOnAccent)
                                .frame(width: 15, height: 15)
                            Text(String(localized: "atelier_share_card", defaultValue: "生成今日明信片"))
                        }
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chimmoVinyl(palette: palette, tint: accent, prominent: true))

                    Button {
                        vm.isNightLampPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            ChimmoCraftMark(.nightLampHalo, color: palette.nightLampGold)
                                .frame(width: 15, height: 15)
                            Text(String(localized: "atelier_open_lamp", defaultValue: "琥珀夜灯"))
                        }
                        .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .buttonStyle(.chimmoVinyl(palette: palette, tint: palette.nightLampGold, prominent: false))
                }
            }

            if snap.totalMinutes > 0 || snap.sessionsCompleted > 0 || snap.frissonReleasesCount > 0 {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text(String(localized: "atelier_reset_stats", defaultValue: "重置本机聆听统计"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: ChimmoAffordance.minHitTarget)
                }
                .confirmationDialog(
                    String(localized: "atelier_reset_confirm_title", defaultValue: "清空本机全部专注时长、伴眠与战栗记录？已收藏配方会保留。"),
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "atelier_reset_confirm_btn", defaultValue: "清空本地统计"), role: .destructive) {
                        vm.stats.resetAllStats()
                    }
                    Button(String(localized: "action_cancel", defaultValue: "取消"), role: .cancel) {}
                }
            }
        }
        .padding(16)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: accent)
    }

    private func statTile(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(accent)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous).fill(palette.insetStageSurface))
    }

    // MARK: - Appearance & Haptics Section

    private func appearanceAndHapticsSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: String(localized: "atelier_prefs_title", defaultValue: "外观与触觉手感"),
                detail: nil,
                isNight: palette.isNight,
                tint: accent
            )

            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "atelier_theme_label", defaultValue: "昼夜纸墨主题"))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)

                let increased = (contrast == .increased)
                let borderW = StorybookSurfaceClarityPolicy.borderLineWidth(isActive: false, reduceTransparency: reduceTransparency, increasedContrast: increased)
                let borderOpacity = StorybookSurfaceClarityPolicy.subtleBorderOpacity(isNight: palette.isNight, reduceTransparency: reduceTransparency, increasedContrast: increased)

                let modeCards = ForEach(ChimmoAppearanceMode.allCases) { mode in
                    let selected = (vm.appearanceMode == mode)
                    Button {
                        vm.appearanceMode = mode
                        if vm.hapticsEnabled { AcousticHapticsEngine.shared.playScrubTick() }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.subheadline.weight(.semibold))
                            Text(mode.badgeText)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                        .padding(.vertical, 6)
                        .foregroundStyle(selected ? palette.contrastInkOnAccent : palette.primaryInk)
                        .background(
                            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                                .fill(selected ? accent : palette.insetStageSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                                        .strokeBorder(
                                            selected ? (increased ? palette.primaryInk : accent) : palette.primaryInk.opacity(borderOpacity),
                                            lineWidth: selected && increased ? 2.0 : borderW
                                        )
                                )
                        )
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                    .accessibilityLabel(mode.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }

                if type >= .xxLarge {
                    VStack(spacing: 8) {
                        modeCards
                    }
                } else {
                    HStack(spacing: 8) {
                        modeCards
                    }
                }

                Divider().overlay(palette.divider)

                Toggle(isOn: $vm.hapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "atelier_haptics_title", defaultValue: "掌心声学微振反馈"))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text(String(localized: "atelier_haptics_sub", defaultValue: "转动频段与蓄积释怀时同步释放细腻 Core Haptics 触觉共振"))
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(accent)
            }
            .padding(16)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    // MARK: - Guild & Legal Hub Section

    private func guildAndComplianceSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ChimmoSectionTitle(
                title: String(localized: "atelier_kiln_hub", defaultValue: "声学工坊与合规边界"),
                detail: nil,
                isNight: palette.isNight,
                tint: accent
            )

            VStack(spacing: 10) {
                NavigationLink {
                    CharacterSoundTestView(palette: palette) { member in
                        vm.auditionChimmoMember(member)
                    }
                } label: {
                    hubRow(
                        icon: .frissonSeed,
                        title: String(localized: "guild_nav_title", defaultValue: "咩哞七小只图鉴"),
                        subtitle: String(localized: "atelier_guild_sub", defaultValue: "点击试听 1–7 音级毛毡琴声色与窑陶性格"),
                        tint: accent
                    )
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))

                NavigationLink {
                    ChimmoAcousticSafetyView(palette: palette)
                } label: {
                    hubRow(
                        icon: .speakerHeadphones,
                        title: String(localized: "safety_nav_title", defaultValue: "收听安全与非医疗边界"),
                        subtitle: String(localized: "atelier_safety_sub", defaultValue: "纯感官声学艺术体验，非医疗器械；含 40 Hz 高频听感留意说明"),
                        tint: palette.nightLampGold
                    )
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .privacy, palette: palette)
                } label: {
                    hubRow(
                        icon: .cardSeal,
                        title: String(localized: "legal_privacy_title", defaultValue: "隐私与安全声明"),
                        subtitle: String(localized: "atelier_privacy_sub", defaultValue: "100% 本地离线零联网 · 仅声明 CA92.1 与 35F9.1"),
                        tint: palette.celadonAccent
                    )
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .terms, palette: palette)
                } label: {
                    hubRow(
                        icon: .appearanceDial,
                        title: String(localized: "legal_terms_title", defaultValue: "使用条款"),
                        subtitle: String(localized: "atelier_terms_sub", defaultValue: "自愿聆听约定与静态 PNG 明信片分享授权"),
                        tint: accent
                    )
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .licenses, palette: palette)
                } label: {
                    hubRow(
                        icon: .soundLibrary,
                        title: String(localized: "legal_licenses_title", defaultValue: "公版谱源与致谢"),
                        subtitle: String(localized: "atelier_licenses_sub", defaultValue: "公版古典曲谱索引、vDSP 纯 Swift 算法与版权说明"),
                        tint: palette.harmonyWash
                    )
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            }
        }
    }

    private func hubRow(icon: ChimmoCraftSymbol, title: String, subtitle: String, tint: Color) -> some View {
        let highClarity = reduceTransparency || contrast == .increased
        let showWash = StorybookSurfaceClarityPolicy.showsTranslucentTintWash(reduceTransparency: highClarity)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(showWash ? tint.opacity(palette.isNight ? 0.22 : 0.12) : palette.insetStageSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(tint.opacity(highClarity ? 0.65 : 0.0), lineWidth: 1.25)
                    )
                    .frame(width: 40, height: 40)
                ChimmoCraftMark(icon, color: tint)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryInk)
        }
        .padding(14)
        .frame(minHeight: ChimmoAffordance.minHitTarget)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    private var footerCrest: some View {
        VStack(spacing: 8) {
            KilnDuoBrandCrestView(palette: palette, size: 30)
            Text(appVersionLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}
