import SwiftUI

/// The whole colour vocabulary of the app. Colour is a scarce resource here:
/// the coral → amber gradient is only allowed on selection, progress and focus,
/// so it keeps its meaning the moment it appears.
enum Palette {
    static let background = Color(hex: 0x0B0C0E)
    static let elevated = Color(hex: 0x16181D)
    static let surface = Color(hex: 0x101216)

    static let coral = Color(hex: 0xFF6B4A)
    static let amber = Color(hex: 0xFFB020)
    static let ice = Color(hex: 0x4A9EFF)

    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.56)
    static let textTertiary = Color.white.opacity(0.34)

    static let hairline = Color.white.opacity(0.08)

    static let accentGradient = LinearGradient(
        colors: [coral, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hairlineGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.24),
            Color.white.opacity(0.05),
            Color.white.opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum Metrics {
    static let cardRadius: CGFloat = 20
    static let panelRadius: CGFloat = 24
    static let gutter: CGFloat = 10
    static let screenPadding: CGFloat = 16
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
