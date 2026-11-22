import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ImportError: LocalizedError {
    case unreadable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取这张图片"
        case .encodingFailed: return "无法写入图片文件"
        }
    }
}

/// Import is transactional per photo: decode → re-encode into a temp file in the
/// destination folder → atomic move → thumbnail → index entry. A crash at any
/// point leaves either a complete photo or no photo, never a half-written one.
struct PhotoImporter: Sendable {
    func ingest(_ data: Data, paths: LibraryPaths) async throws -> PhotoItem {
        try await Task.detached(priority: .userInitiated) {
            try PhotoImporter.process(data, paths: paths)
        }.value
    }

    static func process(_ data: Data, paths: LibraryPaths) throws -> PhotoItem {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImportError.unreadable
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let capturedAt = captureDate(from: properties)

        // Upright, 2000 px long side, orientation baked in. Every later stage
        // (grid, lightbox, Metal) can then ignore EXIF rotation entirely.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2000,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImportError.unreadable
        }

        let id = UUID()
        var fileName = id.uuidString + ".heic"
        var encodedURL = paths.photosDirectory.appendingPathComponent("tmp-\(id.uuidString).heic")

        if !encode(image, to: encodedURL, type: .heic, quality: 0.82) {
            try? FileManager.default.removeItem(at: encodedURL)
            encodedURL = paths.photosDirectory.appendingPathComponent("tmp-\(id.uuidString).jpg")
            guard encode(image, to: encodedURL, type: .jpeg, quality: 0.86) else {
                try? FileManager.default.removeItem(at: encodedURL)
                throw ImportError.encodingFailed
            }
            fileName = id.uuidString + ".jpg"
        }

        let finalURL = paths.photosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: finalURL)
        do {
            try FileManager.default.moveItem(at: encodedURL, to: finalURL)
        } catch {
            try? FileManager.default.removeItem(at: encodedURL)
            throw ImportError.encodingFailed
        }

        writeThumbnail(from: finalURL, to: paths.thumbnailURL(forID: id))

        let attributes = try? FileManager.default.attributesOfItem(atPath: finalURL.path)
        let byteSize = (attributes?[.size] as? NSNumber)?.intValue ?? 0

        return PhotoItem(
            id: id,
            fileName: fileName,
            pixelWidth: image.width,
            pixelHeight: image.height,
            addedAt: .now,
            capturedAt: capturedAt,
            isFavorite: false,
            byteSize: byteSize,
            tint: averageTint(of: image)
        )
    }

    private static func encode(_ image: CGImage, to url: URL, type: UTType, quality: Double) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else { return false }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    /// Thumbnails come from the encoded file through ImageIO, which is the
    /// fast path for a 640 px downsample. Because the thumbnail lives in
    /// Caches it can vanish at any time; ThumbnailStore regenerates it from
    /// the full photo when that happens.
    private static func writeThumbnail(from photoURL: URL, to thumbURL: URL) {
        guard let source = CGImageSourceCreateWithURL(photoURL as CFURL, nil) else { return }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 640,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
        _ = encode(thumb, to: thumbURL, type: .heic, quality: 0.72)
    }

    private static func averageTint(of image: CGImage) -> PhotoItem.Tint {
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = pixel.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return .neutral }
        return PhotoItem.Tint(
            red: Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue: Double(pixel[2]) / 255
        )
    }

    private static func captureDate(from properties: [CFString: Any]?) -> Date? {
        guard let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let string = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.date(from: string)
    }
}

extension LibraryPaths {
    func thumbnailURL(forID id: UUID) -> URL {
        thumbnails.appendingPathComponent(id.uuidString + ".heic")
    }
}
