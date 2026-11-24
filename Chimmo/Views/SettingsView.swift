import SwiftUI

/// 商业软件级「工坊」主页（与「摸索台灯 · YouView」一脉相承的绘本纸感与信息条理性）：
/// 1) 品牌身份卡（窑陶 1-3-5 徽章 + 创作计数徽标）
/// 2) 主题哲学与七声音阶剧场入口（「轻哼成曲，七声和鸣」）
/// 3) 可视化外观切换卡（日光棉纸 / 夜灯深靛 / 跟随系统三联微型画布预览）
/// 4) 工坊偏好设置卡（默认舞台画境 / 五音保护 / 触感反馈 / PNG-WAV-MIDI 导出）
/// 5) 商业级离线透明与法务文档入口（隐私政策 / 使用条款 / 开源与曲库鸣谢 / 官网与支持）
public struct SettingsView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenSharePostcard: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        vm: StudioViewModel,
        palette: ChimmoPalette,
        onOpenSharePostcard: @escaping () -> Void = {}
    ) {
        self.vm = vm
        self.palette = palette
        self.onOpenSharePostcard = onOpenSharePostcard
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.57.0"
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
                    VStack(alignment: .leading, spacing: 14) {
                        brandIdentityCard

                        ensemblePhilosophyBanner

                        appearanceSwatchCard

                        preferencesCard

                        transparencyDock
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("工坊")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 1. Brand Identity Card

    private var brandIdentityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                SettingsBrandMarkView(isNight: palette.isNight)
                    .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text("咩哞 · Chimmo")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)

                    Text("离线声学音乐绘本与轻创作工具")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryInk)

                    ChimmoFlowRow(spacing: 6, lineSpacing: 5) {
                        atelierBadge(
                            text: "已创作 \(vm.notebook.entries.count) 首",
                            symbol: "music.note",
                            tint: palette.homeAnchor
                        )
                        atelierBadge(
                            text: "\(SpecimenLibrary.all.count) 首典藏",
                            symbol: "books.vertical.fill",
                            tint: palette.celadonAccent
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
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(palette.isNight ? tint : tint.mix(with: palette.primaryInk, by: 0.20))
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(tint.opacity(palette.isNight ? 0.22 : 0.13))
        )
    }

    // MARK: - 2. Philosophy & Seven-Voice Theater Banner

    private var ensemblePhilosophyBanner: some View {
        NavigationLink {
            CharacterSoundTestView(
                palette: palette,
                scaleMode: vm.document.scaleMode,
                cradleEnabled: vm.cradleEnabled,
                onAuditionDuo: { vm.auditionDuoCharacter($0) },
                onAuditionMember: { vm.auditionChimmoMember($0) }
            )
        } label: {
            HStack(spacing: 12) {
                LivingChimmoDuoBadgeView(
                    isNight: palette.isNight,
                    accentColor: palette.homeAnchor,
                    melodyActive: false,
                    cowAwake: vm.cradleEnabled
                )
                .frame(width: 68, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("轻哼成曲，七声和鸣")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("认识双子咩哞与调内七小只，轻触试听七声音阶与和声性格")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk.opacity(0.65))
            }
            .padding(14)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: palette.homeAnchor)
            .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.4))
        .accessibilityLabel("声音角色图鉴，轻哼成曲，七声和鸣")
        .accessibilityHint("试听小羊咩、小牛哞与七小只音阶")
    }

    // MARK: - 3. Visual Appearance Swatches (Mossling Spin-Off Twin)

    private var appearanceSwatchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ChimmoResonanceBead(size: 10, isNight: palette.isNight, tint: palette.nightLampGold)
                Text("外观")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                Spacer()
                Text(vm.appearance.label)
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
                    let active = vm.appearance == pref
                    Button {
                        vm.appearance = pref
                        AcousticHapticsEngine.shared.playScrubTick()
                    } label: {
                        appearanceSwatchTile(for: pref, active: active)
                    }
                    .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
                    .accessibilityLabel("外观显示 \(pref.label)")
                    .accessibilityValue(active ? "已选中" : "")
                    .accessibilityHint("选择白天纸艺、夜间星灯或跟随系统外观")
                }
            }
        }
        .padding(14)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
    }

    private func appearanceSwatchTile(for pref: AppearancePreference, active: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
        return ZStack(alignment: .bottom) {
            Group {
                switch pref {
                case .daylight:
                    daySwatchCanvas
                case .nightLamp:
                    nightSwatchCanvas
                case .auto:
                    HStack(spacing: 0) {
                        daySwatchCanvas
                        nightSwatchCanvas
                    }
                }
            }
            .frame(height: 66)
            .clipShape(shape)

            HStack(spacing: 4) {
                Image(systemName: appearanceSymbol(for: pref))
                    .font(.caption2.weight(.bold))
                Text(pref.label)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(pref == .nightLamp ? Color(hex: 0xF2E2C4) : (pref == .daylight ? Color(hex: 0x1C1D19) : palette.primaryInk))
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill((pref == .nightLamp ? Color(hex: 0x19213F) : (pref == .daylight ? Color(hex: 0xFFFFFF) : palette.cardSurface)).opacity(0.92))
            )
            .padding(.bottom, 7)

            if active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.homeAnchor)
                    .background(Circle().fill(palette.cardSurface).padding(1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }
        }
        .overlay(
            shape
                .strokeBorder(
                    active ? palette.homeAnchor : palette.primaryInk.opacity(palette.isNight ? 0.14 : 0.08),
                    lineWidth: active ? 2.0 : 1.0
                )
        )
        .contentShape(shape)
    }

    private var daySwatchCanvas: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0xFBF7F0)
            Circle()
                .fill(Color(hex: 0xC4513A).opacity(0.22))
                .frame(width: 24, height: 24)
                .offset(x: 18, y: -28)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xE5ECE5))
                .frame(height: 18)
                .offset(y: 4)
        }
    }

    private var nightSwatchCanvas: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: 0x0E1430)
            Circle()
                .fill(Color(hex: 0xFFB547).opacity(0.32))
                .frame(width: 34, height: 34)
                .offset(x: 8, y: -8)
            Circle()
                .fill(Color(hex: 0xFFB547))
                .frame(width: 6, height: 6)
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
    }

    private func appearanceSymbol(for pref: AppearancePreference) -> String {
        switch pref {
        case .auto: return "circle.lefthalf.filled"
        case .daylight: return "sun.max.fill"
        case .nightLamp: return "lamp.desk.fill"
        }
    }

    // MARK: - 4. Studio Preferences Card

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "声学与舞台设定",
                isNight: palette.isNight,
                tint: palette.celadonAccent
            )

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    prefIconTile(symbol: vm.visualMode.iconName, tint: palette.celadonAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("舞台默认视图")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryInk)
                        Text("进入「聆听」时的默认画境")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                    }

                    Spacer(minLength: 4)

                    Picker("舞台默认视图", selection: $vm.visualMode) {
                        ForEach(StageVisualMode.displayOrder) { mode in
                            Text(mode.storybookLabel).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(palette.homeAnchor)
                    .accessibilityHint("选择进入应用时的主舞台画境样式")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Divider().opacity(0.45).padding(.leading, 56)

                HStack(spacing: 12) {
                    prefIconTile(symbol: "shield.lefthalf.filled", tint: palette.homeAnchor)

                    Toggle(isOn: $vm.pentatonicSafe) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("五音防跑调保护")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("创作与跟弹时自动避开半音碰撞")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }
                    }
                    .tint(palette.homeAnchor)
                    .accessibilityHint("创作与跟弹时自动避开半音碰撞")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().opacity(0.45).padding(.leading, 56)

                HStack(spacing: 12) {
                    prefIconTile(symbol: "hand.tap.fill", tint: palette.bassRibbon)

                    Toggle(isOn: $vm.musicHapticsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("节拍触感反馈")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("点按音珠与拍点触发细腻触觉")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }
                    }
                    .tint(palette.homeAnchor)
                    .accessibilityHint("点按音珠与切换拍点时触发轻量触觉")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().opacity(0.45).padding(.leading, 56)

                Button {
                    onOpenSharePostcard()
                } label: {
                    HStack(spacing: 12) {
                        prefIconTile(symbol: "square.and.arrow.up", tint: palette.nightLampGold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("导出当前作品 (PNG / WAV / MIDI)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryInk)
                            Text("目前曲本共收藏 \(vm.notebook.entries.count) 首")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryInk)
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.secondaryInk.opacity(0.65))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("打开明信片图片与音频工程导出面板")
            }
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
        }
    }

    private func prefIconTile(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(palette.isNight ? 0.24 : 0.14))
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.isNight ? tint : tint.mix(with: palette.primaryInk, by: 0.20))
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    // MARK: - 5. Commercial-Grade Offline Transparency & Legal Hub

    private var transparencyDock: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChimmoSectionTitle(
                title: "隐私与文档",
                detail: "v\(appVersion) (\(appBuild))",
                isNight: palette.isNight,
                tint: palette.harmonyWash
            )

            let cols: [GridItem] = dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

            LazyVGrid(columns: cols, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    prefIconTile(symbol: "lock.shield.fill", tint: palette.celadonAccent)
                    Text("仅本机离线")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text("零账号、零上传与广告")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .licenses)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            prefIconTile(symbol: "books.vertical.fill", tint: palette.harmonyWash)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.secondaryInk.opacity(0.65))
                        }
                        Text("开源与曲目鸣谢")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("SwiftF0 MIT · 28 首自洁谱面")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                    .contentShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
                }
                .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            }

            VStack(spacing: 0) {
                NavigationLink {
                    ChimmoLegalDocumentView(kind: .privacy)
                } label: {
                    legalLinkRow(title: "隐私政策", symbol: "hand.raised.fill", tint: palette.celadonAccent)
                }
                .buttonStyle(.plain)

                Divider().opacity(0.45).padding(.leading, 56)

                NavigationLink {
                    ChimmoLegalDocumentView(kind: .terms)
                } label: {
                    legalLinkRow(title: "使用条款", symbol: "doc.text.fill", tint: palette.nightLampGold)
                }
                .buttonStyle(.plain)

                if let siteURL = URL(string: "https://mjuvdeysii.github.io/chimmo/") {
                    Divider().opacity(0.45).padding(.leading, 56)

                    Link(destination: siteURL) {
                        legalExternalRow(title: "官方网站", symbol: "globe", tint: palette.bassRibbon)
                    }
                }

                if let issuesURL = URL(string: "https://github.com/mjuvdeysii/chimmo/issues") {
                    Divider().opacity(0.45).padding(.leading, 56)

                    Link(destination: issuesURL) {
                        legalExternalRow(title: "问题反馈与支持", symbol: "bubble.left.and.text.bubble.right", tint: palette.homeAnchor)
                    }
                }
            }
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)

            Text("咩哞 · Chimmo 完全在本机离线运行，无需登录，不上传任何录音或个人数据。")
                .font(.footnote)
                .foregroundStyle(palette.secondaryInk)
                .padding(.horizontal, 4)
        }
    }

    private func legalLinkRow(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            prefIconTile(symbol: symbol, tint: tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryInk)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryInk.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func legalExternalRow(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            prefIconTile(symbol: symbol, tint: tint)
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

/// 法律、隐私与开源协议正文页（原生 `insetGrouped` 商业排版标准，文案严格对齐官网静态法务页）。
public struct ChimmoLegalDocumentView: View {
    public enum LegalDocumentKind: String, Identifiable, CaseIterable, Sendable {
        case privacy
        case terms
        case licenses

        public var id: String { rawValue }

        public var navigationTitle: String {
            switch self {
            case .privacy: return "隐私政策"
            case .terms: return "使用条款"
            case .licenses: return "开源许可与曲目鸣谢"
            }
        }
    }

    public let kind: LegalDocumentKind

    public init(kind: LegalDocumentKind) {
        self.kind = kind
    }

    public var body: some View {
        List {
            switch kind {
            case .privacy:
                privacySections
            case .terms:
                termsSections
            case .licenses:
                licensesSections
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(kind.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var privacySections: some View {
        Section {
            LabeledContent("生效日期", value: "2026 年 11 月 21 日")
            LabeledContent("最近修订", value: "2026 年 11 月 24 日")
        }

        Section("1. 核心原则：不联网、不收集任何数据") {
            Text("咩哞（Chimmo）是一款完全在您的设备本地离线运行的音乐创作与可视化应用。我们不设账号系统，不连接任何远程服务器，不包含任何广告、统计分析或第三方追踪 SDK。")
                .font(.subheadline)
        }

        Section("2. 麦克风权限的使用") {
            Text("当您使用「哼唱捉珠」功能时，应用会向 iOS 系统请求麦克风访问权限。您哼唱的音频信号仅在设备本机内存中实时转换为音高与音珠，从不上传、不外发，也不会用于任何云端训练或个人身份识别。您随时可以在系统「设置 > 隐私与安全性 > 麦克风」中撤回权限。")
                .font(.subheadline)
        }

        Section("3. 本地存储与离线导出") {
            Text("您在应用内创作或调整的旋律仅保存在您的设备本机。只有当您主动使用系统分享菜单导出绘本明信片（PNG）、立体声音频（WAV）或标准 MIDI 文件时，对应文件才会通过您指定的系统方式分享。")
                .font(.subheadline)
        }

        Section("在线文档与支持") {
            if let url = URL(string: "https://mjuvdeysii.github.io/chimmo/privacy.html") {
                Link("查看网页版隐私政策", destination: url)
            }
            if let issuesURL = URL(string: "https://github.com/mjuvdeysii/chimmo/issues") {
                Link("GitHub Issues 联系开发者", destination: issuesURL)
            }
        }
    }

    @ViewBuilder
    private var termsSections: some View {
        Section {
            LabeledContent("生效日期", value: "2026 年 11 月 21 日")
        }

        Section("1. 创作归属") {
            Text("您使用咩哞（Chimmo）自行哼唱、点按或编排并导出的原创旋律、PNG 卡片、WAV 音频与标准 MIDI 作品，其著作权完全归您本人所有。")
                .font(.subheadline)
        }

        Section("2. 应用与 IP 权利") {
            Text("应用内的「咩哞七小只（陶诺、豆叩、拍咯、呜嘟、壳咯、钵莫、叮尖）」以及小羊咩、小牛哞角色造型、视觉设计、文案与原创代码受著作权保护。")
                .font(.subheadline)
        }

        Section("3. 免责声明") {
            Text("本应用按“现状”提供，完全在设备本地离线运行。开发者不对因设备硬件故障或系统升级导致的本地临时草图丢失承担赔偿责任。")
                .font(.subheadline)
        }

        Section("在线文档") {
            if let url = URL(string: "https://mjuvdeysii.github.io/chimmo/terms.html") {
                Link("查看网页版使用条款", destination: url)
            }
        }
    }

    @ViewBuilder
    private var licensesSections: some View {
        Section("1. SwiftF0 (MIT License)") {
            Text("本应用中的动态规划音符切分算法（SwiftF0NoteSegmenter.swift）参考并移植自开源项目 lars76/swift-f0（MIT License）。")
                .font(.subheadline)

            Text(
"""
MIT License

Copyright (c) 2025 Lars Nieradzik

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
"""
            )
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }

        Section("2. 内置曲库与版权边界") {
            Text("内置 20 首古典名曲（圣桑《天鹅》、李斯特、巴赫、柴可夫斯基、德彪西、肖邦、德沃夏克、萨蒂、贝多芬、舒伯特、帕赫贝尔、莫扎特等）均为作者逝世逾百年的全球公有领域乐谱独立编配。")
                .font(.subheadline)
            Text("内置 8 首夏日治愈与现代技法曲目均为本项目 100% 原创，不含任何受版权保护的现代影视或流行作品旋律。")
                .font(.subheadline)
        }

        Section("在线文档") {
            if let url = URL(string: "https://mjuvdeysii.github.io/chimmo/licenses.html") {
                Link("查看网页版开源许可", destination: url)
            }
        }
    }
}

/// 声音角色图鉴子页面（保留互动试听惊喜，同时与工坊绘本纸卡语系完全统一）。
public struct CharacterSoundTestView: View {
    public let palette: ChimmoPalette
    public let scaleMode: ScaleMode
    public let cradleEnabled: Bool
    public let onAuditionDuo: (ChimmoDuoCharacter) -> Void
    public let onAuditionMember: (ChimmoMember) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedMemberDegree: Int? = nil
    @State private var auditioningDuo: ChimmoDuoCharacter? = nil
    @State private var resetTask: Task<Void, Never>? = nil

    public init(
        palette: ChimmoPalette,
        scaleMode: ScaleMode = .brightMajor,
        cradleEnabled: Bool = true,
        onAuditionDuo: @escaping (ChimmoDuoCharacter) -> Void = { _ in },
        onAuditionMember: @escaping (ChimmoMember) -> Void = { _ in }
    ) {
        self.palette = palette
        self.scaleMode = scaleMode
        self.cradleEnabled = cradleEnabled
        self.onAuditionDuo = onAuditionDuo
        self.onAuditionMember = onAuditionMember
    }

    public var body: some View {
        let skyColor = scaleMode.skyAuroraColor(isNight: palette.isNight)
        ZStack {
            AmbientPaperBackdrop(palette: palette, accentTint: palette.homeAnchor)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ChimmoSectionTitle(
                        title: "双子主创",
                        detail: "轻触试听声部",
                        isNight: palette.isNight,
                        tint: palette.homeAnchor
                    )

                    VStack(spacing: 0) {
                        ForEach(Array(ChimmoDuoCharacter.allCases.enumerated()), id: \.element.id) { idx, character in
                            let isAuditioning = auditioningDuo == character
                            Button {
                                auditioningDuo = character
                                onAuditionDuo(character)
                                scheduleReset()
                            } label: {
                                HStack(spacing: 12) {
                                    Group {
                                        if character == .mie {
                                            ChimmoSheepView(
                                                isNight: palette.isNight,
                                                accentColor: skyColor,
                                                isSinging: auditioningDuo == .mie,
                                                phaseTime: 0
                                            )
                                        } else {
                                            ChimmoCowView(
                                                isNight: palette.isNight,
                                                accentColor: skyColor,
                                                isAwake: cradleEnabled,
                                                isPlaying: auditioningDuo == .mou,
                                                phaseTime: 0
                                            )
                                        }
                                    }
                                    .frame(width: 44, height: 34)
                                    .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(character.chineseName)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(palette.primaryInk)
                                        Text(character.roleShort)
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryInk)
                                    }

                                    Spacer()

                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(isAuditioning ? palette.homeAnchor : palette.secondaryInk)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(minHeight: 54)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: auditioningDuo)
                            .accessibilityLabel("\(character.chineseName)，\(character.roleShort)")
                            .accessibilityValue(isAuditioning ? "正在试听" : "")
                            .accessibilityHint("轻点试听双子角色音色")

                            if idx + 1 < ChimmoDuoCharacter.allCases.count {
                                Divider().opacity(0.45).padding(.leading, 68)
                            }
                        }
                    }
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)

                    ChimmoSectionTitle(
                        title: "调内七小只音阶家族",
                        detail: "首调 1–7",
                        isNight: palette.isNight,
                        tint: palette.celadonAccent
                    )

                    VStack(spacing: 0) {
                        ForEach(Array(ChimmoMember.allCases.enumerated()), id: \.element.id) { idx, member in
                            let isSinging = focusedMemberDegree == member.degree
                            let memberRole = member.isTriadPillar ? "主和弦家族定锚" : (member.isTensionDegree ? "天然张力倾向音" : "色彩过渡音")
                            Button {
                                focusedMemberDegree = member.degree
                                onAuditionMember(member)
                                scheduleReset()
                            } label: {
                                HStack(spacing: 12) {
                                    ChimmoFigureView(
                                        member: member,
                                        isNight: palette.isNight,
                                        isMinor: scaleMode.isMinorFlavored,
                                        isSinging: isSinging,
                                        focusedDegree: focusedMemberDegree,
                                        time: 0,
                                        listeningTilt: 0
                                    )
                                    .scaleEffect(0.72)
                                    .frame(width: 36, height: 36)
                                    .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(member.degree) \(member.solfege) · \(member.chineseName)")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(palette.primaryInk)
                                        Text(memberRole)
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryInk)
                                    }

                                    Spacer()

                                    Image(systemName: "play.fill")
                                        .font(.caption)
                                        .foregroundStyle(isSinging ? palette.homeAnchor : palette.secondaryInk)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: focusedMemberDegree)
                            .accessibilityLabel("\(member.degree) \(member.solfege) \(member.chineseName)，\(memberRole)")
                            .accessibilityValue(isSinging ? "正在发音" : "")
                            .accessibilityHint("轻点试听\(member.chineseName)的音级")

                            if idx + 1 < ChimmoMember.allCases.count {
                                Divider().opacity(0.45).padding(.leading, 62)
                            }
                        }
                    }
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("声音角色图鉴")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            resetTask?.cancel()
            resetTask = nil
        }
    }

    private func scheduleReset() {
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            if !Task.isCancelled {
                focusedMemberDegree = nil
                auditioningDuo = nil
            }
        }
    }
}

/// 商业级窑陶品牌印记徽章（1-3-5 三人组居中陈列，无厚重黑色漫画框）。
private struct SettingsBrandMarkView: View {
    let isNight: Bool

    var body: some View {
        let p = ChimmoPalette(isNight: isNight)
        ZStack {
            RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                .fill(isNight ? Color(hex: 0x161E3B) : Color(hex: 0xFBF7F0))
                .overlay(
                    RoundedRectangle(cornerRadius: ChimmoRadius.inner, style: .continuous)
                        .strokeBorder(
                            isNight ? Color(hex: 0xFFB547).opacity(0.28) : Color(hex: 0xC4513A).opacity(0.20),
                            lineWidth: 1.0
                        )
                )

            HStack(alignment: .bottom, spacing: 2.5) {
                Circle()
                    .fill(ChimmoMember.plokko.bodyColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(p.primaryInk.opacity(0.45), lineWidth: 0.9))
                Circle()
                    .fill(ChimmoMember.taono.bodyColor)
                    .frame(width: 17, height: 17)
                    .overlay(Circle().strokeBorder(p.primaryInk.opacity(0.45), lineWidth: 1.0))
                Circle()
                    .fill(ChimmoMember.corllo.bodyColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(p.primaryInk.opacity(0.45), lineWidth: 0.9))
            }
        }
        .accessibilityHidden(true)
    }
}
