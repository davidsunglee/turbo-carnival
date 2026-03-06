import Testing
import GameplayKit
@testable import Engine2043

struct ECSTests {
    @Test func aabbIntersection() {
        let a = AABB(center: SIMD2(0, 0), halfExtents: SIMD2(10, 10))
        let b = AABB(center: SIMD2(15, 0), halfExtents: SIMD2(10, 10))
        let c = AABB(center: SIMD2(25, 0), halfExtents: SIMD2(10, 10))

        #expect(a.intersects(b))
        #expect(b.intersects(a))
        #expect(!a.intersects(c))
    }

    @Test func collisionLayerMasking() {
        let player = CollisionLayer.player
        let enemy = CollisionLayer.enemy
        let mask: CollisionLayer = [.enemy, .enemyProjectile]

        #expect(!player.intersection(mask).isEmpty == false)
        #expect(!enemy.intersection(mask).isEmpty == true)
    }

    @Test func healthComponentDamageAndInvulnerability() {
        let health = HealthComponent(health: 100)

        health.takeDamage(10)
        #expect(health.currentHealth == 90)
        #expect(health.isInvulnerable)

        // Should not take damage while invulnerable
        health.takeDamage(10)
        #expect(health.currentHealth == 90)

        // Tick invulnerability timer
        health.updateInvulnerability(deltaTime: 0.6)
        #expect(!health.isInvulnerable)

        // Now takes damage again
        health.takeDamage(10)
        #expect(health.currentHealth == 80)
    }

    @Test @MainActor func physicsSystemUpdatePositions() {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let physics = PhysicsComponent()
        physics.velocity = SIMD2(60, 0)
        entity.addComponent(physics)

        let system = PhysicsSystem()
        system.register(entity)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)

        system.syncFromComponents()
        system.update(time: time)

        let pos = entity.component(ofType: TransformComponent.self)!.position
        #expect(abs(pos.x - 1.0) < 0.01) // 60 * 1/60 = 1.0
        #expect(abs(pos.y) < 0.01)
    }

    @Test @MainActor func renderSystemCollectsSprites() {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(10, 20)))
        entity.addComponent(RenderComponent(size: SIMD2(32, 32), color: GameConfig.Palette.player))

        let system = RenderSystem()
        system.register(entity)

        let sprites = system.collectSprites()
        #expect(sprites.count == 1)
        #expect(sprites[0].position.x == 10)
        #expect(sprites[0].position.y == 20)
    }

    @Test @MainActor func physicsSystemUnregister() {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: .zero))
        entity.addComponent(PhysicsComponent())

        let system = PhysicsSystem()
        system.register(entity)
        system.unregister(entity)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time) // should not crash
    }
}
