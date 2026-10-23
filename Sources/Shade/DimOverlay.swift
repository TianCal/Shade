import AppKit

/// A translucent black, click-through overlay placed directly above a target window.
final class DimOverlay {
    let targetID: CGWindowID
    let pid: pid_t
    let appName: String
    private let window: NSWindow
    private var lastFrame: NSRect = .zero

    /// Dim level: 0 is no dimming, 1 is fully black.
    var dim: CGFloat {
        didSet { window.contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(dim).cgColor }
    }

    var windowNumber: Int { window.windowNumber }

    init(target: WindowInfo, dim: CGFloat) {
        targetID = target.id
        pid = target.pid
        appName = target.ownerName
        self.dim = dim

        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .normal // Same level as normal windows so it can sit directly above the target
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(dim).cgColor
        view.layer?.cornerRadius = Self.cornerRadius
        view.layer?.cornerCurve = .continuous
        window.contentView = view
    }

    /// Recent macOS windows have rounded corners; this approximates them so the overlay covers the corners without spilling outside.
    private static let cornerRadius: CGFloat = 16

    /// Moves the overlay onto the target and makes sure it is ordered directly above it.
    func show(over target: WindowInfo, windowAbove: CGWindowID?) {
        let frame = Geometry.cocoaRect(fromCG: target.bounds)
        if frame != lastFrame {
            window.setFrame(frame, display: true)
            lastFrame = frame
        }
        if !window.isVisible || windowAbove != CGWindowID(window.windowNumber) {
            window.order(.above, relativeTo: Int(target.id))
        }
    }

    func hide() {
        if window.isVisible { window.orderOut(nil) }
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
