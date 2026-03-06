import GameplayKit
import simd

public struct ProjectileSpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var damage: Float
}

@MainActor
public final class WeaponSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingSpawns: [ProjectileSpawnRequest] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: WeaponComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(time: GameTime) {
        pendingSpawns.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let weapon = entity.component(ofType: WeaponComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self),
                  weapon.isFiring else { continue }

            weapon.timeSinceLastShot += time.fixedDeltaTime
            let interval = 1.0 / weapon.fireRate

            if weapon.timeSinceLastShot >= interval {
                weapon.timeSinceLastShot -= interval
                pendingSpawns.append(ProjectileSpawnRequest(
                    position: transform.position,
                    velocity: SIMD2(0, weapon.projectileSpeed),
                    damage: weapon.damage
                ))
            }
        }
    }
}
