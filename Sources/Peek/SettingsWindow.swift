import Cocoa

/// Settings window with circle size slider and overlay style picker.
class SettingsWindow: NSWindow {

    private weak var appDelegate: AppDelegate?
    private var sizeSlider: NSSlider!
    private var sizeValueLabel: NSTextField!
    private var styleSegment: NSSegmentedControl!

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
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
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 220))

        let padding: CGFloat = 20
        var y: CGFloat = 176

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

        self.contentView = contentView
    }

    /// Read current values from AppDelegate and update the controls
    private func syncFromPreferences() {
        guard let app = appDelegate else { return }
        sizeSlider.doubleValue = Double(app.circleRadius)
        styleSegment.selectedSegment = app.overlayStyle.rawValue
        updateSizeLabel()
    }

    @objc private func styleChanged() {
        guard let newStyle = OverlayStyle(rawValue: styleSegment.selectedSegment) else { return }
        appDelegate?.overlayStyle = newStyle
    }

    @objc private func sizeChanged() {
        let radius = CGFloat(sizeSlider.doubleValue)
        appDelegate?.circleRadius = radius
        updateSizeLabel()
    }

    private func updateSizeLabel() {
        let diameter = Int(sizeSlider.doubleValue * 2)
        sizeValueLabel.stringValue = "\(diameter)px"
    }
}
