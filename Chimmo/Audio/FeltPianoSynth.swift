import AVFAudio
import Foundation
import os

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
    }

    private let router: HalfDuplexAudioRouter
    private let lock: OSAllocatedUnfairLock<AudioState>
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

    public func silenceAll() {
        lock.withLock { state in
            for i in 0..<state.voices.count {
                state.voices[i].active = false
            }
            state.pair.active = false
            state.pair.targetGain = 0.0
        }
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

    public func playNote(
        frequency: Double,
        velocity: Double = 0.55,
        decay: Double = 1.75,
        brightness: Double = 0.95,
        timbre: Timbre = .feltPiano,
        delaySeconds: Double = 0.0
    ) {
        ensureRunning()
        guard frequency.isFinite && frequency >= 28.0 && frequency <= 4800.0 else { return }

        lock.withLock { state in
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
                decaySeconds: max(0.25, min(4.8, decay)),
                brightness: max(0.2, min(1.4, brightness))
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
        playNote(frequency: bassHz, velocity: bassVel, decay: 2.5, brightness: 0.55, timbre: .warmBass, delaySeconds: 0.0)

        guard level >= 0.28 else { return }
        let arpNotes = level >= 0.52 ? voicing.upperDegrees : Array(voicing.upperDegrees.prefix(2))
        for (idx, deg) in arpNotes.enumerated() {
            let oct = idx == 0 ? -1 : 0
            let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
            let delay = Double(idx + 1) * 0.038
            let vel = (0.14 + level * 0.10) * (idx == 0 ? 1.05 : 0.92)
            playNote(frequency: hz, velocity: vel, decay: 2.1, brightness: 0.78, timbre: .feltPiano, delaySeconds: delay)
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
                delaySeconds: Double(arpNotes.count + 1) * 0.042
            )
        }
    }

    /// 弹奏指定调内三和弦，支持 4 种真实大师左手伴奏织体。
    public func playDiatonicChord(
        rootMIDI: Int,
        mode: ScaleMode,
        chord: DiatonicChord,
        texture: AccompanimentTexture = .swanRipple,
        spanDuration: Double = 1.6,
        intensity: Double = 0.82
    ) {
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

        switch texture {
        case .swanRipple:
            playNote(frequency: bassHz, velocity: 0.25 * clamped, decay: dur * 1.35, brightness: 0.50, timbre: .warmBass, delaySeconds: 0.0)
            let pattern: [Double] = [bassHz, fifthHz, midRootHz, thirdHz, midRootHz, fifthHz]
            let stepSec = min(0.24, max(0.11, dur / Double(pattern.count)))
            for (idx, hz) in pattern.enumerated() {
                let vel = (idx == 0 ? 0.16 : (idx == 3 ? 0.19 : 0.14)) * clamped
                playNote(
                    frequency: hz,
                    velocity: vel,
                    decay: 1.65,
                    brightness: 0.84,
                    timbre: .liquidHarp,
                    delaySeconds: Double(idx) * stepSec
                )
            }

        case .feltWaltz:
            playNote(frequency: bassHz, velocity: 0.30 * clamped, decay: dur * 1.25, brightness: 0.54, timbre: .warmBass, delaySeconds: 0.0)
            let beat = min(0.55, max(0.26, dur / 3.0))
            for beatIdx in 1...2 {
                let t = Double(beatIdx) * beat
                let liftVel = (beatIdx == 1 ? 0.17 : 0.13) * clamped
                playNote(frequency: fifthHz, velocity: liftVel, decay: 1.35, brightness: 0.76, timbre: .feltPiano, delaySeconds: t)
                playNote(frequency: thirdHz, velocity: liftVel * 0.95, decay: 1.35, brightness: 0.80, timbre: .feltPiano, delaySeconds: t + 0.018)
                playNote(frequency: midRootHz, velocity: liftVel * 0.85, decay: 1.35, brightness: 0.82, timbre: .feltPiano, delaySeconds: t + 0.032)
            }

        case .summerGlass:
            let ninthDeg = ((rDeg) % 7) + 1
            let ninthHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: ninthDeg, octaveOffset: 0)
            let sparkleHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: fifthDeg, octaveOffset: 1)
            playNote(frequency: bassHz, velocity: 0.24 * clamped, decay: 2.4, brightness: 0.50, timbre: .warmBass, delaySeconds: 0.0)
            playNote(frequency: fifthHz, velocity: 0.18 * clamped, decay: 2.1, brightness: 0.82, timbre: .feltPiano, delaySeconds: 0.055)
            playNote(frequency: ninthHz, velocity: 0.17 * clamped, decay: 2.0, brightness: 0.88, timbre: .feltPiano, delaySeconds: 0.13)
            playNote(frequency: thirdHz, velocity: 0.16 * clamped, decay: 1.9, brightness: 0.86, timbre: .feltPiano, delaySeconds: 0.21)
            playNote(frequency: sparkleHz, velocity: 0.14 * clamped, decay: 1.5, brightness: 1.05, timbre: .celesta, delaySeconds: min(0.52, dur * 0.42))

        case .pureChorale:
            playNote(frequency: bassHz, velocity: 0.25 * clamped, decay: 2.3, brightness: 0.55, timbre: .warmBass, delaySeconds: 0.0)
            for (idx, deg) in tones.enumerated() {
                let oct = (idx > 0 && deg < rDeg) ? 0 : (idx == 0 ? -1 : 0)
                let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
                playNote(
                    frequency: hz,
                    velocity: 0.19 * clamped,
                    decay: 2.1,
                    brightness: 0.80,
                    timbre: .feltPiano,
                    delaySeconds: Double(idx) * 0.025
                )
            }
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

                for i in 0..<count {
                    var mixL = 0.0
                    var mixR = 0.0

                    // 1. 44 声部室内乐发声引擎
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
                        var instFreq = freq

                        switch state.voices[vIdx].timbre {
                        case .feltPiano:
                            let attack = min(1.0, age / (0.009 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.56))
                            let env = attack * bodyDecay * vel
                            let bright = exp(-ageSec * 3.4) * state.voices[vIdx].brightness
                            let hammerEnv = exp(-ageSec * 145.0) * 0.085
                            let hammer = sin(state.voices[vIdx].hammerPhase) * hammerEnv
                            let fund = (sin(ph) + sin(phD)) * 0.36
                            sample = (
                                fund +
                                sin(ph * 2.001) * (0.20 * (0.35 + 0.65 * bright)) +
                                sin(ph * 3.003) * (0.075 * bright) +
                                sin(ph * 4.006) * (0.028 * bright * bright) +
                                hammer
                            ) * env

                        case .singingCello:
                            let attack = min(1.0, age / (0.055 * sr))
                            let sustainPhase = min(1.0, ageSec / max(0.25, decay))
                            let release = sustainPhase < 0.72
                                ? (1.0 - sustainPhase * 0.20)
                                : max(0.0, 0.856 * exp(-(ageSec - decay * 0.72) / max(0.18, decay * 0.42)))
                            let env = attack * release * vel * 0.92
                            let vibDepth = min(1.0, max(0.0, (ageSec - 0.16) / 0.32)) * 0.0052
                            instFreq = freq * (1.0 + vibDepth * sin(twoPi * 5.1 * ageSec))
                            let bowWarmth = 0.65 + 0.35 * sin(min(Double.pi, ageSec * 2.2))
                            sample = (
                                sin(ph) * 0.54 +
                                sin(ph * 2.0) * (0.26 * bowWarmth) +
                                sin(ph * 3.0) * (0.13 * bowWarmth) +
                                sin(ph * 4.0) * 0.055 +
                                sin(ph * 5.0) * 0.025
                            ) * env

                        case .liquidHarp:
                            let attack = min(1.0, age / (0.004 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.48))
                            let env = attack * bodyDecay * vel
                            let shimmer = exp(-ageSec * 4.8)
                            sample = (
                                sin(ph) * 0.64 +
                                sin(ph * 2.0) * (0.24 * (0.3 + 0.7 * shimmer)) +
                                sin(ph * 3.0) * (0.09 * shimmer) +
                                sin(ph * 4.0) * (0.03 * shimmer * shimmer)
                            ) * env

                        case .warmBass:
                            let attack = min(1.0, age / (0.030 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.72))
                            let env = attack * bodyDecay * vel
                            let sub = sin(ph * 0.5) * 0.24
                            sample = (
                                sub +
                                sin(ph) * 0.62 +
                                sin(ph * 2.0) * 0.18 * exp(-ageSec * 1.8) +
                                sin(ph * 3.0) * 0.06 * exp(-ageSec * 2.8)
                            ) * env

                        case .celesta:
                            let attack = min(1.0, age / (0.003 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.42))
                            let env = attack * bodyDecay * vel
                            sample = (
                                sin(ph) * 0.64 +
                                sin(ph * 2.0) * 0.22 * exp(-ageSec * 4.2) +
                                sin(ph * 2.756) * 0.13 * exp(-ageSec * 7.2)
                            ) * env
                        }

                        let pan = max(-0.44, min(0.44, (log2(max(40.0, freq) / 261.63)) * 0.18))
                        mixL += sample * (0.5 - pan * 0.5)
                        mixR += sample * (0.5 + pan * 0.5)

                        let step = twoPi * instFreq * invSR
                        state.voices[vIdx].phase += step
                        state.voices[vIdx].phaseDetune += step * 1.00055
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

                    leftPtr[i] = Float(tanh(mixL * 0.84))
                    rightPtr?[i] = Float(tanh(mixR * 0.84))
                }
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
        do {
            let eng = AVAudioEngine()
            let node = makeSourceNode(format: format)
            let rev = AVAudioUnitReverb()
            rev.loadFactoryPreset(.mediumHall2)
            rev.wetDryMix = 28.0

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
        frequency: Double = 440.0
    ) throws -> (peak: Float, reverbInRate: Double, reverbOutRate: Double) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw NSError(domain: "app.chimmo.synth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }

        lock.withLock { state in
            state.sampleRate = sampleRate
            state.voices[0] = Voice(
                active: true,
                timbre: .feltPiano,
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

        let eng = AVAudioEngine()
        let node = makeSourceNode(format: format)
        let rev = AVAudioUnitReverb()
        rev.loadFactoryPreset(.mediumHall2)
        rev.wetDryMix = 28.0
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

        var peak: Float = 0.0
        for _ in 0..<4 {
            let status = try eng.renderOffline(512, to: buffer)
            if status == .success, let channels = buffer.floatChannelData {
                let len = Int(buffer.frameLength)
                for i in 0..<len {
                    peak = max(peak, abs(channels[0][i]))
                }
            }
        }
        eng.stop()
        silenceAll()
        return (peak, inRate, outRate)
    }
}
