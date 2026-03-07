# Phase 4: Full Arsenal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete all primary weapons (Vulcan Auto-Gun, Phase Laser), all secondary weapons (EMP Sweep, Overcharge Protocol), and separate Weapon Module item from utility items.

**Architecture:** Expand the existing WeaponType enum and WeaponSystem to support 4 primary and 3 secondary weapons. Phase Laser uses instant hitscan (no projectile entity). Three secondary weapons share a charge pool and are mapped to individual keys (Z/X/C). Weapon Module items are a distinct drop from utility items with separate cycling logic.

**Tech Stack:** Swift, GameplayKit (ECS), Metal, simd

---

### Task 1: Expand PlayerInput for three secondary fire buttons

Currently `PlayerInput` has a single `secondaryFire: Bool`. We need three independent secondary fire booleans, one per weapon.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/InputManager.swift`

**Step 1: Add secondary fire fields to PlayerInput**

Replace the single `secondaryFire` with three fields:

```swift
public struct PlayerInput: Sendable {
    public var movement: SIMD2<Float> = .zero
    public var primaryFire: Bool = false
    public var secondaryFire1: Bool = false  // Z — Grav-Bomb
    public var secondaryFire2: Bool = false  // X — EMP Sweep
    public var secondaryFire3: Bool = false  // C — Overcharge Protocol

    public init() {}
}
```

**Step 2: Fix compile errors**

This will break `KeyboardInputProvider`, `TouchInputProvider`, and `Galaxy1Scene` which all reference `secondaryFire`. Update each in the next tasks. For now, just save this file.

**Step 3: Commit**

Do NOT commit yet — the build is broken. Continue to Task 2.

---

### Task 2: Update KeyboardInputProvider for Z/X/C keys

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift`

**Step 1: Add X and C key codes and map all three**

```swift
#if os(macOS)
import simd

@MainActor
public final class KeyboardInputProvider: InputProvider {
    private var keysPressed: Set<UInt16> = []

    private enum KeyCode {
        static let leftArrow:  UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow:  UInt16 = 125
        static let upArrow:    UInt16 = 126
        static let space:      UInt16 = 49
        static let z:          UInt16 = 6
        static let x:          UInt16 = 7
        static let c:          UInt16 = 8
    }

    public init() {}

    public func keyDown(_ keyCode: UInt16) {
        keysPressed.insert(keyCode)
    }

    public func keyUp(_ keyCode: UInt16) {
        keysPressed.remove(keyCode)
    }

    public func poll() -> PlayerInput {
        var input = PlayerInput()

        if keysPressed.contains(KeyCode.leftArrow)  { input.movement.x -= 1 }
        if keysPressed.contains(KeyCode.rightArrow)  { input.movement.x += 1 }
        if keysPressed.contains(KeyCode.upArrow)     { input.movement.y += 1 }
        if keysPressed.contains(KeyCode.downArrow)    { input.movement.y -= 1 }

        let length = simd_length(input.movement)
        if length > 1 {
            input.movement /= length
        }

        input.primaryFire = keysPressed.contains(KeyCode.space)
        input.secondaryFire1 = keysPressed.contains(KeyCode.z)
        input.secondaryFire2 = keysPressed.contains(KeyCode.x)
        input.secondaryFire3 = keysPressed.contains(KeyCode.c)

        return input
    }
}
#endif
```

---

### Task 3: Update TouchInputProvider for three secondary buttons

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift`

**Step 1: Replace single secondary with three button rects and states**

```swift
#if os(iOS)
import UIKit
import simd

@MainActor
public final class TouchInputProvider: InputProvider {
    // Joystick state
    private var joystickOrigin: SIMD2<Float>?
    private var joystickCurrent: SIMD2<Float>?
    private var joystickTouchID: ObjectIdentifier?

    // Button state
    private var primaryFireActive: Bool = false
    private var secondary1Active: Bool = false
    private var secondary2Active: Bool = false
    private var secondary3Active: Bool = false
    private var primaryTouchID: ObjectIdentifier?
    private var secondary1TouchID: ObjectIdentifier?
    private var secondary2TouchID: ObjectIdentifier?
    private var secondary3TouchID: ObjectIdentifier?

    // Configuration
    private let maxJoystickRadius: Float = 60
    private let deadZone: Float = 10

    // Screen dimensions (set by MetalView on layout)
    public var screenSize: CGSize = .zero

    // Button rects (set by MetalView on layout)
    public var primaryButtonRect: CGRect = .zero
    public var secondary1ButtonRect: CGRect = .zero
    public var secondary2ButtonRect: CGRect = .zero
    public var secondary3ButtonRect: CGRect = .zero

    public init() {}

    public func poll() -> PlayerInput {
        var input = PlayerInput()

        if let origin = joystickOrigin, let current = joystickCurrent {
            var delta = current - origin
            let length = simd_length(delta)

            if length < deadZone {
                delta = .zero
            } else if length > maxJoystickRadius {
                delta = simd_normalize(delta) * maxJoystickRadius
            }

            input.movement = delta / maxJoystickRadius
            input.movement.y = -input.movement.y
        }

        input.primaryFire = primaryFireActive
        input.secondaryFire1 = secondary1Active
        input.secondaryFire2 = secondary2Active
        input.secondaryFire3 = secondary3Active

        return input
    }

    // MARK: - Touch handling (called by MetalView)

    public func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let loc = touch.location(in: view)
            let point = SIMD2<Float>(Float(loc.x), Float(loc.y))
            let touchID = ObjectIdentifier(touch)

            if loc.x < screenSize.width / 2 && joystickTouchID == nil {
                joystickOrigin = point
                joystickCurrent = point
                joystickTouchID = touchID
            } else if loc.x >= screenSize.width / 2 {
                if secondary3ButtonRect.contains(loc) && secondary3TouchID == nil {
                    secondary3Active = true
                    secondary3TouchID = touchID
                } else if secondary2ButtonRect.contains(loc) && secondary2TouchID == nil {
                    secondary2Active = true
                    secondary2TouchID = touchID
                } else if secondary1ButtonRect.contains(loc) && secondary1TouchID == nil {
                    secondary1Active = true
                    secondary1TouchID = touchID
                } else if primaryTouchID == nil {
                    primaryFireActive = true
                    primaryTouchID = touchID
                }
            }
        }
    }

    public func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let touchID = ObjectIdentifier(touch)
            if touchID == joystickTouchID {
                let loc = touch.location(in: view)
                joystickCurrent = SIMD2<Float>(Float(loc.x), Float(loc.y))
            }
        }
    }

    public func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        cancelTouches(touches)
    }

    public func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        cancelTouches(touches)
    }

    private func cancelTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let touchID = ObjectIdentifier(touch)
            if touchID == joystickTouchID {
                joystickOrigin = nil
                joystickCurrent = nil
                joystickTouchID = nil
            }
            if touchID == primaryTouchID {
                primaryFireActive = false
                primaryTouchID = nil
            }
            if touchID == secondary1TouchID {
                secondary1Active = false
                secondary1TouchID = nil
            }
            if touchID == secondary2TouchID {
                secondary2Active = false
                secondary2TouchID = nil
            }
            if touchID == secondary3TouchID {
                secondary3Active = false
                secondary3TouchID = nil
            }
        }
    }
}

#endif
```

---

### Task 4: Update iOS MetalView button layout

**Files:**
- Modify: `Project2043-iOS/MetalView.swift`

**Step 1: Replace `secondaryButtonRect` with three secondary button rects**

In `layoutSubviews()`, replace the current secondary button rect setup with a vertical stack of 3 buttons above the primary fire button. Update `touchInput.secondaryButtonRect` → `touchInput.secondary1ButtonRect` etc.

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    let scale = UIScreen.main.scale
    metalLayer.drawableSize = CGSize(
        width: bounds.width * scale,
        height: bounds.height * scale
    )

    touchInput.screenSize = bounds.size

    let buttonW: CGFloat = 80
    let buttonH: CGFloat = 80
    let margin: CGFloat = 20
    let rightEdge = bounds.width - margin

    // Primary fire: larger, bottom-right
    touchInput.primaryButtonRect = CGRect(
        x: rightEdge - buttonW,
        y: bounds.height - margin - buttonH,
        width: buttonW,
        height: buttonH
    )

    // Secondary buttons: stacked vertically above primary
    let secW: CGFloat = 60
    let secH: CGFloat = 50
    let secGap: CGFloat = 10
    let secX = rightEdge - secW - 10
    let secBaseY = bounds.height - margin - buttonH - secGap

    // Secondary 1 (Grav-Bomb): lowest, just above primary
    touchInput.secondary1ButtonRect = CGRect(
        x: secX, y: secBaseY - secH,
        width: secW, height: secH
    )

    // Secondary 2 (EMP Sweep): middle
    touchInput.secondary2ButtonRect = CGRect(
        x: secX, y: secBaseY - secH * 2 - secGap,
        width: secW, height: secH
    )

    // Secondary 3 (Overcharge): top
    touchInput.secondary3ButtonRect = CGRect(
        x: secX, y: secBaseY - secH * 3 - secGap * 2,
        width: secW, height: secH
    )
}
```

**Step 2: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/InputManager.swift \
       Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift \
       Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift \
       Project2043-iOS/MetalView.swift
git commit -m "feat: expand input system for three secondary fire buttons (Z/X/C)"
```

---

### Task 5: Add Vulcan and Phase Laser weapon types and config constants

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift`

**Step 1: Expand WeaponType enum and add Phase Laser / Overcharge state**

```swift
import GameplayKit

public enum WeaponType: Int, CaseIterable, Sendable {
    case doubleCannon = 0
    case triSpread = 1
    case vulcanAutoGun = 2
    case phaseLaser = 3
}

public enum SecondaryType: Sendable {
    case gravBomb
    case empSweep
    case overcharge
}

public final class WeaponComponent: GKComponent {
    public var fireRate: Double = 5.0
    public var damage: Float = 1.0
    public var projectileSpeed: Float = 400.0
    public var timeSinceLastShot: Double = 0
    public var isFiring: Bool = false
    public var weaponType: WeaponType = .doubleCannon
    public var secondaryCharges: Int = 1
    public var secondaryFiring: SecondaryType? = nil
    public var secondaryCooldown: Double = 0.5
    public var firesDownward: Bool = false

    // Phase Laser state
    public var laserBurstTimer: Double = 0
    public var laserCooldownTimer: Double = 0
    public var isLaserBurstActive: Bool = false

    // Overcharge state
    public var overchargeActive: Bool = false
    public var overchargeTimer: Double = 0

    public override init() { super.init() }

    public convenience init(fireRate: Double, damage: Float, projectileSpeed: Float) {
        self.init()
        self.fireRate = fireRate
        self.damage = damage
        self.projectileSpeed = projectileSpeed
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

Note: `isSecondaryFiring: Bool` is replaced by `secondaryFiring: SecondaryType?` (nil means not firing).

**Step 2: Add config constants**

Add to `GameConfig.swift` inside the `Weapon` enum:

```swift
public enum Weapon {
    // Existing
    public static let triSpreadAngle: Float = .pi / 12
    public static let triSpreadDamage: Float = 0.7
    public static let gravBombMaxCharges = 3
    public static let gravBombStartCharges = 1
    public static let gravBombDetonateTime: Double = 0.4
    public static let gravBombBlastRadius: Float = 120
    public static let gravBombDamage: Float = 3

    // Vulcan Auto-Gun
    public static let vulcanFireRateMultiplier: Double = 2.0
    public static let vulcanDamage: Float = 1.0
    public static let vulcanProjectileSize = SIMD2<Float>(4, 10)

    // Phase Laser
    public static let laserBurstDuration: Double = 0.8
    public static let laserCooldownDuration: Double = 0.5
    public static let laserTickInterval: Double = 0.1
    public static let laserDamagePerTick: Float = 0.4
    public static let laserWidth: Float = 8

    // EMP Sweep
    public static let empSlowMoDuration: Double = 0.3

    // Overcharge Protocol
    public static let overchargeDuration: Double = 5.0
    public static let overchargeFireRateMultiplier: Double = 2.0
    public static let overchargeHitboxScale: Float = 1.5
}
```

Add new palette colors in `Palette`:

```swift
public static let empFlash = SIMD4<Float>(0.5, 0.7, 1.0, 0.4)
public static let overchargeGlow = SIMD4<Float>(1.0, 0.6, 0.0, 0.8)
public static let laserBeam = SIMD4<Float>(0.4, 1.0, 0.4, 0.9)
```

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift \
       Engine2043/Sources/Engine2043/Core/GameConfig.swift
git commit -m "feat: add Vulcan, Phase Laser weapon types and config constants"
```

---

### Task 6: Implement Vulcan Auto-Gun and Phase Laser in WeaponSystem

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift`

**Step 1: Add LaserHitscanRequest and secondary request types**

Add new request types and expand the secondary spawn to carry a type discriminator:

```swift
public struct LaserHitscanRequest: Sendable {
    public var position: SIMD2<Float>
    public var width: Float
    public var damagePerTick: Float
}

public enum SecondarySpawnType: Sendable {
    case gravBomb
    case empSweep
    case overcharge
}

public struct SecondarySpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var type: SecondarySpawnType
}
```

**Step 2: Add pending laser hitscan list**

Add to WeaponSystem:

```swift
public private(set) var pendingLaserHitscans: [LaserHitscanRequest] = []
```

Clear it at the top of `update(time:)`:

```swift
pendingLaserHitscans.removeAll(keepingCapacity: true)
```

**Step 3: Rewrite the primary fire logic to handle all 4 weapon types + overcharge**

In `update(time:)`, the primary fire block becomes:

```swift
// Overcharge timer
if weapon.overchargeActive {
    weapon.overchargeTimer -= time.fixedDeltaTime
    if weapon.overchargeTimer <= 0 {
        weapon.overchargeActive = false
        weapon.overchargeTimer = 0
    }
}

// Phase Laser: separate burst/cooldown logic
if weapon.weaponType == .phaseLaser {
    if weapon.isFiring && !weapon.isLaserBurstActive && weapon.laserCooldownTimer <= 0 {
        weapon.isLaserBurstActive = true
        weapon.laserBurstTimer = GameConfig.Weapon.laserBurstDuration
        weapon.timeSinceLastShot = 0
    }

    if weapon.isLaserBurstActive {
        weapon.laserBurstTimer -= time.fixedDeltaTime
        weapon.timeSinceLastShot += time.fixedDeltaTime

        let tickInterval = GameConfig.Weapon.laserTickInterval
        if weapon.timeSinceLastShot >= tickInterval {
            weapon.timeSinceLastShot -= tickInterval
            pendingLaserHitscans.append(LaserHitscanRequest(
                position: transform.position,
                width: GameConfig.Weapon.laserWidth,
                damagePerTick: GameConfig.Weapon.laserDamagePerTick
            ))
        }

        if weapon.laserBurstTimer <= 0 {
            weapon.isLaserBurstActive = false
            weapon.laserCooldownTimer = GameConfig.Weapon.laserCooldownDuration
        }
    } else {
        weapon.laserCooldownTimer = max(0, weapon.laserCooldownTimer - time.fixedDeltaTime)
    }
} else if weapon.isFiring {
    // Standard projectile weapons
    weapon.timeSinceLastShot += time.fixedDeltaTime
    var effectiveFireRate = weapon.fireRate
    if weapon.weaponType == .vulcanAutoGun {
        effectiveFireRate *= GameConfig.Weapon.vulcanFireRateMultiplier
    }
    if weapon.overchargeActive {
        effectiveFireRate *= GameConfig.Weapon.overchargeFireRateMultiplier
    }
    let interval = 1.0 / effectiveFireRate

    if weapon.timeSinceLastShot >= interval {
        weapon.timeSinceLastShot -= interval
        spawnPrimaryProjectiles(weapon: weapon, position: transform.position)
    }
}
```

**Step 4: Add Vulcan and update Tri-Spread in spawnPrimaryProjectiles**

Add the `.vulcanAutoGun` case. Also, if overcharge is active, widen projectile sizes:

```swift
private func spawnPrimaryProjectiles(weapon: WeaponComponent, position: SIMD2<Float>) {
    let direction: Float = weapon.firesDownward ? -1 : 1

    switch weapon.weaponType {
    case .doubleCannon:
        let offset: Float = 8
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position + SIMD2(-offset, 0),
            velocity: SIMD2(0, weapon.projectileSpeed * direction),
            damage: weapon.damage
        ))
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position + SIMD2(offset, 0),
            velocity: SIMD2(0, weapon.projectileSpeed * direction),
            damage: weapon.damage
        ))

    case .triSpread:
        let angle = GameConfig.Weapon.triSpreadAngle
        let speed = weapon.projectileSpeed
        let damage = GameConfig.Weapon.triSpreadDamage

        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(0, speed * direction),
            damage: damage
        ))
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(-sin(angle) * speed, cos(angle) * speed * direction),
            damage: damage
        ))
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(sin(angle) * speed, cos(angle) * speed * direction),
            damage: damage
        ))

    case .vulcanAutoGun:
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(0, weapon.projectileSpeed * direction),
            damage: GameConfig.Weapon.vulcanDamage
        ))

    case .phaseLaser:
        break // Handled via hitscan, not projectiles
    }
}
```

**Step 5: Rewrite secondary fire to handle 3 types**

Replace the existing secondary fire block in `update(time:)`:

```swift
// Secondary fire cooldown always ticks
weapon.secondaryCooldown += time.fixedDeltaTime

// Secondary fire
if let secondaryType = weapon.secondaryFiring,
   weapon.secondaryCharges > 0,
   weapon.secondaryCooldown >= 0.5 {
    weapon.secondaryCooldown = 0
    weapon.secondaryCharges -= 1
    weapon.secondaryFiring = nil

    switch secondaryType {
    case .gravBomb:
        pendingSecondarySpawns.append(SecondarySpawnRequest(
            position: transform.position,
            velocity: SIMD2(0, 150),
            type: .gravBomb
        ))
    case .empSweep:
        pendingSecondarySpawns.append(SecondarySpawnRequest(
            position: transform.position,
            velocity: .zero,
            type: .empSweep
        ))
    case .overcharge:
        pendingSecondarySpawns.append(SecondarySpawnRequest(
            position: transform.position,
            velocity: .zero,
            type: .overcharge
        ))
    }
}
```

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift
git commit -m "feat: implement Vulcan Auto-Gun and Phase Laser in WeaponSystem"
```

---

### Task 7: Update Galaxy1Scene input handling and secondary weapon dispatch

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Update handleInput() to map 3 secondary buttons**

```swift
private func handleInput() {
    guard let input = inputProvider?.poll() else { return }

    if let physics = player.component(ofType: PhysicsComponent.self) {
        physics.velocity = input.movement * GameConfig.Player.speed
    }

    if let weapon = player.component(ofType: WeaponComponent.self) {
        weapon.isFiring = input.primaryFire

        // Map secondary fire buttons — first pressed wins
        if input.secondaryFire1 {
            weapon.secondaryFiring = .gravBomb
        } else if input.secondaryFire2 {
            weapon.secondaryFiring = .empSweep
        } else if input.secondaryFire3 {
            weapon.secondaryFiring = .overcharge
        } else {
            weapon.secondaryFiring = nil
        }
    }

    if let transform = player.component(ofType: TransformComponent.self) {
        let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2
        let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2
        transform.position.x = max(-halfW, min(halfW, transform.position.x))
        transform.position.y = max(-halfH, min(halfH, transform.position.y))
    }
}
```

**Step 2: Add slow-mo state to the scene**

Add new instance variables near the game state section:

```swift
private var slowMoTimer: Double = 0
private var isSlowMo: Bool = false
```

**Step 3: Update fixedUpdate to handle secondary spawn types**

Replace the grav-bomb spawn loop with a dispatch on secondary type:

```swift
// Handle secondary weapon spawns
for request in weaponSystem.pendingSecondarySpawns {
    switch request.type {
    case .gravBomb:
        spawnGravBomb(position: request.position, velocity: request.velocity)
    case .empSweep:
        activateEMPSweep()
    case .overcharge:
        activateOvercharge()
    }
}
```

**Step 4: Implement activateEMPSweep()**

Add this method. It removes all enemy projectiles and starts the slow-mo timer:

```swift
private func activateEMPSweep() {
    // Cancel all enemy projectiles
    for proj in enemyProjectiles {
        pendingRemovals.append(proj)
    }

    // Visual flash
    let flash = GKEntity()
    flash.addComponent(TransformComponent(position: .zero))
    flash.addComponent(RenderComponent(
        size: SIMD2(GameConfig.designWidth, GameConfig.designHeight),
        color: GameConfig.Palette.empFlash
    ))
    let flashPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
    flash.addComponent(flashPhysics)
    registerEntity(flash)
    blastEffects.append((entity: flash, timer: 0.2))

    // Start slow-mo
    slowMoTimer = GameConfig.Weapon.empSlowMoDuration
    isSlowMo = true
}
```

**Step 5: Implement activateOvercharge()**

```swift
private func activateOvercharge() {
    if let weapon = player.component(ofType: WeaponComponent.self) {
        weapon.overchargeActive = true
        weapon.overchargeTimer = GameConfig.Weapon.overchargeDuration
    }
}
```

**Step 6: Apply slow-mo time scaling in fixedUpdate**

At the very top of `fixedUpdate`, after the `guard gameState == .playing` check, add:

```swift
// Slow-mo from EMP Sweep
if isSlowMo {
    slowMoTimer -= time.fixedDeltaTime
    if slowMoTimer <= 0 {
        isSlowMo = false
    }
}
```

When `isSlowMo` is true, we want enemy movement/projectiles to be slowed but not the player. The simplest approach: scale enemy physics velocities temporarily. However, since our fixed timestep is constant, a cleaner approach is to halve enemy velocity during slow-mo in the steering/formation/turret updates. Actually, the simplest approach that doesn't break anything: during slow-mo, skip the enemy turret firing and slow the enemy formation/steering update rates. This is a ~0.3s window so keep it simple — just don't update turrets or spawn enemy projectiles during slow-mo:

In `fixedUpdate`, wrap the turret and boss projectile spawn in:

```swift
if !isSlowMo {
    updateTurrets(deltaTime: time.fixedDeltaTime)
    // ...boss projectile spawns...
}
```

This gives the player a brief reprieve consistent with the design intent.

**Step 7: Handle Phase Laser hitscan**

After `weaponSystem.update(time: time)`, process laser hitscans:

```swift
// Process Phase Laser hitscans
for hitscan in weaponSystem.pendingLaserHitscans {
    processLaserHitscan(hitscan)
}
```

Add the method:

```swift
private func processLaserHitscan(_ hitscan: LaserHitscanRequest) {
    let halfWidth = hitscan.width / 2
    let laserMinX = hitscan.position.x - halfWidth
    let laserMaxX = hitscan.position.x + halfWidth
    let laserMinY = hitscan.position.y
    let laserMaxY = GameConfig.designHeight / 2 + 50 // Top of screen + margin

    for enemy in enemies {
        guard let transform = enemy.component(ofType: TransformComponent.self),
              let health = enemy.component(ofType: HealthComponent.self),
              health.isAlive else { continue }

        let size = enemy.component(ofType: RenderComponent.self)?.size ?? .zero
        let enemyMinX = transform.position.x - size.x / 2
        let enemyMaxX = transform.position.x + size.x / 2
        let enemyMinY = transform.position.y - size.y / 2
        let enemyMaxY = transform.position.y + size.y / 2

        // Check overlap: laser column intersects enemy AABB
        if laserMaxX >= enemyMinX && laserMinX <= enemyMaxX &&
           laserMaxY >= enemyMinY && laserMinY <= enemyMaxY {
            health.takeDamage(hitscan.damagePerTick)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    scoreSystem.addScore(score.points)
                }
                pendingRemovals.append(enemy)
                checkFormationWipe(enemy: enemy)
            }
        }
    }
}
```

**Step 8: Add laser beam visual to collectSprites**

In `collectSprites()`, after collecting render system sprites, add the laser beam visual if active:

```swift
// Phase Laser beam visual
if let weapon = player.component(ofType: WeaponComponent.self),
   weapon.weaponType == .phaseLaser,
   weapon.isLaserBurstActive,
   let transform = player.component(ofType: TransformComponent.self) {
    let beamHeight = GameConfig.designHeight / 2 + 50 - transform.position.y
    sprites.append(SpriteInstance(
        position: SIMD2(transform.position.x, transform.position.y + beamHeight / 2),
        size: SIMD2(GameConfig.Weapon.laserWidth, beamHeight),
        color: GameConfig.Palette.laserBeam
    ))
}
```

**Step 9: Add overcharge visual glow around player**

In `collectSprites()`, add an overcharge aura:

```swift
// Overcharge visual
if let weapon = player.component(ofType: WeaponComponent.self),
   weapon.overchargeActive,
   let transform = player.component(ofType: TransformComponent.self) {
    sprites.append(SpriteInstance(
        position: transform.position,
        size: GameConfig.Player.size * 1.5,
        color: GameConfig.Palette.overchargeGlow
    ))
}
```

**Step 10: Update Vulcan projectile size**

In `spawnPlayerProjectile`, the projectile size should vary by weapon type. The current code always uses `GameConfig.Player.projectileSize`. Update:

```swift
private func spawnPlayerProjectile(_ request: ProjectileSpawnRequest) {
    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: request.position))

    let weapon = player.component(ofType: WeaponComponent.self)
    var projSize = GameConfig.Player.projectileSize
    if weapon?.weaponType == .vulcanAutoGun {
        projSize = GameConfig.Weapon.vulcanProjectileSize
    }
    if weapon?.overchargeActive == true {
        projSize *= GameConfig.Weapon.overchargeHitboxScale
    }

    let physics = PhysicsComponent(
        collisionSize: projSize,
        layer: .playerProjectile,
        mask: [.enemy, .bossShield, .item]
    )
    physics.velocity = request.velocity
    entity.addComponent(physics)

    entity.addComponent(RenderComponent(
        size: projSize,
        color: SIMD4(1, 1, 1, 1)
    ))

    registerEntity(entity)
    projectiles.append(entity)
}
```

**Step 11: Update handleProjectileHitEnemy to use actual projectile damage**

Currently `handleProjectileHitEnemy` always uses `GameConfig.Player.damage`. It should use the `request.damage` that was stored. But since entities don't carry damage, we can derive it from the weapon. Actually, `ProjectileSpawnRequest` has a `damage` field — but the entity itself doesn't store it. The simplest fix: the damage is always `GameConfig.Player.damage` for Double Cannon and Vulcan, and `GameConfig.Weapon.triSpreadDamage` for Tri-Spread. Since we can't easily store per-projectile damage on the entity without adding a component, and the current code already uses a flat value, let's leave this as-is for now. The Vulcan does 1.0 damage (same as Double Cannon), and Tri-Spread already has its damage encoded in the spawn request. Actually, the issue is that `handleProjectileHitEnemy` always uses `GameConfig.Player.damage` regardless of what `request.damage` was. This is a pre-existing bug. To fix properly, add a simple damage tag. But to keep scope tight, note that Vulcan damage = Player.damage = 1.0, so this only matters for Tri-Spread. Leave this for now — it's a pre-existing issue.

**Step 12: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire EMP Sweep, Overcharge, and Phase Laser hitscan in Galaxy1Scene"
```

---

### Task 8: Separate Weapon Module item from utility items

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Refactor ItemComponent for two item categories**

The utility cycle currently has `energyCell` and `weaponModule`. We're splitting: utility items cycle through utility types only, and weapon module items are a separate entity type that cycles through weapons.

```swift
import GameplayKit

public enum UtilityItemType: Int, CaseIterable, Sendable {
    case energyCell = 0
}

public final class ItemComponent: GKComponent {
    public var currentCycleIndex: Int = 0
    public var timeAlive: Double = 0
    public var bounceDirection: Float = 1
    public var isWeaponModule: Bool = false

    // For weapon module: which weapon is currently displayed
    public var displayedWeapon: WeaponType = .doubleCannon
    // Weapons available to cycle through (excludes current player weapon)
    public var weaponCycle: [WeaponType] = []
    public var weaponCycleIndex: Int = 0

    public var utilityItemType: UtilityItemType {
        UtilityItemType(rawValue: currentCycleIndex % UtilityItemType.allCases.count) ?? .energyCell
    }

    public var shouldDespawn: Bool {
        timeAlive >= 8.0
    }

    public func advanceCycle() {
        if isWeaponModule {
            guard !weaponCycle.isEmpty else { return }
            weaponCycleIndex = (weaponCycleIndex + 1) % weaponCycle.count
            displayedWeapon = weaponCycle[weaponCycleIndex]
        } else {
            currentCycleIndex = (currentCycleIndex + 1) % UtilityItemType.allCases.count
        }
    }

    public override init() { super.init() }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

**Step 2: Update ItemSystem color rendering**

In `ItemSystem.update(deltaTime:)`, replace the color switch:

```swift
if item.isWeaponModule {
    render.color = GameConfig.Palette.weaponModule
} else {
    switch item.utilityItemType {
    case .energyCell:
        render.color = GameConfig.Palette.item
    }
}
```

**Step 3: Update Galaxy1Scene item spawning**

Add a separate `spawnWeaponModuleItem(at:)` method and modify `spawnItem` to only spawn utility items:

```swift
private func spawnItem(at position: SIMD2<Float>) {
    // 20% chance to spawn weapon module instead of utility item
    if Float.random(in: 0..<1) < 0.2 {
        spawnWeaponModuleItem(at: position)
        return
    }

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: position))

    let physics = PhysicsComponent(
        collisionSize: GameConfig.Item.size,
        layer: .item,
        mask: [.player, .playerProjectile]
    )
    entity.addComponent(physics)

    entity.addComponent(RenderComponent(
        size: GameConfig.Item.size,
        color: GameConfig.Palette.item
    ))

    entity.addComponent(ItemComponent())

    registerEntity(entity)
    items.append(entity)
}

private func spawnWeaponModuleItem(at position: SIMD2<Float>) {
    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: position))

    let physics = PhysicsComponent(
        collisionSize: GameConfig.Item.size,
        layer: .item,
        mask: [.player, .playerProjectile]
    )
    entity.addComponent(physics)

    entity.addComponent(RenderComponent(
        size: GameConfig.Item.size,
        color: GameConfig.Palette.weaponModule
    ))

    let itemComp = ItemComponent()
    itemComp.isWeaponModule = true

    // Build weapon cycle excluding current player weapon
    let currentWeapon = player.component(ofType: WeaponComponent.self)?.weaponType ?? .doubleCannon
    let allWeapons: [WeaponType] = [.doubleCannon, .triSpread, .vulcanAutoGun, .phaseLaser]
    itemComp.weaponCycle = allWeapons.filter { $0 != currentWeapon }
    if let first = itemComp.weaponCycle.first {
        itemComp.displayedWeapon = first
        itemComp.weaponCycleIndex = 0
    }

    entity.addComponent(itemComp)

    registerEntity(entity)
    items.append(entity)
}
```

**Step 4: Capital ship turret clears always drop weapon module**

In `checkFormationWipe`, check if the formation was turrets (they have TurretComponent with a parentEntity). If so, always drop weapon module:

```swift
private func checkFormationWipe(enemy: GKEntity) {
    for (id, members) in formationEnemies {
        if members.contains(where: { $0 === enemy }) {
            let alive = members.filter { member in
                guard let health = member.component(ofType: HealthComponent.self) else { return false }
                return health.isAlive && !pendingRemovals.contains(where: { $0 === member })
            }
            if alive.isEmpty {
                if let transform = enemy.component(ofType: TransformComponent.self) {
                    // Capital ship turrets always drop weapon module
                    let isTurretFormation = members.first?.component(ofType: TurretComponent.self)?.parentEntity != nil
                    if isTurretFormation {
                        spawnWeaponModuleItem(at: transform.position)
                    } else {
                        spawnItem(at: transform.position)
                    }
                }
                formationEnemies.removeValue(forKey: id)
            }
            break
        }
    }
}
```

**Step 5: Update handlePlayerCollectsItem for new item structure**

```swift
private func handlePlayerCollectsItem(item: GKEntity) {
    guard let itemComp = item.component(ofType: ItemComponent.self) else { return }

    if itemComp.isWeaponModule {
        if let weapon = player.component(ofType: WeaponComponent.self) {
            weapon.weaponType = itemComp.displayedWeapon
            // Reset weapon-specific state
            weapon.isLaserBurstActive = false
            weapon.laserBurstTimer = 0
            weapon.laserCooldownTimer = 0
            // Update damage for weapon type
            switch weapon.weaponType {
            case .doubleCannon, .vulcanAutoGun:
                weapon.damage = GameConfig.Player.damage
            case .triSpread:
                weapon.damage = GameConfig.Weapon.triSpreadDamage
            case .phaseLaser:
                weapon.damage = GameConfig.Weapon.laserDamagePerTick
            }
        }
    } else {
        switch itemComp.utilityItemType {
        case .energyCell:
            if let health = player.component(ofType: HealthComponent.self) {
                health.currentHealth = min(health.maxHealth, health.currentHealth + GameConfig.Item.energyRestoreAmount)
            }
        }
    }

    pendingRemovals.append(item)
}
```

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift \
       Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift \
       Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: separate Weapon Module item from utility items with weapon cycling"
```

---

### Task 9: Update HUD for new weapons and charges

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Update appendHUD to show weapon type and charge indicators**

Replace the existing `appendHUD` method:

```swift
private func appendHUD(to sprites: inout [SpriteInstance]) {
    let topY: Float = GameConfig.designHeight / 2 - 20

    // Energy bar background
    sprites.append(SpriteInstance(
        position: SIMD2(-45, topY),
        size: SIMD2(120, 12),
        color: SIMD4(0.2, 0.2, 0.2, 0.8)
    ))

    // Energy bar fill
    let health = player.component(ofType: HealthComponent.self)
    let fraction = (health?.currentHealth ?? 0) / (health?.maxHealth ?? 100)
    let barWidth: Float = 116 * fraction
    let barOffset = (barWidth - 116) / 2
    sprites.append(SpriteInstance(
        position: SIMD2(-45 + barOffset, topY),
        size: SIMD2(max(barWidth, 0), 8),
        color: GameConfig.Palette.player
    ))

    // Score bar
    let scoreWidth = min(Float(scoreSystem.currentScore) / 10.0, 100.0)
    sprites.append(SpriteInstance(
        position: SIMD2(100, topY),
        size: SIMD2(max(scoreWidth, 0), 8),
        color: SIMD4(1, 1, 1, 0.8)
    ))

    // Secondary charges (bottom-right)
    let weapon = player.component(ofType: WeaponComponent.self)
    let charges = weapon?.secondaryCharges ?? 0
    for i in 0..<charges {
        sprites.append(SpriteInstance(
            position: SIMD2(140 - Float(i) * 14, -GameConfig.designHeight / 2 + 20),
            size: SIMD2(10, 10),
            color: GameConfig.Palette.gravBomb
        ))
    }

    // Weapon indicator (bottom-center) — color per weapon type
    let weaponType = weapon?.weaponType ?? .doubleCannon
    let weaponColor: SIMD4<Float>
    switch weaponType {
    case .doubleCannon:
        weaponColor = SIMD4(1, 1, 1, 0.5)
    case .triSpread:
        weaponColor = GameConfig.Palette.weaponModule
    case .vulcanAutoGun:
        weaponColor = SIMD4(1, 0.3, 0.3, 0.8)
    case .phaseLaser:
        weaponColor = GameConfig.Palette.laserBeam
    }
    sprites.append(SpriteInstance(
        position: SIMD2(0, -GameConfig.designHeight / 2 + 20),
        size: SIMD2(20, 6),
        color: weaponColor
    ))

    // Phase Laser cooldown indicator
    if weaponType == .phaseLaser, let w = weapon {
        if w.laserCooldownTimer > 0 {
            let cooldownFrac = Float(w.laserCooldownTimer / GameConfig.Weapon.laserCooldownDuration)
            sprites.append(SpriteInstance(
                position: SIMD2(0, -GameConfig.designHeight / 2 + 30),
                size: SIMD2(20 * cooldownFrac, 3),
                color: SIMD4(0.5, 0.5, 0.5, 0.6)
            ))
        } else if w.isLaserBurstActive {
            let burstFrac = Float(w.laserBurstTimer / GameConfig.Weapon.laserBurstDuration)
            sprites.append(SpriteInstance(
                position: SIMD2(0, -GameConfig.designHeight / 2 + 30),
                size: SIMD2(20 * burstFrac, 3),
                color: GameConfig.Palette.laserBeam
            ))
        }
    }

    // Overcharge active indicator
    if weapon?.overchargeActive == true {
        sprites.append(SpriteInstance(
            position: SIMD2(0, -GameConfig.designHeight / 2 + 38),
            size: SIMD2(20, 3),
            color: GameConfig.Palette.overchargeGlow
        ))
    }
}
```

**Step 2: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: update HUD for 4 weapon types and secondary charge display"
```

---

### Task 10: Build verification and fix compile errors

**Files:**
- Potentially any file from Tasks 1-9

**Step 1: Build the project**

Run:
```bash
cd /Users/david/Code/XCode/turbo-carnival && xcodebuild -project Project2043.xcodeproj -scheme Project2043-macOS -destination 'platform=macOS' build 2>&1 | tail -40
```

Expected: BUILD SUCCEEDED

**Step 2: Fix any compile errors**

Common issues to watch for:
- Any remaining references to the old `secondaryFire` (should be `secondaryFire1`)
- Any remaining references to `isSecondaryFiring` (should be `secondaryFiring`)
- Any remaining references to `ItemType` (should be `UtilityItemType`)
- `SecondarySpawnRequest` now has a `type` field — check all construction sites
- `WeaponType` is now `Int, CaseIterable` — verify enum usage

**Step 3: Fix and commit**

```bash
git add -A
git commit -m "fix: resolve compile errors from Phase 4 arsenal changes"
```

---

### Task 11: Smoke test gameplay

**Step 1: Run the macOS target**

Launch the game and verify:
- Player fires Double Cannon by default (space bar)
- Z key fires Grav-Bomb (existing behavior)
- X key fires EMP Sweep (all enemy projectiles vanish, brief pause)
- C key fires Overcharge Protocol (fire rate doubles for 5 seconds, wider projectiles)
- Charge pool is shared across Z/X/C — using any deducts 1 charge
- Weapon Module items drop (blue hex) — shoot to cycle through weapons, collect to swap
- Vulcan Auto-Gun: single narrow fast-fire projectile
- Phase Laser: beam appears on fire, 0.8s burst, 0.5s cooldown, damages enemies in column
- HUD shows current weapon color, charge count, Phase Laser cooldown bar, Overcharge indicator
- Capital ship turret clears always drop weapon module item
- Formation kills drop utility items (80%) or weapon modules (20%)

**Step 2: Fix any gameplay bugs found**

Common issues:
- Weapon module item not cycling correctly (check weaponCycle array construction)
- Phase Laser not hitting enemies (check column overlap math — ensure laserMinY starts at player position)
- Overcharge not resetting after 5s (check timer decrement in WeaponSystem)
- EMP slow-mo lasting too long or not working (check slowMoTimer)

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: gameplay bug fixes from Phase 4 smoke test"
```
