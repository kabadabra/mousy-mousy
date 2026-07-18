# Mousy Mousy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implementation subagents run on the **Opus** model per user request.

**Goal:** A macOS menu bar app where a mouse critter (🐭) leads the cursor through patterns to keep the Mac awake and the user "active", with a Liquid Glass ESC overlay.

**Architecture:** SwiftPM package, two targets: `MousyCore` (pure, testable logic — geometry, patterns, scheduler, engine) and `MousyMousy` (executable — SwiftUI `MenuBarExtra`, AppKit overlay panels, CGEvent posting, IOKit power assertions). One `CADisplayLink` clock drives both the sprite and the cursor. Hand-assembled `.app` bundle signed with a stable self-signed cert.

**Tech Stack:** Swift 6.3 (Command Line Tools only, NO Xcode), SwiftUI + AppKit, CoreGraphics CGEvent, IOKit power management, ServiceManagement, Swift Testing (`import Testing`) via `swift test`.

**Spec:** `docs/superpowers/specs/2026-07-18-mousy-mousy-design.md` — read it before starting any task.

## Global Constraints

- Repo root: `~/app-dev/mousy-mousy`. All paths below are relative to it.
- macOS 26 only: `platforms: [.macOS(.v26)]`. No availability fallbacks.
- No third-party dependencies. No Xcode/xcodebuild — `swift build` / `swift test` only.
- Bundle ID `com.chris.mousymousy` — never change it. App name "Mousy Mousy", executable `MousyMousy`.
- Sign ONLY with the `MousyMousy Dev` cert (Task 12). Never ad-hoc (`-s -`): ad-hoc breaks the TCC Accessibility grant on every rebuild and breaks SMAppService.
- Never launch the bare binary — always via `open` on the `.app` bundle (TCC attribution).
- Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `build:`). NEVER reference Claude as co-author. Never `git push`.
- TDD for everything in `MousyCore`. App-target tasks are build-verified + manually smoke-tested (no display, no unit test).
- Cursor/pattern math is in Cocoa global coordinates (bottom-left origin) everywhere; the ONLY top-left flip is inside `CursorSynthesizer` (via `Geometry.cgFromCocoa`) and `Geometry.viewFromCocoa` for SwiftUI.

---

### Task 1: Project scaffold

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/MousyCore/Placeholder.swift`, `Sources/MousyMousy/main.swift`, `Tests/MousyCoreTests/SmokeTests.swift`

**Interfaces:**
- Produces: package layout every later task builds on. Library module `MousyCore`, executable module `MousyMousy`, test module `MousyCoreTests`.

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MousyMousy",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "MousyCore"),
        .executableTarget(name: "MousyMousy", dependencies: ["MousyCore"]),
        .testTarget(name: "MousyCoreTests", dependencies: ["MousyCore"]),
    ]
)
```

- [ ] **Step 2: Write .gitignore**

```
.build/
dist/
.DS_Store
*.p12
*.key
*.crt
.superpowers/
```

- [ ] **Step 3: Write stub sources**

`Sources/MousyCore/Placeholder.swift` (deleted in Task 2):

```swift
public enum MousyCore { public static let version = "0.1.0" }
```

`Sources/MousyMousy/main.swift` (replaced by the SwiftUI App in Task 11):

```swift
import MousyCore
print("Mousy Mousy \(MousyCore.version)")
```

`Tests/MousyCoreTests/SmokeTests.swift` (deleted in Task 2):

```swift
import Testing
@testable import MousyCore

@Test func packageBuilds() {
    #expect(MousyCore.version == "0.1.0")
}
```

- [ ] **Step 4: Verify build and tests**

Run: `swift build && swift test`
Expected: `Build complete!` and `Test run with 1 test passed`

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: scaffold SwiftPM package with core, app, and test targets"
```

---

### Task 2: Geometry and deviation detection

**Files:**
- Create: `Sources/MousyCore/Geometry.swift`, `Sources/MousyCore/Deviation.swift`, `Tests/MousyCoreTests/GeometryTests.swift`
- Delete: `Sources/MousyCore/Placeholder.swift`, `Tests/MousyCoreTests/SmokeTests.swift`

**Interfaces:**
- Produces:
  - `Geometry.cgFromCocoa(_ p: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint`
  - `Geometry.viewFromCocoa(_ p: CGPoint, screenFrame: CGRect) -> CGPoint`
  - `Geometry.distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat`
  - `Deviation.threshold: CGFloat` (== 15)
  - `Deviation.humanMoved(expected: CGPoint, actual: CGPoint, threshold: CGFloat) -> Bool`

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/GeometryTests.swift`:

```swift
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

@Test func deviationTriggersOnlyBeyondThreshold() {
    let a = CGPoint(x: 500, y: 500)
    #expect(!Deviation.humanMoved(expected: a, actual: CGPoint(x: 510, y: 500)))
    #expect(Deviation.humanMoved(expected: a, actual: CGPoint(x: 516, y: 500)))
    #expect(Deviation.threshold == 15)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'Geometry' in scope`

- [ ] **Step 3: Implement**

Delete `Sources/MousyCore/Placeholder.swift` and `Tests/MousyCoreTests/SmokeTests.swift`.

`Sources/MousyCore/Geometry.swift`:

```swift
import CoreGraphics
import Foundation

public enum Geometry {
    /// Cocoa global (bottom-left origin) → CG global (top-left origin).
    /// Flip is about the PRIMARY screen's height, never the current screen's.
    public static func cgFromCocoa(_ p: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: p.x, y: primaryScreenHeight - p.y)
    }

    /// Cocoa global point → local point for a view exactly filling `screenFrame`
    /// (SwiftUI/AppKit-flipped top-left origin).
    public static func viewFromCocoa(_ p: CGPoint, screenFrame: CGRect) -> CGPoint {
        CGPoint(x: p.x - screenFrame.minX, y: screenFrame.maxY - p.y)
    }

    public static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
```

`Sources/MousyCore/Deviation.swift`:

```swift
import CoreGraphics

/// Detects that the human moved the physical mouse while patterns were running.
public enum Deviation {
    public static let threshold: CGFloat = 15

    public static func humanMoved(expected: CGPoint, actual: CGPoint,
                                  threshold: CGFloat = Deviation.threshold) -> Bool {
        Geometry.distance(expected, actual) > threshold
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add coordinate conversion and deviation detection"
```

---

### Task 3: Seeded RNG and trail buffer

**Files:**
- Create: `Sources/MousyCore/SeededRNG.swift`, `Sources/MousyCore/TrailBuffer.swift`, `Tests/MousyCoreTests/TrailBufferTests.swift`

**Interfaces:**
- Produces:
  - `struct SeededRNG: RandomNumberGenerator, Sendable` with `init(seed: UInt64)`
  - `struct TrailBuffer: Sendable` with `init(maxAge: TimeInterval = 2.0)`, `mutating func append(time: TimeInterval, point: CGPoint)`, `func sample(at time: TimeInterval) -> CGPoint?`

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/TrailBufferTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'SeededRNG' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/SeededRNG.swift`:

```swift
/// SplitMix64 — deterministic RNG so pattern behavior is reproducible in tests.
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

`Sources/MousyCore/TrailBuffer.swift`:

```swift
import CoreGraphics
import Foundation

/// Ring of timestamped positions; the cursor samples Mousy's trail ~0.35 s in the past.
public struct TrailBuffer: Sendable {
    private var samples: [(time: TimeInterval, point: CGPoint)] = []
    private let maxAge: TimeInterval

    public init(maxAge: TimeInterval = 2.0) { self.maxAge = maxAge }

    public mutating func append(time: TimeInterval, point: CGPoint) {
        samples.append((time, point))
        while let first = samples.first, time - first.time > maxAge {
            samples.removeFirst()
        }
    }

    /// Linearly interpolated point at `time`, clamped to the oldest/newest sample.
    public func sample(at time: TimeInterval) -> CGPoint? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if time <= first.time { return first.point }
        if time >= last.time { return last.point }
        for i in 1..<samples.count where samples[i].time >= time {
            let a = samples[i - 1], b = samples[i]
            let span = b.time - a.time
            let f = span > 0 ? (time - a.time) / span : 1
            return CGPoint(x: a.point.x + (b.point.x - a.point.x) * CGFloat(f),
                           y: a.point.y + (b.point.y - a.point.y) * CGFloat(f))
        }
        return last.point
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add seeded RNG and interpolating trail buffer"
```

---

### Task 4: Pattern protocol + parametric patterns (Circle, Star, Figure-8)

**Files:**
- Create: `Sources/MousyCore/Patterns/MousePattern.swift`, `Sources/MousyCore/Patterns/CirclePattern.swift`, `Sources/MousyCore/Patterns/StarPattern.swift`, `Sources/MousyCore/Patterns/FigureEightPattern.swift`, `Tests/MousyCoreTests/ParametricPatternTests.swift`

**Interfaces:**
- Consumes: `Geometry.distance`
- Produces:
  - `protocol MousePattern: Sendable { func startPoint(in bounds: CGRect) -> CGPoint; mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint }`
  - `struct CirclePattern: MousePattern` (`init()`)
  - `struct StarPattern: MousePattern` (`init()`)
  - `struct FigureEightPattern: MousePattern` (`init()`)
- All positions are Cocoa global points inside `bounds`. `speed` is a multiplier (1.0 = Normal).

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/ParametricPatternTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'CirclePattern' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/Patterns/MousePattern.swift`:

```swift
import CoreGraphics
import Foundation

/// A route Mousy runs. Positions are Cocoa global coordinates inside `bounds`.
/// `speed` is a multiplier (Sleepy 0.5 / Normal 1.0 / Frisky 1.8).
/// `cursor` is the current cursor position (used by ZoomiesPattern to flee).
public protocol MousePattern: Sendable {
    func startPoint(in bounds: CGRect) -> CGPoint
    mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint
}
```

`Sources/MousyCore/Patterns/CirclePattern.swift`:

```swift
import CoreGraphics
import Foundation

public struct CirclePattern: MousePattern {
    private var angle: Double = 0
    public init() {}

    public func startPoint(in bounds: CGRect) -> CGPoint { point(angle: 0, in: bounds) }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        angle += dt * 0.9 * speed          // radians/second at Normal
        return point(angle: angle, in: bounds)
    }

    private func point(angle: Double, in b: CGRect) -> CGPoint {
        let r = 0.35 * min(b.width, b.height)
        return CGPoint(x: b.midX + r * CGFloat(cos(angle)), y: b.midY + r * CGFloat(sin(angle)))
    }
}
```

`Sources/MousyCore/Patterns/StarPattern.swift`:

```swift
import CoreGraphics
import Foundation

/// Five-point star traversed as a continuous stroke (vertex order 0,2,4,1,3).
public struct StarPattern: MousePattern {
    private var progress: Double = 0       // distance traveled along the stroke
    public init() {}

    public static func vertices(in b: CGRect) -> [CGPoint] {
        let r = 0.4 * min(b.width, b.height)
        return [0, 2, 4, 1, 3].map { i in
            let a = Double.pi / 2 + Double(i) * 2 * .pi / 5   // point-up star
            return CGPoint(x: b.midX + r * CGFloat(cos(a)), y: b.midY + r * CGFloat(sin(a)))
        }
    }

    public func startPoint(in bounds: CGRect) -> CGPoint { Self.vertices(in: bounds)[0] }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        let vs = Self.vertices(in: bounds)
        let pts = vs + [vs[0]]
        let lens = zip(pts, pts.dropFirst()).map { Geometry.distance($0, $1) }
        let total = Double(lens.reduce(0, +))
        progress = (progress + dt * 260 * speed).truncatingRemainder(dividingBy: total)
        var remaining = progress
        for (i, len) in lens.enumerated() {
            if remaining <= Double(len) {
                let f = len > 0 ? CGFloat(remaining) / len : 0
                let a = pts[i], b = pts[i + 1]
                return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            }
            remaining -= Double(len)
        }
        return pts[0]
    }
}
```

`Sources/MousyCore/Patterns/FigureEightPattern.swift`:

```swift
import CoreGraphics
import Foundation

/// Horizontal figure-8 (Lissajous a=1, b=2).
public struct FigureEightPattern: MousePattern {
    private var t: Double = 0
    public init() {}

    public func startPoint(in bounds: CGRect) -> CGPoint { point(t: 0, in: bounds) }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        t += dt * 0.8 * speed
        return point(t: t, in: bounds)
    }

    private func point(t: Double, in b: CGRect) -> CGPoint {
        CGPoint(x: b.midX + 0.35 * b.width * CGFloat(sin(t)),
                y: b.midY + 0.30 * b.height * CGFloat(sin(2 * t)))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add pattern protocol with circle, star, and figure-8"
```

---

### Task 5: Stateful patterns (Scribble, Zoomies), Transit, PatternKind

**Files:**
- Create: `Sources/MousyCore/Patterns/ScribblePattern.swift`, `Sources/MousyCore/Patterns/ZoomiesPattern.swift`, `Sources/MousyCore/Patterns/TransitPattern.swift`, `Sources/MousyCore/Patterns/PatternKind.swift`, `Tests/MousyCoreTests/StatefulPatternTests.swift`

**Interfaces:**
- Consumes: `MousePattern`, `SeededRNG`, `Geometry.distance`
- Produces:
  - `struct ScribblePattern: MousePattern` (`init(seed: UInt64)`)
  - `struct ZoomiesPattern: MousePattern` (`init(seed: UInt64)`, `static let dartDistance: CGFloat` == 120)
  - `struct TransitPattern: MousePattern` (`init(from: CGPoint, to: CGPoint)`, `var isFinished: Bool`, `let duration: TimeInterval` — computed from distance at ~900 pt/s, clamped to 0.4–2.2 s so even corner-to-corner scampers stay smooth)
  - `enum PatternKind: String, CaseIterable, Sendable` — `.circle, .star, .figureEight, .scribble, .zoomies`; `func makePattern(seed: UInt64) -> any MousePattern`; `var displayName: String` ("Circle", "Star", "Figure-8", "Scribble", "Zoomies")

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/StatefulPatternTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import MousyCore

private let bounds = CGRect(x: 80, y: 80, width: 1760, height: 920)
private let dt = 1.0 / 120.0

@Test func scribbleStaysInBoundsAndIsDeterministic() {
    var a = ScribblePattern(seed: 7), b = ScribblePattern(seed: 7)
    var last = CGPoint.zero
    for _ in 0..<Int(60.0 * 120) {
        let pa = a.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
        let pb = b.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
        #expect(pa == pb)
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(pa))
        last = pa
    }
    var c = ScribblePattern(seed: 8)
    var cLast = CGPoint.zero
    for _ in 0..<Int(60.0 * 120) {
        cLast = c.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
    }
    #expect(last != cLast)   // different seeds diverge
}

@Test func scribbleIsContinuous() {
    var p = ScribblePattern(seed: 1)
    var prev = p.startPoint(in: bounds)
    for _ in 0..<Int(30.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.8, cursor: .zero)
        #expect(Geometry.distance(prev, pt) < 25)
        prev = pt
    }
}

@Test func zoomiesDartsAwayFromCursor() {
    var p = ZoomiesPattern(seed: 3)
    // Warm up with the cursor far away.
    var pos = CGPoint.zero
    for _ in 0..<120 {
        pos = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: CGPoint(x: -5000, y: -5000))
    }
    // Park the cursor right next to Mousy: within dartDistance.
    let cursor = CGPoint(x: pos.x + 50, y: pos.y)
    let before = Geometry.distance(pos, cursor)
    #expect(before < ZoomiesPattern.dartDistance)
    var after = pos
    for _ in 0..<120 {   // one second of fleeing
        after = p.step(dt: dt, bounds: bounds, speed: 1.0, cursor: cursor)
    }
    #expect(Geometry.distance(after, cursor) > before + 100)   // it ran away
}

@Test func zoomiesStaysInBounds() {
    var p = ZoomiesPattern(seed: 9)
    var cursor = CGPoint(x: bounds.midX, y: bounds.midY)
    for _ in 0..<Int(60.0 * 120) {
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.8, cursor: cursor)
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(pt))
        cursor = pt   // worst case: cursor glued to Mousy, constant darting
    }
}

@Test func transitEasesBetweenPointsAndFinishes() {
    let from = CGPoint(x: 100, y: 100), to = CGPoint(x: 1000, y: 800)
    var t = TransitPattern(from: from, to: to)
    #expect(t.startPoint(in: bounds) == from)
    #expect(!t.isFinished)
    var prev = from
    var steps = 0
    while !t.isFinished && steps < 1000 {
        let p = t.step(dt: dt, bounds: bounds, speed: 1.0, cursor: .zero)
        #expect(Geometry.distance(prev, p) < 25)   // ≤900 pt/s at 120 fps + easing
        prev = p
        steps += 1
    }
    #expect(t.isFinished)
    #expect(Geometry.distance(prev, to) < 1)
    // Duration scales with distance, clamped to [0.4, 2.2].
    #expect(TransitPattern(from: .zero, to: CGPoint(x: 10, y: 0)).duration == 0.4)
    #expect(TransitPattern(from: .zero, to: CGPoint(x: 9000, y: 0)).duration == 2.2)
}

@Test func patternKindFactoryAndNames() {
    #expect(PatternKind.allCases.count == 5)
    #expect(PatternKind.figureEight.displayName == "Figure-8")
    for kind in PatternKind.allCases {
        var p = kind.makePattern(seed: 1)
        let pt = p.step(dt: dt, bounds: bounds, speed: 1.0,
                        cursor: CGPoint(x: bounds.midX, y: bounds.midY))
        #expect(bounds.insetBy(dx: -1, dy: -1).contains(pt))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'ScribblePattern' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/Patterns/ScribblePattern.swift`:

```swift
import CoreGraphics
import Foundation

/// Smooth wandering random walk: low-pass-filtered random steering.
public struct ScribblePattern: MousePattern {
    private var rng: SeededRNG
    private var position: CGPoint?
    private var heading: Double = 0
    private var turnRate: Double = 0

    public init(seed: UInt64 = 0xC0FFEE) { rng = SeededRNG(seed: seed) }

    public func startPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        var pos = position ?? startPoint(in: bounds)
        let jolt = Double.random(in: -6...6, using: &rng)
        turnRate += (jolt - turnRate) * min(1, dt * 2)
        heading += turnRate * dt
        let v = 230 * speed
        pos.x += CGFloat(cos(heading) * v * dt)
        pos.y += CGFloat(sin(heading) * v * dt)
        if !bounds.contains(pos) {
            heading = atan2(Double(bounds.midY - pos.y), Double(bounds.midX - pos.x))
            turnRate = 0
            pos.x = min(max(pos.x, bounds.minX), bounds.maxX)
            pos.y = min(max(pos.y, bounds.minY), bounds.maxY)
        }
        position = pos
        return pos
    }
}
```

`Sources/MousyCore/Patterns/ZoomiesPattern.swift`:

```swift
import CoreGraphics
import Foundation

/// Free-roam wander; darts away when the cursor closes in. Never gets caught.
public struct ZoomiesPattern: MousePattern {
    public static let dartDistance: CGFloat = 120

    private var rng: SeededRNG
    private var position: CGPoint?
    private var heading: Double = 0
    private var turnRate: Double = 0
    private var dartBoost: Double = 0     // extra speed multiplier, decays

    public init(seed: UInt64 = 0x5EED) { rng = SeededRNG(seed: seed) }

    public func startPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        var pos = position ?? startPoint(in: bounds)
        if Geometry.distance(pos, cursor) < Self.dartDistance {
            let away = atan2(Double(pos.y - cursor.y), Double(pos.x - cursor.x))
            heading = away + Double.random(in: -0.8...0.8, using: &rng)
            dartBoost = 2.2
            turnRate = 0
        }
        let jolt = Double.random(in: -5...5, using: &rng)
        turnRate += (jolt - turnRate) * min(1, dt * 2)
        heading += turnRate * dt * (dartBoost > 0.1 ? 0.2 : 1)   // darts fly straight
        dartBoost = max(0, dartBoost - dt * 1.8)
        let v = 240 * speed * (1 + dartBoost)
        pos.x += CGFloat(cos(heading) * v * dt)
        pos.y += CGFloat(sin(heading) * v * dt)
        if !bounds.contains(pos) {
            heading = atan2(Double(bounds.midY - pos.y), Double(bounds.midX - pos.x))
            turnRate = 0
            pos.x = min(max(pos.x, bounds.minX), bounds.maxX)
            pos.y = min(max(pos.y, bounds.minY), bounds.maxY)
        }
        position = pos
        return pos
    }
}
```

`Sources/MousyCore/Patterns/TransitPattern.swift`:

```swift
import CoreGraphics
import Foundation

/// Smooth-stepped scamper between a point and the next pattern's start.
/// Duration scales with distance (~900 pt/s), clamped to [0.4, 2.2] s — the
/// 2.2 s ceiling keeps even corner-to-corner scampers under ~23 pt/frame at
/// 60 fps (smoothstep peaks at 1.5× the mean speed).
public struct TransitPattern: MousePattern {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: TimeInterval
    private var elapsed: TimeInterval = 0

    public init(from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
        self.duration = min(2.2, max(0.4, Double(Geometry.distance(from, to)) / 900))
    }

    public var isFinished: Bool { elapsed >= duration }

    public func startPoint(in bounds: CGRect) -> CGPoint { from }

    public mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint {
        elapsed = min(duration, elapsed + dt)
        let f = elapsed / duration
        let e = CGFloat(f * f * (3 - 2 * f))   // smoothstep ease-in-out
        return CGPoint(x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e)
    }
}
```

`Sources/MousyCore/Patterns/PatternKind.swift`:

```swift
public enum PatternKind: String, CaseIterable, Sendable {
    case circle, star, figureEight, scribble, zoomies

    public func makePattern(seed: UInt64) -> any MousePattern {
        switch self {
        case .circle: CirclePattern()
        case .star: StarPattern()
        case .figureEight: FigureEightPattern()
        case .scribble: ScribblePattern(seed: seed)
        case .zoomies: ZoomiesPattern(seed: seed)
        }
    }

    public var displayName: String {
        switch self {
        case .circle: "Circle"
        case .star: "Star"
        case .figureEight: "Figure-8"
        case .scribble: "Scribble"
        case .zoomies: "Zoomies"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add scribble, zoomies, transit patterns and pattern kinds"
```

---

### Task 6: PatternScheduler

**Files:**
- Create: `Sources/MousyCore/PatternScheduler.swift`, `Tests/MousyCoreTests/SchedulerTests.swift`

**Interfaces:**
- Consumes: `PatternKind`, `TransitPattern`, `MousePattern`, `SeededRNG`
- Produces:
  - `struct PatternScheduler: Sendable`
  - `enum PatternScheduler.Mode: Sendable, Equatable { case autoCycle, fixed(PatternKind) }`
  - `init(mode: Mode, seed: UInt64)`
  - `mutating func step(now: TimeInterval, dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint` — first call transits from `cursor` to the first pattern's start
  - `private(set) var currentKind: PatternKind?`
  - `static func pickNext(excluding: PatternKind?, using rng: inout SeededRNG) -> PatternKind`
  - `static func nextDuration(using rng: inout SeededRNG) -> TimeInterval` (20–40 s)

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/SchedulerTests.swift`:

```swift
import Testing
import CoreGraphics
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'PatternScheduler' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/PatternScheduler.swift`:

```swift
import CoreGraphics
import Foundation

/// Owns the current pattern, switches on a 20–40 s cadence in auto-cycle mode,
/// and bridges every switch with a TransitPattern so Mousy never teleports.
public struct PatternScheduler: Sendable {
    public enum Mode: Sendable, Equatable {
        case autoCycle
        case fixed(PatternKind)
    }

    private var rng: SeededRNG
    private let mode: Mode
    private var current: (any MousePattern)?
    private var transit: TransitPattern?
    private var switchAt: TimeInterval = 0
    private var lastPoint: CGPoint?
    public private(set) var currentKind: PatternKind?

    public init(mode: Mode, seed: UInt64) {
        self.mode = mode
        self.rng = SeededRNG(seed: seed)
    }

    public static func pickNext(excluding: PatternKind?, using rng: inout SeededRNG) -> PatternKind {
        let candidates = PatternKind.allCases.filter { $0 != excluding }
        return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
    }

    public static func nextDuration(using rng: inout SeededRNG) -> TimeInterval {
        Double.random(in: 20...40, using: &rng)
    }

    public mutating func step(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> CGPoint {
        // Mid-transit: keep scampering.
        if var t = transit {
            let p = t.step(dt: dt, bounds: bounds, speed: speed, cursor: cursor)
            transit = t.isFinished ? nil : t
            lastPoint = p
            return p
        }
        // Time to pick a pattern? (first call, or auto-cycle expiry)
        if current == nil || (mode == .autoCycle && now >= switchAt) {
            let kind: PatternKind
            switch mode {
            case .fixed(let k): kind = k
            case .autoCycle: kind = Self.pickNext(excluding: currentKind, using: &rng)
            }
            let pattern = kind.makePattern(seed: rng.next())
            currentKind = kind
            current = pattern
            switchAt = now + Self.nextDuration(using: &rng)
            var t = TransitPattern(from: lastPoint ?? cursor,
                                   to: pattern.startPoint(in: bounds))
            let p = t.step(dt: dt, bounds: bounds, speed: speed, cursor: cursor)
            transit = t.isFinished ? nil : t
            lastPoint = p
            return p
        }
        // Normal pattern stepping.
        var c = current!
        let p = c.step(dt: dt, bounds: bounds, speed: speed, cursor: cursor)
        current = c
        lastPoint = p
        return p
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add pattern scheduler with auto-cycle and transit bridging"
```

---

### Task 7: Settings model

**Files:**
- Create: `Sources/MousyCore/SettingsModel.swift`, `Tests/MousyCoreTests/SettingsTests.swift`

**Interfaces:**
- Consumes: `PatternKind`, `PatternScheduler.Mode`
- Produces:
  - `enum MoveSpeed: String, CaseIterable, Sendable { case sleepy, normal, frisky }` with `var multiplier: Double` (0.5 / 1.0 / 1.8) and `var displayName: String` ("Sleepy"/"Normal"/"Frisky")
  - `enum PatternChoice: String, CaseIterable, Sendable { case auto, circle, star, figureEight, scribble, zoomies }` with `var schedulerMode: PatternScheduler.Mode` and `var displayName: String` ("Auto-cycle" for `.auto`, else the kind's name)

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/SettingsTests.swift`:

```swift
import Testing
@testable import MousyCore

@Test func speedMultipliers() {
    #expect(MoveSpeed.sleepy.multiplier == 0.5)
    #expect(MoveSpeed.normal.multiplier == 1.0)
    #expect(MoveSpeed.frisky.multiplier == 1.8)
    #expect(MoveSpeed.sleepy.displayName == "Sleepy")
}

@Test func patternChoiceMapsToSchedulerMode() {
    #expect(PatternChoice.auto.schedulerMode == .autoCycle)
    #expect(PatternChoice.zoomies.schedulerMode == .fixed(.zoomies))
    #expect(PatternChoice.figureEight.schedulerMode == .fixed(.figureEight))
    #expect(PatternChoice.auto.displayName == "Auto-cycle")
    #expect(PatternChoice.figureEight.displayName == "Figure-8")
    #expect(PatternChoice.allCases.count == 6)
}

@Test func rawValuesRoundTripForAppStorage() {
    for c in PatternChoice.allCases { #expect(PatternChoice(rawValue: c.rawValue) == c) }
    for s in MoveSpeed.allCases { #expect(MoveSpeed(rawValue: s.rawValue) == s) }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'MoveSpeed' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/SettingsModel.swift`:

```swift
public enum MoveSpeed: String, CaseIterable, Sendable {
    case sleepy, normal, frisky

    public var multiplier: Double {
        switch self {
        case .sleepy: 0.5
        case .normal: 1.0
        case .frisky: 1.8
        }
    }

    public var displayName: String {
        switch self {
        case .sleepy: "Sleepy"
        case .normal: "Normal"
        case .frisky: "Frisky"
        }
    }
}

public enum PatternChoice: String, CaseIterable, Sendable {
    case auto, circle, star, figureEight, scribble, zoomies

    public var schedulerMode: PatternScheduler.Mode {
        switch self {
        case .auto: .autoCycle
        case .circle: .fixed(.circle)
        case .star: .fixed(.star)
        case .figureEight: .fixed(.figureEight)
        case .scribble: .fixed(.scribble)
        case .zoomies: .fixed(.zoomies)
        }
    }

    public var displayName: String {
        switch self {
        case .auto: "Auto-cycle"
        case .circle: PatternKind.circle.displayName
        case .star: PatternKind.star.displayName
        case .figureEight: PatternKind.figureEight.displayName
        case .scribble: PatternKind.scribble.displayName
        case .zoomies: PatternKind.zoomies.displayName
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add speed and pattern choice settings model"
```

---

### Task 8: EngineCore

**Files:**
- Create: `Sources/MousyCore/EngineCore.swift`, `Tests/MousyCoreTests/EngineCoreTests.swift`

**Interfaces:**
- Consumes: `PatternScheduler`, `TrailBuffer`
- Produces:
  - `struct EngineCore` with `init(mode: PatternScheduler.Mode, seed: UInt64, cursorLag: TimeInterval = 0.35)`
  - `struct EngineCore.Frame: Sendable { let mousy: CGPoint; let cursor: CGPoint; let facingLeft: Bool }`
  - `mutating func tick(now: TimeInterval, dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> Frame`
  - `let cursorLag: TimeInterval`

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/EngineCoreTests.swift`:

```swift
import Testing
import CoreGraphics
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'EngineCore' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/EngineCore.swift`:

```swift
import CoreGraphics
import Foundation

/// One tick = one frame: advances Mousy along the scheduled pattern, records the
/// trail, and derives the cursor position by sampling the trail `cursorLag` ago.
public struct EngineCore {
    public struct Frame: Sendable {
        public let mousy: CGPoint       // Cocoa global
        public let cursor: CGPoint      // Cocoa global, trails mousy
        public let facingLeft: Bool
    }

    public let cursorLag: TimeInterval
    private var scheduler: PatternScheduler
    private var trail = TrailBuffer()
    private var lastMousyX: CGFloat?
    private var facingLeft = true       // 🐭 faces left natively

    public init(mode: PatternScheduler.Mode, seed: UInt64, cursorLag: TimeInterval = 0.35) {
        self.scheduler = PatternScheduler(mode: mode, seed: seed)
        self.cursorLag = cursorLag
    }

    public mutating func tick(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> Frame {
        let mousy = scheduler.step(now: now, dt: dt, bounds: bounds, speed: speed, cursor: cursor)
        trail.append(time: now, point: mousy)
        let target = trail.sample(at: now - cursorLag) ?? mousy
        if let lx = lastMousyX, abs(mousy.x - lx) > 0.5 { facingLeft = mousy.x < lx }
        lastMousyX = mousy.x
        return Frame(mousy: mousy, cursor: target, facingLeft: facingLeft)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all tests)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add engine core combining scheduler and cursor trail"
```

---

### Task 9: System services (CursorSynthesizer, WakeGuard, DisplayLinkDriver, PermissionGate, LaunchAtLogin)

**Files:**
- Create: `Sources/MousyMousy/CursorSynthesizer.swift`, `Sources/MousyMousy/WakeGuard.swift`, `Sources/MousyMousy/DisplayLinkDriver.swift`, `Sources/MousyMousy/PermissionGate.swift`, `Sources/MousyMousy/LaunchAtLogin.swift`

**Interfaces:**
- Consumes: `Geometry.cgFromCocoa`
- Produces (all `@MainActor`, app target — no unit tests; verified by build here and manually in Task 12):
  - `final class CursorSynthesizer` — `init()`, `func post(cocoaPoint: CGPoint)`, `private(set) var lastPosted: CGPoint?`, `var currentCocoaPosition: CGPoint`, `static let eventTag: Int64`
  - `final class WakeGuard` — `func start()`, `func stop()`
  - `final class DisplayLinkDriver: NSObject` — `var onTick: ((TimeInterval, TimeInterval) -> Void)?` (now, dt), `func start(in view: NSView)`, `func stop()`
  - `enum PermissionGate` — `static var isTrusted: Bool`, `static func promptForAccess()`
  - `enum LaunchAtLogin` — `static var isEnabled: Bool`, `static func set(_ enabled: Bool) throws`

- [ ] **Step 1: Implement all five files**

`Sources/MousyMousy/CursorSynthesizer.swift`:

```swift
import AppKit
import MousyCore

/// Posts synthetic mouse-move events. The ONLY place Cocoa coords are flipped to
/// CG top-left space. Events come from a private, tagged source so they are
/// identifiable as ours by any observer.
@MainActor
final class CursorSynthesizer {
    static let eventTag: Int64 = 0x4D6F_7573_79   // "Mousy"

    private let source: CGEventSource?
    private(set) var lastPosted: CGPoint?          // Cocoa global

    init() {
        source = CGEventSource(stateID: .privateState)
        source?.userData = Self.eventTag
    }

    func post(cocoaPoint p: CGPoint) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cg = Geometry.cgFromCocoa(p, primaryScreenHeight: primaryHeight)
        let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                            mouseCursorPosition: cg, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
        lastPosted = p
    }

    /// Reading the cursor needs no permission.
    var currentCocoaPosition: CGPoint { NSEvent.mouseLocation }
}
```

`Sources/MousyMousy/WakeGuard.swift`:

```swift
import Foundation
import IOKit.pwr_mgt

/// Belt and braces: synthetic events keep SOFTWARE seeing activity, IOPM keeps
/// the MACHINE awake. Standing display-sleep assertion + periodic user-activity
/// declarations (the Jiggler/KeepingYouAwake pattern).
@MainActor
final class WakeGuard {
    private var sleepAssertion: IOPMAssertionID = 0
    private var activityID: IOPMAssertionID = 0
    private var timer: Timer?

    func start() {
        stop()
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "Mousy Mousy is keeping the display awake" as CFString,
                                    &sleepAssertion)
        declareActivity()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.declareActivity() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
    }

    private func declareActivity() {
        // Reusing activityID replaces the previous declaration.
        IOPMAssertionDeclareUserActivity("Mousy Mousy activity" as CFString,
                                         kIOPMUserActiveLocal, &activityID)
    }
}
```

`Sources/MousyMousy/DisplayLinkDriver.swift`:

```swift
import AppKit
import QuartzCore

/// One CADisplayLink (vended by the overlay view, macOS 14+ API) drives both the
/// sprite and the cursor so the chase stays phase-locked. ProMotion-aware.
@MainActor
final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval?

    /// (now, dt) — `now` is the link's targetTimestamp.
    var onTick: ((TimeInterval, TimeInterval) -> Void)?

    func start(in view: NSView) {
        stop()
        lastTime = nil
        link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let dt = min(0.1, max(0, now - (lastTime ?? now)))
        lastTime = now
        if dt > 0 { onTick?(now, dt) }
    }
}
```

`Sources/MousyMousy/PermissionGate.swift`:

```swift
import ApplicationServices
import CoreGraphics

/// One TCC grant: Accessibility (covers event posting too).
@MainActor
enum PermissionGate {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Post rights are checked per WindowServer connection; can lag the grant.
    /// If this stays false after granting, the app needs a relaunch (spec §7/§9).
    static var canPostEvents: Bool { CGPreflightPostEventAccess() }

    /// Shows the system "wants to control this computer" dialog with a
    /// deep link to System Settings ▸ Privacy & Security ▸ Accessibility.
    static func promptForAccess() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
```

`Sources/MousyMousy/LaunchAtLogin.swift`:

```swift
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            // User must approve in System Settings ▸ Login Items (spec §8).
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 2: Verify it builds (main.swift still the print stub)**

Run: `swift build && swift test`
Expected: `Build complete!`, all core tests PASS

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add cursor synthesis, wake guard, display link, permission and login services"
```

---

### Task 10: Overlay UI (panel, model, views, controller)

**Files:**
- Create: `Sources/MousyMousy/OverlayPanel.swift`, `Sources/MousyMousy/OverlayModel.swift`, `Sources/MousyMousy/OverlayView.swift`, `Sources/MousyMousy/OverlayController.swift`

**Interfaces:**
- Consumes: `Geometry.viewFromCocoa`
- Produces (all `@MainActor`):
  - `final class OverlayPanel: NSPanel` — `init(screen: NSScreen)`, `canBecomeKey == true`
  - `@Observable final class OverlayModel` — `enum Phase: Equatable { case countdown(Int), running }`; vars `phase`, `spriteViewPosition: CGPoint`, `facingLeft: Bool`, `showSprite: Bool`, `cardDimmed: Bool`; `func reset()`
  - `struct OverlayView: View` — `init(model: OverlayModel, isCardScreen: Bool)`
  - `final class OverlayController` — `let model: OverlayModel`, `var onEscape: (() -> Void)?`, `private(set) var cardScreen: NSScreen?`, `private(set) var cardPanel: OverlayPanel?`, `func show()`, `func dismiss()`, `func updateSprite(cocoaGlobal: CGPoint, facingLeft: Bool)`

- [ ] **Step 1: Implement all four files**

`Sources/MousyMousy/OverlayPanel.swift`:

```swift
import AppKit

/// Borderless, non-activating, screen-saver-level panel. Becomes key WITHOUT
/// activating the app (Spotlight's trick), so ESC reaches us while the user's
/// frontmost app keeps focus appearance. Cursor input passes through.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }     // borderless panels refuse key by default
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver                     // above menu bar and Dock; cursor still composites above
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        hidesOnDeactivate = false                // NSPanel default would hide it
        isFloatingPanel = true
        animationBehavior = .none
        isReleasedWhenClosed = false
    }
}
```

`Sources/MousyMousy/OverlayModel.swift`:

```swift
import CoreGraphics
import Observation

@Observable @MainActor
final class OverlayModel {
    enum Phase: Equatable {
        case countdown(Int)
        case running
    }

    var phase: Phase = .countdown(3)
    var spriteViewPosition: CGPoint = .zero      // card panel's local (top-left) coords
    var facingLeft = true
    var showSprite = false
    var cardDimmed = false

    func reset() {
        phase = .countdown(3)
        spriteViewPosition = .zero
        facingLeft = true
        showSprite = false
        cardDimmed = false
    }
}
```

`Sources/MousyMousy/OverlayView.swift`:

```swift
import SwiftUI

/// Full-screen overlay content. The scrim is load-bearing: Liquid Glass samples
/// IN-WINDOW content, so without it the card renders flat on a clear window.
struct OverlayView: View {
    let model: OverlayModel
    let isCardScreen: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            if isCardScreen {
                EscCardView(model: model)
                if model.showSprite {
                    MousySpriteView(model: model)
                }
            }
        }
    }
}

struct EscCardView: View {
    let model: OverlayModel

    var body: some View {
        VStack(spacing: 14) {
            Text("🐭").font(.system(size: 42))
            switch model.phase {
            case .countdown(let n):
                Text("Starting in \(n)…")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
            case .running:
                Label("ESC to exit", systemImage: "escape")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(.primary)
        .padding(44)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .opacity(model.cardDimmed ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.6), value: model.cardDimmed)
    }
}

struct MousySpriteView: View {
    let model: OverlayModel

    var body: some View {
        Text("🐭")
            .font(.system(size: 40))
            // 🐭 faces left natively; mirror when running right.
            .scaleEffect(x: model.facingLeft ? 1 : -1, y: 1)
            .position(model.spriteViewPosition)
    }
}
```

`Sources/MousyMousy/OverlayController.swift`:

```swift
import AppKit
import SwiftUI
import MousyCore

/// One panel per display (scrim everywhere; card + sprite on the cursor's
/// display, which is made key for ESC capture).
@MainActor
final class OverlayController {
    let model = OverlayModel()
    var onEscape: (() -> Void)?
    private(set) var cardScreen: NSScreen?
    private(set) var cardPanel: OverlayPanel?

    private var panels: [OverlayPanel] = []
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func show() {
        dismiss()
        model.reset()
        let mouse = NSEvent.mouseLocation
        let screens = NSScreen.screens
        cardScreen = screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? screens.first
        for screen in screens {
            let isCard = screen == cardScreen
            let panel = OverlayPanel(screen: screen)
            panel.contentView = NSHostingView(rootView: OverlayView(model: model, isCardScreen: isCard))
            panel.alphaValue = 0
            if isCard {
                cardPanel = panel
                panel.makeKeyAndOrderFront(nil)   // non-activating: app stays in background
            } else {
                panel.orderFrontRegardless()
            }
            panels.append(panel)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            panels.forEach { $0.animator().alphaValue = 1 }
        }
        installMonitors()
    }

    func dismiss() {
        removeMonitors()
        let old = panels
        panels = []
        cardPanel = nil
        cardScreen = nil
        guard !old.isEmpty else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            old.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            Task { @MainActor in old.forEach { $0.orderOut(nil) } }
        })
    }

    func updateSprite(cocoaGlobal p: CGPoint, facingLeft: Bool) {
        guard let frame = cardScreen?.frame else { return }
        model.spriteViewPosition = Geometry.viewFromCocoa(p, screenFrame: frame)
        model.facingLeft = facingLeft
    }

    private func installMonitors() {
        // Primary: our panel is key, so every keystroke arrives here. Swallow all
        // keys while the overlay is up (spec §4); ESC stops the session.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 { self?.onEscape?() }
            }
            return nil
        }
        // Backup for the edge case where another app steals key status mid-run.
        // Global monitors never see our own app's events, so both are needed.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 { self?.onEscape?() }
            }
        }
    }

    private func removeMonitors() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build && swift test`
Expected: `Build complete!`, all core tests PASS.
If the compiler rejects `MainActor.assumeIsolated` inside the monitor closures, replace the closure bodies with `Task { @MainActor in ... }` for the global monitor only (the local monitor must stay synchronous to return `nil`; for it, `assumeIsolated` is correct because local monitors always fire on the main thread).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add overlay panels, glass ESC card, and mousy sprite views"
```

---

### Task 11: AppController, SafetyMonitor, MenuBarExtra app

**Files:**
- Create: `Sources/MousyMousy/SafetyMonitor.swift`, `Sources/MousyMousy/AppController.swift`, `Sources/MousyMousy/MousyMousyApp.swift`
- Delete: `Sources/MousyMousy/main.swift`

**Interfaces:**
- Consumes: everything from Tasks 8–10 (`EngineCore`, `CursorSynthesizer`, `WakeGuard`, `DisplayLinkDriver`, `PermissionGate`, `LaunchAtLogin`, `OverlayController`, `PatternChoice`, `MoveSpeed`, `Deviation`)
- Produces:
  - `final class SafetyMonitor` — `var onInterrupt: (() -> Void)?`, `func startObservingSystem()`, `func stopObservingSystem()`
  - `@Observable final class AppController` — `enum State: Equatable { case idle, countdown, running }`, `private(set) var state: State`, `func start(choice: PatternChoice, speed: MoveSpeed)`, `func stop()`
  - `@main struct MousyMousyApp: App` with `MenuBarExtra`

- [ ] **Step 1: Implement**

`Sources/MousyMousy/SafetyMonitor.swift`:

```swift
import AppKit

/// Stops the session when the system state changes under us: sleep, screens
/// sleeping, screen lock, screensaver, fast user switch. Names on the
/// DistributedNotificationCenter are undocumented-but-stable (standard in this
/// app category). Always STOP (not pause): jiggling a locked screen fights the
/// lock idle and looks like HID injection.
@MainActor
final class SafetyMonitor {
    var onInterrupt: (() -> Void)?
    private var workspaceTokens: [NSObjectProtocol] = []
    private var distributedTokens: [NSObjectProtocol] = []
    private var centerTokens: [NSObjectProtocol] = []

    func startObservingSystem() {
        stopObservingSystem()
        // Display topology changed mid-run (monitor un/plugged) → a human is
        // present; end the session rather than rebuild panels live (spec §9).
        centerTokens = [NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onInterrupt?() }
            }]
        let ws = NSWorkspace.shared.notificationCenter
        let wsNames: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ]
        workspaceTokens = wsNames.map { name in
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onInterrupt?() }
            }
        }
        let dnc = DistributedNotificationCenter.default()
        let dncNames = ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"]
        distributedTokens = dncNames.map { name in
            dnc.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onInterrupt?() }
            }
        }
    }

    func stopObservingSystem() {
        workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        distributedTokens.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        centerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceTokens = []
        distributedTokens = []
        centerTokens = []
    }
}
```

`Sources/MousyMousy/AppController.swift`:

```swift
import AppKit
import QuartzCore
import Observation
import MousyCore

/// State machine: idle → countdown → running → idle. Owns every subsystem.
@Observable @MainActor
final class AppController {
    enum State: Equatable { case idle, countdown, running }

    private(set) var state: State = .idle

    let overlay = OverlayController()
    private let synthesizer = CursorSynthesizer()
    private let wake = WakeGuard()
    private let safety = SafetyMonitor()
    private let driver = DisplayLinkDriver()
    private var engine: EngineCore?
    private var bounds: CGRect = .zero
    private var speed: Double = 1
    private var runningSince: TimeInterval?
    private var countdownTask: Task<Void, Never>?
    private var dimTask: Task<Void, Never>?

    func start(choice: PatternChoice, speed: MoveSpeed) {
        guard state == .idle, PermissionGate.isTrusted, PermissionGate.canPostEvents else { return }
        state = .countdown
        self.speed = speed.multiplier
        overlay.onEscape = { [weak self] in self?.stop() }
        safety.onInterrupt = { [weak self] in self?.stop() }
        overlay.show()
        safety.startObservingSystem()
        engine = EngineCore(mode: choice.schedulerMode, seed: UInt64.random(in: .min ... .max))
        // Patterns run on the card screen, inset so Mousy avoids edges/corners.
        bounds = (overlay.cardScreen?.frame ?? .zero).insetBy(dx: 80, dy: 80)
        countdownTask = Task { [weak self] in
            for n in [3, 2, 1] {
                self?.overlay.model.phase = .countdown(n)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            self?.beginRunning()
        }
    }

    private func beginRunning() {
        guard state == .countdown else { return }
        guard let view = overlay.cardPanel?.contentView else { stop(); return }
        state = .running
        overlay.model.phase = .running
        overlay.model.showSprite = true
        runningSince = nil                       // armed on first tick
        wake.start()
        dimTask = Task { [weak self] in          // card fades after 5 s (spec §4)
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self?.state == .running else { return }
            self?.overlay.model.cardDimmed = true
        }
        driver.onTick = { [weak self] now, dt in self?.tick(now: now, dt: dt) }
        driver.start(in: view)
    }

    private func tick(now: TimeInterval, dt: TimeInterval) {
        guard state == .running, var engine else { return }
        if runningSince == nil { runningSince = now }
        // Deviation check: armed 0.5 s after running begins (spec §5.6) so the
        // hand leaving the mouse doesn't trip it.
        if let since = runningSince, now - since > 0.5,
           let expected = synthesizer.lastPosted,
           Deviation.humanMoved(expected: expected, actual: synthesizer.currentCocoaPosition) {
            stop()
            return
        }
        let frame = engine.tick(now: now, dt: dt, bounds: bounds, speed: speed,
                                cursor: synthesizer.currentCocoaPosition)
        self.engine = engine
        overlay.updateSprite(cocoaGlobal: frame.mousy, facingLeft: frame.facingLeft)
        synthesizer.post(cocoaPoint: frame.cursor)
    }

    func stop() {
        guard state != .idle else { return }
        countdownTask?.cancel()
        dimTask?.cancel()
        driver.stop()
        driver.onTick = nil
        wake.stop()
        safety.stopObservingSystem()
        engine = nil
        overlay.dismiss()
        state = .idle
    }
}
```

`Sources/MousyMousy/MousyMousyApp.swift` (also delete `Sources/MousyMousy/main.swift`):

```swift
import SwiftUI
import MousyCore

@main
struct MousyMousyApp: App {
    @State private var controller = AppController()
    @AppStorage("patternChoice") private var patternRaw = PatternChoice.auto.rawValue
    @AppStorage("moveSpeed") private var speedRaw = MoveSpeed.normal.rawValue

    var body: some Scene {
        MenuBarExtra("Mousy Mousy", systemImage: "computermouse") {
            MenuContent(controller: controller, patternRaw: $patternRaw, speedRaw: $speedRaw)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    let controller: AppController
    @Binding var patternRaw: String
    @Binding var speedRaw: String
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        // Re-evaluated each time the menu opens; after granting Accessibility
        // in System Settings, reopen the menu to see Start.
        if PermissionGate.isTrusted {
            if controller.state == .idle {
                Button("Start Mousy") {
                    controller.start(choice: PatternChoice(rawValue: patternRaw) ?? .auto,
                                     speed: MoveSpeed(rawValue: speedRaw) ?? .normal)
                }
                .keyboardShortcut("s")
            } else {
                Button("Stop") { controller.stop() }
            }
        } else {
            Button("Grant Accessibility Access…") { PermissionGate.promptForAccess() }
        }
        Divider()
        Picker("Pattern", selection: $patternRaw) {
            ForEach(PatternChoice.allCases, id: \.rawValue) { c in
                Text(c.displayName).tag(c.rawValue)
            }
        }
        Picker("Speed", selection: $speedRaw) {
            ForEach(MoveSpeed.allCases, id: \.rawValue) { s in
                Text(s.displayName).tag(s.rawValue)
            }
        }
        Divider()
        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { on in
                try? LaunchAtLogin.set(on)
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        ))
        Divider()
        Button("Quit Mousy Mousy") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
```

- [ ] **Step 2: Verify it builds and core tests pass**

Run: `swift build && swift test`
Expected: `Build complete!`, all core tests PASS

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add app controller, safety monitor, and menu bar app"
```

---

### Task 12: Packaging, signing, first launch, UAT doc

**Files:**
- Create: `Support/Info.plist`, `scripts/make-cert.sh`, `scripts/build.sh`, `docs/UAT.md`, `README.md`

**Interfaces:**
- Consumes: the built `MousyMousy` binary
- Produces: signed `dist/Mousy Mousy.app`, installed `/Applications/Mousy Mousy.app`

- [ ] **Step 1: Write Support/Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MousyMousy</string>
    <key>CFBundleIdentifier</key>
    <string>com.chris.mousymousy</string>
    <key>CFBundleName</key>
    <string>Mousy Mousy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Write scripts/make-cert.sh (one-time cert creation)**

```bash
#!/bin/bash
# Creates the stable self-signed "MousyMousy Dev" code-signing cert.
# WHY: TCC stores the app's designated requirement. Ad-hoc signatures degenerate
# to a per-build cdhash, so the Accessibility grant dies on every rebuild. A
# stable cert gives 'identifier "com.chris.mousymousy" and certificate leaf'
# — grants survive rebuilds indefinitely. Also required for SMAppService and
# macOS 26's stricter event-synthesis gating.
set -euo pipefail
CN="MousyMousy Dev"

if security find-certificate -c "$CN" >/dev/null 2>&1; then
    echo "Certificate '$CN' already exists — nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
    -keyout "$TMP/dev.key" -out "$TMP/dev.crt" \
    -subj "/CN=$CN" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"

# -legacy is load-bearing: without it Keychain imports the p12 but codesign
# cannot use the key.
openssl pkcs12 -export -legacy -in "$TMP/dev.crt" -inkey "$TMP/dev.key" \
    -out "$TMP/dev.p12" -password pass:mousy

security import "$TMP/dev.p12" -k ~/Library/Keychains/login.keychain-db \
    -P mousy -T /usr/bin/codesign

cat <<'EOF'

Certificate imported. ONE MANUAL STEP REMAINS:
  1. Open Keychain Access, find "MousyMousy Dev" under My Certificates.
  2. Double-click it → Trust → Code Signing → Always Trust.
  3. Close the window (enter your password when asked).

Then run scripts/build.sh
EOF
```

- [ ] **Step 3: Write scripts/build.sh**

```bash
#!/bin/bash
# Builds, bundles, signs. Pass --install to copy into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/Mousy Mousy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MousyMousy "$APP/Contents/MacOS/MousyMousy"
cp Support/Info.plist "$APP/Contents/Info.plist"

# NEVER ad-hoc (-s -): see scripts/make-cert.sh header.
codesign --force --sign "MousyMousy Dev" "$APP"
codesign --verify --verbose=2 "$APP"
echo "Built and signed: $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Mousy Mousy.app"
    cp -R "$APP" "/Applications/Mousy Mousy.app"
    echo "Installed. Launch with: open '/Applications/Mousy Mousy.app'"
    echo "(Always launch via 'open' or Finder — never the bare binary — so TCC"
    echo " attributes the Accessibility grant to the app.)"
fi
```

- [ ] **Step 4: Make scripts executable, create cert, build, install**

Run:

```bash
chmod +x scripts/make-cert.sh scripts/build.sh
./scripts/make-cert.sh
```

Expected: certificate imported message + the manual Keychain trust step. **STOP and ask the user (Chris) to perform the Keychain "Always Trust" step before continuing.** Then:

```bash
./scripts/build.sh --install
```

Expected: `Built and signed: dist/Mousy Mousy.app`, `Installed.`
If codesign fails with `no identity found`, the Keychain trust step hasn't been done yet.

- [ ] **Step 5: First launch + smoke test (requires the user at the machine)**

Run: `open "/Applications/Mousy Mousy.app"`

Ask the user to verify, in order:
1. Mouse icon appears in the menu bar; no Dock icon.
2. Menu shows "Grant Accessibility Access…" → click → system dialog → grant in System Settings.
3. Reopen menu → "Start Mousy" appears. Start it.
4. Scrim + glass card fade in, countdown 3-2-1, Mousy runs, cursor chases.
5. ESC exits gracefully. Start again; physically move the mouse → it stops.
6. `pmset -g assertions | grep -i mousy` shows the assertion while running.

- [ ] **Step 6: Write docs/UAT.md**

```markdown
# Mousy Mousy — Manual UAT Checklist

Run after any significant change. Build via `scripts/build.sh --install`,
launch via `open "/Applications/Mousy Mousy.app"`.

## Permission flow
- [ ] Fresh state (`tccutil reset Accessibility com.chris.mousymousy`): menu shows
      "Grant Accessibility Access…"; clicking shows the system dialog.
- [ ] After granting and reopening the menu, "Start Mousy" appears.

## Session lifecycle
- [ ] Start → scrim fades in on ALL displays; glass card centered on the
      cursor's display; countdown 3…2…1.
- [ ] Hand resting on the mouse during countdown does NOT abort the session.
- [ ] After countdown: Mousy runs, cursor chases ~a third of a second behind,
      card switches to "ESC to exit" and dims after ~5 s.
- [ ] ESC exits gracefully (fade out), cursor stays where it was.
- [ ] Physically moving the mouse mid-run stops the session.
- [ ] Menu "Stop" works. Other keys (letters, space, ⌘Q) do NOT leak into the
      app that was focused before starting, and do not exit the session.

## Patterns
- [ ] Auto-cycle: pattern changes every 20–40 s with a smooth scamper between
      patterns (no cursor teleports).
- [ ] Each pinned pattern works: Circle, Star, Figure-8, Scribble, Zoomies.
- [ ] Zoomies: Mousy darts away when the cursor closes in.
- [ ] Speeds Sleepy/Normal/Frisky are visibly different.

## Staying awake
- [ ] While running: `pmset -g assertions | grep -i mousy` shows
      PreventUserIdleDisplaySleep. After stop: assertion gone.
- [ ] With a 1-minute display-sleep setting, the display stays on while running.
- [ ] Teams/Slack presence stays Active during a >5 min run.

## Safety stops
- [ ] Lock screen (Ctrl-Cmd-Q) mid-run → session stops (unlock: overlay gone).
- [ ] Close lid / sleep mid-run → stopped after wake.

## Multi-display (if available)
- [ ] Scrim covers every display; card + Mousy on the cursor's display.
- [ ] Patterns stay on the display where the session started.

## Persistence & login
- [ ] Pattern + speed selections survive an app relaunch.
- [ ] Launch at Login toggle registers (System Settings ▸ Login Items shows
      "Mousy Mousy" / "MousyMousy Dev"); survives logout/login.
- [ ] Rebuild (`scripts/build.sh --install`) → Accessibility STILL granted
      (no re-prompt) — this is the self-signed-cert guarantee.
```

- [ ] **Step 7: Write README.md**

```markdown
# Mousy Mousy 🐭

A macOS menu bar app that keeps your Mac awake by letting a little mouse run
around your screen while your cursor chases it. Circles, stars, figure-8s,
scribbles, and zoomies. Press ESC (or just move your mouse) to take back
control.

## Build (no Xcode needed — Command Line Tools only)

    ./scripts/make-cert.sh    # one-time: creates the local signing cert
    ./scripts/build.sh --install
    open "/Applications/Mousy Mousy.app"

Grant Accessibility access on first run (one-time; survives rebuilds thanks to
the stable self-signed cert).

## Develop

    swift test        # core logic tests (patterns, scheduler, engine)
    swift build       # debug build

Spec: docs/superpowers/specs/2026-07-18-mousy-mousy-design.md
Manual test checklist: docs/UAT.md
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "build: add app bundle packaging, signing scripts, UAT checklist, and readme"
```

---

## Post-plan verification (after all tasks)

- [ ] `swift test` — everything green.
- [ ] Full `docs/UAT.md` pass with the user at the machine.
- [ ] `git log --oneline` — one commit per task, conventional format.
