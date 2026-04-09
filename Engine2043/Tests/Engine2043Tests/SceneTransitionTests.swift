import Testing
import simd
@testable import Engine2043

struct SceneTransitionTests {
    @Test @MainActor func titleSceneRequestsGameOnInput() {
        let scene = TitleScene()
        let input = MockInputProvider(primary: true)
        scene.inputProvider = input

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        while time.shouldPerformFixedUpdate() {
            scene.fixedUpdate(time: time)
            time.consumeFixedUpdate()
        }

        #expect(scene.requestedTransition != nil)
    }

    @Test @MainActor func gameOverSceneStartsWithNoTransition() {
        let result = GameResult(finalScore: 1000, enemiesDestroyed: 5, elapsedTime: 60.0, didWin: false)
        let scene = GameOverScene(result: result)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func victorySceneStartsWithNoTransition() {
        let result = GameResult(finalScore: 5000, enemiesDestroyed: 47, elapsedTime: 180.0, didWin: true)
        let scene = VictoryScene(result: result)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func gameResultPreservesData() {
        let result = GameResult(finalScore: 12345, enemiesDestroyed: 42, elapsedTime: 123.45, didWin: true)
        #expect(result.finalScore == 12345)
        #expect(result.enemiesDestroyed == 42)
        #expect(result.elapsedTime == 123.45)
        #expect(result.didWin == true)
    }

    @Test func toGalaxy3TransitionCarriesPlayerState() {
        let carryover = PlayerCarryover(
            weaponType: .lightningArc,
            score: 8000,
            secondaryCharges: 3,
            shieldDroneCount: 1,
            enemiesDestroyed: 55,
            elapsedTime: 200.0
        )
        let transition = SceneTransition.toGalaxy3(carryover)

        if case .toGalaxy3(let carried) = transition {
            #expect(carried.weaponType == .lightningArc)
            #expect(carried.score == 8000)
            #expect(carried.secondaryCharges == 3)
            #expect(carried.shieldDroneCount == 1)
            #expect(carried.enemiesDestroyed == 55)
            #expect(carried.elapsedTime == 200.0)
        } else {
            #expect(Bool(false), "Expected .toGalaxy3 case")
        }
    }
}
