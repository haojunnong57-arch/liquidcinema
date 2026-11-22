import SwiftUI

/// A full-bleed metal backdrop. The content is forced to the screen size, and
/// one `colorEffect` pass adds a soft vignette plus fine grain. Used only
/// behind the lightbox photo — never on the photos themselves.
struct FilmBackdrop<Content: View>: View {
    var intensity: Double
    private let content: Content

    init(intensity: Double = 0.8, @ViewBuilder content: () -> Content) {
        self.intensity = intensity
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .colorEffect(
                    ShaderLibrary.filmVignette(
                        .float(intensity),
                        .float2(proxy.size.width, proxy.size.height)
                    )
                )
        }
    }
}
