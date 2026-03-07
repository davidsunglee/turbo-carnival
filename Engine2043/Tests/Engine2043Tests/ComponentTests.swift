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
        #expect(item.utilityItemType == .scoreBonus)

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
}
