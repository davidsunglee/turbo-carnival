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
        engine = GameEngine(renderer: renderer)

        touchInput = TouchInputProvider()
        let scene = Galaxy1Scene()
        scene.inputProvider = touchInput

        let audio = AVAudioManager()
        scene.audioProvider = audio

        engine.currentScene = scene

        displayLink = CADisplayLink(target: self, selector: #selector(render(_:)))
        displayLink.add(to: .main, forMode: .default)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = UIScreen.main.scale
        metalLayer.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        // Update touch provider with screen dimensions and button rects
        touchInput.screenSize = bounds.size

        let buttonW: CGFloat = 80
        let buttonH: CGFloat = 80
        let margin: CGFloat = 20
        let rightEdge = bounds.width - margin

        // Primary fire: larger, lower right
        touchInput.primaryButtonRect = CGRect(
            x: rightEdge - buttonW,
            y: bounds.height - margin - buttonH,
            width: buttonW,
            height: buttonH
        )

        // Secondary buttons: stacked vertically above primary
        let secW: CGFloat = 60
        let secH: CGFloat = 50
        let secGap: CGFloat = 10
        let secX = rightEdge - secW - 10
        let secBaseY = bounds.height - margin - buttonH - secGap

        // Secondary 1 (Grav-Bomb): lowest, just above primary
        touchInput.secondary1ButtonRect = CGRect(
            x: secX, y: secBaseY - secH,
            width: secW, height: secH
        )

        // Secondary 2 (EMP Sweep): middle
        touchInput.secondary2ButtonRect = CGRect(
            x: secX, y: secBaseY - secH * 2 - secGap,
            width: secW, height: secH
        )

        // Secondary 3 (Overcharge): top
        touchInput.secondary3ButtonRect = CGRect(
            x: secX, y: secBaseY - secH * 3 - secGap * 2,
            width: secW, height: secH
        )
    }

    @objc private func render(_ displayLink: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 1.0 / 60.0 : displayLink.timestamp - lastTimestamp
        lastTimestamp = displayLink.timestamp

        engine.update(deltaTime: dt)

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
