import Carbon

final class EmergencyHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    func register() -> Bool {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<EmergencyHotKey>.fromOpaque(context).takeUnretainedValue().action?()
            return noErr
        }, 1, &spec, context, &handler)
        guard handlerStatus == noErr else { return false }
        // Control + Option + Command + F, independent of focus and Accessibility permission.
        let id = EventHotKeyID(signature: 0x4D44554F, id: 1)
        return RegisterEventHotKey(UInt32(kVK_ANSI_F), UInt32(controlKey | optionKey | cmdKey), id,
                                   GetApplicationEventTarget(), 0, &hotKey) == noErr
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
