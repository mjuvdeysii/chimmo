import SwiftUI
import XCTest
@testable import Chimmo

final class BrainwaveResonanceTests: XCTestCase {

    func testOfflineBrainwaveAudioTelemetryAndStereoBinauralSpread() throws {
        let synth = FeltPianoSynth()

        for band in BrainwaveBand.allCases {
            let telemetry = try synth.verifyBrainwaveOfflineTelemetry(
                sampleRate: 48_000.0,
                carrierHz: band.defaultCarrierHz,
                beatHz: band.defaultBeatHz,
                noiseGain: band.defaultNoiseGain
            )
            XCTAssertGreaterThan(telemetry.peakL, 0.01, "\(band.shortCode) 左声道应有真实声压")
            XCTAssertGreaterThan(telemetry.peakR, 0.01, "\(band.shortCode) 右声道应有真实声压")
            XCTAssertLessThanOrEqual(telemetry.peakL, 0.95, "\(band.shortCode) 左声道必须经过安全限幅")
            XCTAssertLessThanOrEqual(telemetry.peakR, 0.95, "\(band.shortCode) 右声道必须经过安全限幅")
            XCTAssertGreaterThan(telemetry.lrDifference, 0.001, "\(band.shortCode) 双耳差频左右声道应存在波形差异")
            XCTAssertGreaterThan(telemetry.duringEnvelope.rmsEnergy, 0.001)
            XCTAssertEqual(telemetry.afterStopEnvelope.rmsEnergy, 0.0, accuracy: 0.0001)
        }
    }

    func testFrissonReleaseOfflineAudioRender() throws {
        let synth = FeltPianoSynth()
        synth.triggerFrissonRelease(rootHz: 196.0, intensity: 0.85)
        let res = try synth.verifyOfflineRenderTelemetry(sampleRate: 48_000.0, frequency: 196.0, timbre: .feltPiano)
        XCTAssertGreaterThan(res.peak, 0.02)
        XCTAssertLessThanOrEqual(res.peak, 0.95)
        XCTAssertEqual(res.reverbInRate, 48_000.0, accuracy: 1.0)
        XCTAssertEqual(res.reverbOutRate, 48_000.0, accuracy: 1.0)
        XCTAssertEqual(res.envelopeAfterSilence.rmsEnergy, 0.0, accuracy: 0.0001)
    }

    func testDomainModelsPresetsAndCapsulesIntegrity() {
        XCTAssertEqual(BrainwaveBand.allCases, [.delta, .theta, .alpha, .gamma])
        XCTAssertEqual(AcousticWashKind.allCases.count, 4)
        XCTAssertEqual(ResonancePreset.all.count, 12)
        XCTAssertEqual(Set(ResonancePreset.all.map(\.id)).count, 12)
        XCTAssertEqual(FrissonCapsule.all.count, 8)
        XCTAssertEqual(Set(FrissonCapsule.all.map(\.id)).count, 8)

        for band in BrainwaveBand.allCases {
            XCTAssertLessThan(band.minBeatHz, band.maxBeatHz)
            XCTAssertGreaterThanOrEqual(band.defaultBeatHz, band.minBeatHz)
            XCTAssertLessThanOrEqual(band.defaultBeatHz, band.maxBeatHz)
        }

        for cap in FrissonCapsule.all {
            XCTAssertFalse(cap.specimen.notes.isEmpty)
            XCTAssertFalse(cap.frissonHighlight.isEmpty)
        }
    }

    func testResonanceKinematicsSafetyAndTimeWindows() {
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 2.0), .delta)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 6.0), .theta)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 10.0), .alpha)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 38.0), .gamma)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: .nan), .alpha)
        XCTAssertEqual(ResonanceKinematics.clampedBeatHz(-10.0), 1.5, accuracy: 0.001)
        XCTAssertEqual(ResonanceKinematics.clampedBeatHz(999.0), 42.0, accuracy: 0.001)

        let pair = ResonanceKinematics.binauralFrequencies(carrierHz: 216.0, beatHz: 10.0)
        XCTAssertEqual(pair.left, 211.0, accuracy: 0.001)
        XCTAssertEqual(pair.right, 221.0, accuracy: 0.001)

        // 人声基频八度折叠（低男声、高女声与异常值安全兜底）
        XCTAssertTrue((120.0...260.0).contains(ResonanceKinematics.foldHumFrequencyToCarrier(85.0)))
        XCTAssertTrue((120.0...260.0).contains(ResonanceKinematics.foldHumFrequencyToCarrier(420.0)))
        XCTAssertEqual(ResonanceKinematics.foldHumFrequencyToCarrier(.nan), 174.0, accuracy: 0.001)

        // 全天 24 小时 3 步旅程完整性
        for hour in [0, 8, 15, 20, 23] {
            let steps = ResonanceKinematics.dailyJourneySteps(forHour: hour)
            XCTAssertEqual(steps.count, 3)
            let banner = ResonanceKinematics.timeOfDayBanner(forHour: hour)
            XCTAssertFalse(banner.title.isEmpty)
        }

        // Reduce Motion 下保持完全静态无振荡缩放
        let s1 = ResonanceKinematics.orbPulseScale(phaseTime: 0.5, beatHz: 10.0, energy: 0.8, frissonCharge: 0.0, reduceMotion: true)
        let s2 = ResonanceKinematics.orbPulseScale(phaseTime: 3.7, beatHz: 10.0, energy: 0.8, frissonCharge: 0.0, reduceMotion: true)
        XCTAssertEqual(s1, 1.0, accuracy: 0.0001)
        XCTAssertEqual(s2, 1.0, accuracy: 0.0001)

        let companion = ResonanceKinematics.gentleCompanionMessage(totalMinutes: 12, frissonCount: 3, favoriteBand: .theta)
        XCTAssertFalse(companion.isEmpty)
        XCTAssertTrue(companion.contains("漂浮放空"))
    }

    @MainActor
    func testResonanceStatsStoreAndViewModelLifecycle() throws {
        let suiteName = "app.chimmo.v2.tests.\(UUID().uuidString)"
        let defs = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defs.removePersistentDomain(forName: suiteName)
        defer { defs.removePersistentDomain(forName: suiteName) }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_v2_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let studio = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir), preferences: defs)
        let stats = ResonanceStatsStore(preferences: defs)
        let vm = ResonanceViewModel(studioVM: studio, statsStore: stats, preferences: defs)

        // 1. 启动配方、切换频段与离线记录
        let preset = ResonancePreset.all[0]
        vm.startPreset(preset)
        XCTAssertTrue(vm.isBedPlaying)
        XCTAssertEqual(vm.selectedBand, preset.band)
        XCTAssertEqual(vm.activePreset?.id, preset.id)
        XCTAssertEqual(stats.recentPresetIDs.first, preset.id)

        // 2. 颅内战栗蓄力 -> 释放
        vm.beginFrissonHold()
        XCTAssertTrue(vm.isHoldingFrisson)
        vm.updateFrissonHold(progress: 0.85)
        XCTAssertEqual(vm.frissonCharge, 0.85, accuracy: 0.001)
        let burstBefore = vm.frissonBurstSequence
        vm.releaseFrissonHold()
        XCTAssertFalse(vm.isHoldingFrisson)
        XCTAssertEqual(vm.frissonBurstSequence, burstBefore + 1)
        XCTAssertEqual(stats.frissonPeakCount, 1)

        // 3. 预设人声基频回退（保证拒麦审核场景仍畅通）
        vm.applyFallbackVoiceRoot(hz: 136.1, label: "低沉男声")
        XCTAssertEqual(vm.matchedHumHz ?? 0.0, 136.1, accuracy: 0.2)
        XCTAssertTrue(vm.isBedPlaying)

        // 4. 收藏与后台停播逻辑
        stats.toggleFavoritePreset(preset.id)
        XCTAssertTrue(stats.isFavorite(preset.id))
        vm.backgroundAudioEnabled = false
        vm.handleAppEnteredBackground()
        XCTAssertFalse(vm.isBedPlaying)

        // 5. V2.0 全视图日/夜实例化校验 + 声学安全合规页
        XCTAssertNotNil(ResonanceRootView(preferences: defs))
        for isNight in [false, true] {
            let p = ChimmoPalette(isNight: isNight)
            XCTAssertNotNil(TodayJourneyView(vm: vm, palette: p))
            XCTAssertNotNil(ResonanceFieldView(vm: vm, palette: p))
            XCTAssertNotNil(ExploreResonanceView(vm: vm, palette: p))
            XCTAssertNotNil(ProfileSanctuaryView(vm: vm, palette: p))
        }
        XCTAssertNotNil(ChimmoAcousticSafetyView())
        vm.stopAllAudio()
    }

    func testTestFlightPublicBetaBundleAndPrivacyCompliance() throws {
        // 1. PrivacyInfo.xcprivacy 必须真实打包并包含 UserDefaults CA92.1 声明（杜绝 ITMS-91053）
        let privacyURL = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let privacyData = try Data(contentsOf: privacyURL)
        let plistObj = try PropertyListSerialization.propertyList(from: privacyData, format: nil)
        let dict = try XCTUnwrap(plistObj as? [String: Any])
        XCTAssertEqual(dict["NSPrivacyTracking"] as? Bool, false)
        let apiTypes = try XCTUnwrap(dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let hasUserDefaultsReason = apiTypes.contains { item in
            let api = item["NSPrivacyAccessedAPIType"] as? String
            let reasons = item["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
            return api == "NSPrivacyAccessedAPICategoryUserDefaults" && reasons.contains("CA92.1")
        }
        XCTAssertTrue(hasUserDefaultsReason, "PrivacyInfo.xcprivacy 必须申报 NSPrivacyAccessedAPICategoryUserDefaults (CA92.1)")

        // 2. Info.plist 后台音频、免加密问卷与麦克风合规声明校验
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool, false)
        let bgModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        XCTAssertTrue(bgModes.contains("audio"), "Info.plist 必须开启 UIBackgroundModes audio 支持锁屏声场")
        let micDesc = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String ?? ""
        XCTAssertFalse(micDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let shortVer = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        XCTAssertEqual(shortVer, "2.0.0")
    }
}
