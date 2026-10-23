import AppKit

/// 其他 App 的一个窗口（来自 CGWindowList）。bounds 使用 CG 坐标：原点在主屏左上角，y 向下。
struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let ownerName: String
    let bounds: CGRect
    let layer: Int
}

enum WindowList {
    /// 当前 Space 中屏幕上的窗口，按从前到后排序。读取位置和所属 App 不需要“屏幕录制”权限。
    static func onScreen() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return raw.compactMap(parse)
    }

    /// 窗口是否仍然存在（包括最小化或位于其他 Space 的窗口）。
    static func exists(_ id: CGWindowID) -> Bool {
        guard let raw = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]] else { return false }
        return !raw.isEmpty
    }

    /// 某个全局 Cocoa 坐标点下方最靠前的普通窗口，不包括本 App 自己的窗口。
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
            ownerName: dict[kCGWindowOwnerName as String] as? String ?? "未知 App",
            bounds: bounds,
            layer: dict[kCGWindowLayer as String] as? Int ?? 0
        )
    }
}

enum Geometry {
    /// 主屏高度，用于在 CG 坐标（左上原点）和 Cocoa 坐标（左下原点）之间转换。
    private static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    static func cocoaRect(fromCG rect: CGRect) -> NSRect {
        NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cgPoint(fromCocoa point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
