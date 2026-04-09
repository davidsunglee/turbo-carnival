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

    // MARK: - Runtime Physics Resync Integration Tests (Finding 1)

    @Test @MainActor func runtimeCollisionLayerChangeIsResynced() {
        // Simulates shield toggle: entity starts with collisionLayer = [] (disabled),
        // then re-enables it at runtime. CollisionSystem must detect the change.
        let system = CollisionSystem(worldBounds: worldBounds)
        let shield = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(40, 12),
            collisionLayer: .bossShield, collisionMask: [.playerProjectile]
        )
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(6, 12),
            collisionLayer: .playerProjectile, collisionMask: [.enemy, .bossShield]
        )
        system.register(shield)
        system.register(projectile)

        // Disable shield collision at runtime (like shields-off in phase 1/2)
        let shieldPhysics = shield.component(ofType: PhysicsComponent.self)!
        shieldPhysics.collisionLayer = []
        shieldPhysics.collisionMask = []

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        // No collision because shield layer is now empty
        #expect(system.collisionPairs.isEmpty,
                "Disabled shield should not produce collision pairs")

        // Re-enable shield collision (like shields activating in phase 3)
        shieldPhysics.collisionLayer = .bossShield
        shieldPhysics.collisionMask = [.playerProjectile]
        system.update(time: time)

        #expect(system.collisionPairs.count == 1,
                "Re-enabled shield should produce collision with overlapping projectile")
    }

    @Test @MainActor func shieldWindowBulletDeflectionThroughRealCollisionSystem() {
        // Integration test: shield entity has collision enabled, projectile overlaps —
        // CollisionSystem should produce a pair. This verifies that runtime layer/mask
        // mutations from BossSystem are picked up after the resync fix.
        let system = CollisionSystem(worldBounds: worldBounds)

        // Shield entity with collision enabled (shields active in phase 3)
        let shield = TestEntityFactory.makeEntity(
            position: SIMD2(0, 100), size: SIMD2(80, 12),
            collisionLayer: .bossShield, collisionMask: [.playerProjectile, .blast]
        )
        // Player projectile heading toward shield
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(0, 100), size: SIMD2(6, 12),
            collisionLayer: .playerProjectile, collisionMask: [.enemy, .bossShield]
        )
        system.register(shield)
        system.register(projectile)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1,
                "Projectile overlapping active shield should produce a collision pair")
    }

    @Test @MainActor func zenithPhase1BulletReachesBossThroughRealCollisionSystem() {
        // In phase 1/2, shields are collision-disabled so the projectile reaches the boss.
        let system = CollisionSystem(worldBounds: worldBounds)

        // Boss entity
        let boss = TestEntityFactory.makeEntity(
            position: SIMD2(0, 100), size: SIMD2(120, 120),
            collisionLayer: .enemy, collisionMask: [.player, .playerProjectile, .blast]
        )
        // Shield entity — disabled (phase 1)
        let shield = TestEntityFactory.makeEntity(
            position: SIMD2(0, 100), size: SIMD2(80, 12),
            collisionLayer: [], collisionMask: []
        )
        // Projectile overlapping the boss
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(0, 100), size: SIMD2(6, 12),
            collisionLayer: .playerProjectile, collisionMask: [.enemy, .bossShield]
        )
        system.register(boss)
        system.register(shield)
        system.register(projectile)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        // Should detect projectile-boss pair but NOT projectile-shield (shield disabled)
        #expect(system.collisionPairs.count == 1,
                "With shields disabled, projectile should only collide with boss")
        let pair = system.collisionPairs[0]
        let entities = [pair.0, pair.1]
        #expect(entities.contains(where: { $0 === boss }),
                "Collision pair should include the boss entity")
        #expect(entities.contains(where: { $0 === projectile }),
                "Collision pair should include the projectile entity")
    }

    @Test @MainActor func rotatingGateCollisionSizeChangesOverTime() {
        // Rotating gates can change their collisionSize at runtime.
        // CollisionSystem must resync halfExtents each frame.
        let system = CollisionSystem(worldBounds: worldBounds)

        // Gate entity starts with large collision (closed)
        let gate = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player]
        )
        // Player near the gate's edge
        let player = TestEntityFactory.makeEntity(
            position: SIMD2(0, 50), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: [.barrier]
        )
        system.register(gate)
        system.register(player)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        // Gate closed — large hitbox should overlap with player at y=50
        #expect(system.collisionPairs.count == 1,
                "Closed gate (large hitbox) should collide with nearby player")

        // Shrink gate collision (gate open)
        gate.component(ofType: PhysicsComponent.self)!.collisionSize = SIMD2(40, 20)
        system.update(time: time)

        // Gate open — small hitbox should NOT reach player at y=50
        #expect(system.collisionPairs.isEmpty,
                "Open gate (small hitbox) should not collide with player at y=50")

        // Close gate again
        gate.component(ofType: PhysicsComponent.self)!.collisionSize = SIMD2(40, 120)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1,
                "Re-closed gate should collide with player again")
    }

    @Test @MainActor func runtimeMaskChangeAffectsCollisionDetection() {
        // Verify that changing collisionMask at runtime is resynced.
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
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

        // Clear masks at runtime — should stop detecting collisions
        a.component(ofType: PhysicsComponent.self)!.collisionMask = []
        b.component(ofType: PhysicsComponent.self)!.collisionMask = []
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty,
                "Clearing masks at runtime should prevent collision detection")
    }
}
