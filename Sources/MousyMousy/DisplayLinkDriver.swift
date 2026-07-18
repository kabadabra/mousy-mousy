import AppKit
import QuartzCore

/// One CADisplayLink (vended by the overlay view, macOS 14+ API) drives both the
/// sprite and the cursor so the chase stays phase-locked. ProMotion-aware.
@MainActor
final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval?

    /// (now, dt) — `now` is the link's targetTimestamp.
    var onTick: ((TimeInterval, TimeInterval) -> Void)?

    func start(in view: NSView) {
        stop()
        lastTime = nil
        link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let dt = min(0.1, max(0, now - (lastTime ?? now)))
        lastTime = now
        if dt > 0 { onTick?(now, dt) }
    }
}
