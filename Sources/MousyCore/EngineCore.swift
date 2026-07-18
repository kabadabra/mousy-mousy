import CoreGraphics
import Foundation

/// One tick = one frame: advances Mousy along the scheduled pattern, records the
/// trail, and derives the cursor position by sampling the trail `cursorLag` ago.
public struct EngineCore {
    public struct Frame: Sendable {
        public let mousy: CGPoint       // Cocoa global
        public let cursor: CGPoint      // Cocoa global, trails mousy
        public let facingLeft: Bool
    }

    public let cursorLag: TimeInterval
    private var scheduler: PatternScheduler
    private var trail = TrailBuffer()
    private var lastMousyX: CGFloat?
    private var facingLeft = true       // 🐭 faces left natively

    public init(mode: PatternScheduler.Mode, seed: UInt64, cursorLag: TimeInterval = 0.35) {
        self.scheduler = PatternScheduler(mode: mode, seed: seed)
        self.cursorLag = cursorLag
    }

    public mutating func tick(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> Frame {
        let mousy = scheduler.step(now: now, dt: dt, bounds: bounds, speed: speed, cursor: cursor)
        trail.append(time: now, point: mousy)
        let target = trail.sample(at: now - cursorLag) ?? mousy
        if let lx = lastMousyX, abs(mousy.x - lx) > 0.5 { facingLeft = mousy.x < lx }
        lastMousyX = mousy.x
        return Frame(mousy: mousy, cursor: target, facingLeft: facingLeft)
    }
}
