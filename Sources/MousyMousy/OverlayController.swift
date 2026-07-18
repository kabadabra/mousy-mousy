import AppKit
import SwiftUI
import MousyCore

/// One panel per display (scrim everywhere; card + sprite on the cursor's
/// display, which is made key for ESC capture).
@MainActor
final class OverlayController {
    let model = OverlayModel()
    var onEscape: (() -> Void)?
    private(set) var cardScreen: NSScreen?
    private(set) var cardPanel: OverlayPanel?

    private var panels: [OverlayPanel] = []
    private var panelScreens: [NSScreen] = []
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func show() {
        dismiss()
        model.reset()
        let mouse = NSEvent.mouseLocation
        let screens = NSScreen.screens
        cardScreen = screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? screens.first
        panelScreens = []
        for (index, screen) in screens.enumerated() {
            let isCard = screen == cardScreen
            let panel = OverlayPanel(screen: screen)
            panel.contentView = NSHostingView(rootView: OverlayView(
                model: model, isCardScreen: isCard, screenIndex: index))
            panel.alphaValue = 0
            if isCard {
                cardPanel = panel
                panel.makeKeyAndOrderFront(nil)   // non-activating: app stays in background
            } else {
                panel.orderFrontRegardless()
            }
            panels.append(panel)
            panelScreens.append(screen)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            panels.forEach { $0.animator().alphaValue = 1 }
        }
        installMonitors()
    }

    func dismiss() {
        removeMonitors()
        let old = panels
        panels = []
        panelScreens = []
        cardPanel = nil
        cardScreen = nil
        guard !old.isEmpty else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            old.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            Task { @MainActor in old.forEach { $0.orderOut(nil) } }
        })
    }

    func updateSprite(cocoaGlobal p: CGPoint, facingLeft: Bool) {
        guard !panelScreens.isEmpty else { return }
        let index = panelScreens.firstIndex { NSMouseInRect(p, $0.frame, false) }
            ?? model.spriteScreenIndex
        model.spriteScreenIndex = index
        model.spriteViewPosition = Geometry.viewFromCocoa(p, screenFrame: panelScreens[index].frame)
        model.facingLeft = facingLeft
    }

    private func installMonitors() {
        // Primary: our panel is key, so every keystroke arrives here. Swallow all
        // keys while the overlay is up (spec §4); ESC stops the session.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 { self?.onEscape?() }
            }
            return nil
        }
        // Backup for the edge case where another app steals key status mid-run.
        // Global monitors never see our own app's events, so both are needed.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 { self?.onEscape?() }
            }
        }
    }

    private func removeMonitors() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }
}
