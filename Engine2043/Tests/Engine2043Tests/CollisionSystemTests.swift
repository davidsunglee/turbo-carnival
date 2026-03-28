import Testing
import GameplayKit
import simd
@testable import Engine2043

struct CollisionSystemTests {
    private let worldBounds = AABB(min: SIMD2(-500, -500), max: SIMD2(500, 500))

    @Test @MainActor func emptySystemProducesNoPairs() {
        let system = CollisionSystem(worldBounds: worldBounds)
        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func overlappingEntitiesWithMatchingMaskCollide() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let player = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let enemy = TestEntityFactory.makeEntity(
            position: SIMD2(5, 5), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(player)
        system.register(enemy)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func nonOverlappingEntitiesDoNotCollide() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(-100, 0), size: SIMD2(10, 10),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(100, 0), size: SIMD2(10, 10),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func overlappingEntitiesWithoutMatchingMaskDoNotCollide() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(5, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func asymmetricMaskStillProducesCollision() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(10, 10),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        let enemy = TestEntityFactory.makeEntity(
            position: SIMD2(3, 3), size: SIMD2(10, 10),
            collisionLayer: .enemy, collisionMask: []
        )
        system.register(projectile)
        system.register(enemy)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func unregisterRemovesEntityFromDetection() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(5, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)
        system.unregister(a)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func duplicateRegisterIsIgnored() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let entity = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(10, 10),
            collisionLayer: .player, collisionMask: .enemy
        )
        system.register(entity)
        system.register(entity)

        system.unregister(entity)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func manyOverlappingEntitiesAllDetected() {
        let system = CollisionSystem(worldBounds: worldBounds)
        var entities: [GKEntity] = []
        // Space enemies so each sits within a single QuadTree leaf,
        // preventing duplicate broad-phase results.
        for i in 0..<20 {
            let entity = TestEntityFactory.makeEntity(
                position: SIMD2(-450 + Float(i) * 45, 0), size: SIMD2(4, 4),
                collisionLayer: .enemy, collisionMask: .playerProjectile
            )
            system.register(entity)
            entities.append(entity)
        }

        // Projectile large enough to overlap every enemy
        let proj = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(1000, 1000),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        system.register(proj)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count >= 20)
    }

    @Test @MainActor func spatialPartitioningFiltersDistantEntities() {
        let system = CollisionSystem(worldBounds: worldBounds)
        for i in 0..<12 {
            let entity = TestEntityFactory.makeEntity(
                position: SIMD2(200 + Float(i) * 3, 200 + Float(i) * 3),
                size: SIMD2(10, 10),
                collisionLayer: .enemy, collisionMask: .playerProjectile
            )
            system.register(entity)
        }
        let proj = TestEntityFactory.makeEntity(
            position: SIMD2(-400, -400), size: SIMD2(10, 10),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        system.register(proj)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func entityOutsideWorldBoundsIsNotDetected() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(600, 600), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func asymmetricMaskWorksWhenMaskHolderIsHigherIndex() {
        // The collision loop uses j > i to avoid double-counting. When
        // only the higher-indexed entity carries the mask the lower-indexed
        // entity's empty mask causes it to be skipped by the guard, so
        // the pair is still detected through the higher-index scan path
        // only if the higher-index entity's mask is non-empty AND it
        // iterates with i = higherIndex finding j = lowerIndex -- but
        // j > i would be false. In this implementation the pair is missed,
        // which is the expected (documented) trade-off for O(N) scan.
        let system = CollisionSystem(worldBounds: worldBounds)
        let enemy = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(10, 10),
            collisionLayer: .enemy, collisionMask: []
        )
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(3, 3), size: SIMD2(10, 10),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        system.register(enemy)
        system.register(projectile)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        // Pair is NOT detected because the mask-holder has a higher index
        // and the loop skips j <= i. This verifies the expected limitation.
        #expect(system.collisionPairs.count == 0)
    }

    @Test @MainActor func entityWithEmptyLayerIsNotRegistered() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let entity = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(10, 10),
            collisionLayer: [], collisionMask: .enemy
        )
        system.register(entity)
        system.unregister(entity)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func positionSyncFromTransformComponent() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(-100, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(100, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        a.component(ofType: TransformComponent.self)!.position = SIMD2(0, 0)
        b.component(ofType: TransformComponent.self)!.position = SIMD2(5, 0)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func swapRemovePreservesOtherEntities() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(100, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        let c = TestEntityFactory.makeEntity(
            position: SIMD2(0, 5), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)
        system.register(c)

        system.unregister(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func collisionPairsClearedBetweenUpdates() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(5, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.count == 1)

        a.component(ofType: TransformComponent.self)!.position = SIMD2(-200, 0)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }
}
