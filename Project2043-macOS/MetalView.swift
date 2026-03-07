import Cocoa
import Metal
import QuartzCore
import Engine2043

class MetalView: NSView {
    private var metalLayer: CAMetalLayer!
    private var engine: GameEngine!
    private var inputProvider: KeyboardInputProvider!
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let layer = CAMetalLayer()
        layer.device = MTLCreateSystemDefaultDevice()
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false
        self.wantsLayer = true
        self.layer = layer
        self.metalLayer = layer

        guard let device = layer.device else { return }

        let renderer = try! Renderer(device: device)
        engine = GameEngine(renderer: renderer)

        inputProvider = KeyboardInputProvider()
        let scene = Galaxy1Scene()
        scene.inputProvider = inputProvider

        let audio = AVAudioManager()
        scene.audioProvider = audio

        let sfxEngine = SynthAudioEngine()
        scene.sfx = sfxEngine

        engine.currentScene = scene
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil

        guard let screen = window?.screen else { return }
        let link = screen.displayLink(target: self, selector: #selector(render(_:)))
        link.add(to: .main, forMode: .default)
        displayLink = link
    }

    override func layout() {
        super.layout()
        guard let metalLayer else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        metalLayer.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
    }

    @objc private func render(_ displayLink: CADisplayLink) {
        let timestamp = displayLink.timestamp
        let dt = lastTimestamp == 0 ? 1.0 / 60.0 : timestamp - lastTimestamp
        lastTimestamp = timestamp

        engine.update(deltaTime: dt)

        guard let drawable = metalLayer.nextDrawable() else { return }
        engine.render(to: drawable)
    }

    // MARK: - Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        inputProvider.keyDown(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        inputProvider.keyUp(event.keyCode)
    }
}
