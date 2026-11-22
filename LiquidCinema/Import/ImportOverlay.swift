import SwiftUI

struct ImportOverlay: View {
    let progress: ImportProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ring
                VStack(spacing: 4) {
                    Text("正在导入")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(progress.completed) / \(progress.total)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 26)
            .glassChrome(
                in: RoundedRectangle(cornerRadius: Metrics.panelRadius, style: .continuous),
                tint: Palette.coral
            )
        }
        .transition(.opacity)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(progress.fraction, 0.004))
                .stroke(
                    Palette.accentGradient,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: progress.fraction)
            Text("\(Int((progress.fraction * 100).rounded()))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(width: 66, height: 66)
    }
}
