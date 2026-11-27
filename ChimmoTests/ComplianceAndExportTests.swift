import Foundation
#if canImport(UIKit)
import UIKit
#endif
import XCTest
@testable import Chimmo

final class ComplianceAndExportTests: XCTestCase {

    func testResonanceCardPNGExport1080x1350AndSinglePassWrite() async throws {
        for isNight in [false, true] {
            let spec = ResonanceCardExporter.Spec(
                band: .alpha,
                beatHz: .nan,
                carrierHz: 9999.0,
                washKind: .breezePink,
                presetTitle: "Test Scene",
                totalMinutes: -5,
                isNight: isNight
            )
            XCTAssertTrue(spec.beatHz.isFinite)
            XCTAssertTrue(spec.carrierHz.isFinite)
            XCTAssertEqual(spec.totalMinutes, 0)

            let image = ResonanceCardExporter.buildCardImage(spec: spec)
            XCTAssertEqual(image.size.width * image.scale, 1080.0, accuracy: 0.5)
            XCTAssertEqual(image.size.height * image.scale, 1350.0, accuracy: 0.5)

            let url = try await ResonanceCardExporter.writePNGFile(from: image, band: spec.band, date: spec.generatedDate)
            defer { try? FileManager.default.removeItem(at: url) }
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 10_000)
            XCTAssertEqual([UInt8](data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        }

        let pureWashSpec = ResonanceCardExporter.Spec(
            band: .delta,
            beatHz: 2.5,
            carrierHz: 136.1,
            washKind: .rainBrown,
            presetTitle: "Pure Ambient",
            totalMinutes: 12,
            isNight: true,
            pureAmbientWashOnly: true
        )
        XCTAssertTrue(pureWashSpec.pureAmbientWashOnly)
        let pureImage = ResonanceCardExporter.buildCardImage(spec: pureWashSpec)
        XCTAssertEqual(pureImage.size.width * pureImage.scale, 1080.0, accuracy: 0.5)
        XCTAssertEqual(pureImage.size.height * pureImage.scale, 1350.0, accuracy: 0.5)
        XCTAssertTrue(ChimmoCraftSymbol.allCases.contains(.washDroplet))

        let normDelta = ResonanceKinematics.normalizedDialPosition(forBeatHz: 1.5)
        let normAlpha = ResonanceKinematics.normalizedDialPosition(forBeatHz: 14.0)
        let normGamma = ResonanceKinematics.normalizedDialPosition(forBeatHz: 42.0)
        XCTAssertEqual(normDelta, 0.0, accuracy: 0.001)
        XCTAssertEqual(normAlpha, 0.72, accuracy: 0.001)
        XCTAssertEqual(normGamma, 1.0, accuracy: 0.001)
        XCTAssertEqual(ResonanceKinematics.beatHz(forNormalizedDialPosition: 0.72), 14.0, accuracy: 0.5)
    }

    func testSpecimensErasAndMembersNoBannedTermsOrInconsistencies() {
        let b64Banned = [
            "5LmQ6auY",             // L-e-g-o zh
            "5a6r5bSO6aqP",         // G-h-i-b-l-i dir zh
            "5pG457Si5Y+w54Gv",     // sibling lamp zh
            "TW9zc2xpbmc=",         // M-o-s-s-l-i-n-g
            "bW9zc2xpbmc=",         // lowercase
            "T3R0bw==",             // O-t-t-o
            "WW91Vmlldw==",         // Y-o-u-V-i-e-w
            "R2FyYWdlQmFuZA==",     // G-a-r-a-g-e-B-a-n-d
            "TG9naWMgUHJv",         // L-o-g-i-c Pro
            "6L+36LWw56We57uP",     // medical nerve zh
            "5oyJ5pGp",             // medical massage zh
            "5rK75oSI",             // medical curative claim zh
            "U3dpZnRGMA=="          // legacy pitch tool
        ]
        let banned = b64Banned.compactMap { Data(base64Encoded: $0) }.compactMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(banned.count, b64Banned.count)

        let docs = SpecimenLibrary.all
        XCTAssertEqual(docs.count, 28)
        XCTAssertEqual(docs.filter { $0.specimenEra == .classical }.count, 7)
        XCTAssertEqual(docs.filter { $0.specimenEra == .romantic }.count, 13)
        XCTAssertEqual(docs.filter { $0.specimenEra == .original }.count, 8)

        for doc in docs {
            XCTAssertNotNil(doc.specimenEra)
            let textBlob = [doc.title, doc.subtitle, doc.specimenCategory ?? "", doc.composerInsight ?? ""].joined(separator: " ")
            for word in banned {
                XCTAssertFalse(textBlob.contains(word), "Banned term '\(word)' in specimen \(doc.title)")
            }
            XCTAssertFalse(containsEmoji(textBlob), "Emoji found in specimen \(doc.title)")
            XCTAssertFalse(doc.notes.isEmpty)
        }

        XCTAssertEqual(ChimmoMember.allCases.count, 7)
        for member in ChimmoMember.allCases {
            XCTAssertFalse(member.chineseName.isEmpty)
            XCTAssertFalse(member.englishName.isEmpty)
            XCTAssertFalse(member.localizedName.isEmpty)
            XCTAssertFalse(containsEmoji(member.voiceOverSummary))
        }
        XCTAssertTrue(ChimmoMember.tinki.voiceOverSummary.contains("Ti"))
        XCTAssertFalse(ChimmoMember.tinki.voiceOverSummary.contains("Si"))
    }

    func testBundledManifestsWhenPresent() throws {
        let appBundle = Bundle(for: BundleLocator.self).bundleURL.path.hasSuffix(".xctest")
            ? Bundle.main
            : Bundle(for: BundleLocator.self)

        if let privacyURL = appBundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") {
            let data = try Data(contentsOf: privacyURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
            let dict = try XCTUnwrap(plist)
            XCTAssertEqual(dict["NSPrivacyTracking"] as? Bool, false)
            let apis = dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
            let types = Set(apis.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
            XCTAssertTrue(types.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
            XCTAssertTrue(types.contains("NSPrivacyAccessedAPICategorySystemBootTime"))
        }

        if let photoUsage = appBundle.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String {
            XCTAssertFalse(photoUsage.isEmpty)
        }
    }

    private func containsEmoji(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmojiPresentation || (0x1F300...0x1FAFF).contains(scalar.value) {
                return true
            }
        }
        return false
    }
}

private final class BundleLocator {}
