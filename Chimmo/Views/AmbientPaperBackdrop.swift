import SwiftUI

/// 零能耗静态空气氛围背景层（v0.7.0 彻底移除全屏持续 15fps `TimelineView` 重绘）：
/// 仅在日光/夜灯切换或切换五色天光情绪时平滑渐变过渡，保证主画布独享 120Hz 算力且机身不发热不掉帧。
public struct AmbientPaperBackdrop: View {
    public let palette: ChimmoPalette
    public var accentTint: Color?

    public init(palette: ChimmoPalette, accentTint: Color? = nil) {
        self.palette = palette
        self.accentTint = accentTint
    }

    public var body: some View {
        let tint = accentTint ?? palette.homeAnchor
        ZStack {
            palette.paper

            if palette.isNight {
                RadialGradient(
                    colors: [
                        palette.nightLampGold.opacity(0.16),
                        tint.opacity(0.07),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.22),
                    startRadius: 12,
                    endRadius: 420
                )
            } else {
                RadialGradient(
                    colors: [
                        Color(hex: 0xFFE8B0).opacity(0.24),
                        tint.opacity(0.07),
                        .clear
                    ],
                    center: UnitPoint(x: 0.85, y: 0.08),
                    startRadius: 12,
                    endRadius: 480
                )

                LinearGradient(
                    colors: [tint.opacity(0.05), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.55), value: palette.isNight)
    }
}
