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
