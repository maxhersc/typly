import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Required to make sure the app behaves properly when launched as a standalone background executable
app.setActivationPolicy(.accessory)

app.run()
