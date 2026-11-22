import LiquidPhotos
import SwiftUI
import UIKit

/// Wraps the Metal stage in an Equatable shell. While the photo is settling —
/// a drag, a chrome fade, a hint spring — SwiftUI can skip `updateUIView`
/// entirely, so the stage is not woken for a frame that never changed.
struct StageSurface: View, Equatable {
    let images: [UIImage]
    let base: Int
    let selection: Int
    let style: LiquidPhotosStyle
    let onSelect: (Int) -> Void

    var body: some View {
        LiquidPhotos(
            images,
            selection: Binding(
                get: { max(0, min(selection, max(images.count - 1, 0))) },
                set: { onSelect($0) }
            ),
            isPlaying: .constant(false),
            style: style
        )
    }

    static func == (lhs: StageSurface, rhs: StageSurface) -> Bool {
        guard lhs.selection == rhs.selection,
              lhs.base == rhs.base,
              lhs.style == rhs.style,
              lhs.images.count == rhs.images.count else { return false }
        return lhs.images.first.map { ObjectIdentifier($0) } == rhs.images.first.map { ObjectIdentifier($0) }
            && lhs.images.last.map { ObjectIdentifier($0) } == rhs.images.last.map { ObjectIdentifier($0) }
    }
}

/// Same idea for the shelf: it only needs to redraw when its photos or its
/// selection actually change.
struct StripSurface: View, Equatable {
    let images: [UIImage]
    let selection: Int
    let size: CGFloat
    let onSelect: (Int) -> Void

    var body: some View {
        LiquidPhotoStrip(
            images,
            selection: Binding(
                get: { max(0, min(selection, max(images.count - 1, 0))) },
                set: { onSelect($0) }
            ),
            size: size
        )
    }

    static func == (lhs: StripSurface, rhs: StripSurface) -> Bool {
        guard lhs.selection == rhs.selection,
              lhs.size == rhs.size,
              lhs.images.count == rhs.images.count else { return false }
        return lhs.images.first.map { ObjectIdentifier($0) } == rhs.images.first.map { ObjectIdentifier($0) }
            && lhs.images.last.map { ObjectIdentifier($0) } == rhs.images.last.map { ObjectIdentifier($0) }
    }
}
