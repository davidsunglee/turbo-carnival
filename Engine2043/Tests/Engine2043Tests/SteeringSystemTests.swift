import Testing
import GameplayKit
import simd
@testable import Engine2043

struct SteeringSystemTests {
    @Test @MainActor func steeringSystemHoverStopsAtThreshold() {
        let system = SteeringSystem()

        let entity = GKEntity()
        let transform = TransformComponent(position: SIMD2(0, 300))
        entity.addComponent(transform)
        let physics = PhysicsComponent(collisionSize: SIMD2(32, 32), layer: .enemy, mask: [])
        physics.velocity = SIMD2(0, -GameConfig.Enemy.tier2Speed)
        entity.addComponent(physics)
        let steering = SteeringComponent(behavior: .hover)
        steering.hoverY = 100
        entity.addComponent(steering)

        system.register(entity)
        system.playerPosition = SIMD2(0, -250)

        // Simulate enough frames to reach hover Y
        for _ in 0..<600 {
            system.update(deltaTime: 1.0 / 60.0)
            transform.position += physics.velocity * Float(1.0 / 60.0)
        }

        #expect(steering.hasReachedHover == true)
        #expect(abs(physics.velocity.y) < GameConfig.Enemy.tier2Speed)
    }

    @Test @MainActor func steeringSystemStrafeBoundsAtCustomWidth() {
        let system = SteeringSystem()
        let customHalfWidth: Float = 500

        let entity = GKEntity()
        let transform = TransformComponent(position: SIMD2(customHalfWidth - 25, 100))
        entity.addComponent(transform)
        let physics = PhysicsComponent(collisionSize: SIMD2(32, 32), layer: .enemy, mask: [])
        entity.addComponent(physics)
        let steering = SteeringComponent(behavior: .strafe)
        steering.hasReachedHover = true
        steering.strafeDirection = 1
        entity.addComponent(steering)

        system.register(entity)
        system.playerPosition = SIMD2(0, -250)
        system.update(deltaTime: 1.0 / 60.0, viewportHalfWidth: customHalfWidth)

        // At x=475, past halfWidth-30=470, direction should flip to -1
        #expect(steering.strafeDirection == Float(-1))
    }

    @Test @MainActor func steeringSystemStrafeMovesHorizontally() {
        let system = SteeringSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 100)))
        let physics = PhysicsComponent(collisionSize: SIMD2(32, 32), layer: .enemy, mask: [])
        entity.addComponent(physics)
        let steering = SteeringComponent(behavior: .strafe)
        steering.hasReachedHover = true
        entity.addComponent(steering)

        system.register(entity)
        system.playerPosition = SIMD2(50, -250)

        system.update(deltaTime: 1.0 / 60.0)

        #expect(physics.velocity.x != 0)
    }
}
