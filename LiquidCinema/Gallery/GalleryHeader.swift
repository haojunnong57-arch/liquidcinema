import SwiftUI

struct GalleryHeader: View {
    let count: Int
    let favourites: Int
    @Binding var filter: LibraryFilter
    let onImport: () -> Void
    let onRevealMeter: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LiquidCinema")
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(Palette.textPrimary)
                        .onLongPressGesture(minimumDuration: 1.1, perform: onRevealMeter)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
                Button(action: onImport) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 46, height: 46)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.92))
                .glassChrome(in: Circle(), tint: Palette.coral, interactive: true)
                .accessibilityLabel("导入照片")
            }

            filterBar
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(alignment: .top) {
            LinearGradient(
                colors: [
                    Palette.background,
                    Palette.background.opacity(0.92),
                    Palette.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 168)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    private var subtitle: String {
        if count == 0 { return "本地 · 不联网" }
        if favourites > 0 { return "\(count) 张 · \(favourites) 张收藏" }
        return "\(count) 张 · 本地"
    }

    private var filterBar: some View {
        HStack(spacing: 2) {
            ForEach(LibraryFilter.allCases) { value in
                Button {
                    guard value != filter else { return }
                    Haptics.whisper()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        filter = value
                    }
                } label: {
                    Text(value.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(filter == value ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Palette.textSecondary))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 7)
                        .background {
                            if filter == value {
                                Capsule().fill(Color.white.opacity(0.07))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == value ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .glassChrome(in: Capsule())
    }
}
