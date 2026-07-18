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
        // Swift 6 strict concurrency rejects reading the imported C global
        // `kAXTrustedCheckOptionPrompt` (non-Sendable mutable var); its value is
        // the stable CFString "AXTrustedCheckOptionPrompt", used here directly.
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
