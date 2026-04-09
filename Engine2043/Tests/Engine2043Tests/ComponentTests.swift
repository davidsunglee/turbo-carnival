import Testing
import simd
@testable import Engine2043

struct ComponentTests {
    @Test func scoreComponentDefaults() {
        let score = ScoreComponent(points: 50)
        #expect(score.points == 50)
    }

    @Test func itemComponentCycling() {
        let item = ItemComponent()
        #expect(item.currentCycleIndex == 0)
        #expect(item.utilityItemType == .energyCell)

        item.advanceCycle()
        #expect(item.currentCycleIndex == 1)
        #expect(item.utilityItemType == .chargeCell)

        item.advanceCycle()
        #expect(item.currentCycleIndex == 2)
        #expect(item.utilityItemType == .orbitingShield)

        item.advanceCycle()
        #expect(item.currentCycleIndex == 0)
        #expect(item.utilityItemType == .energyCell)
    }

    @Test func itemComponentDespawnTimer() {
        let item = ItemComponent()
        #expect(item.timeAlive == 0)
        item.timeAlive = 8.0
        #expect(item.shouldDespawn)
    }

    @Test func formationComponentDefaults() {
        let formation = FormationComponent(pattern: .sineWave, index: 2, formationID: 1)
        #expect(formation.pattern == .sineWave)
        #expect(formation.index == 2)
        #expect(formation.formationID == 1)
        #expect(formation.phaseOffset == 0)
    }

    @Test func steeringComponentDefaults() {
        let steering = SteeringComponent(behavior: .hover)
        #expect(steering.behavior == .hover)
        #expect(steering.hoverY == Float(100))
        #expect(steering.steerStrength == Float(2.0))
    }

    @Test func turretComponentTracking() {
        let turret = TurretComponent(trackingSpeed: 2.0)
        #expect(turret.trackingSpeed == 2.0)
        #expect(turret.fireInterval == 1.5)
        #expect(turret.timeSinceLastShot == 0)
    }

    @Test func renderComponentSpriteId() {
        let rc = RenderComponent(size: SIMD2(32, 32), color: SIMD4(1, 1, 1, 1))
        #expect(rc.spriteId == nil)

        rc.spriteId = "player"
        #expect(rc.spriteId == "player")
    }

    @Test func bossPhaseComponentTransitions() {
        let boss = BossPhaseComponent(totalHP: 30)
        #expect(boss.currentPhase == 0)
        #expect(boss.phaseThresholds == [0.6, 0.3])

        boss.updatePhase(healthFraction: 1.0)
        #expect(boss.currentPhase == 0)

        boss.updatePhase(healthFraction: 0.5)
        #expect(boss.currentPhase == 1)

        boss.updatePhase(healthFraction: 0.2)
        #expect(boss.currentPhase == 2)
    }

    // MARK: - BarrierComponent

    @Test func barrierComponentTrenchWallDefaults() {
        let barrier = BarrierComponent(kind: .trenchWall)
        #expect(barrier.kind == .trenchWall)
        #expect(barrier.contactDamage == GameConfig.Galaxy3.Barrier.collisionDamage)
        #expect(barrier.rotationSpeed == 0)
        #expect(barrier.currentAngle == 0)
    }

    @Test func barrierComponentRotatingGate() {
        let barrier = BarrierComponent(kind: .rotatingGate)
        #expect(barrier.kind == .rotatingGate)
        #expect(barrier.rotationSpeed == GameConfig.Galaxy3.Barrier.rotatingGateSpeed)
    }

    // MARK: - FortressNodeComponent

    @Test func fortressNodeShieldGenerator() {
        let node = FortressNodeComponent(role: .shieldGenerator, fortressID: 1)
        #expect(node.role == .shieldGenerator)
        #expect(node.fortressID == 1)
        #expect(node.isShielded == true)
        #expect(node.fireInterval == 0)
    }

    @Test func fortressNodeMainBattery() {
        let node = FortressNodeComponent(role: .mainBattery, fortressID: 2)
        #expect(node.role == .mainBattery)
        #expect(node.fortressID == 2)
        #expect(node.fireInterval == 2.5)
        #expect(node.timeSinceLastShot == 0)
    }

    @Test func fortressNodePulseTurret() {
        let node = FortressNodeComponent(role: .pulseTurret, fortressID: 3)
        #expect(node.role == .pulseTurret)
        #expect(node.fireInterval == 1.5)
    }

    // MARK: - ProjectileComponent

    @Test func projectileComponentDefaults() {
        let proj = ProjectileComponent(damage: 2.0, speed: 250)
        #expect(proj.damage == 2.0)
        #expect(proj.speed == 250)
        #expect(proj.effects == [])
        #expect(proj.lifetime == 5.0)
        #expect(proj.age == 0)
        #expect(proj.isHoming == false)
        #expect(proj.isExpired == false)
    }

    @Test func projectileComponentExpiration() {
        let proj = ProjectileComponent(damage: 1.0, speed: 300)
        proj.age = 5.0
        #expect(proj.isExpired == true)
    }

    @Test func projectileComponentEmpEffect() {
        let proj = ProjectileComponent(damage: 1.0, speed: 200, effects: .empDisable)
        #expect(proj.effects.contains(.empDisable))
    }

    @Test func projectileComponentHomingSetup() {
        let proj = ProjectileComponent(damage: 1.0, speed: 160)
        proj.isHoming = true
        proj.homingTurnRate = 2.5
        proj.lifetime = GameConfig.Galaxy3.BossAttack.homingMissileLifetime
        #expect(proj.isHoming == true)
        #expect(proj.homingTurnRate == 2.5)
        #expect(proj.lifetime == 5.0)
    }

    // MARK: - ZenithBossComponent

    @Test func zenithBossComponentDefaults() {
        let boss = ZenithBossComponent()
        #expect(boss.currentPhase == .intro)
        #expect(boss.isShieldActive == false)
        #expect(boss.scrollLockRequested == false)
        #expect(boss.isDefeated == false)
        #expect(boss.phaseThresholds == [0.75, 0.50, 0.25])
    }

    @Test func zenithBossPhaseTransitions() {
        let boss = ZenithBossComponent()

        // Full health -> phase 1
        boss.updatePhase(healthFraction: 1.0)
        #expect(boss.currentPhase == .phase1)

        // At 75% threshold -> phase 2
        boss.updatePhase(healthFraction: 0.75)
        #expect(boss.currentPhase == .phase2)

        // Below 50% -> phase 3
        boss.updatePhase(healthFraction: 0.45)
        #expect(boss.currentPhase == .phase3)

        // Below 25% -> phase 4
        boss.updatePhase(healthFraction: 0.20)
        #expect(boss.currentPhase == .phase4)
    }

    @Test func zenithBossDefeatedLocksPhase() {
        let boss = ZenithBossComponent()
        boss.currentPhase = .defeated
        boss.isDefeated = true

        boss.updatePhase(healthFraction: 0.0)
        #expect(boss.currentPhase == .defeated)
    }

    // MARK: - ProjectileSpawnRequest Extended Fields

    @Test func projectileSpawnRequestBackwardCompatibility() {
        // Creating without new fields should use safe defaults
        let req = ProjectileSpawnRequest(position: .zero, velocity: SIMD2(0, -200), damage: 5)
        #expect(req.effects == [])
        #expect(req.isHoming == false)
        #expect(req.homingTurnRate == 0)
        #expect(req.lifetime == 5.0)
        #expect(req.damage == 5)
    }

    @Test func projectileSpawnRequestHomingFields() {
        let req = ProjectileSpawnRequest(
            position: SIMD2(10, 20), velocity: SIMD2(0, -100), damage: 8,
            isHoming: true, homingTurnRate: 2.5, lifetime: 3.0
        )
        #expect(req.isHoming == true)
        #expect(req.homingTurnRate == 2.5)
        #expect(req.lifetime == 3.0)
        #expect(req.position == SIMD2<Float>(10, 20))
    }

    @Test func projectileSpawnRequestEmpEffects() {
        let req = ProjectileSpawnRequest(
            position: .zero, velocity: SIMD2(0, -200), damage: 5, effects: .empDisable
        )
        #expect(req.effects.contains(.empDisable))
        #expect(req.isHoming == false)
    }

    // MARK: - ZenithBossComponent Timer Defaults

    @Test func zenithBossTimerFieldsAllStartAtZero() {
        let boss = ZenithBossComponent()
        #expect(boss.attackTimer == 0)
        #expect(boss.shieldTimer == 0)
        #expect(boss.shieldCooldownTimer == 0)
        #expect(boss.empTimer == 0)
        #expect(boss.introTimer == 0)
        #expect(boss.spiralAngle == 0)
    }

    @Test func zenithBossLastPhaseStartsAsIntro() {
        let boss = ZenithBossComponent()
        #expect(boss.lastPhase == .intro)
    }

    // MARK: - ZenithPhase Enum Raw Values

    @Test func zenithPhaseRawValuesAreSequential() {
        #expect(ZenithPhase.intro.rawValue == 0)
        #expect(ZenithPhase.phase1.rawValue == 1)
        #expect(ZenithPhase.phase2.rawValue == 2)
        #expect(ZenithPhase.phase3.rawValue == 3)
        #expect(ZenithPhase.phase4.rawValue == 4)
        #expect(ZenithPhase.defeated.rawValue == 5)
    }

    // MARK: - BarrierComponent Edge Cases

    @Test func barrierComponentContactDamageMatchesConfig() {
        let trench = BarrierComponent(kind: .trenchWall)
        let gate = BarrierComponent(kind: .rotatingGate)
        // Both barrier kinds use the same collision damage from config
        #expect(trench.contactDamage == gate.contactDamage)
        #expect(trench.contactDamage == GameConfig.Galaxy3.Barrier.collisionDamage)
    }

    // MARK: - ProjectileComponent Multiple Effects

    @Test func projectileComponentDefaultsDoNotExpire() {
        let proj = ProjectileComponent(damage: 1.0, speed: 300)
        #expect(proj.age == 0)
        #expect(proj.isExpired == false)
        #expect(proj.lifetime == 5.0)
    }

    @Test func projectileComponentCustomLifetime() {
        let proj = ProjectileComponent(damage: 1.0, speed: 300)
        proj.lifetime = 2.0
        proj.age = 1.9
        #expect(proj.isExpired == false)
        proj.age = 2.0
        #expect(proj.isExpired == true)
    }
}
