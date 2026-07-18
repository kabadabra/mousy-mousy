# Multi-Screen Roaming (v1.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Implementation subagents run on the **Opus** model per user preference.

**Goal:** Mousy roams across ALL displays: each pattern runs on one display, and between patterns Mousy scampers across the shared screen border to the next display, cursor in pursuit.

**Architecture:** Introduce `Arena` (a display's screen rect + inset play area) in MousyCore. `PatternScheduler` gains a multi-arena step: on every pattern switch it picks an arena; cross-arena moves route through an `ArenaRouting.waypoint` on the shared screen edge (straight legs then stay inside the two convex screen rects — cursor-safe, no dead-zone crossings). App layer renders the sprite on whichever display's overlay panel contains it. Menu gains a "Roam Displays" toggle (default on).

**Tech Stack:** unchanged (Swift 6, SwiftPM, Swift Testing via `./scripts/test.sh`).

**Spec:** §3.1 of `docs/superpowers/specs/2026-07-18-mousy-mousy-design.md` (amended alongside this plan).

## Global Constraints

- All v1 Global Constraints still apply (see `docs/superpowers/plans/2026-07-18-mousy-mousy.md`): conventional commits, never reference Claude as co-author, never push, no third-party deps, tests via `./scripts/test.sh` (never bare `swift test`), TDD for MousyCore, app-target tasks build-verified.
- Backward compatibility: the existing single-`bounds` `PatternScheduler.step` and `EngineCore.tick` signatures MUST keep working unchanged (existing tests must pass unmodified) — implement them as sugar over the arenas versions.
- Coordinates: everything stays Cocoa global; arenas carry both the full `screen` rect (routing) and the `inset` rect (pattern bounds, 80 pt margin).
- Session behavior unchanged: ESC-only exit, backdrop presets, screen-topology change still stops the session.

---

### Task 1: Arena + ArenaRouting

**Files:**
- Create: `Sources/MousyCore/Arena.swift`, `Tests/MousyCoreTests/ArenaRoutingTests.swift`

**Interfaces:**
- Produces:
  - `struct Arena: Sendable, Equatable { let screen: CGRect; let inset: CGRect }` with `init(screen:inset:)` and `init(screen:margin: CGFloat = 80)`
  - `ArenaRouting.waypoint(from: CGRect, to: CGRect) -> CGPoint` — midpoint of the shared screen edge segment; closest-point midpoint fallback for corner-touch arrangements

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/ArenaRoutingTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh`
Expected: FAIL — `cannot find 'Arena' in scope`

- [ ] **Step 3: Implement**

`Sources/MousyCore/Arena.swift`:

```swift
import CoreGraphics

/// One display's playable area: the full screen rect (for cursor-safe routing
/// between displays) and the inset rect patterns run inside.
public struct Arena: Sendable, Equatable {
    public let screen: CGRect
    public let inset: CGRect

    public init(screen: CGRect, inset: CGRect) {
        self.screen = screen
        self.inset = inset
    }

    public init(screen: CGRect, margin: CGFloat = 80) {
        self.init(screen: screen, inset: screen.insetBy(dx: margin, dy: margin))
    }
}

public enum ArenaRouting {
    /// Cursor-safe waypoint for a scamper between two screens. Screens sharing
    /// an edge get the midpoint of the shared segment — straight legs to/from
    /// it stay inside the two convex screen rects, so neither Mousy nor the
    /// cursor ever crosses a dead zone. Corner-touch arrangements fall back to
    /// the midpoint of the closest-point pair (best effort).
    public static func waypoint(from a: CGRect, to b: CGRect) -> CGPoint {
        let tol: CGFloat = 1
        // Vertical shared edge (side-by-side).
        if abs(a.maxX - b.minX) <= tol || abs(b.maxX - a.minX) <= tol {
            let x = abs(a.maxX - b.minX) <= tol ? (a.maxX + b.minX) / 2 : (b.maxX + a.minX) / 2
            let lo = max(a.minY, b.minY), hi = min(a.maxY, b.maxY)
            if hi > lo { return CGPoint(x: x, y: (lo + hi) / 2) }
        }
        // Horizontal shared edge (stacked).
        if abs(a.maxY - b.minY) <= tol || abs(b.maxY - a.minY) <= tol {
            let y = abs(a.maxY - b.minY) <= tol ? (a.maxY + b.minY) / 2 : (b.maxY + a.minY) / 2
            let lo = max(a.minX, b.minX), hi = min(a.maxX, b.maxX)
            if hi > lo { return CGPoint(x: (lo + hi) / 2, y: y) }
        }
        // Fallback: midpoint of the closest-point pair.
        let pa = CGPoint(x: min(max(b.midX, a.minX), a.maxX),
                         y: min(max(b.midY, a.minY), a.maxY))
        let pb = CGPoint(x: min(max(pa.x, b.minX), b.maxX),
                         y: min(max(pa.y, b.minY), b.maxY))
        return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh`
Expected: PASS (all existing + 6 new)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add arena model and cross-display waypoint routing"
```

---

### Task 2: Multi-arena PatternScheduler

**Files:**
- Modify: `Sources/MousyCore/PatternScheduler.swift`
- Create: `Tests/MousyCoreTests/RoamingSchedulerTests.swift`

**Interfaces:**
- Consumes: `Arena`, `ArenaRouting.waypoint`, `TransitPattern`, `PatternKind`
- Produces (existing members unchanged; existing `step(now:dt:bounds:speed:cursor:)` keeps identical behavior as sugar):
  - `mutating func step(now: TimeInterval, dt: TimeInterval, arenas: [Arena], speed: Double, cursor: CGPoint) -> CGPoint`
  - `private(set) var currentArenaIndex: Int`
  - `static func pickArena(count: Int, using rng: inout SeededRNG) -> Int`
- Behavior: pattern switches happen in autoCycle mode (as today) AND in fixed mode when `arenas.count > 1` (same kind restarts on a possibly different display). Cross-arena switches queue TWO transit legs: current → waypoint(screenA, screenB) → new pattern's start. Same-arena switches keep the single-leg transit. Continuity (< 30 pt/frame at 60 fps) must hold across everything.

- [ ] **Step 1: Write the failing tests**

`Tests/MousyCoreTests/RoamingSchedulerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh`
Expected: FAIL — `no exact matches in call to instance method 'step'` (arenas overload missing)

- [ ] **Step 3: Implement**

Replace `Sources/MousyCore/PatternScheduler.swift` with:

```swift
import CoreGraphics
import Foundation

/// Owns the current pattern and, with multiple arenas, which display it runs
/// on. Switches on a 20–40 s cadence (auto-cycle always; fixed mode only when
/// roaming across >1 arena). Every switch is bridged by transit legs so Mousy
/// never teleports; cross-display legs route through the shared screen edge.
public struct PatternScheduler: Sendable {
    public enum Mode: Sendable, Equatable {
        case autoCycle
        case fixed(PatternKind)
    }

    private var rng: SeededRNG
    private let mode: Mode
    private var current: (any MousePattern)?
    private var transits: [TransitPattern] = []
    private var switchAt: TimeInterval = 0
    private var lastPoint: CGPoint?
    public private(set) var currentKind: PatternKind?
    public private(set) var currentArenaIndex: Int = 0

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

    public static func pickArena(count: Int, using rng: inout SeededRNG) -> Int {
        Int.random(in: 0..<count, using: &rng)
    }

    /// v1 sugar: a single rect used directly as the pattern bounds.
    public mutating func step(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> CGPoint {
        step(now: now, dt: dt, arenas: [Arena(screen: bounds, inset: bounds)],
             speed: speed, cursor: cursor)
    }

    public mutating func step(now: TimeInterval, dt: TimeInterval, arenas: [Arena],
                              speed: Double, cursor: CGPoint) -> CGPoint {
        let arena = arenas[min(currentArenaIndex, arenas.count - 1)]
        // Mid-transit: keep scampering through the queued legs.
        if var t = transits.first {
            let p = t.step(dt: dt, bounds: arena.inset, speed: speed, cursor: cursor)
            if t.isFinished { transits.removeFirst() } else { transits[0] = t }
            lastPoint = p
            return p
        }
        // Time to pick a pattern? First call, auto-cycle expiry, or roam hop.
        let switching = mode == .autoCycle || arenas.count > 1
        if current == nil || (switching && now >= switchAt) {
            let kind: PatternKind
            switch mode {
            case .fixed(let k): kind = k
            case .autoCycle: kind = Self.pickNext(excluding: currentKind, using: &rng)
            }
            let fromIndex = currentArenaIndex
            let toIndex = arenas.count > 1 ? Self.pickArena(count: arenas.count, using: &rng)
                                           : 0
            let toArena = arenas[toIndex]
            let pattern = kind.makePattern(seed: rng.next())
            currentKind = kind
            current = pattern
            currentArenaIndex = toIndex
            switchAt = now + Self.nextDuration(using: &rng)

            let from = lastPoint ?? cursor
            let start = pattern.startPoint(in: toArena.inset)
            if toIndex != fromIndex {
                let w = ArenaRouting.waypoint(from: arenas[fromIndex].screen,
                                              to: toArena.screen)
                transits = [TransitPattern(from: from, to: w),
                            TransitPattern(from: w, to: start)]
            } else {
                transits = [TransitPattern(from: from, to: start)]
            }
            var t = transits[0]
            let p = t.step(dt: dt, bounds: toArena.inset, speed: speed, cursor: cursor)
            if t.isFinished { transits.removeFirst() } else { transits[0] = t }
            lastPoint = p
            return p
        }
        // Normal pattern stepping in the current arena.
        var c = current!
        let p = c.step(dt: dt, bounds: arena.inset, speed: speed, cursor: cursor)
        current = c
        lastPoint = p
        return p
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh`
Expected: PASS — all new tests AND the untouched v1 `SchedulerTests.swift` (behavior-compatibility gate)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: teach pattern scheduler to roam across display arenas"
```

---

### Task 3: EngineCore arenas passthrough

**Files:**
- Modify: `Sources/MousyCore/EngineCore.swift`
- Create: `Tests/MousyCoreTests/RoamingEngineTests.swift`

**Interfaces:**
- Consumes: `PatternScheduler.step(now:dt:arenas:speed:cursor:)`
- Produces: `mutating func tick(now: TimeInterval, dt: TimeInterval, arenas: [Arena], speed: Double, cursor: CGPoint) -> Frame` (existing `tick(now:dt:bounds:speed:cursor:)` becomes sugar delegating to it; identical behavior)

- [ ] **Step 1: Write the failing test**

`Tests/MousyCoreTests/RoamingEngineTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./scripts/test.sh`
Expected: FAIL — `no exact matches in call to instance method 'tick'`

- [ ] **Step 3: Implement**

In `Sources/MousyCore/EngineCore.swift`, replace the existing `tick` with the pair:

```swift
    /// v1 sugar: a single rect used directly as the pattern bounds.
    public mutating func tick(now: TimeInterval, dt: TimeInterval, bounds: CGRect,
                              speed: Double, cursor: CGPoint) -> Frame {
        tick(now: now, dt: dt, arenas: [Arena(screen: bounds, inset: bounds)],
             speed: speed, cursor: cursor)
    }

    public mutating func tick(now: TimeInterval, dt: TimeInterval, arenas: [Arena],
                              speed: Double, cursor: CGPoint) -> Frame {
        let mousy = scheduler.step(now: now, dt: dt, arenas: arenas, speed: speed, cursor: cursor)
        trail.append(time: now, point: mousy)
        let target = trail.sample(at: now - cursorLag) ?? mousy
        if let lx = lastMousyX, abs(mousy.x - lx) > 0.5 { facingLeft = mousy.x < lx }
        lastMousyX = mousy.x
        return Frame(mousy: mousy, cursor: target, facingLeft: facingLeft)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh`
Expected: PASS (all, including untouched v1 `EngineCoreTests.swift`)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: engine core ticks across display arenas"
```

---

### Task 4: App wiring — roam toggle, cross-panel sprite

**Files:**
- Modify: `Sources/MousyMousy/AppController.swift`, `Sources/MousyMousy/OverlayController.swift`, `Sources/MousyMousy/OverlayModel.swift`, `Sources/MousyMousy/OverlayView.swift`, `Sources/MousyMousy/MousyMousyApp.swift`

**Interfaces:**
- Consumes: `EngineCore.tick(arenas:)`, `Arena(screen:margin:)`
- Produces: `AppController.start(choice:speed:backdrop:roam: Bool)`; `OverlayModel.spriteScreenIndex: Int`; `OverlayView(model:isCardScreen:screenIndex:)`; `OverlayController.updateSprite` resolves which panel shows the sprite; menu Toggle "Roam Displays" persisted at `@AppStorage("roamDisplays")` default `true`
- No unit tests (visual layer); gate is `swift build` + full core suite + manual smoke.

- [ ] **Step 1: OverlayModel — track the sprite's display**

Add below `var scrimOpacity`:

```swift
    var spriteScreenIndex = 0                    // which panel renders the sprite
```

and in `reset()` add:

```swift
        spriteScreenIndex = 0
```

- [ ] **Step 2: OverlayView — render sprite on its panel, not only the card's**

Replace the `OverlayView` struct with:

```swift
struct OverlayView: View {
    let model: OverlayModel
    let isCardScreen: Bool
    let screenIndex: Int

    var body: some View {
        ZStack {
            Color.black.opacity(model.scrimOpacity).ignoresSafeArea()
            if isCardScreen {
                EscCardView(model: model)
            }
            if model.showSprite && model.spriteScreenIndex == screenIndex {
                MousySpriteView(model: model)
            }
        }
    }
}
```

- [ ] **Step 3: OverlayController — per-panel screens and sprite routing**

Add a stored property next to `panels`:

```swift
    private var panelScreens: [NSScreen] = []
```

In `show()`, replace the `for screen in screens` loop header block so each panel records its screen and index (the only changes: capture `index`, pass `screenIndex`, append to `panelScreens`):

```swift
        panelScreens = []
        for (index, screen) in screens.enumerated() {
            let isCard = screen == cardScreen
            let panel = OverlayPanel(screen: screen)
            panel.contentView = NSHostingView(rootView: OverlayView(
                model: model, isCardScreen: isCard, screenIndex: index))
            panel.alphaValue = 0
            if isCard {
                cardPanel = panel
                panel.makeKeyAndOrderFront(nil)   // non-activating: app stays in background
            } else {
                panel.orderFrontRegardless()
            }
            panels.append(panel)
            panelScreens.append(screen)
        }
```

In `dismiss()`, also clear it: add `panelScreens = []` next to `panels = []`.

Replace `updateSprite` with:

```swift
    func updateSprite(cocoaGlobal p: CGPoint, facingLeft: Bool) {
        guard !panelScreens.isEmpty else { return }
        let index = panelScreens.firstIndex { NSMouseInRect(p, $0.frame, false) }
            ?? model.spriteScreenIndex
        model.spriteScreenIndex = index
        model.spriteViewPosition = Geometry.viewFromCocoa(p, screenFrame: panelScreens[index].frame)
        model.facingLeft = facingLeft
    }
```

- [ ] **Step 4: AppController — arenas + roam parameter**

Change the stored property `private var bounds: CGRect = .zero` to:

```swift
    private var arenas: [Arena] = []
```

Change `start` signature and the bounds line:

```swift
    func start(choice: PatternChoice, speed: MoveSpeed, backdrop: BackdropStyle, roam: Bool) {
```

and replace the `bounds = ...` line with:

```swift
        // Roaming: every display is an arena; otherwise just the card screen.
        let screens = NSScreen.screens
        if roam && screens.count > 1 {
            arenas = screens.map { Arena(screen: $0.frame) }
        } else {
            arenas = [Arena(screen: overlay.cardScreen?.frame ?? .zero)]
        }
```

In `beginRunning()`, update the log line to describe arenas:

```swift
        log.notice("beginRunning: canPostEvents=\(PermissionGate.canPostEvents, privacy: .public) arenas=\(self.arenas.count, privacy: .public)")
```

In `tick`, replace the engine call:

```swift
        let frame = engine.tick(now: now, dt: dt, arenas: arenas, speed: speed,
                                cursor: synthesizer.currentCocoaPosition)
```

- [ ] **Step 5: Menu — Roam Displays toggle**

`MousyMousyApp`: add alongside the other `@AppStorage` properties:

```swift
    @AppStorage("roamDisplays") private var roamDisplays = true
```

pass it into `MenuContent` (add `roamDisplays: $roamDisplays` to the call and a matching `@Binding var roamDisplays: Bool` property), extend the Start action:

```swift
                controller.start(choice: PatternChoice(rawValue: patternRaw) ?? .auto,
                                 speed: MoveSpeed(rawValue: speedRaw) ?? .normal,
                                 backdrop: BackdropStyle(rawValue: backdropRaw) ?? .subtle,
                                 roam: roamDisplays)
```

and add after the Backdrop picker:

```swift
        Toggle("Roam Displays", isOn: $roamDisplays)
```

- [ ] **Step 6: Verify build + suite**

Run: `swift build && ./scripts/test.sh`
Expected: `Build complete!`, all core tests PASS

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: roam displays toggle with cross-panel sprite rendering"
```

---

### Task 5: Docs, version, release

**Files:**
- Modify: `README.md`, `docs/UAT.md`, `docs/superpowers/specs/2026-07-18-mousy-mousy-design.md` (§3.1 already amended alongside this plan), `Support/Info.plist`

- [ ] **Step 1: README** — in the Use section, add after the Backdrop bullet:

```markdown
- **Roam Displays** — with more than one screen, Mousy runs a pattern on one
  display, then scampers across the border to another. Turn off to keep the
  session on the display where it started.
```

- [ ] **Step 2: UAT** — replace the Multi-display section with:

```markdown
## Multi-display (if available)
- [ ] Scrim covers every display; card on the display where the session started.
- [ ] Roam Displays ON: Mousy crosses to the other display within a few pattern
      switches; the sprite renders on whichever display it occupies; the cursor
      follows across the border with no teleports.
- [ ] Roam Displays OFF: patterns stay on the starting display for the whole
      session.
```

- [ ] **Step 3: Version bump** — `Support/Info.plist`: `CFBundleShortVersionString` → `1.1.0`, `CFBundleVersion` → `3`.

- [ ] **Step 4: Commit + release**

```bash
git add -A && git commit -m "docs: document display roaming; bump to 1.1.0"
./scripts/release.sh v1.1.0 --publish    # OFF GlobalProtect VPN (stapling)
```

Then install locally (`./scripts/build.sh --install`, relaunch) and run the Multi-display UAT section with the user.

---

## Post-plan verification

- [ ] `./scripts/test.sh` fully green (v1 tests untouched and passing — behavior-compat gate).
- [ ] Manual: roam on/off both behave per UAT on the user's two-display setup.
