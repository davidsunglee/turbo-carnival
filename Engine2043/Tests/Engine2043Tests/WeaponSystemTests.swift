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

        // Advance exactly to tri-spread fire rate interval so fire happens on last update
        let steps = Int(ceil(1.0 / GameConfig.Weapon.triSpreadFireRate / GameConfig.fixedTimeStep))
        for _ in 0..<steps {
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            _ = time.shouldPerformFixedUpdate()
            system.update(time: time)
        }

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

    @Test @MainActor func lightningArcDoesNotSpawnProjectiles() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .lightningArc
        weapon.isFiring = true
        weapon.timeSinceLastShot = 1.0
        entity.addComponent(weapon)

        system.register(entity)

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        _ = time.shouldPerformFixedUpdate()
        system.update(time: time)

        #expect(system.pendingSpawns.isEmpty, "Lightning Arc should not create projectile spawns")
    }

    @Test @MainActor func triSpreadUsesReducedFireRate() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4.0, damage: 0.7, projectileSpeed: 500)
        weapon.weaponType = .triSpread
        weapon.isFiring = true
        entity.addComponent(weapon)

        system.register(entity)

        // At default fireRate 4.0, interval is 0.25s. At triSpreadFireRate 3.0, interval is 0.333s.
        // Advance 0.26s — should fire at 4.0 rate but NOT at 3.0 rate.
        let steps = Int(0.26 / GameConfig.fixedTimeStep)
        for _ in 0..<steps {
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            _ = time.shouldPerformFixedUpdate()
            system.update(time: time)
        }

        // If tri-spread correctly uses 3.0 fire rate, no shots should have fired yet
        // (0.26s < 0.333s interval). Only the very first tick fires immediately since
        // timeSinceLastShot starts at 0.
        // Actually: timeSinceLastShot starts at 0. First tick adds 1/60. interval = 1/3 = 0.333.
        // After 0.26s (≈16 ticks), timeSinceLastShot ≈ 0.267 < 0.333, so no shots.
        // Wait: first update timeSinceLastShot = 1/60 = 0.0167. Still < 0.333. No shot.
        // After 16 updates: timeSinceLastShot ≈ 0.267. Still < 0.333. No shot.
        #expect(system.pendingSpawns.isEmpty, "Tri-spread should not fire within 0.26s at 3.0 fire rate")

        // Now advance past 0.333s total — should fire
        let moreSteps = Int(0.08 / GameConfig.fixedTimeStep) + 1
        for _ in 0..<moreSteps {
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            _ = time.shouldPerformFixedUpdate()
            system.update(time: time)
        }

        #expect(system.pendingSpawns.count == 3, "Tri-spread should fire 3 projectiles after 0.333s")
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
