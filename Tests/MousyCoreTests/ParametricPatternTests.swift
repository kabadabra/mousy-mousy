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
    // Record the frame at which each vertex is first reached during one fresh
    // traversal. StarPattern.vertices(in:) returns them already in stroke order
    // (0,2,4,1,3), so first-arrival order must equal the array's own order —
    // a regression to plain pentagon order (0,1,2,3,4) would break this.
    var firstArrival = Array(repeating: Int.max, count: 5)
    let dt = 1.0 / 120.0
    for frame in 0..<Int(60.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: .zero)
        for (i, v) in vertices.enumerated()
        where firstArrival[i] == Int.max && Geometry.distance(pt, v) < 8 {
            firstArrival[i] = frame
        }
    }
    #expect(firstArrival.allSatisfy { $0 != Int.max })
    let arrivalOrder = (0..<5).sorted { firstArrival[$0] < firstArrival[$1] }
    #expect(arrivalOrder == Array(0..<5))
}

@Test func starStaysInBoundsAndContinuous() {
    var p = StarPattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}

@Test func figureEightStaysInBoundsAndContinuous() {
    var p = FigureEightPattern()
    assertContinuous(&p, seconds: 20, speed: 1.8, maxJump: 25)
}
