import GameplayKit
import simd

@MainActor
public final class PlaceholderScene: GameScene {

    // Systems
    private let physicsSystem = PhysicsSystem()
    private let collisionSystem: CollisionSystem
    private let renderSystem = RenderSystem()
    private let weaponSystem = WeaponSystem()

    // Input
    public var inputProvider: (any InputProvider)?

    // Entities
    private var player: GKEntity!
    private var enemies: [GKEntity] = []
    private var projectiles: [GKEntity] = []
    private var pendingRemovals: [GKEntity] = []

    // Spawn timing
    private var spawnTimer: Double = 0
    private let spawnInterval: Double = 2.0
    private let enemyFormationSize = 5

    // Player config
    private let playerSpeed: Float = 200
    private let playerSize = SIMD2<Float>(30, 30)

    // World bounds (slightly larger than design resolution for culling)
    private let worldBounds = AABB(
        min: SIMD2(-200, -340),
        max: SIMD2(200, 340)
    )

    public init() {
        collisionSystem = CollisionSystem(worldBounds: worldBounds)
        setupPlayer()
    }

    // MARK: - Setup

    private func setupPlayer() {
        player = GKEntity()

        let transform = TransformComponent(position: SIMD2(0, -250))
        player.addComponent(transform)

        let physics = PhysicsComponent(
            collisionSize: playerSize,
            layer: .player,
            mask: [.enemy, .enemyProjectile, .item]
        )
        player.addComponent(physics)

        player.addComponent(RenderComponent(
            size: playerSize,
            color: GameConfig.Palette.player
        ))

        player.addComponent(HealthComponent(health: 100))

        let weapon = WeaponComponent(fireRate: 8, damage: 1, projectileSpeed: 500)
        player.addComponent(weapon)

        registerEntity(player)
    }

    private func spawnEnemyFormation() {
        let spacing: Float = 50
        let startX = -Float(enemyFormationSize - 1) / 2 * spacing

        for i in 0..<enemyFormationSize {
            let entity = GKEntity()
            let xOffset = startX + Float(i) * spacing
            // V-formation: center enemies are higher
            let yOffset = abs(Float(i) - Float(enemyFormationSize - 1) / 2) * 20

            let transform = TransformComponent(
                position: SIMD2(xOffset, 340 + yOffset)
            )
            entity.addComponent(transform)

            let physics = PhysicsComponent(
                collisionSize: SIMD2(24, 24),
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            physics.velocity = SIMD2(0, -80)
            entity.addComponent(physics)

            entity.addComponent(RenderComponent(
                size: SIMD2(24, 24),
                color: GameConfig.Palette.enemy
            ))

            entity.addComponent(HealthComponent(health: 1))

            registerEntity(entity)
            enemies.append(entity)
        }
    }

    private func spawnProjectile(_ request: ProjectileSpawnRequest) {
        let entity = GKEntity()

        entity.addComponent(TransformComponent(position: request.position))

        let physics = PhysicsComponent(
            collisionSize: SIMD2(6, 12),
            layer: .playerProjectile,
            mask: [.enemy]
        )
        physics.velocity = request.velocity
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: SIMD2(6, 12),
            color: SIMD4(1, 1, 1, 1)
        ))

        registerEntity(entity)
        projectiles.append(entity)
    }

    // MARK: - Entity Management

    private func registerEntity(_ entity: GKEntity) {
        physicsSystem.register(entity)
        collisionSystem.register(entity)
        renderSystem.register(entity)
        weaponSystem.register(entity)
    }

    private func unregisterEntity(_ entity: GKEntity) {
        physicsSystem.unregister(entity)
        collisionSystem.unregister(entity)
        renderSystem.unregister(entity)
        weaponSystem.unregister(entity)
    }

    private func removeEntity(_ entity: GKEntity) {
        unregisterEntity(entity)
        enemies.removeAll { $0 === entity }
        projectiles.removeAll { $0 === entity }
    }

    // MARK: - GameScene Protocol

    public func fixedUpdate(time: GameTime) {
        handleInput()

        // Update order per plan: Input -> Physics -> Collision -> Weapons
        physicsSystem.syncFromComponents()
        physicsSystem.update(time: time)
        collisionSystem.update(time: time)
        weaponSystem.update(time: time)

        // Spawn projectiles from weapon system
        for request in weaponSystem.pendingSpawns {
            spawnProjectile(request)
        }

        // Handle collisions
        processCollisions()

        // Handle invulnerability
        player.component(ofType: HealthComponent.self)?
            .updateInvulnerability(deltaTime: time.fixedDeltaTime)

        // Cull off-screen entities
        cullOffScreen()

        // Process pending removals
        for entity in pendingRemovals {
            removeEntity(entity)
        }
        pendingRemovals.removeAll()

        // Enemy spawning
        spawnTimer += time.fixedDeltaTime
        if spawnTimer >= spawnInterval {
            spawnTimer -= spawnInterval
            spawnEnemyFormation()
        }
    }

    public func update(time: GameTime) {
        // Flicker player during invulnerability
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
        var sprites = renderSystem.collectSprites()

        // HUD: energy bar background
        sprites.append(SpriteInstance(
            position: SIMD2(0, 300),
            size: SIMD2(200, 12),
            color: SIMD4(0.2, 0.2, 0.2, 0.8)
        ))

        // HUD: energy bar fill
        let health = player.component(ofType: HealthComponent.self)
        let fraction = (health?.currentHealth ?? 0) / (health?.maxHealth ?? 100)
        let barWidth: Float = 196 * fraction
        let barOffset = (barWidth - 196) / 2

        sprites.append(SpriteInstance(
            position: SIMD2(barOffset, 300),
            size: SIMD2(barWidth, 8),
            color: GameConfig.Palette.player
        ))

        return sprites
    }

    // MARK: - Logic

    private func handleInput() {
        guard let input = inputProvider?.poll() else { return }

        if let physics = player.component(ofType: PhysicsComponent.self) {
            physics.velocity = input.movement * playerSpeed
        }

        if let weapon = player.component(ofType: WeaponComponent.self) {
            weapon.isFiring = input.primaryFire
        }

        // Clamp player to play area
        if let transform = player.component(ofType: TransformComponent.self) {
            let halfW = GameConfig.designWidth / 2 - playerSize.x / 2
            let halfH = GameConfig.designHeight / 2 - playerSize.y / 2
            transform.position.x = max(-halfW, min(halfW, transform.position.x))
            transform.position.y = max(-halfH, min(halfH, transform.position.y))
        }
    }

    private func processCollisions() {
        for (entityA, entityB) in collisionSystem.collisionPairs {
            let layerA = entityA.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []
            let layerB = entityB.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []

            if layerA.contains(.playerProjectile) && layerB.contains(.enemy) {
                handleProjectileHit(projectile: entityA, enemy: entityB)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.enemy) {
                handleProjectileHit(projectile: entityB, enemy: entityA)
            } else if layerA.contains(.player) && layerB.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityB)
            } else if layerB.contains(.player) && layerA.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityA)
            }
        }
    }

    private func handleProjectileHit(projectile: GKEntity, enemy: GKEntity) {
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(1)
            if !health.isAlive {
                pendingRemovals.append(enemy)
            }
        }
        pendingRemovals.append(projectile)
    }

    private func handlePlayerEnemyCollision(enemy: GKEntity) {
        player.component(ofType: HealthComponent.self)?.takeDamage(15)
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(health.currentHealth)
            if !health.isAlive {
                pendingRemovals.append(enemy)
            }
        }
    }

    private func cullOffScreen() {
        let margin: Float = 50
        let minY = -GameConfig.designHeight / 2 - margin
        let maxY = GameConfig.designHeight / 2 + margin

        for entity in (enemies + projectiles) {
            guard let transform = entity.component(ofType: TransformComponent.self) else { continue }
            if transform.position.y < minY || transform.position.y > maxY {
                pendingRemovals.append(entity)
            }
        }
    }
}
