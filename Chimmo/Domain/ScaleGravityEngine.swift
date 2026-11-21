import Foundation

/// 调性引力吸附、音程压缩幽灵备选珠推荐、以及边听边拍（Tap-Along）无损重拍对齐引擎。
public enum ScaleGravityEngine {

    public struct SnappedResult: Sendable {
        public let rootMIDI: Int
        public let mode: ScaleMode
        public let notes: [NoteBead]
    }

    /// 将任意物理 Hz 音符串转换为相对调式引力陶珠：
    /// 1. 在 12 个主音 × 大小调中寻找加权音程残差最小的归宿；
    /// 2. 对偏离 > 22 cents 或涉及大跳压缩风险的音符自动附带调内相邻音级「幽灵备选珠」。
    public static func snapToGravityScale(
        rawNotes: [SegmentedNote],
        preferredMode: ScaleMode? = nil
    ) -> SnappedResult {
        guard !rawNotes.isEmpty else {
            return SnappedResult(rootMIDI: 60, mode: preferredMode ?? .brightMajor, notes: [])
        }

        let midiValues = rawNotes.map { 69.0 + 12.0 * log2(max(20.0, $0.pitchHz) / 440.0) }
        let medianMIDI = midiValues.sorted()[midiValues.count / 2]
        let baseOctave = Int(floor(medianMIDI / 12.0)) * 12

        let candidateModes: [ScaleMode] = preferredMode.map { [$0] } ?? [.brightMajor, .wistfulMinor]
        var bestRoot = 60
        var bestMode: ScaleMode = candidateModes[0]
        var bestLoss = Double.infinity

        for mode in candidateModes {
            let offsets = mode.semitoneOffsets
            for pc in 0..<12 {
                var loss = 0.0
                for (idx, m) in midiValues.enumerated() {
                    let rel = positiveMod(m - Double(pc), 12.0)
                    let dist = offsets.map { circularSemitoneDistance(rel, Double($0)) }.min() ?? 6.0
                    let weight = max(0.15, rawNotes[idx].duration)
                    // 优先让结尾落音停在主音 1 或属音 5 上，符合自然乐句归属感
                    let cadenceBonus = (idx == midiValues.count - 1 && (dist < 0.45 && (circularSemitoneDistance(rel, 0) < 0.45 || circularSemitoneDistance(rel, 7) < 0.45))) ? -0.18 : 0.0
                    loss += dist * weight + cadenceBonus
                }
                if loss < bestLoss {
                    bestLoss = loss
                    bestMode = mode
                    bestRoot = nearestRootMIDI(pitchClass: pc, around: baseOctave)
                }
            }
        }

        let t0 = rawNotes.first?.start ?? 0.0
        var beads: [NoteBead] = []
        let offsets = bestMode.semitoneOffsets

        for (idx, raw) in rawNotes.enumerated() {
            let m = midiValues[idx]
            let (deg, oct, errSemitones) = nearestScaleStep(midi: m, rootMIDI: bestRoot, offsets: offsets)

            var ghosts: [GhostCandidate] = []
            // 若偏离 > 0.22 半音，或前后出现 ≥3 级跳跃（业余者易唱扁大跳，参见 Pfordresher 2007），给出调内邻音幽灵珠
            let prevDeg = beads.last?.degree
            let isLargeLeap = prevDeg.map { abs(deg - $0) >= 3 } ?? false
            if abs(errSemitones) > 0.22 || isLargeLeap {
                let dir = errSemitones >= 0 ? 1 : -1
                let primaryNeighbor = stepScale(degree: deg, octave: oct, delta: dir)
                ghosts.append(GhostCandidate(degree: primaryNeighbor.0, octaveOffset: primaryNeighbor.1))
                if abs(errSemitones) > 0.38 || isLargeLeap {
                    let secondary = stepScale(degree: deg, octave: oct, delta: -dir)
                    ghosts.append(GhostCandidate(degree: secondary.0, octaveOffset: secondary.1))
                }
            }

            beads.append(
                NoteBead(
                    degree: deg,
                    octaveOffset: oct,
                    rawOnset: max(0, raw.start - t0),
                    rawDuration: max(0.12, raw.duration),
                    confidence: raw.confidence,
                    ghostCandidates: ghosts
                )
            )
        }

        return SnappedResult(rootMIDI: bestRoot, mode: bestMode, notes: beads)
    }

    /// 边听边拍（Tap-Along）无损重拍对齐：
    /// 用中位步长过滤拍歪的离群点，同时锚定 BPM 与强拍相位，不破坏 rawOnset / rawDuration。
    public static func applyTapAlongGrid(
        notes: [NoteBead],
        tapTimestamps: [Double]
    ) -> (bpm: Double, alignedNotes: [NoteBead])? {
        let sortedTaps = tapTimestamps.sorted()
        guard sortedTaps.count >= 3 else { return nil }

        var intervals: [Double] = []
        for i in 1..<sortedTaps.count {
            let dt = sortedTaps[i] - sortedTaps[i - 1]
            if dt >= 0.25 && dt <= 1.5 { // 40–240 BPM
                intervals.append(dt)
            }
        }
        guard !intervals.isEmpty else { return nil }
        intervals.sort()
        let beatSec = intervals[intervals.count / 2]
        let bpm = max(45.0, min(200.0, 60.0 / beatSec))

        // 取首拍作为重拍锚点，对齐至半拍（八分音符）网格
        let phase = sortedTaps[0]
        let gridStep = beatSec / 2.0

        let aligned = notes.map { note -> NoteBead in
            var copy = note
            let relOnset = note.rawOnset - phase
            let snappedOnset = max(0, phase + (relOnset / gridStep).rounded() * gridStep)
            let snappedDur = max(gridStep, (note.rawDuration / gridStep).rounded() * gridStep)
            copy.quantizedOnset = snappedOnset
            copy.quantizedDuration = snappedDur
            return copy
        }

        return (bpm, aligned)
    }

    // MARK: - Helpers

    private static func positiveMod(_ a: Double, _ m: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }

    private static func circularSemitoneDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        return min(d, 12.0 - d)
    }

    private static func nearestRootMIDI(pitchClass: Int, around baseOctave: Int) -> Int {
        let candidates = [baseOctave - 12 + pitchClass, baseOctave + pitchClass, baseOctave + 12 + pitchClass]
        let chosen = candidates.min(by: { abs($0 - 60) < abs($1 - 60) }) ?? (60 + pitchClass)
        return max(48, min(71, chosen))
    }

    private static func nearestScaleStep(midi: Double, rootMIDI: Int, offsets: [Int]) -> (Int, Int, Double) {
        var bestDeg = 1
        var bestOct = 0
        var bestErr = Double.infinity

        for oct in -1...1 {
            for idx in 0..<7 {
                let target = Double(rootMIDI + offsets[idx] + oct * 12)
                let err = midi - target
                if abs(err) < abs(bestErr) {
                    bestErr = err
                    bestDeg = idx + 1
                    bestOct = oct
                }
            }
        }
        return (bestDeg, bestOct, bestErr)
    }

    private static func stepScale(degree: Int, octave: Int, delta: Int) -> (Int, Int) {
        let linear = octave * 7 + (degree - 1) + delta
        let clamped = max(-7, min(13, linear))
        let newOct = Int(floor(Double(clamped) / 7.0))
        let newDeg = clamped - newOct * 7 + 1
        return (max(1, min(7, newDeg)), max(-1, min(1, newOct)))
    }
}
