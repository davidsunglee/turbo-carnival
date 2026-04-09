import GameplayKit
import simd

@MainActor
public final class Galaxy3Scene: GameScene {

    // MARK: - Stage State

    enum StageState {
        case scrolling
        case bossIntro
        case bossActive
        case bossDefeat
    }
    private(set) var stageState: StageState = .scrolling

    // MARK: - Systems
    private let physicsSystem = PhysicsSystem()
    private let collisionSystem: CollisionSystem
    private let renderSystem = RenderSystem()
    private let weaponSystem = WeaponSystem()
    private let formationSystem = FormationSystem()
    private let steeringSystem = SteeringSystem()
    let itemSystem = ItemSystem() // CollisionContext
    private let shieldDroneSystem = ShieldDroneSystem()
    let scoreSystem = ScoreSystem() // CollisionContext
    private let backgroundSystem = BackgroundSystem()
    private let bossSystem = BossSystem()
    private let environmentSystem = Galaxy3EnvironmentSystem()
    private let encounterDirector = Galaxy3EncounterDirector()
    private var lightningArcSystem: LightningArcSystem!
    private let collisionResponseHandler = CollisionResponseHandler()
    private let titleCard = GalaxyTitleCard(title: "GALAXY 3: THE ZENITH ARMADA GRID")

    // MARK: - Input / Audio
    public var inputProvider: (any InputProvider)?
    public var audioProvider: (any AudioProvider)?
    public var sfx: AudioEngine?
    public var viewportManager: ViewportManager?

    // MARK: - Entities
    var player: GKEntity! // CollisionContext
    private var enemies: [GKEntity] = []
    private var projectiles: [GKEntity] = []
    private var enemyProjectiles: [GKEntity] = []
    private var items: [GKEntity] = []
    private var barriers: [GKEntity] = []
    private var fortressHulls: [GKEntity] = []
    private(set) var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    private var shieldDrones: [GKEntity] = []
    var pendingRemovals: [GKEntity] = [] // CollisionContext

    // MARK: - Formation tracking
    private var formationEnemies: [Int: [GKEntity]] = [:]
    private var nextFormationID: Int = 0

    // MARK: - Rendering
    public var backgroundColor: SIMD4<Float> { GameConfig.Galaxy3.Palette.g3Background }

    // MARK: - Game state
    public private(set) var gameState: GameState = .playing
    private var gravBombEntities: [GKEntity] = []
    private var gravBombTimers: [ObjectIdentifier: Double] = [:]
    private var tractorBeamSearchTimer: Double = 0
    private var blastEffects: [(entity: GKEntity, timer: Double)] = []
    private var slowMoTimer: Double = 0
    private var isSlowMo: Bool = false
    public var hudInsets: (top: Float, bottom: Float, left: Float, right: Float) = (0, 0, 0, 0)
    private var lastWeaponType: WeaponType?
    private var weaponNameTimer: Double = 0
    private static let weaponNameDuration: Double = 3.5
    public private(set) var requestedTransition: SceneTransition?
    private var gameOverTimer: Double = 0
    private static let restartDelay: Double = 1.5
    private static let bossFlashDuration: Double = 0.7
    private static let bossFadeDuration: Double = 3.0
    private var bossDyingTimer: Double = 0
    private var isBossDying: Bool = false
    private var musicStarted = false
    public var enemiesDestroyed: Int = 0 // CollisionContext
    public private(set) var elapsedTime: Double = 0

    public var gameResult: GameResult {
        GameResult(
            finalScore: scoreSystem.currentScore,
            enemiesDestroyed: enemiesDestroyed,
            elapsedTime: elapsedTime,
            didWin: gameState == .victory
        )
    }

    // MARK: - World
    private var worldBounds: AABB {
        let hw = viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)
        let hh = GameConfig.designHeight / 2
        return AABB(min: SIMD2(-hw, -hh), max: SIMD2(hw, hh))
    }

    private var currentHalfWidth: Float {
        viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)
    }

    // MARK: - Init

    public init(carryover: PlayerCarryover) {
        collisionSystem = CollisionSystem(worldBounds: AABB(min: SIMD2(-200, -340), max: SIMD2(200, 340)))
        backgroundSystem.palette = .galaxy3

        // Carry over stats (accumulated totals)
        enemiesDestroyed = carryover.enemiesDestroyed
        elapsedTime = carryover.elapsedTime

        setupPlayer(carryover: carryover)
        lightningArcSystem = LightningArcSystem(player: player)
        collisionResponseHandler.context = self

        // Spawn initial shield drones from carryover
        if carryover.shieldDroneCount > 0 {
            spawnInitialShieldDrones(count: carryover.shieldDroneCount)
        }
    }

    private func setupPlayer(carryover: PlayerCarryover) {
        player = GKEntity()

        let transform = TransformComponent(position: SIMD2(0, -250))
        player.addComponent(transform)

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Player.size,
            layer: .player,
            mask: [.enemy, .enemyProjectile, .item, .barrier]
        )
        player.addComponent(physics)

        let playerRender = RenderComponent(
            size: GameConfig.Player.size,
            color: SIMD4(1, 1, 1, 1)
        )
        playerRender.spriteId = "player"
        player.addComponent(playerRender)

        // Energy always restored to full on galaxy transition
        player.addComponent(HealthComponent(health: GameConfig.Player.health))

        let weapon = WeaponComponent(
            fireRate: GameConfig.Player.fireRate,
            damage: GameConfig.Player.damage,
            projectileSpeed: GameConfig.Player.projectileSpeed
        )
        weapon.weaponType = carryover.weaponType
        weapon.secondaryCharges = carryover.secondaryCharges
        // Set appropriate damage for the carried weapon type
        switch carryover.weaponType {
        case .doubleCannon:
            weapon.damage = GameConfig.Player.damage
        case .lightningArc:
            weapon.damage = GameConfig.Weapon.lightningArcDamagePerTick
        case .triSpread:
            weapon.damage = GameConfig.Weapon.triSpreadDamage
        case .phaseLaser:
            weapon.damage = GameConfig.Weapon.laserDamagePerTick
        }
        player.addComponent(weapon)

        // Restore score from carryover
        scoreSystem.setScore(carryover.score)

        registerEntity(player)
    }

    // MARK: - Entity Management

    private func registerEntity(_ entity: GKEntity) {
        physicsSystem.register(entity)
        collisionSystem.register(entity)
        renderSystem.register(entity)
        weaponSystem.register(entity)
        formationSystem.register(entity)
        steeringSystem.register(entity)
        itemSystem.register(entity)
        shieldDroneSystem.register(entity)
    }

    private func unregisterEntity(_ entity: GKEntity) {
        physicsSystem.unregister(entity)
        collisionSystem.unregister(entity)
        renderSystem.unregister(entity)
        weaponSystem.unregister(entity)
        formationSystem.unregister(entity)
        steeringSystem.unregister(entity)
        itemSystem.unregister(entity)
        shieldDroneSystem.unregister(entity)
        bossSystem.unregister(entity)
    }

    private func removeEntity(_ entity: GKEntity) {
        unregisterEntity(entity)
        lightningArcSystem.unregisterEnemy(entity)
        lightningArcSystem.unregisterItem(entity)
        enemies.removeAll { $0 === entity }
        projectiles.removeAll { $0 === entity }
        enemyProjectiles.removeAll { $0 === entity }
        items.removeAll { $0 === entity }
        barriers.removeAll { $0 === entity }
        fortressHulls.removeAll { $0 === entity }
        gravBombEntities.removeAll { $0 === entity }
        gravBombTimers.removeValue(forKey: ObjectIdentifier(entity))
        shieldEntities.removeAll { $0 === entity }
        shieldDrones.removeAll { $0 === entity }

        for (id, var members) in formationEnemies {
            members.removeAll { $0 === entity }
            if members.isEmpty {
                formationEnemies.removeValue(forKey: id)
            } else {
                formationEnemies[id] = members
            }
        }
    }

    // MARK: - GameScene Protocol

    public func fixedUpdate(time: GameTime) {
        if !musicStarted {
            musicStarted = true
            // Reuse galaxy2 music for Galaxy 3 first pass
            sfx?.startMusic(.galaxy2)
        }
        sfx?.updateMusicFade(deltaTime: Float(time.fixedDeltaTime))

        // Title card plays before gameplay begins
        if !titleCard.isDone {
            titleCard.update(deltaTime: time.fixedDeltaTime)
            return
        }

        if gameState == .playing {
            elapsedTime += time.fixedDeltaTime
        }

        // Game over / victory -- transition after delay
        if gameState != .playing {
            gameOverTimer += time.fixedDeltaTime
            if gameOverTimer > Self.restartDelay && requestedTransition == nil {
                if gameState == .gameOver {
                    requestedTransition = .toGameOver(gameResult)
                } else if gameState == .victory {
                    requestedTransition = .toVictory(gameResult)
                }
            }
            return
        }

        // Boss dying animation
        if isBossDying {
            bossDyingTimer += time.fixedDeltaTime
            if let boss = bossEntity,
               let render = boss.component(ofType: RenderComponent.self) {
                if bossDyingTimer < Self.bossFlashDuration {
                    let t = Float(bossDyingTimer / Self.bossFlashDuration)
                    render.color = SIMD4(1, 1, 1, 1 - t * 0.3)
                } else {
                    let fadeElapsed = bossDyingTimer - Self.bossFlashDuration
                    let alpha = Float(max(0, 1 - fadeElapsed / Self.bossFadeDuration))
                    render.color = SIMD4(1, 1, 1, alpha)
                    if alpha <= 0 {
                        render.isVisible = false
                    }
                }
            }
            let totalBossDeathDuration = Self.bossFlashDuration + Self.bossFadeDuration
            if bossDyingTimer >= totalBossDeathDuration {
                // Galaxy 3 boss defeated -- go to victory
                gameState = .victory
                isBossDying = false
            }
        }

        // Slow-mo from EMP Sweep
        if isSlowMo {
            slowMoTimer -= time.fixedDeltaTime
            if slowMoTimer <= 0 {
                isSlowMo = false
            }
        }

        handleInput()

        // Track weapon type changes for HUD flash
        if let weapon = player.component(ofType: WeaponComponent.self) {
            if lastWeaponType == nil {
                lastWeaponType = weapon.weaponType
            } else if weapon.weaponType != lastWeaponType {
                lastWeaponType = weapon.weaponType
                weaponNameTimer = Self.weaponNameDuration
            }
        }
        if weaponNameTimer > 0 {
            weaponNameTimer -= time.fixedDeltaTime
        }

        // Environment system (Galaxy 3 scroll)
        environmentSystem.update(deltaTime: time.fixedDeltaTime)

        // Background starfield (separate from environment scroll)
        backgroundSystem.update(deltaTime: time.fixedDeltaTime)
        if environmentSystem.isScrollLocked {
            backgroundSystem.isScrollLocked = true
        } else {
            backgroundSystem.isScrollLocked = false
        }

        // Encounter director
        encounterDirector.update(
            scrollDistance: environmentSystem.scrollDistance,
            deltaTime: time.fixedDeltaTime
        )
        processEncounterCommands()

        // Update lane bounds from active barriers
        environmentSystem.updateLaneBounds(barriers: barriers)

        // Scroll barriers downward with environment
        updateBarriers(deltaTime: time.fixedDeltaTime)

        // Behavior systems
        let playerPos = player.component(ofType: TransformComponent.self)?.position ?? .zero
        steeringSystem.playerPosition = playerPos
        formationSystem.update(deltaTime: time.fixedDeltaTime)
        steeringSystem.update(deltaTime: time.fixedDeltaTime, viewportHalfWidth: currentHalfWidth)

        // Turrets and boss projectiles paused during slow-mo
        if !isSlowMo {
            updateTurrets(deltaTime: time.fixedDeltaTime)
            updateFortressNodes(deltaTime: time.fixedDeltaTime)

            bossSystem.playerPosition = playerPos
            bossSystem.update(deltaTime: time.fixedDeltaTime)
            for spawn in bossSystem.pendingProjectileSpawns {
                spawnBossProjectile(spawn)
            }
        }

        // Transition bossIntro -> bossActive when intro descent completes
        if stageState == .bossIntro,
           let boss = bossEntity,
           let zenith = boss.component(ofType: ZenithBossComponent.self),
           zenith.currentPhase != .intro {
            stageState = .bossActive
        }

        // Update homing projectiles and expire aged-out projectiles
        updateHomingProjectiles(deltaTime: time.fixedDeltaTime)

        // Physics
        physicsSystem.syncFromComponents()
        physicsSystem.update(time: time)

        // Clamp player position to screen boundaries (must run after physics)
        if let transform = player.component(ofType: TransformComponent.self) {
            let halfW = currentHalfWidth - GameConfig.Player.size.x / 2
            let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2

            // When inside an active corridor, restrict X to the lane bounds
            let laneBounds = environmentSystem.activeLaneBounds
            if laneBounds.isActive {
                let playerHalfW = GameConfig.Player.size.x / 2
                let minX = laneBounds.leftWall + playerHalfW
                let maxX = laneBounds.rightWall - playerHalfW
                transform.position.x = max(minX, min(maxX, transform.position.x))
            }

            transform.position.x = max(-halfW, min(halfW, transform.position.x))
            transform.position.y = max(-halfH, min(halfH, transform.position.y))
        }

        collisionSystem.update(time: time)
        weaponSystem.update(time: time)

        // Lightning Arc
        lightningArcSystem.update(deltaTime: time.fixedDeltaTime)
        if !lightningArcSystem.pendingDamage.isEmpty {
            sfx?.play(.lightningArcZap)
        }
        for (entity, damage) in lightningArcSystem.pendingDamage {
            if let health = entity.component(ofType: HealthComponent.self) {
                health.takeDamage(damage)
                if !health.isAlive {
                    sfx?.play(.enemyDestroyed)
                    if let score = entity.component(ofType: ScoreComponent.self) {
                        scoreSystem.addScore(score.points)
                    }
                    enemiesDestroyed += 1
                    pendingRemovals.append(entity)
                    checkFormationWipe(enemy: entity)
                }
            }
        }
        for entity in lightningArcSystem.pendingItemHits {
            itemSystem.handleProjectileHit(on: entity)
            sfx?.play(.itemCycle)
        }

        // Spawn player projectiles
        for request in weaponSystem.pendingSpawns {
            spawnPlayerProjectile(request)
        }

        // Handle secondary weapon spawns
        for request in weaponSystem.pendingSecondarySpawns {
            switch request.type {
            case .gravBomb:
                spawnGravBomb(position: request.position, velocity: request.velocity)
            case .empSweep:
                activateEMPSweep()
            case .overcharge:
                activateOvercharge()
            }
        }

        // Process Phase Laser hitscans
        for hitscan in weaponSystem.pendingLaserHitscans {
            processLaserHitscan(hitscan)
        }

        // Update grav-bomb timers
        updateGravBombs(deltaTime: time.fixedDeltaTime)

        // Update blast effects
        blastEffects = blastEffects.compactMap { effect in
            let remaining = effect.timer - time.fixedDeltaTime
            if remaining <= 0 {
                pendingRemovals.append(effect.entity)
                return nil
            }
            return (entity: effect.entity, timer: remaining)
        }

        // Item system
        itemSystem.update(deltaTime: time.fixedDeltaTime, viewportHalfWidth: currentHalfWidth)
        for entity in itemSystem.pendingDespawns {
            pendingRemovals.append(entity)
        }

        // Shield drone system
        shieldDroneSystem.update(deltaTime: time.fixedDeltaTime)
        for drone in shieldDroneSystem.pendingRemovals {
            pendingRemovals.append(drone)
        }

        // Collisions
        processCollisions()

        // Player invulnerability
        player.component(ofType: HealthComponent.self)?
            .updateInvulnerability(deltaTime: time.fixedDeltaTime)

        // Check boss defeat (after all damage systems have run)
        if !isBossDying,
           let boss = bossEntity,
           let health = boss.component(ofType: HealthComponent.self),
           !health.isAlive,
           gameState == .playing {
            isBossDying = true
            bossDyingTimer = 0
            stageState = .bossDefeat
            sfx?.play(.victory)
            sfx?.stopLaser()
            sfx?.stopMusic()
            pendingRemovals.removeAll { $0 === boss }
        }

        // Check game over
        if let health = player.component(ofType: HealthComponent.self), !health.isAlive {
            gameState = .gameOver
            sfx?.play(.playerDeath)
            sfx?.stopLaser()
            sfx?.stopMusic()
            for drone in shieldDrones {
                pendingRemovals.append(drone)
            }
        }

        // Propagate fortress shield-down AFTER all damage paths have run
        // but BEFORE entity removals, so dead generators are still visible.
        propagateFortressShieldDown()

        // Fortress hull updates
        updateFortressHulls()

        // Cull off-screen
        cullOffScreen()

        // Process removals
        for entity in pendingRemovals {
            removeEntity(entity)
        }
        pendingRemovals.removeAll()
    }

    public func update(time: GameTime) {
        if let health = player.component(ofType: HealthComponent.self),
           let render = player.component(ofType: RenderComponent.self) {
            if health.isInvulnerable {
                render.isVisible = Int(time.totalTime * 20) % 2 == 0
            } else {
                render.isVisible = true
            }
        }
    }

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        var sprites = backgroundSystem.collectSprites()

        // Environment plating entities render behind gameplay
        for entity in environmentSystem.platingEntities {
            if let transform = entity.component(ofType: TransformComponent.self),
               let render = entity.component(ofType: RenderComponent.self),
               render.isVisible {
                let uv = atlas?.uvRect(for: render.spriteId) ?? SpriteInstance.defaultUVRect
                sprites.append(SpriteInstance(
                    position: transform.position,
                    size: render.size,
                    color: render.color,
                    rotation: transform.rotation,
                    uvRect: uv
                ))
            }
        }

        // Fortress hulls render behind gameplay entities
        for hull in fortressHulls {
            if let transform = hull.component(ofType: TransformComponent.self),
               let render = hull.component(ofType: RenderComponent.self) {
                let uv = atlas?.uvRect(for: render.spriteId) ?? SpriteInstance.defaultUVRect
                sprites.append(SpriteInstance(
                    position: transform.position,
                    size: render.size,
                    color: render.color,
                    rotation: transform.rotation,
                    uvRect: uv
                ))
            }
        }

        // Barriers are registered in renderSystem via registerEntity, so
        // renderSystem.collectSprites already includes them. No manual loop needed.
        sprites.append(contentsOf: renderSystem.collectSprites(atlas: atlas))

        // Phase Laser beam visual
        if let weapon = player.component(ofType: WeaponComponent.self),
           weapon.weaponType == .phaseLaser,
           weapon.isFiring && !weapon.isLaserOverheated,
           let transform = player.component(ofType: TransformComponent.self) {
            let beamHeight = GameConfig.designHeight / 2 + 50 - transform.position.y
            sprites.append(SpriteInstance(
                position: SIMD2(transform.position.x, transform.position.y + beamHeight / 2),
                size: SIMD2(GameConfig.Weapon.laserWidth, beamHeight),
                color: GameConfig.Palette.laserBeam
            ))
        }

        // Lightning Arc visuals
        for arc in lightningArcSystem.activeArcs {
            let segments = 4
            var points: [SIMD2<Float>] = [arc.from]
            for i in 1..<segments {
                let t = Float(i) / Float(segments)
                let mid = arc.from + (arc.to - arc.from) * t
                let jitter = SIMD2<Float>(Float.random(in: -6...6), Float.random(in: -6...6))
                points.append(mid + jitter)
            }
            points.append(arc.to)

            let alpha = 0.6 + arc.damageMultiplier * 0.4
            for i in 0..<points.count - 1 {
                let from = points[i]
                let to = points[i + 1]
                let diff = to - from
                let length = simd_length(diff)
                guard length > 0 else { continue }
                let midpoint = (from + to) / 2
                let angle = atan2(diff.x, diff.y)

                sprites.append(SpriteInstance(
                    position: midpoint,
                    size: SIMD2(3, length),
                    color: SIMD4<Float>(0.3, 0.6, 1.0, alpha * 0.5),
                    rotation: -angle
                ))
                sprites.append(SpriteInstance(
                    position: midpoint,
                    size: SIMD2(1, length),
                    color: SIMD4<Float>(0.8, 0.9, 1.0, alpha),
                    rotation: -angle
                ))
            }
        }

        if gameState == .gameOver {
            appendGameOverOverlay(to: &sprites)
        } else if gameState == .victory {
            appendVictoryOverlay(to: &sprites)
        }

        return sprites
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []

        // Overcharge visual
        if let weapon = player.component(ofType: WeaponComponent.self),
           weapon.overchargeActive,
           let transform = player.component(ofType: TransformComponent.self),
           let uv = effectSheet?.uvRect(for: "overchargeGlow") {
            sprites.append(SpriteInstance(
                position: transform.position,
                size: GameConfig.Player.size * 1.5,
                color: SIMD4(1, 1, 1, 0.8),
                uvRect: uv
            ))
        }

        // Blast effects (grav bomb blast, EMP flash)
        for (entity, _) in blastEffects {
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let render = entity.component(ofType: RenderComponent.self) else { continue }

            let dw = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
            let isEmp = render.size.x >= dw * 0.9
            let spriteId = isEmp ? "empFlash" : "gravBombBlast"

            if let uv = effectSheet?.uvRect(for: spriteId) {
                sprites.append(SpriteInstance(
                    position: transform.position,
                    size: render.size,
                    color: SIMD4(1, 1, 1, render.color.w),
                    uvRect: uv
                ))
            }
        }

        appendEffectHUD(to: &sprites, effectSheet: effectSheet)
        sprites.append(contentsOf: titleCard.collectSprites(effectSheet: effectSheet))

        return sprites
    }

    private func appendEffectHUD(to sprites: inout [SpriteInstance], effectSheet: EffectTextureSheet?) {
        guard let effectSheet else { return }
        let topY: Float = GameConfig.designHeight / 2 - hudInsets.top - 10

        // --- Upper left: Energy bar ---
        let energyX: Float = -currentHalfWidth + hudInsets.left + 80
        if let uv = effectSheet.uvRect(for: "hudBarFrame") {
            sprites.append(SpriteInstance(
                position: SIMD2(energyX, topY),
                size: SIMD2(90, 12),
                color: SIMD4(1, 1, 1, 1),
                uvRect: uv
            ))
        }

        let health = player.component(ofType: HealthComponent.self)
        let fraction = (health?.currentHealth ?? 0) / (health?.maxHealth ?? 100)
        let barWidth: Float = 86 * fraction
        let barOffset = (barWidth - 86) / 2
        if let uv = effectSheet.uvRect(for: "hudBarFill") {
            sprites.append(SpriteInstance(
                position: SIMD2(energyX + barOffset, topY),
                size: SIMD2(max(barWidth, 0), 8),
                color: GameConfig.Palette.player,
                uvRect: uv
            ))
        }

        // --- Upper center: Score ---
        let scoreText = String(format: "%08d", scoreSystem.currentScore)
        sprites.append(contentsOf: BitmapText.makeSprites(
            scoreText,
            at: SIMD2(0, topY),
            color: SIMD4(1, 1, 1, 0.9),
            scale: 1.5,
            effectSheet: effectSheet
        ))

        // --- Upper right: Weapon info (pips + icon) ---
        let weaponIconX: Float = currentHalfWidth - hudInsets.right - 50
        let weapon = player.component(ofType: WeaponComponent.self)
        let charges = weapon?.secondaryCharges ?? 0
        if let uv = effectSheet.uvRect(for: "hudChargePip") {
            for i in 0..<charges {
                let pipX = weaponIconX - 26 - Float(i) * 14
                sprites.append(SpriteInstance(
                    position: SIMD2(pipX, topY),
                    size: SIMD2(12, 12),
                    color: SIMD4(1, 1, 1, 1),
                    uvRect: uv
                ))
            }
        }

        let weaponType = weapon?.weaponType ?? .doubleCannon
        let weaponColor: SIMD4<Float>
        switch weaponType {
        case .doubleCannon: weaponColor = SIMD4(1, 1, 1, 0.5)
        case .triSpread:    weaponColor = GameConfig.Palette.weaponModule
        case .lightningArc: weaponColor = GameConfig.Palette.weaponLightningArc
        case .phaseLaser:   weaponColor = GameConfig.Palette.laserBeam
        }
        if let uv = effectSheet.uvRect(for: "hudWeaponIcon") {
            sprites.append(SpriteInstance(
                position: SIMD2(weaponIconX, topY),
                size: SIMD2(32, 12),
                color: weaponColor,
                uvRect: uv
            ))
        }

        // Weapon name flash
        if weaponNameTimer > 0 {
            let fadeAlpha = Float(min(weaponNameTimer / 0.5, 1.0))
            let name = weaponDisplayName(weaponType)
            sprites.append(contentsOf: BitmapText.makeSprites(
                name,
                at: SIMD2(weaponIconX, topY - 14),
                color: SIMD4(weaponColor.x, weaponColor.y, weaponColor.z, fadeAlpha),
                scale: 1.0,
                effectSheet: effectSheet
            ))
        }

        // Phase Laser heat gauge
        if weaponType == .phaseLaser, let w = weapon {
            if let frameUV = effectSheet.uvRect(for: "hudHeatFrame") {
                sprites.append(SpriteInstance(
                    position: SIMD2(weaponIconX, topY - 14),
                    size: SIMD2(32, 5),
                    color: SIMD4(1, 1, 1, 1),
                    uvRect: frameUV
                ))
            }

            let heatFrac = Float(w.laserHeat / GameConfig.Weapon.laserMaxHeat)
            if let fillUV = effectSheet.uvRect(for: "hudHeatFill") {
                if w.isLaserOverheated {
                    let cooldownFrac = Float(w.laserOverheatTimer / GameConfig.Weapon.laserOverheatCooldown)
                    sprites.append(SpriteInstance(
                        position: SIMD2(weaponIconX, topY - 14),
                        size: SIMD2(30 * cooldownFrac, 3),
                        color: SIMD4(1, 0.2, 0.2, 0.8),
                        uvRect: fillUV
                    ))
                } else if heatFrac > 0 {
                    let color = SIMD4<Float>(heatFrac, 1.0 - heatFrac * 0.6, 0.2, 0.8)
                    sprites.append(SpriteInstance(
                        position: SIMD2(weaponIconX, topY - 14),
                        size: SIMD2(30 * heatFrac, 3),
                        color: color,
                        uvRect: fillUV
                    ))
                }
            }
        }

        // Overcharge active indicator
        if weapon?.overchargeActive == true {
            if let uv = effectSheet.uvRect(for: "hudBarFill") {
                sprites.append(SpriteInstance(
                    position: SIMD2(weaponIconX, topY - 22),
                    size: SIMD2(32, 4),
                    color: GameConfig.Palette.overchargeGlow,
                    uvRect: uv
                ))
            }
        }
    }

    private func weaponDisplayName(_ type: WeaponType) -> String {
        switch type {
        case .doubleCannon: return "DOUBLE CANNON"
        case .triSpread:    return "TRI-SPREAD"
        case .lightningArc: return "LIGHTNING ARC"
        case .phaseLaser:   return "PHASE LASER"
        }
    }

    // MARK: - Input

    private func handleInput() {
        guard let input = inputProvider?.poll() else { return }

        if let physics = player.component(ofType: PhysicsComponent.self) {
            physics.velocity = input.movement * GameConfig.Player.speed
        }

        if let weapon = player.component(ofType: WeaponComponent.self) {
            weapon.isFiring = input.primaryFire

            // Phase Laser audio
            if weapon.weaponType == .phaseLaser {
                if input.primaryFire && !weapon.isLaserOverheated {
                    sfx?.startLaser()
                    sfx?.setLaserHeat(Float(weapon.laserHeat / GameConfig.Weapon.laserMaxHeat))
                } else {
                    sfx?.stopLaser()
                }
            } else {
                sfx?.stopLaser()
            }

            // Map secondary fire buttons -- first pressed wins
            if input.secondaryFire1 {
                weapon.secondaryFiring = .gravBomb
            } else if input.secondaryFire2 {
                weapon.secondaryFiring = .empSweep
            } else if input.secondaryFire3 {
                weapon.secondaryFiring = .overcharge
            } else {
                weapon.secondaryFiring = nil
            }
        }
    }

    // MARK: - Encounter Director Command Processing

    private func processEncounterCommands() {
        for command in encounterDirector.pendingCommands {
            switch command {
            case .droneCluster(let count, let spawnX):
                spawnDroneCluster(count: count, spawnX: spawnX)
            case .fighterSquad(let count, let spawnX):
                spawnFighterSquad(count: count, spawnX: spawnX)
            case .fortressEncounter(let fortressID):
                spawnFortressEncounter(fortressID: fortressID)
            case .barrierLayout(let kind, let width):
                spawnBarrierLayout(kind: kind, width: width)
            case .bossTrigger:
                triggerBoss()
            }
        }
    }

    // MARK: - Spawning

    private func spawnDroneCluster(count: Int, spawnX: Float) {
        let formationID = nextFormationID
        nextFormationID += 1
        var members: [GKEntity] = []

        let spacing: Float = 30
        let startX = spawnX - Float(count - 1) / 2 * spacing
        // Convert spawnX from design-space [0..360] to centered coordinates
        let centerOffset = -GameConfig.designWidth / 2

        for i in 0..<count {
            let x = centerOffset + startX + Float(i) * spacing
            let y = GameConfig.designHeight / 2 + 30

            let entity = Galaxy3EntityFactory.makeTrackingDrone(at: SIMD2(x, y))

            let formation = FormationComponent(pattern: .staggeredLine, index: i, formationID: formationID)
            entity.addComponent(formation)

            registerEntity(entity)
            enemies.append(entity)
            members.append(entity)
            lightningArcSystem.registerEnemy(entity)
        }

        formationEnemies[formationID] = members
    }

    private func spawnFighterSquad(count: Int, spawnX: Float) {
        let centerOffset = -GameConfig.designWidth / 2

        for i in 0..<count {
            let spacing: Float = 50
            let x = centerOffset + spawnX + Float(i) * spacing - Float(count - 1) / 2 * spacing
            let y = GameConfig.designHeight / 2 + 40

            let entity = Galaxy3EntityFactory.makeFighter(at: SIMD2(x, y))

            let steering = SteeringComponent(behavior: .leadShot)
            steering.steerStrength = 3.0
            entity.addComponent(steering)

            let turretComp = TurretComponent(trackingSpeed: 1.5)
            turretComp.fireInterval = 2.0
            turretComp.projectileSpeed = 250
            turretComp.damage = 5
            entity.addComponent(turretComp)

            registerEntity(entity)
            enemies.append(entity)
            lightningArcSystem.registerEnemy(entity)
        }
    }

    private func spawnFortressEncounter(fortressID: Int) {
        let hullY = GameConfig.designHeight / 2 + GameConfig.Galaxy3.Enemy.fortressHullSize.y / 2 + 20
        let hull = Galaxy3EntityFactory.makeFortressHull(at: SIMD2(0, hullY))
        let hullPhysics = PhysicsComponent(
            collisionSize: GameConfig.Galaxy3.Enemy.fortressHullSize,
            layer: [],
            mask: []
        )
        hullPhysics.velocity = SIMD2(0, -environmentSystem.scrollSpeed * 0.5)
        hull.addComponent(hullPhysics)
        physicsSystem.register(hull)
        fortressHulls.append(hull)

        // Spawn fortress nodes around the hull
        let nodeOffsets: [(role: FortressNodeRole, offset: SIMD2<Float>)] = [
            (.shieldGenerator, SIMD2(0, 30)),
            (.mainBattery, SIMD2(-60, 0)),
            (.mainBattery, SIMD2(60, 0)),
            (.pulseTurret, SIMD2(-30, -20)),
            (.pulseTurret, SIMD2(30, -20)),
        ]

        let formationID = nextFormationID
        nextFormationID += 1
        var nodeMembers: [GKEntity] = []

        for nodeSpec in nodeOffsets {
            let nodePos = SIMD2(nodeSpec.offset.x, hullY + nodeSpec.offset.y)
            let node = Galaxy3EntityFactory.makeFortressNode(
                role: nodeSpec.role,
                at: nodePos,
                fortressID: fortressID
            )

            // Nodes move with the hull
            let nodePhysics = node.component(ofType: PhysicsComponent.self)
            nodePhysics?.velocity = SIMD2(0, -environmentSystem.scrollSpeed * 0.5)

            let turretComp = TurretComponent(trackingSpeed: 1.5)
            turretComp.parentEntity = hull
            turretComp.mountOffset = nodeSpec.offset
            if let fortNode = node.component(ofType: FortressNodeComponent.self) {
                turretComp.fireInterval = fortNode.fireInterval
            }
            turretComp.projectileSpeed = 200
            turretComp.damage = 5
            node.addComponent(turretComp)

            registerEntity(node)
            enemies.append(node)
            lightningArcSystem.registerEnemy(node)
            nodeMembers.append(node)
        }

        formationEnemies[formationID] = nodeMembers
    }

    private func spawnBarrierLayout(kind: BarrierKind, width: Float) {
        // Create barrier walls on left and right sides of the corridor
        let centerX: Float = 0
        let gapHalf = width / 2
        let segmentSize = GameConfig.Galaxy3.Barrier.gateSegmentSize
        let spawnY = GameConfig.designHeight / 2 + segmentSize.y / 2 + 10

        // Left wall barrier
        let leftX = centerX - gapHalf - segmentSize.x / 2
        let leftBarrier = Galaxy3EntityFactory.makeBarrier(kind: kind, at: SIMD2(leftX, spawnY))
        registerEntity(leftBarrier)
        barriers.append(leftBarrier)

        // Right wall barrier
        let rightX = centerX + gapHalf + segmentSize.x / 2
        let rightBarrier = Galaxy3EntityFactory.makeBarrier(kind: kind, at: SIMD2(rightX, spawnY))
        registerEntity(rightBarrier)
        barriers.append(rightBarrier)
    }

    private func triggerBoss() {
        guard stageState == .scrolling else { return }
        stageState = .bossIntro
        environmentSystem.lockScroll()

        // Clear remaining barriers and lane bounds so the boss arena is open
        for barrier in barriers {
            unregisterEntity(barrier)
        }
        barriers.removeAll()
        environmentSystem.resetLaneBounds()

        // Spawn Zenith Core Sentinel boss at top of screen
        let bossPos = SIMD2<Float>(0, 340) // above visible area; intro will descend to 200
        let (core, shields) = Galaxy3EntityFactory.makeZenithBossShell(at: bossPos)

        // Register boss entities directly — keep stageState as .bossIntro
        bossEntity = core
        registerEntity(core)
        bossSystem.register(core)
        enemies.append(core)
        lightningArcSystem.registerEnemy(core)

        for shield in shields {
            registerEntity(shield)
            bossSystem.registerShield(shield)
            shieldEntities.append(shield)
        }

        bossSystem.bossType = .zenithCoreSentinel

        // Hide shield entities initially (they appear in phase 3+)
        for shield in shields {
            shield.component(ofType: RenderComponent.self)?.isVisible = false
        }

        // Switch to boss music — reuse existing boss track
        sfx?.stopMusic()
        sfx?.startMusic(.boss)
    }

    // MARK: - Projectile Spawning

    private func spawnPlayerProjectile(_ request: ProjectileSpawnRequest) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: request.position))

        let weapon = player.component(ofType: WeaponComponent.self)
        var projSize = GameConfig.Player.projectileSize
        if weapon?.overchargeActive == true {
            projSize *= GameConfig.Weapon.overchargeHitboxScale
        }

        let physics = PhysicsComponent(
            collisionSize: projSize,
            layer: .playerProjectile,
            mask: [.enemy, .bossShield, .item, .barrier]
        )
        physics.velocity = request.velocity
        entity.addComponent(physics)

        let weaponType = weapon?.weaponType ?? .doubleCannon
        let spriteId: String
        switch weaponType {
        case .doubleCannon: spriteId = "playerBullet"
        case .triSpread:    spriteId = "triSpreadBullet"
        case .lightningArc: spriteId = "playerBullet"
        case .phaseLaser:   spriteId = "playerBullet"
        }

        let render = RenderComponent(size: projSize, color: SIMD4(1, 1, 1, 1))
        render.spriteId = spriteId
        entity.addComponent(render)

        registerEntity(entity)
        projectiles.append(entity)

        if let weaponType = player.component(ofType: WeaponComponent.self)?.weaponType {
            switch weaponType {
            case .doubleCannon: sfx?.play(.doubleCannonFire)
            case .triSpread: sfx?.play(.triSpreadFire)
            case .lightningArc: break
            case .phaseLaser: break
            }
        }
    }

    private func spawnEnemyProjectile(position: SIMD2<Float>, velocity: SIMD2<Float>, damage: Float) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: SIMD2(8, 8),
            layer: .enemyProjectile,
            mask: [.player, .shieldDrone]
        )
        physics.velocity = velocity
        entity.addComponent(physics)

        let render = RenderComponent(size: SIMD2(8, 8), color: SIMD4(1, 1, 1, 1))
        render.spriteId = "enemyBullet"
        entity.addComponent(render)

        registerEntity(entity)
        enemyProjectiles.append(entity)
    }

    private func spawnBossProjectile(_ request: ProjectileSpawnRequest) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: request.position))

        let size: SIMD2<Float> = request.isHoming ? SIMD2(10, 10) : SIMD2(8, 8)
        let physics = PhysicsComponent(
            collisionSize: size,
            layer: .enemyProjectile,
            mask: [.player, .shieldDrone]
        )
        physics.velocity = request.velocity
        entity.addComponent(physics)

        let projComp = ProjectileComponent(damage: request.damage, speed: simd_length(request.velocity), effects: request.effects)
        projComp.isHoming = request.isHoming
        projComp.homingTurnRate = request.homingTurnRate
        projComp.lifetime = request.lifetime
        entity.addComponent(projComp)

        let spriteId = request.effects.contains(.empDisable) ? "g3EmpProjectile" : "enemyBullet"
        let render = RenderComponent(size: size, color: SIMD4(1, 1, 1, 1))
        render.spriteId = spriteId
        entity.addComponent(render)

        registerEntity(entity)
        enemyProjectiles.append(entity)
    }

    private func spawnGravBomb(position: SIMD2<Float>, velocity: SIMD2<Float>) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: SIMD2(16, 16),
            layer: .blast,
            mask: [.enemy]
        )
        physics.velocity = velocity
        entity.addComponent(physics)

        let render = RenderComponent(size: SIMD2(16, 16), color: SIMD4(1, 1, 1, 1))
        render.spriteId = "gravBombSprite"
        entity.addComponent(render)

        registerEntity(entity)
        gravBombEntities.append(entity)
        gravBombTimers[ObjectIdentifier(entity)] = 0
        sfx?.play(.gravBombLaunch)
    }

    private func spawnUtilityItem(at position: SIMD2<Float>) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Item.size,
            layer: .item,
            mask: [.player, .playerProjectile]
        )
        entity.addComponent(physics)

        let render = RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 1, 1))
        entity.addComponent(render)

        let itemComp = ItemComponent()
        itemComp.currentCycleIndex = Int.random(in: 0..<UtilityItemType.allCases.count)

        switch itemComp.utilityItemType {
        case .energyCell:
            render.spriteId = "energyDrop"
        case .chargeCell:
            render.spriteId = "chargeCell"
        case .orbitingShield:
            render.spriteId = "shieldDrop"
        }

        entity.addComponent(itemComp)

        registerEntity(entity)
        items.append(entity)
        lightningArcSystem.registerItem(entity)
        sfx?.play(.itemSpawn)
    }

    private func spawnWeaponModuleItem(at position: SIMD2<Float>) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Item.size,
            layer: .item,
            mask: [.player, .playerProjectile]
        )
        entity.addComponent(physics)

        let render = RenderComponent(size: GameConfig.Item.size, color: GameConfig.Palette.weaponDoubleCannon)
        render.spriteId = "weaponDoubleCannon"
        entity.addComponent(render)

        let itemComp = ItemComponent()
        itemComp.isWeaponModule = true

        let currentWeapon = player.component(ofType: WeaponComponent.self)?.weaponType ?? .doubleCannon
        let allWeapons: [WeaponType] = [.doubleCannon, .triSpread, .lightningArc, .phaseLaser]
        itemComp.weaponCycle = allWeapons.filter { $0 != currentWeapon }
        if let first = itemComp.weaponCycle.first {
            itemComp.displayedWeapon = first
            itemComp.weaponCycleIndex = 0
            switch first {
            case .doubleCannon:
                render.color = GameConfig.Palette.weaponDoubleCannon
                render.spriteId = "weaponDoubleCannon"
            case .triSpread:
                render.color = GameConfig.Palette.weaponTriSpread
                render.spriteId = "weaponTriSpread"
            case .lightningArc:
                render.color = GameConfig.Palette.weaponLightningArc
                render.spriteId = "weaponLightningArc"
            case .phaseLaser:
                render.color = GameConfig.Palette.weaponPhaseLaser
                render.spriteId = "weaponPhaseLaser"
            }
        }

        entity.addComponent(itemComp)

        registerEntity(entity)
        items.append(entity)
        lightningArcSystem.registerItem(entity)
        sfx?.play(.itemSpawn)
    }

    private func spawnInitialShieldDrones(count: Int) {
        guard let playerTransform = player.component(ofType: TransformComponent.self) else { return }
        let toSpawn = min(count, GameConfig.ShieldDrone.maxDrones)

        for _ in 0..<toSpawn {
            let entity = GKEntity()
            entity.addComponent(TransformComponent(position: playerTransform.position))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.ShieldDrone.droneSize,
                layer: .shieldDrone,
                mask: [.enemyProjectile]
            )
            entity.addComponent(physics)

            let render = RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: GameConfig.Palette.shieldDrone)
            render.spriteId = "shieldDrone"
            entity.addComponent(render)

            let droneComp = ShieldDroneComponent()
            droneComp.ownerEntity = player
            entity.addComponent(droneComp)

            registerEntity(entity)
            shieldDrones.append(entity)
        }

        // Redistribute orbit angles evenly
        for (i, drone) in shieldDrones.enumerated() {
            if let comp = drone.component(ofType: ShieldDroneComponent.self) {
                comp.orbitAngle = Float(i) * (2 * .pi / Float(shieldDrones.count))
            }
        }
    }

    func spawnShieldDrones() { // CollisionContext
        guard let playerTransform = player.component(ofType: TransformComponent.self) else { return }
        let maxDrones = GameConfig.ShieldDrone.maxDrones
        let slotsAvailable = maxDrones - shieldDrones.count
        guard slotsAvailable > 0 else { return }
        let toSpawn = min(2, slotsAvailable)

        for _ in 0..<toSpawn {
            let entity = GKEntity()
            entity.addComponent(TransformComponent(position: playerTransform.position))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.ShieldDrone.droneSize,
                layer: .shieldDrone,
                mask: [.enemyProjectile]
            )
            entity.addComponent(physics)

            let render = RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: GameConfig.Palette.shieldDrone)
            render.spriteId = "shieldDrone"
            entity.addComponent(render)

            let droneComp = ShieldDroneComponent()
            droneComp.ownerEntity = player
            entity.addComponent(droneComp)

            registerEntity(entity)
            shieldDrones.append(entity)
        }

        // Redistribute orbit angles evenly
        let totalDrones = shieldDrones.count
        for (i, drone) in shieldDrones.enumerated() {
            if let comp = drone.component(ofType: ShieldDroneComponent.self) {
                comp.orbitAngle = Float(i) * (2 * .pi / Float(totalDrones))
            }
        }
    }

    // MARK: - Updates

    private func updateTurrets(deltaTime: Double) {
        for enemy in enemies {
            guard let turret = enemy.component(ofType: TurretComponent.self),
                  let transform = enemy.component(ofType: TransformComponent.self) else { continue }

            // Skip fortress nodes that don't fire (shieldGenerator)
            if let fortNode = enemy.component(ofType: FortressNodeComponent.self),
               fortNode.role == .shieldGenerator { continue }

            if let parent = turret.parentEntity,
               let parentTransform = parent.component(ofType: TransformComponent.self) {
                transform.position = parentTransform.position + turret.mountOffset
                if let parentPhysics = parent.component(ofType: PhysicsComponent.self),
                   let turretPhysics = enemy.component(ofType: PhysicsComponent.self) {
                    turretPhysics.velocity = parentPhysics.velocity
                }
            }

            turret.timeSinceLastShot += deltaTime
            if turret.timeSinceLastShot >= turret.fireInterval {
                turret.timeSinceLastShot = 0
                let playerPos = player.component(ofType: TransformComponent.self)?.position ?? .zero
                let diff = playerPos - transform.position
                let len = simd_length(diff)
                let dir = len > 0 ? diff / len : SIMD2<Float>(0, -1)
                spawnEnemyProjectile(
                    position: transform.position,
                    velocity: dir * turret.projectileSpeed,
                    damage: turret.damage
                )
            }
        }
    }

    private func updateFortressNodes(deltaTime: Double) {
        // Formerly handled shield propagation; that logic is now in
        // propagateFortressShieldDown() which runs after all damage paths.
        // This method is retained for future per-frame fortress-node updates.
    }

    /// Check for dead shield generators and propagate shield-down to sibling
    /// fortress nodes sharing the same fortressID. Called after all damage
    /// systems (collisions, laser hitscan, lightning arc) but before entity
    /// removals so the dead generator entity is still in the enemies array.
    private func propagateFortressShieldDown() {
        var destroyedGeneratorIDs: Set<Int> = []
        for enemy in enemies {
            guard let fortNode = enemy.component(ofType: FortressNodeComponent.self),
                  fortNode.role == .shieldGenerator else { continue }
            if let health = enemy.component(ofType: HealthComponent.self), !health.isAlive {
                destroyedGeneratorIDs.insert(fortNode.fortressID)
            }
        }

        if !destroyedGeneratorIDs.isEmpty {
            for enemy in enemies {
                guard let fortNode = enemy.component(ofType: FortressNodeComponent.self) else { continue }
                if destroyedGeneratorIDs.contains(fortNode.fortressID) {
                    fortNode.isShielded = false
                }
            }
        }
    }

    private func updateHomingProjectiles(deltaTime: Double) {
        let playerPos = player.component(ofType: TransformComponent.self)?.position ?? .zero

        for proj in enemyProjectiles {
            guard let projComp = proj.component(ofType: ProjectileComponent.self) else { continue }

            projComp.age += deltaTime
            if projComp.isExpired {
                pendingRemovals.append(proj)
                continue
            }

            guard projComp.isHoming,
                  let physics = proj.component(ofType: PhysicsComponent.self),
                  let transform = proj.component(ofType: TransformComponent.self) else { continue }

            let currentSpeed = simd_length(physics.velocity)
            guard currentSpeed > 0 else { continue }
            let dir = simd_normalize(playerPos - transform.position)
            let currentDir = physics.velocity / currentSpeed
            let turnAmount = projComp.homingTurnRate * Float(deltaTime)
            let blended = currentDir + dir * turnAmount
            let blendedLen = simd_length(blended)
            let newDir = blendedLen > 0 ? blended / blendedLen : currentDir
            physics.velocity = newDir * projComp.speed
        }
    }

    private func updateBarriers(deltaTime: Double) {
        guard !environmentSystem.isScrollLocked else { return }
        let scrollDelta = environmentSystem.scrollSpeed * Float(deltaTime)

        for barrier in barriers {
            guard let transform = barrier.component(ofType: TransformComponent.self) else { continue }
            transform.position.y -= scrollDelta

            // Rotate rotating gates and modulate collision width based on angle
            if let barrierComp = barrier.component(ofType: BarrierComponent.self),
               barrierComp.kind == .rotatingGate,
               let physics = barrier.component(ofType: PhysicsComponent.self) {
                barrierComp.currentAngle += barrierComp.rotationSpeed * Float(deltaTime)
                transform.rotation = barrierComp.currentAngle
                // When gate is perpendicular (angle ~0 or ~π), full collision width (closed).
                // When gate is parallel (angle ~π/2), near-zero width (open).
                let openFactor = abs(sin(barrierComp.currentAngle))
                let baseSize = GameConfig.Galaxy3.Barrier.gateSegmentSize
                physics.collisionSize = SIMD2(baseSize.x * (1.0 - openFactor * 0.9), baseSize.y)
            }
        }

        // Remove barriers that are off-screen below
        barriers.removeAll { barrier in
            guard let transform = barrier.component(ofType: TransformComponent.self),
                  let render = barrier.component(ofType: RenderComponent.self) else {
                return true
            }
            if transform.position.y + render.size.y / 2 < -GameConfig.designHeight / 2 - 50 {
                unregisterEntity(barrier)
                return true
            }
            return false
        }
    }

    private func updateFortressHulls() {
        for hull in fortressHulls {
            if let transform = hull.component(ofType: TransformComponent.self),
               transform.position.y < -GameConfig.designHeight / 2 - GameConfig.Galaxy3.Enemy.fortressHullSize.y {
                pendingRemovals.append(hull)
            }
        }
    }

    private func updateGravBombs(deltaTime: Double) {
        for bomb in gravBombEntities {
            let id = ObjectIdentifier(bomb)
            gravBombTimers[id] = (gravBombTimers[id] ?? 0) + deltaTime

            if let timer = gravBombTimers[id], timer >= GameConfig.Weapon.gravBombDetonateTime {
                detonateGravBomb(bomb)
                pendingRemovals.append(bomb)
            }
        }
    }

    private func detonateGravBomb(_ bomb: GKEntity) {
        guard let transform = bomb.component(ofType: TransformComponent.self) else { return }
        sfx?.play(.gravBombDetonate)
        let center = transform.position
        let radius = GameConfig.Weapon.gravBombBlastRadius

        for enemy in enemies {
            guard let enemyTransform = enemy.component(ofType: TransformComponent.self),
                  let health = enemy.component(ofType: HealthComponent.self) else { continue }

            let dist = simd_length(enemyTransform.position - center)
            if dist <= radius {
                health.takeDamage(GameConfig.Weapon.gravBombDamage)
                if !health.isAlive {
                    if let score = enemy.component(ofType: ScoreComponent.self) {
                        scoreSystem.addScore(score.points)
                    }
                    enemiesDestroyed += 1
                    pendingRemovals.append(enemy)
                }
            }
        }

        for proj in enemyProjectiles {
            guard let projTransform = proj.component(ofType: TransformComponent.self) else { continue }
            if simd_length(projTransform.position - center) <= radius {
                pendingRemovals.append(proj)
            }
        }

        let blast = GKEntity()
        blast.addComponent(TransformComponent(position: center))
        let blastRender = RenderComponent(
            size: SIMD2(radius * 2, radius * 2),
            color: GameConfig.Palette.gravBombBlast
        )
        blastRender.isVisible = false
        blast.addComponent(blastRender)
        let blastPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        blast.addComponent(blastPhysics)
        registerEntity(blast)
        blastEffects.append((entity: blast, timer: 0.15))
    }

    private func activateEMPSweep() {
        sfx?.play(.empSweep)
        for proj in enemyProjectiles {
            pendingRemovals.append(proj)
        }

        let flash = GKEntity()
        flash.addComponent(TransformComponent(position: .zero))
        let empWidth = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
        let flashRender = RenderComponent(
            size: SIMD2(empWidth, GameConfig.designHeight),
            color: GameConfig.Galaxy3.Palette.g3EmpFlash
        )
        flashRender.isVisible = false
        flash.addComponent(flashRender)
        let flashPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        flash.addComponent(flashPhysics)
        registerEntity(flash)
        blastEffects.append((entity: flash, timer: 0.2))

        slowMoTimer = GameConfig.Weapon.empSlowMoDuration
        isSlowMo = true
    }

    private func activateOvercharge() {
        if let weapon = player.component(ofType: WeaponComponent.self) {
            weapon.overchargeActive = true
            weapon.overchargeTimer = GameConfig.Weapon.overchargeDuration
            sfx?.play(.overchargeActivate)
        }
    }

    func processLaserHitscan(_ hitscan: LaserHitscanRequest) {
        let halfWidth = hitscan.width / 2
        let laserMinX = hitscan.position.x - halfWidth
        let laserMaxX = hitscan.position.x + halfWidth
        let laserMinY = hitscan.position.y
        let laserMaxY = GameConfig.designHeight / 2 + 50

        // Item cycling is unaffected by barrier occlusion
        for item in items {
            guard let transform = item.component(ofType: TransformComponent.self) else { continue }
            let size = item.component(ofType: RenderComponent.self)?.size ?? .zero

            let itemMinX = transform.position.x - size.x / 2
            let itemMaxX = transform.position.x + size.x / 2
            let itemMinY = transform.position.y - size.y / 2
            let itemMaxY = transform.position.y + size.y / 2

            if laserMaxX >= itemMinX && laserMinX <= itemMaxX &&
               laserMaxY >= itemMinY && laserMinY <= itemMaxY {
                itemSystem.handleProjectileHit(on: item)
                sfx?.play(.itemCycle)
            }
        }

        // Find the nearest barrier that occludes the beam (stops it from
        // reaching targets behind). Barriers with a Y above the player's Y
        // and overlapping the beam's X range block the beam.
        var beamCutoffY: Float = laserMaxY
        for barrier in barriers {
            guard let bTransform = barrier.component(ofType: TransformComponent.self),
                  let bPhysics = barrier.component(ofType: PhysicsComponent.self) else { continue }
            let bHalfW = bPhysics.collisionSize.x / 2
            let bHalfH = bPhysics.collisionSize.y / 2
            let bMinX = bTransform.position.x - bHalfW
            let bMaxX = bTransform.position.x + bHalfW
            let bMinY = bTransform.position.y - bHalfH

            // Barrier must overlap beam horizontally AND be above the player
            guard laserMaxX >= bMinX && laserMinX <= bMaxX,
                  bMinY > laserMinY else { continue }

            // The beam stops at the bottom edge of the nearest occluding barrier
            beamCutoffY = min(beamCutoffY, bMinY)
        }

        // Process enemies sorted by Y (ascending — nearest to player first),
        // stopping at the beam cutoff.
        struct EnemyHit {
            let entity: GKEntity
            let y: Float
        }

        var hits: [EnemyHit] = []
        for enemy in enemies {
            guard let transform = enemy.component(ofType: TransformComponent.self),
                  let health = enemy.component(ofType: HealthComponent.self),
                  health.isAlive else { continue }

            let size = enemy.component(ofType: RenderComponent.self)?.size ?? .zero
            guard laserMaxX >= transform.position.x - size.x / 2,
                  laserMinX <= transform.position.x + size.x / 2,
                  beamCutoffY >= transform.position.y - size.y / 2,
                  laserMinY <= transform.position.y + size.y / 2 else { continue }

            hits.append(EnemyHit(entity: enemy, y: transform.position.y))
        }
        hits.sort { $0.y < $1.y }

        for hit in hits {
            let enemy = hit.entity

            // Zenith boss shield check — laser is deflected when shield is active
            if let zenith = enemy.component(ofType: ZenithBossComponent.self),
               zenith.isShieldActive {
                sfx?.play(.bossShieldDeflect)
                continue
            }

            // Fortress node shielding — shielded non-generator nodes deflect the laser
            if let fortNode = enemy.component(ofType: FortressNodeComponent.self),
               fortNode.isShielded,
               fortNode.role != .shieldGenerator {
                sfx?.play(.bossShieldDeflect)
                continue
            }

            guard let health = enemy.component(ofType: HealthComponent.self) else { continue }
            health.takeDamage(hitscan.damagePerTick)
            if !health.isAlive {
                sfx?.play(.enemyDestroyed)
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    scoreSystem.addScore(score.points)
                }
                enemiesDestroyed += 1
                pendingRemovals.append(enemy)
                checkFormationWipe(enemy: enemy)
            } else {
                sfx?.play(.enemyHit)
            }
        }
    }

    // MARK: - Testability

    /// Registers an entity as an enemy. For use in tests via @testable import only.
    func addEnemyForTesting(_ entity: GKEntity) {
        registerEntity(entity)
        enemies.append(entity)
        lightningArcSystem.registerEnemy(entity)
    }

    /// Registers an entity as a barrier. For use in tests via @testable import only.
    func addBarrierForTesting(_ entity: GKEntity) {
        registerEntity(entity)
        barriers.append(entity)
    }

    // MARK: - Collisions

    private func processCollisions() {
        collisionResponseHandler.processCollisions(pairs: collisionSystem.collisionPairs)
    }

    func checkFormationWipe(enemy: GKEntity) { // CollisionContext
        for (id, members) in formationEnemies {
            if members.contains(where: { $0 === enemy }) {
                let alive = members.filter { member in
                    guard let health = member.component(ofType: HealthComponent.self) else { return false }
                    return health.isAlive && !pendingRemovals.contains(where: { $0 === member })
                }
                if alive.isEmpty {
                    if let transform = enemy.component(ofType: TransformComponent.self) {
                        if Float.random(in: 0..<1) < 0.45 {
                            spawnUtilityItem(at: transform.position)
                        }
                    }
                    formationEnemies.removeValue(forKey: id)
                }
                break
            }
        }
    }

    // MARK: - Barrier Push-Out

    func handleBarrierPushOut(barrier: GKEntity) {
        guard let playerTransform = player.component(ofType: TransformComponent.self),
              let barrierTransform = barrier.component(ofType: TransformComponent.self),
              let barrierPhysics = barrier.component(ofType: PhysicsComponent.self) else { return }

        // Push player out of barrier overlap on the closest axis
        let playerPos = playerTransform.position
        let barrierPos = barrierTransform.position
        let barrierHalf = barrierPhysics.collisionSize / 2
        let playerHalf = GameConfig.Player.size / 2

        let overlapLeft = (barrierPos.x + barrierHalf.x) - (playerPos.x - playerHalf.x)
        let overlapRight = (playerPos.x + playerHalf.x) - (barrierPos.x - barrierHalf.x)
        let minOverlapX = min(overlapLeft, overlapRight)

        if overlapLeft < overlapRight {
            playerTransform.position.x -= minOverlapX
        } else {
            playerTransform.position.x += minOverlapX
        }
    }

    // MARK: - Cull

    private func cullOffScreen() {
        let margin: Float = 50
        let minY = -GameConfig.designHeight / 2 - margin
        let maxY = GameConfig.designHeight / 2 + margin
        let minX = -currentHalfWidth - margin
        let maxX = currentHalfWidth + margin

        for entity in (enemies + projectiles + enemyProjectiles) {
            if let turret = entity.component(ofType: TurretComponent.self),
               turret.parentEntity != nil { continue }

            guard let transform = entity.component(ofType: TransformComponent.self) else { continue }
            if transform.position.y < minY || transform.position.y > maxY ||
               transform.position.x < minX || transform.position.x > maxX {
                pendingRemovals.append(entity)
            }
        }
    }

    // MARK: - HUD

    private func appendGameOverOverlay(to sprites: inout [SpriteInstance]) {
        let overlayW = (viewportManager?.currentDesignWidth ?? GameConfig.designWidth) * 2
        sprites.append(SpriteInstance(
            position: .zero,
            size: SIMD2(overlayW, GameConfig.designHeight * 2),
            color: SIMD4(0, 0, 0, 0.6)
        ))
    }

    private func appendVictoryOverlay(to sprites: inout [SpriteInstance]) {
        let overlayW = (viewportManager?.currentDesignWidth ?? GameConfig.designWidth) * 2
        sprites.append(SpriteInstance(
            position: .zero,
            size: SIMD2(overlayW, GameConfig.designHeight * 2),
            color: SIMD4(0, 0, 0, 0.4)
        ))
    }
}

extension Galaxy3Scene: CollisionContext {}
