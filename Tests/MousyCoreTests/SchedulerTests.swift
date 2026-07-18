import Testing
import CoreGraphics
import Foundation
@testable import MousyCore

private let bounds = CGRect(x: 80, y: 80, width: 1760, height: 920)
private let dt = 1.0 / 60.0

@Test func pickNextNeverImmediatelyRepeats() {
    var rng = SeededRNG(seed: 5)
    var previous: PatternKind? = nil
    for _ in 0..<200 {
        let next = PatternScheduler.pickNext(excluding: previous, using: &rng)
        #expect(next != previous)
        previous = next
    }
}

@Test func durationsAreTwentyToFortySeconds() {
    var rng = SeededRNG(seed: 6)
    for _ in 0..<100 {
        let d = PatternScheduler.nextDuration(using: &rng)
        #expect(d >= 20 && d <= 40)
    }
}

@Test func autoCycleIsContinuousAcrossSwitches() {
    var s = PatternScheduler(mode: .autoCycle, seed: 11)
    var now: TimeInterval = 0
    var prev = CGPoint(x: 500, y: 500)   // simulated cursor start
    var kinds = Set<PatternKind>()
    for _ in 0..<Int(300.0 * 60) {       // 5 simulated minutes
        let p = s.step(now: now, dt: dt, bounds: bounds, speed: 1.0, cursor: prev)
        #expect(Geometry.distance(prev, p) < 30)   // no teleports, even at switches
        prev = p
        now += dt
        if let k = s.currentKind { kinds.insert(k) }
    }
    #expect(kinds.count >= 3)            // actually cycles through patterns
}

@Test func fixedModeKeepsOnePattern() {
    var s = PatternScheduler(mode: .fixed(.circle), seed: 2)
    var now: TimeInterval = 0
    for _ in 0..<Int(90.0 * 60) {        // well past any auto-cycle duration
        _ = s.step(now: now, dt: dt, bounds: bounds, speed: 1.0,
                   cursor: CGPoint(x: 500, y: 500))
        now += dt
    }
    #expect(s.currentKind == .circle)
}

@Test func firstStepTransitsFromCursor() {
    var s = PatternScheduler(mode: .fixed(.star), seed: 2)
    let cursor = CGPoint(x: 200, y: 200)
    let p = s.step(now: 0, dt: dt, bounds: bounds, speed: 1.0, cursor: cursor)
    #expect(Geometry.distance(cursor, p) < 30)   // starts from the cursor, not the star
}
