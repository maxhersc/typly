import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var inputController: GlobalInputController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        checkAccessibilityPermissions()
        
        inputController = GlobalInputController()
        inputController?.start()
    }
    
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Typly needs Accessibility permissions to capture selected text. Please enable it in System Settings -> Privacy & Security -> Accessibility, then restart Typly."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            NSApplication.shared.terminate(nil)
        }
    }
}
