import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum TheoryStage: Int, CaseIterable, Identifiable, Sendable {
    case shapeOfSound = 1
    case gravityOfNotes = 2
    case harmonyMagic = 3
    case tellYourStory = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .shapeOfSound: return "阶段一 · 声音的形状"
        case .gravityOfNotes: return "阶段二 · 音符的性格与引力"
        case .harmonyMagic: return "阶段三 · 听懂伴奏与编曲魔法"
        case .tellYourStory: return "阶段四 · 写出你的第一段乐思"
        }
    }

    public var subtitle: String {
        switch self {
        case .shapeOfSound: return "零门槛破冰：把看不见的声音变成海拔与心跳"
        case .gravityOfNotes: return "听懂为什么会有回家感、紧绷感与晴雨情绪"
        case .harmonyMagic: return "揭秘和弦聚光灯，以及《天鹅》水波伴奏的秘密"
        case .tellYourStory: return "掌握乐句问答，把脑海里的旋律变成完整作品"
        }
    }
}

public enum TheoryChapter: Int, CaseIterable, Identifiable, Sendable {
    case pitchAltitude = 1
    case heartbeatRhythm = 2
    case findHome = 3
    case narrowSteps = 4
    case weatherThird = 5
    case chordSpotlights = 6
    case swanTextureMagic = 7
    case questionAndAnswer = 8

    public var id: Int { rawValue }

    public var stage: TheoryStage {
        switch self {
        case .pitchAltitude, .heartbeatRhythm: return .shapeOfSound
        case .findHome, .narrowSteps, .weatherThird: return .gravityOfNotes
        case .chordSpotlights, .swanTextureMagic: return .harmonyMagic
        case .questionAndAnswer: return .tellYourStory
        }
    }

    public var numberBadge: String { "0\(rawValue)" }

    public var title: String {
        switch self {
        case .pitchAltitude: return "声音其实有「海拔」"
        case .heartbeatRhythm: return "心跳与长短呼吸"
        case .findHome: return "寻找音乐里的「家」"
        case .narrowSteps: return "为什么台阶有宽有窄？"
        case .weatherThird: return "一颗音改变整片天气"
        case .chordSpotlights: return "三束聚光灯就是和弦"
        case .swanTextureMagic: return "《天鹅》水波的秘密"
        case .questionAndAnswer: return "问句与答句：一首歌怎么写完"
        }
    }

    public var everydayMetaphor: String {
        switch self {
        case .pitchAltitude: return "一指画山脉 · 认识音高"
        case .heartbeatRhythm: return "灯笼强弱 · 认识节拍与时值"
        case .findHome: return "拖音珠回家 · 认识主音 Do"
        case .narrowSteps: return "窄台阶魔力 · 认识半音与 7→1"
        case .weatherThird: return "晴雨开关 · 认识大调与小调"
        case .chordSpotlights: return "隔一个叠三只 · 认识三和弦"
        case .swanTextureMagic: return "左手伴奏魔法 · 认识音乐织体"
        case .questionAndAnswer: return "给旋律挑结局 · 开启自由记录"
        }
    }

    public var teaser: String {
        switch self {
        case .pitchAltitude: return "不用背谱！手指在天空画一道山坡，立刻看懂旋律轮廓。"
        case .heartbeatRhythm: return "同样的音，换三拍圆舞或拉长尾音，为什么瞬间像另一首歌？"
        case .findHome: return "亲手上下拖动悬空的音珠，找唯一让耳朵松一口气的位置。"
        case .narrowSteps: return "看见 3-4 与 7-1↑ 的极窄缝隙，把叮尖推上半步感受释然。"
        case .weatherThird: return "只把 3·拍咯拉下半格，整片晴空立刻变成温柔微雨。"
        case .chordSpotlights: return "亲手隔一个点亮三只咩哞，瞬间听懂「和弦」为何悦耳。"
        case .swanTextureMagic: return "同样四个和弦，为何圣桑弹出来像湖水，电子琴弹出来像打卡？"
        case .questionAndAnswer: return "为一句悬在空中的问句挑三种电影结局，然后去记录你的脑放！"
        }
    }

    public var accentMember: ChimmoMember {
        switch self {
        case .pitchAltitude: return .corllo
        case .heartbeatRhythm: return .doko
        case .findHome: return .taono
        case .narrowSteps: return .tinki
        case .weatherThird: return .plokko
        case .chordSpotlights: return .bomo
        case .swanTextureMagic: return .udo
        case .questionAndAnswer: return .taono
        }
    }
}

/// 音律脱盲启蒙馆（4 阶段 × 8 关可触摸发声微剧场，生活比喻先行 → 动手顿悟 → 揭晓真实乐理名称）
public struct TheoryJourneyView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @Binding public var completedChapters: Set<Int>
    public let onJumpToCapture: () -> Void
    public let onOpenSwanMasterpiece: () -> Void

    @State private var activeChapter: TheoryChapter? = nil

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        completedChapters: Binding<Set<Int>>,
        onJumpToCapture: @escaping () -> Void,
        onOpenSwanMasterpiece: @escaping () -> Void
    ) {
        self.palette = palette
        self.synth = synth
        self._completedChapters = completedChapters
        self.onJumpToCapture = onJumpToCapture
        self.onOpenSwanMasterpiece = onOpenSwanMasterpiece
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 顶部年轻明亮的进度英雄卡片
                    heroProgressCard

                    // 4 个循序渐进的脱盲阶段
                    ForEach(TheoryStage.allCases) { stage in
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stage.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Text(stage.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            .padding(.horizontal, 4)

                            ForEach(TheoryChapter.allCases.filter { $0.stage == stage }) { chapter in
                                chapterCard(chapter)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("音律启蒙馆")
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
                        activeChapter = next
                    },
                    onFinishToCapture: {
                        activeChapter = nil
                        onJumpToCapture()
                    },
                    onTryTheSwan: {
                        activeChapter = nil
                        onOpenSwanMasterpiece()
                    }
                )
                .id(chapter.id)
            }
        }
    }

    private var heroProgressCard: some View {
        let ratio = Double(completedChapters.count) / Double(TheoryChapter.allCases.count)
        let nextChapter = TheoryChapter.allCases.first { !completedChapters.contains($0.rawValue) } ?? .pitchAltitude

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("零基础音律脱盲之旅")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text("不背枯燥术语！用画山坡、点灯光、拨湖水的方式，8 关彻底看懂音乐家眼中的世界。")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                }
                Spacer()
                Text("\(completedChapters.count)/\(TheoryChapter.allCases.count)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(palette.homeAnchor.opacity(0.16)))
                    .foregroundStyle(palette.homeAnchor)
            }

            // 年轻活力的渐变进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.shelfSurface)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.homeAnchor, palette.bassRibbon, palette.harmonyWash],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, geo.size.width * CGFloat(ratio)))
                }
            }
            .frame(height: 8)

            HStack(spacing: 10) {
                Button {
                    activeChapter = nextChapter
                } label: {
                    Label(
                        completedChapters.isEmpty ? "从第 1 关开始玩" : "继续第 \(nextChapter.rawValue) 关：\(nextChapter.title)",
                        systemImage: "play.fill"
                    )
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(palette.homeAnchor))
                    .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                }

                Button {
                    onOpenSwanMasterpiece()
                } label: {
                    Label("先听《天鹅》导赏", systemImage: "music.note")
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
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.25 : 0.05), radius: 12, y: 4)
        )
    }

    private func chapterCard(_ chapter: TheoryChapter) -> some View {
        let done = completedChapters.contains(chapter.rawValue)
        let accent = palette.isNight ? chapter.accentMember.nightGlowColor : chapter.accentMember.bodyColor

        return Button {
            activeChapter = chapter
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(done ? 0.22 : 0.14))
                        .frame(width: 46, height: 46)
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(accent)
                    } else {
                        Text(chapter.numberBadge)
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(chapter.everydayMetaphor)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(chapter.teaser)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryInk.opacity(0.7))
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(done ? accent.opacity(0.45) : palette.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func saveCompleted() {
        UserDefaults.standard.set(Array(completedChapters), forKey: "chimmo_completed_chapters")
    }
}

// MARK: - 8 Playable Micro-Instrument Chapters

private struct TheoryChapterPlaygroundSheet: View {
    let chapter: TheoryChapter
    let palette: ChimmoPalette
    let synth: FeltPianoSynth
    let onComplete: () -> Void
    let onOpenNext: (TheoryChapter) -> Void
    let onFinishToCapture: () -> Void
    let onTryTheSwan: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var solved: Bool = false
    @State private var insightTitle: String = ""
    @State private var insightBody: String = ""
    @State private var playTask: Task<Void, Never>? = nil

    // Ch1: Pitch Altitude touch mountain
    @State private var ch1Trail: [(x: CGFloat, y: CGFloat, deg: Int)] = []
    @State private var ch1LastDeg: Int? = nil

    // Ch2: Heartbeat Lanterns & Note Length
    @State private var ch2IsWaltz: Bool = false
    @State private var ch2ActiveBeat: Int = -1
    @State private var ch2SlowBreath: Bool = false
    @State private var ch2Experiments: Int = 0

    // Ch3: Drag last bead home
    @State private var ch3DragDegree: Int = 4

    // Ch4: Narrow semitone staircase 7 -> 1↑
    @State private var ch4PushedUp: Bool = false

    // Ch5: Weather third slider (0 = major, 1 = minor)
    @State private var ch5IsMinor: Bool = false
    @State private var ch5Switches: Int = 0

    // Ch6: Spotlight triad builder (7 toggles)
    @State private var ch6Selected: Set<Int> = [1]
    @State private var ch6TriadsFound: Set<String> = []

    // Ch7: Swan texture studio
    @State private var ch7Texture: AccompanimentTexture = .pureChorale
    @State private var ch7Tried: Set<AccompanimentTexture> = []
    @State private var ch7PulseStep: Int = 0

    // Ch8: Question & Answer endings
    @State private var ch8ChosenEnding: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 顶部轻盈标签
                    VStack(alignment: .leading, spacing: 4) {
                        Text("第 \(chapter.rawValue)/8 关 · \(chapter.everydayMetaphor)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.isNight ? chapter.accentMember.nightGlowColor : chapter.accentMember.bodyColor)
                        Text(chapter.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }

                    // 专属交互小玩具舞台
                    Group {
                        switch chapter {
                        case .pitchAltitude: chapter1PitchAltitude
                        case .heartbeatRhythm: chapter2Heartbeat
                        case .findHome: chapter3FindHome
                        case .narrowSteps: chapter4NarrowSteps
                        case .weatherThird: chapter5WeatherThird
                        case .chordSpotlights: chapter6ChordSpotlights
                        case .swanTextureMagic: chapter7SwanTexture
                        case .questionAndAnswer: chapter8QuestionAnswer
                        }
                    }

                    // 顿悟揭晓卡（先体验、后揭晓乐理原名）
                    if !insightBody.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if !insightTitle.isEmpty {
                                Label(insightTitle, systemImage: solved ? "sparkles" : "ear.and.waveform")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(solved ? palette.homeAnchor : palette.primaryInk)
                            }
                            Text(insightBody)
                                .font(.subheadline)
                                .foregroundStyle(palette.primaryInk.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(solved ? palette.homeAnchor.opacity(0.14) : palette.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(solved ? palette.homeAnchor.opacity(0.5) : palette.divider, lineWidth: 1)
                                )
                        )
                    }

                    // 下一关引导按钮
                    if solved {
                        HStack(spacing: 10) {
                            if chapter == .swanTextureMagic {
                                Button {
                                    stopTask()
                                    onTryTheSwan()
                                } label: {
                                    Label("去听完整《天鹅》", systemImage: "water.waves")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(palette.bassRibbon.opacity(0.16)))
                                        .foregroundStyle(palette.bassRibbon)
                                }
                            }
                            Spacer()
                            if let next = TheoryChapter(rawValue: chapter.rawValue + 1) {
                                Button("下一关：\(next.title) →") {
                                    stopTask()
                                    onOpenNext(next)
                                }
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(palette.homeAnchor))
                                .foregroundStyle(palette.isNight ? Color(hex: 0x0E1726) : .white)
                            } else {
                                Button("去画布捉住我的脑放 →") {
                                    stopTask()
                                    onFinishToCapture()
                                }
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(palette.melodyTerracotta))
                                .foregroundStyle(.white)
                            }
                        }
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

    // MARK: Ch 1 — 一指画山坡（音高与旋律轮廓）

    private var chapter1PitchAltitude: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("把手指放在下面的晴空画布里，从左往右画一座「山峰」（先往上爬、再滑下来）。听听你的指尖高度怎样变成旋律！")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(palette.divider, lineWidth: 1)
                        )

                    Canvas { ctx, size in
                        // 轻柔的 7 条海拔参考线
                        for deg in 1...7 {
                            let y = size.height - 20 - CGFloat(deg - 1) / 6.0 * (size.height - 40)
                            var line = Path()
                            line.move(to: CGPoint(x: 16, y: y))
                            line.addLine(to: CGPoint(x: size.width - 16, y: y))
                            ctx.stroke(line, with: .color(palette.divider), lineWidth: 0.8)
                        }

                        if ch1Trail.count > 1 {
                            var path = Path()
                            path.move(to: CGPoint(x: ch1Trail[0].x, y: ch1Trail[0].y))
                            for pt in ch1Trail.dropFirst() {
                                path.addLine(to: CGPoint(x: pt.x, y: pt.y))
                            }
                            ctx.stroke(
                                path,
                                with: .linearGradient(
                                    Gradient(colors: [palette.homeAnchor, palette.bassRibbon, palette.melodyTerracotta]),
                                    startPoint: .zero,
                                    endPoint: CGPoint(x: size.width, y: 0)
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )

                            for pt in ch1Trail where ch1Trail.count < 40 {
                                let col = ChimmoMember.from(degree: pt.deg).bodyColor
                                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)), with: .color(col))
                            }
                        }
                    }

                    if ch1Trail.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "hand.draw.fill")
                                .font(.title2)
                                .foregroundStyle(palette.bassRibbon)
                            Text("用手指在这里上下画一座山峰")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.secondaryInk)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let h = max(60, geo.size.height)
                            let norm = max(0, min(1, 1.0 - (val.location.y - 16) / (h - 32)))
                            let deg = max(1, min(7, Int((norm * 6.0).rounded()) + 1))
                            ch1Trail.append((val.location.x, max(16, min(h - 16, val.location.y)), deg))
                            if ch1Trail.count > 65 { ch1Trail.removeFirst() }
                            if ch1LastDeg != deg {
                                ch1LastDeg = deg
                                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                                synth.playNote(frequency: hz, velocity: 0.56, decay: 1.1, brightness: 0.95)
                                fireHaptic(.light)
                            }
                            let uniqueDegs = Set(ch1Trail.map(\.deg))
                            if uniqueDegs.count >= 4 {
                                solved = true
                                onComplete()
                                insightTitle = "原来乐谱就是「声音的海拔地图」！"
                                insightBody = "你刚刚画出的高低曲线，在音乐里就叫「音高（Pitch）」与「旋律轮廓」。往上走像仰望或激动，往下走像叹息或落地——你闭着眼其实本来就懂音乐的形状！"
                            }
                        }
                        .onEnded { _ in
                            ch1LastDeg = nil
                        }
                )
            }
            .frame(height: 196)
        }
    }

    // MARK: Ch 2 — 心跳与呼吸（节拍强弱 & 音符长短）

    private var chapter2Heartbeat: some View {
        let beatsCount = ch2IsWaltz ? 3 : 4
        return VStack(alignment: .leading, spacing: 14) {
            Text("音乐不只是高高低低，还有像心脏一样的「强弱心跳」。试着切换「四拍漫步」和「三拍圆舞」，再拉长呼吸听听变化！")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            // 呼吸灯笼舞台
            HStack(spacing: 14) {
                ForEach(0..<beatsCount, id: \.self) { beat in
                    let isStrong = beat == 0
                    let isLit = ch2ActiveBeat == beat
                    let accent = isStrong ? palette.melodyTerracotta : palette.bassRibbon
                    VStack(spacing: 6) {
                        Circle()
                            .fill(accent.opacity(isLit ? 0.95 : 0.18))
                            .frame(width: isStrong ? 52 : 38, height: isStrong ? 52 : 38)
                            .scaleEffect(isLit ? 1.14 : 1.0)
                            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isLit)
                            .overlay(
                                Text(isStrong ? "重" : "轻")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(isLit ? .white : accent)
                            )
                        Text("第 \(beat + 1) 拍")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 108)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))

            HStack(spacing: 10) {
                Button {
                    ch2IsWaltz = false
                    ch2Experiments += 1
                    runHeartbeatDemo()
                } label: {
                    Label("四拍漫步 (4/4)", systemImage: "figure.walk")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(!ch2IsWaltz ? palette.bassRibbon : palette.cardSurface))
                        .foregroundStyle(!ch2IsWaltz ? .white : palette.primaryInk)
                }

                Button {
                    ch2IsWaltz = true
                    ch2Experiments += 1
                    runHeartbeatDemo()
                } label: {
                    Label("三拍圆舞 (3/4)", systemImage: "wind")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(ch2IsWaltz ? palette.harmonyWash : palette.cardSurface))
                        .foregroundStyle(ch2IsWaltz ? .white : palette.primaryInk)
                }
            }

            Toggle(isOn: $ch2SlowBreath) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("拉长每颗音的呼吸（像《天鹅》一样舒展）")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.primaryInk)
                    Text("开启后再点上面播放，感受「长音 vs 短音」如何改写情绪")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                }
            }
            .tint(palette.homeAnchor)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.cardSurface))
            .onChange(of: ch2SlowBreath) { _, _ in
                ch2Experiments += 1
                runHeartbeatDemo()
            }
        }
    }

    private func runHeartbeatDemo() {
        stopTask()
        let isWaltz = ch2IsWaltz
        let slow = ch2SlowBreath
        let notes = isWaltz ? [1, 3, 5, 6, 5, 3] : [1, 3, 5, 3, 4, 3, 2, 1]
        let beatsPerBar = isWaltz ? 3 : 4
        let stepNs: UInt64 = slow ? 520_000_000 : 320_000_000

        playTask = Task { @MainActor in
            for (idx, deg) in notes.enumerated() {
                if Task.isCancelled { return }
                let beat = idx % beatsPerBar
                ch2ActiveBeat = beat
                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                synth.playNote(frequency: hz, velocity: beat == 0 ? 0.65 : 0.48, decay: slow ? 1.8 : 0.9, brightness: 0.95)
                if beat == 0 {
                    synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: idx < beatsPerBar ? .I : .IV, texture: isWaltz ? .feltWaltz : .pureChorale, intensity: 0.55)
                }
                try? await Task.sleep(nanoseconds: stepNs)
            }
            ch2ActiveBeat = -1
            if ch2Experiments >= 2 {
                solved = true
                onComplete()
                insightTitle = "音乐 = 海拔（音高）× 心跳（节拍与长短）"
                insightBody = "四拍子（强-弱-次强-弱）像走路，大多数流行歌都用它；三拍子（强-弱-弱）像荡秋千，正是《天鹅》、肖邦夜曲与巴赫小步舞曲摇曳优美的秘诀！"
            } else {
                insightTitle = "再切换另一种心跳对比听听看！"
                insightBody = "刚才听的是 \(isWaltz ? "三拍摇曳圆舞" : "四拍稳步漫行")，试试点另一个按钮或打开「拉长呼吸」。"
            }
        }
    }

    // MARK: Ch 3 — 亲手上下拖音珠回家（主音 1 Do）

    private var chapter3FindHome: some View {
        let fixed = [5, 4, 3, 2]
        return VStack(alignment: .leading, spacing: 12) {
            Text("下面有一句走到一半的旋律（5→4→3→2→?）。用手指直接上下拖动最后一颗发光陶珠，找出唯一让你耳朵「彻底松一口气」的家！")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.cardSurface)

                    // 1 号家的温暖地平线
                    let homeY = h - 26
                    Path { p in
                        p.move(to: CGPoint(x: 16, y: homeY))
                        p.addLine(to: CGPoint(x: w - 16, y: homeY))
                    }
                    .stroke(palette.homeAnchor.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

                    Text("1·陶诺（家）")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.homeAnchor)
                        .position(x: 56, y: homeY - 12)

                    // 前 4 颗固定音珠
                    ForEach(0..<fixed.count, id: \.self) { idx in
                        let deg = fixed[idx]
                        let x = 36 + CGFloat(idx) * ((w - 92) / 4.0)
                        let y = h - 26 - CGFloat(deg - 1) / 5.0 * (h - 56)
                        let m = ChimmoMember.from(degree: deg)
                        Circle()
                            .fill(m.bodyColor.opacity(0.85))
                            .frame(width: 24, height: 24)
                            .overlay(Text("\(deg)").font(.caption2.weight(.bold)).foregroundStyle(.white))
                            .position(x: x, y: y)
                    }

                    // 第 5 颗可亲手上下拖拽的陶珠！
                    let dragX = w - 42
                    let dragY = h - 26 - CGFloat(ch3DragDegree - 1) / 5.0 * (h - 56)
                    let dragM = ChimmoMember.from(degree: ch3DragDegree)
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(dragM.bodyColor)
                        Circle()
                            .fill(dragM.bodyColor)
                            .frame(width: 34, height: 34)
                            .shadow(color: dragM.bodyColor.opacity(0.45), radius: 8)
                            .overlay(Text("\(ch3DragDegree)").font(.subheadline.weight(.bold)).foregroundStyle(.white))
                    }
                    .position(x: dragX, y: dragY)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let norm = max(0, min(1, (h - 26 - val.location.y) / max(40, h - 56)))
                                let nextDeg = max(1, min(6, Int((norm * 5.0).rounded()) + 1))
                                if nextDeg != ch3DragDegree {
                                    ch3DragDegree = nextDeg
                                    fireHaptic(.light)
                                    let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: nextDeg, octaveOffset: 0)
                                    synth.playNote(frequency: hz, velocity: 0.62, decay: 1.2, brightness: 0.95)
                                }
                            }
                            .onEnded { _ in
                                playPhrase([5, 4, 3, 2, ch3DragDegree], mode: .brightMajor)
                                if ch3DragDegree == 1 {
                                    solved = true
                                    onComplete()
                                    insightTitle = "找到了！这就是乐理里的「主音（Tonic）」"
                                    insightBody = "无论旋律在外面走多远，落回 1·陶诺（Do）的那一刻都会有「句号落地」的安稳感。作曲家就是靠「离家—悬停—回家」制造故事起伏的！"
                                } else {
                                    insightTitle = "停在 \(ch3DragDegree)·\(dragM.chineseName) 还有点意犹未尽…"
                                    insightBody = "试试把右侧这颗珠子一直往下拖到最底部的「1·陶诺」暖线，再松手听听看！"
                                }
                            }
                    )
                }
            }
            .frame(height: 196)
        }
    }

    // MARK: Ch 4 — 发光半音楼梯（7→1↑ 窄台阶魔力）

    private var chapter4NarrowSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("大多数人以为 1 到 7 每级台阶一样宽——其实错了！大调里「3 和 4」「7 和高音 1↑」之间只隔了半步（半音），挨得特别近，像磁铁一样互相吸引。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            VStack(spacing: 8) {
                // 高音 1↑ 台阶
                HStack {
                    Text("高音 1↑ · 陶诺（高楼的家）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.homeAnchor)
                    Spacer()
                    Circle()
                        .fill(ChimmoMember.taono.bodyColor.opacity(ch4PushedUp ? 1.0 : 0.35))
                        .frame(width: ch4PushedUp ? 30 : 22, height: ch4PushedUp ? 30 : 22)
                        .shadow(color: ch4PushedUp ? ChimmoMember.taono.bodyColor.opacity(0.5) : .clear, radius: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(palette.homeAnchor.opacity(ch4PushedUp ? 0.18 : 0.08)))

                // 窄缝视觉标签
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text(ch4PushedUp ? "已跨过半音窄缝！听见那股「舒了一口气」的魔力了吗？" : "仅隔 1 个半音（极窄磁铁缝！）")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(ch4PushedUp ? palette.homeAnchor : palette.tensionFilament)

                // 7·叮尖台阶
                HStack {
                    Text("7 · 叮尖（悬在半空的导音）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.tensionFilament)
                    Spacer()
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ChimmoMember.tinki.bodyColor)
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(45))
                        .opacity(ch4PushedUp ? 0.35 : 1.0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(palette.tensionFilament.opacity(0.10)))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))

            HStack(spacing: 10) {
                Button {
                    ch4PushedUp = false
                    playPhrase([1, 3, 5, 7], mode: .brightMajor)
                    insightTitle = "听见憋着一口气的紧绷感了吗？"
                    insightBody = "停在 7·叮尖就像快要打喷嚏却没打出来——点右边按钮把它推上半步试试！"
                } label: {
                    Text("1. 先听悬在 7")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.cardSurface))
                        .foregroundStyle(palette.primaryInk)
                }

                Button {
                    ch4PushedUp = true
                    playPhrase([1, 3, 5, 7, 8], mode: .brightMajor)
                    solved = true
                    onComplete()
                    insightTitle = "这就是「半音」与「导音解决（7→1↑）」！"
                    insightBody = "因为距离只有别的台阶的一半，7 对高音 1↑ 有最强的磁铁引力。在主画布左侧，红标「半」字标出的正是这些充满情感张力的窄台阶！"
                } label: {
                    Text("2. 推上半步回家 →")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.melodyTerracotta))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: Ch 5 — 晴雨拉杆（大调 3 vs 小调 ♭3）

    private var chapter5WeatherThird: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("大调听起来像阳光草坡，小调像月夜细雨——其实最大的秘密全在「3·拍咯」一人身上！点下方开关把它往下降半格听听看。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            HStack(spacing: 16) {
                ChimmoFigureView(
                    member: .plokko,
                    isNight: palette.isNight,
                    isMinor: ch5IsMinor,
                    isSinging: true,
                    time: 0,
                    listeningTilt: 0
                )
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ch5IsMinor ? "🌧 微雨小调（3·拍咯下移半格）" : "☀️ 晴空大调（标准 3·拍咯）")
                        .font(.headline)
                        .foregroundStyle(palette.primaryInk)
                    Text(ch5IsMinor ? "就像柴可夫斯基《天鹅湖》与月光下的思念" : "就像圣桑《天鹅》与夏日清澈的晴空")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill((ch5IsMinor ? palette.harmonyWash : palette.melodyTerracotta).opacity(0.12))
            )

            HStack(spacing: 12) {
                Button {
                    ch5IsMinor = false
                    ch5Switches += 1
                    playPhrase([1, 2, 3, 5, 3, 1], mode: .brightMajor)
                    checkCh5()
                } label: {
                    Label("晴空大调", systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(!ch5IsMinor ? palette.melodyTerracotta : palette.cardSurface))
                        .foregroundStyle(!ch5IsMinor ? .white : palette.primaryInk)
                }

                Button {
                    ch5IsMinor = true
                    ch5Switches += 1
                    playPhrase([1, 2, 3, 5, 3, 1], mode: .wistfulMinor)
                    checkCh5()
                } label: {
                    Label("降半格 · 微雨小调", systemImage: "cloud.rain.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(ch5IsMinor ? palette.harmonyWash : palette.cardSurface))
                        .foregroundStyle(ch5IsMinor ? .white : palette.primaryInk)
                }
            }
        }
    }

    private func checkCh5() {
        if ch5Switches >= 2 {
            solved = true
            onComplete()
            insightTitle = "原来「大调 / 小调」只差半个台阶的距离！"
            insightBody = "3·拍咯（Mi）往下降半个音变成 ♭3，情绪就从明朗转向深情忧郁。等会去名曲库对比听圣桑《天鹅》（大调）和柴可夫斯基《天鹅湖》（小调），你会瞬间听透！"
        } else {
            insightTitle = "再点一下另一边的天气按钮！"
            insightBody = "让耳朵亲自对比同一串音符在晴空大调与微雨小调里的神奇变身。"
        }
    }

    // MARK: Ch 6 — 亲手隔一个点亮三只咩哞（三和弦聚光灯）

    private var chapter6ChordSpotlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("「和弦」其实超简单：在 1~7 里「隔一只选一只」点亮 3 只咩哞同时发声，就是最和谐的三和弦！试试点亮 1·3·5、4·6·1 或 5·7·2：")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { deg in
                    let m = ChimmoMember.from(degree: deg)
                    let on = ch6Selected.contains(deg)
                    let col = palette.isNight ? m.nightGlowColor : m.bodyColor
                    Button {
                        if on {
                            ch6Selected.remove(deg)
                        } else {
                            if ch6Selected.count >= 3 { ch6Selected.removeAll() }
                            ch6Selected.insert(deg)
                        }
                        let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                        synth.playNote(frequency: hz, velocity: 0.52, decay: 1.2, brightness: 0.92)
                        evaluateCh6Selection()
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(on ? col : col.opacity(0.18))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Text("\(deg)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(on ? .white : col)
                                )
                            Text(m.chineseName)
                                .font(.system(size: 9.5, weight: on ? .bold : .regular))
                                .foregroundStyle(on ? palette.primaryInk : palette.secondaryInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(on ? col.opacity(0.14) : palette.cardSurface))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                quickTriadButton(label: "快捷点亮 I (1·3·5)", set: [1, 3, 5])
                quickTriadButton(label: "IV (4·6·1)", set: [4, 6, 1])
                quickTriadButton(label: "V (5·7·2)", set: [5, 7, 2])
            }
        }
    }

    private func quickTriadButton(label: String, set: Set<Int>) -> some View {
        Button(label) {
            ch6Selected = set
            evaluateCh6Selection()
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(palette.shelfSurface))
        .foregroundStyle(palette.primaryInk)
    }

    private func evaluateCh6Selection() {
        let sorted = ch6Selected.sorted()
        guard sorted.count == 3 else {
            insightTitle = "已点亮 \(sorted.count)/3 只聚光灯"
            insightBody = "继续按「隔一只选一只」点亮第 3 只咩哞（比如 1、3、5），听它们合鸣！"
            return
        }

        let matched: DiatonicChord?
        switch sorted {
        case [1, 3, 5]: matched = .I
        case [2, 4, 6]: matched = .ii
        case [3, 5, 7]: matched = .iii
        case [1, 4, 6]: matched = .IV
        case [2, 5, 7]: matched = .V
        case [1, 3, 6]: matched = .vi
        default: matched = nil
        }

        if let ch = matched {
            synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: ch, texture: .pureChorale, intensity: 0.9)
            ch6TriadsFound.insert(ch.roman)
            solved = true
            onComplete()
            insightTitle = "点亮了 \(ch.roman) 和弦（\(ch.tonesFormula) · \(ch.moodTitle)）！"
            insightBody = "这就是乐理里的「三和弦」！在创作画布里，当你选了 \(ch.roman) 和弦，它的 3 条音高泳道就会亮成同色光带——旋律踩进光带里就稳稳和谐！"
        } else {
            for (i, d) in sorted.enumerated() {
                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: d, octaveOffset: 0)
                synth.playNote(frequency: hz, velocity: 0.42, decay: 1.0, delaySeconds: Double(i) * 0.03)
            }
            insightTitle = "这三只挤得有点近，听出碰撞感了吗？"
            insightBody = "因为相邻两个音挨在一起会互相打架！试试「隔一只选一只」，比如点亮 1·3·5 或 4·6·1。"
        }
    }

    // MARK: Ch 7 — 《天鹅》水波的秘密（4 种大师左手伴奏织体实时对比！）

    private var chapter7SwanTexture: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("为什么同样弹「I → vi → IV → V」四个和弦，电子琴听起来像打卡，圣桑《天鹅》听起来却像天鹅滑过湖面？点下面 4 种「左手弹法」亲自对比！")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            VStack(spacing: 9) {
                ForEach(AccompanimentTexture.allCases) { tex in
                    let selected = ch7Texture == tex
                    Button {
                        ch7Texture = tex
                        ch7Tried.insert(tex)
                        playTextureDemo(tex)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tex.iconName)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill((selected ? palette.bassRibbon : palette.secondaryInk).opacity(0.16)))
                                .foregroundStyle(selected ? palette.bassRibbon : palette.secondaryInk)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tex.label)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Text(tex.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryInk)
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(palette.bassRibbon)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(palette.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(selected ? palette.bassRibbon : palette.divider, lineWidth: selected ? 1.5 : 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func playTextureDemo(_ tex: AccompanimentTexture) {
        stopTask()
        let prog: [DiatonicChord] = [.I, .vi, .IV, .V]
        playTask = Task { @MainActor in
            for (idx, ch) in prog.enumerated() {
                if Task.isCancelled { return }
                ch7PulseStep = idx
                synth.playDiatonicChord(
                    rootMIDI: 58,
                    mode: .brightMajor,
                    chord: ch,
                    texture: tex,
                    spanDuration: 1.35,
                    intensity: 0.90
                )
                try? await Task.sleep(nanoseconds: 1_250_000_000)
            }
            if ch7Tried.count >= 2 {
                solved = true
                onComplete()
                insightTitle = "你刚刚揭开了编曲最核心的秘密：「音乐织体（Texture）」！"
                insightBody = "和弦完全没变，只要把三个音拆成流动的「天鹅水波」或加上透明高音泛音的「夏日清风」，音乐立刻有了画面感！在创作页，你可以把这 4 种大师织体一键套在自己哼的旋律上！"
            } else {
                insightTitle = "正在试听「\(tex.label)」"
                insightBody = "再点一种别的织体（强烈推荐对比「天鹅水波」和「夏日清风」）！"
            }
        }
    }

    // MARK: Ch 8 — 问句与答句（一首歌怎么写完）

    private var chapter8QuestionAnswer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("写歌其实就像聊天：先抛出一句停在 5·壳咯 的「问句」（1→3→5→6→5），再给它配上一句「答句」。挑一种你最喜欢的电影结局听听看：")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)

            VStack(spacing: 10) {
                endingChoiceCard(
                    id: 1,
                    title: "结局 A · 稳稳回家（4→3→2→1）",
                    desc: "像童话圆满收尾，踏实、温暖、有句号感",
                    answer: [4, 3, 2, 1],
                    chord: .I,
                    lesson: "古典与民谣最经典的「完全终止（归家）」！你已经完整看懂了音高、节拍、半音、大小调、和弦、织体与乐句结构——现在就去捉住你脑海里的第一段旋律吧！"
                )
                endingChoiceCard(
                    id: 2,
                    title: "结局 B · 电影怀旧余味（4→3→5→6）",
                    desc: "不回 1 而是轻轻落在 6·钵莫，留下温柔未完的夏日思绪",
                    answer: [4, 3, 5, 6],
                    chord: .vi,
                    lesson: "这就是东亚治愈动画配乐最爱用的「微酸留白收尾（落 vi 级）」！你已经解锁全部 8 关音律脱盲，现在去把脑放哼出来、套上夏日清风或天鹅水波试试吧！"
                )
                endingChoiceCard(
                    id: 3,
                    title: "结局 C · 飞向天空高潮（6→7→1↑）",
                    desc: "靠 7·叮尖的半音磁铁一举推上高音 1↑，气势豁然开朗！",
                    answer: [6, 7, 8],
                    chord: .I,
                    lesson: "把第 4 关学过的 7→1↑ 半音牵引放进副歌结尾，瞬间引爆情绪高潮！你已彻底脱盲，快去主画布记录属于自己的脑放旋律吧！"
                )
            }
        }
    }

    private func endingChoiceCard(id: Int, title: String, desc: String, answer: [Int], chord: DiatonicChord, lesson: String) -> some View {
        let selected = ch8ChosenEnding == id
        return Button {
            ch8ChosenEnding = id
            playPhrase([1, 3, 5, 6, 5] + answer, mode: .brightMajor, finalChord: chord)
            solved = true
            onComplete()
            insightTitle = "恭喜通关全部 8 关音律启蒙！"
            insightBody = lesson
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryInk)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(selected ? palette.homeAnchor : palette.bassRibbon)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(palette.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(selected ? palette.homeAnchor : palette.divider, lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Shared Helpers

    private func stopTask() {
        playTask?.cancel()
        playTask = nil
    }

    private func playPhrase(_ steps: [Int], mode: ScaleMode, finalChord: DiatonicChord? = nil) {
        stopTask()
        playTask = Task { @MainActor in
            for (idx, step) in steps.enumerated() {
                if Task.isCancelled { return }
                let deg = step > 7 ? 1 : step
                let oct = step > 7 ? 1 : 0
                let hz = mode.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: oct)
                synth.playNote(frequency: hz, velocity: 0.60, decay: 1.5, brightness: 0.95)
                if idx == 0 {
                    synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: .I, texture: .summerGlass, intensity: 0.55)
                } else if idx == steps.count - 1 {
                    let ch = finalChord ?? ((deg == 1) ? .I : (deg == 7 ? .V : .IV))
                    synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: ch, texture: .summerGlass, intensity: 0.65)
                }
                try? await Task.sleep(nanoseconds: 340_000_000)
            }
        }
    }

    private func fireHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}
