import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {

    // Menu bar item
    private var statusItem: NSStatusItem!

    // Menu shown from the status item
    private let statusMenu = NSMenu()

    // One overlay window per screen
    private var overlayWindows: [OverlayWindow] = []

    // Whether the privacy screen is currently active
    private var isActive = false

    // Polls the public cursor-location API only while the overlay is active.
    // This avoids Accessibility or Input Monitoring permissions.
    private var mouseTrackingTimer: Timer?
    private var lastMouseLocation: NSPoint?

    // Settings window (single instance, reused)
    private var settingsWindow: SettingsWindow?

    // Global hotkey reference
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerInstalled = false

    // User preferences
    private let defaults = UserDefaults.standard
    private let circleRadiusKey = "circleRadius"
    private let overlayStyleKey = "overlayStyle"
    private let edgeTransitionKey = "edgeTransition"
    private let shortcutKeyCodeKey = "shortcutKeyCode"
    private let shortcutModifiersKey = "shortcutModifiers"

    // MARK: - Public properties for Settings UI

    /// Current circle radius (half the diameter). Persisted in UserDefaults.
    var circleRadius: CGFloat {
        get {
            let stored = defaults.double(forKey: circleRadiusKey)
            return stored > 0 ? stored : 150
        }
        set {
            defaults.set(newValue, forKey: circleRadiusKey)
            for window in overlayWindows {
                (window.contentView as? OverlayView)?.circleRadius = newValue
            }
        }
    }

    /// Current overlay style. Persisted in UserDefaults.
    var overlayStyle: OverlayStyle {
        get {
            let stored = defaults.integer(forKey: overlayStyleKey)
            return OverlayStyle(rawValue: stored) ?? .darkBlur
        }
        set {
            defaults.set(newValue.rawValue, forKey: overlayStyleKey)
            for window in overlayWindows {
                (window.contentView as? OverlayView)?.style = newValue
            }
        }
    }

    /// Current edge transition. Persisted in UserDefaults.
    var edgeTransition: EdgeTransition {
        get {
            let stored = defaults.integer(forKey: edgeTransitionKey)
            return EdgeTransition(rawValue: stored) ?? .soft
        }
        set {
            defaults.set(newValue.rawValue, forKey: edgeTransitionKey)
            for window in overlayWindows {
                (window.contentView as? OverlayView)?.edgeTransition = newValue
            }
        }
    }

    /// Current keyboard shortcut. Persisted in UserDefaults.
    var currentShortcut: KeyboardShortcut {
        get {
            // If no value stored, return the default (⌥⌘P)
            guard defaults.object(forKey: shortcutKeyCodeKey) != nil else {
                return .defaultShortcut
            }
            let code = UInt32(defaults.integer(forKey: shortcutKeyCodeKey))
            let mods = UInt32(defaults.integer(forKey: shortcutModifiersKey))
            return KeyboardShortcut(keyCode: code, carbonModifiers: mods)
        }
        set {
            let previous = currentShortcut
            defaults.set(Int(newValue.keyCode), forKey: shortcutKeyCodeKey)
            defaults.set(Int(newValue.carbonModifiers), forKey: shortcutModifiersKey)

            // Re-register the hotkey with the new shortcut
            if !reregisterHotKey() {
                // Registration failed (shortcut conflict) — revert
                defaults.set(Int(previous.keyCode), forKey: shortcutKeyCodeKey)
                defaults.set(Int(previous.carbonModifiers), forKey: shortcutModifiersKey)

                let alert = NSAlert()
                alert.messageText = "Shortcut Unavailable"
                alert.informativeText = "The shortcut \(newValue.displayString) could not be registered. It may conflict with another application. The previous shortcut \(previous.displayString) has been restored."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()

                // Re-register the previous working shortcut
                _ = reregisterHotKey()
            }

            updateToggleMenuItem()
        }
    }

    var isOverlayActive: Bool {
        return isActive
    }

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Peek")
            button.toolTip = "Peek — click for controls"
        }

        // Use a standard menu so Quit is visible from a normal click.
        buildMenu()
        statusItem.menu = statusMenu

        // Listen for screen configuration changes (monitors connected/disconnected)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Register global hotkey ⌥⌘P
        registerHotKey()

        #if DEBUG
        let arguments = Set(ProcessInfo.processInfo.arguments)
        if arguments.contains("--show-settings") {
            DispatchQueue.main.async { [weak self] in self?.openSettings() }
        } else if arguments.contains("--show-about") {
            DispatchQueue.main.async { [weak self] in self?.openAbout() }
        } else if arguments.contains("--show-menu") {
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.button?.performClick(nil)
            }
        }
        if arguments.contains("--activate-overlay") {
            DispatchQueue.main.async { [weak self] in self?.activate() }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }

    // MARK: - Menu

    private func buildMenu() {
        statusMenu.removeAllItems()

        let sc = currentShortcut
        let toggleTitle = isActive ? "Turn Peek Off" : "Turn Peek On"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: sc.keyEquivalentCharacter)
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = sc.appKitModifierMask
        statusMenu.addItem(toggleItem)

        statusMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About Peek", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        statusMenu.addItem(aboutItem)

        let privacyItem = NSMenuItem(title: "Privacy Policy", action: #selector(openPrivacyPolicy), keyEquivalent: "")
        privacyItem.target = self
        statusMenu.addItem(privacyItem)

        statusMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Peek", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    // MARK: - Menu actions

    @objc private func toggleFromMenu() {
        toggle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(appDelegate: self)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        let credits = NSMutableAttributedString(
            string: "A digital privacy screen for macOS.\n\nBlurs your screen with a clear circle that follows your mouse.\n\nMade by santiagoalonso.com",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let siteText = "santiagoalonso.com"
        let siteRange = (credits.string as NSString).range(of: siteText)
        if let siteURL = URL(string: "https://santiagoalonso.com") {
            credits.addAttribute(.link, value: siteURL, range: siteRange)
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Peek",
            .applicationVersion: version,
            .version: build,
            .credits: credits
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPrivacyPolicy() {
        guard let url = URL(string: "https://github.com/madebysan/peek/blob/main/PRIVACY.md") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Toggle overlay on/off

    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    private func activate() {
        isActive = true
        createOverlayWindows()
        startMouseTracking()
        updateMenuBarIcon()
    }

    private func deactivate() {
        isActive = false
        stopMouseTracking()
        removeOverlayWindows()
        updateMenuBarIcon()
    }

    private func updateMenuBarIcon() {
        let symbolName = isActive ? "eye.circle.fill" : "eye.circle"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Peek"
        )
        updateToggleMenuItem()
    }

    // MARK: - Overlay windows (one per screen)

    private func createOverlayWindows() {
        removeOverlayWindows()

        let style = overlayStyle
        let radius = circleRadius
        let edge = edgeTransition

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen, circleRadius: radius, style: style, edgeTransition: edge)
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
    }

    private func removeOverlayWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    @objc private func screenParametersChanged() {
        if isActive {
            createOverlayWindows()
            updateMousePosition(force: true)
        }
    }

    // MARK: - Mouse tracking

    private func startMouseTracking() {
        stopMouseTracking()
        updateMousePosition(force: true)

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateMousePosition()
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTrackingTimer = timer
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        lastMouseLocation = nil
    }

    private func updateMousePosition(force: Bool = false) {
        let mouseLocation = NSEvent.mouseLocation
        guard force || mouseLocation != lastMouseLocation else { return }
        lastMouseLocation = mouseLocation

        for window in overlayWindows {
            guard let screen = window.screen ?? NSScreen.main else { continue }
            let overlayView = window.contentView as? OverlayView

            // Convert global mouse coordinates to screen-local (bottom-left origin)
            // Both NSEvent.mouseLocation and CGContext use bottom-left, so no flip needed
            let localX = mouseLocation.x - screen.frame.origin.x
            let localY = mouseLocation.y - screen.frame.origin.y

            let isOnThisScreen = screen.frame.contains(mouseLocation)
            overlayView?.updateMousePosition(x: localX, y: localY, visible: isOnThisScreen)
        }
    }

    // MARK: - Menu item sync

    /// Keep the menu item label and shortcut in sync with the current state.
    private func updateToggleMenuItem() {
        guard let toggleItem = statusMenu.items.first(where: { $0.action == #selector(toggleFromMenu) }) else { return }
        let sc = currentShortcut
        toggleItem.title = isActive ? "Turn Peek Off" : "Turn Peek On"
        toggleItem.keyEquivalent = sc.keyEquivalentCharacter
        toggleItem.keyEquivalentModifierMask = sc.appKitModifierMask
    }

    // MARK: - Global hotkey

    /// Install the Carbon event handler (once at launch).
    private func installHotKeyHandler() {
        guard !hotKeyHandlerInstalled else { return }
        hotKeyHandlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil
        )
    }

    /// Register the hotkey using the current shortcut. Returns true on success.
    @discardableResult
    private func registerHotKey() -> Bool {
        // Install the event handler if it hasn't been installed yet
        installHotKeyHandler()

        let sc = currentShortcut
        let hotKeyID = EventHotKeyID(signature: OSType(0x5065656B), // "Peek" in ASCII
                                      id: 1)

        let status = RegisterEventHotKey(
            sc.keyCode,
            sc.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Peek: Failed to register hotkey \(sc.displayString) (error \(status))")
            return false
        }
        return true
    }

    private func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    /// Unregister the old hotkey and register the new one. Returns true on success.
    @discardableResult
    private func reregisterHotKey() -> Bool {
        unregisterHotKey()
        return registerHotKey()
    }
}

// C-style callback for the Carbon hotkey event — calls toggle() on the AppDelegate
private func hotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        appDelegate.toggle()
    }
    return noErr
}
