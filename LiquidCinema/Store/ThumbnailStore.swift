import ImageIO
import UIKit

/// Memory-resident thumbnails with a disk fallback. The disk copy lives in
/// Caches and may be purged by the system, so a miss regenerates it from the
/// full photo rather than showing a hole.
final class ThumbnailStore: @unchecked Sendable {
    static let shared = ThumbnailStore()

    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(
        label: "com.liquidcinema.thumbnails",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private var memoryWarning: NSObjectProtocol?

    init() {
        cache.countLimit = 320
        cache.totalCostLimit = 96 * 1024 * 1024
        memoryWarning = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [cache] _ in
            cache.removeAllObjects()
        }
    }

    deinit {
        if let memoryWarning {
            NotificationCenter.default.removeObserver(memoryWarning)
        }
    }

    func cached(_ id: UUID) -> UIImage? {
        cache.object(forKey: id.uuidString as NSString)
    }

    func image(for item: PhotoItem, paths: LibraryPaths) async -> UIImage? {
        let key = item.id.uuidString as NSString
        if let hit = cache.object(forKey: key) { return hit }

        let thumbURL = paths.thumbnailURL(for: item)
        let photoURL = paths.photoURL(for: item)

        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            queue.async {
                let image = ThumbnailStore.load(thumbURL: thumbURL, photoURL: photoURL)
                if let image {
                    self.cache.setObject(image, forKey: key, cost: ThumbnailStore.cost(of: image))
                }
                continuation.resume(returning: image)
            }
        }
    }

    private static func load(thumbURL: URL, photoURL: URL) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 720,
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let source = CGImageSourceCreateWithURL(thumbURL as CFURL, nil),
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: image)
        }
        guard let source = CGImageSourceCreateWithURL(photoURL as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private static func cost(of image: UIImage) -> Int {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        return Int(pixels * 4)
    }
}
