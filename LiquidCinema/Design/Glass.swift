import SwiftUI

/// Liquid Glass, applied only to navigation and control chrome — never to
/// photo content (HIG). On iOS 26 it is the real system material; before that
/// it is a layered material with a specular rim, which reads as glass without
/// the cost of a per-frame refraction pass behind scrolling content.
struct GlassChrome<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
        } else {
            legacy(content)
        }
        #else
        legacy(content)
        #endif
    }

    @ViewBuilder
    private func legacy(_ content: Content) -> some View {
        content
            .background { shape.fill(.ultraThinMaterial) }
            .background { shape.fill(tint.opacity(0.16)) }
            .overlay { shape.stroke(Palette.hairlineGradient, lineWidth: 0.8) }
            .clipShape(shape)
    }
}

extension View {
    /// Chrome-only liquid glass. `tint` is a whisper of colour, not a fill.
    func glassChrome<S: Shape>(
        in shape: S,
        tint: Color = .clear,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassChrome(shape: shape, tint: tint, interactive: interactive))
    }
}

/// Several glass elements that must be able to sample each other belong in one
/// container, otherwise each one refracts its own little bubble.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
