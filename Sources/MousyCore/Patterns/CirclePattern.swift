import CoreGraphics
import Foundation

public struct CirclePattern: MousePattern {
    private var angle: Double = 0
    public init() {}

    public func startPoint(in bounds: CGRect) -> CGPoint { point(angle: 0, in: bounds) }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        angle += dt * 0.9 * speed          // radians/second at Normal
        return point(angle: angle, in: bounds)
    }

    private func point(angle: Double, in b: CGRect) -> CGPoint {
        let r = 0.35 * min(b.width, b.height)
        return CGPoint(x: b.midX + r * CGFloat(cos(angle)), y: b.midY + r * CGFloat(sin(angle)))
    }
}
