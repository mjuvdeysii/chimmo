import AVFAudio
import Foundation
import os

/// 实时声学能量包络快照（由音频渲染线程每帧无锁写入，供主舞台 60fps 呼吸与光泽随动读取，零堆分配）。
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

/// 温暖五声部室内乐声学合成器（歌唱大提琴 Singing Cello + 音乐厅毛毡钢琴 Felt Piano + 湖面竖琴 Liquid Harp + 大提琴低音 Warm Bass + 星光钢片琴 Celesta）。
/// 全异步懒初始化与无锁渲染护航：不在 `init()` 或主线程阻塞构建 `AVAudioEngine` / `AVAudioUnitReverb`，彻底杜绝真机首屏卡死与音频线程优先级反转。
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

    private struct ContinuousPairState: Sendable {
        var active: Bool = false
        var targetGain: Double = 0.0
        var currentGain: Double = 0.0
        var targetHzA: Double = 261.63
        var currentHzA: Double = 261.63
        var targetHzB: Double = 392.00
        var currentHzB: Double = 392.00
        var phaseA: Double = 0.0
        var phaseB: Double = 0.0
    }

    private struct AudioState: Sendable {
        var sampleRate: Double = 48_000.0
        var voices: [Voice]
        var pair: ContinuousPairState = ContinuousPairState()
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
    private let lock: OSAllocatedUnfairLock<AudioState>
    private let telemetryLock = OSAllocatedUnfairLock<AcousticEnvelopeSnapshot>(initialState: .silent)
    private let audioQueue = DispatchQueue(label: "app.chimmo.audio.synth", qos: .userInitiated)
    private let lifecycleLock = NSLock()

    private var engine: AVAudioEngine?
    private var reverb: AVAudioUnitReverb?
    private var sourceNode: AVAudioSourceNode?
    private var configuredSampleRate: Double = 0
    private var isStarted: Bool = false
    private var isStarting: Bool = false
    private var observersInstalled: Bool = false
    private var observerTokens: [NSObjectProtocol] = []
    private var engineConfigObserverToken: NSObjectProtocol?
    private var graphGeneration: UInt64 = 0

    public init(router: HalfDuplexAudioRouter = HalfDuplexAudioRouter()) {
        self.router = router
        self.lock = OSAllocatedUnfairLock(
            initialState: AudioState(sampleRate: 48_000.0, voices: Array(repeating: Voice(), count: 44))
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
        lock.withLock { state in
            state.pair.active || state.voices.contains(where: { $0.active })
        }
    }

    /// 非阻塞唤醒：首次发声时在专用串行后台队列完成硬件采样率探测与音频图装配，主线程零卡顿。
    public func ensureRunning() {
        let shouldStart: Bool = lifecycleLock.withLock {
            if isStarted || isStarting {
                return false
            }
            isStarting = true
            return true
        }
        guard shouldStart else { return }

        audioQueue.async { [weak self] in
            self?.startEngineOnQueue()
        }
    }

    public func stopForRecording() {
        silenceAll()
        audioQueue.async { [weak self] in
            self?.stopEngineOnQueue()
        }
    }

    /// 供录音流程顺序等待音频引擎释放完毕，绝不阻塞主线程。
    public func stopForRecordingAsync(_ completion: @escaping @Sendable () -> Void) {
        silenceAll()
        audioQueue.async { [weak self] in
            self?.stopEngineOnQueue()
            completion()
        }
    }

    public func currentAcousticEnvelope() -> AcousticEnvelopeSnapshot {
        telemetryLock.withLockIfAvailable { $0 } ?? .silent
    }

    public func applySpaceProfile(_ profile: AcousticSpaceProfile) {
        let wet = max(12.0, min(46.0, profile.reverbWetMix.isFinite ? profile.reverbWetMix : 28.0))
        let warmth = max(0.65, min(1.30, profile.warmthDamping.isFinite ? profile.warmthDamping : 1.0))
        let spread = max(0.60, min(1.40, profile.stereoSpread.isFinite ? profile.stereoSpread : 1.0))
        lock.withLock { state in
            state.reverbWetMix = wet
            state.warmthDamping = warmth
            state.stereoSpread = spread
        }
        audioQueue.async { [weak self] in
            self?.reverb?.wetDryMix = wet
        }
    }

    public func currentSpaceProfile() -> AcousticSpaceProfile {
        lock.withLock { state in
            AcousticSpaceProfile(
                reverbWetMix: state.reverbWetMix,
                warmthDamping: state.warmthDamping,
                stereoSpread: state.stereoSpread
            )
        }
    }

    public func silenceAll() {
        lock.withLock { state in
            for i in 0..<state.voices.count {
                state.voices[i].active = false
            }
            state.pair.active = false
            state.pair.targetGain = 0.0
            state.envRMS = 0.0
            state.envWarmth = 0.0
            state.envShimmer = 0.0
            state.lpWarmthState = 0.0
            state.prevMono = 0.0
            state.reflectionIdx = 0
            state.reflectionLPL = 0.0
            state.reflectionLPR = 0.0
            for idx in 0..<state.reflectionBufL.count {
                state.reflectionBufL[idx] = 0.0
                state.reflectionBufR[idx] = 0.0
            }
        }
        telemetryLock.withLockIfAvailable { $0 = .silent }
    }

    /// 实时平滑连续双声波共振（支持连续滑动频率比，丝滑无爆音）
    public func setContinuousPair(hzA: Double, hzB: Double, gain: Double = 0.24) {
        ensureRunning()
        guard hzA.isFinite && hzB.isFinite && hzA >= 40 && hzB >= 40 else { return }
        lock.withLock { state in
            if !state.pair.active {
                state.pair.currentHzA = hzA
                state.pair.currentHzB = hzB
            }
            state.pair.active = true
            state.pair.targetHzA = hzA
            state.pair.targetHzB = hzB
            state.pair.targetGain = max(0.0, min(0.45, gain))
        }
    }

    public func stopContinuousPair() {
        lock.withLock { state in
            state.pair.active = false
            state.pair.targetGain = 0.0
        }
    }

    private static func enqueueVoice(
        into state: inout AudioState,
        frequency: Double,
        velocity: Double,
        decay: Double,
        brightness: Double,
        timbre: Timbre,
        delaySeconds: Double,
        pan: Double?
    ) {
        guard frequency.isFinite && frequency >= 28.0 && frequency <= 4800.0 else { return }

        let resolvedPan = pan.map { max(-0.65, min(0.65, $0.isFinite ? $0 : 0.0)) }
            ?? max(-0.46, min(0.46, log2(max(40.0, frequency) / 261.63) * 0.20))
        let scaledDecay = PitchScaledAcousticEnvelope.scaledDecay(baseDecay: decay, frequency: frequency)
        let absorbedBright = max(0.2, min(1.4, brightness * PitchScaledAcousticEnvelope.highFrequencyAirAbsorption(frequency: frequency)))

        let delaySamps = max(0.0, delaySeconds * state.sampleRate)
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
            velocity: max(0.03, min(1.0, velocity)),
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
        ensureRunning()
        guard frequency.isFinite && frequency >= 28.0 && frequency <= 4800.0 else { return }

        lock.withLock { state in
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

    /// 随「物理水位（waterLevel 0...1）」弹奏富有生命力的错落琶音与低音托底
    public func playWaterCradle(
        rootMIDI: Int,
        mode: ScaleMode,
        voicing: ChordVoicing,
        waterLevel: Double
    ) {
        let level = max(0.0, min(1.0, waterLevel))
        guard level >= 0.08 else { return }

        let bassHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: voicing.bassDegree, octaveOffset: voicing.bassOctave)
        let bassVel = 0.22 + level * 0.16
        playNote(frequency: bassHz, velocity: bassVel, decay: 2.5, brightness: 0.55, timbre: .warmBass, delaySeconds: 0.0, pan: 0.0)

        guard level >= 0.28 else { return }
        let arpNotes = level >= 0.52 ? voicing.upperDegrees : Array(voicing.upperDegrees.prefix(2))
        let cradlePans = [-0.24, 0.22, -0.14]
        for (idx, deg) in arpNotes.enumerated() {
            let oct = idx == 0 ? -1 : 0
            let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
            let delay = Double(idx + 1) * 0.038
            let vel = (0.14 + level * 0.10) * (idx == 0 ? 1.05 : 0.92)
            playNote(
                frequency: hz,
                velocity: vel,
                decay: 2.1,
                brightness: 0.78,
                timbre: .feltPiano,
                delaySeconds: delay,
                pan: cradlePans[idx % cradlePans.count]
            )
        }

        if level >= 0.72, let shimmerDeg = voicing.upperDegrees.last {
            let shimmerHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: shimmerDeg, octaveOffset: 1)
            let shimmerVel = (level - 0.65) * 0.34
            playNote(
                frequency: shimmerHz,
                velocity: shimmerVel,
                decay: 1.45,
                brightness: 1.1,
                timbre: .celesta,
                delaySeconds: Double(arpNotes.count + 1) * 0.042,
                pan: 0.32
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

    /// 弹奏指定调内三和弦，支持 4 种真实大师左手立体声宽伴奏织体。
    public func playDiatonicChord(
        rootMIDI: Int,
        mode: ScaleMode,
        chord: DiatonicChord,
        texture: AccompanimentTexture = .swanRipple,
        spanDuration: Double = 1.6,
        intensity: Double = 0.82
    ) {
        let events = Self.diatonicChordEvents(
            startTime: 0.0,
            rootMIDI: rootMIDI,
            mode: mode,
            chord: chord,
            texture: texture,
            spanDuration: spanDuration,
            intensity: intensity
        )
        for ev in events {
            playNote(
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

    public func playWaterRipplePreview(rootMIDI: Int, mode: ScaleMode, profile: HarmonyProfile) {
        let voicing = profile.voicing(for: 1)
        let bassHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: voicing.bassDegree, octaveOffset: -1)
        playNote(frequency: bassHz, velocity: 0.24, decay: 1.8, timbre: .warmBass, delaySeconds: 0.0)
        for (idx, deg) in [1, 3, 5, 2].enumerated() {
            let oct = idx == 3 ? 1 : 0
            let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
            playNote(
                frequency: hz,
                velocity: 0.20,
                decay: 1.5,
                timbre: idx == 3 ? .celesta : .liquidHarp,
                delaySeconds: Double(idx + 1) * 0.055
            )
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
        ) { [weak self] _ in
            self?.audioQueue.async {
                self?.stopEngineOnQueue()
            }
        }
        observerTokens.append(inactiveToken)

        let resumeToken = nc.addObserver(
            forName: AVAudioSession.resumptionRecommendationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.audioQueue.async {
                guard let self else { return }
                self.lifecycleLock.withLock {
                    self.isStarted = false
                    self.isStarting = false
                }
                if self.hasActiveVoices() {
                    self.ensureRunning()
                }
            }
        }
        observerTokens.append(resumeToken)

        let routeToken = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            let reasonRaw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            let reason = reasonRaw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason == .oldDeviceUnavailable || reason == .newDeviceAvailable || reason == .categoryChange else {
                return
            }
            self?.audioQueue.async {
                guard let self else { return }
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
        sourceNode = nil
        configuredSampleRate = 0
    }

    private func startEngineOnQueue() {
        installObserversIfNeeded()
        do {
            try router.configure(mode: .playback)
            let probeEngine = AVAudioEngine()
            let outSR = probeEngine.outputNode.outputFormat(forBus: 0).sampleRate
            let effectiveSR = (outSR >= 22_050.0 && outSR <= 96_000.0) ? outSR : max(44_100.0, router.hardwareSampleRate)
            lock.withLock { $0.sampleRate = effectiveSR }

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

    private func makeSourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
        let stateLock = lock
        let tLock = telemetryLock
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
                let twoPi = 2.0 * Double.pi
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
                    var mixL = 0.0
                    var mixR = 0.0

                    // 1. 44 声部室内乐物理微声学发声引擎
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
                        mixL += sample * (0.5 - pan * 0.5) - split
                        mixR += sample * (0.5 + pan * 0.5) + split

                        let step = twoPi * instFreq * invSR
                        state.voices[vIdx].phase += step
                        state.voices[vIdx].phaseDetune += step * 1.00058
                        state.voices[vIdx].hammerPhase += step * 7.3
                        if state.voices[vIdx].phase > twoPi * 1024.0 {
                            state.voices[vIdx].phase.formTruncatingRemainder(dividingBy: twoPi)
                            state.voices[vIdx].phaseDetune.formTruncatingRemainder(dividingBy: twoPi)
                        }
                        state.voices[vIdx].ageSamples += 1.0
                    }

                    // 2. 连续物理共鸣双振子
                    if state.pair.active || state.pair.currentGain > 0.0004 {
                        let gainTarget = state.pair.active ? state.pair.targetGain : 0.0
                        state.pair.currentGain += (gainTarget - state.pair.currentGain) * 0.0018
                        state.pair.currentHzA += (state.pair.targetHzA - state.pair.currentHzA) * 0.0035
                        state.pair.currentHzB += (state.pair.targetHzB - state.pair.currentHzB) * 0.0035

                        let sA = (sin(state.pair.phaseA) * 0.72 + sin(state.pair.phaseA * 2.0) * 0.18 + sin(state.pair.phaseA * 3.0) * 0.06)
                        let sB = (sin(state.pair.phaseB) * 0.72 + sin(state.pair.phaseB * 2.0) * 0.18 + sin(state.pair.phaseB * 3.0) * 0.06)
                        let g = state.pair.currentGain
                        mixL += (sA * 0.62 + sB * 0.38) * g
                        mixR += (sA * 0.38 + sB * 0.62) * g

                        state.pair.phaseA += twoPi * state.pair.currentHzA * invSR
                        state.pair.phaseB += twoPi * state.pair.currentHzB * invSR
                        if state.pair.phaseA > twoPi * 1024.0 { state.pair.phaseA.formTruncatingRemainder(dividingBy: twoPi) }
                        if state.pair.phaseB > twoPi * 1024.0 { state.pair.phaseB.formTruncatingRemainder(dividingBy: twoPi) }
                    }

                    // 3. 零堆分配木质沙龙早期声学反射（11ms/17ms 柔和低通交叉回响）
                    let wIdx = state.reflectionIdx
                    let rL = (wIdx + refCap - refDelayL) % refCap
                    let rR = (wIdx + refCap - refDelayR) % refCap
                    let delayedL = state.reflectionBufL[rL]
                    let delayedR = state.reflectionBufR[rR]
                    state.reflectionLPL += (delayedL - state.reflectionLPL) * 0.28
                    state.reflectionLPR += (delayedR - state.reflectionLPR) * 0.28
                    state.reflectionBufL[wIdx] = mixL
                    state.reflectionBufR[wIdx] = mixR
                    state.reflectionIdx = (wIdx + 1) % refCap

                    let spatialL = mixL + state.reflectionLPR * refGain
                    let spatialR = mixR + state.reflectionLPL * refGain
                    let outL = tanh(spatialL * 0.84)
                    let outR = tanh(spatialR * 0.84)
                    leftPtr[i] = Float(outL)
                    rightPtr?[i] = Float(outR)

                    let mono = (outL + outR) * 0.5
                    sumSq += mono * mono
                    lpWarm += (mono - lpWarm) * 0.055
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
                state.envRMS += (rawRMS - state.envRMS) * (rawRMS > state.envRMS ? 0.38 : 0.14)
                state.envWarmth += (rawWarm - state.envWarmth) * (rawWarm > state.envWarmth ? 0.35 : 0.12)
                state.envShimmer += (rawShim - state.envShimmer) * (rawShim > state.envShimmer ? 0.42 : 0.16)
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

        // 优先构建完整「声源 -> 音乐厅混响 -> mainMixerNode」链路；若极少数音频路由拒绝混响格式则自动降级为「声源 -> mainMixerNode」直通，绝不静音！
        let initialWet = lock.withLock { $0.reverbWetMix }
        do {
            let eng = AVAudioEngine()
            let node = makeSourceNode(format: format)
            let rev = AVAudioUnitReverb()
            rev.loadFactoryPreset(.mediumHall2)
            rev.wetDryMix = initialWet

            let mixer = eng.mainMixerNode
            mixer.outputVolume = 1.0

            eng.attach(node)
            eng.attach(rev)
            try eng.connectNode(node, to: rev, format: format)
            try eng.connectNode(rev, to: mixer, format: format)

            eng.prepare()
            try eng.start()

            graphGeneration &+= 1
            attachConfigObserver(for: eng, generation: graphGeneration)
            self.engine = eng
            self.reverb = rev
            self.sourceNode = node
            self.configuredSampleRate = sampleRate
        } catch {
            let eng = AVAudioEngine()
            let node = makeSourceNode(format: format)
            let mixer = eng.mainMixerNode
            mixer.outputVolume = 1.0

            eng.attach(node)
            try eng.connectNode(node, to: mixer, format: format)

            eng.prepare()
            try eng.start()

            graphGeneration &+= 1
            attachConfigObserver(for: eng, generation: graphGeneration)
            self.engine = eng
            self.reverb = nil
            self.sourceNode = node
            self.configuredSampleRate = sampleRate
        }
    }

    /// 离线音频管线自检（供 XCTest 直接验证 48kHz 双端混响连接绝不报 -10868 且真实输出有效 PCM 声压，绝不触发实时录音/播放权限）
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
        let res = try runOfflineReverbRender(sampleRate: sampleRate) { state in
            state.voices[0] = Voice(
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

    public func verifyContinuousPairRenderTelemetry(
        sampleRate: Double = 48_000.0,
        hzA: Double = 329.63,
        hzB: Double = 261.63,
        gain: Double = 0.20
    ) throws -> (
        peak: Float,
        duringEnvelope: AcousticEnvelopeSnapshot,
        afterStopEnvelope: AcousticEnvelopeSnapshot
    ) {
        let clampedGain = max(0.05, min(0.42, gain))
        let res = try runOfflineReverbRender(sampleRate: sampleRate) { state in
            state.pair.active = true
            state.pair.currentHzA = max(40.0, hzA)
            state.pair.targetHzA = max(40.0, hzA)
            state.pair.currentHzB = max(40.0, hzB)
            state.pair.targetHzB = max(40.0, hzB)
            state.pair.currentGain = clampedGain
            state.pair.targetGain = clampedGain
        }
        stopContinuousPair()
        return (res.peak, res.envelopeDuringRender, res.envelopeAfterSilence)
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
        let res = try runOfflineReverbRender(sampleRate: sampleRate) { state in
            state.voices[0] = Voice(
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

    private func runOfflineReverbRender(
        sampleRate: Double,
        configureAudioState: (inout AudioState) -> Void
    ) throws -> (
        peak: Float,
        peakL: Float,
        peakR: Float,
        reverbInRate: Double,
        reverbOutRate: Double,
        envelopeDuringRender: AcousticEnvelopeSnapshot,
        envelopeAfterSilence: AcousticEnvelopeSnapshot
    ) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw NSError(domain: "app.chimmo.synth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }

        silenceAll()
        let activeWet = lock.withLock { state -> Float in
            state.sampleRate = sampleRate
            configureAudioState(&state)
            return state.reverbWetMix
        }

        let eng = AVAudioEngine()
        let node = makeSourceNode(format: format)
        let rev = AVAudioUnitReverb()
        rev.loadFactoryPreset(.mediumHall2)
        rev.wetDryMix = activeWet
        let mixer = eng.mainMixerNode
        mixer.outputVolume = 1.0

        eng.attach(node)
        eng.attach(rev)
        try eng.connectNode(node, to: rev, format: format)
        try eng.connectNode(rev, to: mixer, format: format)

        try eng.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        try eng.start()

        let inRate = rev.inputFormat(forBus: 0).sampleRate
        let outRate = rev.outputFormat(forBus: 0).sampleRate

        guard let buffer = AVAudioPCMBuffer(pcmFormat: eng.manualRenderingFormat, frameCapacity: 512) else {
            eng.stop()
            throw NSError(domain: "app.chimmo.synth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
        }

        var peakL: Float = 0.0
        var peakR: Float = 0.0
        let chCount = Int(buffer.format.channelCount)
        for _ in 0..<8 {
            let status = try eng.renderOffline(512, to: buffer)
            if status == .success, let channels = buffer.floatChannelData {
                let len = Int(buffer.frameLength)
                for i in 0..<len {
                    peakL = max(peakL, abs(channels[0][i]))
                    if chCount > 1 {
                        peakR = max(peakR, abs(channels[1][i]))
                    }
                }
            }
        }
        let peak = max(peakL, peakR)
        let duringEnv = currentAcousticEnvelope()
        eng.stop()
        silenceAll()
        let afterEnv = currentAcousticEnvelope()
        return (peak, peakL, peakR, inRate, outRate, duringEnv, afterEnv)
    }

    /// 完全隔离的整曲离线立体声渲染（绝不触碰实时 `AVAudioSession` 或正在播放的引擎，用于本地离线导出可播放音频）。
    public static func renderOfflineSongPCM(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        accompanimentTexture: AccompanimentTexture = .swanRipple,
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        playbackRate: Double = 1.0,
        visualMode: StageVisualMode = .orbitalDisc,
        sampleRate: Double = 44_100.0
    ) throws -> (left: [Float], right: [Float], sampleRate: Int) {
        let safeSR = max(22_050.0, min(48_000.0, sampleRate.isFinite ? sampleRate : 44_100.0))
        let safeRate = max(0.5, min(1.6, playbackRate.isFinite ? playbackRate : 1.0))
        let rateScale = 1.0 / safeRate
        let profile = AcousticSpaceProfile.profile(for: document.scaleMode)

        let synth = FeltPianoSynth(router: HalfDuplexAudioRouter())
        synth.lock.withLock { state in
            state.sampleRate = safeSR
            state.reverbWetMix = Float(max(12.0, min(46.0, profile.reverbWetMix.isFinite ? profile.reverbWetMix : 28.0)))
            state.warmthDamping = max(0.65, min(1.30, profile.warmthDamping.isFinite ? profile.warmthDamping : 1.0))
            state.stereoSpread = max(0.60, min(1.40, profile.stereoSpread.isFinite ? profile.stereoSpread : 1.0))
        }

        let groove = document.grooveStrength
        let totalDur = max(0.6, document.totalDuration)
        let resolvedVoice = melodyVoice ?? document.preferredVoice ?? .singingCello
        let voiceTimbre = Timbre.from(voice: resolvedVoice)
        let spans = TheoryLensEngine.buildChordSpans(
            document: document,
            preset: chordPreset,
            overrides: chordOverrides
        )

        var events: [OfflineSynthNoteEvent] = []
        if chordPreset != .off {
            for span in spans {
                let chordEvents = diatonicChordEvents(
                    startTime: span.startTime * rateScale,
                    rootMIDI: document.rootMIDI,
                    mode: document.scaleMode,
                    chord: span.chord,
                    texture: accompanimentTexture,
                    spanDuration: max(0.75, (span.endTime - span.startTime) * rateScale),
                    intensity: 0.72
                )
                events.append(contentsOf: chordEvents)
            }
        }

        let sortedNotes = document.notes.sorted {
            $0.displayOnset(grooveStrength: groove) < $1.displayOnset(grooveStrength: groove)
        }
        for bead in sortedNotes {
            let onset = bead.displayOnset(grooveStrength: groove)
            let dur = bead.displayDuration(grooveStrength: groove)
            let hz = document.scaleMode.frequencyHz(
                rootMIDI: document.rootMIDI,
                degree: bead.degree,
                octaveOffset: bead.octaveOffset
            )
            let pan = AcousticSpatialPanMapper.pan(
                forBeatOnset: onset,
                totalDuration: totalDur,
                visualMode: visualMode
            )
            events.append(OfflineSynthNoteEvent(
                timeSec: onset * rateScale,
                frequency: hz,
                velocity: 0.62,
                decay: max(0.85, dur * 1.45 * rateScale),
                brightness: 0.96,
                timbre: voiceTimbre,
                pan: pan
            ))
        }

        if shadowEnabled {
            let shadowNotes = CounterpointShadowEngine.generateShadowVoice(document: document, spans: spans)
            let shadowTimbre: Timbre = (resolvedVoice == .liquidHarp) ? .celesta : .liquidHarp
            for shadow in shadowNotes {
                let sHz = document.scaleMode.frequencyHz(
                    rootMIDI: document.rootMIDI,
                    degree: shadow.degree,
                    octaveOffset: shadow.octaveOffset
                )
                let sPan = -AcousticSpatialPanMapper.pan(
                    forBeatOnset: shadow.onset,
                    totalDuration: totalDur,
                    visualMode: visualMode
                ) * 0.65
                events.append(OfflineSynthNoteEvent(
                    timeSec: shadow.onset * rateScale,
                    frequency: sHz,
                    velocity: 0.36,
                    decay: max(0.85, shadow.duration * rateScale * 1.35),
                    brightness: 0.85,
                    timbre: shadowTimbre,
                    pan: sPan
                ))
            }
        }
        events.sort { $0.timeSec < $1.timeSec }

        let rawSeconds = document.notes.isEmpty ? 1.0 : (totalDur * rateScale + 1.85)
        let clampedSeconds = max(1.0, min(28.0, rawSeconds))
        let totalFrames = max(512, Int((clampedSeconds * safeSR).rounded()))
        let chunkFrames: AVAudioFrameCount = 512

        guard let format = AVAudioFormat(standardFormatWithSampleRate: safeSR, channels: 2) else {
            throw NSError(domain: "app.chimmo.synth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }

        let eng = AVAudioEngine()
        let node = synth.makeSourceNode(format: format)
        let mixer = eng.mainMixerNode
        mixer.outputVolume = 1.0
        eng.attach(node)

        do {
            let rev = AVAudioUnitReverb()
            rev.loadFactoryPreset(.mediumHall2)
            rev.wetDryMix = Float(max(12.0, min(46.0, profile.reverbWetMix.isFinite ? profile.reverbWetMix : 28.0)))
            eng.attach(rev)
            try eng.connectNode(node, to: rev, format: format)
            try eng.connectNode(rev, to: mixer, format: format)
        } catch {
            try eng.connectNode(node, to: mixer, format: format)
        }

        try eng.enableManualRenderingMode(.offline, format: format, maximumFrameCount: chunkFrames)
        try eng.start()
        defer { eng.stop() }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: eng.manualRenderingFormat, frameCapacity: chunkFrames) else {
            throw NSError(domain: "app.chimmo.synth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
        }

        var leftOut: [Float] = []
        var rightOut: [Float] = []
        leftOut.reserveCapacity(totalFrames)
        rightOut.reserveCapacity(totalFrames)

        let immutableEvents = events
        var renderedFrames = 0
        var nextEventIdx = 0
        while renderedFrames < totalFrames {
            let remaining = totalFrames - renderedFrames
            let blockCount = min(Int(chunkFrames), remaining)
            let blockStartSec = Double(renderedFrames) / safeSR
            let blockEndSec = Double(renderedFrames + blockCount) / safeSR

            let batchStart = nextEventIdx
            while nextEventIdx < immutableEvents.count && immutableEvents[nextEventIdx].timeSec < blockEndSec {
                nextEventIdx += 1
            }
            if batchStart < nextEventIdx {
                let batch = immutableEvents[batchStart..<nextEventIdx]
                synth.lock.withLock { state in
                    for ev in batch {
                        Self.enqueueVoice(
                            into: &state,
                            frequency: ev.frequency,
                            velocity: ev.velocity,
                            decay: ev.decay,
                            brightness: ev.brightness,
                            timbre: ev.timbre,
                            delaySeconds: max(0.0, ev.timeSec - blockStartSec),
                            pan: ev.pan
                        )
                    }
                }
            }

            let status = try eng.renderOffline(AVAudioFrameCount(blockCount), to: buffer)
            if status == .success, let channels = buffer.floatChannelData {
                let len = Int(buffer.frameLength)
                let chCount = Int(buffer.format.channelCount)
                for i in 0..<len {
                    let sL = channels[0][i]
                    let sR = chCount > 1 ? channels[1][i] : sL
                    leftOut.append(sL.isFinite ? sL : 0.0)
                    rightOut.append(sR.isFinite ? sR : 0.0)
                }
            } else {
                for _ in 0..<blockCount {
                    leftOut.append(0.0)
                    rightOut.append(0.0)
                }
            }
            renderedFrames += blockCount
        }

        var maxAbs: Float = 0.0
        for i in 0..<leftOut.count {
            maxAbs = max(maxAbs, max(abs(leftOut[i]), abs(rightOut[i])))
        }
        if maxAbs > 0.88 {
            let scale = 0.88 / maxAbs
            for i in 0..<leftOut.count {
                leftOut[i] *= scale
                rightOut[i] *= scale
            }
        }

        let fadeSamples = min(leftOut.count, Int(safeSR * 0.06))
        if fadeSamples > 0 {
            let startIdx = leftOut.count - fadeSamples
            for offset in 0..<fadeSamples {
                let gain = Float(fadeSamples - offset) / Float(fadeSamples)
                leftOut[startIdx + offset] *= gain
                rightOut[startIdx + offset] *= gain
            }
        }

        return (leftOut, rightOut, Int(safeSR))
    }
}
