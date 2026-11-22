import SwiftUI
import UIKit

/// A display-link based FPS readout so "120 Hz" is something the owner can
/// verify on device instead of something a document claims. Long-press the
/// wordmark to show it; it stops the link when hidden.
@MainActor
@Observable
final class FrameMeter {
    private(set) var fps: Double = 0
    private(set) var floor: Double = 0

    private var link: CADisplayLink?
    private var proxy: DisplayLinkProxy?
    private var lastTime: CFTimeInterval = 0
    private var accumulated: Double = 0
    private var frames: Int = 0

    var isRunning: Bool { link != nil }

    func start() {
        stop()
        let target = DisplayLinkProxy()
        target.handler = { [weak self] link in
            self?.tick(link)
        }
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkProxy.fire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        proxy = target
        self.link = link
        lastTime = CACurrentMediaTime()
        accumulated = 0
        frames = 0
        fps = 0
        floor = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
        proxy = nil
        fps = 0
        floor = 0
    }

    private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let delta = now - lastTime
        lastTime = now
        guard delta > 0, delta < 1 else { return }
        accumulated += delta
        frames += 1
        guard accumulated >= 0.5 else { return }
        let measured = Double(frames) / accumulated
        fps = measured
        floor = floor == 0 ? measured : min(floor, measured)
        accumulated = 0
        frames = 0
    }
}

@MainActor
private final class DisplayLinkProxy: NSObject {
    var handler: ((CADisplayLink) -> Void)?

    @objc func fire(_ link: CADisplayLink) {
        handler?(link)
    }
}

struct FrameHUD: View {
    let meter: FrameMeter

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicator)
                .frame(width: 6, height: 6)
            Text("\(Int(meter.fps.rounded())) fps")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text("min \(Int(meter.floor.rounded()))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
        }
        .foregroundStyle(Palette.textPrimary)
        .monospacedDigit()
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .glassChrome(in: Capsule())
        .allowsHitTesting(false)
    }

    private var indicator: Color {
        if meter.fps >= 100 { return Color(hex: 0x38D39F) }
        if meter.fps >= 55 { return Palette.amber }
        return Palette.coral
    }
}
