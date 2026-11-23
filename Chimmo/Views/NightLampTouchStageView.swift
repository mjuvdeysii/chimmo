import SwiftUI

/// 终极无障碍包容体验：「闭眼夜灯摸音剧场」（灵感源自《摸索台灯》夜灯模式）
/// 深夜不刺眼、无需看屏幕、哪怕闭上眼睛或存在视力障碍，单指在深蓝玻璃面上轻轻上下滑动即可凭掌心震动与柔和琴声「摸」出脑海里的旋律，
/// 并自动无声录成一条纸上呼吸旋律，随时贴进明信片手账册。
public struct NightLampTouchStageView: View {
    public let synth: FeltPianoSynth
    public let initialMode: ScaleMode
    public let onSaveMidnightDream: ([NoteBead], ScaleMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pentatonicSanctuary: Bool = true
    @State private var scaleMode: ScaleMode
    @State private var fingerPos: CGPoint? = nil
    @State private var currentDegree: Int = 1
    @State private var currentOctave: Int = 0
    @State private var capturedNotes: [NoteBead] = []
    @State private var captureStart: TimeInterval? = nil
    @State private var afterRings: [LampRing] = []

    private struct LampRing: Identifiable {
        let id = UUID()
        let birth: TimeInterval
        let pt: CGPoint
        let color: Color
    }

    public init(
        synth: FeltPianoSynth,
        initialMode: ScaleMode = .brightMajor,
        onSaveMidnightDream: @escaping ([NoteBead], ScaleMode) -> Void
    ) {
        self.synth = synth
        self.initialMode = initialMode
        self.onSaveMidnightDream = onSaveMidnightDream
        self._scaleMode = State(initialValue: initialMode)
    }

    public var body: some View {
        ZStack {
            // 家族正典深夜蓝夜灯底色（永不刺眼）
            Color(hex: 0x1B2245).ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
                let now = tl.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        Canvas { ctx, cSize in
                            // Otto 同款台灯暖琥珀光晕（跟随手指位置温柔移动！）
                            let center = fingerPos ?? CGPoint(x: cSize.width * 0.5, y: cSize.height * 0.5)
                            let grad = Gradient(colors: [
                                Color(hex: 0xFFB84D).opacity(fingerPos != nil ? 0.30 : 0.14),
                                Color(hex: 0x4FD8CB).opacity(0.06),
                                .clear
                            ])
                            ctx.fill(
                                Path(CGRect(origin: .zero, size: cSize)),
                                with: .radialGradient(grad, center: center, startRadius: 8, endRadius: 230)
                            )

                            // 极微弱的水平声学琴弦暗纹（0...12 半音与触控完全对齐，不刺眼，供睁眼时微弱参考）
                            let frets: [(Int, Int)] = pentatonicSanctuary
                                ? [(1, 0), (2, 0), (3, 0), (5, 0), (6, 0), (1, 1)]
                                : [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (1, 1)]
                            for (deg, oct) in frets {
                                let semi = ScalePitchGeometry.semitoneOffset(degree: deg, octaveOffset: oct, mode: scaleMode)
                                let norm = ScalePitchGeometry.normalizedY(semitone: semi, minSemitone: 0, maxSemitone: 12)
                                let y = cSize.height - 110 - norm * max(120, cSize.height - 230)
                                var p = Path()
                                p.move(to: CGPoint(x: 28, y: y))
                                p.addLine(to: CGPoint(x: cSize.width - 28, y: y))
                                let isHome = deg == 1
                                ctx.stroke(
                                    p,
                                    with: .color(Color(hex: isHome ? 0xFFB84D : 0xF4EBDD).opacity(isHome ? 0.25 : 0.08)),
                                    lineWidth: isHome ? 1.5 : 0.8
                                )
                            }

                            // 暖琥珀余影涟漪（每次指尖滑过一颗音自动绽放消散）
                            for ring in afterRings {
                                let age = now - ring.birth
                                guard age >= 0 && age < 1.4 else { continue }
                                let p = age / 1.4
                                let r = 18.0 + CGFloat(p) * 96.0
                                let alpha = pow(1.0 - p, 1.8) * 0.65
                                ctx.stroke(
                                    Path(ellipseIn: CGRect(x: ring.pt.x - r, y: ring.pt.y - r, width: r * 2, height: r * 2)),
                                    with: .color(ring.color.opacity(alpha)),
                                    style: StrokeStyle(lineWidth: 1.8)
                                )
                            }
                        }

                        // 呼吸陪伴的小陶诺（夜灯微亮，不说话，只轻轻看着你的手指）
                        VStack {
                            Spacer()
                            HStack(spacing: 14) {
                                ChimmoFigureView(
                                    member: ChimmoMember.from(degree: currentDegree),
                                    isNight: true,
                                    isMinor: scaleMode.isMinorFlavored,
                                    isSinging: fingerPos != nil,
                                    focusedDegree: currentDegree,
                                    time: now,
                                    listeningTilt: 0
                                )
                                .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fingerPos == nil ? "闭上眼，用拇指在夜灯玻璃上上下轻摸" : "\(currentDegree)·\(ChimmoMember.from(degree: currentDegree).chineseName)（\(ChimmoMember.from(degree: currentDegree).roleLabel)）")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color(hex: 0xF4EBDD))
                                    Text(capturedNotes.isEmpty ? "每划过一根无形琴弦，掌心都会轻轻回震" : "已悄悄接住 \(capturedNotes.count) 颗睡前旋律珠")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: 0xAEB4CC))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.bottom, 86)
                            .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                fingerPos = val.location
                                handleTouch(at: val.location, in: size)
                            }
                            .onEnded { _ in
                                fingerPos = nil
                            }
                    )
                }
            }

            // 顶部极简夜灯控制条 + 底部保存胶囊
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label("熄灯返回", systemImage: "xmark")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .foregroundStyle(Color(hex: 0xF4EBDD))
                    }

                    Spacer()

                    Button {
                        pentatonicSanctuary.toggle()
                        AcousticHapticsEngine.shared.playBeatTap(isStrong: false)
                    } label: {
                        Text(pentatonicSanctuary ? "🎋 五声安心弦" : "🎼 七声完整弦")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color(hex: 0xFFB84D).opacity(0.20)))
                            .foregroundStyle(Color(hex: 0xFFB84D))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                Spacer()

                if !capturedNotes.isEmpty {
                    HStack(spacing: 12) {
                        Button("清空重写") {
                            capturedNotes.removeAll()
                            captureStart = nil
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                        .foregroundStyle(Color(hex: 0xAEB4CC))

                        Button {
                            onSaveMidnightDream(capturedNotes, scaleMode)
                            AcousticHapticsEngine.shared.playResolutionExhale()
                            dismiss()
                        } label: {
                            Label("把这 \(capturedNotes.count) 颗梦境贴进手账册 →", systemImage: "bookmark.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color(hex: 0xFFB84D)))
                                .foregroundStyle(Color(hex: 0x1B2245))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 22)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("闭眼夜灯摸音剧场，上下滑动屏幕可用触觉和声音记录睡前旋律")
    }

    private func handleTouch(at pt: CGPoint, in size: CGSize) {
        let usableH = max(120, size.height - 230)
        let normFromBottom = max(0, min(1, (size.height - 110 - pt.y) / usableH))
        let raw = ScalePitchGeometry.nearestDegreeAndOctave(
            normalizedFromBottom: normFromBottom,
            mode: scaleMode,
            minSemitone: 0,
            maxSemitone: 12
        )
        let deg: Int
        if pentatonicSanctuary {
            switch raw.degree {
            case 4: deg = 3
            case 7: deg = 6
            default: deg = raw.degree
            }
        } else {
            deg = raw.degree
        }
        let oct = max(0, min(1, raw.octaveOffset))

        if deg != currentDegree || oct != currentOctave || capturedNotes.isEmpty {
            currentDegree = deg
            currentOctave = oct

            // 触觉无障碍编码：1·陶诺稳重颂钵、4/7 微颤张力、其余清脆木弦
            if deg == 1 {
                AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.78)
            } else if deg == 4 || deg == 7 {
                AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.48)
            } else {
                AcousticHapticsEngine.shared.playBeatTap(isStrong: deg == 5)
            }

            let hz = scaleMode.frequencyHz(rootMIDI: 60, degree: deg, octaveOffset: oct)
            synth.playNote(frequency: hz, velocity: 0.54, decay: 1.8, timbre: .singingCello)
            if capturedNotes.count % 3 == 0 {
                let ch: DiatonicChord = (deg == 1 || deg == 3 || deg == 5) ? .I : (deg == 6 ? .vi : .IV)
                synth.playDiatonicChord(rootMIDI: 60, mode: scaleMode, chord: ch, texture: .swanRipple, spanDuration: 1.8, intensity: 0.45)
            }

            let now = Date().timeIntervalSinceReferenceDate
            if captureStart == nil { captureStart = now }
            let onset = max(0.08, now - (captureStart ?? now))
            if capturedNotes.count >= 20 {
                capturedNotes.removeFirst()
            }
            capturedNotes.append(NoteBead(degree: deg, octaveOffset: oct, rawOnset: onset, rawDuration: 0.55, phraseTag: "🌙 夜灯"))

            afterRings.removeAll { now - $0.birth > 1.5 }
            afterRings.append(LampRing(birth: now, pt: pt, color: ChimmoMember.from(degree: deg).nightGlowColor))
        }
    }
}
