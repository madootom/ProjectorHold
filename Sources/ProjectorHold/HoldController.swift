import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit

enum HoldMode {
    case off
    case blank
    case frozen
}

private typealias MirrorPair = (display: CGDirectDisplayID, source: CGDirectDisplayID)

@MainActor
final class HoldController: ObservableObject {
    @Published private(set) var mode: HoldMode = .off
    @Published private(set) var message: String?
    @Published private(set) var needsScreenPermission = false
    @Published var includeThisMac: Bool = UserDefaults.standard.bool(forKey: "includeThisMac") {
        didSet { UserDefaults.standard.set(includeThisMac, forKey: "includeThisMac") }
    }

    private var overlays: [OverlayWindow] = []
    private var hotKeys: [GlobalHotKey] = []
    /// Mirroring that was switched off to freeze or blank the TV, restored on release.
    private var pausedMirroring: [MirrorPair] = []

    private let noDisplayMessage =
        "No TV or external display found. Start AirPlay to your TV from Control Center > Screen Mirroring."

    init() {
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        hotKeys = [
            GlobalHotKey(keyCode: UInt32(kVK_ANSI_B), modifiers: modifiers) { [weak self] in
                Task { await self?.toggleBlank() }
            },
            GlobalHotKey(keyCode: UInt32(kVK_ANSI_F), modifiers: modifiers) { [weak self] in
                Task { await self?.toggleFreeze() }
            }
        ]
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.release() }
        }
    }

    func toggleBlank() async {
        if mode == .blank {
            release()
            return
        }
        await releaseAndSettle()
        await hold(.blank, picture: nil)
    }

    func toggleFreeze() async {
        if mode == .frozen {
            release()
            return
        }
        await releaseAndSettle()

        // CGPreflightScreenCaptureAccess keeps returning the answer it had when
        // the app launched, so it is only used to show the prompt once. The
        // capture itself is the real test of whether permission was granted.
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }

        do {
            // Capture before any display change, while the TV still shows the presentation.
            let mirroring = includeThisMac ? [] : mirrorPairsWithThisMac()
            let sources = mirroring.isEmpty
                ? targetScreens
                : NSScreen.screens.filter { displaysShowingThisMac().contains($0.displayID) }
            let frames = try await capture(sources)
            log("Freeze captured \(frames.count) of \(sources.count) screen(s), mirroring: \(!mirroring.isEmpty)")
            await hold(.frozen, picture: { screen in
                mirroring.isEmpty ? frames[screen.displayID] : frames.values.first
            })
            needsScreenPermission = false
        } catch {
            let nsError = error as NSError
            log("Freeze failed: \(nsError.domain) \(nsError.code) \(nsError.localizedDescription)")
            if nsError.domain == SCStreamErrorDomain && nsError.code == SCStreamError.userDeclined.rawValue {
                needsScreenPermission = true
                message = "Freeze needs Screen & System Audio Recording permission. Turn on ProjectorHold in System Settings, then choose Restart Projector Hold."
            } else {
                message = "Freeze failed: \(nsError.localizedDescription) (\(nsError.domain) \(nsError.code))"
            }
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// macOS applies a newly granted Screen Recording permission only after the app restarts.
    func restart() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - Holding the TV picture

    /// Covers the TV with a black screen or a frozen picture. If the TV is mirroring
    /// this Mac, mirroring is switched off first so the Mac's own screen stays live.
    private func hold(_ newMode: HoldMode, picture: ((NSScreen) -> CGImage?)?) async {
        let mirroring = includeThisMac ? [] : mirrorPairsWithThisMac()
        if !mirroring.isEmpty {
            guard stopMirroring(mirroring) else {
                message = "Couldn't separate the TV from this Mac's screen. Check ~/Library/Logs/ProjectorHold.log."
                return
            }
            pausedMirroring = mirroring
            await waitUntil { !self.targetScreens.isEmpty }
        }

        let screens = targetScreens
        guard !screens.isEmpty else {
            release()
            message = noDisplayMessage
            return
        }

        overlays = screens.map { OverlayWindow(screen: $0, image: picture?($0)) }
        overlays.forEach { $0.show() }
        mode = newMode
        message = nil
    }

    /// Removes the overlay and turns mirroring back on if the app turned it off.
    private func release() {
        overlays.forEach { $0.close() }
        overlays = []
        mode = .off
        if !pausedMirroring.isEmpty {
            startMirroring(pausedMirroring)
            pausedMirroring = []
        }
    }

    /// Releases any current hold and, if mirroring was restored, waits for the
    /// screens to settle so the next capture sees the mirrored picture again.
    private func releaseAndSettle() async {
        guard mode != .off else { return }
        let restoring = !pausedMirroring.isEmpty
        release()
        if restoring {
            await waitUntil { !self.mirrorPairsWithThisMac().isEmpty }
        }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<40 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - Displays

    /// The AirPlay or external displays, so the Mac's own screen stays usable.
    /// A display that mirrors the Mac's screen shows the same picture, so it is
    /// left out too. Everything is included when the user turns that option on.
    private var targetScreens: [NSScreen] {
        let thisMac = displaysShowingThisMac()
        return NSScreen.screens.filter { screen in
            includeThisMac || !thisMac.contains(screen.displayID)
        }
    }

    private func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    /// The built-in display plus any display in a mirror set with it.
    private func displaysShowingThisMac() -> Set<CGDirectDisplayID> {
        let ids = onlineDisplays()
        var result = Set<CGDirectDisplayID>()
        for id in ids where CGDisplayIsBuiltin(id) != 0 {
            result.insert(id)
            let source = CGDisplayMirrorsDisplay(id)
            if source != kCGNullDirectDisplay {
                result.insert(source)
            }
        }
        for id in ids where result.contains(CGDisplayMirrorsDisplay(id)) {
            result.insert(id)
        }
        return result
    }

    private func mirrorPairsWithThisMac() -> [MirrorPair] {
        let group = displaysShowingThisMac()
        return onlineDisplays().compactMap { id in
            let source = CGDisplayMirrorsDisplay(id)
            guard source != kCGNullDirectDisplay, group.contains(id) else { return nil }
            return (id, source)
        }
    }

    /// Splits the mirror set, keeping the built-in display as the main screen so
    /// the menu bar and windows stay on the Mac while the TV is held.
    private func stopMirroring(_ pairs: [MirrorPair]) -> Bool {
        let builtIn = onlineDisplays().first { CGDisplayIsBuiltin($0) != 0 }
        let builtInWidth = builtIn.map { Int32(CGDisplayBounds($0).width) } ?? 0
        return configureDisplays { config in
            for pair in pairs {
                CGConfigureDisplayMirrorOfDisplay(config, pair.display, kCGNullDirectDisplay)
            }
            if let builtIn {
                CGConfigureDisplayOrigin(config, builtIn, 0, 0)
                let others = Set(pairs.flatMap { [$0.display, $0.source] }).subtracting([builtIn])
                for id in others {
                    CGConfigureDisplayOrigin(config, id, builtInWidth, 0)
                }
            }
        }
    }

    private func startMirroring(_ pairs: [MirrorPair]) {
        _ = configureDisplays { config in
            for pair in pairs {
                CGConfigureDisplayMirrorOfDisplay(config, pair.display, pair.source)
                CGConfigureDisplayOrigin(config, pair.source, 0, 0)
            }
        }
    }

    private func configureDisplays(_ change: (CGDisplayConfigRef) -> Void) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            log("Could not begin display configuration")
            return false
        }
        change(config)
        let result = CGCompleteDisplayConfiguration(config, .forSession)
        if result != .success {
            log("Display configuration failed: \(result.rawValue)")
        }
        return result == .success
    }

    // MARK: - Capture

    /// Captures the given screens, leaving out this app's own windows so an
    /// overlay that is already showing does not end up in the frozen picture.
    private func capture(_ screens: [NSScreen]) async throws -> [CGDirectDisplayID: CGImage] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownBundleID = Bundle.main.bundleIdentifier
        let ownWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == ownBundleID }

        var frames: [CGDirectDisplayID: CGImage] = [:]
        for screen in screens {
            guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
                continue
            }
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let config = SCStreamConfiguration()
            config.width = Int(screen.frame.width * screen.backingScaleFactor)
            config.height = Int(screen.frame.height * screen.backingScaleFactor)
            config.showsCursor = false
            frames[screen.displayID] = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        }
        return frames
    }

    /// Appends to ~/Library/Logs/ProjectorHold.log so failures can be diagnosed.
    private func log(_ text: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ProjectorHold.log")
        let line = "\(Date()) \(text)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
