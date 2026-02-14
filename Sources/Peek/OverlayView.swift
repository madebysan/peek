import Cocoa
import QuartzCore

/// Overlay styles for the privacy screen
enum OverlayStyle: Int {
    case lightBlur = 0   // Frosted glass — shapes/colors faintly visible
    case darkBlur = 1    // Dark frosted glass + dimming (default)
    case blackout = 2    // Solid black — nothing visible outside the circle
}

/// The main overlay view: a fullscreen blur/tint with a circular reveal hole following the mouse.
///
/// Performance approach:
/// - 5 concentric CAShapeLayer rings as the mask (no CIFilter, no CGImage rendering)
/// - Each ring has even-odd fill (rect + circle cutout) with graduated opacity
/// - They composite via sourceOver to create a smooth alpha gradient from 0→1
/// - Per frame: just 5 path updates (trivial CPU). All rendering is GPU-accelerated.
class OverlayView: NSView {

    /// Radius of the clear circle around the mouse
    var circleRadius: CGFloat {
        didSet { updateMaskPaths() }
    }

    /// Visual style of the overlay
    var style: OverlayStyle {
        didSet { applyStyle() }
    }

    // Subviews
    private let blurView = NSVisualEffectView()
    private let tintView = NSView()

    // Mask: transparent base with ring sublayers that build up alpha
    private let maskBase = CALayer()
    private var ringLayers: [CAShapeLayer] = []

    // Ring configuration: radiusOffset from circleRadius, and opacity.
    // Ordered bottom to top. Bottom layer ensures full opacity outside the soft zone.
    // The graduated opacities composite (sourceOver) into a smooth 0→1 curve.
    private struct Ring {
        let radiusOffset: CGFloat
        let opacity: Float
    }

    private let rings: [Ring] = [
        Ring(radiusOffset: 60, opacity: 1.0),    // Base: full coverage beyond outer edge
        Ring(radiusOffset: 45, opacity: 0.50),   // Outer fade
        Ring(radiusOffset: 30, opacity: 0.30),   // Mid fade
        Ring(radiusOffset: 15, opacity: 0.20),   // Inner fade
        Ring(radiusOffset: 0,  opacity: 0.10),   // Faintest ring at circle edge
    ]

    // Mouse state
    private var lastMouseX: CGFloat = 0
    private var lastMouseY: CGFloat = 0
    private var mouseVisible = false

    init(frame: NSRect, circleRadius: CGFloat, style: OverlayStyle) {
        self.circleRadius = circleRadius
        self.style = style
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.circleRadius = 150
        self.style = .darkBlur
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Blur view fills the entire overlay
        blurView.frame = bounds
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        addSubview(blurView)

        // Tint view on top for additional darkening
        tintView.frame = bounds
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        addSubview(tintView)

        // Create the ring layers (bottom to top)
        for ring in rings {
            let shapeLayer = CAShapeLayer()
            shapeLayer.fillRule = .evenOdd
            shapeLayer.fillColor = NSColor.black.cgColor
            shapeLayer.opacity = ring.opacity
            maskBase.addSublayer(shapeLayer)
            ringLayers.append(shapeLayer)
        }

        applyStyle()
    }

    private func applyStyle() {
        switch style {
        case .lightBlur:
            blurView.isHidden = false
            blurView.material = .fullScreenUI
            blurView.appearance = NSAppearance(named: .aqua)
            tintView.layer?.backgroundColor = CGColor(gray: 1, alpha: 0.1)

        case .darkBlur:
            blurView.isHidden = false
            blurView.material = .hudWindow
            blurView.appearance = NSAppearance(named: .darkAqua)
            tintView.layer?.backgroundColor = CGColor(gray: 0, alpha: 0.3)

        case .blackout:
            blurView.isHidden = true
            tintView.layer?.backgroundColor = CGColor(gray: 0, alpha: 1.0)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let layer = self.layer else { return }
        maskBase.frame = layer.bounds
        for ringLayer in ringLayers {
            ringLayer.frame = layer.bounds
        }
        layer.mask = maskBase
        updateMaskPaths()
    }

    /// Move the clear circle to follow the mouse.
    func updateMousePosition(x: CGFloat, y: CGFloat, visible: Bool) {
        lastMouseX = x
        lastMouseY = y
        mouseVisible = visible
        updateMaskPaths()
    }

    /// Updates all ring paths — the only per-frame work.
    private func updateMaskPaths() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, ring) in rings.enumerated() {
            let r = circleRadius + ring.radiusOffset
            let path = CGMutablePath()

            // Oversized rect so edges extend beyond screen
            path.addRect(bounds.insetBy(dx: -100, dy: -100))

            // Circle cutout (even-odd makes this a hole)
            if mouseVisible {
                path.addEllipse(in: CGRect(
                    x: lastMouseX - r,
                    y: lastMouseY - r,
                    width: r * 2,
                    height: r * 2
                ))
            }

            ringLayers[i].path = path
        }

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        if let layer = self.layer {
            maskBase.frame = layer.bounds
            for ringLayer in ringLayers {
                ringLayer.frame = layer.bounds
            }
        }
        updateMaskPaths()
    }
}
