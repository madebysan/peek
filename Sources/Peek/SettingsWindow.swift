import Cocoa
import ServiceManagement

/// Settings window: a live preview of the overlay above one aligned form of controls.
class SettingsWindow: NSWindow {

    private weak var appDelegate: AppDelegate?
    private var preview: OverlayPreviewView!
    private var styleSegment: NSSegmentedControl!
    private var intensitySlider: NSSlider!
    private var intensityValueLabel: NSTextField!
    private var softnessSlider: NSSlider!
    private var softnessValueLabel: NSTextField!
    private var sizeSlider: NSSlider!
    private var sizeValueLabel: NSTextField!
    private var shortcutRecorder: ShortcutRecorderView!
    private var loginCheckbox: NSButton!
    private var saveDefaultButton: NSButton!
    private var restoreDefaultButton: NSButton!

    // Layout constants (4-pt rhythm)
    private let margin: CGFloat = 20
    private let sliderWidth: CGFloat = 232
    private let valueWidth: CGFloat = 52

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Peek Settings"
        self.isReleasedWhenClosed = false

        setupUI()
        syncFromPreferences()
        self.center()
    }

    // MARK: - Layout

    private func setupUI() {
        preview = OverlayPreviewView()
        preview.translatesAutoresizingMaskIntoConstraints = false

        styleSegment = NSSegmentedControl(labels: ["Light Blur", "Dark Blur", "Blackout"], trackingMode: .selectOne, target: self, action: #selector(styleChanged))
        styleSegment.segmentDistribution = .fillEqually
        styleSegment.translatesAutoresizingMaskIntoConstraints = false
        styleSegment.widthAnchor.constraint(equalToConstant: sliderWidth + 8 + valueWidth).isActive = true

        (intensitySlider, intensityValueLabel) = makeSliderParts(min: 0.05, max: 1, action: #selector(intensityChanged))
        (softnessSlider, softnessValueLabel) = makeSliderParts(min: 0, max: 200, action: #selector(softnessChanged))
        (sizeSlider, sizeValueLabel) = makeSliderParts(min: 50, max: 600, action: #selector(sizeChanged))

        shortcutRecorder = ShortcutRecorderView(frame: .zero, shortcut: appDelegate?.currentShortcut ?? .defaultShortcut)
        shortcutRecorder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shortcutRecorder.widthAnchor.constraint(equalToConstant: 112),
            shortcutRecorder.heightAnchor.constraint(equalToConstant: 24),
        ])
        shortcutRecorder.toolTip = "Click, then press a new shortcut. Esc cancels."
        shortcutRecorder.onChange = { [weak self] newShortcut in
            self?.appDelegate?.currentShortcut = newShortcut
            // If the shortcut was reverted (conflict), sync the recorder back
            if let current = self?.appDelegate?.currentShortcut, current != newShortcut {
                self?.shortcutRecorder.shortcut = current
            }
        }

        let shortcutHint = NSTextField(labelWithString: "Turns Peek on and off from any app.")
        shortcutHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        shortcutHint.textColor = .secondaryLabelColor

        let shortcutStack = NSStackView(views: [shortcutRecorder, shortcutHint])
        shortcutStack.orientation = .vertical
        shortcutStack.alignment = .leading
        shortcutStack.spacing = 6

        loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(loginToggled))

        let shortcutLabel = formLabel("Shortcut:")
        // Save the current look, or go back to the saved one
        restoreDefaultButton = NSButton(title: "Restore Default", target: self, action: #selector(restoreDefault))
        restoreDefaultButton.toolTip = "Go back to your saved default look"
        saveDefaultButton = NSButton(title: "Save as Default", target: self, action: #selector(saveAsDefault))
        saveDefaultButton.toolTip = "Keep this style, intensity, softness and size as your default"
        for button in [restoreDefaultButton!, saveDefaultButton!] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        }
        let defaultsRow = NSStackView(views: [restoreDefaultButton, saveDefaultButton])
        defaultsRow.orientation = .horizontal
        defaultsRow.spacing = 8

        let grid = NSGridView(views: [
            [formLabel("Style:"), styleSegment],
            [formLabel("Intensity:"), sliderRow(intensitySlider, intensityValueLabel)],
            [formLabel("Edge softness:"), sliderRow(softnessSlider, softnessValueLabel)],
            [formLabel("Circle size:"), sliderRow(sizeSlider, sizeValueLabel)],
            [NSGridCell.emptyContentView, defaultsRow],
            [separator(), NSGridCell.emptyContentView],
            [shortcutLabel, shortcutStack],
            [NSGridCell.emptyContentView, loginCheckbox],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        for i in 0..<grid.numberOfRows {
            grid.row(at: i).yPlacement = .center
        }

        // Separator spans both columns with extra air around it
        grid.row(at: 4).topPadding = -2
        let separatorRow = grid.row(at: 5)
        separatorRow.mergeCells(in: NSRange(location: 0, length: 2))
        separatorRow.cell(at: 0).xPlacement = .fill
        separatorRow.topPadding = 4
        separatorRow.bottomPadding = 4

        // Label lines up with the shortcut field, not the field-plus-hint stack
        grid.row(at: 6).yPlacement = .top
        let shortcutLabelCell = grid.cell(atColumnIndex: 0, rowIndex: 6)
        shortcutLabelCell.yPlacement = .none
        shortcutLabelCell.customPlacementConstraints = [
            shortcutLabel.centerYAnchor.constraint(equalTo: shortcutRecorder.centerYAnchor),
        ]
        grid.row(at: 7).topPadding = 4

        let quitButton = NSButton(title: "Quit Peek", target: appDelegate, action: #selector(AppDelegate.quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.toolTip = "Quit Peek completely"
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        let footerSeparator = separator()

        let content = NSView()
        for view in [preview!, grid, footerSeparator, quitButton] {
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: content.topAnchor, constant: margin),
            preview.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin),
            preview.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -margin),
            preview.heightAnchor.constraint(equalToConstant: 148),

            grid.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 20),
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: margin),

            footerSeparator.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 20),
            footerSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footerSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            quitButton.topAnchor.constraint(equalTo: footerSeparator.bottomAnchor, constant: 12),
            quitButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -margin),
            quitButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),

            content.widthAnchor.constraint(equalToConstant: 460),
        ])

        self.contentView = content
        content.layoutSubtreeIfNeeded()
        setContentSize(content.fittingSize)
        self.initialFirstResponder = styleSegment
    }

    private func formLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    private func makeSliderParts(min: Double, max: Double, action: Selector) -> (NSSlider, NSTextField) {
        let slider = NSSlider(value: min, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: sliderWidth).isActive = true

        let value = NSTextField(labelWithString: "")
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.alignment = .right
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: valueWidth).isActive = true
        return (slider, value)
    }

    private func sliderRow(_ slider: NSSlider, _ value: NSTextField) -> NSStackView {
        let row = NSStackView(views: [slider, value])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    // MARK: - State

    /// Read current values from AppDelegate and update the controls
    private func syncFromPreferences() {
        guard let app = appDelegate else { return }
        styleSegment.selectedSegment = app.overlayStyle.rawValue
        intensitySlider.doubleValue = Double(app.overlayIntensity)
        softnessSlider.doubleValue = Double(app.edgeSoftness)
        sizeSlider.doubleValue = Double(app.circleRadius)
        shortcutRecorder.shortcut = app.currentShortcut
        updateValueLabels()
        updatePreview()

        // Sync launch at login checkbox from system state
        let status = SMAppService.mainApp.status
        loginCheckbox.state = (status == .enabled) ? .on : .off
    }

    private func updateValueLabels() {
        intensityValueLabel.stringValue = "\(Int((intensitySlider.doubleValue * 100).rounded()))%"
        let softness = Int(softnessSlider.doubleValue.rounded())
        softnessValueLabel.stringValue = softness < 4 ? "Sharp" : "\(softness) px"
        sizeValueLabel.stringValue = "\(Int(sizeSlider.doubleValue * 2)) px"
    }

    private func updatePreview() {
        guard let app = appDelegate else { return }
        updateDefaultButtons()
        preview.apply(style: app.overlayStyle, intensity: app.overlayIntensity,
                      edgeSoftness: app.edgeSoftness, circleRadius: app.circleRadius)
    }

    /// Both buttons do nothing while the current look already is the default
    private func updateDefaultButtons() {
        guard let app = appDelegate else { return }
        let isDefault = app.currentLook.matches(app.defaultLook)
        saveDefaultButton.isEnabled = !isDefault
        restoreDefaultButton.isEnabled = !isDefault
    }

    // MARK: - Actions

    @objc private func saveAsDefault() {
        appDelegate?.saveCurrentLookAsDefault()
        updateDefaultButtons()
    }

    @objc private func restoreDefault() {
        appDelegate?.restoreDefaultLook()
        syncFromPreferences()
    }

    @objc private func styleChanged() {
        guard let newStyle = OverlayStyle(rawValue: styleSegment.selectedSegment) else { return }
        appDelegate?.overlayStyle = newStyle
        updatePreview()
    }

    @objc private func intensityChanged() {
        appDelegate?.overlayIntensity = CGFloat(intensitySlider.doubleValue)
        updateValueLabels()
        updatePreview()
    }

    @objc private func softnessChanged() {
        appDelegate?.edgeSoftness = CGFloat(softnessSlider.doubleValue.rounded())
        updateValueLabels()
        updatePreview()
    }

    @objc private func sizeChanged() {
        appDelegate?.circleRadius = CGFloat(sizeSlider.doubleValue)
        updateValueLabels()
        updatePreview()
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
}

// MARK: - Preview

/// A scaled-down stand-in for the screen: sample content under a real OverlayView
/// that blurs within the window. The circle follows the pointer while it's over the preview.
private class OverlayPreviewView: NSView {

    /// Preview size relative to the real screen, applied to the circle and fade
    private let scale: CGFloat = 0.3

    private let sample = SampleContentView()
    private let overlay = OverlayView(frame: .zero, circleRadius: 45, style: .darkBlur,
                                      edgeSoftness: 36, intensity: 1, blendingMode: .withinWindow)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        addSubview(sample)
        addSubview(overlay)

        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Preview of the overlay")
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    func apply(style: OverlayStyle, intensity: CGFloat, edgeSoftness: CGFloat, circleRadius: CGFloat) {
        overlay.style = style
        overlay.intensity = intensity
        overlay.edgeSoftness = edgeSoftness * scale
        overlay.circleRadius = circleRadius * scale
    }

    override func layout() {
        super.layout()
        sample.frame = bounds
        overlay.frame = bounds
        centerCircle()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func centerCircle() {
        overlay.updateMousePosition(x: bounds.midX, y: bounds.midY, visible: true)
    }

    // Follow the pointer inside the preview
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        overlay.updateMousePosition(x: p.x, y: p.y, visible: true)
    }

    override func mouseExited(with event: NSEvent) {
        centerCircle()
    }
}

/// Generic document-like content for the preview: a sidebar, a heading, text lines and an image block.
/// Drawn at roughly the same 0.3 scale as the circle so the proportions read true.
/// Always a light page, so every style (including Blackout) reads clearly in both appearances.
private class SampleContentView: NSView {

    override var isFlipped: Bool { true }

    private let ink = NSColor(white: 0.1, alpha: 1)

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        // Sidebar
        let sidebar = NSRect(x: 0, y: 0, width: 92, height: bounds.height)
        NSColor(white: 0.95, alpha: 1).setFill()
        sidebar.fill()
        ink.withAlphaComponent(0.3).setFill()
        for (i, width) in [52, 40, 60, 34, 48, 44, 56].enumerated() {
            bar(x: 12, y: 16 + CGFloat(i) * 13, width: CGFloat(width), height: 5)
        }

        // Heading
        ink.withAlphaComponent(0.85).setFill()
        bar(x: 112, y: 16, width: 120, height: 8)

        // Image block
        let image = NSRect(x: bounds.width - 128, y: 16, width: 112, height: 72)
        let gradient = NSGradient(starting: .systemTeal, ending: .systemIndigo)
        gradient?.draw(in: NSBezierPath(roundedRect: image, xRadius: 4, yRadius: 4), angle: -60)

        // Paragraph lines beside the image, then full-width lines below it
        ink.withAlphaComponent(0.45).setFill()
        let textLeft: CGFloat = 112
        var y: CGFloat = 36
        for fraction: CGFloat in [1, 0.92, 0.97, 0.6, 0, 1] {
            if fraction > 0 {
                bar(x: textLeft, y: y, width: (image.minX - 16 - textLeft) * fraction, height: 4)
            }
            y += 9
        }
        for fraction: CGFloat in [0.88, 0.95, 0.4, 0, 0.97, 0.9, 0.96, 0.7] where y < bounds.height - 8 {
            if fraction > 0 {
                bar(x: textLeft, y: y, width: (bounds.width - 16 - textLeft) * fraction, height: 4)
            }
            y += 9
        }
    }

    private func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height),
                     xRadius: height / 2, yRadius: height / 2).fill()
    }
}
