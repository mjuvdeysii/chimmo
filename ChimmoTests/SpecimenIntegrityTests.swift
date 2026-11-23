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
            moodSticker: "✨ 我的名曲变奏",
            summaryNote: "从《天鹅》3 颗火种中改写出的专属变奏"
        )
        XCTAssertEqual(saved.moodSticker, "✨ 我的名曲变奏")

        let reloaded = MelodyNotebookStore(directory: tmpDir)
        XCTAssertEqual(reloaded.entries.first?.moodSticker, "✨ 我的名曲变奏")
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
}
