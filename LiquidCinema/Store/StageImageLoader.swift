import ImageIO
import UIKit

/// Full-bleed images for the lightbox stage. 1400 px long side is more than any
/// iPhone needs for a 1:1 fit, and it keeps a nine-photo window inside a sane
/// memory budget while LiquidPhotos holds its own rgba16 textures.
enum StageImageLoader {
    static func load(_ item: PhotoItem, paths: LibraryPaths, maxPixel: Int = 1400) async -> UIImage? {
        let url = paths.photoURL(for: item)
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: image))
            }
        }
    }
}
