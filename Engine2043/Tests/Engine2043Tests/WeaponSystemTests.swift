import Testing
import GameplayKit
import simd
@testable import Engine2043

struct WeaponSystemTests {
    @Test @MainActor func weaponSystemDoubleCannonSpawnsTwoProjectiles() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 60, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .doubleCannon
        weapon.isFiring = true
        entity.addComponent(weapon)

        system.register(entity)

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        _ = time.shouldPerformFixedUpdate()
        system.update(time: time)

        #expect(system.pendingSpawns.count == 2)
        // Both fire upward
        #expect(system.pendingSpawns[0].velocity.y > 0)
        #expect(system.pendingSpawns[1].velocity.y > 0)
    }

    @Test @MainActor func weaponSystemTriSpreadSpawnsThreeProjectiles() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 60, damage: 0.7, projectileSpeed: 500)
        weapon.weaponType = .triSpread
        weapon.isFiring = true
        entity.addComponent(weapon)

        system.register(entity)

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        _ = time.shouldPerformFixedUpdate()
        system.update(time: time)

        #expect(system.pendingSpawns.count == 3)
        // Center projectile goes straight up
        #expect(system.pendingSpawns[0].velocity.x == 0)
        #expect(system.pendingSpawns[0].velocity.y > 0)
        // Left projectile has negative X
        #expect(system.pendingSpawns[1].velocity.x < 0)
        // Right projectile has positive X
        #expect(system.pendingSpawns[2].velocity.x > 0)
    }

    @Test @MainActor func weaponSystemSecondaryFireCreatesSpawn() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 8, damage: 1, projectileSpeed: 500)
        weapon.secondaryCharges = 1
        weapon.secondaryFiring = .gravBomb
        weapon.secondaryCooldown = 0.5  // Ready to fire
        entity.addComponent(weapon)

        system.register(entity)

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        _ = time.shouldPerformFixedUpdate()
        system.update(time: time)

        #expect(system.pendingSecondarySpawns.count == 1)
        #expect(weapon.secondaryCharges == 0)
    }

    @Test @MainActor func weaponSystemEnemyFiresDownward() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        let weapon = WeaponComponent(fireRate: 60, damage: 5, projectileSpeed: 250)
        weapon.isFiring = true
        weapon.firesDownward = true
        entity.addComponent(weapon)

        system.register(entity)

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        _ = time.shouldPerformFixedUpdate()
        system.update(time: time)

        #expect(system.pendingSpawns.count > 0)
        #expect(system.pendingSpawns[0].velocity.y < 0)
    }
}
