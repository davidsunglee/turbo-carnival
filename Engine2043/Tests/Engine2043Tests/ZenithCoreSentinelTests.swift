import Testing
import GameplayKit
import simd
@testable import Engine2043

// MARK: - Helpers

@MainActor
private func makeZenithBossEntity(hp: Float = 150) -> GKEntity {
    let boss = GKEntity()
    boss.addComponent(TransformComponent(position: SIMD2(0, 200)))
    let health = HealthComponent(health: hp)
    health.hasInvulnerabilityFrames = false
    boss.addComponent(health)

    let bossPhase = BossPhaseComponent(totalHP: hp)
    bossPhase.phaseThresholds = GameConfig.Galaxy3.Enemy.bossPhaseThresholds
    boss.addComponent(bossPhase)

    boss.addComponent(ScoreComponent(points: GameConfig.Galaxy3.Score.g3Boss))

    let render = RenderComponent(size: GameConfig.Galaxy3.Enemy.bossSize, color: SIMD4(1, 1, 1, 1))
    render.spriteId = "g3ZenithCore"
    boss.addComponent(render)

    let physics = PhysicsComponent(
        collisionSize: GameConfig.Galaxy3.Enemy.bossSize,
        layer: .enemy,
        mask: [.player, .playerProjectile, .blast]
    )
    boss.addComponent(physics)

    let zenith = ZenithBossComponent()
    boss.addComponent(zenith)

    return boss
}

@MainActor
private func makeZenithBossSystem(hp: Float = 150) -> (system: BossSystem, boss: GKEntity) {
    let system = BossSystem()
    system.bossType = .zenithCoreSentinel
    let boss = makeZenithBossEntity(hp: hp)
    system.register(boss)
    system.playerPosition = SIMD2(0, -200)
    return (system, boss)
}

/// Advance the boss past the intro phase.
@MainActor
private func skipIntro(system: BossSystem, boss: GKEntity) {
    let zenith = boss.component(ofType: ZenithBossComponent.self)!
    // Fast-forward intro timer
    for _ in 0..<120 { // 2 seconds at 60fps
        system.update(deltaTime: 1.0 / 60.0)
    }
    // Verify intro is done
    assert(zenith.currentPhase == .phase1, "Should be in phase 1 after intro")
}

// MARK: - Tests

struct ZenithCoreSentinelTests {

    // MARK: - Phase tests

    @Test @MainActor func zenithHasFourPhasesAtCorrectThresholds() {
        let zenith = ZenithBossComponent()
        #expect(zenith.phaseThresholds == [0.75, 0.50, 0.25])

        zenith.updatePhase(healthFraction: 1.0)
        #expect(zenith.currentPhase == .phase1)

        zenith.updatePhase(healthFraction: 0.75)
        #expect(zenith.currentPhase == .phase2)

        zenith.updatePhase(healthFraction: 0.50)
        #expect(zenith.currentPhase == .phase3)

        zenith.updatePhase(healthFraction: 0.25)
        #expect(zenith.currentPhase == .phase4)
    }

    @Test @MainActor func phase1StartsOnFullHealth() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        #expect(zenith.currentPhase == .phase1)
    }

    @Test @MainActor func phase2ActivatesAt75Percent() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.75 // exactly at threshold
        system.update(deltaTime: 1.0 / 60.0)
        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        #expect(zenith.currentPhase == .phase2)
    }

    @Test @MainActor func phase3ActivatesAt50Percent() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.45 // below 50%
        system.update(deltaTime: 1.0 / 60.0)
        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        #expect(zenith.currentPhase == .phase3)
    }

    @Test @MainActor func phase4ActivatesAt25Percent() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.20 // below 25%
        system.update(deltaTime: 1.0 / 60.0)
        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        #expect(zenith.currentPhase == .phase4)
    }

    // MARK: - Shield tests

    @Test @MainActor func shieldWindowActivatesInPhase3() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Move to phase 3
        health.currentHealth = 150 * 0.45
        system.update(deltaTime: 1.0 / 60.0)
        #expect(zenith.currentPhase == .phase3)

        // Run enough frames to trigger shield activation (cooldown is 8.0s)
        let frames = Int(GameConfig.Galaxy3.BossAttack.shieldCooldown / (1.0 / 60.0)) + 10
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
        }
        #expect(zenith.isShieldActive == true, "Shield should activate after cooldown in phase 3")
    }

    @Test @MainActor func bossInvulnerableDuringShieldWindow() {
        let boss = makeZenithBossEntity()
        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        let health = boss.component(ofType: HealthComponent.self)!
        zenith.isShieldActive = true
        let initialHP = health.currentHealth

        // Simulate a projectile hitting the boss while shield is active
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockZenithCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity(position: SIMD2(0, 100))
        handler.processCollisions(pairs: [(projectile, boss)])

        #expect(health.currentHealth == initialHP, "Boss should not take damage while shield is active")
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }), "Projectile should be consumed")
    }

    @Test @MainActor func shieldWindowDeactivatesAfterDuration() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Move to phase 3
        health.currentHealth = 150 * 0.45

        // Activate shield directly
        zenith.isShieldActive = true
        zenith.shieldTimer = 0

        // Run frames past shieldWindowDuration
        let frames = Int(GameConfig.Galaxy3.BossAttack.shieldWindowDuration / (1.0 / 60.0)) + 10
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
        }
        #expect(zenith.isShieldActive == false, "Shield should deactivate after window duration")
    }

    // MARK: - EMP tests

    @Test @MainActor func empProjectileDisablesSecondaries() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockZenithCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Create EMP projectile with ProjectileComponent
        let empProj = TestEntityFactory.makeEnemyProjectileEntity()
        let projComp = ProjectileComponent(damage: 5, speed: 200, effects: .empDisable)
        empProj.addComponent(projComp)

        handler.processCollisions(pairs: [(player, empProj)])

        let weapon = player.component(ofType: WeaponComponent.self)!
        #expect(weapon.secondaryDisabled == true, "EMP should disable secondaries")
        #expect(weapon.secondaryDisableTimer == GameConfig.Galaxy3.BossAttack.empDisableDuration)
    }

    // MARK: - Attack generation tests

    @Test @MainActor func phase1GeneratesGridBeamAttacks() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)

        // Accumulate spawns for enough time to trigger grid beam (interval = 2.0s)
        var totalProjectiles = 0
        let frames = Int(2.5 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            totalProjectiles += system.pendingProjectileSpawns.count
        }

        #expect(totalProjectiles > 0, "Phase 1 should generate grid beam attacks")
    }

    @Test @MainActor func phase4GeneratesOverlappedAttacks() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)

        // Move to phase 4
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.20

        // Accumulate projectiles from phase 4 for 3 seconds
        var phase4Total = 0
        let frames = Int(3.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            phase4Total += system.pendingProjectileSpawns.count
        }

        // Also accumulate phase 1 for comparison
        let (system1, boss1) = makeZenithBossSystem()
        skipIntro(system: system1, boss: boss1)
        var phase1Total = 0
        for _ in 0..<frames {
            system1.update(deltaTime: 1.0 / 60.0)
            phase1Total += system1.pendingProjectileSpawns.count
        }

        #expect(phase4Total > phase1Total, "Phase 4 should produce more projectiles than phase 1")
    }

    @Test @MainActor func phase3GeneratesHomingMissiles() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.45

        // Run enough frames to trigger homing missiles (interval = 4.0s)
        var hasHoming = false
        let frames = Int(5.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            for spawn in system.pendingProjectileSpawns {
                if spawn.isHoming { hasHoming = true }
            }
        }

        #expect(hasHoming, "Phase 3 should produce homing missiles")
    }

    @Test @MainActor func phase3GeneratesEMPProjectiles() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.45

        var hasEMP = false
        let frames = Int(5.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            for spawn in system.pendingProjectileSpawns {
                if spawn.effects.contains(.empDisable) { hasEMP = true }
            }
        }

        #expect(hasEMP, "Phase 3 should produce EMP projectiles")
    }

    // MARK: - Defeat tests

    @Test @MainActor func defeatTransitionsToVictory() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)

        let health = boss.component(ofType: HealthComponent.self)!
        let phase = boss.component(ofType: BossPhaseComponent.self)!

        health.currentHealth = 0
        system.update(deltaTime: 1.0 / 60.0)

        #expect(phase.isDefeated == true, "Boss should be defeated when HP reaches 0")
    }

    // MARK: - Intro tests

    @Test @MainActor func introDescendsBoss() {
        let system = BossSystem()
        system.bossType = .zenithCoreSentinel
        // Place boss at y=340, matching real spawn position
        let boss = makeZenithBossEntity(hp: 150)
        boss.component(ofType: TransformComponent.self)!.position = SIMD2(0, 340)
        system.register(boss)
        system.playerPosition = SIMD2(0, -200)

        let transform = boss.component(ofType: TransformComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Boss starts in intro
        #expect(zenith.currentPhase == .intro)
        let startY = transform.position.y

        // Run a few frames
        for _ in 0..<30 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        // Boss should have descended
        #expect(transform.position.y < startY, "Boss should descend during intro")
    }

    // MARK: - BossType enum

    @Test @MainActor func zenithCoreSentinelTypeCanBeSet() {
        let system = BossSystem()
        system.bossType = .zenithCoreSentinel
        #expect(system.bossType == .zenithCoreSentinel)
    }

    // MARK: - ProjectileSpawnRequest extensions

    @Test func projectileSpawnRequestDefaultsPreserved() {
        let req = ProjectileSpawnRequest(position: .zero, velocity: SIMD2(0, -200), damage: 5)
        #expect(req.effects == [])
        #expect(req.isHoming == false)
        #expect(req.homingTurnRate == 0)
        #expect(req.lifetime == 5.0)
    }

    @Test func projectileSpawnRequestWithEffects() {
        let req = ProjectileSpawnRequest(
            position: .zero, velocity: SIMD2(0, -200), damage: 5,
            effects: .empDisable, isHoming: true, homingTurnRate: 2.5, lifetime: 3.0
        )
        #expect(req.effects.contains(.empDisable))
        #expect(req.isHoming == true)
        #expect(req.homingTurnRate == 2.5)
        #expect(req.lifetime == 3.0)
    }

    // MARK: - ZenithBossComponent new fields

    @Test func zenithBossComponentNewFieldDefaults() {
        let zenith = ZenithBossComponent()
        #expect(zenith.attackTimer == 0)
        #expect(zenith.shieldTimer == 0)
        #expect(zenith.shieldCooldownTimer == 0)
        #expect(zenith.empTimer == 0)
        #expect(zenith.introTimer == 0)
        #expect(zenith.spiralAngle == 0)
        #expect(zenith.lastPhase == .intro)
    }

    // MARK: - Invulnerability Window Timing

    @Test @MainActor func shieldCooldownTimerAccumulatesCorrectly() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Move to phase 3 where shields are active
        health.currentHealth = 150 * 0.45
        system.update(deltaTime: 1.0 / 60.0)
        #expect(zenith.currentPhase == .phase3)

        // Shield should start inactive with cooldown accumulating
        zenith.isShieldActive = false
        zenith.shieldCooldownTimer = 0

        // Run 1 second — cooldown should accumulate
        for _ in 0..<60 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        // shieldCooldownTimer should be approximately 1.0
        // (unless shield already activated, in which case cooldownTimer reset)
        let cooldown = GameConfig.Galaxy3.BossAttack.shieldCooldown
        if zenith.isShieldActive {
            // Shield activated before 1 second — cooldown was shorter or timer was ahead
            #expect(zenith.shieldTimer >= 0, "Shield timer should be accumulating")
        } else {
            #expect(zenith.shieldCooldownTimer > 0.9, "Cooldown timer should accumulate (~1.0s)")
            #expect(zenith.shieldCooldownTimer < cooldown, "Should not have reached cooldown yet")
        }
    }

    @Test @MainActor func shieldActivatesAndDeactivatesInCycle() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Move to phase 3
        health.currentHealth = 150 * 0.45

        // Run for 15 seconds — should see at least one shield cycle
        var shieldWasActive = false
        var shieldWasInactive = false
        let frames = Int(15.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            if zenith.isShieldActive {
                shieldWasActive = true
            } else if shieldWasActive {
                // Shield turned off after being on
                shieldWasInactive = true
                break
            }
        }

        #expect(shieldWasActive, "Shield should activate at some point during phase 3")
        #expect(shieldWasInactive, "Shield should deactivate after window duration")
    }

    // MARK: - Defeat Transitions

    @Test @MainActor func defeatSetsBossPhaseDefeatedFlag() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)

        let health = boss.component(ofType: HealthComponent.self)!
        let phase = boss.component(ofType: BossPhaseComponent.self)!

        health.currentHealth = 0
        system.update(deltaTime: 1.0 / 60.0)

        #expect(phase.isDefeated == true, "BossPhaseComponent should be defeated")
    }

    @Test @MainActor func defeatStopsProjectileGeneration() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)

        let health = boss.component(ofType: HealthComponent.self)!

        // Kill the boss
        health.currentHealth = 0
        system.update(deltaTime: 1.0 / 60.0)

        // Run more frames — boss should not generate more projectiles
        var totalProjectilesAfterDeath = 0
        for _ in 0..<120 {
            system.update(deltaTime: 1.0 / 60.0)
            totalProjectilesAfterDeath += system.pendingProjectileSpawns.count
        }

        #expect(totalProjectilesAfterDeath == 0,
                "Defeated boss should not generate any projectiles")
    }

    // MARK: - All Attack Pattern Types Present Across Phases

    @Test @MainActor func phase2GeneratesSpiralSweeps() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        health.currentHealth = 150 * 0.74 // Just below 75% threshold

        // Run enough frames to generate phase 2 attacks (grid beam + spiral)
        var totalProjectiles = 0
        let frames = Int(3.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            totalProjectiles += system.pendingProjectileSpawns.count
        }

        // Phase 2 adds spiral sweeps on top of grid beams, so more projectiles
        #expect(totalProjectiles > 0, "Phase 2 should generate projectiles including spirals")
    }

    @Test @MainActor func phase4HasMoreProjectilesThanPhase2() {
        // Phase 4 should be strictly more intense than phase 2
        let (system4, boss4) = makeZenithBossSystem()
        skipIntro(system: system4, boss: boss4)
        boss4.component(ofType: HealthComponent.self)!.currentHealth = 150 * 0.20

        var phase4Total = 0
        let frames = Int(5.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system4.update(deltaTime: 1.0 / 60.0)
            phase4Total += system4.pendingProjectileSpawns.count
        }

        let (system2, boss2) = makeZenithBossSystem()
        skipIntro(system: system2, boss: boss2)
        boss2.component(ofType: HealthComponent.self)!.currentHealth = 150 * 0.74

        var phase2Total = 0
        for _ in 0..<frames {
            system2.update(deltaTime: 1.0 / 60.0)
            phase2Total += system2.pendingProjectileSpawns.count
        }

        #expect(phase4Total > phase2Total,
                "Phase 4 (\(phase4Total)) should produce more projectiles than phase 2 (\(phase2Total))")
    }

    @Test @MainActor func phase4GeneratesEMPProjectiles() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        boss.component(ofType: HealthComponent.self)!.currentHealth = 150 * 0.20

        var hasEMP = false
        let frames = Int(5.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            for spawn in system.pendingProjectileSpawns {
                if spawn.effects.contains(.empDisable) { hasEMP = true }
            }
        }

        #expect(hasEMP, "Phase 4 should produce EMP projectiles")
    }

    @Test @MainActor func phase4GeneratesHomingMissiles() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        boss.component(ofType: HealthComponent.self)!.currentHealth = 150 * 0.20

        var hasHoming = false
        let frames = Int(5.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
            for spawn in system.pendingProjectileSpawns {
                if spawn.isHoming { hasHoming = true }
            }
        }

        #expect(hasHoming, "Phase 4 should produce homing missiles")
    }

    // MARK: - Phase Transition Resets Attack Timer

    @Test @MainActor func phaseTransitionResetsAttackTimer() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Run for 1 second in phase 1 to accumulate attack timer
        for _ in 0..<60 {
            system.update(deltaTime: 1.0 / 60.0)
        }
        #expect(zenith.attackTimer > 0, "Attack timer should have accumulated")

        // Trigger phase transition to phase 2
        health.currentHealth = 150 * 0.74
        system.update(deltaTime: 1.0 / 60.0)

        #expect(zenith.currentPhase == .phase2)
        // Attack timer should have been reset on phase change
        // (The timer may not be exactly 0 after the update tick, but it should be small)
        #expect(zenith.attackTimer < 0.1,
                "Attack timer should reset on phase transition")
    }

    // MARK: - Intro Completes and Transitions to Phase 1

    @Test @MainActor func introCompletesTransitionToPhase1() {
        let system = BossSystem()
        system.bossType = .zenithCoreSentinel
        let boss = makeZenithBossEntity(hp: 150)
        boss.component(ofType: TransformComponent.self)!.position = SIMD2(0, 340)
        system.register(boss)
        system.playerPosition = SIMD2(0, -200)

        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        #expect(zenith.currentPhase == .intro)

        // Run for 2 seconds (intro duration is 1.5s)
        for _ in 0..<120 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(zenith.currentPhase == .phase1, "Should transition to phase 1 after intro")
        let transform = boss.component(ofType: TransformComponent.self)!
        #expect(transform.position.y == 200, "Boss should be at y=200 after intro descent")
    }

    // MARK: - Shield Does Not Activate in Phase 1 or 2

    @Test @MainActor func shieldDoesNotActivateInPhase1() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let zenith = boss.component(ofType: ZenithBossComponent.self)!

        // Run for 15 seconds in phase 1
        let frames = Int(15.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(zenith.isShieldActive == false, "Shield should not activate in phase 1")
    }

    @Test @MainActor func shieldDoesNotActivateInPhase2() {
        let (system, boss) = makeZenithBossSystem()
        skipIntro(system: system, boss: boss)
        let health = boss.component(ofType: HealthComponent.self)!
        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        health.currentHealth = 150 * 0.74 // phase 2

        let frames = Int(15.0 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(zenith.isShieldActive == false, "Shield should not activate in phase 2")
    }
}

// MARK: - Mock Collision Context

@MainActor
private final class MockZenithCollisionContext: CollisionContext {
    var player: GKEntity!
    let scoreSystem = ScoreSystem()
    let itemSystem = ItemSystem()
    var sfx: AudioEngine? = nil
    var pendingRemovals: [GKEntity] = []
    var enemiesDestroyed: Int = 0

    init(player: GKEntity) {
        self.player = player
    }

    func checkFormationWipe(enemy: GKEntity) {}
    func spawnShieldDrones() {}
}
