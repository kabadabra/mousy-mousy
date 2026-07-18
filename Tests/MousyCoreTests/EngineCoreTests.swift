import Testing
import CoreGraphics
import Foundation
@testable import MousyCore

private let bounds = CGRect(x: 80, y: 80, width: 1760, height: 920)
private let dt = 1.0 / 60.0

@Test func cursorTrailsMousyByLag() {
    var e = EngineCore(mode: .fixed(.circle), seed: 1)
    var now: TimeInterval = 0
    var history: [(t: TimeInterval, p: CGPoint)] = []
    var lastFrame: EngineCore.Frame? = nil
    for _ in 0..<Int(5.0 * 60) {
        now += dt
        let f = e.tick(now: now, dt: dt, bounds: bounds, speed: 1.0,
                       cursor: f0(lastFrame))
        history.append((now, f.mousy))
        lastFrame = f
    }
    // After warm-up, the cursor should sit where Mousy was `cursorLag` ago.
    let f = lastFrame!
    let target = history.last { $0.t <= now - e.cursorLag }!.p
    #expect(Geometry.distance(f.cursor, target) < 15)
    // And visibly behind Mousy (circle moves ~0.9 rad/s; lag ≈ 0.3 rad apart).
    #expect(Geometry.distance(f.cursor, f.mousy) > 20)
}

private func f0(_ f: EngineCore.Frame?) -> CGPoint {
    f?.cursor ?? CGPoint(x: bounds.midX, y: bounds.midY)
}

@Test func facingFollowsHorizontalTravel() {
    var e = EngineCore(mode: .fixed(.circle), seed: 1)
    var now: TimeInterval = 0
    var sawLeft = false, sawRight = false
    for _ in 0..<Int(10.0 * 60) {   // > one full circle revolution
        now += dt
        let f = e.tick(now: now, dt: dt, bounds: bounds, speed: 1.0,
                       cursor: CGPoint(x: bounds.midX, y: bounds.midY))
        if f.facingLeft { sawLeft = true } else { sawRight = true }
    }
    #expect(sawLeft && sawRight)
}
