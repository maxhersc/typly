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
}

class ContextClassifier {
    
    func captureContext() -> TyplyContext {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRaw: CFTypeRef?
        
        // Get focused element
        let error = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRaw)
        
        guard error == .success, let focusedElement = focusedElementRaw as! AXUIElement? else {
            return fallbackContext()
        }
        
        // Get selected text
        var selectedTextRaw: CFTypeRef?
        let textError = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextRaw)
        
        guard textError == .success, let selectedText = selectedTextRaw as? String, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallbackContext()
        }
        
        // Check editability
        var isEditable = false
        var isSettable: DarwinBoolean = false
        let settableError = AXUIElementIsAttributeSettable(focusedElement, kAXSelectedTextAttribute as CFString, &isSettable)
        
        if settableError == .success && isSettable.boolValue {
            isEditable = true
        } else {
            // Check roles as fallback
            var roleRaw: CFTypeRef?
            if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleRaw) == .success,
               let role = roleRaw as? String {
                if role == kAXTextFieldRole || role == kAXTextAreaRole {
                    isEditable = true
                }
            }
        }
        
        return TyplyContext(selectedText: selectedText, isEditable: isEditable, focusedElement: focusedElement)
    }
    
    private func fallbackContext() -> TyplyContext {
        // Fallback: Copy via Cmd+C
        // For v1, if AX fails, we can try to extract from pasteboard.
        // Doing Cmd+C programmatically via CGEvent is an option, but for now we'll just return empty/non-editable.
        return TyplyContext(selectedText: "", isEditable: false, focusedElement: nil)
    }
    
    func determineAction(for context: TyplyContext) -> TyplyAction? {
        let text = context.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordCount = words.count
        
        if wordCount == 1 {
            if context.isEditable {
                return .fixSpelling(text)
            } else {
                return .define(text)
            }
        } else {
            if context.isEditable {
                return .rewrite(text)
            } else {
                return .summarize(text)
            }
        }
    }
}
