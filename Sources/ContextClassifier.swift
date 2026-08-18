import AppKit

enum TyplyAction {
    case fixSpelling(String)
    case rewrite(String)
    case summarize(String)
    case define(String)
}

struct TyplyContext {
    let selectedText: String
    let isEditable: Bool
    let focusedElement: AXUIElement?
    /// True when the text came from a clipboard round trip rather than from the
    /// Accessibility API, which means we cannot write back through AX either.
    let usedPasteboardFallback: Bool
}

final class ContextClassifier {

    /// How long to wait for the front app to service a synthetic Cmd+C.
    private static let pasteboardSettleDelay: TimeInterval = 0.15

    /// Captures the current selection. The completion is always called on the main thread.
    func captureContext(completion: @escaping (TyplyContext) -> Void) {
        let focusedElement = copyFocusedElement()
        let editable = focusedElement.map(isElementEditable) ?? false

        if let focusedElement, let text = copySelectedText(from: focusedElement) {
            completion(TyplyContext(selectedText: text,
                                    isEditable: editable,
                                    focusedElement: focusedElement,
                                    usedPasteboardFallback: false))
            return
        }

        // Chromium, Electron and most web views never expose AXSelectedText, so ask
        // the front app for a copy instead of giving up.
        captureViaPasteboard(focusedElement: focusedElement,
                             isEditable: editable,
                             completion: completion)
    }

    private func copyFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var raw: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(systemWide,
                                                 kAXFocusedUIElementAttribute as CFString,
                                                 &raw)

        // Check the CFTypeID before casting: AX hands back whatever the app put there.
        guard error == .success,
              let value = raw,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func copySelectedText(from element: AXUIElement) -> String? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &raw) == .success,
              let text = raw as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private func isElementEditable(_ element: AXUIElement) -> Bool {
        var isSettable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable) == .success,
           isSettable.boolValue {
            return true
        }

        var roleRaw: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRaw) == .success,
           let role = roleRaw as? String {
            return role == kAXTextFieldRole || role == kAXTextAreaRole || role == kAXComboBoxRole
        }
        return false
    }

    private func captureViaPasteboard(focusedElement: AXUIElement?,
                                      isEditable: Bool,
                                      completion: @escaping (TyplyContext) -> Void) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let changeCountBeforeCopy = pasteboard.changeCount

        KeyboardSimulator.copySelection()

        // Synthetic key events are delivered asynchronously by the window server,
        // so give the front app a moment before reading the pasteboard back.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteboardSettleDelay) {
            let copied = pasteboard.changeCount != changeCountBeforeCopy
                ? pasteboard.string(forType: .string)
                : nil

            snapshot.restore(to: pasteboard)

            var text = ""
            if let copied, !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = copied
            }

            completion(TyplyContext(selectedText: text,
                                    isEditable: isEditable,
                                    focusedElement: focusedElement,
                                    usedPasteboardFallback: true))
        }
    }

    func determineAction(for context: TyplyContext) -> TyplyAction? {
        let text = context.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }

        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        if words.count == 1 {
            return context.isEditable ? .fixSpelling(text) : .define(text)
        } else {
            return context.isEditable ? .rewrite(text) : .summarize(text)
        }
    }
}
