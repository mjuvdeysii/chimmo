import SwiftUI

/// V2.2 咩哞原创三页声学工坊导航：声场（默认直达）/ 声库 / 工坊
public enum ResonanceTab: Int, Hashable, CaseIterable, Sendable {
    case field = 0    // 声场（默认首页，直达活体窑陶共振盆）
    case library = 1  // 声库（四频段窑陶调音座 / 12套配方 / 闭眼夜灯 / 8首乐章 / 28首典藏）
    case atelier = 2  // 工坊（咩哞窑陶铭牌 / 纪念卡导出 / 角色试音 / 外观三联 / 偏好与安全合规）
}

/// V2.2 「咩哞 · Mie & Mou」离线窑陶共振工作台主根视图。
public struct ResonanceRootView: View {
    @StateObject private var vm: ResonanceViewModel
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var selectedTab: ResonanceTab = .field

    public init(preferences: UserDefaults? = .standard) {
        _vm = StateObject(
            wrappedValue: ResonanceViewModel(
                preferences: preferences,
                enableSystemNowPlaying: preferences === UserDefaults.standard
            )
        )
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
            Tab(value: ResonanceTab.field) {
                ResonanceFieldView(vm: vm, palette: palette)
            } label: {
                Label("声场", systemImage: selectedTab == .field ? "waveform.circle.fill" : "waveform.circle")
            }

            Tab(value: ResonanceTab.library) {
                AcousticLibraryView(
                    vm: vm,
                    palette: palette,
                    onOpenField: { selectedTab = .field }
                )
            } label: {
                Label("声库", systemImage: selectedTab == .library ? "books.vertical.fill" : "books.vertical")
            }

            Tab(value: ResonanceTab.atelier) {
                AtelierSettingsView(
                    vm: vm,
                    palette: palette,
                    onOpenField: { selectedTab = .field }
                )
            } label: {
                Label("工坊", systemImage: selectedTab == .atelier ? "dial.medium.fill" : "dial.medium")
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
            .accessibilityHint("轻点打开声场控制台")

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
