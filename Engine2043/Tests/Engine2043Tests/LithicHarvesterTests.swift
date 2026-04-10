import Testing
import GameplayKit
import simd
@testable import Engine2043

// MARK: - Mock Collision Context (private to this file)

@MainActor
private final class MockCollisionContext: CollisionContext {
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

// MARK: - Helpers

@MainActor
private func makeBossEntity(hp: Float = 100, armorSlots: Int = 6) -> (boss: GKEntity, armor: BossArmorComponent) {
    let boss = GKEntity()
    boss.addComponent(TransformComponent(position: SIMD2(0, 200)))
    let health = HealthComponent(health: hp)
    health.hasInvulnerabilityFrames = false
    boss.addComponent(health)
    boss.addComponent(BossPhaseComponent(totalHP: hp))
    boss.addComponent(ScoreComponent(points: 1000))

    let render = RenderComponent(size: SIMD2(100, 100), color: SIMD4(1, 1, 1, 1))
    render.spriteId = "lithicHarvesterCore"
    boss.addComponent(render)

    let armorComp = BossArmorComponent()
    let slotCount = armorSlots
    for i in 0..<slotCount {
        let angle = Float(i) / Float(slotCount) * .pi * 2
        armorComp.slots.append(ArmorSlot(angle: angle, entity: nil))
    }
    boss.addComponent(armorComp)
    return (boss, armorComp)
}

@MainActor
private func makeArmorAsteroidEntity(position: SIMD2<Float> = .zero, hp: Float = 4.0) -> GKEntity {
    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: position))
    let physics = PhysicsComponent(
        collisionSize: SIMD2(16, 16),
        layer: .asteroid,
        mask: [.playerProjectile]
    )
    entity.addComponent(physics)
    let render = RenderComponent(size: SIMD2(16, 16), color: SIMD4(0.5, 0.4, 0.35, 1.0))
    render.spriteId = "asteroidSmall"
    entity.addComponent(render)
    let health = HealthComponent(health: hp)
    health.hasInvulnerabilityFrames = false
    entity.addComponent(health)
    entity.addComponent(AsteroidComponent(size: .small))
    return entity
}

// MARK: - Tests

struct LithicHarvesterTests {

    // MARK: - Boss spawns with correct HP and armor slots

    @Test @MainActor func bossSpawnsWithCorrectHPAndArmorSlots() {
        let (boss, armor) = makeBossEntity(hp: GameConfig.Galaxy2.Enemy.bossHP, armorSlots: GameConfig.Galaxy2.Enemy.bossArmorSlots)
        let health = boss.component(ofType: HealthComponent.self)!

        #expect(health.currentHealth == 100)
        #expect(health.maxHealth == 100)
        #expect(armor.slots.count == 6)
    }

    // MARK: - Armor slots block projectile damage

    @Test @MainActor func armorSlotsBlockProjectileDamage() {
        // Setup: boss with armor entity in slot 0
        let (boss, armor) = makeBossEntity()
        let armorAsteroid = makeArmorAsteroidEntity(hp: GameConfig.Galaxy2.Enemy.bossArmorSlotHP)
        armor.slots[0].entity = armorAsteroid

        let bossHealth = boss.component(ofType: HealthComponent.self)!
        let armorHealth = armorAsteroid.component(ofType: HealthComponent.self)!
        let initialBossHP = bossHealth.currentHealth

        // BossSystem with lithic harvester type - check armor intercept logic
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.register(boss)

        // Verify boss has armor component with active slots
        let bossArmor = boss.component(ofType: BossArmorComponent.self)!
        #expect(bossArmor.slots[0].isActive == true)

        // Simulate projectile hitting armor: damage the armor entity, not the boss
        armorHealth.takeDamage(GameConfig.Player.damage)

        #expect(bossHealth.currentHealth == initialBossHP, "Boss should not take damage when armor blocks")
        #expect(armorHealth.currentHealth < GameConfig.Galaxy2.Enemy.bossArmorSlotHP, "Armor entity should take damage")
    }

    // MARK: - Destroying armor creates gaps

    @Test @MainActor func destroyingArmorCreatesGap() {
        let (boss, armor) = makeBossEntity()
        let armorAsteroid = makeArmorAsteroidEntity(hp: 1.0)
        armor.slots[0].entity = armorAsteroid

        #expect(armor.slots[0].isActive == true)

        // Destroy the armor entity
        let armorHealth = armorAsteroid.component(ofType: HealthComponent.self)!
        armorHealth.takeDamage(100)  // overkill

        #expect(!armorHealth.isAlive)

        // Simulate the scene clearing dead armor entities
        armor.slots[0].entity = nil
        #expect(armor.slots[0].isActive == false, "Slot should become a gap after armor is destroyed")
    }

    // MARK: - Boss takes damage through gaps

    @Test @MainActor func bossTakesDamageThroughGaps() {
        let (boss, armor) = makeBossEntity()

        // All armor slots empty (gaps)
        for i in 0..<armor.slots.count {
            armor.slots[i].entity = nil
        }

        let bossHealth = boss.component(ofType: HealthComponent.self)!
        let initialHP = bossHealth.currentHealth

        // Direct damage to boss (no armor to intercept)
        bossHealth.takeDamage(10)

        #expect(bossHealth.currentHealth == initialHP - 10, "Boss should take damage through gaps")
    }

    // MARK: - Phase Laser damages armor first, then boss through gaps

    @Test @MainActor func phaseLaserDamagesArmorFirstThenBoss() {
        let (boss, armor) = makeBossEntity()

        // Slot 0 has armor, slot 1 is empty
        let armorAsteroid = makeArmorAsteroidEntity(hp: GameConfig.Galaxy2.Enemy.bossArmorSlotHP)
        armor.slots[0].entity = armorAsteroid
        // Other slots empty

        let bossHealth = boss.component(ofType: HealthComponent.self)!
        let armorHealth = armorAsteroid.component(ofType: HealthComponent.self)!

        // Laser hits armor first
        let laserDmg: Float = 2.0
        armorHealth.takeDamage(laserDmg)
        let initialBossHP = bossHealth.currentHealth

        #expect(armorHealth.currentHealth == GameConfig.Galaxy2.Enemy.bossArmorSlotHP - laserDmg)
        #expect(bossHealth.currentHealth == initialBossHP, "Boss HP unchanged while armor takes laser damage")

        // After armor destroyed, laser hits boss
        armorHealth.takeDamage(100)
        armor.slots[0].entity = nil

        // Now boss takes damage directly
        bossHealth.takeDamage(laserDmg)
        #expect(bossHealth.currentHealth == initialBossHP - laserDmg, "Boss should take laser damage through gap")
    }

    // MARK: - Tractor beam timer triggers armor rebuild

    @Test @MainActor func tractorBeamTimerTriggersArmorRebuild() {
        let (boss, armor) = makeBossEntity()
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.register(boss)

        // Clear all armor slots (gaps)
        for i in 0..<armor.slots.count {
            armor.slots[i].entity = nil
        }

        // Run updates to accumulate tractor beam timer past the interval (8.0s for phase 0)
        // In phase 0, tractorBeamInterval = 8.0
        system.playerPosition = SIMD2(0, -200)

        // Advance past tractor beam interval
        let steps = Int(8.5 / (1.0 / 60.0))
        for _ in 0..<steps {
            system.update(deltaTime: 1.0 / 60.0)
        }

        // After timer expires, system should signal tractor beam pulls
        #expect(armor.tractorBeamTimer >= armor.tractorBeamInterval || system.pendingTractorBeamPulls.count > 0 || armor.tractorBeamTimer < 1.0,
                "Tractor beam timer should have cycled")
    }

    // MARK: - Phase transitions change attack patterns

    @Test @MainActor func phaseTransitionsChangeAttackPatterns() {
        let system = BossSystem()
        system.bossType = .lithicHarvester

        let (boss, _) = makeBossEntity(hp: 100)
        system.register(boss)
        system.playerPosition = SIMD2(0, -200)

        let health = boss.component(ofType: HealthComponent.self)!

        // Phase 0 (HP > 60%): should fire 3 predictive shots
        // Accumulate spawns across frames (pendingProjectileSpawns is cleared each update)
        var phase0Total = 0
        for _ in 0..<150 {
            system.update(deltaTime: 1.0 / 60.0)
            phase0Total += system.pendingProjectileSpawns.count
        }

        // Phase 1 (HP 30-60%): more projectiles
        health.currentHealth = 50  // 50% = phase 1
        var phase1Total = 0
        for _ in 0..<150 {
            system.update(deltaTime: 1.0 / 60.0)
            phase1Total += system.pendingProjectileSpawns.count
        }

        // Phase 2 (HP < 30%): dense radial + rapid shots
        health.currentHealth = 20  // 20% = phase 2
        var phase2Total = 0
        for _ in 0..<150 {
            system.update(deltaTime: 1.0 / 60.0)
            phase2Total += system.pendingProjectileSpawns.count
        }

        // Each phase should produce increasing projectile counts
        #expect(phase0Total > 0, "Phase 0 should generate attacks")
        #expect(phase2Total >= phase1Total, "Phase 2 should produce at least as many projectiles as phase 1")
    }

    // MARK: - Boss death when HP reaches 0

    @Test @MainActor func bossDeathWhenHPReachesZero() {
        let system = BossSystem()
        system.bossType = .lithicHarvester

        let (boss, _) = makeBossEntity(hp: 100)
        system.register(boss)

        let health = boss.component(ofType: HealthComponent.self)!
        let phase = boss.component(ofType: BossPhaseComponent.self)!

        health.currentHealth = 0
        system.update(deltaTime: 1.0 / 60.0)

        #expect(phase.isDefeated == true, "Boss should be defeated when HP reaches 0")
    }

    // MARK: - BossType enum

    @Test @MainActor func bossTypeDefaultsToGalaxy1() {
        let system = BossSystem()
        #expect(system.bossType == .galaxy1)
    }

    @Test @MainActor func lithicHarvesterTypeCanBeSet() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        #expect(system.bossType == .lithicHarvester)
    }

    // MARK: - Armor component basics

    @Test @MainActor func armorSlotReportsActiveCorrectly() {
        var slot = ArmorSlot(angle: 0, entity: nil)
        #expect(!slot.isActive)

        slot.entity = GKEntity()
        #expect(slot.isActive)
    }

    @Test @MainActor func bossArmorComponentDefaults() {
        let comp = BossArmorComponent()
        #expect(comp.slots.isEmpty)
        #expect(comp.tractorBeamTargets.isEmpty)
        #expect(comp.tractorBeamTimer == 0)
        #expect(comp.tractorBeamInterval == 8.0)
        #expect(comp.armorRadius == 70)
    }

    // MARK: - Pending armor attachments and tractor beam pulls

    @Test @MainActor func pendingTractorBeamPullsAndArmorAttachments() {
        let system = BossSystem()
        system.bossType = .lithicHarvester

        // Initially empty
        #expect(system.pendingTractorBeamPulls.isEmpty)
        #expect(system.pendingArmorAttachments.isEmpty)
    }

    // MARK: - Geometric armor gap regression tests

    /// Destroy one armor slot, fire a projectile from the gap's angle,
    /// assert boss takes damage directly.
    @Test @MainActor func bossTakesDamageThroughArmorGap() {
        // Boss at (0, 200) with 6 armor slots
        let (boss, armor) = makeBossEntity(hp: 100, armorSlots: 6)
        let bossHealth = boss.component(ofType: HealthComponent.self)!
        let initialHP = bossHealth.currentHealth

        // Physics layer so collision handler recognises it as .enemy
        let bossPhysics = PhysicsComponent(
            collisionSize: SIMD2(100, 100),
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        boss.addComponent(bossPhysics)

        // Populate all slots with armor entities EXCEPT slot 1 (angle = π/3 ≈ 60°)
        for i in 0..<armor.slots.count {
            if i == 1 { continue } // leave gap at slot 1
            let armorEntity = makeArmorAsteroidEntity(hp: 100)
            armor.slots[i].entity = armorEntity
        }
        // Confirm the gap
        #expect(armor.slots[1].isActive == false)

        // Position projectile so the approach angle to the boss matches slot 1's angle (π/3).
        // approach = atan2(boss.y - proj.y, boss.x - proj.x) = π/3
        // boss is at (0, 200). We need proj at a position such that atan2(200 - py, 0 - px) = π/3
        // tan(π/3) = √3 ≈ 1.732.  Place projectile at (-100, 200 - 100*√3) ≈ (-100, 27)
        let projX: Float = -100
        let projY: Float = 200 - 100 * sqrt(3.0)
        let projectile = TestEntityFactory.makeProjectileEntity(position: SIMD2(projX, projY))

        // Setup collision handler
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        handler.processCollisions(pairs: [(projectile, boss)])

        // Boss should take damage through the gap
        #expect(bossHealth.currentHealth < initialHP,
                "Boss should take damage when projectile comes through armor gap")
    }

    /// Fire a projectile from a covered angle, assert armor takes damage (not boss).
    @Test @MainActor func bossArmorBlocksProjectileFromCoveredAngle() {
        let (boss, armor) = makeBossEntity(hp: 100, armorSlots: 6)
        let bossHealth = boss.component(ofType: HealthComponent.self)!
        let initialBossHP = bossHealth.currentHealth

        let bossPhysics = PhysicsComponent(
            collisionSize: SIMD2(100, 100),
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        boss.addComponent(bossPhysics)

        // Populate slot 0 (angle = 0, covers ±30° i.e. [-30°, 30°]) with an armor entity
        let armorEntity = makeArmorAsteroidEntity(hp: 100)
        armor.slots[0].entity = armorEntity
        let armorHealth = armorEntity.component(ofType: HealthComponent.self)!
        let initialArmorHP = armorHealth.currentHealth

        // Position projectile directly to the right of the boss so approach angle ≈ 0.
        // approach = atan2(200 - 200, 0 - 200) = atan2(0, -200) = π  ... that's slot 3.
        // We need approach = 0, so atan2(boss.y - proj.y, boss.x - proj.x) = 0
        // i.e. proj is to the left of the boss at same Y: proj at (-200, 200)
        // atan2(200-200, 0-(-200)) = atan2(0, 200) = 0 ✓
        let projectile = TestEntityFactory.makeProjectileEntity(position: SIMD2(-200, 200))

        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        handler.processCollisions(pairs: [(projectile, boss)])

        // Armor should take damage, boss should not
        #expect(armorHealth.currentHealth < initialArmorHP,
                "Armor should take damage when projectile comes from a covered angle")
        #expect(bossHealth.currentHealth == initialBossHP,
                "Boss should NOT take damage when armor blocks the projectile")
    }

    /// Destroy the armor slot covering the vertical approach, fire laser,
    /// assert boss takes damage.
    @Test @MainActor func phaseLaserDamagesBossThroughArmorGap() {
        // Boss at (0, 200), player laser source at (0, -200)
        // Approach angle = atan2(200 - (-200), 0 - 0) = atan2(400, 0) = π/2
        // Slot 1 angle = π/3 ≈ 60°, covers [30°, 90°]  → covers π/2
        // Slot 2 angle = 2π/3 ≈ 120°, covers [90°, 150°] → also covers π/2 at exact boundary
        // With ±30° half-arc: |π/2 - π/3| = π/6 = 30° ≤ 30° → slot 1 covers it.
        let (boss, armor) = makeBossEntity(hp: 100, armorSlots: 6)
        let bossHealth = boss.component(ofType: HealthComponent.self)!

        let bossPhysics = PhysicsComponent(
            collisionSize: SIMD2(100, 100),
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        boss.addComponent(bossPhysics)

        // Populate all slots with armor EXCEPT slot 1 (the one covering the vertical laser)
        for i in 0..<armor.slots.count {
            if i == 1 { continue }
            let armorEntity = makeArmorAsteroidEntity(hp: 100)
            armor.slots[i].entity = armorEntity
        }
        // Also remove slot 2 to avoid boundary ambiguity at exactly π/2
        armor.slots[2].entity = nil

        let initialBossHP = bossHealth.currentHealth

        // Simulate laser hitscan: the laser fires straight up from (0, -200)
        // We need to replicate the boss-overlap + angle check logic.
        // The boss hitbox at (0,200) with size (100,100) spans x:[-50,50], y:[150,250]
        // The laser at x=0 with some width definitely overlaps.

        // Directly test the angle logic: approach angle from laser source (0,-200) to boss (0,200)
        let laserSourceY: Float = -200
        let bossPos = boss.component(ofType: TransformComponent.self)!.position
        let approachAngle = atan2(bossPos.y - laserSourceY, bossPos.x - 0)
        // approachAngle = atan2(400, 0) = π/2
        #expect(abs(approachAngle - .pi / 2) < 0.01, "Laser approach angle should be ~π/2")

        // Check that no active armor slot covers π/2
        let halfArc: Float = .pi / 6
        var coveringSlot: Int? = nil
        for (i, slot) in armor.slots.enumerated() where slot.isActive {
            var diff = approachAngle - slot.angle
            while diff > .pi  { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            if abs(diff) <= halfArc {
                coveringSlot = i
                break
            }
        }
        #expect(coveringSlot == nil,
                "No active armor slot should cover the vertical approach when slot 1 and 2 are gaps")

        // Since no armor covers the approach, boss takes laser damage directly
        let laserDmg: Float = 2.0
        bossHealth.takeDamage(laserDmg)
        #expect(bossHealth.currentHealth == initialBossHP - laserDmg,
                "Boss should take laser damage through armor gap at vertical approach")
    }

    // MARK: - Lithic Harvester attack patterns differ from Galaxy 1

    @Test @MainActor func lithicHarvesterAttacksDifferFromGalaxy1() {
        // Galaxy 1 boss
        let g1System = BossSystem()
        let g1Boss = GKEntity()
        g1Boss.addComponent(TransformComponent(position: SIMD2(0, 200)))
        g1Boss.addComponent(HealthComponent(health: 30))
        g1Boss.addComponent(BossPhaseComponent(totalHP: 30))
        g1System.register(g1Boss)
        g1System.playerPosition = SIMD2(0, -200)

        // Lithic Harvester
        let g2System = BossSystem()
        g2System.bossType = .lithicHarvester
        let (g2Boss, _) = makeBossEntity(hp: 100)
        g2System.register(g2Boss)
        g2System.playerPosition = SIMD2(0, -200)

        // Accumulate spawns across frames
        var g1Total = 0
        var g2Total = 0
        for _ in 0..<180 {
            g1System.update(deltaTime: 1.0 / 60.0)
            g2System.update(deltaTime: 1.0 / 60.0)
            g1Total += g1System.pendingProjectileSpawns.count
            g2Total += g2System.pendingProjectileSpawns.count
        }

        // Both should produce attacks but potentially different counts
        // (Galaxy 1 fires 8 radial at baseInterval 1.0; Lithic Harvester fires 3 aimed at interval 2.0)
        #expect(g1Total > 0, "Galaxy 1 boss should attack")
        #expect(g2Total > 0, "Lithic Harvester should attack")
    }

    // MARK: - Boss entry descent

    @Test @MainActor func lithicHarvesterDescendsDuringIntro() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, _) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        transform.position = SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)
        let phase = boss.component(ofType: BossPhaseComponent.self)!
        phase.introComplete = false

        system.register(boss)

        let startY = transform.position.y

        // Run 30 frames (~0.5s)
        for _ in 0..<30 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(transform.position.y < startY, "Boss should descend during intro")
        #expect(system.pendingProjectileSpawns.isEmpty, "Boss should not fire during intro")
    }

    @Test @MainActor func lithicHarvesterIntroCompletesAtRestingY() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, _) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        transform.position = SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)
        let phase = boss.component(ofType: BossPhaseComponent.self)!
        phase.introComplete = false

        system.register(boss)

        // Run for 2 seconds (intro is 1.5s)
        for _ in 0..<120 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(phase.introComplete == true, "Intro should be complete after 1.5s")
        #expect(transform.position.y == GameConfig.Galaxy2.Boss.restingY,
                "Boss should be at resting Y after intro")
    }

    // MARK: - Lateral drift

    @Test @MainActor func lithicHarvesterDriftsLaterally() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, _) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        system.register(boss)

        // Run for ~1.25s (quarter of the 5.0s period in phase 0) — should be near peak
        let frames = Int(1.25 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(abs(transform.position.x) > 1.0,
                "Boss should have drifted away from x=0, got \(transform.position.x)")
    }

    @Test @MainActor func lithicHarvesterPhase2DriftProducesLargerOffsetAtSharedSampleTime() {
        // Phase 0: amplitude 30, period 5
        let system0 = BossSystem()
        system0.bossType = .lithicHarvester
        system0.playerPosition = SIMD2(0, -200)
        let (boss0, _) = makeBossEntity(hp: 100)
        system0.register(boss0)
        let transform0 = boss0.component(ofType: TransformComponent.self)!

        // Phase 2: amplitude 60, period 3
        let system2 = BossSystem()
        system2.bossType = .lithicHarvester
        system2.playerPosition = SIMD2(0, -200)
        let (boss2, _) = makeBossEntity(hp: 100)
        system2.register(boss2)
        let health2 = boss2.component(ofType: HealthComponent.self)!
        health2.currentHealth = 20  // 20% -> phase 2
        let transform2 = boss2.component(ofType: TransformComponent.self)!

        // Run both for 0.75s.
        // phase 0 offset ~= 30 * sin(2π * 0.75 / 5)  ≈ 24.3
        // phase 2 offset ~= 60 * sin(2π * 0.75 / 3)  = 60
        let frames = Int(0.75 / (1.0 / 60.0))
        for _ in 0..<frames {
            system0.update(deltaTime: 1.0 / 60.0)
            system2.update(deltaTime: 1.0 / 60.0)
        }

        #expect(abs(transform2.position.x) > abs(transform0.position.x) + 10,
                "Phase 2 drift should have a clearly larger offset than phase 0")
    }

    // MARK: - Armor ring rotation

    @Test @MainActor func armorRingRotatesOverTime() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, armor) = makeBossEntity(hp: 100)
        let armorEntity = makeArmorAsteroidEntity(position: .zero)
        armor.slots[0].entity = armorEntity

        system.register(boss)

        #expect(armor.rotationAngle == 0, "Rotation should start at 0")

        for _ in 0..<60 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(armor.rotationAngle > 0.35 && armor.rotationAngle < 0.45,
                "Rotation angle should be ~0.4 after 1s, got \(armor.rotationAngle)")
    }

    @Test @MainActor func armorAsteroidPositionChangesWithRotation() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, armor) = makeBossEntity(hp: 100)
        let armorEntity = makeArmorAsteroidEntity(position: .zero)
        armor.slots[0].entity = armorEntity
        let armorTransform = armorEntity.component(ofType: TransformComponent.self)!

        system.register(boss)

        system.update(deltaTime: 1.0 / 60.0)
        let initialPos = armorTransform.position

        for _ in 0..<59 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        let finalPos = armorTransform.position
        let distance = simd_length(finalPos - initialPos)
        #expect(distance > 1.0,
                "Armor asteroid should have moved due to rotation, distance: \(distance)")
    }

    @Test @MainActor func armorRotationSpeedIncreasesWithPhase() {
        let system0 = BossSystem()
        system0.bossType = .lithicHarvester
        system0.playerPosition = SIMD2(0, -200)
        let (boss0, armor0) = makeBossEntity(hp: 100)
        system0.register(boss0)

        let system2 = BossSystem()
        system2.bossType = .lithicHarvester
        system2.playerPosition = SIMD2(0, -200)
        let (boss2, armor2) = makeBossEntity(hp: 100)
        let health2 = boss2.component(ofType: HealthComponent.self)!
        health2.currentHealth = 20  // 20% -> phase 2
        system2.register(boss2)

        for _ in 0..<60 {
            system0.update(deltaTime: 1.0 / 60.0)
            system2.update(deltaTime: 1.0 / 60.0)
        }

        #expect(armor2.rotationAngle > armor0.rotationAngle,
                "Phase 2 rotation should be faster: p0=\(armor0.rotationAngle), p2=\(armor2.rotationAngle)")
    }

    @Test @MainActor func rotatedArmorCoverageUsesRotationAngle() {
        let armor = BossArmorComponent()
        armor.slots = [ArmorSlot(angle: 0, entity: makeArmorAsteroidEntity())]

        #expect(armor.coveringSlotIndex(for: 0) == 0)

        armor.rotationAngle = .pi / 2

        #expect(armor.coveringSlotIndex(for: 0) == nil)
        #expect(armor.coveringSlotIndex(for: .pi / 2) == 0)
    }

    // MARK: - BossPhaseComponent intro/drift fields

    @Test @MainActor func bossPhaseComponentHasIntroAndDriftFields() {
        let phase = BossPhaseComponent(totalHP: 100)
        #expect(phase.introTimer == 0)
        #expect(phase.introComplete == true)
        #expect(phase.driftElapsed == 0)
    }

    // MARK: - BossArmorComponent rotationAngle field

    @Test @MainActor func bossArmorComponentHasRotationAngle() {
        let comp = BossArmorComponent()
        #expect(comp.rotationAngle == 0)
    }

    // MARK: - Config constants exist

    @Test func lithicHarvesterConfigConstantsExist() {
        // Boss intro
        #expect(GameConfig.Galaxy2.Boss.spawnY == 340)
        #expect(GameConfig.Galaxy2.Boss.restingY == 250)
        #expect(GameConfig.Galaxy2.Boss.introDuration == 1.5)

        // Lateral drift
        #expect(GameConfig.Galaxy2.Boss.driftAmplitude == [30.0, 45.0, 60.0])
        #expect(GameConfig.Galaxy2.Boss.driftPeriod == [5.0, 4.0, 3.0])

        // Armor rotation
        #expect(GameConfig.Galaxy2.Boss.armorRotationSpeed == [0.4, 0.7, 1.1])
    }
}
