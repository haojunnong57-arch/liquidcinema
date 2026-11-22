import Foundation
import Observation
import SwiftUI

struct ImportProgress: Equatable {
    var total: Int
    var completed: Int
    var failed: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(completed) / Double(total))
    }
}

struct UndoRecord: Identifiable, Equatable {
    let id: UUID
    let item: PhotoItem
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case favourites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .favourites: return "收藏"
        }
    }
}

/// The single source of truth. Metadata lives in an atomically-written JSON
/// index (a 1000-photo library parses in a few milliseconds, which is what makes
/// the cold-start budget reachable), pixels live as files on disk.
@MainActor
@Observable
final class PhotoLibrary {
    private(set) var items: [PhotoItem] = []
    private(set) var progress: ImportProgress?
    private(set) var undoRecord: UndoRecord?
    private(set) var notice: String?

    var filter: LibraryFilter = .all

    let paths = LibraryPaths()

    private let importer = PhotoImporter()
    private var saveWork: Task<Void, Never>?
    private var trash: [UUID: TrashEntry] = [:]
    private var purgeWork: [UUID: Task<Void, Never>] = [:]

    private struct TrashEntry {
        let item: PhotoItem
        let index: Int
    }

    init() {
        do {
            try paths.prepare()
        } catch {
            notice = "无法创建本地存储目录"
        }
        loadIndex()
        emptyTrash()
    }

    // MARK: - Derived

    var visibleItems: [PhotoItem] {
        filter == .all ? items : items.filter(\.isFavorite)
    }

    var favouriteCount: Int {
        items.reduce(0) { $0 + ($1.isFavorite ? 1 : 0) }
    }

    var isImporting: Bool { progress != nil }

    var storageSummary: String {
        let total = items.reduce(0) { $0 + $1.byteSize }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(total))
    }

    // MARK: - Import

    func beginImport(total: Int) {
        progress = ImportProgress(total: max(total, 1), completed: 0, failed: 0)
        Haptics.prepareAll()
    }

    func importOne(_ data: Data) async {
        guard progress != nil else { return }
        do {
            let item = try await importer.ingest(data, paths: paths)
            items.insert(item, at: 0)
            progress?.completed += 1
        } catch {
            progress?.completed += 1
            progress?.failed += 1
        }
    }

    func markImportFailure() {
        progress?.completed += 1
        progress?.failed += 1
    }

    func finishImport() {
        sortItems()
        writeIndex()
        let failed = progress?.failed ?? 0
        progress = nil
        if failed == 0 {
            Haptics.success()
        } else {
            notice = "\(failed) 张照片导入失败"
            Haptics.whisper()
        }
    }

    // MARK: - Mutations

    func toggleFavourite(_ item: PhotoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isFavorite.toggle()
        scheduleSave()
    }

    func setFavourite(_ id: UUID, to value: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].isFavorite != value else { return }
        items[index].isFavorite = value
        scheduleSave()
    }

    func clearNotice() {
        notice = nil
    }

    /// Delete is a move, not an unlink: the photo sits in Trash for five seconds
    /// so Undo is a rename rather than a restore from nowhere.
    func delete(_ item: PhotoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let source = paths.photoURL(for: item)
        let destination = paths.trashURL(for: item)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            notice = "无法删除：\(error.localizedDescription)"
            return
        }

        items.remove(at: index)
        trash[item.id] = TrashEntry(item: item, index: index)
        undoRecord = UndoRecord(id: UUID(), item: item)
        writeIndex()
        schedulePurge(for: item.id)
        Haptics.peak()
    }

    func undoDelete() {
        guard let record = undoRecord, let entry = trash[record.item.id] else { return }
        purgeWork[record.item.id]?.cancel()
        purgeWork[record.item.id] = nil

        do {
            try FileManager.default.moveItem(
                at: paths.trashURL(for: entry.item),
                to: paths.photoURL(for: entry.item)
            )
        } catch {
            notice = "撤销失败，照片仍在最近删除"
        }

        let index = min(entry.index, items.count)
        items.insert(entry.item, at: index)
        trash[record.item.id] = nil
        undoRecord = nil
        writeIndex()
        Haptics.whisper()
    }

    // MARK: - Persistence

    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: paths.indexURL.path) else { return }
        do {
            let data = try Data(contentsOf: paths.indexURL)
            let decoded = try JSONDecoder().decode([PhotoItem].self, from: data)
            // A photo whose file vanished (restore from a partial backup, a bug)
            // must not leave a permanent grey tile in the grid.
            items = decoded.filter {
                FileManager.default.fileExists(atPath: paths.photoURL(for: $0).path)
            }
            sortItems()
        } catch {
            let backup = paths.indexURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: paths.indexURL, to: backup)
            items = []
            notice = "索引损坏，已备份并重新开始"
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        saveWork = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.writeIndex()
        }
    }

    func writeIndex() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: paths.indexURL, options: [.atomic])
        } catch {
            notice = "无法保存索引"
        }
    }

    private func sortItems() {
        items.sort { lhs, rhs in
            if lhs.displayDate == rhs.displayDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.displayDate > rhs.displayDate
        }
    }

    // MARK: - Trash

    private func schedulePurge(for id: UUID) {
        purgeWork[id]?.cancel()
        purgeWork[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_400_000_000)
            guard !Task.isCancelled else { return }
            self?.purge(id)
        }
    }

    private func purge(_ id: UUID) {
        guard let entry = trash[id] else { return }
        try? FileManager.default.removeItem(at: paths.trashURL(for: entry.item))
        try? FileManager.default.removeItem(at: paths.thumbnailURL(for: entry.item))
        trash[id] = nil
        purgeWork[id] = nil
        if undoRecord?.item.id == id { undoRecord = nil }
    }

    /// Anything still in Trash at launch belongs to a session that ended.
    private func emptyTrash() {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: paths.trashDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }
}
