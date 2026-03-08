import Testing
import GameplayKit
import simd
@testable import Engine2043

@MainActor
final class MockInputProvider: InputProvider {
    var movement: SIMD2<Float>
    var primary: Bool

    init(movement: SIMD2<Float> = .zero, primary: Bool = false) {
        self.movement = movement
        self.primary = primary
    }

    func poll() -> PlayerInput {
        var input = PlayerInput()
        input.movement = movement
        input.primaryFire = primary
        return input
    }
}

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

    @Test @MainActor func sceneShouldRestartIsFalseInitially() {
        let scene = Galaxy1Scene()
        #expect(scene.shouldRestart == false)
    }
}
