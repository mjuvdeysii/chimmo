import SwiftUI
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

    func testFiveSkySpectrumShiftsExactlyOneSemitonePerStep() {
        let skies = ScaleMode.allCases
        XCTAssertEqual(skies.count, 5)
        for i in 0..<(skies.count - 1) {
            let a = skies[i].semitoneOffsets
            let b = skies[i + 1].semitoneOffsets
            let diffs = zip(a, b).map { $0 - $1 }
            let changedCount = diffs.filter { $0 != 0 }.count
            let totalShift = diffs.reduce(0, +)
            XCTAssertEqual(changedCount, 1, "相邻两片天光（\(skies[i].label) -> \(skies[i+1].label)）应恰好只挪动 1 只咩哞")
            XCTAssertEqual(totalShift, 1, "每向右移动一片天空，应恰好降 1 个半音")
        }
    }

    func testMotifOrigamiCounterpointAndHarmonicRatioPhysics() {
        // 物理比例验证：纯五度 3:2 高度和谐，半音 16:15 为张力摩擦
        let fifth = HarmonicRatioPhysics.analyze(melodyDegree: 5, rootDegree: 1, mode: .brightMajor)
        XCTAssertEqual(fifth.ratioText, "3 : 2")
        XCTAssertFalse(fifth.isTense)
        XCTAssertGreaterThan(fifth.consonance, 0.9)

        let halfStep = HarmonicRatioPhysics.descriptor(forSemitones: 1)
        XCTAssertEqual(halfStep.ratioText, "16 : 15")
        XCTAssertTrue(halfStep.isTense)

        // 3 音种子折纸「四句成诗」应自然生长为完整起承转合乐章
        let seed = [
            NoteBead(degree: 1, rawOnset: 0.1, rawDuration: 0.45),
            NoteBead(degree: 3, rawOnset: 0.55, rawDuration: 0.45),
            NoteBead(degree: 5, rawOnset: 1.0, rawDuration: 0.55)
        ]
        let poem = MotifOrigamiEngine.grow(notes: seed, operation: .fullFourPhrasePoem)
        XCTAssertEqual(poem.count, 12) // 3+3+3+3
        XCTAssertEqual(poem.first?.phraseTag, "起·种子")
        XCTAssertEqual(poem.last?.phraseTag, "合·归家")

        // 圣桑《天鹅》应能自动编织出影子对位副旋律
        let swan = SpecimenLibrary.saintSaensTheSwan
        XCTAssertEqual(swan.preferredVoice, .singingCello)
        let spans = TheoryLensEngine.buildChordSpans(document: swan, preset: .autoMatch)
        let shadows = CounterpointShadowEngine.generateShadowVoice(document: swan, spans: spans)
        XCTAssertFalse(shadows.isEmpty)
    }

    @MainActor
    func testMasterpieceOnionPeelerAndPostcardStickerPersistence() {
        let swan = SpecimenLibrary.saintSaensTheSwan
        XCTAssertEqual(MasterpieceOnionEngine.layer(forIndex: 0, totalCount: swan.notes.count), .seed)
        XCTAssertEqual(MasterpieceOnionEngine.layer(forIndex: 1, totalCount: swan.notes.count), .seed)
        XCTAssertEqual(MasterpieceOnionEngine.layer(forIndex: 2, totalCount: swan.notes.count), .seed)
        XCTAssertEqual(MasterpieceOnionEngine.layer(forIndex: swan.notes.count - 1, totalCount: swan.notes.count), .skeleton)

        // 零变动应原样返回
        let unchanged = MasterpieceOnionEngine.applySeedShifts(document: swan, shifts: [0, 0, 0])
        XCTAssertEqual(unchanged.notes, swan.notes)
        XCTAssertTrue(unchanged.isSpecimen)

        // 改写火种音应产生专属变奏，同时保持结尾归家音高稳定
        let varied = MasterpieceOnionEngine.applySeedShifts(document: swan, shifts: [1, -1, 2])
        XCTAssertFalse(varied.isSpecimen)
        XCTAssertTrue(varied.title.contains("我的变奏"))
        XCTAssertNotEqual(varied.notes[0].degree, swan.notes[0].degree)
        XCTAssertEqual(varied.notes.last?.degree, swan.notes.last?.degree)
        XCTAssertEqual(varied.notes.last?.octaveOffset, swan.notes.last?.octaveOffset)

        // 声音明信片心情贴纸离线持久化
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v05-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let store = MelodyNotebookStore(directory: tmpDir)
        let saved = store.save(
            document: varied,
            chordPreset: .autoMatch,
            chordOverrides: [:],
            accompanimentTexture: .swanRipple,
            moodSticker: "我的名曲变奏",
            summaryNote: "从《天鹅》3 颗火种中改写出的专属变奏"
        )
        XCTAssertEqual(saved.moodSticker, "我的名曲变奏")

        let reloaded = MelodyNotebookStore(directory: tmpDir)
        XCTAssertEqual(reloaded.entries.first?.moodSticker, "我的名曲变奏")
        XCTAssertEqual(reloaded.entries.first?.document.title, varied.title)
    }

    @MainActor
    func testXylophoneRollEngineAndInlineTapWorkflow() {
        XCTAssertEqual(XylophoneLane.allLanes.count, 8)
        XCTAssertEqual(XylophoneLane.allowedIndices(pentatonicSafe: true), [0, 1, 2, 4, 5, 7])
        XCTAssertEqual(XylophoneLane.nearestAllowedIndex(3, pentatonicSafe: true), 2) // 4 自动避让到 3

        let raw = [
            NoteBead(degree: 3, rawOnset: 0.15, rawDuration: 0.45),
            NoteBead(degree: 3, rawOnset: 0.65, rawDuration: 0.45),
            NoteBead(degree: 3, rawOnset: 1.15, rawDuration: 0.45),
            NoteBead(degree: 3, rawOnset: 1.75, rawDuration: 0.65)
        ]

        // 4 种山坡快选保留全部节奏时间，并把音高塑形到安全木琴条上
        for hill in MelodyHillTemplate.allCases {
            let shaped = XylophoneRollEngine.applyHill(hill, to: raw, pentatonicSafe: true)
            XCTAssertEqual(shaped.count, raw.count)
            for (orig, s) in zip(raw, shaped) {
                XCTAssertEqual(orig.rawOnset, s.rawOnset, accuracy: 1e-6)
                XCTAssertNotEqual(s.degree, 4)
                XCTAssertNotEqual(s.degree, 7)
            }
        }

        // 「只听高低走势、不管跑调」相对轮廓映射
        let hummed = XylophoneRollEngine.applyRelativeContour(
            to: raw,
            normalizedHeights: [0.0, 0.5, 1.0, 0.0],
            pentatonicSafe: true
        )
        XCTAssertEqual(hummed[0].degree, 1)
        XCTAssertEqual(hummed[2].degree, 1)
        XCTAssertEqual(hummed[2].octaveOffset, 1) // 最高点映射到 1↑
        XCTAssertEqual(XylophoneRollEngine.stepDeltaLabel(from: hummed[0], to: hummed[2]), "+7↗")

        // 验光师 3 选 1 智能亮灯推荐
        let startHints = XylophoneRollEngine.suggestThreeLanes(forBeatIndex: 0, in: hummed, pentatonicSafe: true)
        XCTAssertEqual(startHints.count, 3)
        let midHints = XylophoneRollEngine.suggestThreeLanes(forBeatIndex: 1, in: hummed, pentatonicSafe: true)
        XCTAssertEqual(midHints.count, 3)
        let endHints = XylophoneRollEngine.suggestThreeLanes(forBeatIndex: 3, in: hummed, pentatonicSafe: true)
        XCTAssertEqual(endHints.count, 3)
        XCTAssertEqual(endHints.first?.laneIndex, 0) // 最后一拍优先亮起 1·回家

        // ViewModel 内联木鼓敲节奏 → 定型 → 亮灯跟弹完整流程
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v06-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tmpDir))
        vm.startRhythmTap()
        XCTAssertTrue(vm.isTappingRhythm)
        vm.recordRhythmDrumTap()
        vm.recordRhythmDrumTap()
        vm.recordRhythmDrumTap()
        vm.commitRhythmTaps()
        XCTAssertFalse(vm.isTappingRhythm)
        XCTAssertEqual(vm.document.notes.count, 3)
        XCTAssertTrue(vm.pentatonicSafe)
        XCTAssertTrue(vm.smartHintActive)
        XCTAssertEqual(vm.smartHints.count, 3)

        // 切到名曲亮灯跟弹并验证敲击目标彩条自动步进
        vm.openSpecimenForFollowGlow(SpecimenLibrary.saintSaensTheSwan)
        XCTAssertTrue(vm.followGlowActive)
        XCTAssertEqual(vm.followGlowIndex, 0)
        let firstNote = vm.document.notes[0]
        let firstLane = XylophoneLane.lane(at: XylophoneLane.laneIndex(degree: firstNote.degree, octaveOffset: firstNote.octaveOffset))
        vm.strikeXylophoneLane(firstLane)
        XCTAssertEqual(vm.followGlowIndex, 1)
    }

    func testOrbitalRotationKeepsActiveNoteAtTwelveOClock() {
        let total = 12.0
        for onset in [0.0, 2.5, 6.0, 9.75] {
            let angle = OrbitalGeometry.screenAngle(onset: onset, playheadTime: onset, totalDuration: total)
            let normalized = atan2(sin(angle), cos(angle))
            XCTAssertEqual(normalized, -Double.pi / 2.0, accuracy: 1e-6, "在 onset=\(onset) 时刻音珠应准确转到正上方 12 点钟唱针处")
        }

        // 极坐标逆向点击映射应能准确还原出轨道索引与时间点
        let center = CGPoint(x: 200, y: 200)
        let innerR: CGFloat = 50
        let outerR: CGFloat = 155
        let rot = OrbitalGeometry.discRotationRadians(playheadTime: 3.0, totalDuration: total)
        let targetOnset = 5.4
        let targetLane = 4 // 5·Sol
        let r = OrbitalGeometry.orbitRadius(laneIndex: targetLane, innerRadius: innerR, outerRadius: outerR)
        let screenAng = OrbitalGeometry.screenAngle(onset: targetOnset, playheadTime: 3.0, totalDuration: total)
        let pt = CGPoint(x: center.x + CGFloat(cos(screenAng)) * r, y: center.y + CGFloat(sin(screenAng)) * r)

        let recoveredLane = OrbitalGeometry.laneIndex(forRadius: r, innerRadius: innerR, outerRadius: outerR, pentatonicSafe: true)
        let recoveredOnset = OrbitalGeometry.onset(forScreenPoint: pt, center: center, discRotation: rot, totalDuration: total)
        XCTAssertEqual(recoveredLane, targetLane)
        XCTAssertEqual(recoveredOnset, targetOnset, accuracy: 1e-3)
    }

    func testFlowingRiverKeepsActiveNoteLockedOnBeam() {
        let anchorX: CGFloat = 112.0
        let pxPerSec: CGFloat = 84.0
        let swan = SpecimenLibrary.saintSaensTheSwan
        XCTAssertGreaterThan(swan.totalDuration, 18.0)

        for note in swan.notes {
            let t = note.rawOnset
            let scrollX = FlowingRiverGeometry.worldScrollX(playheadTime: t, manualScrollX: 0, pxPerSecond: pxPerSec)
            let x = FlowingRiverGeometry.screenX(onset: t, scrollX: scrollX, anchorX: anchorX, pxPerSecond: pxPerSec)
            XCTAssertEqual(x, anchorX, accuracy: 1e-5, "流动山河模式下当前发声音珠必须稳稳锁定在固定金光束位置")
        }
    }

    func testContourSketchSamplerAndColorblindGlyphs() {
        let glyphs = (0..<8).map { PitchGlyphShape.glyph(forLaneIndex: $0) }
        XCTAssertEqual(Set(glyphs).count, 8, "8 条音高轨道必须对应 8 种完全不同的色盲友好几何图腾")
        for g in glyphs {
            XCTAssertFalse(g.path(in: CGRect(x: 0, y: 0, width: 16, height: 16)).isEmpty)
        }

        // 从左下画到右上的爬坡曲线应生成单调上升的归一化高度 [0...1]
        let stroke = [
            CGPoint(x: 0, y: 120),
            CGPoint(x: 100, y: 70),
            CGPoint(x: 200, y: 10)
        ]
        let heights = ContourSketchSampler.sampleContour(points: stroke, in: CGSize(width: 200, height: 120), slotCount: 6)
        XCTAssertEqual(heights.count, 6)
        XCTAssertLessThan(heights.first ?? 1, heights.last ?? 0)
        XCTAssertGreaterThanOrEqual(heights.first ?? -1, 0.0)
        XCTAssertLessThanOrEqual(heights.last ?? 2, 1.0)
    }

    @MainActor
    func testPlaybackClockAndScrubbing() {
        let clock = PlaybackClock()
        clock.start(totalDuration: 8.0, from: 2.0, at: 100.0)
        XCTAssertTrue(clock.isPlaying)
        XCTAssertEqual(clock.currentTime(at: 102.5) ?? -1, 4.5, accuracy: 1e-5)
        XCTAssertGreaterThan(clock.continuousRotationTurns(at: 109.0), 1.0)

        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v07-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.scrubToTime(4.2, triggerNotes: false)
        XCTAssertEqual(vm.clock.scrubTime ?? -1, 4.2, accuracy: 1e-5)
        vm.endScrubbing()

        vm.startBlankCanvas()
        XCTAssertTrue(vm.document.notes.isEmpty)
        vm.applyDrawnHillContour([0.1, 0.5, 0.9, 0.6, 0.2, 0.0])
        XCTAssertEqual(vm.document.notes.count, 6)

        // Creative Alchemy Round 1: 折纸成诗（6 音提取 4 音种子 -> 4+4+4+3 = 15 颗）+ 大师火种微调变奏
        vm.growCurrentWithOrigami(.fullFourPhrasePoem)
        XCTAssertEqual(vm.document.notes.count, 15)
        let tags = Set(vm.document.notes.compactMap(\.phraseTag))
        XCTAssertTrue(tags.contains("起·种子"))
        XCTAssertTrue(tags.contains("承·爬楼"))
        XCTAssertTrue(tags.contains("转·倒影"))
        XCTAssertTrue(tags.contains("合·归家"))

        vm.openSpecimen(SpecimenLibrary.saintSaensTheSwan, autoPlay: false)
        let originalTitle = vm.document.title
        vm.applyMasterpieceSeedShifts([1, -1, 2])
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertTrue(vm.document.title.contains(originalTitle))
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound2RateShadowAndConstellation() {
        // 1. PlaybackClock 无跳变变速验证（含循环边界跨圈）
        let clock = PlaybackClock()
        clock.start(totalDuration: 8.0, from: 2.0, at: 100.0)
        XCTAssertEqual(clock.currentTime(at: 102.5) ?? -1, 4.5, accuracy: 1e-6)
        let turnsBeforeSlow = clock.continuousRotationTurns(at: 102.5)

        clock.setRate(0.5, at: 102.5)
        XCTAssertEqual(clock.currentTime(at: 102.5) ?? -1, 4.5, accuracy: 1e-6, "中途降速绝不能引发播放位置跳变")
        XCTAssertEqual(clock.continuousRotationTurns(at: 102.5), turnsBeforeSlow, accuracy: 1e-6)
        XCTAssertEqual(clock.currentTime(at: 104.5) ?? -1, 5.5, accuracy: 1e-6, "0.5× 速推进 2 秒墙钟应推进 1 秒乐曲时间")

        // 跨过第 1 圈结尾进入第 2 圈后再次切到 1.25×，旋转圈数与当前时刻均保持连续
        let turnsBeforeFast = clock.continuousRotationTurns(at: 112.5)
        let timeBeforeFast = clock.currentTime(at: 112.5) ?? -1
        clock.setRate(1.25, at: 112.5)
        XCTAssertEqual(clock.currentTime(at: 112.5) ?? -1, timeBeforeFast, accuracy: 1e-6)
        XCTAssertEqual(clock.continuousRotationTurns(at: 112.5), turnsBeforeFast, accuracy: 1e-6)
        clock.stop()

        // 2. ConstellationGeometry 星云万花筒几何与流星轨迹插值
        let center = CGPoint(x: 200, y: 200)
        let radius: CGFloat = 120
        let starPoints = (0..<8).map { ConstellationGeometry.starPoint(laneIndex: $0, center: center, radius: radius) }
        for (idx, pt) in starPoints.enumerated() {
            XCTAssertEqual(hypot(pt.x - center.x, pt.y - center.y), radius, accuracy: 1e-4, "星辰 \(idx) 必须位于星轨圆周上")
        }
        XCTAssertEqual(
            ConstellationGeometry.hitStarLane(at: starPoints[4], center: center, radius: radius, pentatonicSafe: true),
            4
        )
        XCTAssertNil(
            ConstellationGeometry.hitStarLane(at: starPoints[3], center: center, radius: radius, pentatonicSafe: true),
            "开启安心 5 音时第 4 音星辰不应被直接点中"
        )
        XCTAssertEqual(
            ConstellationGeometry.hitStarLane(at: starPoints[3], center: center, radius: radius, pentatonicSafe: false),
            3
        )

        let duetDoc = MelodyDocument(
            title: "双星测试",
            subtitle: "",
            notes: [
                NoteBead(degree: 1, octaveOffset: 0, rawOnset: 1.0, rawDuration: 0.8),
                NoteBead(degree: 5, octaveOffset: 0, rawOnset: 3.0, rawDuration: 0.8)
            ]
        )
        let snapStart = ConstellationGeometry.cometSnapshot(
            notes: duetDoc.notes,
            grooveStrength: 0.0,
            currentTime: 1.0,
            center: center,
            radius: radius
        )
        XCTAssertNotNil(snapStart)
        XCTAssertEqual(snapStart?.position.x ?? 0, starPoints[0].x, accuracy: 1e-4)
        XCTAssertEqual(snapStart?.position.y ?? 0, starPoints[0].y, accuracy: 1e-4)

        let snapMid = ConstellationGeometry.cometSnapshot(
            notes: duetDoc.notes,
            grooveStrength: 0.0,
            currentTime: 2.0,
            center: center,
            radius: radius
        )
        XCTAssertEqual(snapMid?.activeLaneIndex, 0)
        XCTAssertEqual(snapMid?.nextLaneIndex, 4)
        XCTAssertEqual(snapMid?.progress ?? -1, 0.5, accuracy: 1e-4)

        // 3. 四幕情绪词 + StudioViewModel 影子对位/音乐触觉/呼吸倍速状态联动
        for chord in DiatonicChord.allCases {
            XCTAssertFalse(chord.shortMoodGlyph.isEmpty)
        }
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v09-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.openSpecimen(SpecimenLibrary.saintSaensTheSwan, autoPlay: false)
        XCTAssertFalse(vm.shadowNotes.isEmpty)

        let initialShadow = vm.shadowCounterpointEnabled
        vm.toggleShadowCounterpoint()
        XCTAssertNotEqual(vm.shadowCounterpointEnabled, initialShadow)

        let initialHaptics = vm.musicHapticsEnabled
        vm.toggleMusicHaptics()
        XCTAssertNotEqual(vm.musicHapticsEnabled, initialHaptics)

        vm.setPlaybackRate(0.65)
        XCTAssertEqual(vm.playbackRate, 0.65, accuracy: 1e-5)
        XCTAssertEqual(vm.clock.playbackRate, 0.65, accuracy: 1e-5)
        vm.stopPlayback()
    }

    @MainActor
    func testAudioSynth48kHzGraphNoFormatErrorAndAudiblePCM() throws {
        let synth = FeltPianoSynth()
        let result = try synth.verifyOfflineRenderPeak(sampleRate: 48_000.0, frequency: 440.0)
        XCTAssertEqual(result.reverbInRate, 48_000.0, accuracy: 1.0, "混响输入总线必须与 48kHz 硬件源对齐")
        XCTAssertEqual(result.reverbOutRate, 48_000.0, accuracy: 1.0, "混响输出总线必须显式声明同频格式，严防 iOS -10868 静音故障")
        XCTAssertGreaterThan(result.peak, 0.05, "合成器渲染管线必须产生真实可闻的正向声压振幅")
    }

    @MainActor
    func testCreativeAlchemyRound3NightLampPostcardBorrowAndZeroEmojiGuard() throws {
        // 1. TactileFieldMapper 闭眼迟滞磁吸校验
        XCTAssertEqual(TactileFieldMapper.rawNormalizedY(locationY: 92, height: 100, paddingRatio: 0.08), 0.0, accuracy: 1e-5)
        XCTAssertEqual(TactileFieldMapper.rawNormalizedY(locationY: 8, height: 100, paddingRatio: 0.08), 1.0, accuracy: 1e-5)

        // 五声安全模式共有 6 档 [0, 1, 2, 4, 5, 7]，死区 0.24 下跨 0.74 才切到下一档
        XCTAssertEqual(
            TactileFieldMapper.snappedLaneIndex(normalizedY: 0.12, previousLaneIndex: 0, pentatonicSafe: true),
            0,
            "在死区范围内的手部微颤不应触发跳音"
        )
        XCTAssertEqual(
            TactileFieldMapper.snappedLaneIndex(normalizedY: 0.18, previousLaneIndex: 0, pentatonicSafe: true),
            1,
            "跨过迟滞阈值后应精准吸进下一档音阶"
        )
        XCTAssertEqual(
            TactileFieldMapper.magneticDetentNormalizedY(laneIndex: 7, pentatonicSafe: false),
            1.0,
            accuracy: 1e-5
        )

        // 2. 离线黑胶星轨明信片 PNG 渲染与空曲安全防护
        let pngData = VinylPostcardExporter.renderPNGData(
            document: SpecimenLibrary.saintSaensTheSwan,
            shadowEnabled: true,
            isNight: true
        )
        XCTAssertNotNil(pngData)
        if let pngData {
            XCTAssertGreaterThan(pngData.count, 1024)
            XCTAssertEqual(Array(pngData.prefix(4)), [0x89, 0x50, 0x4E, 0x47], "导出字节必须为标准 PNG 文件头")
        }

        let emptyDoc = MelodyDocument(title: "空盘测试", subtitle: "", notes: [])
        XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: emptyDoc, isNight: false))

        let tempURL = try VinylPostcardExporter.writeTemporaryPostcardFile(document: SpecimenLibrary.saintSaensTheSwan)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        XCTAssertTrue(tempURL.lastPathComponent.hasSuffix(".png"))

        // 3. 闭眼滑音短句保存 & 28 首曲库风格套用
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v011-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.applyNightLampPhrase(
            [
                NoteBead(degree: 1, rawOnset: 0.14, rawDuration: 0.45),
                NoteBead(degree: 5, rawOnset: 0.70, rawDuration: 0.65)
            ],
            pentatonicSafe: true
        )
        XCTAssertEqual(vm.document.notes.count, 2)
        XCTAssertTrue(vm.pentatonicSafe)
        XCTAssertTrue(vm.document.title.contains("闭眼滑音"))

        vm.borrowHarmonyAtmosphere(from: SpecimenLibrary.tchaikovskySwanLake)
        XCTAssertEqual(vm.document.notes.count, 2, "套用曲风只能替换调式与伴奏，不能覆盖用户的音符")
        XCTAssertEqual(vm.document.scaleMode, .wistfulMinor)
        XCTAssertEqual(vm.document.harmonyProfile, .filmGlow)
        XCTAssertEqual(vm.accompanimentTexture, .swanRipple)
        XCTAssertEqual(vm.melodyVoice, .singingCello)
        vm.stopPlayback()

        // 4. 大白话界面文案与视图模式校验
        XCTAssertEqual(StageVisualMode.allCases.map(\.rawValue), ["转盘", "曲线", "星环"])
        XCTAssertTrue(ScaleMode.allCases.allSatisfy { $0.shortSkyLabel.count <= 2 && $0.label.count <= 2 })

        // 5. 全局零 Emoji 门禁守卫
        var inspectStrings: [String] = []
        inspectStrings.append(contentsOf: PitchGlyphShape.allCases.map(\.symbolName))
        inspectStrings.append(contentsOf: MelodyHillTemplate.allCases.map(\.shortLabel))
        inspectStrings.append(contentsOf: DiatonicChord.allCases.map(\.shortMoodGlyph))
        inspectStrings.append(contentsOf: XylophoneRollEngine.suggestThreeLanes(forBeatIndex: 0, in: [], pentatonicSafe: true).map(\.badge))
        for text in inspectStrings {
            for scalar in text.unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji, "禁止在设计文案与标记中出现 Emoji 符号：\(text)")
            }
        }
    }

    @MainActor
    func testCreativeAlchemyRound5PreLinguisticInstrument() throws {
        // 1. 每种调式具备不少于 3 个音的听觉签名试听琶音
        for mode in ScaleMode.allCases {
            let preview = mode.signaturePreviewDegrees
            XCTAssertGreaterThanOrEqual(preview.count, 3)
            XCTAssertTrue(preview.allSatisfy { (1...7).contains($0) })
        }

        // 2. 无字声光引导几何：跟灯弹光桥、空画布呼吸引导环、选中音符径向滑轨
        let bridge = PreLinguisticGuideGeometry.followLightBridgePath(
            from: CGPoint(x: 160, y: 120),
            toLaneIndex: 3,
            canvasSize: CGSize(width: 320, height: 300)
        )
        XCTAssertEqual(bridge.start, CGPoint(x: 160, y: 120))
        XCTAssertEqual(bridge.end.x, (3.5 / 8.0) * 320.0, accuracy: 1e-4)
        XCTAssertEqual(bridge.end.y, 298.0, accuracy: 1e-4)

        let rings = PreLinguisticGuideGeometry.emptyCanvasPulseRadii(phase: 0.28, maxRadius: 120)
        XCTAssertEqual(rings.count, 3)
        XCTAssertLessThan(rings[0].radius, rings[1].radius)
        XCTAssertLessThan(rings[1].radius, rings[2].radius)
        XCTAssertTrue(rings.allSatisfy { (0.0...1.0).contains($0.opacity) })

        let ticks = PreLinguisticGuideGeometry.selectionTractionTicks(
            center: CGPoint(x: 100, y: 100),
            angle: 0.0,
            innerRadius: 30,
            outerRadius: 90
        )
        XCTAssertEqual(ticks.inner.x, 130.0, accuracy: 1e-4)
        XCTAssertEqual(ticks.inner.y, 100.0, accuracy: 1e-4)
        XCTAssertEqual(ticks.outer.x, 190.0, accuracy: 1e-4)
        XCTAssertEqual(ticks.outer.y, 100.0, accuracy: 1e-4)

        // 3. 声音先行，零文字说教弹窗：切换风格/伴奏/音色静默无 Toast，保存触发图标脉冲
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v012-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.setScaleMode(.cloudLydian)
        XCTAssertEqual(vm.document.scaleMode, .cloudLydian)
        XCTAssertNil(vm.statusToast)

        vm.setAccompanimentTexture(.feltWaltz)
        XCTAssertEqual(vm.accompanimentTexture, .feltWaltz)
        XCTAssertNil(vm.statusToast)

        vm.setMelodyVoice(.celestaGlass)
        XCTAssertEqual(vm.melodyVoice, .celestaGlass)
        XCTAssertNil(vm.statusToast)

        let pulseBefore = vm.lastSavedPulse
        vm.saveCurrentToNotebook()
        XCTAssertEqual(vm.lastSavedPulse, pulseBefore + 1)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound6LivingAcousticSoundboard() throws {
        // 1. 全部 5 种室内乐声学音色在 48kHz 混响管线下无格式错误且实时输出包络可观测
        let synth = FeltPianoSynth()
        let timbres: [FeltPianoSynth.Timbre] = [.feltPiano, .singingCello, .liquidHarp, .warmBass, .celesta]
        for timbre in timbres {
            let res = try synth.verifyOfflineRenderTelemetry(sampleRate: 48_000.0, frequency: 329.63, timbre: timbre)
            XCTAssertEqual(res.reverbInRate, 48_000.0, accuracy: 1.0)
            XCTAssertEqual(res.reverbOutRate, 48_000.0, accuracy: 1.0)
            XCTAssertTrue(res.peak.isFinite)
            XCTAssertGreaterThan(res.peak, 0.03)
            XCTAssertLessThanOrEqual(res.peak, 1.0)
            XCTAssertGreaterThan(res.envelopeDuringRender.rmsEnergy, 0.0)
            XCTAssertEqual(res.envelopeAfterSilence.rmsEnergy, 0.0, accuracy: 1e-6)
        }

        // 2. 彩虹琴键纵向力度表达映射器：顶部清亮强劲、底部轻柔温润、越界安全钳位
        let topDyn = ExpressiveTouchMapper.dynamics(normalizedY: 0.0)
        let bottomDyn = ExpressiveTouchMapper.dynamics(normalizedY: 1.0)
        XCTAssertGreaterThan(topDyn.velocity, bottomDyn.velocity)
        XCTAssertGreaterThan(topDyn.brightness, bottomDyn.brightness)
        XCTAssertGreaterThan(topDyn.rippleScale, bottomDyn.rippleScale)
        XCTAssertEqual(ExpressiveTouchMapper.dynamics(normalizedY: -0.5), topDyn)
        XCTAssertEqual(ExpressiveTouchMapper.dynamics(normalizedY: 1.5), bottomDyn)

        // 3. 当前和弦共鸣音级与涟漪力度透传契约
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v013-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        let chordDegrees = vm.activeChordToneDegrees
        XCTAssertEqual(chordDegrees.count, 3)
        XCTAssertTrue(chordDegrees.allSatisfy { (1...7).contains($0) })

        vm.setChordPreset(.off)
        XCTAssertTrue(vm.activeChordToneDegrees.isEmpty)

        vm.setChordPreset(.autoMatch)
        vm.toggleFollowGlow()
        XCTAssertTrue(vm.activeChordToneDegrees.isEmpty)
        vm.stopPlayback()

        let bus = StageRippleBus()
        bus.emit(laneIndex: 2, degree: 3, onset: 0.5, colorHex: 0xE64980, intensity: 0.84)
        XCTAssertEqual(bus.events.last?.intensity ?? 0.0, 0.84, accuracy: 1e-5)
    }

    @MainActor
    func testCreativeAlchemyRound7VibratoAndStructuralAnchors() throws {
        // 1. HarmonicVibratoMapper：±24 音分钳位、音高偏移方向与越界安全
        let sharp = HarmonicVibratoMapper.vibratoState(dxFromStar: 18, dyFromStar: 6, radius: 36, baseHz: 440.0, anchorHz: 261.63)
        let flat = HarmonicVibratoMapper.vibratoState(dxFromStar: -18, dyFromStar: 6, radius: 36, baseHz: 440.0, anchorHz: 261.63)
        let extreme = HarmonicVibratoMapper.vibratoState(dxFromStar: 500, dyFromStar: -500, radius: 0, baseHz: 440.0, anchorHz: 261.63)
        XCTAssertGreaterThan(sharp.frequencyHz, 440.0)
        XCTAssertLessThan(flat.frequencyHz, 440.0)
        XCTAssertEqual(extreme.centsOffset, 24.0, accuracy: 1e-5)
        XCTAssertGreaterThanOrEqual(sharp.swellGain, 0.08)
        XCTAssertLessThanOrEqual(extreme.swellGain, 0.20)
        XCTAssertTrue(extreme.frequencyHz.isFinite && extreme.sympatheticHz.isFinite)

        // 2. 1 / 5 结构定锚轨道判断
        let anchors = (0..<8).filter { PreLinguisticGuideGeometry.isStructuralAnchorLane($0) }
        XCTAssertEqual(anchors, [0, 4, 7])

        // 3. 连续双声波震荡器 48kHz 离线发声与安全收音清零
        let synth = FeltPianoSynth()
        let pairRes = try synth.verifyContinuousPairRenderTelemetry(sampleRate: 48_000.0, hzA: 329.63, hzB: 261.63, gain: 0.20)
        XCTAssertTrue(pairRes.peak.isFinite)
        XCTAssertGreaterThan(pairRes.peak, 0.03)
        XCTAssertLessThanOrEqual(pairRes.peak, 1.0)
        XCTAssertGreaterThan(pairRes.duringEnvelope.rmsEnergy, 0.0)
        XCTAssertEqual(pairRes.afterStopEnvelope.rmsEnergy, 0.0, accuracy: 1e-6)

        // 4. StudioViewModel 星环揉弦开关与防误触/防长鸣收尾保护
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v014-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.pentatonicSafe = false
        vm.beginOrUpdateStarVibrato(laneIndex: 2, dx: 18, dy: 8, hitRadius: 36)
        XCTAssertEqual(vm.activeVibratoLane, 2)
        vm.endStarVibrato()
        XCTAssertNil(vm.activeVibratoLane)

        vm.pentatonicSafe = true
        vm.beginOrUpdateStarVibrato(laneIndex: 3, dx: 12, dy: 4, hitRadius: 36)
        XCTAssertNil(vm.activeVibratoLane, "五音模式屏蔽半音轨道时不得误触发持续揉弦")

        vm.beginOrUpdateStarVibrato(laneIndex: 4, dx: -10, dy: 6, hitRadius: 36)
        XCTAssertEqual(vm.activeVibratoLane, 4)
        vm.stopPlayback()
        XCTAssertNil(vm.activeVibratoLane)

        // 5. 空明信片无字图形渲染校验
        let emptyDoc = MelodyDocument(title: "空盘测试", subtitle: "", notes: [])
        let pngData = VinylPostcardExporter.renderPNGData(document: emptyDoc, isNight: true)
        XCTAssertNotNil(pngData)
    }

    @MainActor
    func testCreativeAlchemyRound8IntervalSilkAndVoiceOverStage() throws {
        // 1. 棱镜音程丝线几何美学校验：级进轻盈无外晕，大跳加粗发光
        let step = IntervalSilkStyle.metrics(fromLane: 0, toLane: 1, isNight: false)
        let leap = IntervalSilkStyle.metrics(fromLane: 0, toLane: 4, isNight: true)
        let wideLeap = IntervalSilkStyle.metrics(fromLane: 0, toLane: 7, isNight: false)
        XCTAssertFalse(step.isExpressiveLeap)
        XCTAssertEqual(step.glowWidth, 0.0, accuracy: 1e-5)
        XCTAssertTrue(leap.isExpressiveLeap)
        XCTAssertGreaterThan(leap.glowWidth, 0.0)
        XCTAssertGreaterThan(leap.coreWidth, step.coreWidth)
        XCTAssertTrue(wideLeap.isExpressiveLeap)
        XCTAssertGreaterThanOrEqual(wideLeap.coreWidth, leap.coreWidth)

        // 2. VoiceOver 主舞台逐音升降调与安全边界钳位
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v015-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.document = MelodyDocument(
            title: "盲人可调旋律",
            subtitle: "",
            notes: [NoteBead(degree: 3, octaveOffset: 0, rawOnset: 0.2, rawDuration: 0.5)]
        )
        vm.pentatonicSafe = true
        vm.selectedBeadID = vm.document.notes.first?.id

        vm.shiftSelectedBeadPitch(delta: 1)
        XCTAssertEqual(vm.document.notes.first?.degree, 5, "五音模式升一音应自动跳过被屏蔽的 4 (Fa) 落入 5 (Sol)")
        XCTAssertNil(vm.statusToast)

        vm.shiftSelectedBeadPitch(delta: -1)
        XCTAssertEqual(vm.document.notes.first?.degree, 3)

        vm.shiftSelectedBeadPitch(delta: 20)
        XCTAssertEqual(vm.document.notes.first?.degree, 1)
        XCTAssertEqual(vm.document.notes.first?.octaveOffset, 1)

        vm.shiftSelectedBeadPitch(delta: -20)
        XCTAssertEqual(vm.document.notes.first?.degree, 1)
        XCTAssertEqual(vm.document.notes.first?.octaveOffset, 0)

        // 3. 主舞台实时语义读音摘要校验（含曲名、音符数、选中拍且零 Emoji）
        let summary = vm.stageAccessibilitySummary
        XCTAssertTrue(summary.contains("盲人可调旋律"))
        XCTAssertTrue(summary.contains("1 个音"))
        XCTAssertTrue(summary.contains("第 1 拍"))
        for scalar in summary.unicodeScalars {
            let v = scalar.value
            let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
            XCTAssertFalse(isEmoji)
        }
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound9VocalRibbonSustainAndMiniVinyl() throws {
        // 1. LivePitchContourFilter 自适应噪底、三点中值滤波与活体音高轨迹归一化
        let quietFloor = LivePitchContourFilter.adaptiveNoiseFloorRMS(peakRMS: 0.01)
        let loudFloor = LivePitchContourFilter.adaptiveNoiseFloorRMS(peakRMS: 0.40)
        XCTAssertEqual(quietFloor, 0.004, accuracy: 1e-6)
        XCTAssertGreaterThan(loudFloor, quietFloor)

        let glitchSpike = LivePitchContourFilter.medianSmooth([12.0, 24.0, 12.2, 12.4])
        XCTAssertEqual(glitchSpike[1], 12.2, accuracy: 1e-5, "孤立八度毛刺必须被中值滤波抹平")

        let flatHum = LivePitchContourFilter.normalizeSemitoneTrace([12.0, 12.1, 12.2, 12.05])
        XCTAssertEqual(flatHum.count, 4)
        XCTAssertTrue(flatHum.allSatisfy { abs($0 - 0.48) < 1e-5 }, "平稳单音轻哼时音高丝带应稳在中心")

        let risingTrace = LivePitchContourFilter.normalizeSemitoneTrace([0.0, 4.0, 7.0, 12.0])
        XCTAssertEqual(risingTrace.count, 4)
        XCTAssertTrue(zip(risingTrace, risingTrace.dropFirst()).allSatisfy { $0 <= $1 })
        XCTAssertTrue(risingTrace.allSatisfy { $0 >= 0.08 && $0 <= 0.92 })

        let voiced = LivePitchContourFilter.extractVoicedSemitones(
            pitchHz: [120.0, 220.0, 440.0, 80.0],
            confidence: [0.9, 0.9, 0.9, 0.9],
            frameRMS: [0.001, 0.15, 0.25, 0.002]
        )
        XCTAssertEqual(voiced.count, 2, "低于自适应噪底的帧必须被静音门限剔除")

        // 2. TactileSustainStage 三档呼吸延音节拍门槛与无 Emoji/黑话校验
        let s0 = TactileSustainStage.stage(forHeldSeconds: -0.5)
        let s1 = TactileSustainStage.stage(forHeldSeconds: 0.50)
        let s2 = TactileSustainStage.stage(forHeldSeconds: 1.00)
        let s3 = TactileSustainStage.stage(forHeldSeconds: 1.60)
        XCTAssertEqual([s0.tier, s1.tier, s2.tier, s3.tier], [0, 1, 2, 3])
        XCTAssertLessThan(s0.haloScale, s1.haloScale)
        XCTAssertLessThan(s1.haloScale, s2.haloScale)
        XCTAssertLessThan(s2.haloScale, s3.haloScale)
        XCTAssertLessThan(s0.targetDuration, s1.targetDuration)
        XCTAssertLessThan(s1.targetDuration, s2.targetDuration)
        XCTAssertLessThan(s2.targetDuration, s3.targetDuration)
        for stage in [s0, s1, s2, s3] {
            XCTAssertFalse(stage.label.contains("音珠"))
            for scalar in stage.label.unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji)
            }
        }

        // 3. HumCapturePipeline 初始干净状态与重采样比例校验
        let router = HalfDuplexAudioRouter()
        let synth = FeltPianoSynth()
        let pipeline = HumCapturePipeline(router: router, synth: synth)
        XCTAssertTrue(pipeline.livePitchTrace.isEmpty)
        XCTAssertTrue(pipeline.statusMessage.isEmpty)
        let resampled = HumCapturePipeline.resampleLinear([Float](repeating: 0.25, count: 4800), from: 48_000.0, to: 16_000.0)
        XCTAssertEqual(resampled.count, 1600)
    }

    @MainActor
    func testCreativeAlchemyRound10SpatialAcousticsAndThreeStagePostcards() throws {
        // 1. AcousticSpaceProfile 五色情绪空间气候校验
        for mode in ScaleMode.allCases {
            let prof = AcousticSpaceProfile.profile(for: mode)
            XCTAssertGreaterThanOrEqual(prof.reverbWetMix, 14.0)
            XCTAssertLessThanOrEqual(prof.reverbWetMix, 44.0)
            XCTAssertGreaterThanOrEqual(prof.warmthDamping, 0.70)
            XCTAssertLessThanOrEqual(prof.warmthDamping, 1.25)
            XCTAssertGreaterThanOrEqual(prof.stereoSpread, 0.85)
        }
        let dreamProf = AcousticSpaceProfile.profile(for: .cloudLydian)
        let brightProf = AcousticSpaceProfile.profile(for: .brightMajor)
        let minorProf = AcousticSpaceProfile.profile(for: .wistfulMinor)
        XCTAssertGreaterThan(dreamProf.reverbWetMix, brightProf.reverbWetMix)
        XCTAssertGreaterThan(brightProf.warmthDamping, minorProf.warmthDamping)

        // 2. AcousticSpatialPanMapper 三态主舞台方位映射与安全钳位
        for mode in StageVisualMode.allCases {
            let pMid = AcousticSpatialPanMapper.pan(forBeatOnset: 2.0, totalDuration: 4.0, visualMode: mode)
            XCTAssertTrue(pMid.isFinite)
            XCTAssertGreaterThanOrEqual(pMid, -0.58)
            XCTAssertLessThanOrEqual(pMid, 0.58)
            XCTAssertEqual(AcousticSpatialPanMapper.pan(forBeatOnset: .nan, totalDuration: 4.0, visualMode: mode), 0.0)
            XCTAssertEqual(AcousticSpatialPanMapper.pan(forBeatOnset: 1.0, totalDuration: 0.0, visualMode: mode), 0.0)
        }
        let riverLeft = AcousticSpatialPanMapper.pan(forBeatOnset: 0.0, totalDuration: 4.0, visualMode: .flowingRiver)
        let riverRight = AcousticSpatialPanMapper.pan(forBeatOnset: 4.0, totalDuration: 4.0, visualMode: .flowingRiver)
        XCTAssertLessThan(riverLeft, 0.0)
        XCTAssertGreaterThan(riverRight, 0.0)

        // 3. FeltPianoSynth 48kHz 离线立体声像与空间气候应用验证
        let synth = FeltPianoSynth()
        synth.applySpaceProfile(dreamProf)
        XCTAssertEqual(synth.currentSpaceProfile(), dreamProf)

        let leftRender = try synth.verifySpatialPanOfflineTelemetry(
            sampleRate: 48_000.0,
            frequency: 440.0,
            pan: -0.55,
            spaceProfile: brightProf
        )
        XCTAssertEqual(leftRender.reverbInRate, 48_000.0, accuracy: 1.0)
        XCTAssertEqual(leftRender.reverbOutRate, 48_000.0, accuracy: 1.0)
        XCTAssertGreaterThan(leftRender.peakL, leftRender.peakR)

        let rightRender = try synth.verifySpatialPanOfflineTelemetry(
            sampleRate: 48_000.0,
            frequency: 440.0,
            pan: 0.55,
            spaceProfile: brightProf
        )
        XCTAssertGreaterThan(rightRender.peakR, rightRender.peakL)

        // 4. 三态所见即所得黑胶明信片离线 PNG 渲染校验
        let emptyDoc = MelodyDocument(title: "空态明信片", subtitle: "", notes: [])
        for vMode in StageVisualMode.allCases {
            for night in [false, true] {
                let png = VinylPostcardExporter.renderPNGData(
                    document: SpecimenLibrary.saintSaensTheSwan,
                    shadowEnabled: true,
                    isNight: night,
                    visualMode: vMode
                )
                XCTAssertNotNil(png, "\(vMode.rawValue) 明信片 PNG 不得为空")
                XCTAssertGreaterThan(png?.count ?? 0, 1000)

                let emptyPng = VinylPostcardExporter.renderPNGData(
                    document: emptyDoc,
                    isNight: night,
                    visualMode: vMode
                )
                XCTAssertNotNil(emptyPng)
            }
        }
    }

    @MainActor
    func testCreativeAlchemyRound11StringDecayRibbonVibratoAndVoiceOverDuration() throws {
        // 1. 跨音高琴弦物理阻尼律单调性与安全边界验证
        let bassDecay = PitchScaledAcousticEnvelope.scaledDecay(baseDecay: 1.8, frequency: 130.81)
        let midDecay = PitchScaledAcousticEnvelope.scaledDecay(baseDecay: 1.8, frequency: 261.63)
        let trebleDecay = PitchScaledAcousticEnvelope.scaledDecay(baseDecay: 1.8, frequency: 1046.50)
        XCTAssertGreaterThan(bassDecay, midDecay)
        XCTAssertGreaterThan(midDecay, trebleDecay)
        XCTAssertGreaterThan(PitchScaledAcousticEnvelope.highFrequencyAirAbsorption(frequency: 130.81),
                             PitchScaledAcousticEnvelope.highFrequencyAirAbsorption(frequency: 1046.50))
        let nanDecay = PitchScaledAcousticEnvelope.scaledDecay(baseDecay: .nan, frequency: 0.0)
        XCTAssertTrue(nanDecay.isFinite && nanDecay >= 0.22)

        // 2. 底栏琴条纵向表达死区与水银光柱 + 揉弦偏移映射验证
        let tapDeadzone = KeyRibbonExpressionMapper.expression(verticalOffsetPt: 6.5, barHeightPt: 62.0)
        XCTAssertFalse(tapDeadzone.isVibratoActive)
        XCTAssertEqual(tapDeadzone.mercuryFraction, 0.0)

        let pushUp = KeyRibbonExpressionMapper.expression(verticalOffsetPt: -26.0, barHeightPt: 62.0)
        XCTAssertTrue(pushUp.isVibratoActive)
        XCTAssertGreaterThan(pushUp.mercuryFraction, 0.18)
        XCTAssertLessThanOrEqual(pushUp.mercuryFraction, 1.0)
        let vibState = HarmonicVibratoMapper.vibratoState(
            dxFromStar: pushUp.vibratoDX,
            dyFromStar: pushUp.vibratoDY,
            radius: 26.0,
            baseHz: 440.0,
            anchorHz: 261.63
        )
        XCTAssertLessThanOrEqual(abs(vibState.centsOffset), 24.0)

        // 3. 主舞台盲人转子时值朗读摘要包含精确拍长与零 Emoji 验证
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v018-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.document = MelodyDocument(
            title: "时值朗读验证",
            subtitle: "",
            notes: [NoteBead(degree: 5, octaveOffset: 0, rawOnset: 0.2, rawDuration: 1.2)]
        )
        vm.selectedBeadID = vm.document.notes.first?.id
        let summary = vm.stageAccessibilitySummary
        XCTAssertTrue(summary.contains("1.2秒"), "选中拍摘要应读出具体秒数以便视障者调控长短音")
        for scalar in summary.unicodeScalars {
            let v = scalar.value
            let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
            XCTAssertFalse(isEmoji)
        }
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound12LiveBrushShelfAcousticsAndCurtain() throws {
        // 1. SketchPitchBrushMapper 单指画线即划即响音高、双耳声像与节流校验
        let highLane = SketchPitchBrushMapper.laneIndex(normalizedTopToBottomY: 0.0, pentatonicSafe: true)
        let lowLane = SketchPitchBrushMapper.laneIndex(normalizedTopToBottomY: 1.0, pentatonicSafe: true)
        let midFaAvoid = SketchPitchBrushMapper.laneIndex(normalizedTopToBottomY: 0.56, pentatonicSafe: true)
        XCTAssertEqual(highLane, 7)
        XCTAssertEqual(lowLane, 0)
        XCTAssertNotEqual(midFaAvoid, 3, "五音模式下画线声画笔同样不得落入易跑调的 4 (Fa)")
        XCTAssertLessThan(SketchPitchBrushMapper.spatialPan(normalizedX: 0.0), 0.0)
        XCTAssertGreaterThan(SketchPitchBrushMapper.spatialPan(normalizedX: 1.0), 0.0)
        XCTAssertTrue(SketchPitchBrushMapper.shouldTrigger(lastTriggerTime: 0.0, now: 1.0))
        XCTAssertFalse(SketchPitchBrushMapper.shouldTrigger(lastTriggerTime: 1.00, now: 1.02))
        XCTAssertTrue(SketchPitchBrushMapper.shouldTrigger(lastTriggerTime: 1.00, now: 1.06))

        // 2. 曲库 28 首作品与情绪光谱关联声学气候校验
        XCTAssertEqual(SpecimenLibrary.all.count, 28)
        for spec in SpecimenLibrary.all {
            let prof = AcousticSpaceProfile.profile(for: spec.scaleMode)
            XCTAssertGreaterThan(prof.reverbWetMix, 12.0)
            let samplePan = AcousticSpatialPanMapper.pan(
                forBeatOnset: spec.notes.first?.displayOnset(grooveStrength: spec.grooveStrength) ?? 0.0,
                totalDuration: spec.totalDuration,
                visualMode: .orbitalDisc
            )
            XCTAssertTrue(samplePan.isFinite)
        }
        for mode in ScaleMode.allCases {
            for scalar in mode.shortSkyLabel.unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji)
            }
        }
    }

    @MainActor
    func testCreativeAlchemyRound13TranspositionGrooveAndDownbeat() throws {
        // 1. GrooveAlignmentEngine 无损节拍吸附与辐射拍线校验
        let unaligned = [
            NoteBead(degree: 1, rawOnset: 0.12, rawDuration: 0.32),
            NoteBead(degree: 3, rawOnset: 0.49, rawDuration: 0.29),
            NoteBead(degree: 5, rawOnset: 0.87, rawDuration: 0.34),
            NoteBead(degree: 1, rawOnset: 1.24, rawDuration: 0.62)
        ]
        let aligned = GrooveAlignmentEngine.populateQuantizedTargets(for: unaligned)
        XCTAssertEqual(aligned.count, 4)
        for i in 0..<4 {
            XCTAssertEqual(aligned[i].rawOnset, unaligned[i].rawOnset, accuracy: 1e-6, "原始呼吸时间戳不得被抹除")
            XCTAssertNotNil(aligned[i].quantizedOnset)
            if i > 0 {
                XCTAssertGreaterThanOrEqual((aligned[i].quantizedOnset ?? 0) - (aligned[i - 1].quantizedOnset ?? 0), 0.10)
            }
            XCTAssertEqual(aligned[i].displayOnset(grooveStrength: 0.0), aligned[i].rawOnset, accuracy: 1e-6)
            XCTAssertEqual(aligned[i].displayOnset(grooveStrength: 1.0), aligned[i].quantizedOnset ?? -1.0, accuracy: 1e-6)
        }
        XCTAssertTrue(GrooveAlignmentEngine.beatSpokeAngles(totalDuration: 3.0, grooveStrength: 0.0, beatStep: 0.36).isEmpty)
        let spokes = GrooveAlignmentEngine.beatSpokeAngles(totalDuration: 3.0, grooveStrength: 1.0, beatStep: 0.36)
        XCTAssertTrue((4...24).contains(spokes.count))

        // 2. RootTranspositionHelper 音区钳位、简标与零 Emoji 无障碍文案校验
        XCTAssertEqual(RootTranspositionHelper.clampedRootMIDI(30), 48)
        XCTAssertEqual(RootTranspositionHelper.clampedRootMIDI(99), 72)
        XCTAssertEqual(RootTranspositionHelper.compactLabel(forRootMIDI: 60), "0")
        XCTAssertEqual(RootTranspositionHelper.compactLabel(forRootMIDI: 65), "+5")
        XCTAssertEqual(RootTranspositionHelper.compactLabel(forRootMIDI: 55), "-5")
        for offset in RootTranspositionHelper.presetOffsets {
            let lbl = RootTranspositionHelper.accessibilityLabel(forRootMIDI: 60 + offset)
            XCTAssertFalse(lbl.isEmpty)
            for scalar in lbl.unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji)
            }
        }

        // 3. StudioViewModel 全曲音区移调与律动混合（不改简谱级数且零日常 Toast）
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v020-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.document = MelodyDocument(title: "移调测试", subtitle: "", rootMIDI: 60, grooveStrength: 0.0, notes: unaligned)
        let originalDegrees = vm.document.notes.map(\.degree)

        vm.setRootMIDI(65)
        XCTAssertEqual(vm.document.rootMIDI, 65)
        XCTAssertEqual(vm.document.notes.map(\.degree), originalDegrees, "移调不得更改原有简谱相对数字")
        XCTAssertNil(vm.statusToast)

        vm.setGrooveStrength(1.0)
        XCTAssertEqual(vm.document.grooveStrength, 1.0, accuracy: 1e-5)
        XCTAssertTrue(vm.document.notes.allSatisfy { $0.quantizedOnset != nil })
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound14RoomReflectionsAndRiverBeatGrid() throws {
        // 1. GrooveAlignmentEngine 曲线视图垂直拍线生成与零律动退化
        XCTAssertTrue(GrooveAlignmentEngine.beatTimestamps(totalDuration: 3.2, grooveStrength: 0.0, beatStep: 0.36).isEmpty)
        let stamps = GrooveAlignmentEngine.beatTimestamps(totalDuration: 3.2, grooveStrength: 0.5, beatStep: 0.40)
        XCTAssertEqual(stamps.count, 8)
        XCTAssertEqual(stamps.first ?? -1.0, 0.0, accuracy: 1e-6)
        XCTAssertTrue(zip(stamps, stamps.dropFirst()).allSatisfy { $0 < $1 })

        // 2. 早期木质琴房交叉反射 + 48kHz 离线立体声分离与清零校验
        let synth = FeltPianoSynth()
        let leftSpatial = try synth.verifySpatialPanOfflineTelemetry(
            sampleRate: 48_000.0,
            frequency: 392.0,
            pan: -0.55,
            spaceProfile: AcousticSpaceProfile.profile(for: .forestDorian)
        )
        XCTAssertGreaterThan(leftSpatial.peakL, leftSpatial.peakR, "加入早期木质交叉反射后左声像直达能量仍须清晰高于右侧")
        XCTAssertLessThanOrEqual(max(leftSpatial.peakL, leftSpatial.peakR), 1.0)

        let postEnv = try synth.verifyOfflineRenderTelemetry(sampleRate: 48_000.0, frequency: 261.63, timbre: .singingCello)
        XCTAssertEqual(postEnv.envelopeAfterSilence.rmsEnergy, 0.0, accuracy: 1e-6, "silenceAll 必须同步清零早期反射环形缓冲")

        // 3. 打开任意名曲与借风格时即时同步空间声学气候
        let store = MelodyNotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chimmo-v021-\(UUID().uuidString)"))
        let vm = StudioViewModel(notebookStore: store)
        vm.openSpecimenForFollowGlow(SpecimenLibrary.lisztLiebestraum)
        XCTAssertEqual(vm.synth.currentSpaceProfile(), AcousticSpaceProfile.profile(for: SpecimenLibrary.lisztLiebestraum.scaleMode))
        vm.borrowHarmonyAtmosphere(from: SpecimenLibrary.debussyClairDeLune)
        XCTAssertEqual(vm.synth.currentSpaceProfile(), AcousticSpaceProfile.profile(for: SpecimenLibrary.debussyClairDeLune.scaleMode))
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound15StudioMIDIAndPostcardSync() throws {
        // 1. GM 乐器映射与多通道 MIDI 导出契约（主奏通道 0 + 伴奏通道 1 + 伴唱通道 2）
        XCTAssertEqual(MIDIExporter.generalMIDIProgram(for: .concertPiano), 0)
        XCTAssertEqual(MIDIExporter.generalMIDIProgram(for: .singingCello), 42)
        XCTAssertEqual(MIDIExporter.generalMIDIProgram(for: .liquidHarp), 46)
        XCTAssertEqual(MIDIExporter.generalMIDIProgram(for: .celestaGlass), 8)

        let doc = MelodyDocument(
            title: "多轨乐器测试",
            subtitle: "",
            rootMIDI: 65,
            scaleMode: .cloudLydian,
            grooveStrength: 1.0,
            notes: GrooveAlignmentEngine.populateQuantizedTargets(for: [
                NoteBead(degree: 1, rawOnset: 0.14, rawDuration: 0.5),
                NoteBead(degree: 5, rawOnset: 1.80, rawDuration: 0.6)
            ])
        )
        let plainMIDI = MIDIExporter.encodeSMF(
            document: doc,
            includeHarmonyCradle: true,
            melodyVoice: .singingCello,
            includeShadowCounterpoint: false
        )
        let duetMIDI = MIDIExporter.encodeSMF(
            document: doc,
            includeHarmonyCradle: true,
            melodyVoice: .singingCello,
            includeShadowCounterpoint: true
        )
        let bytes = [UInt8](duetMIDI)
        XCTAssertEqual(Array(bytes.prefix(4)), [0x4D, 0x54, 0x68, 0x64])
        XCTAssertEqual(Array(bytes.suffix(3)), [0xFF, 0x2F, 0x00])
        // 验证写入了大提琴 Program Change [0xC0, 42] 与伴唱通道 [0x92]
        XCTAssertTrue(zip(bytes, bytes.dropFirst()).contains { $0 == 0xC0 && $1 == 42 })
        XCTAssertTrue(bytes.contains(0x92), "开启巴赫伴唱导出时必须写入独立第 2 通道音符事件")
        XCTAssertGreaterThan(duetMIDI.count, plainMIDI.count)

        // 2. 黑胶明信片律动拍线与移调印章离线渲染校验
        let discPng = VinylPostcardExporter.renderPNGData(
            document: doc,
            melodyVoice: .singingCello,
            shadowEnabled: true,
            isNight: true,
            visualMode: .orbitalDisc
        )
        let riverPng = VinylPostcardExporter.renderPNGData(
            document: doc,
            melodyVoice: .singingCello,
            shadowEnabled: true,
            isNight: false,
            visualMode: .flowingRiver
        )
        XCTAssertGreaterThan(discPng?.count ?? 0, 1000)
        XCTAssertGreaterThan(riverPng?.count ?? 0, 1000)
    }

    @MainActor
    func testCreativeAlchemyRound16NightLampAuditionAndStarDynamics() {
        // 1. 闭眼滑音排拍与删除无缝重排验证
        XCTAssertEqual(NightLampPhraseHelper.nextOnset(after: []), 0.14, accuracy: 1e-6)
        XCTAssertEqual(NightLampPhraseHelper.totalAuditionDuration(of: []), 0.0, accuracy: 1e-6)

        let draft: [NoteBead] = [
            NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.14, rawDuration: 0.40),
            NoteBead(degree: 3, octaveOffset: 0, rawOnset: 0.62, rawDuration: 0.70),
            NoteBead(degree: 5, octaveOffset: 0, rawOnset: 1.40, rawDuration: 0.50)
        ]
        let removedMiddle = NightLampPhraseHelper.removingBead(at: 1, from: draft)
        XCTAssertEqual(removedMiddle.count, 2)
        XCTAssertEqual(removedMiddle[0].degree, 1)
        XCTAssertEqual(removedMiddle[0].rawOnset, 0.14, accuracy: 1e-6)
        XCTAssertEqual(removedMiddle[1].degree, 5)
        // 第一音 duration=0.40 -> max(0.36, 0.40 + 0.08) = 0.48 -> 第二音起点无缝衔接至 0.62
        XCTAssertEqual(removedMiddle[1].rawOnset, 0.62, accuracy: 1e-6)
        XCTAssertNil(removedMiddle[1].quantizedOnset)
        XCTAssertGreaterThan(NightLampPhraseHelper.totalAuditionDuration(of: removedMiddle), 1.2)
        // 越界索引保持原队列不变
        XCTAssertEqual(NightLampPhraseHelper.removingBead(at: 9, from: draft).count, 3)

        // 2. 星环偏心距力学响度与亮度响应 + 非法浮点防护
        let centerHit = StarHitDynamicsMapper.hitDynamics(distancePt: 0.0, hitRadius: 36.0)
        let rimHit = StarHitDynamicsMapper.hitDynamics(distancePt: 34.0, hitRadius: 36.0)
        XCTAssertGreaterThan(centerHit.velocity, rimHit.velocity)
        XCTAssertGreaterThan(centerHit.brightness, rimHit.brightness)
        XCTAssertTrue((0.35...0.90).contains(centerHit.velocity))
        XCTAssertTrue((0.60...1.25).contains(centerHit.brightness))

        let nanGuard = StarHitDynamicsMapper.hitDynamics(distancePt: .nan, hitRadius: 0.0)
        XCTAssertFalse(nanGuard.velocity.isNaN)
        XCTAssertFalse(nanGuard.brightness.isNaN)

        // 3. 主音胸腔移调裁剪与标签校验
        XCTAssertEqual(RootTranspositionHelper.clampedRootMIDI(10), 48)
        XCTAssertEqual(RootTranspositionHelper.clampedRootMIDI(99), 72)
        XCTAssertEqual(RootTranspositionHelper.compactLabel(forRootMIDI: 60), "0")
        XCTAssertEqual(RootTranspositionHelper.compactLabel(forRootMIDI: 65), "+5")
        XCTAssertEqual(RootTranspositionHelper.compactLabel(forRootMIDI: 55), "-5")
        XCTAssertEqual(RootTranspositionHelper.accessibilityLabel(forRootMIDI: 62), "升高 2 半音")
    }

    @MainActor
    func testCreativeAlchemyRound17SympatheticBenchAndPhraseNav() {
        // 1. 琴席左右立体声摆位与木质共鸣箱泛音弦映射
        let leftSpec = SympatheticResonanceMapper.compute(
            laneIndex: 0,
            baseHz: 261.63,
            velocity: 0.68,
            stereoSpread: 1.0,
            pentatonicSafe: false
        )
        let rightSpec = SympatheticResonanceMapper.compute(
            laneIndex: 7,
            baseHz: 523.25,
            velocity: 0.68,
            stereoSpread: 1.0,
            pentatonicSafe: false
        )
        XCTAssertLessThan(leftSpec.keyPan, -0.35)
        XCTAssertGreaterThan(rightSpec.keyPan, 0.35)
        XCTAssertEqual(leftSpec.keyPan + rightSpec.keyPan, 0.0, accuracy: 1e-6)
        XCTAssertEqual(leftSpec.overtoneHz, 261.63 * 1.5, accuracy: 1e-2)
        XCTAssertEqual(rightSpec.overtoneHz, 523.25 * 0.5, accuracy: 1e-2)
        XCTAssertGreaterThan(leftSpec.overtoneVelocity, 0.0)
        XCTAssertGreaterThan(leftSpec.overtonePan, 0.0) // 泛音反向扩散

        // 五音模式下 3 Mi 避开不发音的 7 Si（lane 6）
        let pentaMi = SympatheticResonanceMapper.compute(
            laneIndex: 2,
            baseHz: 329.63,
            velocity: 0.70,
            stereoSpread: 1.0,
            pentatonicSafe: true
        )
        XCTAssertTrue(XylophoneLane.lane(at: pentaMi.sympatheticLaneIndex).isPentatonicSafe)

        // 轻触低力度及 NaN 防护
        let whisperSpec = SympatheticResonanceMapper.compute(laneIndex: 1, baseHz: 293.66, velocity: 0.20)
        XCTAssertEqual(whisperSpec.overtoneVelocity, 0.0, accuracy: 1e-6)
        let nanSpec = SympatheticResonanceMapper.compute(laneIndex: 99, baseHz: .nan, velocity: .nan)
        XCTAssertFalse(nanSpec.keyPan.isNaN)
        XCTAssertFalse(nanSpec.overtoneHz.isNaN)

        // 2. 乐句级跨步导航与开头 4 拍速览
        let doc = SpecimenLibrary.saintSaensTheSwan
        let spans = TheoryLensEngine.buildChordSpans(document: doc, preset: .autoMatch, overrides: [:])
        XCTAssertEqual(PhraseNavigationMapper.openingPreviewCount(for: doc.notes), 4)
        XCTAssertEqual(PhraseNavigationMapper.openingPreviewCount(for: Array(doc.notes.prefix(2))), 2)
        XCTAssertNil(PhraseNavigationMapper.nextPhraseBeatIndex(notes: [], spans: [], grooveStrength: 0, currentBeatIndex: nil, delta: 1))

        let jumpedForward = PhraseNavigationMapper.nextPhraseBeatIndex(
            notes: doc.notes,
            spans: spans,
            grooveStrength: doc.grooveStrength,
            currentBeatIndex: 0,
            delta: 1
        )
        XCTAssertNotNil(jumpedForward)
        XCTAssertGreaterThan(jumpedForward ?? 0, 0)

        let jumpedBack = PhraseNavigationMapper.nextPhraseBeatIndex(
            notes: doc.notes,
            spans: spans,
            grooveStrength: doc.grooveStrength,
            currentBeatIndex: jumpedForward,
            delta: -1
        )
        XCTAssertEqual(jumpedBack, 0)

        // 3. 盲人乐句摘要 + 无例行撤销 Toast 契约
        let vm = StudioViewModel()
        if let midNote = vm.document.notes.dropFirst(min(4, max(0, vm.document.notes.count - 1))).first {
            vm.selectBead(midNote.id, playContext: false)
            XCTAssertTrue(vm.stageAccessibilitySummary.contains("句"))
            let origDegree = vm.document.notes.first(where: { $0.id == midNote.id })?.degree
            vm.shiftSelectedBeadPitch(delta: 1)
            vm.undo()
            XCTAssertNil(vm.statusToast, "撤销不得弹出文字提示条")
            XCTAssertFalse(vm.canUndo)
            let restoredDegree = vm.document.notes.first(where: { $0.id == midNote.id })?.degree
            XCTAssertEqual(restoredDegree, origDegree)
        }
        vm.stepPhrase(delta: 1)
        vm.previewOpeningPhrase()
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound18DrumAccentsSeedPreviewAndShelfHalo() {
        // 1. 节奏鼓四拍重音/次重音/左右声像映射与安全边界
        let beat1 = RhythmDrumAccentMapper.tapVoice(forTapIndex: 0)
        let beat2 = RhythmDrumAccentMapper.tapVoice(forTapIndex: 1)
        let beat3 = RhythmDrumAccentMapper.tapVoice(forTapIndex: 2)
        let beat5 = RhythmDrumAccentMapper.tapVoice(forTapIndex: 4)
        XCTAssertTrue(beat1.isDownbeat)
        XCTAssertEqual(beat1.degree, 1)
        XCTAssertGreaterThan(beat1.velocity, 0.5)
        XCTAssertEqual(beat1.pan, 0.0, accuracy: 1e-6)
        XCTAssertTrue(beat5.isDownbeat)
        XCTAssertLessThan(beat2.pan, 0.0)
        XCTAssertEqual(beat3.degree, 5)
        XCTAssertGreaterThan(beat3.pan, 0.0)
        XCTAssertEqual(RhythmDrumAccentMapper.tapVoice(forTapIndex: -3), beat1)

        // 2. 动态间距节奏柱宽度映射与 NaN 防护
        XCTAssertTrue(RhythmDrumAccentMapper.barVisualMetrics(timestamps: []).isEmpty)
        let taps: [TimeInterval] = [10.0, 10.20, 11.15, 11.35, 11.80]
        let bars = RhythmDrumAccentMapper.barVisualMetrics(timestamps: taps)
        XCTAssertEqual(bars.count, 5)
        XCTAssertTrue(bars[0].isDownbeat)
        XCTAssertTrue(bars[4].isDownbeat)
        XCTAssertLessThan(bars[0].widthPt, bars[1].widthPt) // 0.20s 比 0.95s 更窄
        XCTAssertTrue((8.0...26.0).contains(bars[1].widthPt))

        let nanBars = RhythmDrumAccentMapper.barVisualMetrics(timestamps: [1.0, .nan, .infinity])
        XCTAssertEqual(nanBars.count, 3)
        XCTAssertFalse(nanBars.contains(where: { $0.widthPt.isNaN || $0.heightPt.isNaN }))

        // 3. 鼓点强弱声部录入 + 开头三音变奏即点试听（含空白文档回退）
        let vm = StudioViewModel()
        vm.startRhythmTap()
        vm.recordRhythmDrumTap()
        vm.recordRhythmDrumTap()
        XCTAssertEqual(vm.liveTapTimestamps.count, 2)
        vm.previewSeedShift(index: 0, shift: 2)
        vm.previewSeedShift(index: 2, shift: -3)
        vm.previewSeedShift(index: 9, shift: 1) // 越界保护
        vm.startBlankCanvas()
        vm.previewSeedShift(index: 1, shift: 1) // 空白画布回退试听不崩溃
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound19StudioWAVExportAndTempoPreview() throws {
        // 1. RIFF/WAVE Stereo 16-bit 头部与 NaN 安全编码检验
        let sampleWAV = StudioAudioExporter.encodePCM16StereoWAV(
            left: [0.0, 0.5, -0.5, .nan, 2.0],
            right: [0.0, -0.5, 0.5, .infinity, -2.0],
            sampleRate: 44_100
        )
        XCTAssertEqual(sampleWAV.count, 44 + 5 * 4)
        let bytes = [UInt8](sampleWAV)
        XCTAssertEqual(String(bytes: bytes[0..<4], encoding: .ascii), "RIFF")
        XCTAssertEqual(String(bytes: bytes[8..<12], encoding: .ascii), "WAVE")
        XCTAssertEqual(String(bytes: bytes[12..<16], encoding: .ascii), "fmt ")
        XCTAssertEqual(String(bytes: bytes[36..<40], encoding: .ascii), "data")

        // 2. 整曲离线隔离立体声渲染 + 倍速时长真实联动
        let doc = SpecimenLibrary.saintSaensTheSwan
        let fastWAV = try StudioAudioExporter.renderWAVData(
            document: doc,
            chordPreset: .autoMatch,
            chordOverrides: [:],
            accompanimentTexture: .swanRipple,
            melodyVoice: .singingCello,
            shadowEnabled: true,
            playbackRate: 1.25,
            visualMode: .orbitalDisc,
            sampleRate: 44_100
        )
        let slowWAV = try StudioAudioExporter.renderWAVData(
            document: doc,
            chordPreset: .autoMatch,
            chordOverrides: [:],
            accompanimentTexture: .swanRipple,
            melodyVoice: .singingCello,
            shadowEnabled: true,
            playbackRate: 0.75,
            visualMode: .orbitalDisc,
            sampleRate: 44_100
        )
        XCTAssertGreaterThan(fastWAV.count, 44_100)
        XCTAssertLessThan(fastWAV.count, slowWAV.count, "1.25x 倍速导出的 WAV 文件应显著短于 0.75x")

        // 验证生成 PCM 存在真实有声波形且绝不削波
        let fastBytes = [UInt8](fastWAV)
        var maxSampleAbs = 0
        var idx = 44
        while idx + 1 < fastBytes.count {
            let lo = Int16(fastBytes[idx])
            let hi = Int16(fastBytes[idx + 1]) << 8
            let sample = abs(Int(Int16(bitPattern: UInt16(bitPattern: lo | hi))))
            if sample > maxSampleAbs { maxSampleAbs = sample }
            idx += 8
        }
        XCTAssertGreaterThan(maxSampleAbs, 650, "离线导出的 WAV 波形应有清晰可听声压")
        XCTAssertLessThanOrEqual(maxSampleAbs, 32_767)

        // 3. 空文档兜底与临时 .wav 文件落盘校验
        let emptyDoc = MelodyDocument(
            title: "空曲/测试:1",
            subtitle: "",
            rootMIDI: 60,
            scaleMode: .cloudLydian,
            harmonyProfile: .clearWater,
            grooveStrength: 0.0,
            notes: []
        )
        let emptyWAV = try StudioAudioExporter.renderWAVData(document: emptyDoc, sampleRate: 22_050)
        XCTAssertGreaterThan(emptyWAV.count, 44)
        let emptyHeader = [UInt8](emptyWAV.prefix(12))
        XCTAssertEqual(String(bytes: emptyHeader[0..<4], encoding: .ascii), "RIFF")

        let fileURL = try StudioAudioExporter.writeTemporaryWAVFile(
            document: emptyDoc,
            sampleRate: 22_050
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }
        XCTAssertEqual(fileURL.pathExtension, "wav")
        let diskSize = (try? Data(contentsOf: fileURL).count) ?? 0
        XCTAssertEqual(diskSize, emptyWAV.count)

        // 4. 暂停态调节播放速度时触发双拍节奏耳返与范围钳位且零 Toast
        let vm = StudioViewModel()
        vm.setPlaybackRate(1.25)
        XCTAssertEqual(vm.playbackRate, 1.25, accuracy: 1e-6)
        vm.setPlaybackRate(4.0)
        XCTAssertEqual(vm.playbackRate, 1.6, accuracy: 1e-6)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound20SongbookAndPostcardCipher() throws {
        // 1. 曲库重命名与副本复制独立持久化验证
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo-r20-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = MelodyNotebookStore(directory: tempDir)
        let doc = MelodyDocument(
            title: "初稿",
            subtitle: "",
            rootMIDI: 60,
            scaleMode: .brightMajor,
            harmonyProfile: .feltSun,
            grooveStrength: 0.0,
            notes: [
                NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.2, rawDuration: 0.4),
                NoteBead(degree: 5, octaveOffset: 0, rawOnset: 0.7, rawDuration: 0.5)
            ]
        )
        let saved = store.save(
            document: doc,
            chordPreset: .autoMatch,
            chordOverrides: [:],
            accompanimentTexture: .swanRipple,
            summaryNote: "晴空草稿"
        )
        XCTAssertNil(store.rename(id: saved.id, newTitle: "   \n  "))
        let renamed = store.rename(id: saved.id, newTitle: "  秋夜钢琴  ")
        XCTAssertEqual(renamed?.document.title, "秋夜钢琴")

        let copied = store.duplicate(id: saved.id)
        XCTAssertNotNil(copied)
        XCTAssertNotEqual(copied?.id, saved.id)
        XCTAssertNotEqual(copied?.document.id, saved.document.id)
        XCTAssertEqual(copied?.document.title, "秋夜钢琴 副本")
        XCTAssertEqual(store.entries.count, 2)

        let reloadedStore = MelodyNotebookStore(directory: tempDir)
        XCTAssertEqual(reloadedStore.entries.count, 2)
        XCTAssertTrue(reloadedStore.entries.contains(where: { $0.document.title == "秋夜钢琴" }))
        XCTAssertTrue(reloadedStore.entries.contains(where: { $0.document.title == "秋夜钢琴 副本" }))

        // 2. StudioViewModel 重命名联动且零 Toast
        let vm = StudioViewModel(notebookStore: store)
        vm.openSavedEntry(saved, autoPlay: false)
        vm.renameCurrentSong("雨后回声")
        XCTAssertEqual(vm.document.title, "雨后回声")
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertNil(vm.statusToast)
        XCTAssertEqual(store.entries.first(where: { $0.id == saved.id })?.document.title, "雨后回声")

        // 3. 明信片简谱音符可视条离线快照与 PNG 渲染校验
        let swan = SpecimenLibrary.saintSaensTheSwan
        let cipherSnap = VinylPostcardSnapshot(document: swan, isNight: true, visualMode: .orbitalDisc, includeJianpuStrip: true)
        XCTAssertTrue(cipherSnap.includeJianpuStrip)
        XCTAssertEqual(cipherSnap.jianpuTokens.count, min(14, swan.notes.count))
        let pngData = VinylPostcardExporter.renderPNGData(
            document: swan,
            isNight: true,
            visualMode: .orbitalDisc,
            includeJianpuStrip: true
        )
        XCTAssertGreaterThan(pngData?.count ?? 0, 1000)
    }

    @MainActor
    func testCreativeAlchemyRound21MicroTimingNudgeAndShelfSearch() {
        // 1. 节拍微调防越界避让与 120ms 网格磁吸验证
        let notes: [NoteBead] = [
            NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.20, rawDuration: 0.35),
            NoteBead(degree: 3, octaveOffset: 0, rawOnset: 0.65, rawDuration: 0.40),
            NoteBead(degree: 5, octaveOffset: 0, rawOnset: 1.15, rawDuration: 0.45)
        ]
        // 向前大力微调不得越过前一拍 + 0.09s
        let clampedEarlier = BeatTimingNudgeHelper.nudgedOnset(
            notes: notes,
            targetIndex: 1,
            rawDelta: -2.0,
            grooveStrength: 0.0
        )
        XCTAssertEqual(clampedEarlier, 0.29, accuracy: 1e-6)

        // 向后大力微调不得越过下一拍 - 0.09s
        let clampedLater = BeatTimingNudgeHelper.nudgedOnset(
            notes: notes,
            targetIndex: 1,
            rawDelta: 3.0,
            grooveStrength: 0.0
        )
        XCTAssertEqual(clampedLater, 1.06, accuracy: 1e-6)

        // 整齐律动模式下触发 0.12s 网格对齐且保持邻拍间距
        let snappedNudge = BeatTimingNudgeHelper.nudgedOnset(
            notes: notes,
            targetIndex: 1,
            rawDelta: 0.09,
            grooveStrength: 0.9
        )
        XCTAssertEqual(snappedNudge, 0.72, accuracy: 1e-6)

        // 2. 拖拽混合网格与 NaN 防护
        let freeSnap = BeatTimingNudgeHelper.dragGridSnapOnset(rawOnset: 0.53, grooveStrength: 0.0)
        XCTAssertEqual(freeSnap.onset, 0.53, accuracy: 1e-6)
        let lockedSnap = BeatTimingNudgeHelper.dragGridSnapOnset(rawOnset: 0.53, grooveStrength: 0.85)
        XCTAssertEqual(lockedSnap.gridBucket, 4) // 4 * 0.12 = 0.48
        XCTAssertLessThan(abs(lockedSnap.onset - 0.48), abs(0.53 - 0.48))

        let nanSnap = BeatTimingNudgeHelper.dragGridSnapOnset(rawOnset: .nan, grooveStrength: .nan)
        XCTAssertFalse(nanSnap.onset.isNaN)

        // 3. StudioViewModel 选中拍微调闭环与零 Toast 契约
        let vm = StudioViewModel()
        guard vm.document.notes.count >= 3 else {
            XCTFail("默认样本需至少含 3 个音符")
            return
        }
        let targetID = vm.document.notes[1].id
        let origOnset = vm.document.notes[1].rawOnset
        vm.selectBead(targetID, playContext: false)
        vm.nudgeSelectedBeadTiming(delta: 0.08)
        XCTAssertNil(vm.statusToast)
        XCTAssertTrue(vm.canUndo)
        XCTAssertFalse(vm.document.isSpecimen)
        let movedOnset = vm.document.notes.first(where: { $0.id == targetID })?.rawOnset ?? 0
        XCTAssertGreaterThan(movedOnset, origOnset)
        XCTAssertGreaterThanOrEqual(movedOnset, vm.document.notes[0].rawOnset + 0.089)
        vm.undo()
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound22DuoIPConsoleAndSparkline() {
        // 1. 「咩 × 哞」双子角色定义与零 Emoji 校验
        XCTAssertEqual(ChimmoDuoCharacter.allCases.count, 2)
        for ch in ChimmoDuoCharacter.allCases {
            XCTAssertFalse(ch.chineseName.isEmpty)
            XCTAssertFalse(ch.roleShort.isEmpty)
            XCTAssertFalse(ch.accessibilityLabel.isEmpty)
            for scalar in (ch.chineseName + ch.roleShort + ch.accessibilityLabel).unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji)
            }
        }

        let activeState = ChimmoDuoCompanionState.compute(melodyActive: true, cowAwake: true, isPlaying: true, reduceMotion: false)
        XCTAssertLessThan(activeState.sheepBouncePt, 0)
        XCTAssertGreaterThan(activeState.sheepEarWiggleDeg, 0)
        XCTAssertFalse(activeState.cowSleeping)
        XCTAssertGreaterThan(activeState.cowGlowOpacity, 0.8)

        let reducedState = ChimmoDuoCompanionState.compute(melodyActive: true, cowAwake: false, isPlaying: true, reduceMotion: true)
        XCTAssertEqual(reducedState.sheepBouncePt, 0)
        XCTAssertEqual(reducedState.sheepEarWiggleDeg, 0)
        XCTAssertEqual(reducedState.cowBreathScale, 1.0, accuracy: 1e-6)
        XCTAssertTrue(reducedState.cowSleeping)
        XCTAssertEqual(reducedState.cowGlowOpacity, 0.0, accuracy: 1e-6)

        // 2. 曲库微型旋律曲线采样器（空曲、单音、长曲限幅与边界保真）
        let emptyDoc = MelodyDocument(title: "空", subtitle: "", notes: [])
        XCTAssertTrue(MelodySparklineMapper.samples(for: emptyDoc).isEmpty)

        let singleDoc = MelodyDocument(
            title: "单音",
            subtitle: "",
            notes: [NoteBead(degree: 5, octaveOffset: 0, rawOnset: 0.4, rawDuration: 0.5)]
        )
        let singleSamples = MelodySparklineMapper.samples(for: singleDoc)
        XCTAssertEqual(singleSamples.count, 1)
        XCTAssertEqual(singleSamples[0].xNorm, 0.5, accuracy: 1e-6)
        XCTAssertEqual(singleSamples[0].laneIndex, 4)

        let swan = SpecimenLibrary.saintSaensTheSwan
        let swanSamples = MelodySparklineMapper.samples(for: swan, maxPoints: 18)
        XCTAssertLessThanOrEqual(swanSamples.count, 19)
        XCTAssertGreaterThanOrEqual(swanSamples.count, 4)
        XCTAssertEqual(swanSamples.first?.xNorm ?? -1, 0.0, accuracy: 1e-6)
        XCTAssertEqual(swanSamples.last?.xNorm ?? -1, 1.0, accuracy: 1e-6)
        XCTAssertTrue(swanSamples.allSatisfy { (0.0...1.0).contains($0.xNorm) && (0.0...1.0).contains($0.yNorm) })

        // 3. 声音调色台声学包络波形与伴奏点阵图谱校验
        for voice in MelodyVoice.allCases {
            let env = AcousticSignatureGeometry.voiceEnvelopePoints(for: voice)
            XCTAssertEqual(env.count, 17)
            XCTAssertTrue(env.allSatisfy { (0.0...1.0).contains($0) })
        }
        for tex in AccompanimentTexture.allCases {
            let dots = AcousticSignatureGeometry.accompanimentPatternDots(for: tex)
            XCTAssertFalse(dots.isEmpty)
            XCTAssertTrue(dots.allSatisfy { (0.0...1.0).contains($0.x) && (0.0...1.0).contains($0.y) && $0.radiusScale > 0.5 })
        }

        // 4. 空曲库直达创作、双子试听与哼唱定调音珠零 Toast 联动
        let vm = StudioViewModel()
        vm.triggerNewCreationFromShelf()
        XCTAssertTrue(vm.requestOpenDreamSheet)
        vm.auditionDuoCharacter(.mie)
        vm.auditionDuoCharacter(.mou)
        vm.previewHumReference(degree: 1)
        vm.previewHumReference(degree: 5)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()

        // 5. 含双子印章的日光/夜灯明信片 PNG 渲染校验
        let dayPNG = VinylPostcardExporter.renderPNGData(document: swan, shadowEnabled: true, isNight: false, visualMode: .orbitalDisc)
        let nightPNG = VinylPostcardExporter.renderPNGData(document: swan, shadowEnabled: true, isNight: true, visualMode: .resonanceNebula)
        XCTAssertGreaterThan(dayPNG?.count ?? 0, 1024)
        XCTAssertGreaterThan(nightPNG?.count ?? 0, 1024)
    }

    @MainActor
    func testCreativeAlchemyRound23MorphPreviewFaderAndDurationStrip() {
        // 1. 旋律扩写双曲线对比预览几何校验
        for op in MotifGrowthOperation.allCases {
            let curves = MotifMorphPreviewGeometry.curves(for: op)
            XCTAssertFalse(curves.seedPoints.isEmpty)
            XCTAssertFalse(curves.morphedPoints.isEmpty)
            XCTAssertTrue(curves.seedPoints.allSatisfy { (0.0...1.0).contains($0) })
            XCTAssertTrue(curves.morphedPoints.allSatisfy { (0.0...1.0).contains($0) })
        }

        // 2. 开头三音彩色音高推子直拖映射与边界防护
        XCTAssertEqual(SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: 0.0), 3)
        XCTAssertEqual(SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: 0.5), 0)
        XCTAssertEqual(SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: 1.0), -3)
        XCTAssertEqual(SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: .nan), 0)
        XCTAssertEqual(SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: -5.0), 3)
        XCTAssertEqual(SeedPitchFaderMapper.shift(forNormalizedTopToBottomY: 5.0), -3)

        let lowFill = SeedPitchFaderMapper.normalizedFillHeight(forShift: -3)
        let midFill = SeedPitchFaderMapper.normalizedFillHeight(forShift: 0)
        let highFill = SeedPitchFaderMapper.normalizedFillHeight(forShift: 3)
        XCTAssertLessThan(lowFill, midFill)
        XCTAssertLessThan(midFill, highFill)

        let emptyDoc = MelodyDocument(title: "空", subtitle: "", notes: [])
        let swan = SpecimenLibrary.saintSaensTheSwan
        for idx in 0..<3 {
            for shift in -3...3 {
                let emptyLane = SeedPitchFaderMapper.resolvedLaneIndex(document: emptyDoc, noteIndex: idx, shift: shift)
                let swanLane = SeedPitchFaderMapper.resolvedLaneIndex(document: swan, noteIndex: idx, shift: shift)
                XCTAssertTrue((0...7).contains(emptyLane))
                XCTAssertTrue((0...7).contains(swanLane))
            }
        }

        // 3. 闭眼滑音颗粒时值视觉宽度比例与 NaN 防护
        let shortRatio = NightLampPhraseHelper.normalizedDurationRatio(for: 0.28)
        let longRatio = NightLampPhraseHelper.normalizedDurationRatio(for: 1.85)
        let nanRatio = NightLampPhraseHelper.normalizedDurationRatio(for: .nan)
        XCTAssertEqual(shortRatio, 0.0, accuracy: 1e-6)
        XCTAssertEqual(longRatio, 1.0, accuracy: 1e-6)
        XCTAssertTrue(nanRatio.isFinite)

        let shortWidth = NightLampPhraseHelper.chipVisualWidth(forDuration: 0.28)
        let longWidth = NightLampPhraseHelper.chipVisualWidth(forDuration: 1.85)
        XCTAssertEqual(shortWidth, 46.0, accuracy: 1e-4)
        XCTAssertEqual(longWidth, 98.0, accuracy: 1e-4)
        XCTAssertLessThan(shortWidth, longWidth)

        // 4. 主舞台双子问候和音零 Toast 联动
        let vm = StudioViewModel()
        vm.auditionDuoGreeting()
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound24HarmonyStripChordPresetsAndTimingFix() throws {
        // 1. 四幕和声触控轨几何映射与防呆（正常乐曲、空集、NaN/0 总时长、五档短标无 Emoji）
        let swan = SpecimenLibrary.saintSaensTheSwan
        let spans = TheoryLensEngine.buildChordSpans(document: swan, preset: .autoMatch)
        let segments = HarmonyCurtainStripMapper.segments(from: spans, totalDuration: swan.totalDuration)
        XCTAssertEqual(segments.count, spans.count)
        let totalFrac = segments.reduce(0.0) { $0 + $1.fractionWidth }
        XCTAssertEqual(totalFrac, 1.0, accuracy: 1e-5)
        XCTAssertTrue(segments.allSatisfy { $0.fractionWidth >= 0.10 && !$0.romanLabel.isEmpty })

        XCTAssertTrue(HarmonyCurtainStripMapper.segments(from: [], totalDuration: 4.0).isEmpty)

        let nanSegments = HarmonyCurtainStripMapper.segments(from: spans, totalDuration: .nan)
        XCTAssertEqual(nanSegments.count, spans.count)
        XCTAssertEqual(nanSegments.reduce(0.0) { $0 + $1.fractionWidth }, 1.0, accuracy: 1e-5)
        XCTAssertTrue(nanSegments.allSatisfy { $0.fractionWidth.isFinite && $0.fractionWidth > 0 })

        for preset in ChordProgressionPreset.allCases {
            let tag = HarmonyCurtainStripMapper.shortPresetTag(for: preset)
            XCTAssertFalse(tag.isEmpty)
            for scalar in tag.unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji)
            }
        }

        // 2. 删除曲库当前打开作品同步清理孤立 currentSavedEntryID + updateBeatTiming 停播与改写标记
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r24_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let isolatedStore = MelodyNotebookStore(directory: tempDir)
        let vm = StudioViewModel(notebookStore: isolatedStore)
        vm.openSpecimen(swan, autoPlay: true)
        XCTAssertTrue(vm.isPlaying)
        let firstID = try XCTUnwrap(vm.document.notes.first?.id)

        vm.updateBeatTiming(beadID: firstID, newOnset: 0.36)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertTrue(vm.document.title.contains("我的改写"))
        XCTAssertNil(vm.statusToast)

        vm.updateBeatTiming(beadID: firstID, newOnset: .nan)
        let clampedBeat = vm.document.notes.first(where: { $0.id == firstID })
        XCTAssertTrue((clampedBeat?.rawOnset ?? 0).isFinite)
        XCTAssertGreaterThanOrEqual(clampedBeat?.rawOnset ?? 0, 0.08)

        vm.saveCurrentToNotebook()
        let savedID = try XCTUnwrap(vm.currentSavedEntryID)
        XCTAssertEqual(isolatedStore.entries.count, 1)
        vm.deleteSavedEntry(id: savedID)
        XCTAssertNil(vm.currentSavedEntryID)
        XCTAssertTrue(isolatedStore.entries.isEmpty)

        // 3. 五档和弦进行切换与清唱开关一致性（零 Toast）
        for preset in [ChordProgressionPreset.classicPop, .summerFloat, .warmStory, .off, .autoMatch] {
            vm.setChordPreset(preset)
            XCTAssertEqual(vm.chordPreset, preset)
            XCTAssertTrue(vm.chordOverrides.isEmpty)
            XCTAssertEqual(vm.cradleEnabled, preset != .off)
        }
        vm.stopPlayback()
        XCTAssertNil(vm.statusToast)
    }

    @MainActor
    func testCreativeAlchemyRound25LivingDuoKinematicsChoirCategoryBadgesAndEditFixes() throws {
        // 1. 「咩 × 哞」实时呼吸、眨眼、视线跟随与小憩弧线运动学验证
        let reduced = ChimmoDuoMotionKinematics.compute(
            phaseTime: 0.05,
            melodyActive: false,
            cowAwake: false,
            isPlaying: true,
            gazeBias: 0.8,
            reduceMotion: true
        )
        XCTAssertEqual(reduced.sheepBreathY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(reduced.sheepBreathScaleY, 1.0, accuracy: 1e-6)
        XCTAssertFalse(reduced.sheepBlinkClosed)
        XCTAssertEqual(reduced.cowBreathY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(reduced.cowBreathScale, 1.0, accuracy: 1e-6)
        XCTAssertFalse(reduced.cowBlinkClosed)
        XCTAssertEqual(reduced.sleepArcProgress, 0.0, accuracy: 1e-6)
        XCTAssertEqual(reduced.gazeOffsetX, 0.0, accuracy: 1e-6)

        let neutralClamped = ChimmoDuoMotionKinematics.compute(
            phaseTime: 0.0,
            melodyActive: false,
            cowAwake: true,
            isPlaying: false,
            gazeBias: 2.5,
            reduceMotion: false
        )
        XCTAssertEqual(neutralClamped.gazeOffsetX, 1.0, accuracy: 1e-6)

        let sheepBlink = ChimmoDuoMotionKinematics.compute(
            phaseTime: 0.05,
            melodyActive: false,
            cowAwake: true,
            isPlaying: false,
            gazeBias: -0.5,
            reduceMotion: false
        )
        XCTAssertTrue(sheepBlink.sheepBlinkClosed)
        XCTAssertEqual(sheepBlink.gazeOffsetX, -0.5, accuracy: 1e-6)

        let singingSuppressesBlink = ChimmoDuoMotionKinematics.compute(
            phaseTime: 0.05,
            melodyActive: true,
            cowAwake: true,
            isPlaying: true,
            gazeBias: 0.0,
            reduceMotion: false
        )
        XCTAssertFalse(singingSuppressesBlink.sheepBlinkClosed)

        let cowBlink = ChimmoDuoMotionKinematics.compute(
            phaseTime: 3.50,
            melodyActive: false,
            cowAwake: true,
            isPlaying: false,
            gazeBias: 0.2,
            reduceMotion: false
        )
        XCTAssertTrue(cowBlink.cowBlinkClosed)

        let cowSleeping = ChimmoDuoMotionKinematics.compute(
            phaseTime: 1.25,
            melodyActive: false,
            cowAwake: false,
            isPlaying: false,
            gazeBias: 0.0,
            reduceMotion: false
        )
        XCTAssertFalse(cowSleeping.cowBlinkClosed)
        XCTAssertGreaterThan(cowSleeping.sleepArcProgress, 0.0)

        let nanSafe = ChimmoDuoMotionKinematics.compute(
            phaseTime: .nan,
            melodyActive: false,
            cowAwake: false,
            isPlaying: false,
            gazeBias: .infinity,
            reduceMotion: false
        )
        XCTAssertTrue(nanSafe.sheepBreathY.isFinite && nanSafe.cowBreathScale.isFinite && nanSafe.gazeOffsetX.isFinite)

        // 2. 曲库短分类图标短标映射与 0 Emoji 校验
        let badges = LibraryCategoryBadgeMapper.badges()
        XCTAssertEqual(badges.count, SpecimenLibrary.categories.count)
        for badge in badges {
            XCTAssertFalse(badge.shortLabel.isEmpty)
            XCTAssertLessThanOrEqual(badge.shortLabel.count, 2)
            XCTAssertFalse(badge.iconName.isEmpty)
            for scalar in (badge.shortLabel + badge.rawCategory).unicodeScalars {
                let v = scalar.value
                let isEmoji = (0x1F000...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v) || (0xFE00...0xFE0F).contains(v)
                XCTAssertFalse(isEmoji)
            }
        }
        XCTAssertEqual(LibraryCategoryBadgeMapper.badge(for: "室内乐精选").shortLabel, "室内")
        XCTAssertEqual(LibraryCategoryBadgeMapper.badge(for: "   ").shortLabel, "曲目")

        // 3. 时值修改/删除断连修复、空画布双子起音与七小只试听零 Toast 契约
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r25_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.openSpecimen(SpecimenLibrary.saintSaensTheSwan, autoPlay: true)
        XCTAssertTrue(vm.isPlaying)
        let firstID = try XCTUnwrap(vm.document.notes.first?.id)
        let origDur = vm.document.notes[0].rawDuration

        vm.adjustSelectedBeadDuration(delta: 0.22)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertTrue(vm.document.title.contains("我的改写"))
        XCTAssertGreaterThan(vm.document.notes.first(where: { $0.id == firstID })?.rawDuration ?? 0, origDur)
        XCTAssertNil(vm.statusToast)

        vm.adjustSelectedBeadDuration(delta: .nan)
        XCTAssertTrue((vm.document.notes.first(where: { $0.id == firstID })?.rawDuration ?? -1).isFinite)

        vm.togglePlayback()
        XCTAssertTrue(vm.isPlaying)
        vm.deleteSelectedBead()
        XCTAssertFalse(vm.isPlaying)
        XCTAssertNil(vm.statusToast)

        // 单音删除清空画布时同步清零选中态、提示灯与和弦段索引
        vm.startBlankCanvas()
        vm.placeNoteOnCanvas(degree: 1, octaveOffset: 0, atTime: 0.16)
        vm.smartHintActive = true
        XCTAssertEqual(vm.document.notes.count, 1)
        vm.deleteSelectedBead()
        XCTAssertTrue(vm.document.notes.isEmpty)
        XCTAssertNil(vm.selectedBeadID)
        XCTAssertFalse(vm.smartHintActive)
        XCTAssertEqual(vm.activeChordSpanID, 0)

        // 空画布一键「咩哞起音」与七小只声部试听
        vm.chordPreset = .off
        vm.plantDuoStarterMotif()
        XCTAssertEqual(vm.document.notes.count, 5)
        XCTAssertTrue(vm.pentatonicSafe)
        XCTAssertTrue(vm.cradleEnabled)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertEqual(vm.selectedBeadID, vm.document.notes.first?.id)
        XCTAssertNil(vm.statusToast)

        for member in ChimmoMember.allCases {
            vm.auditionChimmoMember(member)
        }
        vm.stopPlayback()
        XCTAssertNil(vm.statusToast)
    }

    @MainActor
    func testCreativeAlchemyRound26DreamBrushKinematicsSignaturePulseAndUndoSync() throws {
        // 1. DreamBrushKinematics 静止、敲击四拍脉冲与高低拖拽越界防卫
        let idle = DreamBrushKinematics.reaction(brushNormalizedY: nil, brushNormalizedX: nil, tapCount: 0)
        XCTAssertEqual(idle.sheepTiltProgress, 0.0, accuracy: 0.0001)
        XCTAssertEqual(idle.sheepGazeBias, 0.0, accuracy: 0.0001)
        XCTAssertFalse(idle.sheepSinging)
        XCTAssertFalse(idle.cowBeatHighlight)
        XCTAssertEqual(idle.beatCycleIndex, 0)

        let tapDownbeat = DreamBrushKinematics.reaction(brushNormalizedY: nil, brushNormalizedX: nil, tapCount: 1)
        XCTAssertEqual(tapDownbeat.beatCycleIndex, 0)
        XCTAssertTrue(tapDownbeat.cowBeatHighlight)
        XCTAssertTrue(tapDownbeat.sheepSinging)
        XCTAssertLessThan(tapDownbeat.sheepGazeBias, 0.0)

        let tapSecond = DreamBrushKinematics.reaction(brushNormalizedY: nil, brushNormalizedX: nil, tapCount: 2)
        XCTAssertEqual(tapSecond.beatCycleIndex, 1)
        XCTAssertFalse(tapSecond.cowBeatHighlight)
        XCTAssertFalse(tapSecond.sheepSinging)

        let tapCycleRestart = DreamBrushKinematics.reaction(brushNormalizedY: nil, brushNormalizedX: nil, tapCount: 5)
        XCTAssertEqual(tapCycleRestart.beatCycleIndex, 0)
        XCTAssertTrue(tapCycleRestart.cowBeatHighlight)

        let negativeTap = DreamBrushKinematics.reaction(brushNormalizedY: nil, brushNormalizedX: nil, tapCount: -4)
        XCTAssertEqual(negativeTap.beatCycleIndex, 0)
        XCTAssertFalse(negativeTap.cowBeatHighlight)

        let highBrush = DreamBrushKinematics.reaction(brushNormalizedY: 0.08, brushNormalizedX: 0.85, tapCount: 2)
        XCTAssertTrue(highBrush.sheepSinging)
        XCTAssertGreaterThan(highBrush.sheepTiltProgress, 0.5)
        XCTAssertGreaterThan(highBrush.sheepGazeBias, 0.3)

        let lowBrush = DreamBrushKinematics.reaction(brushNormalizedY: 0.95, brushNormalizedX: 0.1, tapCount: 1)
        XCTAssertTrue(lowBrush.sheepSinging)
        XCTAssertLessThan(lowBrush.sheepTiltProgress, -0.5)
        XCTAssertLessThan(lowBrush.sheepGazeBias, -0.3)
        XCTAssertTrue(lowBrush.cowBeatHighlight)

        let nanBrush = DreamBrushKinematics.reaction(brushNormalizedY: .nan, brushNormalizedX: .infinity, tapCount: 1)
        XCTAssertEqual(nanBrush.sheepTiltProgress, 0.0, accuracy: 0.0001)
        XCTAssertTrue(nanBrush.sheepGazeBias.isFinite)

        // 2. AcousticSignatureAnimationHelper 试听波形扫描游标与点阵索引映射
        XCTAssertEqual(AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: -0.1), 0.0, accuracy: 0.0001)
        XCTAssertEqual(
            AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: 0.325, durationSeconds: 0.65),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: 2.0, durationSeconds: 0.65),
            1.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: .nan), 0.0, accuracy: 0.0001)
        XCTAssertEqual(
            AcousticSignatureAnimationHelper.sweepProgress(elapsedSeconds: 0.3, durationSeconds: 0.01),
            0.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(AcousticSignatureAnimationHelper.activeIndex(progress: 0.0, itemCount: 5), 0)
        XCTAssertEqual(AcousticSignatureAnimationHelper.activeIndex(progress: 0.5, itemCount: 5), 2)
        XCTAssertEqual(AcousticSignatureAnimationHelper.activeIndex(progress: 1.0, itemCount: 5), 4)
        XCTAssertNil(AcousticSignatureAnimationHelper.activeIndex(progress: 0.5, itemCount: 0))
        XCTAssertNil(AcousticSignatureAnimationHelper.activeIndex(progress: .nan, itemCount: 5))

        // 3. StudioViewModel.undo() 同步恢复 AcousticSpaceProfile 声场与 pentatonicSafe 五声安全锁
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r26_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.startBlankCanvas()
        vm.plantDuoStarterMotif()
        XCTAssertTrue(vm.pentatonicSafe)
        let baseMode = vm.document.scaleMode
        let switchedMode: ScaleMode = (baseMode == .wistfulMinor) ? .brightMajor : .wistfulMinor

        vm.setScaleMode(switchedMode)
        XCTAssertEqual(vm.document.scaleMode, switchedMode)
        XCTAssertEqual(vm.synth.currentSpaceProfile(), AcousticSpaceProfile.profile(for: switchedMode))

        vm.pentatonicSafe = false
        vm.undo()

        XCTAssertEqual(vm.document.scaleMode, baseMode)
        XCTAssertEqual(vm.synth.currentSpaceProfile(), AcousticSpaceProfile.profile(for: baseMode))
        XCTAssertTrue(vm.pentatonicSafe)
        XCTAssertNil(vm.statusToast)
    }

    @MainActor
    func testCreativeAlchemyRound27KilnHardwareMaterialsTransportRingAndStageRedesign() throws {
        // 1. ChimmoPalette 暖窑日光与深夜天鹅绒硬件材质底盘区分
        let day = ChimmoPalette(isNight: false)
        let night = ChimmoPalette(isNight: true)
        XCTAssertNotEqual(day.paper, night.paper)
        XCTAssertNotEqual(day.woodTrayTop, night.woodTrayTop)
        XCTAssertNotEqual(day.woodTrayBottom, night.woodTrayBottom)
        XCTAssertNotEqual(day.brassHairline, night.brassHairline)
        XCTAssertNotEqual(day.glazeHighlight, night.glazeHighlight)
        XCTAssertNotEqual(day.recessShadow, night.recessShadow)

        // 2. KilnKeyPhysics 四态物理高度、下压位移与静音压扁边界
        let rest = KilnKeyPhysics.elevation(isPressed: false, isFollowTarget: false, isMuted: false)
        let pressed = KilnKeyPhysics.elevation(isPressed: true, isFollowTarget: false, isMuted: false)
        let follow = KilnKeyPhysics.elevation(isPressed: false, isFollowTarget: true, isMuted: false)
        let muted = KilnKeyPhysics.elevation(isPressed: true, isFollowTarget: true, isMuted: true)

        XCTAssertEqual(rest.frontLipHeight, 4.2, accuracy: 0.0001)
        XCTAssertEqual(rest.pressOffsetY, 0.0, accuracy: 0.0001)
        XCTAssertLessThan(pressed.frontLipHeight, rest.frontLipHeight)
        XCTAssertGreaterThan(pressed.pressOffsetY, rest.pressOffsetY)
        XCTAssertGreaterThan(follow.frontLipHeight, rest.frontLipHeight)
        XCTAssertLessThan(follow.pressOffsetY, rest.pressOffsetY)
        XCTAssertEqual(muted.frontLipHeight, 1.5, accuracy: 0.0001)
        XCTAssertEqual(muted.pressOffsetY, 2.0, accuracy: 0.0001)

        // 3. StageTransportRingMapper 零值/非有限/绕圈取模与 5/7 五音表盘刻度计数
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: nil, totalDuration: 4.0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: .nan, totalDuration: 4.0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: 2.0, totalDuration: 0.04), 0.0, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: 2.0, totalDuration: .infinity), 0.0, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: 1.0, totalDuration: 4.0), 0.25, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: 5.5, totalDuration: 4.0), 0.375, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.loopProgress(currentTime: -1.0, totalDuration: 4.0), 0.75, accuracy: 0.0001)
        XCTAssertEqual(StageTransportRingMapper.pentatonicIndicatorCount(isSafe: true), 5)
        XCTAssertEqual(StageTransportRingMapper.pentatonicIndicatorCount(isSafe: false), 7)

        // 4. 舞台双子角守护交互契约（咩试听与哞唤醒/试听保持零例行 Toast）
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r27_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.startBlankCanvas()
        vm.plantDuoStarterMotif()
        vm.setChordPreset(.off)
        XCTAssertFalse(vm.cradleEnabled)

        vm.auditionDuoCharacter(.mie)
        XCTAssertNil(vm.statusToast)

        if !vm.cradleEnabled {
            vm.setChordPreset(.autoMatch)
        }
        vm.auditionDuoCharacter(.mou)
        XCTAssertTrue(vm.cradleEnabled)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound28VinylBoutiqueKinematicsAndDuplicateNaming() throws {
        // 1. VinylBoutiqueKinematics 封套滑动露出与黄铜唱臂角度状态机
        let idle = VinylBoutiqueKinematics.state(isPlaying: false, reduceMotion: false)
        XCTAssertEqual(idle.discPeekOffsetX, 20.0, accuracy: 0.0001)
        XCTAssertEqual(idle.tonearmAngleDeg, -8.0, accuracy: 0.0001)
        XCTAssertFalse(idle.turntableActive)

        let playing = VinylBoutiqueKinematics.state(isPlaying: true, reduceMotion: false)
        XCTAssertGreaterThan(playing.discPeekOffsetX, idle.discPeekOffsetX)
        XCTAssertEqual(playing.tonearmAngleDeg, 20.0, accuracy: 0.0001)
        XCTAssertTrue(playing.turntableActive)

        let reduced = VinylBoutiqueKinematics.state(isPlaying: true, reduceMotion: true)
        XCTAssertGreaterThan(reduced.discPeekOffsetX, idle.discPeekOffsetX)
        XCTAssertLessThan(reduced.discPeekOffsetX, playing.discPeekOffsetX)
        XCTAssertTrue(reduced.turntableActive)

        // 2. MelodyNotebookStore.duplicate 保留首份"副本"且连续复制不重名
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r28_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = MelodyNotebookStore(directory: tempDir)
        let baseDoc = MelodyDocument(
            title: "琥珀圆舞曲",
            scaleMode: .brightMajor,
            notes: [NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.1, rawDuration: 0.4)]
        )
        let saved = store.save(document: baseDoc, chordPreset: .autoMatch, chordOverrides: [:], summaryNote: "")
        let firstCopy = try XCTUnwrap(store.duplicate(id: saved.id))
        XCTAssertEqual(firstCopy.document.title, "琥珀圆舞曲 副本")

        let secondCopy = try XCTUnwrap(store.duplicate(id: saved.id))
        XCTAssertEqual(secondCopy.document.title, "琥珀圆舞曲 副本 2")

        let thirdCopyFromCopy = try XCTUnwrap(store.duplicate(id: firstCopy.id))
        XCTAssertEqual(thirdCopyFromCopy.document.title, "琥珀圆舞曲 副本 3")

        let distinctTitles = Set(store.entries.map(\.document.title))
        XCTAssertEqual(distinctTitles.count, 4)
    }

    @MainActor
    func testCreativeAlchemyRound29HumVUMeterKinematicsAndDreamWorkbenchCleanup() throws {
        // 1. HumVUMeterKinematics 非录音态、非有限边界与 9 段声压表增调递推
        let idle = HumVUMeterKinematics.reading(inputLevel: 0.92, isRecording: false)
        XCTAssertEqual(idle.needleAngleDegrees, -44.0, accuracy: 0.0001)
        XCTAssertEqual(idle.activeSegments, 0)
        XCTAssertFalse(idle.isHot)

        let nanReading = HumVUMeterKinematics.reading(inputLevel: .nan, isRecording: true)
        let infReading = HumVUMeterKinematics.reading(inputLevel: .infinity, isRecording: true)
        let negReading = HumVUMeterKinematics.reading(inputLevel: -0.5, isRecording: true)
        XCTAssertEqual(nanReading, idle)
        XCTAssertEqual(infReading, idle)
        XCTAssertEqual(negReading, idle)

        let low = HumVUMeterKinematics.reading(inputLevel: 0.12, isRecording: true)
        let mid = HumVUMeterKinematics.reading(inputLevel: 0.48, isRecording: true)
        let hot = HumVUMeterKinematics.reading(inputLevel: 0.82, isRecording: true)
        let full = HumVUMeterKinematics.reading(inputLevel: 1.0, isRecording: true)

        XCTAssertLessThan(low.needleAngleDegrees, mid.needleAngleDegrees)
        XCTAssertLessThan(mid.needleAngleDegrees, hot.needleAngleDegrees)
        XCTAssertLessThan(hot.needleAngleDegrees, full.needleAngleDegrees)
        XCTAssertEqual(full.needleAngleDegrees, 44.0, accuracy: 0.0001)

        XCTAssertGreaterThanOrEqual(low.activeSegments, 1)
        XCTAssertLessThan(low.activeSegments, mid.activeSegments)
        XCTAssertLessThan(mid.activeSegments, hot.activeSegments)
        XCTAssertLessThanOrEqual(hot.activeSegments, full.activeSegments)
        XCTAssertEqual(full.activeSegments, 9)

        XCTAssertFalse(low.isHot)
        XCTAssertFalse(mid.isHot)
        XCTAssertTrue(hot.isHot)
        XCTAssertTrue(full.isHot)

        let zeroSeg = HumVUMeterKinematics.reading(inputLevel: 0.9, isRecording: true, totalSegments: 0)
        XCTAssertEqual(zeroSeg.activeSegments, 0)

        // 2. HumCapturePipeline.cancelRecording & StudioViewModel.cancelHumCapture 干净重置校验
        let router = HalfDuplexAudioRouter()
        let synth = FeltPianoSynth()
        let pipeline = HumCapturePipeline(router: router, synth: synth)
        pipeline.cancelRecording()
        XCTAssertFalse(pipeline.isRecording)
        XCTAssertEqual(pipeline.inputLevel, 0.0, accuracy: 0.0001)
        XCTAssertTrue(pipeline.livePitchTrace.isEmpty)
        XCTAssertTrue(pipeline.statusMessage.isEmpty)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r29_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.cancelHumCapture()
        XCTAssertFalse(vm.capturePipeline.isRecording)
        XCTAssertEqual(vm.capturePipeline.inputLevel, 0.0, accuracy: 0.0001)
        XCTAssertTrue(vm.capturePipeline.livePitchTrace.isEmpty)
        XCTAssertTrue(vm.capturePipeline.statusMessage.isEmpty)
        XCTAssertNil(vm.statusToast)

        // 3. 敲击节奏清理契约
        vm.startRhythmTap()
        vm.recordRhythmDrumTap()
        XCTAssertTrue(vm.isTappingRhythm)
        XCTAssertEqual(vm.liveTapTimestamps.count, 1)
        vm.cancelRhythmTap()
        XCTAssertFalse(vm.isTappingRhythm)
        XCTAssertTrue(vm.liveTapTimestamps.isEmpty)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound30SoundPaletteBoxKinematicsAndAudioReadiness() throws {
        // 1. SoundPaletteBoxKinematics 机械黄铜拨杆四态运动学
        let onLive = SoundPaletteBoxKinematics.toggleLeverState(isOn: true, reduceMotion: false)
        let offLive = SoundPaletteBoxKinematics.toggleLeverState(isOn: false, reduceMotion: false)
        let onReduced = SoundPaletteBoxKinematics.toggleLeverState(isOn: true, reduceMotion: true)
        let offReduced = SoundPaletteBoxKinematics.toggleLeverState(isOn: false, reduceMotion: true)

        XCTAssertEqual(onLive.travelFraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(onLive.tiltDegrees, -7.0, accuracy: 0.0001)
        XCTAssertEqual(onLive.lampGlowOpacity, 0.92, accuracy: 0.0001)

        XCTAssertEqual(offLive.travelFraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(offLive.tiltDegrees, 7.0, accuracy: 0.0001)
        XCTAssertEqual(offLive.lampGlowOpacity, 0.16, accuracy: 0.0001)

        XCTAssertEqual(onReduced.travelFraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(onReduced.tiltDegrees, 0.0, accuracy: 0.0001)
        XCTAssertEqual(offReduced.travelFraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(offReduced.tiltDegrees, 0.0, accuracy: 0.0001)

        // 2. SoundPaletteBoxKinematics 示波窗 4 种音色分化与异常数值边界防护
        XCTAssertTrue(
            SoundPaletteBoxKinematics.oscilloscopeSamples(for: .concertPiano, rootMIDI: 60, playbackRate: 1.0, phase: 0.0, sampleCount: 0).isEmpty
        )
        XCTAssertEqual(
            SoundPaletteBoxKinematics.oscilloscopeSamples(for: .concertPiano, rootMIDI: 60, playbackRate: 1.0, phase: 0.0, sampleCount: 1),
            [0.5]
        )

        let waveSets = MelodyVoice.allCases.map {
            SoundPaletteBoxKinematics.oscilloscopeSamples(
                for: $0,
                rootMIDI: 60,
                playbackRate: 1.0,
                phase: 0.35,
                sampleCount: 28
            )
        }
        for wave in waveSets {
            XCTAssertEqual(wave.count, 28)
            XCTAssertTrue(wave.allSatisfy { $0.isFinite && $0 >= 0.06 && $0 <= 0.94 })
        }
        for i in 0..<waveSets.count {
            for j in (i + 1)..<waveSets.count {
                XCTAssertNotEqual(waveSets[i], waveSets[j], "各主旋律音色示波曲线应具备可区分形态")
            }
        }

        let nanWave = SoundPaletteBoxKinematics.oscilloscopeSamples(
            for: .singingCello,
            rootMIDI: 999,
            playbackRate: .nan,
            phase: .infinity,
            sampleCount: 28
        )
        XCTAssertEqual(nanWave.count, 28)
        XCTAssertTrue(nanWave.allSatisfy { $0.isFinite && $0 >= 0.06 && $0 <= 0.94 })

        // 3. SoundPaletteBoxKinematics 1·3·5 三音偶聚焦路由
        XCTAssertNil(SoundPaletteBoxKinematics.triadFocusDegree(for: nil))
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .scale), 3)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .voice), 5)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .pitch), 5)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .tempo), 5)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .groove), 5)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .texture), 1)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .chord), 1)
        XCTAssertEqual(SoundPaletteBoxKinematics.triadFocusDegree(for: .character(6)), 6)
        XCTAssertNil(SoundPaletteBoxKinematics.triadFocusDegree(for: .character(0)))
        XCTAssertNil(SoundPaletteBoxKinematics.triadFocusDegree(for: .character(8)))

        // 4. setGrooveStrength 幂等防重复撤销栈污染 + 声学设置零例行 Toast
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r30_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.startBlankCanvas()
        vm.plantDuoStarterMotif()
        vm.stopPlayback()

        let baselineGroove = vm.document.grooveStrength
        vm.setGrooveStrength(0.5)
        XCTAssertTrue(vm.canUndo)

        // 连续重复点选同档位不应再新增撤销记录
        vm.setGrooveStrength(0.5)
        vm.undo()
        XCTAssertEqual(vm.document.grooveStrength, baselineGroove, accuracy: 0.001)

        vm.setScaleMode(.cloudLydian)
        vm.setMelodyVoice(.liquidHarp)
        vm.setAccompanimentTexture(.summerGlass)
        vm.setRootMIDI(65)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound31StageHardwareCaliperAndPerchKinematics() throws {
        // 1. StageHardwareCaliperKinematics 时值标尺与异常数值防护
        let shortCaliper = StageHardwareCaliperKinematics.caliperReading(
            rawDuration: 0.14,
            beatIndex: 0,
            totalCount: 5,
            tickCount: 8
        )
        let midCaliper = StageHardwareCaliperKinematics.caliperReading(
            rawDuration: 0.55,
            beatIndex: 2,
            totalCount: 5,
            tickCount: 8
        )
        let longCaliper = StageHardwareCaliperKinematics.caliperReading(
            rawDuration: 1.20,
            beatIndex: 4,
            totalCount: 5,
            tickCount: 8
        )

        XCTAssertEqual(shortCaliper.tickCount, 8)
        XCTAssertEqual(shortCaliper.positionFraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(midCaliper.positionFraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(longCaliper.positionFraction, 1.0, accuracy: 0.0001)

        XCTAssertGreaterThanOrEqual(shortCaliper.highlightedTickCount, 1)
        XCTAssertLessThanOrEqual(shortCaliper.highlightedTickCount, midCaliper.highlightedTickCount)
        XCTAssertLessThanOrEqual(midCaliper.highlightedTickCount, longCaliper.highlightedTickCount)
        XCTAssertLessThanOrEqual(longCaliper.highlightedTickCount, 8)

        let nanCaliper = StageHardwareCaliperKinematics.caliperReading(
            rawDuration: .nan,
            beatIndex: -4,
            totalCount: 0,
            tickCount: 0
        )
        XCTAssertTrue(nanCaliper.durationFraction.isFinite)
        XCTAssertEqual(nanCaliper.durationFraction, 0.15, accuracy: 0.0001)
        XCTAssertEqual(nanCaliper.positionFraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(nanCaliper.tickCount, 1)
        XCTAssertEqual(nanCaliper.highlightedTickCount, 1)

        let soloCaliper = StageHardwareCaliperKinematics.caliperReading(
            rawDuration: 0.50,
            beatIndex: 0,
            totalCount: 1,
            tickCount: 8
        )
        XCTAssertEqual(soloCaliper.positionFraction, 0.5, accuracy: 0.0001)

        // 2. StageHardwareCaliperKinematics 舞台双子底座三态与减弱动态效果尊重
        let sleeping = StageHardwareCaliperKinematics.cornerPerchState(isAwake: false, isActive: false, reduceMotion: false)
        let standby = StageHardwareCaliperKinematics.cornerPerchState(isAwake: true, isActive: false, reduceMotion: false)
        let singing = StageHardwareCaliperKinematics.cornerPerchState(isAwake: true, isActive: true, reduceMotion: false)
        let reduced = StageHardwareCaliperKinematics.cornerPerchState(isAwake: true, isActive: true, reduceMotion: true)

        XCTAssertLessThan(sleeping.glowOpacity, standby.glowOpacity)
        XCTAssertLessThan(standby.glowOpacity, singing.glowOpacity)
        XCTAssertLessThan(sleeping.brassPinOpacity, standby.brassPinOpacity)
        XCTAssertLessThan(standby.brassPinOpacity, singing.brassPinOpacity)
        XCTAssertEqual(sleeping.liftPoints, 0.0, accuracy: 0.0001)
        XCTAssertEqual(standby.liftPoints, 0.0, accuracy: 0.0001)
        XCTAssertEqual(singing.liftPoints, -2.5, accuracy: 0.0001)
        XCTAssertEqual(reduced.liftPoints, 0.0, accuracy: 0.0001)
    }

    @MainActor
    func testCreativeAlchemyRound32StorybookFlatCartoonLayoutAndIPKeyBuddies() throws {
        // 1. StorybookIllustrationLayout 童书山坡轮廓生成与 NaN 安全防护
        XCTAssertTrue(StorybookIllustrationLayout.rollingHillProfile(sampleCount: 0, amplitude: 0.16, phaseShift: 0.0).isEmpty)
        let solo = StorybookIllustrationLayout.rollingHillProfile(sampleCount: 1, amplitude: 0.16, phaseShift: 0.0)
        XCTAssertEqual(solo.count, 1)
        XCTAssertEqual(solo[0].xFraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(solo[0].yFraction, 0.5, accuracy: 0.0001)

        let hills = StorybookIllustrationLayout.rollingHillProfile(sampleCount: 16, amplitude: 0.18, phaseShift: 1.2)
        XCTAssertEqual(hills.count, 16)
        XCTAssertEqual(hills.first?.xFraction ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hills.last?.xFraction ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertTrue(hills.allSatisfy { $0.yFraction.isFinite && $0.yFraction >= 0.05 && $0.yFraction <= 0.95 })

        let nanHills = StorybookIllustrationLayout.rollingHillProfile(sampleCount: 10, amplitude: .nan, phaseShift: .infinity)
        XCTAssertEqual(nanHills.count, 10)
        XCTAssertTrue(nanHills.allSatisfy { $0.xFraction.isFinite && $0.yFraction >= 0.05 && $0.yFraction <= 0.95 })

        // 2. 咩哞七小只琴键融合头像姿态联动（大/小调、欢唱与减弱动态效果）
        let plokkoMajor = StorybookIllustrationLayout.keyBuddyPose(for: .plokko, isSinging: false, isMinor: false, reduceMotion: false)
        let plokkoMinor = StorybookIllustrationLayout.keyBuddyPose(for: .plokko, isSinging: false, isMinor: true, reduceMotion: false)
        let plokkoSinging = StorybookIllustrationLayout.keyBuddyPose(for: .plokko, isSinging: true, isMinor: false, reduceMotion: false)
        let plokkoReduced = StorybookIllustrationLayout.keyBuddyPose(for: .plokko, isSinging: true, isMinor: true, reduceMotion: true)

        XCTAssertEqual(plokkoMajor.popOffsetY, 0.0, accuracy: 0.0001)
        XCTAssertEqual(plokkoMajor.earTiltDegrees, -6.0, accuracy: 0.0001)
        XCTAssertEqual(plokkoMinor.earTiltDegrees, 10.0, accuracy: 0.0001)
        XCTAssertFalse(plokkoMajor.showSingingSmile)

        XCTAssertEqual(plokkoSinging.popOffsetY, -3.0, accuracy: 0.0001)
        XCTAssertEqual(plokkoSinging.earTiltDegrees, -12.0, accuracy: 0.0001)
        XCTAssertTrue(plokkoSinging.showSingingSmile)

        XCTAssertEqual(plokkoReduced.popOffsetY, 0.0, accuracy: 0.0001)
        XCTAssertEqual(plokkoReduced.earTiltDegrees, 0.0, accuracy: 0.0001)
        XCTAssertTrue(plokkoReduced.showSingingSmile)

        let dokoIdle = StorybookIllustrationLayout.keyBuddyPose(for: .doko, isSinging: false, isMinor: false, reduceMotion: false)
        let udoIdle = StorybookIllustrationLayout.keyBuddyPose(for: .udo, isSinging: false, isMinor: false, reduceMotion: false)
        let tinkiIdle = StorybookIllustrationLayout.keyBuddyPose(for: .tinki, isSinging: false, isMinor: false, reduceMotion: false)
        let tinkiSinging = StorybookIllustrationLayout.keyBuddyPose(for: .tinki, isSinging: true, isMinor: false, reduceMotion: false)
        XCTAssertEqual(dokoIdle.earTiltDegrees, 4.0, accuracy: 0.0001)
        XCTAssertEqual(udoIdle.earTiltDegrees, -4.0, accuracy: 0.0001)
        XCTAssertEqual(tinkiIdle.earTiltDegrees, -7.0, accuracy: 0.0001)
        XCTAssertEqual(tinkiSinging.earTiltDegrees, -10.0, accuracy: 0.0001)
        XCTAssertEqual(tinkiSinging.popOffsetY, -3.0, accuracy: 0.0001)
    }

    @MainActor
    func testCreativeAlchemyRound33StorybookChoirMeterAndDreamAudioReadiness() throws {
        // 1. StorybookChoirMeterKinematics 声浪合唱舞台轮廓与减弱动态效果尊重
        XCTAssertTrue(StorybookChoirMeterKinematics.hillBars(inputLevel: 0.5, isRecording: true, barCount: 0, reduceMotion: false).isEmpty)

        let soloHill = StorybookChoirMeterKinematics.hillBars(inputLevel: 0.0, isRecording: false, barCount: 1, reduceMotion: false)
        XCTAssertEqual(soloHill.count, 1)
        XCTAssertEqual(soloHill[0].heightFraction, 0.36, accuracy: 0.0001)
        XCTAssertFalse(soloHill[0].isLit)
        XCTAssertFalse(soloHill[0].isPeakZone)
        XCTAssertEqual(soloHill[0].buddyPopOffsetY, 0.0, accuracy: 0.0001)

        let idleBars = StorybookChoirMeterKinematics.hillBars(inputLevel: 0.9, isRecording: false, barCount: 9, reduceMotion: false)
        XCTAssertEqual(idleBars.count, 9)
        XCTAssertTrue(idleBars.allSatisfy { !$0.isLit && !$0.isPeakZone && $0.buddyPopOffsetY == 0.0 && $0.heightFraction >= 0.22 && $0.heightFraction <= 0.36 })

        let nanBars = StorybookChoirMeterKinematics.hillBars(inputLevel: .nan, isRecording: true)
        let infBars = StorybookChoirMeterKinematics.hillBars(inputLevel: .infinity, isRecording: true)
        XCTAssertEqual(nanBars.count, 9)
        XCTAssertEqual(infBars.count, 9)
        XCTAssertTrue(nanBars.allSatisfy { !$0.isLit && $0.heightFraction.isFinite })
        XCTAssertTrue(infBars.allSatisfy { !$0.isLit && $0.heightFraction.isFinite })

        let lowBars = StorybookChoirMeterKinematics.hillBars(inputLevel: 0.15, isRecording: true, barCount: 9, reduceMotion: false)
        XCTAssertGreaterThanOrEqual(lowBars.filter(\.isLit).count, 1)
        XCTAssertFalse(lowBars[6].isPeakZone)
        XCTAssertTrue(lowBars[7].isPeakZone)
        XCTAssertTrue(lowBars[8].isPeakZone)
        XCTAssertLessThan(lowBars[0].buddyPopOffsetY, 0.0)

        let hotBars = StorybookChoirMeterKinematics.hillBars(inputLevel: 0.95, isRecording: true, barCount: 9, reduceMotion: false)
        XCTAssertTrue(hotBars.allSatisfy(\.isLit))
        XCTAssertGreaterThan(hotBars[4].heightFraction, hotBars[0].heightFraction)
        XCTAssertGreaterThanOrEqual(hotBars[4].heightFraction, 0.85)

        let reducedBars = StorybookChoirMeterKinematics.hillBars(inputLevel: 0.95, isRecording: true, barCount: 9, reduceMotion: true)
        XCTAssertTrue(reducedBars.allSatisfy { $0.isLit && $0.buddyPopOffsetY == 0.0 })

        // 2. 七小只声压点头助威集合映射与越界保护
        XCTAssertTrue(StorybookChoirMeterKinematics.cheeringBuddyIndices(activeSegments: 0, totalSegments: 9, buddyCount: 7).isEmpty)
        XCTAssertTrue(StorybookChoirMeterKinematics.cheeringBuddyIndices(activeSegments: 3, totalSegments: 0, buddyCount: 7).isEmpty)
        XCTAssertEqual(StorybookChoirMeterKinematics.cheeringBuddyIndices(activeSegments: 1, totalSegments: 9, buddyCount: 7), [0])
        XCTAssertEqual(StorybookChoirMeterKinematics.cheeringBuddyIndices(activeSegments: 5, totalSegments: 9, buddyCount: 7), Set(0..<4))
        XCTAssertEqual(StorybookChoirMeterKinematics.cheeringBuddyIndices(activeSegments: 9, totalSegments: 9, buddyCount: 7), Set(0..<7))

        // 3. 捕梦工坊鼓点与开头音高推子试听唤醒且零例行 Toast
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r33_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.startBlankCanvas()
        vm.startRhythmTap()
        vm.recordRhythmDrumTap()
        vm.recordRhythmDrumTap()
        XCTAssertEqual(vm.liveTapTimestamps.count, 2)
        vm.previewSeedShift(index: 0, shift: 1)
        vm.previewSeedShift(index: 2, shift: -1)
        vm.cancelRhythmTap()
        XCTAssertFalse(vm.isTappingRhythm)
        XCTAssertTrue(vm.liveTapTimestamps.isEmpty)
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()
    }

    @MainActor
    func testCreativeAlchemyRound34StorybookShelfAndPostcardFlatCartoon() throws {
        // 1. StorybookPostcardAndShelfKinematics 主角小偶选取（空作品归家、频次优先、平局取尾音）
        let emptyDoc = MelodyDocument(title: " ", scaleMode: .brightMajor, notes: [])
        XCTAssertEqual(StorybookPostcardAndShelfKinematics.heroMember(for: emptyDoc), .taono)

        let solDominantDoc = MelodyDocument(
            title: "远望晴空",
            scaleMode: .brightMajor,
            notes: [
                NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.0, rawDuration: 0.4),
                NoteBead(degree: 5, octaveOffset: 0, rawOnset: 0.4, rawDuration: 0.4),
                NoteBead(degree: 5, octaveOffset: 0, rawOnset: 0.8, rawDuration: 0.4),
                NoteBead(degree: 3, octaveOffset: 0, rawOnset: 1.2, rawDuration: 0.4)
            ]
        )
        XCTAssertEqual(StorybookPostcardAndShelfKinematics.heroMember(for: solDominantDoc), .corllo)

        let tieBreakEndingDoc = MelodyDocument(
            title: "落回三音",
            scaleMode: .wistfulMinor,
            notes: [
                NoteBead(degree: 5, octaveOffset: 0, rawOnset: 0.0, rawDuration: 0.4),
                NoteBead(degree: 3, octaveOffset: 0, rawOnset: 0.4, rawDuration: 0.4)
            ]
        )
        XCTAssertEqual(StorybookPostcardAndShelfKinematics.heroMember(for: tieBreakEndingDoc), .plokko)

        // 2. 唱片封套主角头像联动位移与减弱动态效果尊重
        let plokkoIdleMinor = StorybookPostcardAndShelfKinematics.sleevePlacement(
            isPlaying: false,
            hero: .plokko,
            isMinor: true,
            reduceMotion: false
        )
        let plokkoPlayMinor = StorybookPostcardAndShelfKinematics.sleevePlacement(
            isPlaying: true,
            hero: .plokko,
            isMinor: true,
            reduceMotion: false
        )
        let plokkoReduced = StorybookPostcardAndShelfKinematics.sleevePlacement(
            isPlaying: true,
            hero: .plokko,
            isMinor: true,
            reduceMotion: true
        )
        XCTAssertEqual(plokkoIdleMinor.shadowOffsetY, 2.5, accuracy: 0.0001)
        XCTAssertEqual(plokkoPlayMinor.shadowOffsetY, 4.0, accuracy: 0.0001)
        XCTAssertEqual(plokkoIdleMinor.buddyTiltDegrees, 10.0, accuracy: 0.0001)
        XCTAssertLessThan(plokkoPlayMinor.buddyOffsetY, 0.0)
        XCTAssertEqual(plokkoReduced.buddyOffsetY, 0.0, accuracy: 0.0001)
        XCTAssertEqual(plokkoReduced.buddyTiltDegrees, 0.0, accuracy: 0.0001)

        // 3. 扁平太阳光线端点生成与边界防护
        XCTAssertTrue(StorybookPostcardAndShelfKinematics.radialRaySegments(center: CGPoint(x: 10, y: 10), innerRadius: 8, outerRadius: 14, rayCount: 0).isEmpty)
        XCTAssertTrue(StorybookPostcardAndShelfKinematics.radialRaySegments(center: CGPoint(x: CGFloat.nan, y: 10), innerRadius: 8, outerRadius: 14, rayCount: 8).isEmpty)
        let rays = StorybookPostcardAndShelfKinematics.radialRaySegments(center: CGPoint(x: 50, y: 50), innerRadius: 10, outerRadius: 20, rayCount: 8)
        XCTAssertEqual(rays.count, 8)
        XCTAssertEqual(rays[0].start.x, 50.0, accuracy: 0.001)
        XCTAssertEqual(rays[0].start.y, 40.0, accuracy: 0.001)
        XCTAssertEqual(rays[0].end.y, 30.0, accuracy: 0.001)

        // 4. VinylPostcardSnapshot IP 主角映射与六组合离线 PNG 渲染非空验证
        let snap = VinylPostcardSnapshot(
            document: tieBreakEndingDoc,
            isNight: true,
            visualMode: .orbitalDisc,
            includeJianpuStrip: true
        )
        XCTAssertEqual(snap.heroMember, .plokko)
        XCTAssertFalse(snap.jianpuTokens.isEmpty)

        for night in [false, true] {
            for mode in StageVisualMode.allCases {
                let data = VinylPostcardExporter.renderPNGData(
                    document: solDominantDoc,
                    shadowEnabled: true,
                    isNight: night,
                    visualMode: mode,
                    includeJianpuStrip: true
                )
                XCTAssertNotNil(data)
            }
        }
        XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: emptyDoc, isNight: false, visualMode: .orbitalDisc))
    }

    @MainActor
    func testCreativeAlchemyRound35NightLampStarryInclusivityAndSoloAudio() {
        // 1. 星空锚点境界条件（非正数清空，常规 5 颗，上限 8 颗且全数落于画布安全区间内）
        XCTAssertTrue(StorybookNightLampInclusivityKinematics.starPositions(count: 0).isEmpty)
        XCTAssertTrue(StorybookNightLampInclusivityKinematics.starPositions(count: -3).isEmpty)
        XCTAssertEqual(StorybookNightLampInclusivityKinematics.starPositions(count: 5).count, 5)
        let eightStars = StorybookNightLampInclusivityKinematics.starPositions(count: 8)
        let cappedStars = StorybookNightLampInclusivityKinematics.starPositions(count: 20)
        XCTAssertEqual(eightStars.count, 8)
        XCTAssertEqual(cappedStars.count, 8)
        for star in cappedStars {
            XCTAssertGreaterThan(star.xFraction, 0)
            XCTAssertLessThan(star.xFraction, 1)
            XCTAssertGreaterThan(star.yFraction, 0)
            XCTAssertLessThan(star.yFraction, 1)
            XCTAssertGreaterThan(star.radius, 0)
        }

        // 2. 「减弱动态效果」分档圈径边界与非法时长防御
        XCTAssertEqual(StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 0, heldSeconds: 0.0, reduceMotion: true), 54, accuracy: 1e-6)
        XCTAssertEqual(StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 3, heldSeconds: 2.0, reduceMotion: true), 102, accuracy: 1e-6)
        XCTAssertEqual(StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: -1, heldSeconds: 0.0, reduceMotion: true), 54, accuracy: 1e-6)
        XCTAssertEqual(StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 99, heldSeconds: 0.0, reduceMotion: true), 102, accuracy: 1e-6)

        let d0 = StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 0, heldSeconds: 0.0, reduceMotion: false)
        let d1 = StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 1, heldSeconds: 0.5, reduceMotion: false)
        let d2 = StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 2, heldSeconds: 1.0, reduceMotion: false)
        let d3 = StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 3, heldSeconds: 2.0, reduceMotion: false)
        XCTAssertGreaterThan(d3, d0)
        XCTAssertLessThanOrEqual(d0, d1)
        XCTAssertLessThanOrEqual(d1, d2)
        XCTAssertLessThanOrEqual(d2, d3)

        for weirdSeconds in [Double.nan, Double.infinity, -1.0] {
            let safeDiameter = StorybookNightLampInclusivityKinematics.haloDiameter(sustainTier: 1, heldSeconds: weirdSeconds, reduceMotion: false)
            XCTAssertTrue(safeDiameter.isFinite)
            XCTAssertGreaterThan(safeDiameter, 0)
        }

        // 3. VoiceOver 实时星夜画布朗读状态摘要与负值防护
        let thirdMember = ChimmoMember.from(degree: 3)
        let summary3 = StorybookNightLampInclusivityKinematics.accessibilityCanvasValue(currentMember: thirdMember, capturedCount: 3)
        XCTAssertTrue(summary3.contains(thirdMember.voiceOverSummary))
        XCTAssertTrue(summary3.contains("已录 3 音"))
        let clampedSummary = StorybookNightLampInclusivityKinematics.accessibilityCanvasValue(currentMember: thirdMember, capturedCount: -5)
        XCTAssertTrue(clampedSummary.contains("已录 0 音"))

        // 4. 夜灯哼唱/触控短语写入状态流转与零 Toast 契约
        let vm = StudioViewModel()
        let beads = [
            NoteBead(degree: 1, rawOnset: 0.0, rawDuration: 0.5),
            NoteBead(degree: 5, rawOnset: 0.6, rawDuration: 0.5)
        ]
        vm.applyNightLampPhrase(beads, pentatonicSafe: true)
        XCTAssertEqual(vm.document.notes.count, 2)
        XCTAssertTrue(vm.pentatonicSafe)
        XCTAssertNil(vm.statusToast)

        let sheet = NightLampTactileSheet(vm: vm)
        XCTAssertNotNil(sheet)
    }

    @MainActor
    func testCreativeAlchemyRound36AppIconCanonsAndStorybookGuidedMoments() {
        // 1. 1-3-5 主三和弦三人组顺序与新版 AppIcon IP 正典完全对齐（陶诺-拍咯-壳咯）
        let iconTriad = ChimmoMember.allCases.filter(\.isTriadPillar)
        XCTAssertEqual(iconTriad, [.taono, .plokko, .corllo])

        // 2. 空曲谱、空分幕与空白徽章标题均安全返回 nil，避免空白舞台误占空间
        let swan = SpecimenLibrary.saintSaensTheSwan
        XCTAssertNil(StorybookGuidedMomentKinematics.chipModel(moment: nil, document: swan))

        let emptyDoc = MelodyDocument(
            title: "空白测试",
            subtitle: "",
            rootMIDI: 60,
            scaleMode: .brightMajor,
            harmonyProfile: swan.harmonyProfile,
            grooveStrength: 0.0,
            notes: []
        )
        XCTAssertNil(StorybookGuidedMomentKinematics.chipModel(moment: swan.guidedMoments?.first, document: emptyDoc))

        let blankMoment = GuidedStoryMoment(id: 99, timeFraction: 0.5, badge: "   \n ", caption: "无字忽略")
        XCTAssertNil(StorybookGuidedMomentKinematics.chipModel(moment: blankMoment, document: swan))

        // 3. 越界与 NaN timeFraction 防御以及《天鹅》分幕角标映射
        let nanMoment = GuidedStoryMoment(id: 100, timeFraction: .nan, badge: "天鹅浮水", caption: "测试异常值保护")
        let nanChip = StorybookGuidedMomentKinematics.chipModel(moment: nanMoment, document: swan)
        XCTAssertEqual(nanChip?.progressFraction ?? -1, 0.0, accuracy: 1e-6)
        XCTAssertEqual(nanChip?.targetOnsetSeconds ?? -1, 0.0, accuracy: 1e-6)

        let overMoment = GuidedStoryMoment(id: 101, timeFraction: 2.5, badge: "终点落宁", caption: "上限钳位保护")
        let overChip = StorybookGuidedMomentKinematics.chipModel(moment: overMoment, document: swan)
        XCTAssertEqual(overChip?.progressFraction ?? -1, 1.0, accuracy: 1e-6)
        XCTAssertEqual(overChip?.targetOnsetSeconds ?? -1, swan.totalDuration, accuracy: 1e-6)

        guard let openingMoment = swan.guidedMoments?.first,
              let chip = StorybookGuidedMomentKinematics.chipModel(moment: openingMoment, document: swan) else {
            XCTFail("天鹅标本必须生成有效的绘本分幕角标模型")
            return
        }
        XCTAssertFalse(chip.badge.isEmpty)
        XCTAssertFalse(chip.caption.isEmpty)
        XCTAssertTrue((0.0...1.0).contains(chip.progressFraction))
        XCTAssertGreaterThanOrEqual(chip.targetOnsetSeconds, 0.0)

        // 4. 点按分幕角标跳转试听保持零例行 Toast
        let vm = StudioViewModel()
        vm.scrubToTime(chip.targetOnsetSeconds, triggerNotes: false)
        vm.endScrubbing()
        XCTAssertNil(vm.statusToast)
    }

    @MainActor
    func testCreativeAlchemyRound37AffordanceContractHitTargetsAndCompactChrome() {
        // 1. 两极交互视觉契约：可点按钮拥有硬阴影与按下下沉，静态容器与只读标签零硬阴影且非零线框隔离
        let primaryIdle = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary, isPressed: false, reduceMotion: false)
        let primaryPressed = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary, isPressed: true, reduceMotion: false)
        let primaryReduced = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary, isPressed: true, reduceMotion: true)
        XCTAssertTrue(primaryIdle.usesHardInkOutline)
        XCTAssertGreaterThan(primaryIdle.shadowOffsetY, 0.0)
        XCTAssertEqual(primaryIdle.minHitDimension, 44.0, accuracy: 1e-6)
        XCTAssertGreaterThan(primaryPressed.pressSinkOffsetY, 0.0)
        XCTAssertLessThan(primaryPressed.shadowOffsetY, primaryIdle.shadowOffsetY)
        XCTAssertEqual(primaryReduced.pressSinkOffsetY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(primaryReduced.shadowOffsetY, primaryIdle.shadowOffsetY, accuracy: 1e-6)

        let secondaryIdle = StorybookAffordanceMetrics.styleSpec(for: .interactiveSecondary, isPressed: false, reduceMotion: false)
        let secondaryPressed = StorybookAffordanceMetrics.styleSpec(for: .interactiveSecondary, isPressed: true, reduceMotion: false)
        XCTAssertTrue(secondaryIdle.usesHardInkOutline)
        XCTAssertEqual(secondaryIdle.minHitDimension, 40.0, accuracy: 1e-6)
        XCTAssertGreaterThan(secondaryPressed.pressSinkOffsetY, 0.0)
        XCTAssertLessThan(secondaryPressed.shadowOffsetY, secondaryIdle.shadowOffsetY)

        let quietSpec = StorybookAffordanceMetrics.styleSpec(for: .quietContainer)
        XCTAssertFalse(quietSpec.usesHardInkOutline)
        XCTAssertEqual(quietSpec.shadowOffsetY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(quietSpec.borderWidth, 1.0, accuracy: 1e-6)

        let labelSpec = StorybookAffordanceMetrics.styleSpec(for: .readOnlyLabel)
        XCTAssertFalse(labelSpec.usesHardInkOutline)
        XCTAssertEqual(labelSpec.borderWidth, 0.0, accuracy: 1e-6)
        XCTAssertEqual(labelSpec.shadowOffsetY, 0.0, accuracy: 1e-6)

        // 2. 触控热区校验（覆盖过小热区扩展、负值、NaN 与无穷大防护）
        let undersized = StorybookAffordanceMetrics.validatedHitTarget(visualWidth: 26, visualHeight: 26)
        XCTAssertEqual(undersized.width, 40.0, accuracy: 1e-6)
        XCTAssertEqual(undersized.height, 40.0, accuracy: 1e-6)

        let roomy = StorybookAffordanceMetrics.validatedHitTarget(visualWidth: 62, visualHeight: 46, minimum: 44)
        XCTAssertEqual(roomy.width, 62.0, accuracy: 1e-6)
        XCTAssertEqual(roomy.height, 46.0, accuracy: 1e-6)

        let safeWeird = StorybookAffordanceMetrics.validatedHitTarget(visualWidth: .nan, visualHeight: -12, minimum: .infinity)
        XCTAssertEqual(safeWeird.width, 40.0, accuracy: 1e-6)
        XCTAssertEqual(safeWeird.height, 40.0, accuracy: 1e-6)

        // 3. 曲库与弹窗顶栏高度紧凑预算校验
        let defaultShelfHeight = StorybookAffordanceMetrics.shelfHeaderBudgetHeight(isSearchExpanded: false, showsFilterRow: true)
        let expandedShelfHeight = StorybookAffordanceMetrics.shelfHeaderBudgetHeight(isSearchExpanded: true, showsFilterRow: true)
        XCTAssertLessThanOrEqual(defaultShelfHeight, 96.0)
        XCTAssertGreaterThan(expandedShelfHeight, defaultShelfHeight)
        XCTAssertLessThanOrEqual(StorybookAffordanceMetrics.sheetHeaderBudgetHeight(hasModeRail: true), 56.0)
        XCTAssertLessThanOrEqual(StorybookAffordanceMetrics.sheetHeaderBudgetHeight(hasModeRail: false), 56.0)

        // 4. 全站降噪视图与双态明信片实例化与渲染校验
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        let vm = StudioViewModel()
        let req = VinylPostcardRequest(document: vm.document, visualMode: .orbitalDisc)

        XCTAssertNotNil(AmbientPaperBackdrop(palette: dayPalette))
        XCTAssertNotNil(StorybookQuietCardSurface(palette: nightPalette, accent: nightPalette.homeAnchor, isHighlighted: true))
        XCTAssertNotNil(StorybookQuietTag(text: "只读", systemImage: "lock.fill", tint: dayPalette.homeAnchor, textColor: dayPalette.primaryInk, isNight: false))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(MusicBoxShelfView(palette: dayPalette, synth: vm.synth, notebook: vm.notebook, currentDocumentID: vm.document.id, onLoadSavedToBoard: { _ in }, onPlayAlongSpecimen: { _ in }, onEditSpecimenOnBoard: { _ in }, onStartNewTap: {}))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: nightPalette))
        XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(AboutSheetView(palette: dayPalette, currentDocument: vm.document, cradleEnabled: vm.cradleEnabled))
        XCTAssertNotNil(VinylPostcardShareSheet(palette: nightPalette, request: req))
        XCTAssertNotNil(NightLampTactileSheet(vm: vm))

        XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: vm.document, isNight: false, visualMode: .orbitalDisc, includeJianpuStrip: true))
        XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: vm.document, isNight: true, visualMode: .flowingRiver, includeJianpuStrip: true))
    }

    @MainActor
    func testCreativeAlchemyRound38StorybookHillStageWreathAndSongbookShelf() {
        // 1. GuidedStoryMoment NaN / Inf 安全边界修复回归校验（CI 绿灯防线）
        let nanMoment = GuidedStoryMoment(id: 1, timeFraction: .nan, badge: "保护", caption: "测试")
        XCTAssertEqual(nanMoment.timeFraction, 0.0, accuracy: 1e-6)
        let infMoment = GuidedStoryMoment(id: 2, timeFraction: .infinity, badge: "无穷大", caption: "测试")
        XCTAssertEqual(infMoment.timeFraction, 0.0, accuracy: 1e-6)

        // 2. 主舞台默认展示全宽绘本山坡乐谱视图（消灭竖屏圆形留白）且彻底告别黑胶图标
        let vm = StudioViewModel()
        XCTAssertEqual(vm.visualMode, .flowingRiver)
        XCTAssertEqual(StageVisualMode.displayOrder, [.flowingRiver, .orbitalDisc, .resonanceNebula])
        XCTAssertEqual(StageVisualMode.displayOrder.map(\.storybookLabel), ["山坡", "花环", "星环"])
        for icon in StageVisualMode.allCases.map(\.iconName) {
            XCTAssertFalse(icon.contains("record"), "视图模式图标不应包含旧黑胶隐喻: \(icon)")
            XCTAssertFalse(icon.contains("opticaldisc"), "视图模式图标不应包含旧光盘隐喻: \(icon)")
        }

        // 3. 绘本曲本封面翻页与丝带书签状态机（静态 / 试听 / 减弱动态效果）
        let idleBook = StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: false, reduceMotion: false)
        XCTAssertEqual(idleBook.pagePeekOffsetX, 3.0, accuracy: 1e-6)
        XCTAssertEqual(idleBook.bookmarkDropY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(idleBook.coverTiltDegrees, 0.0, accuracy: 1e-6)

        let playingBook = StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: true, reduceMotion: false)
        XCTAssertEqual(playingBook.pagePeekOffsetX, 9.0, accuracy: 1e-6)
        XCTAssertEqual(playingBook.bookmarkDropY, 3.5, accuracy: 1e-6)
        XCTAssertEqual(playingBook.coverTiltDegrees, -2.0, accuracy: 1e-6)

        let reducedBook = StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: true, reduceMotion: true)
        XCTAssertEqual(reducedBook.pagePeekOffsetX, 6.0, accuracy: 1e-6)
        XCTAssertEqual(reducedBook.bookmarkDropY, 2.0, accuracy: 1e-6)
        XCTAssertEqual(reducedBook.coverTiltDegrees, 0.0, accuracy: 1e-6)

        // 4. 绘本山坡天际线采样器（含空值/NaN 回退与单调边界校验）
        let fallbackCrest = StorybookWreathAndSongbookKinematics.hillCrestPoints(from: [.nan, .infinity])
        XCTAssertEqual(fallbackCrest.count, 12)
        for pt in fallbackCrest {
            XCTAssertTrue(pt.yFraction.isFinite && (0.0...1.0).contains(pt.yFraction))
        }

        let pitchCrest = StorybookWreathAndSongbookKinematics.hillCrestPoints(from: [0.1, 0.9, 0.4], sampleCount: 12)
        XCTAssertEqual(pitchCrest.count, 12)
        XCTAssertEqual(pitchCrest.first?.xFraction ?? -1, 0.0, accuracy: 1e-6)
        XCTAssertEqual(pitchCrest.last?.xFraction ?? -1, 1.0, accuracy: 1e-6)
        for i in 1..<pitchCrest.count {
            XCTAssertGreaterThan(pitchCrest[i].xFraction, pitchCrest[i - 1].xFraction)
            XCTAssertTrue(pitchCrest[i].yFraction.isFinite && (0.0...1.0).contains(pitchCrest[i].yFraction))
        }

        // 5. 花环 12 点钟书签角标角度（含 NaN 与 Reduce Motion 分支）
        XCTAssertEqual(StorybookWreathAndSongbookKinematics.wreathBookmarkAngle(forPlayheadFraction: .nan, reduceMotion: false), -Double.pi / 2.0, accuracy: 1e-6)
        XCTAssertEqual(StorybookWreathAndSongbookKinematics.wreathBookmarkAngle(forPlayheadFraction: 0.5, reduceMotion: false), -Double.pi / 2.0, accuracy: 1e-6)
        XCTAssertEqual(StorybookWreathAndSongbookKinematics.wreathBookmarkAngle(forPlayheadFraction: 0.5, reduceMotion: true), Double.pi / 2.0, accuracy: 1e-6)

        // 6. 三态明信片（山坡 / 花环 / 星环）与去黑胶开卷星章印记渲染校验
        for mode in StageVisualMode.displayOrder {
            XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: vm.document, isNight: false, visualMode: mode, includeJianpuStrip: true))
            XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: vm.document, isNight: true, visualMode: mode, includeJianpuStrip: true))
        }
        XCTAssertNotNil(ChimmoCraftMark(.vinylSeal, color: ChimmoPalette(isNight: false).nightLampGold))
    }

    @MainActor
    func testCreativeAlchemyRound39FullChainStorybookIdentityConsistency() {
        // 1. 主舞台默认山坡态与三态绘本排布契约
        let vm = StudioViewModel()
        XCTAssertEqual(vm.visualMode, .flowingRiver)
        XCTAssertEqual(StageVisualMode.displayOrder, [.flowingRiver, .orbitalDisc, .resonanceNebula])
        XCTAssertEqual(StageVisualMode.displayOrder.map(\.storybookLabel), ["山坡", "花环", "星环"])
        XCTAssertEqual(StageVisualMode.displayOrder.map(\.iconName), ["mountain.2.fill", "rays", "sparkles"])

        // 2. 1-3-5 核心三音家族与 4/7 张力家族定位和官网 / 短片一致
        XCTAssertEqual(ChimmoMember.allCases.filter(\.isTriadPillar), [.taono, .plokko, .corllo])
        XCTAssertEqual(ChimmoMember.allCases.filter(\.isTensionDegree), [.udo, .tinki])

        // 3. 两极交互视觉契约与减弱动态效果一致性
        let interactiveSpec = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary, isPressed: false, reduceMotion: false)
        let pressedSpec = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary, isPressed: true, reduceMotion: false)
        let reducedPressedSpec = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary, isPressed: true, reduceMotion: true)
        let quietSpec = StorybookAffordanceMetrics.styleSpec(for: .quietContainer, isPressed: false, reduceMotion: false)
        let readOnlySpec = StorybookAffordanceMetrics.styleSpec(for: .readOnlyLabel, isPressed: false, reduceMotion: false)

        XCTAssertTrue(interactiveSpec.usesHardInkOutline)
        XCTAssertGreaterThan(interactiveSpec.shadowOffsetY, pressedSpec.shadowOffsetY)
        XCTAssertEqual(pressedSpec.pressSinkOffsetY, 2.0)
        XCTAssertEqual(reducedPressedSpec.pressSinkOffsetY, 0.0)
        XCTAssertEqual(interactiveSpec.minHitDimension, 44.0)
        XCTAssertEqual(quietSpec.shadowOffsetY, 0.0)
        XCTAssertFalse(quietSpec.usesHardInkOutline)
        XCTAssertEqual(readOnlySpec.borderWidth, 0.0)
        XCTAssertEqual(readOnlySpec.shadowOffsetY, 0.0)

        // 4. 绘本曲谱封面、连续山坡轮廓与 12 点钟书签星花环运动学
        let idleBook = StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: false, reduceMotion: false)
        let activeBook = StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: true, reduceMotion: false)
        let reducedBook = StorybookWreathAndSongbookKinematics.bookCoverState(isPlaying: true, reduceMotion: true)
        XCTAssertGreaterThan(activeBook.pagePeekOffsetX, idleBook.pagePeekOffsetX)
        XCTAssertLessThan(activeBook.coverTiltDegrees, 0.0)
        XCTAssertEqual(reducedBook.coverTiltDegrees, 0.0)

        let hillPoints = StorybookWreathAndSongbookKinematics.hillCrestPoints(
            from: [0.0, 0.25, 0.5, 0.75, 1.0, .nan],
            sampleCount: 16
        )
        XCTAssertEqual(hillPoints.count, 16)
        XCTAssertTrue(hillPoints.allSatisfy { $0.xFraction.isFinite && $0.yFraction >= 0.08 && $0.yFraction <= 0.92 })

        XCTAssertEqual(
            StorybookWreathAndSongbookKinematics.wreathBookmarkAngle(forPlayheadFraction: 0.5, reduceMotion: false),
            -Double.pi / 2.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            StorybookWreathAndSongbookKinematics.wreathBookmarkAngle(forPlayheadFraction: 0.5, reduceMotion: true),
            Double.pi / 2.0,
            accuracy: 0.0001
        )

        // 5. 日夜双色与三态明信片导出链路回归守护
        for mode in StageVisualMode.displayOrder {
            XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: vm.document, isNight: false, visualMode: mode, includeJianpuStrip: true))
            XCTAssertNotNil(VinylPostcardExporter.renderPNGData(document: vm.document, isNight: true, visualMode: mode, includeJianpuStrip: true))
        }
    }

    @MainActor
    func testCreativeAlchemyRound40ShowcaseCreateSplitSongPickerAndCommercialSettings() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r40_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        XCTAssertEqual(vm.activeSpace, .showcase)
        XCTAssertTrue(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.title, SpecimenLibrary.saintSaensTheSwan.title)
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        // 1. 切换进入独立「创作」空间：干净可写的个人空白草稿
        vm.switchSpace(to: .create)
        XCTAssertEqual(vm.activeSpace, .create)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertTrue(vm.document.notes.isEmpty)
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        // 2. 通过创作区琴键写入 3 颗音符，确保可连续追加且未保存状态准确标记
        vm.appendOrReplaceNoteFromCreateKey(XylophoneLane.lane(at: 0))
        vm.appendOrReplaceNoteFromCreateKey(XylophoneLane.lane(at: 2))
        vm.appendOrReplaceNoteFromCreateKey(XylophoneLane.lane(at: 4))
        XCTAssertEqual(vm.document.notes.count, 3)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        XCTAssertNil(vm.selectedBeadID)

        // 3. 切回「欣赏」浏览名曲与自由伴奏即兴，不得破坏已写草稿，也不篡改经典正典
        vm.switchSpace(to: .showcase)
        XCTAssertEqual(vm.activeSpace, .showcase)
        XCTAssertTrue(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.title, SpecimenLibrary.saintSaensTheSwan.title)
        vm.auditionShowcaseLane(XylophoneLane.lane(at: 2))
        XCTAssertTrue(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.notes.count, SpecimenLibrary.saintSaensTheSwan.notes.count)

        // 4. 切回「创作」后，3 颗未保存草稿音符与未保存标记完好保留；支持明确「试听」与「保存作品」
        vm.switchSpace(to: .create)
        XCTAssertEqual(vm.activeSpace, .create)
        XCTAssertEqual(vm.document.notes.count, 3)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)

        vm.auditionCurrentCreation()
        XCTAssertTrue(vm.isPlaying)
        vm.stopPlayback()
        XCTAssertFalse(vm.isPlaying)

        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)
        XCTAssertNotNil(vm.currentSavedEntryID)
        XCTAssertEqual(vm.notebook.entries.count, 1)

        // 5. 从「欣赏」点击「去改编」复制经典进入创作空间，不污染原始「天鹅」赏析副本
        vm.switchSpace(to: .showcase)
        vm.forkCurrentShowcaseIntoCreate()
        XCTAssertEqual(vm.activeSpace, .create)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertTrue(vm.document.title.contains(SpecimenLibrary.saintSaensTheSwan.title))
        XCTAssertTrue(vm.hasUnsavedCreationChanges)

        vm.switchSpace(to: .showcase)
        XCTAssertTrue(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.title, SpecimenLibrary.saintSaensTheSwan.title)

        // 6. 商业级三标签架构、创作页、设置页与法务文档视图实例化校验（日夜双色）
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertEqual(ChimmoTab.board, ChimmoTab.showcase)
        XCTAssertEqual(ChimmoTab.musicBox, ChimmoTab.songbook)
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: dayPalette))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(SettingsView(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SettingsView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}, onForkToCreate: {}))
        XCTAssertNotNil(MusicBoxShelfView(palette: dayPalette, synth: vm.synth, notebook: vm.notebook, currentDocumentID: vm.document.id, initialSegment: 1, navigationTitleText: "选择曲目", showsDismissButton: true, onLoadSavedToBoard: { _ in }, onPlayAlongSpecimen: { _ in }, onEditSpecimenOnBoard: { _ in }, onForkSpecimenToCreate: { _ in }, onStartNewTap: {}))
        XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: dayPalette, initialTab: 1))
        XCTAssertNotNil(AboutSheetView(palette: dayPalette, currentDocument: vm.document, cradleEnabled: vm.cradleEnabled))
        for docKind in ChimmoLegalDocumentView.LegalDocumentKind.allCases {
            XCTAssertNotNil(ChimmoLegalDocumentView(kind: docKind))
        }
        XCTAssertNotNil(CharacterSoundTestView(palette: nightPalette))
    }

    @MainActor
    func testCreativeAlchemyRound41CreationCraftChapterFlipAndDirtyTracking() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r41_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. CreationStarterSeed 三颗灵感种子与纯值边界校验
        XCTAssertEqual(CreationStarterSeed.allCases.count, 3)
        for seed in CreationStarterSeed.allCases {
            XCTAssertFalse(seed.shortLabel.isEmpty)
            XCTAssertFalse(seed.titlePrefix.isEmpty)
            XCTAssertGreaterThanOrEqual(seed.notes.count, 5)
            for idx in seed.notes.indices {
                XCTAssertGreaterThan(seed.notes[idx].rawOnset, 0.0)
                XCTAssertGreaterThanOrEqual(seed.notes[idx].rawDuration, 0.30)
                if idx > 0 {
                    XCTAssertGreaterThan(seed.notes[idx].rawOnset, seed.notes[idx - 1].rawOnset)
                }
            }
        }

        // 2. CreationDraftMetrics 状态格式化与 NaN 保护
        XCTAssertEqual(
            CreationDraftMetrics.statusLine(noteCount: 0, totalDuration: 3.2, isSaved: false, hasUnsavedChanges: false),
            "空白草稿"
        )
        XCTAssertEqual(
            CreationDraftMetrics.statusLine(noteCount: 5, totalDuration: .nan, isSaved: false, hasUnsavedChanges: true),
            "未保存 · 5 音"
        )
        XCTAssertEqual(
            CreationDraftMetrics.statusLine(noteCount: 5, totalDuration: 3.5, isSaved: true, hasUnsavedChanges: false),
            "已保存 · 5 音 · 3.5s"
        )

        // 3. Showcase 绘本分幕前后翻页导航与跳转播放
        let swan = SpecimenLibrary.saintSaensTheSwan
        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        XCTAssertEqual(vm.activeSpace, .showcase)
        XCTAssertEqual(vm.document.title, swan.title)

        let nav0 = StorybookGuidedMomentKinematics.chapterNavigation(for: swan.guidedMoments?.first, in: swan)
        XCTAssertNotNil(nav0)
        XCTAssertEqual(nav0?.currentIndex, 0)
        XCTAssertEqual(nav0?.totalCount, 3)
        XCTAssertEqual(nav0?.progressLabel, "1/3")
        XCTAssertFalse(nav0?.canStepPrevious ?? true)
        XCTAssertTrue(nav0?.canStepNext ?? false)

        vm.stepGuidedMoment(delta: 1)
        XCTAssertEqual(vm.activeGuidedMoment?.id, 1)
        XCTAssertTrue(vm.isPlaying)
        vm.stopPlayback()

        if let thirdMoment = swan.guidedMoments?.last {
            vm.jumpToGuidedMoment(thirdMoment, autoPlay: false)
            XCTAssertEqual(vm.activeGuidedMoment?.id, thirdMoment.id)
            XCTAssertNotNil(vm.clock.scrubTime)
            XCTAssertGreaterThan(vm.clock.scrubTime ?? 0.0, 1.0)
        }

        let navLast = StorybookGuidedMomentKinematics.chapterNavigation(for: vm.activeGuidedMoment, in: swan)
        XCTAssertEqual(navLast?.progressLabel, "3/3")
        XCTAssertTrue(navLast?.canStepPrevious ?? false)
        XCTAssertFalse(navLast?.canStepNext ?? true)

        // 4. Creation 种子种植、脏状态全链路闭环与跟灯状态防误写守卫
        vm.switchSpace(to: .create)
        vm.plantCreationStarter(.moonlightCradle)
        XCTAssertFalse(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.scaleMode, .wistfulMinor)
        XCTAssertNil(vm.selectedBeadID)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        let seedCount = vm.document.notes.count
        vm.stopPlayback()

        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        vm.setChordPreset(.classicPop)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        vm.setAccompanimentTexture(.feltWaltz)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        vm.setMelodyVoice(.celestaGlass)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        vm.setRootMIDI(62)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        vm.cycleSpanChord(spanIndex: 0)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        vm.undo()
        XCTAssertTrue(vm.hasUnsavedCreationChanges)

        // 跟灯激活期间在创作区点按七小只琴键不得额外追加新音符
        vm.toggleFollowGlow()
        XCTAssertTrue(vm.followGlowActive)
        let countBeforeFollowTap = vm.document.notes.count
        vm.appendOrReplaceNoteFromCreateKey(XylophoneLane.lane(at: 0))
        XCTAssertEqual(vm.document.notes.count, countBeforeFollowTap)
        vm.toggleFollowGlow()
        XCTAssertFalse(vm.followGlowActive)
        XCTAssertEqual(countBeforeFollowTap, seedCount)

        // 验证 Showcase 原作未受创作操作影响
        vm.switchSpace(to: .showcase)
        XCTAssertTrue(vm.document.isSpecimen)
        XCTAssertEqual(vm.document.title, swan.title)

        // 5. 日夜双色视图实例化回归校验
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: dayPalette))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(NightLampTactileSheet(vm: vm))
        XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SettingsView(vm: vm, palette: dayPalette))
    }

    @MainActor
    func testCreativeAlchemyRound42FullChainThreeSpaceAndOpenMotionAlignment() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r42_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. 三域独立空间标签顺序与向后兼容别名校验
        XCTAssertEqual(ChimmoTab.allCases, [.showcase, .create, .songbook, .settings])
        XCTAssertEqual(ChimmoTab.board, .showcase)
        XCTAssertEqual(ChimmoTab.musicBox, .songbook)

        // 2. CreationStarterSeed 三颗起音种子调式与独立命名前缀校验
        XCTAssertEqual(CreationStarterSeed.allCases, [.sunnyMeadow, .moonlightCradle, .hoppingSteps])
        XCTAssertEqual(CreationStarterSeed.sunnyMeadow.recommendedScaleMode, .brightMajor)
        XCTAssertEqual(CreationStarterSeed.moonlightCradle.recommendedScaleMode, .wistfulMinor)
        XCTAssertEqual(CreationStarterSeed.hoppingSteps.recommendedScaleMode, .cloudLydian)
        XCTAssertEqual(Set(CreationStarterSeed.allCases.map(\.titlePrefix)).count, 3)

        // 3. Two-Pole Affordance Contract：只读标签零边框零阴影，主按钮 >= 44pt 热区与暖墨描边
        let readOnlySpec = StorybookAffordanceMetrics.styleSpec(for: .readOnlyLabel)
        XCTAssertEqual(readOnlySpec.borderWidth, 0.0, accuracy: 0.0001)
        XCTAssertEqual(readOnlySpec.shadowOffsetY, 0.0, accuracy: 0.0001)
        XCTAssertFalse(readOnlySpec.usesHardInkOutline)

        let quietSpec = StorybookAffordanceMetrics.styleSpec(for: .quietContainer)
        XCTAssertEqual(quietSpec.shadowOffsetY, 0.0, accuracy: 0.0001)
        XCTAssertFalse(quietSpec.usesHardInkOutline)

        let primarySpec = StorybookAffordanceMetrics.styleSpec(for: .interactivePrimary)
        XCTAssertGreaterThanOrEqual(primarySpec.minHitDimension, 44.0)
        XCTAssertTrue(primarySpec.usesHardInkOutline)

        // 4. 分幕导航契约：nil/empty 均返回 nil，并在德沃夏克《念故乡》3 幕曲谱上验证首尾边界
        let nilMomentsDoc = MelodyDocument(title: "无分幕草稿", guidedMoments: nil)
        XCTAssertNil(StorybookGuidedMomentKinematics.chapterNavigation(for: nil, in: nilMomentsDoc))

        let emptyMomentsDoc = MelodyDocument(title: "空分幕草稿", guidedMoments: [])
        XCTAssertNil(StorybookGuidedMomentKinematics.chapterNavigation(for: nil, in: emptyMomentsDoc))

        let goingHome = SpecimenLibrary.dvorakGoingHome
        let moments = try XCTUnwrap(goingHome.guidedMoments)
        XCTAssertEqual(moments.count, 3)

        let navStart = try XCTUnwrap(StorybookGuidedMomentKinematics.chapterNavigation(for: moments[0], in: goingHome))
        XCTAssertEqual(navStart.totalCount, 3)
        XCTAssertEqual(navStart.currentIndex, 0)
        XCTAssertFalse(navStart.canStepPrevious)
        XCTAssertTrue(navStart.canStepNext)

        let navMiddle = try XCTUnwrap(StorybookGuidedMomentKinematics.chapterNavigation(for: moments[1], in: goingHome))
        XCTAssertEqual(navMiddle.totalCount, 3)
        XCTAssertEqual(navMiddle.currentIndex, 1)
        XCTAssertTrue(navMiddle.canStepPrevious)
        XCTAssertTrue(navMiddle.canStepNext)

        let navEnd = try XCTUnwrap(StorybookGuidedMomentKinematics.chapterNavigation(for: moments[2], in: goingHome))
        XCTAssertEqual(navEnd.totalCount, 3)
        XCTAssertEqual(navEnd.currentIndex, 2)
        XCTAssertTrue(navEnd.canStepPrevious)
        XCTAssertFalse(navEnd.canStepNext)

        // 5. 三域状态切换隔离 + 日夜设置视图回归
        XCTAssertEqual(StudioSpace.allCases, [.showcase, .create])
        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.openSpecimen(goingHome, autoPlay: false)
        XCTAssertEqual(vm.activeSpace, .showcase)
        vm.stepGuidedMoment(delta: 1)
        XCTAssertEqual(vm.activeGuidedMoment?.id, moments[1].id)
        vm.stopPlayback()

        vm.switchSpace(to: .create)
        vm.plantCreationStarter(.hoppingSteps)
        XCTAssertEqual(vm.document.scaleMode, .cloudLydian)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        vm.stopPlayback()

        vm.switchSpace(to: .showcase)
        XCTAssertEqual(vm.document.title, goingHome.title)
        XCTAssertNotNil(SettingsView(vm: vm, palette: ChimmoPalette(isNight: true)))
    }

    @MainActor
    func testCreativeAlchemyRound43BeatPitchAdjustmentAndCompactHitTargets() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r43_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. 紧凑工具按钮触控热区标准校验（>= 40pt）
        XCTAssertGreaterThanOrEqual(StorybookAffordanceMetrics.compactToolMinHitDimension, 40.0)
        let expandedTarget = StorybookAffordanceMetrics.validatedHitTarget(
            visualWidth: 34,
            visualHeight: 34,
            minimum: StorybookAffordanceMetrics.compactToolMinHitDimension
        )
        XCTAssertGreaterThanOrEqual(expandedTarget.width, 40.0)
        XCTAssertGreaterThanOrEqual(expandedTarget.height, 40.0)

        // 2. CreateBeatAdjustmentDescriptor 音级微调上下限与 NaN 防护校验
        let lowDoBead = NoteBead(degree: 1, octaveOffset: 0, rawOnset: 0.2, rawDuration: .nan)
        let lowDesc = CreateBeatAdjustmentDescriptor(
            bead: lowDoBead,
            index: 0,
            totalCount: 3,
            pentatonicSafe: true
        )
        XCTAssertEqual(lowDesc.beatProgressLabel, "1/3")
        XCTAssertFalse(lowDesc.canStepPrevious)
        XCTAssertTrue(lowDesc.canStepNext)
        XCTAssertFalse(lowDesc.canStepPitchDown)
        XCTAssertTrue(lowDesc.canStepPitchUp)
        XCTAssertFalse(lowDesc.pitchSummaryLabel.lowercased().contains("nan"))

        let highDoBead = NoteBead(degree: 1, octaveOffset: 1, rawOnset: 1.0, rawDuration: 0.8)
        let highDesc = CreateBeatAdjustmentDescriptor(
            bead: highDoBead,
            index: 2,
            totalCount: 3,
            pentatonicSafe: true
        )
        XCTAssertEqual(highDesc.beatProgressLabel, "3/3")
        XCTAssertTrue(highDesc.canStepPrevious)
        XCTAssertFalse(highDesc.canStepNext)
        XCTAssertTrue(highDesc.canStepPitchDown)
        XCTAssertFalse(highDesc.canStepPitchUp)
        XCTAssertTrue(highDesc.pitchSummaryLabel.contains("0.8s"))

        // 3. 创作区单拍音级微调闭环（含五音规避、下界不溢出与脏状态追踪）
        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.switchSpace(to: .create)
        vm.plantCreationStarter(.sunnyMeadow)
        vm.stopPlayback()
        vm.saveCurrentToNotebook()
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        let firstBead = try XCTUnwrap(vm.document.notes.first)
        XCTAssertEqual(firstBead.degree, 1)
        vm.selectBead(firstBead.id, playContext: false)

        // 已在最低音 1 Do，向下降不应发生越界修改
        vm.shiftSelectedBeadPitch(delta: -1)
        XCTAssertEqual(vm.document.notes.first?.degree, 1)
        XCTAssertFalse(vm.hasUnsavedCreationChanges)

        // 向上升一格到 2 Re，应更新乐谱并标记未保存改动
        vm.shiftSelectedBeadPitch(delta: 1)
        XCTAssertEqual(vm.document.notes.first?.degree, 2)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)

        // 再升两格（3 Mi -> 跳过 4 Fa（五音安全开启）-> 5 Sol）
        vm.shiftSelectedBeadPitch(delta: 1)
        vm.shiftSelectedBeadPitch(delta: 1)
        XCTAssertEqual(vm.document.notes.first?.degree, 5)

        // 降一格回到 3 Mi
        vm.shiftSelectedBeadPitch(delta: -1)
        XCTAssertEqual(vm.document.notes.first?.degree, 3)

        // 4. 日夜与图鉴无障碍视图回归构造
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: dayPalette))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: nightPalette))
        XCTAssertNotNil(VinylPostcardShareSheet(palette: dayPalette, request: VinylPostcardRequest(document: vm.document)))
        XCTAssertNotNil(AboutSheetView(palette: dayPalette, currentDocument: vm.document, cradleEnabled: true))
        XCTAssertNotNil(SettingsView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(CharacterSoundTestView(palette: dayPalette, scaleMode: .wistfulMinor, cradleEnabled: true))
    }

    @MainActor
    func testCreativeAlchemyRound44All28SpecimensHaveStorybookChapters() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r44_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let allSpecimens = SpecimenLibrary.all
        XCTAssertEqual(allSpecimens.count, 28)

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))

        for spec in allSpecimens {
            let moments = try XCTUnwrap(spec.guidedMoments, "曲目《\(spec.title)》应配备绘本分幕角标")
            XCTAssertGreaterThanOrEqual(moments.count, 2, "曲目《\(spec.title)》至少包含 2 幕故事")

            var prevFraction = -0.1
            for (idx, moment) in moments.enumerated() {
                XCTAssertEqual(moment.id, idx)
                XCTAssertGreaterThanOrEqual(moment.timeFraction, 0.0)
                XCTAssertLessThan(moment.timeFraction, 1.0)
                XCTAssertGreaterThan(moment.timeFraction, prevFraction)
                prevFraction = moment.timeFraction
                XCTAssertFalse(moment.badge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertFalse(moment.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                let nav = try XCTUnwrap(StorybookGuidedMomentKinematics.chapterNavigation(for: moment, in: spec))
                XCTAssertEqual(nav.currentIndex, idx)
                XCTAssertEqual(nav.totalCount, moments.count)
                XCTAssertEqual(nav.canStepPrevious, idx > 0)
                XCTAssertEqual(nav.canStepNext, idx + 1 < moments.count)

                let chip = StorybookGuidedMomentKinematics.chipModel(moment: moment, document: spec)
                XCTAssertNotNil(chip)
            }

            vm.openSpecimen(spec, autoPlay: false)
            XCTAssertEqual(vm.activeGuidedMoment?.id, 0)
            vm.stepGuidedMoment(delta: 1)
            XCTAssertEqual(vm.activeGuidedMoment?.id, 1)
            vm.stopPlayback()
        }
    }

    @MainActor
    func testCreativeAlchemyRound45ReduceMotionKeyboardAndDynamicTypeContract() throws {
        // 1. 硬件键盘快捷键契约：欣赏与创作双空间严格隔离且键位无冲突
        let showcaseKeys = StorybookAffordanceMetrics.keyboardShortcuts(for: .showcase)
        let createKeys = StorybookAffordanceMetrics.keyboardShortcuts(for: .create)
        XCTAssertFalse(showcaseKeys.isEmpty)
        XCTAssertFalse(createKeys.isEmpty)
        XCTAssertEqual(Set(showcaseKeys.map(\.keyLabel)).count, showcaseKeys.count)
        XCTAssertEqual(Set(createKeys.map(\.keyLabel)).count, createKeys.count)
        XCTAssertEqual(showcaseKeys.map(\.keyLabel), ["Space"])
        XCTAssertEqual(createKeys.map(\.keyLabel), ["Space", "Cmd+S", "Cmd+Z", "Cmd+N"])
        XCTAssertTrue(showcaseKeys.allSatisfy { $0.space == .showcase && !$0.actionTitle.isEmpty })
        XCTAssertTrue(createKeys.allSatisfy { $0.space == .create && !$0.actionTitle.isEmpty })

        // 2. 空间切换与状态隔离契约
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r45_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        XCTAssertEqual(vm.activeSpace, .showcase)
        XCTAssertFalse(vm.document.notes.isEmpty)

        vm.switchSpace(to: .create)
        XCTAssertEqual(vm.activeSpace, .create)
        vm.plantCreationStarter(.sunnyMeadow)
        XCTAssertFalse(vm.document.notes.isEmpty)

        vm.switchSpace(to: .showcase)
        XCTAssertEqual(vm.activeSpace, .showcase)
        XCTAssertFalse(vm.document.notes.isEmpty)

        // 3. 日夜模式与 Reduce Motion / Dynamic Type 核心视图构造回归
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotNil(AmbientPaperBackdrop(palette: dayPalette))
        XCTAssertNotNil(AmbientPaperBackdrop(palette: nightPalette))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(AboutSheetView(palette: dayPalette, currentDocument: vm.document, cradleEnabled: true))
        XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: nightPalette))
        XCTAssertNotNil(NightLampTactileSheet(vm: vm))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SettingsView(vm: vm, palette: nightPalette))
    }

    @MainActor
    func testCreativeAlchemyRound46DynamicTypeAndZeroSub40ptHitTargets() throws {
        // 1. 全端触控最小尺寸与紧凑胶囊缩放比例契约
        XCTAssertEqual(StorybookAffordanceMetrics.compactToolMinHitDimension, 40.0, accuracy: 0.001)
        XCTAssertEqual(StorybookAffordanceMetrics.compactPillMinimumScaleFactor, 0.75, accuracy: 0.001)
        XCTAssertTrue((0.5...0.9).contains(StorybookAffordanceMetrics.compactPillMinimumScaleFactor))

        let hitTarget = StorybookAffordanceMetrics.validatedHitTarget(
            visualWidth: 34.0,
            visualHeight: 32.0,
            minimum: StorybookAffordanceMetrics.compactToolMinHitDimension
        )
        XCTAssertEqual(hitTarget.width, 40.0, accuracy: 0.001)
        XCTAssertEqual(hitTarget.height, 40.0, accuracy: 0.001)

        // 2. 日夜与无障碍 Dynamic Type 核心工作区与抽屉视图实例化回归
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r46_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)

        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(
            MusicBoxShelfView(
                palette: dayPalette,
                synth: vm.synth,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                onLoadSavedToBoard: { _ in },
                onPlayAlongSpecimen: { _ in },
                onEditSpecimenOnBoard: { _ in },
                onStartNewTap: {}
            )
        )
        XCTAssertNotNil(
            MusicBoxShelfView(
                palette: nightPalette,
                synth: vm.synth,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                onLoadSavedToBoard: { _ in },
                onPlayAlongSpecimen: { _ in },
                onEditSpecimenOnBoard: { _ in },
                onStartNewTap: {}
            )
        )
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: nightPalette))
        XCTAssertNotNil(NightLampTactileSheet(vm: vm))
    }

    @MainActor
    func testCreativeAlchemyRound47MosslingSpinOffFourTabAtelierArchitecture() throws {
        // 1. 摸索台灯同源四标签纯血叙事架构（聆听 · 创作 · 曲本 · 工坊）
        XCTAssertEqual(ChimmoTab.allCases, [.showcase, .create, .songbook, .settings])
        XCTAssertEqual(ChimmoTab.board, .showcase)
        XCTAssertEqual(ChimmoTab.musicBox, .songbook)
        XCTAssertEqual(AppearancePreference.allCases.map(\.label), ["自动", "日光", "夜灯"])

        // 2. 嵌套圆角体系由外向内严格递减
        XCTAssertGreaterThan(ChimmoRadius.stage, ChimmoRadius.card)
        XCTAssertGreaterThan(ChimmoRadius.card, ChimmoRadius.inner)
        XCTAssertGreaterThan(ChimmoRadius.inner, ChimmoRadius.tile)
        XCTAssertGreaterThan(ChimmoRadius.tile, ChimmoRadius.chip)

        // 3. 日夜色板衍生统一性与对比边界
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotEqual(dayPalette.paper, nightPalette.paper)
        XCTAssertNotEqual(dayPalette.cardSurface, nightPalette.cardSurface)
        XCTAssertNotEqual(dayPalette.prominentFill, dayPalette.paper)
        XCTAssertNotEqual(dayPalette.celadonAccent, nightPalette.celadonAccent)

        // 4. 新版工坊组件与四标签全视图日夜回归实例化
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("chimmo_r47_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        XCTAssertNotNil(ChimmoFlowRow(spacing: 7, lineSpacing: 7))
        XCTAssertNotNil(ChimmoResonanceBead(size: 10, isNight: false))
        XCTAssertNotNil(ChimmoResonanceBead(size: 10, isNight: true))
        XCTAssertNotNil(ChimmoSectionTitle(title: "声学与舞台设定", detail: "日夜同辉", isNight: false))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(
            MusicBoxShelfView(
                palette: dayPalette,
                synth: vm.synth,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                navigationTitleText: "曲本",
                showsDismissButton: false,
                onLoadSavedToBoard: { _ in },
                onPlayAlongSpecimen: { _ in },
                onEditSpecimenOnBoard: { _ in },
                onStartNewTap: {}
            )
        )
        XCTAssertNotNil(SettingsView(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SettingsView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(CharacterSoundTestView(palette: dayPalette))
        XCTAssertNotNil(CharacterSoundTestView(palette: nightPalette))
    }

    @MainActor
    func testCreativeAlchemyRound48ModalSheetsAtelierCohesion() throws {
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotEqual(dayPalette.prominentFill, nightPalette.prominentFill)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_r48_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.plantCreationStarter(.sunnyMeadow)
        vm.setChordPreset(.autoMatch)
        vm.toggleFollowGlow()
        XCTAssertNotNil(vm.document.id)

        // 1. 调音百宝箱 SoundPaletteBoxSheet 昼夜渲染实例化
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: nightPalette))

        // 2. 灵光捕手 DreamCaptureSheet 三大分镜（0 节奏画线 / 1 轻哼电台 / 2 折纸工坊）
        for tabIndex in [0, 1, 2] {
            XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: dayPalette, initialTab: tabIndex))
            XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: nightPalette, initialTab: tabIndex))
        }

        // 3. 明信片分享页与跟弹主舞台组件同源实例化
        let postcardRequest = VinylPostcardRequest(document: vm.document)
        XCTAssertNotNil(VinylPostcardShareSheet(palette: dayPalette, request: postcardRequest))
        XCTAssertNotNil(VinylPostcardShareSheet(palette: nightPalette, request: postcardRequest))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: dayPalette))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(
            MusicBoxShelfView(
                palette: nightPalette,
                synth: vm.synth,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                navigationTitleText: "曲本",
                showsDismissButton: false,
                onLoadSavedToBoard: { _ in },
                onPlayAlongSpecimen: { _ in },
                onEditSpecimenOnBoard: { _ in },
                onStartNewTap: {}
            )
        )
    }

    @MainActor
    func testCreativeAlchemyRound49NightLampAndFullEcosystemSync() throws {
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertEqual(ChimmoTab.allCases, [.showcase, .create, .songbook, .settings])

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_r49_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.plantCreationStarter(.sunnyMeadow)

        let nightSheet = NightLampTactileSheet(vm: vm)
        XCTAssertNotNil(nightSheet)
        XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        XCTAssertNotNil(CreateStudioView(vm: vm, palette: nightPalette))
        XCTAssertNotNil(SettingsView(vm: vm, palette: nightPalette))
    }

    @MainActor
    func testCreativeAlchemyRound50ZeroCartoonShadowAndFullOttoNightCohesion() throws {
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotEqual(dayPalette.paper, nightPalette.paper)
        XCTAssertNotEqual(dayPalette.prominentFill, nightPalette.prominentFill)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_r50_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.plantCreationStarter(.sunnyMeadow)

        for mode in StageVisualMode.allCases {
            vm.visualMode = mode
            XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
            XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        }

        XCTAssertNotNil(NightLampTactileSheet(vm: vm))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: nightPalette))
        XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: nightPalette, initialTab: 1))
    }

    @MainActor
    func testCreativeAlchemyRound51PostcardZeroShadowAndCreationSongbookLoop() throws {
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_r51_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.switchSpace(to: .create)
        vm.plantCreationStarter(.sunnyMeadow)
        vm.renameCurrentSong("晨露窑钟")
        let pulseBeforeSave = vm.lastSavedPulse
        vm.saveCurrentToNotebook()

        let savedID = try XCTUnwrap(vm.currentSavedEntryID)
        XCTAssertFalse(vm.hasUnsavedCreationChanges)
        XCTAssertEqual(vm.lastSavedPulse, pulseBeforeSave + 1)
        XCTAssertNil(vm.statusToast)

        let savedEntry = try XCTUnwrap(vm.notebook.entries.first(where: { $0.id == savedID }))

        // 1. 窑纸明信片导出（日/夜 × 三画境）均能离线非空渲染
        for isNight in [false, true] {
            for mode in StageVisualMode.allCases {
                let png = VinylPostcardExporter.renderPNGData(
                    document: savedEntry.document,
                    shadowEnabled: true,
                    isNight: isNight,
                    visualMode: mode,
                    includeJianpuStrip: true
                )
                XCTAssertNotNil(png)
            }
        }

        // 2. 从创作修改草稿后切至「聆听」播放曲本作品，切回创作仍保留未保存编辑快照
        let countBeforeMutation = vm.document.notes.count
        vm.placeNoteOnCanvas(degree: 5, octaveOffset: 0, atTime: 2.2)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)
        let mutatedCount = vm.document.notes.count
        XCTAssertGreaterThan(mutatedCount, countBeforeMutation)

        vm.switchSpace(to: .showcase)
        vm.openSavedEntry(savedEntry, autoPlay: false)
        XCTAssertEqual(vm.document.notes.count, countBeforeMutation)

        vm.switchSpace(to: .create)
        XCTAssertEqual(vm.document.notes.count, mutatedCount)
        XCTAssertTrue(vm.hasUnsavedCreationChanges)

        // 3. 新版「聆听 / 编辑」双回调在日/夜与弹窗下均可安全实例化
        XCTAssertNotNil(
            CreateStudioView(
                vm: vm,
                palette: dayPalette,
                onOpenSavedInShowcase: { _ in }
            )
        )
        XCTAssertNotNil(
            OrbitalStageView(
                vm: vm,
                palette: nightPalette,
                onOpenAbout: {},
                onOpenSharePostcard: {},
                onOpenSavedInCreate: { _ in }
            )
        )
        XCTAssertNotNil(
            MusicBoxShelfView(
                palette: nightPalette,
                synth: vm.synth,
                notebook: vm.notebook,
                currentDocumentID: vm.document.id,
                navigationTitleText: "曲本",
                showsDismissButton: false,
                onLoadSavedToBoard: { _ in },
                onPlaySavedInShowcase: { _ in },
                onPlayAlongSpecimen: { _ in },
                onEditSpecimenOnBoard: { _ in },
                onStartNewTap: {}
            )
        )
    }

    @MainActor
    func testCreativeAlchemyRound52ZeroCartoonOutlineAndInteractiveOscilloscope() throws {
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_r52_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        vm.plantCreationStarter(.sunnyMeadow)

        // 1. 声场示波合奏试听与全画境/捕音/调音台日夜实例化
        vm.auditionDuoGreeting()
        XCTAssertNil(vm.statusToast)
        vm.stopPlayback()

        for mode in StageVisualMode.allCases {
            vm.visualMode = mode
            XCTAssertNotNil(OrbitalStageView(vm: vm, palette: dayPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
            XCTAssertNotNil(OrbitalStageView(vm: vm, palette: nightPalette, onOpenAbout: {}, onOpenSharePostcard: {}))
        }

        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: nightPalette))
        for tab in [0, 1, 2] {
            XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: dayPalette, initialTab: tab))
            XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: nightPalette, initialTab: tab))
        }
    }

    @MainActor
    func testCreativeAlchemyRound53PitchChoirSpotlightAndInsetSurfaceToken() throws {
        // 1. StorybookChoirMeterKinematics.pitchFocusedBuddyIndex 非录音、空值、NaN 与夹紧边界校验
        XCTAssertNil(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: 0.5, isRecording: false))
        XCTAssertNil(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: nil, isRecording: true))
        XCTAssertNil(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: .nan, isRecording: true))
        XCTAssertNil(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: .infinity, isRecording: true))
        XCTAssertNil(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: 0.5, isRecording: true, buddyCount: 0))

        XCTAssertEqual(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: -0.4, isRecording: true), 0)
        XCTAssertEqual(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: 0.0, isRecording: true), 0)
        XCTAssertEqual(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: 0.5, isRecording: true), 3)
        XCTAssertEqual(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: 1.0, isRecording: true), 6)
        XCTAssertEqual(StorybookChoirMeterKinematics.pitchFocusedBuddyIndex(normalizedPitch: 1.8, isRecording: true), 6)

        // 2. ChimmoPalette.insetStageSurface 日/夜语义色板区分
        let dayPalette = ChimmoPalette(isNight: false)
        let nightPalette = ChimmoPalette(isNight: true)
        XCTAssertNotEqual(dayPalette.insetStageSurface, nightPalette.insetStageSurface)

        // 3. 捕梦工坊三大面板与调音百宝箱在日/夜下均可安全实例化
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chimmo_r53_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = StudioViewModel(notebookStore: MelodyNotebookStore(directory: tempDir))
        for tab in [0, 1, 2] {
            XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: dayPalette, initialTab: tab))
            XCTAssertNotNil(DreamCaptureSheet(vm: vm, palette: nightPalette, initialTab: tab))
        }
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: dayPalette))
        XCTAssertNotNil(SoundPaletteBoxSheet(vm: vm, palette: nightPalette))
    }
}
