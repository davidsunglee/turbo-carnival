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
            #expect(carried?.weaponType == .lightningArc)
            #expect(carried?.score == 8000)
            #expect(carried?.secondaryCharges == 3)
            #expect(carried?.shieldDroneCount == 1)
            #expect(carried?.enemiesDestroyed == 55)
            #expect(carried?.elapsedTime == 200.0)
        } else {
            #expect(Bool(false), "Expected .toGalaxy3 case")
        }
    }

    // MARK: - All SceneTransition Enum Cases

    @Test func allSceneTransitionCasesCanBeConstructed() {
        let result = GameResult(finalScore: 100, enemiesDestroyed: 5, elapsedTime: 30.0, didWin: false)
        let carryover = PlayerCarryover(
            weaponType: .doubleCannon, score: 0, secondaryCharges: 0,
            shieldDroneCount: 0, enemiesDestroyed: 0, elapsedTime: 0
        )

        // Verify every case can be constructed without error
        let transitions: [SceneTransition] = [
            .toGame,
            .toTitle,
            .toGalaxySelect,
            .toGameOver(result),
            .toVictory(result),
            .toGalaxy2(carryover),
            .toGalaxy3(carryover),
        ]
        #expect(transitions.count == 7, "All 7 transition cases should exist")
    }

    @Test func toVictoryTransitionPreservesResult() {
        let result = GameResult(finalScore: 30000, enemiesDestroyed: 150, elapsedTime: 900.0, didWin: true)
        let transition = SceneTransition.toVictory(result)

        if case .toVictory(let stored) = transition {
            #expect(stored.finalScore == 30000)
            #expect(stored.enemiesDestroyed == 150)
            #expect(stored.elapsedTime == 900.0)
            #expect(stored.didWin == true)
        } else {
            #expect(Bool(false), "Expected .toVictory case")
        }
    }

    @Test func toGalaxy2TransitionPreservesCarryover() {
        let carryover = PlayerCarryover(
            weaponType: .phaseLaser, score: 4500, secondaryCharges: 2,
            shieldDroneCount: 1, enemiesDestroyed: 30, elapsedTime: 90.0
        )
        let transition = SceneTransition.toGalaxy2(carryover)

        if case .toGalaxy2(let carried) = transition {
            #expect(carried?.weaponType == .phaseLaser)
            #expect(carried?.score == 4500)
            #expect(carried?.shieldDroneCount == 1)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2 case")
        }
    }

    @Test func toGalaxySelectTransitionExists() {
        let transition = SceneTransition.toGalaxySelect
        if case .toGalaxySelect = transition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toGalaxySelect case")
        }
    }

    @Test func toGalaxy2AcceptsNilCarryover() {
        let transition = SceneTransition.toGalaxy2(nil)
        if case .toGalaxy2(let carryover) = transition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2 case")
        }
    }

    @Test func toGalaxy3AcceptsNilCarryover() {
        let transition = SceneTransition.toGalaxy3(nil)
        if case .toGalaxy3(let carryover) = transition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy3 case")
        }
    }

    @Test @MainActor func galaxy2SceneAcceptsNilCarryover() {
        let scene = Galaxy2Scene(carryover: nil)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func galaxy3SceneAcceptsNilCarryover() {
        let scene = Galaxy3Scene(carryover: nil)
        #expect(scene.requestedTransition == nil)
    }
}
