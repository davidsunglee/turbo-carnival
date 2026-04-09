import GameplayKit
import simd

@MainActor
public enum Galaxy3EntityFactory {

    // MARK: - Tracking Drone (Tier 1)

    public static func makeTrackingDrone(at position: SIMD2<Float>) -> GKEntity {
        let entity = GKEntity()

        let transform = TransformComponent(position: position)
        entity.addComponent(transform)

        let size = GameConfig.Galaxy3.Enemy.tier1Size
        let physics = PhysicsComponent(
            collisionSize: size,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        physics.velocity = SIMD2<Float>(0, -GameConfig.Galaxy3.Enemy.tier1Speed)
        entity.addComponent(physics)

        let render = RenderComponent(
            size: size,
            color: GameConfig.Galaxy3.Palette.g3Tier1
        )
        render.spriteId = "g3TrackingDrone"
        entity.addComponent(render)

        let health = HealthComponent(health: GameConfig.Galaxy3.Enemy.tier1HP)
        health.hasInvulnerabilityFrames = false
        entity.addComponent(health)

        let score = ScoreComponent(points: GameConfig.Galaxy3.Score.g3Tier1)
        entity.addComponent(score)

        return entity
    }

    // MARK: - Fighter (Tier 2)

    public static func makeFighter(at position: SIMD2<Float>) -> GKEntity {
        let entity = GKEntity()

        let transform = TransformComponent(position: position)
        entity.addComponent(transform)

        let size = GameConfig.Galaxy3.Enemy.tier2Size
        let physics = PhysicsComponent(
            collisionSize: size,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        physics.velocity = SIMD2<Float>(0, -GameConfig.Galaxy3.Enemy.tier2Speed)
        entity.addComponent(physics)

        let render = RenderComponent(
            size: size,
            color: GameConfig.Galaxy3.Palette.g3Tier2
        )
        render.spriteId = "g3Fighter"
        entity.addComponent(render)

        let health = HealthComponent(health: GameConfig.Galaxy3.Enemy.tier2HP)
        health.hasInvulnerabilityFrames = false
        entity.addComponent(health)

        let score = ScoreComponent(points: GameConfig.Galaxy3.Score.g3Tier2)
        entity.addComponent(score)

        return entity
    }

    // MARK: - Fortress Hull (decorative)

    public static func makeFortressHull(at position: SIMD2<Float>) -> GKEntity {
        let entity = GKEntity()

        let transform = TransformComponent(position: position)
        entity.addComponent(transform)

        let size = GameConfig.Galaxy3.Enemy.fortressHullSize
        let physics = PhysicsComponent(
            collisionSize: size,
            layer: .enemy,
            mask: []  // Hull is decorative, nodes are the interactive targets
        )
        entity.addComponent(physics)

        let render = RenderComponent(
            size: size,
            color: GameConfig.Galaxy3.Palette.g3FortressHull
        )
        render.spriteId = "g3FortressHull"
        entity.addComponent(render)

        return entity
    }

    // MARK: - Fortress Node

    public static func makeFortressNode(
        role: FortressNodeRole,
        at position: SIMD2<Float>,
        fortressID: Int
    ) -> GKEntity {
        let entity = GKEntity()

        let transform = TransformComponent(position: position)
        entity.addComponent(transform)

        let size = GameConfig.Galaxy3.Enemy.fortressNodeSize
        let physics = PhysicsComponent(
            collisionSize: size,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        entity.addComponent(physics)

        let render = RenderComponent(
            size: size,
            color: GameConfig.Galaxy3.Palette.g3Tier2
        )
        render.spriteId = "g3FortressNode"
        entity.addComponent(render)

        let hp: Float
        switch role {
        case .shieldGenerator:
            hp = GameConfig.Galaxy3.Enemy.fortressShieldGenHP
        case .mainBattery:
            hp = GameConfig.Galaxy3.Enemy.fortressMainBatteryHP
        case .pulseTurret:
            hp = GameConfig.Galaxy3.Enemy.fortressPulseTurretHP
        }
        let health = HealthComponent(health: hp)
        health.hasInvulnerabilityFrames = false
        entity.addComponent(health)

        let score = ScoreComponent(points: GameConfig.Galaxy3.Score.g3FortressNode)
        entity.addComponent(score)

        let fortressNode = FortressNodeComponent(role: role, fortressID: fortressID)
        entity.addComponent(fortressNode)

        return entity
    }

    // MARK: - Barrier

    public static func makeBarrier(kind: BarrierKind, at position: SIMD2<Float>) -> GKEntity {
        let entity = GKEntity()

        let transform = TransformComponent(position: position)
        entity.addComponent(transform)

        let size = GameConfig.Galaxy3.Barrier.gateSegmentSize
        let physics = PhysicsComponent(
            collisionSize: size,
            layer: .barrier,
            mask: [.player]
        )
        entity.addComponent(physics)

        let render = RenderComponent(
            size: size,
            color: GameConfig.Galaxy3.Palette.g3Barrier
        )
        render.spriteId = "g3BarrierWall"
        entity.addComponent(render)

        let barrier = BarrierComponent(kind: kind)
        entity.addComponent(barrier)

        return entity
    }

    // MARK: - Zenith Boss Shell

    public static func makeZenithBossShell(
        at position: SIMD2<Float>
    ) -> (core: GKEntity, shields: [GKEntity]) {
        // Core entity
        let core = GKEntity()

        let coreTransform = TransformComponent(position: position)
        core.addComponent(coreTransform)

        let coreSize = GameConfig.Galaxy3.Enemy.bossSize
        let corePhysics = PhysicsComponent(
            collisionSize: coreSize,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        core.addComponent(corePhysics)

        let coreRender = RenderComponent(
            size: coreSize,
            color: GameConfig.Galaxy3.Palette.g3BossCore
        )
        coreRender.spriteId = "g3ZenithCore"
        core.addComponent(coreRender)

        let coreHealth = HealthComponent(health: GameConfig.Galaxy3.Enemy.bossHP)
        coreHealth.hasInvulnerabilityFrames = false
        core.addComponent(coreHealth)

        let coreScore = ScoreComponent(points: GameConfig.Galaxy3.Score.g3Boss)
        core.addComponent(coreScore)

        let zenithBoss = ZenithBossComponent()
        core.addComponent(zenithBoss)

        let bossPhase = BossPhaseComponent(totalHP: GameConfig.Galaxy3.Enemy.bossHP)
        bossPhase.phaseThresholds = GameConfig.Galaxy3.Enemy.bossPhaseThresholds
        core.addComponent(bossPhase)

        // Shield entities — 4 shields arranged around the core
        let shieldOffsets: [SIMD2<Float>] = [
            SIMD2<Float>(0, coreSize.y / 2 + 8),    // top
            SIMD2<Float>(0, -(coreSize.y / 2 + 8)),  // bottom
            SIMD2<Float>(-(coreSize.x / 2 + 8), 0),  // left
            SIMD2<Float>(coreSize.x / 2 + 8, 0),     // right
        ]

        var shields: [GKEntity] = []
        for offset in shieldOffsets {
            let shield = GKEntity()

            let shieldPos = position + offset
            let shieldTransform = TransformComponent(position: shieldPos)
            shield.addComponent(shieldTransform)

            let shieldSize = SIMD2<Float>(40, 12)
            let shieldPhysics = PhysicsComponent(
                collisionSize: shieldSize,
                layer: .bossShield,
                mask: [.playerProjectile, .blast]
            )
            shield.addComponent(shieldPhysics)

            let shieldRender = RenderComponent(
                size: shieldSize,
                color: GameConfig.Galaxy3.Palette.g3BossShield
            )
            shieldRender.spriteId = "g3ZenithShield"
            shield.addComponent(shieldRender)

            shields.append(shield)
        }

        return (core: core, shields: shields)
    }
}
