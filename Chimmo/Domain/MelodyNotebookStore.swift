import Foundation

/// 一条保存在本地「脑放记录本」中的个人旋律卡片（100% 离线持久化）。
public struct SavedMelodyEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var document: MelodyDocument
    public var chordPreset: ChordProgressionPreset
    public var chordOverrides: [Int: DiatonicChord]
    public var summaryNote: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        summaryNote: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.document = document
        self.chordPreset = chordPreset
        self.chordOverrides = chordOverrides
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
        summaryNote: String,
        existingEntryID: UUID? = nil
    ) -> SavedMelodyEntry {
        var cleanDoc = document
        cleanDoc.isSpecimen = false
        if cleanDoc.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanDoc.title = "脑放旋律 #\(entries.count + 1)"
        }

        let now = Date()
        if let targetID = existingEntryID, let idx = entries.firstIndex(where: { $0.id == targetID }) {
            entries[idx].document = cleanDoc
            entries[idx].chordPreset = chordPreset
            entries[idx].chordOverrides = chordOverrides
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
                summaryNote: summaryNote
            )
            entries.insert(entry, at: 0)
            persist()
            return entry
        }
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
