# Remaining Graphics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace all placeholder colored quads (projectiles, pickups, effects, HUD) with procedurally generated sprite art using a dual-texture rendering system.

**Architecture:** Crisp sprites (projectiles, pickups) are added to the existing 512x512 texture atlas with AA off. Soft sprites (effects, HUD) go in a new 256x256 EffectTextureSheet with AA on. The renderer does two draw calls per frame — one per texture — using a second SpriteBatcher. No Metal shader changes needed.

**Tech Stack:** Swift 6, Metal, CoreGraphics, Swift Testing

---

### Task 1: Add Projectile Sprites to SpriteFactory

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write failing tests for all 5 projectile sprites**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func makePlayerBulletReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makePlayerBullet()
    #expect(width == 6)
    #expect(height == 12)
    #expect(pixels.count == 6 * 12 * 4)
}

@Test func makePlayerBulletHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makePlayerBullet()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeTriSpreadBulletReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeTriSpreadBullet()
    #expect(width == 8)
    #expect(height == 8)
    #expect(pixels.count == 8 * 8 * 4)
}

@Test func makeTriSpreadBulletHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeTriSpreadBullet()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeVulcanBulletReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeVulcanBullet()
    #expect(width == 4)
    #expect(height == 8)
    #expect(pixels.count == 4 * 8 * 4)
}

@Test func makeVulcanBulletHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeVulcanBullet()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeEnemyBulletReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeEnemyBullet()
    #expect(width == 8)
    #expect(height == 8)
    #expect(pixels.count == 8 * 8 * 4)
}

@Test func makeEnemyBulletHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeEnemyBullet()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeGravBombSpriteReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeGravBombSprite()
    #expect(width == 16)
    #expect(height == 16)
    #expect(pixels.count == 16 * 16 * 4)
}

@Test func makeGravBombSpriteHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeGravBombSprite()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: Compilation errors — methods don't exist yet.

**Step 3: Implement all 5 projectile sprite methods**

Add to `SpriteFactory.swift` after the existing `makeBossShield()` method:

```swift
// MARK: - Player Bullet (6x12)
// Vertical elongated diamond, white core with cyan (#00ffd2) trailing edge.

public static func makePlayerBullet() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 6, h = 12
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2

    // Cyan trailing edge (bottom half)
    ctx.setFillColor(cgColor(0, 255, 210))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
    ctx.addLine(to: CGPoint(x: 1, y: CGFloat(h) / 2))
    ctx.addLine(to: CGPoint(x: cx, y: 2))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: CGFloat(h) / 2))
    ctx.closePath()
    ctx.fillPath()

    // White core (upper portion)
    ctx.setFillColor(cgColor(255, 255, 255))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
    ctx.addLine(to: CGPoint(x: 2, y: CGFloat(h) / 2 + 1))
    ctx.addLine(to: CGPoint(x: cx, y: 4))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: CGFloat(h) / 2 + 1))
    ctx.closePath()
    ctx.fillPath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Tri-Spread Bullet (8x8)
// Small rotated diamond, orange (#ff8033) outline, bright center.

public static func makeTriSpreadBullet() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 8, h = 8
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Dark orange fill
    ctx.setFillColor(cgColor(100, 50, 20))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
    ctx.addLine(to: CGPoint(x: 1, y: cy))
    ctx.addLine(to: CGPoint(x: cx, y: 1))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: cy))
    ctx.closePath()
    ctx.fillPath()

    // Orange outline
    ctx.setStrokeColor(cgColor(255, 128, 51))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
    ctx.addLine(to: CGPoint(x: 1, y: cy))
    ctx.addLine(to: CGPoint(x: cx, y: 1))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: cy))
    ctx.closePath()
    ctx.strokePath()

    // Bright center
    ctx.setFillColor(cgColor(255, 200, 150))
    ctx.fillEllipse(in: CGRect(x: cx - 1, y: cy - 1, width: 2, height: 2))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Vulcan Bullet (4x8)
// Narrow dart, red (#ff3333) outline, white tip.

public static func makeVulcanBullet() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 4, h = 8
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2

    // Dark red fill
    ctx.setFillColor(cgColor(80, 15, 15))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
    ctx.addLine(to: CGPoint(x: 0, y: 2))
    ctx.addLine(to: CGPoint(x: cx, y: 0))
    ctx.addLine(to: CGPoint(x: CGFloat(w), y: 2))
    ctx.closePath()
    ctx.fillPath()

    // Red outline
    ctx.setStrokeColor(cgColor(255, 51, 51))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
    ctx.addLine(to: CGPoint(x: 0, y: 2))
    ctx.addLine(to: CGPoint(x: cx, y: 0))
    ctx.addLine(to: CGPoint(x: CGFloat(w), y: 2))
    ctx.closePath()
    ctx.strokePath()

    // White tip
    ctx.setFillColor(cgColor(255, 255, 255))
    ctx.fillEllipse(in: CGRect(x: cx - 1, y: CGFloat(h) - 3, width: 2, height: 2))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Enemy Bullet (8x8)
// Downward-pointing arrowhead, hostile orange (#ff9e64) outline, dark fill.

public static func makeEnemyBullet() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 8, h = 8
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2

    // Dark fill
    ctx.setFillColor(cgColor(80, 40, 20))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: 1))
    ctx.addLine(to: CGPoint(x: 1, y: CGFloat(h) - 2))
    ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 4))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: CGFloat(h) - 2))
    ctx.closePath()
    ctx.fillPath()

    // Orange outline
    ctx.setStrokeColor(cgColor(255, 158, 100))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: 1))
    ctx.addLine(to: CGPoint(x: 1, y: CGFloat(h) - 2))
    ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 4))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 1, y: CGFloat(h) - 2))
    ctx.closePath()
    ctx.strokePath()

    // Bright core
    ctx.setFillColor(cgColor(255, 220, 180))
    ctx.fillEllipse(in: CGRect(x: cx - 1, y: 3, width: 2, height: 2))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Gravity Bomb Sprite (16x16)
// Octagonal shell, gold (#ffda4d) outline, dark center, bright core dot.

public static func makeGravBombSprite() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 16, h = 16
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Octagon
    let r: CGFloat = 6
    var pts: [CGPoint] = []
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        pts.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
    }

    // Dark fill
    ctx.setFillColor(cgColor(50, 40, 10))
    ctx.beginPath()
    ctx.move(to: pts[0])
    for pt in pts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Gold outline
    ctx.setStrokeColor(cgColor(255, 218, 77))
    ctx.setLineWidth(2)
    ctx.beginPath()
    ctx.move(to: pts[0])
    for pt in pts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.strokePath()

    // Bright core dot
    ctx.setFillColor(cgColor(255, 240, 180))
    ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add projectile sprites to SpriteFactory"
```

---

### Task 2: Add Pickup Sprites to SpriteFactory

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write failing tests for all 3 pickup sprites**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func makeEnergyDropReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeEnergyDrop()
    #expect(width == 16)
    #expect(height == 16)
    #expect(pixels.count == 16 * 16 * 4)
}

@Test func makeEnergyDropHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeEnergyDrop()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeChargeCellReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeChargeCell()
    #expect(width == 16)
    #expect(height == 16)
    #expect(pixels.count == 16 * 16 * 4)
}

@Test func makeChargeCellHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeChargeCell()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeWeaponModuleSpriteReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeWeaponModuleSprite()
    #expect(width == 20)
    #expect(height == 20)
    #expect(pixels.count == 20 * 20 * 4)
}

@Test func makeWeaponModuleSpriteHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeWeaponModuleSprite()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: Compilation errors — methods don't exist yet.

**Step 3: Implement all 3 pickup sprite methods**

Add to `SpriteFactory.swift`:

```swift
// MARK: - Energy Drop (16x16)
// Lightning bolt silhouette, gold (#e0af68) fill, white highlight line.

public static func makeEnergyDrop() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 16, h = 16
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    // Lightning bolt shape
    ctx.setFillColor(cgColor(224, 175, 104))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 9, y: 14))
    ctx.addLine(to: CGPoint(x: 5, y: 14))
    ctx.addLine(to: CGPoint(x: 8, y: 8))
    ctx.addLine(to: CGPoint(x: 5, y: 8))
    ctx.addLine(to: CGPoint(x: 10, y: 2))
    ctx.addLine(to: CGPoint(x: 11, y: 2))
    ctx.addLine(to: CGPoint(x: 8, y: 7))
    ctx.addLine(to: CGPoint(x: 11, y: 7))
    ctx.closePath()
    ctx.fillPath()

    // White highlight line down center
    ctx.setStrokeColor(cgColor(255, 255, 255, 200))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 9, y: 13))
    ctx.addLine(to: CGPoint(x: 7, y: 8))
    ctx.addLine(to: CGPoint(x: 10, y: 3))
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Charge Cell (16x16)
// Hexagonal battery, purple (#9966ff) outline, segmented interior, bright core.

public static func makeChargeCell() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 16, h = 16
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Hexagon
    let r: CGFloat = 6
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

    // Segment lines
    ctx.setStrokeColor(cgColor(80, 50, 140))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 4, y: cy - 1))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: cy - 1))
    ctx.move(to: CGPoint(x: 4, y: cy + 1))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: cy + 1))
    ctx.strokePath()

    // Bright core
    ctx.setFillColor(cgColor(200, 180, 255))
    ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Weapon Module (20x20)
// Diamond frame with crosshair/plus inside, blue (#4d80ff) outline, darker fill.

public static func makeWeaponModuleSprite() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 20, h = 20
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Dark fill diamond
    ctx.setFillColor(cgColor(15, 25, 60))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
    ctx.addLine(to: CGPoint(x: 2, y: cy))
    ctx.addLine(to: CGPoint(x: cx, y: 2))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: cy))
    ctx.closePath()
    ctx.fillPath()

    // Blue outline diamond
    ctx.setStrokeColor(cgColor(77, 128, 255))
    ctx.setLineWidth(2)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 2))
    ctx.addLine(to: CGPoint(x: 2, y: cy))
    ctx.addLine(to: CGPoint(x: cx, y: 2))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: cy))
    ctx.closePath()
    ctx.strokePath()

    // Crosshair/plus inside
    ctx.setStrokeColor(cgColor(120, 160, 255))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: cy - 4))
    ctx.addLine(to: CGPoint(x: cx, y: cy + 4))
    ctx.move(to: CGPoint(x: cx - 4, y: cy))
    ctx.addLine(to: CGPoint(x: cx + 4, y: cy))
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add pickup sprites to SpriteFactory"
```

---

### Task 3: Register New Crisp Sprites in TextureAtlas

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write failing test for new sprite names**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func textureAtlasIncludesProjectileAndPickupSprites() {
    let names = TextureAtlas.spriteNames
    #expect(names.contains("playerBullet"))
    #expect(names.contains("triSpreadBullet"))
    #expect(names.contains("vulcanBullet"))
    #expect(names.contains("enemyBullet"))
    #expect(names.contains("gravBombSprite"))
    #expect(names.contains("energyDrop"))
    #expect(names.contains("chargeCell"))
    #expect(names.contains("weaponModule"))
}
```

**Step 2: Run tests to verify it fails**

Run: `cd Engine2043 && swift test --filter textureAtlasIncludesProjectileAndPickupSprites 2>&1 | tail -10`
Expected: FAIL — names not in the set.

**Step 3: Update TextureAtlas with new layout entries and generators**

In `TextureAtlas.swift`:

Update `spriteNames`:
```swift
public nonisolated(unsafe) static let spriteNames: Set<String> = [
    "player", "swarmer", "bruiser", "capitalHull", "turret", "bossCore", "bossShield",
    "playerBullet", "triSpreadBullet", "vulcanBullet", "enemyBullet", "gravBombSprite",
    "energyDrop", "chargeCell", "weaponModule"
]
```

Add new entries to `layout` array:
```swift
// Row 172: Projectiles
SpriteEntry(name: "playerBullet",    x: 0,   y: 172, width: 6,  height: 12),
SpriteEntry(name: "triSpreadBullet", x: 6,   y: 172, width: 8,  height: 8),
SpriteEntry(name: "vulcanBullet",    x: 14,  y: 172, width: 4,  height: 8),
SpriteEntry(name: "enemyBullet",     x: 18,  y: 172, width: 8,  height: 8),
SpriteEntry(name: "gravBombSprite",  x: 26,  y: 172, width: 16, height: 16),
// Row 188: Pickups
SpriteEntry(name: "energyDrop",      x: 0,   y: 188, width: 16, height: 16),
SpriteEntry(name: "chargeCell",      x: 16,  y: 188, width: 16, height: 16),
SpriteEntry(name: "weaponModule",    x: 32,  y: 188, width: 20, height: 20),
```

Add new entries to the `generators` array inside `init(device:)`:
```swift
("playerBullet",    SpriteFactory.makePlayerBullet),
("triSpreadBullet", SpriteFactory.makeTriSpreadBullet),
("vulcanBullet",    SpriteFactory.makeVulcanBullet),
("enemyBullet",     SpriteFactory.makeEnemyBullet),
("gravBombSprite",  SpriteFactory.makeGravBombSprite),
("energyDrop",      SpriteFactory.makeEnergyDrop),
("chargeCell",      SpriteFactory.makeChargeCell),
("weaponModule",    SpriteFactory.makeWeaponModuleSprite),
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: register projectile and pickup sprites in TextureAtlas"
```

---

### Task 4: Add Soft Context Helper and Effect Sprites to SpriteFactory

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write failing tests for all 3 effect sprites**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func makeGravBombBlastReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeGravBombBlast()
    #expect(width == 128)
    #expect(height == 128)
    #expect(pixels.count == 128 * 128 * 4)
}

@Test func makeGravBombBlastHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeGravBombBlast()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeEmpFlashReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeEmpFlash()
    #expect(width == 128)
    #expect(height == 128)
    #expect(pixels.count == 128 * 128 * 4)
}

@Test func makeEmpFlashHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeEmpFlash()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeOverchargeGlowReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeOverchargeGlow()
    #expect(width == 64)
    #expect(height == 64)
    #expect(pixels.count == 64 * 64 * 4)
}

@Test func makeOverchargeGlowHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeOverchargeGlow()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: Compilation errors — methods don't exist yet.

**Step 3: Add makeSoftContext helper and implement effect sprites**

Add to `SpriteFactory.swift` in the `// MARK: - Helpers` section, after `makeContext`:

```swift
static func makeSoftContext(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    return ctx
}
```

Add effect sprite methods:

```swift
// MARK: - Grav Bomb Blast (128x128)
// Radial gradient ring — gold-white center fading to transparent gold. Hollow center.

public static func makeGravBombBlast() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 128, h = 128
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Draw radial gradient ring manually with concentric circles
    let maxR: CGFloat = 60
    let minR: CGFloat = 20
    let steps = 40
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps)
        let r = maxR - t * (maxR - minR)
        let alpha = UInt8(min(255, Int((1.0 - t) * 0.6 * 255)))
        let green = UInt8(min(255, 218 + Int(t * 37)))
        ctx.setFillColor(cgColor(255, green, UInt8(min(255, 77 + Int(t * 103))), alpha))
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    // Hollow center — clear inner circle
    ctx.setBlendMode(.clear)
    ctx.fillEllipse(in: CGRect(x: cx - minR + 4, y: cy - minR + 4,
                                width: (minR - 4) * 2, height: (minR - 4) * 2))
    ctx.setBlendMode(.normal)

    // Bright ring at inner edge
    ctx.setStrokeColor(cgColor(255, 255, 230, 200))
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: cx - minR + 3, y: cy - minR + 3,
                                  width: (minR - 3) * 2, height: (minR - 3) * 2))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - EMP Flash (128x128)
// Full radial gradient — cyan-white center fading to transparent blue.

public static func makeEmpFlash() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 128, h = 128
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Radial gradient from bright center to transparent edge
    let maxR: CGFloat = 60
    let steps = 50
    for i in (0..<steps).reversed() {
        let t = CGFloat(i) / CGFloat(steps)
        let r = maxR * (1.0 - t)
        let alpha = UInt8(min(255, Int(t * 0.5 * 255)))
        let red = UInt8(min(255, Int(128 * t + 80 * (1.0 - t))))
        let green = UInt8(min(255, Int(178 * t + 120 * (1.0 - t))))
        ctx.setFillColor(cgColor(red, green, 255, alpha))
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    // Bright white center
    ctx.setFillColor(cgColor(220, 240, 255, 180))
    ctx.fillEllipse(in: CGRect(x: cx - 8, y: cy - 8, width: 16, height: 16))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Overcharge Glow (64x64)
// Soft diamond/star shape — orange-yellow center with transparent falloff.

public static func makeOverchargeGlow() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 64, h = 64
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Layered diamond shapes from outer (transparent) to inner (bright)
    let layers = 8
    for i in (0..<layers).reversed() {
        let t = CGFloat(i) / CGFloat(layers)
        let size = 28 * (1.0 - t) + 4
        let alpha = UInt8(min(255, Int(t * 0.8 * 255)))
        let green = UInt8(min(255, Int(153 * t + 100 * (1.0 - t))))
        ctx.setFillColor(cgColor(255, green, 0, alpha))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: cy + size))
        ctx.addLine(to: CGPoint(x: cx - size * 0.6, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: cy - size))
        ctx.addLine(to: CGPoint(x: cx + size * 0.6, y: cy))
        ctx.closePath()
        ctx.fillPath()
    }

    // Bright center
    ctx.setFillColor(cgColor(255, 230, 150, 220))
    ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add soft context helper and effect sprites to SpriteFactory"
```

---

### Task 5: Add HUD Sprites to SpriteFactory

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write failing tests for all 6 HUD sprites**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func makeHudBarFrameReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeHudBarFrame()
    #expect(width == 64)
    #expect(height == 8)
    #expect(pixels.count == 64 * 8 * 4)
}

@Test func makeHudBarFrameHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeHudBarFrame()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeHudBarFillReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeHudBarFill()
    #expect(width == 32)
    #expect(height == 4)
    #expect(pixels.count == 32 * 4 * 4)
}

@Test func makeHudBarFillHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeHudBarFill()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeHudChargePipReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeHudChargePip()
    #expect(width == 12)
    #expect(height == 12)
    #expect(pixels.count == 12 * 12 * 4)
}

@Test func makeHudChargePipHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeHudChargePip()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeHudWeaponIconReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeHudWeaponIcon()
    #expect(width == 16)
    #expect(height == 8)
    #expect(pixels.count == 16 * 8 * 4)
}

@Test func makeHudWeaponIconHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeHudWeaponIcon()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeHudHeatFrameReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeHudHeatFrame()
    #expect(width == 16)
    #expect(height == 3)
    #expect(pixels.count == 16 * 3 * 4)
}

@Test func makeHudHeatFrameHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeHudHeatFrame()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeHudHeatFillReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeHudHeatFill()
    #expect(width == 14)
    #expect(height == 2)
    #expect(pixels.count == 14 * 2 * 4)
}

@Test func makeHudHeatFillHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeHudHeatFill()
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: Compilation errors.

**Step 3: Implement all 6 HUD sprite methods**

Add to `SpriteFactory.swift`:

```swift
// MARK: - HUD Bar Frame (64x8)
// Rounded-rect border, cyan (#00ffd2) outline, transparent interior.

public static func makeHudBarFrame() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 64, h = 8
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let rect = CGRect(x: 1, y: 1, width: CGFloat(w) - 2, height: CGFloat(h) - 2)
    let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
    ctx.setStrokeColor(cgColor(0, 255, 210, 200))
    ctx.setLineWidth(1)
    ctx.addPath(path)
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - HUD Bar Fill (32x4)
// Horizontal gradient pill, player cyan.

public static func makeHudBarFill() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 32, h = 4
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
    let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)

    // Gradient from bright left to slightly dimmer right
    for x in 0..<w {
        let t = CGFloat(x) / CGFloat(w)
        let alpha = UInt8(min(255, Int((1.0 - t * 0.3) * 255)))
        ctx.setFillColor(cgColor(0, 255, 210, alpha))
        ctx.fill(CGRect(x: CGFloat(x), y: 0, width: 1, height: CGFloat(h)))
    }

    // Clip to rounded rect shape
    ctx.setBlendMode(.destinationIn)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.setBlendMode(.normal)

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - HUD Charge Pip (12x12)
// Small octagon, gold outline, dark fill, bright center dot.

public static func makeHudChargePip() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 12, h = 12
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2
    let r: CGFloat = 4.5

    var pts: [CGPoint] = []
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        pts.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
    }

    // Dark fill
    ctx.setFillColor(cgColor(40, 30, 10))
    ctx.beginPath()
    ctx.move(to: pts[0])
    for pt in pts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Gold outline
    ctx.setStrokeColor(cgColor(255, 218, 77))
    ctx.setLineWidth(1.5)
    ctx.beginPath()
    ctx.move(to: pts[0])
    for pt in pts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.strokePath()

    // Bright center
    ctx.setFillColor(cgColor(255, 240, 180))
    ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - HUD Weapon Icon (16x8)
// Small chevron pointing up, tinted per weapon type at runtime.

public static func makeHudWeaponIcon() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 16, h = 8
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2

    // White chevron (will be tinted by RenderComponent.color at runtime)
    ctx.setFillColor(cgColor(255, 255, 255))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 1))
    ctx.addLine(to: CGPoint(x: 2, y: 2))
    ctx.addLine(to: CGPoint(x: 4, y: 2))
    ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 3))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: 2))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 2, y: 2))
    ctx.closePath()
    ctx.fillPath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - HUD Heat Frame (16x3)
// Thin rounded-rect outline, neutral gray.

public static func makeHudHeatFrame() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 16, h = 3
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let rect = CGRect(x: 0.5, y: 0.5, width: CGFloat(w) - 1, height: CGFloat(h) - 1)
    let path = CGPath(roundedRect: rect, cornerWidth: 1, cornerHeight: 1, transform: nil)
    ctx.setStrokeColor(cgColor(150, 150, 150, 180))
    ctx.setLineWidth(0.5)
    ctx.addPath(path)
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - HUD Heat Fill (14x2)
// Simple gradient pill, tinted green-to-red at runtime.

public static func makeHudHeatFill() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 14, h = 2
    guard let ctx = makeSoftContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    // White fill (tinted at runtime)
    ctx.setFillColor(cgColor(255, 255, 255))
    let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
    let path = CGPath(roundedRect: rect, cornerWidth: 1, cornerHeight: 1, transform: nil)
    ctx.addPath(path)
    ctx.fillPath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add HUD sprites to SpriteFactory"
```

---

### Task 6: Create EffectTextureSheet

**Files:**
- Create: `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write failing test for EffectTextureSheet sprite names**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func effectTextureSheetSpriteNames() {
    let names = EffectTextureSheet.spriteNames
    #expect(names.contains("gravBombBlast"))
    #expect(names.contains("empFlash"))
    #expect(names.contains("overchargeGlow"))
    #expect(names.contains("hudBarFrame"))
    #expect(names.contains("hudBarFill"))
    #expect(names.contains("hudChargePip"))
    #expect(names.contains("hudWeaponIcon"))
    #expect(names.contains("hudHeatFrame"))
    #expect(names.contains("hudHeatFill"))
}
```

**Step 2: Run tests to verify it fails**

Run: `cd Engine2043 && swift test --filter effectTextureSheetSpriteNames 2>&1 | tail -10`
Expected: Compilation error — `EffectTextureSheet` doesn't exist.

**Step 3: Create EffectTextureSheet.swift**

Create `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift`:

```swift
import Metal
import simd

@MainActor
public final class EffectTextureSheet {
    public let texture: MTLTexture
    private var uvRects: [String: SIMD4<Float>] = [:]

    public static let sheetSize = 256

    public nonisolated(unsafe) static let spriteNames: Set<String> = [
        "gravBombBlast", "empFlash", "overchargeGlow",
        "hudBarFrame", "hudBarFill", "hudChargePip",
        "hudWeaponIcon", "hudHeatFrame", "hudHeatFill"
    ]

    struct SpriteEntry {
        let name: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    static let layout: [SpriteEntry] = [
        // Row 0: Effects
        SpriteEntry(name: "gravBombBlast",  x: 0,   y: 0,   width: 128, height: 128),
        SpriteEntry(name: "empFlash",       x: 128, y: 0,   width: 128, height: 128),
        // Row 128: Overcharge
        SpriteEntry(name: "overchargeGlow", x: 0,   y: 128, width: 64,  height: 64),
        // Row 192: HUD elements
        SpriteEntry(name: "hudBarFrame",    x: 0,   y: 192, width: 64,  height: 8),
        SpriteEntry(name: "hudBarFill",     x: 64,  y: 192, width: 32,  height: 4),
        SpriteEntry(name: "hudChargePip",   x: 96,  y: 192, width: 12,  height: 12),
        SpriteEntry(name: "hudWeaponIcon",  x: 108, y: 192, width: 16,  height: 8),
        SpriteEntry(name: "hudHeatFrame",   x: 124, y: 192, width: 16,  height: 3),
        SpriteEntry(name: "hudHeatFill",    x: 140, y: 192, width: 14,  height: 2),
    ]

    init(device: MTLDevice) throws {
        let size = Self.sheetSize
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        desc.usage = [.shaderRead]

        guard let tex = device.makeTexture(descriptor: desc) else {
            throw RendererError.failedToCreateTexture
        }
        self.texture = tex

        let generators: [(String, () -> (pixels: [UInt8], width: Int, height: Int))] = [
            ("gravBombBlast",  SpriteFactory.makeGravBombBlast),
            ("empFlash",       SpriteFactory.makeEmpFlash),
            ("overchargeGlow", SpriteFactory.makeOverchargeGlow),
            ("hudBarFrame",    SpriteFactory.makeHudBarFrame),
            ("hudBarFill",     SpriteFactory.makeHudBarFill),
            ("hudChargePip",   SpriteFactory.makeHudChargePip),
            ("hudWeaponIcon",  SpriteFactory.makeHudWeaponIcon),
            ("hudHeatFrame",   SpriteFactory.makeHudHeatFrame),
            ("hudHeatFill",    SpriteFactory.makeHudHeatFill),
        ]

        let s = Float(size)

        for entry in Self.layout {
            guard let gen = generators.first(where: { $0.0 == entry.name }) else { continue }
            let (pixels, w, h) = gen.1()
            guard pixels.count == w * h * 4 else { continue }

            pixels.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                tex.replace(
                    region: MTLRegionMake2D(entry.x, entry.y, w, h),
                    mipmapLevel: 0,
                    withBytes: base,
                    bytesPerRow: w * 4
                )
            }

            uvRects[entry.name] = SIMD4<Float>(
                Float(entry.x) / s,
                Float(entry.y) / s,
                Float(entry.width) / s,
                Float(entry.height) / s
            )
        }
    }

    public func uvRect(for spriteId: String) -> SIMD4<Float>? {
        uvRects[spriteId]
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: create EffectTextureSheet for soft effect and HUD sprites"
```

---

### Task 7: Dual-Texture Rendering Support

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameEngine.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/Renderer.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/PlaceholderScene.swift`

The `GameScene` protocol, `Renderer`, and `RenderPassPipeline` need to support a second set of sprites rendered with the effect texture sheet.

**Step 1: Update GameScene protocol**

In `GameEngine.swift`, change the protocol:

```swift
@MainActor
public protocol GameScene: AnyObject {
    func fixedUpdate(time: GameTime)
    func update(time: GameTime)
    func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance]
    func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance]
}
```

Add a default implementation via extension so PlaceholderScene doesn't break:

```swift
extension GameScene {
    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        []
    }
}
```

Update `GameEngine.render`:

```swift
public func render(to drawable: CAMetalDrawable) {
    let sprites = currentScene?.collectSprites(atlas: renderer.textureAtlas) ?? []
    let effectSprites = currentScene?.collectEffectSprites(effectSheet: renderer.effectSheet) ?? []
    renderer.render(to: drawable, sprites: sprites, effectSprites: effectSprites, totalTime: Float(time.totalTime))
}
```

**Step 2: Update Renderer**

In `Renderer.swift`:

Add `effectSheet` property and second batcher. Update init and render method:

```swift
@MainActor
public final class Renderer {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let spriteBatcher: SpriteBatcher
    private let effectBatcher: SpriteBatcher
    private let renderPassPipeline: RenderPassPipeline
    public let textureAtlas: TextureAtlas
    public let effectSheet: EffectTextureSheet
    private let bloomBlurKernel: MPSImageGaussianBlur

    public init(device: MTLDevice) throws {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = queue

        let library = try device.makeDefaultLibrary(bundle: Bundle.module)
        self.renderPassPipeline = try RenderPassPipeline(device: device, library: library)
        self.spriteBatcher = try SpriteBatcher(device: device)
        self.effectBatcher = try SpriteBatcher(device: device)
        self.textureAtlas = try TextureAtlas(device: device)
        self.effectSheet = try EffectTextureSheet(device: device)
        self.bloomBlurKernel = MPSImageGaussianBlur(device: device, sigma: 6.0)
    }

    public func render(to drawable: CAMetalDrawable, sprites: [SpriteInstance], effectSprites: [SpriteInstance], totalTime: Float) {
        let width = drawable.texture.width
        let height = drawable.texture.height
        guard width > 0, height > 0 else { return }

        renderPassPipeline.ensureOffscreenTexture(width: width, height: height)
        spriteBatcher.update(instances: sprites)
        effectBatcher.update(instances: effectSprites)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        var uniforms = Uniforms(viewProjection: makeOrthographicProjection())

        // Pass 1: Forward (sprites -> offscreen)
        renderPassPipeline.encodeForwardPass(
            commandBuffer: commandBuffer,
            batcher: spriteBatcher,
            uniforms: &uniforms,
            texture: textureAtlas.defaultTexture
        )

        // Pass 1b: Effect sprites (same offscreen, load existing content)
        if effectBatcher.instanceCount > 0 {
            renderPassPipeline.encodeEffectPass(
                commandBuffer: commandBuffer,
                batcher: effectBatcher,
                uniforms: &uniforms,
                texture: effectSheet.texture
            )
        }

        // Pass 2: Bloom extract
        renderPassPipeline.encodeBloomExtractPass(commandBuffer: commandBuffer)

        // Pass 3: MPS Gaussian blur
        if let src = renderPassPipeline.bloomExtractTextureForBlur,
           let dst = renderPassPipeline.bloomBlurTextureForBlur {
            bloomBlurKernel.encode(commandBuffer: commandBuffer, sourceTexture: src, destinationTexture: dst)
        }

        // Pass 4: Final composite
        var ppUniforms = PostProcessUniforms(time: totalTime)
        renderPassPipeline.encodePostProcessPass(
            commandBuffer: commandBuffer,
            drawable: drawable,
            uniforms: &ppUniforms
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeOrthographicProjection() -> simd_float4x4 {
        let hw = GameConfig.designWidth / 2
        let hh = GameConfig.designHeight / 2

        return simd_float4x4(
            SIMD4<Float>(1.0 / hw, 0, 0, 0),
            SIMD4<Float>(0, 1.0 / hh, 0, 0),
            SIMD4<Float>(0, 0, -1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
```

**Step 3: Add encodeEffectPass to RenderPassPipeline**

In `RenderPassPipeline.swift`, add a new method after `encodeForwardPass`:

```swift
func encodeEffectPass(
    commandBuffer: MTLCommandBuffer,
    batcher: SpriteBatcher,
    uniforms: inout Uniforms,
    texture: MTLTexture
) {
    guard let offscreen = offscreenTexture else { return }

    let passDesc = MTLRenderPassDescriptor()
    passDesc.colorAttachments[0].texture = offscreen
    passDesc.colorAttachments[0].loadAction = .load   // Keep existing content
    passDesc.colorAttachments[0].storeAction = .store

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
    encoder.setRenderPipelineState(spritePipelineState)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
    encoder.setFragmentTexture(texture, index: 0)
    encoder.setFragmentSamplerState(postProcessSampler, index: 0)  // Linear filtering for soft sprites

    batcher.encode(encoder: encoder)

    encoder.endEncoding()
}
```

**Step 4: Build to verify compilation**

Run: `cd Engine2043 && swift build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/GameEngine.swift Engine2043/Sources/Engine2043/Rendering/Renderer.swift Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift
git commit -m "feat: add dual-texture rendering with effect pass"
```

---

### Task 8: Wire Projectile Sprites in Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Update spawnPlayerProjectile to use sprite IDs**

In `Galaxy1Scene.swift`, find the `spawnPlayerProjectile` method (around line 610). Change the `RenderComponent` to use the weapon-specific sprite ID:

Before the `RenderComponent` creation, determine the sprite ID based on weapon type:
```swift
let weaponType = player.component(ofType: WeaponComponent.self)?.weaponType ?? .doubleCannon
let spriteId: String
switch weaponType {
case .doubleCannon: spriteId = "playerBullet"
case .triSpread:    spriteId = "triSpreadBullet"
case .vulcanAutoGun: spriteId = "vulcanBullet"
case .phaseLaser:   spriteId = "playerBullet" // Fallback, laser doesn't use projectiles
}

let render = RenderComponent(size: projSize, color: SIMD4(1, 1, 1, 1))
render.spriteId = spriteId
entity.addComponent(render)
```

**Step 2: Update spawnEnemyProjectile to use sprite ID**

Find `spawnEnemyProjectile` (around line 647). Change the `RenderComponent`:

```swift
let render = RenderComponent(size: SIMD2(8, 8), color: SIMD4(1, 1, 1, 1))
render.spriteId = "enemyBullet"
entity.addComponent(render)
```

**Step 3: Update spawnGravBomb to use sprite ID**

Find `spawnGravBomb` (around line 668). Change the `RenderComponent`:

```swift
let render = RenderComponent(size: SIMD2(16, 16), color: SIMD4(1, 1, 1, 1))
render.spriteId = "gravBombSprite"
entity.addComponent(render)
```

**Step 4: Build to verify compilation**

Run: `cd Engine2043 && swift build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire projectile sprites in Galaxy1Scene"
```

---

### Task 9: Wire Pickup Sprites in Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Update spawnItem to use energyDrop sprite**

Find `spawnItem` (around line 691). Change the `RenderComponent`:

```swift
let render = RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 1, 1))
render.spriteId = "energyDrop"
entity.addComponent(render)
```

**Step 2: Update spawnWeaponModuleItem to use weaponModule sprite**

Find `spawnWeaponModuleItem` (around line 720). Change the `RenderComponent`:

```swift
let render = RenderComponent(size: GameConfig.Item.size, color: GameConfig.Palette.weaponModule)
render.spriteId = "weaponModule"
entity.addComponent(render)
```

Note: `weaponModule` sprite keeps its color tint (not white) so weapon type colors show through. The initial color is `weaponModule` palette blue. When the weapon cycles, the existing `ItemSystem` should update the color — check if it does.

**Step 3: Check ItemSystem for weapon color cycling**

Read `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift` and verify weapon module items update their `RenderComponent.color` when cycling weapons. If so, those colors should be the weapon palette colors. If the current code sets the render color, keep it as-is. The sprite texture is white-based and will be tinted by the color.

**Step 4: Update charge display items**

Find where secondary charge pips are set in the `appendHUD` method. The charge pips currently use `GameConfig.Palette.gravBomb` color and 10x10 size — these will be updated in Task 11 (HUD). No change needed here.

**Step 5: Build to verify compilation**

Run: `cd Engine2043 && swift build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire pickup sprites in Galaxy1Scene"
```

---

### Task 10: Wire Effect Sprites in Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add collectEffectSprites method to Galaxy1Scene**

Add a new method to Galaxy1Scene that returns effect sprites. These are the overcharge glow, grav bomb blast, and EMP flash visuals that currently live in `collectSprites`.

```swift
public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
    var sprites: [SpriteInstance] = []

    // Overcharge visual
    if let weapon = player.component(ofType: WeaponComponent.self),
       weapon.overchargeActive,
       let transform = player.component(ofType: TransformComponent.self),
       let uv = effectSheet?.uvRect(for: "overchargeGlow") {
        sprites.append(SpriteInstance(
            position: transform.position,
            size: GameConfig.Player.size * 1.5,
            color: SIMD4(1, 1, 1, 0.8),
            uvRect: uv
        ))
    }

    // Blast effects (grav bomb blast, EMP flash)
    for (entity, _) in blastEffects {
        guard let transform = entity.component(ofType: TransformComponent.self),
              let render = entity.component(ofType: RenderComponent.self) else { continue }

        let isEmp = render.size.x >= GameConfig.designWidth * 0.9
        let spriteId = isEmp ? "empFlash" : "gravBombBlast"

        if let uv = effectSheet?.uvRect(for: spriteId) {
            sprites.append(SpriteInstance(
                position: transform.position,
                size: render.size,
                color: SIMD4(1, 1, 1, render.color.w),
                uvRect: uv
            ))
        }
    }

    appendEffectHUD(to: &sprites, effectSheet: effectSheet)

    return sprites
}
```

**Step 2: Remove effect sprites from collectSprites**

In the existing `collectSprites` method, remove:
- The "Overcharge visual" block (lines ~310-318)
- The blast effects are separate entities that go through renderSystem — leave them registered but they'll still render via the white pixel fallback. Actually, blast effect entities don't have `spriteId` set, so they'll render as white pixel quads via the atlas. We need to **not** render them through the atlas path.

To prevent double-rendering of blast effects: modify the blast effect entity creation to set `isVisible = false` on their RenderComponent so the atlas renderSystem skips them. The effect sprites are rendered via `collectEffectSprites` instead. Update `detonateGravBomb` and `activateEMPSweep`:

In `detonateGravBomb` (around line 839), after creating the blast entity's RenderComponent:
```swift
let blastRender = RenderComponent(
    size: SIMD2(radius * 2, radius * 2),
    color: GameConfig.Palette.gravBombBlast
)
blastRender.isVisible = false  // Rendered via effect pass instead
blast.addComponent(blastRender)
```

In `activateEMPSweep` (around line 859), after creating the flash entity's RenderComponent:
```swift
let flashRender = RenderComponent(
    size: SIMD2(GameConfig.designWidth, GameConfig.designHeight),
    color: GameConfig.Palette.empFlash
)
flashRender.isVisible = false  // Rendered via effect pass instead
flash.addComponent(flashRender)
```

Also remove the overcharge visual block from `collectSprites` (the one at lines ~310-318).

**Step 3: Build to verify compilation**

Run: `cd Engine2043 && swift build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire effect sprites via dual-texture effect pass"
```

---

### Task 11: Wire HUD Sprites in Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Create appendEffectHUD method**

Add a new private method that builds HUD sprites for the effect pass:

```swift
private func appendEffectHUD(to sprites: inout [SpriteInstance], effectSheet: EffectTextureSheet?) {
    guard let effectSheet else { return }
    let topY: Float = GameConfig.designHeight / 2 - 20

    // Energy bar frame
    if let uv = effectSheet.uvRect(for: "hudBarFrame") {
        sprites.append(SpriteInstance(
            position: SIMD2(-45, topY),
            size: SIMD2(120, 12),
            color: SIMD4(1, 1, 1, 1),
            uvRect: uv
        ))
    }

    // Energy bar fill
    let health = player.component(ofType: HealthComponent.self)
    let fraction = (health?.currentHealth ?? 0) / (health?.maxHealth ?? 100)
    let barWidth: Float = 116 * fraction
    let barOffset = (barWidth - 116) / 2
    if let uv = effectSheet.uvRect(for: "hudBarFill") {
        sprites.append(SpriteInstance(
            position: SIMD2(-45 + barOffset, topY),
            size: SIMD2(max(barWidth, 0), 8),
            color: GameConfig.Palette.player,
            uvRect: uv
        ))
    }

    // Score bar — stays as white quad (no sprite)
    sprites.append(SpriteInstance(
        position: SIMD2(100, topY),
        size: SIMD2(max(min(Float(scoreSystem.currentScore) / 10.0, 100.0), 0), 8),
        color: SIMD4(1, 1, 1, 0.8)
    ))

    // Secondary charges
    let weapon = player.component(ofType: WeaponComponent.self)
    let charges = weapon?.secondaryCharges ?? 0
    if let uv = effectSheet.uvRect(for: "hudChargePip") {
        for i in 0..<charges {
            sprites.append(SpriteInstance(
                position: SIMD2(140 - Float(i) * 14, -GameConfig.designHeight / 2 + 20),
                size: SIMD2(12, 12),
                color: SIMD4(1, 1, 1, 1),
                uvRect: uv
            ))
        }
    }

    // Weapon indicator
    let weaponType = weapon?.weaponType ?? .doubleCannon
    let weaponColor: SIMD4<Float>
    switch weaponType {
    case .doubleCannon: weaponColor = SIMD4(1, 1, 1, 0.5)
    case .triSpread:    weaponColor = GameConfig.Palette.weaponModule
    case .vulcanAutoGun: weaponColor = SIMD4(1, 0.3, 0.3, 0.8)
    case .phaseLaser:   weaponColor = GameConfig.Palette.laserBeam
    }
    if let uv = effectSheet.uvRect(for: "hudWeaponIcon") {
        sprites.append(SpriteInstance(
            position: SIMD2(0, -GameConfig.designHeight / 2 + 20),
            size: SIMD2(20, 8),
            color: weaponColor,
            uvRect: uv
        ))
    }

    // Phase Laser heat gauge
    if weaponType == .phaseLaser, let w = weapon {
        if let frameUV = effectSheet.uvRect(for: "hudHeatFrame") {
            sprites.append(SpriteInstance(
                position: SIMD2(0, -GameConfig.designHeight / 2 + 30),
                size: SIMD2(20, 3),
                color: SIMD4(1, 1, 1, 1),
                uvRect: frameUV
            ))
        }

        let heatFrac = Float(w.laserHeat / GameConfig.Weapon.laserMaxHeat)
        if let fillUV = effectSheet.uvRect(for: "hudHeatFill") {
            if w.isLaserOverheated {
                let cooldownFrac = Float(w.laserOverheatTimer / GameConfig.Weapon.laserOverheatCooldown)
                sprites.append(SpriteInstance(
                    position: SIMD2(0, -GameConfig.designHeight / 2 + 30),
                    size: SIMD2(20 * cooldownFrac, 2),
                    color: SIMD4(1, 0.2, 0.2, 0.8),
                    uvRect: fillUV
                ))
            } else if heatFrac > 0 {
                let color = SIMD4<Float>(heatFrac, 1.0 - heatFrac * 0.6, 0.2, 0.8)
                sprites.append(SpriteInstance(
                    position: SIMD2(0, -GameConfig.designHeight / 2 + 30),
                    size: SIMD2(20 * heatFrac, 2),
                    color: color,
                    uvRect: fillUV
                ))
            }
        }
    }

    // Overcharge active indicator
    if weapon?.overchargeActive == true {
        if let uv = effectSheet.uvRect(for: "hudBarFill") {
            sprites.append(SpriteInstance(
                position: SIMD2(0, -GameConfig.designHeight / 2 + 38),
                size: SIMD2(20, 3),
                color: GameConfig.Palette.overchargeGlow,
                uvRect: uv
            ))
        }
    }
}
```

**Step 2: Remove the old appendHUD call from collectSprites**

In `collectSprites`, remove the line:
```swift
appendHUD(to: &sprites)
```

The HUD is now rendered via `collectEffectSprites` → `appendEffectHUD`. The game-over and victory overlays should stay in `collectSprites` (they're simple full-screen quads that don't need sprite art).

Keep the game-over/victory overlay calls:
```swift
if gameState == .gameOver {
    appendGameOverOverlay(to: &sprites)
} else if gameState == .victory {
    appendVictoryOverlay(to: &sprites)
}
```

The old `appendHUD` method can be deleted entirely since `appendEffectHUD` replaces it.

**Step 3: Build to verify compilation**

Run: `cd Engine2043 && swift build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 4: Run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire HUD sprites via effect texture sheet"
```

---

### Task 12: Final Verification

**Files:** None (verification only)

**Step 1: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -30`
Expected: All tests pass.

**Step 2: Build the full Xcode project**

Run: `cd /Users/david/Code/XCode/turbo-carnival && xcodebuild -scheme turbo-carnival -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 3: Visual verification**

Launch the app and verify:
- Player bullets are cyan-white diamonds (not white rectangles)
- Enemy bullets are orange arrowheads
- Grav bombs are gold octagons
- Energy drops are lightning bolt shapes
- Weapon modules are blue diamond frames
- Blast effects have radial gradients
- EMP flash has a smooth cyan-white pulse
- HUD energy bar has a frame with gradient fill
- Charge pips are gold octagons
- Weapon indicator is a tinted chevron

**Step 4: Commit if any fixes were needed**

If visual tweaks are needed, adjust sprite drawing code in `SpriteFactory.swift` and commit.
