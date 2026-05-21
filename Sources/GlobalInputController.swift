import AppKit

class GlobalInputController {
    
    private var eventMonitor: Any?
    private let classifier = ContextClassifier()
    
    func start() {
        // We use flagsChanged to detect Caps Lock
        // Note: NSEvent's global monitor is called asynchronously and does not allow modifying the event.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }
    
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    // We want to trigger when Caps Lock is PRESSED, but Caps Lock toggles state.
    // So we'll trigger any time Caps Lock changes state.
    // A better approach is checking the event's keyCode == 57 (Caps Lock)
    private func handleFlagsChanged(_ event: NSEvent) {
        // KeyCode 57 is Caps Lock
        if event.keyCode == 57 {
            // Because Caps Lock triggers on both press down and release, 
            // distinguishing between keydown and keyup for Caps Lock using NSEvent 
            // is tricky, but often macOS sends flagsChanged when the state changes.
            // Let's just trigger immediately when Caps Lock state toggles.
            
            DispatchQueue.main.async {
                self.triggerPipeline()
            }
        }
    }
    
    private func triggerPipeline() {
        // Step 1: Capture context
        let context = classifier.captureContext()
        
        // Step 2: Classify action
        let action = classifier.determineAction(for: context)
        
        // Step 3: Execute action
        if let action = action {
            ActionExecutor.shared.execute(action: action, context: context)
        }
    }
}
