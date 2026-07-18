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

@Test func starStaysInBoundsAndContinuous() {
    var p = StarPattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}

@Test func figureEightStaysInBoundsAndContinuous() {
    var p = FigureEightPattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}
