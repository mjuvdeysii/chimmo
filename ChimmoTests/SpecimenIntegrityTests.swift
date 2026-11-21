import XCTest
@testable import Chimmo

final class SpecimenIntegrityTests: XCTestCase {

    func testSevenChimmosCanonIntegrity() {
        XCTAssertEqual(ChimmoMember.allCases.count, 7)
        let names = Set(ChimmoMember.allCases.map(\.chineseName))
        XCTAssertEqual(names.count, 7)

        // 1-3-5 主三和弦核心位
        let pillars = ChimmoMember.allCases.filter(\.isTriadPillar).map(\.degree)
        XCTAssertEqual(pillars, [1, 3, 5])

        // 4 和 7 为天然张力音级
        let tense = ChimmoMember.allCases.filter(\.isTensionDegree).map(\.degree)
        XCTAssertEqual(tense, [4, 7])
    }

    func testAllBuiltInSpecimensAreWellFormed() {
        XCTAssertGreaterThanOrEqual(SpecimenLibrary.all.count, 6)
        for spec in SpecimenLibrary.all {
            XCTAssertTrue(spec.isSpecimen)
            XCTAssertFalse(spec.notes.isEmpty, "\(spec.title) 不应为空")
            XCTAssertFalse((spec.composerInsight ?? "").isEmpty, "\(spec.title) 应包含编曲视角解说")

            var prevOnset = -1.0
            for note in spec.notes {
                XCTAssertTrue((1...7).contains(note.degree))
                XCTAssertGreaterThanOrEqual(note.rawOnset, prevOnset)
                prevOnset = note.rawOnset
            }
        }
    }

    func testAllHarmonyProfilesCoverAllSevenDegrees() {
        for profile in HarmonyProfile.allCases {
            for deg in 1...7 {
                let voicing = profile.voicing(for: deg)
                XCTAssertTrue((1...7).contains(voicing.bassDegree))
                XCTAssertFalse(voicing.upperDegrees.isEmpty)
            }
        }
    }

    func testComplete28MasterpieceCatalogAndMIDIExport() {
        XCTAssertEqual(SpecimenLibrary.all.count, 28, "v0.3.0 曲库应包含 28 首（20 首全球公版古典名曲 + 8 首原创夏日治愈技法）")
        XCTAssertNotNil(SpecimenLibrary.saintSaensTheSwan.activeGuidedMoment(at: 0.0))
        XCTAssertEqual(SpecimenLibrary.saintSaensTheSwan.preferredTexture, .swanRipple)

        let midiData = MIDIExporter.encodeSMF(document: SpecimenLibrary.saintSaensTheSwan, includeHarmonyCradle: true)
        XCTAssertGreaterThan(midiData.count, 64)
        let header = String(decoding: midiData.prefix(4), as: UTF8.self)
        XCTAssertEqual(header, "MThd")
    }

    func testTrueSemitoneGeometryMajorAndMinor() {
        // 大调：3-4 相差 1 个半音，7-高音1 相差 1 个半音
        let m3 = ScalePitchGeometry.semitoneOffset(degree: 3, octaveOffset: 0, mode: .brightMajor)
        let m4 = ScalePitchGeometry.semitoneOffset(degree: 4, octaveOffset: 0, mode: .brightMajor)
        let m7 = ScalePitchGeometry.semitoneOffset(degree: 7, octaveOffset: 0, mode: .brightMajor)
        let mHigh1 = ScalePitchGeometry.semitoneOffset(degree: 1, octaveOffset: 1, mode: .brightMajor)
        XCTAssertEqual(m4 - m3, 1)
        XCTAssertEqual(mHigh1 - m7, 1)

        // 小调：3 级（拍咯）真实下降 1 个半音（4 -> 3）
        let minor3 = ScalePitchGeometry.semitoneOffset(degree: 3, octaveOffset: 0, mode: .wistfulMinor)
        XCTAssertEqual(m3 - minor3, 1)
    }

    @MainActor
    func testWorkbenchLadderTextureBeadEditAndOfflineNotebook() {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let store = MelodyNotebookStore(directory: tmpDir)
        let vm = StudioViewModel(notebookStore: store)
        XCTAssertTrue(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.title, SpecimenLibrary.saintSaensTheSwan.title)

        // 点按左侧音阶阶梯 3·拍咯与 1·陶诺，自动切入自由创作并落珠
        vm.triggerLadderMember(.plokko, octaveOffset: 0)
        vm.triggerLadderMember(.taono, octaveOffset: 0)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.notes.count, 2)
        XCTAssertFalse(vm.currentInsight.headline.isEmpty)

        // 选中音珠拉长时长与删除功能验证
        let durBefore = vm.document.notes.last?.rawDuration ?? 0
        vm.adjustSelectedBeadDuration(delta: 0.25)
        XCTAssertGreaterThan(vm.document.notes.last?.rawDuration ?? 0, durBefore)

        // 切换伴奏织体与底部第 1 小节和弦光带卡片
        vm.setAccompanimentTexture(.summerGlass)
        let beforeChord = vm.chordSpans[0].chord
        vm.cycleSpanChord(spanIndex: 0)
        XCTAssertNotEqual(vm.chordSpans[0].chord, beforeChord)

        // 保存至本机离线乐思本并重新加载验证持久化（含伴奏织体）
        vm.saveCurrentToNotebook()
        XCTAssertEqual(store.entries.count, 1)

        let reloaded = MelodyNotebookStore(directory: tmpDir)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.document.notes.count, 2)
        XCTAssertEqual(reloaded.entries.first?.accompanimentTexture, .summerGlass)
    }
}
