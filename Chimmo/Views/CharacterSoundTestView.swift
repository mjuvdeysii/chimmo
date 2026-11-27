import SwiftUI

/// Interactive 7-member kiln ceramic sound & voice audition studio.
public struct CharacterSoundTestView: View {
    public let palette: ChimmoPalette
    public var onAuditionMember: (ChimmoMember) -> Void

    @State private var activeSingingDegree: Int? = nil
    @State private var resetTask: Task<Void, Never>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.scenePhase) private var scenePhase

    public init(
        palette: ChimmoPalette,
        onAuditionMember: @escaping (ChimmoMember) -> Void = { _ in }
    ) {
        self.palette = palette
        self.onAuditionMember = onAuditionMember
    }

    public var body: some View {
        ZStack {
            AmbientPaperBackdrop(palette: palette)

            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            KilnDuoBrandCrestView(palette: palette, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "guild_header_title", defaultValue: "七位音高小伙伴的窑陶声色"))
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Text(String(localized: "guild_header_sub", defaultValue: "轻点任意成员试听毛毡琴声：1·3·5 是归属基石，4·7 是温柔推进张力。"))
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: palette.homeAnchor)

                    let columns = type >= .xxLarge
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                    let pauseGuildAnim = reduceMotion || scenePhase != .active
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: pauseGuildAnim)) { timeline in
                        let animTime = pauseGuildAnim ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(ChimmoMember.allCases) { member in
                                memberCard(member, time: animTime)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(String(localized: "guild_nav_title", defaultValue: "咩哞七小只图鉴"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            resetTask?.cancel()
            resetTask = nil
        }
    }

    private func memberCard(_ member: ChimmoMember, time: Double) -> some View {
        let isSinging = (activeSingingDegree == member.degree)
        let accent = palette.isNight ? member.nightGlowColor : member.accentColor

        return Button {
            triggerMember(member)
        } label: {
            VStack(spacing: 8) {
                ChimmoFigureView(
                    member: member,
                    isNight: palette.isNight,
                    isMinor: false,
                    isSinging: isSinging,
                    focusedDegree: activeSingingDegree,
                    time: time
                )
                .frame(width: 60, height: 68)

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(member.degree)")
                            .font(.system(.caption, design: .rounded).weight(.heavy).monospacedDigit())
                            .foregroundStyle(accent)
                        Text(member.solfege)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                    }
                    Text("\(member.localizedName) · \(member.roleLabel)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(type.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.inner, tint: isSinging ? accent : nil)
        }
        .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.5))
        .accessibilityLabel(String(format: String(localized: "vo_pair_fmt", defaultValue: "%@ · %@"), member.localizedName, member.voiceOverSummary))
        .accessibilityHint(String(localized: "guild_member_hint", defaultValue: "轻点试听该音阶音色与触感"))
    }

    private func triggerMember(_ member: ChimmoMember) {
        if reduceMotion {
            activeSingingDegree = member.degree
        } else {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
                activeSingingDegree = member.degree
            }
        }
        onAuditionMember(member)

        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 520_000_000)
            guard !Task.isCancelled else { return }
            if activeSingingDegree == member.degree {
                activeSingingDegree = nil
            }
        }
    }
}

/// Sculptural dual kiln crest emblem representing Mie & Mou harmonic dialogue.
public struct KilnDuoBrandCrestView: View {
    public let palette: ChimmoPalette
    public var size: CGFloat = 28

    public init(palette: ChimmoPalette, size: CGFloat = 28) {
        self.palette = palette
        self.size = size
    }

    public var body: some View {
        ChimmoDuoBadgeView(
            isNight: palette.isNight,
            accentColor: palette.isNight ? palette.nightLampGold : palette.homeAnchor,
            melodyActive: false,
            cowAwake: true
        )
        .frame(width: size * 1.45, height: size)
        .accessibilityHidden(true)
    }
}
