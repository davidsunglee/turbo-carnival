import Testing
import GameplayKit
import simd
@testable import Engine2043

struct Galaxy1SceneIntegrationTests {

    @MainActor
    private func runFrames(_ scene: Galaxy1Scene, count: Int) {
        var time = GameTime()
        for _ in 0..<count {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }
    }

    @Test @MainActor func playerMovementProducesSprites() {
        let scene = Galaxy1Scene()
        let input = MockInputProvider(movement: SIMD2(1, 0))
        scene.inputProvider = input

        runFrames(scene, count: 30)
        let sprites = scene.collectSprites(atlas: nil)

        #expect(sprites.count > 0)
    }

    @Test @MainActor func firingIncreasesTotalSpriteCount() {
        let scene = Galaxy1Scene()
        let noFireInput = MockInputProvider()
        scene.inputProvider = noFireInput

        runFrames(scene, count: 10)
        let baselineCount = scene.collectSprites(atlas: nil).count

        let fireInput = MockInputProvider(primary: true)
        scene.inputProvider = fireInput
        runFrames(scene, count: 20)
        let firingCount = scene.collectSprites(atlas: nil).count

        #expect(firingCount > baselineCount)
    }

    @Test @MainActor func gameStartsInPlayingState() {
        let scene = Galaxy1Scene()
        #expect(scene.gameState == .playing)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func elapsedTimeAdvancesWithFrames() {
        let scene = Galaxy1Scene()
        runFrames(scene, count: 60)
        #expect(scene.elapsedTime > 0.5)
    }

    @Test @MainActor func sceneRunsStablyFor300Frames() {
        let scene = Galaxy1Scene()
        let input = MockInputProvider(movement: SIMD2(0.5, 0), primary: true)
        scene.inputProvider = input

        runFrames(scene, count: 300)

        #expect(scene.gameState == .playing)
        let sprites = scene.collectSprites(atlas: nil)
        #expect(sprites.count > 0)
    }

    @Test @MainActor func gameResultReflectsCurrentState() {
        let scene = Galaxy1Scene()
        runFrames(scene, count: 10)

        let result = scene.gameResult
        #expect(result.finalScore >= 0)
        #expect(result.elapsedTime > 0)
        #expect(result.didWin == false)
    }
}
