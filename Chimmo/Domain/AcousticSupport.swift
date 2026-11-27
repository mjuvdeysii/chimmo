import CoreGraphics
import Foundation

/// Active live pitch smoothing, normalization, and acoustic space shaping helpers.
public enum LivePitchContourFilter {
    public static func adaptiveNoiseFloorRMS(peakRMS: Double) -> Double {
        guard peakRMS.isFinite, peakRMS > 0 else { return 0.004 }
        return max(0.004, peakRMS * 0.12)
    }

    public static func medianSmooth(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }
        var out = values
        for i in 1..<(values.count - 1) {
            let a = values[i - 1], b = values[i], c = values[i + 1]
            if a.isFinite && b.isFinite && c.isFinite {
                out[i] = [a, b, c].sorted()[1]
            }
        }
        return out
    }

    public static func normalizeSemitoneTrace(_ rawSemitones: [Double]) -> [Double] {
        let valid = rawSemitones.filter { $0.isFinite }
        guard !valid.isEmpty else { return [] }
        let smoothed = medianSmooth(valid)
        guard let lo = smoothed.min(), let hi = smoothed.max() else { return [] }
        let span = hi - lo
        if span < 0.8 {
            return Array(repeating: 0.48, count: smoothed.count)
        }
        let effSpan = max(4.0, span)
        let mid = (lo + hi) * 0.5
        return smoothed.map { val in
            let norm = 0.5 + (val - mid) / effSpan
            return max(0.08, min(0.92, norm))
        }
    }

    public static func frameRMS(mono16kSamples: [Float], frameCount: Int, hopSize: Int) -> [Double] {
        guard frameCount > 0, !mono16kSamples.isEmpty else { return [] }
        let n = mono16kSamples.count
        var result = [Double](repeating: 0.0, count: frameCount)
        let halfWin = max(64, hopSize)
        for f in 0..<frameCount {
            let center = f * hopSize
            let lo = max(0, center - halfWin)
            let hi = min(n, center + halfWin)
            guard hi > lo else { continue }
            var sumSq = 0.0
            for idx in lo..<hi {
                let s = Double(mono16kSamples[idx])
                sumSq += s * s
            }
            result[f] = sqrt(sumSq / Double(hi - lo))
        }
        return result
    }

    public static func extractVoicedSemitones(
        pitchHz: [Double],
        confidence: [Double],
        frameRMS: [Double]
    ) -> [Double] {
        let peak = frameRMS.filter { $0.isFinite }.max() ?? 0.0
        let gate = adaptiveNoiseFloorRMS(peakRMS: peak)
        var voiced: [Double] = []
        voiced.reserveCapacity(pitchHz.count)
        for i in 0..<pitchHz.count {
            let hz = pitchHz[i]
            let conf = i < confidence.count ? confidence[i] : 1.0
            let rms = i < frameRMS.count ? frameRMS[i] : peak
            if hz.isFinite && hz > 65.0 && conf >= 0.32 && rms >= gate {
                voiced.append(12.0 * log2(hz / 110.0))
            }
        }
        return medianSmooth(voiced)
    }
}

/// Modal acoustic space climate for specimen playback and resonance field depth.
public struct AcousticSpaceProfile: Equatable, Sendable {
    public let reverbWetMix: Float
    public let warmthDamping: Double
    public let stereoSpread: Double

    public init(reverbWetMix: Float, warmthDamping: Double, stereoSpread: Double) {
        self.reverbWetMix = reverbWetMix
        self.warmthDamping = warmthDamping
        self.stereoSpread = stereoSpread
    }

    public static func profile(for mode: ScaleMode) -> AcousticSpaceProfile {
        switch mode {
        case .cloudLydian:
            return AcousticSpaceProfile(reverbWetMix: 38.0, warmthDamping: 0.94, stereoSpread: 1.22)
        case .brightMajor:
            return AcousticSpaceProfile(reverbWetMix: 22.0, warmthDamping: 1.08, stereoSpread: 1.00)
        case .goldenMixolydian:
            return AcousticSpaceProfile(reverbWetMix: 27.0, warmthDamping: 0.90, stereoSpread: 1.06)
        case .forestDorian:
            return AcousticSpaceProfile(reverbWetMix: 31.0, warmthDamping: 0.98, stereoSpread: 1.12)
        case .wistfulMinor:
            return AcousticSpaceProfile(reverbWetMix: 35.0, warmthDamping: 0.86, stereoSpread: 1.14)
        }
    }
}

public enum StageVisualMode: String, CaseIterable, Sendable {
    case orbitalDisc
    case flowingRiver
    case resonanceNebula
}

/// Gentle spatial panorama curve across specimen playback progress.
public enum AcousticSpatialPanMapper {
    public static func pan(forBeatOnset onset: Double, totalDuration: Double, visualMode: StageVisualMode) -> Double {
        guard onset.isFinite, totalDuration.isFinite, totalDuration > 0.05 else {
            return 0.0
        }
        let progress = max(0.0, min(1.0, onset / totalDuration))
        let angle = -Double.pi * 0.5 + progress * Double.pi * 2.0
        let raw: Double
        switch visualMode {
        case .orbitalDisc:
            raw = sin(angle) * 0.44
        case .flowingRiver:
            raw = (progress * 2.0 - 1.0) * 0.48
        case .resonanceNebula:
            raw = cos(angle) * 0.36 + sin(angle * 2.0) * 0.14
        }
        return max(-0.58, min(0.58, raw))
    }
}

/// Frequency-dependent string decay & air absorption envelope.
public enum PitchScaledAcousticEnvelope {
    public static func scaledDecay(baseDecay: Double, frequency: Double) -> Double {
        let safeDecay = baseDecay.isFinite ? max(0.25, min(4.8, baseDecay)) : 1.5
        let safeFreq = frequency.isFinite ? max(40.0, min(4800.0, frequency)) : 261.63
        let factor = max(0.58, min(1.38, pow(261.63 / safeFreq, 0.28)))
        return max(0.22, min(5.4, safeDecay * factor))
    }

    public static func highFrequencyAirAbsorption(frequency: Double) -> Double {
        let safeFreq = frequency.isFinite ? max(40.0, min(4800.0, frequency)) : 261.63
        return max(0.68, min(1.18, pow(261.63 / safeFreq, 0.16)))
    }
}

/// Kiln cotton-paper horizon geometry for rolling acoustic hills.
public enum KilnLandscapeGeometry {
    public struct HillCrestPoint: Equatable, Sendable {
        public let xFraction: Double
        public let yFraction: Double

        public init(xFraction: Double, yFraction: Double) {
            self.xFraction = xFraction
            self.yFraction = yFraction
        }
    }

    public static func rollingHillProfile(
        sampleCount: Int,
        amplitude: Double,
        phaseShift: Double
    ) -> [HillCrestPoint] {
        guard sampleCount > 0 else { return [] }
        if sampleCount == 1 {
            return [HillCrestPoint(xFraction: 0.0, yFraction: 0.5)]
        }
        let safeAmp = amplitude.isFinite ? max(0.0, min(0.42, amplitude)) : 0.14
        let safePhase = phaseShift.isFinite ? phaseShift : 0.0
        let denom = Double(sampleCount - 1)
        return (0..<sampleCount).map { idx in
            let u = Double(idx) / denom
            let wave = sin(u * Double.pi * 2.2 + safePhase) * 0.65 + cos(u * Double.pi * 1.1 + safePhase * 0.5) * 0.35
            let y = max(0.05, min(0.95, 0.55 - wave * safeAmp))
            return HillCrestPoint(xFraction: u, yFraction: y)
        }
    }
}
