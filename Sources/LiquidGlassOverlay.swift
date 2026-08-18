import AppKit

/// A borderless, non activating panel never becomes the key window, so any control
/// inside it has to opt in to receiving the very first click.
private final class FirstMouseVisualEffectView: NSVisualEffectView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class LiquidGlassOverlay: NSPanel {

    private enum Metrics {
        static let contentWidth: CGFloat = 300
        static let minimumTextWidth: CGFloat = 120
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 14
        static let closeButtonSize: CGFloat = 18
        static let closeButtonGap: CGFloat = 8
        static let screenMargin: CGFloat = 12
        static let autoDismissDelay: TimeInterval = 3.0
        static let cursorOffset: CGFloat = 15
        static let measurementHeight: CGFloat = 10_000
    }

    var onDismiss: ((LiquidGlassOverlay) -> Void)?

    private let textLabel: NSTextField
    private let showsCloseButton: Bool
    private var dismissTimer: Timer?
    private var isDismissing = false

    init(text: String, showCloseButton: Bool = false) {
        showsCloseButton = showCloseButton

        textLabel = NSTextField(labelWithString: text)
        textLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textLabel.textColor = .white
        textLabel.alignment = .center
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 12
        textLabel.preferredMaxLayoutWidth = Metrics.contentWidth

        // Measure the wrapped text, then size the panel around it.
        let textSize = textLabel.sizeThatFits(NSSize(width: Metrics.contentWidth,
                                                    height: Metrics.measurementHeight))
        let textWidth = min(Metrics.contentWidth, max(textSize.width, Metrics.minimumTextWidth))
        let closeButtonWidth = showCloseButton ? Metrics.closeButtonSize + Metrics.closeButtonGap : 0
        let width = textWidth + Metrics.horizontalPadding * 2 + closeButtonWidth
        let height = textSize.height + Metrics.verticalPadding * 2

        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        // NSWindow releases itself on close by default, which over-releases under ARC
        // while ActionExecutor still holds a strong reference to this panel.
        isReleasedWhenClosed = false

        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Both of these are required. Setting a clear background alone does not make
        // the window non opaque, so vibrancy never blends and the rounded corners get
        // drawn over an opaque black square.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        setupContentView()
        positionNearCursor()
    }

    private func setupContentView() {
        let container = FirstMouseVisualEffectView()
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.appearance = NSAppearance(named: .vibrantDark)

        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true

        // Subtle edge highlight for the glass effect.
        container.layer?.borderWidth = 1.0
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textLabel)

        // The bottom pin is not required: the panel is already sized from the measured
        // text, and a rounding difference should not produce a broken constraint.
        let bottomPin = textLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor,
                                                          constant: -Metrics.verticalPadding)
        bottomPin.priority = .defaultHigh

        var constraints: [NSLayoutConstraint] = [
            textLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor,
                                               constant: Metrics.horizontalPadding),
            textLabel.topAnchor.constraint(equalTo: container.topAnchor,
                                           constant: Metrics.verticalPadding),
            bottomPin,
            textLabel.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.contentWidth)
        ]

        if showsCloseButton {
            let closeButton = FirstMouseButton()
            closeButton.title = ""
            closeButton.bezelStyle = .shadowlessSquare
            closeButton.isBordered = false
            closeButton.imagePosition = .imageOnly
            closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                        accessibilityDescription: "Close")
            closeButton.contentTintColor = .white
            closeButton.target = self
            closeButton.action = #selector(dismissOverlay)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(closeButton)

            constraints += [
                closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor,
                                                      constant: -Metrics.closeButtonGap),
                closeButton.widthAnchor.constraint(equalToConstant: Metrics.closeButtonSize),
                closeButton.heightAnchor.constraint(equalToConstant: Metrics.closeButtonSize),
                textLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor,
                                                    constant: -Metrics.closeButtonGap)
            ]
        } else {
            constraints.append(textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor,
                                                                   constant: -Metrics.horizontalPadding))
        }

        NSLayoutConstraint.activate(constraints)
        contentView = container
    }

    private func positionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation

        // Slightly above and to the right of the cursor, then clamped so the panel
        // never lands partly off screen.
        var origin = NSPoint(x: mouseLocation.x + Metrics.cursorOffset,
                             y: mouseLocation.y + Metrics.cursorOffset)

        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = frame.size
            let maxX = visible.maxX - size.width - Metrics.screenMargin
            let maxY = visible.maxY - size.height - Metrics.screenMargin
            origin.x = min(max(origin.x, visible.minX + Metrics.screenMargin), max(maxX, visible.minX))
            origin.y = min(max(origin.y, visible.minY + Metrics.screenMargin), max(maxY, visible.minY))
        }

        setFrameOrigin(origin)
    }

    func show() {
        alphaValue = 0
        // orderFrontRegardless, because an accessory app is never the active app.
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 1.0
        }

        if !showsCloseButton {
            dismissTimer?.invalidate()
            dismissTimer = Timer.scheduledTimer(withTimeInterval: Metrics.autoDismissDelay,
                                                repeats: false) { [weak self] _ in
                self?.dismissOverlay()
            }
        }
    }

    @objc func dismissOverlay() {
        guard !isDismissing else { return }
        isDismissing = true

        dismissTimer?.invalidate()
        dismissTimer = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.close()
            self.onDismiss?(self)
        })
    }

    deinit {
        dismissTimer?.invalidate()
    }
}
