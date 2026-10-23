import AppKit

/// 选窗口模式：在每块屏幕上盖一层透明窗口，高亮鼠标下方的窗口，点击即选中，Esc 取消。
final class WindowPicker {
    private var windows: [PickerWindow] = []
    private var completion: ((WindowInfo?) -> Void)?

    func begin(completion: @escaping (WindowInfo?) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion

        for screen in NSScreen.screens {
            let window = PickerWindow(screen: screen)
            window.pickerView.onHover = { [weak self] in self?.refreshHighlight() }
            window.pickerView.onClick = { [weak self] in self?.finish(with: WindowList.topWindow(atCocoaPoint: NSEvent.mouseLocation)) }
            window.pickerView.onCancel = { [weak self] in self?.finish(with: nil) }
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first(where: { $0.screen == NSScreen.main })?.makeKey()
        NSCursor.crosshair.push()
        refreshHighlight()
    }

    private func refreshHighlight() {
        let hovered = WindowList.topWindow(atCocoaPoint: NSEvent.mouseLocation)
        let rect = hovered.map { Geometry.cocoaRect(fromCG: $0.bounds) }
        for window in windows {
            window.pickerView.highlight = rect.map { window.convertFromScreen($0) }
            window.pickerView.highlightName = hovered?.ownerName
        }
    }

    private func finish(with info: WindowInfo?) {
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        let completion = self.completion
        self.completion = nil
        completion?(info)
    }
}

private final class PickerWindow: NSWindow {
    let pickerView = PickerView()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = pickerView
    }

    override var canBecomeKey: Bool { true }
}

private final class PickerView: NSView {
    var onHover: (() -> Void)?
    var onClick: (() -> Void)?
    var onCancel: (() -> Void)?
    var highlight: NSRect? { didSet { needsDisplay = true } }
    var highlightName: String?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseMoved(with event: NSEvent) { onHover?() }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func rightMouseDown(with event: NSEvent) { onCancel?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } // Esc
    }

    override func draw(_ dirtyRect: NSRect) {
        // 几乎透明但不为 0，这样才能接收鼠标事件
        NSColor.black.withAlphaComponent(0.08).setFill()
        bounds.fill()

        if let rect = highlight {
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 4
            path.stroke()
        }

        let text = highlightName.map { "点击调暗「\($0)」的这个窗口 · Esc 取消" } ?? "把鼠标移到要调暗的窗口上，点击选中 · Esc 取消"
        drawBanner(text)
    }

    private func drawBanner(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let box = NSRect(x: bounds.midX - size.width / 2 - 16, y: bounds.maxY - 90,
                         width: size.width + 32, height: size.height + 16)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: box, xRadius: 10, yRadius: 10).fill()
        (text as NSString).draw(at: NSPoint(x: box.minX + 16, y: box.minY + 8), withAttributes: attrs)
    }
}
