import SwiftUI

/// 继承《摸索台灯》的「4 秒无字点灯开场」：
/// 没有弹窗说明书，不说话，只用眼神、呼吸、一根紧绷的金丝与一声释然的和弦，让零基础用户 4 秒内读懂音符世界的引力。
public struct ChimmoOpeningView: View {
    public let synth: FeltPianoSynth
    public let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lampLit: Bool = false
    @State private var resolved: Bool = false
    @State private var rippleExpand: CGFloat = 0.0
    @State private var autoTask: Task<Void, Never>? = nil

    public init(synth: FeltPianoSynth, onFinished: @escaping () -> Void) {
        self.synth = synth
        self.onFinished = onFinished
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                // 家族深夜台灯底色（缓缓点亮）
                Color(hex: 0x1B2245).ignoresSafeArea()

                // 暖金台灯呼吸光晕
                RadialGradient(
                    colors: [
                        Color(hex: 0xFFB84D).opacity(lampLit ? (resolved ? 0.34 : 0.22) : 0.02),
                        Color(hex: 0x4FD8CB).opacity(resolved ? 0.14 : 0.0),
                        .clear
                    ],
                    center: UnitPoint(x: 0.36, y: 0.50),
                    startRadius: 12,
                    endRadius: resolved ? 340 : 210
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.1), value: lampLit)
                .animation(.easeOut(duration: 0.9), value: resolved)

                VStack {
                    Spacer()

                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let homePos = CGPoint(x: w * 0.35, y: h * 0.52)
                        let tinkiPos = resolved
                            ? CGPoint(x: w * 0.54, y: h * 0.52)
                            : CGPoint(x: w * 0.74, y: h * 0.44)

                        ZStack {
                            // 释然归家时的余影光环（以 1·陶诺 暖灯为中心荡开）
                            if resolved {
                                Circle()
                                    .strokeBorder(Color(hex: 0xFFB84D).opacity(max(0, 0.7 - Double(rippleExpand) * 0.7)), lineWidth: 2.2)
                                    .frame(width: 72 + rippleExpand * 260, height: 72 + rippleExpand * 260)
                                    .position(x: (homePos.x + tinkiPos.x) * 0.5, y: homePos.y)
                            }

                            // 7·叮尖与 1·陶诺之间绷紧的细金丝（归家瞬间融化消失）
                            if lampLit && !resolved {
                                Path { p in
                                    let vib = reduceMotion ? 0 : CGFloat(sin(now * 28.0)) * 5.0
                                    p.move(to: homePos)
                                    p.addQuadCurve(
                                        to: tinkiPos,
                                        control: CGPoint(x: (homePos.x + tinkiPos.x) * 0.5, y: (homePos.y + tinkiPos.y) * 0.5 + vib)
                                    )
                                }
                                .stroke(Color(hex: 0xFFB84D).opacity(0.75), style: StrokeStyle(lineWidth: 2.0, dash: [5, 4]))
                            }

                            // 1·陶诺（像 Otto 的台灯一样在左方稳稳亮起暖光）
                            ChimmoFigureView(
                                member: .taono,
                                isNight: true,
                                isMinor: false,
                                isSinging: resolved,
                                focusedDegree: 7,
                                time: now,
                                listeningTilt: 0
                            )
                            .frame(width: 84, height: 84)
                            .position(homePos)
                            .opacity(lampLit ? 1.0 : 0.15)
                            .scaleEffect(lampLit ? 1.0 : 0.88)
                            .animation(.easeOut(duration: 0.8), value: lampLit)

                            // 7·叮尖（起初在右上方踮脚微颤，触碰后快乐蹦回陶诺身边）
                            ChimmoFigureView(
                                member: .tinki,
                                isNight: true,
                                isMinor: false,
                                isSinging: resolved,
                                focusedDegree: 1,
                                time: now,
                                listeningTilt: resolved ? 0 : -0.4
                            )
                            .frame(width: 72, height: 72)
                            .offset(x: (!resolved && !reduceMotion) ? CGFloat(sin(now * 34.0)) * 2.2 : 0)
                            .position(tinkiPos)
                            .opacity(lampLit ? 1.0 : 0.0)
                            .animation(.spring(response: 0.65, dampingFraction: 0.72), value: resolved)
                        }
                    }
                    .frame(height: 240)

                    Spacer()

                    // 极轻的底部微提示（几乎无字，随时可点跳过）
                    Text(resolved ? "咩哞 · 捉住脑海里的旋律" : "轻点一下，接他回家")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(hex: 0xF4EBDD).opacity(lampLit ? 0.68 : 0.0))
                        .padding(.bottom, 44)
                        .animation(.easeIn(duration: 0.6), value: lampLit)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                triggerResolveAndEnter()
            }
        }
        .onAppear {
            startSequence()
        }
        .onDisappear {
            autoTask?.cancel()
        }
    }

    private func startSequence() {
        autoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            lampLit = true
            // 轻轻响起悬停的 7·叮尖，引发直觉好奇
            let hz7 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 7, octaveOffset: 0)
            synth.playNote(frequency: hz7, velocity: 0.42, decay: 1.8, timbre: .singingCello)
            AcousticHapticsEngine.shared.playTensionFlutter(intensity: 0.35)

            // 3.6 秒后若用户未点击，也温柔自动完成归家并进入桌面，绝不卡住任何人
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            if !Task.isCancelled && !resolved {
                triggerResolveAndEnter()
            }
        }
    }

    private func triggerResolveAndEnter() {
        guard !resolved else {
            onFinished()
            return
        }
        resolved = true
        autoTask?.cancel()

        // 7 -> 高音 1↑ 释然归家 + 圣桑式湖面竖琴温暖铺开 + 掌心长舒一口气震动
        let hz1 = ScaleMode.brightMajor.frequencyHz(rootMIDI: 60, degree: 1, octaveOffset: 1)
        synth.playNote(frequency: hz1, velocity: 0.60, decay: 2.2, timbre: .singingCello)
        synth.playDiatonicChord(rootMIDI: 60, mode: .brightMajor, chord: .I, texture: .swanRipple, spanDuration: 1.8, intensity: 0.72)
        AcousticHapticsEngine.shared.playResolutionExhale()

        withAnimation(.easeOut(duration: 1.05)) {
            rippleExpand = 1.0
        }

        autoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            if !Task.isCancelled {
                onFinished()
            }
        }
    }
}
