import Testing
import Foundation
import CoreGraphics
@testable import MousyCore

@Test func engineRoamsArenasWithLaggingCursor() {
    let arenas = [Arena(screen: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
                  Arena(screen: CGRect(x: 2560, y: 0, width: 2560, height: 1440))]
    var e = EngineCore(mode: .autoCycle, seed: 5)
    var now: TimeInterval = 0
    let dt = 1.0 / 60.0
    var prevMousy: CGPoint? = nil
    var sawRightScreen = false
    for _ in 0..<Int(600.0 * 60) {
        now += dt
        let f = e.tick(now: now, dt: dt, arenas: arenas, speed: 1.0,
                       cursor: CGPoint(x: 100, y: 100))
        if let pm = prevMousy { #expect(Geometry.distance(pm, f.mousy) < 30) }
        if f.mousy.x > 2560 { sawRightScreen = true }
        prevMousy = f.mousy
    }
    #expect(sawRightScreen)
}
