import AppKit

/// A translucent black, click-through overlay placed above a target window.
final class DimOverlay {
    private(set) var targetID: CGWindowID
    let pid: pid_t
    let appName: String
    private let window: NSWindow
    private var lastFrame: NSRect = .zero
    private var lastReorder = Date.distantPast

    /// Last known CG bounds of the target, used to find it again if the app replaces the window.
    private(set) var targetBounds: CGRect
    /// When the target window was first found to no longer exist; nil while it exists.
    var goneSince: Date?

    /// Dim level: 0 is no dimming, 1 is fully black.
    var dim: CGFloat {
        didSet { window.contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(dim).cgColor }
    }

    var windowID: CGWindowID { CGWindowID(window.windowNumber) }
    var isShown: Bool { window.isVisible }

    init(target: WindowInfo, dim: CGFloat) {
        targetID = target.id
        targetBounds = target.bounds
        pid = target.pid
        appName = target.ownerName
        self.dim = dim

        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.canHide = false // Stay visible if Shade gets hidden (e.g. by "Hide Others")
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

    /// Minimum time between reorders. Reordering doesn't always land exactly above the target
    /// (e.g. in fullscreen Spaces), so a reorder that doesn't stick shouldn't be retried every frame.
    private static let reorderInterval: TimeInterval = 0.2

    /// Moves the overlay onto the target and orders it above the target when needed.
    func show(over target: WindowInfo, needsReorder: Bool) {
        targetBounds = target.bounds
        let frame = Geometry.cocoaRect(fromCG: target.bounds)
        if frame != lastFrame {
            window.setFrame(frame, display: true)
            lastFrame = frame
        }
        let now = Date()
        if !window.isVisible || (needsReorder && now.timeIntervalSince(lastReorder) > Self.reorderInterval) {
            window.order(.above, relativeTo: Int(target.id))
            lastReorder = now
            Log.overlay.debug("Reordered overlay above window \(target.id) (\(self.appName, privacy: .public))")
        }
    }

    func retarget(to target: WindowInfo) {
        targetID = target.id
        targetBounds = target.bounds
        goneSince = nil
    }

    func hide() {
        if window.isVisible { window.orderOut(nil) }
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
