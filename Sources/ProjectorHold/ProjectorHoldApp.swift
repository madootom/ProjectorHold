import SwiftUI

enum Links {
    /// Where "Support Projector Hold" goes. Swap in the Lemon Squeezy or Gumroad link when it exists.
    static let support = URL(string: "https://melvinardra.com")!
}

@main
struct ProjectorHoldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: appDelegate.controller, showWelcome: appDelegate.showWelcome)
        } label: {
            MenuIcon(controller: appDelegate.controller)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = HoldController()
    private lazy var welcome = WelcomeWindow(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: WelcomeWindow.seenKey) || defaults.bool(forKey: WelcomeWindow.reopenKey) {
            defaults.set(false, forKey: WelcomeWindow.reopenKey)
            showWelcome()
        }
    }

    func showWelcome() {
        welcome.show()
    }
}

private struct MenuIcon: View {
    @ObservedObject var controller: HoldController

    var body: some View {
        switch controller.mode {
        case .off: Image(systemName: "display")
        case .blank: Image(systemName: "rectangle.fill")
        case .frozen: Image(systemName: "pause.rectangle.fill")
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var controller: HoldController
    let showWelcome: () -> Void

    var body: some View {
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
        Button("Show Welcome Guide") {
            showWelcome()
        }
        Button("Support Projector Hold ♥") {
            NSWorkspace.shared.open(Links.support)
        }
        Divider()
        Button("Quit Projector Hold") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
