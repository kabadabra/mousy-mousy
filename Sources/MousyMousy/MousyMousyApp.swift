import SwiftUI
import MousyCore

@main
struct MousyMousyApp: App {
    @State private var controller = AppController()
    @AppStorage("patternChoice") private var patternRaw = PatternChoice.auto.rawValue
    @AppStorage("moveSpeed") private var speedRaw = MoveSpeed.normal.rawValue
    @AppStorage("backdrop") private var backdropRaw = BackdropStyle.subtle.rawValue

    var body: some Scene {
        MenuBarExtra("Mousy Mousy", systemImage: "computermouse") {
            MenuContent(controller: controller, patternRaw: $patternRaw,
                        speedRaw: $speedRaw, backdropRaw: $backdropRaw)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    let controller: AppController
    @Binding var patternRaw: String
    @Binding var speedRaw: String
    @Binding var backdropRaw: String
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        // Re-evaluated each time the menu opens; after granting Accessibility
        // in System Settings, reopen the menu to see Start.
        if !PermissionGate.isTrusted {
            Button("Grant Accessibility Access…") { PermissionGate.promptForAccess() }
        } else if !PermissionGate.canPostEvents {
            // AX-trusted, but event-post rights lag the grant until the app is
            // relaunched (see PermissionGate.canPostEvents). AppController.start()
            // also guards on canPostEvents, so a "Start Mousy" click would
            // silently no-op here — surface the relaunch hint instead (spec §9).
            Button("Relaunch Mousy Mousy to finish setup") {}
                .disabled(true)
        } else if controller.state == .idle {
            Button("Start Mousy") {
                controller.start(choice: PatternChoice(rawValue: patternRaw) ?? .auto,
                                 speed: MoveSpeed(rawValue: speedRaw) ?? .normal,
                                 backdrop: BackdropStyle(rawValue: backdropRaw) ?? .subtle)
            }
            .keyboardShortcut("s")
        } else {
            Button("Stop") { controller.stop() }
        }
        Divider()
        Picker("Pattern", selection: $patternRaw) {
            ForEach(PatternChoice.allCases, id: \.rawValue) { c in
                Text(c.displayName).tag(c.rawValue)
            }
        }
        Picker("Speed", selection: $speedRaw) {
            ForEach(MoveSpeed.allCases, id: \.rawValue) { s in
                Text(s.displayName).tag(s.rawValue)
            }
        }
        Picker("Backdrop", selection: $backdropRaw) {
            ForEach(BackdropStyle.allCases, id: \.rawValue) { b in
                Text(b.displayName).tag(b.rawValue)
            }
        }
        Divider()
        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { on in
                try? LaunchAtLogin.set(on)
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        ))
        Divider()
        Button("Quit Mousy Mousy") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
