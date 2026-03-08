# Weapon Drop Sprite Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the single shared 20x20 weapon module sprite with 4 unique 24x24 weapon-specific sprites with iconic silhouettes.

**Architecture:** Add 4 new sprite generator functions to SpriteFactory (one per weapon type), update the texture atlas layout to accommodate them, and wire up ItemSystem to switch spriteId per weapon type like utility drops already do.

**Tech Stack:** Swift, CoreGraphics (CGContext for procedural sprite drawing), Metal (texture atlas)

---

### Task 1: Add 4 weapon drop sprite tests in SpriteFactoryTests

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift:341-353`

**Step 1: Write failing tests for the 4 new sprite functions**

Add before the closing `}` of the test struct (before line 354):

```swift
    @Test func doubleCannonDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makeDoubleCannonDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        // Verify not blank — at least one non-zero alpha pixel
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test func triSpreadDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makeTriSpreadDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test func lightningArcDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makeLightningArcDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }

    @Test func phaseLaserDropSpriteHasCorrectDimensions() {
        let (pixels, w, h) = SpriteFactory.makePhaseLaserDrop()
        #expect(w == 24)
        #expect(h == 24)
        #expect(pixels.count == 24 * 24 * 4)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent)
    }
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: Compilation error — functions don't exist yet

**Step 3: Commit**

```
git add Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "test: add failing tests for 4 weapon drop sprites"
```

---

### Task 2: Implement the 4 weapon drop sprite functions in SpriteFactory

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift:749-793`

**Step 1: Replace `makeWeaponModuleSprite()` with 4 new functions**

Delete lines 749-793 (the `makeWeaponModuleSprite` function and its MARK comment). Replace with:

```swift
    // MARK: - Double Cannon Drop (24x24)
    // Two parallel vertical barrels with bright muzzle dots at top.

    public static func makeDoubleCannonDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Outer glow
        ctx.setFillColor(cgColor(0, 128, 255, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Left barrel
        ctx.setFillColor(cgColor(0, 128, 255))
        ctx.fill(CGRect(x: 6, y: 5, width: 4, height: 14))
        // Right barrel
        ctx.fill(CGRect(x: 14, y: 5, width: 4, height: 14))

        // Barrel highlights
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 8, y: 6))
        ctx.addLine(to: CGPoint(x: 8, y: 18))
        ctx.move(to: CGPoint(x: 16, y: 6))
        ctx.addLine(to: CGPoint(x: 16, y: 18))
        ctx.strokePath()

        // Muzzle flash dots
        ctx.setFillColor(cgColor(200, 230, 255))
        ctx.fillEllipse(in: CGRect(x: 6.5, y: 3, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 14.5, y: 3, width: 3, height: 3))

        // Base connecting piece
        ctx.setFillColor(cgColor(0, 100, 200))
        ctx.fill(CGRect(x: 8, y: 17, width: 8, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Tri-Spread Drop (24x24)
    // Three lines fanning upward from a common base — trident/spread shape.

    public static func makeTriSpreadDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        // Outer glow
        ctx.setFillColor(cgColor(255, 0, 51, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        let baseX: CGFloat = 12
        let baseY: CGFloat = 20

        // Three spread lines (thick, filled)
        ctx.setStrokeColor(cgColor(255, 0, 51))
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.beginPath()
        // Center prong
        ctx.move(to: CGPoint(x: baseX, y: baseY))
        ctx.addLine(to: CGPoint(x: baseX, y: 4))
        // Left prong
        ctx.move(to: CGPoint(x: baseX, y: baseY))
        ctx.addLine(to: CGPoint(x: 4, y: 6))
        // Right prong
        ctx.move(to: CGPoint(x: baseX, y: baseY))
        ctx.addLine(to: CGPoint(x: 20, y: 6))
        ctx.strokePath()

        // White highlight on center prong
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: baseX, y: baseY - 1))
        ctx.addLine(to: CGPoint(x: baseX, y: 5))
        ctx.strokePath()

        // Bright tips
        ctx.setFillColor(cgColor(255, 200, 210))
        ctx.fillEllipse(in: CGRect(x: baseX - 1.5, y: 3, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 3, y: 5, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 19, y: 5, width: 3, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Lightning Arc Drop (24x24)
    // Plasma ring — circle with 3-4 jagged sparks radiating outward.

    public static func makeLightningArcDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2
        let cy = CGFloat(h) / 2

        // Outer glow
        ctx.setFillColor(cgColor(255, 255, 0, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Main plasma ring
        ctx.setStrokeColor(cgColor(255, 255, 0))
        ctx.setLineWidth(2.5)
        ctx.strokeEllipse(in: CGRect(x: 6, y: 6, width: 12, height: 12))

        // Bright inner ring
        ctx.setFillColor(cgColor(255, 255, 200))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

        // 4 jagged sparks radiating outward
        ctx.setStrokeColor(cgColor(255, 255, 100))
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.beginPath()
        // Top spark
        ctx.move(to: CGPoint(x: cx, y: 6))
        ctx.addLine(to: CGPoint(x: cx - 1, y: 3))
        ctx.addLine(to: CGPoint(x: cx + 1, y: 1))
        // Right spark
        ctx.move(to: CGPoint(x: 18, y: cy))
        ctx.addLine(to: CGPoint(x: 21, y: cy - 1))
        ctx.addLine(to: CGPoint(x: 23, y: cy + 1))
        // Bottom spark
        ctx.move(to: CGPoint(x: cx, y: 18))
        ctx.addLine(to: CGPoint(x: cx + 1, y: 21))
        ctx.addLine(to: CGPoint(x: cx - 1, y: 23))
        // Left spark
        ctx.move(to: CGPoint(x: 6, y: cy))
        ctx.addLine(to: CGPoint(x: 3, y: cy + 1))
        ctx.addLine(to: CGPoint(x: 1, y: cy - 1))
        ctx.strokePath()

        // White highlight on ring top
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 6, startAngle: -.pi * 0.7, endAngle: -.pi * 0.3, clockwise: false)
        ctx.strokePath()

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }

    // MARK: - Phase Laser Drop (24x24)
    // Focused beam line with lens circle at base, radiating lines at tip.

    public static func makePhaseLaserDrop() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 24, h = 24
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Outer glow
        ctx.setFillColor(cgColor(0, 255, 51, 40))
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))

        // Beam line (thick)
        ctx.setStrokeColor(cgColor(0, 255, 51))
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 18))
        ctx.addLine(to: CGPoint(x: cx, y: 5))
        ctx.strokePath()

        // Lens circle at base
        ctx.setStrokeColor(cgColor(0, 200, 40))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: cx - 4, y: 16, width: 8, height: 6))

        // Radiating lines at tip
        ctx.setStrokeColor(cgColor(0, 255, 51))
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.beginPath()
        // Center tip
        ctx.move(to: CGPoint(x: cx, y: 5))
        ctx.addLine(to: CGPoint(x: cx, y: 2))
        // Left ray
        ctx.move(to: CGPoint(x: cx, y: 5))
        ctx.addLine(to: CGPoint(x: cx - 4, y: 2))
        // Right ray
        ctx.move(to: CGPoint(x: cx, y: 5))
        ctx.addLine(to: CGPoint(x: cx + 4, y: 2))
        ctx.strokePath()

        // White highlight down beam center
        ctx.setStrokeColor(cgColor(255, 255, 255, 200))
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: 17))
        ctx.addLine(to: CGPoint(x: cx, y: 6))
        ctx.strokePath()

        // Bright tip dot
        ctx.setFillColor(cgColor(200, 255, 220))
        ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: 2, width: 3, height: 3))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
```

**Step 2: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All 4 new tests PASS

**Step 3: Commit**

```
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift
git commit -m "feat: add 4 unique weapon drop sprites (24x24 each)"
```

---

### Task 3: Update TextureAtlas to use the 4 new sprites

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift:11-14,42,92`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift:350`

**Step 1: Update `spriteNames` set (line 11-15)**

Replace the `spriteNames` declaration:

```swift
    public nonisolated(unsafe) static let spriteNames: Set<String> = [
        "player", "swarmer", "bruiser", "capitalHull", "turret", "bossCore", "bossShield",
        "playerBullet", "triSpreadBullet", "lightningArcIcon", "enemyBullet", "gravBombSprite",
        "energyDrop", "chargeCell", "shieldDrop", "shieldDrone",
        "weaponDoubleCannon", "weaponTriSpread", "weaponLightningArc", "weaponPhaseLaser"
    ]
```

**Step 2: Update layout array (line 42)**

Replace the single `weaponModule` entry with 4 entries. The pickups row at y=188 becomes:

```swift
        // Row 188: Pickups
        SpriteEntry(name: "energyDrop",          x: 0,   y: 188, width: 24, height: 24),
        SpriteEntry(name: "chargeCell",          x: 24,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponDoubleCannon",  x: 48,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponTriSpread",     x: 72,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponLightningArc",  x: 96,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponPhaseLaser",    x: 120, y: 188, width: 24, height: 24),
        SpriteEntry(name: "shieldDrop",          x: 144, y: 188, width: 24, height: 24),
        SpriteEntry(name: "shieldDrone",         x: 168, y: 188, width: 10, height: 10),
```

**Step 3: Update generators array (line 92)**

Replace the single `weaponModule` generator entry:

```swift
            ("weaponDoubleCannon",  SpriteFactory.makeDoubleCannonDrop),
            ("weaponTriSpread",     SpriteFactory.makeTriSpreadDrop),
            ("weaponLightningArc",  SpriteFactory.makeLightningArcDrop),
            ("weaponPhaseLaser",    SpriteFactory.makePhaseLaserDrop),
```

**Step 4: Update test assertion in SpriteFactoryTests (line 350)**

Replace `#expect(names.contains("weaponModule"))` with:

```swift
        #expect(names.contains("weaponDoubleCannon"))
        #expect(names.contains("weaponTriSpread"))
        #expect(names.contains("weaponLightningArc"))
        #expect(names.contains("weaponPhaseLaser"))
```

**Step 5: Run tests**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests PASS

**Step 6: Commit**

```
git add Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: update texture atlas with 4 weapon drop sprite slots"
```

---

### Task 4: Add test for weapon module spriteId switching in ItemSystem

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/ItemSystemTests.swift`

**Step 1: Add test for weapon spriteId switching**

Add before the closing `}` of the test struct:

```swift
    @Test @MainActor func weaponModuleUpdatesSpriteIdPerWeapon() {
        let system = ItemSystem()

        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
        entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: []))
        let item = ItemComponent()
        item.isWeaponModule = true
        item.weaponCycle = [.doubleCannon, .triSpread, .lightningArc, .phaseLaser]
        item.displayedWeapon = .doubleCannon
        item.weaponCycleIndex = 0
        entity.addComponent(item)
        let render = RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 1, 1))
        entity.addComponent(render)

        system.register(entity)

        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "weaponDoubleCannon")

        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "weaponTriSpread")

        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "weaponLightningArc")

        system.handleProjectileHit(on: entity)
        system.update(deltaTime: 1.0 / 60.0)
        #expect(render.spriteId == "weaponPhaseLaser")
    }
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter ItemSystemTests/weaponModuleUpdatesSpriteIdPerWeapon 2>&1 | tail -10`
Expected: FAIL — spriteId is not being set for weapon modules yet

**Step 3: Commit**

```
git add Engine2043/Tests/Engine2043Tests/ItemSystemTests.swift
git commit -m "test: add failing test for weapon module spriteId switching"
```

---

### Task 5: Wire up ItemSystem to switch spriteId per weapon type

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift:54-60`

**Step 1: Add spriteId switching in the weapon module branch**

Replace lines 54-60 (the weapon module switch block):

```swift
            if item.isWeaponModule {
                switch item.displayedWeapon {
                case .doubleCannon:
                    render.color = GameConfig.Palette.weaponDoubleCannon
                    render.spriteId = "weaponDoubleCannon"
                case .triSpread:
                    render.color = GameConfig.Palette.weaponTriSpread
                    render.spriteId = "weaponTriSpread"
                case .lightningArc:
                    render.color = GameConfig.Palette.weaponLightningArc
                    render.spriteId = "weaponLightningArc"
                case .phaseLaser:
                    render.color = GameConfig.Palette.weaponPhaseLaser
                    render.spriteId = "weaponPhaseLaser"
                }
```

**Step 2: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter ItemSystemTests 2>&1 | tail -10`
Expected: All tests PASS

**Step 3: Commit**

```
git add Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift
git commit -m "feat: switch weapon drop spriteId per weapon type"
```

---

### Task 6: Update Galaxy1Scene spawn to use new initial sprite

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:977-978`

**Step 1: Update `spawnWeaponModuleItem` to set initial spriteId based on displayed weapon**

Replace lines 977-978:

```swift
        let render = RenderComponent(size: GameConfig.Item.size, color: GameConfig.Palette.weaponDoubleCannon)
        render.spriteId = "weaponDoubleCannon"
```

Then after line 990 (where `itemComp.displayedWeapon = first` is set), add sprite syncing:

```swift
            switch first {
            case .doubleCannon:
                render.color = GameConfig.Palette.weaponDoubleCannon
                render.spriteId = "weaponDoubleCannon"
            case .triSpread:
                render.color = GameConfig.Palette.weaponTriSpread
                render.spriteId = "weaponTriSpread"
            case .lightningArc:
                render.color = GameConfig.Palette.weaponLightningArc
                render.spriteId = "weaponLightningArc"
            case .phaseLaser:
                render.color = GameConfig.Palette.weaponPhaseLaser
                render.spriteId = "weaponPhaseLaser"
            }
```

**Step 2: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 3: Commit**

```
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: set initial weapon drop sprite based on displayed weapon"
```

---

### Task 7: Clean up dead code

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift` (confirm `makeWeaponModuleSprite` is already removed from Task 2)
- Verify: no remaining references to old `"weaponModule"` sprite ID in source files (docs are fine to leave)

**Step 1: Search for stale references**

Run: `cd Engine2043 && grep -rn '"weaponModule"' Sources/`
Expected: No matches (only docs/ may still reference it, which is fine)

**Step 2: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 3: Final commit**

Only commit if any cleanup was needed. Otherwise, done.
