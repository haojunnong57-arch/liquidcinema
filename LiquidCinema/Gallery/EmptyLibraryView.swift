import GlassGlow
import SwiftUI

struct EmptyLibraryView: View {
    let onImport: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 26) {
            emblem

            VStack(spacing: 9) {
                Text("把光留下来")
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Palette.textPrimary)
                Text("照片只存在这台设备上。\n没有账号，没有云端，没有追踪。")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundStyle(Palette.textSecondary)
            }

            Button(action: onImport) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("导入照片")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .contentShape(Capsule())
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.95))
            .glassChrome(in: Capsule(), tint: Palette.coral, interactive: true)
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emblem: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 54, weight: .ultraLight))
            .foregroundStyle(.white)
            .frame(width: 132, height: 132)
            .fixedSize()
            .modifier(EmblemGlow(frozen: reduceMotion))
    }
}

/// GlassGlow renders the halo in Metal; freezing the clock is the Reduce Motion
/// variant, so the emblem still has presence without any motion.
private struct EmblemGlow: ViewModifier {
    let frozen: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if frozen {
            content.glassGlow(.sunset, speed: 0.6, glow: 1.15, time: 2.4)
        } else {
            content.glassGlow(.sunset, speed: 0.62, glow: 1.15)
        }
    }
}
