import SwiftUI
import UIKit

/// A grid thumbnail. The card size is fixed by layout, so the stored 640 px
/// thumbnail is never asked to upscale past roughly 2× of what the screen
/// actually paints — the single biggest lever on scroll smoothness.
struct ThumbnailView: View {
    let item: PhotoItem
    let paths: LibraryPaths
    var maxPixel: Int = 720

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                placeholder
            } else {
                skeleton
            }
        }
        .task(id: item.id) {
            await load()
        }
    }

    private var skeleton: some View {
        Rectangle()
            .fill(Palette.elevated)
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }

    private var placeholder: some View {
        ZStack {
            Palette.elevated
            VStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 17, weight: .semibold))
                Text("无法读取")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Palette.textTertiary)
        }
    }

    private func load() async {
        if let cached = ThumbnailStore.shared.cached(item.id) {
            image = cached
            return
        }
        let loaded = await ThumbnailStore.shared.image(for: item, paths: paths)
        guard !Task.isCancelled else { return }
        if let loaded {
            withAnimation(.easeOut(duration: 0.18)) { image = loaded }
        } else {
            failed = true
        }
    }
}

/// Press feedback for anything tappable: a scale only, which the compositor
/// can run without touching layout.
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.965

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
