import Testing
import GameplayKit
import simd
@testable import Engine2043

struct BossSystemTests {
    @Test @MainActor func bossSystemRotatesShields() {
        let system = BossSystem()

        let bossEntity = GKEntity()
        bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        bossEntity.addComponent(HealthComponent(health: 30))
        let bossPhase = BossPhaseComponent(totalHP: 30)
        bossEntity.addComponent(bossPhase)

        system.register(bossEntity)
        system.update(deltaTime: 1.0)

        #expect(bossPhase.shieldRotation != 0)
    }

    @Test @MainActor func bossSystemTransitionsPhases() {
        let system = BossSystem()

        let bossEntity = GKEntity()
        bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let health = HealthComponent(health: 30)
        bossEntity.addComponent(health)
        let bossPhase = BossPhaseComponent(totalHP: 30)
        bossEntity.addComponent(bossPhase)

        system.register(bossEntity)

        health.currentHealth = 15
        system.update(deltaTime: 1.0 / 60.0)
        #expect(bossPhase.currentPhase == 1)

        health.currentHealth = 6
        system.update(deltaTime: 1.0 / 60.0)
        #expect(bossPhase.currentPhase == 2)
    }

    @Test @MainActor func bossSystemGeneratesAttackSpawns() {
        let system = BossSystem()

        let bossEntity = GKEntity()
        bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        bossEntity.addComponent(HealthComponent(health: 30))
        let bossPhase = BossPhaseComponent(totalHP: 30)
        bossEntity.addComponent(bossPhase)

        system.register(bossEntity)

        for _ in 0..<120 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(system.pendingProjectileSpawns.count > 0)
    }

    @Test @MainActor func bossSystemDetectsDefeat() {
        let system = BossSystem()

        let bossEntity = GKEntity()
        bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let health = HealthComponent(health: 30)
        health.currentHealth = 0
        bossEntity.addComponent(health)
        let bossPhase = BossPhaseComponent(totalHP: 30)
        bossEntity.addComponent(bossPhase)

        system.register(bossEntity)
        system.update(deltaTime: 1.0 / 60.0)

        #expect(bossPhase.isDefeated == true)
    }
}
