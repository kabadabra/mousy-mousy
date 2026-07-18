# Mousy Mousy — Design Spec

Date: 2026-07-18
Status: Approved by Chris (design review, this date)
Replaces: `~/mouse_mover.js` (JXA script that teleported the cursor randomly every 1.5 s)

## 1. What it is

Mousy Mousy is a macOS menu bar app that keeps the Mac awake and the user "active" by
moving the cursor. Instead of sporadic teleports, a little mouse critter (🐭, "Mousy")
runs around the screen and the real cursor chases it along patterned routes. While
active, a full-screen overlay shows a Liquid Glass card: press **ESC** to exit.

Personal-use app for Chris's machine (macOS 26.5, Apple Silicon). Not sandboxed, not
notarized, not App Store.

## 2. Goals and non-goals

Goals (v1):

- Menu bar only (no Dock icon), start/stop mouse-move mode from the menu.
- Cursor follows Mousy through five patterns at three speeds.
- Glass "ESC" card + dimming scrim overlay while active, with a 3-2-1 countdown
  before movement starts.
- Machine stays awake (display + system) and software presence detectors
  (Teams-style idle watchers) see activity.
- Instant, graceful exit on ESC, screen lock/sleep/fast user switch, or menu
  Stop. (Changed after v1 hands-on: physical mouse input does NOT end the
  session — the original mouse-movement exit tripped on residual hand contact.)
- Launch-at-login toggle.
- Accessibility permission survives rebuilds (stable signing identity).

Non-goals (v1) — parked for later:

- Custom app icon artwork (SF Symbol / emoji in menu bar is fine).
- Notarized distribution to other machines.
- Timers/scheduling ("keep awake for 2 h").
- Keypress simulation (the old script's spacebar feature — deliberately dropped:
  cursor events already reset the idle channels that matter, and synthetic
  keypresses can type into focused apps).
- Pattern hopping across multiple displays (patterns run on the display the cursor
  is on when mode starts; scrim covers all displays).

## 3. Concept: Mousy always leads

The unifying design decision: **Mousy is always on screen leading; the cursor always
chases.** Patterns are just the routes Mousy takes. The cursor samples Mousy's path
~0.35 s in the past, so it visibly trails without catching up. This makes the
"cursor chases a mouse" idea the whole app rather than a bolted-on easter egg.

### Patterns

Each pattern runs 20–40 s (randomized), then Mousy scampers (smooth transit, not a
teleport) to the next pattern's starting point. Default mode is **Auto-cycle**
(shuffled order, no immediate repeats); any single pattern can be pinned from the menu.

| Pattern  | Route |
|----------|-------|
| Circle   | Large circle centered on screen, radius ~35 % of the smaller screen dimension |
| Star     | Five-point star path, traversed point-to-point |
| Figure-8 | Lissajous a=1 b=2 curve |
| Scribble | Smooth random walk (low-frequency noise steering; stays inside a margin) |
| Zoomies  | Free-roam wander; when the cursor gets within ~120 pt Mousy darts away on a new heading. Never caught. |

Speeds: **Sleepy**, **Normal**, **Frisky** — a multiplier on path traversal speed
(and dart intensity for Zoomies).

All pattern math is pure: `f(t, bounds, speed) → point` (Scribble/Zoomies carry
their own state stepped by `dt`). Pure functions make the geometry unit-testable
without a display.

## 4. UX flow

1. Menu bar icon: mouse SF Symbol (template image so it adapts to menu bar tint).
2. Menu (SwiftUI `MenuBarExtra`, `.menu` style):
   - **Start Mousy** (keyboard shortcut ⌘S while menu open) / **Stop** while running
   - **Pattern ▸** Auto-cycle (default) · Circle · Star · Figure-8 · Scribble · Zoomies
   - **Speed ▸** Sleepy · Normal · Frisky
   - **Launch at Login** (toggle)
   - **Quit** (⌘Q)
   - If Accessibility isn't granted, the menu shows **"Grant Accessibility Access…"**
     instead of Start (see §7).
3. On Start: scrim (black at ~12 % opacity) fades in over **all** displays; the glass
   card appears centered on the display containing the cursor.
4. Card shows **"Starting in 3… 2… 1"** — a moment to take your hand off the
   mouse before Mousy takes over.
5. Patterns run. Card shows an escape-key glyph + **"ESC to exit"**, and after ~5 s
   fades to ~35 % opacity so it doesn't dominate the screen.
6. Exit triggers (any → graceful fade-out of overlay, cursor left where it is):
   - **ESC** key
   - Screen lock, screensaver, system/display sleep, fast user switch
   - **Stop** from the menu
   - Non-ESC keys are swallowed by the overlay and ignored (the overlay panel is the
     key window while mode is active; session ends only via the triggers above).

## 5. Architecture

Hybrid SwiftUI/AppKit, single SwiftPM executable target, macOS 26-only
(`platforms: [.macOS(.v26)]` — no availability fallbacks needed).

```
MousyMousyApp (SwiftUI @main, MenuBarExtra)
 └─ AppController (state machine, owns everything below)
     ├─ PermissionGate       AX prompt + preflight polling
     ├─ OverlayController    NSPanel per screen + ESC monitors
     │   └─ OverlayView      scrim + EscCardView (glass) + MousySpriteView
     ├─ PatternEngine        CADisplayLink tick → Mousy pos + cursor target
     │   └─ Pattern (protocol) + 5 implementations
     ├─ CursorSynthesizer    CGEvent posting, coordinate conversion
     ├─ WakeGuard            IOPM assertions + user-activity declarations
     ├─ SafetyMonitor        deviation check + lock/sleep/session observers
     ├─ Settings             @AppStorage-backed (pattern, speed)
     └─ LaunchAtLogin        SMAppService.mainApp wrapper
```

`AppController` states: `idle → countdown → running → stopping → idle`. All
transitions on the main actor.

### 5.1 Overlay windows

One `NSPanel` subclass per `NSScreen`, built fresh on every session start. If
`NSApplication.didChangeScreenParametersNotification` fires mid-run, the session
stops gracefully (a topology change implies a human is present — simpler and
safer than rebuilding panels live):

- `styleMask: [.borderless, .nonactivatingPanel]` — becomes key **without
  activating the app**, so the user's frontmost app keeps focus appearance
  (Spotlight's trick).
- `canBecomeKey` overridden → `true` (borderless windows refuse key by default).
- `level = .screenSaver` (above menu bar and Dock; the hardware cursor always
  composites above every window level, so the cursor stays visible).
- `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`,
  `ignoresMouseEvents = true`, `hidesOnDeactivate = false`,
  `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- Content: `NSHostingView(rootView: OverlayView(...))`.

The panel on the cursor's display gets the card + Mousy sprite and is made key
(`makeKeyAndOrderFront`); other displays get scrim-only panels.

### 5.2 ESC capture

- Primary: `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` — the key panel
  receives all keystrokes; monitor swallows ESC (keyCode 53) → stop; swallows and
  ignores everything else. Zero permissions.
- Backup: `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` for the edge case
  where another app steals key status mid-run (global monitors never see your own
  app's events, so both are needed; key monitoring rides on the Accessibility grant
  the app already has).
- No CGEventTap anywhere (a listen-only keyboard tap would demand a second TCC
  prompt for Input Monitoring).

### 5.3 Glass card

SwiftUI, real Liquid Glass: `.glassEffect(.regular, in: .rect(cornerRadius: 28))`.
Glass samples **in-window** content on macOS, so the full-screen 12 % scrim behind it
is load-bearing — without it the card sits on a fully transparent window and renders
flat. (The scrim also visually signals "mode is active".) No `GlassEffectContainer`
needed for a single card.

### 5.4 Animation and movement

- One clock: `contentView.displayLink(target:selector:)` → `CADisplayLink`
  (macOS 14+ API; ProMotion-aware; CVDisplayLink is deprecated). Added to `.main`
  run loop, `.common` modes.
- Each tick at `targetTimestamp`: compute Mousy's position `f(t)`, render sprite
  (SwiftUI `Canvas` / positioned `Text("🐭")`, flipped horizontally to face travel
  direction); compute cursor target `f(t − 0.35)`; post cursor event.
- Cursor posting: `CGEvent(mouseEventSource: src, mouseType: .mouseMoved,
  mouseCursorPosition: p, mouseButton: .left).post(tap: .cghidEventTap)` where
  `src = CGEventSource(stateID: .privateState)` with a magic `userData` tag
  (`0x4D6F757379`, "Mousy") so our events are identifiable by any observer.
  `CGWarpMouseCursorPosition` is rejected: it emits no events, so apps and idle
  counters never see the movement.
- Coordinates: pattern math and sprite run in Cocoa global space (bottom-left
  origin); `CursorSynthesizer` is the **only** place that flips to CG top-left
  space: `cg.y = NSScreen.screens[0].frame.height − cocoa.y` (flip about the
  *primary* screen height; x shared; secondaries may be negative in both spaces).

### 5.5 Staying awake (belt and braces)

Synthetic CGEvents keep *software* happy (they reset
`CGEventSource.secondsSinceLastEventType` idle counters that presence detectors
read) but are **not** reliable against display sleep on modern macOS. So while
running, `WakeGuard` also:

- holds a `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertion
  (created on start, released on stop and on `willSleep`), and
- calls `IOPMAssertionDeclareUserActivity(..., kIOPMUserActiveLocal, &id)` every
  ~30 s (reusing the assertion ID).

This is the shipping pattern from Jiggler/KeepingYouAwake. Verifiable via
`pmset -g assertions`. Assertions do not (and should not) block lid-close sleep.

### 5.6 Safety monitor

- Physical mouse input does not stop the session (v1 hands-on change: a
  deviation-based auto-stop proved too trigger-happy — residual hand contact
  at arm time ended sessions — and was removed in favor of ESC-only).
- **Lock/sleep/session observers** → immediate stop:
  - `NSWorkspace`: `willSleepNotification`, `screensDidSleepNotification`,
    `sessionDidResignActiveNotification`
  - `DistributedNotificationCenter`: `com.apple.screenIsLocked`,
    `com.apple.screensaver.didstart` (undocumented-but-stable names, standard in
    this app category)
  - Rationale: jiggling a locked screen fights the lock idle and looks like HID
    injection; always stop (not pause-and-resume — user re-starts from the menu).

## 6. Settings & persistence

`@AppStorage` (UserDefaults): selected pattern (default Auto-cycle), speed (default
Normal). Launch-at-login state is owned by `SMAppService.mainApp.status`, not
duplicated in defaults. No other persisted state.

## 7. Permission flow (Accessibility, exactly one grant)

1. On Start (or app launch), check `AXIsProcessTrusted()` /
   `CGPreflightPostEventAccess()`.
2. If not granted: menu shows "Grant Accessibility Access…" → triggers
   `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` (system
   dialog with a deep link to System Settings ▸ Privacy & Security ▸ Accessibility).
3. Poll `CGPreflightPostEventAccess()` every ~2 s while ungranted; when it flips,
   enable Start. If posting still fails after grant, suggest an app relaunch (post
   rights are checked per WindowServer connection).
4. Sandboxing is off (required for CGEvent posting). The Accessibility toggle also
   covers the PostEvent and ListenEvent TCC buckets — no Input Monitoring prompt.

## 8. Build, signing, packaging (no Xcode — CLT only)

- `Package.swift`: swift-tools-version 6.2+, single `executableTarget`, platform
  `.macOS(.v26)`.
- `scripts/make-cert.sh` (one-time): create self-signed code-signing cert
  **"MousyMousy Dev"** (openssl → p12 with `-legacy` → `security import` into login
  keychain → user sets "Always Trust" for Code Signing in Keychain Access).
  **Why this matters:** TCC stores the app's designated requirement; ad-hoc
  signatures degenerate to a per-build cdhash, so the Accessibility grant silently
  dies on every rebuild. A stable cert gives
  `identifier "com.chris.mousymousy" and certificate leaf = H"…"` — grants survive
  rebuilds indefinitely. (macOS 26 also gates event synthesis more strictly for
  ad-hoc-signed processes, and `SMAppService` registration fails with pure ad-hoc
  signing — the cert fixes all three.)
- `scripts/build.sh`: `swift build -c release` → assemble
  `dist/Mousy Mousy.app/Contents/{MacOS/MousyMousy, Info.plist, Resources}` →
  `codesign --force --sign "MousyMousy Dev"` → optional `--install` copies to
  `/Applications/Mousy Mousy.app` (stable path; keeps TCC rows and login-item
  registration valid; never launch the bare binary — always via `open`/Finder so
  TCC attributes the grant to the app, not the terminal).
- `Support/Info.plist`: `CFBundleIdentifier com.chris.mousymousy` (stable forever),
  `LSUIElement true`, `CFBundlePackageType APPL`, `LSMinimumSystemVersion 26.0`,
  name/executable/version keys.
- Launch at login: `SMAppService.mainApp.register()/unregister()`; surface
  `.requiresApproval` by deep-linking `SMAppService.openSystemSettingsLoginItems()`.

## 9. Error handling

| Failure | Behavior |
|---------|----------|
| Accessibility not granted | Start disabled; menu shows grant flow (§7) |
| CGEvent post fails after grant | Stop mode, menu hint to relaunch app |
| Display config changes mid-run | Stop gracefully (panels are rebuilt fresh on every start) |
| `SMAppService` registration error | Toggle reverts; menu item shows "needs approval" state with settings deep-link |
| IOPM assertion create fails | Non-fatal: log, continue (CGEvents still cover presence) |

## 10. Testing

- **Unit (`swift test`)**: pattern geometry (points stay in bounds, continuity/no
  teleports between ticks, star vertex order, Zoomies dart trigger), Cocoa↔CG
  coordinate flip (multi-display fixtures incl. negative-origin secondaries),
  auto-cycle shuffle (no immediate repeats).
- **Manual UAT checklist** (committed as `docs/UAT.md`): permission first-run flow;
  each exit trigger;
  card legibility + fade; multi-display scrim; lock-screen stop; `pmset -g
  assertions` shows the assertion while running and not after; presence check
  (system idle time resets while running); launch at login; rebuild → permission
  still valid.

## 11. Development process

- Repo: `~/app-dev/mousy-mousy`, git, conventional commits.
- Implementation executed by **Opus-model subagents** from a written plan
  (superpowers writing-plans → subagent-driven development), TDD where the seam is
  testable (pattern math, coordinates, state machine).
