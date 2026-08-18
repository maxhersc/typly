import AppKit

final class ActionExecutor {

    static let shared = ActionExecutor()

    /// How long the pasteboard has to stay ours for the front app to service the
    /// synthetic Cmd+V before we put the user's clipboard back.
    private static let clipboardRestoreDelay: TimeInterval = 0.8

    private var currentOverlay: LiquidGlassOverlay?

    /// `completion` runs once the action has been carried out, successfully or not.
    func execute(action: TyplyAction, context: TyplyContext, completion: @escaping () -> Void) {
        TextTransformerEngine.shared.transform(action: action) { [weak self] result in
            defer { completion() }
            guard let self else { return }

            switch result {
            case .failure(let message):
                // Show the problem; never type an error message into the document.
                self.showOverlay(text: message, showCloseButton: true)

            case .success(let text):
                switch action {
                case .fixSpelling, .rewrite:
                    if context.isEditable {
                        self.replace(text: text, in: context)
                    } else {
                        self.showOverlay(text: text, showCloseButton: true)
                    }
                case .summarize:
                    self.showOverlay(text: text, showCloseButton: true)
                case .define:
                    self.showOverlay(text: text, showCloseButton: false)
                }
            }
        }
    }

    func reportNoSelection() {
        showOverlay(text: "Select some text first.", showCloseButton: false)
    }

    private func replace(text: String, in context: TyplyContext) {
        // If the selection itself came from the clipboard, AX cannot write it back.
        if !context.usedPasteboardFallback,
           let element = context.focusedElement,
           AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
            return
        }
        pasteOverSelection(text: text)
    }

    private func pasteOverSelection(text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        KeyboardSimulator.paste()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.clipboardRestoreDelay) {
            snapshot.restore(to: pasteboard)
        }
    }

    private func showOverlay(text: String, showCloseButton: Bool) {
        currentOverlay?.dismissOverlay()

        let overlay = LiquidGlassOverlay(text: text, showCloseButton: showCloseButton)
        overlay.onDismiss = { [weak self] dismissed in
            if self?.currentOverlay === dismissed {
                self?.currentOverlay = nil
            }
        }
        overlay.show()
        currentOverlay = overlay
    }
}
