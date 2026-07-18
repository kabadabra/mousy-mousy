import AppKit
import QuartzCore
import Observation
import MousyCore
import os.log

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
    private let log = Logger(subsystem: "com.chris.mousymousy", category: "session")

    func start(choice: PatternChoice, speed: MoveSpeed) {
        guard state == .idle, PermissionGate.isTrusted, PermissionGate.canPostEvents else { return }
        state = .countdown
        self.speed = speed.multiplier
        overlay.onEscape = { [weak self] in self?.stop(reason: "escape") }
        safety.onInterrupt = { [weak self] in self?.stop(reason: "system-interrupt") }
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
        guard let view = overlay.cardPanel?.contentView else { stop(reason: "no-overlay-view"); return }
        log.notice("beginRunning: canPostEvents=\(PermissionGate.canPostEvents, privacy: .public) bounds=\(String(describing: self.bounds), privacy: .public)")
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
           let expected = synthesizer.lastPosted {
            let actual = synthesizer.currentCocoaPosition
            if Deviation.humanMoved(expected: expected, actual: actual) {
                log.notice("deviation: expected=(\(expected.x, privacy: .public),\(expected.y, privacy: .public)) actual=(\(actual.x, privacy: .public),\(actual.y, privacy: .public)) dist=\(Geometry.distance(expected, actual), privacy: .public)")
                stop(reason: "deviation")
                return
            }
        }
        let frame = engine.tick(now: now, dt: dt, bounds: bounds, speed: speed,
                                cursor: synthesizer.currentCocoaPosition)
        self.engine = engine
        overlay.updateSprite(cocoaGlobal: frame.mousy, facingLeft: frame.facingLeft)
        synthesizer.post(cocoaPoint: frame.cursor)
    }

    func stop(reason: String = "menu") {
        guard state != .idle else { return }
        log.notice("stop(\(reason, privacy: .public)) from state \(String(describing: self.state), privacy: .public)")
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
