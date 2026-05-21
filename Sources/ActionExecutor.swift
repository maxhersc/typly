import AppKit

class ActionExecutor {
    
    static let shared = ActionExecutor()
    
    private var currentOverlay: LiquidGlassOverlay?
    
    func execute(action: TyplyAction, context: TyplyContext) {
        TextTransformerEngine.shared.transform(action: action) { [weak self] result in
            
            switch action {
            case .fixSpelling, .rewrite:
                // Inline replacement
                if context.isEditable, let element = context.focusedElement {
                    self?.replaceInline(text: result, in: element)
                } else {
                    // Fallback if somehow it was classified editable but we don't have element
                    self?.showOverlay(text: result)
                }
                
            case .summarize:
                self?.showOverlay(text: result, showCloseButton: true)
            case .define:
                self?.showOverlay(text: result, showCloseButton: false)
            }
        }
    }
    
    private func replaceInline(text: String, in element: AXUIElement) {
        let error = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        
        if error != .success {
            // Fallback: clipboard paste
            copyToClipboardAndPaste(text: text)
        }
    }
    
    private func copyToClipboardAndPaste(text: String) {
        let pasteboard = NSPasteboard.general
        let oldItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Synthesize Cmd+V
        simulateKeyPress(keyCode: 9, useCommand: true) // 9 is 'v'
        
        // We cannot reliably restore clipboard immediately because simulated keys are async,
        // but for v1 we just leave the text in clipboard or delay restore.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let items = oldItems {
                pasteboard.clearContents()
                pasteboard.writeObjects(items)
            }
        }
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, useCommand: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        
        if useCommand {
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
        }
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func showOverlay(text: String, showCloseButton: Bool = false) {
        // If an overlay is already showing, dismiss it
        currentOverlay?.close()
        
        let overlay = LiquidGlassOverlay(text: text, showCloseButton: showCloseButton)
        overlay.show()
        currentOverlay = overlay
    }
}
