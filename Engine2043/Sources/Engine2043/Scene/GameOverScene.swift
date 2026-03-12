import simd

@MainActor
public final class GameOverScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?

    private let result: GameResult
    public private(set) var requestedTransition: SceneTransition?

    private var appearTimer: Double = 0
    private let menuAppearDelay: Double = 1.0 // delay before menu options appear
    private var menuVisible: Bool = false

    // Highlight state
    private var highlightedOption: Int? = nil

    private let menuOptions: [MenuInput.Option] = [
        MenuInput.Option(label: "RETRY", position: SIMD2(0, -60), scale: 2.0),
        MenuInput.Option(label: "TITLE SCREEN", position: SIMD2(0, -90), scale: 2.0),
    ]

    public init(result: GameResult) {
        self.result = result
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        backgroundSystem.update(deltaTime: dt)

        if !menuVisible {
            appearTimer += dt
            if appearTimer >= menuAppearDelay {
                menuVisible = true
            }
            return
        }

        // Check for tap/click input
        guard let input = inputProvider?.poll() else { return }
        if let tapPos = input.tapPosition {
            if let hit = MenuInput.hitTest(tapPosition: tapPos, options: menuOptions) {
                switch hit {
                case 0: requestedTransition = .toGame
                case 1: requestedTransition = .toTitle
                default: break
                }
            }
        }
    }

    public func update(time: GameTime) {}

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        backgroundSystem.collectSprites()
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        var sprites: [SpriteInstance] = []

        // GAME OVER title
        sprites.append(contentsOf: BitmapText.makeSprites(
            "GAME OVER",
            at: SIMD2(0, 60),
            color: SIMD4(GameConfig.Palette.enemy.x, GameConfig.Palette.enemy.y, GameConfig.Palette.enemy.z, 0.95),
            scale: 3.0,
            effectSheet: effectSheet
        ))

        // Score
        let scoreText = String(format: "%08d", result.finalScore)
        sprites.append(contentsOf: BitmapText.makeSprites(
            scoreText,
            at: SIMD2(0, 20),
            color: SIMD4(1, 1, 1, 0.8),
            scale: 2.0,
            effectSheet: effectSheet
        ))

        // Menu options (only after delay)
        if menuVisible {
            for (i, option) in menuOptions.enumerated() {
                let isHighlighted = highlightedOption == i
                let alpha: Float = isHighlighted ? 1.0 : 0.7
                sprites.append(contentsOf: BitmapText.makeSprites(
                    option.label,
                    at: option.position,
                    color: SIMD4(1, 1, 1, alpha),
                    scale: option.scale,
                    effectSheet: effectSheet
                ))
            }
        }

        return sprites
    }
}
