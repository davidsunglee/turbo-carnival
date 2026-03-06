import Testing
import GameplayKit
import simd
@testable import Engine2043

struct SystemTests {
    @Test @MainActor func scoreSystemAccumulatesPoints() {
        let system = ScoreSystem()
        #expect(system.currentScore == 0)

        system.addScore(10)
        system.addScore(50)
        #expect(system.currentScore == 60)
    }

    @Test @MainActor func scoreSystemResettable() {
        let system = ScoreSystem()
        system.addScore(100)
        system.reset()
        #expect(system.currentScore == 0)
    }
}
