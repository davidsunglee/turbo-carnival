import GameplayKit
import simd

public struct ProjectileSpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var damage: Float
}

public struct SecondarySpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
}

@MainActor
public final class WeaponSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingSpawns: [ProjectileSpawnRequest] = []
    public private(set) var pendingSecondarySpawns: [SecondarySpawnRequest] = []

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
        pendingSecondarySpawns.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let weapon = entity.component(ofType: WeaponComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            // Primary fire
            if weapon.isFiring {
                weapon.timeSinceLastShot += time.fixedDeltaTime
                let interval = 1.0 / weapon.fireRate

                if weapon.timeSinceLastShot >= interval {
                    weapon.timeSinceLastShot -= interval
                    spawnPrimaryProjectiles(weapon: weapon, position: transform.position)
                }
            }

            // Secondary fire cooldown always ticks
            weapon.secondaryCooldown += time.fixedDeltaTime

            // Secondary fire
            if weapon.isSecondaryFiring && weapon.secondaryCharges > 0 && weapon.secondaryCooldown >= 0.5 {
                weapon.secondaryCooldown = 0
                weapon.secondaryCharges -= 1
                weapon.isSecondaryFiring = false
                pendingSecondarySpawns.append(SecondarySpawnRequest(
                    position: transform.position,
                    velocity: SIMD2(0, 150)
                ))
            }
        }
    }

    private func spawnPrimaryProjectiles(weapon: WeaponComponent, position: SIMD2<Float>) {
        let direction: Float = weapon.firesDownward ? -1 : 1

        switch weapon.weaponType {
        case .doubleCannon:
            let offset: Float = 8
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position + SIMD2(-offset, 0),
                velocity: SIMD2(0, weapon.projectileSpeed * direction),
                damage: weapon.damage
            ))
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position + SIMD2(offset, 0),
                velocity: SIMD2(0, weapon.projectileSpeed * direction),
                damage: weapon.damage
            ))

        case .triSpread:
            let angle = GameConfig.Weapon.triSpreadAngle
            let speed = weapon.projectileSpeed
            let damage = GameConfig.Weapon.triSpreadDamage

            // Center
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(0, speed * direction),
                damage: damage
            ))
            // Left
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(-sin(angle) * speed, cos(angle) * speed * direction),
                damage: damage
            ))
            // Right
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(sin(angle) * speed, cos(angle) * speed * direction),
                damage: damage
            ))
        }
    }
}
