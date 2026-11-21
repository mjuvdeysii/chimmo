import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum TheoryChapter: Int, CaseIterable, Identifiable, Sendable {
    case findHome = 1
    case semitonePull = 2
    case majorMinorThird = 3
    case stackTriad = 4
    case reharmonize = 5
    case captureFirstMelody = 6

    public var id: Int { rawValue }

    public var numberBadge: String { "0\(rawValue)" }

    public var title: String {
        switch self {
        case .findHome: return "寻找「家」"
        case .semitonePull: return "贴得很近的邻居"
        case .majorMinorThird: return "一颗音改变晴雨"
        case .stackTriad: return "把三只小偶叠起来"
        case .reharmonize: return "给同一旋律换底色"
        case .captureFirstMelody: return "捉住你的第一段脑放"
        }
    }

    public var conceptTag: String {
        switch self {
        case .findHome: return "主音 1 Do · 归属感"
        case .semitonePull: return "半音间距 · 导音 7→1"
        case .majorMinorThird: return "大调 3 vs 小调 ♭3"
        case .stackTriad: return "三和弦 · I / IV / V"
        case .reharmonize: return "和声进行 · 编曲魔法"
        case .captureFirstMelody: return "哼唱记录 · 乐思本"
        }
    }

    public var teaser: String {
        switch self {
        case .findHome: return "为什么有些结尾像没说完话，只有一个音像句号？"
        case .semitonePull: return "肉眼看见 7 和高音 1 的半音窄缝，亲手释放悬念。"
        case .majorMinorThird: return "只挪动 3·拍咯半步，让整段音乐瞬间由晴转雨。"
        case .stackTriad: return "同时点亮 3 条泳道，30 秒真正听懂「和弦」是什么。"
        case .reharmonize: return "旋律一个音不改，换掉底下的光带就能改写情绪。"
        case .captureFirstMelody: return "带着刚解锁的乐理透视眼，去捉住你脑海里的旋律！"
        }
    }

    public var accentMember: ChimmoMember {
        switch self {
        case .findHome: return .taono
        case .semitonePull: return .tinki
        case .majorMinorThird: return .plokko
        case .stackTriad: return .corllo
        case .reharmonize: return .udo
        case .captureFirstMelody: return .bomo
        }
    }
}

/// 音律启蒙 6 关互动微剧场（无障碍零门槛入门路径，每关 30 秒亲手玩懂一个核心乐理）
public struct TheoryJourneyView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @Binding public var completedChapters: Set<Int>
    public let onJumpToCapture: () -> Void

    @State private var activeChapter: TheoryChapter? = nil

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        completedChapters: Binding<Set<Int>>,
        onJumpToCapture: @escaping () -> Void
    ) {
        self.palette = palette
        self.synth = synth
        self._completedChapters = completedChapters
        self.onJumpToCapture = onJumpToCapture
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 顶部轻盈进度导语卡片
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("6 步看见音符世界")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Spacer()
                            Text("已完成 \(completedChapters.count)/\(TheoryChapter.allCases.count)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(palette.homeAnchor.opacity(0.16)))
                                .foregroundStyle(palette.homeAnchor)
                        }

                        Text("不需要背五线谱，也不用记英文和弦名。每一关只需 30 秒动动手指，靠耳朵和眼睛亲手验证一个音乐家每天在用的核心规律。")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(palette.shelfSurface)
                    )

                    // 6 关交互卡片列表
                    ForEach(TheoryChapter.allCases) { chapter in
                        let done = completedChapters.contains(chapter.rawValue)
                        let accent = palette.isNight ? chapter.accentMember.nightGlowColor : chapter.accentMember.bodyColor

                        Button {
                            if chapter == .captureFirstMelody {
                                completedChapters.insert(chapter.rawValue)
                                saveCompleted()
                                onJumpToCapture()
                            } else {
                                activeChapter = chapter
                            }
                        } label: {
                            HStack(spacing: 14) {
                                // 编号徽章
                                ZStack {
                                    Circle()
                                        .fill(accent.opacity(done ? 0.24 : 0.16))
                                        .frame(width: 46, height: 46)
                                    if done {
                                        Image(systemName: "checkmark")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(accent)
                                    } else {
                                        Text(chapter.numberBadge)
                                            .font(.headline.weight(.bold).monospacedDigit())
                                            .foregroundStyle(accent)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(chapter.title)
                                            .font(.headline)
                                            .foregroundStyle(palette.primaryInk)
                                        Text(chapter.conceptTag)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(accent.opacity(0.14)))
                                            .foregroundStyle(accent)
                                    }
                                    Text(chapter.teaser)
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryInk)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(palette.shelfSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(done ? accent.opacity(0.45) : palette.divider, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("音律启蒙")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeChapter) { chapter in
                TheoryChapterPlaygroundSheet(
                    chapter: chapter,
                    palette: palette,
                    synth: synth,
                    onComplete: {
                        completedChapters.insert(chapter.rawValue)
                        saveCompleted()
                    },
                    onOpenNext: { next in
                        if next == .captureFirstMelody {
                            activeChapter = nil
                            completedChapters.insert(next.rawValue)
                            saveCompleted()
                            onJumpToCapture()
                        } else {
                            activeChapter = next
                        }
                    }
                )
                .id(chapter.id)
            }
        }
    }

    private func saveCompleted() {
        UserDefaults.standard.set(Array(completedChapters), forKey: "chimmo_completed_chapters")
    }
}

// MARK: - Interactive 30-Second Playable Chapter Sheet

private struct TheoryChapterPlaygroundSheet: View {
    let chapter: TheoryChapter
    let palette: ChimmoPalette
    let synth: FeltPianoSynth
    let onComplete: () -> Void
    let onOpenNext: (TheoryChapter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var solved: Bool = false
    @State private var statusText: String = ""

    // Lesson 1 state
    @State private var ch1LastDegree: Int = 2
    // Lesson 2 state
    @State private var ch2Resolved: Bool = false
    // Lesson 3 state
    @State private var ch3Minor: Bool = false
    @State private var ch3ToggledCount: Int = 0
    // Lesson 4 state
    @State private var ch4ActiveChord: DiatonicChord = .I
    @State private var ch4TriedChords: Set<DiatonicChord> = []
    // Lesson 5 state
    @State private var ch5Preset: ChordProgressionPreset = .classicPop
    @State private var ch5TriedPresets: Set<ChordProgressionPreset> = []
    @State private var playTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 章节标题与概念标牌
                    VStack(alignment: .leading, spacing: 6) {
                        Text("第 \(chapter.rawValue) 课 · \(chapter.conceptTag)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.homeAnchor)
                        Text(chapter.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }

                    // 各课专属交互剧场
                    Group {
                        switch chapter {
                        case .findHome: lesson1FindHome
                        case .semitonePull: lesson2SemitonePull
                        case .majorMinorThird: lesson3MajorMinor
                        case .stackTriad: lesson4StackTriad
                        case .reharmonize: lesson5Reharmonize
                        case .captureFirstMelody: EmptyView()
                        }
                    }

                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(palette.primaryInk)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(solved ? palette.homeAnchor.opacity(0.15) : palette.shelfSurface)
                            )
                    }

                    if solved {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(palette.homeAnchor)
                            Text("顿悟解锁！")
                                .font(.headline)
                                .foregroundStyle(palette.homeAnchor)
                            Spacer()
                            if let next = TheoryChapter(rawValue: chapter.rawValue + 1) {
                                Button("下一课：\(next.title) →") {
                                    stopTask()
                                    onOpenNext(next)
                                }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(palette.homeAnchor.opacity(0.55), lineWidth: 1.2)
                        )
                    }
                }
                .padding(18)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        stopTask()
                        dismiss()
                    }
                }
            }
            .onDisappear { stopTask() }
        }
    }

    // MARK: Lesson 1 - Find Home (Tonic 1 Do)

    private var lesson1FindHome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("先听这句停在半路的旋律（5 → 4 → 3 → 2 → ?），然后点选下面任意一只咩哞作为结尾，找出唯一让你耳朵「彻底松一口气」的家。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            // 阶梯可视化示意
            HStack(spacing: 10) {
                ForEach(Array([5, 4, 3, 2, ch1LastDegree].enumerated()), id: \.offset) { _, deg in
                    let m = ChimmoMember.from(degree: deg)
                    VStack(spacing: 4) {
                        Circle()
                            .fill(palette.isNight ? m.nightGlowColor : m.bodyColor)
                            .frame(width: 28, height: 28)
                            .overlay(Text("\(deg)").font(.caption.weight(.bold)).foregroundStyle(.white))
                            .offset(y: CGFloat(5 - deg) * 8)
                        Text(m.chineseName)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 112)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.shelfSurface))

            HStack(spacing: 10) {
                ForEach([1, 2, 4, 6], id: \.self) { cand in
                    let m = ChimmoMember.from(degree: cand)
                    Button {
                        ch1LastDegree = cand
                        playPhrase([5, 4, 3, 2, cand], mode: .brightMajor)
                        if cand == 1 {
                            solved = true
                            onComplete()
                            statusText = "就是它！1·陶诺（Do）是整条音阶的引力中心，音乐学里叫「主音」。所有旋律无论走多远，回到 1 就像句子画上句号。"
                        } else {
                            statusText = "结尾停在 \(cand)·\(m.chineseName) 听起来是不是还有点没说完？再试试别的小偶！"
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(cand)·\(m.chineseName)")
                                .font(.subheadline.weight(.semibold))
                            Text(m.roleLabel)
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(ch1LastDegree == cand ? (palette.isNight ? m.nightGlowColor : m.bodyColor).opacity(0.24) : palette.shelfSurface)
                        )
                        .foregroundStyle(palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Lesson 2 - Semitone Pull (7 -> 1↑)

    private var lesson2SemitonePull: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("大调音阶里不是每个音都隔一样远：7·叮尖离上面的高音 1·陶诺只隔「半步」（半音），所以它总像踮着脚尖急切想靠上去。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.shelfSurface)

                VStack(spacing: 10) {
                    // 高音 1↑ 轨道
                    HStack {
                        Text("高音 1↑ · 陶诺（家）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.homeAnchor)
                        Spacer()
                        Circle()
                            .fill(ChimmoMember.taono.bodyColor.opacity(ch2Resolved ? 1.0 : 0.35))
                            .frame(width: ch2Resolved ? 32 : 24, height: ch2Resolved ? 32 : 24)
                    }
                    .padding(.horizontal, 18)

                    // 半音窄缝示意
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.caption.weight(.bold))
                        Text(ch2Resolved ? "已越过半音窄缝，紧绷瞬间舒展！" : "仅差 1 个半音（紧绷牵引中…）")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(ch2Resolved ? palette.homeAnchor : palette.tensionFilament)

                    // 7·叮尖轨道
                    HStack {
                        Text("7 · 叮尖（导音）")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.tensionFilament)
                        Spacer()
                        RoundedRectangle(cornerRadius: 5)
                            .fill(ChimmoMember.tinki.bodyColor)
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(45))
                            .opacity(ch2Resolved ? 0.3 : 1.0)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.vertical, 18)
            }

            HStack(spacing: 12) {
                Button {
                    ch2Resolved = false
                    playPhrase([1, 3, 5, 7], mode: .brightMajor)
                    statusText = "听见停在 7·叮尖时那种悬在半空、憋着一口气的紧绷感了吗？"
                } label: {
                    Text("1. 先听悬在 7·叮尖")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }

                Button {
                    ch2Resolved = true
                    playPhrase([1, 3, 5, 7, 8], mode: .brightMajor)
                    solved = true
                    onComplete()
                    statusText = "就是这半步的魔力！7→1↑ 是全音乐界引力最强的「导音解决」，几乎所有宏大副歌的高潮都靠它释放情绪。"
                } label: {
                    Text("2. 推上半步回家 →")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.melodyTerracotta))
                        .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
            }
        }
    }

    // MARK: Lesson 3 - Major vs Minor (3·Plokko shifts by 1 semitone!)

    private var lesson3MajorMinor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("大调和小调听起来一晴一雨，其实最核心的秘密只藏在 3·拍咯 身上——把它往下降半个音，整个世界的天气瞬间改变！")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            HStack(spacing: 16) {
                ChimmoFigureView(
                    member: .plokko,
                    isNight: palette.isNight,
                    isMinor: ch3Minor,
                    isSinging: true,
                    time: 0,
                    listeningTilt: 0
                )
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ch3Minor ? "微酸小调（3·拍咯降半音 ♭3）" : "晴朗大调（标准 3·拍咯）")
                        .font(.headline)
                        .foregroundStyle(palette.primaryInk)
                    Text(ch3Minor ? "与 1·陶诺相距 3 个半音（小三度），双耳微垂" : "与 1·陶诺相距 4 个半音（大三度），双耳轻扬")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(palette.shelfSurface))

            HStack(spacing: 12) {
                Button {
                    ch3Minor = false
                    ch3ToggledCount += 1
                    playPhrase([1, 2, 3, 5, 3, 1], mode: .brightMajor)
                    checkLesson3()
                } label: {
                    Label("晴朗大调", systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(!ch3Minor ? palette.melodyTerracotta : palette.shelfSurface))
                        .foregroundStyle(!ch3Minor ? (palette.isNight ? Color(hex: 0x1B2245) : .white) : palette.primaryInk)
                }

                Button {
                    ch3Minor = true
                    ch3ToggledCount += 1
                    playPhrase([1, 2, 3, 5, 3, 1], mode: .wistfulMinor)
                    checkLesson3()
                } label: {
                    Label("降半音 · 微酸小调", systemImage: "cloud.rain.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(ch3Minor ? palette.bassRibbon : palette.shelfSurface))
                        .foregroundStyle(ch3Minor ? .white : palette.primaryInk)
                }
            }
        }
    }

    private func checkLesson3() {
        if ch3ToggledCount >= 2 {
            solved = true
            onComplete()
            statusText = "听出差别了吗？大调与小调不是玄学，只是 3 级音（以及 6、7 级）相差那微妙的 1 个半音！回到画布切大小调时，你可以亲眼看到左侧阶梯的 3·拍咯上下滑动。"
        } else {
            statusText = "再点一下另一个按钮，对比同一串音符在晴朗与微酸之间的瞬间转变！"
        }
    }

    // MARK: Lesson 4 - Stack a Triad (Illuminating 3 Lanes)

    private var lesson4StackTriad: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("什么叫「和弦」？其实就是按「隔一个选一个」的规律，把 3 只咩哞叠在一起同时发声！点下面三个和弦，看画布里哪 3 条泳道被同时照亮。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            // 7 条迷你泳道预览
            VStack(spacing: 4) {
                ForEach((1...7).reversed(), id: \.self) { deg in
                    let inChord = ch4ActiveChord.chordToneDegrees.contains(deg)
                    let tint = ch4ActiveChord.color(isNight: palette.isNight)
                    HStack(spacing: 8) {
                        Text("\(deg)·\(ChimmoMember.from(degree: deg).chineseName)")
                            .font(.caption2.weight(inChord ? .bold : .regular))
                            .frame(width: 52, alignment: .leading)
                            .foregroundStyle(inChord ? tint : palette.secondaryInk)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(inChord ? tint.opacity(0.32) : palette.paper.opacity(0.5))
                            .frame(height: 16)
                            .overlay(alignment: .trailing) {
                                if inChord {
                                    Text("组成音")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(tint)
                                        .padding(.trailing, 8)
                                }
                            }
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(palette.shelfSurface))

            HStack(spacing: 10) {
                ForEach([DiatonicChord.I, .IV, .V], id: \.self) { ch in
                    let tint = ch.color(isNight: palette.isNight)
                    Button {
                        ch4ActiveChord = ch
                        ch4TriedChords.insert(ch)
                        synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: ch, intensity: 0.9)
                        if ch4TriedChords.count >= 3 {
                            solved = true
                            onComplete()
                            statusText = "你已经掌握了流行乐最核心的「三大支柱和弦」：I（1·3·5 稳固家）、IV（4·6·1 宽阔出发）、V（5·7·2 推你回家）！"
                        } else {
                            statusText = "已点亮 \(ch.roman) 和弦（\(ch.tonesFormula) · \(ch.moodTitle)），把三个都点一遍听听它们的接力！"
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(ch.roman) 和弦")
                                .font(.subheadline.weight(.bold))
                            Text(ch.tonesFormula)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(ch4ActiveChord == ch ? 0.28 : 0.12)))
                        .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Lesson 5 - Reharmonization (Same Melody, Different Emotional Backing)

    private var lesson5Reharmonize: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("编曲家最迷人的魔法之一叫「和声替换」：上方旋律一个音都不改（永远是 3 → 5 → 3 → 1），只换掉底下的和弦光带，就能讲出完全不同的故事。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            VStack(spacing: 10) {
                ForEach([ChordProgressionPreset.classicPop, .summerFloat, .warmStory], id: \.self) { preset in
                    let isSel = ch5Preset == preset
                    Button {
                        ch5Preset = preset
                        ch5TriedPresets.insert(preset)
                        playReharmonizedDemo(preset: preset)
                        if ch5TriedPresets.count >= 2 {
                            solved = true
                            onComplete()
                            statusText = "太棒了！你亲耳听到了编曲家的秘密：旋律只是骨架，底下的和弦光带才是真正的「情绪滤镜」。在主画布底部随时可以这样一指换和弦！"
                        } else {
                            statusText = "正在用「\(preset.label)」托起 3-5-3-1，再点另一种和声对比看看！"
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(preset.sequence.map(\.roman).joined(separator: "  →  "))
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: isSel ? "speaker.wave.2.fill" : "play.circle")
                                .font(.title3)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSel ? palette.homeAnchor.opacity(0.18) : palette.shelfSurface)
                        )
                        .foregroundStyle(isSel ? palette.homeAnchor : palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Audio Playback Helpers for Micro-Lessons

    private func stopTask() {
        playTask?.cancel()
        playTask = nil
    }

    private func playPhrase(_ steps: [Int], mode: ScaleMode) {
        stopTask()
        playTask = Task { @MainActor in
            for (idx, step) in steps.enumerated() {
                if Task.isCancelled { return }
                let deg = step > 7 ? 1 : step
                let oct = step > 7 ? 1 : 0
                let hz = mode.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: oct)
                synth.playNote(frequency: hz, velocity: 0.62, decay: 1.4, brightness: 0.95)
                if idx == 0 || idx == steps.count - 1 {
                    let ch: DiatonicChord = (deg == 1) ? .I : (deg == 7 ? .V : .IV)
                    synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: ch, intensity: 0.55)
                }
                try? await Task.sleep(nanoseconds: 340_000_000)
            }
        }
    }

    private func playReharmonizedDemo(preset: ChordProgressionPreset) {
        stopTask()
        let melody = [3, 5, 3, 1]
        let chords = preset.sequence
        playTask = Task { @MainActor in
            for i in 0..<melody.count {
                if Task.isCancelled { return }
                let deg = melody[i]
                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                synth.playNote(frequency: hz, velocity: 0.60, decay: 1.6, brightness: 0.94)
                if i < chords.count {
                    synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: chords[i], intensity: 0.85)
                }
                try? await Task.sleep(nanoseconds: 680_000_000)
            }
        }
    }
}
