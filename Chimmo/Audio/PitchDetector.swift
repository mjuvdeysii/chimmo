import Accelerate
import Foundation

/// 16 kHz / 256-hop monophonic pitch contour frame representation.
public struct PitchContour: Sendable, Equatable {
    public static let sampleRate: Double = 16_000.0
    public static let hopSize: Int = 256
    public static let framePeriod: Double = Double(hopSize) / sampleRate // 0.016 s

    public let timestamps: [Double]
    public let pitchHz: [Double]
    public let confidence: [Double]
    public let loudnessDB: [Double]

    public init(timestamps: [Double], pitchHz: [Double], confidence: [Double], loudnessDB: [Double]) {
        self.timestamps = timestamps
        self.pitchHz = pitchHz
        self.confidence = confidence
        self.loudnessDB = loudnessDB
    }
}

/// Offline monophonic fundamental-frequency estimation protocol.
public protocol PitchDetector: Sendable {
    var displayName: String { get }
    func detect(mono16kSamples: [Float], fmin: Double, fmax: Double) -> PitchContour
}

/// Pure Swift + Accelerate/vDSP offline YIN detector (CMNDF + parabolic interpolation + pre-AGC silence gate).
public struct YINvDSPPitchDetector: PitchDetector {
    public var displayName: String {
        String(localized: "pitch_detector_yin_name", defaultValue: "YIN-vDSP（离线零依赖）")
    }

    private let silencePeakThreshold: Float = 0.0025
    private let unscaledSilenceFloorDB: Double = -46.0
    private let yinThreshold: Float = 0.16

    public init() {}

    public func detect(
        mono16kSamples: [Float],
        fmin: Double = 75.0,
        fmax: Double = 1100.0
    ) -> PitchContour {
        let sr = PitchContour.sampleRate
        let hop = PitchContour.hopSize
        let windowSize = 1024 // 64 ms window
        guard mono16kSamples.count >= hop,
              fmin.isFinite, fmax.isFinite,
              fmin >= 20.0, fmax > fmin, fmax <= sr * 0.49 else {
            return PitchContour(timestamps: [], pitchHz: [], confidence: [], loudnessDB: [])
        }

        // Sanitize non-finite samples before DSP work.
        let cleanRaw: [Float]
        if mono16kSamples.contains(where: { !$0.isFinite }) {
            cleanRaw = mono16kSamples.map { $0.isFinite ? $0 : 0.0 }
        } else {
            cleanRaw = mono16kSamples
        }

        var maxPeak: Float = 0.0
        vDSP_maxmgv(cleanRaw, 1, &maxPeak, vDSP_Length(cleanRaw.count))
        let gain: Float = (maxPeak > silencePeakThreshold) ? min(14.0, 0.75 / maxPeak) : 1.0

        var samples = [Float](repeating: 0, count: cleanRaw.count)
        if gain != 1.0 {
            var g = gain
            vDSP_vsmul(cleanRaw, 1, &g, &samples, 1, vDSP_Length(cleanRaw.count))
        } else {
            samples = cleanRaw
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
        var cmndf = [Float](repeating: 1, count: maxLag + 1)
        var tempDiff = [Float](repeating: 0, count: windowSize / 2)

        let halfW = windowSize / 2

        for f in 0..<nFrames {
            timestamps[f] = Double(f) * PitchContour.framePeriod
            let center = f * hop
            let start = center - halfW

            // Measure pre-AGC window peak & RMS loudness so quiet noise floors stay gated.
            var rawFramePeak: Float = 0.0
            for i in 0..<windowSize {
                let idx = start + i
                if idx >= 0 && idx < cleanRaw.count {
                    frameBuf[i] = samples[idx]
                    let av = abs(cleanRaw[idx])
                    if av > rawFramePeak { rawFramePeak = av }
                } else {
                    frameBuf[i] = 0.0
                }
            }

            let rmsStart = max(0, center - hop)
            let rmsEnd = min(cleanRaw.count, center + hop)
            var sumSq: Float = 0.0
            if rmsEnd > rmsStart {
                cleanRaw.withUnsafeBufferPointer { ptr in
                    if let base = ptr.baseAddress {
                        vDSP_svesq(base + rmsStart, 1, &sumSq, vDSP_Length(rmsEnd - rmsStart))
                    }
                }
            }
            let rawRMS = sqrt(Double(sumSq) / Double(max(1, rmsEnd - rmsStart)))
            let rawDB = 20.0 * log10(max(rawRMS, 1e-7))
            loudness[f] = rawDB

            if rawFramePeak < silencePeakThreshold || rawDB < unscaledSilenceFloorDB {
                pitches[f] = 0.0
                confidences[f] = 0.0
                continue
            }

            cmndf[0] = 1.0
            var runningSum: Float = 0.0

            frameBuf.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                for tau in 1...maxLag {
                    vDSP_vsub(base + tau, 1, base, 1, &tempDiff, 1, vDSP_Length(halfW))
                    var sq: Float = 0.0
                    vDSP_svesq(tempDiff, 1, &sq, vDSP_Length(halfW))
                    runningSum += sq
                    cmndf[tau] = runningSum > 1e-9 ? (sq * Float(tau) / runningSum) : 1.0
                }
            }

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
