import AVFAudio
import Foundation
import os

/// 温暖五声部室内乐声学合成器（歌唱大提琴 Singing Cello + 音乐厅毛毡钢琴 Felt Piano + 湖面竖琴 Liquid Harp + 大提琴低音 Warm Bass + 星光钢片琴 Celesta）。
/// 同时内置无爆音连续双振子物理共鸣通道，用于「波纹对称」与「一颗音的五种人生」实时平滑滑音实验。
public final class FeltPianoSynth {

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
        var voices: [Voice]
        var pair: ContinuousPairState = ContinuousPairState()
    }

    private let maxVoices = 44
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44_100.0
    private let router: HalfDuplexAudioRouter

    private let lock: OSAllocatedUnfairLock<AudioState>
    private var isStarted = false

    public init(router: HalfDuplexAudioRouter = HalfDuplexAudioRouter()) {
        self.router = router
        self.lock = OSAllocatedUnfairLock(
            initialState: AudioState(voices: Array(repeating: Voice(), count: 44))
        )
        setupGraph()
    }

    private func setupGraph() {
        let sr = sampleRate
        let stateLock = lock

        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)
            guard count > 0, let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let rightPtr = abl.count > 1 ? abl[1].mData?.assumingMemoryBound(to: Float.self) : nil

            stateLock.withLock { state in
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
                            // 立体声微失谐双弦 + 温暖木槌瞬态（音乐厅毛毡钢琴）
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
                            // 呼吸感歌唱大提琴：55ms 柔和运弓起音 + 延迟出现的 5.1Hz 细腻揉弦 + 温暖木腔泛音
                            let attack = min(1.0, age / (0.055 * sr))
                            let sustainPhase = min(1.0, ageSec / max(0.25, decay))
                            let release = sustainPhase < 0.72
                                ? (1.0 - sustainPhase * 0.20)
                                : max(0.0, 0.856 * exp(-(ageSec - decay * 0.72) / max(0.18, decay * 0.42)))
                            let env = attack * release * vel * 0.92
                            let vibDepth = min(1.0, max(0.0, (ageSec - 0.16) / 0.32)) * 0.0052
                            instFreq = freq * (1.0 + vibDepth * sin(twoPi * 5.1 * ageSec))
                            // 模拟弓弦锯齿经大提琴共鸣箱低通后的温暖奇数+偶数泛音
                            let bowWarmth = 0.65 + 0.35 * sin(min(Double.pi, ageSec * 2.2))
                            sample = (
                                sin(ph) * 0.54 +
                                sin(ph * 2.0) * (0.26 * bowWarmth) +
                                sin(ph * 3.0) * (0.13 * bowWarmth) +
                                sin(ph * 4.0) * 0.055 +
                                sin(ph * 5.0) * 0.025
                            ) * env

                        case .liquidHarp:
                            // 湖面竖琴（圣桑《天鹅》水波专属）：晶莹清脆拨弦起音 + 丝绸水晕衰减
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

                    // 2. 连续物理共鸣双振子（哲学体验馆平滑滑音，零爆音指数包络）
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
            }
            return noErr
        }

        sourceNode = node
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 34.0

        engine.attach(node)
        engine.attach(reverb)
        engine.connect(node, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    public func ensureRunning() {
        guard !isStarted else { return }
        do {
            try router.configure(mode: .playback)
            if !engine.isRunning {
                try engine.start()
            }
            isStarted = true
        } catch {
            isStarted = false
        }
    }

    public func stopForRecording() {
        silenceAll()
        if engine.isRunning {
            engine.stop()
        }
        isStarted = false
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

    /// 哲学体验馆专用：实时平滑连续双声波共振（支持连续滑动频率比，丝滑无爆音）
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
        let delaySamps = max(0.0, delaySeconds * sampleRate)

        lock.withLock { state in
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

    /// 弹奏指定调内三和弦，支持 4 种真实大师左手伴奏织体（天鹅水波升级为「湖面竖琴」流淌波浪！）。
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
            // 圣桑《天鹅》标志性湖面竖琴波浪：温暖低音托底 + 6 粒晶莹上下波动竖琴分解
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
}
