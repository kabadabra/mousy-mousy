import CoreGraphics
import Foundation

/// Free-roam wander; darts away when the cursor closes in. Never gets caught.
public struct ZoomiesPattern: MousePattern {
    public static let dartDistance: CGFloat = 120

    private var rng: SeededRNG
    private var position: CGPoint?
    private var heading: Double = 0
    private var turnRate: Double = 0
    private var dartBoost: Double = 0     // extra speed multiplier, decays

    public init(seed: UInt64 = 0x5EED) { rng = SeededRNG(seed: seed) }

    public func startPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        var pos = position ?? startPoint(in: bounds)
        if Geometry.distance(pos, cursor) < Self.dartDistance {
            let away = atan2(Double(pos.y - cursor.y), Double(pos.x - cursor.x))
            heading = away + Double.random(in: -0.8...0.8, using: &rng)
            dartBoost = 2.2
            turnRate = 0
        }
        let jolt = Double.random(in: -5...5, using: &rng)
        turnRate += (jolt - turnRate) * min(1, dt * 2)
        heading += turnRate * dt * (dartBoost > 0.1 ? 0.2 : 1)   // darts fly straight
        dartBoost = max(0, dartBoost - dt * 1.8)
        let v = 240 * speed * (1 + dartBoost)
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
