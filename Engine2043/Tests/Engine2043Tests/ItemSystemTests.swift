import Testing
import GameplayKit
import simd
@testable import Engine2043

struct ItemSystemTests {
    @Test @MainActor func itemSystemDriftsDown() {
        let system = ItemSystem()

        let entity = GKEntity()
        let transform = TransformComponent(position: SIMD2(0, 200))
        entity.addComponent(transform)
        let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [.playerProjectile, .player])
        entity.addComponent(physics)
        entity.addComponent(ItemComponent())
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)
        system.update(deltaTime: 1.0)

        #expect(physics.velocity.y == Float(-40))
    }

    @Test @MainActor func itemSystemBounces() {
        let system = ItemSystem()

        let entity = GKEntity()
        let halfW = GameConfig.designWidth / 2
        let transform = TransformComponent(position: SIMD2(halfW - 5, 200))
        entity.addComponent(transform)
        let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [.playerProjectile, .player])
        entity.addComponent(physics)
        let item = ItemComponent()
        item.bounceDirection = 1
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)
        system.update(deltaTime: 1.0 / 60.0)

        #expect(item.bounceDirection == Float(-1))
    }

    @Test @MainActor func itemSystemTracksDespawn() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [])
        entity.addComponent(physics)
        let item = ItemComponent()
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)

        for _ in 0..<500 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(system.pendingDespawns.contains(where: { $0 === entity }))
    }

    @Test @MainActor func itemSystemAdvancesCycleOnHit() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: []))
        let item = ItemComponent()
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)

        #expect(item.utilityItemType == .energyCell)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .chargeCell)
    }

    @Test @MainActor func itemSystemCyclesToOrbitingShield() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: []))
        let item = ItemComponent()
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)

        #expect(item.utilityItemType == .energyCell)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .chargeCell)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .orbitingShield)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .energyCell)
    }

    @Test @MainActor func itemSystemUpdatesSpriteIdPerType() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: []))
        let item = ItemComponent()
        entity.addComponent(item)
        let render = RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 1, 1))
        entity.addComponent(render)

        system.register(entity)

        // energyCell
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "energyDrop")

        // chargeCell
        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "chargeCell")

        // orbitingShield
        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "shieldDrop")
    }
}
