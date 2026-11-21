import AVFAudio
import Foundation
import os

/// 低延迟纯代码温暖毛毡钢琴合成器（AVAudioEngine + AVAudioSourceNode + 空间混响）。
/// 音频渲染回调内零堆分配、锁粒度极短，无需外挂巨型 SF2 即可在首发版发出温润、带木锤柔击感的毛毡琴声。
public final class FeltPianoSynth {

    private struct Voice: Sendable {
        var active: Bool = false
        var frequency: Double = 440.0
        var phase: Double = 0.0
        var ageSamples: Double = 0.0
        var velocity: Double = 0.5
        var decaySeconds: Double = 1.8
        var brightness: Double = 1.0
    }

    private let maxVoices = 20
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44_100.0
    private let router: HalfDuplexAudioRouter

    // 预分配固定长度声部数组，渲染线程绝不分配内存
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
                let attackSamples = 0.012 * sr

                for i in 0..<count {
                    var mixL = 0.0
                    var mixR = 0.0

                    for vIdx in 0..<voices.count {
                        if !voices[vIdx].active { continue }
                        let age = voices[vIdx].ageSamples
                        let ageSec = age * invSR
                        let decay = voices[vIdx].decaySeconds
                        if ageSec > decay * 2.4 {
                            voices[vIdx].active = false
                            continue
                        }

                        // 柔和毛毡起音 + 双段自然指数衰减
                        let envAttack = min(1.0, age / attackSamples)
                        let envDecay = exp(-ageSec / (decay * 0.48))
                        let env = envAttack * envDecay * voices[vIdx].velocity

                        let ph = voices[vIdx].phase
                        // 温暖毛毡泛音配方：厚实基频 + 柔滑 2 次 + 随时间快速变暗的 3/4 次泛音
                        let bright = exp(-ageSec * 3.8) * voices[vIdx].brightness
                        let sample = (
                            sin(ph) * 0.72 +
                            sin(ph * 2.0) * (0.19 * (0.45 + 0.55 * bright)) +
                            sin(ph * 3.0) * (0.065 * bright) +
                            sin(ph * 4.0) * (0.025 * bright * bright)
                        ) * env

                        // 按音高轻微立体声展宽（低音偏左、高音偏右，模拟坐于钢琴前的真实听感）
                        let pan = max(-0.35, min(0.35, (log2(voices[vIdx].frequency / 261.63)) * 0.16))
                        mixL += sample * (0.5 - pan * 0.5)
                        mixR += sample * (0.5 + pan * 0.5)

                        voices[vIdx].phase += twoPi * voices[vIdx].frequency * invSR
                        if voices[vIdx].phase > twoPi * 1024.0 {
                            voices[vIdx].phase.formTruncatingRemainder(dividingBy: twoPi)
                        }
                        voices[vIdx].ageSamples += 1.0
                    }

                    // 柔和软限幅防多声部削波爆音
                    let outL = Float(tanh(mixL * 0.85))
                    let outR = Float(tanh(mixR * 0.85))
                    leftPtr[i] = outL
                    rightPtr?[i] = outR
                }
            }
            return noErr
        }

        sourceNode = node
        reverb.loadFactoryPreset(.mediumHall2)
        reverb.wetDryMix = 26.0

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
            // 模拟器无音频输出硬件时静默降级，不崩溃
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

    public func playNote(frequency: Double, velocity: Double = 0.55, decay: Double = 1.6, brightness: Double = 0.9) {
        ensureRunning()
        guard frequency.isFinite && frequency >= 32.0 && frequency <= 4200.0 else { return }

        lock.withLock { voices in
            // 优先寻找空闲声部，否则复用最老声部
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
                frequency: frequency,
                phase: 0.0,
                ageSamples: 0.0,
                velocity: max(0.05, min(1.0, velocity)),
                decaySeconds: max(0.25, min(4.0, decay)),
                brightness: max(0.2, min(1.4, brightness))
            )
        }
    }

    public func playChord(
        rootMIDI: Int,
        mode: ScaleMode,
        voicing: ChordVoicing,
        intensity: Double = 1.0
    ) {
        let bassHz = mode.frequencyHz(rootMIDI: rootMIDI, degree: voicing.bassDegree, octaveOffset: voicing.bassOctave)
        playNote(frequency: bassHz, velocity: 0.28 * intensity, decay: 2.2, brightness: 0.55)

        for (idx, deg) in voicing.upperDegrees.enumerated() {
            let oct = idx == 0 ? -1 : 0
            let hz = mode.frequencyHz(rootMIDI: rootMIDI, degree: deg, octaveOffset: oct)
            playNote(frequency: hz, velocity: 0.16 * intensity, decay: 1.9, brightness: 0.72)
        }
    }
}
