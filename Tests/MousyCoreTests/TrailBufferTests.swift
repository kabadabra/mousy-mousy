import Testing
import CoreGraphics
@testable import MousyCore

@Test func seededRNGIsDeterministic() {
    var a = SeededRNG(seed: 42), b = SeededRNG(seed: 42)
    for _ in 0..<10 { #expect(a.next() == b.next()) }
    var c = SeededRNG(seed: 43)
    #expect(a.next() != c.next())
}

@Test func emptyBufferReturnsNil() {
    #expect(TrailBuffer().sample(at: 1.0) == nil)
}

@Test func sampleInterpolatesLinearly() {
    var t = TrailBuffer()
    t.append(time: 0, point: CGPoint(x: 0, y: 0))
    t.append(time: 1, point: CGPoint(x: 100, y: 50))
    #expect(t.sample(at: 0.5) == CGPoint(x: 50, y: 25))
}

@Test func sampleClampsToOldestAndNewest() {
    var t = TrailBuffer()
    t.append(time: 10, point: CGPoint(x: 1, y: 1))
    t.append(time: 11, point: CGPoint(x: 2, y: 2))
    #expect(t.sample(at: 5) == CGPoint(x: 1, y: 1))
    #expect(t.sample(at: 20) == CGPoint(x: 2, y: 2))
}

@Test func oldSamplesArePruned() {
    var t = TrailBuffer(maxAge: 1.0)
    t.append(time: 0, point: CGPoint(x: 0, y: 0))
    t.append(time: 5, point: CGPoint(x: 9, y: 9))
    #expect(t.sample(at: 0) == CGPoint(x: 9, y: 9))   // old sample gone, clamps to oldest kept
}
