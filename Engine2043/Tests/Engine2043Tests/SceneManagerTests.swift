import Testing
import Metal
import simd
@testable import Engine2043

@MainActor
private final class StubScene: GameScene {
    var requestedTransition: SceneTransition?
    func fixedUpdate(time: GameTime) {}
    func update(time: GameTime) {}
    func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] { [] }
}

struct SceneManagerTests {

    @MainActor
    private func makeManager() -> (SceneManager, GameEngine) {
        let engine = GameEngine()
        return (SceneManager(engine: engine), engine)
    }

    @Test @MainActor func transitionProgressStartsAtZero() {
        let (manager, _) = makeManager()

        #expect(manager.isTransitioning == false)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func checkForTransitionIgnoresNilRequest() {
        let (manager, engine) = makeManager()

        let scene = StubScene()
        scene.requestedTransition = nil
        engine.currentScene = scene

        manager.checkForTransition()
        #expect(manager.isTransitioning == false)
    }

    @Test @MainActor func checkForTransitionStartsFadeOut() {
        let (manager, engine) = makeManager()

        let scene = StubScene()
        scene.requestedTransition = .toTitle
        engine.currentScene = scene

        manager.checkForTransition()
        #expect(manager.isTransitioning == true)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func transitionCallsCorrectFactory() {
        let (manager, engine) = makeManager()

        var titleFactoryCalled = false
        let titleScene = StubScene()
        manager.makeTitleScene = {
            titleFactoryCalled = true
            return titleScene
        }

        let gameScene = StubScene()
        gameScene.requestedTransition = .toTitle
        engine.currentScene = gameScene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(titleFactoryCalled)
        #expect(engine.currentScene as AnyObject === titleScene)
    }

    @Test @MainActor func transitionCompletesAndResetsState() {
        let (manager, engine) = makeManager()

        manager.makeTitleScene = { StubScene() }

        let scene = StubScene()
        scene.requestedTransition = .toTitle
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)
        manager.updateTransition(deltaTime: 0.25)

        #expect(manager.isTransitioning == false)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func transitionProgressReachesPeakAtMidpoint() {
        let (manager, engine) = makeManager()

        manager.makeTitleScene = { StubScene() }

        let scene = StubScene()
        scene.requestedTransition = .toTitle
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.2)

        #expect(manager.isTransitioning == true)
    }

    @Test @MainActor func gameOverFactoryReceivesResult() {
        let (manager, engine) = makeManager()

        var receivedResult: GameResult?
        manager.makeGameOverScene = { result in
            receivedResult = result
            return StubScene()
        }

        let scene = StubScene()
        let expectedResult = GameResult(finalScore: 1000, enemiesDestroyed: 5, elapsedTime: 60.0, didWin: false)
        scene.requestedTransition = .toGameOver(expectedResult)
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(receivedResult?.finalScore == 1000)
        #expect(receivedResult?.enemiesDestroyed == 5)
    }

    @Test @MainActor func noTransitionUpdateWhenNotTransitioning() {
        let (manager, _) = makeManager()

        manager.updateTransition(deltaTime: 1.0)
        #expect(manager.isTransitioning == false)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func galaxy3TransitionCallsFactory() {
        let (manager, engine) = makeManager()

        var galaxy3FactoryCalled = false
        var receivedCarryover: PlayerCarryover?
        let galaxy3Scene = StubScene()
        manager.makeGalaxy3Scene = { carryover in
            galaxy3FactoryCalled = true
            receivedCarryover = carryover
            return galaxy3Scene
        }

        let currentScene = StubScene()
        let carryover = PlayerCarryover(
            weaponType: .triSpread,
            score: 5000,
            secondaryCharges: 2,
            shieldDroneCount: 0,
            enemiesDestroyed: 40,
            elapsedTime: 120.0
        )
        currentScene.requestedTransition = .toGalaxy3(carryover)
        engine.currentScene = currentScene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(galaxy3FactoryCalled)
        #expect(receivedCarryover?.score == 5000)
        #expect(receivedCarryover?.weaponType == .triSpread)
        #expect(engine.currentScene as AnyObject === galaxy3Scene)
    }

    // MARK: - All Transition Types Regression

    @Test @MainActor func toGameTransitionCallsFactory() {
        let (manager, engine) = makeManager()

        var gameFactoryCalled = false
        let gameScene = StubScene()
        manager.makeGameScene = {
            gameFactoryCalled = true
            return gameScene
        }

        let scene = StubScene()
        scene.requestedTransition = .toGame
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(gameFactoryCalled)
        #expect(engine.currentScene as AnyObject === gameScene)
    }

    @Test @MainActor func victoryTransitionCallsFactoryWithResult() {
        let (manager, engine) = makeManager()

        var receivedResult: GameResult?
        let victoryScene = StubScene()
        manager.makeVictoryScene = { result in
            receivedResult = result
            return victoryScene
        }

        let scene = StubScene()
        let expectedResult = GameResult(finalScore: 25000, enemiesDestroyed: 120, elapsedTime: 600.0, didWin: true)
        scene.requestedTransition = .toVictory(expectedResult)
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(receivedResult?.finalScore == 25000)
        #expect(receivedResult?.didWin == true)
        #expect(engine.currentScene as AnyObject === victoryScene)
    }

    @Test @MainActor func galaxy2TransitionCallsFactory() {
        let (manager, engine) = makeManager()

        var receivedCarryover: PlayerCarryover?
        let galaxy2Scene = StubScene()
        manager.makeGalaxy2Scene = { carryover in
            receivedCarryover = carryover
            return galaxy2Scene
        }

        let scene = StubScene()
        let carryover = PlayerCarryover(
            weaponType: .doubleCannon,
            score: 3000,
            secondaryCharges: 1,
            shieldDroneCount: 0,
            enemiesDestroyed: 25,
            elapsedTime: 90.0
        )
        scene.requestedTransition = .toGalaxy2(carryover)
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(receivedCarryover?.score == 3000)
        #expect(receivedCarryover?.weaponType == .doubleCannon)
        #expect(engine.currentScene as AnyObject === galaxy2Scene)
    }
}
