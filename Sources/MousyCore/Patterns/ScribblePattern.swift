import CoreGraphics
import Foundation

/// Smooth wandering random walk: low-pass-filtered random steering.
public struct ScribblePattern: MousePattern {
    private var rng: SeededRNG
    private var position: CGPoint?
    private var heading: Double = 0
    private var turnRate: Double = 0

    public init(seed: UInt64 = 0xC0FFEE) { rng = SeededRNG(seed: seed) }

    public func startPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        var pos = position ?? startPoint(in: bounds)
        let jolt = Double.random(in: -6...6, using: &rng)
        turnRate += (jolt - turnRate) * min(1, dt * 2)
        heading += turnRate * dt
        let v = 230 * speed
        pos.x += CGFloat(cos(heading) * v * dt)
        pos.y += CGFloat(sin(heading) * v * dt)
        if !bounds.contains(pos) {
            heading = atan2(Double(bounds.midY - pos.y), Double(bounds.midX - pos.x))
            turnRate = 0
            pos.x = min(max(pos.x, bounds.minX), bounds.maxX)
            pos.y = min(max(pos.y, bounds.minY), bounds.maxY)
        }
        position = pos
        return pos
    }
}
