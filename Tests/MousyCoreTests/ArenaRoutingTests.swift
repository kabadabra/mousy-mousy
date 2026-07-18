import Testing
import CoreGraphics
@testable import MousyCore

@Test func arenaInsetsByMargin() {
    let a = Arena(screen: CGRect(x: 0, y: 0, width: 1000, height: 800))
    #expect(a.inset == CGRect(x: 80, y: 80, width: 840, height: 640))
}

@Test func sideBySideSharedEdgeWaypoint() {
    let left = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    let right = CGRect(x: 2560, y: 0, width: 2560, height: 1440)
    let w = ArenaRouting.waypoint(from: left, to: right)
    #expect(w == CGPoint(x: 2560, y: 720))
    #expect(ArenaRouting.waypoint(from: right, to: left) == w)   // symmetric
}

@Test func offsetHeightsUseOverlapMidpoint() {
    // Right screen shorter and raised: shared edge overlap is y 500...1400.
    let left = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    let right = CGRect(x: 2560, y: 500, width: 1920, height: 900)
    let w = ArenaRouting.waypoint(from: left, to: right)
    #expect(w == CGPoint(x: 2560, y: 950))
}

@Test func stackedScreensShareHorizontalEdge() {
    let bottom = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    let top = CGRect(x: 300, y: 1440, width: 1920, height: 1080)
    let w = ArenaRouting.waypoint(from: bottom, to: top)
    // x overlap is 300...2220 → mid 1260, y at the shared edge 1440.
    #expect(w == CGPoint(x: 1260, y: 1440))
}

@Test func cornerTouchFallsBackToClosestPointMidpoint() {
    // Diagonal corner contact only: no shared edge segment.
    let a = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let b = CGRect(x: 1000, y: 1000, width: 1000, height: 1000)
    let w = ArenaRouting.waypoint(from: a, to: b)
    #expect(w == CGPoint(x: 1000, y: 1000))
}

@Test func waypointLegsStayInsideTheTwoScreens() {
    // Convexity guarantee: interior point → edge waypoint stays in-rect.
    let left = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    let right = CGRect(x: 2560, y: 500, width: 1920, height: 900)
    let w = ArenaRouting.waypoint(from: left, to: right)
    let pA = CGPoint(x: 400, y: 200)      // inside left
    let pB = CGPoint(x: 4000, y: 1200)    // inside right
    for t in stride(from: 0.0, through: 1.0, by: 0.05) {
        let leg1 = CGPoint(x: pA.x + (w.x - pA.x) * t, y: pA.y + (w.y - pA.y) * t)
        let leg2 = CGPoint(x: w.x + (pB.x - w.x) * t, y: w.y + (pB.y - w.y) * t)
        #expect(left.insetBy(dx: -1, dy: -1).contains(leg1))
        #expect(right.insetBy(dx: -1, dy: -1).contains(leg2))
    }
}
