import XCTest
@testable import Chimmo

final class PitchAndGravityTests: XCTestCase {

    private func makeSine(freq: Double, durationSec: Double, amplitude: Float = 0.4) -> [Float] {
        let sr = PitchContour.sampleRate
        let count = Int(sr * durationSec)
        return (0..<count).map { i in
            amplitude * sin(Float(2.0 * Double.pi * freq * Double(i) / sr))
        }
    }

    func testYINvDSPDetectsQuietLateNightHumWithin15Cents() {
        // 模拟深夜轻声哼唱（-26 dBFS 低振幅）验证 AGC 归一化与 YIN 精度
        let targetHz = 329.63 // E4
        let samples = makeSine(freq: targetHz, durationSec: 0.65, amplitude: 0.05)
        let detector = YINvDSPPitchDetector()

        let contour = detector.detect(mono16kSamples: samples)
        let notes = SwiftF0NoteSegmenter.segmentNotes(from: contour, pitchHoldMs: 80.0)

        XCTAssertEqual(notes.count, 1)
        if let first = notes.first {
            let centsError = abs(1200.0 * log2(first.pitchHz / targetHz))
            XCTAssertLessThan(centsError, 15.0, "音准误差应小于 15 cents，实际为 \(centsError)")
        }
    }

    func testDriftedAmateurMelodyProducesGhostCandidates() {
        // C4 -> 略微唱偏 32 cents 的 E4 -> 大跳至 G4 -> 归家 C4
        let driftedE4 = 329.63 * pow(2.0, -32.0 / 1200.0)
        let raw = [
            SegmentedNote(start: 0.0, end: 0.4, pitchHz: 261.63),
            SegmentedNote(start: 0.45, end: 0.85, pitchHz: driftedE4),
            SegmentedNote(start: 0.9, end: 1.3, pitchHz: 392.00),
            SegmentedNote(start: 1.35, end: 1.85, pitchHz: 261.63)
        ]

        let snapped = ScaleGravityEngine.snapToGravityScale(rawNotes: raw, preferredMode: .brightMajor)
        XCTAssertEqual(snapped.notes.count, 4)
        XCTAssertFalse(snapped.notes[1].ghostCandidates.isEmpty, "偏离 > 22 cents 应生成幽灵备选珠")
    }

    func testTapAlongIsStrictlyNonDestructive() {
        let original = [
            NoteBead(degree: 1, rawOnset: 0.03, rawDuration: 0.47),
            NoteBead(degree: 3, rawOnset: 0.56, rawDuration: 0.44),
            NoteBead(degree: 5, rawOnset: 1.08, rawDuration: 0.52),
            NoteBead(degree: 1, rawOnset: 1.62, rawDuration: 0.65)
        ]
        let taps = [0.0, 0.5, 1.0, 1.5, 2.0] // 120 BPM

        let result = ScaleGravityEngine.applyTapAlongGrid(notes: original, tapTimestamps: taps)
        XCTAssertNotNil(result)
        guard let result else { return }

        XCTAssertEqual(result.bpm, 120.0, accuracy: 2.0)
        // 验证归整焦距归零时 100% 恢复原始呼吸时间轴
        for (orig, aligned) in zip(original, result.alignedNotes) {
            XCTAssertEqual(aligned.displayOnset(grooveStrength: 0.0), orig.rawOnset, accuracy: 1e-9)
            XCTAssertEqual(aligned.displayDuration(grooveStrength: 0.0), orig.rawDuration, accuracy: 1e-9)
            XCTAssertNotNil(aligned.quantizedOnset)
        }
    }
}
