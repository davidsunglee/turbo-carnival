import GameplayKit
import simd

@MainActor
public final class SteeringSystem {
    private var entities: [GKEntity] = []
    public var playerPosition: SIMD2<Float> = .zero

    private var accumulatedTime: Double = 0

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: SteeringComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double, viewportHalfWidth: Float = GameConfig.designWidth / 2) {
        accumulatedTime += deltaTime
        let halfWidth = viewportHalfWidth

        for entity in entities {
            guard let steering = entity.component(ofType: SteeringComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            if !steering.hasReachedHover {
                physics.velocity.y = -GameConfig.Enemy.tier2Speed
                if transform.position.y <= steering.hoverY {
                    steering.hasReachedHover = true
                    physics.velocity.y = 0
                }
                continue
            }

            switch steering.behavior {
            case .hover:
                let dx = playerPosition.x - transform.position.x
                physics.velocity.x = sign(dx) * min(abs(dx) * steering.steerStrength, 80)
                physics.velocity.y = 0

            case .strafe:
                let strafeSpeed: Float = 100
                physics.velocity.x = steering.strafeDirection * strafeSpeed
                physics.velocity.y = 0

                if transform.position.x > halfWidth - 30 {
                    steering.strafeDirection = -1
                } else if transform.position.x < -halfWidth + 30 {
                    steering.strafeDirection = 1
                }

            case .leadShot:
                let dx = playerPosition.x - transform.position.x
                physics.velocity.x = dx * steering.steerStrength
                physics.velocity.y = sin(Float(accumulatedTime) * 2) * 20
            }
        }
    }
}
