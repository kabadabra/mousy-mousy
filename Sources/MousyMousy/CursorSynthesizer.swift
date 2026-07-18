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
