import SwiftUI

/// 七只活生生的哑光窑陶咩哞（遵循 mossling 家族生命感标准）：
/// 各自拥有独立的呼吸节拍、不规则眨眼、眼神跟随（全员转眼看向正在发声的伙伴）、脚底接地影，以及唱响时的喜悦笑眼与共鸣微光。
public struct ChimmoFigureView: View {
    public let member: ChimmoMember
    public let isNight: Bool
    public let isMinor: Bool
    public let isSinging: Bool
    public let focusedDegree: Int?
    public let time: Double
    public let listeningTilt: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        member: ChimmoMember,
        isNight: Bool,
        isMinor: Bool,
        isSinging: Bool,
        focusedDegree: Int? = nil,
        time: Double = 0,
        listeningTilt: Double = 0
    ) {
        self.member = member
        self.isNight = isNight
        self.isMinor = isMinor
        self.isSinging = isSinging
        self.focusedDegree = focusedDegree
        self.time = time
        self.listeningTilt = listeningTilt
    }

    // 每只小偶独有的呼吸周期（2.5s–3.7s）
    private var breathPhase: Double {
        if reduceMotion { return 0 }
        let period = 2.6 + Double(member.degree) * 0.16
        return sin((time * 2.0 * .pi / period) + Double(member.degree) * 1.1)
    }

    // 自然错峰眨眼（每 4.2–6.8 秒快速眨眼 130ms）
    private var isBlinking: Bool {
        if reduceMotion || isSinging { return false }
        let cycle = 4.3 + Double((member.degree * 7) % 5) * 0.55
        let local = (time + Double(member.degree) * 1.37).truncatingRemainder(dividingBy: cycle)
        return local >= 0 && local < 0.13
    }

    // 眼神跟随：当某只伙伴发声时，其余伙伴的瞳孔温柔看向它并略微仰望上方飘起的音珠
    private var gazeOffset: CGSize {
        if reduceMotion { return .zero }
        if isSinging {
            return CGSize(width: 0, height: -1.1)
        }
        if let target = focusedDegree {
            let delta = Double(target - member.degree)
            let gx = max(-1.5, min(1.5, delta * 0.55))
            return CGSize(width: gx, height: -0.7)
        }
        // 平时极慢的轻微眼神游移
        let wander = sin(time * 0.45 + Double(member.degree) * 2.1) * 0.7
        return CGSize(width: wander, height: 0)
    }

    private var bodyFillColor: Color {
        member.bodyColor
    }

    private var inkContour: Color {
        isNight ? Color(hex: 0x0A0F24) : Color(hex: 0x231B15)
    }

    private var baseTiltDegrees: Double {
        if reduceMotion { return 0 }
        let idleSway = breathPhase * 1.6
        switch member {
        case .tinki: return (isSinging ? -14.0 : -8.5) + idleSway
        case .doko: return 4.0 + idleSway
        case .udo: return -4.5 + idleSway
        case .plokko: return listeningTilt * 9.0 + idleSway * 1.5
        default: return idleSway * 0.8
        }
    }

    private var bounceOffsetY: CGFloat {
        if reduceMotion { return 0 }
        let breathY = CGFloat(breathPhase) * -1.4
        if isSinging { return -7.5 }
        if member == .plokko && isMinor { return 2.2 + breathY }
        return breathY
    }

    private var breathScale: CGSize {
        if reduceMotion { return CGSize(width: 1, height: 1) }
        if isSinging { return CGSize(width: 1.07, height: 1.09) }
        let s = CGFloat(breathPhase) * 0.018
        return CGSize(width: 1.0 - s * 0.6, height: 1.0 + s)
    }

    public var body: some View {
        ZStack {
            // 脚下接地柔影（扁平卡通平涂椭圆）
            Ellipse()
                .fill(inkContour.opacity(isNight ? 0.45 : 0.16))
                .frame(width: isSinging ? 22 : 28, height: 5.5)
                .offset(y: 25)

            // 唱响时的头顶共鸣音环
            if isSinging {
                Circle()
                    .strokeBorder(
                        (isNight ? member.nightGlowColor : member.bodyColor).opacity(0.55),
                        lineWidth: 1.8
                    )
                    .frame(width: 44, height: 44)
                    .offset(y: 2)
            }

            Group {
                switch member {
                case .taono: taonoBody
                case .doko: dokoBody
                case .plokko: plokkoBody
                case .udo: udoBody
                case .corllo: corlloBody
                case .bomo: bomoBody
                case .tinki: tinkiBody
                }
            }
            .scaleEffect(x: breathScale.width, y: breathScale.height, anchor: .bottom)
            .offset(y: bounceOffsetY)
            .rotationEffect(.degrees(baseTiltDegrees), anchor: .bottom)
        }
        .frame(width: 50, height: 58)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.58), value: isSinging)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: isMinor)
    }

    // MARK: - Expressive Glazed Eyes (Idle / Gaze / Blink / Singing Happy Arc)

    private func glazedEyes(spacing: CGFloat = 10, yOffset: CGFloat = -2, size: CGFloat = 4.8) -> some View {
        HStack(spacing: spacing) {
            singleEye(size: size)
            singleEye(size: size)
        }
        .offset(x: gazeOffset.width, y: yOffset + gazeOffset.height)
    }

    @ViewBuilder
    private func singleEye(size: CGFloat) -> some View {
        if isSinging {
            // 陶醉跟唱弯弯笑眼 (^ ^)
            SingingEyeArc()
                .stroke(Color(hex: 0x1C1D19), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: size * 1.15, height: size * 0.75)
        } else if isBlinking {
            Capsule()
                .fill(Color(hex: 0x1C1D19))
                .frame(width: size * 1.1, height: 1.5)
        } else {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(Color(hex: 0x1C1D19))
                    .frame(width: size, height: size)
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: size * 0.34, height: size * 0.34)
                    .offset(x: size * 0.18, y: size * 0.15)
            }
        }
    }

    // MARK: - 1. 陶诺 Taono (赤陶倒钟共鸣铃)

    private var taonoBody: some View {
        ZStack {
            HStack(spacing: 7) {
                VStack(spacing: -3) {
                    Circle()
                        .fill(Color(hex: 0xF2E6D0))
                        .overlay(Circle().stroke(inkContour, lineWidth: 1.2))
                        .frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(bodyFillColor)
                        .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(inkContour, lineWidth: 1.3))
                        .frame(width: 6.5, height: 14)
                }
                VStack(spacing: -3) {
                    Circle()
                        .fill(Color(hex: 0xF2E6D0))
                        .overlay(Circle().stroke(inkContour, lineWidth: 1.2))
                        .frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(bodyFillColor)
                        .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(inkContour, lineWidth: 1.3))
                        .frame(width: 6.5, height: 13)
                }
                .rotationEffect(.degrees(isSinging ? -4 : -13))
            }
            .offset(y: -19)

            HStack(spacing: 10) {
                Capsule().fill(member.accentColor).frame(width: 9, height: 5)
                Capsule().fill(member.accentColor).frame(width: 9, height: 5)
            }
            .offset(y: 22)

            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(bodyFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(inkContour, lineWidth: 1.6)
                )
                .frame(width: 32, height: 32)
                .offset(y: 5)

            glazedEyes(spacing: 9.5, yOffset: -1)

            ZStack {
                Circle()
                    .fill(Color(hex: 0xF2E6D0))
                    .frame(width: 11.5, height: 11.5)
                    .overlay(Circle().stroke(inkContour, lineWidth: 1.1))
                if isNight || isSinging {
                    Circle()
                        .fill(member.nightGlowColor.opacity(isSinging ? 0.55 : 0.34))
                        .frame(width: isSinging ? 20 : 16, height: isSinging ? 20 : 16)
                }
                Circle()
                    .fill(isNight || isSinging ? member.nightGlowColor : Color(hex: 0xFFB547))
                    .frame(width: 6.2, height: 6.2)
            }
            .offset(x: -3, y: 11)
        }
    }

    // MARK: - 2. 豆叩 Doko (暖杏陶小木鱼)

    private var dokoBody: some View {
        ZStack {
            HStack(spacing: 10) {
                Capsule().fill(member.accentColor).frame(width: 8, height: 5)
                Capsule().fill(member.accentColor).frame(width: 8, height: 5)
            }
            .offset(y: 22)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bodyFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(inkContour, lineWidth: 1.6)
                )
                .frame(width: 32, height: 27)
                .offset(y: 8)

            Capsule()
                .fill(isNight || isSinging ? member.nightGlowColor.opacity(0.9) : member.accentColor)
                .frame(width: isSinging ? 17 : 14, height: 2.8)
                .offset(y: -1)

            glazedEyes(spacing: 9, yOffset: 8, size: 4.5)
        }
    }

    // MARK: - 3. 拍咯 Plokko (珊瑚平衡不倒翁 · 大/小调晴雨表)

    private var plokkoBody: some View {
        let wingAngle: Double = isSinging ? 18 : (isMinor ? -15 : 10)
        let rimColor: Color = isNight || isSinging ? member.nightGlowColor : inkContour
        return ZStack {
            Ellipse()
                .fill(member.accentColor)
                .frame(width: 24, height: 6.5)
                .offset(y: 22)

            HStack(spacing: 22) {
                Capsule()
                    .fill(bodyFillColor)
                    .overlay(Capsule().stroke(rimColor, lineWidth: 1.4))
                    .frame(width: 13.5, height: 7.5)
                    .rotationEffect(.degrees(wingAngle))
                Capsule()
                    .fill(bodyFillColor)
                    .overlay(Capsule().stroke(rimColor, lineWidth: 1.4))
                    .frame(width: 13.5, height: 7.5)
                    .rotationEffect(.degrees(-wingAngle))
            }
            .offset(y: 7)

            Circle()
                .fill(bodyFillColor)
                .overlay(Circle().stroke(inkContour, lineWidth: 1.6))
                .frame(width: 30, height: 30)
                .offset(y: 6)

            Circle()
                .fill(isNight || isSinging ? member.nightGlowColor : Color(hex: 0xFFB547))
                .overlay(Circle().stroke(inkContour, lineWidth: 0.9))
                .frame(width: isSinging ? 6.0 : 5.0, height: isSinging ? 6.0 : 5.0)
                .offset(y: -3.5)

            glazedEyes(spacing: 9, yOffset: 6, size: 4.5)
        }
    }

    // MARK: - 4. 呜嘟 Udo (影青瓷小陶笛)

    private var udoBody: some View {
        ZStack {
            HStack(spacing: 9) {
                Capsule().fill(member.accentColor).frame(width: 8, height: 4.8)
                Capsule().fill(member.accentColor).frame(width: 8, height: 4.8)
            }
            .offset(y: 22)

            Ellipse()
                .fill(bodyFillColor)
                .overlay(Ellipse().stroke(inkContour, lineWidth: 1.6))
                .frame(width: 28, height: 32)
                .offset(y: 5)

            VStack(spacing: 3) {
                Circle().fill(isNight || isSinging ? member.nightGlowColor : member.accentColor).frame(width: 4.2, height: 4.2)
                Circle().fill(isNight || isSinging ? member.nightGlowColor.opacity(0.85) : member.accentColor.opacity(0.8)).frame(width: 3.2, height: 3.2)
            }
            .offset(x: 9, y: -1)

            glazedEyes(spacing: 7.5, yOffset: 5, size: 4.4)
                .offset(x: -2)
        }
    }

    // MARK: - 5. 壳咯 Corllo (宣瓷螺旋号角贝)

    private var corlloBody: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(member.accentColor)
                    .overlay(Circle().stroke(inkContour, lineWidth: 1.3))
                    .frame(width: 19.5, height: 19.5)
                Circle().fill(member.bodyColor).frame(width: 12, height: 12)
                Circle()
                    .fill(isNight || isSinging ? member.nightGlowColor : Color(hex: 0xFFE49E))
                    .frame(width: isSinging ? 7.5 : 6, height: isSinging ? 7.5 : 6)
            }
            .offset(x: 13, y: -3)

            HStack(spacing: 9) {
                Capsule().fill(Color(hex: 0x4D2B22)).frame(width: 8, height: 4.8)
                Capsule().fill(Color(hex: 0x4D2B22)).frame(width: 8, height: 4.8)
            }
            .offset(y: 22)

            Ellipse()
                .fill(bodyFillColor)
                .overlay(Ellipse().stroke(inkContour, lineWidth: 1.6))
                .frame(width: 26, height: 33)
                .offset(x: -2, y: 5)

            glazedEyes(spacing: 7.5, yOffset: 3, size: 4.4)
                .offset(x: -4)
        }
    }

    // MARK: - 6. 钵莫 Bomo (焙赭陶小手碟)

    private var bomoBody: some View {
        ZStack {
            HStack(spacing: 11) {
                Capsule().fill(Color(hex: 0x3E2318)).frame(width: 8.5, height: 4.8)
                Capsule().fill(Color(hex: 0x3E2318)).frame(width: 8.5, height: 4.8)
            }
            .offset(y: 22)

            Ellipse()
                .fill(bodyFillColor)
                .overlay(Ellipse().stroke(inkContour, lineWidth: 1.6))
                .frame(width: 34, height: 25)
                .offset(y: 8)

            Ellipse()
                .fill(isNight || isSinging ? member.nightGlowColor : Color(hex: 0xFFE49E))
                .overlay(Ellipse().stroke(inkContour, lineWidth: 1.0))
                .frame(width: isSinging ? 20 : 18, height: 5.8)
                .offset(y: -2)

            glazedEyes(spacing: 10, yOffset: 9, size: 4.4)
        }
    }

    // MARK: - 7. 叮尖 Tinki (窑赭陶踮脚尖芽)

    private var tinkiBody: some View {
        ZStack {
            VStack(spacing: -1) {
                ZStack {
                    if isNight || isSinging {
                        Circle().fill(member.nightGlowColor.opacity(isSinging ? 0.55 : 0.35)).frame(width: 16, height: 16)
                    }
                    Circle()
                        .fill(isNight || isSinging ? Color(hex: 0xFFC45A) : Color(hex: 0xFFE49E))
                        .overlay(Circle().stroke(inkContour, lineWidth: 1.1))
                        .frame(width: 7.2, height: 7.2)
                }
                RoundedRectangle(cornerRadius: 1).fill(inkContour).frame(width: 2.2, height: 6)
            }
            .offset(y: -17)

            Capsule()
                .fill(bodyFillColor)
                .overlay(Capsule().stroke(inkContour, lineWidth: 1.6))
                .frame(width: 22, height: 32)
                .offset(y: 5)

            glazedEyes(spacing: 7, yOffset: 2, size: 4.3)
        }
    }
}

private struct SingingEyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - 1.5)
        )
        return p
    }
}
