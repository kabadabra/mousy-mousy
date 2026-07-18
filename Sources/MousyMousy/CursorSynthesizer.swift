import AppKit
import MousyCore
import os.log

/// Posts synthetic mouse-move events. The ONLY place Cocoa coords are flipped to
/// CG top-left space. Events come from a private, tagged source so they are
/// identifiable as ours by any observer.
@MainActor
final class CursorSynthesizer {
    static let eventTag: Int64 = 0x4D6F_7573_79   // "Mousy"

    private let source: CGEventSource?
    private(set) var lastPosted: CGPoint?          // Cocoa global
    private let log = Logger(subsystem: "com.chris.mousymousy", category: "synth")
    private var postCount = 0

    init() {
        source = CGEventSource(stateID: .privateState)
        source?.userData = Self.eventTag
        if source == nil { log.error("CGEventSource(.privateState) returned nil") }
    }

    func post(cocoaPoint p: CGPoint) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cg = Geometry.cgFromCocoa(p, primaryScreenHeight: primaryHeight)
        let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                            mouseCursorPosition: cg, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
        postCount += 1
        if postCount <= 3 || event == nil {
            let readback = NSEvent.mouseLocation
            log.notice("post #\(self.postCount, privacy: .public) eventNil=\(event == nil, privacy: .public) cocoa=(\(p.x, privacy: .public),\(p.y, privacy: .public)) cg=(\(cg.x, privacy: .public),\(cg.y, privacy: .public)) readback=(\(readback.x, privacy: .public),\(readback.y, privacy: .public)) primaryH=\(primaryHeight, privacy: .public)")
        }
        lastPosted = p
    }

    /// Reading the cursor needs no permission.
    var currentCocoaPosition: CGPoint { NSEvent.mouseLocation }
}
