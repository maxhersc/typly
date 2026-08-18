import AppKit
import Carbon.HIToolbox

/// Thin wrappers around the low level input APIs we need in more than one place.
enum KeyboardSimulator {

    /// Posts a synthetic key press. Requires Accessibility permission.
    static func press(keyCode: CGKeyCode, command: Bool = false) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        if command {
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
        }

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    static func copySelection() {
        press(keyCode: CGKeyCode(kVK_ANSI_C), command: true)
    }

    static func paste() {
        press(keyCode: CGKeyCode(kVK_ANSI_V), command: true)
    }
}

/// A copy of the pasteboard contents, so we can borrow the pasteboard for a
/// copy/paste round trip and then hand it back the way we found it.
struct PasteboardSnapshot {

    private let items: [NSPasteboardItem]

    init(_ pasteboard: NSPasteboard = .general) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}
