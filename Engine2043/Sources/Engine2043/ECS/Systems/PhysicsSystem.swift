import GameplayKit
import simd

@MainActor
public final class PhysicsSystem {
    private var entities: ContiguousArray<GKEntity> = []
    private var positions: ContiguousArray<SIMD2<Float>> = []
    private var velocities: ContiguousArray<SIMD2<Float>> = []
    private var entityIndices: [ObjectIdentifier: Int] = [:]

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: TransformComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil else { return }
        guard entityIndices[ObjectIdentifier(entity)] == nil else { return }

        let index = entities.count
        entityIndices[ObjectIdentifier(entity)] = index
        entities.append(entity)
        positions.append(entity.component(ofType: TransformComponent.self)!.position)
        velocities.append(entity.component(ofType: PhysicsComponent.self)!.velocity)
    }

    public func unregister(_ entity: GKEntity) {
        guard let index = entityIndices.removeValue(forKey: ObjectIdentifier(entity)) else { return }
        let lastIndex = entities.count - 1
        if index != lastIndex {
            entities[index] = entities[lastIndex]
            positions[index] = positions[lastIndex]
            velocities[index] = velocities[lastIndex]
            entityIndices[ObjectIdentifier(entities[index])] = index
        }
        entities.removeLast()
        positions.removeLast()
        velocities.removeLast()
    }

    public func syncFromComponents() {
        for i in entities.indices {
            if let transform = entities[i].component(ofType: TransformComponent.self) {
                positions[i] = transform.position
            }
            if let physics = entities[i].component(ofType: PhysicsComponent.self) {
                velocities[i] = physics.velocity
            }
        }
    }

    public func update(time: GameTime) {
        let dt = Float(time.fixedDeltaTime)
        for i in positions.indices {
            positions[i] += velocities[i] * dt
        }
        for i in entities.indices {
            entities[i].component(ofType: TransformComponent.self)?.position = positions[i]
        }
    }
}
