import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var inputController: GlobalInputController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Passive check only — never prompts, never opens System Settings, and never
        // gates startup on the result. AXIsProcessTrusted() just reflects whatever the
        // user already decided in System Settings > Privacy & Security > Accessibility.
        // When it's false, ContextClassifier already degrades to its clipboard-based
        // capture fallback, so Typly stays useful either way.
        if !AXIsProcessTrusted() {
            NSLog("Typly: Accessibility is not trusted yet; falling back to clipboard-based text capture until it is granted.")
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
