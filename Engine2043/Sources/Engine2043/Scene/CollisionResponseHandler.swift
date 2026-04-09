import GameplayKit
import simd

/// Protocol providing the game state that collision responses need to read/write.
@MainActor
protocol CollisionContext: AnyObject {
    var player: GKEntity! { get }
    var scoreSystem: ScoreSystem { get }
    var itemSystem: ItemSystem { get }
    var sfx: AudioEngine? { get }
    var pendingRemovals: [GKEntity] { get set }
    var enemiesDestroyed: Int { get set }
    /// Galaxy2Scene provides an AsteroidSystem; Galaxy1Scene returns nil via default extension.
    var asteroidSystem: AsteroidSystem? { get }

    func checkFormationWipe(enemy: GKEntity)
    func spawnShieldDrones()
    func handleBarrierPushOut(barrier: GKEntity)
}

extension CollisionContext {
    var asteroidSystem: AsteroidSystem? { nil }
    func handleBarrierPushOut(barrier: GKEntity) {}
}

/// Handles collision pair dispatch and response logic.
/// Extracted from Galaxy1Scene to enable isolated testing.
@MainActor
final class CollisionResponseHandler {
    weak var context: (any CollisionContext)?

    init(context: (any CollisionContext)? = nil) {
        self.context = context
    }

    func processCollisions(pairs: [(GKEntity, GKEntity)]) {
        guard let ctx = context else { return }

        for (entityA, entityB) in pairs {
            let layerA = entityA.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []
            let layerB = entityB.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []

            // NOTE: Phase Laser (hitscan) vs asteroid is handled by the scene's
            // processLaserHitscan method, not by collision pairs here.

            // Barrier branches — checked first since .barrier is its own layer,
            // distinct from enemy/asteroid. Barriers are never destroyed.
            if layerA.contains(.player) && layerB.contains(.barrier) {
                handlePlayerHitBarrier(barrier: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.barrier) {
                handlePlayerHitBarrier(barrier: entityA, ctx: ctx)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.barrier) {
                ctx.pendingRemovals.append(entityA)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.barrier) {
                ctx.pendingRemovals.append(entityB)

            // Asteroid branches — checked before enemy/projectile branches since
            // .asteroid is a distinct layer that does not overlap with .enemy.
            } else if layerA.contains(.playerProjectile) && layerB.contains(.asteroid) {
                handleProjectileHitAsteroid(projectile: entityA, asteroid: entityB, ctx: ctx)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.asteroid) {
                handleProjectileHitAsteroid(projectile: entityB, asteroid: entityA, ctx: ctx)
            } else if layerA.contains(.player) && layerB.contains(.asteroid) {
                handlePlayerHitAsteroid(asteroid: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.asteroid) {
                handlePlayerHitAsteroid(asteroid: entityA, ctx: ctx)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityA, enemy: entityB, ctx: ctx)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityB, enemy: entityA, ctx: ctx)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.bossShield) {
                ctx.pendingRemovals.append(entityA)
                ctx.sfx?.play(.bossShieldDeflect)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.bossShield) {
                ctx.pendingRemovals.append(entityB)
                ctx.sfx?.play(.bossShieldDeflect)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.item) {
                ctx.itemSystem.handleProjectileHit(on: entityB)
                ctx.sfx?.play(.itemCycle)
                ctx.pendingRemovals.append(entityA)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.item) {
                ctx.itemSystem.handleProjectileHit(on: entityA)
                ctx.sfx?.play(.itemCycle)
                ctx.pendingRemovals.append(entityB)
            } else if layerA.contains(.player) && layerB.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityA, ctx: ctx)
            } else if layerA.contains(.shieldDrone) && layerB.contains(.enemyProjectile) {
                if let drone = entityA.component(ofType: ShieldDroneComponent.self) {
                    drone.takeHit()
                    ctx.sfx?.play(.bossShieldDeflect)
                    ctx.pendingRemovals.append(entityB)
                }
            } else if layerB.contains(.shieldDrone) && layerA.contains(.enemyProjectile) {
                if let drone = entityB.component(ofType: ShieldDroneComponent.self) {
                    drone.takeHit()
                    ctx.sfx?.play(.bossShieldDeflect)
                    ctx.pendingRemovals.append(entityA)
                }
            } else if layerA.contains(.player) && layerB.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityA, ctx: ctx)
            } else if layerA.contains(.player) && layerB.contains(.item) {
                handlePlayerCollectsItem(item: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.item) {
                handlePlayerCollectsItem(item: entityA, ctx: ctx)
            }
        }
    }

    private func handleProjectileHitAsteroid(projectile: GKEntity, asteroid: GKEntity, ctx: any CollisionContext) {
        // Small (destructible) asteroids have a HealthComponent; large ones do not.
        if let health = asteroid.component(ofType: HealthComponent.self) {
            health.takeDamage(GameConfig.Player.damage)
            if !health.isAlive {
                ctx.sfx?.play(.asteroidDestroyed)
                if let score = asteroid.component(ofType: ScoreComponent.self) {
                    ctx.scoreSystem.addScore(score.points)
                }
                ctx.pendingRemovals.append(asteroid)
            } else {
                ctx.sfx?.play(.asteroidHit)
            }
        }
        // Always remove the projectile — asteroids block player projectiles regardless of size.
        ctx.pendingRemovals.append(projectile)
    }

    private func handlePlayerHitAsteroid(asteroid: GKEntity, ctx: any CollisionContext) {
        // Player takes kinetic damage. Asteroid is NOT destroyed — player bounces off.
        ctx.player.component(ofType: HealthComponent.self)?.takeDamage(GameConfig.Galaxy2.Asteroid.collisionDamage)
        ctx.sfx?.play(.playerDamaged)
    }

    /// Half-arc that an armor slot covers on each side of its angle (±30°).
    static let armorSlotHalfArc: Float = .pi / 6  // 30°

    /// Returns the index of the armor slot (if any) that covers the given approach angle.
    private func armorSlotCovering(angle: Float, armor: BossArmorComponent) -> Int? {
        for (i, slot) in armor.slots.enumerated() where slot.isActive {
            var diff = angle - slot.angle
            // Normalize to [-π, π]
            while diff > .pi  { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            if abs(diff) <= Self.armorSlotHalfArc {
                return i
            }
        }
        return nil
    }

    private func handleProjectileHitEnemy(projectile: GKEntity, enemy: GKEntity, ctx: any CollisionContext) {
        // Boss armor interception: geometric angle-based check.
        // Compute approach angle from projectile to boss; only the armor slot
        // covering that angle can block the hit.
        if let armor = enemy.component(ofType: BossArmorComponent.self),
           let projPos = projectile.component(ofType: TransformComponent.self)?.position,
           let bossPos = enemy.component(ofType: TransformComponent.self)?.position {
            let approachAngle = atan2(bossPos.y - projPos.y, bossPos.x - projPos.x)
            if let idx = armorSlotCovering(angle: approachAngle, armor: armor),
               let armorEntity = armor.slots[idx].entity,
               let armorHealth = armorEntity.component(ofType: HealthComponent.self) {
                armorHealth.takeDamage(GameConfig.Player.damage)
                if !armorHealth.isAlive {
                    ctx.sfx?.play(.asteroidDestroyed)
                    armor.slots[idx].entity = nil
                    ctx.pendingRemovals.append(armorEntity)
                } else {
                    ctx.sfx?.play(.bossShieldDeflect) // armor deflects the projectile
                }
                ctx.pendingRemovals.append(projectile)
                return
            }
        }

        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(GameConfig.Player.damage)
            if !health.isAlive {
                ctx.sfx?.play(.enemyDestroyed)
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    ctx.scoreSystem.addScore(score.points)
                }
                ctx.enemiesDestroyed += 1
                ctx.pendingRemovals.append(enemy)
                ctx.checkFormationWipe(enemy: enemy)
            } else {
                ctx.sfx?.play(.enemyHit)
            }
        }
        ctx.pendingRemovals.append(projectile)
    }

    private func handlePlayerEnemyCollision(enemy: GKEntity, ctx: any CollisionContext) {
        ctx.player.component(ofType: HealthComponent.self)?.takeDamage(GameConfig.Player.collisionDamage)
        ctx.sfx?.play(.playerDamaged)
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(health.currentHealth)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    ctx.scoreSystem.addScore(score.points)
                }
                ctx.enemiesDestroyed += 1
                ctx.pendingRemovals.append(enemy)
            }
        }
    }

    private func handlePlayerHitByProjectile(projectile: GKEntity, ctx: any CollisionContext) {
        if let projComp = projectile.component(ofType: ProjectileComponent.self) {
            ctx.player.component(ofType: HealthComponent.self)?.takeDamage(projComp.damage)
            if projComp.effects.contains(.empDisable),
               let weapon = ctx.player.component(ofType: WeaponComponent.self) {
                weapon.secondaryDisabled = true
                weapon.secondaryDisableTimer = GameConfig.Galaxy3.BossAttack.empDisableDuration
            }
        } else {
            // Legacy fallback: Galaxy 1 and Galaxy 2 projectiles lack ProjectileComponent
            ctx.player.component(ofType: HealthComponent.self)?.takeDamage(5)
        }
        ctx.sfx?.play(.playerDamaged)
        ctx.pendingRemovals.append(projectile)
    }

    private func handlePlayerHitBarrier(barrier: GKEntity, ctx: any CollisionContext) {
        let damage = barrier.component(ofType: BarrierComponent.self)?.contactDamage
            ?? GameConfig.Galaxy3.Barrier.collisionDamage
        ctx.player.component(ofType: HealthComponent.self)?.takeDamage(damage)
        ctx.sfx?.play(.playerDamaged)
        ctx.handleBarrierPushOut(barrier: barrier)
    }

    private func handlePlayerCollectsItem(item: GKEntity, ctx: any CollisionContext) {
        ctx.sfx?.play(.itemPickup)
        guard let itemComp = item.component(ofType: ItemComponent.self) else { return }

        if itemComp.isWeaponModule {
            if let weapon = ctx.player.component(ofType: WeaponComponent.self) {
                weapon.weaponType = itemComp.displayedWeapon
                weapon.laserHeat = 0
                weapon.isLaserOverheated = false
                weapon.laserOverheatTimer = 0
                switch weapon.weaponType {
                case .doubleCannon:
                    weapon.damage = GameConfig.Player.damage
                case .lightningArc:
                    weapon.damage = GameConfig.Weapon.lightningArcDamagePerTick
                case .triSpread:
                    weapon.damage = GameConfig.Weapon.triSpreadDamage
                case .phaseLaser:
                    weapon.damage = GameConfig.Weapon.laserDamagePerTick
                }
            }
        } else {
            switch itemComp.utilityItemType {
            case .energyCell:
                if let health = ctx.player.component(ofType: HealthComponent.self) {
                    health.currentHealth = min(health.maxHealth, health.currentHealth + GameConfig.Item.energyRestoreAmount)
                }
            case .chargeCell:
                if let weapon = ctx.player.component(ofType: WeaponComponent.self) {
                    weapon.secondaryCharges = min(GameConfig.Weapon.gravBombMaxCharges, weapon.secondaryCharges + GameConfig.Item.chargeRestoreAmount)
                }
            case .orbitingShield:
                ctx.spawnShieldDrones()
            }
        }

        ctx.pendingRemovals.append(item)
    }
}
