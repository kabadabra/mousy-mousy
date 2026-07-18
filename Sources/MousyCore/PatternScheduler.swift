import CoreGraphics
import Foundation

/// Owns the current pattern, switches on a 20–40 s cadence in auto-cycle mode,
/// and bridges every switch with a TransitPattern so Mousy never teleports.
public struct PatternScheduler: Sendable {
    public enum Mode: Sendable, Equatable {
        case autoCycle
        case fixed(PatternKind)
    }

    private var rng: SeededRNG
    private let mode: Mode
    private var current: (any MousePattern)?
    private var transit: TransitPattern?
    private var switchAt: TimeInterval = 0
    private var lastPoint: CGPoint?
    public private(set) var currentKind: PatternKind?

    public init(mode: Mode, seed: UInt64) {
        self.mode = mode
        self.rng = SeededRNG(seed: seed)
    }

    public static func pickNext(excluding: PatternKind?, using rng: inout SeededRNG) -> PatternKind {
        let candidates = PatternKind.allCases.filter { $0 != excluding }
        return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
    }

    public static func nextDuration(using rng: inout SeededRNG) -> TimeInterval {
        Double.random(in: 20...40, using: &rng)
    }

    public mutating func step(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> CGPoint {
        // Mid-transit: keep scampering.
        if var t = transit {
            let p = t.step(dt: dt, bounds: bounds, speed: speed, cursor: cursor)
            transit = t.isFinished ? nil : t
            lastPoint = p
            return p
        }
        // Time to pick a pattern? (first call, or auto-cycle expiry)
        if current == nil || (mode == .autoCycle && now >= switchAt) {
            let kind: PatternKind
            switch mode {
            case .fixed(let k): kind = k
            case .autoCycle: kind = Self.pickNext(excluding: currentKind, using: &rng)
            }
            let pattern = kind.makePattern(seed: rng.next())
            currentKind = kind
            current = pattern
            switchAt = now + Self.nextDuration(using: &rng)
            var t = TransitPattern(from: lastPoint ?? cursor,
                                   to: pattern.startPoint(in: bounds))
            let p = t.step(dt: dt, bounds: bounds, speed: speed, cursor: cursor)
            transit = t.isFinished ? nil : t
            lastPoint = p
            return p
        }
        // Normal pattern stepping.
        var c = current!
        let p = c.step(dt: dt, bounds: bounds, speed: speed, cursor: cursor)
        current = c
        lastPoint = p
        return p
    }
}
