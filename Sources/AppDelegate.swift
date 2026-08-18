import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var inputController: GlobalInputController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard hasAccessibilityPermission() else {
            presentAccessibilityAlert()
            return
        }

        let controller = GlobalInputController()
        guard controller.start() else {
            presentAlert(title: "Shortcut Unavailable",
                         message: """
                         Typly couldn't register \(controller.shortcutDescription) — another app is probably \
                         using it. Choose a different shortcut, then relaunch Typly:

                         defaults write com.typly.app HotKeyCode -int <virtual key code>
                         defaults write com.typly.app HotKeyModifiers -int <carbon modifier mask>
                         """)
            NSApplication.shared.terminate(nil)
            return
        }

        inputController = controller
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        inputController?.stop()
    }

    private func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func presentAccessibilityAlert() {
        // An accessory app is not active, so the alert would otherwise open behind
        // whatever the user is looking at.
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = """
        Typly needs Accessibility permissions to read the selected text and to type \
        replacements. Enable it in System Settings › Privacy & Security › Accessibility, \
        then restart Typly.

        If Typly is already listed there but still not working, remove it with the “−” \
        button and add it again — the permission is tied to the app's code signature, \
        which changes when Typly is rebuilt.
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        NSApplication.shared.terminate(nil)
    }

    private func presentAlert(title: String, message: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
