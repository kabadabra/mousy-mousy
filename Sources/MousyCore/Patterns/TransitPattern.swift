import CoreGraphics
import Foundation

/// Smooth-stepped scamper between a point and the next pattern's start.
/// Duration scales with distance (~900 pt/s), clamped to [0.4, 2.2] s — the
/// 2.2 s ceiling keeps even corner-to-corner scampers under ~23 pt/frame at
/// 60 fps (smoothstep peaks at 1.5× the mean speed).
public struct TransitPattern: MousePattern {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: TimeInterval
    private var elapsed: TimeInterval = 0

    public init(from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
        self.duration = min(2.2, max(0.4, Double(Geometry.distance(from, to)) / 900))
    }

    public var isFinished: Bool { elapsed >= duration }

    public func startPoint(in bounds: CGRect) -> CGPoint { from }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        elapsed = min(duration, elapsed + dt)
        let f = elapsed / duration
        let e = CGFloat(f * f * (3 - 2 * f))   // smoothstep ease-in-out
        return CGPoint(x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e)
    }
}
