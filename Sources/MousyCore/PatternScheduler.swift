import CoreGraphics
import Foundation

/// Owns the current pattern and, with multiple arenas, which display it runs
/// on. Switches on a 20–40 s cadence (auto-cycle always; fixed mode only when
/// roaming across >1 arena). Every switch is bridged by transit legs so Mousy
/// never teleports; cross-display legs route through the shared screen edge.
public struct PatternScheduler: Sendable {
    public enum Mode: Sendable, Equatable {
        case autoCycle
        case fixed(PatternKind)
    }

    private var rng: SeededRNG
    private let mode: Mode
    private var current: (any MousePattern)?
    private var transits: [TransitPattern] = []
    private var switchAt: TimeInterval = 0
    private var lastPoint: CGPoint?
    public private(set) var currentKind: PatternKind?
    public private(set) var currentArenaIndex: Int = 0

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

    public static func pickArena(count: Int, using rng: inout SeededRNG) -> Int {
        Int.random(in: 0..<count, using: &rng)
    }

    /// v1 sugar: a single rect used directly as the pattern bounds.
    public mutating func step(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> CGPoint {
        step(now: now, dt: dt, arenas: [Arena(screen: bounds, inset: bounds)],
             speed: speed, cursor: cursor)
    }

    public mutating func step(now: TimeInterval, dt: TimeInterval, arenas: [Arena],
                              speed: Double, cursor: CGPoint) -> CGPoint {
        let arena = arenas[min(currentArenaIndex, arenas.count - 1)]
        // Mid-transit: keep scampering through the queued legs.
        if var t = transits.first {
            let p = t.step(dt: dt, bounds: arena.inset, speed: speed, cursor: cursor)
            if t.isFinished { transits.removeFirst() } else { transits[0] = t }
            lastPoint = p
            return p
        }
        // Time to pick a pattern? First call, auto-cycle expiry, or roam hop.
        let switching = mode == .autoCycle || arenas.count > 1
        if current == nil || (switching && now >= switchAt) {
            let kind: PatternKind
            switch mode {
            case .fixed(let k): kind = k
            case .autoCycle: kind = Self.pickNext(excluding: currentKind, using: &rng)
            }
            let fromIndex = currentArenaIndex
            let toIndex = arenas.count > 1 ? Self.pickArena(count: arenas.count, using: &rng)
                                           : 0
            let toArena = arenas[toIndex]
            let pattern = kind.makePattern(seed: rng.next())
            currentKind = kind
            current = pattern
            currentArenaIndex = toIndex
            switchAt = now + Self.nextDuration(using: &rng)

            let from = lastPoint ?? cursor
            let start = pattern.startPoint(in: toArena.inset)
            if toIndex != fromIndex {
                let w = ArenaRouting.waypoint(from: arenas[fromIndex].screen,
                                              to: toArena.screen)
                transits = [TransitPattern(from: from, to: w),
                            TransitPattern(from: w, to: start)]
            } else {
                transits = [TransitPattern(from: from, to: start)]
            }
            var t = transits[0]
            let p = t.step(dt: dt, bounds: toArena.inset, speed: speed, cursor: cursor)
            if t.isFinished { transits.removeFirst() } else { transits[0] = t }
            lastPoint = p
            return p
        }
        // Normal pattern stepping in the current arena.
        var c = current!
        let p = c.step(dt: dt, bounds: arena.inset, speed: speed, cursor: cursor)
        current = c
        lastPoint = p
        return p
    }
}
