import simd

@MainActor
public final class TitleScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?
    public var viewportManager: ViewportManager?
    public var sfx: AudioEngine?

    // Attract mode entities — simple scripted sprites (no ECS needed)
    private var attractShipPos = SIMD2<Float>(0, -100)
    private var attractShipVel = SIMD2<Float>(30, 20)
    private var attractEnemies: [(pos: SIMD2<Float>, vel: SIMD2<Float>)] = []
    private var attractProjectiles: [(pos: SIMD2<Float>, vel: SIMD2<Float>, age: Double)] = []
    private var attractFireTimer: Double = 0
    private var attractSeeded = false
    private var musicStarted = false

    // UI state
    private var blinkTimer: Double = 0
    private var showPrompt: Bool = true
    private var totalTime: Double = 0

    // Transition
    public private(set) var requestedTransition: SceneTransition?

    public init() {}

    private func seedAttractEnemies() {
        let hw = (viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)) - 40
        for i in 0..<5 {
            let x = -hw + Float(i) * (hw * 2 / 4)
            attractEnemies.append((
                pos: SIMD2(x, GameConfig.designHeight / 2 + 50),
                vel: SIMD2(0, -40)
            ))
        }
    }

    public func fixedUpdate(time: GameTime) {
        if !musicStarted {
            musicStarted = true
            sfx?.startMusic(.title)
        }
        if !attractSeeded {
            seedAttractEnemies()
            attractSeeded = true
        }

        let dt = time.fixedDeltaTime
        totalTime += dt

        backgroundSystem.update(deltaTime: dt)

        // Attract ship — bounce around the lower portion of the screen
        let hw = (viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)) - 20
        let hh = GameConfig.designHeight / 2 - 20
        attractShipPos += attractShipVel * Float(dt)
        if attractShipPos.x < -hw || attractShipPos.x > hw { attractShipVel.x *= -1 }
        if attractShipPos.y < -hh || attractShipPos.y > 0 { attractShipVel.y *= -1 }

        // Attract enemies — drift down, wrap around
        for i in attractEnemies.indices {
            attractEnemies[i].pos += attractEnemies[i].vel * Float(dt)
            if attractEnemies[i].pos.y < -hh - 30 {
                attractEnemies[i].pos.y = hh + 30
                attractEnemies[i].pos.x = Float.random(in: -hw...hw)
            }
        }

        // Auto-fire projectiles
        attractFireTimer += dt
        if attractFireTimer >= 0.3 {
            attractFireTimer = 0
            attractProjectiles.append((
                pos: attractShipPos + SIMD2(0, 15),
                vel: SIMD2(0, 500),
                age: 0
            ))
        }

        // Update projectiles
        for i in attractProjectiles.indices.reversed() {
            attractProjectiles[i].pos += attractProjectiles[i].vel * Float(dt)
            attractProjectiles[i].age += dt
            if attractProjectiles[i].age > 1.5 {
                attractProjectiles.remove(at: i)
            }
        }

        // Blink timer
        blinkTimer += dt
        if blinkTimer >= 0.5 {
            blinkTimer = 0
            showPrompt.toggle()
        }

        // Check for start input
        if let input = inputProvider?.poll() {
            if input.primaryFire || input.secondaryFire1 || input.secondaryFire2 || input.secondaryFire3 {
                requestedTransition = .toGame
            }
        }
    }

    public func update(time: GameTime) {}

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        var sprites = backgroundSystem.collectSprites()

        // Attract mode player ship
        var shipSprite = SpriteInstance(
            position: attractShipPos,
            size: GameConfig.Player.size,
            color: SIMD4(1, 1, 1, 0.6)
        )
        if let atlas {
            shipSprite.uvRect = atlas.uvRect(for: "player")
        }
        sprites.append(shipSprite)

        // Attract mode enemies
        for enemy in attractEnemies {
            var enemySprite = SpriteInstance(
                position: enemy.pos,
                size: GameConfig.Enemy.tier1Size,
                color: SIMD4(GameConfig.Palette.enemy.x, GameConfig.Palette.enemy.y, GameConfig.Palette.enemy.z, 0.5)
            )
            if let atlas {
                enemySprite.uvRect = atlas.uvRect(for: "tier1")
            }
            sprites.append(enemySprite)
        }

        // Attract mode projectiles
        for proj in attractProjectiles {
            var projSprite = SpriteInstance(
                position: proj.pos,
                size: GameConfig.Player.projectileSize,
                color: SIMD4(GameConfig.Palette.player.x, GameConfig.Palette.player.y, GameConfig.Palette.player.z, 0.5)
            )
            if let atlas {
                projSprite.uvRect = atlas.uvRect(for: "playerBullet")
            }
            sprites.append(projSprite)
        }

        return sprites
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        var sprites: [SpriteInstance] = []

        // Title text
        sprites.append(contentsOf: BitmapText.makeSprites(
            "PROJECT 2043",
            at: SIMD2(0, 120),
            color: GameConfig.Palette.player,
            scale: 4.0,
            effectSheet: effectSheet
        ))

        // Blinking start prompt
        if showPrompt {
            #if os(iOS)
            let promptText = "TAP TO START"
            #else
            let promptText = "PRESS SPACE"
            #endif
            sprites.append(contentsOf: BitmapText.makeSprites(
                promptText,
                at: SIMD2(0, -80),
                color: SIMD4(1, 1, 1, 0.8),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        return sprites
    }
}
