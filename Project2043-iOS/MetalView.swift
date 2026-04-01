import UIKit
import Metal
import QuartzCore
import Engine2043

final class MetalView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    private var metalLayer: CAMetalLayer { self.layer as! CAMetalLayer }
    private var engine: GameEngine!
    private var displayLink: CADisplayLink!
    private var lastTimestamp: CFTimeInterval = 0
    private var touchInput: TouchInputProvider!
    private var sceneManager: SceneManager!
    private var viewportManager: ViewportManager!

    // Control overlays
    private var fireOverlay: UIView!
    private var bombOverlay: UIView!
    private var empOverlay: UIView!
    private var ocOverlay: UIView!
    private var joystickBase: UIView!
    private var joystickKnob: UIView!

    private var defaultJoystickCenter: CGPoint {
        CGPoint(x: 60 + safeAreaInsets.left, y: bounds.height - 60 - safeAreaInsets.bottom)
    }

    private static let controlTint = UIColor(red: 0, green: 1, blue: 210.0 / 255.0, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isMultipleTouchEnabled = true

        guard let device = MTLCreateSystemDefaultDevice() else { return }
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm

        let renderer = try! Renderer(device: device)
        viewportManager = ViewportManager()
        renderer.viewportManager = viewportManager
        engine = GameEngine(renderer: renderer)

        touchInput = TouchInputProvider()
        touchInput.viewportManager = viewportManager

        let audio = AVAudioManager()
        let sfxEngine = AudioEngine()

        sceneManager = SceneManager(engine: engine)

        sceneManager.makeTitleScene = { [weak self] in
            let scene = TitleScene()
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            scene.sfx = sfxEngine
            return scene
        }

        sceneManager.makeGameScene = { [weak self] in
            let scene = Galaxy1Scene()
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            scene.audioProvider = audio
            scene.sfx = sfxEngine
            audio.stopAll()
            sfxEngine.stopLaser()
            sfxEngine.stopMusic()
            return scene
        }

        sceneManager.makeGameOverScene = { [weak self] result in
            let scene = GameOverScene(result: result)
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            return scene
        }

        sceneManager.makeVictoryScene = { [weak self] result in
            let scene = VictoryScene(result: result)
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            return scene
        }

        // Start with title screen
        let titleScene = TitleScene()
        titleScene.inputProvider = touchInput
        titleScene.viewportManager = viewportManager
        titleScene.sfx = sfxEngine
        engine.currentScene = titleScene

        setupControlOverlays()

        displayLink = CADisplayLink(target: self, selector: #selector(render(_:)))
        displayLink.add(to: .main, forMode: .default)
    }

    // MARK: - Control overlays

    private func setupControlOverlays() {
        let tint = Self.controlTint

        // Dynamic joystick (hidden until touch)
        joystickBase = UIView()
        joystickBase.isUserInteractionEnabled = false
        joystickBase.alpha = 0.15
        joystickBase.layer.borderColor = tint.withAlphaComponent(0.35).cgColor
        joystickBase.layer.borderWidth = 2
        joystickBase.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        joystickBase.layer.cornerRadius = 40
        addSubview(joystickBase)

        joystickKnob = UIView()
        joystickKnob.isUserInteractionEnabled = false
        joystickKnob.alpha = 0.15
        joystickKnob.backgroundColor = tint.withAlphaComponent(0.35)
        joystickKnob.bounds = CGRect(x: 0, y: 0, width: 30, height: 30)
        joystickKnob.layer.cornerRadius = 15
        addSubview(joystickKnob)

        // Buttons
        fireOverlay = makeButtonOverlay(label: "A", cornerRadius: 40)
        bombOverlay = makeButtonOverlay(label: "1", cornerRadius: 22)
        empOverlay = makeButtonOverlay(label: "2", cornerRadius: 22)
        ocOverlay = makeButtonOverlay(label: "3", cornerRadius: 22)

        addSubview(fireOverlay)
        addSubview(bombOverlay)
        addSubview(empOverlay)
        addSubview(ocOverlay)
    }

    private func makeButtonOverlay(label text: String, cornerRadius: CGFloat) -> UIView {
        let tint = Self.controlTint
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = tint.withAlphaComponent(0.06)
        v.layer.borderColor = tint.withAlphaComponent(0.25).cgColor
        v.layer.borderWidth = 1.5
        v.layer.cornerRadius = cornerRadius

        let lbl = UILabel()
        lbl.text = text
        lbl.textColor = tint.withAlphaComponent(0.5)
        lbl.font = .monospacedSystemFont(ofSize: 14, weight: .heavy)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])

        return v
    }

    private func updateControlOverlays() {
        let tint = Self.controlTint
        let active: CGFloat = 0.25
        let idle: CGFloat = 0.06

        // Button pressed states
        fireOverlay.backgroundColor = tint.withAlphaComponent(touchInput.isPrimaryFireActive ? active : idle)
        bombOverlay.backgroundColor = tint.withAlphaComponent(touchInput.isSecondary1Active ? active : idle)
        empOverlay.backgroundColor = tint.withAlphaComponent(touchInput.isSecondary2Active ? active : idle)
        ocOverlay.backgroundColor = tint.withAlphaComponent(touchInput.isSecondary3Active ? active : idle)

        // Dynamic joystick
        if let origin = touchInput.joystickOriginPoint {
            joystickBase.alpha = 1
            joystickBase.center = origin
            joystickKnob.alpha = 1

            if let current = touchInput.joystickCurrentPoint {
                var dx = current.x - origin.x
                var dy = current.y - origin.y
                let dist = sqrt(dx * dx + dy * dy)
                let maxR: CGFloat = 40
                if dist > maxR {
                    dx = dx / dist * maxR
                    dy = dy / dist * maxR
                }
                joystickKnob.center = CGPoint(x: origin.x + dx, y: origin.y + dy)
            } else {
                joystickKnob.center = origin
            }
        } else {
            // Return to default position with dim opacity
            joystickBase.alpha = 0.15
            joystickBase.center = defaultJoystickCenter
            joystickKnob.alpha = 0.15
            joystickKnob.center = defaultJoystickCenter
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = UIScreen.main.scale
        metalLayer.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        if bounds.height > 0 {
            viewportManager.targetAspectRatio = Float(bounds.width / bounds.height)
        }

        // Update touch provider with screen dimensions and button rects
        touchInput.screenSize = bounds.size

        let buttonW: CGFloat = 80
        let buttonH: CGFloat = 80
        let margin: CGFloat = 20
        let rightEdge = bounds.width - margin

        // Primary fire: larger, lower right
        let fireRect = CGRect(
            x: rightEdge - buttonW,
            y: bounds.height - margin - buttonH,
            width: buttonW,
            height: buttonH
        )
        touchInput.primaryButtonRect = fireRect
        fireOverlay.frame = fireRect

        // Secondary buttons: horizontal arc above primary fire
        let secSize: CGFloat = 44
        let fireCenter = CGPoint(x: fireRect.midX, y: fireRect.midY)
        let arcRadius: CGFloat = 85
        // 3 buttons in a gentle arc, sweeping left from fire button
        // Order reversed: 3 (rightmost) → 2 → 1 (leftmost)
        let angles: [CGFloat] = [-1.60, -1.05, -0.50]  // radians from top

        let secRects: [CGRect] = angles.map { angle in
            let cx = fireCenter.x + arcRadius * sin(angle)
            let cy = fireCenter.y - arcRadius * cos(angle)
            return CGRect(x: cx - secSize / 2, y: cy - secSize / 2,
                          width: secSize, height: secSize)
        }

        touchInput.secondary1ButtonRect = secRects[0]
        bombOverlay.frame = secRects[0]

        touchInput.secondary2ButtonRect = secRects[1]
        empOverlay.frame = secRects[1]

        touchInput.secondary3ButtonRect = secRects[2]
        ocOverlay.frame = secRects[2]

    }

    private func updateHudInsets(for scene: Galaxy1Scene) {
        let screenHeight = bounds.height
        let screenWidth = bounds.width
        if screenHeight > 0 && screenWidth > 0 {
            let vUnitsPerPt = GameConfig.designHeight / Float(screenHeight)
            let designWidth = scene.viewportManager?.currentDesignWidth ?? GameConfig.designWidth
            let hUnitsPerPt = designWidth / Float(screenWidth)
            scene.hudInsets = (
                top: Float(safeAreaInsets.top) * vUnitsPerPt,
                bottom: Float(safeAreaInsets.bottom) * vUnitsPerPt,
                left: Float(safeAreaInsets.left) * hUnitsPerPt,
                right: Float(safeAreaInsets.right) * hUnitsPerPt
            )
        }
    }

    private func setControlOverlaysVisible(_ visible: Bool) {
        fireOverlay.isHidden = !visible
        bombOverlay.isHidden = !visible
        empOverlay.isHidden = !visible
        ocOverlay.isHidden = !visible
        joystickBase.isHidden = !visible
        joystickKnob.isHidden = !visible
    }

    @objc private func render(_ displayLink: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 1.0 / 60.0 : displayLink.timestamp - lastTimestamp
        lastTimestamp = displayLink.timestamp

        viewportManager.update(dt: Float(dt))

        // HUD insets for game scenes
        if let gameScene = engine.currentScene as? Galaxy1Scene {
            updateHudInsets(for: gameScene)
        }

        engine.update(deltaTime: dt)

        // Scene transition management
        sceneManager.checkForTransition()
        sceneManager.updateTransition(deltaTime: dt)
        engine.renderer.transitionProgress = sceneManager.transitionProgress

        // Show/hide control overlays based on current scene
        let isPlaying = engine.currentScene is Galaxy1Scene
        setControlOverlaysVisible(isPlaying)

        if isPlaying {
            updateControlOverlays()
        }

        guard let drawable = metalLayer.nextDrawable() else { return }
        engine.render(to: drawable)
    }

    // MARK: - Touch forwarding

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesBegan(touches, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesMoved(touches, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesEnded(touches, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesCancelled(touches, in: self)
    }
}
