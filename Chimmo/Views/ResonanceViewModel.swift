import AVFAudio
import Combine
import Foundation
import QuartzCore
import SwiftUI

/// V2.0 「咩哞 · 脑波共振场」核心状态机（100% 离线、统筹双耳声场 / 颅内战栗 / 轻哼迷走同频 / 精选乐章胶囊）。
@MainActor
public final class ResonanceViewModel: ObservableObject {
    private static let hapticsPrefKey = "chimmo.v2.pref.haptics"
    private static let bgAudioPrefKey = "chimmo.v2.pref.bgAudio"

    public let studioVM: StudioViewModel
    public let stats: ResonanceStatsStore

    @Published public var selectedBand: BrainwaveBand = .alpha
    @Published public var beatHz: Double = BrainwaveBand.alpha.defaultBeatHz
    @Published public var carrierHz: Double = BrainwaveBand.alpha.defaultCarrierHz
    @Published public var washKind: AcousticWashKind = .breezePink
    @Published public var noiseGain: Double = AcousticWashKind.breezePink.noiseGain
    @Published public var overtoneWarmth: Double = AcousticWashKind.breezePink.overtoneWarmth

    @Published public var isBedPlaying: Bool = false
    @Published public var isHeadphonesConnected: Bool = false
    @Published public var activePreset: ResonancePreset? = nil
    @Published public var activeCapsule: FrissonCapsule? = nil

    @Published public var frissonCharge: Double = 0.0
    @Published public var isHoldingFrisson: Bool = false
    @Published public var frissonBurstSequence: Int = 0
    @Published public var isHumCapturing: Bool = false
    @Published public var humStatusHint: String = ""
    @Published public var matchedHumHz: Double? = nil

    /// 定时分钟数：0 表示持续不限
    @Published public var timerMinutes: Int = 15
    @Published public var remainingSeconds: Int? = nil

    @Published public var hapticsEnabled: Bool = true {
        didSet {
            preferences?.set(hapticsEnabled, forKey: Self.hapticsPrefKey)
        }
    }
    @Published public var backgroundAudioEnabled: Bool = true {
        didSet {
            preferences?.set(backgroundAudioEnabled, forKey: Self.bgAudioPrefKey)
        }
    }

    @Published public var openNightLampSheet: Bool = false
    @Published public var focusHumGuideOnFieldAppear: Bool = false
    @Published public var focusFrissonGuideOnFieldAppear: Bool = false

    private let preferences: UserDefaults?
    private let nowPlaying: NowPlayingResonanceController
    private var clickVariantCounter: Int = 0
    private var sessionTickTask: Task<Void, Never>?
    private var frissonHoldTask: Task<Void, Never>?
    private var routeObserverToken: NSObjectProtocol?
    private var cancellables: Set<AnyCancellable> = []
    private var holdStartedAt: Double = 0

    public init(
        studioVM: StudioViewModel? = nil,
        statsStore: ResonanceStatsStore? = nil,
        preferences: UserDefaults? = nil,
        enableSystemNowPlaying: Bool = false
    ) {
        let resolvedStudio = studioVM ?? StudioViewModel(preferences: preferences)
        let resolvedStats = statsStore ?? ResonanceStatsStore(preferences: preferences)
        self.studioVM = resolvedStudio
        self.stats = resolvedStats
        self.preferences = preferences
        self.nowPlaying = NowPlayingResonanceController(enabled: enableSystemNowPlaying)

        if let prefs = preferences {
            if prefs.object(forKey: Self.hapticsPrefKey) != nil {
                self.hapticsEnabled = prefs.bool(forKey: Self.hapticsPrefKey)
            }
            if prefs.object(forKey: Self.bgAudioPrefKey) != nil {
                self.backgroundAudioEnabled = prefs.bool(forKey: Self.bgAudioPrefKey)
            }
        }

        self.isHeadphonesConnected = resolvedStudio.router.isHeadphonesConnected
        observeSystemAndCaptureEvents()
        bindRemotePlaybackCommands()
    }

    deinit {
        if let token = routeObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func observeSystemAndCaptureEvents() {
        #if os(iOS)
        routeObserverToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let nextHeadphones = self.studioVM.router.isHeadphonesConnected
                if nextHeadphones != self.isHeadphonesConnected {
                    self.isHeadphonesConnected = nextHeadphones
                    if self.isBedPlaying {
                        self.pushSynthBedState()
                    }
                }
            }
        }
        #endif

        studioVM.capturePipeline.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] msg in
                guard let self, !msg.isEmpty else { return }
                self.humStatusHint = msg
                if self.isHumCapturing && !self.studioVM.capturePipeline.isRecording {
                    self.isHumCapturing = false
                }
            }
            .store(in: &cancellables)
    }

    public var effectiveIsochronicDepth: Double {
        if isHeadphonesConnected {
            // 戴耳机走纯正双耳立体声差频，只留极微弱呼吸波纹避免生硬感
            return 0.04
        }
        // 外放时自动补偿柔和等时脉动，不戴耳机也能感知清晰节律（Gamma 高频柔和克制）
        return selectedBand == .gamma ? 0.14 : 0.24
    }

    public var currentHeadline: String {
        if let cap = activeCapsule {
            return cap.title
        }
        if let preset = activePreset {
            return preset.title
        }
        return "\(selectedBand.title) · \(String(format: "%.1f", beatHz)) Hz"
    }

    public var currentSubline: String {
        if activeCapsule != nil {
            return "正在演奏声波乐章"
        }
        return isHeadphonesConnected ? "耳机双耳差频模式" : "外放等时共振模式"
    }

    // MARK: - Playback & Band Controls

    public func startPreset(_ preset: ResonancePreset) {
        stopCapsule()
        activePreset = preset
        selectedBand = preset.band
        beatHz = preset.beatHz
        carrierHz = preset.carrierHz
        washKind = preset.washKind
        noiseGain = preset.washKind.noiseGain
        overtoneWarmth = preset.washKind.overtoneWarmth
        timerMinutes = preset.durationMinutes
        remainingSeconds = preset.durationMinutes > 0 ? preset.durationMinutes * 60 : nil

        isBedPlaying = true
        pushSynthBedState()
        stats.recordRecentPreset(preset.id)
        restartSessionTicker()
        syncNowPlaying()

        if hapticsEnabled {
            AcousticHapticsEngine.shared.playBrainwaveDetent(bandIndex: preset.band.bandIndex)
        }
    }

    public func selectBand(_ band: BrainwaveBand, autoPlay: Bool = true) {
        let changed = band != selectedBand
        selectedBand = band
        activePreset = nil
        beatHz = band.defaultBeatHz
        carrierHz = band.defaultCarrierHz
        if washKind != .pureWave {
            noiseGain = band.defaultNoiseGain
        }
        if autoPlay {
            stopCapsule()
            if !isBedPlaying {
                isBedPlaying = true
                if timerMinutes > 0 && remainingSeconds == nil {
                    remainingSeconds = timerMinutes * 60
                }
                restartSessionTicker()
            }
            pushSynthBedState()
        } else if isBedPlaying {
            pushSynthBedState()
        }
        syncNowPlaying()

        if changed {
            clickVariantCounter &+= 1
            studioVM.synth.playTactileKilnClick(variantIndex: clickVariantCounter)
            if hapticsEnabled {
                AcousticHapticsEngine.shared.playBrainwaveDetent(bandIndex: band.bandIndex)
            }
        }
    }

    public func applyWashKind(_ kind: AcousticWashKind) {
        washKind = kind
        noiseGain = kind.noiseGain
        overtoneWarmth = kind.overtoneWarmth
        activePreset = nil
        if isBedPlaying {
            pushSynthBedState()
            syncNowPlaying()
        }
        clickVariantCounter &+= 1
        studioVM.synth.playTactileKilnClick(variantIndex: clickVariantCounter, bright: 0.85)
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playScrubTick()
        }
    }

    public func updateNoiseGain(_ value: Double) {
        noiseGain = max(0.0, min(0.24, value.isFinite ? value : 0.08))
        if isBedPlaying {
            pushSynthBedState()
        }
    }

    public func updateOvertoneWarmth(_ value: Double) {
        overtoneWarmth = max(0.0, min(1.0, value.isFinite ? value : 0.55))
        if isBedPlaying {
            pushSynthBedState()
        }
    }

    public func setTimerMinutes(_ minutes: Int) {
        let safe = max(0, min(90, minutes))
        timerMinutes = safe
        if isBedPlaying {
            remainingSeconds = safe > 0 ? safe * 60 : nil
            syncNowPlaying()
        } else {
            remainingSeconds = nil
        }
        clickVariantCounter &+= 1
        studioVM.synth.playTactileKilnClick(variantIndex: clickVariantCounter, bright: 0.72)
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playScrubTick()
        }
    }

    public func toggleBedPlayback() {
        if isBedPlaying {
            stopBedPlayback()
        } else {
            stopCapsule()
            isBedPlaying = true
            if timerMinutes > 0 && (remainingSeconds ?? 0) <= 0 {
                remainingSeconds = timerMinutes * 60
            }
            pushSynthBedState()
            restartSessionTicker()
            syncNowPlaying()
            if hapticsEnabled {
                AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.45)
            }
        }
    }

    public func stopBedPlayback() {
        isBedPlaying = false
        sessionTickTask?.cancel()
        sessionTickTask = nil
        studioVM.synth.stopBrainwaveBed()
        syncNowPlaying()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playScrubTick()
        }
    }

    public func stopAllAudio() {
        cancelFrissonHold()
        stopBedPlayback()
        stopCapsule()
        studioVM.synth.silenceAll()
        nowPlaying.clear()
    }

    public func handleAppEnteredBackground() {
        if !backgroundAudioEnabled {
            stopBedPlayback()
            stopCapsule()
        }
    }

    public func tuneBeatFrequency(_ newBeatHz: Double, carrierOffsetNorm: Double = 0.0) {
        let clampedBeat = ResonanceKinematics.clampedBeatHz(newBeatHz)
        let prevBand = selectedBand
        let nextBand = ResonanceKinematics.band(forBeatHz: clampedBeat)
        beatHz = clampedBeat
        selectedBand = nextBand
        activePreset = nil

        if matchedHumHz == nil {
            let offset = max(-1.0, min(1.0, carrierOffsetNorm.isFinite ? carrierOffsetNorm : 0.0))
            carrierHz = max(100.0, min(320.0, nextBand.defaultCarrierHz + offset * 28.0))
        }

        if isBedPlaying {
            pushSynthBedState()
        }

        if nextBand != prevBand && hapticsEnabled {
            AcousticHapticsEngine.shared.playBrainwaveDetent(bandIndex: nextBand.bandIndex)
        }
    }

    // MARK: - Frisson Hold & Release (颅内战栗瞬时快感)

    public func beginFrissonHold() {
        guard !isHoldingFrisson else { return }
        isHoldingFrisson = true
        holdStartedAt = CACurrentMediaTime()
        frissonCharge = max(frissonCharge, 0.12)
        studioVM.synth.ensureRunning()
        pushFrissonTensionToSynth(charge: frissonCharge)

        frissonHoldTask?.cancel()
        frissonHoldTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isHoldingFrisson else { break }
                let held = max(0.0, CACurrentMediaTime() - self.holdStartedAt)
                let nextCharge = min(1.0, 0.12 + held / 1.75)
                self.frissonCharge = nextCharge
                self.pushFrissonTensionToSynth(charge: nextCharge)
                if self.hapticsEnabled {
                    AcousticHapticsEngine.shared.playFrissonBuildTick(progress: nextCharge)
                }
                if nextCharge >= 1.0 {
                    try? await Task.sleep(nanoseconds: 95_000_000)
                } else {
                    try? await Task.sleep(nanoseconds: 55_000_000)
                }
            }
        }
    }

    public func updateFrissonHold(progress: Double) {
        let clamped = progress.isFinite ? max(0.0, min(1.0, progress)) : 0.0
        frissonCharge = clamped
        pushFrissonTensionToSynth(charge: clamped)
    }

    public func releaseFrissonHold() {
        let wasHolding = isHoldingFrisson
        isHoldingFrisson = false
        frissonHoldTask?.cancel()
        frissonHoldTask = nil

        let charge = max(0.38, min(1.0, wasHolding ? frissonCharge : 0.72))
        frissonCharge = 0.0

        studioVM.synth.triggerFrissonRelease(rootHz: carrierHz, intensity: 0.55 + charge * 0.45)
        if isBedPlaying {
            pushSynthBedState()
        } else {
            studioVM.synth.stopBrainwaveBed()
        }

        if hapticsEnabled {
            AcousticHapticsEngine.shared.playFrissonCascade(intensity: Float(0.62 + charge * 0.36))
        }
        frissonBurstSequence &+= 1
        stats.recordFrissonPeak()
    }

    public func cancelFrissonHold() {
        isHoldingFrisson = false
        frissonHoldTask?.cancel()
        frissonHoldTask = nil
        frissonCharge = 0.0
        if isBedPlaying {
            pushSynthBedState()
        } else {
            studioVM.synth.stopBrainwaveBed()
        }
    }

    private func pushFrissonTensionToSynth(charge: Double) {
        let gain = isBedPlaying ? 0.25 : 0.14
        let noise = isBedPlaying ? noiseGain : 0.03
        studioVM.synth.setBrainwaveBed(
            carrierHz: carrierHz,
            beatHz: beatHz,
            gain: gain,
            isochronicDepth: effectiveIsochronicDepth,
            overtoneWarmth: overtoneWarmth,
            noiseGain: noise,
            noiseColor: washKind.noiseColor,
            frissonTension: charge
        )
    }

    // MARK: - Vagal Hum Resonance (3 秒轻哼同频包裹)

    public func startHumResonance() {
        stopBedPlayback()
        stopCapsule()
        humStatusHint = ""
        isHumCapturing = true
        studioVM.capturePipeline.startRecording()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playBeatTap(isStrong: true)
        }
    }

    public func finishHumResonance() async {
        guard studioVM.capturePipeline.isRecording else {
            isHumCapturing = false
            return
        }
        let detected = await studioVM.capturePipeline.stopAndExtractFundamentalHz()
        isHumCapturing = false
        guard let rawHz = detected else {
            if humStatusHint.isEmpty {
                humStatusHint = "没听清轻哼声，可以再试一次或直接选择常用共振基频"
            }
            return
        }
        let folded = ResonanceKinematics.foldHumFrequencyToCarrier(rawHz)
        matchedHumHz = folded
        carrierHz = folded
        selectedBand = .theta
        beatHz = 6.0
        washKind = .kilnOvertone
        noiseGain = AcousticWashKind.kilnOvertone.noiseGain
        overtoneWarmth = 0.86
        activePreset = nil
        humStatusHint = "已锁住你声音的基频 \(Int(folded.rounded())) Hz"

        isBedPlaying = true
        if timerMinutes > 0 && (remainingSeconds ?? 0) <= 0 {
            remainingSeconds = timerMinutes * 60
        }
        pushSynthBedState()
        restartSessionTicker()
        syncNowPlaying()
        studioVM.synth.triggerFrissonRelease(rootHz: folded, intensity: 0.72)
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playResolutionExhale()
        }
        stats.recordFrissonPeak()
    }

    public func cancelHumResonance() {
        isHumCapturing = false
        studioVM.capturePipeline.cancelRecording()
        humStatusHint = ""
    }

    /// 拒绝麦克风权限或安静环境中无需开口时的零阻断预设人声基频
    public func applyFallbackVoiceRoot(hz: Double, label: String) {
        cancelHumResonance()
        let folded = ResonanceKinematics.foldHumFrequencyToCarrier(hz)
        matchedHumHz = folded
        carrierHz = folded
        washKind = .kilnOvertone
        overtoneWarmth = 0.86
        humStatusHint = "已设为「\(label)」\(Int(folded.rounded())) Hz 共振基频"
        if !isBedPlaying {
            isBedPlaying = true
            if timerMinutes > 0 && (remainingSeconds ?? 0) <= 0 {
                remainingSeconds = timerMinutes * 60
            }
            restartSessionTicker()
        }
        pushSynthBedState()
        syncNowPlaying()
        studioVM.synth.triggerFrissonRelease(rootHz: folded, intensity: 0.65)
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playConsonantGlow(intensity: 0.55)
        }
    }

    // MARK: - Frisson Musical Capsules (精选鸡皮疙瘩乐章胶囊)

    public func toggleCapsule(_ capsule: FrissonCapsule) {
        if activeCapsule?.id == capsule.id && studioVM.isPlaying {
            stopCapsule()
        } else {
            playFrissonCapsule(capsule)
        }
    }

    public func playFrissonCapsule(_ capsule: FrissonCapsule) {
        stopBedPlayback()
        activeCapsule = capsule
        selectedBand = capsule.companionBand
        beatHz = capsule.companionBand.defaultBeatHz
        carrierHz = capsule.companionBand.defaultCarrierHz
        studioVM.openSpecimen(capsule.specimen, autoPlay: true)
        restartSessionTicker()
        syncNowPlaying()
        if hapticsEnabled {
            AcousticHapticsEngine.shared.playSeedBloom()
        }
    }

    public func stopCapsule() {
        activeCapsule = nil
        if studioVM.isPlaying {
            studioVM.stopPlayback()
        }
        if !isBedPlaying {
            sessionTickTask?.cancel()
            sessionTickTask = nil
        }
        syncNowPlaying()
    }

    // MARK: - Internals

    private func bindRemotePlaybackCommands() {
        nowPlaying.bindCommands(
            onPlay: { [weak self] in
                guard let self else { return }
                if !self.isBedPlaying && self.activeCapsule == nil {
                    self.toggleBedPlayback()
                }
            },
            onPause: { [weak self] in
                guard let self else { return }
                if self.activeCapsule != nil {
                    self.stopCapsule()
                }
                if self.isBedPlaying {
                    self.stopBedPlayback()
                }
            },
            onToggle: { [weak self] in
                guard let self else { return }
                if let cap = self.activeCapsule {
                    self.toggleCapsule(cap)
                } else {
                    self.toggleBedPlayback()
                }
            }
        )
    }

    private func syncNowPlaying() {
        let playing = isBedPlaying || (activeCapsule != nil && studioVM.isPlaying)
        let totalDur: Double? = {
            if let cap = activeCapsule {
                return cap.specimen.totalDuration
            }
            return timerMinutes > 0 ? Double(timerMinutes * 60) : nil
        }()
        let elapsed: Double? = {
            if let rem = remainingSeconds, timerMinutes > 0, isBedPlaying {
                return max(0.0, Double(timerMinutes * 60 - rem))
            }
            return nil
        }()
        let hex: UInt32 = {
            switch selectedBand {
            case .delta: return 0x6F54B8
            case .theta: return 0xC4513A
            case .alpha: return 0x3D7A77
            case .gamma: return 0x3577A8
            }
        }()
        nowPlaying.updateNowPlaying(
            title: currentHeadline,
            bandLabel: currentSubline,
            isPlaying: playing,
            durationSeconds: totalDur,
            elapsedSeconds: elapsed,
            accentHex: hex,
            isNight: studioVM.appearance == .nightLamp
        )
    }

    private func pushSynthBedState() {
        studioVM.synth.setBrainwaveBed(
            carrierHz: carrierHz,
            beatHz: beatHz,
            gain: 0.25,
            isochronicDepth: effectiveIsochronicDepth,
            overtoneWarmth: overtoneWarmth,
            noiseGain: noiseGain,
            noiseColor: washKind.noiseColor,
            frissonTension: isHoldingFrisson ? frissonCharge : 0.0
        )
    }

    private func restartSessionTicker() {
        sessionTickTask?.cancel()
        sessionTickTask = Task { @MainActor [weak self] in
            var pulsePhase = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                guard self.isBedPlaying || (self.activeCapsule != nil && self.studioVM.isPlaying) else {
                    break
                }

                self.stats.recordResonanceSeconds(1.0, band: self.selectedBand)

                if self.isBedPlaying && self.hapticsEnabled && (pulsePhase % 4 == 0) {
                    AcousticHapticsEngine.shared.playBrainwavePulse(intensity: 0.26)
                }
                pulsePhase &+= 1

                if self.isBedPlaying, let rem = self.remainingSeconds {
                    if rem <= 1 {
                        self.remainingSeconds = nil
                        self.stats.recordSessionCompleted(band: self.selectedBand)
                        self.stopBedPlayback()
                        break
                    } else {
                        self.remainingSeconds = rem - 1
                    }
                }
            }
        }
    }
}
