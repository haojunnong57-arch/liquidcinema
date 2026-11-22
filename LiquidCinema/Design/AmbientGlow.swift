import SwiftUI

/// Two radial glows breathing behind the gallery. Period 11 s, amplitude 18/14 pt,
/// and only `offset` changes, so the work stays on the render server instead of
/// re-laying out a blurred 800 pt layer every frame. Reduce Motion freezes it.
struct AmbientGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                orb(colors: [Palette.coral.opacity(0.10), Palette.coral.opacity(0)])
                    .offset(
                        x: -proxy.size.width * 0.30 + phase * 18,
                        y: -proxy.size.height * 0.10 - phase * 14
                    )

                orb(colors: [Palette.ice.opacity(0.08), Palette.ice.opacity(0)])
                    .offset(
                        x: proxy.size.width * 0.48 - phase * 16,
                        y: proxy.size.height * 0.58 + phase * 12
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onChange(of: reduceMotion) { _, _ in start() }
    }

    private func orb(colors: [Color]) -> some View {
        RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 380)
            .frame(width: 760, height: 760)
    }

    private func start() {
        phase = 0
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
            phase = 1
        }
    }
}
