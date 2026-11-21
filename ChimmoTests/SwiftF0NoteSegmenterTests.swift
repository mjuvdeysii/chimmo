import XCTest
@testable import Chimmo

final class SwiftF0NoteSegmenterTests: XCTestCase {

    func testSegmentsTwoDistinctNotes() {
        let framesPerNote = 25 // 400 ms each
        let total = framesPerNote * 2
        var ts: [Double] = []
        var hz: [Double] = []
        var conf: [Double] = []
        var db: [Double] = []

        for i in 0..<total {
            ts.append(Double(i) * PitchContour.framePeriod)
            hz.append(i < framesPerNote ? 261.63 : 392.00) // C4 -> G4
            conf.append(0.95)
            db.append(-12.0)
        }

        let contour = PitchContour(timestamps: ts, pitchHz: hz, confidence: conf, loudnessDB: db)
        let notes = SwiftF0NoteSegmenter.segmentNotes(from: contour, pitchHoldMs: 80.0)

        XCTAssertEqual(notes.count, 2)
        if notes.count == 2 {
            XCTAssertEqual(notes[0].pitchHz, 261.63, accuracy: 2.0)
            XCTAssertEqual(notes[1].pitchHz, 392.00, accuracy: 3.0)
        }
    }

    func testSplitsRepeatedSamePitchViaLoudnessValley() {
        // 连续两个 440 Hz (da - da)，中间出现 12 dB 音量谷值（持续 3 帧 = 48 ms）
        let total = 48
        var ts: [Double] = []
        var hz: [Double] = []
        var conf: [Double] = []
        var db: [Double] = []

        for i in 0..<total {
            ts.append(Double(i) * PitchContour.framePeriod)
            hz.append(440.0)
            let inValley = (i >= 22 && i <= 25)
            conf.append(inValley ? 0.35 : 0.95)
            db.append(inValley ? -26.0 : -10.0)
        }

        let contour = PitchContour(timestamps: ts, pitchHz: hz, confidence: conf, loudnessDB: db)
        let notes = SwiftF0NoteSegmenter.segmentNotes(from: contour, pitchHoldMs: 60.0)

        XCTAssertEqual(notes.count, 2, "响度谷值应将连续同音切分为两颗独立音珠")
    }

    func testSilenceProducesNoNotes() {
        let total = 30
        let contour = PitchContour(
            timestamps: (0..<total).map { Double($0) * PitchContour.framePeriod },
            pitchHz: [Double](repeating: 0.0, count: total),
            confidence: [Double](repeating: 0.0, count: total),
            loudnessDB: [Double](repeating: -90.0, count: total)
        )
        let notes = SwiftF0NoteSegmenter.segmentNotes(from: contour)
        XCTAssertTrue(notes.isEmpty)
    }
}
