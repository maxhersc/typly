import AppKit

class LiquidGlassOverlay: NSPanel {
    
    private let textLabel: NSTextField
    private var dismissTimer: Timer?
    private let showCloseButton: Bool
    
    init(text: String, showCloseButton: Bool = false) {
        self.showCloseButton = showCloseButton
        textLabel = NSTextField(labelWithString: text)
        textLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textLabel.textColor = .labelColor
        textLabel.alignment = .center
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 10
        
        // Calculate size based on text
        let maxSize = NSSize(width: 300, height: 1000)
        let rect = textLabel.cell!.cellSize(forBounds: NSRect(origin: .zero, size: maxSize))
        
        let width = min(max(rect.width + 40, 150), 340)
        let height = rect.height + (showCloseButton ? 50 : 30)
        
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = true
        
        setupVisualEffectView()
        
        positionNearCursor()
    }
    
    private func setupVisualEffectView() {
        let visualEffectView = NSVisualEffectView(frame: self.contentView!.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(textLabel)
        
        if showCloseButton {
            let closeButton = NSButton()
            closeButton.title = ""
            closeButton.bezelStyle = .shadowlessSquare
            closeButton.isBordered = false
            closeButton.imagePosition = .imageOnly
            closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
            closeButton.contentTintColor = .secondaryLabelColor
            closeButton.target = self
            closeButton.action = #selector(fadeOutAndClose)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            
            visualEffectView.addSubview(closeButton)
            
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 10),
                closeButton.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -10),
                closeButton.widthAnchor.constraint(equalToConstant: 20),
                closeButton.heightAnchor.constraint(equalToConstant: 20)
            ])
            
            NSLayoutConstraint.activate([
                textLabel.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
                textLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor, constant: 10),
                textLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
            ])
        } else {
            NSLayoutConstraint.activate([
                textLabel.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
                textLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
                textLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
            ])
        }
        
        self.contentView = visualEffectView
    }
    
    private func positionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        
        // Position slightly above and to the right of the cursor
        let x = mouseLocation.x + 15
        let y = mouseLocation.y + 15
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show() {
        self.alphaValue = 0
        self.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        })
        
        if !showCloseButton {
            dismissTimer?.invalidate()
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.fadeOutAndClose()
            }
        }
    }
    
    @objc private func fadeOutAndClose() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.close()
        })
    }
}
