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
        #expect(item.itemType == .energyCell)

        item.advanceCycle()
        #expect(item.currentCycleIndex == 1)
        #expect(item.itemType == .weaponModule)

        item.advanceCycle()
        #expect(item.currentCycleIndex == 0)
        #expect(item.itemType == .energyCell)
    }

    @Test func itemComponentDespawnTimer() {
        let item = ItemComponent()
        #expect(item.timeAlive == 0)
        item.timeAlive = 8.0
        #expect(item.shouldDespawn)
    }
}
