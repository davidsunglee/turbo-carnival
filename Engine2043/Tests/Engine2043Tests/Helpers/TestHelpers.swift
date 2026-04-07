import Testing
import GameplayKit
import simd
@testable import Engine2043

// MARK: - Mock Input Providers

@MainActor
final class MockInputProvider: InputProvider {
    var movement: SIMD2<Float>
    var primary: Bool
    var secondary1: Bool = false
    var secondary2: Bool = false
    var secondary3: Bool = false
    var tapPos: SIMD2<Float>?

    init(movement: SIMD2<Float> = .zero, primary: Bool = false) {
        self.movement = movement
        self.primary = primary
    }

    func poll() -> PlayerInput {
        var input = PlayerInput()
        input.movement = movement
        input.primaryFire = primary
        input.secondaryFire1 = secondary1
        input.secondaryFire2 = secondary2
        input.secondaryFire3 = secondary3
        input.tapPosition = tapPos
        tapPos = nil
        return input
    }
}

@MainActor
final class MockAudioProvider: AudioProvider {
    var playedEffects: [String] = []
    var playedMusic: [String] = []
    var stopAllCount = 0

    func playEffect(_ name: String) { playedEffects.append(name) }
    func playMusic(_ name: String) { playedMusic.append(name) }
    func stopAll() { stopAllCount += 1 }
}

// MARK: - Entity Factories

@MainActor
enum TestEntityFactory {
    static func makeEntity(
        position: SIMD2<Float> = .zero,
        size: SIMD2<Float> = SIMD2(16, 16),
        collisionLayer: CollisionLayer = [],
        collisionMask: CollisionLayer = [],
        health: Float = 0,
        scorePoints: Int = 0
    ) -> GKEntity {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))
        let physics = PhysicsComponent()
        physics.collisionSize = size
        physics.collisionLayer = collisionLayer
        physics.collisionMask = collisionMask
        entity.addComponent(physics)
        if health > 0 {
            entity.addComponent(HealthComponent(health: health))
        }
        if scorePoints > 0 {
            entity.addComponent(ScoreComponent(points: scorePoints))
        }
        return entity
    }

    static func makePlayerEntity(position: SIMD2<Float> = .zero) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(20, 20),
            collisionLayer: .player,
            collisionMask: [.enemy, .enemyProjectile, .item],
            health: 100
        )
        entity.addComponent(WeaponComponent(
            fireRate: GameConfig.Player.fireRate,
            damage: GameConfig.Player.damage,
            projectileSpeed: 400
        ))
        return entity
    }

    static func makeEnemyEntity(
        position: SIMD2<Float> = .zero,
        health: Float = 10,
        scorePoints: Int = 100
    ) -> GKEntity {
        makeEntity(
            position: position,
            size: SIMD2(16, 16),
            collisionLayer: .enemy,
            collisionMask: [.player, .playerProjectile, .blast],
            health: health,
            scorePoints: scorePoints
        )
    }

    static func makeProjectileEntity(
        position: SIMD2<Float> = .zero,
        velocity: SIMD2<Float> = SIMD2(0, 300)
    ) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(4, 8),
            collisionLayer: .playerProjectile,
            collisionMask: [.enemy, .bossShield]
        )
        entity.component(ofType: PhysicsComponent.self)?.velocity = velocity
        return entity
    }

    static func makeItemEntity(
        position: SIMD2<Float> = .zero,
        isWeaponModule: Bool = false,
        utilityIndex: Int = 0
    ) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(12, 12),
            collisionLayer: .item,
            collisionMask: [.player, .playerProjectile]
        )
        let item = ItemComponent()
        item.isWeaponModule = isWeaponModule
        item.currentCycleIndex = utilityIndex
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: SIMD2(12, 12), color: SIMD4(1, 1, 1, 1)))
        return entity
    }

    static func makeShieldDroneEntity(position: SIMD2<Float> = .zero) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(10, 10),
            collisionLayer: .shieldDrone,
            collisionMask: .enemyProjectile
        )
        entity.addComponent(ShieldDroneComponent())
        return entity
    }

    static func makeEnemyProjectileEntity(position: SIMD2<Float> = .zero) -> GKEntity {
        makeEntity(
            position: position,
            size: SIMD2(4, 4),
            collisionLayer: .enemyProjectile,
            collisionMask: [.player, .shieldDrone]
        )
    }

    /// Makes an asteroid entity matching AsteroidSystem's layout.
    /// Small asteroids include HealthComponent + ScoreComponent; large ones do not.
    static func makeAsteroidEntity(
        size: AsteroidSize = .small,
        health: Float? = nil,
        position: SIMD2<Float> = .zero
    ) -> GKEntity {
        let collisionSize = size == .large
            ? GameConfig.Galaxy2.Asteroid.largeSize
            : GameConfig.Galaxy2.Asteroid.smallSize
        let actualHealth: Float
        if size == .small {
            actualHealth = health ?? GameConfig.Galaxy2.Asteroid.smallHP
        } else {
            actualHealth = 0  // large asteroids have no HealthComponent
        }
        let entity = makeEntity(
            position: position,
            size: collisionSize,
            collisionLayer: .asteroid,
            collisionMask: [.player, .playerProjectile],
            health: actualHealth,
            scorePoints: size == .small ? GameConfig.Galaxy2.Score.asteroidSmall : 0
        )
        entity.addComponent(AsteroidComponent(size: size))
        return entity
    }
}

// MARK: - GameTime Helpers

extension GameTime {
    /// Create a GameTime advanced by N fixed steps (advances only, does NOT consume).
    /// Use `runFrames` helpers in integration tests for proper advance+consume loops.
    @MainActor
    static func advancedWithoutConsuming(frames: Int) -> GameTime {
        var time = GameTime()
        for _ in 0..<frames {
            time.advance(by: GameConfig.fixedTimeStep)
        }
        return time
    }
}
