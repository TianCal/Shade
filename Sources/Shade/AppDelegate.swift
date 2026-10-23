import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let controller = DimController()
    private let picker = WindowPicker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // variableLength fits the icon itself instead of reserving a square like squareLength
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        controller.onChange = { [weak self] in self?.updateIcon() }

        // Debug: `Shade --dim-app Safari` dims that app's frontmost window on launch
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--dim-app"), i + 1 < args.count {
            let name = args[i + 1]
            if let target = WindowList.onScreen().first(where: { $0.ownerName == name && $0.layer == 0 }) {
                controller.add(target: target)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.removeAll()
    }

    private func updateIcon() {
        let symbol = controller.overlays.isEmpty ? "sun.min" : "sun.min.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Shade")?
            .withSymbolConfiguration(config)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let pick = NSMenuItem(title: "Pick a Window to Dim…", action: #selector(pickWindow), keyEquivalent: "")
        pick.target = self
        menu.addItem(pick)

        if !controller.overlays.isEmpty {
            menu.addItem(.separator())
            for overlay in controller.overlays {
                let item = NSMenuItem()
                item.view = SliderMenuView(
                    title: overlay.appName,
                    value: overlay.dim,
                    onChange: { [weak self] value in self?.controller.setDim(value, for: overlay) },
                    onRemove: { [weak self, weak menu] in
                        menu?.cancelTracking()
                        self?.controller.remove(overlay)
                    }
                )
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let removeAll = NSMenuItem(title: "Undim All", action: #selector(removeAll), keyEquivalent: "")
            removeAll.target = self
            menu.addItem(removeAll)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Shade", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func pickWindow() {
        // Wait for the menu to close before entering pick mode
        DispatchQueue.main.async { [weak self] in
            self?.picker.begin { info in
                guard let self, let info else { return }
                self.controller.add(target: info)
                NSRunningApplication(processIdentifier: info.pid)?.activate()
            }
        }
    }

    @objc private func removeAll() {
        controller.removeAll()
    }
}

/// One menu row: app name + dim slider + remove button.
private final class SliderMenuView: NSView {
    private let onChange: (CGFloat) -> Void
    private let onRemove: () -> Void
    private let percentLabel = NSTextField(labelWithString: "")

    init(title: String, value: CGFloat, onChange: @escaping (CGFloat) -> Void, onRemove: @escaping () -> Void) {
        self.onChange = onChange
        self.onRemove = onRemove
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 54))

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 14, y: 30, width: 170, height: 18)

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(x: 184, y: 31, width: 56, height: 16)

        let removeButton = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Undim")!,
                                    target: self, action: #selector(remove))
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.toolTip = "Stop dimming this window"
        removeButton.frame = NSRect(x: 248, y: 29, width: 20, height: 20)

        // Cap at 90% so the window never goes fully black
        let slider = NSSlider(value: Double(value), minValue: 0, maxValue: 0.9, target: self, action: #selector(sliderChanged(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 14, y: 6, width: 254, height: 20)

        [titleLabel, percentLabel, removeButton, slider].forEach(addSubview)
        updatePercent(value)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        updatePercent(value)
        onChange(value)
    }

    @objc private func remove() { onRemove() }

    private func updatePercent(_ value: CGFloat) {
        percentLabel.stringValue = "Dim \(Int((value * 100).rounded()))%"
    }
}
