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

    @Test @MainActor func backgroundSystemProducesSprites() {
        let bg = BackgroundSystem()
        let sprites = bg.collectSprites()
        #expect(sprites.count == GameConfig.Background.starCount + GameConfig.Background.nebulaCount)
    }

    @Test @MainActor func backgroundSystemScrolls() {
        let bg = BackgroundSystem()
        let before = bg.scrollDistance
        bg.update(deltaTime: 1.0)
        let after = bg.scrollDistance
        #expect(after > before)
    }

    @Test @MainActor func backgroundSystemWrapsStars() {
        let bg = BackgroundSystem()
        for _ in 0..<1000 {
            bg.update(deltaTime: 1.0 / 60.0)
        }
        let sprites = bg.collectSprites()
        let maxY = GameConfig.designHeight / 2 + 50
        let minY = -GameConfig.designHeight / 2 - 50
        for sprite in sprites {
            #expect(sprite.position.y >= minY)
            #expect(sprite.position.y <= maxY)
        }
    }
}
