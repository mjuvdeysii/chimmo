import SwiftUI

/// Root 3-tab shell: Resonance Field, Sound Library, and Kiln Atelier.
public struct ResonanceRootView: View {
    @StateObject private var vm: ResonanceViewModel
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase

    public init(preferences: UserDefaults = .standard) {
        _vm = StateObject(wrappedValue: ResonanceViewModel(preferences: preferences))
    }

    private var isNightResolved: Bool {
        vm.resolvedIsNight(systemScheme: systemScheme)
    }

    private var palette: ChimmoPalette {
        ChimmoPalette(isNight: isNightResolved)
    }

    private var bandAccent: Color {
        vm.selectedBand.accentColor(isNight: isNightResolved)
    }

    public var body: some View {
        TabView(selection: $vm.selectedTab) {
            ResonanceFieldView(vm: vm, palette: palette)
                .tag(ResonanceTab.field)
                .tabItem {
                    Label(ResonanceTab.field.title, systemImage: ResonanceTab.field.iconName)
                }

            AcousticLibraryView(vm: vm, palette: palette)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if vm.isResonancePlaying || vm.isSpecimenPlaying {
                        ResonanceMiniBar(vm: vm, palette: palette)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)
                    }
                }
                .tag(ResonanceTab.library)
                .tabItem {
                    Label(ResonanceTab.library.title, systemImage: ResonanceTab.library.iconName)
                }

            AtelierSettingsView(vm: vm, palette: palette)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if vm.isResonancePlaying || vm.isSpecimenPlaying {
                        ResonanceMiniBar(vm: vm, palette: palette)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)
                    }
                }
                .tag(ResonanceTab.atelier)
                .tabItem {
                    Label(ResonanceTab.atelier.title, systemImage: ResonanceTab.atelier.iconName)
                }
        }
        .tint(bandAccent)
        .preferredColorScheme(vm.appearanceMode.colorScheme)
        .sheet(isPresented: $vm.isHumSheetPresented) {
            HumResonanceSheet(vm: vm, capturePipeline: vm.capturePipeline, palette: palette)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.isCardSharePresented) {
            ResonanceCardShareSheet(vm: vm, palette: palette)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $vm.isNightLampPresented) {
            NightLampTactileSheet(vm: vm)
        }
        .onAppear {
            vm.updateSystemColorScheme(systemScheme)
        }
        .onChange(of: systemScheme) { _, newScheme in
            vm.updateSystemColorScheme(newScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            vm.handleScenePhase(newPhase)
        }
    }
}

/// Compact floating acoustic status bar shown on Library and Atelier tabs when sound is active.
private struct ResonanceMiniBar: View {
    @ObservedObject var vm: ResonanceViewModel
    let palette: ChimmoPalette

    var body: some View {
        let bandAccent = vm.selectedBand.accentColor(isNight: palette.isNight)
        let isPlaying = vm.isResonancePlaying || vm.isSpecimenPlaying

        HStack(spacing: 12) {
            Button {
                vm.selectedTab = .field
            } label: {
                HStack(spacing: 10) {
                    ChimmoDuoBadgeView(
                        isNight: palette.isNight,
                        accentColor: bandAccent,
                        melodyActive: isPlaying,
                        cowAwake: isPlaying
                    )
                    .frame(width: 42, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.activeMasterTitle)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                            .lineLimit(1)

                        Text(
                            vm.isSpecimenPlaying
                                ? String(localized: "minibar_specimen_playing", defaultValue: "室乐胶囊播放中 · 点击切回声场")
                                : (vm.pureAmbientWashOnly
                                    ? String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲")
                                    : "\(vm.selectedBand.title) · \(String(format: "%.1f Hz", vm.beatHz))")
                        )
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .frame(minHeight: ChimmoAffordance.minHitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.0))
            .accessibilityLabel(String(localized: "minibar_jump_vo", defaultValue: "返回声场主界面"))
            .accessibilityValue(
                vm.isSpecimenPlaying
                    ? "\(vm.activeMasterTitle) · \(String(localized: "minibar_specimen_playing", defaultValue: "室乐胶囊播放中 · 点击切回声场"))"
                    : (vm.pureAmbientWashOnly
                        ? "\(vm.activeMasterTitle) · \(String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲"))"
                        : "\(vm.activeMasterTitle) · \(String(format: "%.1f Hz", vm.beatHz))")
            )

            Button {
                if vm.isSpecimenPlaying {
                    vm.stopSpecimenPlayback()
                } else {
                    vm.toggleResonancePlayback()
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.contrastInkOnAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(bandAccent))
            }
            .buttonStyle(StorybookTactileButtonStyle(sinkY: 1.4))
            .accessibilityLabel(isPlaying
                                ? String(localized: "action_pause_sound", defaultValue: "暂停声场")
                                : String(localized: "action_play_sound", defaultValue: "开启声场"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: bandAccent)
    }
}
