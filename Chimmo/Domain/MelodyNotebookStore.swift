import Foundation

/// 一条保存在本地「脑放记录本」中的个人旋律卡片（100% 离线持久化）。
public struct SavedMelodyEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var document: MelodyDocument
    public var chordPreset: ChordProgressionPreset
    public var chordOverrides: [Int: DiatonicChord]
    public var accompanimentTexture: AccompanimentTexture?
    public var moodSticker: String?
    public var summaryNote: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        accompanimentTexture: AccompanimentTexture? = .swanRipple,
        moodSticker: String? = "我的作品",
        summaryNote: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.document = document
        self.chordPreset = chordPreset
        self.chordOverrides = chordOverrides
        self.accompanimentTexture = accompanimentTexture
        self.moodSticker = moodSticker
        self.summaryNote = summaryNote
    }
}

/// 本地脑放旋律持久化仓库（存放在沙盒 Documents/chimmo_notebook.json，永不联网）。
@MainActor
public final class MelodyNotebookStore: ObservableObject {
    @Published public private(set) var entries: [SavedMelodyEntry] = []

    private let fileURL: URL

    public init(directory: URL? = nil) {
        let baseDir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = baseDir.appendingPathComponent("chimmo_notebook.json")
        load()
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([SavedMelodyEntry].self, from: data)
            entries = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            entries = []
        }
    }

    @discardableResult
    public func save(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset,
        chordOverrides: [Int: DiatonicChord],
        accompanimentTexture: AccompanimentTexture = .swanRipple,
        moodSticker: String? = nil,
        summaryNote: String,
        existingEntryID: UUID? = nil
    ) -> SavedMelodyEntry {
        var cleanDoc = document
        cleanDoc.isSpecimen = false
        if cleanDoc.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanDoc.title = "我的旋律 #\(entries.count + 1)"
        }

        let resolvedSticker = moodSticker ?? defaultSticker(for: cleanDoc.scaleMode)
        let now = Date()
        if let targetID = existingEntryID, let idx = entries.firstIndex(where: { $0.id == targetID }) {
            entries[idx].document = cleanDoc
            entries[idx].chordPreset = chordPreset
            entries[idx].chordOverrides = chordOverrides
            entries[idx].accompanimentTexture = accompanimentTexture
            entries[idx].moodSticker = resolvedSticker
            entries[idx].summaryNote = summaryNote
            entries[idx].updatedAt = now
            let updated = entries.remove(at: idx)
            entries.insert(updated, at: 0)
            persist()
            return updated
        } else {
            let entry = SavedMelodyEntry(
                createdAt: now,
                updatedAt: now,
                document: cleanDoc,
                chordPreset: chordPreset,
                chordOverrides: chordOverrides,
                accompanimentTexture: accompanimentTexture,
                moodSticker: resolvedSticker,
                summaryNote: summaryNote
            )
            entries.insert(entry, at: 0)
            persist()
            return entry
        }
    }

    private func defaultSticker(for mode: ScaleMode) -> String {
        switch mode {
        case .cloudLydian: return "梦幻"
        case .brightMajor: return "明亮"
        case .goldenMixolydian: return "温暖"
        case .forestDorian: return "清新"
        case .wistfulMinor: return "忧郁"
        }
    }

    @discardableResult
    public func rename(id: UUID, newTitle: String) -> SavedMelodyEntry? {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = entries.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        entries[idx].document.title = trimmed
        entries[idx].document.isSpecimen = false
        entries[idx].updatedAt = Date()
        let updated = entries.remove(at: idx)
        entries.insert(updated, at: 0)
        persist()
        return updated
    }

    @discardableResult
    public func duplicate(id: UUID) -> SavedMelodyEntry? {
        guard let source = entries.first(where: { $0.id == id }) else {
            return nil
        }
        let now = Date()
        let srcDoc = source.document
        let trimmedBase = srcDoc.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootBase: String = {
            if let range = trimmedBase.range(of: " 副本(?: \\d+)?$", options: .regularExpression) {
                return String(trimmedBase[..<range.lowerBound])
            }
            return trimmedBase.isEmpty ? "我的作品" : trimmedBase
        }()
        let firstCandidate = "\(rootBase) 副本"
        let existingTitles = Set(entries.map(\.document.title))
        var copyTitle = firstCandidate
        if existingTitles.contains(copyTitle) {
            var suffix = 2
            while existingTitles.contains("\(firstCandidate) \(suffix)") {
                suffix += 1
            }
            copyTitle = "\(firstCandidate) \(suffix)"
        }
        let copiedDoc = MelodyDocument(
            id: UUID(),
            title: copyTitle,
            subtitle: srcDoc.subtitle,
            rootMIDI: srcDoc.rootMIDI,
            scaleMode: srcDoc.scaleMode,
            harmonyProfile: srcDoc.harmonyProfile,
            grooveStrength: srcDoc.grooveStrength,
            estimatedBPM: srcDoc.estimatedBPM,
            notes: srcDoc.notes,
            isSpecimen: false,
            specimenCategory: srcDoc.specimenCategory,
            composerInsight: srcDoc.composerInsight,
            preferredTexture: srcDoc.preferredTexture,
            preferredVoice: srcDoc.preferredVoice,
            guidedMoments: srcDoc.guidedMoments
        )
        let copyEntry = SavedMelodyEntry(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            document: copiedDoc,
            chordPreset: source.chordPreset,
            chordOverrides: source.chordOverrides,
            accompanimentTexture: source.accompanimentTexture,
            moodSticker: source.moodSticker,
            summaryNote: source.summaryNote
        )
        entries.insert(copyEntry, at: 0)
        persist()
        return copyEntry
    }

    public func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 静默忽略写入失败，不阻塞主界面
        }
    }
}
