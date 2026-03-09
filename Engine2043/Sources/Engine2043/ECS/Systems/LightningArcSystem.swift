import GameplayKit

public struct ArcSegment: Sendable {
    public let from: SIMD2<Float>
    public let to: SIMD2<Float>
    public let damageMultiplier: Float
}

@MainActor
public final class LightningArcSystem {
    private weak var playerEntity: GKEntity?
    private var enemies: [GKEntity] = []
    private var items: [GKEntity] = []
    public private(set) var activeArcs: [ArcSegment] = []
    public private(set) var pendingDamage: [(entity: GKEntity, damage: Float)] = []
    public private(set) var pendingItemHits: [GKEntity] = []

    private var tickAccumulator: Double = 0

    // Ramp-up tracking
    private weak var currentPrimaryTarget: GKEntity?
    private var rampTimer: Double = 0

    // Per-item cooldown tracking (keyed by ObjectIdentifier)
    private var itemHitCooldowns: [ObjectIdentifier: Double] = [:]

    public init(player: GKEntity) {
        self.playerEntity = player
    }

    public func registerEnemy(_ entity: GKEntity) {
        enemies.append(entity)
    }

    public func unregisterEnemy(_ entity: GKEntity) {
        enemies.removeAll { $0 === entity }
    }

    public func registerItem(_ entity: GKEntity) {
        items.append(entity)
    }

    public func unregisterItem(_ entity: GKEntity) {
        items.removeAll { $0 === entity }
        itemHitCooldowns.removeValue(forKey: ObjectIdentifier(entity))
    }

    public func update(deltaTime: Double) {
        activeArcs.removeAll(keepingCapacity: true)
        pendingDamage.removeAll(keepingCapacity: true)
        pendingItemHits.removeAll(keepingCapacity: true)

        // Tick down item cooldowns
        let cooldownDuration = GameConfig.Weapon.lightningArcItemCycleCooldown
        for (key, remaining) in itemHitCooldowns {
            let updated = remaining - deltaTime
            if updated <= 0 {
                itemHitCooldowns.removeValue(forKey: key)
            } else {
                itemHitCooldowns[key] = updated
            }
        }

        guard let player = playerEntity,
              let weapon = player.component(ofType: WeaponComponent.self),
              weapon.weaponType == .lightningArc,
              weapon.isFiring,
              let playerTransform = player.component(ofType: TransformComponent.self) else {
            tickAccumulator = 0
            currentPrimaryTarget = nil
            rampTimer = 0
            return
        }

        let playerPos = playerTransform.position
        let range = GameConfig.Weapon.lightningArcRange
        let chainRange = GameConfig.Weapon.lightningArcChainRange
        let maxChains = GameConfig.Weapon.lightningArcChainTargets
        let falloff = GameConfig.Weapon.lightningArcChainDamageFalloff
        let baseDamage = GameConfig.Weapon.lightningArcDamagePerTick

        // Find primary target: nearest enemy or item within range
        var primaryTarget: GKEntity?
        var bestDist: Float = range
        for enemy in enemies {
            guard let health = enemy.component(ofType: HealthComponent.self),
                  health.isAlive,
                  let transform = enemy.component(ofType: TransformComponent.self) else { continue }
            let dist = simd_distance(playerPos, transform.position)
            if dist < bestDist {
                bestDist = dist
                primaryTarget = enemy
            }
        }
        for item in items {
            guard let transform = item.component(ofType: TransformComponent.self) else { continue }
            let dist = simd_distance(playerPos, transform.position)
            if dist < bestDist {
                bestDist = dist
                primaryTarget = item
            }
        }

        guard let primary = primaryTarget,
              let primaryTransform = primary.component(ofType: TransformComponent.self) else {
            tickAccumulator = 0
            currentPrimaryTarget = nil
            rampTimer = 0
            return
        }

        // Ramp-up: reset if primary target changed
        if primary !== currentPrimaryTarget {
            currentPrimaryTarget = primary
            rampTimer = 0
        }

        // Calculate ramp multiplier from current state before advancing timer
        let rampProgress = Float(rampTimer / GameConfig.Weapon.lightningArcRampDuration)
        let minRamp = GameConfig.Weapon.lightningArcMinRampMultiplier
        let rampMultiplier = minRamp + (1.0 - minRamp) * rampProgress

        rampTimer = min(rampTimer + deltaTime, GameConfig.Weapon.lightningArcRampDuration)

        // Build arc chain (enemies and items)
        var chainTargets: [GKEntity] = [primary]
        var lastPos = primaryTransform.position

        for _ in 0..<maxChains {
            var nextTarget: GKEntity?
            var nextDist: Float = chainRange
            for enemy in enemies {
                guard !chainTargets.contains(where: { $0 === enemy }),
                      let health = enemy.component(ofType: HealthComponent.self),
                      health.isAlive,
                      let transform = enemy.component(ofType: TransformComponent.self) else { continue }
                let dist = simd_distance(lastPos, transform.position)
                if dist < nextDist {
                    nextDist = dist
                    nextTarget = enemy
                }
            }
            for item in items {
                guard !chainTargets.contains(where: { $0 === item }),
                      let transform = item.component(ofType: TransformComponent.self) else { continue }
                let dist = simd_distance(lastPos, transform.position)
                if dist < nextDist {
                    nextDist = dist
                    nextTarget = item
                }
            }
            guard let next = nextTarget,
                  let nextTransform = next.component(ofType: TransformComponent.self) else { break }
            chainTargets.append(next)
            lastPos = nextTransform.position
        }

        // Build visual arc segments (always, for smooth visuals)
        var prevPos = playerPos
        for (i, target) in chainTargets.enumerated() {
            guard let transform = target.component(ofType: TransformComponent.self) else { continue }
            let multiplier = powf(falloff, Float(i))
            activeArcs.append(ArcSegment(from: prevPos, to: transform.position, damageMultiplier: multiplier))
            prevPos = transform.position
        }

        // Apply damage / item hits on tick interval
        tickAccumulator += deltaTime
        let tickInterval = 1.0 / GameConfig.Weapon.lightningArcTickRate
        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            for (i, target) in chainTargets.enumerated() {
                if target.component(ofType: ItemComponent.self) != nil {
                    // Item: cycle with cooldown
                    let id = ObjectIdentifier(target)
                    if itemHitCooldowns[id] == nil {
                        pendingItemHits.append(target)
                        itemHitCooldowns[id] = cooldownDuration
                    }
                } else {
                    // Enemy: apply damage
                    let chainFalloff = powf(falloff, Float(i))
                    pendingDamage.append((entity: target, damage: baseDamage * rampMultiplier * chainFalloff))
                }
            }
        }
    }
}
