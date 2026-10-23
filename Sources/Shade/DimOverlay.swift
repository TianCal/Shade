import AppKit

/// 盖在某个目标窗口上方的半透明黑色遮罩，点击可以穿透。
final class DimOverlay {
    let targetID: CGWindowID
    let pid: pid_t
    let appName: String
    private let window: NSWindow
    private var lastFrame: NSRect = .zero

    /// 调暗程度，0 表示不调暗，1 表示全黑。
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
        window.level = .normal // 与普通窗口同一层，才能插在目标窗口正上方
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(dim).cgColor
        view.layer?.cornerRadius = Self.cornerRadius
        view.layer?.cornerCurve = .continuous
        window.contentView = view
    }

    /// 新版 macOS 的窗口是圆角的；这个值是近似值，盖住四角的同时不让黑色溢出窗口外。
    private static let cornerRadius: CGFloat = 16

    /// 把遮罩移动到目标位置，并确保它排在目标窗口正上方。
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
