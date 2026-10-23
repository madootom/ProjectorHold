import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Uses Carbon's hot-key API, which works
/// without Accessibility or Input Monitoring permission.
final class GlobalHotKey {
    private static var nextID: UInt32 = 1
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()

        let id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action

        let hotKeyID = EventHotKeyID(signature: OSType(0x50484F4B), id: id) // "PHOK"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let action = GlobalHotKey.actions[hotKeyID.id]
            DispatchQueue.main.async { action?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
