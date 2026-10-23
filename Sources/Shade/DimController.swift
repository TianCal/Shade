import AppKit

/// 管理所有遮罩：定时读取窗口列表，让每个遮罩跟随目标窗口。
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

    // MARK: - 跟随目标窗口

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common 模式：菜单展开、拖动滑块时也继续跟随
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let list = WindowList.onScreen()
        var indexByID: [CGWindowID: Int] = [:]
        for (i, info) in list.enumerated() { indexByID[info.id] = i }

        var closed: [DimOverlay] = []
        for overlay in overlays {
            guard let i = indexByID[overlay.targetID] else {
                // 不在当前屏幕上：可能最小化、在其他 Space，或者已经关闭
                if WindowList.exists(overlay.targetID) { overlay.hide() } else { closed.append(overlay) }
                continue
            }
            overlay.show(over: list[i], windowAbove: i > 0 ? list[i - 1].id : nil)
        }
        closed.forEach(remove)
    }

    // MARK: - 按 App 记住调暗程度

    private func key(for appName: String) -> String { "dim.\(appName)" }

    private func savedDim(for appName: String) -> CGFloat {
        let saved = UserDefaults.standard.object(forKey: key(for: appName)) as? Double
        return CGFloat(saved ?? Double(Self.defaultDim))
    }
}
