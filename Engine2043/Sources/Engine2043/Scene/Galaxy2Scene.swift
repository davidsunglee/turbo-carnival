import GameplayKit
import simd

@MainActor
public final class Galaxy2Scene: GameScene {

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
    private let spawnDirector = SpawnDirector(galaxy: .galaxy2)
    let asteroidSystem = AsteroidSystem() // CollisionContext
    private var lightningArcSystem: LightningArcSystem!
    private let collisionResponseHandler = CollisionResponseHandler()
    private let titleCard = GalaxyTitleCard(title: "GALAXY 2: KAY'SHARA EXPANSE")

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
    private var capitalShipHulls: [GKEntity] = []
    private(set) var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    private var armorEntities: [GKEntity] = []  // armor asteroids orbiting Lithic Harvester
    private var shieldDrones: [GKEntity] = []
    private var asteroids: [GKEntity] = []
    var asteroidCount: Int { asteroids.count } // testability
    var pendingRemovals: [GKEntity] = [] // CollisionContext

    // MARK: - Formation tracking
    private var formationEnemies: [Int: [GKEntity]] = [:]
    private var nextFormationID: Int = 0

    // MARK: - Rendering
    public var backgroundColor: SIMD4<Float> { GameConfig.Galaxy2.Palette.g2Background }

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

    public init(carryover: PlayerCarryover? = nil) {
        let carryover = carryover ?? PlayerCarryover(
            weaponType: .doubleCannon,
            score: 0,
            secondaryCharges: 1,
            shieldDroneCount: 0,
            enemiesDestroyed: 0,
            elapsedTime: 0
        )
        collisionSystem = CollisionSystem(worldBounds: AABB(min: SIMD2(-200, -340), max: SIMD2(200, 340)))
        backgroundSystem.palette = .galaxy2

        // Carry over stats (accumulated totals)
        enemiesDestroyed = carryover.enemiesDestroyed
        elapsedTime = carryover.elapsedTime

        setupPlayer(carryover: carryover)
        lightningArcSystem = LightningArcSystem(player: player)
        collisionResponseHandler.context = self

        // Spawn initial sparse asteroid background layer
        let sparseAsteroids = asteroidSystem.spawnSparseLayer(
            count: GameConfig.Galaxy2.Asteroid.sparseCount,
            viewportHalfWidth: GameConfig.designWidth / 2,
            fieldHeight: GameConfig.designHeight
        )
        for entity in sparseAsteroids {
            registerAsteroid(entity)
        }

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
            mask: [.enemy, .enemyProjectile, .item, .asteroid]
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

    private func registerAsteroid(_ entity: GKEntity) {
        asteroidSystem.register(entity)
        physicsSystem.register(entity)
        collisionSystem.register(entity)
        renderSystem.register(entity)
        asteroids.append(entity)
    }

    private func unregisterAsteroid(_ entity: GKEntity) {
        asteroidSystem.unregister(entity)
        physicsSystem.unregister(entity)
        collisionSystem.unregister(entity)
        renderSystem.unregister(entity)
        asteroids.removeAll { $0 === entity }
    }

    private func removeEntity(_ entity: GKEntity) {
        // Check if it's an asteroid first
        if entity.component(ofType: AsteroidComponent.self) != nil {
            unregisterAsteroid(entity)
            return
        }

        unregisterEntity(entity)
        lightningArcSystem.unregisterEnemy(entity)
        lightningArcSystem.unregisterItem(entity)
        enemies.removeAll { $0 === entity }
        projectiles.removeAll { $0 === entity }
        enemyProjectiles.removeAll { $0 === entity }
        items.removeAll { $0 === entity }
        capitalShipHulls.removeAll { $0 === entity }
        gravBombEntities.removeAll { $0 === entity }
        gravBombTimers.removeValue(forKey: ObjectIdentifier(entity))
        shieldEntities.removeAll { $0 === entity }
        armorEntities.removeAll { $0 === entity }
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

        // Game over / victory — transition after delay
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
                let weapon = player.component(ofType: WeaponComponent.self)
                let carryover = PlayerCarryover(
                    weaponType: weapon?.weaponType ?? .doubleCannon,
                    score: scoreSystem.currentScore,
                    secondaryCharges: weapon?.secondaryCharges ?? 1,
                    shieldDroneCount: shieldDrones.count,
                    enemiesDestroyed: enemiesDestroyed,
                    elapsedTime: elapsedTime
                )
                ProgressStore.markCleared(galaxy: 2)
                requestedTransition = .toGalaxy3(carryover)
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

        // Background and spawn director
        backgroundSystem.update(deltaTime: time.fixedDeltaTime)
        if spawnDirector.shouldLockScroll {
            backgroundSystem.isScrollLocked = true
        }

        spawnDirector.update(scrollDistance: backgroundSystem.scrollDistance)
        processSpawnDirectorWaves()

        // Process asteroid field triggers
        for fieldDef in spawnDirector.pendingAsteroidFields {
            let fieldEntities = asteroidSystem.spawnField(
                count: fieldDef.count,
                largeFraction: fieldDef.largeFraction,
                spawnYBase: GameConfig.designHeight / 2 + 50,
                viewportHalfWidth: currentHalfWidth
            )
            for entity in fieldEntities {
                registerAsteroid(entity)
            }
        }

        // Scripted drops
        for drop in spawnDirector.pendingDrops {
            switch drop.type {
            case .weaponModule:
                let x = Float.random(in: -40...40)
                spawnWeaponModuleItem(at: SIMD2(x, 300))
            }
        }

        // Behavior systems
        let playerPos = player.component(ofType: TransformComponent.self)?.position ?? .zero
        steeringSystem.playerPosition = playerPos
        formationSystem.update(deltaTime: time.fixedDeltaTime)
        steeringSystem.update(deltaTime: time.fixedDeltaTime, viewportHalfWidth: currentHalfWidth)

        // Turrets and boss projectiles paused during slow-mo
        if !isSlowMo {
            updateTurrets(deltaTime: time.fixedDeltaTime)

            bossSystem.playerPosition = playerPos
            bossSystem.update(deltaTime: time.fixedDeltaTime)
            for spawn in bossSystem.pendingProjectileSpawns {
                spawnEnemyProjectile(position: spawn.position, velocity: spawn.velocity, damage: spawn.damage)
            }

            // Initiate new tractor beam captures when boss has empty armor slots
            initiateTractorBeamCaptures(deltaTime: time.fixedDeltaTime)

            // Process tractor beam pulls: move targeted asteroids toward boss
            processTractorBeamPulls()

            // Process boss armor: clean up destroyed armor entities
            updateBossArmor()
        }

        // Asteroid system update
        asteroidSystem.update(deltaTime: time.fixedDeltaTime)
        for entity in asteroidSystem.pendingRemovals {
            pendingRemovals.append(entity)
        }

        // Physics
        physicsSystem.syncFromComponents()
        physicsSystem.update(time: time)

        // Clamp player position to screen boundaries (must run after physics)
        if let transform = player.component(ofType: TransformComponent.self) {
            let halfW = currentHalfWidth - GameConfig.Player.size.x / 2
            let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2
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

        // Capital ship hull updates
        updateCapitalShipHulls()

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

        // Capital ship hulls render behind gameplay entities
        for hull in capitalShipHulls {
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

        // Asteroids render between background and gameplay entities
        for asteroid in asteroids {
            if let transform = asteroid.component(ofType: TransformComponent.self),
               let render = asteroid.component(ofType: RenderComponent.self),
               render.isVisible {
                let spriteId: String?
                if let asteroidComp = asteroid.component(ofType: AsteroidComponent.self) {
                    spriteId = asteroidComp.asteroidSize == .large ? "asteroidLarge" : "asteroidSmall"
                } else {
                    spriteId = render.spriteId
                }
                let uv = atlas?.uvRect(for: spriteId) ?? SpriteInstance.defaultUVRect
                sprites.append(SpriteInstance(
                    position: transform.position,
                    size: render.size,
                    color: render.color,
                    rotation: transform.rotation,
                    uvRect: uv
                ))
            }
        }

        // Armor entities render on top of asteroids
        for armorEntity in armorEntities {
            if let transform = armorEntity.component(ofType: TransformComponent.self),
               let render = armorEntity.component(ofType: RenderComponent.self),
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

        // Tractor beam visuals
        if let boss = bossEntity,
           let bossTransform = boss.component(ofType: TransformComponent.self),
           let armor = boss.component(ofType: BossArmorComponent.self) {
            for target in armor.tractorBeamTargets {
                guard let targetTransform = target.component(ofType: TransformComponent.self) else { continue }
                let from = bossTransform.position
                let to = targetTransform.position
                let diff = to - from
                let length = simd_length(diff)
                guard length > 0 else { continue }
                let midpoint = (from + to) / 2
                let angle = atan2(diff.x, diff.y)

                let uv = atlas?.uvRect(for: "tractorBeamSegment") ?? SpriteInstance.defaultUVRect
                sprites.append(SpriteInstance(
                    position: midpoint,
                    size: SIMD2(4, length),
                    color: GameConfig.Galaxy2.Palette.g2TractorBeam,
                    rotation: -angle,
                    uvRect: uv
                ))
            }
        }

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

            // Map secondary fire buttons — first pressed wins
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

    // MARK: - Spawning

    private func processSpawnDirectorWaves() {
        for wave in spawnDirector.pendingWaves {
            switch wave.enemyTier {
            case .tier1:
                spawnG2Tier1Formation(wave: wave)
            case .tier2:
                spawnG2Tier2Group(wave: wave)
            case .tier3:
                spawnG2MiningBarge(wave: wave)
            case .boss:
                spawnBoss()
            }
        }
    }

    private func spawnG2Tier1Formation(wave: WaveDefinition) {
        let formationID = nextFormationID
        nextFormationID += 1
        var members: [GKEntity] = []

        let spacing: Float = 50
        let startX = wave.spawnX - Float(wave.count - 1) / 2 * spacing

        for i in 0..<wave.count {
            let entity = GKEntity()
            let xOffset = startX + Float(i) * spacing
            var yOffset: Float = 0
            if wave.pattern == .vShape {
                yOffset = abs(Float(i) - Float(wave.count - 1) / 2) * 20
            }

            entity.addComponent(TransformComponent(position: SIMD2(xOffset, wave.spawnY + yOffset)))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.Galaxy2.Enemy.tier1Size,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            entity.addComponent(physics)

            let tier1Render = RenderComponent(
                size: GameConfig.Galaxy2.Enemy.tier1Size,
                color: GameConfig.Galaxy2.Palette.g2Tier1
            )
            tier1Render.spriteId = "g2Interceptor"
            entity.addComponent(tier1Render)

            let health1 = HealthComponent(health: GameConfig.Galaxy2.Enemy.tier1HP)
            health1.hasInvulnerabilityFrames = false
            entity.addComponent(health1)
            entity.addComponent(ScoreComponent(points: GameConfig.Galaxy2.Score.g2Tier1))

            let formation = FormationComponent(pattern: wave.pattern, index: i, formationID: formationID)
            if wave.pattern == .sineWave {
                formation.phaseOffset = Float(i) * 0.5
            }
            entity.addComponent(formation)

            registerEntity(entity)
            enemies.append(entity)
            members.append(entity)
            lightningArcSystem.registerEnemy(entity)
        }

        formationEnemies[formationID] = members
    }

    private func spawnG2Tier2Group(wave: WaveDefinition) {
        for i in 0..<wave.count {
            let entity = GKEntity()

            let xSpread: Float = 60
            let x = wave.spawnX + Float(i) * xSpread - Float(wave.count - 1) / 2 * xSpread
            entity.addComponent(TransformComponent(position: SIMD2(x, wave.spawnY)))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.Galaxy2.Enemy.tier2Size,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            physics.velocity = SIMD2(0, -GameConfig.Galaxy2.Enemy.tier2Speed)
            entity.addComponent(physics)

            let tier2Render = RenderComponent(
                size: GameConfig.Galaxy2.Enemy.tier2Size,
                color: GameConfig.Galaxy2.Palette.g2Tier2
            )
            tier2Render.spriteId = "g2Fighter"
            entity.addComponent(tier2Render)

            let health2 = HealthComponent(health: GameConfig.Galaxy2.Enemy.tier2HP)
            health2.hasInvulnerabilityFrames = false
            entity.addComponent(health2)
            entity.addComponent(ScoreComponent(points: GameConfig.Galaxy2.Score.g2Tier2))

            let steering = SteeringComponent(behavior: .leadShot)
            steering.steerStrength = 3.0
            entity.addComponent(steering)

            let turretComp = TurretComponent(trackingSpeed: 1.5)
            turretComp.fireInterval = 1.5
            turretComp.projectileSpeed = 300
            turretComp.damage = 5
            entity.addComponent(turretComp)

            registerEntity(entity)
            enemies.append(entity)
            lightningArcSystem.registerEnemy(entity)
        }
    }

    private func spawnG2MiningBarge(wave: WaveDefinition) {
        let hull = GKEntity()
        hull.addComponent(TransformComponent(position: SIMD2(0, wave.spawnY + 100)))
        let hullRender = RenderComponent(
            size: GameConfig.Galaxy2.Enemy.tier3HullSize,
            color: GameConfig.Palette.capitalShipHull
        )
        hullRender.spriteId = "miningBargeHull"
        hull.addComponent(hullRender)
        let hullPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        hullPhysics.velocity = SIMD2(0, -GameConfig.Background.starScrollSpeed * GameConfig.Enemy.tier3ScrollMultiplier)
        hull.addComponent(hullPhysics)
        physicsSystem.register(hull)
        capitalShipHulls.append(hull)

        // 6 turrets: 3 on each side, spread across the 216-wide hull
        let turretOffsets: [SIMD2<Float>] = [
            SIMD2(-85, 25), SIMD2(-50, 25), SIMD2(-15, 25),  // left side
            SIMD2(15, 25),  SIMD2(50, 25),  SIMD2(85, 25)    // right side
        ]

        let formationID = nextFormationID
        nextFormationID += 1
        var turretMembers: [GKEntity] = []

        for offset in turretOffsets.prefix(wave.count) {
            let turret = GKEntity()

            let turretTransform = TransformComponent(
                position: SIMD2(offset.x, wave.spawnY + 100 + offset.y)
            )
            turret.addComponent(turretTransform)

            let turretPhysics = PhysicsComponent(
                collisionSize: GameConfig.Galaxy2.Enemy.tier3TurretSize,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            turretPhysics.velocity = SIMD2(0, -GameConfig.Background.starScrollSpeed * GameConfig.Enemy.tier3ScrollMultiplier)
            turret.addComponent(turretPhysics)

            let turretRender = RenderComponent(
                size: GameConfig.Galaxy2.Enemy.tier3TurretSize,
                color: GameConfig.Palette.turret
            )
            turretRender.spriteId = "miningBargeTurret"
            turret.addComponent(turretRender)

            let turretHealth = HealthComponent(health: GameConfig.Galaxy2.Enemy.tier3TurretHP)
            turretHealth.hasInvulnerabilityFrames = false
            turret.addComponent(turretHealth)
            turret.addComponent(ScoreComponent(points: GameConfig.Galaxy2.Score.g2Tier3Turret))

            let turretComp = TurretComponent(trackingSpeed: 2.0)
            turretComp.parentEntity = hull
            turretComp.mountOffset = offset
            turret.addComponent(turretComp)

            registerEntity(turret)
            enemies.append(turret)
            lightningArcSystem.registerEnemy(turret)
            turretMembers.append(turret)
        }

        formationEnemies[formationID] = turretMembers
    }

    private func spawnBoss() {
        let boss = GKEntity()

        boss.addComponent(TransformComponent(position: SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)))
        let physics = PhysicsComponent(
            collisionSize: GameConfig.Galaxy2.Enemy.bossSize,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        boss.addComponent(physics)

        let bossRender = RenderComponent(
            size: GameConfig.Galaxy2.Enemy.bossSize,
            color: GameConfig.Galaxy2.Palette.g2BossCore
        )
        bossRender.spriteId = "lithicHarvesterCore"
        boss.addComponent(bossRender)

        let bossHealth = HealthComponent(health: GameConfig.Galaxy2.Enemy.bossHP)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(BossPhaseComponent(totalHP: GameConfig.Galaxy2.Enemy.bossHP))
        boss.component(ofType: BossPhaseComponent.self)!.introComplete = false
        boss.addComponent(ScoreComponent(points: GameConfig.Galaxy2.Score.g2Boss))

        // Lithic Harvester armor
        let armorComp = BossArmorComponent()
        let slotCount = GameConfig.Galaxy2.Enemy.bossArmorSlots
        for i in 0..<slotCount {
            let angle = Float(i) / Float(slotCount) * .pi * 2
            armorComp.slots.append(ArmorSlot(angle: angle, entity: nil))
        }
        boss.addComponent(armorComp)

        registerEntity(boss)
        bossSystem.bossType = .lithicHarvester
        bossSystem.register(boss)
        enemies.append(boss)
        lightningArcSystem.registerEnemy(boss)
        bossEntity = boss

        // Spawn initial armor asteroids
        let bossPos = boss.component(ofType: TransformComponent.self)!.position
        for i in 0..<slotCount {
            let armorEntity = makeArmorAsteroid(
                position: bossPos + SIMD2(
                    cos(armorComp.slots[i].angle),
                    sin(armorComp.slots[i].angle)
                ) * armorComp.armorRadius
            )
            armorComp.slots[i].entity = armorEntity
            registerEntity(armorEntity)
            collisionSystem.register(armorEntity)
            armorEntities.append(armorEntity)
        }

        sfx?.fadeToTrack(.galaxy2Boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
    }

    private func makeArmorAsteroid(position: SIMD2<Float>) -> GKEntity {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))
        let physics = PhysicsComponent(
            collisionSize: GameConfig.Galaxy2.Asteroid.smallSize,
            layer: .asteroid,
            mask: [.playerProjectile]
        )
        entity.addComponent(physics)
        let render = RenderComponent(
            size: GameConfig.Galaxy2.Asteroid.smallSize,
            color: GameConfig.Galaxy2.Palette.g2AsteroidSmall
        )
        render.spriteId = "asteroidSmall"
        entity.addComponent(render)
        let health = HealthComponent(health: GameConfig.Galaxy2.Enemy.bossArmorSlotHP)
        health.hasInvulnerabilityFrames = false
        entity.addComponent(health)
        entity.addComponent(AsteroidComponent(size: .small))
        return entity
    }

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
            mask: [.enemy, .bossShield, .item, .asteroid]
        )
        physics.velocity = request.velocity
        entity.addComponent(physics)

        let projComp = ProjectileComponent(damage: request.damage, speed: simd_length(request.velocity))
        entity.addComponent(projComp)

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

    private func initiateTractorBeamCaptures(deltaTime: Double) {
        guard let boss = bossEntity,
              let armor = boss.component(ofType: BossArmorComponent.self),
              let bossPos = boss.component(ofType: TransformComponent.self)?.position else { return }

        tractorBeamSearchTimer += deltaTime
        let hasEmptySlot = armor.slots.contains { !$0.isActive }
        let notCurrentlyPulling = armor.tractorBeamTargets.isEmpty

        // Only try to capture a new asteroid periodically (using boss's tractor beam interval)
        guard hasEmptySlot && notCurrentlyPulling &&
              tractorBeamSearchTimer >= armor.tractorBeamInterval else { return }

        tractorBeamSearchTimer = 0

        // Find nearest asteroid not already serving as armor
        let armorEntityIds = Set(armorEntities.map { ObjectIdentifier($0) })
        if let nearest = asteroids
            .filter({ !armorEntityIds.contains(ObjectIdentifier($0)) })
            .min(by: {
                let d1 = simd_length(($0.component(ofType: TransformComponent.self)?.position ?? .zero) - bossPos)
                let d2 = simd_length(($1.component(ofType: TransformComponent.self)?.position ?? .zero) - bossPos)
                return d1 < d2
            }) {
            armor.tractorBeamTargets.append(nearest)
            sfx?.play(.tractorBeam) // tractor beam activation
        }
    }

    private func processTractorBeamPulls() {
        guard let boss = bossEntity,
              let armor = boss.component(ofType: BossArmorComponent.self),
              let bossTransform = boss.component(ofType: TransformComponent.self) else { return }

        // Move tractor beam targets toward the boss
        var arrivedIndices: [Int] = []
        for (i, target) in armor.tractorBeamTargets.enumerated() {
            guard let targetTransform = target.component(ofType: TransformComponent.self) else { continue }

            let toBoss = bossTransform.position - targetTransform.position
            let distance = simd_length(toBoss)

            if distance < armor.armorRadius + 10 {
                // Arrived — attach to an empty armor slot
                arrivedIndices.append(i)
                if let emptyIdx = armor.slots.firstIndex(where: { !$0.isActive }) {
                    armor.slots[emptyIdx].entity = target
                    armorEntities.append(target)
                    sfx?.play(.tractorBeam)
                }
            } else {
                // Move toward boss
                let dir = toBoss / distance
                targetTransform.position += dir * 120 * Float(GameConfig.fixedTimeStep)
            }
        }

        // Remove arrived targets (iterate in reverse to preserve indices)
        for i in arrivedIndices.sorted().reversed() {
            armor.tractorBeamTargets.remove(at: i)
        }
    }

    private func updateBossArmor() {
        guard let boss = bossEntity,
              let armor = boss.component(ofType: BossArmorComponent.self) else { return }

        // Clean up destroyed armor entities
        for i in 0..<armor.slots.count {
            if let armorEntity = armor.slots[i].entity,
               let health = armorEntity.component(ofType: HealthComponent.self),
               !health.isAlive {
                armor.slots[i].entity = nil
                pendingRemovals.append(armorEntity)
                armorEntities.removeAll { $0 === armorEntity }
            }
        }
    }

    private func updateCapitalShipHulls() {
        for hull in capitalShipHulls {
            if let transform = hull.component(ofType: TransformComponent.self),
               transform.position.y < -GameConfig.designHeight / 2 - GameConfig.Galaxy2.Enemy.tier3HullSize.y {
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
            color: GameConfig.Palette.empFlash
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

        // Item cycling is unaffected by asteroid occlusion
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

        // Gather all entities (enemies + asteroids) that overlap the beam, sorted
        // ascending by Y so those nearest the player are processed first.
        enum LaserHitKind {
            case enemy(GKEntity)
            case asteroid(GKEntity)
        }
        struct HitCandidate {
            let kind: LaserHitKind
            let y: Float
        }

        var candidates: [HitCandidate] = []

        for enemy in enemies {
            guard let transform = enemy.component(ofType: TransformComponent.self),
                  let health = enemy.component(ofType: HealthComponent.self),
                  health.isAlive else { continue }

            let size = enemy.component(ofType: RenderComponent.self)?.size ?? .zero
            guard laserMaxX >= transform.position.x - size.x / 2,
                  laserMinX <= transform.position.x + size.x / 2,
                  laserMaxY >= transform.position.y - size.y / 2,
                  laserMinY <= transform.position.y + size.y / 2 else { continue }

            candidates.append(HitCandidate(kind: .enemy(enemy), y: transform.position.y))
        }

        for asteroid in asteroids {
            guard let transform = asteroid.component(ofType: TransformComponent.self),
                  asteroid.component(ofType: AsteroidComponent.self) != nil else { continue }

            let size = asteroid.component(ofType: PhysicsComponent.self)?.collisionSize
                ?? asteroid.component(ofType: RenderComponent.self)?.size ?? .zero
            guard laserMaxX >= transform.position.x - size.x / 2,
                  laserMinX <= transform.position.x + size.x / 2,
                  laserMaxY >= transform.position.y - size.y / 2,
                  laserMinY <= transform.position.y + size.y / 2 else { continue }

            candidates.append(HitCandidate(kind: .asteroid(asteroid), y: transform.position.y))
        }

        // Sort ascending Y: entities closest to the player (lowest Y) come first.
        candidates.sort { $0.y < $1.y }

        for candidate in candidates {
            switch candidate.kind {
            case .asteroid(let asteroid):
                guard let asteroidComp = asteroid.component(ofType: AsteroidComponent.self) else { continue }
                if asteroidComp.asteroidSize == .large {
                    return // Large asteroid blocks the beam — nothing behind it is hit
                }
                // Small asteroid: take damage; beam continues through
                if let health = asteroid.component(ofType: HealthComponent.self) {
                    health.takeDamage(hitscan.damagePerTick)
                    if !health.isAlive {
                        sfx?.play(.asteroidDestroyed)
                        if let score = asteroid.component(ofType: ScoreComponent.self) {
                            scoreSystem.addScore(score.points)
                        }
                        pendingRemovals.append(asteroid)
                    } else {
                        sfx?.play(.asteroidHit)
                    }
                }

            case .enemy(let enemy):
                // Boss armor interception: geometric angle-based check.
                // The Phase Laser fires straight up from the player, so the angle
                // from boss toward the laser source determines which armor
                // slot (if any) blocks the beam.
                if let armor = enemy.component(ofType: BossArmorComponent.self) {
                    let laserApproachAngle = atan2(
                        hitscan.position.y - enemy.component(ofType: TransformComponent.self)!.position.y,
                        hitscan.position.x - enemy.component(ofType: TransformComponent.self)!.position.x
                    )
                    if let idx = armor.coveringSlotIndex(for: laserApproachAngle),
                       let armorEntity = armor.slots[idx].entity,
                       let armorHealth = armorEntity.component(ofType: HealthComponent.self) {
                        armorHealth.takeDamage(hitscan.damagePerTick)
                        if !armorHealth.isAlive {
                            sfx?.play(.asteroidDestroyed)
                            armor.slots[idx].entity = nil
                            pendingRemovals.append(armorEntity)
                            armorEntities.removeAll { $0 === armorEntity }
                        } else {
                            sfx?.play(.bossShieldDeflect) // armor deflects the laser
                        }
                        continue  // Armor absorbed the laser — skip boss damage
                    }
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
    }

    // MARK: - Testability

    /// Registers an entity as an enemy. For use in tests via @testable import only.
    func addEnemyForTesting(_ entity: GKEntity) {
        registerEntity(entity)
        enemies.append(entity)
        lightningArcSystem.registerEnemy(entity)
    }

    /// Registers an entity as an asteroid. For use in tests via @testable import only.
    func addAsteroidForTesting(_ entity: GKEntity) {
        registerAsteroid(entity)
    }

    /// Removes an asteroid immediately (bypasses pendingRemovals). For use in tests only.
    func removeAsteroidForTesting(_ entity: GKEntity) {
        unregisterAsteroid(entity)
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

extension Galaxy2Scene: CollisionContext {}
