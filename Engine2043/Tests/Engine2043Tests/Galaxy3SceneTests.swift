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

    // MARK: - Stage State Transitions

    @Test @MainActor func stageStateRemainsScrollingDuringEarlyFrames() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        // Run 120 frames (2 seconds) — well within scrolling territory
        runFrames(scene, count: 120)

        #expect(scene.stageState == .scrolling, "Stage should remain scrolling during early gameplay")
        #expect(scene.bossEntity == nil, "No boss yet during scrolling")
    }

    // MARK: - Boss Entity Spawning via Boss Trigger

    @Test @MainActor func bossTriggerSpawnsBossEntity() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        // We need to scroll far enough to trigger boss spawn (scroll distance 2200)
        // Galaxy3 scrollSpeed = 40 units/s, so 2200/40 = 55 seconds = 3300 frames + title card ~186 frames
        // Keep player alive during the scroll
        for _ in 0..<3600 {
            scene.player.component(ofType: HealthComponent.self)?.currentHealth = GameConfig.Player.health
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
            // Early exit once boss spawns to save time
            if scene.bossEntity != nil { break }
        }

        #expect(scene.bossEntity != nil, "Boss should spawn after scrolling to trigger distance")
        // Stage state should have progressed past scrolling
        #expect(scene.stageState != .scrolling, "Stage should transition from scrolling when boss triggers")
    }

    // MARK: - Scroll Lock on Boss Trigger

    @Test @MainActor func scrollLocksWhenBossSpawns() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        // Scroll to boss trigger
        for _ in 0..<3600 {
            scene.player.component(ofType: HealthComponent.self)?.currentHealth = GameConfig.Player.health
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
            if scene.bossEntity != nil { break }
        }

        guard scene.bossEntity != nil else {
            Issue.record("Boss never spawned; cannot test scroll lock")
            return
        }

        // After boss spawns, scrolling should be locked
        // The stageState should be bossIntro or bossActive (not scrolling)
        let isLocked = scene.stageState == .bossIntro || scene.stageState == .bossActive
        #expect(isLocked, "Scroll should be locked after boss trigger, got \(scene.stageState)")
    }

    // MARK: - Boss Has ZenithBossComponent

    @Test @MainActor func spawnedBossHasZenithBossComponent() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        for _ in 0..<3600 {
            scene.player.component(ofType: HealthComponent.self)?.currentHealth = GameConfig.Player.health
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
            if scene.bossEntity != nil { break }
        }

        guard let boss = scene.bossEntity else {
            Issue.record("Boss never spawned")
            return
        }

        #expect(boss.component(ofType: ZenithBossComponent.self) != nil,
                "Boss should have ZenithBossComponent")
        #expect(boss.component(ofType: HealthComponent.self) != nil,
                "Boss should have HealthComponent")
        #expect(boss.component(ofType: BossPhaseComponent.self) != nil,
                "Boss should have BossPhaseComponent")
    }

    // MARK: - Title Card Blocks Gameplay

    @Test @MainActor func titleCardPreventsGameplayAdvancement() {
        let initialElapsedTime: Double = 180.0
        let carryover = makeCarryover(elapsedTime: initialElapsedTime)
        let scene = Galaxy3Scene(carryover: carryover)

        // Run for 1 second (within title card duration ~3.1s)
        runFrames(scene, count: 60)

        // Elapsed time should NOT advance during title card
        #expect(scene.elapsedTime == initialElapsedTime,
                "elapsedTime should not advance during title card")
    }

    @Test @MainActor func elapsedTimeAdvancesAfterTitleCard() {
        let carryover = makeCarryover(elapsedTime: 180.0)
        let scene = Galaxy3Scene(carryover: carryover)

        // Title card ~3.1s => run 4s = 240 frames
        runFrames(scene, count: 240)

        #expect(scene.elapsedTime > 180.0,
                "elapsedTime should advance after title card completes")
    }

    // MARK: - All Weapon Types Carry Over Correctly

    @Test @MainActor func allWeaponTypesCarryOverCorrectly() {
        let weaponTypes: [WeaponType] = [.doubleCannon, .triSpread, .lightningArc, .phaseLaser]

        for wt in weaponTypes {
            let carryover = makeCarryover(weaponType: wt)
            let scene = Galaxy3Scene(carryover: carryover)
            let weapon = scene.player.component(ofType: WeaponComponent.self)!
            #expect(weapon.weaponType == wt, "Weapon type \(wt) should carry over")
        }
    }

    // MARK: - Player Collision Mask Includes Barrier

    @Test @MainActor func playerCollisionMaskIncludesBarrierAndEnemy() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        let physics = scene.player.component(ofType: PhysicsComponent.self)!
        #expect(physics.collisionMask.contains(.barrier))
        #expect(physics.collisionMask.contains(.enemy))
        #expect(physics.collisionMask.contains(.enemyProjectile))
        #expect(physics.collisionMask.contains(.item))
    }
}
