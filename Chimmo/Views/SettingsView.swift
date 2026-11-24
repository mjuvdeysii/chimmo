import SwiftUI

/// 商业软件级「设置与关于」原生页（严格对齐 Apple HIG Settings / Lists & Tables 规范：零渐层、零虚影、零 Emoji、清晰系统语义）。
public struct SettingsView: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette
    public let onOpenSharePostcard: () -> Void

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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.53.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        SettingsBrandMarkView(isNight: palette.isNight)
                            .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("咩哞 · Chimmo")
                                .font(.headline)
                            Text("离线声学音乐绘本与轻创作工具")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("版本 \(appVersion) (\(appBuild))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("偏好设置") {
                    Picker("外观显示", selection: $vm.appearance) {
                        ForEach(AppearancePreference.allCases) { pref in
                            Text(pref.label).tag(pref)
                        }
                    }
                    .accessibilityHint("选择白天纸艺、夜间星灯或跟随系统外观")

                    Picker("舞台默认视图", selection: $vm.visualMode) {
                        ForEach(StageVisualMode.displayOrder) { mode in
                            Text(mode.storybookLabel).tag(mode)
                        }
                    }
                    .accessibilityHint("选择进入应用时的主舞台画境样式")

                    Toggle("节拍触感反馈", isOn: $vm.musicHapticsEnabled)
                        .accessibilityHint("点按音珠与切换拍点时触发轻量触觉")

                    Toggle("五音防跑调保护", isOn: $vm.pentatonicSafe)
                        .accessibilityHint("创作与跟弹时自动避开半音碰撞")
                }

                Section("作品与导出") {
                    LabeledContent("已保存作品", value: "\(vm.notebook.entries.count) 首")
                    LabeledContent("存储方式", value: "仅本机离线")

                    Button {
                        onOpenSharePostcard()
                    } label: {
                        Label("导出当前作品 (PNG / WAV / MIDI)", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityHint("打开明信片图片与音频工程导出面板")
                }

                Section("隐私与法律") {
                    NavigationLink("隐私政策") {
                        ChimmoLegalDocumentView(kind: .privacy)
                    }
                    NavigationLink("使用条款") {
                        ChimmoLegalDocumentView(kind: .terms)
                    }
                    NavigationLink("开源许可与曲目鸣谢") {
                        ChimmoLegalDocumentView(kind: .licenses)
                    }
                }

                Section {
                    NavigationLink {
                        CharacterSoundTestView(
                            palette: palette,
                            scaleMode: vm.document.scaleMode,
                            cradleEnabled: vm.cradleEnabled,
                            onAuditionDuo: { vm.auditionDuoCharacter($0) },
                            onAuditionMember: { vm.auditionChimmoMember($0) }
                        )
                    } label: {
                        Label("声音角色图鉴", systemImage: "music.mic")
                    }
                    .accessibilityHint("试听小羊咩、小牛哞与七小只音阶")

                    if let siteURL = URL(string: "https://mjuvdeysii.github.io/chimmo/") {
                        Link(destination: siteURL) {
                            HStack {
                                Label("官方网站", systemImage: "globe")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let issuesURL = URL(string: "https://github.com/mjuvdeysii/chimmo/issues") {
                        Link(destination: issuesURL) {
                            HStack {
                                Label("问题反馈与支持", systemImage: "bubble.left.and.text.bubble.right")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    LabeledContent("版本信息", value: "v\(appVersion) (\(appBuild))")
                } header: {
                    Text("关于与支持")
                } footer: {
                    Text("咩哞 · Chimmo 完全在本机离线运行，无需登录，不上传任何录音或个人数据。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
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

/// 声音角色图鉴子页面（保留互动试听惊喜，同时避免混入商业「设置」首页）。
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
        List {
            Section("双子主创") {
                ForEach(ChimmoDuoCharacter.allCases) { character in
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
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(character.roleShort)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "speaker.wave.2.fill")
                                .font(.subheadline)
                                .foregroundStyle(isAuditioning ? Color.accentColor : .secondary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: auditioningDuo)
                    .accessibilityLabel("\(character.chineseName)，\(character.roleShort)")
                    .accessibilityValue(isAuditioning ? "正在试听" : "")
                    .accessibilityHint("轻点试听双子角色音色")
                }
            }

            Section("调内七小只音阶家族") {
                ForEach(ChimmoMember.allCases) { member in
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
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(memberRole)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundStyle(isSinging ? Color.accentColor : .secondary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: focusedMemberDegree)
                    .accessibilityLabel("\(member.degree) \(member.solfege) \(member.chineseName)，\(memberRole)")
                    .accessibilityValue(isSinging ? "正在发音" : "")
                    .accessibilityHint("轻点试听\(member.chineseName)的音级")
                }
            }
        }
        .listStyle(.insetGrouped)
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

/// 精简商业级品牌图标缩略图（纯扁平 1-3-5 三人组剪影，无渐变、无虚影）。
private struct SettingsBrandMarkView: View {
    let isNight: Bool

    var body: some View {
        let p = ChimmoPalette(isNight: isNight)
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isNight ? Color(hex: 0x101733) : Color(hex: 0xFFFDF7))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(p.cartoonOutline.opacity(0.24), lineWidth: 1.0)
                )

            HStack(alignment: .bottom, spacing: 2) {
                Circle()
                    .fill(ChimmoMember.plokko.bodyColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(p.cartoonOutline, lineWidth: 1.1))
                Circle()
                    .fill(ChimmoMember.taono.bodyColor)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().strokeBorder(p.cartoonOutline, lineWidth: 1.2))
                Circle()
                    .fill(ChimmoMember.corllo.bodyColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(p.cartoonOutline, lineWidth: 1.1))
            }
        }
        .accessibilityHidden(true)
    }
}
