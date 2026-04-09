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

    // MARK: - Phase Laser vs Zenith Boss Shield

    @Test @MainActor func phaseLaserBlockedByZenithBossShield() {
        let carryover = makeCarryover(weaponType: .phaseLaser)
        let scene = Galaxy3Scene(carryover: carryover)

        // Create a boss enemy with ZenithBossComponent and shield active
        let boss = GKEntity()
        boss.addComponent(TransformComponent(position: SIMD2(0, 100)))
        let bossHealth = HealthComponent(health: 150)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(PhysicsComponent(
            collisionSize: SIMD2(80, 80), layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        ))
        let render = RenderComponent(size: SIMD2(80, 80), color: SIMD4(1, 1, 1, 1))
        boss.addComponent(render)
        boss.addComponent(ScoreComponent(points: 5000))
        let zenith = ZenithBossComponent()
        zenith.isShieldActive = true
        boss.addComponent(zenith)

        scene.addEnemyForTesting(boss)
        let initialHP = bossHealth.currentHealth

        // Fire laser at the boss
        let hitscan = LaserHitscanRequest(
            position: SIMD2(0, -250),
            width: GameConfig.Weapon.laserWidth,
            damagePerTick: GameConfig.Weapon.laserDamagePerTick
        )
        scene.processLaserHitscan(hitscan)

        #expect(bossHealth.currentHealth == initialHP,
                "Boss should not take laser damage while shield is active")
    }

    @Test @MainActor func phaseLaserDamagesBossWhenShieldInactive() {
        let carryover = makeCarryover(weaponType: .phaseLaser)
        let scene = Galaxy3Scene(carryover: carryover)

        let boss = GKEntity()
        boss.addComponent(TransformComponent(position: SIMD2(0, 100)))
        let bossHealth = HealthComponent(health: 150)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(PhysicsComponent(
            collisionSize: SIMD2(80, 80), layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        ))
        let render = RenderComponent(size: SIMD2(80, 80), color: SIMD4(1, 1, 1, 1))
        boss.addComponent(render)
        boss.addComponent(ScoreComponent(points: 5000))
        let zenith = ZenithBossComponent()
        zenith.isShieldActive = false
        boss.addComponent(zenith)

        scene.addEnemyForTesting(boss)
        let initialHP = bossHealth.currentHealth

        let hitscan = LaserHitscanRequest(
            position: SIMD2(0, -250),
            width: GameConfig.Weapon.laserWidth,
            damagePerTick: GameConfig.Weapon.laserDamagePerTick
        )
        scene.processLaserHitscan(hitscan)

        #expect(bossHealth.currentHealth < initialHP,
                "Boss should take laser damage when shield is inactive")
    }

    // MARK: - Phase Laser vs Barrier Occlusion

    @Test @MainActor func phaseLaserBlockedByBarrier() {
        let carryover = makeCarryover(weaponType: .phaseLaser)
        let scene = Galaxy3Scene(carryover: carryover)

        // Place an enemy above a barrier
        let enemy = TestEntityFactory.makeEnemyEntity(position: SIMD2(0, 100), health: 10)
        let enemyRender = RenderComponent(size: SIMD2(16, 16), color: SIMD4(1, 1, 1, 1))
        enemy.addComponent(enemyRender)
        scene.addEnemyForTesting(enemy)

        // Place a barrier between the player (y=-250) and the enemy (y=100)
        let barrier = Galaxy3EntityFactory.makeBarrier(kind: .trenchWall, at: SIMD2(0, 0))
        scene.addBarrierForTesting(barrier)

        let enemyHealth = enemy.component(ofType: HealthComponent.self)!
        let initialHP = enemyHealth.currentHealth

        let hitscan = LaserHitscanRequest(
            position: SIMD2(0, -250),
            width: GameConfig.Weapon.laserWidth,
            damagePerTick: GameConfig.Weapon.laserDamagePerTick
        )
        scene.processLaserHitscan(hitscan)

        #expect(enemyHealth.currentHealth == initialHP,
                "Enemy behind barrier should not take laser damage")
    }

    // MARK: - Fortress Node Shielding

    @Test @MainActor func shieldedFortressNodeDeflectsProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockGalaxy3CollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Create a fortress node that is shielded (non-generator)
        let node = Galaxy3EntityFactory.makeFortressNode(role: .mainBattery, at: .zero, fortressID: 1)
        let nodeHealth = node.component(ofType: HealthComponent.self)!
        let initialHP = nodeHealth.currentHealth

        let projectile = TestEntityFactory.makeProjectileEntity()
        handler.processCollisions(pairs: [(projectile, node)])

        #expect(nodeHealth.currentHealth == initialHP,
                "Shielded fortress node should not take damage")
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }),
                "Projectile should be consumed")
    }

    @Test @MainActor func shieldGeneratorCanBeDamagedWhileShielded() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockGalaxy3CollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Create a shield generator — generators should always be damageable
        let gen = Galaxy3EntityFactory.makeFortressNode(role: .shieldGenerator, at: .zero, fortressID: 1)
        let genHealth = gen.component(ofType: HealthComponent.self)!
        let initialHP = genHealth.currentHealth

        let projectile = TestEntityFactory.makeProjectileEntity()
        handler.processCollisions(pairs: [(projectile, gen)])

        #expect(genHealth.currentHealth < initialHP,
                "Shield generator should be damageable even while isShielded is true")
    }

    @Test @MainActor func unshieldedFortressNodeTakesDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockGalaxy3CollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let node = Galaxy3EntityFactory.makeFortressNode(role: .mainBattery, at: .zero, fortressID: 1)
        // Unshield it (as if the shield generator was destroyed)
        node.component(ofType: FortressNodeComponent.self)!.isShielded = false
        let nodeHealth = node.component(ofType: HealthComponent.self)!
        let initialHP = nodeHealth.currentHealth

        let projectile = TestEntityFactory.makeProjectileEntity()
        handler.processCollisions(pairs: [(projectile, node)])

        #expect(nodeHealth.currentHealth < initialHP,
                "Unshielded fortress node should take damage")
    }

    // MARK: - Phase Laser vs Fortress Shielding

    @Test @MainActor func phaseLaserDeflectedByShieldedFortressNode() {
        let carryover = makeCarryover(weaponType: .phaseLaser)
        let scene = Galaxy3Scene(carryover: carryover)

        let node = Galaxy3EntityFactory.makeFortressNode(role: .pulseTurret, at: SIMD2(0, 50), fortressID: 1)
        let nodeRender = RenderComponent(size: GameConfig.Galaxy3.Enemy.fortressNodeSize, color: SIMD4(1, 1, 1, 1))
        node.addComponent(nodeRender)
        scene.addEnemyForTesting(node)

        let nodeHealth = node.component(ofType: HealthComponent.self)!
        let initialHP = nodeHealth.currentHealth

        let hitscan = LaserHitscanRequest(
            position: SIMD2(0, -250),
            width: GameConfig.Weapon.laserWidth,
            damagePerTick: GameConfig.Weapon.laserDamagePerTick
        )
        scene.processLaserHitscan(hitscan)

        #expect(nodeHealth.currentHealth == initialHP,
                "Shielded fortress node should deflect phase laser")
    }

    // MARK: - Fortress Shield Propagation (Finding 1 & 4)

    @Test @MainActor func killingShieldGeneratorUnshieldsSiblingNodes() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        // Run past the title card
        runFrames(scene, count: 200)

        // Manually spawn a fortress encounter using the testability helpers
        let fortressID = 42
        let generator = Galaxy3EntityFactory.makeFortressNode(
            role: .shieldGenerator, at: SIMD2(0, 100), fortressID: fortressID
        )
        let battery = Galaxy3EntityFactory.makeFortressNode(
            role: .mainBattery, at: SIMD2(-60, 100), fortressID: fortressID
        )
        let turret = Galaxy3EntityFactory.makeFortressNode(
            role: .pulseTurret, at: SIMD2(60, 100), fortressID: fortressID
        )
        scene.addEnemyForTesting(generator)
        scene.addEnemyForTesting(battery)
        scene.addEnemyForTesting(turret)

        // Verify siblings start shielded
        let batteryFort = battery.component(ofType: FortressNodeComponent.self)!
        let turretFort = turret.component(ofType: FortressNodeComponent.self)!
        #expect(batteryFort.isShielded == true)
        #expect(turretFort.isShielded == true)

        // Kill the generator
        let genHealth = generator.component(ofType: HealthComponent.self)!
        genHealth.currentHealth = 0

        // Run one frame so propagateFortressShieldDown() fires
        runFrames(scene, count: 1)

        // Sibling nodes should now be unshielded
        #expect(batteryFort.isShielded == false,
                "Battery should be unshielded after generator dies")
        #expect(turretFort.isShielded == false,
                "Turret should be unshielded after generator dies")
    }

    @Test @MainActor func shieldPropagationHappensBeforeEntityRemoval() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)
        runFrames(scene, count: 200)

        let fortressID = 99
        let generator = Galaxy3EntityFactory.makeFortressNode(
            role: .shieldGenerator, at: SIMD2(0, 100), fortressID: fortressID
        )
        let battery = Galaxy3EntityFactory.makeFortressNode(
            role: .mainBattery, at: SIMD2(-60, 100), fortressID: fortressID
        )
        scene.addEnemyForTesting(generator)
        scene.addEnemyForTesting(battery)

        // Kill generator and queue it for removal (simulating collision kill)
        let genHealth = generator.component(ofType: HealthComponent.self)!
        genHealth.currentHealth = 0
        scene.pendingRemovals.append(generator)

        // Run one frame — propagation should see the dead generator before removal
        runFrames(scene, count: 1)

        let batteryFort = battery.component(ofType: FortressNodeComponent.self)!
        #expect(batteryFort.isShielded == false,
                "Shield propagation must run before entity removal")
    }

    // MARK: - Player Contact vs Boss (Finding 2 & 4)

    @Test @MainActor func playerRammingZenithBossDoesNotKillBoss() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockGalaxy3CollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let (boss, _) = Galaxy3EntityFactory.makeZenithBossShell(at: SIMD2(0, 200))
        let bossHealth = boss.component(ofType: HealthComponent.self)!
        let initialHP = bossHealth.currentHealth

        handler.processCollisions(pairs: [(player, boss)])

        #expect(bossHealth.isAlive, "Boss must survive player ramming")
        #expect(bossHealth.currentHealth == initialHP - GameConfig.Player.collisionDamage,
                "Boss should take only collisionDamage from player contact")
    }

    // MARK: - Boss Arena Clears Barriers (Finding 3)

    @Test @MainActor func triggerBossClearsBarriersAndLaneBounds() {
        let carryover = makeCarryover()
        let scene = Galaxy3Scene(carryover: carryover)

        // Run past title card
        runFrames(scene, count: 200)

        // Add some barriers near the player's Y so they register as lane bounds
        let barrier1 = Galaxy3EntityFactory.makeBarrier(kind: .trenchWall, at: SIMD2(-100, -250))
        let barrier2 = Galaxy3EntityFactory.makeBarrier(kind: .trenchWall, at: SIMD2(100, -250))
        scene.addBarrierForTesting(barrier1)
        scene.addBarrierForTesting(barrier2)

        // Run a frame to update lane bounds
        runFrames(scene, count: 1)
        #expect(scene.barrierCountForTesting >= 2, "Barriers should be present before boss trigger")

        // Scroll to boss trigger distance — 2200 / 40 = 55s = 3300 frames + 200 title
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
            Issue.record("Boss never spawned; cannot test barrier clearing")
            return
        }

        #expect(scene.stageState == .bossIntro || scene.stageState == .bossActive,
                "Stage should have transitioned to boss")
        #expect(scene.barrierCountForTesting == 0,
                "All barriers should be cleared when boss triggers")
        #expect(scene.laneBoundsForTesting.isActive == false,
                "Lane bounds should be reset when boss triggers")
    }

    // MARK: - Finding 3: Lightning Arc Respects Shield Logic

    @Test @MainActor func lightningArcCannotDamageZenithDuringShieldWindow() {
        let carryover = makeCarryover(weaponType: .lightningArc)
        let scene = Galaxy3Scene(carryover: carryover)
        let input = MockInputProvider(movement: .zero, primary: true) // firing
        scene.inputProvider = input

        // Run past title card
        runFrames(scene, count: 200)

        // Create a boss enemy with ZenithBossComponent and shield active
        let boss = GKEntity()
        boss.addComponent(TransformComponent(position: SIMD2(0, 0))) // within lightning range
        let bossHealth = HealthComponent(health: 150)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(PhysicsComponent(
            collisionSize: SIMD2(80, 80), layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        ))
        let render = RenderComponent(size: SIMD2(80, 80), color: SIMD4(1, 1, 1, 1))
        boss.addComponent(render)
        boss.addComponent(ScoreComponent(points: 5000))
        let zenith = ZenithBossComponent()
        zenith.isShieldActive = true
        boss.addComponent(zenith)

        scene.addEnemyForTesting(boss)
        let initialHP = bossHealth.currentHealth

        // Run several frames to allow lightning arc to fire
        for _ in 0..<60 {
            scene.player.component(ofType: HealthComponent.self)?.currentHealth = GameConfig.Player.health
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }

        #expect(bossHealth.currentHealth == initialHP,
                "Lightning Arc should not damage Zenith during shield window")
    }

    @Test @MainActor func lightningArcCannotDamageShieldedFortressNode() {
        let carryover = makeCarryover(weaponType: .lightningArc)
        let scene = Galaxy3Scene(carryover: carryover)
        let input = MockInputProvider(movement: .zero, primary: true) // firing
        scene.inputProvider = input

        // Run past title card
        runFrames(scene, count: 200)

        // Create a shielded fortress node within lightning range
        let node = Galaxy3EntityFactory.makeFortressNode(role: .mainBattery, at: SIMD2(0, 0), fortressID: 1)
        // Ensure isShielded is true (default from factory)
        node.addComponent(RenderComponent(size: GameConfig.Galaxy3.Enemy.fortressNodeSize, color: SIMD4(1, 1, 1, 1)))
        scene.addEnemyForTesting(node)

        let nodeHealth = node.component(ofType: HealthComponent.self)!
        let initialHP = nodeHealth.currentHealth

        // Run several frames
        for _ in 0..<60 {
            scene.player.component(ofType: HealthComponent.self)?.currentHealth = GameConfig.Player.health
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }

        #expect(nodeHealth.currentHealth == initialHP,
                "Lightning Arc should not damage shielded fortress node")
    }

    // MARK: - Finding 5: Enemy Projectile Custom Damage

    @Test @MainActor func enemyProjectileWithCustomDamageAppliesCorrectDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockGalaxy3CollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Create enemy projectile with ProjectileComponent carrying custom damage
        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()
        let projComp = ProjectileComponent(damage: 10, speed: 200)
        enemyProj.addComponent(projComp)

        handler.processCollisions(pairs: [(player, enemyProj)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 90,
                "Enemy projectile with damage 10 should deal 10 damage, not legacy 5")
    }

    // MARK: - Boss Intro State Persists

    @Test @MainActor func bossIntroStatePersistsUntilDescentCompletes() {
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

        guard let boss = scene.bossEntity else {
            Issue.record("Boss never spawned")
            return
        }

        let zenith = boss.component(ofType: ZenithBossComponent.self)!
        // Right after trigger, boss should be in intro and stageState should be bossIntro
        if zenith.currentPhase == .intro {
            #expect(scene.stageState == .bossIntro,
                    "Stage state should be bossIntro during boss intro descent")
        }

        // Run enough frames for intro to complete (1.5s = 90 frames)
        for _ in 0..<120 {
            scene.player.component(ofType: HealthComponent.self)?.currentHealth = GameConfig.Player.health
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }

        #expect(scene.stageState == .bossActive,
                "Stage state should transition to bossActive after intro completes")
    }
}

// MARK: - Mock Collision Context for Galaxy3 Tests

@MainActor
private final class MockGalaxy3CollisionContext: CollisionContext {
    var player: GKEntity!
    let scoreSystem = ScoreSystem()
    let itemSystem = ItemSystem()
    var sfx: AudioEngine? = nil
    var pendingRemovals: [GKEntity] = []
    var enemiesDestroyed: Int = 0

    init(player: GKEntity) {
        self.player = player
    }

    func checkFormationWipe(enemy: GKEntity) {}
    func spawnShieldDrones() {}
}
