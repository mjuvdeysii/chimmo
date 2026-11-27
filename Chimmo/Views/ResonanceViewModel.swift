import AVFAudio
import Combine
import Foundation
import QuartzCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Appearance mode across Day, Night, and System Automatic themes.
public enum ChimmoAppearanceMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case auto
    case day
    case night

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return String(localized: "appearance_auto", defaultValue: "随系统")
        case .day: return String(localized: "appearance_day", defaultValue: "暖昼陶纸")
        case .night: return String(localized: "appearance_night", defaultValue: "深眠月夜")
        }
    }

    public var badgeText: String {
        switch self {
        case .auto: return String(localized: "appearance_auto_short", defaultValue: "自动")
        case .day: return String(localized: "appearance_day_short", defaultValue: "暖昼")
        case .night: return String(localized: "appearance_night_short", defaultValue: "深眠")
        }
    }

    public var iconName: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .day: return "sun.max.fill"
        case .night: return "moon.stars.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .day: return .light
        case .night: return .dark
        }
    }
}

/// Top-level 3-tab IA: Acoustic Field / Sound Library / Atelier.
public enum ResonanceTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case field
    case library
    case atelier

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .field: return String(localized: "tab_field", defaultValue: "声场")
        case .library: return String(localized: "tab_library", defaultValue: "声库")
        case .atelier: return String(localized: "tab_atelier", defaultValue: "工坊")
        }
    }

    public var iconName: String {
        switch self {
        case .field: return "waveform.circle.fill"
        case .library: return "square.grid.2x2.fill"
        case .atelier: return "slider.horizontal.3"
        }
    }
}

/// Unified single-source-of-truth ViewModel for Mie & Mou acoustic field, specimen previews,
/// offline hum resonance calibration, sleep timer pause/resume with smooth 15s taper, and lock-screen controls.
@MainActor
public final class ResonanceViewModel: ObservableObject {
    public let router: HalfDuplexAudioRouter
    public let synth: FeltPianoSynth
    public let capturePipeline: HumCapturePipeline
    public let stats: ResonanceStatsStore

    @Published public var selectedTab: ResonanceTab = .field
    @Published public var selectedBand: BrainwaveBand = .alpha
    @Published public var beatHz: Double = BrainwaveBand.alpha.defaultBeatHz
    @Published public var carrierHz: Double = BrainwaveBand.alpha.defaultCarrierHz
    @Published public var washKind: AcousticWashKind = .breezePink
    @Published public var noiseGain: Double = AcousticWashKind.breezePink.noiseGain
    @Published public var overtoneWarmth: Double = AcousticWashKind.breezePink.overtoneWarmth

    @Published public var pureAmbientWashOnly: Bool {
        didSet {
            preferences.set(pureAmbientWashOnly, forKey: Keys.pureAmbientWashOnly)
            if isResonancePlaying {
                pushSynthBedState()
            }
            syncNowPlaying()
        }
    }

    @Published public private(set) var isResonancePlaying: Bool = false
    @Published public private(set) var activePreset: ResonancePreset? = nil
    @Published public private(set) var activeCapsule: FrissonCapsule? = nil
    @Published public private(set) var activeSpecimen: MelodyDocument? = nil
    @Published public private(set) var isSpecimenPlaying: Bool = false

    @Published public var matchedHumHz: Double? = nil
    @Published public var humMatchMessage: String? = nil

    @Published public var isHeadphonesConnected: Bool = false
    @Published public var frissonCharge: Double = 0.0
    @Published public var isFrissonCharging: Bool = false
    @Published public var frissonBurstPulse: Int = 0

    @Published public var sleepTimerMinutes: Int? = nil
    @Published public private(set) var sleepRemainingSeconds: Int = 0

    @Published public var isNightLampPresented: Bool = false
    @Published public var isHumSheetPresented: Bool = false
    @Published public var isCardSharePresented: Bool = false

    @Published public var appearanceMode: ChimmoAppearanceMode {
        didSet {
            preferences.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
            resolvedDarkMode = resolvedIsNight(systemScheme: lastSystemScheme)
            syncNowPlaying()
        }
    }

    @Published public var hapticsEnabled: Bool {
        didSet {
            preferences.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
            AcousticHapticsEngine.shared.isEnabled = hapticsEnabled
        }
    }

    private enum Keys {
        static let appearanceMode = "app.chimmo.appearanceMode"
        static let hapticsEnabled = "app.chimmo.hapticsEnabled"
        static let pureAmbientWashOnly = "app.chimmo.pureAmbientWashOnly"
    }

    private let preferences: UserDefaults
    private let nowPlaying: NowPlayingResonanceController
    private var sleepTimerTask: Task<Void, Never>?
    private var sleepMonotonicDeadline: Double?
    private var frissonChargeTask: Task<Void, Never>?
    private var specimenPlaybackTask: Task<Void, Never>?
    private var lastAcousticTickMonotonic: Double = CACurrentMediaTime()
    private var routeObserverToken: NSObjectProtocol?
    private var statsCancellable: AnyCancellable?
    private var audioReady: Bool = false
    private var lastSystemScheme: ColorScheme = .light
    private var resolvedDarkMode: Bool = false

    public init(
        preferences: UserDefaults = .standard,
        statsStore: ResonanceStatsStore? = nil,
        enableSystemNowPlaying: Bool = true
    ) {
        self.preferences = preferences
        let r = HalfDuplexAudioRouter()
        let s = FeltPianoSynth(router: r)
        let cap = HumCapturePipeline(router: r, synth: s)
        self.router = r
        self.synth = s
        self.capturePipeline = cap
        self.stats = statsStore ?? ResonanceStatsStore(preferences: preferences)
        self.nowPlaying = NowPlayingResonanceController(enabled: enableSystemNowPlaying)

        if let rawAppearance = preferences.string(forKey: Keys.appearanceMode),
           let savedMode = ChimmoAppearanceMode(rawValue: rawAppearance) {
            self.appearanceMode = savedMode
        } else {
            self.appearanceMode = .auto
        }

        if preferences.object(forKey: Keys.hapticsEnabled) != nil {
            self.hapticsEnabled = preferences.bool(forKey: Keys.hapticsEnabled)
        } else {
            self.hapticsEnabled = true
        }

        self.pureAmbientWashOnly = preferences.bool(forKey: Keys.pureAmbientWashOnly)
        AcousticHapticsEngine.shared.isEnabled = self.hapticsEnabled
        self.isHeadphonesConnected = r.isHeadphonesConnected
        self.resolvedDarkMode = (self.appearanceMode == .night)

        self.statsCancellable = self.stats.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        s.onPlaybackInterruptedBySystem = { [weak self] in
            Task { @MainActor [weak self] in
                self?.pauseFromSystemInterruption()
            }
        }

        installRouteObserver()
        bindRemoteCommands()
    }

    deinit {
        if let token = routeObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    public func resolvedIsNight(systemScheme: ColorScheme) -> Bool {
        switch appearanceMode {
        case .auto: return systemScheme == .dark
        case .day: return false
        case .night: return true
        }
    }

    public func updateSystemColorScheme(_ scheme: ColorScheme) {
        lastSystemScheme = scheme
        resolvedDarkMode = resolvedIsNight(systemScheme: scheme)
        if isResonancePlaying || activeSpecimen != nil {
            syncNowPlaying()
        }
    }

    public func prepareAudioEngineIfNeeded() {
        guard !audioReady else { return }
        audioReady = true
        synth.ensureRunning(clearUserInterruption: true)
        refreshHeadphonesState()
    }

    public func refreshHeadphonesState() {
        isHeadphonesConnected = router.isHeadphonesConnected
    }

    public var isochronicDepthForCurrentRoute: Double {
        if pureAmbientWashOnly { return 0.0 }
        if isHeadphonesConnected {
            return selectedBand == .gamma ? 0.08 : 0.05
        }
        return selectedBand == .gamma ? 0.30 : 0.24
    }

    public var activeMasterTitle: String {
        if let specimen = activeSpecimen, isSpecimenPlaying {
            return specimen.title
        }
        if pureAmbientWashOnly {
            return "\(washKind.title) · \(String(localized: "wash_pure_badge", defaultValue: "纯自然声床"))"
        }
        if let preset = activePreset {
            return preset.title
        }
        if let capsule = activeCapsule {
            return capsule.title
        }
        return "\(selectedBand.title) · \(String(format: "%.1f", beatHz)) Hz"
    }

    // MARK: - Scene Lifecycle

    public func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            refreshHeadphonesState()
            AcousticHapticsEngine.shared.isEnabled = hapticsEnabled
        case .inactive:
            AcousticHapticsEngine.shared.stopForBackground()
            stats.flush()
            if capturePipeline.isRecording || capturePipeline.isStartingCapture {
                cancelHumCapture()
            }
        case .background:
            AcousticHapticsEngine.shared.stopForBackground()
            stats.flush()
            if !isResonancePlaying && !isSpecimenPlaying {
                synth.stopAndDeactivate()
                audioReady = false
                nowPlaying.clearNowPlayingInfo()
            }
        @unknown default:
            break
        }
    }

    private func pauseFromSystemInterruption() {
        isResonancePlaying = false
        isSpecimenPlaying = false
        specimenPlaybackTask?.cancel()
        specimenPlaybackTask = nil
        frissonChargeTask?.cancel()
        frissonChargeTask = nil
        isFrissonCharging = false
        frissonCharge = 0.0
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepMonotonicDeadline = nil
        if sleepTimerMinutes == nil {
            sleepRemainingSeconds = 0
        }
        activeCapsule = nil
        synth.stopBrainwaveBed()
        synth.silenceAll()
        stats.flush()
        syncNowPlaying()
    }

    // MARK: - Playback Controls

    public func toggleResonancePlayback() {
        if isResonancePlaying {
            pauseResonancePlayback()
        } else {
            startResonancePlayback()
        }
    }

    public func startPreset(_ preset: ResonancePreset) {
        stopSpecimenPlayback()
        prepareAudioEngineIfNeeded()
        activeCapsule = nil
        activePreset = preset
        selectedBand = preset.band
        beatHz = ResonanceKinematics.clampedBeatHz(preset.beatHz)
        carrierHz = matchedHumHz ?? preset.carrierHz
        washKind = preset.washKind
        noiseGain = preset.washKind.noiseGain
        overtoneWarmth = preset.washKind.overtoneWarmth

        isResonancePlaying = true
        lastAcousticTickMonotonic = CACurrentMediaTime()
        resumeArmedSleepDeadlineIfNeeded()
        synth.setSleepFadeMultiplier(1.0)
        pushSynthBedState()
        stats.recordRecentPreset(preset.id)
        ensureAcousticProgressLoopIfPlaying()
        syncNowPlaying()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playBrainwaveDetent(bandIndex: preset.band.bandIndex)
        }
    }

    public func startResonancePlayback() {
        stopSpecimenPlayback()
        prepareAudioEngineIfNeeded()
        isResonancePlaying = true
        lastAcousticTickMonotonic = CACurrentMediaTime()
        resumeArmedSleepDeadlineIfNeeded()
        if let deadline = sleepMonotonicDeadline {
            let rem = max(0.0, deadline - CACurrentMediaTime())
            if rem <= 15.0 {
                let linear = max(0.0, min(1.0, rem / 15.0))
                synth.setSleepFadeMultiplier(max(0.015, linear * linear))
            } else {
                synth.setSleepFadeMultiplier(1.0)
            }
        } else {
            synth.setSleepFadeMultiplier(1.0)
        }
        pushSynthBedState()
        ensureAcousticProgressLoopIfPlaying()
        syncNowPlaying()
    }

    public func pauseResonancePlayback() {
        isResonancePlaying = false
        stopSpecimenPlayback()
        synth.stopBrainwaveBed()
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        if let deadline = sleepMonotonicDeadline {
            sleepRemainingSeconds = max(0, Int(ceil(deadline - CACurrentMediaTime())))
        }
        sleepMonotonicDeadline = nil
        if sleepTimerMinutes == nil {
            sleepRemainingSeconds = 0
        }
        stats.flush()
        syncNowPlaying()
    }

    private func resumeArmedSleepDeadlineIfNeeded() {
        if sleepTimerMinutes != nil && sleepRemainingSeconds > 0 && sleepMonotonicDeadline == nil {
            sleepMonotonicDeadline = CACurrentMediaTime() + Double(sleepRemainingSeconds)
        }
    }

    public func selectBand(_ band: BrainwaveBand, startPlayingIfIdle: Bool = true) {
        selectedBand = band
        activePreset = nil
        beatHz = band.defaultBeatHz
        carrierHz = matchedHumHz ?? band.defaultCarrierHz

        if band == .gamma && washKind == .rainBrown {
            applyWashKind(.mistWhite, updateSynth: false)
        } else if band == .delta && washKind == .mistWhite {
            applyWashKind(.rainBrown, updateSynth: false)
        }

        if isResonancePlaying {
            synth.setSleepFadeMultiplier(1.0)
            pushSynthBedState()
        } else if startPlayingIfIdle {
            startResonancePlayback()
        }
        syncNowPlaying()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playBrainwaveDetent(bandIndex: band.bandIndex)
        }
    }

    public func cycleBand(step: Int) {
        let all = BrainwaveBand.allCases
        guard let idx = all.firstIndex(of: selectedBand) else { return }
        let next = (idx + step + all.count) % all.count
        selectBand(all[next], startPlayingIfIdle: true)
    }

    public func applyWashKind(_ kind: AcousticWashKind, updateSynth: Bool = true) {
        washKind = kind
        noiseGain = kind.noiseGain
        overtoneWarmth = kind.overtoneWarmth
        if updateSynth && isResonancePlaying {
            pushSynthBedState()
        }
        if updateSynth {
            syncNowPlaying()
        }
        if updateSynth && hapticsEnabled {
            AcousticHapticsEngine.shared.playScrubTick()
        }
    }

    public func setNoiseGain(_ gain: Double) {
        let clamped = gain.isFinite ? max(0.0, min(0.24, gain)) : 0.08
        noiseGain = clamped
        if isResonancePlaying {
            pushSynthBedState()
        }
    }

    public func setOvertoneWarmth(_ warmth: Double) {
        let clamped = warmth.isFinite ? max(0.0, min(1.0, warmth)) : 0.55
        overtoneWarmth = clamped
        if isResonancePlaying {
            pushSynthBedState()
        }
    }

    public func triggerTactileClick(index: Int = 0) {
        prepareAudioEngineIfNeeded()
        synth.playTactileKilnClick(variantIndex: index, bright: 0.72 + Double(index % 4) * 0.05)
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playScrubTick()
        }
    }

    public func updateInteractiveDial(beatHz newBeatHz: Double, carrierShiftHz: Double? = nil) {
        let clampedBeat = ResonanceKinematics.clampedBeatHz(newBeatHz)
        let prevBand = selectedBand
        let nextBand = ResonanceKinematics.band(forBeatHz: clampedBeat)
        beatHz = clampedBeat
        if nextBand != prevBand {
            selectedBand = nextBand
            activePreset = nil
            if hapticsEnabled {
                AcousticHapticsEngine.shared.playBrainwaveDetent(bandIndex: nextBand.bandIndex)
            }
        }
        if let c = carrierShiftHz, c.isFinite {
            carrierHz = max(110.0, min(320.0, c))
        }
        if isResonancePlaying {
            pushSynthBedState()
        }
        syncNowPlaying()
    }

    // MARK: - Frisson Hold & Release

    public func beginFrissonHold() {
        guard !isFrissonCharging else { return }
        prepareAudioEngineIfNeeded()
        isFrissonCharging = true
        frissonCharge = 0.0
        frissonChargeTask?.cancel()
        frissonChargeTask = Task { @MainActor [weak self] in
            let start = CACurrentMediaTime()
            while let self, self.isFrissonCharging && !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - start
                let nextCharge = min(1.0, elapsed / 1.45)
                self.frissonCharge = nextCharge
                if self.isResonancePlaying {
                    self.pushSynthBedState()
                }
                if self.hapticsEnabled {
                    AcousticHapticsEngine.shared.playFrissonBuildTick(progress: nextCharge)
                }
                if nextCharge >= 1.0 {
                    self.releaseFrissonBloom(charged: 1.0)
                    return
                }
                try? await Task.sleep(nanoseconds: 55_000_000)
            }
        }
    }

    public func releaseFrissonHold() {
        guard isFrissonCharging else { return }
        let current = frissonCharge
        isFrissonCharging = false
        frissonChargeTask?.cancel()
        frissonChargeTask = nil
        if current >= 0.25 {
            releaseFrissonBloom(charged: current)
        } else {
            frissonCharge = 0.0
            if isResonancePlaying {
                pushSynthBedState()
            }
        }
    }

    public func releaseFrissonBloom(charged: Double = 0.88) {
        let safeCharged = charged.isFinite ? max(0.45, min(1.0, charged)) : 0.88
        isFrissonCharging = false
        frissonChargeTask?.cancel()
        frissonChargeTask = nil
        frissonCharge = 0.0
        frissonBurstPulse &+= 1
        prepareAudioEngineIfNeeded()
        synth.triggerFrissonRelease(rootHz: carrierHz, intensity: safeCharged)
        if isResonancePlaying {
            pushSynthBedState()
        }
        stats.recordFrissonPeak()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playFrissonCascade(intensity: Float(0.62 + safeCharged * 0.36))
        }
    }

    // MARK: - Sleep Timer (Monotonic Clock Pause/Resume + Smooth 15s Taper)

    public func setSleepTimer(minutes: Int?) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        guard let minutes, minutes > 0 else {
            sleepTimerMinutes = nil
            sleepRemainingSeconds = 0
            sleepMonotonicDeadline = nil
            synth.setSleepFadeMultiplier(1.0)
            if isResonancePlaying {
                ensureAcousticProgressLoopIfPlaying()
            }
            syncNowPlaying()
            return
        }

        let clamped = max(5, min(180, minutes))
        sleepTimerMinutes = clamped
        sleepRemainingSeconds = clamped * 60
        sleepMonotonicDeadline = CACurrentMediaTime() + Double(clamped * 60)
        synth.setSleepFadeMultiplier(1.0)

        if !isResonancePlaying && !isSpecimenPlaying {
            startResonancePlayback()
        } else {
            startSleepAndProgressLoop()
        }
        syncNowPlaying()
    }

    private func ensureAcousticProgressLoopIfPlaying() {
        if sleepTimerTask == nil {
            startSleepAndProgressLoop()
        }
    }

    private func startSleepAndProgressLoop() {
        sleepTimerTask?.cancel()
        lastAcousticTickMonotonic = CACurrentMediaTime()
        sleepTimerTask = Task { @MainActor [weak self] in
            var secondCounter = 0
            var subTicks = 0
            while let self, !Task.isCancelled {
                let inFinalFade: Bool = {
                    if let dl = self.sleepMonotonicDeadline {
                        return (dl - CACurrentMediaTime()) <= 16.0
                    }
                    return false
                }()
                let sleepNs: UInt64 = inFinalFade ? 200_000_000 : 1_000_000_000
                try? await Task.sleep(nanoseconds: sleepNs)
                guard !Task.isCancelled else { return }

                let nowMono = CACurrentMediaTime()
                let delta = min(5.0, max(0.0, nowMono - self.lastAcousticTickMonotonic))
                self.lastAcousticTickMonotonic = nowMono
                if self.isResonancePlaying && delta > 0.0 {
                    self.stats.recordResonanceSeconds(delta, band: self.selectedBand)
                }

                if let deadline = self.sleepMonotonicDeadline {
                    let remDouble = deadline - nowMono
                    if remDouble <= 0 {
                        self.sleepRemainingSeconds = 0
                        self.sleepMonotonicDeadline = nil
                        self.sleepTimerMinutes = nil
                        self.stats.recordSessionCompleted(band: self.selectedBand)
                        self.pauseResonancePlayback()
                        self.synth.stopAndDeactivate()
                        self.audioReady = false
                        self.nowPlaying.clearNowPlayingInfo()
                        return
                    }
                    self.sleepRemainingSeconds = Int(ceil(remDouble))
                    if remDouble <= 15.0 {
                        let linear = max(0.0, min(1.0, remDouble / 15.0))
                        self.synth.setSleepFadeMultiplier(max(0.015, linear * linear))
                    } else {
                        self.synth.setSleepFadeMultiplier(1.0)
                    }
                } else if !self.isResonancePlaying {
                    return
                }

                subTicks += inFinalFade ? 1 : 5
                if subTicks >= 5 {
                    subTicks = 0
                    secondCounter += 1
                    if self.isResonancePlaying && secondCounter % 3 == 0 {
                        self.refreshHeadphonesState()
                        if secondCounter % 15 == 0 {
                            self.syncNowPlaying()
                        }
                        if self.hapticsEnabled && self.isNightLampPresented {
                            AcousticHapticsEngine.shared.playBrainwavePulse(intensity: 0.24)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hum Capture Calibration

    public func beginHumCalibration() {
        pauseResonancePlayback()
        humMatchMessage = nil
        capturePipeline.startRecording()
    }

    public func cancelHumCapture() {
        capturePipeline.cancelRecording()
        humMatchMessage = nil
    }

    public func finishHumResonance() async -> Bool {
        guard let rawHz = await capturePipeline.stopAndExtractFundamentalHz() else {
            return false
        }
        let folded = ResonanceKinematics.foldHumFrequencyToCarrier(rawHz)
        matchedHumHz = folded
        carrierHz = folded
        selectedBand = .theta
        beatHz = BrainwaveBand.theta.defaultBeatHz
        overtoneWarmth = 0.85
        noiseGain = AcousticWashKind.kilnOvertone.noiseGain
        washKind = .kilnOvertone
        humMatchMessage = String(
            format: String(localized: "hum_locked_format", defaultValue: "已将你的自然音色锁频至 %.0f Hz 共振载波"),
            folded
        )
        startResonancePlayback()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playResolutionExhale()
        }
        return true
    }

    public func applyQuickHumPresetHz(_ hz: Double) {
        let folded = ResonanceKinematics.foldHumFrequencyToCarrier(hz)
        matchedHumHz = folded
        carrierHz = folded
        humMatchMessage = String(
            format: String(localized: "hum_preset_locked_format", defaultValue: "已选择 %.0f Hz 暖声共振载波"),
            folded
        )
        startResonancePlayback()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.55)
        }
    }

    public func clearMatchedHum() {
        matchedHumHz = nil
        humMatchMessage = nil
        carrierHz = selectedBand.defaultCarrierHz
        if isResonancePlaying {
            pushSynthBedState()
        }
        syncNowPlaying()
    }

    // MARK: - Specimen & Capsule Acoustic Audition

    public func toggleCapsule(_ capsule: FrissonCapsule) {
        if activeCapsule?.id == capsule.id && isSpecimenPlaying {
            stopSpecimenPlayback()
            activeCapsule = nil
        } else {
            playFrissonCapsule(capsule)
        }
    }

    public func playFrissonCapsule(_ capsule: FrissonCapsule) {
        activeCapsule = capsule
        startSpecimenAudition(capsule.specimen)
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playSeedBloom()
        }
    }

    public func toggleSpecimenPlayback(_ specimen: MelodyDocument) {
        if activeSpecimen?.id == specimen.id && isSpecimenPlaying {
            stopSpecimenPlayback()
        } else {
            activeCapsule = nil
            startSpecimenAudition(specimen)
        }
    }

    public func startSpecimenAudition(_ document: MelodyDocument) {
        pauseResonancePlayback()
        prepareAudioEngineIfNeeded()
        activeSpecimen = document
        isSpecimenPlaying = true
        synth.applySpaceProfile(AcousticSpaceProfile.profile(for: document.scaleMode))
        synth.setSleepFadeMultiplier(1.0)
        syncNowPlaying()

        specimenPlaybackTask?.cancel()
        specimenPlaybackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let resolvedVoice = document.preferredVoice ?? .singingCello
            let timbre = FeltPianoSynth.Timbre.from(voice: resolvedVoice)
            let preferredTexture = document.preferredTexture ?? .swanRipple
            let spans = TheoryLensEngine.buildChordSpans(document: document, preset: .autoMatch)
            let groove = document.grooveStrength
            let notes = document.notes.sorted {
                $0.displayOnset(grooveStrength: groove) < $1.displayOnset(grooveStrength: groove)
            }
            let totalDuration = max(2.0, document.totalDuration)

            let timelineStart = CACurrentMediaTime()
            var nextNoteIdx = 0
            var nextSpanIdx = 0

            while self.isSpecimenPlaying && !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - timelineStart
                while nextSpanIdx < spans.count && spans[nextSpanIdx].startTime <= elapsed {
                    let span = spans[nextSpanIdx]
                    nextSpanIdx += 1
                    self.synth.playDiatonicChord(
                        rootMIDI: document.rootMIDI,
                        mode: document.scaleMode,
                        chord: span.chord,
                        texture: preferredTexture,
                        spanDuration: max(0.75, span.endTime - span.startTime),
                        intensity: 0.72
                    )
                }
                while nextNoteIdx < notes.count && notes[nextNoteIdx].displayOnset(grooveStrength: groove) <= elapsed {
                    let bead = notes[nextNoteIdx]
                    nextNoteIdx += 1
                    let onset = bead.displayOnset(grooveStrength: groove)
                    let dur = bead.displayDuration(grooveStrength: groove)
                    let hz = document.scaleMode.frequencyHz(
                        rootMIDI: document.rootMIDI,
                        degree: bead.degree,
                        octaveOffset: bead.octaveOffset
                    )
                    let pan = AcousticSpatialPanMapper.pan(
                        forBeatOnset: onset,
                        totalDuration: totalDuration,
                        visualMode: .orbitalDisc
                    )
                    self.synth.playNote(
                        frequency: hz,
                        velocity: 0.62,
                        decay: max(0.85, dur * 1.45),
                        brightness: 0.96,
                        timbre: timbre,
                        delaySeconds: 0.0,
                        pan: pan
                    )
                    if self.hapticsEnabled {
                        let m = ChimmoMember.from(degree: bead.degree)
                        AcousticHapticsEngine.shared.playPlaybackNotePulse(
                            laneIndex: bead.degree - 1,
                            isHome: m.isTriadPillar,
                            isTension: m.isTensionDegree,
                            isDownbeat: nextNoteIdx == 1
                        )
                    }
                }
                if elapsed >= totalDuration + 1.2 {
                    break
                }
                try? await Task.sleep(nanoseconds: 28_000_000)
            }

            if !Task.isCancelled {
                self.isSpecimenPlaying = false
                self.activeCapsule = nil
                self.syncNowPlaying()
            }
        }
    }

    public func stopSpecimenPlayback() {
        specimenPlaybackTask?.cancel()
        specimenPlaybackTask = nil
        if isSpecimenPlaying {
            isSpecimenPlaying = false
            activeCapsule = nil
            synth.softStopChamberVoices()
            syncNowPlaying()
        }
    }

    public func auditionChimmoMember(_ member: ChimmoMember) {
        prepareAudioEngineIfNeeded()
        let mode = ScaleMode.brightMajor
        let hz = mode.frequencyHz(rootMIDI: 60, degree: member.degree, octaveOffset: 0)
        synth.playNote(
            frequency: hz,
            velocity: 0.65,
            decay: 1.45,
            brightness: 0.94,
            timbre: .feltPiano,
            delaySeconds: 0.0,
            pan: 0.0
        )
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playPitchTouch(
                laneIndex: member.degree - 1,
                isHome: member.isTriadPillar,
                isTension: member.isTensionDegree
            )
        }
    }

    // MARK: - Audio Synthesis & System Observers

    private func pushSynthBedState() {
        if pureAmbientWashOnly {
            synth.setBrainwaveBed(
                carrierHz: carrierHz,
                beatHz: beatHz,
                gain: 0.0,
                isochronicDepth: 0.0,
                overtoneWarmth: 0.0,
                noiseGain: max(0.08, noiseGain),
                noiseColor: washKind.noiseColor,
                frissonTension: 0.0,
                pureWashOnly: true
            )
            return
        }

        let baseGain: Double
        switch selectedBand {
        case .delta: baseGain = 0.24
        case .theta: baseGain = 0.26
        case .alpha: baseGain = 0.24
        case .gamma: baseGain = 0.16
        }
        synth.setBrainwaveBed(
            carrierHz: carrierHz,
            beatHz: beatHz,
            gain: baseGain,
            isochronicDepth: isochronicDepthForCurrentRoute,
            overtoneWarmth: overtoneWarmth,
            noiseGain: noiseGain,
            noiseColor: washKind.noiseColor,
            frissonTension: frissonCharge,
            pureWashOnly: false
        )
    }

    private func installRouteObserver() {
        #if os(iOS)
        routeObserverToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let reasonRaw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            let reason = reasonRaw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshHeadphonesState()
                if reason == .oldDeviceUnavailable {
                    if self.isResonancePlaying || self.isSpecimenPlaying {
                        self.pauseResonancePlayback()
                    }
                    return
                }
                if self.isResonancePlaying {
                    self.pushSynthBedState()
                }
            }
        }
        #endif
    }

    private func bindRemoteCommands() {
        nowPlaying.bindCommands(
            onPlay: { [weak self] in
                guard let self, !self.isResonancePlaying, !self.isSpecimenPlaying else { return }
                self.startResonancePlayback()
            },
            onPause: { [weak self] in
                guard let self else { return }
                self.pauseResonancePlayback()
            },
            onToggle: { [weak self] in
                guard let self else { return }
                if self.isSpecimenPlaying {
                    self.stopSpecimenPlayback()
                } else {
                    self.toggleResonancePlayback()
                }
            },
            onNextBand: { [weak self] in
                guard let self else { return }
                self.cycleBand(step: 1)
            },
            onPreviousBand: { [weak self] in
                guard let self else { return }
                self.cycleBand(step: -1)
            }
        )
    }

    private func syncNowPlaying() {
        if !isResonancePlaying && !isSpecimenPlaying && sleepTimerMinutes == nil && activePreset == nil {
            nowPlaying.clearNowPlayingInfo()
            return
        }
        let duration = sleepTimerMinutes.map { Double($0 * 60) }
        let elapsed = duration.map { max(0.0, $0 - Double(sleepRemainingSeconds)) }
        let isNight = resolvedDarkMode
        let bandSummary = pureAmbientWashOnly
            ? washKind.title
            : "\(selectedBand.title) · \(selectedBand.hzRangeLabel)"
        nowPlaying.updateNowPlaying(
            title: activeMasterTitle,
            bandLabel: bandSummary,
            isPlaying: isResonancePlaying || isSpecimenPlaying,
            durationSeconds: duration,
            elapsedSeconds: elapsed,
            accentHex: isNight ? selectedBand.accentHexNight : selectedBand.accentHexLight,
            isNight: isNight
        )
    }
}
