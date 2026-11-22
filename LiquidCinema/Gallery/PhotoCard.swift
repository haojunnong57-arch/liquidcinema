import SwiftUI

struct PhotoCard: View {
    let item: PhotoItem
    let paths: LibraryPaths
    let onOpen: () -> Void
    let onToggleFavourite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onOpen()
        } label: {
            surface
        }
        .buttonStyle(PressScaleButtonStyle())
        .contextMenu {
            Button {
                onToggleFavourite()
            } label: {
                Label(
                    item.isFavorite ? "取消收藏" : "收藏",
                    systemImage: item.isFavorite ? "heart.slash" : "heart"
                )
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityLabel(item.isFavorite ? "照片，已收藏" : "照片")
        .accessibilityAddTraits(.isImage)
    }

    private var surface: some View {
        Color.clear
            .aspectRatio(item.aspectRatio, contentMode: .fit)
            .overlay {
                ThumbnailView(item: item, paths: paths)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            }
            .overlay(alignment: .topTrailing) {
                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 5, y: 1)
                        .padding(9)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}
