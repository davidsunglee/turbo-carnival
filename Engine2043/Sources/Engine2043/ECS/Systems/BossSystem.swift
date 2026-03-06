import GameplayKit
import simd

@MainActor
public final class BossSystem {
    private var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    public private(set) var pendingProjectileSpawns: [ProjectileSpawnRequest] = []
    public var playerPosition: SIMD2<Float> = .zero

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

        let speedMultiplier: Float = Float(bossPhase.currentPhase + 1)
        bossPhase.shieldRotation += bossPhase.shieldSpeed * speedMultiplier * Float(deltaTime)

        updateShieldPositions(bossPosition: transform.position, rotation: bossPhase.shieldRotation, phase: bossPhase.currentPhase)

        attackTimer += deltaTime
        let attackInterval = baseAttackInterval / Double(bossPhase.currentPhase + 1)

        if attackTimer >= attackInterval {
            attackTimer -= attackInterval
            generateAttack(from: transform.position, phase: bossPhase.currentPhase, rotation: bossPhase.shieldRotation)
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

    private func generateAttack(from position: SIMD2<Float>, phase: Int, rotation: Float) {
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
}
