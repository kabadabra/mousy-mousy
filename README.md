# Mousy Mousy 🐭

**Keep your Mac awake and active while long-running tasks finish in the
background.** AI coding sessions, builds, big downloads, deploys — anything
that dies or disconnects when your machine dozes off. Instead of a boring
jiggler, a little mouse runs around your screen and your cursor chases it:
circles, stars, figure-8s, scribbles, and zoomies. Press **ESC** to take back
control.

While a session runs, Mousy Mousy keeps two channels covered:

- **The machine**: an IOKit power assertion stops the display and system from
  sleeping (the same mechanism as Amphetamine/KeepingYouAwake).
- **Your software**: real synthetic mouse events reset the system idle
  counters, so presence indicators and idle-watching apps see you as active.

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon
- Accessibility permission (one-time prompt on first run — it's how the app is
  allowed to move your cursor)

## Install

### Download (precompiled)

1. Grab the latest `MousyMousy-vX.Y.Z.zip` from
   [Releases](../../releases), unzip, and drag **Mousy Mousy.app** into
   `/Applications`.
2. Because releases are not notarized by Apple, the first launch is blocked by
   Gatekeeper: open **System Settings ▸ Privacy & Security**, scroll down, and
   click **Open Anyway** next to Mousy Mousy (macOS Sequoia and later removed
   the right-click-Open shortcut). This is needed once.
3. Launch it, then grant Accessibility access from the menu bar mouse icon.

### Build from source (no Xcode needed)

Only the Command Line Tools are required:

    ./scripts/make-cert.sh    # one-time fallback signing cert (skipped
                              # automatically if you have an Apple Development
                              # identity in your keychain)
    ./scripts/build.sh --install
    open "/Applications/Mousy Mousy.app"

Grant Accessibility access on first run. The grant survives rebuilds — the
build is always signed with a stable identity, never ad-hoc.

## Use

Everything lives in the menu bar mouse icon:

- **Start Mousy** — a glass card counts down 3…2…1, then Mousy takes off with
  your cursor in pursuit.
- **Pattern** — Auto-cycle (default, shuffles every 20–40 s) or pin Circle,
  Star, Figure-8, Scribble, or Zoomies (Mousy darts away whenever the cursor
  gets close).
- **Speed** — Sleepy, Normal, or Frisky.
- **Backdrop** — Subtle keeps your desktop visible; Dim and Dark act as a
  night/privacy mode that hides what's on screen while you're away. (Honesty
  note: on OLED and mini-LED displays the dark modes also save real energy;
  on regular LCD monitors the backlight burns the same watts either way.)
- **Exit** — press **ESC**, pick Stop from the menu, or lock/sleep the
  machine. Moving your physical mouse does *not* end the session; Mousy
  just retakes the wheel.
- **Launch at Login** — optional toggle.

## Privacy

Mousy Mousy needs exactly one permission — Accessibility — to post cursor
events. It reads nothing, records nothing, and makes no network connections.

## Develop

    ./scripts/test.sh       # core logic tests (patterns, scheduler, engine)
    swift build             # debug build
    ./scripts/make-icon.sh  # regenerate the app icon
    ./scripts/release.sh v1.0.1 [--publish]   # zip a release (and publish via gh)

Bump `CFBundleShortVersionString`/`CFBundleVersion` in `Support/Info.plist`
when tagging a release.

Design spec: `docs/superpowers/specs/2026-07-18-mousy-mousy-design.md`
Manual test checklist: `docs/UAT.md`
