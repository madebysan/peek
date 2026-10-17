import Cocoa
import QuartzCore

/// Overlay styles for the privacy screen (controls the fill appearance)
enum OverlayStyle: Int, Codable {
    case lightBlur = 0   // Frosted glass — shapes/colors faintly visible
    case darkBlur = 1    // Dark frosted glass + dimming (default)
    case blackout = 2    // Solid black — nothing visible outside the circle
}

/// The main overlay view: a fullscreen blur/tint with a circular reveal hole following the mouse.
///
/// The mask has two layers:
/// - A black CAShapeLayer covering the screen, with an even-odd hole of the circle radius plus the fade
/// - A radial CAGradientLayer filling that hole, clear in the middle and black at its rim,
///   so the edge fades continuously with no visible bands
/// Per frame: one path update and one frame move (trivial CPU). All rendering is GPU-accelerated.
class OverlayView: NSView {

    /// Radius of the clear circle around the mouse
    var circleRadius: CGFloat {
        didSet { updateFadeGradient() }
    }

    /// Visual style of the overlay (fill appearance)
    var style: OverlayStyle {
        didSet { applyStyle() }
    }

    /// Width in px of the fade from the clear circle into the overlay. 0 is a hard edge.
    var edgeSoftness: CGFloat {
        didSet { updateFadeGradient() }
    }

    /// Strength of the overlay, 0...1. Fades the whole blur/tint so it can range
    /// from barely there to the full style (fully black for Blackout).
    var intensity: CGFloat {
        didSet { alphaValue = intensity }
    }

    /// .behindWindow for the real overlay; .withinWindow for the Settings preview
    private let blendingMode: NSVisualEffectView.BlendingMode

    // Subviews
    private let blurView = NSVisualEffectView()
    private let tintView = NSView()

    // Mask layers
    private let maskBase = CALayer()
    private let coverLayer = CAShapeLayer()
    private let fadeLayer = CAGradientLayer()

    /// Outer radius of the fade: where the overlay reaches full strength
    private var outerRadius: CGFloat {
        circleRadius + max(edgeSoftness, 0)
    }

    // Mouse state
    private var lastMouseX: CGFloat = 0
    private var lastMouseY: CGFloat = 0
    private var mouseVisible = false

    init(frame: NSRect, circleRadius: CGFloat, style: OverlayStyle, edgeSoftness: CGFloat, intensity: CGFloat,
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.blendingMode = blendingMode
        self.circleRadius = circleRadius
        self.style = style
        self.edgeSoftness = edgeSoftness
        self.intensity = intensity
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.circleRadius = 150
        self.style = .darkBlur
        self.edgeSoftness = 120
        self.intensity = 1
        self.blendingMode = .behindWindow
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Blur view fills the entire overlay
        blurView.frame = bounds
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = blendingMode
        blurView.state = .active
        addSubview(blurView)

        // Tint view on top for additional darkening
        tintView.frame = bounds
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        addSubview(tintView)

        // Mask: solid outside the fade, radial gradient across it
        coverLayer.fillRule = .evenOdd
        coverLayer.fillColor = NSColor.black.cgColor
        fadeLayer.type = .radial
        fadeLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        fadeLayer.endPoint = CGPoint(x: 1, y: 1)
        maskBase.addSublayer(coverLayer)
        maskBase.addSublayer(fadeLayer)
        updateFadeGradient()
        applyStyle()
        alphaValue = intensity
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
        coverLayer.frame = layer.bounds
        layer.mask = maskBase
        updateMaskPaths()
    }

    /// Rebuilds the gradient stops for the current radius and softness.
    /// Alpha follows a smoothstep curve from 0 at the circle edge to 1 at the outer radius.
    private func updateFadeGradient() {
        let outer = outerRadius
        let inner = outer > 0 ? Double(circleRadius / outer) : 1
        let stops = 12
        var colors: [CGColor] = [CGColor(gray: 0, alpha: 0)]
        var locations: [NSNumber] = [0]
        for i in 0...stops {
            let t = Double(i) / Double(stops)
            colors.append(CGColor(gray: 0, alpha: t * t * (3 - 2 * t)))
            locations.append(NSNumber(value: inner + (1 - inner) * t))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeLayer.colors = colors
        fadeLayer.locations = locations
        fadeLayer.isHidden = edgeSoftness < 1
        CATransaction.commit()

        updateMaskPaths()
    }

    /// Move the clear circle to follow the mouse.
    func updateMousePosition(x: CGFloat, y: CGFloat, visible: Bool) {
        lastMouseX = x
        lastMouseY = y
        mouseVisible = visible
        updateMaskPaths()
    }

    /// Moves the hole and the gradient to the cursor — the only per-frame work.
    private func updateMaskPaths() {
        let r = edgeSoftness < 1 ? circleRadius : outerRadius
        let circle = CGRect(x: lastMouseX - r, y: lastMouseY - r, width: r * 2, height: r * 2)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Oversized rect so edges extend beyond screen; even-odd makes the circle a hole
        let path = CGMutablePath()
        path.addRect(bounds.insetBy(dx: -200, dy: -200))
        if mouseVisible {
            path.addEllipse(in: circle)
        }
        coverLayer.path = path

        fadeLayer.frame = circle
        fadeLayer.opacity = mouseVisible ? 1 : 0

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        if let layer = self.layer {
            maskBase.frame = layer.bounds
            coverLayer.frame = layer.bounds
        }
        updateMaskPaths()
    }
}
