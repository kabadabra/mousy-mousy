import CoreGraphics
import Foundation

/// Five-point star traversed as a continuous stroke (vertex order 0,2,4,1,3).
public struct StarPattern: MousePattern {
    private var progress: Double = 0       // distance traveled along the stroke
    public init() {}

    public static func vertices(in b: CGRect) -> [CGPoint] {
        let r = 0.4 * min(b.width, b.height)
        return [0, 2, 4, 1, 3].map { i in
            let a = Double.pi / 2 + Double(i) * 2 * .pi / 5   // point-up star
            return CGPoint(x: b.midX + r * CGFloat(cos(a)), y: b.midY + r * CGFloat(sin(a)))
        }
    }

    public func startPoint(in bounds: CGRect) -> CGPoint { Self.vertices(in: bounds)[0] }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        let vs = Self.vertices(in: bounds)
        let pts = vs + [vs[0]]
        let lens = zip(pts, pts.dropFirst()).map { Geometry.distance($0, $1) }
        let total = Double(lens.reduce(0, +))
        progress = (progress + dt * 260 * speed).truncatingRemainder(dividingBy: total)
        var remaining = progress
        for (i, len) in lens.enumerated() {
            if remaining <= Double(len) {
                let f = len > 0 ? CGFloat(remaining) / len : 0
                let a = pts[i], b = pts[i + 1]
                return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            }
            remaining -= Double(len)
        }
        return pts[0]
    }
}
