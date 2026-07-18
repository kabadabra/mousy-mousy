import CoreGraphics
import Foundation

/// Ring of timestamped positions; the cursor samples Mousy's trail ~0.35 s in the past.
public struct TrailBuffer: Sendable {
    private var samples: [(time: TimeInterval, point: CGPoint)] = []
    private let maxAge: TimeInterval

    public init(maxAge: TimeInterval = 2.0) { self.maxAge = maxAge }

    public mutating func append(time: TimeInterval, point: CGPoint) {
        samples.append((time, point))
        while let first = samples.first, time - first.time > maxAge {
            samples.removeFirst()
        }
    }

    /// Linearly interpolated point at `time`, clamped to the oldest/newest sample.
    public func sample(at time: TimeInterval) -> CGPoint? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if time <= first.time { return first.point }
        if time >= last.time { return last.point }
        for i in 1..<samples.count where samples[i].time >= time {
            let a = samples[i - 1], b = samples[i]
            let span = b.time - a.time
            let f = span > 0 ? (time - a.time) / span : 1
            return CGPoint(x: a.point.x + (b.point.x - a.point.x) * CGFloat(f),
                           y: a.point.y + (b.point.y - a.point.y) * CGFloat(f))
        }
        return last.point
    }
}
