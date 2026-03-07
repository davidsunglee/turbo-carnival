# Sprite Art via CGContext Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace placeholder colored quads for player and enemy entities with CGContext-generated pixel art sprites packed into a texture atlas.

**Architecture:** New `SpriteFactory` class draws geometric/abstract neon sprites using CGContext (anti-aliasing off). `TextureAtlas` is expanded to pack all sprites into a 512x512 atlas and expose UV rects by name. `RenderComponent` gains a `spriteId` field so the `RenderSystem` can look up UV rects at render time.

**Tech Stack:** Swift 6, Metal, CoreGraphics (CGContext), GameplayKit

---

### Task 1: Add `spriteId` to RenderComponent

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/RenderComponent.swift`
- Test: `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`

**Step 1: Write the failing test**

Add to `ComponentTests.swift`:

```swift
func testRenderComponentSpriteId() {
    let rc = RenderComponent(size: SIMD2(32, 32), color: SIMD4(1, 1, 1, 1))
    XCTAssertNil(rc.spriteId)

    rc.spriteId = "player"
    XCTAssertEqual(rc.spriteId, "player")
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testRenderComponentSpriteId`
Expected: FAIL — `spriteId` does not exist on RenderComponent

**Step 3: Write minimal implementation**

In `RenderComponent.swift`, add the property:

```swift
public final class RenderComponent: GKComponent {
    public var size: SIMD2<Float> = SIMD2(32, 32)
    public var color: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    public var isVisible: Bool = true
    public var spriteId: String?
    // ... rest unchanged
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testRenderComponentSpriteId`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/RenderComponent.swift Engine2043/Tests/Engine2043Tests/ComponentTests.swift
git commit -m "feat: add spriteId property to RenderComponent"
```

---

### Task 2: Create `SpriteFactory` with helper and player ship sprite

**Files:**
- Create: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Create: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing test**

Create `SpriteFactoryTests.swift`:

```swift
import XCTest
@testable import Engine2043

final class SpriteFactoryTests: XCTestCase {
    func testMakePlayerShipReturnsCorrectSize() {
        let (pixels, width, height) = SpriteFactory.makePlayerShip()
        XCTAssertEqual(width, 48)
        XCTAssertEqual(height, 48)
        XCTAssertEqual(pixels.count, 48 * 48 * 4)
    }

    func testMakePlayerShipHasNonTransparentPixels() {
        let (pixels, _, _) = SpriteFactory.makePlayerShip()
        // Check that at least some pixels have non-zero alpha
        let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        XCTAssertTrue(hasVisiblePixels)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter SpriteFactoryTests`
Expected: FAIL — SpriteFactory does not exist

**Step 3: Write minimal implementation**

Create `SpriteFactory.swift`:

```swift
import CoreGraphics
import simd

public enum SpriteFactory {

    // MARK: - Helpers

    /// Creates a CGContext with anti-aliasing disabled and returns it.
    /// Caller draws into the context, then calls `extractPixels`.
    static func makeContext(width: Int, height: Int) -> CGContext? {
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
        ctx.setShouldAntialias(false)
        ctx.setAllowsAntialiasing(false)
        ctx.interpolationQuality = .none
        return ctx
    }

    /// Extracts raw RGBA pixel data from a CGContext.
    static func extractPixels(from ctx: CGContext, width: Int, height: Int) -> [UInt8] {
        guard let data = ctx.data else { return [] }
        let byteCount = width * height * 4
        return Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: byteCount
        ))
    }

    static func cgColor(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) -> CGColor {
        CGColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }

    // MARK: - Player Ship (48x48)
    // Diamond/chevron pointing up. Cyan (#00ffd2) outline, dark interior, bright core, engine glow.

    public static func makePlayerShip() -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 48, h = 48
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }

        let cx = CGFloat(w) / 2

        // Dark interior fill
        ctx.setFillColor(cgColor(0, 40, 35))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 4))     // nose (top in game, CGContext y is flipped)
        ctx.addLine(to: CGPoint(x: 6, y: 10))                // left wing tip
        ctx.addLine(to: CGPoint(x: cx - 4, y: 18))           // left inner notch
        ctx.addLine(to: CGPoint(x: cx, y: 4))                // tail center
        ctx.addLine(to: CGPoint(x: cx + 4, y: 18))           // right inner notch
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: 10))   // right wing tip
        ctx.closePath()
        ctx.fillPath()

        // Bright cyan outline
        ctx.setStrokeColor(cgColor(0, 255, 210))
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx, y: CGFloat(h) - 4))
        ctx.addLine(to: CGPoint(x: 6, y: 10))
        ctx.addLine(to: CGPoint(x: cx - 4, y: 18))
        ctx.addLine(to: CGPoint(x: cx, y: 4))
        ctx.addLine(to: CGPoint(x: cx + 4, y: 18))
        ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: 10))
        ctx.closePath()
        ctx.strokePath()

        // Cockpit core - bright dot
        ctx.setFillColor(cgColor(200, 255, 240))
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: 28, width: 6, height: 6))

        // Engine glow at tail (bottom in game = top in CGContext)
        ctx.setFillColor(cgColor(0, 200, 180, 180))
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: 2, width: 8, height: 6))
        ctx.setFillColor(cgColor(150, 255, 230, 120))
        ctx.fillEllipse(in: CGRect(x: cx - 2, y: 0, width: 4, height: 4))

        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter SpriteFactoryTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add SpriteFactory with player ship sprite"
```

---

### Task 3: Add Tier 1 Swarmer sprite

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing test**

Add to `SpriteFactoryTests.swift`:

```swift
func testMakeSwarmerReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeSwarmer()
    XCTAssertEqual(width, 32)
    XCTAssertEqual(height, 32)
    XCTAssertEqual(pixels.count, 32 * 32 * 4)
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testMakeSwarmerReturnsCorrectSize`
Expected: FAIL — `makeSwarmer` does not exist

**Step 3: Write minimal implementation**

Add to `SpriteFactory.swift`:

```swift
// MARK: - Tier 1 Swarmer (32x32)
// Downward-pointing dart. Pink/magenta (#f7768e) outline, dark fill, bright core.

public static func makeSwarmer() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 32, h = 32
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2

    // Dark magenta fill
    ctx.setFillColor(cgColor(100, 30, 50))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: 4))              // bottom point (top in game = nose pointing down)
    ctx.addLine(to: CGPoint(x: 4, y: CGFloat(h) - 4))  // top-left wing
    ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 10)) // top center notch
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: CGFloat(h) - 4)) // top-right wing
    ctx.closePath()
    ctx.fillPath()

    // Pink outline
    ctx.setStrokeColor(cgColor(247, 118, 142))
    ctx.setLineWidth(2)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: 4))
    ctx.addLine(to: CGPoint(x: 4, y: CGFloat(h) - 4))
    ctx.addLine(to: CGPoint(x: cx, y: CGFloat(h) - 10))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 4, y: CGFloat(h) - 4))
    ctx.closePath()
    ctx.strokePath()

    // Energy core
    ctx.setFillColor(cgColor(255, 200, 210))
    ctx.fillEllipse(in: CGRect(x: cx - 2, y: 14, width: 4, height: 4))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testMakeSwarmerReturnsCorrectSize`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add Tier 1 Swarmer sprite to SpriteFactory"
```

---

### Task 4: Add Tier 2 Bruiser sprite

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing test**

Add to `SpriteFactoryTests.swift`:

```swift
func testMakeBruiserReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeBruiser()
    XCTAssertEqual(width, 40)
    XCTAssertEqual(height, 40)
    XCTAssertEqual(pixels.count, 40 * 40 * 4)
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testMakeBruiserReturnsCorrectSize`
Expected: FAIL — `makeBruiser` does not exist

**Step 3: Write minimal implementation**

Add to `SpriteFactory.swift`:

```swift
// MARK: - Tier 2 Bruiser (40x40)
// Hexagonal body. Blue-cyan (#6490c0) outline, thick edges, turret dots, bright core.

public static func makeBruiser() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 40, h = 40
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Hexagon vertices (flat-top orientation)
    let r: CGFloat = 17
    var hexPoints: [CGPoint] = []
    for i in 0..<6 {
        let angle = CGFloat(i) * .pi / 3 - .pi / 6 // flat-top
        hexPoints.append(CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
    }

    // Dark blue fill
    ctx.setFillColor(cgColor(25, 40, 80))
    ctx.beginPath()
    ctx.move(to: hexPoints[0])
    for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Blue-cyan outline (thick)
    ctx.setStrokeColor(cgColor(100, 144, 192))
    ctx.setLineWidth(3)
    ctx.beginPath()
    ctx.move(to: hexPoints[0])
    for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.strokePath()

    // Turret dots on sides
    ctx.setFillColor(cgColor(160, 200, 240))
    ctx.fillEllipse(in: CGRect(x: 4, y: cy - 2, width: 4, height: 4))
    ctx.fillEllipse(in: CGRect(x: CGFloat(w) - 8, y: cy - 2, width: 4, height: 4))

    // Bright core
    ctx.setFillColor(cgColor(200, 230, 255))
    ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testMakeBruiserReturnsCorrectSize`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add Tier 2 Bruiser sprite to SpriteFactory"
```

---

### Task 5: Add Tier 3 Capital Ship hull and turret sprites

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing tests**

Add to `SpriteFactoryTests.swift`:

```swift
func testMakeCapitalHullReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeCapitalHull()
    XCTAssertEqual(width, 140)
    XCTAssertEqual(height, 60)
    XCTAssertEqual(pixels.count, 140 * 60 * 4)
}

func testMakeTurretReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeTurret()
    XCTAssertEqual(width, 24)
    XCTAssertEqual(height, 24)
    XCTAssertEqual(pixels.count, 24 * 24 * 4)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter "testMakeCapitalHullReturnsCorrectSize|testMakeTurretReturnsCorrectSize"`
Expected: FAIL — methods do not exist

**Step 3: Write minimal implementation**

Add to `SpriteFactory.swift`:

```swift
// MARK: - Tier 3 Capital Ship Hull (140x60)
// Long hull with angular cutouts. Dark gray-blue (#323250) fill, lighter panel lines.

public static func makeCapitalHull() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 140, h = 60
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cw = CGFloat(w)
    let ch = CGFloat(h)

    // Main hull body with angled bow
    ctx.setFillColor(cgColor(40, 50, 80))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 10, y: 5))
    ctx.addLine(to: CGPoint(x: cw - 10, y: 5))
    ctx.addLine(to: CGPoint(x: cw - 2, y: 15))
    ctx.addLine(to: CGPoint(x: cw - 2, y: ch - 15))
    ctx.addLine(to: CGPoint(x: cw - 10, y: ch - 5))
    ctx.addLine(to: CGPoint(x: 10, y: ch - 5))
    ctx.addLine(to: CGPoint(x: 2, y: ch - 15))
    ctx.addLine(to: CGPoint(x: 2, y: 15))
    ctx.closePath()
    ctx.fillPath()

    // Darker recessed panel lines
    ctx.setStrokeColor(cgColor(30, 35, 55))
    ctx.setLineWidth(1)
    // Horizontal panel lines
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 12, y: 20)); ctx.addLine(to: CGPoint(x: cw - 12, y: 20))
    ctx.move(to: CGPoint(x: 12, y: ch - 20)); ctx.addLine(to: CGPoint(x: cw - 12, y: ch - 20))
    // Vertical panel lines
    ctx.move(to: CGPoint(x: 35, y: 8)); ctx.addLine(to: CGPoint(x: 35, y: ch - 8))
    ctx.move(to: CGPoint(x: 70, y: 8)); ctx.addLine(to: CGPoint(x: 70, y: ch - 8))
    ctx.move(to: CGPoint(x: 105, y: 8)); ctx.addLine(to: CGPoint(x: 105, y: ch - 8))
    ctx.strokePath()

    // Bridge highlight at center
    ctx.setFillColor(cgColor(60, 75, 110))
    ctx.fill(CGRect(x: 55, y: 22, width: 30, height: 16))

    // Outer edge highlight
    ctx.setStrokeColor(cgColor(70, 85, 120))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 10, y: 5))
    ctx.addLine(to: CGPoint(x: cw - 10, y: 5))
    ctx.addLine(to: CGPoint(x: cw - 2, y: 15))
    ctx.addLine(to: CGPoint(x: cw - 2, y: ch - 15))
    ctx.addLine(to: CGPoint(x: cw - 10, y: ch - 5))
    ctx.addLine(to: CGPoint(x: 10, y: ch - 5))
    ctx.addLine(to: CGPoint(x: 2, y: ch - 15))
    ctx.addLine(to: CGPoint(x: 2, y: 15))
    ctx.closePath()
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Tier 3 Turret (24x24)
// Octagonal ring. Orange-red (#ff6633) ring, dark center, bright barrel dot.

public static func makeTurret() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 24, h = 24
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Octagon ring
    let outerR: CGFloat = 10
    let innerR: CGFloat = 6
    var outerPts: [CGPoint] = []
    var innerPts: [CGPoint] = []
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        outerPts.append(CGPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
        innerPts.append(CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
    }

    // Orange-red outer fill
    ctx.setFillColor(cgColor(255, 102, 51))
    ctx.beginPath()
    ctx.move(to: outerPts[0])
    for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Dark inner cutout
    ctx.setFillColor(cgColor(40, 20, 15))
    ctx.beginPath()
    ctx.move(to: innerPts[0])
    for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Barrel dot
    ctx.setFillColor(cgColor(255, 180, 120))
    ctx.fillEllipse(in: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter "testMakeCapitalHullReturnsCorrectSize|testMakeTurretReturnsCorrectSize"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add Capital Ship hull and turret sprites to SpriteFactory"
```

---

### Task 6: Add Boss core and shield sprites

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing tests**

Add to `SpriteFactoryTests.swift`:

```swift
func testMakeBossCoreReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeBossCore()
    XCTAssertEqual(width, 64)
    XCTAssertEqual(height, 64)
    XCTAssertEqual(pixels.count, 64 * 64 * 4)
}

func testMakeBossShieldReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeBossShield()
    XCTAssertEqual(width, 40)
    XCTAssertEqual(height, 12)
    XCTAssertEqual(pixels.count, 40 * 12 * 4)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter "testMakeBossCoreReturnsCorrectSize|testMakeBossShieldReturnsCorrectSize"`
Expected: FAIL — methods do not exist

**Step 3: Write minimal implementation**

Add to `SpriteFactory.swift`:

```swift
// MARK: - Boss Core (64x64)
// Concentric geometric rings. Blue (#4499ff) outer, white-blue center, octagonal edges.

public static func makeBossCore() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 64, h = 64
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    let cx = CGFloat(w) / 2
    let cy = CGFloat(h) / 2

    // Outer octagon ring (glow)
    func octagon(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<8).map { i in
            let angle = CGFloat(i) * .pi / 4
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    let center = CGPoint(x: cx, y: cy)

    // Dim outer glow ring
    let outerPts = octagon(center: center, radius: 28)
    ctx.setFillColor(cgColor(30, 60, 120))
    ctx.beginPath()
    ctx.move(to: outerPts[0])
    for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Blue outer ring stroke
    ctx.setStrokeColor(cgColor(68, 153, 255))
    ctx.setLineWidth(3)
    ctx.beginPath()
    ctx.move(to: outerPts[0])
    for pt in outerPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.strokePath()

    // Mid ring
    let midPts = octagon(center: center, radius: 18)
    ctx.setFillColor(cgColor(20, 40, 80))
    ctx.beginPath()
    ctx.move(to: midPts[0])
    for pt in midPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    ctx.setStrokeColor(cgColor(100, 180, 255))
    ctx.setLineWidth(2)
    ctx.beginPath()
    ctx.move(to: midPts[0])
    for pt in midPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.strokePath()

    // Inner core
    let innerPts = octagon(center: center, radius: 8)
    ctx.setFillColor(cgColor(150, 210, 255))
    ctx.beginPath()
    ctx.move(to: innerPts[0])
    for pt in innerPts.dropFirst() { ctx.addLine(to: pt) }
    ctx.closePath()
    ctx.fillPath()

    // Bright center dot
    ctx.setFillColor(cgColor(220, 240, 255))
    ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}

// MARK: - Boss Shield Segment (40x12)
// Elongated bar. Light cyan (#99ccff) with bright edge highlights.

public static func makeBossShield() -> (pixels: [UInt8], width: Int, height: Int) {
    let w = 40, h = 12
    guard let ctx = makeContext(width: w, height: h) else {
        return (Array(repeating: 0, count: w * h * 4), w, h)
    }

    // Rounded-rect body
    let rect = CGRect(x: 2, y: 2, width: CGFloat(w) - 4, height: CGFloat(h) - 4)
    let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)

    // Fill with semi-transparent cyan
    ctx.setFillColor(cgColor(100, 170, 220, 180))
    ctx.addPath(path)
    ctx.fillPath()

    // Bright edge highlight
    ctx.setStrokeColor(cgColor(153, 204, 255))
    ctx.setLineWidth(2)
    ctx.addPath(path)
    ctx.strokePath()

    // Center highlight line
    ctx.setStrokeColor(cgColor(200, 230, 255, 150))
    ctx.setLineWidth(1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 6, y: CGFloat(h) / 2))
    ctx.addLine(to: CGPoint(x: CGFloat(w) - 6, y: CGFloat(h) / 2))
    ctx.strokePath()

    return (extractPixels(from: ctx, width: w, height: h), w, h)
}
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter "testMakeBossCoreReturnsCorrectSize|testMakeBossShieldReturnsCorrectSize"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add Boss core and shield sprites to SpriteFactory"
```

---

### Task 7: Expand TextureAtlas to pack sprites and expose UV rects

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing test**

Add to `SpriteFactoryTests.swift`:

```swift
func testTextureAtlasSpriteNames() {
    // Verify the atlas layout constants are defined
    let names = TextureAtlas.spriteNames
    XCTAssertTrue(names.contains("player"))
    XCTAssertTrue(names.contains("swarmer"))
    XCTAssertTrue(names.contains("bruiser"))
    XCTAssertTrue(names.contains("capitalHull"))
    XCTAssertTrue(names.contains("turret"))
    XCTAssertTrue(names.contains("bossCore"))
    XCTAssertTrue(names.contains("bossShield"))
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testTextureAtlasSpriteNames`
Expected: FAIL — `spriteNames` does not exist

**Step 3: Write implementation**

Replace `TextureAtlas.swift` with:

```swift
import Metal
import simd

@MainActor
public final class TextureAtlas {
    public let texture: MTLTexture
    private var uvRects: [String: SIMD4<Float>] = [:]

    public static let atlasSize = 512

    public static let spriteNames: Set<String> = [
        "player", "swarmer", "bruiser", "capitalHull", "turret", "bossCore", "bossShield"
    ]

    struct SpriteEntry {
        let name: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    static let layout: [SpriteEntry] = [
        SpriteEntry(name: "player",      x: 0,   y: 0,   width: 48,  height: 48),
        SpriteEntry(name: "swarmer",     x: 48,  y: 0,   width: 32,  height: 32),
        SpriteEntry(name: "bruiser",     x: 80,  y: 0,   width: 40,  height: 40),
        SpriteEntry(name: "capitalHull", x: 0,   y: 48,  width: 140, height: 60),
        SpriteEntry(name: "turret",      x: 140, y: 48,  width: 24,  height: 24),
        SpriteEntry(name: "bossCore",    x: 0,   y: 108, width: 64,  height: 64),
        SpriteEntry(name: "bossShield",  x: 64,  y: 108, width: 40,  height: 12),
    ]

    // Legacy accessor for code that still passes the texture to the renderer
    public var defaultTexture: MTLTexture { texture }

    init(device: MTLDevice) throws {
        let size = Self.atlasSize
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

        // Place white 1x1 pixel at (511, 511) as fallback
        let white: [UInt8] = [255, 255, 255, 255]
        tex.replace(
            region: MTLRegionMake2D(size - 1, size - 1, 1, 1),
            mipmapLevel: 0,
            withBytes: white,
            bytesPerRow: 4
        )

        // Store fallback UV rect
        let s = Float(size)
        uvRects["_white"] = SIMD4<Float>(Float(size - 1) / s, Float(size - 1) / s, 1.0 / s, 1.0 / s)

        // Generate and blit all sprites
        let generators: [(String, () -> (pixels: [UInt8], width: Int, height: Int))] = [
            ("player",      SpriteFactory.makePlayerShip),
            ("swarmer",     SpriteFactory.makeSwarmer),
            ("bruiser",     SpriteFactory.makeBruiser),
            ("capitalHull", SpriteFactory.makeCapitalHull),
            ("turret",      SpriteFactory.makeTurret),
            ("bossCore",    SpriteFactory.makeBossCore),
            ("bossShield",  SpriteFactory.makeBossShield),
        ]

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

    /// Returns the UV rect for a sprite, or the white-pixel fallback.
    public func uvRect(for spriteId: String?) -> SIMD4<Float> {
        guard let id = spriteId, let rect = uvRects[id] else {
            return uvRects["_white"] ?? SIMD4<Float>(0, 0, 1, 1)
        }
        return rect
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testTextureAtlasSpriteNames`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: expand TextureAtlas to pack sprites and expose UV rects"
```

---

### Task 8: Wire RenderSystem to use UV rects from TextureAtlas

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/RenderSystem.swift`

The `RenderSystem.collectSprites()` method currently creates `SpriteInstance` with default `uvRect` (0,0,1,1). It needs to look up UV rects from the atlas based on each entity's `RenderComponent.spriteId`.

**Step 1: Write the failing test**

This is a wiring change that depends on `TextureAtlas` (which requires a Metal device). Rather than mocking Metal, we test the behavior change: when `spriteId` is set and an atlas is provided, the returned `SpriteInstance` should have a non-default `uvRect`.

Add to `ComponentTests.swift`:

```swift
func testRenderSystemUsesDefaultUvRectWithoutSpriteId() {
    let rs = RenderSystem()
    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: .zero))
    entity.addComponent(RenderComponent(size: SIMD2(32, 32), color: SIMD4(1, 1, 1, 1)))
    rs.register(entity)

    let sprites = rs.collectSprites(atlas: nil)
    XCTAssertEqual(sprites.count, 1)
    XCTAssertEqual(sprites[0].uvRect, SIMD4<Float>(0, 0, 1, 1))
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testRenderSystemUsesDefaultUvRectWithoutSpriteId`
Expected: FAIL — `collectSprites(atlas:)` does not match signature (current is `collectSprites()`)

**Step 3: Write implementation**

Update `RenderSystem.swift`:

```swift
import GameplayKit

@MainActor
public final class RenderSystem {
    private var entities: [GKEntity] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: TransformComponent.self) != nil,
              entity.component(ofType: RenderComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func collectSprites(atlas: TextureAtlas? = nil) -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []
        sprites.reserveCapacity(entities.count)

        for entity in entities {
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let render = entity.component(ofType: RenderComponent.self),
                  render.isVisible else { continue }

            let uv = atlas?.uvRect(for: render.spriteId) ?? SIMD4<Float>(0, 0, 1, 1)

            sprites.append(SpriteInstance(
                position: transform.position,
                size: render.size,
                color: render.color,
                rotation: transform.rotation,
                uvRect: uv
            ))
        }

        return sprites
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter testRenderSystemUsesDefaultUvRectWithoutSpriteId`
Expected: PASS

**Step 5: Also verify no other tests broke from signature change**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test`
Expected: If any callers of `collectSprites()` break, update them in the next step. The default parameter `atlas: nil` should keep existing call sites working.

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/RenderSystem.swift Engine2043/Tests/Engine2043Tests/ComponentTests.swift
git commit -m "feat: wire RenderSystem to look up UV rects from TextureAtlas"
```

---

### Task 9: Pass TextureAtlas into scene's render path and assign sprite IDs to entities

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

This task wires everything together: entities get `spriteId` set at spawn time, and the scene passes the atlas to `collectSprites()`.

**Step 1: Understand the current render flow**

The scene needs access to the `TextureAtlas` to pass it to `RenderSystem.collectSprites(atlas:)`. Currently, `Galaxy1Scene` doesn't hold a reference to the atlas. Check how sprites are collected by searching for `collectSprites` calls.

Search for: `collectSprites` in `Galaxy1Scene.swift` and any file that calls it.

**Step 2: Update Galaxy1Scene to accept and use TextureAtlas**

Find all `collectSprites()` call sites in the codebase. The renderer calls `render(to:sprites:totalTime:)` with sprites collected from the scene. The scene's `collectSprites()` call likely lives in a protocol method or the platform layer.

Search for `collectSprites` across the project to find the caller, then:

1. Add a `textureAtlas` property to `Galaxy1Scene`
2. Pass it through to `renderSystem.collectSprites(atlas: textureAtlas)`
3. Set `spriteId` on `RenderComponent` at each entity spawn point

**Step 3: Set sprite IDs on entity creation**

At each spawn site in `Galaxy1Scene.swift`, after creating the `RenderComponent`, set the `spriteId`:

- `setupPlayer()` (line ~77): After creating `RenderComponent`, add `rc.spriteId = "player"` and set `color` to white
- `spawnTier1Formation()` (line ~413): Set `spriteId = "swarmer"`, color to white
- `spawnTier2Group()` (line ~453): Set `spriteId = "bruiser"`, color to white
- `spawnCapitalShip()` hull (line ~482): Set `spriteId = "capitalHull"`, color to white
- `spawnCapitalShip()` turrets (line ~518): Set `spriteId = "turret"`, color to white
- `spawnBoss()` core (line ~552): Set `spriteId = "bossCore"`, color to white
- `spawnBoss()` shields (line ~574): Set `spriteId = "bossShield"`, color to white

For entities keeping colored quads (projectiles, items, effects), leave `spriteId` as nil — the fallback white pixel preserves their current behavior.

**Step 4: Find how `collectSprites` reaches the renderer**

Search the codebase for the call chain:
- `Galaxy1Scene` has `renderSystem.collectSprites()` somewhere in its update/render path
- The platform layer (likely a `MetalView` or `GameViewController`) gets sprites from the scene and passes them to `Renderer.render(to:sprites:totalTime:)`

Add the atlas reference where it's needed so `collectSprites(atlas:)` gets the atlas.

**Step 5: Run the full test suite**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test`
Expected: All tests pass. Existing entity behavior unchanged — sprites with `spriteId = nil` fall back to white pixel with color multiply (same as before).

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire sprite IDs to entities and pass atlas through render path"
```

---

### Task 10: Visual verification and adjustments

**Files:**
- Possibly modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift` (art tweaks)

**Step 1: Build and run the game**

Build the Xcode project and run on macOS target. Verify:

1. Player ship renders as a cyan diamond/chevron instead of a solid square
2. Tier 1 swarmers render as pink darts
3. Tier 2 bruisers render as blue hexagons
4. Capital ship hull renders with panel detail instead of a flat rectangle
5. Turrets render as orange octagonal rings
6. Boss core renders as concentric blue rings
7. Boss shields render as cyan bars
8. Projectiles, items, and effects still render correctly as colored quads
9. Post-processing (bloom, scanlines, chromatic aberration) still works
10. No visual artifacts from atlas UV sampling at sprite edges

**Step 2: Check sampler state**

Verify that `RenderPassPipeline.swift` line 64-67 already has `.nearest` filtering on the sprite sampler. This is confirmed from the code read — no change needed.

**Step 3: Adjust art if needed**

If any sprite looks wrong (shapes not centered, colors off, edges bleeding), adjust the CGContext drawing code in `SpriteFactory.swift`. Common issues:
- CGContext Y-axis is flipped vs game coordinates — sprites may appear upside-down
- Stroke width may extend outside the sprite bounds — add padding or reduce radii
- Premultiplied alpha may darken semi-transparent edges

**Step 4: Commit any adjustments**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift
git commit -m "fix: adjust sprite art for visual correctness"
```

---

### Task 11: Final test run and cleanup

**Step 1: Run full test suite**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test`
Expected: All tests pass

**Step 2: Check for any leftover issues**

- Search for any remaining `RenderComponent(size:` calls that should have a `spriteId` but don't
- Verify the old `TextureAtlas.defaultTexture` property still works via the computed property alias

**Step 3: Commit if any cleanup was needed**

```bash
git add -A
git commit -m "chore: cleanup after sprite art integration"
```
