# Weapon Balance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebalance all primary and secondary weapons to create distinct power niches per the weapon balance design.

**Architecture:** Numeric tuning in GameConfig, mechanical changes to LightningArcSystem (damage ramp-up tracking) and WeaponSystem (heat-scaled laser damage, tri-spread fire rate override). No new files needed.

**Tech Stack:** Swift, GameplayKit, Swift Testing framework

---

### Task 1: Update GameConfig Constants

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift:44-77`

**Step 1: Update existing constants and add new ones**

In `GameConfig.Weapon`, make these changes:

```swift
public enum Weapon {
    public static let triSpreadAngle: Float = .pi / 9           // was .pi / 12
    public static let triSpreadFireRate: Double = 3.0            // NEW
    public static let triSpreadDamage: Float = 0.7

    public static let gravBombMaxCharges = 3
    public static let gravBombStartCharges = 1
    public static let gravBombDetonateTime: Double = 0.4
    public static let gravBombBlastRadius: Float = 120
    public static let gravBombDamage: Float = 3

    // Lightning Arc
    public static let lightningArcRange: Float = 200
    public static let lightningArcDamagePerTick: Float = 0.6    // was 0.8
    public static let lightningArcTickRate: Double = 10.0
    public static let lightningArcChainTargets: Int = 2
    public static let lightningArcChainDamageFalloff: Float = 0.5
    public static let lightningArcChainRange: Float = 80
    public static let lightningArcRampDuration: Double = 0.5    // NEW
    public static let lightningArcMinRampMultiplier: Float = 0.25 // NEW

    // Phase Laser
    public static let laserTickInterval: Double = 0.1
    public static let laserDamagePerTick: Float = 1.0
    public static let laserWidth: Float = 8
    public static let laserHeatPerSecond: Double = 1.0
    public static let laserCoolPerSecond: Double = 2.0
    public static let laserMaxHeat: Double = 1.0
    public static let laserOverheatCooldown: Double = 1.0
    public static let laserMaxHeatDamageMultiplier: Float = 1.6 // NEW

    // EMP Sweep
    public static let empSlowMoDuration: Double = 0.8           // was 0.3

    // Overcharge Protocol
    public static let overchargeDuration: Double = 4.0          // was 5.0
    public static let overchargeFireRateMultiplier: Double = 2.0
    public static let overchargeHitboxScale: Float = 1.5
}
```

**Step 2: Build to verify no compile errors**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build Succeeded

**Step 3: Run all existing tests to verify nothing broke**

Run: `cd Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests pass

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/GameConfig.swift
git commit -m "balance: update weapon constants — tri-spread, lightning, laser, EMP, overcharge"
```

---

### Task 2: Tri-Spread Fire Rate Override

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift:99-114`
- Test: `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift`

**Step 1: Write the failing test**

Add to `WeaponSystemTests`:

```swift
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
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter triSpreadUsesReducedFireRate 2>&1 | tail -5`
Expected: FAIL — tri-spread fires at 0.25s (old rate) instead of waiting until 0.333s

**Step 3: Implement tri-spread fire rate override**

In `WeaponSystem.swift`, modify lines 99-105. After `} else if weapon.isFiring {`:

```swift
} else if weapon.isFiring {
    // Standard projectile weapons
    weapon.timeSinceLastShot += time.fixedDeltaTime
    var effectiveFireRate = weapon.fireRate
    if weapon.weaponType == .lightningArc {
        effectiveFireRate = GameConfig.Weapon.lightningArcTickRate
    } else if weapon.weaponType == .triSpread {
        effectiveFireRate = GameConfig.Weapon.triSpreadFireRate
    }
    if weapon.overchargeActive {
```

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter triSpreadUsesReducedFireRate 2>&1 | tail -5`
Expected: PASS

**Step 5: Run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift
git commit -m "balance: tri-spread uses dedicated fire rate (3.0) instead of default"
```

---

### Task 3: Lightning Arc Damage Ramp-Up

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/LightningArcSystem.swift`
- Test: `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift`

**Step 1: Write the failing tests**

Add to `WeaponSystemTests`:

```swift
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

    // Run for full ramp duration + a bit extra
    let totalTime = GameConfig.Weapon.lightningArcRampDuration + 0.1
    let steps = Int(totalTime / (1.0 / 60.0))
    for _ in 0..<steps {
        system.update(deltaTime: 1.0 / 60.0)
    }

    let lastDamage = system.pendingDamage.last!.damage
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
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter lightningArcRamp 2>&1 | tail -10`
Expected: FAIL — current system applies flat damage with no ramp

**Step 3: Implement ramp-up in LightningArcSystem**

Replace `LightningArcSystem.swift` with ramp tracking. Add two properties and modify the damage section:

```swift
@MainActor
public final class LightningArcSystem {
    private weak var playerEntity: GKEntity?
    private var enemies: [GKEntity] = []
    public private(set) var activeArcs: [ArcSegment] = []
    public private(set) var pendingDamage: [(entity: GKEntity, damage: Float)] = []

    private var tickAccumulator: Double = 0

    // Ramp-up tracking
    private weak var currentPrimaryTarget: GKEntity?
    private var rampTimer: Double = 0

    public init(player: GKEntity) {
        self.playerEntity = player
    }

    public func registerEnemy(_ entity: GKEntity) {
        enemies.append(entity)
    }

    public func unregisterEnemy(_ entity: GKEntity) {
        enemies.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        activeArcs.removeAll(keepingCapacity: true)
        pendingDamage.removeAll(keepingCapacity: true)

        guard let player = playerEntity,
              let weapon = player.component(ofType: WeaponComponent.self),
              weapon.weaponType == .lightningArc,
              weapon.isFiring,
              let playerTransform = player.component(ofType: TransformComponent.self) else {
            tickAccumulator = 0
            currentPrimaryTarget = nil
            rampTimer = 0
            return
        }

        let playerPos = playerTransform.position
        let range = GameConfig.Weapon.lightningArcRange
        let chainRange = GameConfig.Weapon.lightningArcChainRange
        let maxChains = GameConfig.Weapon.lightningArcChainTargets
        let falloff = GameConfig.Weapon.lightningArcChainDamageFalloff
        let baseDamage = GameConfig.Weapon.lightningArcDamagePerTick

        // Find primary target: nearest enemy within range
        var primaryTarget: GKEntity?
        var bestDist: Float = range
        for enemy in enemies {
            guard let health = enemy.component(ofType: HealthComponent.self),
                  health.isAlive,
                  let transform = enemy.component(ofType: TransformComponent.self) else { continue }
            let dist = simd_distance(playerPos, transform.position)
            if dist < bestDist {
                bestDist = dist
                primaryTarget = enemy
            }
        }

        guard let primary = primaryTarget,
              let primaryTransform = primary.component(ofType: TransformComponent.self) else {
            tickAccumulator = 0
            currentPrimaryTarget = nil
            rampTimer = 0
            return
        }

        // Ramp-up: reset if primary target changed
        if primary !== currentPrimaryTarget {
            currentPrimaryTarget = primary
            rampTimer = 0
        }
        rampTimer = min(rampTimer + deltaTime, GameConfig.Weapon.lightningArcRampDuration)

        // Calculate ramp multiplier: lerp from minRamp to 1.0
        let rampProgress = Float(rampTimer / GameConfig.Weapon.lightningArcRampDuration)
        let minRamp = GameConfig.Weapon.lightningArcMinRampMultiplier
        let rampMultiplier = minRamp + (1.0 - minRamp) * rampProgress

        // Build arc chain
        var chainTargets: [GKEntity] = [primary]
        var lastPos = primaryTransform.position

        for _ in 0..<maxChains {
            var nextTarget: GKEntity?
            var nextDist: Float = chainRange
            for enemy in enemies {
                guard !chainTargets.contains(where: { $0 === enemy }),
                      let health = enemy.component(ofType: HealthComponent.self),
                      health.isAlive,
                      let transform = enemy.component(ofType: TransformComponent.self) else { continue }
                let dist = simd_distance(lastPos, transform.position)
                if dist < nextDist {
                    nextDist = dist
                    nextTarget = enemy
                }
            }
            guard let next = nextTarget,
                  let nextTransform = next.component(ofType: TransformComponent.self) else { break }
            chainTargets.append(next)
            lastPos = nextTransform.position
        }

        // Build visual arc segments (always, for smooth visuals)
        var prevPos = playerPos
        for (i, target) in chainTargets.enumerated() {
            guard let transform = target.component(ofType: TransformComponent.self) else { continue }
            let multiplier = powf(falloff, Float(i))
            activeArcs.append(ArcSegment(from: prevPos, to: transform.position, damageMultiplier: multiplier))
            prevPos = transform.position
        }

        // Apply damage on tick interval
        tickAccumulator += deltaTime
        let tickInterval = 1.0 / GameConfig.Weapon.lightningArcTickRate
        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            for (i, target) in chainTargets.enumerated() {
                let chainFalloff = powf(falloff, Float(i))
                pendingDamage.append((entity: target, damage: baseDamage * rampMultiplier * chainFalloff))
            }
        }
    }
}
```

**Step 4: Run ramp tests to verify they pass**

Run: `cd Engine2043 && swift test --filter lightningArcRamp 2>&1 | tail -10`
Expected: All 3 ramp tests PASS

**Step 5: Run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/LightningArcSystem.swift Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift
git commit -m "balance: lightning arc damage ramp-up — 25% to 100% over 0.5s on same target"
```

---

### Task 4: Phase Laser Heat-Scaled Damage

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift:78-87`
- Test: `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift`

**Step 1: Write the failing tests**

Add to `WeaponSystemTests`:

```swift
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
    for _ in 0..<steps {
        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        _ = time.shouldPerformFixedUpdate()
        system.update(time: time)
    }

    // Get the last hitscan request — it should have scaled damage
    let lastHitscan = system.pendingLaserHitscans.last!
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

    // First tick — heat should be near 0
    var time = GameTime()
    time.advance(by: GameConfig.Weapon.laserTickInterval)
    _ = time.shouldPerformFixedUpdate()
    system.update(time: time)

    // First hitscan should be very close to base damage
    guard let firstHitscan = system.pendingLaserHitscans.first else {
        #expect(Bool(false), "Should have a laser hitscan")
        return
    }
    #expect(firstHitscan.damagePerTick >= 1.0, "Initial damage should be at least base")
    #expect(firstHitscan.damagePerTick < 1.15, "Initial damage should be near base (low heat)")
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter phaseLaser 2>&1 | tail -10`
Expected: FAIL — current code uses flat `laserDamagePerTick` regardless of heat

**Step 3: Implement heat-scaled damage**

In `WeaponSystem.swift`, modify the laser hitscan creation (lines 82-86). Replace the `pendingLaserHitscans.append` block:

```swift
                    // Fire damage ticks
                    let tickInterval = GameConfig.Weapon.laserTickInterval
                    if weapon.timeSinceLastShot >= tickInterval {
                        weapon.timeSinceLastShot -= tickInterval
                        let heatRatio = Float(weapon.laserHeat / GameConfig.Weapon.laserMaxHeat)
                        let heatMultiplier = 1.0 + heatRatio * (GameConfig.Weapon.laserMaxHeatDamageMultiplier - 1.0)
                        pendingLaserHitscans.append(LaserHitscanRequest(
                            position: transform.position,
                            width: GameConfig.Weapon.laserWidth,
                            damagePerTick: GameConfig.Weapon.laserDamagePerTick * heatMultiplier
                        ))
                    }
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter phaseLaser 2>&1 | tail -10`
Expected: PASS

**Step 5: Run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift
git commit -m "balance: phase laser damage scales 1.0x to 1.6x with heat buildup"
```

---

### Task 5: Final Verification

**Files:** None (verification only)

**Step 1: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass, 0 failures

**Step 2: Build for both platforms**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build Succeeded

**Step 3: Verify GameConfig values are correct**

Spot-check by reading `GameConfig.swift` and confirming:
- `triSpreadAngle` = π/9
- `triSpreadFireRate` = 3.0
- `lightningArcDamagePerTick` = 0.6
- `lightningArcRampDuration` = 0.5
- `lightningArcMinRampMultiplier` = 0.25
- `laserMaxHeatDamageMultiplier` = 1.6
- `empSlowMoDuration` = 0.8
- `overchargeDuration` = 4.0

**Step 4: Commit (if any test fixes were needed)**

Only if changes were made during verification.
