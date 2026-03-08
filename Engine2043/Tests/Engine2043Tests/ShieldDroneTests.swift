import Testing
import GameplayKit
import simd
@testable import Engine2043

struct ShieldDroneTests {
    @Test func shieldDroneComponentDefaults() {
        let comp = ShieldDroneComponent()
        #expect(comp.hitsRemaining == GameConfig.ShieldDrone.hitsPerDrone)
        #expect(comp.orbitRadius == GameConfig.ShieldDrone.orbitRadius)
        #expect(comp.orbitSpeed == GameConfig.ShieldDrone.orbitSpeed)
    }

    @Test func shieldDroneComponentTakeHit() {
        let comp = ShieldDroneComponent()
        comp.takeHit()
        #expect(comp.hitsRemaining == GameConfig.ShieldDrone.hitsPerDrone - 1)
        #expect(!comp.isDestroyed)
    }

    @Test func shieldDroneComponentDestroyedAfterMaxHits() {
        let comp = ShieldDroneComponent()
        for _ in 0..<GameConfig.ShieldDrone.hitsPerDrone {
            comp.takeHit()
        }
        #expect(comp.isDestroyed)
    }

    @Test @MainActor func shieldDroneSystemUpdatesPosition() {
        let system = ShieldDroneSystem()

        let playerEntity = GKEntity()
        playerEntity.addComponent(TransformComponent(position: SIMD2(100, 200)))

        let drone = GKEntity()
        drone.addComponent(TransformComponent(position: .zero))
        drone.addComponent(RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: SIMD4(1, 1, 1, 1)))
        let droneComp = ShieldDroneComponent()
        droneComp.ownerEntity = playerEntity
        droneComp.orbitAngle = 0
        drone.addComponent(droneComp)

        system.register(drone)
        system.update(deltaTime: 0)

        let pos = drone.component(ofType: TransformComponent.self)!.position
        // At angle 0, drone should be at player.x + radius, player.y
        let expectedX = Float(100) + GameConfig.ShieldDrone.orbitRadius
        let expectedY = Float(200)
        #expect(abs(pos.x - expectedX) < 0.1)
        #expect(abs(pos.y - expectedY) < 0.1)
    }

    @Test @MainActor func shieldDroneSystemAdvancesAngle() {
        let system = ShieldDroneSystem()

        let playerEntity = GKEntity()
        playerEntity.addComponent(TransformComponent(position: SIMD2(0, 0)))

        let drone = GKEntity()
        drone.addComponent(TransformComponent(position: .zero))
        drone.addComponent(RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: SIMD4(1, 1, 1, 1)))
        let droneComp = ShieldDroneComponent()
        droneComp.ownerEntity = playerEntity
        droneComp.orbitAngle = 0
        drone.addComponent(droneComp)

        system.register(drone)
        system.update(deltaTime: 1.0)

        #expect(droneComp.orbitAngle > 0)
    }

    @Test @MainActor func shieldDroneSystemMarksDestroyedForRemoval() {
        let system = ShieldDroneSystem()

        let playerEntity = GKEntity()
        playerEntity.addComponent(TransformComponent(position: .zero))

        let drone = GKEntity()
        drone.addComponent(TransformComponent(position: .zero))
        drone.addComponent(RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: SIMD4(1, 1, 1, 1)))
        let droneComp = ShieldDroneComponent()
        droneComp.ownerEntity = playerEntity
        for _ in 0..<GameConfig.ShieldDrone.hitsPerDrone {
            droneComp.takeHit()
        }
        drone.addComponent(droneComp)

        system.register(drone)
        system.update(deltaTime: 0)

        #expect(system.pendingRemovals.contains(where: { $0 === drone }))
    }
}
