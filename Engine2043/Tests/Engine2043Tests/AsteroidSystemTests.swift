import Testing
import GameplayKit
import simd
@testable import Engine2043

struct AsteroidSystemTests {

    // MARK: - spawnField: count and components

    @Test @MainActor func spawnFieldReturnsCorrectCount() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 10, largeFraction: 0.0,
                                          spawnYBase: 700, viewportHalfWidth: 180)
        #expect(entities.count == 10)
    }

    @Test @MainActor func spawnFieldEntitiesHaveRequiredComponents() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 5, largeFraction: 0.0,
                                          spawnYBase: 700, viewportHalfWidth: 180)
        for entity in entities {
            #expect(entity.component(ofType: TransformComponent.self) != nil)
            #expect(entity.component(ofType: PhysicsComponent.self) != nil)
            #expect(entity.component(ofType: RenderComponent.self) != nil)
            #expect(entity.component(ofType: AsteroidComponent.self) != nil)
        }
    }

    // MARK: - Large fraction

    @Test @MainActor func spawnFieldRoughlyRespectLargeFraction() {
        let system = AsteroidSystem()
        let total = 100
        let entities = system.spawnField(count: total, largeFraction: 0.5,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        let largeCount = entities.filter {
            $0.component(ofType: AsteroidComponent.self)?.asteroidSize == .large
        }.count
        // expect roughly 50 ± 20
        #expect(largeCount >= 30 && largeCount <= 70)
    }

    @Test @MainActor func spawnFieldAllSmallWhenFractionZero() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 0.0,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            #expect(entity.component(ofType: AsteroidComponent.self)?.asteroidSize == .small)
        }
    }

    @Test @MainActor func spawnFieldAllLargeWhenFractionOne() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 1.0,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            #expect(entity.component(ofType: AsteroidComponent.self)?.asteroidSize == .large)
        }
    }

    // MARK: - Small asteroids have HealthComponent

    @Test @MainActor func smallAsteroidsHaveHealthComponent() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 0.0,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            let health = entity.component(ofType: HealthComponent.self)
            #expect(health != nil)
            #expect(health?.maxHealth == GameConfig.Galaxy2.Asteroid.smallHP)
        }
    }

    @Test @MainActor func smallAsteroidsHaveScoreComponent() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 0.0,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            let score = entity.component(ofType: ScoreComponent.self)
            #expect(score != nil)
            #expect(score?.points == GameConfig.Galaxy2.Score.asteroidSmall)
        }
    }

    // MARK: - Large asteroids have no HealthComponent

    @Test @MainActor func largeAsteroidsHaveNoHealthComponent() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 1.0,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            #expect(entity.component(ofType: HealthComponent.self) == nil)
        }
    }

    @Test @MainActor func largeAsteroidsHaveNoScoreComponent() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 1.0,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            #expect(entity.component(ofType: ScoreComponent.self) == nil)
        }
    }

    // MARK: - Collision layer

    @Test @MainActor func allSpawnedEntitiesHaveAsteroidCollisionLayer() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 20, largeFraction: 0.5,
                                          spawnYBase: 0, viewportHalfWidth: 180)
        for entity in entities {
            let physics = entity.component(ofType: PhysicsComponent.self)
            #expect(physics?.collisionLayer == .asteroid)
            #expect(physics?.collisionMask.contains(.player) == true)
            #expect(physics?.collisionMask.contains(.playerProjectile) == true)
        }
    }

    // MARK: - update: scrolls downward

    @Test @MainActor func updateScrollsAsteroidsDown() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 3, largeFraction: 0.0,
                                          spawnYBase: 300, viewportHalfWidth: 180)
        for entity in entities {
            system.register(entity)
        }

        let initialPositions = entities.map {
            $0.component(ofType: TransformComponent.self)!.position.y
        }

        let dt = 1.0 / 60.0
        system.update(deltaTime: dt)

        for (i, entity) in entities.enumerated() {
            let newY = entity.component(ofType: TransformComponent.self)!.position.y
            let expected = initialPositions[i] - GameConfig.Galaxy2.Asteroid.scrollSpeed * Float(dt)
            #expect(abs(newY - expected) < 0.001)
        }
    }

    // MARK: - update: off-screen removal

    @Test @MainActor func updateAddsOffScreenAsteroidsToPendingRemovals() {
        let system = AsteroidSystem()

        // Place asteroid already off-screen (well below the threshold)
        let entity = GKEntity()
        let halfSize = GameConfig.Galaxy2.Asteroid.smallSize.y / 2
        let transform = TransformComponent(position: SIMD2(0, -(halfSize + 10)))
        entity.addComponent(transform)
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Galaxy2.Asteroid.smallSize,
                                              layer: .asteroid, mask: [.player, .playerProjectile]))
        entity.addComponent(RenderComponent(size: GameConfig.Galaxy2.Asteroid.smallSize,
                                             color: SIMD4(1, 1, 1, 1)))
        entity.addComponent(AsteroidComponent(size: .small))
        entity.addComponent(HealthComponent(health: GameConfig.Galaxy2.Asteroid.smallHP))

        system.register(entity)
        system.update(deltaTime: 1.0 / 60.0)

        #expect(system.pendingRemovals.contains(where: { $0 === entity }))
    }

    @Test @MainActor func updateDoesNotAddOnScreenAsteroidsToPendingRemovals() {
        let system = AsteroidSystem()
        let entities = system.spawnField(count: 3, largeFraction: 0.0,
                                          spawnYBase: 300, viewportHalfWidth: 180)
        for entity in entities {
            system.register(entity)
        }

        system.update(deltaTime: 1.0 / 60.0)

        #expect(system.pendingRemovals.isEmpty)
    }

    // MARK: - spawnSparseLayer

    @Test @MainActor func spawnSparseLayerReturnsCorrectCount() {
        let system = AsteroidSystem()
        let entities = system.spawnSparseLayer(count: 8, viewportHalfWidth: 180, fieldHeight: 640)
        #expect(entities.count == 8)
    }

    @Test @MainActor func spawnSparseLayerEntitiesHaveRequiredComponents() {
        let system = AsteroidSystem()
        let entities = system.spawnSparseLayer(count: 5, viewportHalfWidth: 180, fieldHeight: 640)
        for entity in entities {
            #expect(entity.component(ofType: TransformComponent.self) != nil)
            #expect(entity.component(ofType: PhysicsComponent.self) != nil)
            #expect(entity.component(ofType: RenderComponent.self) != nil)
            #expect(entity.component(ofType: AsteroidComponent.self) != nil)
        }
    }

    @Test @MainActor func spawnSparseLayerEntitiesHaveAsteroidCollisionLayer() {
        let system = AsteroidSystem()
        let entities = system.spawnSparseLayer(count: 10, viewportHalfWidth: 180, fieldHeight: 640)
        for entity in entities {
            let physics = entity.component(ofType: PhysicsComponent.self)
            #expect(physics?.collisionLayer == .asteroid)
        }
    }

    // MARK: - AsteroidComponent properties

    @Test func asteroidComponentIsDestructibleForSmall() {
        let component = AsteroidComponent(size: .small)
        #expect(component.isDestructible == true)
    }

    @Test func asteroidComponentIsNotDestructibleForLarge() {
        let component = AsteroidComponent(size: .large)
        #expect(component.isDestructible == false)
    }
}
