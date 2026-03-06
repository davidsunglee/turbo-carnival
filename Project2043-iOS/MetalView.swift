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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm

        let renderer = try! Renderer(device: device)
        engine = GameEngine(renderer: renderer)

        let scene = PlaceholderScene()
        scene.inputProvider = TouchInputProvider()
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
    }

    @objc private func render(_ displayLink: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 1.0 / 60.0 : displayLink.timestamp - lastTimestamp
        lastTimestamp = displayLink.timestamp

        engine.update(deltaTime: dt)

        guard let drawable = metalLayer.nextDrawable() else { return }
        engine.render(to: drawable)
    }
}
