import Cocoa

/// A fullscreen borderless window that covers a single display.
/// It sits above everything and passes all mouse events through to apps underneath.
class OverlayWindow: NSWindow {

    init(screen: NSScreen, circleRadius: CGFloat, style: OverlayStyle) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Position on the correct screen
        self.setFrame(screen.frame, display: true)

        // Transparent window background (the blur/tint comes from the overlay view)
        self.backgroundColor = .clear
        self.isOpaque = false

        // Sit above almost everything
        self.level = .init(rawValue: NSWindow.Level.screenSaver.rawValue - 1)

        // Allow the window to appear on all Spaces and alongside fullscreen apps
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Critical: let all mouse events pass through to apps underneath
        self.ignoresMouseEvents = true

        // Don't show in the window switcher or Expose
        self.hidesOnDeactivate = false

        // Set up the overlay view with blur + mask
        let overlayView = OverlayView(frame: screen.frame, circleRadius: circleRadius, style: style)
        self.contentView = overlayView
    }
}
