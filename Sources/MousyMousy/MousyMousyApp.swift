import SwiftUI
import MousyCore

@main
struct MousyMousyApp: App {
    @State private var controller = AppController()
    @AppStorage("patternChoice") private var patternRaw = PatternChoice.auto.rawValue
    @AppStorage("moveSpeed") private var speedRaw = MoveSpeed.normal.rawValue

    var body: some Scene {
        MenuBarExtra("Mousy Mousy", systemImage: "computermouse") {
            MenuContent(controller: controller, patternRaw: $patternRaw, speedRaw: $speedRaw)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    let controller: AppController
    @Binding var patternRaw: String
    @Binding var speedRaw: String
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        // Re-evaluated each time the menu opens; after granting Accessibility
        // in System Settings, reopen the menu to see Start.
        if PermissionGate.isTrusted {
            if controller.state == .idle {
                Button("Start Mousy") {
                    controller.start(choice: PatternChoice(rawValue: patternRaw) ?? .auto,
                                     speed: MoveSpeed(rawValue: speedRaw) ?? .normal)
                }
                .keyboardShortcut("s")
            } else {
                Button("Stop") { controller.stop() }
            }
        } else {
            Button("Grant Accessibility Access…") { PermissionGate.promptForAccess() }
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
