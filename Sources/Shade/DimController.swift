import AppKit

/// Manages all overlays: polls the window list and keeps each overlay on top of its target window.
final class DimController {
    private(set) var overlays: [DimOverlay] = []
    private var timer: Timer?
    var onChange: (() -> Void)?

    static let defaultDim: CGFloat = 0.3

    func add(target: WindowInfo) {
        guard !overlays.contains(where: { $0.targetID == target.id }) else { return }
        let overlay = DimOverlay(target: target, dim: savedDim(for: target.ownerName))
        overlays.append(overlay)
        startTimerIfNeeded()
        tick()
        onChange?()
    }

    func remove(_ overlay: DimOverlay) {
        overlay.close()
        overlays.removeAll { $0 === overlay }
        if overlays.isEmpty { stopTimer() }
        onChange?()
    }

    func removeAll() {
        overlays.forEach { $0.close() }
        overlays.removeAll()
        stopTimer()
        onChange?()
    }

    func setDim(_ value: CGFloat, for overlay: DimOverlay) {
        overlay.dim = value
        UserDefaults.standard.set(Double(value), forKey: key(for: overlay.appName))
    }

    // MARK: - Tracking target windows

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common mode keeps tracking while the menu is open or a slider is being dragged
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// How long a target must be gone before its overlay is removed, so a transient miss doesn't drop it.
    private static let removalDelay: TimeInterval = 2

    private func tick() {
        let list = WindowList.onScreen()
        // An empty list means the window server couldn't be read (e.g. while the session is locked); try again next tick
        guard !list.isEmpty else { return }
        var indexByID: [CGWindowID: Int] = [:]
        for (i, info) in list.enumerated() { indexByID[info.id] = i }

        var closed: [DimOverlay] = []
        for overlay in overlays {
            if let i = indexByID[overlay.targetID] {
                if !overlay.isShown { Log.overlay.notice("Showing overlay for window \(overlay.targetID) (\(overlay.appName, privacy: .public))") }
                overlay.goneSince = nil
                overlay.show(over: list[i], needsReorder: needsReorder(overlay, targetIndex: i, in: list, indexByID: indexByID))
                continue
            }

            // Not on screen: minimized, in another Space, or closed
            if overlay.isShown { Log.overlay.notice("Hiding overlay: window \(overlay.targetID) (\(overlay.appName, privacy: .public)) is not on screen") }
            overlay.hide()
            if WindowList.exists(overlay.targetID) {
                overlay.goneSince = nil
                continue
            }
            if let replacement = replacement(for: overlay, in: list) {
                Log.overlay.notice("Window \(overlay.targetID) was replaced by \(replacement.id) (\(overlay.appName, privacy: .public)); following it")
                overlay.retarget(to: replacement)
                continue
            }
            let now = Date()
            if let since = overlay.goneSince {
                if now.timeIntervalSince(since) > Self.removalDelay {
                    Log.overlay.notice("Removing overlay: window \(overlay.targetID) (\(overlay.appName, privacy: .public)) was closed")
                    closed.append(overlay)
                }
            } else {
                overlay.goneSince = now
            }
        }
        closed.forEach(remove)
    }

    /// Whether the overlay has to be reordered above its target. Apps often keep their own helper windows
    /// (toolbars, title bars) directly above a window, so the overlay only needs to be somewhere above the
    /// target with no other app's overlapping window in between.
    private func needsReorder(_ overlay: DimOverlay, targetIndex: Int, in list: [WindowInfo], indexByID: [CGWindowID: Int]) -> Bool {
        guard let overlayIndex = indexByID[overlay.windowID], overlayIndex < targetIndex else { return true }
        let target = list[targetIndex]
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return list[(overlayIndex + 1)..<targetIndex].contains { info in
            info.pid != target.pid && info.pid != ownPID && info.layer == 0
                && info.bounds.insetBy(dx: 4, dy: 4).intersects(target.bounds)
        }
    }

    /// Some apps swap a window for a new one with the same frame; find that window so the overlay can follow it.
    private func replacement(for overlay: DimOverlay, in list: [WindowInfo]) -> WindowInfo? {
        let old = overlay.targetBounds
        return list.first { info in
            info.pid == overlay.pid && info.layer == 0
                && !overlays.contains { $0.targetID == info.id }
                && abs(info.bounds.minX - old.minX) <= 2 && abs(info.bounds.minY - old.minY) <= 2
                && abs(info.bounds.width - old.width) <= 2 && abs(info.bounds.height - old.height) <= 2
        }
    }

    // MARK: - Remembering dim level per app

    private func key(for appName: String) -> String { "dim.\(appName)" }

    private func savedDim(for appName: String) -> CGFloat {
        let saved = UserDefaults.standard.object(forKey: key(for: appName)) as? Double
        return CGFloat(saved ?? Double(Self.defaultDim))
    }
}
