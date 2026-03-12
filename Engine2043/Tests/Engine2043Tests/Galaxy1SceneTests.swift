import Testing
import GameplayKit
import simd
@testable import Engine2043

struct Galaxy1SceneTests {
    @Test @MainActor func sceneInitializesWithPlayer() {
        let scene = Galaxy1Scene()
        let sprites = scene.collectSprites(atlas: nil)
        // Should have background sprites + player + HUD elements
        #expect(sprites.count > 0)
    }

    @Test @MainActor func sceneUpdatesWithoutCrash() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(1, 0), primary: true)
        scene.inputProvider = mockInput

        var time = GameTime()
        // Simulate several frames
        for _ in 0..<60 {
            time.advance(by: 1.0 / 60.0)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }

        let sprites = scene.collectSprites(atlas: nil)
        #expect(sprites.count > 0)
    }

    @Test @MainActor func sceneGameStateStartsAsPlaying() {
        let scene = Galaxy1Scene()
        #expect(scene.gameState == .playing)
    }

    @Test @MainActor func sceneRequestedTransitionIsNilInitially() {
        let scene = Galaxy1Scene()
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func sceneTracksEnemiesDestroyed() {
        let scene = Galaxy1Scene()
        #expect(scene.enemiesDestroyed == 0)
    }

    @Test @MainActor func sceneTracksElapsedTime() {
        let scene = Galaxy1Scene()
        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        while time.shouldPerformFixedUpdate() {
            scene.fixedUpdate(time: time)
            time.consumeFixedUpdate()
        }
        #expect(scene.elapsedTime > 0)
    }

    @Test @MainActor func sceneExposesGameResult() {
        let scene = Galaxy1Scene()
        let result = scene.gameResult
        #expect(result.finalScore == 0)
        #expect(result.enemiesDestroyed == 0)
        #expect(result.didWin == false)
    }
}
