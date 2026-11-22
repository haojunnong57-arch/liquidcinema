import SwiftUI

/// Multi-property timeline for a single beat: a heart that punches in, floats up
/// and dissolves. `scale`, `opacity` and `rise` each need their own curve at
/// their own time, which a phase list cannot express — so this is a
/// KeyframeAnimator, not a chain of `.animation()` calls.
struct FavoriteBurst: View {
    let trigger: Int

    private struct Pose {
        var scale: Double = 0.45
        var opacity: Double = 0
        var rise: Double = 0
        var blur: Double = 6
    }

    var body: some View {
        KeyframeAnimator(initialValue: Pose(), trigger: trigger) { pose in
            Image(systemName: "heart.fill")
                .font(.system(size: 86, weight: .bold))
                .foregroundStyle(Palette.accentGradient)
                .shadow(color: Palette.coral.opacity(0.55), radius: 26)
                .scaleEffect(pose.scale)
                .opacity(pose.opacity)
                .offset(y: pose.rise)
                .blur(radius: pose.blur)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.86, duration: 0.09)
                SpringKeyframe(1.16, duration: 0.2, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.2, spring: .snappy)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(0, duration: 0.05)
                CubicKeyframe(1, duration: 0.08)
                CubicKeyframe(1, duration: 0.24)
                CubicKeyframe(0, duration: 0.3)
            }
            KeyframeTrack(\.rise) {
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(-46, duration: 0.6)
            }
            KeyframeTrack(\.blur) {
                CubicKeyframe(6, duration: 0.06)
                CubicKeyframe(0, duration: 0.14)
                CubicKeyframe(2.5, duration: 0.4)
            }
        }
        .allowsHitTesting(false)
    }
}
