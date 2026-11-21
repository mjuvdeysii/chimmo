import SwiftUI

/// 底部七只咩哞木架舞台（横向 7 等分，iPhone 竖屏每只 ≥ 53pt，支持单点与手指横滑连奏）。
public struct TroupeShelfView: View {
    public let palette: ChimmoPalette
    public let isMinor: Bool
    public let activeDegrees: Set<Int>
    public let listeningTilt: Double
    public let onTriggerMember: (ChimmoMember) -> Void

    @State private var lastDraggedDegree: Int?

    public init(
        palette: ChimmoPalette,
        isMinor: Bool,
        activeDegrees: Set<Int>,
        listeningTilt: Double,
        onTriggerMember: @escaping (ChimmoMember) -> Void
    ) {
        self.palette = palette
        self.isMinor = isMinor
        self.activeDegrees = activeDegrees
        self.listeningTilt = listeningTilt
        self.onTriggerMember = onTriggerMember
    }

    public var body: some View {
        GeometryReader { geo in
            let colW = geo.size.width / 7.0
            HStack(spacing: 0) {
                ForEach(ChimmoMember.allCases) { member in
                    let singing = activeDegrees.contains(member.degree)
                    VStack(spacing: 2) {
                        ChimmoFigureView(
                            member: member,
                            isNight: palette.isNight,
                            isMinor: isMinor,
                            isSinging: singing,
                            listeningTilt: listeningTilt
                        )
                        Text("\(member.degree)·\(member.chineseName)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(member.roleLabel)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(palette.secondaryInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(member.voiceOverSummary)
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture {
                        onTriggerMember(member)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let idx = Int(value.location.x / max(1, colW)) + 1
                        let clamped = max(1, min(7, idx))
                        if lastDraggedDegree != clamped {
                            lastDraggedDegree = clamped
                            onTriggerMember(ChimmoMember.from(degree: clamped))
                        }
                    }
                    .onEnded { _ in
                        lastDraggedDegree = nil
                    }
            )
        }
        .frame(height: 92)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(palette.shelfSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}
