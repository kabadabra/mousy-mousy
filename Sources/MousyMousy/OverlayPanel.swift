import AppKit

/// Borderless, non-activating, screen-saver-level panel. Becomes key WITHOUT
/// activating the app (Spotlight's trick), so ESC reaches us while the user's
/// frontmost app keeps focus appearance. Cursor input passes through.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }     // borderless panels refuse key by default
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver                     // above menu bar and Dock; cursor still composites above
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        hidesOnDeactivate = false                // NSPanel default would hide it
        isFloatingPanel = true
        animationBehavior = .none
        isReleasedWhenClosed = false
    }
}
