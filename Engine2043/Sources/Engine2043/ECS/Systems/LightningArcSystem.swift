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
    public private(set) var activeArcs: [ArcSegment] = []
    public private(set) var pendingDamage: [(entity: GKEntity, damage: Float)] = []

    private var tickAccumulator: Double = 0

    public init(player: GKEntity) {
        self.playerEntity = player
    }

    public func registerEnemy(_ entity: GKEntity) {
        enemies.append(entity)
    }

    public func unregisterEnemy(_ entity: GKEntity) {
        enemies.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        activeArcs.removeAll(keepingCapacity: true)
        pendingDamage.removeAll(keepingCapacity: true)

        guard let player = playerEntity,
              let weapon = player.component(ofType: WeaponComponent.self),
              weapon.weaponType == .lightningArc,
              weapon.isFiring,
              let playerTransform = player.component(ofType: TransformComponent.self) else {
            tickAccumulator = 0
            return
        }

        let playerPos = playerTransform.position
        let range = GameConfig.Weapon.lightningArcRange
        let chainRange = GameConfig.Weapon.lightningArcChainRange
        let maxChains = GameConfig.Weapon.lightningArcChainTargets
        let falloff = GameConfig.Weapon.lightningArcChainDamageFalloff
        let baseDamage = GameConfig.Weapon.lightningArcDamagePerTick

        // Find primary target: nearest enemy within range
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

        guard let primary = primaryTarget,
              let primaryTransform = primary.component(ofType: TransformComponent.self) else {
            tickAccumulator = 0
            return
        }

        // Build arc chain
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

        // Apply damage on tick interval
        tickAccumulator += deltaTime
        let tickInterval = 1.0 / GameConfig.Weapon.lightningArcTickRate
        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            for (i, target) in chainTargets.enumerated() {
                let multiplier = powf(falloff, Float(i))
                pendingDamage.append((entity: target, damage: baseDamage * multiplier))
            }
        }
    }
}
