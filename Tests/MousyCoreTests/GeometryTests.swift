import Testing
import CoreGraphics
@testable import MousyCore

@Test func cocoaToCGFlipsAboutPrimaryScreenHeight() {
    let p = Geometry.cgFromCocoa(CGPoint(x: 100, y: 100), primaryScreenHeight: 1080)
    #expect(p == CGPoint(x: 100, y: 980))
}

@Test func cocoaToCGOnSecondaryDisplayUsesPrimaryHeight() {
    // Secondary display left of primary, Cocoa global point can be negative in x.
    let p = Geometry.cgFromCocoa(CGPoint(x: -1820, y: 300), primaryScreenHeight: 1080)
    #expect(p == CGPoint(x: -1820, y: 780))
}

@Test func cocoaToViewLocalTopLeft() {
    // A view filling a secondary screen frame at (-1920, 200), 1920x1080 (Cocoa space).
    let frame = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
    let p = Geometry.viewFromCocoa(CGPoint(x: -1820, y: 300), screenFrame: frame)
    #expect(p == CGPoint(x: 100, y: 980))   // maxY(1280) - 300
}

@Test func distanceIsEuclidean() {
    #expect(Geometry.distance(CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)) == 5)
}
