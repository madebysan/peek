import Cocoa
import QuartzCore

/// Overlay styles for the privacy screen (controls the fill appearance)
enum OverlayStyle: Int {
    case lightBlur = 0   // Frosted glass — shapes/colors faintly visible
    case darkBlur = 1    // Dark frosted glass + dimming (default)
    case blackout = 2    // Solid black — nothing visible outside the circle
}

/// Edge transition styles (controls how the clear circle fades into the overlay)
enum EdgeTransition: Int {
    case soft = 0       // Smooth 60px feather (original)
    case hard = 1       // Sharp cutoff, no feathering
    case wide = 2       // Very gradual 150px fade
    case spotlight = 3  // Tight 30px aggressive falloff, like a flashlight
    case stepped = 4    // Visible discrete bands with clear jumps
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

    /// Visual style of the overlay (fill appearance)
    var style: OverlayStyle {
        didSet { applyStyle() }
    }

    /// Edge transition style (how the circle fades into the overlay)
    var edgeTransition: EdgeTransition {
        didSet { rebuildRingLayers() }
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

    /// Returns the ring configuration for a given edge transition
    private static func rings(for transition: EdgeTransition) -> [Ring] {
        switch transition {
        case .soft:
            // Original: smooth 60px feather
            return [
                Ring(radiusOffset: 60, opacity: 1.0),
                Ring(radiusOffset: 45, opacity: 0.50),
                Ring(radiusOffset: 30, opacity: 0.30),
                Ring(radiusOffset: 15, opacity: 0.20),
                Ring(radiusOffset: 0,  opacity: 0.10),
            ]
        case .hard:
            // Sharp cutoff — single ring, no feathering
            return [
                Ring(radiusOffset: 0, opacity: 1.0),
            ]
        case .wide:
            // Very gradual 150px fade
            return [
                Ring(radiusOffset: 150, opacity: 1.0),
                Ring(radiusOffset: 125, opacity: 0.35),
                Ring(radiusOffset: 100, opacity: 0.20),
                Ring(radiusOffset: 75,  opacity: 0.12),
                Ring(radiusOffset: 50,  opacity: 0.08),
                Ring(radiusOffset: 25,  opacity: 0.05),
                Ring(radiusOffset: 0,   opacity: 0.03),
            ]
        case .spotlight:
            // Tight 30px aggressive falloff — like a flashlight cone
            return [
                Ring(radiusOffset: 30, opacity: 1.0),
                Ring(radiusOffset: 24, opacity: 0.60),
                Ring(radiusOffset: 16, opacity: 0.40),
                Ring(radiusOffset: 8,  opacity: 0.25),
                Ring(radiusOffset: 0,  opacity: 0.15),
            ]
        case .stepped:
            // Visible discrete bands with clear opacity jumps (25px each)
            return [
                Ring(radiusOffset: 75, opacity: 1.0),
                Ring(radiusOffset: 50, opacity: 0.35),
                Ring(radiusOffset: 25, opacity: 0.25),
                Ring(radiusOffset: 0,  opacity: 0.15),
            ]
        }
    }

    // Mouse state
    private var lastMouseX: CGFloat = 0
    private var lastMouseY: CGFloat = 0
    private var mouseVisible = false

    init(frame: NSRect, circleRadius: CGFloat, style: OverlayStyle, edgeTransition: EdgeTransition) {
        self.circleRadius = circleRadius
        self.style = style
        self.edgeTransition = edgeTransition
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.circleRadius = 150
        self.style = .darkBlur
        self.edgeTransition = .soft
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

        // Build ring layers for the current edge transition
        rebuildRingLayers()
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

    /// Rebuilds the mask ring layers for the current edge transition.
    /// Called when edgeTransition changes or during initial setup.
    private func rebuildRingLayers() {
        // Remove existing ring layers
        for layer in ringLayers {
            layer.removeFromSuperlayer()
        }
        ringLayers.removeAll()

        // Create new ring layers for the current transition
        let rings = OverlayView.rings(for: edgeTransition)
        for ring in rings {
            let shapeLayer = CAShapeLayer()
            shapeLayer.fillRule = .evenOdd
            shapeLayer.fillColor = NSColor.black.cgColor
            shapeLayer.opacity = ring.opacity
            if let layerBounds = self.layer?.bounds {
                shapeLayer.frame = layerBounds
            }
            maskBase.addSublayer(shapeLayer)
            ringLayers.append(shapeLayer)
        }

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
        let currentRings = OverlayView.rings(for: edgeTransition)
        guard ringLayers.count == currentRings.count else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, ring) in currentRings.enumerated() {
            let r = circleRadius + ring.radiusOffset
            let path = CGMutablePath()

            // Oversized rect so edges extend beyond screen
            path.addRect(bounds.insetBy(dx: -200, dy: -200))

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
