import CoreGraphics
import Foundation

struct PhotoItem: Identifiable, Codable, Hashable, Sendable {
    struct Tint: Codable, Hashable, Sendable {
        var red: Double
        var green: Double
        var blue: Double

        static let neutral = Tint(red: 0.36, green: 0.37, blue: 0.40)
    }

    let id: UUID
    var fileName: String
    var pixelWidth: Int
    var pixelHeight: Int
    var addedAt: Date
    var capturedAt: Date?
    var isFavorite: Bool
    var byteSize: Int
    var tint: Tint

    var aspectRatio: CGFloat {
        let width = max(pixelWidth, 1)
        let height = max(pixelHeight, 1)
        return CGFloat(width) / CGFloat(height)
    }

    /// Newest shot first; imports that carry no EXIF date fall back to import time.
    var displayDate: Date { capturedAt ?? addedAt }

    init(
        id: UUID = UUID(),
        fileName: String,
        pixelWidth: Int,
        pixelHeight: Int,
        addedAt: Date = .now,
        capturedAt: Date? = nil,
        isFavorite: Bool = false,
        byteSize: Int = 0,
        tint: Tint = .neutral
    ) {
        self.id = id
        self.fileName = fileName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.addedAt = addedAt
        self.capturedAt = capturedAt
        self.isFavorite = isFavorite
        self.byteSize = byteSize
        self.tint = tint
    }

    // Tolerant decoding: a library written by an older build must still open.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        pixelWidth = try container.decode(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decode(Int.self, forKey: .pixelHeight)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        capturedAt = try container.decodeIfPresent(Date.self, forKey: .capturedAt)
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false
        byteSize = (try? container.decode(Int.self, forKey: .byteSize)) ?? 0
        tint = (try? container.decode(Tint.self, forKey: .tint)) ?? .neutral
    }
}
