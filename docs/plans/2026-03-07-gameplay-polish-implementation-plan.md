# Gameplay Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tighten wave pacing, replace Vulcan Auto-Gun with Lightning Arc weapon, and overhaul the drop system for fewer/less predictable drops.

**Architecture:** Three independent changes that touch different systems. Wave compression is a data-only change. Lightning Arc replaces the Vulcan weapon across all layers (component, system, config, rendering, audio). Drop overhaul changes spawn logic from guaranteed-random to scripted-weapons + probabilistic-utilities.

**Tech Stack:** Swift, GameplayKit (GKEntity/GKComponent), Metal (rendering), CoreAudio (synth)

---

### Task 1: Compress Wave Trigger Distances

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift:60-99`

**Step 1: Update all triggerDistance values**

Replace the wave definitions in the `galaxy1Waves()` function (lines 60-99) with compressed values (~40% compression). Keep all other wave properties identical.

```swift
public static func galaxy1Waves() -> [WaveDefinition] {
    return [
        // -- Tutorial ramp (was 50-400, now 50-260)
        WaveDefinition(trigger: 50,   tier: .tier1, pattern: .vShape,        count: 5),
        WaveDefinition(trigger: 155,  tier: .tier1, pattern: .vShape,        count: 5),
        WaveDefinition(trigger: 260,  tier: .tier1, pattern: .vShape,        count: 5),

        // -- Escalation (was 550-1100, now 350-700)
        WaveDefinition(trigger: 350,  tier: .tier1, pattern: .sineWave,      count: 5),
        WaveDefinition(trigger: 440,  tier: .tier1, pattern: .staggeredLine, count: 5),
        WaveDefinition(trigger: 500,  tier: .tier2, pattern: .vShape,        count: 2, spawnX: -60),
        WaveDefinition(trigger: 560,  tier: .tier1, pattern: .sineWave,      count: 5),
        WaveDefinition(trigger: 700,  tier: .tier1, pattern: .vShape,        count: 5),

        // -- Capital ship approach (was 1250-1900, now 800-1200)
        WaveDefinition(trigger: 800,  tier: .tier2, pattern: .vShape,        count: 3, spawnX: 50),
        WaveDefinition(trigger: 880,  tier: .tier1, pattern: .sineWave,      count: 5),
        WaveDefinition(trigger: 960,  tier: .tier1, pattern: .staggeredLine, count: 5),
        WaveDefinition(trigger: 1020, tier: .tier2, pattern: .vShape,        count: 2, spawnX: -40),
        WaveDefinition(trigger: 1120, tier: .tier1, pattern: .vShape,        count: 5),
        WaveDefinition(trigger: 1200, tier: .tier1, pattern: .sineWave,      count: 5),

        // -- Capital ship battle (was 2000-2500, now 1250-1550)
        WaveDefinition(trigger: 1250, tier: .tier3, pattern: .vShape,        count: 4),
        WaveDefinition(trigger: 1370, tier: .tier1, pattern: .vShape,        count: 5),
        WaveDefinition(trigger: 1550, tier: .tier1, pattern: .sineWave,      count: 5),

        // -- Final gauntlet (was 2800-3300, now 1700-2000)
        WaveDefinition(trigger: 1700, tier: .tier2, pattern: .vShape,        count: 3),
        WaveDefinition(trigger: 1760, tier: .tier1, pattern: .staggeredLine, count: 5),
        WaveDefinition(trigger: 1880, tier: .tier2, pattern: .vShape,        count: 2, spawnX: -80),
        WaveDefinition(trigger: 1940, tier: .tier1, pattern: .vShape,        count: 5),
        WaveDefinition(trigger: 2000, tier: .tier1, pattern: .sineWave,      count: 5),

        // -- Boss (was 3500, now 2150)
        WaveDefinition(trigger: 2150, tier: .boss,  pattern: .vShape,        count: 1),
    ]
}
```

**Step 2: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift
git commit -m "feat: compress wave timing ~40% for tighter pacing"
```

---

### Task 2: Rename Vulcan to Lightning Arc — Component & Config

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift:6`
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift:53-56,114`

**Step 1: Rename enum case in WeaponComponent.swift**

At line 6, replace:
```swift
case vulcanAutoGun = 2
```
with:
```swift
case lightningArc = 2
```

**Step 2: Replace Vulcan config constants in GameConfig.swift**

Replace lines 53-56 (the `// Vulcan Auto-Gun` block) with:

```swift
// Lightning Arc
public static let lightningArcRange: Float = 200
public static let lightningArcDamagePerTick: Float = 0.8
public static let lightningArcTickRate: Double = 10.0
public static let lightningArcChainTargets: Int = 2
public static let lightningArcChainDamageFalloff: Float = 0.5
public static let lightningArcChainRange: Float = 80
```

At line 114, replace:
```swift
public static let weaponVulcan = SIMD4<Float>(1.0, 0.2, 0.2, 1.0)
```
with:
```swift
public static let weaponLightningArc = SIMD4<Float>(0.4, 0.7, 1.0, 1.0)
```

**Step 3: Build — expect errors from other files still referencing vulcan**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`
Expected: Multiple errors referencing `vulcanAutoGun`, `vulcanDamage`, `vulcanFireRateMultiplier`, `weaponVulcan`, etc. This is expected — we'll fix these in subsequent tasks.

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift Engine2043/Sources/Engine2043/Core/GameConfig.swift
git commit -m "feat: rename vulcanAutoGun to lightningArc, add arc config constants"
```

---

### Task 3: Implement Lightning Arc in WeaponSystem

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift:103-104,190-195`

**Step 1: Replace Vulcan fire-rate logic with Lightning Arc tick logic**

At lines 103-104, replace:
```swift
if weapon.weaponType == .vulcanAutoGun {
    effectiveFireRate *= GameConfig.Weapon.vulcanFireRateMultiplier
}
```
with:
```swift
if weapon.weaponType == .lightningArc {
    effectiveFireRate = GameConfig.Weapon.lightningArcTickRate
}
```

**Step 2: Replace Vulcan projectile spawn with Lightning Arc spawn**

At lines 190-195, replace the `.vulcanAutoGun` case:
```swift
case .vulcanAutoGun:
    pendingSpawns.append(ProjectileSpawnRequest(
        position: position,
        velocity: SIMD2(0, weapon.projectileSpeed * direction),
        damage: GameConfig.Weapon.vulcanDamage
    ))
```
with:
```swift
case .lightningArc:
    // Lightning arc uses hitscan-style targeting, not projectiles.
    // Primary target acquisition and chain logic handled by LightningArcSystem.
    break
```

**Step 3: Build to check progress**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`
Expected: Fewer errors now — remaining ones in SpriteFactory, Audio, Galaxy1Scene, ItemSystem, tests.

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift
git commit -m "feat: wire lightningArc tick rate in WeaponSystem, remove projectile spawn"
```

---

### Task 4: Create LightningArcSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/LightningArcSystem.swift`

**Step 1: Write the LightningArcSystem**

This system handles target acquisition, chain targeting, and damage application for the Lightning Arc weapon. It outputs arc segment data for the renderer.

```swift
import GameplayKit

public struct ArcSegment: Sendable {
    public let from: SIMD2<Float>
    public let to: SIMD2<Float>
    public let damageMultiplier: Float
}

@MainActor
public final class LightningArcSystem {
    private weak var playerEntity: GKEntity?
    private var enemies: [GKEntity] = []
    public private(set) var activeArcs: [ArcSegment] = []
    public private(set) var pendingDamage: [(entity: GKEntity, damage: Float)] = []

    private var tickAccumulator: Double = 0

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
            return
        }

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
                let multiplier = powf(falloff, Float(i))
                pendingDamage.append((entity: target, damage: baseDamage * multiplier))
            }
        }
    }
}
```

**Step 2: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/LightningArcSystem.swift
git commit -m "feat: add LightningArcSystem with auto-target and chain logic"
```

---

### Task 5: Wire LightningArcSystem into Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add system property**

Near other system declarations (search for `var weaponSystem` or similar), add:
```swift
private var lightningArcSystem: LightningArcSystem!
```

**Step 2: Initialize the system**

In the scene setup method (where other systems are initialized, search for `weaponSystem =`), add:
```swift
lightningArcSystem = LightningArcSystem(player: player)
```

**Step 3: Register enemies with the system**

In enemy spawning functions (the Tier1/Tier2 spawn methods), after creating each enemy entity add:
```swift
lightningArcSystem.registerEnemy(entity)
```

**Step 4: Unregister enemies on removal**

In the enemy removal/cleanup code (search for `pendingRemovals` processing), add:
```swift
lightningArcSystem.unregisterEnemy(entity)
```

**Step 5: Call update in the game loop**

In the fixed update method (search for `weaponSystem.update`), add nearby:
```swift
lightningArcSystem.update(deltaTime: time.fixedDeltaTime)
```

**Step 6: Process pending damage**

After the `lightningArcSystem.update` call, add:
```swift
for (entity, damage) in lightningArcSystem.pendingDamage {
    if let health = entity.component(ofType: HealthComponent.self) {
        health.currentHealth -= damage
    }
}
```

**Step 7: Update weapon fire SFX switch**

At lines 785-792, replace:
```swift
case .vulcanAutoGun: sfx?.play(.vulcanFire)
```
with:
```swift
case .lightningArc: break // handled by continuous audio in render loop
```

**Step 8: Update HUD weapon color switch**

At line 413, replace:
```swift
case .vulcanAutoGun: weaponColor = SIMD4(1, 0.3, 0.3, 0.8)
```
with:
```swift
case .lightningArc: weaponColor = GameConfig.Palette.weaponLightningArc
```

**Step 9: Update weapon damage switch in handlePlayerCollectsItem**

At lines 1173-1174, replace:
```swift
case .doubleCannon, .vulcanAutoGun:
    weapon.damage = GameConfig.Player.damage
```
with:
```swift
case .doubleCannon:
    weapon.damage = GameConfig.Player.damage
case .lightningArc:
    weapon.damage = GameConfig.Weapon.lightningArcDamagePerTick
```

**Step 10: Update weapon module cycle list**

At line 885, replace:
```swift
let allWeapons: [WeaponType] = [.doubleCannon, .triSpread, .vulcanAutoGun, .phaseLaser]
```
with:
```swift
let allWeapons: [WeaponType] = [.doubleCannon, .triSpread, .lightningArc, .phaseLaser]
```

**Step 11: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 12: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire LightningArcSystem into Galaxy1Scene"
```

---

### Task 6: Lightning Arc Sprite & Rendering

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift:482-519`
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift:13,36,85`

**Step 1: Replace makeVulcanBullet with makeLightningArcIcon in SpriteFactory**

Replace the entire `makeVulcanBullet()` function (lines 482-519) with a Lightning Arc icon for the weapon module display. The actual arc rendering will use procedural line drawing, not sprites.

```swift
// MARK: - Lightning Arc Icon (8x8)
// Electric bolt icon for weapon module display.

public static func makeLightningArcIcon() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 8, h = 8
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    // Cyan-white lightning bolt shape
    ctx.setStrokeColor(cgColor(100, 180, 255))
    ctx.setLineWidth(2)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 5, y: 0))
    ctx.addLine(to: CGPoint(x: 3, y: 3))
    ctx.addLine(to: CGPoint(x: 5, y: 3))
    ctx.addLine(to: CGPoint(x: 3, y: 7))
    ctx.strokePath()

    // Bright white core
    ctx.setStrokeColor(cgColor(220, 240, 255))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 5, y: 0))
    ctx.addLine(to: CGPoint(x: 3, y: 3))
    ctx.addLine(to: CGPoint(x: 5, y: 3))
    ctx.addLine(to: CGPoint(x: 3, y: 7))
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 2: Update TextureAtlas sprite names**

At line 13, replace `"vulcanBullet"` with `"lightningArcIcon"` in the spriteNames set.

**Step 3: Update TextureAtlas layout**

At line 36, replace:
```swift
SpriteEntry(name: "vulcanBullet",    x: 14,  y: 172, width: 4,  height: 8),
```
with:
```swift
SpriteEntry(name: "lightningArcIcon", x: 14, y: 172, width: 8, height: 8),
```

**Step 4: Update TextureAtlas generator mapping**

At line 85, replace:
```swift
("vulcanBullet",    SpriteFactory.makeVulcanBullet),
```
with:
```swift
("lightningArcIcon", SpriteFactory.makeLightningArcIcon),
```

**Step 5: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift
git commit -m "feat: add lightning arc icon sprite, replace vulcan bullet"
```

---

### Task 7: Lightning Arc Procedural Rendering

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift` (render loop)

The Lightning Arc needs to draw jagged electric arcs between the player and chain targets. This should be done in the render pass using the `activeArcs` data from `LightningArcSystem`.

**Step 1: Find the render method**

Search for where the renderer draws entities or where the Phase Laser beam is drawn — the lightning arcs should be drawn similarly. Search for `laserBeam` or `drawLine` or the render pass where custom geometry is submitted.

**Step 2: Add arc rendering after the laser beam rendering**

After wherever the phase laser beam is drawn, add lightning arc rendering. For each `ArcSegment` in `lightningArcSystem.activeArcs`, draw a jagged line with 3-4 random intermediate points:

```swift
// Draw lightning arcs
for arc in lightningArcSystem.activeArcs {
    let segments = 4
    var points: [SIMD2<Float>] = [arc.from]
    for i in 1..<segments {
        let t = Float(i) / Float(segments)
        let mid = arc.from + (arc.to - arc.from) * t
        let jitter = SIMD2<Float>(Float.random(in: -6...6), Float.random(in: -6...6))
        points.append(mid + jitter)
    }
    points.append(arc.to)

    let alpha = 0.6 + arc.damageMultiplier * 0.4
    // Outer glow (cyan)
    let glowColor = SIMD4<Float>(0.3, 0.6, 1.0, alpha * 0.5)
    for i in 0..<points.count - 1 {
        renderer.drawLine(from: points[i], to: points[i + 1], color: glowColor, width: 3)
    }
    // Inner core (white-blue)
    let coreColor = SIMD4<Float>(0.8, 0.9, 1.0, alpha)
    for i in 0..<points.count - 1 {
        renderer.drawLine(from: points[i], to: points[i + 1], color: coreColor, width: 1)
    }
}
```

Note: The exact renderer API will need to be adapted to match what already exists (check how Phase Laser beam is drawn). If the renderer doesn't have `drawLine`, the arc segments may need to be submitted as thin quads or use the existing effect rendering system. Check the actual renderer API before implementing.

**Step 3: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: add procedural lightning arc rendering with jitter"
```

---

### Task 8: Lightning Arc Audio

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SFXType.swift:4`
- Modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift:50,110`

**Step 1: Rename SFX type**

In SFXType.swift at line 4, replace:
```swift
case vulcanFire
```
with:
```swift
case lightningArcZap
```

**Step 2: Update cooldown in SynthAudioEngine**

At line 50, replace:
```swift
.vulcanFire: 0.06,
```
with:
```swift
.lightningArcZap: 0.08,
```

**Step 3: Replace sound synthesis**

At line 110, replace:
```swift
buffers[.vulcanFire] = synthesize(duration: 0.04, generator: sawtoothSweep(from: 880, to: 660))
```
with a crackling electric zap sound:
```swift
buffers[.lightningArcZap] = synthesize(duration: 0.06, generator: { t, progress in
    // White noise burst with resonant filter for electric crackle
    let noise = Float.random(in: -1...1)
    let freq: Float = 1200 - 600 * progress
    let resonance = sin(freq * t * .pi * 2) * 0.3
    let envelope = 1.0 - progress * 0.7
    return (noise * 0.6 + resonance) * envelope
})
```

**Step 4: Trigger the zap on each damage tick**

In Galaxy1Scene, where `lightningArcSystem.pendingDamage` is processed (added in Task 5), add a sound trigger:
```swift
if !lightningArcSystem.pendingDamage.isEmpty {
    sfx?.play(.lightningArcZap)
}
```

**Step 5: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/SFXType.swift Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: add lightning arc crackling zap SFX"
```

---

### Task 9: Update ItemSystem Vulcan References

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift:58`

**Step 1: Replace vulcan reference in weapon module color switch**

At line 58, replace:
```swift
case .vulcanAutoGun: render.color = GameConfig.Palette.weaponVulcan
```
with:
```swift
case .lightningArc: render.color = GameConfig.Palette.weaponLightningArc
```

**Step 2: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`
Expected: No more vulcan-related errors.

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift
git commit -m "feat: update ItemSystem weapon color for lightning arc"
```

---

### Task 10: Update Tests

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift`

**Step 1: Add a Lightning Arc test**

Add a test verifying that Lightning Arc does NOT spawn projectiles (since it uses LightningArcSystem instead):

```swift
func testLightningArcDoesNotSpawnProjectiles() {
    let entity = GKEntity()
    let transform = TransformComponent(position: .zero)
    entity.addComponent(transform)

    let weapon = WeaponComponent()
    weapon.weaponType = .lightningArc
    weapon.isFiring = true
    weapon.fireRate = 4.0
    weapon.timeSinceLastShot = 1.0  // enough to trigger
    entity.addComponent(weapon)

    weaponSystem.register(entity)

    let time = GameTime()
    time.advance(fixedDeltaTime: 1.0 / 60.0)
    weaponSystem.update(time: time)

    XCTAssertTrue(weaponSystem.pendingSpawns.isEmpty, "Lightning Arc should not create projectile spawns")
}
```

**Step 2: Fix any existing tests that reference vulcanAutoGun**

Search for `vulcanAutoGun` in the test file and replace with `lightningArc`.

**Step 3: Run tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test 2>&1 | tail -20`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift
git commit -m "test: add lightning arc test, update vulcan references"
```

---

### Task 11: Overhaul Drop System — Scripted Weapon Drops

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add weapon drop triggers to SpawnDirector**

Add a new type or flag to represent scripted weapon drops. In SpawnDirector, add two scripted weapon drop events at ~1/3 and ~2/3 of the compressed stage (715 and 1430 scroll distance):

Option A (simplest): Add a new property to WaveDefinition or a separate array. Since weapon drops aren't waves, add a simple parallel structure:

```swift
public struct ScriptedDrop: Sendable {
    public let triggerDistance: Float
    public let type: ScriptedDropType

    public enum ScriptedDropType: Sendable {
        case weaponModule
    }
}

public static func galaxy1ScriptedDrops() -> [ScriptedDrop] {
    return [
        ScriptedDrop(triggerDistance: 715, type: .weaponModule),
        ScriptedDrop(triggerDistance: 1430, type: .weaponModule),
    ]
}
```

Also add to the SpawnDirector class:
```swift
private var scriptedDrops: [ScriptedDrop]
private var nextDropIndex: Int = 0
public private(set) var pendingDrops: [ScriptedDrop] = []
```

Initialize in `init`:
```swift
self.scriptedDrops = Self.galaxy1ScriptedDrops()
```

Add to `update(scrollDistance:)`:
```swift
while nextDropIndex < scriptedDrops.count,
      scrollDistance >= scriptedDrops[nextDropIndex].triggerDistance {
    pendingDrops.append(scriptedDrops[nextDropIndex])
    nextDropIndex += 1
}
```

**Step 2: Process scripted drops in Galaxy1Scene**

In the scene's update loop (near where `processSpawnDirectorWaves` is called), add:

```swift
for drop in spawnDirector.pendingDrops {
    switch drop.type {
    case .weaponModule:
        // Spawn at top-center area, slightly randomized X
        let x = Float.random(in: -40...40)
        spawnWeaponModuleItem(at: SIMD2(x, 300))
    }
}
spawnDirector.pendingDrops.removeAll()
```

**Step 3: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: add scripted weapon drops at 1/3 and 2/3 stage progress"
```

---

### Task 12: Overhaul Drop System — Randomize Utility Drops

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:837-863,1199-1221`
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift:21-23`

**Step 1: Change spawnItem to only spawn utility items (no weapon chance)**

Replace `spawnItem` (lines 837-863) with:

```swift
private func spawnUtilityItem(at position: SIMD2<Float>) {
    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: position))

    let physics = PhysicsComponent(
        collisionSize: GameConfig.Item.size,
        layer: .item,
        mask: [.player, .playerProjectile]
    )
    entity.addComponent(physics)

    let render = RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 1, 1))
    render.spriteId = "energyDrop"
    entity.addComponent(render)

    let itemComp = ItemComponent()
    // Randomize the starting utility type
    itemComp.currentCycleIndex = Int.random(in: 0..<UtilityItemType.allCases.count)
    entity.addComponent(itemComp)

    registerEntity(entity)
    items.append(entity)
    sfx?.play(.itemSpawn)
}
```

**Step 2: Update checkFormationWipe to use 45% utility-only drops**

Replace the drop logic in `checkFormationWipe` (lines 1209-1214):

```swift
// Old code:
let isTurretFormation = members.first?.component(ofType: TurretComponent.self)?.parentEntity != nil
if isTurretFormation {
    spawnWeaponModuleItem(at: transform.position)
} else {
    spawnItem(at: transform.position)
}
```

With:
```swift
// 45% chance to drop a utility item (weapon drops are now scripted)
if Float.random(in: 0..<1) < 0.45 {
    spawnUtilityItem(at: transform.position)
}
```

**Step 3: Build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | grep "error:" | head -20`

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift
git commit -m "feat: randomize utility drops at 45% rate, remove guaranteed drops"
```

---

### Task 13: Final Build & Cleanup

**Files:**
- All modified files

**Step 1: Full build**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -10`
Expected: Build succeeds with no errors.

**Step 2: Run all tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test 2>&1 | tail -20`
Expected: All tests pass.

**Step 3: Search for any remaining vulcan references**

Run a grep for `vulcan` (case-insensitive) across all Swift files. Any remaining references should be updated or removed.

**Step 4: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "chore: clean up remaining vulcan references"
```
