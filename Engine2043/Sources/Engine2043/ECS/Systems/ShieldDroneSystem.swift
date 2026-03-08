import GameplayKit
import simd
import Foundation

@MainActor
public final class ShieldDroneSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingRemovals: [GKEntity] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: ShieldDroneComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        pendingRemovals.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let drone = entity.component(ofType: ShieldDroneComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            if drone.isDestroyed {
                pendingRemovals.append(entity)
                continue
            }

            guard let owner = drone.ownerEntity,
                  let ownerTransform = owner.component(ofType: TransformComponent.self) else {
                pendingRemovals.append(entity)
                continue
            }

            drone.orbitAngle += Float(deltaTime) * drone.orbitSpeed
            transform.position = ownerTransform.position + SIMD2(
                cosf(drone.orbitAngle) * drone.orbitRadius,
                sinf(drone.orbitAngle) * drone.orbitRadius
            )
        }
    }

    public var droneCount: Int { entities.count }
}
