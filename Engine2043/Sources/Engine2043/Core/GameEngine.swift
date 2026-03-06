import Metal
import QuartzCore

@MainActor
public protocol GameScene: AnyObject {
    func fixedUpdate(time: GameTime)
    func update(time: GameTime)
    func collectSprites() -> [SpriteInstance]
}

@MainActor
public final class GameEngine {
    public private(set) var time = GameTime()
    public let renderer: Renderer
    public var currentScene: (any GameScene)?

    public init(renderer: Renderer) {
        self.renderer = renderer
    }

    public func update(deltaTime: Double) {
        time.advance(by: deltaTime)

        while time.shouldPerformFixedUpdate() {
            currentScene?.fixedUpdate(time: time)
            time.consumeFixedUpdate()
        }

        currentScene?.update(time: time)
    }

    public func render(to drawable: CAMetalDrawable) {
        let sprites = currentScene?.collectSprites() ?? []
        renderer.render(to: drawable, sprites: sprites, totalTime: Float(time.totalTime))
    }
}
