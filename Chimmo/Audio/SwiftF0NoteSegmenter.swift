import Foundation

/// 单音基频逐帧输出（与 MIT 开源 SwiftF0 保持相同帧率口径：16 kHz / 256 hop = 16 ms）。
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

public struct SegmentedNote: Sendable, Equatable {
    public let start: Double
    public let end: Double
    public let pitchHz: Double
    public let confidence: Double

    public var duration: Double { max(0.0, end - start) }

    public init(start: Double, end: Double, pitchHz: Double, confidence: Double = 1.0) {
        self.start = start
        self.end = end
        self.pitchHz = pitchHz
        self.confidence = confidence
    }
}

/// 精确移植自 lars76/swift-f0 (`swift_f0/music.py`, MIT License) 的动态规划音符切分算法。
/// 核心优势：利用 ±64ms 内响度谷值 (>3 dB) 惩罚项，精准切分“连续哼唱相同音高（如 da-da-da）”的重复音。
public enum SwiftF0NoteSegmenter {

    public static func segmentNotes(
        from contour: PitchContour,
        pitchHoldMs: Double = 80.0
    ) -> [SegmentedNote] {
        let n = contour.timestamps.count
        guard n > 0,
              contour.pitchHz.count == n,
              contour.confidence.count == n,
              contour.loudnessDB.count == n
        else { return [] }

        var midi = [Double](repeating: 0.0, count: n)
        var weights = [Double](repeating: 0.0, count: n)
        var uniqueCentSet = Set<Int>()

        for i in 0..<n {
            let f = contour.pitchHz[i]
            let c = min(1.0, max(0.0, contour.confidence[i]))
            if f.isFinite && f > 0 {
                let m = 69.0 + 12.0 * log2(f / 440.0)
                midi[i] = m
                weights[i] = c
                if c > 0.15 {
                    uniqueCentSet.insert(Int(floor(m * 100.0 + 0.5)))
                }
            }
        }

        guard !uniqueCentSet.isEmpty else { return [] }

        // 限制候选音高网格最多 320 个（在 ±10 秒手机哼唱场景下保底毫秒级完成）
        var mu: [Double]
        if uniqueCentSet.count > 320 {
            let sorted = uniqueCentSet.sorted()
            let strideStep = max(1, sorted.count / 320)
            mu = stride(from: 0, to: sorted.count, by: strideStep).map { Double(sorted[$0]) / 100.0 }
        } else {
            mu = uniqueCentSet.sorted().map { Double($0) / 100.0 }
        }

        // ±4 帧（±64 ms）对称填充计算局部响度谷值惩罚
        let pad = 4
        func paddedLevel(_ idx: Int) -> Double {
            if idx < 0 { return contour.loudnessDB[min(n - 1, -idx - 1)] }
            if idx >= n { return contour.loudnessDB[max(0, 2 * n - 1 - idx)] }
            return contour.loudnessDB[idx]
        }

        let threeDB = 10.0 * log10(2.0) // ~3.0103 dB
        var framePenalty = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            let cc = min(0.99, max(0.01, weights[i]))
            let unvoiced = -log(cc / (1.0 - cc))
            var leftMax = -Double.infinity
            var rightMax = -Double.infinity
            for k in 0...pad {
                leftMax = max(leftMax, paddedLevel(i - pad + k))
                rightMax = max(rightMax, paddedLevel(i + k))
            }
            let quiet = max(0.0, min(leftMax, rightMax) - contour.loudnessDB[i] - threeDB)
            framePenalty[i] = unvoiced + quiet
        }

        let beta = max(0.0, pitchHoldMs) / 1000.0 / PitchContour.framePeriod
        let mCount = mu.count

        var vn = [Double](repeating: .infinity, count: mCount)
        var noteStart = [Int](repeating: 0, count: mCount)
        var back = [Int](repeating: 0, count: n + 1)
        var kind = [Int](repeating: -1, count: n + 1)
        var best = 0.0

        for t in 0..<n {
            let startCost = best + beta
            let mt = midi[t]
            let wt = weights[t]
            let qt = framePenalty[t]

            var bestIdx = -1
            var bestVal = Double.infinity

            for j in 0..<mCount {
                if startCost < vn[j] {
                    vn[j] = startCost
                    noteStart[j] = t
                }
                let offpitch = wt * min(abs(mu[j] - mt), 2.0)
                let updated = vn[j] + offpitch + qt
                vn[j] = updated
                if updated < bestVal {
                    bestVal = updated
                    bestIdx = j
                }
            }

            if bestIdx >= 0 && bestVal < best {
                best = bestVal
                back[t + 1] = noteStart[bestIdx]
                kind[t + 1] = bestIdx
            } else {
                back[t + 1] = t
                kind[t + 1] = -1
            }
        }

        var notes: [SegmentedNote] = []
        var b = n
        while b > 0 {
            let a = back[b]
            let k = kind[b]
            if k >= 0 {
                let hz = 440.0 * pow(2.0, (mu[k] - 69.0) / 12.0)
                let sliceConf = weights[a..<b].reduce(0.0, +) / Double(max(1, b - a))
                let startSec = contour.timestamps[a]
                let endSec = contour.timestamps[b - 1] + PitchContour.framePeriod
                notes.append(SegmentedNote(start: startSec, end: endSec, pitchHz: hz, confidence: sliceConf))
            }
            b = a
        }

        notes.reverse()
        return notes
    }
}
