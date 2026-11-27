import AVFAudio
import Foundation
import os

/// Real-time acoustic envelope snapshot updated lock-free from audio render callbacks (zero heap allocations).
public struct AcousticEnvelopeSnapshot: Equatable, Sendable {
    public let rmsEnergy: Double
    public let warmthEnergy: Double
    public let shimmerEnergy: Double

    public init(rmsEnergy: Double, warmthEnergy: Double, shimmerEnergy: Double) {
        self.rmsEnergy = rmsEnergy
        self.warmthEnergy = warmthEnergy
        self.shimmerEnergy = shimmerEnergy
    }

    public static let silent = AcousticEnvelopeSnapshot(rmsEnergy: 0.0, warmthEnergy: 0.0, shimmerEnergy: 0.0)
}

public struct OfflineSynthNoteEvent: Sendable {
    public let timeSec: Double
    public let frequency: Double
    public let velocity: Double
    public let decay: Double
    public let brightness: Double
    public let timbre: FeltPianoSynth.Timbre
    public let pan: Double?

    public init(
        timeSec: Double,
        frequency: Double,
        velocity: Double,
        decay: Double,
        brightness: Double,
        timbre: FeltPianoSynth.Timbre,
        pan: Double? = nil
    ) {
        self.timeSec = timeSec
        self.frequency = frequency
        self.velocity = velocity
        self.decay = decay
        self.brightness = brightness
        self.timbre = timbre
        self.pan = pan
    }
}

/// Offline 44-voice physical-modeling chamber synthesizer and dual-bus binaural brainwave engine:
/// - Dry Binaural Bus (`binauralSourceNode -> mainMixerNode`): pure L/R binaural differential isolation with 0% reverb crosstalk.
/// - Wet Chamber Bus (`chamberSourceNode -> AVAudioUnitReverb -> mainMixerNode`): 44-voice instruments, early wood reflections, ambient wash noise, and frisson bloom cascades.
/// All audio engine construction runs asynchronously on a dedicated serial queue without blocking MainActor.
public final class FeltPianoSynth: @unchecked Sendable {

    public enum Timbre: Int, Sendable {
        case feltPiano = 0
        case warmBass = 1
        case celesta = 2
        case singingCello = 3
        case liquidHarp = 4

        public static func from(voice: MelodyVoice) -> Timbre {
            switch voice {
            case .singingCello: return .singingCello
            case .concertPiano: return .feltPiano
            case .liquidHarp: return .liquidHarp
            case .celestaGlass: return .celesta
            }
        }
    }

    private struct Voice: Sendable {
        var active: Bool = false
        var timbre: Timbre = .feltPiano
        var frequency: Double = 440.0
        var phase: Double = 0.0
        var phaseDetune: Double = 0.0
        var hammerPhase: Double = 0.0
        var ageSamples: Double = 0.0
        var delaySamples: Double = 0.0
        var velocity: Double = 0.5
        var decaySeconds: Double = 1.8
        var brightness: Double = 1.0
        var pan: Double = 0.0
    }

    /// Pure dry L/R binaural bus state (never passed through shared reverb or stereo reflection matrices).
    private struct BinauralState: Sendable {
        var sampleRate: Double = 48_000.0
        var active: Bool = false
        var targetGain: Double = 0.0
        var currentGain: Double = 0.0
        var targetCarrierHz: Double = 216.0
        var currentCarrierHz: Double = 216.0
        var targetBeatHz: Double = 10.0
        var currentBeatHz: Double = 10.0
        var targetIsoDepth: Double = 0.14
        var currentIsoDepth: Double = 0.14
        var targetOvertoneWarmth: Double = 0.55
        var currentOvertoneWarmth: Double = 0.55
        var targetFrissonTension: Double = 0.0
        var currentFrissonTension: Double = 0.0

        var phaseL: Double = 0.0
        var phaseR: Double = 0.0
        var phaseSub: Double = 0.0
        var phaseFifthL: Double = 0.0
        var phaseFifthR: Double = 0.0
        var phaseIso: Double = 0.0
        var phaseBreath: Double = 0.0

        var sleepFadeMultiplier: Double = 1.0
        var targetSleepFadeMultiplier: Double = 1.0
        var muteRampGain: Double = 1.0
        var targetMuteRampGain: Double = 1.0

        var envRMS: Double = 0.0
        var envWarmth: Double = 0.0
        var envShimmer: Double = 0.0
        var lpWarmthState: Double = 0.0
        var prevMono: Double = 0.0
    }

    /// Wet chamber bus state: 44-voice instruments, ambient wash noise bed, frisson tension shimmer, and wooden salon reflections.
    private struct ChamberState: Sendable {
        var sampleRate: Double = 48_000.0
        var voices: [Voice]
        var voiceSoftMuteGain: Double = 1.0
        var voiceSoftMuteTarget: Double = 1.0

        var noiseActive: Bool = false
        var targetNoiseGain: Double = 0.0
        var currentNoiseGain: Double = 0.0
        var targetNoiseColor: Double = 0.25
        var currentNoiseColor: Double = 0.25
        var targetFrissonTension: Double = 0.0
        var currentFrissonTension: Double = 0.0
        var targetCarrierHz: Double = 216.0
        var currentCarrierHz: Double = 216.0

        var noiseSeed: UInt64 = 0x9E3779B97F4A7C15
        var brownL: Double = 0.0
        var brownR: Double = 0.0
        var pinkL: Double = 0.0
        var pinkR: Double = 0.0
        var phaseBreath: Double = 0.0
        var phasePan: Double = 0.0
        var phaseSuspL: Double = 0.0
        var phaseSuspR: Double = 0.0
        var phaseSuspHarmL: Double = 0.0
        var phaseSuspHarmR: Double = 0.0

        var sleepFadeMultiplier: Double = 1.0
        var targetSleepFadeMultiplier: Double = 1.0
        var muteRampGain: Double = 1.0
        var targetMuteRampGain: Double = 1.0

        var envRMS: Double = 0.0
        var envWarmth: Double = 0.0
        var envShimmer: Double = 0.0
        var lpWarmthState: Double = 0.0
        var prevMono: Double = 0.0

        var warmthDamping: Double = 1.0
        var stereoSpread: Double = 1.0
        var reverbWetMix: Float = 28.0
        var reflectionBufL: [Double] = Array(repeating: 0.0, count: 2048)
        var reflectionBufR: [Double] = Array(repeating: 0.0, count: 2048)
        var reflectionIdx: Int = 0
        var reflectionLPL: Double = 0.0
        var reflectionLPR: Double = 0.0
    }

    private let router: HalfDuplexAudioRouter
    private let binauralLock: OSAllocatedUnfairLock<BinauralState>
    private let chamberLock: OSAllocatedUnfairLock<ChamberState>
    private let dryTelemetryLock = OSAllocatedUnfairLock<AcousticEnvelopeSnapshot>(initialState: .silent)
    private let wetTelemetryLock = OSAllocatedUnfairLock<AcousticEnvelopeSnapshot>(initialState: .silent)
    private let audioQueue = DispatchQueue(label: "app.chimmo.audio.synth", qos: .userInitiated)
    private let lifecycleLock = NSLock()

    private var _onPlaybackInterruptedBySystem: (@Sendable () -> Void)?
    public var onPlaybackInterruptedBySystem: (@Sendable () -> Void)? {
        get { lifecycleLock.withLock { _onPlaybackInterruptedBySystem } }
        set { lifecycleLock.withLock { _onPlaybackInterruptedBySystem = newValue } }
    }

    private var engine: AVAudioEngine?
    private var reverb: AVAudioUnitReverb?
    private var binauralSourceNode: AVAudioSourceNode?
    private var chamberSourceNode: AVAudioSourceNode?
    private var configuredSampleRate: Double = 0
    private var isStarted: Bool = false
    private var isStarting: Bool = false
    private var isSuspendedForRecording: Bool = false
    private var isAudioInterrupted: Bool = false
    private var observersInstalled: Bool = false
    private var observerTokens: [NSObjectProtocol] = []
    private var engineConfigObserverToken: NSObjectProtocol?
    private var graphGeneration: UInt64 = 0
    private var lifecycleGeneration: UInt64 = 0

    public init(router: HalfDuplexAudioRouter = HalfDuplexAudioRouter()) {
        self.router = router
        self.binauralLock = OSAllocatedUnfairLock(initialState: BinauralState())
        self.chamberLock = OSAllocatedUnfairLock(
            initialState: ChamberState(voices: Array(repeating: Voice(), count: 44))
        )
    }

    deinit {
        let nc = NotificationCenter.default
        for token in observerTokens {
            nc.removeObserver(token)
        }
        if let engToken = engineConfigObserverToken {
            nc.removeObserver(engToken)
        }
    }

    private func hasActiveVoices() -> Bool {
        let dryActive = binauralLock.withLock { st in
            st.active || st.currentGain > 0.0005
        }
        if dryActive { return true }
        return chamberLock.withLock { st in
            st.noiseActive
                || st.currentNoiseGain > 0.0005
                || st.voices.contains(where: { $0.active })
        }
    }

    /// Non-blocking engine bring-up on dedicated serial background queue.
    public func ensureRunning(clearUserInterruption: Bool = false) {
        let shouldStart: Bool = lifecycleLock.withLock {
            if router.currentMode == .recording || isSuspendedForRecording {
                return false
            }
            if clearUserInterruption {
                isAudioInterrupted = false
            }
            guard !isAudioInterrupted else {
                return false
            }
            if isStarted || isStarting {
                return false
            }
            lifecycleGeneration &+= 1
            isStarting = true
            return true
        }
        guard shouldStart else { return }

        binauralLock.withLock { $0.targetMuteRampGain = 1.0 }
        chamberLock.withLock { $0.targetMuteRampGain = 1.0 }
        audioQueue.async { [weak self] in
            self?.startEngineOnQueue()
        }
    }

    public func stopForRecording() {
        let gen: UInt64 = lifecycleLock.withLock {
            isSuspendedForRecording = true
            lifecycleGeneration &+= 1
            return lifecycleGeneration
        }
        binauralLock.withLock { $0.targetMuteRampGain = 0.0 }
        chamberLock.withLock { $0.targetMuteRampGain = 0.0 }
        audioQueue.asyncAfter(deadline: .now() + .milliseconds(18)) { [weak self] in
            guard let self else { return }
            let stillValid = self.lifecycleLock.withLock { self.lifecycleGeneration == gen && self.isSuspendedForRecording }
            guard stillValid else { return }
            self.stopEngineOnQueue()
            self.silenceAll()
        }
    }

    /// Sequentially fades out playback engine and releases audio route before microphone capture begins.
    public func stopForRecordingAsync(_ completion: @escaping @Sendable () -> Void) {
        let gen: UInt64 = lifecycleLock.withLock {
            isSuspendedForRecording = true
            lifecycleGeneration &+= 1
            return lifecycleGeneration
        }
        binauralLock.withLock { $0.targetMuteRampGain = 0.0 }
        chamberLock.withLock { $0.targetMuteRampGain = 0.0 }
        audioQueue.asyncAfter(deadline: .now() + .milliseconds(18)) { [weak self] in
            guard let self else {
                completion()
                return
            }
            let stillValid = self.lifecycleLock.withLock { self.lifecycleGeneration == gen && self.isSuspendedForRecording }
            if stillValid {
                self.stopEngineOnQueue()
                self.silenceAll()
            }
            completion()
        }
    }

    public func resumeAfterRecording() {
        lifecycleLock.withLock {
            isSuspendedForRecording = false
            isAudioInterrupted = false
            lifecycleGeneration &+= 1
        }
        binauralLock.withLock { st in
            st.muteRampGain = 0.0
            st.targetMuteRampGain = 1.0
        }
        chamberLock.withLock { st in
            st.muteRampGain = 0.0
            st.targetMuteRampGain = 1.0
        }
        ensureRunning(clearUserInterruption: true)
    }

    public func stopAndDeactivate() {
        let gen: UInt64 = lifecycleLock.withLock {
            lifecycleGeneration &+= 1
            return lifecycleGeneration
        }
        binauralLock.withLock { $0.targetMuteRampGain = 0.0 }
        chamberLock.withLock { $0.targetMuteRampGain = 0.0 }
        audioQueue.asyncAfter(deadline: .now() + .milliseconds(18)) { [weak self] in
            guard let self else { return }
            let stillValid = self.lifecycleLock.withLock { self.lifecycleGeneration == gen }
            guard stillValid else { return }
            self.silenceAll()
            self.stopEngineOnQueue()
            self.router.deactivate()
        }
    }

    public func setSleepFadeMultiplier(_ multiplier: Double) {
        let clamped = multiplier.isFinite ? max(0.0, min(1.0, multiplier)) : 1.0
        binauralLock.withLock { $0.targetSleepFadeMultiplier = clamped }
        chamberLock.withLock { $0.targetSleepFadeMultiplier = clamped }
    }

    public func currentAcousticEnvelope() -> AcousticEnvelopeSnapshot {
        let dry = dryTelemetryLock.withLockIfAvailable { $0 } ?? .silent
        let wet = wetTelemetryLock.withLockIfAvailable { $0 } ?? .silent
        return AcousticEnvelopeSnapshot(
            rmsEnergy: min(1.0, max(dry.rmsEnergy, wet.rmsEnergy)),
            warmthEnergy: min(1.0, max(dry.warmthEnergy, wet.warmthEnergy)),
            shimmerEnergy: min(1.0, max(dry.shimmerEnergy, wet.shimmerEnergy))
        )
    }

    public func applySpaceProfile(_ profile: AcousticSpaceProfile) {
        let wet = max(12.0, min(46.0, profile.reverbWetMix.isFinite ? profile.reverbWetMix : 28.0))
        let warmth = max(0.65, min(1.30, profile.warmthDamping.isFinite ? profile.warmthDamping : 1.0))
        let spread = max(0.60, min(1.40, profile.stereoSpread.isFinite ? profile.stereoSpread : 1.0))
        chamberLock.withLock { state in
            state.reverbWetMix = wet
            state.warmthDamping = warmth
            state.stereoSpread = spread
        }
        audioQueue.async { [weak self] in
            self?.reverb?.wetDryMix = wet
        }
    }

    public func currentSpaceProfile() -> AcousticSpaceProfile {
        chamberLock.withLock { state in
            AcousticSpaceProfile(
                reverbWetMix: state.reverbWetMix,
                warmthDamping: state.warmthDamping,
                stereoSpread: state.stereoSpread
            )
        }
    }

    /// Softly fades out active 44-voice chamber notes over ~12ms without cutting ambient bed or causing clicks.
    public func softStopChamberVoices() {
        chamberLock.withLock { state in
            if state.voices.contains(where: { $0.active }) {
                state.voiceSoftMuteTarget = 0.0
            }
        }
    }

    public func silenceAll() {
        binauralLock.withLock { st in
            st.active = false
            st.targetGain = 0.0
            st.currentGain = 0.0
            st.targetFrissonTension = 0.0
            st.currentFrissonTension = 0.0
            st.sleepFadeMultiplier = 1.0
            st.targetSleepFadeMultiplier = 1.0
            st.muteRampGain = 1.0
            st.targetMuteRampGain = 1.0
            st.envRMS = 0.0
            st.envWarmth = 0.0
            st.envShimmer = 0.0
            st.lpWarmthState = 0.0
            st.prevMono = 0.0
        }
        chamberLock.withLock { st in
            for i in 0..<st.voices.count {
                st.voices[i].active = false
            }
            st.voiceSoftMuteGain = 1.0
            st.voiceSoftMuteTarget = 1.0
            st.noiseActive = false
            st.targetNoiseGain = 0.0
            st.currentNoiseGain = 0.0
            st.targetFrissonTension = 0.0
            st.currentFrissonTension = 0.0
            st.phaseSuspHarmL = 0.0
            st.phaseSuspHarmR = 0.0
            st.brownL = 0.0
            st.brownR = 0.0
            st.pinkL = 0.0
            st.pinkR = 0.0
            st.sleepFadeMultiplier = 1.0
            st.targetSleepFadeMultiplier = 1.0
            st.muteRampGain = 1.0
            st.targetMuteRampGain = 1.0
            st.envRMS = 0.0
            st.envWarmth = 0.0
            st.envShimmer = 0.0
            st.lpWarmthState = 0.0
            st.prevMono = 0.0
            st.reflectionIdx = 0
            st.reflectionLPL = 0.0
            st.reflectionLPR = 0.0
            for idx in 0..<st.reflectionBufL.count {
                st.reflectionBufL[idx] = 0.0
                st.reflectionBufR[idx] = 0.0
            }
        }
        dryTelemetryLock.withLockIfAvailable { $0 = .silent }
        wetTelemetryLock.withLockIfAvailable { $0 = .silent }
    }

    /// Starts or smoothly updates the dual-bus brainwave acoustic bed (or unmodulated pure wash when `pureWashOnly == true`).
    public func setBrainwaveBed(
        carrierHz: Double,
        beatHz: Double,
        gain: Double = 0.26,
        isochronicDepth: Double = 0.14,
        overtoneWarmth: Double = 0.55,
        noiseGain: Double = 0.08,
        noiseColor: Double = 0.25,
        frissonTension: Double = 0.0,
        pureWashOnly: Bool = false
    ) {
        ensureRunning(clearUserInterruption: true)
        let safeCarrier = carrierHz.isFinite ? max(80.0, min(440.0, carrierHz)) : 216.0
        let safeBeat = beatHz.isFinite ? max(0.5, min(45.0, beatHz)) : 10.0
        let safeGain = (pureWashOnly || !gain.isFinite) ? (pureWashOnly ? 0.0 : 0.26) : max(0.0, min(0.42, gain))
        let safeIso = pureWashOnly ? 0.0 : (isochronicDepth.isFinite ? max(0.0, min(0.45, isochronicDepth)) : 0.14)
        let safeWarmth = pureWashOnly ? 0.0 : (overtoneWarmth.isFinite ? max(0.0, min(1.0, overtoneWarmth)) : 0.55)
        let safeNoiseGain = noiseGain.isFinite ? max(0.0, min(0.24, noiseGain)) : 0.08
        let safeNoiseColor = noiseColor.isFinite ? max(0.0, min(1.0, noiseColor)) : 0.25
        let safeFrisson = frissonTension.isFinite ? max(0.0, min(1.0, frissonTension)) : 0.0

        binauralLock.withLock { st in
            let wantBinaural = !pureWashOnly && safeGain > 0.0001
            let wasStopped = !st.active && st.currentGain < 0.002
            if wasStopped && wantBinaural {
                st.currentCarrierHz = safeCarrier
                st.currentBeatHz = safeBeat
                st.currentIsoDepth = safeIso
                st.currentOvertoneWarmth = safeWarmth
                st.currentFrissonTension = safeFrisson
                st.sleepFadeMultiplier = 1.0
                st.targetSleepFadeMultiplier = 1.0
            }
            st.targetMuteRampGain = 1.0
            st.active = wantBinaural
            st.targetCarrierHz = safeCarrier
            st.targetBeatHz = safeBeat
            st.targetGain = wantBinaural ? safeGain : 0.0
            st.targetIsoDepth = safeIso
            st.targetOvertoneWarmth = safeWarmth
            st.targetFrissonTension = safeFrisson
        }

        chamberLock.withLock { st in
            let wasNoiseStopped = !st.noiseActive && st.currentNoiseGain < 0.002
            if wasNoiseStopped {
                st.currentCarrierHz = safeCarrier
                st.currentNoiseColor = safeNoiseColor
                st.currentFrissonTension = safeFrisson
                st.sleepFadeMultiplier = 1.0
                st.targetSleepFadeMultiplier = 1.0
            }
            st.targetMuteRampGain = 1.0
            st.noiseActive = (safeNoiseGain > 0.0001 || safeFrisson > 0.001)
            st.targetNoiseGain = safeNoiseGain
            st.targetNoiseColor = safeNoiseColor
            st.targetCarrierHz = safeCarrier
            st.targetFrissonTension = safeFrisson
        }
    }

    public func stopBrainwaveBed() {
        binauralLock.withLock { st in
            st.active = false
            st.targetGain = 0.0
            st.targetFrissonTension = 0.0
        }
        chamberLock.withLock { st in
            st.noiseActive = false
            st.targetNoiseGain = 0.0
            st.targetFrissonTension = 0.0
        }
    }

    /// 10 handcrafted kiln click variations with subtle micro-pitch & pan offsets.
    public func playTactileKilnClick(variantIndex: Int, bright: Double = 0.78) {
        ensureRunning(clearUserInterruption: true)
        let baseTable: [Double] = [
            432.0, 456.0, 480.0, 498.0, 520.0,
            444.0, 472.0, 508.0, 540.0, 568.0
        ]
        let decayTable: [Double] = [
            0.062, 0.070, 0.056, 0.078, 0.066,
            0.074, 0.059, 0.082, 0.064, 0.072
        ]
        let panTable: [Double] = [
            -0.14, 0.12, -0.06, 0.18, 0.0,
            -0.18, 0.08, -0.10, 0.15, -0.03
        ]
        let idx = ((variantIndex % baseTable.count) + baseTable.count) % baseTable.count
        let safeBright = bright.isFinite ? max(0.35, min(1.15, bright)) : 0.78

        playNote(
            frequency: baseTable[idx],
            velocity: 0.24,
            decay: decayTable[idx],
            brightness: safeBright,
            timbre: idx.isMultiple(of: 2) ? .liquidHarp : .celesta,
            delaySeconds: 0.0,
            pan: panTable[idx]
        )
    }

    /// Triggers an Acoustic Frisson harmonic cascade across wide-stereo cello, felt piano, harp, and celesta shimmer.
    public func triggerFrissonRelease(rootHz: Double, intensity: Double = 0.85) {
        ensureRunning(clearUserInterruption: true)
        let base = rootHz.isFinite ? max(90.0, min(360.0, rootHz)) : 196.0
        let amp = intensity.isFinite ? max(0.25, min(1.0, intensity)) : 0.85

        binauralLock.withLock { $0.targetFrissonTension = 0.0 }
        chamberLock.withLock { state in
            state.targetFrissonTension = 0.0
            state.voiceSoftMuteGain = 1.0
            state.voiceSoftMuteTarget = 1.0

            Self.enqueueVoice(into: &state, frequency: max(55.0, base * 0.5), velocity: 0.42 * amp, decay: 3.1, brightness: 0.68, timbre: .singingCello, delaySeconds: 0.0, pan: 0.0)
            Self.enqueueVoice(into: &state, frequency: base, velocity: 0.38 * amp, decay: 2.6, brightness: 0.86, timbre: .feltPiano, delaySeconds: 0.015, pan: -0.08)
            Self.enqueueVoice(into: &state, frequency: base * 1.5, velocity: 0.34 * amp, decay: 2.5, brightness: 0.92, timbre: .liquidHarp, delaySeconds: 0.045, pan: -0.34)
            Self.enqueueVoice(into: &state, frequency: base * 2.0, velocity: 0.32 * amp, decay: 2.4, brightness: 0.98, timbre: .feltPiano, delaySeconds: 0.085, pan: 0.34)
            Self.enqueueVoice(into: &state, frequency: min(2400.0, base * 2.5), velocity: 0.28 * amp, decay: 2.3, brightness: 1.06, timbre: .liquidHarp, delaySeconds: 0.135, pan: -0.46)
            Self.enqueueVoice(into: &state, frequency: min(3200.0, base * 3.0), velocity: 0.22 * amp, decay: 2.0, brightness: 1.12, timbre: .celesta, delaySeconds: 0.185, pan: 0.48)
        }
    }

    private static func enqueueVoice(
        into state: inout ChamberState,
        frequency: Double,
        velocity: Double,
        decay: Double,
        brightness: Double,
        timbre: Timbre,
        delaySeconds: Double,
        pan: Double?
    ) {
        guard frequency.isFinite && frequency >= 28.0 && frequency <= 4800.0 else { return }

        state.voiceSoftMuteTarget = 1.0
        if state.voiceSoftMuteGain < 0.99 {
            state.voiceSoftMuteGain = 1.0
        }

        let safeVel = velocity.isFinite ? max(0.03, min(1.0, velocity)) : 0.55
        let safeDecay = decay.isFinite ? max(0.15, min(6.0, decay)) : 1.75
        let safeBright = brightness.isFinite ? max(0.2, min(1.4, brightness)) : 0.95
        let safeDelay = delaySeconds.isFinite ? max(0.0, min(10.0, delaySeconds)) : 0.0

        let resolvedPan = pan.map { max(-0.65, min(0.65, $0.isFinite ? $0 : 0.0)) }
            ?? max(-0.46, min(0.46, log2(max(40.0, frequency) / 261.63) * 0.20))
        let scaledDecay = PitchScaledAcousticEnvelope.scaledDecay(baseDecay: safeDecay, frequency: frequency)
        let absorbedBright = max(0.2, min(1.4, safeBright * PitchScaledAcousticEnvelope.highFrequencyAirAbsorption(frequency: frequency)))

        let delaySamps = max(0.0, safeDelay * state.sampleRate)
        var targetIdx = 0
        var oldestAge = -1.0
        for i in 0..<state.voices.count {
            if !state.voices[i].active {
                targetIdx = i
                break
            }
            if state.voices[i].ageSamples > oldestAge {
                oldestAge = state.voices[i].ageSamples
                targetIdx = i
            }
        }
        state.voices[targetIdx] = Voice(
            active: true,
            timbre: timbre,
            frequency: frequency,
            phase: 0.0,
            phaseDetune: 0.0,
            hammerPhase: 0.0,
            ageSamples: 0.0,
            delaySamples: delaySamps,
            velocity: safeVel,
            decaySeconds: scaledDecay,
            brightness: absorbedBright,
            pan: resolvedPan
        )
    }

    public func playNote(
        frequency: Double,
        velocity: Double = 0.55,
        decay: Double = 1.75,
        brightness: Double = 0.95,
        timbre: Timbre = .feltPiano,
        delaySeconds: Double = 0.0,
        pan: Double? = nil
    ) {
        ensureRunning(clearUserInterruption: true)
        guard frequency.isFinite && frequency >= 28.0 && frequency <= 4800.0 else { return }

        chamberLock.withLock { state in
            Self.enqueueVoice(
                into: &state,
                frequency: frequency,
                velocity: velocity,
                decay: decay,
                brightness: brightness,
                timbre: timbre,
                delaySeconds: delaySeconds,
                pan: pan
            )
        }
    }

    public static func diatonicChordEvents(
        startTime: Double = 0.0,
        rootMIDI: Int,
        mode: ScaleMode,
        chord: DiatonicChord,
        texture: AccompanimentTexture = .swanRipple,
        spanDuration: Double = 1.6,
        intensity: Double = 0.82
    ) -> [OfflineSynthNoteEvent] {
        let clamped = max(0.2, min(1.0, intensity))
        let dur = max(0.75, min(3.8, spanDuration))
        let tones = chord.chordToneDegrees
        let rDeg = chord.rootDegree
        let thirdDeg = tones.count > 1 ? tones[1] : rDeg
        let fifthDeg = tones.count > 2 ? tones[2] : rDeg

        let bassHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: rDeg, octaveOffset: -1)
        let midRootHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: rDeg, octaveOffset: 0)
        let thirdHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: thirdDeg, octaveOffset: thirdDeg < rDeg ? 0 : -1)
        let fifthHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: fifthDeg, octaveOffset: fifthDeg < rDeg ? 0 : -1)

        var out: [OfflineSynthNoteEvent] = []
        switch texture {
        case .swanRipple:
            out.append(OfflineSynthNoteEvent(timeSec: startTime, frequency: bassHz, velocity: 0.25 * clamped, decay: dur * 1.35, brightness: 0.50, timbre: .warmBass, pan: 0.0))
            let pattern: [Double] = [bassHz, fifthHz, midRootHz, thirdHz, midRootHz, fifthHz]
            let harpPans = [-0.28, -0.14, 0.08, 0.28, 0.14, -0.10]
            let stepSec = min(0.24, max(0.11, dur / Double(pattern.count)))
            for (idx, hz) in pattern.enumerated() {
                let vel = (idx == 0 ? 0.16 : (idx == 3 ? 0.19 : 0.14)) * clamped
                out.append(OfflineSynthNoteEvent(
                    timeSec: startTime + Double(idx) * stepSec,
                    frequency: hz,
                    velocity: vel,
                    decay: 1.65,
                    brightness: 0.84,
                    timbre: .liquidHarp,
                    pan: harpPans[idx % harpPans.count]
                ))
            }

        case .feltWaltz:
            out.append(OfflineSynthNoteEvent(timeSec: startTime, frequency: bassHz, velocity: 0.30 * clamped, decay: dur * 1.25, brightness: 0.54, timbre: .warmBass, pan: 0.0))
            let beat = min(0.55, max(0.26, dur / 3.0))
            for beatIdx in 1...2 {
                let t = Double(beatIdx) * beat
                let liftVel = (beatIdx == 1 ? 0.17 : 0.13) * clamped
                out.append(OfflineSynthNoteEvent(timeSec: startTime + t, frequency: fifthHz, velocity: liftVel, decay: 1.35, brightness: 0.76, timbre: .feltPiano, pan: -0.22))
                out.append(OfflineSynthNoteEvent(timeSec: startTime + t + 0.018, frequency: thirdHz, velocity: liftVel * 0.95, decay: 1.35, brightness: 0.80, timbre: .feltPiano, pan: 0.24))
                out.append(OfflineSynthNoteEvent(timeSec: startTime + t + 0.032, frequency: midRootHz, velocity: liftVel * 0.85, decay: 1.35, brightness: 0.82, timbre: .feltPiano, pan: 0.0))
            }

        case .summerGlass:
            let ninthDeg = ((rDeg) % 7) + 1
            let ninthHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: ninthDeg, octaveOffset: 0)
            let sparkleHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: fifthDeg, octaveOffset: 1)
            out.append(OfflineSynthNoteEvent(timeSec: startTime, frequency: bassHz, velocity: 0.24 * clamped, decay: 2.4, brightness: 0.50, timbre: .warmBass, pan: 0.0))
            out.append(OfflineSynthNoteEvent(timeSec: startTime + 0.055, frequency: fifthHz, velocity: 0.18 * clamped, decay: 2.1, brightness: 0.82, timbre: .feltPiano, pan: -0.24))
            out.append(OfflineSynthNoteEvent(timeSec: startTime + 0.13, frequency: ninthHz, velocity: 0.17 * clamped, decay: 2.0, brightness: 0.88, timbre: .feltPiano, pan: 0.18))
            out.append(OfflineSynthNoteEvent(timeSec: startTime + 0.21, frequency: thirdHz, velocity: 0.16 * clamped, decay: 1.9, brightness: 0.86, timbre: .feltPiano, pan: -0.12))
            out.append(OfflineSynthNoteEvent(timeSec: startTime + min(0.52, dur * 0.42), frequency: sparkleHz, velocity: 0.14 * clamped, decay: 1.5, brightness: 1.05, timbre: .celesta, pan: 0.36))

        case .pureChorale:
            out.append(OfflineSynthNoteEvent(timeSec: startTime, frequency: bassHz, velocity: 0.25 * clamped, decay: 2.3, brightness: 0.55, timbre: .warmBass, pan: 0.0))
            let choralePans = [-0.24, 0.0, 0.24]
            for (idx, deg) in tones.enumerated() {
                let oct = (idx > 0 && deg < rDeg) ? 0 : (idx == 0 ? -1 : 0)
                let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
                out.append(OfflineSynthNoteEvent(
                    timeSec: startTime + Double(idx) * 0.025,
                    frequency: hz,
                    velocity: 0.19 * clamped,
                    decay: 2.1,
                    brightness: 0.80,
                    timbre: .feltPiano,
                    pan: choralePans[idx % choralePans.count]
                ))
            }
        }
        return out
    }

    public func playDiatonicChord(
        rootMIDI: Int,
        mode: ScaleMode,
        chord: DiatonicChord,
        texture: AccompanimentTexture = .swanRipple,
        spanDuration: Double = 1.6,
        intensity: Double = 0.82
    ) {
        ensureRunning(clearUserInterruption: true)
        let events = Self.diatonicChordEvents(
            startTime: 0.0,
            rootMIDI: rootMIDI,
            mode: mode,
            chord: chord,
            texture: texture,
            spanDuration: spanDuration,
            intensity: intensity
        )
        chamberLock.withLock { state in
            for ev in events {
                Self.enqueueVoice(
                    into: &state,
                    frequency: ev.frequency,
                    velocity: ev.velocity,
                    decay: ev.decay,
                    brightness: ev.brightness,
                    timbre: ev.timbre,
                    delaySeconds: ev.timeSec,
                    pan: ev.pan
                )
            }
        }
    }

    // MARK: - Background Serial Audio Graph Lifecycle

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        let nc = NotificationCenter.default

        #if os(iOS)
        let inactiveToken = nc.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self else { return }
            let ctx = note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
            // App-initiated deactivation (.app) must NOT poison playback on future launches.
            guard ctx?.source != .app else { return }

            let wasActive = self.hasActiveVoices()
            self.lifecycleLock.withLock {
                self.isAudioInterrupted = true
            }
            self.audioQueue.async { [weak self] in
                guard let self else { return }
                self.silenceAll()
                self.stopEngineOnQueue()
                if wasActive {
                    self.onPlaybackInterruptedBySystem?()
                }
            }
        }
        observerTokens.append(inactiveToken)

        let resumeToken = nc.addObserver(
            forName: AVAudioSession.resumptionRecommendationNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            let recommendation = (note.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext)?.recommendation
            self?.audioQueue.async {
                guard let self else { return }
                let suspended = self.lifecycleLock.withLock { self.isSuspendedForRecording }
                guard !suspended else { return }
                self.lifecycleLock.withLock {
                    self.isAudioInterrupted = false
                    self.isStarted = false
                    self.isStarting = false
                }
                if recommendation == .shouldResume && self.hasActiveVoices() && self.router.currentMode == .playback {
                    self.ensureRunning()
                } else {
                    self.silenceAll()
                    self.stopEngineOnQueue()
                    self.onPlaybackInterruptedBySystem?()
                }
            }
        }
        observerTokens.append(resumeToken)

        let mediaResetToken = nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.audioQueue.async {
                guard let self else { return }
                let wasActive = self.hasActiveVoices()
                self.resetEngineOnQueue()
                self.lifecycleLock.withLock {
                    self.isAudioInterrupted = false
                }
                if wasActive {
                    self.silenceAll()
                    self.onPlaybackInterruptedBySystem?()
                }
            }
        }
        observerTokens.append(mediaResetToken)

        let routeToken = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            let reasonRaw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            let reason = reasonRaw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason == .oldDeviceUnavailable || reason == .newDeviceAvailable else {
                return
            }
            self?.audioQueue.async {
                guard let self else { return }
                if reason == .oldDeviceUnavailable {
                    let wasActive = self.hasActiveVoices()
                    self.silenceAll()
                    self.stopEngineOnQueue()
                    if wasActive {
                        self.onPlaybackInterruptedBySystem?()
                    }
                    return
                }
                let wasRunningOrActive = self.lifecycleLock.withLock { self.isStarted } || self.hasActiveVoices()
                self.resetEngineOnQueue()
                if wasRunningOrActive && self.router.currentMode == .playback {
                    self.ensureRunning()
                }
            }
        }
        observerTokens.append(routeToken)
        #endif
    }

    private func teardownGraphLocked() {
        if let tok = engineConfigObserverToken {
            NotificationCenter.default.removeObserver(tok)
            engineConfigObserverToken = nil
        }
        if let eng = engine {
            if eng.isRunning {
                eng.stop()
            }
            eng.reset()
        }
        engine = nil
        reverb = nil
        binauralSourceNode = nil
        chamberSourceNode = nil
        configuredSampleRate = 0
    }

    private func startEngineOnQueue() {
        installObserversIfNeeded()
        let blocked = lifecycleLock.withLock {
            isSuspendedForRecording || isAudioInterrupted || router.currentMode == .recording
        }
        if blocked {
            lifecycleLock.withLock {
                isStarted = false
                isStarting = false
            }
            return
        }
        do {
            try router.configure(mode: .playback)
            let probeEngine = AVAudioEngine()
            let outSR = probeEngine.outputNode.outputFormat(forBus: 0).sampleRate
            let effectiveSR = (outSR >= 22_050.0 && outSR <= 96_000.0) ? outSR : max(44_100.0, router.hardwareSampleRate)
            binauralLock.withLock { $0.sampleRate = effectiveSR }
            chamberLock.withLock { $0.sampleRate = effectiveSR }

            if engine == nil || abs(configuredSampleRate - effectiveSR) > 1.0 {
                teardownGraphLocked()
                try startGraphOnQueue(sampleRate: effectiveSR)
            } else if let eng = engine, !eng.isRunning {
                eng.prepare()
                try eng.start()
            }

            let running = engine?.isRunning ?? false
            lifecycleLock.withLock {
                isStarted = running
                isStarting = false
            }
        } catch {
            teardownGraphLocked()
            lifecycleLock.withLock {
                isStarted = false
                isStarting = false
            }
        }
    }

    private func stopEngineOnQueue() {
        if let eng = engine, eng.isRunning {
            eng.stop()
        }
        lifecycleLock.withLock {
            isStarted = false
            isStarting = false
        }
    }

    private func resetEngineOnQueue() {
        teardownGraphLocked()
        lifecycleLock.withLock {
            isStarted = false
            isStarting = false
        }
    }

    /// Pure dry L/R binaural bus node: connects directly to mainMixerNode with ZERO reverb crosstalk.
    private func makeBinauralSourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
        let stateLock = binauralLock
        let tLock = dryTelemetryLock
        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)
            guard count > 0, let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let rightPtr = abl.count > 1 ? abl[1].mData?.assumingMemoryBound(to: Float.self) : nil

            let didRender = stateLock.withLockIfAvailable { st -> Bool in
                let sr = max(22_050.0, st.sampleRate)
                let invSR = 1.0 / sr
                let dtNorm = min(2.5, max(0.25, 48_000.0 / sr))
                let twoPi = 2.0 * Double.pi
                let bwGainAlpha = 1.0 - pow(1.0 - 0.0014, dtNorm)
                let bwParamAlpha = 1.0 - pow(1.0 - 0.0022, dtNorm)
                let bwSlowAlpha = 1.0 - pow(1.0 - 0.0018, dtNorm)
                let bwFrissonAlpha = 1.0 - pow(1.0 - 0.0030, dtNorm)
                let muteAlpha = 1.0 - exp(-1.0 / (0.004 * sr))
                let lpWarmAlpha = 1.0 - pow(1.0 - 0.055, dtNorm)

                var sumSq = 0.0
                var sumWarmSq = 0.0
                var sumDiffSq = 0.0
                var lpWarm = st.lpWarmthState
                var prevMono = st.prevMono

                for i in 0..<count {
                    var dryL = 0.0
                    var dryR = 0.0

                    if st.active || st.currentGain > 0.0004 {
                        let gainTarget = st.active ? st.targetGain : 0.0
                        let tensionTarget = st.active ? st.targetFrissonTension : 0.0

                        st.currentGain += (gainTarget - st.currentGain) * bwGainAlpha
                        st.currentCarrierHz += (st.targetCarrierHz - st.currentCarrierHz) * bwParamAlpha
                        st.currentBeatHz += (st.targetBeatHz - st.currentBeatHz) * bwParamAlpha
                        st.currentIsoDepth += (st.targetIsoDepth - st.currentIsoDepth) * bwSlowAlpha
                        st.currentOvertoneWarmth += (st.targetOvertoneWarmth - st.currentOvertoneWarmth) * bwSlowAlpha
                        st.currentFrissonTension += (tensionTarget - st.currentFrissonTension) * bwFrissonAlpha

                        let carrier = st.currentCarrierHz
                        let beat = st.currentBeatHz
                        let hzL = max(40.0, carrier - beat * 0.5)
                        let hzR = max(40.0, carrier + beat * 0.5)
                        let warmth = st.currentOvertoneWarmth
                        let frisson = st.currentFrissonTension

                        let breathEnv = 0.86 + 0.14 * sin(st.phaseBreath)
                        let isoModHz = max(0.5, min(45.0, beat))
                        let isoEnv = 1.0 - st.currentIsoDepth * 0.5 * (1.0 - cos(st.phaseIso))

                        // Keep Left carrier + Left fifth purely on Left; Right carrier + Right fifth purely on Right.
                        let fifthL = sin(st.phaseFifthL) * (0.14 * warmth)
                        let fifthR = sin(st.phaseFifthR) * (0.14 * warmth)
                        let subTerm = sin(st.phaseSub) * (0.18 * warmth)
                        let carrierL = sin(st.phaseL) * 0.62
                        let carrierR = sin(st.phaseR) * 0.62

                        let bwEnv = st.currentGain * breathEnv * isoEnv * (1.0 + frisson * 0.35)
                        dryL = (carrierL + fifthL + subTerm) * bwEnv
                        dryR = (carrierR + fifthR + subTerm) * bwEnv

                        st.phaseL += twoPi * hzL * invSR
                        st.phaseR += twoPi * hzR * invSR
                        st.phaseSub += twoPi * (carrier * 0.5) * invSR
                        st.phaseFifthL += twoPi * (hzL * 1.5) * invSR
                        st.phaseFifthR += twoPi * (hzR * 1.5) * invSR
                        st.phaseIso += twoPi * isoModHz * invSR
                        st.phaseBreath += twoPi * 0.11 * invSR

                        let wrap = twoPi * 1024.0
                        if st.phaseL > wrap { st.phaseL.formTruncatingRemainder(dividingBy: twoPi) }
                        if st.phaseR > wrap { st.phaseR.formTruncatingRemainder(dividingBy: twoPi) }
                        if st.phaseSub > wrap { st.phaseSub.formTruncatingRemainder(dividingBy: twoPi) }
                        if st.phaseFifthL > wrap { st.phaseFifthL.formTruncatingRemainder(dividingBy: twoPi) }
                        if st.phaseFifthR > wrap { st.phaseFifthR.formTruncatingRemainder(dividingBy: twoPi) }
                        if st.phaseIso > wrap { st.phaseIso.formTruncatingRemainder(dividingBy: twoPi) }
                        if st.phaseBreath > wrap { st.phaseBreath.formTruncatingRemainder(dividingBy: twoPi) }
                    }

                    st.muteRampGain += (st.targetMuteRampGain - st.muteRampGain) * muteAlpha
                    st.sleepFadeMultiplier += (st.targetSleepFadeMultiplier - st.sleepFadeMultiplier) * bwGainAlpha
                    let masterGain = max(0.0, min(1.0, st.muteRampGain * st.sleepFadeMultiplier))

                    let outL = tanh(dryL * masterGain * 0.84)
                    let outR = tanh(dryR * masterGain * 0.84)
                    leftPtr[i] = Float(outL)
                    rightPtr?[i] = Float(outR)

                    let mono = (outL + outR) * 0.5
                    sumSq += mono * mono
                    lpWarm += (mono - lpWarm) * lpWarmAlpha
                    sumWarmSq += lpWarm * lpWarm
                    let diff = mono - prevMono
                    prevMono = mono
                    sumDiffSq += diff * diff
                }

                st.lpWarmthState = lpWarm
                st.prevMono = prevMono
                let invN = 1.0 / Double(max(1, count))
                let rawRMS = min(1.0, sqrt(sumSq * invN) * 2.8)
                let rawWarm = min(1.0, sqrt(sumWarmSq * invN) * 3.1)
                let rawShim = min(1.0, sqrt(sumDiffSq * invN) * 14.0)
                let rmsRiseAlpha = 1.0 - pow(1.0 - 0.38, dtNorm)
                let rmsFallAlpha = 1.0 - pow(1.0 - 0.14, dtNorm)
                st.envRMS += (rawRMS - st.envRMS) * (rawRMS > st.envRMS ? rmsRiseAlpha : rmsFallAlpha)
                st.envWarmth += (rawWarm - st.envWarmth) * (rawWarm > st.envWarmth ? rmsRiseAlpha : rmsFallAlpha)
                st.envShimmer += (rawShim - st.envShimmer) * (rawShim > st.envShimmer ? rmsRiseAlpha : rmsFallAlpha)
                let snap = AcousticEnvelopeSnapshot(
                    rmsEnergy: max(0.0, min(1.0, st.envRMS)),
                    warmthEnergy: max(0.0, min(1.0, st.envWarmth)),
                    shimmerEnergy: max(0.0, min(1.0, st.envShimmer))
                )
                tLock.withLockIfAvailable { $0 = snap }
                return true
            }

            if didRender != true {
                for i in 0..<count {
                    leftPtr[i] = 0
                    rightPtr?[i] = 0
                }
            }
            return noErr
        }
    }

    /// Wet chamber & ambient wash bus node routed through hall reverb.
    private func makeChamberSourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
        let stateLock = chamberLock
        let tLock = wetTelemetryLock
        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)
            guard count > 0, let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let rightPtr = abl.count > 1 ? abl[1].mData?.assumingMemoryBound(to: Float.self) : nil

            let didRender = stateLock.withLockIfAvailable { state -> Bool in
                let sr = max(22_050.0, state.sampleRate)
                let invSR = 1.0 / sr
                let dtNorm = min(2.5, max(0.25, 48_000.0 / sr))
                let twoPi = 2.0 * Double.pi
                let bwGainAlpha = 1.0 - pow(1.0 - 0.0014, dtNorm)
                let bwParamAlpha = 1.0 - pow(1.0 - 0.0022, dtNorm)
                let bwSlowAlpha = 1.0 - pow(1.0 - 0.0018, dtNorm)
                let bwFrissonAlpha = 1.0 - pow(1.0 - 0.0030, dtNorm)
                let muteAlpha = 1.0 - exp(-1.0 / (0.004 * sr))
                let voiceSoftAlpha = 1.0 - exp(-1.0 / (0.008 * sr))
                let brownDecay = pow(0.991, dtNorm)
                let pinkDecay = pow(0.92, dtNorm)
                let reflAlpha = 1.0 - pow(1.0 - 0.28, dtNorm)
                let lpWarmAlpha = 1.0 - pow(1.0 - 0.055, dtNorm)

                var sumSq = 0.0
                var sumWarmSq = 0.0
                var sumDiffSq = 0.0
                var lpWarm = state.lpWarmthState
                var prevMono = state.prevMono
                let refCap = state.reflectionBufL.count
                let refDelayL = min(refCap - 2, max(64, Int(0.011 * sr)))
                let refDelayR = min(refCap - 2, max(96, Int(0.017 * sr)))
                let refGain = 0.085 * max(0.7, min(1.3, Double(state.reverbWetMix) / 28.0))

                for i in 0..<count {
                    var voiceMixL = 0.0
                    var voiceMixR = 0.0
                    var washMixL = 0.0
                    var washMixR = 0.0

                    state.voiceSoftMuteGain += (state.voiceSoftMuteTarget - state.voiceSoftMuteGain) * voiceSoftAlpha
                    if state.voiceSoftMuteTarget == 0.0 && state.voiceSoftMuteGain < 0.001 {
                        for vIdx in 0..<state.voices.count {
                            state.voices[vIdx].active = false
                        }
                        state.voiceSoftMuteGain = 1.0
                        state.voiceSoftMuteTarget = 1.0
                    }

                    // 1. 44-voice physical-modeling chamber instruments
                    for vIdx in 0..<state.voices.count {
                        if !state.voices[vIdx].active { continue }

                        if state.voices[vIdx].delaySamples > 0 {
                            state.voices[vIdx].delaySamples -= 1.0
                            continue
                        }

                        let age = state.voices[vIdx].ageSamples
                        let ageSec = age * invSR
                        let decay = state.voices[vIdx].decaySeconds
                        if ageSec > decay * 2.4 {
                            state.voices[vIdx].active = false
                            continue
                        }

                        let ph = state.voices[vIdx].phase
                        let phD = state.voices[vIdx].phaseDetune
                        let vel = state.voices[vIdx].velocity
                        let freq = state.voices[vIdx].frequency
                        var sample = 0.0
                        var stereoSplit = 0.0
                        var instFreq = freq

                        switch state.voices[vIdx].timbre {
                        case .feltPiano:
                            let attack = min(1.0, age / (0.008 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.58))
                            let env = attack * bodyDecay * vel
                            let effBright = max(0.18, min(1.5, state.voices[vIdx].brightness * state.warmthDamping))
                            let bright = exp(-ageSec * 3.1) * effBright * (0.72 + 0.38 * vel)
                            let hammerThump = exp(-ageSec * 135.0) * 0.11 * sin(state.voices[vIdx].hammerPhase * 0.65)
                            let strA = sin(ph)
                            let strB = sin(phD)
                            stereoSplit = (strA - strB) * 0.14 * env
                            sample = (
                                (strA + strB) * 0.36 +
                                sin(ph * 2.001) * (0.21 * (0.35 + 0.65 * bright)) +
                                sin(ph * 3.003) * (0.08 * bright) +
                                sin(ph * 4.006) * (0.032 * bright * bright) +
                                hammerThump
                            ) * env

                        case .singingCello:
                            let attack = min(1.0, age / (0.052 * sr))
                            let sustainPhase = min(1.0, ageSec / max(0.25, decay))
                            let release = sustainPhase < 0.72
                                ? (1.0 - sustainPhase * 0.18)
                                : max(0.0, 0.87 * exp(-(ageSec - decay * 0.72) / max(0.18, decay * 0.44)))
                            let env = attack * release * vel * 0.94
                            let scoop = -0.006 * exp(-ageSec * 22.0)
                            let vibDepth = min(1.0, max(0.0, (ageSec - 0.14) / 0.30)) * 0.0056
                            let vib = vibDepth * (0.78 * sin(twoPi * 5.05 * ageSec) + 0.22 * sin(twoPi * 3.1 * ageSec))
                            instFreq = freq * (1.0 + scoop + vib)
                            let bowBloom = exp(-ageSec / 0.048) * 0.12
                            let bowWarmth = 0.68 + 0.32 * sin(min(Double.pi, ageSec * 2.1))
                            sample = (
                                sin(ph) * (0.53 + bowBloom * 0.4) +
                                sin(ph * 2.0) * (0.27 * bowWarmth) +
                                sin(ph * 3.0) * (0.14 * bowWarmth + bowBloom * 0.3) +
                                sin(ph * 4.0) * 0.058 +
                                sin(ph * 5.0) * 0.028
                            ) * env

                        case .liquidHarp:
                            let attack = min(1.0, age / (0.0035 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.50))
                            let env = attack * bodyDecay * vel
                            let effBright = max(0.18, min(1.5, state.voices[vIdx].brightness * state.warmthDamping))
                            let shimmer = exp(-ageSec * 4.5) * effBright
                            let pluckTransient = exp(-ageSec * 85.0) * 0.09 * sin(ph * 3.0)
                            stereoSplit = sin(ph * 2.0) * 0.08 * shimmer * env
                            sample = (
                                sin(ph) * 0.62 +
                                sin(ph * 2.0) * (0.25 * (0.32 + 0.68 * shimmer)) +
                                sin(ph * 3.0) * (0.095 * shimmer) +
                                sin(ph * 4.0) * (0.035 * shimmer * shimmer) +
                                pluckTransient
                            ) * env

                        case .warmBass:
                            let attack = min(1.0, age / (0.026 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.74))
                            let env = attack * bodyDecay * vel
                            let pluckBody = exp(-ageSec * 26.0) * 0.12 * sin(ph * 2.0)
                            let sub = sin(ph * 0.5) * 0.26
                            sample = (
                                sub +
                                sin(ph) * 0.60 +
                                sin(ph * 2.0) * 0.19 * exp(-ageSec * 1.7) +
                                sin(ph * 3.0) * 0.065 * exp(-ageSec * 2.6) +
                                pluckBody
                            ) * env

                        case .celesta:
                            let attack = min(1.0, age / (0.0025 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.44))
                            let env = attack * bodyDecay * vel
                            let pinTick = exp(-ageSec * 360.0) * 0.09 * sin(ph * 5.2)
                            sample = (
                                sin(ph) * 0.63 +
                                sin(ph * 2.0) * 0.21 * exp(-ageSec * 3.8) +
                                sin(ph * 2.756) * 0.12 * exp(-ageSec * 6.8) +
                                sin(ph * 3.98) * 0.075 * exp(-ageSec * 9.5) +
                                pinTick
                            ) * env
                        }

                        let pan = max(-0.68, min(0.68, state.voices[vIdx].pan * state.stereoSpread))
                        let split = stereoSplit * state.stereoSpread
                        voiceMixL += (sample * (0.5 - pan * 0.5) - split) * state.voiceSoftMuteGain
                        voiceMixR += (sample * (0.5 + pan * 0.5) + split) * state.voiceSoftMuteGain

                        let step = twoPi * instFreq * invSR
                        state.voices[vIdx].phase += step
                        state.voices[vIdx].phaseDetune += step * 1.00058
                        state.voices[vIdx].hammerPhase += step * 7.3
                        state.voices[vIdx].ageSamples += 1.0
                    }

                    // 2. Ambient noise wash & frisson suspension shimmer (isolated on chamber bus)
                    if state.noiseActive || state.currentNoiseGain > 0.0004 || state.currentFrissonTension > 0.001 {
                        let noiseTarget = state.noiseActive ? state.targetNoiseGain : 0.0
                        let tensionTarget = state.noiseActive ? state.targetFrissonTension : 0.0
                        state.currentNoiseGain += (noiseTarget - state.currentNoiseGain) * bwGainAlpha
                        state.currentNoiseColor += (state.targetNoiseColor - state.currentNoiseColor) * bwSlowAlpha
                        state.currentCarrierHz += (state.targetCarrierHz - state.currentCarrierHz) * bwParamAlpha
                        state.currentFrissonTension += (tensionTarget - state.currentFrissonTension) * bwFrissonAlpha

                        let panShift = 0.14 * sin(state.phasePan)
                        let frisson = state.currentFrissonTension
                        if frisson > 0.001 {
                            let suspL = (sin(state.phaseSuspL) * 0.55 + sin(state.phaseSuspHarmL) * 0.45) * 0.10 * frisson
                            let suspR = (sin(state.phaseSuspR) * 0.55 + sin(state.phaseSuspHarmR) * 0.45) * 0.10 * frisson
                            washMixL += suspL
                            washMixR += suspR
                        }

                        if state.currentNoiseGain > 0.0004 {
                            var s = state.noiseSeed
                            s ^= s << 13
                            s ^= s >> 7
                            s ^= s << 17
                            let wA = (Double(s >> 11) * (1.0 / 9007199254740992.0)) * 2.0 - 1.0
                            s ^= s << 13
                            s ^= s >> 7
                            s ^= s << 17
                            let wB = (Double(s >> 11) * (1.0 / 9007199254740992.0)) * 2.0 - 1.0
                            state.noiseSeed = (s == 0) ? 0x9E3779B97F4A7C15 : s

                            state.brownL = max(-0.8, min(0.8, state.brownL * brownDecay + wA * 0.052 * sqrt(dtNorm)))
                            state.brownR = max(-0.8, min(0.8, state.brownR * brownDecay + wB * 0.052 * sqrt(dtNorm)))
                            state.pinkL = max(-0.8, min(0.8, state.pinkL * pinkDecay + wA * 0.14 * sqrt(dtNorm)))
                            state.pinkR = max(-0.8, min(0.8, state.pinkR * pinkDecay + wB * 0.14 * sqrt(dtNorm)))

                            let c = state.currentNoiseColor
                            let colL = state.brownL * (1.0 - c) + state.pinkL * c
                            let colR = state.brownR * (1.0 - c) + state.pinkR * c
                            let nGain = state.currentNoiseGain * (0.90 + 0.10 * sin(state.phaseBreath))
                            washMixL += colL * nGain * (1.0 - panShift)
                            washMixR += colR * nGain * (1.0 + panShift)
                        }

                        let carrier = state.currentCarrierHz
                        state.phaseBreath += twoPi * 0.11 * invSR
                        state.phaseSuspL += twoPi * (carrier * 1.125) * invSR
                        state.phaseSuspR += twoPi * (carrier * 1.125 + 1.4) * invSR
                        state.phaseSuspHarmL += twoPi * (carrier * 1.125 * 1.185) * invSR
                        state.phaseSuspHarmR += twoPi * ((carrier * 1.125 + 1.4) * 1.185) * invSR
                        state.phasePan += twoPi * 0.065 * invSR

                        let wrap = twoPi * 1024.0
                        if state.phaseBreath > wrap { state.phaseBreath.formTruncatingRemainder(dividingBy: twoPi) }
                        if state.phaseSuspL > wrap { state.phaseSuspL.formTruncatingRemainder(dividingBy: twoPi) }
                        if state.phaseSuspR > wrap { state.phaseSuspR.formTruncatingRemainder(dividingBy: twoPi) }
                        if state.phaseSuspHarmL > wrap { state.phaseSuspHarmL.formTruncatingRemainder(dividingBy: twoPi) }
                        if state.phaseSuspHarmR > wrap { state.phaseSuspHarmR.formTruncatingRemainder(dividingBy: twoPi) }
                        if state.phasePan > wrap { state.phasePan.formTruncatingRemainder(dividingBy: twoPi) }
                    }

                    // 3. Wooden salon early reflections (chamber voices & ambient noise only)
                    let mixL = voiceMixL + washMixL
                    let mixR = voiceMixR + washMixR
                    let wIdx = state.reflectionIdx
                    let rL = (wIdx + refCap - refDelayL) % refCap
                    let rR = (wIdx + refCap - refDelayR) % refCap
                    state.reflectionLPL += (state.reflectionBufL[rL] - state.reflectionLPL) * reflAlpha
                    state.reflectionLPR += (state.reflectionBufR[rR] - state.reflectionLPR) * reflAlpha
                    state.reflectionBufL[wIdx] = mixL
                    state.reflectionBufR[wIdx] = mixR
                    state.reflectionIdx = (wIdx + 1) % refCap

                    state.muteRampGain += (state.targetMuteRampGain - state.muteRampGain) * muteAlpha
                    state.sleepFadeMultiplier += (state.targetSleepFadeMultiplier - state.sleepFadeMultiplier) * bwGainAlpha
                    let masterGain = max(0.0, min(1.0, state.muteRampGain * state.sleepFadeMultiplier))

                    let spatialL = (mixL + state.reflectionLPR * refGain) * masterGain
                    let spatialR = (mixR + state.reflectionLPL * refGain) * masterGain
                    let outL = tanh(spatialL * 0.84)
                    let outR = tanh(spatialR * 0.84)
                    leftPtr[i] = Float(outL)
                    rightPtr?[i] = Float(outR)

                    let mono = (outL + outR) * 0.5
                    sumSq += mono * mono
                    lpWarm += (mono - lpWarm) * lpWarmAlpha
                    sumWarmSq += lpWarm * lpWarm
                    let diff = mono - prevMono
                    prevMono = mono
                    sumDiffSq += diff * diff
                }

                state.lpWarmthState = lpWarm
                state.prevMono = prevMono
                let invN = 1.0 / Double(max(1, count))
                let rawRMS = min(1.0, sqrt(sumSq * invN) * 2.8)
                let rawWarm = min(1.0, sqrt(sumWarmSq * invN) * 3.1)
                let rawShim = min(1.0, sqrt(sumDiffSq * invN) * 14.0)
                let rmsRiseAlpha = 1.0 - pow(1.0 - 0.38, dtNorm)
                let rmsFallAlpha = 1.0 - pow(1.0 - 0.14, dtNorm)
                state.envRMS += (rawRMS - state.envRMS) * (rawRMS > state.envRMS ? rmsRiseAlpha : rmsFallAlpha)
                state.envWarmth += (rawWarm - state.envWarmth) * (rawWarm > state.envWarmth ? rmsRiseAlpha : rmsFallAlpha)
                state.envShimmer += (rawShim - state.envShimmer) * (rawShim > state.envShimmer ? rmsRiseAlpha : rmsFallAlpha)
                let snap = AcousticEnvelopeSnapshot(
                    rmsEnergy: max(0.0, min(1.0, state.envRMS)),
                    warmthEnergy: max(0.0, min(1.0, state.envWarmth)),
                    shimmerEnergy: max(0.0, min(1.0, state.envShimmer))
                )
                tLock.withLockIfAvailable { $0 = snap }
                return true
            }

            if didRender != true {
                for i in 0..<count {
                    leftPtr[i] = 0
                    rightPtr?[i] = 0
                }
            }
            return noErr
        }
    }

    private func attachConfigObserver(for eng: AVAudioEngine, generation: UInt64) {
        if let existing = engineConfigObserverToken {
            NotificationCenter.default.removeObserver(existing)
            engineConfigObserverToken = nil
        }
        engineConfigObserverToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: eng,
            queue: nil
        ) { [weak self] _ in
            self?.audioQueue.async {
                guard let self, self.graphGeneration == generation else { return }
                let hadVoices = self.hasActiveVoices()
                self.resetEngineOnQueue()
                if hadVoices && self.router.currentMode == .playback {
                    self.ensureRunning()
                }
            }
        }
    }

    private func startGraphOnQueue(sampleRate: Double) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return
        }

        // Parallel audio topology:
        //   binauralSourceNode -> mainMixerNode (0% reverb crosstalk)
        //   chamberSourceNode  -> AVAudioUnitReverb (.mediumHall2) -> mainMixerNode
        let initialWet = chamberLock.withLock { $0.reverbWetMix }
        do {
            let eng = AVAudioEngine()
            let dryNode = makeBinauralSourceNode(format: format)
            let wetNode = makeChamberSourceNode(format: format)
            let rev = AVAudioUnitReverb()
            rev.loadFactoryPreset(.mediumHall2)
            rev.wetDryMix = initialWet

            let mixer = eng.mainMixerNode
            mixer.outputVolume = 1.0

            eng.attach(dryNode)
            eng.attach(wetNode)
            eng.attach(rev)
            try eng.connectNode(dryNode, to: mixer, format: format)
            try eng.connectNode(wetNode, to: rev, format: format)
            try eng.connectNode(rev, to: mixer, format: format)

            eng.prepare()
            try eng.start()

            graphGeneration &+= 1
            attachConfigObserver(for: eng, generation: graphGeneration)
            self.engine = eng
            self.reverb = rev
            self.binauralSourceNode = dryNode
            self.chamberSourceNode = wetNode
            self.configuredSampleRate = sampleRate
        } catch {
            let eng = AVAudioEngine()
            let dryNode = makeBinauralSourceNode(format: format)
            let wetNode = makeChamberSourceNode(format: format)
            let mixer = eng.mainMixerNode
            mixer.outputVolume = 1.0

            eng.attach(dryNode)
            eng.attach(wetNode)
            try eng.connectNode(dryNode, to: mixer, format: format)
            try eng.connectNode(wetNode, to: mixer, format: format)

            eng.prepare()
            try eng.start()

            graphGeneration &+= 1
            attachConfigObserver(for: eng, generation: graphGeneration)
            self.engine = eng
            self.reverb = nil
            self.binauralSourceNode = dryNode
            self.chamberSourceNode = wetNode
            self.configuredSampleRate = sampleRate
        }
    }

    // MARK: - Offline Signal Verification & Telemetry API (Zero Hardware Permissions Needed)

    public func verifyOfflineRenderPeak(
        sampleRate: Double = 48_000.0,
        frequency: Double = 440.0,
        timbre: Timbre = .feltPiano
    ) throws -> (peak: Float, reverbInRate: Double, reverbOutRate: Double) {
        let res = try verifyOfflineRenderTelemetry(sampleRate: sampleRate, frequency: frequency, timbre: timbre)
        return (res.peak, res.reverbInRate, res.reverbOutRate)
    }

    public func verifyOfflineRenderTelemetry(
        sampleRate: Double = 48_000.0,
        frequency: Double = 440.0,
        timbre: Timbre = .feltPiano
    ) throws -> (
        peak: Float,
        reverbInRate: Double,
        reverbOutRate: Double,
        envelopeDuringRender: AcousticEnvelopeSnapshot,
        envelopeAfterSilence: AcousticEnvelopeSnapshot
    ) {
        let res = try runOfflineDualBusRender(sampleRate: sampleRate, blocks: 12, blockSize: 512) { _, chamber in
            chamber.voices[0] = Voice(
                active: true,
                timbre: timbre,
                frequency: frequency,
                phase: 0.0,
                phaseDetune: 0.0,
                hammerPhase: 0.0,
                ageSamples: 0.0,
                delaySamples: 0.0,
                velocity: 0.72,
                decaySeconds: 1.2,
                brightness: 0.95
            )
        }
        return (res.peak, res.reverbInRate, res.reverbOutRate, res.envelopeDuringRender, res.envelopeAfterSilence)
    }

    public func verifyBrainwaveOfflineTelemetry(
        sampleRate: Double = 48_000.0,
        carrierHz: Double = 216.0,
        beatHz: Double = 10.0,
        noiseGain: Double = 0.08
    ) throws -> (
        peakL: Float,
        peakR: Float,
        lrDifference: Float,
        duringEnvelope: AcousticEnvelopeSnapshot,
        afterStopEnvelope: AcousticEnvelopeSnapshot
    ) {
        let safeCarrier = max(80.0, min(440.0, carrierHz.isFinite ? carrierHz : 216.0))
        let safeBeat = max(0.5, min(45.0, beatHz.isFinite ? beatHz : 10.0))
        let safeNoise = max(0.0, min(0.24, noiseGain.isFinite ? noiseGain : 0.08))
        let res = try runOfflineDualBusRender(sampleRate: sampleRate, blocks: 12, blockSize: 512) { dry, wet in
            dry.active = true
            dry.currentCarrierHz = safeCarrier
            dry.targetCarrierHz = safeCarrier
            dry.currentBeatHz = safeBeat
            dry.targetBeatHz = safeBeat
            dry.currentGain = 0.26
            dry.targetGain = 0.26
            dry.currentOvertoneWarmth = 0.55
            dry.targetOvertoneWarmth = 0.55
            dry.currentIsoDepth = 0.12
            dry.targetIsoDepth = 0.12

            wet.noiseActive = (safeNoise > 0.0001)
            wet.currentNoiseGain = safeNoise
            wet.targetNoiseGain = safeNoise
            wet.currentCarrierHz = safeCarrier
            wet.targetCarrierHz = safeCarrier
        }
        return (res.peakL, res.peakR, res.lrSampleMaxDiff, res.envelopeDuringRender, res.envelopeAfterSilence)
    }

    public func verifyFrissonReleaseOfflineTelemetry(
        sampleRate: Double = 48_000.0,
        rootHz: Double = 196.0,
        intensity: Double = 0.88
    ) throws -> (peak: Float, duringEnvelope: AcousticEnvelopeSnapshot, afterStopEnvelope: AcousticEnvelopeSnapshot) {
        let base = rootHz.isFinite ? max(90.0, min(360.0, rootHz)) : 196.0
        let amp = intensity.isFinite ? max(0.25, min(1.0, intensity)) : 0.88
        let res = try runOfflineDualBusRender(sampleRate: sampleRate, blocks: 12, blockSize: 512) { _, chamber in
            Self.enqueueVoice(into: &chamber, frequency: max(55.0, base * 0.5), velocity: 0.42 * amp, decay: 3.1, brightness: 0.68, timbre: .singingCello, delaySeconds: 0.0, pan: 0.0)
            Self.enqueueVoice(into: &chamber, frequency: base, velocity: 0.38 * amp, decay: 2.6, brightness: 0.86, timbre: .feltPiano, delaySeconds: 0.005, pan: -0.08)
            Self.enqueueVoice(into: &chamber, frequency: base * 1.5, velocity: 0.34 * amp, decay: 2.5, brightness: 0.92, timbre: .liquidHarp, delaySeconds: 0.012, pan: -0.34)
        }
        return (res.peak, res.envelopeDuringRender, res.envelopeAfterSilence)
    }

    /// True single-channel AM depth measurement: measures Left channel block RMS spread with `isochronicDepth = 0.38` vs `0.0` (zero noise).
    public func verifySingleChannelIsochronicDepth(
        sampleRate: Double = 48_000.0,
        carrierHz: Double = 220.0,
        beatHz: Double = 40.0,
        isochronicDepth: Double
    ) throws -> (minLeftBlockRMS: Float, maxLeftBlockRMS: Float) {
        let res = try runOfflineDualBusRender(sampleRate: sampleRate, blocks: 64, blockSize: 150) { dry, _ in
            dry.active = true
            dry.currentCarrierHz = carrierHz
            dry.targetCarrierHz = carrierHz
            dry.currentBeatHz = beatHz
            dry.targetBeatHz = beatHz
            dry.currentGain = 0.28
            dry.targetGain = 0.28
            dry.currentIsoDepth = isochronicDepth
            dry.targetIsoDepth = isochronicDepth
            dry.currentOvertoneWarmth = 0.0
            dry.targetOvertoneWarmth = 0.0
        }
        return (res.minLeftBlockRMS, res.maxLeftBlockRMS)
    }

    /// Captures exact L/R PCM samples through the live dual-bus graph (dry binaural -> mixer; wet chamber -> reverb -> mixer) for spectral L/R isolation verification.
    public func renderDualBusOfflineSamples(
        sampleRate: Double = 48_000.0,
        frameCount: Int = 24_000,
        carrierHz: Double = 200.0,
        beatHz: Double = 10.0,
        gain: Double = 0.28,
        isochronicDepth: Double = 0.0,
        overtoneWarmth: Double = 0.0,
        noiseGain: Double = 0.0,
        pureWashOnly: Bool = false
    ) throws -> (left: [Float], right: [Float]) {
        let blockSize = 512
        let blocks = max(1, (frameCount + blockSize - 1) / blockSize)
        var capturedL: [Float] = []
        var capturedR: [Float] = []
        capturedL.reserveCapacity(blocks * blockSize)
        capturedR.reserveCapacity(blocks * blockSize)

        _ = try runOfflineDualBusRender(
            sampleRate: sampleRate,
            blocks: blocks,
            blockSize: blockSize,
            onBlock: { leftSlice, rightSlice in
                capturedL.append(contentsOf: leftSlice)
                capturedR.append(contentsOf: rightSlice)
            }
        ) { dry, wet in
            dry.active = !pureWashOnly && gain > 0.0001
            dry.currentCarrierHz = carrierHz
            dry.targetCarrierHz = carrierHz
            dry.currentBeatHz = beatHz
            dry.targetBeatHz = beatHz
            dry.currentGain = pureWashOnly ? 0.0 : gain
            dry.targetGain = pureWashOnly ? 0.0 : gain
            dry.currentIsoDepth = isochronicDepth
            dry.targetIsoDepth = isochronicDepth
            dry.currentOvertoneWarmth = overtoneWarmth
            dry.targetOvertoneWarmth = overtoneWarmth

            wet.noiseActive = noiseGain > 0.0001
            wet.currentNoiseGain = noiseGain
            wet.targetNoiseGain = noiseGain
            wet.currentCarrierHz = carrierHz
            wet.targetCarrierHz = carrierHz
        }

        return (Array(capturedL.prefix(frameCount)), Array(capturedR.prefix(frameCount)))
    }

    public func verifySpatialPanOfflineTelemetry(
        sampleRate: Double = 48_000.0,
        frequency: Double = 440.0,
        pan: Double,
        spaceProfile: AcousticSpaceProfile? = nil
    ) throws -> (
        peakL: Float,
        peakR: Float,
        reverbInRate: Double,
        reverbOutRate: Double
    ) {
        if let profile = spaceProfile {
            applySpaceProfile(profile)
        }
        let clampedPan = max(-0.65, min(0.65, pan.isFinite ? pan : 0.0))
        let res = try runOfflineDualBusRender(sampleRate: sampleRate, blocks: 12, blockSize: 512) { _, chamber in
            chamber.voices[0] = Voice(
                active: true,
                timbre: .feltPiano,
                frequency: frequency,
                phase: 0.0,
                phaseDetune: 0.0,
                hammerPhase: 0.0,
                ageSamples: 0.0,
                delaySamples: 0.0,
                velocity: 0.78,
                decaySeconds: 1.2,
                brightness: 0.95,
                pan: clampedPan
            )
        }
        return (res.peakL, res.peakR, res.reverbInRate, res.reverbOutRate)
    }

    private func runOfflineDualBusRender(
        sampleRate: Double,
        blocks: Int,
        blockSize: Int,
        onBlock: ((_ left: UnsafeBufferPointer<Float>, _ right: UnsafeBufferPointer<Float>) -> Void)? = nil,
        configureAudioState: (inout BinauralState, inout ChamberState) -> Void
    ) throws -> (
        peak: Float,
        peakL: Float,
        peakR: Float,
        lrSampleMaxDiff: Float,
        minLeftBlockRMS: Float,
        maxLeftBlockRMS: Float,
        reverbInRate: Double,
        reverbOutRate: Double,
        envelopeDuringRender: AcousticEnvelopeSnapshot,
        envelopeAfterSilence: AcousticEnvelopeSnapshot
    ) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw NSError(domain: "app.chimmo.synth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }

        audioQueue.sync {
            stopEngineOnQueue()
        }
        silenceAll()

        var drySnapshot = BinauralState()
        drySnapshot.sampleRate = sampleRate
        var wetSnapshot = ChamberState(voices: Array(repeating: Voice(), count: 44))
        wetSnapshot.sampleRate = sampleRate
        configureAudioState(&drySnapshot, &wetSnapshot)

        let configuredWetMix: Float = wetSnapshot.reverbWetMix
        let dryPrepared = drySnapshot
        let wetPrepared = wetSnapshot
        binauralLock.withLock { $0 = dryPrepared }
        chamberLock.withLock { $0 = wetPrepared }

        let eng = AVAudioEngine()
        let dryNode = makeBinauralSourceNode(format: format)
        let wetNode = makeChamberSourceNode(format: format)
        let rev = AVAudioUnitReverb()
        rev.loadFactoryPreset(.mediumHall2)
        rev.wetDryMix = configuredWetMix
        let mixer = eng.mainMixerNode
        mixer.outputVolume = 1.0

        eng.attach(dryNode)
        eng.attach(wetNode)
        eng.attach(rev)
        try eng.connectNode(dryNode, to: mixer, format: format)
        try eng.connectNode(wetNode, to: rev, format: format)
        try eng.connectNode(rev, to: mixer, format: format)

        try eng.enableManualRenderingMode(.offline, format: format, maximumFrameCount: AVAudioFrameCount(blockSize))
        try eng.start()

        let inRate = rev.inputFormat(forBus: 0).sampleRate
        let outRate = rev.outputFormat(forBus: 0).sampleRate

        guard let buffer = AVAudioPCMBuffer(pcmFormat: eng.manualRenderingFormat, frameCapacity: AVAudioFrameCount(blockSize)) else {
            eng.stop()
            throw NSError(domain: "app.chimmo.synth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
        }

        var peakL: Float = 0.0
        var peakR: Float = 0.0
        var lrDiff: Float = 0.0
        var minLeftRMS: Float = .greatestFiniteMagnitude
        var maxLeftRMS: Float = 0.0
        let chCount = Int(buffer.format.channelCount)

        for _ in 0..<blocks {
            let status = try eng.renderOffline(AVAudioFrameCount(blockSize), to: buffer)
            if status == .success, let channels = buffer.floatChannelData {
                let len = Int(buffer.frameLength)
                var sqSumL: Float = 0.0
                let leftBuf = UnsafeBufferPointer(start: channels[0], count: len)
                let rightPtr = chCount > 1 ? channels[1] : channels[0]
                let rightBuf = UnsafeBufferPointer(start: rightPtr, count: len)
                onBlock?(leftBuf, rightBuf)
                for i in 0..<len {
                    let sL = leftBuf[i]
                    let sR = rightBuf[i]
                    peakL = max(peakL, abs(sL))
                    peakR = max(peakR, abs(sR))
                    lrDiff = max(lrDiff, abs(sL - sR))
                    sqSumL += sL * sL
                }
                let blkRMS = sqrt(sqSumL / Float(max(1, len)))
                minLeftRMS = min(minLeftRMS, blkRMS)
                maxLeftRMS = max(maxLeftRMS, blkRMS)
            }
        }
        let peak = max(peakL, peakR)
        let duringEnv = currentAcousticEnvelope()
        eng.stop()
        silenceAll()
        let afterEnv = currentAcousticEnvelope()
        return (peak, peakL, peakR, lrDiff, minLeftRMS, maxLeftRMS, inRate, outRate, duringEnv, afterEnv)
    }
}
