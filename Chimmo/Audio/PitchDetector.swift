import Accelerate
import Foundation

/// 端侧单音基频估计协议（统一支撑 vDSP YIN 零依赖基线与后续 SwiftF0 CoreML/ONNX A/B 切换）。
public protocol PitchDetector: Sendable {
    var displayName: String { get }
    func detect(mono16kSamples: [Float], fmin: Double, fmax: Double) -> PitchContour
}

/// 纯 Swift + Accelerate/vDSP 零依赖 YIN (CMNDF + 抛物线插值 + AGC 归一化 + 静音/响度门限)。
/// 保证 iOS 27 首发零第三方二进制依赖即可在真机上完成 16 kHz 单音哼唱追踪与单元测试验证。
public struct YINvDSPPitchDetector: PitchDetector {
    public let displayName = "YIN-vDSP (离线零依赖)"

    private let silencePeakThreshold: Float = 0.0025
    private let yinThreshold: Float = 0.16

    public init() {}

    public func detect(
        mono16kSamples: [Float],
        fmin: Double = 75.0,
        fmax: Double = 1100.0
    ) -> PitchContour {
        let sr = PitchContour.sampleRate
        let hop = PitchContour.hopSize
        let windowSize = 1024 // 64 ms 窗口，覆盖至 ~62 Hz 低男声基频
        guard mono16kSamples.count >= hop else {
            return PitchContour(timestamps: [], pitchHz: [], confidence: [], loudnessDB: [])
        }

        // 前置柔和 AGC 峰值归一化（解决深夜轻声哼唱 < -35 dBFS 漏检问题，同时保留绝对静音过滤）
        var maxPeak: Float = 0.0
        vDSP_maxmgv(mono16kSamples, 1, &maxPeak, vDSP_Length(mono16kSamples.count))
        let gain: Float = (maxPeak > silencePeakThreshold) ? min(14.0, 0.75 / maxPeak) : 1.0
        var samples = [Float](repeating: 0, count: mono16kSamples.count)
        if gain != 1.0 {
            var g = gain
            vDSP_vsmul(mono16kSamples, 1, &g, &samples, 1, vDSP_Length(mono16kSamples.count))
        } else {
            samples = mono16kSamples
        }

        let nFrames = max(1, samples.count / hop)
        let minLag = max(2, Int(floor(sr / fmax)))
        let maxLag = min(windowSize / 2 - 1, Int(ceil(sr / fmin)))
        guard minLag < maxLag else {
            return PitchContour(timestamps: [], pitchHz: [], confidence: [], loudnessDB: [])
        }

        var timestamps = [Double](repeating: 0, count: nFrames)
        var pitches = [Double](repeating: 0, count: nFrames)
        var confidences = [Double](repeating: 0, count: nFrames)
        var loudness = [Double](repeating: -120, count: nFrames)

        var frameBuf = [Float](repeating: 0, count: windowSize)
        var diff = [Float](repeating: 0, count: maxLag + 1)
        var cmndf = [Float](repeating: 1, count: maxLag + 1)
        var tempDiff = [Float](repeating: 0, count: windowSize / 2)

        let halfW = windowSize / 2

        for f in 0..<nFrames {
            timestamps[f] = Double(f) * PitchContour.framePeriod
            let center = f * hop
            let start = center - halfW

            // 拷贝窗口（越界补零）
            var framePeak: Float = 0.0
            for i in 0..<windowSize {
                let idx = start + i
                let v: Float = (idx >= 0 && idx < samples.count) ? samples[idx] : 0.0
                frameBuf[i] = v
                let av = abs(v)
                if av > framePeak { framePeak = av }
            }

            // 32 ms 居中 RMS 响度（与 SwiftF0 loudness_db 同口径）
            let rmsStart = max(0, center - hop)
            let rmsEnd = min(samples.count, center + hop)
            var sumSq: Float = 0.0
            if rmsEnd > rmsStart {
                samples.withUnsafeBufferPointer { ptr in
                    vDSP_svesq(ptr.baseAddress! + rmsStart, 1, &sumSq, vDSP_Length(rmsEnd - rmsStart))
                }
            }
            let rms = sqrt(Double(sumSq) / Double(max(1, rmsEnd - rmsStart)))
            loudness[f] = 20.0 * log10(max(rms, 1e-7))

            // 静音门限过滤
            if framePeak < silencePeakThreshold * gain || loudness[f] < -46.0 {
                pitches[f] = 0.0
                confidences[f] = 0.0
                continue
            }

            // YIN 差分函数 d(tau) = sum((x[j] - x[j+tau])^2) via vDSP
            diff[0] = 0.0
            cmndf[0] = 1.0
            var runningSum: Float = 0.0

            frameBuf.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                for tau in 1...maxLag {
                    vDSP_vsub(base + tau, 1, base, 1, &tempDiff, 1, vDSP_Length(halfW))
                    var sq: Float = 0.0
                    vDSP_svesq(tempDiff, 1, &sq, vDSP_Length(halfW))
                    diff[tau] = sq
                    runningSum += sq
                    cmndf[tau] = runningSum > 1e-9 ? (sq * Float(tau) / runningSum) : 1.0
                }
            }

            // 绝对阈值搜索首个局部极小值
            var chosenTau = -1
            var tau = minLag
            while tau <= maxLag {
                if cmndf[tau] < yinThreshold {
                    while tau + 1 <= maxLag && cmndf[tau + 1] < cmndf[tau] {
                        tau += 1
                    }
                    chosenTau = tau
                    break
                }
                tau += 1
            }

            // 回退取全局极小值（低置信度）
            if chosenTau < 0 {
                var minVal: Float = 1.0
                for t in minLag...maxLag where cmndf[t] < minVal {
                    minVal = cmndf[t]
                    chosenTau = t
                }
            }

            guard chosenTau >= minLag && chosenTau <= maxLag else {
                pitches[f] = 0.0
                confidences[f] = 0.0
                continue
            }

            // 三点抛物线插值提升亚采样音准精度（< 5 cents）
            var refinedTau = Double(chosenTau)
            if chosenTau > minLag && chosenTau < maxLag {
                let s0 = Double(cmndf[chosenTau - 1])
                let s1 = Double(cmndf[chosenTau])
                let s2 = Double(cmndf[chosenTau + 1])
                let denom = (s0 - 2.0 * s1 + s2)
                if abs(denom) > 1e-9 {
                    let delta = 0.5 * (s0 - s2) / denom
                    if abs(delta) <= 1.0 {
                        refinedTau += delta
                    }
                }
            }

            let minCMNDF = Double(cmndf[chosenTau])
            let conf = max(0.0, min(1.0, 1.0 - minCMNDF * 2.2))
            if conf >= 0.35 && refinedTau > 0 {
                pitches[f] = sr / refinedTau
                confidences[f] = conf
            } else {
                pitches[f] = 0.0
                confidences[f] = conf * 0.4
            }
        }

        // 3 帧中位滤波消除孤立八度跳变毛刺
        let smoothedPitches = medianFilterOctaveGuard(pitches: pitches, confidences: confidences)
        return PitchContour(
            timestamps: timestamps,
            pitchHz: smoothedPitches,
            confidence: confidences,
            loudnessDB: loudness
        )
    }

    private func medianFilterOctaveGuard(pitches: [Double], confidences: [Double]) -> [Double] {
        guard pitches.count >= 3 else { return pitches }
        var out = pitches
        for i in 1..<(pitches.count - 1) {
            let a = pitches[i - 1], b = pitches[i], c = pitches[i + 1]
            if a > 0 && b > 0 && c > 0 && confidences[i] > 0.3 {
                let sorted = [a, b, c].sorted()
                out[i] = sorted[1]
            }
        }
        return out
    }
}
