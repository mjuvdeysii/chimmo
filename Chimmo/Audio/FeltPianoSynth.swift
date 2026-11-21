import AVFAudio
import Foundation
import os

/// 温暖三层声学合成器（毛毡钢琴 Felt Piano + 大提琴低音托底 Warm Bass + 钢片琴星光泛音 Celesta）。
/// 支持随「物理水位（waterLevel 0...1）」自动生长出从单音清唱、深沉低音、指尖错落琶音到星光泛音的丰富编曲层次。
public final class FeltPianoSynth {

    public enum Timbre: Int, Sendable {
        case feltPiano = 0
        case warmBass = 1
        case celesta = 2
    }

    private struct Voice: Sendable {
        var active: Bool = false
        var timbre: Timbre = .feltPiano
        var frequency: Double = 440.0
        var phase: Double = 0.0
        var hammerPhase: Double = 0.0
        var ageSamples: Double = 0.0
        var delaySamples: Double = 0.0
        var velocity: Double = 0.5
        var decaySeconds: Double = 1.8
        var brightness: Double = 1.0
    }

    private let maxVoices = 36
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44_100.0
    private let router: HalfDuplexAudioRouter

    private let lock = OSAllocatedUnfairLock(initialState: [Voice]())
    private var isStarted = false

    public init(router: HalfDuplexAudioRouter = HalfDuplexAudioRouter()) {
        self.router = router
        self.lock.withLock { voices in
            voices = Array(repeating: Voice(), count: maxVoices)
        }
        setupGraph()
    }

    private func setupGraph() {
        let sr = sampleRate
        let voiceLock = lock

        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)
            guard count > 0, let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let rightPtr = abl.count > 1 ? abl[1].mData?.assumingMemoryBound(to: Float.self) : nil

            voiceLock.withLock { voices in
                let invSR = 1.0 / sr
                let twoPi = 2.0 * Double.pi

                for i in 0..<count {
                    var mixL = 0.0
                    var mixR = 0.0

                    for vIdx in 0..<voices.count {
                        if !voices[vIdx].active { continue }

                        // 支持微琶音错落延迟（指尖拨弦/琶音感，零主线程定时器抖动）
                        if voices[vIdx].delaySamples > 0 {
                            voices[vIdx].delaySamples -= 1.0
                            continue
                        }

                        let age = voices[vIdx].ageSamples
                        let ageSec = age * invSR
                        let decay = voices[vIdx].decaySeconds
                        if ageSec > decay * 2.5 {
                            voices[vIdx].active = false
                            continue
                        }

                        let ph = voices[vIdx].phase
                        let vel = voices[vIdx].velocity
                        var sample = 0.0

                        switch voices[vIdx].timbre {
                        case .feltPiano:
                            let attack = min(1.0, age / (0.010 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.52))
                            let env = attack * bodyDecay * vel
                            let bright = exp(-ageSec * 3.6) * voices[vIdx].brightness
                            // 极轻柔的毛毡木槌触弦瞬态（前 18ms）
                            let hammerEnv = exp(-ageSec * 140.0) * 0.09
                            let hammer = sin(voices[vIdx].hammerPhase) * hammerEnv
                            sample = (
                                sin(ph) * 0.70 +
                                sin(ph * 2.001) * (0.21 * (0.4 + 0.6 * bright)) +
                                sin(ph * 3.003) * (0.07 * bright) +
                                sin(ph * 4.006) * (0.025 * bright * bright) +
                                hammer
                            ) * env

                        case .warmBass:
                            let attack = min(1.0, age / (0.028 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.70))
                            let env = attack * bodyDecay * vel
                            let sub = sin(ph * 0.5) * 0.24
                            sample = (
                                sub +
                                sin(ph) * 0.62 +
                                sin(ph * 2.0) * 0.18 * exp(-ageSec * 1.8) +
                                sin(ph * 3.0) * 0.06 * exp(-ageSec * 2.8)
                            ) * env

                        case .celesta:
                            let attack = min(1.0, age / (0.004 * sr))
                            let bodyDecay = exp(-ageSec / (decay * 0.42))
                            let env = attack * bodyDecay * vel
                            // 钢片琴/八音盒清亮泛音（带非整数倍钟琴泛音 2.76x）
                            sample = (
                                sin(ph) * 0.66 +
                                sin(ph * 2.0) * 0.22 * exp(-ageSec * 4.5) +
                                sin(ph * 2.756) * 0.12 * exp(-ageSec * 7.5)
                            ) * env
                        }

                        let pan = max(-0.42, min(0.42, (log2(max(40.0, voices[vIdx].frequency) / 261.63)) * 0.18))
                        mixL += sample * (0.5 - pan * 0.5)
                        mixR += sample * (0.5 + pan * 0.5)

                        let step = twoPi * voices[vIdx].frequency * invSR
                        voices[vIdx].phase += step
                        voices[vIdx].hammerPhase += step * 7.3
                        if voices[vIdx].phase > twoPi * 1024.0 {
                            voices[vIdx].phase.formTruncatingRemainder(dividingBy: twoPi)
                        }
                        voices[vIdx].ageSamples += 1.0
                    }

                    leftPtr[i] = Float(tanh(mixL * 0.86))
                    rightPtr?[i] = Float(tanh(mixR * 0.86))
                }
            }
            return noErr
        }

        sourceNode = node
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 32.0

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
        lock.withLock { voices in
            for i in 0..<voices.count {
                voices[i].active = false
            }
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

        lock.withLock { voices in
            var targetIdx = 0
            var oldestAge = -1.0
            for i in 0..<voices.count {
                if !voices[i].active {
                    targetIdx = i
                    break
                }
                if voices[i].ageSamples > oldestAge {
                    oldestAge = voices[i].ageSamples
                    targetIdx = i
                }
            }
            voices[targetIdx] = Voice(
                active: true,
                timbre: timbre,
                frequency: frequency,
                phase: 0.0,
                hammerPhase: 0.0,
                ageSamples: 0.0,
                delaySamples: delaySamps,
                velocity: max(0.03, min(1.0, velocity)),
                decaySeconds: max(0.25, min(4.5, decay)),
                brightness: max(0.2, min(1.4, brightness))
            )
        }
    }

    /// 随「物理水面高度（waterLevel 0...1）」弹奏富有生命力的错落琶音与低音托底，彻底告别死板电子琴柱式和弦。
    public func playWaterCradle(
        rootMIDI: Int,
        mode: ScaleMode,
        voicing: ChordVoicing,
        waterLevel: Double
    ) {
        let level = max(0.0, min(1.0, waterLevel))
        guard level >= 0.08 else { return }

        // 1. 深水底基：温暖低音大提琴/毛毡低音根音
        let bassHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: voicing.bassDegree, octaveOffset: voicing.bassOctave)
        let bassVel = 0.22 + level * 0.16
        playNote(frequency: bassHz, velocity: bassVel, decay: 2.5, brightness: 0.55, timbre: .warmBass, delaySeconds: 0.0)

        // 2. 水位 ≥ 0.28：依次绽放指尖错落琶音（相隔 38ms，像竖琴/温柔钢琴伴奏）
        guard level >= 0.28 else { return }
        let arpNotes = level >= 0.52 ? voicing.upperDegrees : Array(voicing.upperDegrees.prefix(2))
        for (idx, deg) in arpNotes.enumerated() {
            let oct = idx == 0 ? -1 : 0
            let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
            let delay = Double(idx + 1) * 0.038
            let vel = (0.14 + level * 0.10) * (idx == 0 ? 1.05 : 0.92)
            playNote(frequency: hz, velocity: vel, decay: 2.1, brightness: 0.78, timbre: .feltPiano, delaySeconds: delay)
        }

        // 3. 高水位（≥ 0.72）：拍尾浮现一粒晶莹的钢片琴/八音盒高八度星光泛音
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

    /// 弹奏指定调内三和弦，支持 4 种真实大师左手伴奏织体（天鹅水波 / 圆舞呼吸 / 夏日清风 / 柔和长音），
    /// 利用音频线程采样级延迟精准错落发声，零主线程抖动。
    public func playDiatonicChord(
        rootMIDI: Int,
        mode: ScaleMode,
        chord: DiatonicChord,
        texture: AccompanimentTexture = .swanRipple,
        spanDuration: Double = 1.6,
        intensity: Double = 0.82
    ) {
        let clamped = max(0.2, min(1.0, intensity))
        let dur = max(0.75, min(3.6, spanDuration))
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
            // 圣桑《天鹅》标志性流水波浪：低音铺底 + 6 粒细腻上下波动的竖琴/钢琴分解琶音
            playNote(frequency: bassHz, velocity: 0.25 * clamped, decay: dur * 1.35, brightness: 0.52, timbre: .warmBass, delaySeconds: 0.0)
            let pattern: [Double] = [bassHz, fifthHz, midRootHz, thirdHz, midRootHz, fifthHz]
            let stepSec = min(0.24, max(0.11, dur / Double(pattern.count)))
            for (idx, hz) in pattern.enumerated() {
                let vel = (idx == 0 ? 0.16 : (idx == 3 ? 0.18 : 0.14)) * clamped
                playNote(
                    frequency: hz,
                    velocity: vel,
                    decay: 1.55,
                    brightness: 0.78,
                    timbre: .feltPiano,
                    delaySeconds: Double(idx) * stepSec
                )
            }

        case .feltWaltz:
            // 三拍子浪漫圆舞（李斯特/肖邦/萨蒂）：第 1 拍深沉低音，第 2、3 拍轻柔托起双和弦
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
            // 东亚治愈电影风：开放 add9 透明分解 + 高音区钢片琴星光泛音
            let ninthDeg = ((rDeg) % 7) + 1
            let ninthHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: ninthDeg, octaveOffset: 0)
            let sparkleHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: fifthDeg, octaveOffset: 1)
            playNote(frequency: bassHz, velocity: 0.24 * clamped, decay: 2.4, brightness: 0.50, timbre: .warmBass, delaySeconds: 0.0)
            playNote(frequency: fifthHz, velocity: 0.18 * clamped, decay: 2.1, brightness: 0.82, timbre: .feltPiano, delaySeconds: 0.055)
            playNote(frequency: ninthHz, velocity: 0.17 * clamped, decay: 2.0, brightness: 0.88, timbre: .feltPiano, delaySeconds: 0.13)
            playNote(frequency: thirdHz, velocity: 0.16 * clamped, decay: 1.9, brightness: 0.86, timbre: .feltPiano, delaySeconds: 0.21)
            playNote(frequency: sparkleHz, velocity: 0.13 * clamped, decay: 1.5, brightness: 1.05, timbre: .celesta, delaySeconds: min(0.52, dur * 0.42))

        case .pureChorale:
            // 柔和长音：最清澈、稳定的三音叠加，方便零基础听清和弦内音
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

    /// 切换水面情绪色温时的一串清澈水波确认琶音
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
                timbre: idx == 3 ? .celesta : .feltPiano,
                delaySeconds: Double(idx + 1) * 0.055
            )
        }
    }
}
