import GameplayKit
import simd

public enum BossType: Sendable {
    case galaxy1
    case lithicHarvester
    case zenithCoreSentinel
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
        case .zenithCoreSentinel:
            updateZenithCoreSentinel(boss: boss, bossPhase: bossPhase, health: health, transform: transform, deltaTime: deltaTime)
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

    // MARK: - Zenith Core Sentinel Boss

    private func updateZenithCoreSentinel(boss: GKEntity, bossPhase: BossPhaseComponent, health: HealthComponent, transform: TransformComponent, deltaTime: Double) {
        guard let zenith = boss.component(ofType: ZenithBossComponent.self) else { return }

        // Only update phase from health after intro is complete
        if zenith.currentPhase != .intro {
            let healthFraction = health.currentHealth / bossPhase.totalHP
            zenith.updatePhase(healthFraction: healthFraction)
        }

        // Detect phase transitions
        if zenith.currentPhase != zenith.lastPhase {
            zenith.lastPhase = zenith.currentPhase
            // Reset attack timer on phase change for clean cadence
            zenith.attackTimer = 0
            zenith.empTimer = 0
            zenith.radialBurstTimer = 0
        }

        // Intro descent — boss slides down from above before attacking
        if zenith.currentPhase == .intro {
            zenith.introTimer += deltaTime
            let introDuration: Double = 1.5
            if zenith.introTimer < introDuration {
                let t = Float(zenith.introTimer / introDuration)
                // Descend from y=340 to y=200
                transform.position.y = 340 - t * 140
                return
            }
            // Intro complete — transition to phase 1
            transform.position.y = 200
            zenith.currentPhase = .phase1
            zenith.lastPhase = .phase1
            return
        }

        // Shield window logic (phase 3 and 4 only)
        if zenith.currentPhase == .phase3 || zenith.currentPhase == .phase4 {
            if zenith.isShieldActive {
                zenith.shieldTimer += deltaTime
                let duration = zenith.currentPhase == .phase4
                    ? GameConfig.Galaxy3.BossAttack.shieldWindowDuration * 0.6
                    : GameConfig.Galaxy3.BossAttack.shieldWindowDuration
                if zenith.shieldTimer >= duration {
                    zenith.isShieldActive = false
                    zenith.shieldTimer = 0
                    zenith.shieldCooldownTimer = 0
                    updateZenithShieldVisibility(visible: false)
                }
            } else {
                zenith.shieldCooldownTimer += deltaTime
                let cooldown = zenith.currentPhase == .phase4
                    ? GameConfig.Galaxy3.BossAttack.shieldCooldown * 0.7
                    : GameConfig.Galaxy3.BossAttack.shieldCooldown
                if zenith.shieldCooldownTimer >= cooldown {
                    zenith.isShieldActive = true
                    zenith.shieldCooldownTimer = 0
                    zenith.shieldTimer = 0
                    updateZenithShieldVisibility(visible: true)
                }
            }
        } else {
            // Phases 1 and 2 — shields stay off
            if zenith.isShieldActive {
                zenith.isShieldActive = false
                updateZenithShieldVisibility(visible: false)
            }
        }

        // Update shield positions around boss
        let bossPos = transform.position
        let shieldDistance: Float = 70
        for (i, shield) in shieldEntities.enumerated() {
            guard let shieldTransform = shield.component(ofType: TransformComponent.self) else { continue }
            let angle = Float(i) * (.pi / 2)  // 4 shields, 90-degree spacing
            shieldTransform.position = bossPos + SIMD2(cos(angle), sin(angle)) * shieldDistance
        }

        // Attack sequencing per phase
        let position = transform.position
        zenith.attackTimer += deltaTime

        switch zenith.currentPhase {
        case .phase1:
            // Grid beam attacks with clear gaps
            let interval = GameConfig.Galaxy3.BossAttack.gridBeamInterval
            if zenith.attackTimer >= interval {
                zenith.attackTimer -= interval
                generateGridBeamAttack(from: position)
            }

        case .phase2:
            // Grid beams (faster) + spiral sweeps
            let interval = GameConfig.Galaxy3.BossAttack.gridBeamInterval * 0.75
            if zenith.attackTimer >= interval {
                zenith.attackTimer -= interval
                generateGridBeamAttack(from: position)
                generateSpiralSweep(from: position, zenith: zenith)
            }

        case .phase3:
            // Grid beams
            let interval = GameConfig.Galaxy3.BossAttack.gridBeamInterval * 0.6
            if zenith.attackTimer >= interval {
                zenith.attackTimer -= interval
                generateGridBeamAttack(from: position)
            }
            // Radial bursts on their own configured cadence
            zenith.radialBurstTimer += deltaTime
            let radialInterval3 = GameConfig.Galaxy3.BossAttack.radialBurstInterval
            if zenith.radialBurstTimer >= radialInterval3 {
                zenith.radialBurstTimer -= radialInterval3
                generateRadialBurst(from: position)
            }
            // Homing missiles + EMP on separate timer
            zenith.empTimer += deltaTime
            let homingInterval = GameConfig.Galaxy3.BossAttack.homingMissileInterval
            if zenith.empTimer >= homingInterval {
                zenith.empTimer -= homingInterval
                generateHomingMissiles(from: position)
                generateEMPProjectile(from: position)
            }

        case .phase4:
            // Grid beams + spiral sweeps
            let interval = GameConfig.Galaxy3.BossAttack.gridBeamInterval * 0.5
            if zenith.attackTimer >= interval {
                zenith.attackTimer -= interval
                generateGridBeamAttack(from: position)
                generateSpiralSweep(from: position, zenith: zenith)
            }
            // Radial bursts on their own configured cadence
            zenith.radialBurstTimer += deltaTime
            let radialInterval4 = GameConfig.Galaxy3.BossAttack.radialBurstInterval * 0.8
            if zenith.radialBurstTimer >= radialInterval4 {
                zenith.radialBurstTimer -= radialInterval4
                generateRadialBurst(from: position)
            }
            // More frequent homing + EMP
            zenith.empTimer += deltaTime
            let homingInterval = GameConfig.Galaxy3.BossAttack.homingMissileInterval * 0.6
            if zenith.empTimer >= homingInterval {
                zenith.empTimer -= homingInterval
                generateHomingMissiles(from: position)
                generateEMPProjectile(from: position)
            }

        case .intro, .defeated:
            break
        }
    }

    private func updateZenithShieldVisibility(visible: Bool) {
        for shield in shieldEntities {
            shield.component(ofType: RenderComponent.self)?.isVisible = visible
        }
    }

    // MARK: - Zenith Attack Patterns

    private func generateGridBeamAttack(from position: SIMD2<Float>) {
        let speed = GameConfig.Galaxy3.BossAttack.gridBeamProjectileSpeed
        // Fire a row of downward projectiles with gaps for the player to dodge
        // 5 columns across 360-unit width, with safe lanes between them
        let columns: [Float] = [-120, -60, 0, 60, 120]
        // Leave 2 random safe lanes
        var activeColumns = columns
        let skip1 = Int.random(in: 0..<activeColumns.count)
        activeColumns.remove(at: skip1)
        let skip2 = Int.random(in: 0..<activeColumns.count)
        activeColumns.remove(at: skip2)

        for col in activeColumns {
            let spawnPos = SIMD2<Float>(col, position.y)
            let vel = SIMD2<Float>(0, -speed)
            pendingProjectileSpawns.append(ProjectileSpawnRequest(
                position: spawnPos,
                velocity: vel,
                damage: 5
            ))
        }
    }

    private func generateSpiralSweep(from position: SIMD2<Float>, zenith: ZenithBossComponent) {
        let speed = GameConfig.Galaxy3.BossAttack.radialBurstProjectileSpeed
        // Rotating double-arm spiral using spiralAngle state
        zenith.spiralAngle += 0.4
        let armCount = 2
        for arm in 0..<armCount {
            let angle = zenith.spiralAngle + Float(arm) * .pi
            let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed
            pendingProjectileSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: vel,
                damage: 5
            ))
        }
    }

    private func generateRadialBurst(from position: SIMD2<Float>) {
        let speed = GameConfig.Galaxy3.BossAttack.radialBurstProjectileSpeed
        let count = GameConfig.Galaxy3.BossAttack.radialBurstProjectileCount
        // Offset each burst by a random angle so patterns aren't perfectly repetitive
        let offset = Float.random(in: 0...(Float.pi * 2 / Float(count)))
        for i in 0..<count {
            let angle = Float(i) / Float(count) * .pi * 2 + offset
            let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed
            pendingProjectileSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: vel,
                damage: 5
            ))
        }
    }

    private func generateHomingMissiles(from position: SIMD2<Float>) {
        let speed = GameConfig.Galaxy3.BossAttack.homingMissileSpeed
        let count = GameConfig.Galaxy3.BossAttack.homingMissileCount
        let turnRate = GameConfig.Galaxy3.BossAttack.homingMissileTurnRate
        let lifetime = GameConfig.Galaxy3.BossAttack.homingMissileLifetime

        let dir = playerPosition == position ? SIMD2<Float>(0, -1) : simd_normalize(playerPosition - position)
        let spread: Float = 0.3

        for i in 0..<count {
            let offset = Float(i - count / 2) * spread
            let vel = SIMD2(dir.x + offset, dir.y) * speed
            pendingProjectileSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: vel,
                damage: 8,
                isHoming: true,
                homingTurnRate: turnRate,
                lifetime: lifetime
            ))
        }
    }

    private func generateEMPProjectile(from position: SIMD2<Float>) {
        let speed = GameConfig.Galaxy3.BossAttack.gridBeamProjectileSpeed * 0.8
        let dir = playerPosition == position ? SIMD2<Float>(0, -1) : simd_normalize(playerPosition - position)
        pendingProjectileSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: dir * speed,
            damage: 5,
            effects: .empDisable
        ))
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
