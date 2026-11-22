import Foundation

/// All paths are derived from the container, never hardcoded, and photos are
/// excluded from backup: a 20 GB local library must not become a 20 GB iCloud
/// backup the owner never asked for.
struct LibraryPaths: Sendable {
    let root: URL
    let thumbnails: URL

    init() {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        root = support.appendingPathComponent("LiquidCinema", isDirectory: true)

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        thumbnails = caches.appendingPathComponent("LiquidCinemaThumbnails", isDirectory: true)
    }

    var photosDirectory: URL { root.appendingPathComponent("photos", isDirectory: true) }
    var trashDirectory: URL { root.appendingPathComponent("trash", isDirectory: true) }
    var indexURL: URL { root.appendingPathComponent("library.json") }

    func photoURL(for item: PhotoItem) -> URL {
        photosDirectory.appendingPathComponent(item.fileName)
    }

    func thumbnailURL(for item: PhotoItem) -> URL {
        thumbnails.appendingPathComponent(item.id.uuidString + ".heic")
    }

    func trashURL(for item: PhotoItem) -> URL {
        trashDirectory.appendingPathComponent(item.fileName)
    }

    func prepare() throws {
        for directory in [photosDirectory, trashDirectory, thumbnails] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var photos = photosDirectory
        try? photos.setResourceValues(values)
    }
}
