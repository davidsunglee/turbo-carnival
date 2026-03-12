import simd

@MainActor
public final class VictoryScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?

    private let result: GameResult
    public private(set) var requestedTransition: SceneTransition?

    // Sequential stat reveal timing
    private var revealTimer: Double = 0
    private let statRevealInterval: Double = 0.6
    private var statsRevealed: Int = 0
    private let totalStats = 3

    private var menuVisible: Bool = false

    private let menuOptions: [MenuInput.Option] = [
        MenuInput.Option(label: "RETRY", position: SIMD2(0, -120), scale: 2.0),
        MenuInput.Option(label: "TITLE SCREEN", position: SIMD2(0, -150), scale: 2.0),
    ]

    public init(result: GameResult) {
        self.result = result
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        backgroundSystem.update(deltaTime: dt)

        // Sequential reveal
        revealTimer += dt
        let newRevealed = min(Int(revealTimer / statRevealInterval), totalStats)
        if newRevealed > statsRevealed {
            statsRevealed = newRevealed
        }
        if statsRevealed >= totalStats && revealTimer >= Double(totalStats) * statRevealInterval + 0.5 {
            menuVisible = true
        }

        guard menuVisible else { return }

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

        let cyanColor = GameConfig.Palette.player
        let goldColor = GameConfig.Palette.item

        // MISSION COMPLETE title
        sprites.append(contentsOf: BitmapText.makeSprites(
            "MISSION COMPLETE",
            at: SIMD2(0, 100),
            color: SIMD4(cyanColor.x, cyanColor.y, cyanColor.z, 0.95),
            scale: 3.0,
            effectSheet: effectSheet
        ))

        // Stats (revealed sequentially)
        let statY: Float = 40
        let statSpacing: Float = 30

        if statsRevealed >= 1 {
            // SCORE
            sprites.append(contentsOf: BitmapText.makeSprites(
                "SCORE",
                at: SIMD2(-40, statY),
                color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
            sprites.append(contentsOf: BitmapText.makeSprites(
                String(format: "%08d", result.finalScore),
                at: SIMD2(60, statY),
                color: SIMD4(1, 1, 1, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        if statsRevealed >= 2 {
            // ENEMIES DESTROYED
            sprites.append(contentsOf: BitmapText.makeSprites(
                "DESTROYED",
                at: SIMD2(-40, statY - statSpacing),
                color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
            sprites.append(contentsOf: BitmapText.makeSprites(
                String(format: "%d", result.enemiesDestroyed),
                at: SIMD2(60, statY - statSpacing),
                color: SIMD4(1, 1, 1, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        if statsRevealed >= 3 {
            // TIME
            let minutes = Int(result.elapsedTime) / 60
            let seconds = Int(result.elapsedTime) % 60
            sprites.append(contentsOf: BitmapText.makeSprites(
                "TIME",
                at: SIMD2(-40, statY - statSpacing * 2),
                color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
            sprites.append(contentsOf: BitmapText.makeSprites(
                String(format: "%02d:%02d", minutes, seconds),
                at: SIMD2(60, statY - statSpacing * 2),
                color: SIMD4(1, 1, 1, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        // Menu options
        if menuVisible {
            for option in menuOptions {
                sprites.append(contentsOf: BitmapText.makeSprites(
                    option.label,
                    at: option.position,
                    color: SIMD4(1, 1, 1, 0.7),
                    scale: option.scale,
                    effectSheet: effectSheet
                ))
            }
        }

        return sprites
    }
}
