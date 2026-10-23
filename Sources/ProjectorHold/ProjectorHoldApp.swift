import SwiftUI

@main
struct ProjectorHoldApp: App {
    @StateObject private var controller = HoldController()

    var body: some Scene {
        MenuBarExtra("Projector Hold", systemImage: symbol) {
            Button(controller.mode == .blank ? "Show Screen (⌃⌥⌘B)" : "Blank Screen (⌃⌥⌘B)") {
                Task { await controller.toggleBlank() }
            }
            Button(controller.mode == .frozen ? "Unfreeze (⌃⌥⌘F)" : "Freeze Picture (⌃⌥⌘F)") {
                Task { await controller.toggleFreeze() }
            }
            if let message = controller.message {
                Text(message)
            }
            if controller.needsScreenPermission {
                Button("Open Screen Recording Settings…") {
                    controller.openScreenRecordingSettings()
                }
                Button("Restart Projector Hold") {
                    controller.restart()
                }
            }
            Divider()
            Toggle("Also affect this Mac's screen", isOn: $controller.includeThisMac)
            Divider()
            Button("Quit Projector Hold") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var symbol: String {
        switch controller.mode {
        case .off: return "display"
        case .blank: return "rectangle.fill"
        case .frozen: return "pause.rectangle.fill"
        }
    }
}
