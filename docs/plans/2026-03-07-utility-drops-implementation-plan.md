# Utility Drops Visual Overhaul + Orbiting Shield Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redraw all utility drop sprites at 24x24 with distinct silhouettes, add Orbiting Shield item type with orbiting drone entities.

**Architecture:** Existing utility items (Energy Cell, Charge Cell) get redrawn at 24x24. New `.orbitingShield` case added to `UtilityItemType`. Shield drones are separate ECS entities with a `ShieldDroneComponent` and `ShieldDroneSystem` that orbit the player and absorb enemy projectiles.

**Tech Stack:** Swift 6, GameplayKit ECS, CoreGraphics procedural sprites, Metal texture atlas

---

### Task 1: Update GameConfig — Item Size + ShieldDrone Constants + Palette

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift:84-90` (Item enum)
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift:99-122` (Palette enum)

**Step 1: Update Item.size and add ShieldDrone constants**

In `GameConfig.swift`, change `Item.size` from `(16, 16)` to `(24, 24)` and add the `ShieldDrone` enum after `Item`:

```swift
    public enum Item {
        public static let size = SIMD2<Float>(24, 24)
        public static let driftSpeed: Float = 40
        public static let despawnTime: Double = 8.0
        public static let energyRestoreAmount: Float = 15
        public static let chargeRestoreAmount: Int = 1
    }

    public enum ShieldDrone {
        public static let orbitRadius: Float = 25
        public static let orbitSpeed: Float = 3.14
        public static let hitsPerDrone: Int = 3
        public static let maxDrones: Int = 4
        public static let droneSize = SIMD2<Float>(10, 10)
    }
```

**Step 2: Add shieldDrone palette entry**

Add after `chargeCell` line (117) in the Palette enum:

```swift
        public static let shieldDrone = SIMD4<Float>(0.0, 1.0, 210.0 / 255.0, 1.0)
```

**Step 3: Build to verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/GameConfig.swift
git commit -m "config: item size 24x24, add ShieldDrone constants and palette"
```

---

### Task 2: Add .orbitingShield Enum Case + Collision Layer

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift:3-6`
- Modify: `Engine2043/Sources/Engine2043/ECS/Entity.swift:6-17`

**Step 1: Add orbitingShield to UtilityItemType**

In `ItemComponent.swift`, add the new case:

```swift
public enum UtilityItemType: Int, CaseIterable, Sendable {
    case energyCell = 0
    case chargeCell = 1
    case orbitingShield = 2
}
```

No other changes needed — `advanceCycle()` and `utilityItemType` already use `CaseIterable.allCases.count`.

**Step 2: Add shieldDrone collision layer**

In `Entity.swift`, add after the `blast` line:

```swift
    public static let shieldDrone       = CollisionLayer(rawValue: 1 << 7)
```

**Step 3: Build to verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds (the new enum case will cause a non-exhaustive switch warning/error in `ItemSystem.swift` — that's expected, we fix it in Task 3)

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift Engine2043/Sources/Engine2043/ECS/Entity.swift
git commit -m "ecs: add orbitingShield utility type and shieldDrone collision layer"
```

---

### Task 3: Update ItemSystem — Color/Sprite Switching + Bounce Margin

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift`
- Test: `Engine2043/Tests/Engine2043Tests/ItemSystemTests.swift`

**Step 1: Write failing test for orbitingShield cycle**

Add to `ItemSystemTests.swift`:

```swift
    @Test @MainActor func itemSystemCyclesToOrbitingShield() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: []))
        let item = ItemComponent()
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)

        #expect(item.utilityItemType == .energyCell)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .chargeCell)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .orbitingShield)
        system.handleProjectileHit(on: entity)
        #expect(item.utilityItemType == .energyCell)
    }

    @Test @MainActor func itemSystemUpdatesSpriteIdPerType() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: []))
        let item = ItemComponent()
        entity.addComponent(item)
        let render = RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 1, 1))
        entity.addComponent(render)

        system.register(entity)

        // energyCell
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "energyDrop")

        // chargeCell
        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "chargeCell")

        // orbitingShield
        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "shieldDrop")
    }
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter ItemSystemTests 2>&1 | tail -20`
Expected: `itemSystemCyclesToOrbitingShield` passes (enum cycle works automatically). `itemSystemUpdatesSpriteIdPerType` fails because `spriteId` is not being set in `update()`.

**Step 3: Update ItemSystem.update()**

Replace the full `ItemSystem.swift` with these changes:

1. Fix bounce margin (line 47): change `let margin: Float = 16 / 2` to `let margin: Float = GameConfig.Item.size.x / 2`

2. Update the utility type switch (lines 62-67) to set both color AND spriteId:

```swift
            } else {
                switch item.utilityItemType {
                case .energyCell:
                    render.color = GameConfig.Palette.item
                    render.spriteId = "energyDrop"
                case .chargeCell:
                    render.color = GameConfig.Palette.chargeCell
                    render.spriteId = "chargeCell"
                case .orbitingShield:
                    render.color = GameConfig.Palette.shieldDrone
                    render.spriteId = "shieldDrop"
                }
            }
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter ItemSystemTests 2>&1 | tail -20`
Expected: All ItemSystemTests pass

**Step 5: Update existing ItemSystemTests to use GameConfig.Item.size**

The existing tests hardcode `SIMD2(16, 16)` for item sizes. Update all four existing tests to use `GameConfig.Item.size` instead. For example:

```swift
    @Test @MainActor func itemSystemDriftsDown() {
        let system = ItemSystem()

        let entity = GKEntity()
        let transform = TransformComponent(position: SIMD2(0, 200))
        entity.addComponent(transform)
        let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [.playerProjectile, .player])
        entity.addComponent(physics)
        entity.addComponent(ItemComponent())
        entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

        system.register(entity)
        system.update(deltaTime: 1.0)

        #expect(physics.velocity.y == Float(-40))
    }
```

Apply the same `SIMD2(16, 16)` → `GameConfig.Item.size` replacement to: `itemSystemBounces`, `itemSystemTracksDespawn`, `itemSystemAdvancesCycleOnHit`.

**Step 6: Run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 7: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift Engine2043/Tests/Engine2043Tests/ItemSystemTests.swift
git commit -m "item-system: sprite switching per utility type, fix bounce margin"
```

---

### Task 4: Redraw Sprites at 24x24 + Add Shield Drop and Shield Drone Sprites

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift:597-684` (energyDrop, chargeCell)
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift` (layout + generators + spriteNames)
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift:129-153`

**Step 1: Update SpriteFactory tests for 24x24 sizes + new sprites**

In `SpriteFactoryTests.swift`, update the energy/charge tests and add new ones:

```swift
    // Update existing tests:
    @Test func makeEnergyDropReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeEnergyDrop()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeChargeCellReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeChargeCell()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    // Add new tests:
    @Test func makeShieldDropReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeShieldDrop()
        #expect(width == 24)
        #expect(height == 24)
        #expect(pixels.count == 24 * 24 * 4)
    }

    @Test func makeShieldDropHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeShieldDrop()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }

    @Test func makeShieldDroneReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makeShieldDrone()
        #expect(width == 10)
        #expect(height == 10)
        #expect(pixels.count == 10 * 10 * 4)
    }

    @Test func makeShieldDroneHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makeShieldDrone()
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasVisiblePixels)
    }
```

Also update the `textureAtlasIncludesProjectileAndPickupSprites` test to include:

```swift
        #expect(names.contains("shieldDrop"))
        #expect(names.contains("shieldDrone"))
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: energyDrop/chargeCell size tests fail (still 16x16), shieldDrop/shieldDrone tests fail (methods don't exist)

**Step 3: Redraw makeEnergyDrop() at 24x24**

Replace the method in `SpriteFactory.swift` (lines 597-630):

```swift
    // MARK: - Energy Drop (24x24)
    // Lightning bolt silhouette, gold (#e0af68) fill, white highlight line.

    public static func makeEnergyDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Outer glow (subtle gold halo)
        ctx.setFillColor(cgColor(224, 175, 104, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Lightning bolt shape — larger, more detailed
        ctx.setFillColor(cgColor(224, 175, 104))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 14, y: 21))
        ctx.addLine(to: CGPoint(x: 7, y: 21))
        ctx.addLine(to: CGPoint(x: 11, y: 13))
        ctx.addLine(to: CGPoint(x: 7, y: 13))
        ctx.addLine(to: CGPoint(x: 14, y: 3))
        ctx.addLine(to: CGPoint(x: 16, y: 3))
        ctx.addLine(to: CGPoint(x: 12, y: 11))
        ctx.addLine(to: CGPoint(x: 16, y: 11))
        ctx.closePath()
        ctx.fillPath()

        // White highlight line down center
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 13, y: 20))
        ctx.addLine(to: CGPoint(x: 10, y: 13))
        ctx.addLine(to: CGPoint(x: 14, y: 4))
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
```

**Step 4: Redraw makeChargeCell() at 24x24**

Replace the method in `SpriteFactory.swift` (lines 632-684):

```swift
    // MARK: - Charge Cell (24x24)
    // Hexagonal battery, purple (#9966ff) outline, segmented interior, bright core.

    public static func makeChargeCell() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Hexagon
        let r: CGFloat = 9
        var hexPts: [CGPoint] = []
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            hexPts.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
        }

        // Dark purple fill
        ctx.setFillColor(cgColor(30, 15, 60))
        ctx.beginPath()
        ctx.move(to: hexPts[0])
        for pt in hexPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.fillPath()

        // Purple outline
        ctx.setStrokeColor(cgColor(153, 102, 255))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: hexPts[0])
        for pt in hexPts.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Segment lines (3 horizontal lines)
        ctx.setStrokeColor(cgColor(80, 50, 140))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 5, y: cy - 3))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 5, y: cy - 3))
        ctx.move(to: CGPoint(x: 5, y: cy))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 5, y: cy))
        ctx.move(to: CGPoint(x: 5, y: cy + 3))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 5, y: cy + 3))
        ctx.strokePath()

        // Bright core
        ctx.setFillColor(cgColor(200, 180, 255))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
```

**Step 5: Add makeShieldDrop() — 24x24 cyan halo**

Add after `makeChargeCell()`:

```swift
    // MARK: - Shield Drop (24x24)
    // Concentric cyan rings with bright center dot — "Cyan Halo" per spec.

    public static func makeShieldDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Outer ring
        ctx.setStrokeColor(cgColor(0, 255, 210, 100))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Middle ring
        ctx.setStrokeColor(cgColor(0, 255, 210, 180))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 5, y: 5, width: 14, height: 14))

        // Inner ring
        ctx.setStrokeColor(cgColor(0, 255, 210, 255))
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))

        // Bright center dot
        ctx.setFillColor(cgColor(200, 255, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
```

**Step 6: Add makeShieldDrone() — 10x10 cyan circle**

Add after `makeShieldDrop()`:

```swift
    // MARK: - Shield Drone (10x10)
    // Small cyan filled circle — orbits the player ship.

    public static func makeShieldDrone() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 10, h = 10
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Cyan filled circle
        ctx.setFillColor(cgColor(0, 255, 210, 200))
        ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 8, height: 8))

        // Bright center
        ctx.setFillColor(cgColor(200, 255, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
```

**Step 7: Update TextureAtlas**

In `TextureAtlas.swift`:

1. Update `spriteNames` (line 11-15) — add `"shieldDrop"` and `"shieldDrone"`:

```swift
    public nonisolated(unsafe) static let spriteNames: Set<String> = [
        "player", "swarmer", "bruiser", "capitalHull", "turret", "bossCore", "bossShield",
        "playerBullet", "triSpreadBullet", "lightningArcIcon", "enemyBullet", "gravBombSprite",
        "energyDrop", "chargeCell", "weaponModule", "shieldDrop", "shieldDrone"
    ]
```

2. Update `layout` (lines 39-43) — change energy/charge sizes to 24x24, add shield entries. The pickups row starts at y=188:

```swift
        // Row 188: Pickups
        SpriteEntry(name: "energyDrop",      x: 0,   y: 188, width: 24, height: 24),
        SpriteEntry(name: "chargeCell",      x: 24,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponModule",    x: 48,  y: 188, width: 20, height: 20),
        SpriteEntry(name: "shieldDrop",      x: 68,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "shieldDrone",     x: 92,  y: 188, width: 10, height: 10),
```

3. Update `generators` (lines 88-90) — add the new sprite generators:

```swift
            ("energyDrop",      SpriteFactory.makeEnergyDrop),
            ("chargeCell",      SpriteFactory.makeChargeCell),
            ("weaponModule",    SpriteFactory.makeWeaponModuleSprite),
            ("shieldDrop",      SpriteFactory.makeShieldDrop),
            ("shieldDrone",     SpriteFactory.makeShieldDrone),
```

**Step 8: Run tests**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -30`
Expected: All SpriteFactoryTests pass

**Step 9: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "sprites: redraw energy/charge at 24x24, add shield drop and drone sprites"
```

---

### Task 5: Create ShieldDroneComponent + ShieldDroneSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/ShieldDroneComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/ShieldDroneSystem.swift`
- Create: `Engine2043/Tests/Engine2043Tests/ShieldDroneTests.swift`

**Step 1: Write failing tests**

Create `Engine2043/Tests/Engine2043Tests/ShieldDroneTests.swift`:

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

struct ShieldDroneTests {
    @Test func shieldDroneComponentDefaults() {
        let comp = ShieldDroneComponent()
        #expect(comp.hitsRemaining == GameConfig.ShieldDrone.hitsPerDrone)
        #expect(comp.orbitRadius == GameConfig.ShieldDrone.orbitRadius)
        #expect(comp.orbitSpeed == GameConfig.ShieldDrone.orbitSpeed)
    }

    @Test func shieldDroneComponentTakeHit() {
        let comp = ShieldDroneComponent()
        comp.takeHit()
        #expect(comp.hitsRemaining == GameConfig.ShieldDrone.hitsPerDrone - 1)
        #expect(!comp.isDestroyed)
    }

    @Test func shieldDroneComponentDestroyedAfterMaxHits() {
        let comp = ShieldDroneComponent()
        for _ in 0..<GameConfig.ShieldDrone.hitsPerDrone {
            comp.takeHit()
        }
        #expect(comp.isDestroyed)
    }

    @Test @MainActor func shieldDroneSystemUpdatesPosition() {
        let system = ShieldDroneSystem()

        let playerEntity = GKEntity()
        playerEntity.addComponent(TransformComponent(position: SIMD2(100, 200)))

        let drone = GKEntity()
        drone.addComponent(TransformComponent(position: .zero))
        drone.addComponent(RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: SIMD4(1, 1, 1, 1)))
        let droneComp = ShieldDroneComponent()
        droneComp.ownerEntity = playerEntity
        droneComp.orbitAngle = 0
        drone.addComponent(droneComp)

        system.register(drone)
        system.update(deltaTime: 0)

        let pos = drone.component(ofType: TransformComponent.self)!.position
        // At angle 0, drone should be at player.x + radius, player.y
        let expectedX = Float(100) + GameConfig.ShieldDrone.orbitRadius
        let expectedY = Float(200)
        #expect(abs(pos.x - expectedX) < 0.1)
        #expect(abs(pos.y - expectedY) < 0.1)
    }

    @Test @MainActor func shieldDroneSystemAdvancesAngle() {
        let system = ShieldDroneSystem()

        let playerEntity = GKEntity()
        playerEntity.addComponent(TransformComponent(position: SIMD2(0, 0)))

        let drone = GKEntity()
        drone.addComponent(TransformComponent(position: .zero))
        drone.addComponent(RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: SIMD4(1, 1, 1, 1)))
        let droneComp = ShieldDroneComponent()
        droneComp.ownerEntity = playerEntity
        droneComp.orbitAngle = 0
        drone.addComponent(droneComp)

        system.register(drone)
        system.update(deltaTime: 1.0)

        #expect(droneComp.orbitAngle > 0)
    }

    @Test @MainActor func shieldDroneSystemMarksDestroyedForRemoval() {
        let system = ShieldDroneSystem()

        let playerEntity = GKEntity()
        playerEntity.addComponent(TransformComponent(position: .zero))

        let drone = GKEntity()
        drone.addComponent(TransformComponent(position: .zero))
        drone.addComponent(RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: SIMD4(1, 1, 1, 1)))
        let droneComp = ShieldDroneComponent()
        droneComp.ownerEntity = playerEntity
        for _ in 0..<GameConfig.ShieldDrone.hitsPerDrone {
            droneComp.takeHit()
        }
        drone.addComponent(droneComp)

        system.register(drone)
        system.update(deltaTime: 0)

        #expect(system.pendingRemovals.contains(where: { $0 === drone }))
    }
}
```

**Step 2: Create ShieldDroneComponent**

Create `Engine2043/Sources/Engine2043/ECS/Components/ShieldDroneComponent.swift`:

```swift
import GameplayKit

public final class ShieldDroneComponent: GKComponent {
    public weak var ownerEntity: GKEntity?
    public var orbitAngle: Float = 0
    public var orbitSpeed: Float = GameConfig.ShieldDrone.orbitSpeed
    public var orbitRadius: Float = GameConfig.ShieldDrone.orbitRadius
    public var hitsRemaining: Int = GameConfig.ShieldDrone.hitsPerDrone

    public var isDestroyed: Bool { hitsRemaining <= 0 }

    public func takeHit() {
        hitsRemaining -= 1
    }

    public override init() { super.init() }
    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

**Step 3: Create ShieldDroneSystem**

Create `Engine2043/Sources/Engine2043/ECS/Systems/ShieldDroneSystem.swift`:

```swift
import GameplayKit
import simd
import Foundation

@MainActor
public final class ShieldDroneSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingRemovals: [GKEntity] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: ShieldDroneComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        pendingRemovals.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let drone = entity.component(ofType: ShieldDroneComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            if drone.isDestroyed {
                pendingRemovals.append(entity)
                continue
            }

            guard let owner = drone.ownerEntity,
                  let ownerTransform = owner.component(ofType: TransformComponent.self) else {
                pendingRemovals.append(entity)
                continue
            }

            drone.orbitAngle += Float(deltaTime) * drone.orbitSpeed
            transform.position = ownerTransform.position + SIMD2(
                cosf(drone.orbitAngle) * drone.orbitRadius,
                sinf(drone.orbitAngle) * drone.orbitRadius
            )
        }
    }

    public var droneCount: Int { entities.count }
}
```

**Step 4: Run tests**

Run: `cd Engine2043 && swift test --filter ShieldDroneTests 2>&1 | tail -20`
Expected: All ShieldDroneTests pass

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/ShieldDroneComponent.swift Engine2043/Sources/Engine2043/ECS/Systems/ShieldDroneSystem.swift Engine2043/Tests/Engine2043Tests/ShieldDroneTests.swift
git commit -m "feat: add ShieldDroneComponent and ShieldDroneSystem with tests"
```

---

### Task 6: Integrate Shield Drones into Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

This task wires everything together in the scene. Changes in 4 areas:

**Step 1: Add shieldDroneSystem and shieldDrones array**

Near the top of `Galaxy1Scene`, after `private let itemSystem = ItemSystem()` (line 20):

```swift
    private let shieldDroneSystem = ShieldDroneSystem()
```

After `private var shieldEntities: [GKEntity] = []` (line 40), add:

```swift
    private var shieldDrones: [GKEntity] = []
```

**Step 2: Update registerEntity and unregisterEntity**

In `registerEntity` (line 101-109), add after `itemSystem.register(entity)`:

```swift
        shieldDroneSystem.register(entity)
```

In `unregisterEntity` (line 111-120), add after `itemSystem.unregister(entity)`:

```swift
        shieldDroneSystem.unregister(entity)
```

**Step 3: Update removeEntity**

In `removeEntity` (line 122-), add after `shieldEntities.removeAll { $0 === entity }`:

```swift
        shieldDrones.removeAll { $0 === entity }
```

**Step 4: Update the game loop to call shieldDroneSystem.update()**

Find where systems are updated (around line 170-200 in the `update` method). After `itemSystem.update(deltaTime: time.fixedDeltaTime)` (or wherever the item system update is), add:

```swift
            shieldDroneSystem.update(deltaTime: time.fixedDeltaTime)
            for drone in shieldDroneSystem.pendingRemovals {
                pendingRemovals.append(drone)
            }
```

**Step 5: Update spawnEnemyProjectile to add shieldDrone to collision mask**

In `spawnEnemyProjectile` (line 876-894), change the mask from `[.player]` to `[.player, .shieldDrone]`:

```swift
        let physics = PhysicsComponent(
            collisionSize: SIMD2(8, 8),
            layer: .enemyProjectile,
            mask: [.player, .shieldDrone]
        )
```

**Step 6: Update spawnUtilityItem to set initial spriteId based on random type**

In `spawnUtilityItem` (line 918-940), after setting the random `currentCycleIndex`, set the initial spriteId:

```swift
        let itemComp = ItemComponent()
        itemComp.currentCycleIndex = Int.random(in: 0..<UtilityItemType.allCases.count)

        // Set initial sprite based on random type
        switch itemComp.utilityItemType {
        case .energyCell:
            render.spriteId = "energyDrop"
        case .chargeCell:
            render.spriteId = "chargeCell"
        case .orbitingShield:
            render.spriteId = "shieldDrop"
        }

        entity.addComponent(itemComp)
```

**Step 7: Add spawnShieldDrones method**

Add after `spawnWeaponModuleItem`:

```swift
    private func spawnShieldDrones() {
        guard let playerTransform = player.component(ofType: TransformComponent.self) else { return }
        let maxDrones = GameConfig.ShieldDrone.maxDrones
        let slotsAvailable = maxDrones - shieldDrones.count
        guard slotsAvailable > 0 else { return }
        let toSpawn = min(2, slotsAvailable)

        for _ in 0..<toSpawn {
            let entity = GKEntity()
            entity.addComponent(TransformComponent(position: playerTransform.position))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.ShieldDrone.droneSize,
                layer: .shieldDrone,
                mask: [.enemyProjectile]
            )
            entity.addComponent(physics)

            let render = RenderComponent(size: GameConfig.ShieldDrone.droneSize, color: GameConfig.Palette.shieldDrone)
            render.spriteId = "shieldDrone"
            entity.addComponent(render)

            let droneComp = ShieldDroneComponent()
            droneComp.ownerEntity = player
            entity.addComponent(droneComp)

            registerEntity(entity)
            shieldDrones.append(entity)
        }

        // Redistribute orbit angles evenly
        let totalDrones = shieldDrones.count
        for (i, drone) in shieldDrones.enumerated() {
            if let comp = drone.component(ofType: ShieldDroneComponent.self) {
                comp.orbitAngle = Float(i) * (2 * .pi / Float(totalDrones))
            }
        }
    }
```

**Step 8: Add orbitingShield case to handlePlayerCollectsItem**

In `handlePlayerCollectsItem` (line 1237-1274), add after the `.chargeCell` case:

```swift
            case .orbitingShield:
                spawnShieldDrones()
```

**Step 9: Add shield drone collision handling to processCollisions**

In `processCollisions` (line 1161-1197), add these checks BEFORE the player-enemyProjectile checks (before line 1188). This ensures drones intercept projectiles before they hit the player:

```swift
            } else if layerA.contains(.shieldDrone) && layerB.contains(.enemyProjectile) {
                if let drone = entityA.component(ofType: ShieldDroneComponent.self) {
                    drone.takeHit()
                    sfx?.play(.bossShieldDeflect)
                    pendingRemovals.append(entityB)
                }
            } else if layerB.contains(.shieldDrone) && layerA.contains(.enemyProjectile) {
                if let drone = entityB.component(ofType: ShieldDroneComponent.self) {
                    drone.takeHit()
                    sfx?.play(.bossShieldDeflect)
                    pendingRemovals.append(entityA)
                }
```

**Step 10: Clean up shield drones on player death**

In the game over check (around line 284-289), after `sfx?.stopMusic()`, add:

```swift
            for drone in shieldDrones {
                pendingRemovals.append(drone)
            }
```

**Step 11: Build and run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 12: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: integrate orbiting shield drones — spawning, collision, cleanup"
```

---

### Task 7: Run Full Test Suite + Manual Verification

**Step 1: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -30`
Expected: All tests pass

**Step 2: Build the app**

Run: `cd /Users/david/Code/XCode/turbo-carnival && xcodebuild -scheme turbo-carnival -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit any remaining fixes**

If any fixes were needed, commit them with an appropriate message.

---

Plan complete and saved to `docs/plans/2026-03-07-utility-drops-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
