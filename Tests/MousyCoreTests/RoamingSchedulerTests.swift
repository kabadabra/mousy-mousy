import Testing
import Foundation
import CoreGraphics
@testable import MousyCore

// Two side-by-side displays with different heights → dead zone below the right
// screen's raised bottom edge. The scheduler must never route through it.
private let screenL = CGRect(x: 0, y: 0, width: 2560, height: 1440)
private let screenR = CGRect(x: 2560, y: 500, width: 1920, height: 900)
private let arenas = [Arena(screen: screenL), Arena(screen: screenR)]
private let dt = 1.0 / 60.0

@Test func pickArenaCoversAllIndices() {
    var rng = SeededRNG(seed: 4)
    var seen = Set<Int>()
    for _ in 0..<100 { seen.insert(PatternScheduler.pickArena(count: 2, using: &rng)) }
    #expect(seen == [0, 1])
}

@Test func autoCycleRoamsBothDisplaysContinuouslyAndSafely() {
    var s = PatternScheduler(mode: .autoCycle, seed: 21)
    var now: TimeInterval = 0
    var prev = CGPoint(x: 400, y: 400)
    var visited = Set<Int>()
    for _ in 0..<Int(600.0 * 60) {          // 10 simulated minutes
        let p = s.step(now: now, dt: dt, arenas: arenas, speed: 1.0, cursor: prev)
        #expect(Geometry.distance(prev, p) < 30)                       // no teleports
        let inL = screenL.insetBy(dx: -1, dy: -1).contains(p)
        let inR = screenR.insetBy(dx: -1, dy: -1).contains(p)
        #expect(inL || inR)                                            // never in a dead zone
        visited.insert(s.currentArenaIndex)
        prev = p
        now += dt
    }
    #expect(visited == [0, 1])              // actually roams both displays
}

@Test func fixedModeRoamsButKeepsTheKind() {
    var s = PatternScheduler(mode: .fixed(.circle), seed: 8)
    var now: TimeInterval = 0
    var prev = CGPoint(x: 400, y: 400)
    var visited = Set<Int>()
    for _ in 0..<Int(600.0 * 60) {
        prev = s.step(now: now, dt: dt, arenas: arenas, speed: 1.0, cursor: prev)
        #expect(s.currentKind == .circle)
        visited.insert(s.currentArenaIndex)
        now += dt
    }
    #expect(visited == [0, 1])
}

@Test func singleArenaFixedModeNeverSwitches() {
    // Regression guard: with one arena, fixed mode must behave exactly as v1
    // (no restarts — the circle phase advances without ever resetting).
    var s = PatternScheduler(mode: .fixed(.circle), seed: 8)
    var now: TimeInterval = 0
    var points: [CGPoint] = []
    for _ in 0..<Int(90.0 * 60) {
        points.append(s.step(now: now, dt: dt, arenas: [arenas[0]], speed: 1.0,
                             cursor: CGPoint(x: 400, y: 400)))
        now += dt
    }
    #expect(s.currentArenaIndex == 0)
    // A restart would revisit the circle's start point with a transit jump in
    // phase; continuity over the whole run is the cheap proxy:
    for i in 1..<points.count { #expect(Geometry.distance(points[i-1], points[i]) < 30) }
}

@Test func boundsSugarMatchesSingleArena() {
    var a = PatternScheduler(mode: .fixed(.star), seed: 3)
    var b = PatternScheduler(mode: .fixed(.star), seed: 3)
    let bounds = CGRect(x: 80, y: 80, width: 1760, height: 920)
    var now: TimeInterval = 0
    for _ in 0..<600 {
        let pa = a.step(now: now, dt: dt, bounds: bounds, speed: 1.0, cursor: .zero)
        let pb = b.step(now: now, dt: dt, arenas: [Arena(screen: bounds, inset: bounds)],
                        speed: 1.0, cursor: .zero)
        #expect(pa == pb)
        now += dt
    }
}

@Test func firstTransitRoutesFromCursorsOwnDisplay() {
    // Cursor starts on the SECOND display of a DOWN-offset pair: the right
    // screen's top edge is raised to y=900, so x>2560, y<900 is a dead zone.
    // Seed 0 lands the first pattern on display 0, so the opening scamper is a
    // cross-display transit — it must depart from the cursor's OWN display and
    // route through the shared edge. Anchored at display 0 instead (the pre-fix
    // bug), the straight leg to a display-0 start slices the dead-zone corner.
    let offL = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    let offR = CGRect(x: 2560, y: 900, width: 1920, height: 900)
    let offArenas = [Arena(screen: offL), Arena(screen: offR)]
    var s = PatternScheduler(mode: .autoCycle, seed: 0)
    var now: TimeInterval = 0
    var prev = CGPoint(x: 3200, y: 950)     // inside offR, the secondary display
    for i in 0..<Int(30.0 * 60) {
        let p = s.step(now: now, dt: dt, arenas: offArenas, speed: 1.0, cursor: prev)
        if i == 0 { #expect(s.currentArenaIndex == 0) }   // scenario: pattern 1 on display 0
        #expect(Geometry.distance(prev, p) < 30)
        let inL = offL.insetBy(dx: -1, dy: -1).contains(p)
        let inR = offR.insetBy(dx: -1, dy: -1).contains(p)
        #expect(inL || inR)
        prev = p
        now += dt
    }
}
