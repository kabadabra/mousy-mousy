import AppKit
import os.log

/// Stops the session when the system state changes under us: sleep, screens
/// sleeping, screen lock, screensaver, fast user switch. Names on the
/// DistributedNotificationCenter are undocumented-but-stable (standard in this
/// app category). Always STOP (not pause): jiggling a locked screen fights the
/// lock idle and looks like HID injection.
@MainActor
final class SafetyMonitor {
    var onInterrupt: (() -> Void)?
    private let log = Logger(subsystem: "com.chris.mousymousy", category: "safety")
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
                MainActor.assumeIsolated {
                    self?.log.notice("interrupt: didChangeScreenParameters")
                    self?.onInterrupt?()
                }
            }]
        let ws = NSWorkspace.shared.notificationCenter
        let wsNames: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ]
        workspaceTokens = wsNames.map { name in
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let firedName = note.name.rawValue
                MainActor.assumeIsolated {
                    self?.log.notice("interrupt: \(firedName, privacy: .public)")
                    self?.onInterrupt?()
                }
            }
        }
        let dnc = DistributedNotificationCenter.default()
        let dncNames = ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"]
        distributedTokens = dncNames.map { name in
            dnc.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] note in
                let firedName = note.name.rawValue
                MainActor.assumeIsolated {
                    self?.log.notice("interrupt: \(firedName, privacy: .public)")
                    self?.onInterrupt?()
                }
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
