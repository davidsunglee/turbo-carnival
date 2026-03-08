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

    @Test @MainActor func lightningArcRampStartsAtMinMultiplier() {
        let player = GKEntity()
        player.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .lightningArc
        weapon.isFiring = true
        player.addComponent(weapon)

        let enemy = GKEntity()
        enemy.addComponent(TransformComponent(position: SIMD2(0, 100)))
        enemy.addComponent(HealthComponent(health: 20))

        let system = LightningArcSystem(player: player)
        system.registerEnemy(enemy)

        // Single tick at tick rate interval
        let tickInterval = 1.0 / GameConfig.Weapon.lightningArcTickRate
        system.update(deltaTime: tickInterval)

        #expect(!system.pendingDamage.isEmpty)
        let damage = system.pendingDamage[0].damage
        let expectedMinDamage = GameConfig.Weapon.lightningArcDamagePerTick * GameConfig.Weapon.lightningArcMinRampMultiplier
        #expect(abs(damage - expectedMinDamage) < 0.01, "Initial damage should be base * minRampMultiplier (0.6 * 0.25 = 0.15)")
    }

    @Test @MainActor func lightningArcRampReachesFullDamageAfterDuration() {
        let player = GKEntity()
        player.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .lightningArc
        weapon.isFiring = true
        player.addComponent(weapon)

        let enemy = GKEntity()
        enemy.addComponent(TransformComponent(position: SIMD2(0, 100)))
        enemy.addComponent(HealthComponent(health: 100))

        let system = LightningArcSystem(player: player)
        system.registerEnemy(enemy)

        // Run for full ramp duration + a bit extra, collecting all damage values
        let totalTime = GameConfig.Weapon.lightningArcRampDuration + 0.1
        let steps = Int(totalTime / (1.0 / 60.0))
        var allDamage: [Float] = []
        for _ in 0..<steps {
            system.update(deltaTime: 1.0 / 60.0)
            allDamage.append(contentsOf: system.pendingDamage.map { $0.damage })
        }

        let lastDamage = allDamage.last!
        let baseDamage = GameConfig.Weapon.lightningArcDamagePerTick
        #expect(abs(lastDamage - baseDamage) < 0.01, "After ramp duration, damage should be full base damage (0.6)")
    }

    @Test @MainActor func lightningArcRampResetsOnTargetChange() {
        let player = GKEntity()
        player.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .lightningArc
        weapon.isFiring = true
        player.addComponent(weapon)

        let enemy1 = GKEntity()
        enemy1.addComponent(TransformComponent(position: SIMD2(0, 100)))
        enemy1.addComponent(HealthComponent(health: 100))

        let enemy2 = GKEntity()
        enemy2.addComponent(TransformComponent(position: SIMD2(0, 200)))
        enemy2.addComponent(HealthComponent(health: 100))

        let system = LightningArcSystem(player: player)
        system.registerEnemy(enemy1)
        system.registerEnemy(enemy2)

        // Ramp on enemy1 for 0.3s
        let steps = Int(0.3 / (1.0 / 60.0))
        for _ in 0..<steps {
            system.update(deltaTime: 1.0 / 60.0)
        }

        // Now move enemy2 closer so it becomes the primary target
        enemy2.component(ofType: TransformComponent.self)!.position = SIMD2(0, 50)
        enemy1.component(ofType: TransformComponent.self)!.position = SIMD2(0, 200)

        // Next tick should reset ramp — damage on primary should be back to min
        let tickInterval = 1.0 / GameConfig.Weapon.lightningArcTickRate
        system.update(deltaTime: tickInterval)

        // Find damage applied to enemy2 (the new primary)
        let enemy2Damage = system.pendingDamage.filter { $0.entity === enemy2 }
        #expect(!enemy2Damage.isEmpty)
        let expectedMinDamage = GameConfig.Weapon.lightningArcDamagePerTick * GameConfig.Weapon.lightningArcMinRampMultiplier
        #expect(abs(enemy2Damage[0].damage - expectedMinDamage) < 0.01, "Ramp should reset when primary target changes")
    }

    @Test @MainActor func phaseLaserDamageScalesWithHeat() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .phaseLaser
        weapon.isFiring = true
        entity.addComponent(weapon)

        system.register(entity)

        // Run for 0.5s (half heat buildup). Heat = 0.5, maxHeat = 1.0.
        // Expected multiplier at heat=0.5: 1.0 + (0.5/1.0) * (1.6 - 1.0) = 1.3
        // Expected damagePerTick: 1.0 * 1.3 = 1.3
        let steps = Int(0.5 / GameConfig.fixedTimeStep)
        var allHitscans: [LaserHitscanRequest] = []
        for _ in 0..<steps {
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            _ = time.shouldPerformFixedUpdate()
            system.update(time: time)
            allHitscans.append(contentsOf: system.pendingLaserHitscans)
        }

        // Get the last hitscan request — it should have scaled damage
        let lastHitscan = allHitscans.last!
        // At heat ~0.5, damage should be ~1.3 (between 1.0 and 1.6)
        #expect(lastHitscan.damagePerTick > 1.1, "Laser damage should scale up with heat")
        #expect(lastHitscan.damagePerTick < 1.5, "Laser damage should not exceed expected mid-heat value")
    }

    @Test @MainActor func phaseLaserDamageStartsAtBase() {
        let system = WeaponSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
        let weapon = WeaponComponent(fireRate: 4, damage: 1, projectileSpeed: 500)
        weapon.weaponType = .phaseLaser
        weapon.isFiring = true
        entity.addComponent(weapon)

        system.register(entity)

        // Run enough frames to produce a laser hitscan (tick interval = 0.1s)
        // +1 to handle floating-point accumulation not reaching exact threshold
        let steps = Int(ceil(GameConfig.Weapon.laserTickInterval / GameConfig.fixedTimeStep)) + 1
        var allHitscans: [LaserHitscanRequest] = []
        for _ in 0..<steps {
            var time = GameTime()
            time.advance(by: GameConfig.fixedTimeStep)
            _ = time.shouldPerformFixedUpdate()
            system.update(time: time)
            allHitscans.append(contentsOf: system.pendingLaserHitscans)
        }

        // First hitscan should be very close to base damage
        guard let firstHitscan = allHitscans.first else {
            #expect(Bool(false), "Should have a laser hitscan")
            return
        }
        #expect(firstHitscan.damagePerTick >= 1.0, "Initial damage should be at least base")
        #expect(firstHitscan.damagePerTick < 1.15, "Initial damage should be near base (low heat)")
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
