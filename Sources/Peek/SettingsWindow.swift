import Cocoa
import ServiceManagement

/// Settings window with circle size slider and overlay style picker.
class SettingsWindow: NSWindow {

    private weak var appDelegate: AppDelegate?
    private var sizeSlider: NSSlider!
    private var sizeValueLabel: NSTextField!
    private var styleSegment: NSSegmentedControl!
    private var edgeSegment: NSSegmentedControl!
    private var shortcutRecorder: ShortcutRecorderView!
    private var loginCheckbox: NSButton!

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 386),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Peek Settings"
        self.isReleasedWhenClosed = false
        self.center()

        setupUI()
        syncFromPreferences()
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 386))

        let padding: CGFloat = 20
        var y: CGFloat = 342

        // --- Overlay Style ---
        let styleLabel = NSTextField(labelWithString: "Overlay Style")
        styleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        styleLabel.frame = NSRect(x: padding, y: y, width: 280, height: 18)
        contentView.addSubview(styleLabel)

        y -= 32
        styleSegment = NSSegmentedControl(labels: ["Light Blur", "Dark Blur", "Blackout"], trackingMode: .selectOne, target: self, action: #selector(styleChanged))
        styleSegment.frame = NSRect(x: padding, y: y, width: 280, height: 28)
        styleSegment.segmentStyle = .rounded
        contentView.addSubview(styleSegment)

        // --- Edge Transition ---
        y -= 40
        let edgeLabel = NSTextField(labelWithString: "Edge Transition")
        edgeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        edgeLabel.frame = NSRect(x: padding, y: y, width: 280, height: 18)
        contentView.addSubview(edgeLabel)

        y -= 32
        edgeSegment = NSSegmentedControl(labels: ["Soft", "Hard", "Wide", "Spotlight", "Stepped"], trackingMode: .selectOne, target: self, action: #selector(edgeChanged))
        edgeSegment.frame = NSRect(x: padding, y: y, width: 280, height: 28)
        edgeSegment.segmentStyle = .rounded
        contentView.addSubview(edgeSegment)

        // --- Circle Size ---
        y -= 40
        let sizeLabel = NSTextField(labelWithString: "Circle Size")
        sizeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        sizeLabel.frame = NSRect(x: padding, y: y, width: 200, height: 18)
        contentView.addSubview(sizeLabel)

        sizeValueLabel = NSTextField(labelWithString: "")
        sizeValueLabel.font = .systemFont(ofSize: 12)
        sizeValueLabel.textColor = .secondaryLabelColor
        sizeValueLabel.alignment = .right
        sizeValueLabel.frame = NSRect(x: 200, y: y, width: 100, height: 18)
        contentView.addSubview(sizeValueLabel)

        y -= 26
        sizeSlider = NSSlider(value: 150, minValue: 50, maxValue: 600, target: self, action: #selector(sizeChanged))
        sizeSlider.frame = NSRect(x: padding, y: y, width: 280, height: 20)
        sizeSlider.isContinuous = true
        contentView.addSubview(sizeSlider)

        // Small / Large labels under the slider
        y -= 18
        let smallLabel = NSTextField(labelWithString: "Small")
        smallLabel.font = .systemFont(ofSize: 10)
        smallLabel.textColor = .tertiaryLabelColor
        smallLabel.frame = NSRect(x: padding, y: y, width: 60, height: 14)
        contentView.addSubview(smallLabel)

        let largeLabel = NSTextField(labelWithString: "Large")
        largeLabel.font = .systemFont(ofSize: 10)
        largeLabel.textColor = .tertiaryLabelColor
        largeLabel.alignment = .right
        largeLabel.frame = NSRect(x: 240, y: y, width: 60, height: 14)
        contentView.addSubview(largeLabel)

        // --- Keyboard Shortcut ---
        y -= 36
        let shortcutLabel = NSTextField(labelWithString: "Keyboard Shortcut")
        shortcutLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        shortcutLabel.frame = NSRect(x: padding, y: y, width: 180, height: 18)
        contentView.addSubview(shortcutLabel)

        let initialShortcut = appDelegate?.currentShortcut ?? .defaultShortcut
        shortcutRecorder = ShortcutRecorderView(
            frame: NSRect(x: 200, y: y - 4, width: 100, height: 26),
            shortcut: initialShortcut
        )
        shortcutRecorder.onChange = { [weak self] newShortcut in
            self?.appDelegate?.currentShortcut = newShortcut
            // If the shortcut was reverted (conflict), sync the recorder back
            if let current = self?.appDelegate?.currentShortcut, current != newShortcut {
                self?.shortcutRecorder.shortcut = current
            }
        }
        contentView.addSubview(shortcutRecorder)

        // --- Launch at Login ---
        y -= 30
        loginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(loginToggled))
        loginCheckbox.frame = NSRect(x: padding, y: y, width: 280, height: 18)
        contentView.addSubview(loginCheckbox)

        self.contentView = contentView
    }

    /// Read current values from AppDelegate and update the controls
    private func syncFromPreferences() {
        guard let app = appDelegate else { return }
        sizeSlider.doubleValue = Double(app.circleRadius)
        styleSegment.selectedSegment = app.overlayStyle.rawValue
        edgeSegment.selectedSegment = app.edgeTransition.rawValue
        shortcutRecorder.shortcut = app.currentShortcut
        updateSizeLabel()

        // Sync launch at login checkbox from system state
        let status = SMAppService.mainApp.status
        loginCheckbox.state = (status == .enabled) ? .on : .off
    }

    @objc private func styleChanged() {
        guard let newStyle = OverlayStyle(rawValue: styleSegment.selectedSegment) else { return }
        appDelegate?.overlayStyle = newStyle
    }

    @objc private func edgeChanged() {
        guard let newEdge = EdgeTransition(rawValue: edgeSegment.selectedSegment) else { return }
        appDelegate?.edgeTransition = newEdge
    }

    @objc private func sizeChanged() {
        let radius = CGFloat(sizeSlider.doubleValue)
        appDelegate?.circleRadius = radius
        updateSizeLabel()
    }

    @objc private func loginToggled() {
        do {
            if loginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Peek: Launch at Login failed — \(error.localizedDescription)")
            // Revert checkbox to match actual state
            let status = SMAppService.mainApp.status
            loginCheckbox.state = (status == .enabled) ? .on : .off
        }
    }

    private func updateSizeLabel() {
        let diameter = Int(sizeSlider.doubleValue * 2)
        sizeValueLabel.stringValue = "\(diameter)px"
    }
}
