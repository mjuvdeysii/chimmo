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
}
