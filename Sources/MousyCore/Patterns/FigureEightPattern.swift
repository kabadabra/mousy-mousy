import CoreGraphics
import Foundation

/// Horizontal figure-8 (Lissajous a=1, b=2).
public struct FigureEightPattern: MousePattern {
    private var t: Double = 0
    public init() {}

    public func startPoint(in bounds: CGRect) -> CGPoint { point(t: 0, in: bounds) }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        t += dt * 0.8 * speed
        return point(t: t, in: bounds)
    }

    private func point(t: Double, in b: CGRect) -> CGPoint {
        CGPoint(x: b.midX + 0.35 * b.width * CGFloat(sin(t)),
                y: b.midY + 0.30 * b.height * CGFloat(sin(2 * t)))
    }
}
