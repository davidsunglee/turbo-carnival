import Testing
import GameplayKit
import simd
@testable import Engine2043

@MainActor
private final class MockCollisionContext: CollisionContext {
    var player: GKEntity!
    let scoreSystem = ScoreSystem()
    let itemSystem = ItemSystem()
    var sfx: AudioEngine? = nil
    var pendingRemovals: [GKEntity] = []
    var enemiesDestroyed: Int = 0
    var formationWipeChecked: [GKEntity] = []
    var shieldDronesSpawned = 0
    var barrierPushOutCalled: [GKEntity] = []

    init(player: GKEntity) {
        self.player = player
    }

    func checkFormationWipe(enemy: GKEntity) {
        formationWipeChecked.append(enemy)
    }

    func spawnShieldDrones() {
        shieldDronesSpawned += 1
    }

    func handleBarrierPushOut(barrier: GKEntity) {
        barrierPushOutCalled.append(barrier)
    }
}

struct CollisionResponseHandlerTests {

    @Test @MainActor func projectileHitEnemyDealsDamageAndRemovesBoth() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 1, scorePoints: 100)

        handler.processCollisions(pairs: [(projectile, enemy)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(ctx.enemiesDestroyed == 1)
    }

    @Test @MainActor func projectileHitEnemyAddsScore() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 1, scorePoints: 250)

        handler.processCollisions(pairs: [(projectile, enemy)])

        #expect(ctx.scoreSystem.currentScore == 250)
    }

    @Test @MainActor func projectileHitEnemyChecksFormationWipe() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 1)

        handler.processCollisions(pairs: [(projectile, enemy)])

        #expect(ctx.formationWipeChecked.contains(where: { $0 === enemy }))
    }

    @Test @MainActor func projectileHitEnemyDoesNotKillIfHealthRemains() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 9999)

        handler.processCollisions(pairs: [(projectile, enemy)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.enemiesDestroyed == 0)
    }

    @Test @MainActor func playerEnemyCollisionDamagesBoth() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemy = TestEntityFactory.makeEnemyEntity(health: 10, scorePoints: 50)

        handler.processCollisions(pairs: [(player, enemy)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth < 100)
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.enemiesDestroyed == 1)
        #expect(ctx.scoreSystem.currentScore == 50)
    }

    @Test @MainActor func playerHitByProjectileTakesDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()

        handler.processCollisions(pairs: [(player, enemyProj)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 95)  // takes 5 damage
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemyProj }))
    }

    @Test @MainActor func reversedPairOrderStillWorks() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemy = TestEntityFactory.makeEnemyEntity(health: 1)
        let projectile = TestEntityFactory.makeProjectileEntity()

        handler.processCollisions(pairs: [(enemy, projectile)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
    }

    @Test @MainActor func emptyPairsProducesNoSideEffects() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        handler.processCollisions(pairs: [])

        #expect(ctx.pendingRemovals.isEmpty)
        #expect(ctx.enemiesDestroyed == 0)
    }

    @Test @MainActor func bossShieldDeflectsProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let shield = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(30, 30),
            collisionLayer: .bossShield, collisionMask: .playerProjectile
        )

        handler.processCollisions(pairs: [(projectile, shield)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === shield }))
    }

    @Test @MainActor func projectileHitItemCyclesAndRemovesProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let item = TestEntityFactory.makeItemEntity()
        ctx.itemSystem.register(item)

        let initialIndex = item.component(ofType: ItemComponent.self)!.currentCycleIndex
        handler.processCollisions(pairs: [(projectile, item)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        let newIndex = item.component(ofType: ItemComponent.self)!.currentCycleIndex
        #expect(newIndex != initialIndex)
    }

    @Test @MainActor func shieldDroneBlocksEnemyProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let drone = TestEntityFactory.makeShieldDroneEntity()
        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()

        let hitsBefore = drone.component(ofType: ShieldDroneComponent.self)!.hitsRemaining
        handler.processCollisions(pairs: [(drone, enemyProj)])

        let hitsAfter = drone.component(ofType: ShieldDroneComponent.self)!.hitsRemaining
        #expect(hitsAfter == hitsBefore - 1)
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemyProj }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === drone }))
    }

    @Test @MainActor func playerCollectsEnergyCellRestoresHealth() {
        let player = TestEntityFactory.makePlayerEntity()
        let playerHealth = player.component(ofType: HealthComponent.self)!
        playerHealth.hasInvulnerabilityFrames = false
        playerHealth.takeDamage(50)

        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let item = TestEntityFactory.makeItemEntity(utilityIndex: 0)

        handler.processCollisions(pairs: [(player, item)])

        #expect(playerHealth.currentHealth > 50)
        #expect(ctx.pendingRemovals.contains(where: { $0 === item }))
    }

    @Test @MainActor func playerCollectsWeaponModuleSwitchesWeapon() {
        let player = TestEntityFactory.makePlayerEntity()
        let weapon = player.component(ofType: WeaponComponent.self)!
        #expect(weapon.weaponType == .doubleCannon)

        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let item = TestEntityFactory.makeItemEntity(isWeaponModule: true)
        let itemComp = item.component(ofType: ItemComponent.self)!
        itemComp.displayedWeapon = .triSpread

        handler.processCollisions(pairs: [(player, item)])

        #expect(weapon.weaponType == .triSpread)
        #expect(weapon.damage == GameConfig.Weapon.triSpreadDamage)
        #expect(ctx.pendingRemovals.contains(where: { $0 === item }))
    }

    @Test @MainActor func playerCollectsOrbitingShieldSpawnsDrones() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let item = TestEntityFactory.makeItemEntity(utilityIndex: 2)

        handler.processCollisions(pairs: [(player, item)])

        #expect(ctx.shieldDronesSpawned == 1)
        #expect(ctx.pendingRemovals.contains(where: { $0 === item }))
    }

    // MARK: - Asteroid Collision Tests

    @Test @MainActor func projectileHitSmallAsteroidDamagesItAndRemovesProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        // Small asteroid with full health (2.5) — survives one hit from Player.damage (1.0)
        let asteroid = TestEntityFactory.makeAsteroidEntity(size: .small)
        let healthBefore = asteroid.component(ofType: HealthComponent.self)!.currentHealth

        handler.processCollisions(pairs: [(projectile, asteroid)])

        let healthAfter = asteroid.component(ofType: HealthComponent.self)!.currentHealth
        #expect(healthAfter < healthBefore)
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === asteroid }))
    }

    @Test @MainActor func projectileDestroysSmallAsteroidAddsScoreAndSFX() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        // Give the asteroid health below Player.damage so one hit destroys it
        let asteroid = TestEntityFactory.makeAsteroidEntity(size: .small, health: 0.5)

        handler.processCollisions(pairs: [(projectile, asteroid)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === asteroid }))
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(ctx.scoreSystem.currentScore == GameConfig.Galaxy2.Score.asteroidSmall)
    }

    @Test @MainActor func playerCollidesWithAsteroidTakesCollisionDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        // Disable invulnerability frames so we get an exact health check
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let asteroid = TestEntityFactory.makeAsteroidEntity(size: .large)
        let healthBefore = player.component(ofType: HealthComponent.self)!.currentHealth

        handler.processCollisions(pairs: [(player, asteroid)])

        let healthAfter = player.component(ofType: HealthComponent.self)!.currentHealth
        #expect(healthAfter == healthBefore - GameConfig.Galaxy2.Asteroid.collisionDamage)
        // Asteroid is NOT removed — player bounces off
        #expect(!ctx.pendingRemovals.contains(where: { $0 === asteroid }))
    }

    @Test @MainActor func projectileHitsLargeAsteroidProjectileRemovedAsteroidSurvives() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        // Large asteroid has no HealthComponent — indestructible
        let asteroid = TestEntityFactory.makeAsteroidEntity(size: .large)

        handler.processCollisions(pairs: [(projectile, asteroid)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === asteroid }))
    }

    // MARK: - ProjectileComponent Damage Tests

    @Test @MainActor func playerHitByProjectileWithProjectileComponentUsesItsDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()
        let projComp = ProjectileComponent(damage: 15, speed: 200)
        enemyProj.addComponent(projComp)

        handler.processCollisions(pairs: [(player, enemyProj)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 85)  // 100 - 15
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemyProj }))
    }

    @Test @MainActor func playerHitByLegacyProjectileFallsBackTo5Damage() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Enemy projectile WITHOUT ProjectileComponent — legacy Galaxy 1/2 behavior
        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()

        handler.processCollisions(pairs: [(player, enemyProj)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 95)  // 100 - 5, legacy fallback
    }

    @Test @MainActor func empProjectileDisablesPlayerSecondaries() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()
        let projComp = ProjectileComponent(damage: 10, speed: 200, effects: .empDisable)
        enemyProj.addComponent(projComp)

        handler.processCollisions(pairs: [(player, enemyProj)])

        let weapon = player.component(ofType: WeaponComponent.self)!
        #expect(weapon.secondaryDisabled == true)
        #expect(weapon.secondaryDisableTimer == GameConfig.Galaxy3.BossAttack.empDisableDuration)
    }

    @Test @MainActor func nonEmpProjectileDoesNotDisableSecondaries() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()
        let projComp = ProjectileComponent(damage: 10, speed: 200)
        enemyProj.addComponent(projComp)

        handler.processCollisions(pairs: [(player, enemyProj)])

        let weapon = player.component(ofType: WeaponComponent.self)!
        #expect(weapon.secondaryDisabled == false)
    }

    // MARK: - Barrier Collision Tests

    @Test @MainActor func playerHitBarrierTakesDamageAndBarrierSurvives() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let barrier = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player, .playerProjectile]
        )
        barrier.addComponent(BarrierComponent(kind: .trenchWall))

        handler.processCollisions(pairs: [(player, barrier)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 100 - GameConfig.Galaxy3.Barrier.collisionDamage)
        // Barrier must NOT be in pendingRemovals
        #expect(!ctx.pendingRemovals.contains(where: { $0 === barrier }))
    }

    @Test @MainActor func playerHitBarrierCallsPushOutCallback() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let barrier = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player, .playerProjectile]
        )
        barrier.addComponent(BarrierComponent(kind: .trenchWall))

        handler.processCollisions(pairs: [(player, barrier)])

        #expect(ctx.barrierPushOutCalled.contains(where: { $0 === barrier }))
    }

    @Test @MainActor func playerHitBarrierReversedPairOrder() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let barrier = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player, .playerProjectile]
        )
        barrier.addComponent(BarrierComponent(kind: .trenchWall))

        handler.processCollisions(pairs: [(barrier, player)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 100 - GameConfig.Galaxy3.Barrier.collisionDamage)
        #expect(!ctx.pendingRemovals.contains(where: { $0 === barrier }))
        #expect(ctx.barrierPushOutCalled.contains(where: { $0 === barrier }))
    }

    @Test @MainActor func projectileHitBarrierRemovesProjectileNotBarrier() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let barrier = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player, .playerProjectile]
        )
        barrier.addComponent(BarrierComponent(kind: .trenchWall))

        handler.processCollisions(pairs: [(projectile, barrier)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === barrier }))
    }

    // MARK: - Zenith Shield Invulnerability Tests

    @Test @MainActor func zenithShieldDeflectsProjectileAndProtectsBoss() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Create boss entity with ZenithBossComponent and shield active
        let boss = GKEntity()
        boss.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let bossHealth = HealthComponent(health: 150)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(PhysicsComponent(
            collisionSize: SIMD2(80, 80), layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        ))
        boss.addComponent(ScoreComponent(points: 5000))
        let zenith = ZenithBossComponent()
        zenith.isShieldActive = true
        boss.addComponent(zenith)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let initialHP = bossHealth.currentHealth

        handler.processCollisions(pairs: [(projectile, boss)])

        // Projectile consumed but boss takes NO damage
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(bossHealth.currentHealth == initialHP, "Boss should not take damage while shield is active")
        #expect(!ctx.pendingRemovals.contains(where: { $0 === boss }))
    }

    @Test @MainActor func zenithShieldInactiveAllowsDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let boss = GKEntity()
        boss.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let bossHealth = HealthComponent(health: 150)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(PhysicsComponent(
            collisionSize: SIMD2(80, 80), layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        ))
        boss.addComponent(ScoreComponent(points: 5000))
        let zenith = ZenithBossComponent()
        zenith.isShieldActive = false
        boss.addComponent(zenith)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let initialHP = bossHealth.currentHealth

        handler.processCollisions(pairs: [(projectile, boss)])

        // Without shield, boss should take damage
        #expect(bossHealth.currentHealth < initialHP, "Boss should take damage when shield is inactive")
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
    }

    // MARK: - Barrier Never Destroyed

    @Test @MainActor func multipleProjectilesNeverDestroyBarrier() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let barrier = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player, .playerProjectile]
        )
        barrier.addComponent(BarrierComponent(kind: .rotatingGate))

        // Hit the barrier with 10 projectiles
        for _ in 0..<10 {
            let projectile = TestEntityFactory.makeProjectileEntity()
            handler.processCollisions(pairs: [(projectile, barrier)])
        }

        // Barrier must never appear in pendingRemovals
        #expect(!ctx.pendingRemovals.contains(where: { $0 === barrier }),
                "Barrier should never be destroyed by projectiles")
    }

    // MARK: - Barrier Collision Damage Values

    @Test @MainActor func barrierCollisionDamageMatchesConfig() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let barrier = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(40, 120),
            collisionLayer: .barrier, collisionMask: [.player, .playerProjectile]
        )
        barrier.addComponent(BarrierComponent(kind: .trenchWall))

        let healthBefore = player.component(ofType: HealthComponent.self)!.currentHealth
        handler.processCollisions(pairs: [(player, barrier)])
        let healthAfter = player.component(ofType: HealthComponent.self)!.currentHealth

        let damageTaken = healthBefore - healthAfter
        #expect(damageTaken == GameConfig.Galaxy3.Barrier.collisionDamage,
                "Barrier collision damage should match GameConfig value")
    }

    // MARK: - Player Contact vs Boss / Fortress (Finding 2)

    @Test @MainActor func playerContactWithZenithBossDoesNotKillIt() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let boss = GKEntity()
        boss.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let bossHealth = HealthComponent(health: GameConfig.Galaxy3.Enemy.bossHP)
        bossHealth.hasInvulnerabilityFrames = false
        boss.addComponent(bossHealth)
        boss.addComponent(PhysicsComponent(
            collisionSize: GameConfig.Galaxy3.Enemy.bossSize,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        ))
        boss.addComponent(ScoreComponent(points: GameConfig.Galaxy3.Score.g3Boss))
        boss.addComponent(BossPhaseComponent(totalHP: GameConfig.Galaxy3.Enemy.bossHP))
        boss.addComponent(ZenithBossComponent())

        handler.processCollisions(pairs: [(player, boss)])

        // Boss should survive — takes only collisionDamage, not full HP
        #expect(bossHealth.isAlive, "Zenith boss must survive player contact")
        #expect(bossHealth.currentHealth == GameConfig.Galaxy3.Enemy.bossHP - GameConfig.Player.collisionDamage,
                "Boss should take only collisionDamage, not be one-shot killed")
        // Player should still take damage
        let playerHP = player.component(ofType: HealthComponent.self)!
        #expect(playerHP.currentHealth < 100, "Player should take collision damage")
        // Boss should NOT be in pendingRemovals
        #expect(!ctx.pendingRemovals.contains(where: { $0 === boss }),
                "Boss should not be queued for removal")
    }

    @Test @MainActor func playerContactWithFortressNodeDoesNotOneShot() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Give the node enough HP to survive collisionDamage (15)
        let node = Galaxy3EntityFactory.makeFortressNode(role: .mainBattery, at: .zero, fortressID: 1)
        node.component(ofType: FortressNodeComponent.self)!.isShielded = false
        let nodeHealth = node.component(ofType: HealthComponent.self)!
        nodeHealth.currentHealth = 50  // enough to survive the 15 damage
        let initialHP = nodeHealth.currentHealth

        handler.processCollisions(pairs: [(player, node)])

        #expect(nodeHealth.isAlive, "Fortress node must survive player contact")
        #expect(nodeHealth.currentHealth == initialHP - GameConfig.Player.collisionDamage,
                "Fortress node should take only collisionDamage, not full HP")
        #expect(!ctx.pendingRemovals.contains(where: { $0 === node }))
    }

    @Test @MainActor func playerContactWithShieldedFortressNodeDoesNoDamageToNode() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // Shielded non-generator node
        let node = Galaxy3EntityFactory.makeFortressNode(role: .pulseTurret, at: .zero, fortressID: 1)
        let nodeHealth = node.component(ofType: HealthComponent.self)!
        let initialHP = nodeHealth.currentHealth

        handler.processCollisions(pairs: [(player, node)])

        #expect(nodeHealth.currentHealth == initialHP,
                "Shielded fortress node should take no damage from player ramming")
        // Player still takes damage
        let playerHP = player.component(ofType: HealthComponent.self)!
        #expect(playerHP.currentHealth < 100, "Player should still take collision damage")
    }

    @Test @MainActor func playerContactWithRegularEnemyStillKillsIt() {
        let player = TestEntityFactory.makePlayerEntity()
        player.component(ofType: HealthComponent.self)!.hasInvulnerabilityFrames = false
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemy = TestEntityFactory.makeEnemyEntity(health: 10, scorePoints: 50)

        handler.processCollisions(pairs: [(player, enemy)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }),
                "Regular enemy should still be killed by player contact")
        #expect(ctx.enemiesDestroyed == 1)
    }
}
