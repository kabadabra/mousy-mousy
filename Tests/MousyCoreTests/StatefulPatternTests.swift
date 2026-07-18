import Testing
import CoreGraphics
@testable import MousyCore

private let bounds = CGRect(x: 80, y: 80, width: 1760, height: 920)
private let dt = 1.0 / 120.0

@Test func scribbleStaysInBoundsAndIsDeterministic() {
    var a = ScribblePattern(seed: 7), b = ScribblePattern(seed: 7)
    var last = CGPoint.zero
    for _ in 0..<Int(60.0 * 120) {
        let pa = a.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
        let pb = b.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
        #expect(pa == pb)
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(pa))
        last = pa
    }
    var c = ScribblePattern(seed: 8)
    var cLast = CGPoint.zero
    for _ in 0..<Int(60.0 * 120) {
        cLast = c.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
    }
    #expect(last != cLast)   // different seeds diverge
}

@Test func scribbleIsContinuous() {
    var p = ScribblePattern(seed: 1)
    var prev = p.startPoint(in: bounds)
    for _ in 0..<Int(30.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
        #expect(Geometry.distance(prev, pt) < 25)
        prev = pt
    }
}

@Test func zoomiesDartsAwayFromCursor() {
    var p = ZoomiesPattern(seed: 3)
    // Warm up with the cursor far away.
    var pos = CGPoint.zero
    for _ in 0..<120 {
        pos = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: CGPoint(x: -5000, y: -5000))
    }
    // Park the cursor right next to Mousy: within dartDistance.
    let cursor = CGPoint(x: pos.x + 50, y: pos.y)
    let before = Geometry.distance(pos, cursor)
    #expect(before < ZoomiesPattern.dartDistance)
    var after = pos
    for _ in 0..<120 {   // one second of fleeing
        after = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: cursor)
    }
    #expect(Geometry.distance(after, cursor) > before + 100)   // it ran away
}

@Test func zoomiesStaysInBounds() {
    var p = ZoomiesPattern(seed: 9)
    var cursor = CGPoint(x: bounds.midX, y: bounds.midY)
    for _ in 0..<Int(60.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.8, cursor: cursor)
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(pt))
        cursor = pt   // worst case: cursor glued to Mousy, constant darting
    }
}

@Test func transitEasesBetweenPointsAndFinishes() {
    let from = CGPoint(x: 100, y: 100), to = CGPoint(x: 1000, y: 800)
    var t = TransitPattern(from: from, to: to)
    #expect(t.startPoint(in: bounds) == from)
    #expect(!t.isFinished)
    var prev = from
    var steps = 0
    while !t.isFinished && steps < 1000 {
        let p = t.step(dt: dt, bounds: bounds, speed: 1.0, cursor: .zero)
        #expect(Geometry.distance(prev, p) < 25)   // ≤900 pt/s at 120 fps + easing
        prev = p
        steps += 1
    }
    #expect(t.isFinished)
    #expect(Geometry.distance(prev, to) < 1)
    // Duration scales with distance, clamped to [0.4, 2.2].
    #expect(TransitPattern(from: .zero, to: CGPoint(x: 10, y: 0)).duration == 0.4)
    #expect(TransitPattern(from: .zero, to: CGPoint(x: 9000, y: 0)).duration == 2.2)
}

@Test func patternKindFactoryAndNames() {
    #expect(PatternKind.allCases.count == 5)
    #expect(PatternKind.figureEight.displayName == "Figure-8")
    for kind in PatternKind.allCases {
        var p = kind.makePattern(seed: 1)
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.0,
                        cursor: CGPoint(x: bounds.midX, y: bounds.midY))
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(pt))
    }
}
