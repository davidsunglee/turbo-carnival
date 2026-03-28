import Testing
import GameplayKit
import simd
@testable import Engine2043

@MainActor
private final class MockCollisionContext: CollisionContext {
    var player: GKEntity!
    let scoreSystem = ScoreSystem()
    let itemSystem = ItemSystem()
    var sfx: SynthAudioEngine? = nil
    var pendingRemovals: [GKEntity] = []
    var enemiesDestroyed: Int = 0
    var formationWipeChecked: [GKEntity] = []
    var shieldDronesSpawned = 0

    init(player: GKEntity) {
        self.player = player
    }

    func checkFormationWipe(enemy: GKEntity) {
        formationWipeChecked.append(enemy)
    }

    func spawnShieldDrones() {
        shieldDronesSpawned += 1
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
}
