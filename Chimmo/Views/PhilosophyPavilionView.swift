import SwiftUI

public enum PhilosophyInstallation: Int, CaseIterable, Identifiable, Sendable {
    case oneNoteFiveLives = 1
    case waveSymmetryHaptics = 2
    case halfSecondTear = 3
    case fiveSkiesSpectrum = 4
    case threeNoteOrigami = 5
    case swanWaterDialogue = 6

    public var id: Int { rawValue }

    public var romanNumeral: String {
        switch self {
        case .oneNoteFiveLives: return "I"
        case .waveSymmetryHaptics: return "II"
        case .halfSecondTear: return "III"
        case .fiveSkiesSpectrum: return "IV"
        case .threeNoteOrigami: return "V"
        case .swanWaterDialogue: return "VI"
        }
    }

    public var title: String {
        switch self {
        case .oneNoteFiveLives: return "一颗音的五种人生"
        case .waveSymmetryHaptics: return "波纹对称与掌心震动"
        case .halfSecondTear: return "半秒迟到，一滴泪诞生"
        case .fiveSkiesSpectrum: return "一根弦上的五片天空"
        case .threeNoteOrigami: return "三颗音的折纸森林"
        case .swanWaterDialogue: return "圣桑水波与巴赫对话"
        }
    }

    public var axiomTag: String {
        switch self {
        case .oneNoteFiveLives: return "关系哲学 · 和声的本质"
        case .waveSymmetryHaptics: return "物理哲学 · 声波整数比 × 触觉"
        case .halfSecondTear: return "时间哲学 · 催泪延留音"
        case .fiveSkiesSpectrum: return "光线哲学 · 五色天光光谱"
        case .threeNoteOrigami: return "分形哲学 · 种子长成乐章"
        case .swanWaterDialogue: return "留白哲学 · 织体与复调对话"
        }
    }

    public var hookQuote: String {
        switch self {
        case .oneNoteFiveLives: return "同一颗音纹丝不动，换掉脚下的世界，悲喜瞬间改写。"
        case .waveSymmetryHaptics: return "和谐不是规矩，是波纹的几何静止；在掌心直接摸到它。"
        case .halfSecondTear: return "按住那颗不肯走的音多赖半秒，再滑落——听见鼻酸瞬间。"
        case .fiveSkiesSpectrum: return "每挪动 1 只咩哞半步，就开启一片全新电影天空。"
        case .threeNoteOrigami: return "大师并非写了 200 个音，而是把 3 颗种子折成整座森林。"
        case .swanWaterDialogue: return "单独拨开大提琴、天鹅水波与影子对位，看懂留白之美。"
        }
    }

    public var accentHex: UInt32 {
        switch self {
        case .oneNoteFiveLives: return 0xF25563
        case .waveSymmetryHaptics: return 0x228BE6
        case .halfSecondTear: return 0xE64980
        case .fiveSkiesSpectrum: return 0x12B886
        case .threeNoteOrigami: return 0xF7882F
        case .swanWaterDialogue: return 0x7950F2
        }
    }

    public var iconName: String {
        switch self {
        case .oneNoteFiveLives: return "sun.and.horizon.fill"
        case .waveSymmetryHaptics: return "atom"
        case .halfSecondTear: return "drop.fill"
        case .fiveSkiesSpectrum: return "rainbow"
        case .threeNoteOrigami: return "leaf.fill"
        case .swanWaterDialogue: return "water.waves"
        }
    }
}

/// 音符哲学体验馆：6 座全感官互动声学装置（光影 + 五声部室内乐 + Core Haptics 触觉共振）。
/// 摒弃枯燥术语考卷，让完全不懂乐理的音乐爱好者直接用眼睛、耳朵和掌心触摸音符世界的底层逻辑哲学。
public struct PhilosophyPavilionView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @Binding public var visitedInstallations: Set<Int>
    public let onSendOrigamiToWorkbench: ([NoteBead], ScaleMode) -> Void
    public let onOpenSwanInWorkbench: () -> Void
    public let onOpenDecoupledCapture: () -> Void

    @State private var activeInstallation: PhilosophyInstallation? = nil
    @State private var showBasicsSheet: Bool = false
    @State private var completedBasicChapters: Set<Int> = Set(UserDefaults.standard.array(forKey: "chimmo_completed_chapters") as? [Int] ?? [])

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        visitedInstallations: Binding<Set<Int>>,
        onSendOrigamiToWorkbench: @escaping ([NoteBead], ScaleMode) -> Void,
        onOpenSwanInWorkbench: @escaping () -> Void,
        onOpenDecoupledCapture: @escaping () -> Void
    ) {
        self.palette = palette
        self.synth = synth
        self._visitedInstallations = visitedInstallations
        self.onSendOrigamiToWorkbench = onSendOrigamiToWorkbench
        self.onOpenSwanInWorkbench = onOpenSwanInWorkbench
        self.onOpenDecoupledCapture = onOpenDecoupledCapture
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pavilionHeroBanner

                    LazyVStack(spacing: 12) {
                        ForEach(PhilosophyInstallation.allCases) { inst in
                            installationCard(inst)
                        }
                    }
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("音符哲学馆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBasicsSheet = true
                    } label: {
                        Label("基础 8 课", systemImage: "graduationcap")
                    }
                }
            }
            .sheet(isPresented: $showBasicsSheet) {
                TheoryJourneyView(
                    palette: palette,
                    synth: synth,
                    completedChapters: $completedBasicChapters,
                    onJumpToCapture: {
                        showBasicsSheet = false
                        onOpenDecoupledCapture()
                    },
                    onOpenSwanMasterpiece: {
                        showBasicsSheet = false
                        onOpenSwanInWorkbench()
                    }
                )
            }
            .fullScreenCover(item: $activeInstallation) { inst in
                InstallationFullScreenStage(
                    installation: inst,
                    palette: palette,
                    synth: synth,
                    onMarkVisited: {
                        visitedInstallations.insert(inst.rawValue)
                        UserDefaults.standard.set(Array(visitedInstallations), forKey: "chimmo_visited_philosophy")
                    },
                    onSwitchInstallation: { next in
                        activeInstallation = next
                    },
                    onSendOrigamiToWorkbench: { beads, mode in
                        activeInstallation = nil
                        onSendOrigamiToWorkbench(beads, mode)
                    },
                    onOpenSwan: {
                        activeInstallation = nil
                        onOpenSwanInWorkbench()
                    }
                )
                .id(inst.id)
            }
        }
    }

    private var pavilionHeroBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("看见音符世界的底层哲学")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                Spacer()
                Text("已漫游 \(visitedInstallations.count)/\(PhilosophyInstallation.allCases.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.homeAnchor.opacity(0.16)))
                    .foregroundStyle(palette.homeAnchor)
            }

            Text("不懂乐理不是缺陷——你早就听得懂音乐里的悲喜与呼吸。走进下面 6 座声学哲学装置，用眼睛、耳朵和 iPhone 掌心震动，亲手触摸音符宇宙背后的 6 条自然法则。")
                .font(.caption)
                .foregroundStyle(palette.secondaryInk)

            HStack(spacing: 10) {
                Button {
                    activeInstallation = PhilosophyInstallation.allCases.first { !visitedInstallations.contains($0.rawValue) } ?? .oneNoteFiveLives
                } label: {
                    Label("进入声学体验馆", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(palette.homeAnchor))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                }

                Button {
                    onOpenDecoupledCapture()
                } label: {
                    Label("零门槛敲拍记脑放", systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.22 : 0.05), radius: 12, y: 4)
        )
    }

    private func installationCard(_ inst: PhilosophyInstallation) -> some View {
        let visited = visitedInstallations.contains(inst.rawValue)
        let accent = Color(hex: inst.accentHex)

        return Button {
            activeInstallation = inst
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.24), accent.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: inst.iconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("装置 \(inst.romanNumeral) · \(inst.title)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        if visited {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(palette.homeAnchor)
                        }
                    }
                    Text(inst.axiomTag)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(inst.hookQuote)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accent.opacity(0.8))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(visited ? accent.opacity(0.4) : palette.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full-Screen Museum Installation Stage

private struct InstallationFullScreenStage: View {
    let installation: PhilosophyInstallation
    let palette: ChimmoPalette
    let synth: FeltPianoSynth
    let onMarkVisited: () -> Void
    let onSwitchInstallation: (PhilosophyInstallation) -> Void
    let onSendOrigamiToWorkbench: ([NoteBead], ScaleMode) -> Void
    let onOpenSwan: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var playTask: Task<Void, Never>? = nil

    // Installation I: One Note, 5 Lives
    @State private var relIndex: Int = 0
    @State private var relPulse: Double = 0.0

    // Installation II: Wave Symmetry & Continuous Haptics
    @State private var semitoneSlider: Double = 7.0
    @State private var continuousSoundOn: Bool = false
    @State private var lastHapticSemitone: Int = 7

    // Installation III: Half-Second Tear (Hold 4 -> Slide to 3)
    @State private var isHoldingSuspension: Bool = false
    @State private var suspensionHoldSec: Double = 0.0
    @State private var didResolveTear: Bool = false

    // Installation IV: 5 Skies Spectrum
    @State private var activeSky: ScaleMode = .brightMajor

    // Installation V: 3-Note Origami Forest
    @State private var userSeed: [Int] = [1, 3, 5]
    @State private var grownBeads: [NoteBead] = []
    @State private var origamiHeadline: String = "先点 3 只咩哞种下属于你的小火种，再看它折出森林"

    // Installation VI: Swan Water & Bach Dialogue 3-Fader Mixer
    @State private var mixMelody: Double = 1.0
    @State private var mixWater: Double = 0.85
    @State private var mixCounterpoint: Double = 0.85
    @State private var isMixerPlaying: Bool = false
    @State private var mixerStepIndex: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 极简艺术标题头
                    VStack(alignment: .leading, spacing: 4) {
                        Text("声学哲学装置 \(installation.romanNumeral) · \(installation.axiomTag)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: installation.accentHex))
                        Text(installation.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }

                    // 装置主体舞台
                    Group {
                        switch installation {
                        case .oneNoteFiveLives: stageOneNoteFiveLives
                        case .waveSymmetryHaptics: stageWaveSymmetry
                        case .halfSecondTear: stageHalfSecondTear
                        case .fiveSkiesSpectrum: stageFiveSkies
                        case .threeNoteOrigami: stageThreeNoteOrigami
                        case .swanWaterDialogue: stageSwanDialogueMixer
                        }
                    }

                    // 底部漫游下一座装置
                    HStack {
                        if let prev = PhilosophyInstallation(rawValue: installation.rawValue - 1) {
                            Button("← 装置 \(prev.romanNumeral)") {
                                stopAllAudio()
                                onSwitchInstallation(prev)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(palette.cardSurface))
                            .foregroundStyle(palette.secondaryInk)
                        }
                        Spacer()
                        if let next = PhilosophyInstallation(rawValue: installation.rawValue + 1) {
                            Button("漫游下一座：\(next.title) →") {
                                stopAllAudio()
                                onSwitchInstallation(next)
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                        } else {
                            Button("去工作台听完整《天鹅》 →") {
                                stopAllAudio()
                                onOpenSwan()
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(palette.melodyTerracotta))
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(18)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("退出装置") {
                        stopAllAudio()
                        dismiss()
                    }
                }
            }
            .onAppear { onMarkVisited() }
            .onDisappear { stopAllAudio() }
        }
    }

    private func stopAllAudio() {
        playTask?.cancel()
        playTask = nil
        isMixerPlaying = false
        continuousSoundOn = false
        synth.stopContinuousPair()
    }

    // MARK: - Installation I: One Note, 5 Lives (Relational Philosophy)

    private struct RelWorld {
        let title: String
        let sub: String
        let colorA: Color
        let colorB: Color
        let bassHz: [Double]
        let insight: String
    }

    private var relWorlds: [RelWorld] {
        [
            RelWorld(title: "☀️ 晴空晨光", sub: "脚下站 1·Do", colorA: Color(hex: 0xFF7B7F), colorB: Color(hex: 0x12B886), bassHz: [130.81, 196.0, 261.63], insight: "E4 音高纹丝不动，但脚下温暖的 Do (1) 把它托成了一缕晨光（大调 I）。"),
            RelWorld(title: "🌧 黄昏怀旧", sub: "脚下站 6·La", colorA: Color(hex: 0x5C7CFA), colorB: Color(hex: 0x364FC7), bassHz: [110.0, 164.81, 220.0], insight: "还是同一颗 E4！脚下换成 La (6) 的瞬间，它化作一声温柔思念（小调 vi）。"),
            RelWorld(title: "🫧 夏日悬浮", sub: "脚下站 4·Fa", colorA: Color(hex: 0x22B8CF), colorB: Color(hex: 0x20C997), bassHz: [174.61, 220.0, 261.63], insight: "还是同一颗 E4！Fa 站在脚下，它变成东亚治愈电影里悬浮的透明夏风（IV maj7）。"),
            RelWorld(title: "🌅 远航微风", sub: "脚下站 2·Re", colorA: Color(hex: 0xFF922B), colorB: Color(hex: 0xF06595), bassHz: [146.83, 220.0, 261.63], insight: "站在 Re (2) 上方，同一颗 E4 瞬间带上旅途出发前的暖橘期待（ii9）。"),
            RelWorld(title: "🌌 梦境之门", sub: "脚下站 暗影 ♭6", colorA: Color(hex: 0x7950F2), colorB: Color(hex: 0x1B1E3D), bassHz: [103.83, 155.56, 207.65], insight: "音高依然 100% 没变——只换了脚下的关系，它竟推开了科幻与梦境之门！")
        ]
    }

    private var stageOneNoteFiveLives: some View {
        let world = relWorlds[relIndex]
        return VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(colors: [world.colorA, world.colorB], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .animation(.easeInOut(duration: 0.45), value: relIndex)

                VStack(spacing: 12) {
                    Text("主角音 E4（3·拍咯）全程音高 0.00 Hz 变化")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.24)))
                        .foregroundStyle(.white)

                    Spacer()

                    // 中央永恒不变的主角光珠
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 96 + CGFloat(relPulse * 24), height: 96 + CGFloat(relPulse * 24))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                            .shadow(color: .white.opacity(0.75), radius: 14)
                        VStack(spacing: 0) {
                            Text("3·拍咯")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(hex: 0x182135))
                            Text("E4")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(hex: 0x5A6680))
                        }
                    }

                    Spacer()

                    Text(world.insight)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
                .padding(.top, 14)
            }
            .frame(height: 245)

            // 5 个脚下世界切换卡
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(0..<relWorlds.count, id: \.self) { idx in
                    let w = relWorlds[idx]
                    let active = relIndex == idx
                    Button {
                        relIndex = idx
                        relPulse = 1.0
                        withAnimation(.easeOut(duration: 0.55)) { relPulse = 0.0 }
                        AcousticHapticsEngine.shared.playConsonantGlow(intensity: idx == 4 ? 0.78 : 0.55)
                        // 先清晰唱响纹丝不动的主角音 E4，再由低音与竖琴铺开脚下的世界
                        synth.playNote(frequency: 329.63, velocity: 0.65, decay: 2.6, timbre: .singingCello, delaySeconds: 0.0)
                        for (bIdx, hz) in w.bassHz.enumerated() {
                            synth.playNote(
                                frequency: hz,
                                velocity: bIdx == 0 ? 0.34 : 0.22,
                                decay: 2.4,
                                timbre: bIdx == 0 ? .warmBass : .liquidHarp,
                                delaySeconds: 0.16 + Double(bIdx) * 0.075
                            )
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.title)
                                .font(.subheadline.weight(.bold))
                            Text(w.sub)
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(active ? w.colorA.opacity(0.22) : palette.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(active ? w.colorA : palette.divider, lineWidth: active ? 1.6 : 1)
                                )
                        )
                        .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }

            philosophyTakeawayCard(
                title: "哲学公理 I · 和声是关系的艺术",
                body: "音乐里没有天生悲伤或快乐的孤立音符。情绪诞生在「它与脚下参照物的关系」中——这就是为什么同一个旋律换一套和弦光带，就能讲述截然不同的人生。"
            )
        }
    }

    // MARK: - Installation II: Wave Symmetry & Core Haptics Physics

    private var stageWaveSymmetry: some View {
        let semiInt = Int(semitoneSlider.rounded())
        let desc = HarmonicRatioPhysics.descriptor(forSemitones: semiInt)
        let baseHz = 261.63
        let topHz = baseHz * pow(2.0, semitoneSlider / 12.0)
        let waveColor: Color = desc.isTense ? palette.melodyTerracotta : (desc.consonance > 0.9 ? palette.homeAnchor : palette.bassRibbon)

        return VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: 0x0F172A))

                LissajousWaveView(
                    ratioA: Double(desc.ratioA),
                    ratioB: Double(desc.ratioB),
                    consonance: desc.consonance,
                    accentColor: waveColor,
                    isNight: true,
                    compact: false
                )

                VStack {
                    HStack {
                        Text("频率比 \(desc.ratioText) · \(desc.intervalName)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(desc.isTense ? "⚡ 拍频摩擦" : "✦ 几何静止")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(waveColor.opacity(0.28)))
                            .foregroundStyle(waveColor)
                    }
                    .padding(14)

                    Spacer()

                    Text(desc.poeticEssence)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }
            .frame(height: 240)

            // 连续声波共振开关 + 平滑滑轨
            VStack(spacing: 10) {
                Toggle(isOn: $continuousSoundOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开启持续双声波物理共振（边拖滑块边听波纹咬合）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("开启后手机掌心会同步随和谐/摩擦给出不同触觉震动")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                }
                .tint(palette.homeAnchor)
                .onChange(of: continuousSoundOn) { _, isOn in
                    if isOn {
                        synth.setContinuousPair(hzA: baseHz, hzB: topHz, gain: 0.24)
                    } else {
                        synth.stopContinuousPair()
                    }
                }

                Slider(value: $semitoneSlider, in: 0...12)
                    .tint(waveColor)
                    .onChange(of: semitoneSlider) { _, newVal in
                        let newTopHz = baseHz * pow(2.0, newVal / 12.0)
                        if continuousSoundOn {
                            synth.setContinuousPair(hzA: baseHz, hzB: newTopHz, gain: 0.24)
                        }
                        let rounded = Int(newVal.rounded())
                        if rounded != lastHapticSemitone {
                            lastHapticSemitone = rounded
                            let d = HarmonicRatioPhysics.descriptor(forSemitones: rounded)
                            if d.isTense {
                                AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.6)
                            } else if d.consonance >= 0.85 {
                                AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.72)
                            }
                            if !continuousSoundOn {
                                synth.playNote(frequency: baseHz, velocity: 0.48, decay: 1.5, timbre: .feltPiano)
                                synth.playNote(frequency: newTopHz, velocity: 0.48, decay: 1.5, timbre: .feltPiano, delaySeconds: 0.03)
                            }
                        }
                    }

                // 5 个经典宇宙比例直达磁吸按钮
                HStack(spacing: 6) {
                    ratioAnchorButton("1:1 合一", semi: 0)
                    ratioAnchorButton("16:15 摩擦", semi: 1)
                    ratioAnchorButton("5:4 微笑", semi: 4)
                    ratioAnchorButton("3:2 宇宙", semi: 7)
                    ratioAnchorButton("2:1 八度", semi: 12)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))

            philosophyTakeawayCard(
                title: "哲学公理 II · 和谐是波纹的几何对称",
                body: "乐理不是古人拍脑袋编的规矩，而是琴弦振动的自然常数。哪怕看不懂五线谱，你刚才在眼前看到的静止莲花、在掌心摸到的温润与颤抖，就是全部和谐与张力的物理真相！"
            )
        }
    }

    private func ratioAnchorButton(_ title: String, semi: Double) -> some View {
        let active = Int(semitoneSlider.rounded()) == Int(semi)
        return Button(title) {
            semitoneSlider = semi
            let baseHz = 261.63
            let topHz = baseHz * pow(2.0, semi / 12.0)
            if continuousSoundOn {
                synth.setContinuousPair(hzA: baseHz, hzB: topHz, gain: 0.24)
            } else {
                synth.playNote(frequency: baseHz, velocity: 0.50, decay: 1.8, timbre: .feltPiano)
                synth.playNote(frequency: topHz, velocity: 0.50, decay: 1.8, timbre: .feltPiano, delaySeconds: 0.03)
            }
            let d = HarmonicRatioPhysics.descriptor(forSemitones: Int(semi))
            if d.isTense {
                AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.65)
            } else {
                AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.72)
            }
        }
        .font(.system(size: 10.5, weight: active ? .bold : .medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(active ? palette.bassRibbon : palette.shelfSurface))
        .foregroundStyle(active ? .white : palette.primaryInk)
        .buttonStyle(.plain)
    }

    // MARK: - Installation III: Half-Second Tear (Time & Suspension Philosophy)

    private var stageHalfSecondTear: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: didResolveTear
                                ? [Color(hex: 0x0B9970), Color(hex: 0x228BE6)]
                                : (isHoldingSuspension ? [Color(hex: 0xE64980), Color(hex: 0x7950F2)] : [Color(hex: 0x1E2947), Color(hex: 0x10172A)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .animation(.easeInOut(duration: 0.4), value: didResolveTear)
                    .animation(.easeInOut(duration: 0.2), value: isHoldingSuspension)

                VStack(spacing: 16) {
                    Text(
                        didResolveTear
                            ? "💧 听见那一瞬间融化般的鼻酸与释然了吗？"
                            : (isHoldingSuspension ? "底下的 I 和弦已经回家，但你按住了 4·呜嘟 赖着不走…" : "按住下方「4·呜嘟」半秒以上，再松手让它滑落到「3·拍咯」")
                    )
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                    // 4 -> 3 延留弹性可视化
                    HStack(spacing: 28) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(ChimmoMember.udo.bodyColor)
                                .frame(width: isHoldingSuspension ? 68 : 54, height: isHoldingSuspension ? 68 : 54)
                                .shadow(color: ChimmoMember.udo.bodyColor.opacity(0.8), radius: isHoldingSuspension ? 18 : 6)
                                .overlay(Text("4·Fa").font(.caption.weight(.bold)).foregroundStyle(.white))
                            Text("故意迟到")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Image(systemName: "arrow.right")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white.opacity(didResolveTear ? 1.0 : 0.45))

                        VStack(spacing: 6) {
                            Circle()
                                .fill(ChimmoMember.plokko.bodyColor)
                                .frame(width: didResolveTear ? 70 : 54, height: didResolveTear ? 70 : 54)
                                .shadow(color: ChimmoMember.plokko.bodyColor.opacity(0.85), radius: didResolveTear ? 20 : 6)
                                .overlay(Text("3·Mi").font(.caption.weight(.bold)).foregroundStyle(.white))
                            Text("滑落融化")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }

                    // 物理按住—释放体验按钮
                    Text(isHoldingSuspension ? "感受这股酸楚摩擦… 现在松手释放！" : "按住不放 0.5 秒（赖在 4 上）")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white))
                        .foregroundStyle(Color(hex: 0x182135))
                        .scaleEffect(isHoldingSuspension ? 0.96 : 1.0)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isHoldingSuspension {
                                        isHoldingSuspension = true
                                        didResolveTear = false
                                        // 伴奏已经落回 I (C-G-C)，但大提琴倔强停在 F4 (4·呜嘟) 产生极美酸楚摩擦！
                                        synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: .I, texture: .swanRipple, spanDuration: 1.8, intensity: 0.72)
                                        let hz4 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 4, octaveOffset: 0)
                                        synth.playNote(frequency: hz4, velocity: 0.68, decay: 2.0, timbre: .singingCello)
                                        AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.68)
                                    }
                                }
                                .onEnded { _ in
                                    isHoldingSuspension = false
                                    didResolveTear = true
                                    // 松手瞬间大提琴滑落半音到 E4 (3·拍咯)，紧绷融化！
                                    let hz3 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 3, octaveOffset: 0)
                                    synth.playNote(frequency: hz3, velocity: 0.64, decay: 2.4, timbre: .singingCello)
                                    let hz5 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 5, octaveOffset: 0)
                                    synth.playNote(frequency: hz5, velocity: 0.22, decay: 2.0, timbre: .liquidHarp, delaySeconds: 0.08)
                                    AcousticHapticsEngine.shared.playResolutionExhale()
                                }
                        )
                }
                .padding(20)
            }
            .frame(height: 280)

            philosophyTakeawayCard(
                title: "哲学公理 III · 深情诞生在「迟到的半秒」里",
                body: "如果旋律总是准时跟伴奏一起落地，听起来就像口号；当伴奏已经回家、旋律却因舍不得而多停留半秒再滑落（4→3 延留音），就是巴赫、圣桑与电影配乐最催泪的魔法。"
            )
        }
    }

    // MARK: - Installation IV: 5 Skies Spectrum (Modal Brightness Philosophy)

    private var stageFiveSkies: some View {
        let skyColor = activeSky.skyAuroraColor(isNight: palette.isNight)
        return VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [skyColor.opacity(0.88), Color(hex: 0x10172A)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .animation(.easeInOut(duration: 0.4), value: activeSky)

                VStack(spacing: 14) {
                    HStack {
                        Label(activeSky.label, systemImage: activeSky.iconName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(activeSky.theoryName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                            .foregroundStyle(.white)
                    }

                    // 7 只咩哞的真实半音高度柱状对比（切换天空时亲眼看见只有 1 只咩哞降了半格！）
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(1...7, id: \.self) { deg in
                            let semi = activeSky.semitoneOffsets[deg - 1]
                            let majorSemi = ScaleMode.brightMajor.semitoneOffsets[deg - 1]
                            let diff = semi - majorSemi
                            let m = ChimmoMember.from(degree: deg)
                            VStack(spacing: 4) {
                                if diff != 0 {
                                    Text(diff > 0 ? "+半" : "-半")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(Color(hex: 0xFFE066))
                                } else {
                                    Text(" ")
                                        .font(.system(size: 9.5))
                                }
                                Circle()
                                    .fill(m.nightGlowColor)
                                    .frame(width: 26, height: 26)
                                    .overlay(Text("\(deg)").font(.caption2.weight(.bold)).foregroundStyle(Color(hex: 0x10172A)))
                                    .offset(y: -CGFloat(semi) * 5.2)
                                    .animation(.spring(response: 0.42, dampingFraction: 0.72), value: activeSky)
                                Text(m.chineseName)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 112)

                    Text(activeSky.skyPhilosophy)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .frame(height: 256)

            // 五色天光直达条
            HStack(spacing: 6) {
                ForEach(ScaleMode.allCases) { sky in
                    let sel = activeSky == sky
                    Button {
                        activeSky = sky
                        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.55)
                        playSkyDemo(sky)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sky.iconName)
                                .font(.subheadline)
                            Text(sky.shortSkyLabel)
                                .font(.caption2.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 13).fill(sel ? sky.skyAuroraColor(isNight: false) : palette.cardSurface))
                        .foregroundStyle(sel ? .white : palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }

            philosophyTakeawayCard(
                title: "哲学公理 IV · 从极昼到黄昏，每次只挪半步",
                body: "情绪不只是开心大调与伤心小调！从左到右按「云端→晴空→落日→晨雾→暮雨」滑过，每一步恰好只让一只咩哞下降半格（4↓ → 7↓ → 3↓ → 6↓），这就是电影配乐五彩天光的全部秘密。"
            )
        }
    }

    private func playSkyDemo(_ mode: ScaleMode) {
        playTask?.cancel()
        let motif = [1, 3, 4, 5, 6, 7, 5, 1]
        playTask = Task { @MainActor in
            synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: .I, texture: .summerGlass, spanDuration: 2.2, intensity: 0.72)
            for (i, d) in motif.enumerated() {
                if Task.isCancelled { return }
                let hz = mode.frequencyHz(rootMIDI: 60, degree: d, octaveOffset: 0)
                synth.playNote(frequency: hz, velocity: 0.58, decay: 1.4, timbre: .singingCello)
                if i == 4 {
                    synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: .IV, texture: .summerGlass, spanDuration: 1.8, intensity: 0.68)
                }
                try? await Task.sleep(nanoseconds: 310_000_000)
            }
        }
    }

    // MARK: - Installation V: 3-Note Origami Forest (Fractal Growth)

    private var stageThreeNoteOrigami: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("① 点击 3 只咩哞，种下属于你的 3 音小种子（当前：\(userSeed.map(String.init).joined(separator: " → "))）：")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.primaryInk)

                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { deg in
                        let m = ChimmoMember.from(degree: deg)
                        Button {
                            if userSeed.count >= 3 { userSeed.removeAll() }
                            userSeed.append(deg)
                            let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                            synth.playNote(frequency: hz, velocity: 0.58, decay: 1.2, timbre: .feltPiano)
                            AcousticHapticsEngine.shared.playBeatTap(isStrong: deg == 1)
                        } label: {
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(m.bodyColor)
                                    .frame(width: 32, height: 32)
                                    .overlay(Text("\(deg)").font(.caption.weight(.bold)).foregroundStyle(.white))
                                Text(m.chineseName)
                                    .font(.system(size: 9))
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))

            // ② 4 种分形折纸生长法则
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MotifGrowthOperation.allCases) { op in
                    Button {
                        let seedBeads = userSeed.enumerated().map { idx, d in
                            NoteBead(degree: d, rawOnset: 0.12 + Double(idx) * 0.44, rawDuration: 0.42, phraseTag: "起·种子")
                        }
                        grownBeads = MotifOrigamiEngine.grow(notes: seedBeads, operation: op)
                        origamiHeadline = op.philosophyNote
                        AcousticHapticsEngine.shared.playSeedBloom()
                        playGrownOrigami(grownBeads)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: op.iconName)
                                .foregroundStyle(palette.homeAnchor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(op.label)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Text(op == .fullFourPhrasePoem ? "3音变15音完整诗" : "体验折纸变形")
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(palette.cardSurface))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 折纸结果预览与一键送入工作台
            VStack(alignment: .leading, spacing: 10) {
                Text(origamiHeadline)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.primaryInk)

                if !grownBeads.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(grownBeads) { b in
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(b.member.bodyColor)
                                        .frame(width: 24, height: 24)
                                        .overlay(Text("\(b.degree)").font(.caption2.weight(.bold)).foregroundStyle(.white))
                                    Text(b.phraseTag?.prefix(1).description ?? "")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(palette.secondaryInk)
                                }
                            }
                        }
                    }

                    Button {
                        stopAllAudio()
                        onSendOrigamiToWorkbench(grownBeads, .brightMajor)
                    } label: {
                        Label("把这首折纸乐章送入工作台继续创作与保存 →", systemImage: "arrow.right.circle.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))

            philosophyTakeawayCard(
                title: "哲学公理 V · 大师不是写 200 个音，而是折出森林",
                body: "脑海里只有 3 颗音的碎片就完全足够作曲！通过「爬楼模进、水面倒影、半秒延留」，同一颗小种子会像植物分形一样自然生长成完整的起承转合。"
            )
        }
    }

    private func playGrownOrigami(_ beads: [NoteBead]) {
        playTask?.cancel()
        playTask = Task { @MainActor in
            let chords: [DiatonicChord] = [.I, .IV, .V, .I]
            for (idx, b) in beads.enumerated() {
                if Task.isCancelled { return }
                let delay = idx == 0 ? 0.0 : max(0.14, b.rawOnset - beads[idx - 1].rawOnset)
                if idx > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                if Task.isCancelled { return }
                if idx % 3 == 0 {
                    let ch = chords[(idx / 3) % chords.count]
                    synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: ch, texture: .summerGlass, spanDuration: 1.5, intensity: 0.72)
                }
                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: b.degree, octaveOffset: b.octaveOffset)
                synth.playNote(frequency: hz, velocity: 0.62, decay: max(0.95, b.rawDuration * 1.4), timbre: .feltPiano)
            }
        }
    }

    // MARK: - Installation VI: Swan Water & Bach Dialogue (3-Layer X-Ray Mixer)

    private var stageSwanDialogueMixer: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("圣桑《天鹅》三声部 X 光混音台")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("边播边拖动下面三根声部推子，把水波或大提琴单独关掉听听看！")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    Spacer()
                    Button {
                        if isMixerPlaying {
                            stopAllAudio()
                        } else {
                            startSwanMixerLoop()
                        }
                    } label: {
                        Image(systemName: isMixerPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(palette.homeAnchor)
                    }
                }

                mixerFader(title: "① 歌唱大提琴（主旋律线条）", value: $mixMelody, color: palette.melodyTerracotta)
                mixerFader(title: "② 湖面竖琴水波（圣桑左手织体）", value: $mixWater, color: palette.bassRibbon)
                mixerFader(title: "③ 影子对位副旋律（巴赫式留白对话）", value: $mixCounterpoint, color: palette.harmonyWash)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(palette.cardSurface))

            philosophyTakeawayCard(
                title: "哲学公理 VI · 留白不是空无，是另一个灵魂开口的时刻",
                body: "把「① 主旋律」拉到 0，你会听见湖面竖琴独自荡漾的纯粹之美；把「③ 影子对位」拉满，你会听见当大提琴在长音里喘息时，另一个声部如何温柔接话。"
            )
        }
    }

    private func mixerFader(title: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryInk)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            Slider(value: value, in: 0...1)
                .tint(color)
        }
    }

    private func startSwanMixerLoop() {
        stopAllAudio()
        isMixerPlaying = true
        let swan = SpecimenLibrary.saintSaensTheSwan
        let spans = TheoryLensEngine.buildChordSpans(document: swan, preset: .autoMatch)
        let shadows = CounterpointShadowEngine.generateShadowVoice(document: swan, spans: spans)
        let total = swan.totalDuration

        playTask = Task { @MainActor in
            while !Task.isCancelled && isMixerPlaying {
                let start = Date()
                var nextNote = 0
                var nextShadow = 0
                var lastSpan = -1

                while !Task.isCancelled && isMixerPlaying {
                    let elapsed = Date().timeIntervalSince(start)
                    if let sp = spans.first(where: { elapsed >= $0.startTime && elapsed < $0.endTime }), sp.id != lastSpan {
                        lastSpan = sp.id
                        if mixWater > 0.05 {
                            synth.playDiatonicChord(
                                rootMIDI: swan.rootMIDI,
                                mode: swan.scaleMode,
                                chord: sp.chord,
                                texture: .swanRipple,
                                spanDuration: sp.endTime - sp.startTime,
                                intensity: 0.85 * mixWater
                            )
                        }
                    }

                    while nextNote < swan.notes.count && swan.notes[nextNote].rawOnset <= elapsed {
                        let b = swan.notes[nextNote]
                        if mixMelody > 0.05 {
                            let hz = swan.scaleMode.frequencyHz(rootMIDI: swan.rootMIDI, degree: b.degree, octaveOffset: b.octaveOffset)
                            synth.playNote(frequency: hz, velocity: 0.65 * mixMelody, decay: max(1.1, b.rawDuration * 1.45), timbre: .singingCello)
                        }
                        nextNote += 1
                    }

                    while nextShadow < shadows.count && shadows[nextShadow].onset <= elapsed {
                        let sh = shadows[nextShadow]
                        if mixCounterpoint > 0.05 {
                            let hz = swan.scaleMode.frequencyHz(rootMIDI: swan.rootMIDI, degree: sh.degree, octaveOffset: sh.octaveOffset)
                            synth.playNote(frequency: hz, velocity: 0.34 * mixCounterpoint, decay: max(0.9, sh.duration * 1.4), timbre: .celesta)
                        }
                        nextShadow += 1
                    }

                    if elapsed >= total { break }
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
    }

    private func philosophyTakeawayCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.homeAnchor)
            Text(body)
                .font(.caption)
                .foregroundStyle(palette.primaryInk.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.homeAnchor.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.homeAnchor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
