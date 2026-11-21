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

    func testComplete16SpecimenCatalogAndMIDIExport() {
        XCTAssertEqual(SpecimenLibrary.all.count, 16, "V1.0 标本库应包含完整 16 首（8 公版古典 + 8 现代技法）")
        let midiData = MIDIExporter.encodeSMF(document: SpecimenLibrary.summerSuspension, includeHarmonyCradle: true)
        XCTAssertGreaterThan(midiData.count, 64)
        let header = String(decoding: midiData.prefix(4), as: UTF8.self)
        XCTAssertEqual(header, "MThd")
    }

    @MainActor
    func testInteractiveChimmoTapSpawnsFlyingPearlAndWaterWave() {
        let vm = StudioViewModel()
        XCTAssertTrue(vm.document.isSpecimen)

        // 点按 3 号拍咯应立即切入指尖即兴画卷并发射飞珠涟漪
        vm.triggerMember(.plokko)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.notes.count, 1)
        XCTAssertEqual(vm.document.notes.first?.degree, 3)
        XCTAssertEqual(vm.latestDegree, 3)
        XCTAssertFalse(vm.impulses.isEmpty)

        // 左右轻拂水面应切换和声色温并保持水位托起
        let initialProfile = vm.document.harmonyProfile
        vm.waterLevel = 0.1
        vm.swipeWaterProfile(direction: 1)
        XCTAssertNotEqual(vm.document.harmonyProfile, initialProfile)
        XCTAssertGreaterThanOrEqual(vm.waterLevel, 0.5)
    }
}
