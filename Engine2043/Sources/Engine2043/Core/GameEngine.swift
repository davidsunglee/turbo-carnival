import Metal
import QuartzCore

@MainActor
public protocol GameScene: AnyObject {
    func fixedUpdate(time: GameTime)
    func update(time: GameTime)
    func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance]
    func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance]
    var requestedTransition: SceneTransition? { get }
    var backgroundColor: SIMD4<Float> { get }
}

extension GameScene {
    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        []
    }
    public var requestedTransition: SceneTransition? { nil }
    public var backgroundColor: SIMD4<Float> { GameConfig.Palette.background }
}

@MainActor
public final class GameEngine {
    public private(set) var time = GameTime()
    public let renderer: Renderer?
    public var currentScene: (any GameScene)?
    public var audioProvider: (any AudioProvider)?

    public init(renderer: Renderer) {
        self.renderer = renderer
    }

    /// Lightweight init for unit tests that don't need the rendering pipeline.
    internal init() {
        self.renderer = nil
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
        guard let renderer else { return }
        renderer.clearColor = currentScene?.backgroundColor ?? GameConfig.Palette.background
        let sprites = currentScene?.collectSprites(atlas: renderer.textureAtlas) ?? []
        let effectSprites = currentScene?.collectEffectSprites(effectSheet: renderer.effectSheet) ?? []
        renderer.render(to: drawable, sprites: sprites, effectSprites: effectSprites, totalTime: Float(time.totalTime))
    }
}
