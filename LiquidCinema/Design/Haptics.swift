import SwiftUI
import UIKit

/// Haptics fire at the visual peak, never at the start of an animation:
/// the moment the lightbox lands full-bleed, the moment a page settles,
/// the moment a dismissal is committed, the rebound of a favourite pulse.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() {
        light.impactOccurred(intensity: 0.65)
        light.prepare()
    }

    static func peak() {
        medium.impactOccurred(intensity: 0.9)
        medium.prepare()
    }

    static func whisper() {
        soft.impactOccurred(intensity: 0.5)
        soft.prepare()
    }

    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func prepareAll() {
        light.prepare()
        medium.prepare()
        soft.prepare()
    }
}
