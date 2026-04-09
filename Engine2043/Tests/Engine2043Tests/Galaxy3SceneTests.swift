import Testing
import GameplayKit
import simd
@testable import Engine2043

// MARK: - Helpers

@MainActor
private func makeCarryover(
    weaponType: WeaponType = .doubleCannon,
    score: Int = 2000,
    secondaryCharges: Int = 2,
    shieldDroneCount: Int = 0,
    enemiesDestroyed: Int = 50,
    elapsedTime: Double = 180.0
) -> PlayerCarryover {
    PlayerCarryover(
        weaponType: weaponType,
        score: score,
        secondaryCharges: secondaryCharges,
        shieldDroneCount: shieldDroneCount,
        enemiesDestroyed: enemiesDestroyed,
        elapsedTime: elapsedTime
    )
}

@MainActor
private func runFrames(_ scene: Galaxy3Scene, count: Int) {
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

// MARK: - Tests

struct Galaxy3SceneTests {

    // MARK: - Rendering

    @Test @MainActor func sceneHasGalaxy3BackgroundColor() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        #expect(scene.backgroundColor == GameConfig.Galaxy3.Palette.g3Background)
    }

    // MARK: - Carryover / Initialization

    @Test @MainActor func sceneInitializesWithPlayerWeaponFromCarryover() {
        let carryover = makeCarryover(weaponType: .phaseLaser)
        let scene = Galaxy3Scene(carryover: carryover)

        let weapon = scene.player.component(ofType: WeaponComponent.self)
        #expect(weapon?.weaponType == .phaseLaser)
    }

    @Test @MainActor func sceneInitializesWithScoreFromCarryover() {
        let carryover = makeCarryover(score: 9999)
        let scene = Galaxy3Scene(carryover: carryover)

        #expect(scene.scoreSystem.currentScore == 9999)
    }

    @Test @MainActor func sceneInitializesWithPlayerEnergyFull() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        let health = scene.player.component(ofType: HealthComponent.self)
        #expect(health?.currentHealth == GameConfig.Player.health)
    }

    @Test @MainActor func scenePreservesSecondaryChargesFromCarryover() {
        let carryover = makeCarryover(secondaryCharges: 3)
        let scene = Galaxy3Scene(carryover: carryover)

        let weapon = scene.player.component(ofType: WeaponComponent.self)
        #expect(weapon?.secondaryCharges == 3)
    }

    // MARK: - Basic Scene Behavior

    @Test @MainActor func sceneGameStateStartsAsPlaying() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        #expect(scene.gameState == .playing)
    }

    @Test @MainActor func sceneUpdatesWithoutCrash() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        let mockInput = MockInputProvider(movement: SIMD2(1, 0), primary: true)
        scene.inputProvider = mockInput

        // Should not crash
        runFrames(scene, count: 60)

        let sprites = scene.collectSprites(atlas: nil)
        #expect(sprites.count > 0)
    }

    // MARK: - Stage State

    @Test @MainActor func stageStateStartsAsScrolling() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        #expect(scene.stageState == .scrolling)
    }

    // MARK: - Boss Scaffolding

    @Test @MainActor func bossEntityIsNilAtStart() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        #expect(scene.bossEntity == nil)
    }

    // MARK: - Transition

    @Test @MainActor func sceneRequestedTransitionIsNilInitially() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        #expect(scene.requestedTransition == nil)
    }

    // MARK: - Carryover Weapon Damage

    @Test @MainActor func sceneRestoresTriSpreadWeaponDamage() {
        let carryover = makeCarryover(weaponType: .triSpread)
        let scene = Galaxy3Scene(carryover: carryover)

        let weapon = scene.player.component(ofType: WeaponComponent.self)
        #expect(weapon?.weaponType == .triSpread)
        #expect(weapon?.damage == GameConfig.Weapon.triSpreadDamage)
    }

    @Test @MainActor func sceneRestoresLightningArcWeaponDamage() {
        let carryover = makeCarryover(weaponType: .lightningArc)
        let scene = Galaxy3Scene(carryover: carryover)

        let weapon = scene.player.component(ofType: WeaponComponent.self)
        #expect(weapon?.weaponType == .lightningArc)
        #expect(weapon?.damage == GameConfig.Weapon.lightningArcDamagePerTick)
    }

    // MARK: - Running Stability

    @Test @MainActor func sceneRunsStablyFor300Frames() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        let input = MockInputProvider(movement: SIMD2(0.5, 0), primary: true)
        scene.inputProvider = input

        runFrames(scene, count: 300)

        #expect(scene.gameState == .playing)
        let sprites = scene.collectSprites(atlas: nil)
        #expect(sprites.count > 0)
    }

    @Test @MainActor func sceneCarriesOverEnemiesDestroyedFromGalaxy2() {
        let carryover = makeCarryover(enemiesDestroyed: 75)
        let scene = Galaxy3Scene(carryover: carryover)
        #expect(scene.enemiesDestroyed == 75)
    }

    // MARK: - Player Barrier Mask

    @Test @MainActor func playerHasBarrierInCollisionMask() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        let physics = scene.player.component(ofType: PhysicsComponent.self)
        #expect(physics?.collisionMask.contains(.barrier) == true)
    }

    // MARK: - Game Over

    @Test @MainActor func gameOverInGalaxy3ProducesCorrectGameResult() {
        let carryover = makeCarryover(score: 8000, enemiesDestroyed: 60, elapsedTime: 300.0)
        let scene = Galaxy3Scene(carryover: carryover)

        // Advance past title card so gameplay is active
        runFrames(scene, count: 200)

        // Directly kill the player
        scene.player.component(ofType: HealthComponent.self)?.currentHealth = 0

        // Run until the game-over transition fires (restartDelay = 1.5s = 90 frames)
        runFrames(scene, count: 150)

        guard case .toGameOver(let result) = scene.requestedTransition else {
            Issue.record("Expected .toGameOver transition, got \(String(describing: scene.requestedTransition))")
            return
        }

        #expect(result.finalScore >= 8000, "Game result includes G2 carryover score")
        #expect(!result.didWin, "Game over means didWin is false")
        #expect(result.enemiesDestroyed >= 60, "Carries over G2 enemies destroyed count")
    }
}
