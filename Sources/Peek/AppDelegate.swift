import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    // Menu bar item
    private var statusItem: NSStatusItem!

    // Right-click menu
    private let statusMenu = NSMenu()

    // One overlay window per screen
    private var overlayWindows: [OverlayWindow] = []

    // Whether the privacy screen is currently active
    private var isActive = false

    // Mouse monitor references (global + local for full coverage)
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    // Settings window (single instance, reused)
    private var settingsWindow: SettingsWindow?

    // User preferences
    private let defaults = UserDefaults.standard
    private let circleRadiusKey = "circleRadius"
    private let overlayStyleKey = "overlayStyle"

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

    var isOverlayActive: Bool {
        return isActive
    }

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Peek")
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Build the right-click menu
        buildMenu()

        // Listen for screen configuration changes (monitors connected/disconnected)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Menu

    private func buildMenu() {
        statusMenu.removeAllItems()

        let toggleItem = NSMenuItem(title: "Toggle Peek", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleItem.target = self
        statusMenu.addItem(toggleItem)

        statusMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About Peek", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        statusMenu.addItem(aboutItem)

        statusMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Peek", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    // MARK: - Status item click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show the menu
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            // Remove the menu after it closes so left-click still toggles
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            // Left-click: toggle the overlay
            toggle()
        }
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
        let credits = NSAttributedString(
            string: "A digital privacy screen for macOS.\n\nBlurs your screen with a clear circle that follows your mouse. Keep your content private from wandering eyes while you work.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Peek",
            .applicationVersion: "1.0",
            .version: "1",
            .credits: credits
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
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
    }

    // MARK: - Overlay windows (one per screen)

    private func createOverlayWindows() {
        removeOverlayWindows()

        let style = overlayStyle
        let radius = circleRadius

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen, circleRadius: radius, style: style)
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
        }
    }

    // MARK: - Mouse tracking

    private func startMouseTracking() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]

        // Global monitor: tracks mouse in all OTHER apps
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            self?.handleMouseMoved()
        }

        // Local monitor: tracks mouse when Peek's own windows are focused (Settings, About)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }

        // Update immediately so the circle appears at the current position
        handleMouseMoved()
    }

    private func stopMouseTracking() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
    }

    private func handleMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation

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
}
