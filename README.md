# Mousy Mousy 🐭

A macOS menu bar app that keeps your Mac awake by letting a little mouse run
around your screen while your cursor chases it. Circles, stars, figure-8s,
scribbles, and zoomies. Press ESC to take back control.

## Build (no Xcode needed — Command Line Tools only)

    ./scripts/make-cert.sh    # one-time: creates the local signing cert
    ./scripts/build.sh --install
    open "/Applications/Mousy Mousy.app"

Grant Accessibility access on first run (one-time; survives rebuilds thanks to
the stable self-signed cert).

## Develop

    ./scripts/test.sh    # core logic tests (patterns, scheduler, engine)
    swift build          # debug build

Spec: docs/superpowers/specs/2026-07-18-mousy-mousy-design.md
Manual test checklist: docs/UAT.md
