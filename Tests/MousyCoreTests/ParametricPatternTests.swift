import Testing
import CoreGraphics
@testable import MousyCore

private let bounds = CGRect(x: 80, y: 80, width: 1760, height: 920)

/// Simulate a pattern at 120 fps; assert every point is inside bounds and
/// consecutive points are close (no teleports).
private func assertContinuous(_ pattern: inout some MousePattern,
                              seconds: Double, speed: Double, maxJump: CGFloat) {
    var prev = pattern.startPoint(in: bounds)
    let dt = 1.0 / 120.0
    for _ in 0..<Int(seconds * 120) {
        let p = pattern.step(dt: dt, bounds: bounds, speed: speed,
                             cursor: CGPoint(x: bounds.midX, y: bounds.midY))
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(p))
        #expect(Geometry.distance(prev, p) < maxJump)
        prev = p
    }
}

@Test func circleStaysInBoundsAndContinuous() {
    var p = CirclePattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}

@Test func circleStartsOnItsOwnPath() {
    var p = CirclePattern()
    let start = p.startPoint(in: bounds)
    let first = p.step(dt: 1.0 / 120.0, bounds: bounds, speed: 1.0, cursor: .zero)
    #expect(Geometry.distance(start, first) < 10)
}

@Test func starVisitsAllFiveVertices() {
    var p = StarPattern()
    let vertices = StarPattern.vertices(in: bounds)
    #expect(vertices.count == 5)
    var visited = Array(repeating: false, count: 5)
    let dt = 1.0 / 120.0
    for _ in 0..<Int(60.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: .zero)
        for (i, v) in vertices.enumerated() where Geometry.distance(pt, v) < 8 {
            visited[i] = true
        }
    }
    #expect(visited.allSatisfy { $0 })
}

@Test func starTraversesVerticesInStrokeOrder() {
    var p = StarPattern()
    let vertices = StarPattern.vertices(in: bounds)
    #expect(vertices.count == 5)
    // Record the cursor position at the moment of first arrival at each vertex
    // (the vertex array is used only to DETECT arrivals, never as the expected
    // order — that would be tautological, since step() walks that same array).
    var claimed = Array(repeating: false, count: 5)
    var arrivals: [CGPoint] = []
    let dt = 1.0 / 120.0
    for _ in 0..<Int(60.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: .zero)
        for (i, v) in vertices.enumerated()
        where !claimed[i] && Geometry.distance(pt, v) < 8 {
            claimed[i] = true
            arrivals.append(pt)
        }
    }
    #expect(arrivals.count == 5)

    // Independent geometric oracle: the vertices of a five-point star lie on a
    // circle, and a pentagram stroke advances 144 degrees around the center
    // between consecutive vertices, while a plain pentagon walk advances only
    // 72 degrees. Assert the angle of each consecutive first arrival about the
    // bounds center jumps by ~144 degrees (mod 360), starting at ~90 degrees
    // (point-up star). Detection radius 8 pt on r ~= 368 pt keeps angular noise
    // under ~1.3 degrees per arrival, so a 5-degree tolerance is comfortable.
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let angles = arrivals.map {
        Double(atan2($0.y - center.y, $0.x - center.x)) * 180 / .pi
    }
    /// Signed angular difference mapped into (-180, 180].
    func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }
    #expect(abs(angleDelta(angles[0], 90)) < 5)
    for k in 1..<5 {
        #expect(abs(angleDelta(angles[k] - angles[k - 1], 144)) < 5)
    }
}

@Test func starStaysInBoundsAndContinuous() {
    var p = StarPattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}

@Test func figureEightStaysInBoundsAndContinuous() {
    var p = FigureEightPattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}
