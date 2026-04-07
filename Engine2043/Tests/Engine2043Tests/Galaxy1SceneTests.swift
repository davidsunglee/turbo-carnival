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

    // MARK: - Boundary Clamping

    @Test @MainActor func playerStaysWithinRightBoundaryAtFullSpeed() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(1, 0))
        scene.inputProvider = mockInput

        let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2

        var time = GameTime()
        // Run enough frames for player to reach and exceed the boundary
        for _ in 0..<300 {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
        }

        let playerPos = scene.player.component(ofType: TransformComponent.self)!.position
        #expect(playerPos.x <= halfW, "Player x (\(playerPos.x)) exceeded right boundary (\(halfW))")
    }

    @Test @MainActor func playerStaysWithinLeftBoundaryAtFullSpeed() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(-1, 0))
        scene.inputProvider = mockInput

        let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2

        var time = GameTime()
        for _ in 0..<300 {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
        }

        let playerPos = scene.player.component(ofType: TransformComponent.self)!.position
        #expect(playerPos.x >= -halfW, "Player x (\(playerPos.x)) exceeded left boundary (\(-halfW))")
    }

    @Test @MainActor func playerStaysWithinTopBoundaryAtFullSpeed() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(0, 1))
        scene.inputProvider = mockInput

        let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2

        var time = GameTime()
        for _ in 0..<300 {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
        }

        let playerPos = scene.player.component(ofType: TransformComponent.self)!.position
        #expect(playerPos.y <= halfH, "Player y (\(playerPos.y)) exceeded top boundary (\(halfH))")
    }

    @Test @MainActor func playerStaysWithinBottomBoundaryAtFullSpeed() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(0, -1))
        scene.inputProvider = mockInput

        let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2

        var time = GameTime()
        for _ in 0..<300 {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
        }

        let playerPos = scene.player.component(ofType: TransformComponent.self)!.position
        #expect(playerPos.y >= -halfH, "Player y (\(playerPos.y)) exceeded bottom boundary (\(-halfH))")
    }

    @Test @MainActor func playerRespondsImmediatelyAfterHittingBoundary() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(-1, 0))
        scene.inputProvider = mockInput

        let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2

        var time = GameTime()
        // Drive into the left wall for 120 frames
        for _ in 0..<120 {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
        }

        let posAtWall = scene.player.component(ofType: TransformComponent.self)!.position.x
        #expect(posAtWall == -halfW, "Player should be at left boundary")

        // Now reverse direction for 1 frame
        mockInput.movement = SIMD2(1, 0)
        time.advance(by: GameConfig.fixedTimeStep)
        while time.shouldPerformFixedUpdate() {
            scene.fixedUpdate(time: time)
            time.consumeFixedUpdate()
        }

        let posAfterReverse = scene.player.component(ofType: TransformComponent.self)!.position.x
        #expect(posAfterReverse > posAtWall, "Player should move right immediately after reversing (was \(posAtWall), now \(posAfterReverse))")
    }
}
