import GameplayKit
import simd

public enum BossType: Sendable {
    case galaxy1
    case lithicHarvester
}

@MainActor
public final class BossSystem {
    private var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    public private(set) var pendingProjectileSpawns: [ProjectileSpawnRequest] = []
    public var playerPosition: SIMD2<Float> = .zero
    public var bossType: BossType = .galaxy1

    public private(set) var pendingTractorBeamPulls: [(source: SIMD2<Float>, target: GKEntity)] = []
    public private(set) var pendingArmorAttachments: [(slot: Int, entity: GKEntity)] = []

    private var attackTimer: Double = 0
    private let baseAttackInterval: Double = 1.0

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: BossPhaseComponent.self) != nil,
              entity.component(ofType: HealthComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        bossEntity = entity
    }

    public func registerShield(_ entity: GKEntity) {
        shieldEntities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        if entity === bossEntity { bossEntity = nil }
        shieldEntities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        pendingProjectileSpawns.removeAll(keepingCapacity: true)
        pendingTractorBeamPulls.removeAll(keepingCapacity: true)
        pendingArmorAttachments.removeAll(keepingCapacity: true)

        guard let boss = bossEntity,
              let bossPhase = boss.component(ofType: BossPhaseComponent.self),
              let health = boss.component(ofType: HealthComponent.self),
              let transform = boss.component(ofType: TransformComponent.self) else { return }

        let healthFraction = health.currentHealth / bossPhase.totalHP
        bossPhase.updatePhase(healthFraction: healthFraction)

        if !health.isAlive {
            bossPhase.isDefeated = true
            for shield in shieldEntities {
                shield.component(ofType: RenderComponent.self)?.isVisible = false
            }
            return
        }

        switch bossType {
        case .galaxy1:
            updateGalaxy1Boss(boss: boss, bossPhase: bossPhase, health: health, transform: transform, deltaTime: deltaTime)
        case .lithicHarvester:
            updateLithicHarvester(boss: boss, bossPhase: bossPhase, health: health, transform: transform, deltaTime: deltaTime)
        }
    }

    // MARK: - Galaxy 1 Boss (Orbital Bulwark Alpha)

    private func updateGalaxy1Boss(boss: GKEntity, bossPhase: BossPhaseComponent, health: HealthComponent, transform: TransformComponent, deltaTime: Double) {
        let speedMultiplier: Float = Float(bossPhase.currentPhase + 1)
        bossPhase.shieldRotation += bossPhase.shieldSpeed * speedMultiplier * Float(deltaTime)

        updateShieldPositions(bossPosition: transform.position, rotation: bossPhase.shieldRotation, phase: bossPhase.currentPhase)

        attackTimer += deltaTime
        let attackInterval = baseAttackInterval / Double(bossPhase.currentPhase + 1)

        if attackTimer >= attackInterval {
            attackTimer -= attackInterval
            generateGalaxy1Attack(from: transform.position, phase: bossPhase.currentPhase, rotation: bossPhase.shieldRotation)
        }
    }

    private func updateShieldPositions(bossPosition: SIMD2<Float>, rotation: Float, phase: Int) {
        if phase >= 2 {
            for shield in shieldEntities {
                shield.component(ofType: RenderComponent.self)?.isVisible = false
            }
            return
        }

        let shieldDistance: Float = 60
        for (i, shield) in shieldEntities.enumerated() {
            guard let transform = shield.component(ofType: TransformComponent.self),
                  let render = shield.component(ofType: RenderComponent.self) else { continue }
            let angle = rotation + Float(i) * .pi
            transform.position = bossPosition + SIMD2(cos(angle), sin(angle)) * shieldDistance
            transform.rotation = angle
            render.isVisible = true
        }
    }

    private func generateGalaxy1Attack(from position: SIMD2<Float>, phase: Int, rotation: Float) {
        let speed: Float = 200

        switch phase {
        case 0:
            let count = 8
            for i in 0..<count {
                let angle = Float(i) / Float(count) * .pi * 2 + rotation * 0.1
                let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

        case 1:
            let dir = playerPosition == position ? SIMD2<Float>(0, -1) : simd_normalize(playerPosition - position)
            let spread: Float = 0.2
            for i in -1...1 {
                let offset = Float(i) * spread
                let vel = SIMD2(dir.x + offset, dir.y) * speed * 1.5
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

        default:
            let count = 12
            for i in 0..<count {
                let angle = Float(i) / Float(count) * .pi * 2
                let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed * 1.3
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }
            let dir = playerPosition == position ? SIMD2<Float>(0, -1) : simd_normalize(playerPosition - position)
            pendingProjectileSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: dir * speed * 2,
                damage: 8
            ))
        }
    }

    // MARK: - Lithic Harvester Boss

    private func updateLithicHarvester(boss: GKEntity, bossPhase: BossPhaseComponent, health: HealthComponent, transform: TransformComponent, deltaTime: Double) {
        let phase = bossPhase.currentPhase

        // Determine fire interval based on phase
        let fireInterval: Double
        switch phase {
        case 0: fireInterval = 2.0
        case 1: fireInterval = 1.5
        default: fireInterval = 1.0
        }

        attackTimer += deltaTime

        if attackTimer >= fireInterval {
            attackTimer -= fireInterval
            generateLithicHarvesterAttack(from: transform.position, phase: phase)
        }

        // Tractor beam logic
        if let armor = boss.component(ofType: BossArmorComponent.self) {
            // Update tractor beam interval based on phase
            switch phase {
            case 0: armor.tractorBeamInterval = 8.0
            case 1: armor.tractorBeamInterval = 5.0
            default: armor.tractorBeamInterval = 3.0
            }

            armor.tractorBeamTimer += deltaTime

            if armor.tractorBeamTimer >= armor.tractorBeamInterval {
                armor.tractorBeamTimer -= armor.tractorBeamInterval

                // Check for empty slots
                let hasEmptySlot = armor.slots.contains { !$0.isActive }
                if hasEmptySlot {
                    // Signal the scene to start pulling nearby asteroids
                    // The scene will handle finding actual asteroid targets
                    for target in armor.tractorBeamTargets {
                        pendingTractorBeamPulls.append((source: transform.position, target: target))
                    }
                }
            }

            // Update armor slot positions around boss
            let bossPos = transform.position
            for i in 0..<armor.slots.count {
                if let armorEntity = armor.slots[i].entity,
                   let armorTransform = armorEntity.component(ofType: TransformComponent.self) {
                    let angle = armor.slots[i].angle
                    armorTransform.position = bossPos + SIMD2(cos(angle), sin(angle)) * armor.armorRadius
                }
            }
        }
    }

    private func generateLithicHarvesterAttack(from position: SIMD2<Float>, phase: Int) {
        let dir = playerPosition == position ? SIMD2<Float>(0, -1) : simd_normalize(playerPosition - position)
        let speed: Float = 250

        switch phase {
        case 0:
            // Phase 0: 3 predictive aimed shots
            let spread: Float = 0.15
            for i in -1...1 {
                let offset = Float(i) * spread
                let vel = SIMD2(dir.x + offset, dir.y) * speed
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

        case 1:
            // Phase 1: 3 aimed shots + asteroid fragment launches (higher speed)
            let spread: Float = 0.15
            for i in -1...1 {
                let offset = Float(i) * spread
                let vel = SIMD2(dir.x + offset, dir.y) * speed
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

            // Asteroid fragment launches
            let fragmentSpeed: Float = 400
            for i in -1...1 {
                let offset = Float(i) * 0.1
                let vel = SIMD2(dir.x + offset, dir.y) * fragmentSpeed
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 8
                ))
            }

        default:
            // Phase 2: 12 radial burst + rapid predictive shots + fragments
            let radialCount = 12
            for i in 0..<radialCount {
                let angle = Float(i) / Float(radialCount) * .pi * 2
                let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed * 1.2
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

            // Rapid predictive shots
            let spread: Float = 0.1
            for i in -2...2 {
                let offset = Float(i) * spread
                let vel = SIMD2(dir.x + offset, dir.y) * speed * 1.5
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

            // Fragment launches
            let fragmentSpeed: Float = 400
            for i in -1...1 {
                let offset = Float(i) * 0.1
                let vel = SIMD2(dir.x + offset, dir.y) * fragmentSpeed
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 8
                ))
            }
        }
    }
}
