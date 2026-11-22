import SwiftUI

@main
struct LiquidCinemaApp: App {
    @State private var library = PhotoLibrary()
    @State private var meter = FrameMeter()

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .environment(library)
                .environment(meter)
                .preferredColorScheme(.dark)
                .tint(Palette.coral)
        }
    }
}
