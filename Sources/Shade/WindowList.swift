import AppKit

/// A window belonging to another app (from CGWindowList). `bounds` uses CG coordinates: origin at the top-left of the primary screen, y pointing down.
struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let ownerName: String
    let bounds: CGRect
    let layer: Int
}

enum WindowList {
    /// On-screen windows in the current Space, ordered front to back. Reading bounds and owner doesn't require Screen Recording permission.
    static func onScreen() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return raw.compactMap(parse)
    }

    /// Whether the window still exists (including minimized windows and windows in other Spaces).
    static func exists(_ id: CGWindowID) -> Bool {
        guard let raw = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]] else { return false }
        return !raw.isEmpty
    }

    /// The frontmost normal window under a global Cocoa point, excluding this app's own windows.
    static func topWindow(atCocoaPoint point: NSPoint) -> WindowInfo? {
        let cgPoint = Geometry.cgPoint(fromCocoa: point)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return onScreen().first { info in
            info.pid != ownPID
                && info.layer == 0
                && info.bounds.width > 40 && info.bounds.height > 40
                && info.bounds.contains(cgPoint)
        }
    }

    private static func parse(_ dict: [String: Any]) -> WindowInfo? {
        guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
              let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
              let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict) else { return nil }
        let alpha = dict[kCGWindowAlpha as String] as? Double ?? 1
        guard alpha > 0 else { return nil }
        return WindowInfo(
            id: id,
            pid: pid,
            ownerName: dict[kCGWindowOwnerName as String] as? String ?? "Unknown App",
            bounds: bounds,
            layer: dict[kCGWindowLayer as String] as? Int ?? 0
        )
    }
}

enum Geometry {
    /// Primary screen height, used to convert between CG (top-left origin) and Cocoa (bottom-left origin) coordinates.
    private static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    static func cocoaRect(fromCG rect: CGRect) -> NSRect {
        NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cgPoint(fromCocoa point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
