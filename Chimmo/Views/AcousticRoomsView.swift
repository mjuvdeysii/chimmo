import SwiftUI

/// 《音律长夜》——借鉴《OTTOSSOM》房间解谜与《摸索台灯》蒙氏金色串珠链的「零说教声学小房间」：
/// 不背术语、不做选择题，只靠移动七只咩哞、挪动脚下的台灯、按住半秒张力与感受掌心震动来打通 6 间声音小房间。
public enum AcousticRoom: Int, CaseIterable, Identifiable, Sendable {
    case homeBeforeDark = 1
    case lampBeneathFeet = 2
    case holdHalfSecond = 3
    case twinStringLotus = 4
    case mirrorLakeEcho = 5
    case fiveSkiesDial = 6

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .homeBeforeDark: return "熄灯前回家"
        case .lampBeneathFeet: return "换一盏脚下的灯"
        case .holdHalfSecond: return "拉住那半秒"
        case .twinStringLotus: return "两根弦的莲花"
        case .mirrorLakeEcho: return "镜子湖的回声"
        case .fiveSkiesDial: return "一根弦上的五片天"
        }
    }

    public var poeticPrompt: String {
        switch self {
        case .homeBeforeDark: return "把悬空发抖的石块推到让房间暖灯亮起的位置。"
        case .lampBeneathFeet: return "主角站在原地不动，换三盏脚下的灯，看世界变色。"
        case .holdHalfSecond: return "水波已靠岸，按住 4·呜嘟 多撑半秒，再松手融化。"
        case .twinStringLotus: return "沿琴弦拖动水晶珠，让颤抖的波纹锁成静止的莲花。"
        case .mirrorLakeEcho: return "在湖岸放 3 颗石子，听湖面倒映出巴赫式回声。"
        case .fiveSkiesDial: return "拨动日月盘，看每换一片天空只有一只咩哞迈下半步。"
        }
    }

    public var musicianFootnote: String {
        switch self {
        case .homeBeforeDark: return "音乐家叫它「主音引力（Tonic）」：所有旋律离家远航，终要归回 1·Do。"
        case .lampBeneathFeet: return "音乐家叫它「和声关系」：孤立音符没有悲喜，关系决定色彩。"
        case .holdHalfSecond: return "音乐家叫它「延留音（Suspension）」：那半秒迟到与摩擦，正是催泪瞬间。"
        case .twinStringLotus: return "音乐家叫它「纯律整数比（3:2 / 2:1）」：和谐是两束声波的几何静止。"
        case .mirrorLakeEcho: return "音乐家叫它「动机倒影与分形生长」：大师用 3 颗火种折出整首诗。"
        case .fiveSkiesDial: return "音乐家叫它「五色调式光谱」：云端到暮雨，每步恰好只降 1 个半音。"
        }
    }

    public var hostMember: ChimmoMember {
        switch self {
        case .homeBeforeDark: return .taono
        case .lampBeneathFeet: return .plokko
        case .holdHalfSecond: return .udo
        case .twinStringLotus: return .corllo
        case .mirrorLakeEcho: return .bomo
        case .fiveSkiesDial: return .tinki
        }
    }
}

public struct AcousticRoomsView: View {
    public let palette: ChimmoPalette
    public let synth: FeltPianoSynth
    @Binding public var solvedRooms: Set<Int>
    public let onSendRoomMelodyToBook: ([NoteBead], ScaleMode) -> Void
    public let onOpenSwanPeeler: () -> Void
    public let onOpenAdvancedLab: () -> Void

    @State private var activeRoom: AcousticRoom? = nil

    public init(
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        solvedRooms: Binding<Set<Int>>,
        onSendRoomMelodyToBook: @escaping ([NoteBead], ScaleMode) -> Void,
        onOpenSwanPeeler: @escaping () -> Void,
        onOpenAdvancedLab: @escaping () -> Void
    ) {
        self.palette = palette
        self.synth = synth
        self._solvedRooms = solvedRooms
        self.onSendRoomMelodyToBook = onSendRoomMelodyToBook
        self.onOpenSwanPeeler = onOpenSwanPeeler
        self.onOpenAdvancedLab = onOpenAdvancedLab
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 顶部：蒙氏金色串珠进度链（走过的房间珠子变暖金色，绝无打卡催促）
                        beadChainHeader

                        // 房间 1 占据整行主角位（遵循《摸索台灯》主次版面法则），其余成对或整行呼应
                        let nextRoom = AcousticRoom.allCases.first { !solvedRooms.contains($0.rawValue) } ?? .homeBeforeDark
                        featuredRoomCard(nextRoom)

                        // 全部 6 间声学小房间网格（偶数 2 列，不留半行空白）
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(AcousticRoom.allCases) { room in
                                compactRoomTile(room)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("声学小房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenAdvancedLab()
                    } label: {
                        Label("混音与基础", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .fullScreenCover(item: $activeRoom) { room in
                AcousticRoomPlayStage(
                    room: room,
                    palette: palette,
                    synth: synth,
                    alreadySolved: solvedRooms.contains(room.rawValue),
                    onSolved: {
                        solvedRooms.insert(room.rawValue)
                        UserDefaults.standard.set(Array(solvedRooms), forKey: "chimmo_solved_rooms")
                    },
                    onOpenNext: { next in
                        activeRoom = next
                    },
                    onSendMelodyToBook: { beads, mode in
                        activeRoom = nil
                        onSendRoomMelodyToBook(beads, mode)
                    }
                )
                .id(room.id)
            }
        }
    }

    private var beadChainHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("摸一摸，点亮 6 间声音小房")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                Spacer()
                Text("\(solvedRooms.count)/\(AcousticRoom.allCases.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.nightLampGold)
            }

            // 蒙氏串珠链（已点亮的变成 Otto 暖金珠，未点亮为柔和陶土珠）
            ZStack {
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 2)
                    .padding(.horizontal, 18)

                HStack {
                    ForEach(AcousticRoom.allCases) { r in
                        let lit = solvedRooms.contains(r.rawValue)
                        Button {
                            activeRoom = r
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(lit ? palette.nightLampGold : palette.shelfSurface)
                                    .frame(width: lit ? 30 : 24, height: lit ? 30 : 24)
                                    .shadow(color: lit ? palette.nightLampGold.opacity(0.45) : .clear, radius: 6)
                                if lit {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: 0x1B2245))
                                } else {
                                    Text("\(r.rawValue)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(palette.secondaryInk)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        if r != AcousticRoom.allCases.last { Spacer() }
                    }
                }
            }
            .frame(height: 34)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardSurface)
                .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.2 : 0.04), radius: 10, y: 3)
        )
    }

    private func featuredRoomCard(_ room: AcousticRoom) -> some View {
        let accent = palette.isNight ? room.hostMember.nightGlowColor : room.hostMember.bodyColor
        return Button {
            activeRoom = room
        } label: {
            HStack(spacing: 14) {
                ChimmoFigureView(
                    member: room.hostMember,
                    isNight: palette.isNight,
                    isMinor: false,
                    isSinging: false,
                    time: 0,
                    listeningTilt: 0
                )
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 4) {
                    Text("下一间等待点亮的房 · 0\(room.rawValue)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                    Text(room.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Text(room.poeticPrompt)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(palette.homeAnchor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.cardSurface)
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.24 : 0.05), radius: 12, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func compactRoomTile(_ room: AcousticRoom) -> some View {
        let solved = solvedRooms.contains(room.rawValue)
        let accent = palette.isNight ? room.hostMember.nightGlowColor : room.hostMember.bodyColor

        return Button {
            activeRoom = room
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ChimmoFigureView(
                        member: room.hostMember,
                        isNight: palette.isNight,
                        isMinor: false,
                        isSinging: solved,
                        time: 0,
                        listeningTilt: 0
                    )
                    .frame(width: 42, height: 42)
                    Spacer()
                    if solved {
                        Circle()
                            .fill(palette.nightLampGold)
                            .frame(width: 12, height: 12)
                            .shadow(color: palette.nightLampGold.opacity(0.6), radius: 4)
                    } else {
                        Text("0\(room.rawValue)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(accent)
                    }
                }

                Text(room.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.primaryInk)
                    .lineLimit(1)

                Text(room.poeticPrompt)
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(solved ? palette.nightLampGold.opacity(0.55) : palette.divider, lineWidth: 1)
                    )
                    .shadow(color: palette.primaryInk.opacity(palette.isNight ? 0.18 : 0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OTTOSSOM-Inspired Zero-Text Interactive Room Stage

private struct AcousticRoomPlayStage: View {
    let room: AcousticRoom
    let palette: ChimmoPalette
    let synth: FeltPianoSynth
    let alreadySolved: Bool
    let onSolved: () -> Void
    let onOpenNext: (AcousticRoom) -> Void
    let onSendMelodyToBook: ([NoteBead], ScaleMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var solved: Bool
    @State private var showFootnote: Bool = false
    @State private var playTask: Task<Void, Never>? = nil

    // Room 1: Stepping stones home (drag loose stone to 1)
    @State private var r1StoneDegree: Int = 5

    // Room 2: Lamp beneath feet (3·Plokko stays still, move 4 floor lamps)
    @State private var r2LampIndex: Int = 0
    @State private var r2Tried: Set<Int> = []

    // Room 3: Hold half a second (4 -> 3 tearful suspension)
    @State private var r3Holding: Bool = false

    // Room 4: Twin string lotus (continuous ratio + haptics)
    @State private var r4Semis: Double = 1.0
    @State private var r4Continuous: Bool = true
    @State private var r4LastInt: Int = 1

    // Room 5: Mirror lake echo (3 stones -> Bach mirror)
    @State private var r5Seed: [Int] = [1, 3, 5]
    @State private var r5Grown: [NoteBead] = []

    // Room 6: Five skies dial
    @State private var r6Sky: ScaleMode = .brightMajor
    @State private var r6Tried: Set<ScaleMode> = [.brightMajor]

    init(
        room: AcousticRoom,
        palette: ChimmoPalette,
        synth: FeltPianoSynth,
        alreadySolved: Bool,
        onSolved: @escaping () -> Void,
        onOpenNext: @escaping (AcousticRoom) -> Void,
        onSendMelodyToBook: @escaping ([NoteBead], ScaleMode) -> Void
    ) {
        self.room = room
        self.palette = palette
        self.synth = synth
        self.alreadySolved = alreadySolved
        self.onSolved = onSolved
        self.onOpenNext = onOpenNext
        self.onSendMelodyToBook = onSendMelodyToBook
        self._solved = State(initialValue: alreadySolved)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientPaperBackdrop(palette: palette)

                VStack(spacing: 16) {
                    // 极简一句话提示（无长段说教）
                    VStack(spacing: 4) {
                        Text("房间 0\(room.rawValue) · \(room.title)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text(room.poeticPrompt)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 18)

                    // 沉浸式互动房间舞台
                    Group {
                        switch room {
                        case .homeBeforeDark: room1Stage
                        case .lampBeneathFeet: room2Stage
                        case .holdHalfSecond: room3Stage
                        case .twinStringLotus: room4Stage
                        case .mirrorLakeEcho: room5Stage
                        case .fiveSkiesDial: room6Stage
                        }
                    }
                    .padding(.horizontal, 16)

                    // 通关后温柔点亮的底部金色栏（先感受，点一下才悄悄揭晓音乐家叫它什么）
                    if solved {
                        VStack(spacing: 10) {
                            if showFootnote {
                                Text(room.musicianFootnote)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(palette.primaryInk)
                                    .multilineTextAlignment(.center)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(palette.nightLampGold.opacity(0.16)))
                            }

                            HStack(spacing: 10) {
                                Button(showFootnote ? "收起注解" : "💡 音乐家叫它…") {
                                    withAnimation(.easeInOut(duration: 0.2)) { showFootnote.toggle() }
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(palette.cardSurface))
                                .foregroundStyle(palette.primaryInk)

                                Spacer()

                                if let next = AcousticRoom(rawValue: room.rawValue + 1) {
                                    Button("进入下一间房 →") {
                                        stopAudio()
                                        onOpenNext(next)
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(palette.homeAnchor))
                                    .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                                } else {
                                    Button("全部点亮！回桌面") {
                                        stopAudio()
                                        dismiss()
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(palette.nightLampGold))
                                    .foregroundStyle(Color(hex: 0x1B2245))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 14)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("离开房间") {
                        stopAudio()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if room == .twinStringLotus {
                    let topHz = 261.63 * pow(2.0, r4Semis / 12.0)
                    synth.setContinuousPair(hzA: 261.63, hzB: topHz, gain: 0.22)
                }
            }
            .onDisappear { stopAudio() }
        }
    }

    private func markRoomLit() {
        if !solved {
            solved = true
            onSolved()
        }
        AcousticHapticsEngine.shared.playResolutionExhale()
    }

    private func stopAudio() {
        playTask?.cancel()
        playTask = nil
        synth.stopContinuousPair()
    }

    // MARK: Room 1 — 熄灯前回家（拖动石块回到暖金底座 1·陶诺）

    private var room1Stage: some View {
        let fixedSteps = [5, 4, 3, 2]
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let homeY = h - 42

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(solved ? Color(hex: 0x1B2245) : palette.cardSurface)
                    .overlay(
                        RadialGradient(
                            colors: [palette.nightLampGold.opacity(solved ? 0.36 : 0.06), .clear],
                            center: UnitPoint(x: 0.85, y: 0.82),
                            startRadius: 6,
                            endRadius: 220
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
                    .shadow(color: palette.primaryInk.opacity(0.06), radius: 12, y: 4)

                // 暖金归家地平线
                Path { p in
                    p.move(to: CGPoint(x: 20, y: homeY))
                    p.addLine(to: CGPoint(x: w - 20, y: homeY))
                }
                .stroke(palette.nightLampGold.opacity(solved ? 0.9 : 0.45), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

                // 前 4 只已站好位的石阶小偶
                ForEach(0..<fixedSteps.count, id: \.self) { idx in
                    let deg = fixedSteps[idx]
                    let x = 44 + CGFloat(idx) * ((w - 110) / 4.0)
                    let y = homeY - CGFloat(deg - 1) / 5.0 * (h - 96)
                    ChimmoFigureView(
                        member: ChimmoMember.from(degree: deg),
                        isNight: solved || palette.isNight,
                        isMinor: false,
                        isSinging: false,
                        focusedDegree: r1StoneDegree,
                        time: 0,
                        listeningTilt: 0
                    )
                    .frame(width: 44, height: 44)
                    .position(x: x, y: y)
                }

                // 最后一只可上下亲手推动的小偶（拖到最底部暖线即点亮整间房！）
                let dragX = w - 48
                let dragY = homeY - CGFloat(r1StoneDegree - 1) / 5.0 * (h - 96)
                VStack(spacing: 2) {
                    if !solved {
                        Image(systemName: "arrow.up.and.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.tensionFilament)
                    }
                    ChimmoFigureView(
                        member: ChimmoMember.from(degree: r1StoneDegree),
                        isNight: solved || palette.isNight,
                        isMinor: false,
                        isSinging: solved,
                        focusedDegree: 1,
                        time: 0,
                        listeningTilt: solved ? 0 : 0.35
                    )
                    .frame(width: 58, height: 58)
                }
                .position(x: dragX, y: dragY)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("room1Stage"))
                        .onChanged { val in
                            let norm = max(0, min(1, (homeY - val.location.y) / max(60, h - 96)))
                            let next = max(1, min(6, Int((norm * 5.0).rounded()) + 1))
                            if next != r1StoneDegree {
                                r1StoneDegree = next
                                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: next, octaveOffset: 0)
                                synth.playNote(frequency: hz, velocity: 0.58, decay: 1.2, timbre: .singingCello)
                                AcousticHapticsEngine.shared.playBeatTap(isStrong: next == 1)
                            }
                        }
                        .onEnded { _ in
                            playRoom1Cadence(ending: r1StoneDegree)
                            if r1StoneDegree == 1 {
                                markRoomLit()
                            }
                        }
                )
            }
            .coordinateSpace(name: "room1Stage")
        }
        .frame(maxHeight: .infinity)
    }

    private func playRoom1Cadence(ending: Int) {
        playTask?.cancel()
        let seq = [5, 4, 3, 2, ending]
        playTask = Task { @MainActor in
            for (i, d) in seq.enumerated() {
                if Task.isCancelled { return }
                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: d, octaveOffset: 0)
                synth.playNote(frequency: hz, velocity: 0.60, decay: 1.5, timbre: .singingCello)
                if i == seq.count - 1 {
                    synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: d == 1 ? .I : .V, texture: .swanRipple, intensity: 0.72)
                }
                try? await Task.sleep(nanoseconds: 340_000_000)
            }
        }
    }

    // MARK: Room 2 — 换一盏脚下的灯（3·拍咯不动，换底灯变世界）

    private struct FloorLamp {
        let icon: String
        let title: String
        let tint: Color
        let bassHz: [Double]
    }

    private var r2Lamps: [FloorLamp] {
        [
            FloorLamp(icon: "sun.max.fill", title: "暖阳灯", tint: Color(hex: 0xF25563), bassHz: [130.81, 196.0, 261.63]),
            FloorLamp(icon: "cloud.rain.fill", title: "蓝雨灯", tint: Color(hex: 0x5C7CFA), bassHz: [110.0, 164.81, 220.0]),
            FloorLamp(icon: "water.waves", title: "夏风灯", tint: Color(hex: 0x12B886), bassHz: [174.61, 220.0, 261.63]),
            FloorLamp(icon: "moon.stars.fill", title: "梦境灯", tint: Color(hex: 0x7950F2), bassHz: [103.83, 155.56, 207.65])
        ]
    }

    private var room2Stage: some View {
        let lamp = r2Lamps[r2LampIndex]
        return VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: 0x1B2245))
                    .overlay(
                        RadialGradient(
                            colors: [lamp.tint.opacity(0.42), .clear],
                            center: UnitPoint(x: 0.5, y: 0.72),
                            startRadius: 8,
                            endRadius: 210
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
                    .animation(.easeInOut(duration: 0.45), value: r2LampIndex)

                VStack(spacing: 14) {
                    Spacer()
                    ChimmoFigureView(
                        member: .plokko,
                        isNight: true,
                        isMinor: r2LampIndex == 1 || r2LampIndex == 3,
                        isSinging: true,
                        time: 0,
                        listeningTilt: 0
                    )
                    .frame(width: 96, height: 96)

                    // 脚下的光源圆盘
                    Ellipse()
                        .fill(lamp.tint.opacity(0.65))
                        .frame(width: 112, height: 22)
                        .blur(radius: 4)
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 8) {
                ForEach(0..<r2Lamps.count, id: \.self) { idx in
                    let l = r2Lamps[idx]
                    let active = r2LampIndex == idx
                    Button {
                        r2LampIndex = idx
                        r2Tried.insert(idx)
                        synth.playNote(frequency: 329.63, velocity: 0.65, decay: 2.4, timbre: .singingCello)
                        for (bIdx, hz) in l.bassHz.enumerated() {
                            synth.playNote(frequency: hz, velocity: bIdx == 0 ? 0.32 : 0.20, decay: 2.2, timbre: bIdx == 0 ? .warmBass : .liquidHarp, delaySeconds: 0.14 + Double(bIdx) * 0.07)
                        }
                        AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.55)
                        if r2Tried.count >= 3 { markRoomLit() }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: l.icon)
                            Text(l.title).font(.caption2.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(active ? l.tint : palette.cardSurface))
                        .foregroundStyle(active ? .white : palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Room 3 — 拉住那半秒（4 -> 3 触觉延留释放）

    private var room3Stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: 0x1B2245))
                .overlay(
                    RadialGradient(
                        colors: [(solved ? palette.homeAnchor : (r3Holding ? palette.melodyTerracotta : palette.nightLampGold)).opacity(0.32), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )

            VStack(spacing: 24) {
                HStack(spacing: 32) {
                    ChimmoFigureView(member: .udo, isNight: true, isMinor: false, isSinging: r3Holding, focusedDegree: 3, time: 0, listeningTilt: r3Holding ? 0.45 : 0)
                        .frame(width: 72, height: 72)
                        .scaleEffect(r3Holding ? 1.12 : 1.0)

                    Image(systemName: "arrow.right")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.white.opacity(solved ? 1.0 : 0.35))

                    ChimmoFigureView(member: .plokko, isNight: true, isMinor: false, isSinging: solved && !r3Holding, focusedDegree: 4, time: 0, listeningTilt: 0)
                        .frame(width: 72, height: 72)
                        .scaleEffect(solved && !r3Holding ? 1.12 : 1.0)
                }

                Text(r3Holding ? "感受掌心的细碎颤抖… 现在松手滑落！" : "按住 4·呜嘟 多撑半秒，再松手")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color(hex: 0xF4EBDD)))
                    .foregroundStyle(Color(hex: 0x1B2245))
                    .scaleEffect(r3Holding ? 0.95 : 1.0)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !r3Holding {
                                    r3Holding = true
                                    synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: .I, texture: .swanRipple, spanDuration: 1.8, intensity: 0.72)
                                    let hz4 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 4, octaveOffset: 0)
                                    synth.playNote(frequency: hz4, velocity: 0.66, decay: 2.0, timbre: .singingCello)
                                    AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.68)
                                }
                            }
                            .onEnded { _ in
                                r3Holding = false
                                let hz3 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 3, octaveOffset: 0)
                                synth.playNote(frequency: hz3, velocity: 0.62, decay: 2.4, timbre: .singingCello)
                                markRoomLit()
                            }
                    )
            }
            .padding(24)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Room 4 — 两根弦的莲花（连续声波对称 + 触觉）

    private var room4Stage: some View {
        let sInt = Int(r4Semis.rounded())
        let desc = HarmonicRatioPhysics.descriptor(forSemitones: sInt)
        let tint: Color = desc.isTense ? palette.melodyTerracotta : (desc.consonance > 0.9 ? palette.nightLampGold : palette.homeAnchor)

        return VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: 0x1B2245))
                LissajousWaveView(
                    ratioA: Double(desc.ratioA),
                    ratioB: Double(desc.ratioB),
                    consonance: desc.consonance,
                    accentColor: tint,
                    isNight: true,
                    compact: false
                )
                VStack {
                    Text(desc.isTense ? "波形正在剧烈推搡摩擦…" : "✦ 波形锁成了静止的莲花（\(desc.ratioText)）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.top, 16)
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 8) {
                Slider(value: $r4Semis, in: 0...12)
                    .tint(tint)
                    .onChange(of: r4Semis) { _, nv in
                        let topHz = 261.63 * pow(2.0, nv / 12.0)
                        if r4Continuous {
                            synth.setContinuousPair(hzA: 261.63, hzB: topHz, gain: 0.22)
                        }
                        let r = Int(nv.rounded())
                        if r != r4LastInt {
                            r4LastInt = r
                            let d = HarmonicRatioPhysics.descriptor(forSemitones: r)
                            if d.isTense {
                                AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.65)
                            } else if d.consonance >= 0.94 && r > 0 {
                                markRoomLit()
                            }
                        }
                    }

                HStack {
                    Text("摩擦 16:15")
                    Spacer()
                    Text("寻找到最静谧的 3:2 或 2:1 莲花")
                    Spacer()
                    Text("镜像 2:1")
                }
                .font(.caption2)
                .foregroundStyle(palette.secondaryInk)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))
        }
    }

    // MARK: Room 5 — 镜子湖的回声（3 颗石子倒映成巴赫乐诗）

    private var room5Stage: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                Text("轻点 3 只咩哞放到湖岸上，湖面会立刻倒映出对称乐诗")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryInk)

                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { deg in
                        let m = ChimmoMember.from(degree: deg)
                        Button {
                            if r5Seed.count >= 3 { r5Seed.removeAll() }
                            r5Seed.append(deg)
                            let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: 0)
                            synth.playNote(frequency: hz, velocity: 0.56, decay: 1.1, timbre: .liquidHarp)
                            if r5Seed.count == 3 {
                                let seedBeads = r5Seed.enumerated().map { idx, d in
                                    NoteBead(degree: d, rawOnset: 0.12 + Double(idx) * 0.42, rawDuration: 0.42, phraseTag: "起·种子")
                                }
                                r5Grown = MotifOrigamiEngine.grow(notes: seedBeads, operation: .fullFourPhrasePoem)
                                playMirrorPoem(r5Grown)
                                markRoomLit()
                            }
                        } label: {
                            ChimmoFigureView(member: m, isNight: palette.isNight, isMinor: false, isSinging: r5Seed.contains(deg), time: 0, listeningTilt: 0)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))

            if !r5Grown.isEmpty {
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(r5Grown) { b in
                                Circle()
                                    .fill(b.member.bodyColor)
                                    .frame(width: 22, height: 22)
                                    .overlay(Text("\(b.degree)").font(.caption2.weight(.bold)).foregroundStyle(.white))
                            }
                        }
                    }

                    Button {
                        stopAudio()
                        onSendMelodyToBook(r5Grown, .brightMajor)
                    } label: {
                        Label("把镜子湖的回声贴进我的手账册", systemImage: "bookmark.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(palette.homeAnchor))
                            .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardSurface))
            }
            Spacer()
        }
    }

    private func playMirrorPoem(_ beads: [NoteBead]) {
        playTask?.cancel()
        playTask = Task { @MainActor in
            let chords: [DiatonicChord] = [.I, .IV, .V, .I]
            for (idx, b) in beads.enumerated() {
                if Task.isCancelled { return }
                let delay = idx == 0 ? 0.0 : max(0.14, b.rawOnset - beads[idx - 1].rawOnset)
                if idx > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                if Task.isCancelled { return }
                if idx % 3 == 0 {
                    synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: chords[(idx / 3) % chords.count], texture: .swanRipple, intensity: 0.72)
                }
                let hz = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: b.degree, octaveOffset: b.octaveOffset)
                synth.playNote(frequency: hz, velocity: 0.60, decay: 1.4, timbre: .singingCello)
            }
        }
    }

    // MARK: Room 6 — 一根弦上的五片天

    private var room6Stage: some View {
        let skyTint = r6Sky.skyAuroraColor(isNight: palette.isNight)
        return VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [skyTint.opacity(0.85), Color(hex: 0x1B2245)], startPoint: .top, endPoint: .bottom))
                    .animation(.easeInOut(duration: 0.4), value: r6Sky)

                VStack(spacing: 16) {
                    Text(r6Sky.label)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(1...7, id: \.self) { deg in
                            let semi = r6Sky.semitoneOffsets[deg - 1]
                            let diff = semi - ScaleMode.brightMajor.semitoneOffsets[deg - 1]
                            ChimmoFigureView(
                                member: ChimmoMember.from(degree: deg),
                                isNight: true,
                                isMinor: r6Sky.isMinorFlavored,
                                isSinging: diff != 0,
                                time: 0,
                                listeningTilt: 0
                            )
                            .frame(width: 38, height: 38)
                            .offset(y: -CGFloat(semi) * 5.0)
                            .animation(.spring(response: 0.42, dampingFraction: 0.74), value: r6Sky)
                        }
                    }
                    .frame(height: 112)

                    Text(r6Sky.skyPhilosophy)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 6) {
                ForEach(ScaleMode.allCases) { sky in
                    let sel = r6Sky == sky
                    Button {
                        r6Sky = sky
                        r6Tried.insert(sky)
                        playSkyTune(sky)
                        if r6Tried.count >= 3 { markRoomLit() }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sky.iconName)
                            Text(sky.shortSkyLabel).font(.caption2.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 13).fill(sel ? sky.skyAuroraColor(isNight: false) : palette.cardSurface))
                        .foregroundStyle(sel ? .white : palette.primaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func playSkyTune(_ mode: ScaleMode) {
        playTask?.cancel()
        let notes = [1, 3, 4, 5, 6, 7, 5, 1]
        playTask = Task { @MainActor in
            synth.playDiatonicChord(rootMIDI: 60, mode: mode, chord: .I, texture: .summerGlass, intensity: 0.70)
            for d in notes {
                if Task.isCancelled { return }
                let hz = mode.frequencyHz(rootMIDI: 60, degree: d, octaveOffset: 0)
                synth.playNote(frequency: hz, velocity: 0.58, decay: 1.4, timbre: .singingCello)
                try? await Task.sleep(nanoseconds: 290_000_000)
            }
        }
    }
}
