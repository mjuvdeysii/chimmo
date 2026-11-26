import SwiftUI

/// V2.0 主导航标签（Headspace 极简四页直觉秩序：今日 / 共振 / 探索 / 我的）
public enum ResonanceTab: Int, Hashable, CaseIterable, Sendable {
    case today = 0
    case field = 1
    case explore = 2
    case profile = 3
}

/// V2.0 「咩哞 · Mie & Mou」脑波共振场主根视图。
public struct ResonanceRootView: View {
    @StateObject private var vm: ResonanceViewModel
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var selectedTab: ResonanceTab = .today

    public init(preferences: UserDefaults? = .standard) {
        _vm = StateObject(wrappedValue: ResonanceViewModel(preferences: preferences))
    }

    private var isNight: Bool {
        switch vm.studioVM.appearance {
        case .auto: return systemScheme == .dark
        case .daylight: return false
        case .nightLamp: return true
        }
    }

    private var palette: ChimmoPalette { ChimmoPalette(isNight: isNight) }

    private var showsFloatingMiniBar: Bool {
        selectedTab != .field && (vm.isBedPlaying || (vm.activeCapsule != nil && vm.studioVM.isPlaying))
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: ResonanceTab.today) {
                TodayJourneyView(
                    vm: vm,
                    palette: palette,
                    onOpenField: { selectedTab = .field },
                    onOpenExplore: { selectedTab = .explore }
                )
            } label: {
                Label("今日", systemImage: selectedTab == .today ? "sun.horizon.fill" : "sun.horizon")
            }

            Tab(value: ResonanceTab.field) {
                ResonanceFieldView(vm: vm, palette: palette)
            } label: {
                Label("共振", systemImage: selectedTab == .field ? "waveform.circle.fill" : "waveform.circle")
            }

            Tab(value: ResonanceTab.explore) {
                ExploreResonanceView(
                    vm: vm,
                    palette: palette,
                    onOpenField: { selectedTab = .field }
                )
            } label: {
                Label("探索", systemImage: selectedTab == .explore ? "square.grid.2x2.fill" : "square.grid.2x2")
            }

            Tab(value: ResonanceTab.profile) {
                ProfileSanctuaryView(
                    vm: vm,
                    palette: palette,
                    onOpenField: { selectedTab = .field }
                )
            } label: {
                Label("我的", systemImage: selectedTab == .profile ? "person.crop.circle.fill" : "person.crop.circle")
            }
        }
        .tint(palette.homeAnchor)
        .fontDesign(.rounded)
        .modifier(ResonanceAppearanceModifier(preference: vm.studioVM.appearance))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsFloatingMiniBar {
                ResonanceFloatingMiniBar(
                    vm: vm,
                    palette: palette,
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency,
                    onTapOpenField: {
                        selectedTab = .field
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.82), value: showsFloatingMiniBar)
        .task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            vm.studioVM.synth.ensureRunning()
        }
        .onChange(of: scenePhase) { _, nextPhase in
            if nextPhase == .background {
                vm.handleAppEnteredBackground()
            }
        }
        .sheet(isPresented: $vm.openNightLampSheet) {
            NightLampTactileSheet(vm: vm.studioVM)
        }
    }
}

private struct ResonanceFloatingMiniBar: View {
    @ObservedObject var vm: ResonanceViewModel
    let palette: ChimmoPalette
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let onTapOpenField: () -> Void

    var body: some View {
        let bandTint = vm.selectedBand.accentColor(isNight: palette.isNight)
        let shape = Capsule(style: .continuous)

        HStack(spacing: 12) {
            Button(action: onTapOpenField) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(bandTint)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.currentHeadline)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(vm.currentSubline)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(palette.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("正在播放 \(vm.currentHeadline)，\(vm.currentSubline)")
            .accessibilityHint("轻点打开共振控制台")

            Button {
                if vm.activeCapsule != nil {
                    vm.stopCapsule()
                } else {
                    vm.stopBedPlayback()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(bandTint)
                        .frame(width: 36, height: 36)
                    Image(systemName: "stop.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(palette.contrastInkOnAccent)
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.2))
            .accessibilityLabel("停止播放")
            .accessibilityHint("暂停当前脑波或声波乐章")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background {
            if reduceTransparency {
                shape
                    .fill(palette.cardSurface)
                    .overlay(shape.strokeBorder(bandTint.opacity(0.45), lineWidth: 1.4))
            } else {
                shape
                    .fill(palette.cardSurface.opacity(palette.isNight ? 0.92 : 0.96))
                    .shadow(color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.34), radius: 14, y: 6)
                    .overlay(shape.strokeBorder(palette.primaryInk.opacity(palette.isNight ? 0.16 : 0.08), lineWidth: 1.0))
            }
        }
    }
}

private struct ResonanceAppearanceModifier: ViewModifier {
    let preference: AppearancePreference

    @ViewBuilder
    func body(content: Content) -> some View {
        switch preference {
        case .auto:
            content
        case .daylight:
            content.preferredColorScheme(.light)
        case .nightLamp:
            content.preferredColorScheme(.dark)
        }
    }
}
