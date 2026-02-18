import Cocoa
import Carbon

/// A clickable field that records a keyboard shortcut.
/// Click to start recording, press a modifier+key combo to set it, Escape to cancel.
class ShortcutRecorderView: NSView {

    /// Called when the user records a valid new shortcut.
    var onChange: ((KeyboardShortcut) -> Void)?

    /// The currently displayed shortcut.
    var shortcut: KeyboardShortcut {
        didSet { needsDisplay = true }
    }

    private var isRecording = false

    // MARK: - Init

    init(frame: NSRect, shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - First responder

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        // Background
        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()

        // Border
        if isRecording {
            NSColor.controlAccentColor.setStroke()
        } else {
            NSColor.separatorColor.setStroke()
        }
        path.lineWidth = 1
        path.stroke()

        // Text
        let text: String
        let color: NSColor
        if isRecording {
            text = "Type shortcut\u{2026}"
            color = .placeholderTextColor
        } else {
            text = shortcut.displayString
            color = .labelColor
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        // Click to start recording
        if !isRecording {
            window?.makeFirstResponder(self)
        }
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode

        // Escape cancels recording
        if keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }

        // Reject Tab and Return (reserved for UI navigation)
        if keyCode == UInt16(kVK_Tab) || keyCode == UInt16(kVK_Return) {
            NSSound.beep()
            return
        }

        // Check that at least one modifier is held (Command, Option, Control, or Shift)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifier = !modifiers.intersection([.command, .option, .control, .shift]).isEmpty

        if !hasModifier {
            NSSound.beep()
            return
        }

        // Build the new shortcut
        let carbonMods = KeyboardShortcut.appKitToCarbonModifiers(modifiers)
        let newShortcut = KeyboardShortcut(keyCode: UInt32(keyCode), carbonModifiers: carbonMods)

        shortcut = newShortcut
        window?.makeFirstResponder(nil)
        onChange?(newShortcut)
    }

    // Ignore modifier-only presses (flagsChanged fires for bare Shift, etc.)
    override func flagsChanged(with event: NSEvent) {
        // No-op: we only act on keyDown which has a real key code
    }
}
