import GameplayKit
import simd

public enum GameState: Sendable {
    case playing
    case gameOver
    case victory
}

@MainActor
public final class Galaxy1Scene: GameScene {

    // MARK: - Systems
    private let physicsSystem = PhysicsSystem()
    private let collisionSystem: CollisionSystem
    private let renderSystem = RenderSystem()
    private let weaponSystem = WeaponSystem()
    private let formationSystem = FormationSystem()
    private let steeringSystem = SteeringSystem()
    private let itemSystem = ItemSystem()
    private let scoreSystem = ScoreSystem()
    private let backgroundSystem = BackgroundSystem()
    private let bossSystem = BossSystem()
    private let spawnDirector = SpawnDirector()

    // MARK: - Input / Audio
    public var inputProvider: (any InputProvider)?
    public var audioProvider: (any AudioProvider)?

    // MARK: - Entities
    private var player: GKEntity!
    private var enemies: [GKEntity] = []
    private var projectiles: [GKEntity] = []
    private var enemyProjectiles: [GKEntity] = []
    private var items: [GKEntity] = []
    private var capitalShipHulls: [GKEntity] = []
    private var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    private var pendingRemovals: [GKEntity] = []

    // MARK: - Formation tracking
    private var formationEnemies: [Int: [GKEntity]] = [:]
    private var nextFormationID: Int = 0

    // MARK: - Game state
    public private(set) var gameState: GameState = .playing
    private var gravBombEntities: [GKEntity] = []
    private var gravBombTimers: [ObjectIdentifier: Double] = [:]

    // MARK: - World
    private let worldBounds = AABB(min: SIMD2(-200, -340), max: SIMD2(200, 340))

    // MARK: - Init

    public init() {
        collisionSystem = CollisionSystem(worldBounds: worldBounds)
        setupPlayer()
    }

    private func setupPlayer() {
        player = GKEntity()

        let transform = TransformComponent(position: SIMD2(0, -250))
        player.addComponent(transform)

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Player.size,
            layer: .player,
            mask: [.enemy, .enemyProjectile, .item]
        )
        player.addComponent(physics)

        player.addComponent(RenderComponent(
            size: GameConfig.Player.size,
            color: GameConfig.Palette.player
        ))

        player.addComponent(HealthComponent(health: GameConfig.Player.health))

        let weapon = WeaponComponent(
            fireRate: GameConfig.Player.fireRate,
            damage: GameConfig.Player.damage,
            projectileSpeed: GameConfig.Player.projectileSpeed
        )
        player.addComponent(weapon)

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
    }

    private func unregisterEntity(_ entity: GKEntity) {
        physicsSystem.unregister(entity)
        collisionSystem.unregister(entity)
        renderSystem.unregister(entity)
        weaponSystem.unregister(entity)
        formationSystem.unregister(entity)
        steeringSystem.unregister(entity)
        itemSystem.unregister(entity)
        bossSystem.unregister(entity)
    }

    private func removeEntity(_ entity: GKEntity) {
        unregisterEntity(entity)
        enemies.removeAll { $0 === entity }
        projectiles.removeAll { $0 === entity }
        enemyProjectiles.removeAll { $0 === entity }
        items.removeAll { $0 === entity }
        capitalShipHulls.removeAll { $0 === entity }
        gravBombEntities.removeAll { $0 === entity }
        gravBombTimers.removeValue(forKey: ObjectIdentifier(entity))
        shieldEntities.removeAll { $0 === entity }

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
        guard gameState == .playing else { return }

        handleInput()

        // Background and spawn director
        backgroundSystem.update(deltaTime: time.fixedDeltaTime)
        if spawnDirector.shouldLockScroll {
            backgroundSystem.isScrollLocked = true
        }

        spawnDirector.update(scrollDistance: backgroundSystem.scrollDistance)
        processSpawnDirectorWaves()

        // Behavior systems
        let playerPos = player.component(ofType: TransformComponent.self)?.position ?? .zero
        steeringSystem.playerPosition = playerPos
        formationSystem.update(deltaTime: time.fixedDeltaTime)
        steeringSystem.update(deltaTime: time.fixedDeltaTime)

        // Turrets
        updateTurrets(deltaTime: time.fixedDeltaTime)

        // Boss
        bossSystem.playerPosition = playerPos
        bossSystem.update(deltaTime: time.fixedDeltaTime)
        for spawn in bossSystem.pendingProjectileSpawns {
            spawnEnemyProjectile(position: spawn.position, velocity: spawn.velocity, damage: spawn.damage)
        }

        // Check boss defeat
        if let boss = bossEntity,
           let bossPhase = boss.component(ofType: BossPhaseComponent.self),
           bossPhase.isDefeated {
            gameState = .victory
            scoreSystem.addScore(GameConfig.Score.boss)
        }

        // Physics
        physicsSystem.syncFromComponents()
        physicsSystem.update(time: time)
        collisionSystem.update(time: time)
        weaponSystem.update(time: time)

        // Spawn player projectiles
        for request in weaponSystem.pendingSpawns {
            spawnPlayerProjectile(request)
        }

        // Spawn grav-bombs
        for request in weaponSystem.pendingSecondarySpawns {
            spawnGravBomb(position: request.position, velocity: request.velocity)
        }

        // Update grav-bomb timers
        updateGravBombs(deltaTime: time.fixedDeltaTime)

        // Item system
        itemSystem.update(deltaTime: time.fixedDeltaTime)
        for entity in itemSystem.pendingDespawns {
            pendingRemovals.append(entity)
        }

        // Collisions
        processCollisions()

        // Player invulnerability
        player.component(ofType: HealthComponent.self)?
            .updateInvulnerability(deltaTime: time.fixedDeltaTime)

        // Check game over
        if let health = player.component(ofType: HealthComponent.self), !health.isAlive {
            gameState = .gameOver
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

    public func collectSprites() -> [SpriteInstance] {
        var sprites = backgroundSystem.collectSprites()
        sprites.append(contentsOf: renderSystem.collectSprites())
        appendHUD(to: &sprites)

        if gameState == .gameOver {
            appendGameOverOverlay(to: &sprites)
        } else if gameState == .victory {
            appendVictoryOverlay(to: &sprites)
        }

        return sprites
    }

    // MARK: - Input

    private func handleInput() {
        guard let input = inputProvider?.poll() else { return }

        if let physics = player.component(ofType: PhysicsComponent.self) {
            physics.velocity = input.movement * GameConfig.Player.speed
        }

        if let weapon = player.component(ofType: WeaponComponent.self) {
            weapon.isFiring = input.primaryFire
            weapon.isSecondaryFiring = input.secondaryFire
        }

        if let transform = player.component(ofType: TransformComponent.self) {
            let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2
            let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2
            transform.position.x = max(-halfW, min(halfW, transform.position.x))
            transform.position.y = max(-halfH, min(halfH, transform.position.y))
        }
    }

    // MARK: - Spawning

    private func processSpawnDirectorWaves() {
        for wave in spawnDirector.pendingWaves {
            switch wave.enemyTier {
            case .tier1:
                spawnTier1Formation(wave: wave)
            case .tier2:
                spawnTier2Group(wave: wave)
            case .tier3:
                spawnCapitalShip(wave: wave)
            case .boss:
                spawnBoss()
            }
        }
    }

    private func spawnTier1Formation(wave: WaveDefinition) {
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
                collisionSize: GameConfig.Enemy.tier1Size,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            entity.addComponent(physics)

            entity.addComponent(RenderComponent(
                size: GameConfig.Enemy.tier1Size,
                color: GameConfig.Palette.enemy
            ))

            entity.addComponent(HealthComponent(health: GameConfig.Enemy.tier1HP))
            entity.addComponent(ScoreComponent(points: GameConfig.Score.tier1))

            let formation = FormationComponent(pattern: wave.pattern, index: i, formationID: formationID)
            if wave.pattern == .sineWave {
                formation.phaseOffset = Float(i) * 0.5
            }
            entity.addComponent(formation)

            registerEntity(entity)
            enemies.append(entity)
            members.append(entity)
        }

        formationEnemies[formationID] = members
    }

    private func spawnTier2Group(wave: WaveDefinition) {
        for i in 0..<wave.count {
            let entity = GKEntity()

            let xSpread: Float = 60
            let x = wave.spawnX + Float(i) * xSpread - Float(wave.count - 1) / 2 * xSpread
            entity.addComponent(TransformComponent(position: SIMD2(x, wave.spawnY)))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.Enemy.tier2Size,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            physics.velocity = SIMD2(0, -GameConfig.Enemy.tier2Speed)
            entity.addComponent(physics)

            entity.addComponent(RenderComponent(
                size: GameConfig.Enemy.tier2Size,
                color: GameConfig.Palette.tier2Enemy
            ))

            entity.addComponent(HealthComponent(health: GameConfig.Enemy.tier2HP))
            entity.addComponent(ScoreComponent(points: GameConfig.Score.tier2))

            let steering = SteeringComponent(behavior: i % 2 == 0 ? .hover : .strafe)
            steering.hoverY = Float(50 + i * 40)
            entity.addComponent(steering)

            // Tier 2 enemies fire via TurretComponent (tracked in updateTurrets)
            let turretComp = TurretComponent(trackingSpeed: 1.5)
            turretComp.fireInterval = 2.0
            turretComp.projectileSpeed = 250
            turretComp.damage = 5
            entity.addComponent(turretComp)

            registerEntity(entity)
            enemies.append(entity)
        }
    }

    private func spawnCapitalShip(wave: WaveDefinition) {
        let hull = GKEntity()
        hull.addComponent(TransformComponent(position: SIMD2(0, wave.spawnY + 100)))
        hull.addComponent(RenderComponent(
            size: GameConfig.Enemy.tier3HullSize,
            color: GameConfig.Palette.capitalShipHull
        ))
        let hullPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        hullPhysics.velocity = SIMD2(0, -GameConfig.Background.starScrollSpeed * GameConfig.Enemy.tier3ScrollMultiplier)
        hull.addComponent(hullPhysics)
        registerEntity(hull)
        capitalShipHulls.append(hull)

        let turretOffsets: [SIMD2<Float>] = [
            SIMD2(-80, 30), SIMD2(80, 30),
            SIMD2(-40, -20), SIMD2(40, -20)
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
                collisionSize: GameConfig.Enemy.tier3TurretSize,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            turretPhysics.velocity = SIMD2(0, -GameConfig.Background.starScrollSpeed * GameConfig.Enemy.tier3ScrollMultiplier)
            turret.addComponent(turretPhysics)

            turret.addComponent(RenderComponent(
                size: GameConfig.Enemy.tier3TurretSize,
                color: GameConfig.Palette.hostileProjectile
            ))

            turret.addComponent(HealthComponent(health: GameConfig.Enemy.tier3TurretHP))
            turret.addComponent(ScoreComponent(points: GameConfig.Score.tier3Turret))

            let turretComp = TurretComponent(trackingSpeed: 1.5)
            turretComp.parentEntity = hull
            turretComp.mountOffset = offset
            turret.addComponent(turretComp)

            registerEntity(turret)
            enemies.append(turret)
            turretMembers.append(turret)
        }

        formationEnemies[formationID] = turretMembers
    }

    private func spawnBoss() {
        let boss = GKEntity()

        boss.addComponent(TransformComponent(position: SIMD2(0, 250)))
        let physics = PhysicsComponent(
            collisionSize: GameConfig.Enemy.bossSize,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        boss.addComponent(physics)

        boss.addComponent(RenderComponent(
            size: GameConfig.Enemy.bossSize,
            color: GameConfig.Palette.bossCore
        ))

        boss.addComponent(HealthComponent(health: GameConfig.Enemy.bossHP))
        boss.addComponent(BossPhaseComponent(totalHP: GameConfig.Enemy.bossHP))
        boss.addComponent(ScoreComponent(points: GameConfig.Score.boss))

        registerEntity(boss)
        bossSystem.register(boss)
        enemies.append(boss)
        bossEntity = boss

        for i in 0..<2 {
            let shield = GKEntity()
            let angle = Float(i) * .pi
            shield.addComponent(TransformComponent(
                position: SIMD2(cos(angle) * 60, 250 + sin(angle) * 60)
            ))
            shield.addComponent(RenderComponent(
                size: SIMD2(40, 12),
                color: GameConfig.Palette.bossShield
            ))
            let shieldPhysics = PhysicsComponent(
                collisionSize: SIMD2(40, 12),
                layer: .bossShield,
                mask: [.playerProjectile]
            )
            shield.addComponent(shieldPhysics)

            registerEntity(shield)
            bossSystem.registerShield(shield)
            shieldEntities.append(shield)
        }
    }

    private func spawnPlayerProjectile(_ request: ProjectileSpawnRequest) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: request.position))

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Player.projectileSize,
            layer: .playerProjectile,
            mask: [.enemy, .bossShield, .item]
        )
        physics.velocity = request.velocity
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: GameConfig.Player.projectileSize,
            color: SIMD4(1, 1, 1, 1)
        ))

        registerEntity(entity)
        projectiles.append(entity)
    }

    private func spawnEnemyProjectile(position: SIMD2<Float>, velocity: SIMD2<Float>, damage: Float) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: SIMD2(8, 8),
            layer: .enemyProjectile,
            mask: [.player]
        )
        physics.velocity = velocity
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: SIMD2(8, 8),
            color: GameConfig.Palette.hostileProjectile
        ))

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

        entity.addComponent(RenderComponent(
            size: SIMD2(16, 16),
            color: GameConfig.Palette.gravBomb
        ))

        registerEntity(entity)
        gravBombEntities.append(entity)
        gravBombTimers[ObjectIdentifier(entity)] = 0
    }

    private func spawnItem(at position: SIMD2<Float>) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Item.size,
            layer: .item,
            mask: [.player, .playerProjectile]
        )
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: GameConfig.Item.size,
            color: GameConfig.Palette.item
        ))

        entity.addComponent(ItemComponent())

        registerEntity(entity)
        items.append(entity)
    }

    // MARK: - Updates

    private func updateTurrets(deltaTime: Double) {
        for enemy in enemies {
            guard let turret = enemy.component(ofType: TurretComponent.self),
                  let transform = enemy.component(ofType: TransformComponent.self) else { continue }

            // Follow parent hull position (if has parent)
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

    private func updateCapitalShipHulls() {
        for hull in capitalShipHulls {
            if let transform = hull.component(ofType: TransformComponent.self),
               transform.position.y < -GameConfig.designHeight / 2 - GameConfig.Enemy.tier3HullSize.y {
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

        // Visual blast ring (removed next frame)
        let blast = GKEntity()
        blast.addComponent(TransformComponent(position: center))
        blast.addComponent(RenderComponent(
            size: SIMD2(radius * 2, radius * 2),
            color: GameConfig.Palette.gravBombBlast
        ))
        let blastPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        blast.addComponent(blastPhysics)
        registerEntity(blast)
        pendingRemovals.append(blast)
    }

    // MARK: - Collisions

    private func processCollisions() {
        for (entityA, entityB) in collisionSystem.collisionPairs {
            let layerA = entityA.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []
            let layerB = entityB.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []

            if layerA.contains(.playerProjectile) && layerB.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityA, enemy: entityB)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityB, enemy: entityA)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.bossShield) {
                pendingRemovals.append(entityA)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.bossShield) {
                pendingRemovals.append(entityB)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.item) {
                itemSystem.handleProjectileHit(on: entityB)
                pendingRemovals.append(entityA)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.item) {
                itemSystem.handleProjectileHit(on: entityA)
                pendingRemovals.append(entityB)
            } else if layerA.contains(.player) && layerB.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityB)
            } else if layerB.contains(.player) && layerA.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityA)
            } else if layerA.contains(.player) && layerB.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityB)
            } else if layerB.contains(.player) && layerA.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityA)
            } else if layerA.contains(.player) && layerB.contains(.item) {
                handlePlayerCollectsItem(item: entityB)
            } else if layerB.contains(.player) && layerA.contains(.item) {
                handlePlayerCollectsItem(item: entityA)
            }
        }
    }

    private func handleProjectileHitEnemy(projectile: GKEntity, enemy: GKEntity) {
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(GameConfig.Player.damage)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    scoreSystem.addScore(score.points)
                }
                pendingRemovals.append(enemy)
                checkFormationWipe(enemy: enemy)
            }
        }
        pendingRemovals.append(projectile)
    }

    private func handlePlayerEnemyCollision(enemy: GKEntity) {
        player.component(ofType: HealthComponent.self)?.takeDamage(GameConfig.Player.collisionDamage)
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(health.currentHealth)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    scoreSystem.addScore(score.points)
                }
                pendingRemovals.append(enemy)
            }
        }
    }

    private func handlePlayerHitByProjectile(projectile: GKEntity) {
        player.component(ofType: HealthComponent.self)?.takeDamage(5)
        pendingRemovals.append(projectile)
    }

    private func handlePlayerCollectsItem(item: GKEntity) {
        guard let itemComp = item.component(ofType: ItemComponent.self) else { return }

        switch itemComp.itemType {
        case .energyCell:
            if let health = player.component(ofType: HealthComponent.self) {
                health.currentHealth = min(health.maxHealth, health.currentHealth + GameConfig.Item.energyRestoreAmount)
            }
        case .weaponModule:
            if let weapon = player.component(ofType: WeaponComponent.self) {
                weapon.weaponType = weapon.weaponType == .doubleCannon ? .triSpread : .doubleCannon
                weapon.damage = weapon.weaponType == .triSpread ? GameConfig.Weapon.triSpreadDamage : GameConfig.Player.damage
            }
        }

        pendingRemovals.append(item)
    }

    private func checkFormationWipe(enemy: GKEntity) {
        for (id, members) in formationEnemies {
            if members.contains(where: { $0 === enemy }) {
                let alive = members.filter { member in
                    guard let health = member.component(ofType: HealthComponent.self) else { return false }
                    return health.isAlive && !pendingRemovals.contains(where: { $0 === member })
                }
                if alive.isEmpty {
                    if let transform = enemy.component(ofType: TransformComponent.self) {
                        spawnItem(at: transform.position)
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
        let minX = -GameConfig.designWidth / 2 - margin
        let maxX = GameConfig.designWidth / 2 + margin

        for entity in (enemies + projectiles + enemyProjectiles) {
            guard let transform = entity.component(ofType: TransformComponent.self) else { continue }
            if transform.position.y < minY || transform.position.y > maxY ||
               transform.position.x < minX || transform.position.x > maxX {
                pendingRemovals.append(entity)
            }
        }
    }

    // MARK: - HUD

    private func appendHUD(to sprites: inout [SpriteInstance]) {
        let topY: Float = GameConfig.designHeight / 2 - 20

        // Energy bar background
        sprites.append(SpriteInstance(
            position: SIMD2(-45, topY),
            size: SIMD2(120, 12),
            color: SIMD4(0.2, 0.2, 0.2, 0.8)
        ))

        // Energy bar fill
        let health = player.component(ofType: HealthComponent.self)
        let fraction = (health?.currentHealth ?? 0) / (health?.maxHealth ?? 100)
        let barWidth: Float = 116 * fraction
        let barOffset = (barWidth - 116) / 2
        sprites.append(SpriteInstance(
            position: SIMD2(-45 + barOffset, topY),
            size: SIMD2(max(barWidth, 0), 8),
            color: GameConfig.Palette.player
        ))

        // Score bar (visual indicator proportional to score)
        let scoreWidth = min(Float(scoreSystem.currentScore) / 10.0, 100.0)
        sprites.append(SpriteInstance(
            position: SIMD2(100, topY),
            size: SIMD2(max(scoreWidth, 0), 8),
            color: SIMD4(1, 1, 1, 0.8)
        ))

        // Grav-bomb charges
        let charges = player.component(ofType: WeaponComponent.self)?.secondaryCharges ?? 0
        for i in 0..<charges {
            sprites.append(SpriteInstance(
                position: SIMD2(140 - Float(i) * 14, -GameConfig.designHeight / 2 + 20),
                size: SIMD2(10, 10),
                color: GameConfig.Palette.gravBomb
            ))
        }

        // Weapon indicator
        let weaponType = player.component(ofType: WeaponComponent.self)?.weaponType ?? .doubleCannon
        let weaponColor: SIMD4<Float> = weaponType == .triSpread ? GameConfig.Palette.weaponModule : SIMD4(1, 1, 1, 0.5)
        sprites.append(SpriteInstance(
            position: SIMD2(0, -GameConfig.designHeight / 2 + 20),
            size: SIMD2(20, 6),
            color: weaponColor
        ))
    }

    private func appendGameOverOverlay(to sprites: inout [SpriteInstance]) {
        sprites.append(SpriteInstance(
            position: .zero,
            size: SIMD2(GameConfig.designWidth, GameConfig.designHeight),
            color: SIMD4(0, 0, 0, 0.6)
        ))
        sprites.append(SpriteInstance(
            position: SIMD2(0, 20),
            size: SIMD2(160, 30),
            color: SIMD4(0.8, 0.1, 0.1, 0.9)
        ))
    }

    private func appendVictoryOverlay(to sprites: inout [SpriteInstance]) {
        sprites.append(SpriteInstance(
            position: SIMD2(0, 20),
            size: SIMD2(160, 30),
            color: GameConfig.Palette.player
        ))
    }
}
