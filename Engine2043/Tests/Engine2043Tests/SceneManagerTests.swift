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
}
