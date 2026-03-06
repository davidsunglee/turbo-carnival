import Testing
import simd
@testable import Engine2043

struct SpawnDirectorTests {
    @Test @MainActor func spawnDirectorTriggersWavesAtScrollThresholds() {
        let director = SpawnDirector()
        #expect(director.pendingWaves.isEmpty)

        director.update(scrollDistance: 100)
        #expect(!director.pendingWaves.isEmpty)
        let firstWave = director.pendingWaves.first
        #expect(firstWave?.enemyTier == .tier1)
    }

    @Test @MainActor func spawnDirectorDoesNotDuplicateWaves() {
        let director = SpawnDirector()

        director.update(scrollDistance: 100)
        let count1 = director.pendingWaves.count

        // Call again at same distance — pending should be empty (already triggered)
        director.update(scrollDistance: 100)
        let count2 = director.pendingWaves.count

        #expect(count1 > 0)
        #expect(count2 == 0)
    }

    @Test @MainActor func spawnDirectorTriggersBoss() {
        let director = SpawnDirector()

        director.update(scrollDistance: 3500)
        let bossWave = director.pendingWaves.first(where: { $0.enemyTier == .boss })
        #expect(bossWave != nil)
        #expect(director.shouldLockScroll)
    }

    @Test @MainActor func spawnDirectorUnlocksScroll() {
        let director = SpawnDirector()

        director.update(scrollDistance: 3500)
        #expect(director.shouldLockScroll)

        director.unlockScroll()
        #expect(!director.shouldLockScroll)
    }

    @Test @MainActor func spawnDirectorProgressesThroughAllWaves() {
        let director = SpawnDirector()

        // Scroll far enough to trigger everything
        director.update(scrollDistance: 5000)

        // Should have triggered all waves including boss
        let hasTier1 = director.pendingWaves.contains(where: { $0.enemyTier == .tier1 })
        let hasTier2 = director.pendingWaves.contains(where: { $0.enemyTier == .tier2 })
        let hasTier3 = director.pendingWaves.contains(where: { $0.enemyTier == .tier3 })
        let hasBoss = director.pendingWaves.contains(where: { $0.enemyTier == .boss })

        #expect(hasTier1)
        #expect(hasTier2)
        #expect(hasTier3)
        #expect(hasBoss)
    }
}
