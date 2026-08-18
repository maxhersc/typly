import AppKit
import Carbon.HIToolbox

/// Registers the global trigger shortcut.
///
/// This uses `RegisterEventHotKey` rather than `NSEvent.addGlobalMonitorForEvents`
/// on purpose. A global monitor is read only: it cannot stop the key it observes
/// from also reaching the focused app, which is why the previous Caps Lock trigger
/// toggled Caps Lock every time it fired. A registered hot key is consumed by us
/// and never reaches the front app.
///
/// The shortcut defaults to Option-Command-Space and can be changed with:
///
///     defaults write com.typly.app HotKeyCode -int 49
///     defaults write com.typly.app HotKeyModifiers -int 2304
///
/// where `HotKeyCode` is a virtual key code (`kVK_*`) and `HotKeyModifiers` is a
/// Carbon modifier mask (`cmdKey` 256, `shiftKey` 512, `optionKey` 2048, `controlKey` 4096).
final class HotkeyManager {

    static let keyCodeDefaultsKey = "HotKeyCode"
    static let modifiersDefaultsKey = "HotKeyModifiers"

    private let signature: OSType = 0x5459_504C // 'TYPL'

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    private var keyCode: UInt32 {
        if let stored = UserDefaults.standard.object(forKey: Self.keyCodeDefaultsKey) as? Int {
            return UInt32(stored)
        }
        return UInt32(kVK_Space)
    }

    private var modifiers: UInt32 {
        if let stored = UserDefaults.standard.object(forKey: Self.modifiersDefaultsKey) as? Int {
            return UInt32(stored)
        }
        return UInt32(optionKey | cmdKey)
    }

    /// Human readable form of the active shortcut, for error messages.
    var shortcutDescription: String {
        var description = ""
        if modifiers & UInt32(controlKey) != 0 { description += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { description += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { description += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { description += "⌘" }
        return description + keyName
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        default: return "key \(keyCode)"
        }
    }

    /// Installs the hot key. Returns false if the shortcut is already taken by
    /// another app, in which case nothing is registered.
    @discardableResult
    func register(onTrigger trigger: @escaping () -> Void) -> Bool {
        unregister()
        onTrigger = trigger

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        // A Carbon handler is a C function pointer, so the instance travels
        // through userData instead of being captured.
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }

                var pressedID = EventHotKeyID()
                let status = GetEventParameter(event,
                                               EventParamName(kEventParamDirectObject),
                                               EventParamType(typeEventHotKeyID),
                                               nil,
                                               UInt32(MemoryLayout<EventHotKeyID>.size),
                                               nil,
                                               &pressedID)
                guard status == noErr else { return OSStatus(eventNotHandledErr) }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard pressedID.signature == manager.signature else { return OSStatus(eventNotHandledErr) }

                manager.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard handlerStatus == noErr else {
            unregister()
            return false
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let registerStatus = RegisterEventHotKey(keyCode,
                                                modifiers,
                                                hotKeyID,
                                                GetApplicationEventTarget(),
                                                0,
                                                &hotKeyRef)

        guard registerStatus == noErr, hotKeyRef != nil else {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        onTrigger = nil
    }

    deinit {
        unregister()
    }
}
