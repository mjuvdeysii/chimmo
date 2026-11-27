import AVFAudio
import Combine
import Foundation
import XCTest
@testable import Chimmo

@MainActor
final class BrainwaveResonanceTests: XCTestCase {

    func testBrainwaveCatalogAndKinematics() {
        XCTAssertEqual(BrainwaveBand.allCases, [.delta, .theta, .alpha, .gamma])
        XCTAssertEqual(AcousticWashKind.allCases.count, 4)
        XCTAssertEqual(ResonancePreset.all.count, 12)
        XCTAssertEqual(Set(ResonancePreset.all.map(\.id)).count, 12)
        XCTAssertEqual(FrissonCapsule.all.count, 8)
        XCTAssertEqual(Set(FrissonCapsule.all.map(\.id)).count, 8)

        for cap in FrissonCapsule.all {
            XCTAssertFalse(cap.title.isEmpty)
            XCTAssertFalse(cap.specimen.notes.isEmpty)
        }

        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 2.0), .delta)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 6.0), .theta)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 10.0), .alpha)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 16.0), .alpha)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: 38.0), .gamma)
        XCTAssertEqual(ResonanceKinematics.band(forBeatHz: .nan), .alpha)

        XCTAssertEqual(ResonanceKinematics.clampedBeatHz(-10.0), 1.5, accuracy: 0.001)
        XCTAssertEqual(ResonanceKinematics.clampedBeatHz(999.0), 42.0, accuracy: 0.001)

        let pair = ResonanceKinematics.binauralFrequencies(carrierHz: 216.0, beatHz: 10.0)
        XCTAssertEqual(pair.left, 211.0, accuracy: 0.001)
        XCTAssertEqual(pair.right, 221.0, accuracy: 0.001)

        XCTAssertTrue((120.0...260.0).contains(ResonanceKinematics.foldHumFrequencyToCarrier(85.0)))
        XCTAssertTrue((120.0...260.0).contains(ResonanceKinematics.foldHumFrequencyToCarrier(420.0)))
        XCTAssertEqual(ResonanceKinematics.foldHumFrequencyToCarrier(.nan), 174.0, accuracy: 0.001)

        for hour in 0..<24 {
            let banner = ResonanceKinematics.timeOfDayBanner(forHour: hour)
            XCTAssertFalse(banner.title.isEmpty)
            XCTAssertFalse(banner.subtitle.isEmpty)
            XCTAssertFalse(ResonanceKinematics.recommendedPresets(forHour: hour).isEmpty)
        }

        let s1 = ResonanceKinematics.orbPulseScale(phaseTime: 0.5, beatHz: 10.0, energy: 0.8, frissonCharge: 0.0, reduceMotion: true)
        let s2 = ResonanceKinematics.orbPulseScale(phaseTime: 3.7, beatHz: 10.0, energy: 0.8, frissonCharge: 0.0, reduceMotion: true)
        XCTAssertEqual(s1, s2, accuracy: 0.0001)

        let inhale = ResonanceKinematics.breathGuidePhase(at: 2.0, reduceMotion: false)
        let exhale = ResonanceKinematics.breathGuidePhase(at: 7.0, reduceMotion: false)
        XCTAssertNotEqual(inhale.label, exhale.label)
        let reduced = ResonanceKinematics.breathGuidePhase(at: 7.0, reduceMotion: true)
        XCTAssertEqual(reduced.progress, 0.5, accuracy: 0.001)
    }

    func testYINvDSPPitchDetectorPreAGCGateAndBounds() {
        let detector = YINvDSPPitchDetector()
        let sr = PitchContour.sampleRate
        let count = Int(sr * 0.25)

        let sine180 = (0..<count).map { i in
            Float(0.32 * sin(2.0 * Double.pi * 180.0 * Double(i) / sr))
        }
        let validContour = detector.detect(mono16kSamples: sine180, fmin: 75.0, fmax: 700.0)
        let voicedHz = validContour.pitchHz.filter { $0 > 0 }
        XCTAssertFalse(voicedHz.isEmpty)
        let medianHz = voicedHz.sorted()[voicedHz.count / 2]
        XCTAssertEqual(medianHz, 180.0, accuracy: 4.0)

        let quietNoise = (0..<count).map { i in
            Float(0.001 * sin(2.0 * Double.pi * 180.0 * Double(i) / sr))
        }
        let gatedContour = detector.detect(mono16kSamples: quietNoise, fmin: 75.0, fmax: 700.0)
        XCTAssertTrue(gatedContour.pitchHz.allSatisfy { $0 == 0.0 })

        XCTAssertTrue(detector.detect(mono16kSamples: sine180, fmin: .nan, fmax: 700.0).pitchHz.isEmpty)
        XCTAssertTrue(detector.detect(mono16kSamples: sine180, fmin: 900.0, fmax: 200.0).pitchHz.isEmpty)
    }

    func testDualBusDryBinauralIsolationIsochronicAMAndPureWashDSP() throws {
        let synth = FeltPianoSynth()
        let sr = 48_000.0

        // 1. Spectral L/R channel isolation test: L = 195 Hz, R = 205 Hz with 0% hall crosstalk.
        let samples = try synth.renderDualBusOfflineSamples(
            sampleRate: sr,
            frameCount: 24_000,
            carrierHz: 200.0,
            beatHz: 10.0,
            gain: 0.28,
            isochronicDepth: 0.0,
            overtoneWarmth: 0.0,
            noiseGain: 0.0,
            pureWashOnly: false
        )
        let sliceL = Array(samples.left.dropFirst(4_800))
        let sliceR = Array(samples.right.dropFirst(4_800))
        let magL195 = dftMagnitude(sliceL, freqHz: 195.0, sampleRate: sr)
        let magL205 = dftMagnitude(sliceL, freqHz: 205.0, sampleRate: sr)
        let magR205 = dftMagnitude(sliceR, freqHz: 205.0, sampleRate: sr)
        let magR195 = dftMagnitude(sliceR, freqHz: 195.0, sampleRate: sr)

        XCTAssertGreaterThan(magL195, 0.05)
        XCTAssertGreaterThan(magR205, 0.05)
        XCTAssertLessThan(magL205 / max(1e-6, magL195), 0.02, "Left channel leaked Right carrier!")
        XCTAssertLessThan(magR195 / max(1e-6, magR205), 0.02, "Right channel leaked Left carrier!")

        // 2. True single-channel AM depth test on Left channel (speaker pulse 40 Hz, noiseGain = 0).
        let modulated = try synth.verifySingleChannelIsochronicDepth(sampleRate: sr, carrierHz: 220.0, beatHz: 40.0, isochronicDepth: 0.38)
        let unmodulated = try synth.verifySingleChannelIsochronicDepth(sampleRate: sr, carrierHz: 220.0, beatHz: 40.0, isochronicDepth: 0.0)
        let modSpread = modulated.maxLeftBlockRMS - modulated.minLeftBlockRMS
        let flatSpread = unmodulated.maxLeftBlockRMS - unmodulated.minLeftBlockRMS
        XCTAssertGreaterThan(modSpread, 0.02)
        XCTAssertGreaterThan(modSpread, flatSpread * 2.5)

        // 3. Pure Ambient Wash Only produces audible noise wash with zero binaural carrier tone.
        let washOnly = try synth.renderDualBusOfflineSamples(
            sampleRate: sr,
            frameCount: 16_384,
            carrierHz: 200.0,
            beatHz: 10.0,
            gain: 0.0,
            noiseGain: 0.16,
            pureWashOnly: true
        )
        let washSlice = Array(washOnly.left.dropFirst(4_096))
        let washPeak = washSlice.map(abs).max() ?? 0.0
        let carrierLeak = dftMagnitude(washSlice, freqHz: 195.0, sampleRate: sr)
        XCTAssertGreaterThan(washPeak, 0.005)
        XCTAssertLessThan(carrierLeak, 0.005)

        // 4. General telemetry checks for binaural, multi-timbre, frisson, and pan.
        let bw = try synth.verifyBrainwaveOfflineTelemetry(sampleRate: sr, carrierHz: 216.0, beatHz: 10.0, noiseGain: 0.08)
        XCTAssertGreaterThan(bw.peakL, 0.01)
        XCTAssertGreaterThan(bw.peakR, 0.01)
        XCTAssertGreaterThan(bw.lrDifference, 0.005)
        XCTAssertGreaterThan(bw.duringEnvelope.rmsEnergy, 0.01)
        XCTAssertEqual(bw.afterStopEnvelope, .silent)

        for timbre in [FeltPianoSynth.Timbre.feltPiano, .liquidHarp, .celesta, .singingCello, .warmBass] {
            let res = try synth.verifyOfflineRenderTelemetry(sampleRate: sr, frequency: 261.63, timbre: timbre)
            XCTAssertGreaterThan(res.peak, 0.01)
            XCTAssertEqual(res.reverbInRate, sr, accuracy: 1.0)
            XCTAssertEqual(res.reverbOutRate, sr, accuracy: 1.0)
            XCTAssertEqual(res.envelopeAfterSilence, .silent)
        }

        let frisson = try synth.verifyFrissonReleaseOfflineTelemetry(sampleRate: sr, rootHz: 196.0, intensity: 0.85)
        XCTAssertGreaterThan(frisson.peak, 0.02)
        XCTAssertGreaterThan(frisson.duringEnvelope.rmsEnergy, 0.02)
        XCTAssertEqual(frisson.afterStopEnvelope, .silent)

        let leftPan = try synth.verifySpatialPanOfflineTelemetry(pan: -0.5)
        XCTAssertGreaterThan(leftPan.peakL, leftPan.peakR)
        let rightPan = try synth.verifySpatialPanOfflineTelemetry(pan: 0.5)
        XCTAssertGreaterThan(rightPan.peakR, rightPan.peakL)
    }

    func testResonanceViewModelStateSleepResumeStatsAndPureWash() throws {
        let suiteName = "app.chimmo.tests.\(UUID().uuidString)"
        let defs = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defs.removePersistentDomain(forName: suiteName) }

        let corrupt = ResonanceStatsStore.Snapshot(
            totalMinutes: 99_999_999,
            sessionsCompleted: -50,
            frissonReleasesCount: 5_000_000,
            bandMinutes: ["alpha": -12, "theta": 8_000_000],
            recentPresetIDs: Array(repeating: "p", count: 25),
            favoritePresetIDs: ["alpha_morning_dew"]
        )
        defs.set(try JSONEncoder().encode(corrupt), forKey: "app.chimmo.resonance.stats.v2")

        let stats = ResonanceStatsStore(preferences: defs)
        XCTAssertEqual(stats.snapshot.totalMinutes, 500_000)
        XCTAssertEqual(stats.snapshot.sessionsCompleted, 0)
        XCTAssertEqual(stats.snapshot.frissonReleasesCount, 100_000)
        XCTAssertEqual(stats.snapshot.bandMinutes["alpha"], 0)
        XCTAssertEqual(stats.snapshot.bandMinutes["theta"], 500_000)
        XCTAssertLessThanOrEqual(stats.snapshot.recentPresetIDs.count, 12)

        // Reset clears counters while preserving favorites.
        stats.resetAllStats()
        XCTAssertEqual(stats.snapshot.totalMinutes, 0)
        XCTAssertEqual(stats.snapshot.favoritePresetIDs, ["alpha_morning_dew"])
        XCTAssertEqual(stats.favoriteBand, .alpha)

        let vm = ResonanceViewModel(preferences: defs, statsStore: stats, enableSystemNowPlaying: false)
        var didForwardChange = false
        let cancellable = vm.objectWillChange.sink { _ in didForwardChange = true }
        defer { cancellable.cancel() }

        stats.toggleFavoritePreset(ResonancePreset.all[1].id)
        XCTAssertTrue(didForwardChange)
        XCTAssertTrue(stats.isFavorite(ResonancePreset.all[1].id))

        // Sleep timer survives pause/resume without vanishing deadline.
        vm.setSleepTimer(minutes: 15)
        XCTAssertEqual(vm.sleepTimerMinutes, 15)
        XCTAssertGreaterThan(vm.sleepRemainingSeconds, 800)
        vm.pauseResonancePlayback()
        XCTAssertEqual(vm.sleepTimerMinutes, 15)
        XCTAssertGreaterThan(vm.sleepRemainingSeconds, 800)
        vm.startResonancePlayback()
        XCTAssertTrue(vm.isResonancePlaying)
        XCTAssertEqual(vm.sleepTimerMinutes, 15)
        vm.setSleepTimer(minutes: nil)

        // Pure Ambient Wash persistence & zero-pulse modulation check.
        XCTAssertFalse(vm.pureAmbientWashOnly)
        vm.pureAmbientWashOnly = true
        XCTAssertTrue(defs.bool(forKey: "app.chimmo.pureAmbientWashOnly"))
        XCTAssertEqual(vm.isochronicDepthForCurrentRoute, 0.0, accuracy: 0.0001)
        vm.pureAmbientWashOnly = false

        vm.appearanceMode = .night
        XCTAssertTrue(vm.resolvedIsNight(systemScheme: .light))
        vm.appearanceMode = .day
        XCTAssertFalse(vm.resolvedIsNight(systemScheme: .dark))
        vm.appearanceMode = .auto
        XCTAssertTrue(vm.resolvedIsNight(systemScheme: .dark))

        vm.hapticsEnabled = false
        XCTAssertFalse(AcousticHapticsEngine.shared.isEnabled)
        vm.hapticsEnabled = true
        XCTAssertTrue(AcousticHapticsEngine.shared.isEnabled)

        vm.applyQuickHumPresetHz(174.0)
        XCTAssertEqual(vm.matchedHumHz ?? 0, 174.0, accuracy: 0.1)
        vm.clearMatchedHum()
        XCTAssertNil(vm.matchedHumHz)
        vm.pauseResonancePlayback()

        let np = NowPlayingResonanceController(enabled: false)
        np.clearNowPlayingInfo()
        XCTAssertEqual(defs.string(forKey: "app.chimmo.appearanceMode"), ChimmoAppearanceMode.auto.rawValue)
    }

    private func dftMagnitude(_ samples: [Float], freqHz: Double, sampleRate: Double) -> Double {
        let n = samples.count
        guard n > 0 else { return 0.0 }
        let omega = 2.0 * Double.pi * freqHz / sampleRate
        var real = 0.0
        var imag = 0.0
        for (i, s) in samples.enumerated() {
            let x = Double(s)
            real += x * cos(omega * Double(i))
            imag -= x * sin(omega * Double(i))
        }
        return (2.0 / Double(n)) * hypot(real, imag)
    }
}
