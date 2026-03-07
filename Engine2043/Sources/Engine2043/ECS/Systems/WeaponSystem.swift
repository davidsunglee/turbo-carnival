import GameplayKit
import simd

public struct ProjectileSpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var damage: Float
}

public struct LaserHitscanRequest: Sendable {
    public var position: SIMD2<Float>
    public var width: Float
    public var damagePerTick: Float
}

public enum SecondarySpawnType: Sendable {
    case gravBomb
    case empSweep
    case overcharge
}

public struct SecondarySpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var type: SecondarySpawnType
}

@MainActor
public final class WeaponSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingSpawns: [ProjectileSpawnRequest] = []
    public private(set) var pendingSecondarySpawns: [SecondarySpawnRequest] = []
    public private(set) var pendingLaserHitscans: [LaserHitscanRequest] = []

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
        pendingLaserHitscans.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let weapon = entity.component(ofType: WeaponComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            // Overcharge timer
            if weapon.overchargeActive {
                weapon.overchargeTimer -= time.fixedDeltaTime
                if weapon.overchargeTimer <= 0 {
                    weapon.overchargeActive = false
                    weapon.overchargeTimer = 0
                }
            }

            // Phase Laser: continuous beam with heat
            if weapon.weaponType == .phaseLaser {
                if weapon.isLaserOverheated {
                    weapon.laserOverheatTimer -= time.fixedDeltaTime
                    if weapon.laserOverheatTimer <= 0 {
                        weapon.isLaserOverheated = false
                        weapon.laserHeat = 0
                    }
                } else if weapon.isFiring {
                    // Accumulate heat
                    weapon.laserHeat += GameConfig.Weapon.laserHeatPerSecond * time.fixedDeltaTime
                    weapon.timeSinceLastShot += time.fixedDeltaTime

                    // Fire damage ticks
                    let tickInterval = GameConfig.Weapon.laserTickInterval
                    if weapon.timeSinceLastShot >= tickInterval {
                        weapon.timeSinceLastShot -= tickInterval
                        pendingLaserHitscans.append(LaserHitscanRequest(
                            position: transform.position,
                            width: GameConfig.Weapon.laserWidth,
                            damagePerTick: GameConfig.Weapon.laserDamagePerTick
                        ))
                    }

                    // Check overheat
                    if weapon.laserHeat >= GameConfig.Weapon.laserMaxHeat {
                        weapon.isLaserOverheated = true
                        weapon.laserOverheatTimer = GameConfig.Weapon.laserOverheatCooldown
                    }
                } else {
                    // Cool down when not firing
                    weapon.laserHeat = max(0, weapon.laserHeat - GameConfig.Weapon.laserCoolPerSecond * time.fixedDeltaTime)
                    weapon.timeSinceLastShot = 0
                }
            } else if weapon.isFiring {
                // Standard projectile weapons
                weapon.timeSinceLastShot += time.fixedDeltaTime
                var effectiveFireRate = weapon.fireRate
                if weapon.weaponType == .vulcanAutoGun {
                    effectiveFireRate *= GameConfig.Weapon.vulcanFireRateMultiplier
                }
                if weapon.overchargeActive {
                    effectiveFireRate *= GameConfig.Weapon.overchargeFireRateMultiplier
                }
                let interval = 1.0 / effectiveFireRate

                if weapon.timeSinceLastShot >= interval {
                    weapon.timeSinceLastShot -= interval
                    spawnPrimaryProjectiles(weapon: weapon, position: transform.position)
                }
            }

            // Secondary fire cooldown always ticks
            weapon.secondaryCooldown += time.fixedDeltaTime

            // Secondary fire
            if let secondaryType = weapon.secondaryFiring,
               weapon.secondaryCharges > 0,
               weapon.secondaryCooldown >= 0.5 {
                weapon.secondaryCooldown = 0
                weapon.secondaryCharges -= 1
                weapon.secondaryFiring = nil

                switch secondaryType {
                case .gravBomb:
                    pendingSecondarySpawns.append(SecondarySpawnRequest(
                        position: transform.position,
                        velocity: SIMD2(0, 150),
                        type: .gravBomb
                    ))
                case .empSweep:
                    pendingSecondarySpawns.append(SecondarySpawnRequest(
                        position: transform.position,
                        velocity: .zero,
                        type: .empSweep
                    ))
                case .overcharge:
                    pendingSecondarySpawns.append(SecondarySpawnRequest(
                        position: transform.position,
                        velocity: .zero,
                        type: .overcharge
                    ))
                }
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

            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(0, speed * direction),
                damage: damage
            ))
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(-sin(angle) * speed, cos(angle) * speed * direction),
                damage: damage
            ))
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(sin(angle) * speed, cos(angle) * speed * direction),
                damage: damage
            ))

        case .vulcanAutoGun:
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(0, weapon.projectileSpeed * direction),
                damage: GameConfig.Weapon.vulcanDamage
            ))

        case .phaseLaser:
            break // Handled via hitscan, not projectiles
        }
    }
}
