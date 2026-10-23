import ServiceManagement
import SwiftUI

/// The first-run guide: what the app does, its shortcuts, the Screen Recording
/// permission, launch at login and the optional support link.
@MainActor
final class WelcomeWindow {
    static let seenKey = "hasSeenWelcome"
    /// Set before restarting from the guide so it opens again with the permission granted.
    static let reopenKey = "reopenWelcomeAfterRestart"

    private let controller: HoldController
    private var window: NSWindow?

    init(controller: HoldController) {
        self.controller = controller
    }

    func show() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        if window == nil {
            let view = WelcomeView(controller: controller) { [weak self] in
                self?.window?.close()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Welcome to Projector Hold"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct WelcomeView: View {
    let controller: HoldController
    let done: () -> Void

    // CGPreflightScreenCaptureAccess reflects the permission as it was at launch,
    // which is why turning it on is followed by a restart.
    @State private var screenAccess = CGPreflightScreenCaptureAccess()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projector Hold")
                        .font(.title.bold())
                    Text("Freeze or blank your AirPlay TV while you keep working on your Mac.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Shortcuts")
                ShortcutRow(keys: ["⌃", "⌥", "⌘", "F"], text: "Freeze the TV. Press again to go live.")
                ShortcutRow(keys: ["⌃", "⌥", "⌘", "B"], text: "Blank the TV. Press again to show it.")
                Text("Works while mirroring too. The screens may flicker for a second as it switches.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Allow Screen Recording")
                if screenAccess {
                    Label("Screen Recording is on. Freeze is ready.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Freeze takes a snapshot of the TV, so macOS asks for Screen & System Audio Recording permission. Projector Hold never records audio or saves anything. Blank works without it.")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("1. Click Allow, then turn on ProjectorHold in System Settings.\n2. Come back and click Restart.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Allow Screen Recording…") {
                            _ = CGRequestScreenCaptureAccess()
                            controller.openScreenRecordingSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Restart Projector Hold") {
                            UserDefaults.standard.set(true, forKey: WelcomeWindow.reopenKey)
                            controller.restart()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Good to know")
                Label("Projector Hold lives in the menu bar. Click its screen icon at the top right for the same controls.", systemImage: "menubar.rectangle")
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Open Projector Hold when I log in", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginError {
                    Text(loginError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Divider()

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projector Hold is free.")
                        .font(.callout.bold())
                    Text("If it helps you, you can pay what you want.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Support ♥") {
                    NSWorkspace.shared.open(Links.support)
                }
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Couldn't change this: \(error.localizedDescription). Move Projector Hold to Applications and try again."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.headline)
    }
}

private struct ShortcutRow: View {
    let keys: [String]
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(.body, design: .rounded).bold())
                        .frame(minWidth: 26, minHeight: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                }
            }
            Text(text)
        }
    }
}
