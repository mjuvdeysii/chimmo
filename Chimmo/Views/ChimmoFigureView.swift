import SwiftUI

/// 七只哑光窑陶咩哞高工艺矢量呈现（无台词气泡，只用姿态、倾角、呼吸与微光回应真实音乐）。
public struct ChimmoFigureView: View {
    public let member: ChimmoMember
    public let isNight: Bool
    public let isMinor: Bool
    public let isSinging: Bool
    public let listeningTilt: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        member: ChimmoMember,
        isNight: Bool,
        isMinor: Bool,
        isSinging: Bool,
        listeningTilt: Double = 0
    ) {
        self.member = member
        self.isNight = isNight
        self.isMinor = isMinor
        self.isSinging = isSinging
        self.listeningTilt = listeningTilt
    }

    private var ceramicGradient: RadialGradient {
        RadialGradient(
            colors: [member.bodyColor, member.bodyColor.opacity(0.84)],
            center: UnitPoint(x: 0.34, y: 0.28),
            startRadius: 2,
            endRadius: 34
        )
    }

    private var baseTiltDegrees: Double {
        if reduceMotion { return 0 }
        switch member {
        case .tinki: return isSinging ? -13.0 : -8.5
        case .doko: return 4.0
        case .udo: return -4.5
        case .plokko: return listeningTilt * 8.0
        default: return 0
        }
    }

    private var bounceOffsetY: CGFloat {
        if reduceMotion { return 0 }
        if isSinging { return -6.5 }
        if member == .plokko && isMinor { return 2.5 }
        return 0
    }

    public var body: some View {
        ZStack {
            switch member {
            case .taono:
                taonoBody
            case .doko:
                dokoBody
            case .plokko:
                plokkoBody
            case .udo:
                udoBody
            case .corllo:
                corlloBody
            case .bomo:
                bomoBody
            case .tinki:
                tinkiBody
            }
        }
        .frame(width: 48, height: 54)
        .scaleEffect(isSinging && !reduceMotion ? 1.07 : 1.0)
        .offset(y: bounceOffsetY)
        .rotationEffect(.degrees(baseTiltDegrees))
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.62), value: isSinging)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: isMinor)
    }

    // MARK: - Glazed Eyes (Shared Family Canon)

    private func glazedEyes(spacing: CGFloat = 10, yOffset: CGFloat = -2, size: CGFloat = 4.6) -> some View {
        HStack(spacing: spacing) {
            eyeDot(size: size)
            eyeDot(size: size)
        }
        .offset(y: yOffset)
    }

    private func eyeDot(size: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Color(hex: 0x1C1D19))
                .frame(width: size, height: size)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(x: size * 0.18, y: size * 0.16)
        }
    }

    // MARK: - 1. 陶诺 Taono (赤陶倒钟共鸣铃)

    private var taonoBody: some View {
        ZStack {
            // 不对称软胶音叉耳
            HStack(spacing: 7) {
                VStack(spacing: -3) {
                    Circle().fill(Color(hex: 0xF2E6D0)).frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 3.5).fill(ceramicGradient).frame(width: 6.5, height: 14)
                }
                VStack(spacing: -3) {
                    Circle().fill(Color(hex: 0xF2E6D0)).frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 3.5).fill(ceramicGradient).frame(width: 6.5, height: 13)
                }
                .rotationEffect(.degrees(-12))
            }
            .offset(y: -19)

            // 焙茶豆脚
            HStack(spacing: 10) {
                Capsule().fill(member.accentColor).frame(width: 9, height: 5)
                Capsule().fill(member.accentColor).frame(width: 9, height: 5)
            }
            .offset(y: 22)

            // 倒钟身躯
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(ceramicGradient)
                .frame(width: 31, height: 32)
                .offset(y: 5)

            glazedEyes(spacing: 9, yOffset: -1)

            // 胸口窑白声孔与古铜/夜灯共鸣珠
            ZStack {
                Circle()
                    .fill(Color(hex: 0xF2E6D0))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(member.accentColor.opacity(0.25), lineWidth: 0.8))
                if isNight || isSinging {
                    Circle()
                        .fill(member.nightGlowColor.opacity(isNight ? 0.36 : 0.22))
                        .frame(width: 17, height: 17)
                }
                Circle()
                    .fill(isNight ? member.nightGlowColor : Color(hex: 0xD99E32))
                    .frame(width: 6, height: 6)
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
                .fill(ceramicGradient)
                .frame(width: 32, height: 27)
                .offset(y: 8)

            // 顶缘极简水平声槽
            Capsule()
                .fill(isNight ? member.nightGlowColor.opacity(0.85) : member.accentColor.opacity(0.7))
                .frame(width: 14, height: 2.6)
                .offset(y: -1)

            glazedEyes(spacing: 9, yOffset: 8, size: 4.4)
        }
    }

    // MARK: - 3. 拍咯 Plokko (珊瑚平衡不倒翁 · 大/小调晴雨表)

    private var plokkoBody: some View {
        let wingAngle: Double = isMinor ? -15 : 10
        let rimColor: Color = isNight ? member.nightGlowColor : Color(hex: 0xD9A438)
        return ZStack {
            // 深胡桃静音底座环
            Ellipse()
                .fill(member.accentColor)
                .frame(width: 24, height: 6.5)
                .offset(y: 22)

            // 左右平衡响耳
            HStack(spacing: 22) {
                Capsule()
                    .fill(ceramicGradient)
                    .overlay(Capsule().stroke(rimColor, lineWidth: 1.2))
                    .frame(width: 13, height: 7.5)
                    .rotationEffect(.degrees(wingAngle))
                Capsule()
                    .fill(ceramicGradient)
                    .overlay(Capsule().stroke(rimColor, lineWidth: 1.2))
                    .frame(width: 13, height: 7.5)
                    .rotationEffect(.degrees(-wingAngle))
            }
            .offset(y: 7)

            Circle()
                .fill(ceramicGradient)
                .frame(width: 30, height: 30)
                .offset(y: 6)

            // 额间定音金点
            Circle()
                .fill(rimColor)
                .frame(width: 4.4, height: 4.4)
                .offset(y: -3.5)

            glazedEyes(spacing: 9, yOffset: 6, size: 4.4)
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
                .fill(ceramicGradient)
                .frame(width: 28, height: 32)
                .offset(y: 5)

            // 侧肩两粒焦铜/微光气孔
            VStack(spacing: 3) {
                Circle().fill(isNight ? member.nightGlowColor : member.accentColor).frame(width: 4, height: 4)
                Circle().fill(isNight ? member.nightGlowColor.opacity(0.8) : member.accentColor.opacity(0.8)).frame(width: 3, height: 3)
            }
            .offset(x: 9, y: -1)

            glazedEyes(spacing: 7.5, yOffset: 5, size: 4.3)
                .offset(x: -2)
        }
    }

    // MARK: - 5. 壳咯 Corllo (宣瓷螺旋号角贝)

    private var corlloBody: some View {
        ZStack {
            // 右侧焦铜螺旋号角耳（日光必留锚点）
            ZStack {
                Circle().fill(member.accentColor).frame(width: 19, height: 19)
                Circle().fill(member.bodyColor).frame(width: 12, height: 12)
                Circle()
                    .fill(isNight ? member.nightGlowColor : member.accentColor)
                    .frame(width: 6, height: 6)
            }
            .offset(x: 13, y: -3)

            HStack(spacing: 9) {
                Capsule().fill(Color(hex: 0x4D2B22)).frame(width: 8, height: 4.8)
                Capsule().fill(Color(hex: 0x4D2B22)).frame(width: 8, height: 4.8)
            }
            .offset(y: 22)

            Ellipse()
                .fill(ceramicGradient)
                .overlay(Ellipse().stroke(member.accentColor.opacity(isNight ? 0.15 : 0.30), lineWidth: 1))
                .frame(width: 26, height: 33)
                .offset(x: -2, y: 5)

            glazedEyes(spacing: 7.5, yOffset: 3, size: 4.3)
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
                .fill(ceramicGradient)
                .frame(width: 34, height: 25)
                .offset(y: 8)

            // 顶面浅洼淡金釉面
            Ellipse()
                .fill(member.accentColor.opacity(isNight ? 0.92 : 0.80))
                .frame(width: 18, height: 5.5)
                .offset(y: -2)

            glazedEyes(spacing: 10, yOffset: 9, size: 4.3)
        }
    }

    // MARK: - 7. 叮尖 Tinki (窑赭陶踮脚尖芽)

    private var tinkiBody: some View {
        ZStack {
            // 顶上亮金珠
            VStack(spacing: -1) {
                ZStack {
                    if isNight || isSinging {
                        Circle().fill(member.nightGlowColor.opacity(0.35)).frame(width: 14, height: 14)
                    }
                    Circle().fill(isNight ? Color(hex: 0xFFC45A) : Color(hex: 0xE8BD6B)).frame(width: 6.5, height: 6.5)
                }
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: 0x6B430C)).frame(width: 2.2, height: 6)
            }
            .offset(y: -17)

            // 窄身陀螺体
            Capsule()
                .fill(ceramicGradient)
                .frame(width: 22, height: 32)
                .offset(y: 5)

            glazedEyes(spacing: 7, yOffset: 2, size: 4.2)
        }
    }
}
