import Testing
import simd
@testable import Engine2043

struct Galaxy2SpawnDirectorTests {

    // MARK: - Early Tier 1 Waves

    @Test @MainActor func galaxy2TriggersTier1WavesAtEarlyScrollDistances() {
        let director = SpawnDirector(galaxy: .galaxy2)
        #expect(director.pendingWaves.isEmpty)

        director.update(scrollDistance: 100)
        #expect(!director.pendingWaves.isEmpty)
        #expect(director.pendingWaves.allSatisfy { $0.enemyTier == .tier1 })
    }

    @Test @MainActor func galaxy2HasSineWavePatternInEarlyWaves() {
        let director = SpawnDirector(galaxy: .galaxy2)
        director.update(scrollDistance: 100)
        let hasSineWave = director.pendingWaves.contains { $0.pattern == .sineWave }
        #expect(hasSineWave)
    }

    // MARK: - Asteroid Field Triggers

    @Test @MainActor func galaxy2TriggersAsteroidFieldAtDistance200() {
        let director = SpawnDirector(galaxy: .galaxy2)
        director.update(scrollDistance: 200)
        #expect(!director.pendingAsteroidFields.isEmpty)
        let field = director.pendingAsteroidFields.first
        #expect(field?.triggerDistance == 200)
    }

    @Test @MainActor func galaxy2TriggersAllFiveAsteroidFields() {
        let director = SpawnDirector(galaxy: .galaxy2)

        // Advance step by step to collect all triggered fields
        var allTriggered: [AsteroidFieldDefinition] = []

        for distance: Float in [200, 600, 1000, 1500, 1900] {
            director.update(scrollDistance: distance)
            allTriggered.append(contentsOf: director.pendingAsteroidFields)
        }

        #expect(allTriggered.count == 5)
        let triggeredDistances = allTriggered.map { $0.triggerDistance }.sorted()
        #expect(triggeredDistances == [200, 600, 1000, 1500, 1900])
    }

    @Test @MainActor func galaxy2AsteroidFieldsHaveCorrectDensity() {
        let director = SpawnDirector(galaxy: .galaxy2)
        director.update(scrollDistance: 200)
        let field = director.pendingAsteroidFields.first
        #expect(field?.count == 12)
        #expect(field?.largeFraction == 0.3)
    }

    // MARK: - pendingAsteroidFields lifecycle

    @Test @MainActor func galaxy2PendingAsteroidFieldsClearedBetweenUpdates() {
        let director = SpawnDirector(galaxy: .galaxy2)

        director.update(scrollDistance: 200)
        #expect(!director.pendingAsteroidFields.isEmpty)

        // Second update at same distance — should be cleared (already triggered)
        director.update(scrollDistance: 200)
        #expect(director.pendingAsteroidFields.isEmpty)
    }

    @Test @MainActor func galaxy2MultipleAsteroidFieldsTriggerAtOnceWhenJumpingAhead() {
        let director = SpawnDirector(galaxy: .galaxy2)

        // Jump directly to 600 — should trigger both 200 and 600 in one update
        director.update(scrollDistance: 600)
        #expect(director.pendingAsteroidFields.count == 2)
    }

    // MARK: - Boss at final scroll distance

    @Test @MainActor func galaxy2TriggersBossAt2400() {
        let director = SpawnDirector(galaxy: .galaxy2)
        director.update(scrollDistance: 2400)
        let bossWave = director.pendingWaves.first(where: { $0.enemyTier == .boss })
        #expect(bossWave != nil)
        #expect(director.shouldLockScroll)
    }

    @Test @MainActor func galaxy2BossNotTriggeredBeforeFinalDistance() {
        let director = SpawnDirector(galaxy: .galaxy2)
        director.update(scrollDistance: 2399)
        let bossWave = director.pendingWaves.first(where: { $0.enemyTier == .boss })
        #expect(bossWave == nil)
        #expect(!director.shouldLockScroll)
    }

    // MARK: - Galaxy 1 backward compatibility

    @Test @MainActor func galaxy1HasEmptyAsteroidFields() {
        let director = SpawnDirector()   // uses default init → galaxy1
        director.update(scrollDistance: 5000)
        #expect(director.pendingAsteroidFields.isEmpty)
    }

    @Test @MainActor func galaxy1ExplicitConfigHasEmptyAsteroidFields() {
        let director = SpawnDirector(galaxy: .galaxy1)
        director.update(scrollDistance: 5000)
        #expect(director.pendingAsteroidFields.isEmpty)
    }

    @Test @MainActor func galaxy1DefaultInitBehaviorUnchanged() {
        let director = SpawnDirector()
        director.update(scrollDistance: 100)
        #expect(!director.pendingWaves.isEmpty)
        let first = director.pendingWaves.first
        #expect(first?.enemyTier == .tier1)
    }

    // MARK: - All 4 tiers represented in Galaxy 2

    @Test @MainActor func galaxy2HasAllFourTiersRepresented() {
        let director = SpawnDirector(galaxy: .galaxy2)
        director.update(scrollDistance: 5000)

        let hasTier1 = director.pendingWaves.contains { $0.enemyTier == .tier1 }
        let hasTier2 = director.pendingWaves.contains { $0.enemyTier == .tier2 }
        let hasTier3 = director.pendingWaves.contains { $0.enemyTier == .tier3 }
        let hasBoss  = director.pendingWaves.contains { $0.enemyTier == .boss }

        #expect(hasTier1)
        #expect(hasTier2)
        #expect(hasTier3)
        #expect(hasBoss)
    }

    @Test @MainActor func galaxy2Tier3WavesAppearInMiningBargeSection() {
        let director = SpawnDirector(galaxy: .galaxy2)

        // Advance up to just past tier-3 zone start; collect waves incrementally
        director.update(scrollDistance: 1199)
        let noTier3BeforeZone = director.pendingWaves.allSatisfy { $0.enemyTier != .tier3 }
        #expect(noTier3BeforeZone)

        director.update(scrollDistance: 1200)
        let hasTier3 = director.pendingWaves.contains { $0.enemyTier == .tier3 }
        #expect(hasTier3)
    }
}
