import AppKit

/// Owns the trigger shortcut and runs the capture -> classify -> execute pipeline.
final class GlobalInputController {

    private let hotkeys = HotkeyManager()
    private let classifier = ContextClassifier()
    private var isRunningPipeline = false

    var shortcutDescription: String { hotkeys.shortcutDescription }

    /// Returns false if the shortcut could not be registered.
    @discardableResult
    func start() -> Bool {
        hotkeys.register { [weak self] in
            self?.triggerPipeline()
        }
    }

    func stop() {
        hotkeys.unregister()
    }

    private func triggerPipeline() {
        // Held or repeated shortcuts can fire again while a request is still in
        // flight; one run at a time keeps us from stacking overlays and edits.
        guard !isRunningPipeline else { return }
        isRunningPipeline = true

        classifier.captureContext { [weak self] context in
            guard let self else { return }

            guard let action = self.classifier.determineAction(for: context) else {
                // Say so rather than failing silently: plenty of apps simply do not
                // expose their selection to us.
                self.isRunningPipeline = false
                ActionExecutor.shared.reportNoSelection()
                return
            }

            ActionExecutor.shared.execute(action: action, context: context) { [weak self] in
                self?.isRunningPipeline = false
            }
        }
    }
}
