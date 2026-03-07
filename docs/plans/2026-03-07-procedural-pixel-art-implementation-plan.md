# Procedural Pixel Art Sprites Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace placeholder rectangle visuals for the player and all enemy types with procedurally generated pixel art sprites rendered through a texture atlas.

**Architecture:** A `PixelCanvas` utility paints RGBA bitmaps using drawing primitives. `SpriteGenerator` creates pixel art for each entity type (2 animation frames each). All sprites are packed into a single `MTLTexture` atlas. `RenderComponent` gains a `textureId` field; `RenderSystem` maps it to UV rects and passes them through `SpriteInstance.uvRect` (already exists) to the shader.

**Tech Stack:** Swift 6, Metal, GameplayKit ECS

---

### Task 1: PixelCanvas — Drawing Primitive

**Files:**
- Create: `Engine2043/Sources/Engine2043/Rendering/PixelCanvas.swift`
- Test: `Engine2043/Tests/Engine2043Tests/PixelCanvasTests.swift`

**Step 1: Write the failing tests**

```swift
// PixelCanvasTests.swift
import XCTest
@testable import Engine2043

final class PixelCanvasTests: XCTestCase {

    func testSetPixel() {
        var canvas = PixelCanvas(width: 4, height: 4)
        canvas.setPixel(x: 1, y: 2, color: PixelColor(r: 255, g: 0, b: 0, a: 255))
        let c = canvas.getPixel(x: 1, y: 2)
        XCTAssertEqual(c.r, 255)
        XCTAssertEqual(c.g, 0)
        XCTAssertEqual(c.b, 0)
        XCTAssertEqual(c.a, 255)
    }

    func testSetPixelOutOfBoundsIsIgnored() {
        var canvas = PixelCanvas(width: 4, height: 4)
        canvas.setPixel(x: -1, y: 0, color: PixelColor(r: 255, g: 0, b: 0, a: 255))
        canvas.setPixel(x: 4, y: 0, color: PixelColor(r: 255, g: 0, b: 0, a: 255))
        // Should not crash — all pixels remain zero
        let c = canvas.getPixel(x: 0, y: 0)
        XCTAssertEqual(c.a, 0)
    }

    func testFillRect() {
        var canvas = PixelCanvas(width: 8, height: 8)
        let red = PixelColor(r: 255, g: 0, b: 0, a: 255)
        canvas.fillRect(x: 2, y: 3, w: 3, h: 2, color: red)
        // Inside the rect
        XCTAssertEqual(canvas.getPixel(x: 2, y: 3).r, 255)
        XCTAssertEqual(canvas.getPixel(x: 4, y: 4).r, 255)
        // Outside the rect
        XCTAssertEqual(canvas.getPixel(x: 1, y: 3).a, 0)
        XCTAssertEqual(canvas.getPixel(x: 5, y: 3).a, 0)
    }

    func testHLine() {
        var canvas = PixelCanvas(width: 8, height: 4)
        let blue = PixelColor(r: 0, g: 0, b: 255, a: 255)
        canvas.hLine(x: 1, y: 2, length: 4, color: blue)
        for dx in 0..<4 {
            XCTAssertEqual(canvas.getPixel(x: 1 + dx, y: 2).b, 255)
        }
        XCTAssertEqual(canvas.getPixel(x: 0, y: 2).a, 0)
        XCTAssertEqual(canvas.getPixel(x: 5, y: 2).a, 0)
    }

    func testVLine() {
        var canvas = PixelCanvas(width: 4, height: 8)
        let green = PixelColor(r: 0, g: 255, b: 0, a: 255)
        canvas.vLine(x: 2, y: 1, length: 3, color: green)
        for dy in 0..<3 {
            XCTAssertEqual(canvas.getPixel(x: 2, y: 1 + dy).g, 255)
        }
        XCTAssertEqual(canvas.getPixel(x: 2, y: 0).a, 0)
        XCTAssertEqual(canvas.getPixel(x: 2, y: 4).a, 0)
    }

    func testMirrorHorizontally() {
        var canvas = PixelCanvas(width: 6, height: 2)
        let red = PixelColor(r: 255, g: 0, b: 0, a: 255)
        // Paint only in left half (x=0,1,2)
        canvas.setPixel(x: 0, y: 0, color: red)
        canvas.setPixel(x: 1, y: 1, color: red)
        canvas.mirrorHorizontally()
        // Right half should be mirrored
        XCTAssertEqual(canvas.getPixel(x: 5, y: 0).r, 255) // mirror of x=0
        XCTAssertEqual(canvas.getPixel(x: 4, y: 1).r, 255) // mirror of x=1
    }

    func testRGBABufferLayout() {
        var canvas = PixelCanvas(width: 2, height: 2)
        canvas.setPixel(x: 0, y: 0, color: PixelColor(r: 10, g: 20, b: 30, a: 40))
        let bytes = canvas.rgbaBytes
        XCTAssertEqual(bytes.count, 2 * 2 * 4)
        // First pixel at (0,0)
        XCTAssertEqual(bytes[0], 10)  // R
        XCTAssertEqual(bytes[1], 20)  // G
        XCTAssertEqual(bytes[2], 30)  // B
        XCTAssertEqual(bytes[3], 40)  // A
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter PixelCanvasTests 2>&1 | tail -5`
Expected: Compilation error — `PixelCanvas` not defined

**Step 3: Write minimal implementation**

```swift
// PixelCanvas.swift
public struct PixelColor: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public static let clear = PixelColor(r: 0, g: 0, b: 0, a: 0)
}

public struct PixelCanvas: Sendable {
    public let width: Int
    public let height: Int
    public private(set) var rgbaBytes: [UInt8]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.rgbaBytes = [UInt8](repeating: 0, count: width * height * 4)
    }

    public func getPixel(x: Int, y: Int) -> PixelColor {
        guard x >= 0, x < width, y >= 0, y < height else { return .clear }
        let i = (y * width + x) * 4
        return PixelColor(r: rgbaBytes[i], g: rgbaBytes[i+1], b: rgbaBytes[i+2], a: rgbaBytes[i+3])
    }

    public mutating func setPixel(x: Int, y: Int, color: PixelColor) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let i = (y * width + x) * 4
        rgbaBytes[i] = color.r
        rgbaBytes[i+1] = color.g
        rgbaBytes[i+2] = color.b
        rgbaBytes[i+3] = color.a
    }

    public mutating func fillRect(x: Int, y: Int, w: Int, h: Int, color: PixelColor) {
        for dy in 0..<h {
            for dx in 0..<w {
                setPixel(x: x + dx, y: y + dy, color: color)
            }
        }
    }

    public mutating func hLine(x: Int, y: Int, length: Int, color: PixelColor) {
        for dx in 0..<length {
            setPixel(x: x + dx, y: y, color: color)
        }
    }

    public mutating func vLine(x: Int, y: Int, length: Int, color: PixelColor) {
        for dy in 0..<length {
            setPixel(x: x, y: y + dy, color: color)
        }
    }

    public mutating func mirrorHorizontally() {
        let halfW = width / 2
        for row in 0..<height {
            for col in 0..<halfW {
                let src = getPixel(x: col, y: row)
                setPixel(x: width - 1 - col, y: row, color: src)
            }
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter PixelCanvasTests 2>&1 | tail -10`
Expected: All 7 tests PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/PixelCanvas.swift Engine2043/Tests/Engine2043Tests/PixelCanvasTests.swift
git commit -m "feat: add PixelCanvas drawing primitive with tests"
```

---

### Task 2: TextureAtlas — Sprite Sheet Packing

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift`
- Test: `Engine2043/Tests/Engine2043Tests/TextureAtlasTests.swift`

**Step 1: Write the failing tests**

```swift
// TextureAtlasTests.swift
import XCTest
@testable import Engine2043

final class TextureAtlasTests: XCTestCase {

    func testPackSpritesComputesUVRects() {
        let atlas = SpriteAtlasPacker()

        var small = PixelCanvas(width: 16, height: 16)
        small.setPixel(x: 0, y: 0, color: PixelColor(r: 255, g: 0, b: 0, a: 255))
        atlas.addSprite(name: "small", canvas: small)

        var big = PixelCanvas(width: 32, height: 32)
        big.setPixel(x: 0, y: 0, color: PixelColor(r: 0, g: 255, b: 0, a: 255))
        atlas.addSprite(name: "big", canvas: big)

        let result = atlas.pack()

        // Atlas should be power-of-2 and fit all sprites
        XCTAssertTrue(result.atlasWidth > 0)
        XCTAssertTrue(result.atlasHeight > 0)
        XCTAssertTrue(result.atlasWidth & (result.atlasWidth - 1) == 0, "Width should be power of 2")

        // UV rects should exist for both sprites
        let smallUV = result.uvRect(for: "small")
        XCTAssertNotNil(smallUV)
        let bigUV = result.uvRect(for: "big")
        XCTAssertNotNil(bigUV)

        // UV rects should be normalized (0..1 range)
        if let uv = smallUV {
            XCTAssertGreaterThan(uv.z, 0) // width > 0
            XCTAssertGreaterThan(uv.w, 0) // height > 0
            XCTAssertLessThanOrEqual(uv.x + uv.z, 1.0)
            XCTAssertLessThanOrEqual(uv.y + uv.w, 1.0)
        }
    }

    func testPackedBytesContainSpriteData() {
        let atlas = SpriteAtlasPacker()

        var canvas = PixelCanvas(width: 4, height: 4)
        let red = PixelColor(r: 255, g: 0, b: 0, a: 255)
        canvas.fillRect(x: 0, y: 0, w: 4, h: 4, color: red)
        atlas.addSprite(name: "red_box", canvas: canvas)

        let result = atlas.pack()

        // The packed bytes should contain the red pixel data somewhere
        let bytes = result.rgbaBytes
        XCTAssertGreaterThan(bytes.count, 0)

        // Find at least one red pixel in the output
        var foundRed = false
        for i in stride(from: 0, to: bytes.count, by: 4) {
            if bytes[i] == 255 && bytes[i+1] == 0 && bytes[i+2] == 0 && bytes[i+3] == 255 {
                foundRed = true
                break
            }
        }
        XCTAssertTrue(foundRed, "Red pixel should be present in atlas bytes")
    }

    func testUnknownSpriteReturnsNil() {
        let atlas = SpriteAtlasPacker()
        let result = atlas.pack()
        XCTAssertNil(result.uvRect(for: "nonexistent"))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter TextureAtlasTests 2>&1 | tail -5`
Expected: Compilation error — `SpriteAtlasPacker` not defined

**Step 3: Write implementation**

Add `SpriteAtlasPacker` and `PackedAtlas` to `TextureAtlas.swift`:

```swift
// Append to TextureAtlas.swift (keep existing TextureAtlas class)
import simd

public final class SpriteAtlasPacker: Sendable {
    private var sprites: [(name: String, canvas: PixelCanvas)] = []

    public init() {}

    public func addSprite(name: String, canvas: PixelCanvas) {
        sprites.append((name, canvas))
    }

    public func pack() -> PackedAtlas {
        // Sort sprites tallest-first for row packing
        let sorted = sprites.sorted { $0.canvas.height > $1.canvas.height }

        // Calculate atlas size — simple row packing
        let padding = 1
        var totalArea = 0
        for (_, c) in sorted {
            totalArea += (c.width + padding) * (c.height + padding)
        }

        // Find smallest power-of-2 that fits
        var size = 64
        while size * size < totalArea * 2 { size *= 2 }
        // Cap at 2048
        size = min(size, 2048)

        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        var uvRects: [String: SIMD4<Float>] = [:]

        var cursorX = 0
        var cursorY = 0
        var rowHeight = 0

        for (name, canvas) in sorted {
            // Advance to next row if needed
            if cursorX + canvas.width > size {
                cursorX = 0
                cursorY += rowHeight + padding
                rowHeight = 0
            }

            // Copy canvas into atlas bytes
            for row in 0..<canvas.height {
                let srcStart = row * canvas.width * 4
                let srcEnd = srcStart + canvas.width * 4
                let dstRow = cursorY + row
                let dstStart = (dstRow * size + cursorX) * 4
                guard dstRow < size else { continue }
                let copyLen = min(srcEnd - srcStart, (size - cursorX) * 4)
                for i in 0..<copyLen {
                    bytes[dstStart + i] = canvas.rgbaBytes[srcStart + i]
                }
            }

            // Store normalized UV rect (x, y, width, height)
            let uvX = Float(cursorX) / Float(size)
            let uvY = Float(cursorY) / Float(size)
            let uvW = Float(canvas.width) / Float(size)
            let uvH = Float(canvas.height) / Float(size)
            uvRects[name] = SIMD4<Float>(uvX, uvY, uvW, uvH)

            rowHeight = max(rowHeight, canvas.height)
            cursorX += canvas.width + padding
        }

        return PackedAtlas(
            rgbaBytes: bytes,
            atlasWidth: size,
            atlasHeight: size,
            uvRects: uvRects
        )
    }
}

public struct PackedAtlas: Sendable {
    public let rgbaBytes: [UInt8]
    public let atlasWidth: Int
    public let atlasHeight: Int
    private let uvRects: [String: SIMD4<Float>]

    init(rgbaBytes: [UInt8], atlasWidth: Int, atlasHeight: Int, uvRects: [String: SIMD4<Float>]) {
        self.rgbaBytes = rgbaBytes
        self.atlasWidth = atlasWidth
        self.atlasHeight = atlasHeight
        self.uvRects = uvRects
    }

    public func uvRect(for name: String) -> SIMD4<Float>? {
        uvRects[name]
    }
}
```

Also add a method to `TextureAtlas` to create a Metal texture from a `PackedAtlas`:

```swift
// Add to TextureAtlas class
public var atlasTexture: MTLTexture?
private var spriteUVRects: [String: SIMD4<Float>] = [:]

public func loadAtlas(_ packed: PackedAtlas) throws {
    let desc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: packed.atlasWidth,
        height: packed.atlasHeight,
        mipmapped: false
    )
    desc.usage = [.shaderRead]

    guard let texture = device.makeTexture(descriptor: desc) else {
        throw RendererError.failedToCreateTexture
    }

    packed.rgbaBytes.withUnsafeBytes { ptr in
        texture.replace(
            region: MTLRegionMake2D(0, 0, packed.atlasWidth, packed.atlasHeight),
            mipmapLevel: 0,
            withBytes: ptr.baseAddress!,
            bytesPerRow: packed.atlasWidth * 4
        )
    }

    self.atlasTexture = texture
    self.spriteUVRects = [:]
    // Copy UV rects by checking each name
    // (PackedAtlas exposes uvRect(for:), we need to store them)
}

public func uvRect(for name: String) -> SIMD4<Float> {
    spriteUVRects[name] ?? SIMD4<Float>(0, 0, 1, 1)
}
```

Note: The `loadAtlas` method needs the `PackedAtlas` to expose its uvRects. Add a `public var allUVRects: [String: SIMD4<Float>]` computed property to `PackedAtlas`, or pass them through. The implementer should store `packed`'s rects into `spriteUVRects` using the uvRect(for:) accessor for each known sprite name. Simplest approach: make `uvRects` in `PackedAtlas` public, or add `public var allNames: [String]` and iterate.

The `TextureAtlas` also needs a stored `device` property — add `private let device: MTLDevice` and set it in `init`.

**Step 4: Run tests to verify they pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter TextureAtlasTests 2>&1 | tail -10`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift Engine2043/Tests/Engine2043Tests/TextureAtlasTests.swift
git commit -m "feat: add SpriteAtlasPacker for packing pixel art into texture atlas"
```

---

### Task 3: RenderComponent + RenderSystem — textureId Support

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/RenderComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/RenderSystem.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift` (uvRect lookup)

**Step 1: Add textureId to RenderComponent**

```swift
// RenderComponent.swift — add property
public var textureId: String?
```

Add convenience init that accepts textureId:

```swift
public convenience init(size: SIMD2<Float>, color: SIMD4<Float>, textureId: String? = nil) {
    self.init()
    self.size = size
    self.color = color
    self.textureId = textureId
}
```

**Step 2: Update RenderSystem to pass UV rects**

Modify `RenderSystem` to accept a `TextureAtlas` reference and use it when building `SpriteInstance`:

```swift
// RenderSystem.swift
public func collectSprites(atlas: TextureAtlas? = nil) -> [SpriteInstance] {
    var sprites: [SpriteInstance] = []
    sprites.reserveCapacity(entities.count)

    for entity in entities {
        guard let transform = entity.component(ofType: TransformComponent.self),
              let render = entity.component(ofType: RenderComponent.self),
              render.isVisible else { continue }

        let uvRect: SIMD4<Float>
        if let textureId = render.textureId, let atlas = atlas {
            uvRect = atlas.uvRect(for: textureId)
        } else {
            uvRect = SIMD4<Float>(0, 0, 1, 1)
        }

        sprites.append(SpriteInstance(
            position: transform.position,
            size: render.size,
            color: render.color,
            rotation: transform.rotation,
            uvRect: uvRect
        ))
    }

    return sprites
}
```

**Step 3: Verify existing tests still pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test 2>&1 | tail -10`
Expected: All existing tests PASS (textureId defaults to nil, uvRect defaults to full-texture)

**Step 4: Update all call sites of collectSprites()**

Search Galaxy1Scene.swift for `collectSprites()` calls and pass the atlas. This requires Galaxy1Scene to have access to the atlas. The scene gets it from the Renderer — add a public accessor:

```swift
// Renderer.swift — add public accessor
public var atlas: TextureAtlas { textureAtlas }
```

Then in Galaxy1Scene (or wherever `collectSprites` is called), pass `atlas: renderer.atlas`.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/RenderComponent.swift \
       Engine2043/Sources/Engine2043/ECS/Systems/RenderSystem.swift \
       Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift
git commit -m "feat: add textureId to RenderComponent and UV rect lookup in RenderSystem"
```

---

### Task 4: Renderer — Atlas Texture Binding

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/Renderer.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift`

**Step 1: Update forward pass to use atlas texture**

In `Renderer.render()`, change the texture passed to `encodeForwardPass` from `textureAtlas.defaultTexture` to `textureAtlas.atlasTexture ?? textureAtlas.defaultTexture`:

```swift
// Renderer.swift line 47 — change:
texture: textureAtlas.defaultTexture
// to:
texture: textureAtlas.atlasTexture ?? textureAtlas.defaultTexture
```

**Step 2: Add atlas loading to Renderer init (or a public method)**

Add a public method to load sprites:

```swift
// Renderer.swift
public func loadSpriteAtlas(_ packed: PackedAtlas) throws {
    try textureAtlas.loadAtlas(packed)
}
```

**Step 3: Verify the game still renders (no atlas loaded = falls back to white pixel)**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/Renderer.swift
git commit -m "feat: bind atlas texture in forward pass with fallback to default"
```

---

### Task 5: SpriteGenerator — Player Ship

**Files:**
- Create: `Engine2043/Sources/Engine2043/Rendering/SpriteGenerator.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteGeneratorTests.swift`

**Step 1: Write the failing test**

```swift
// SpriteGeneratorTests.swift
import XCTest
@testable import Engine2043

final class SpriteGeneratorTests: XCTestCase {

    func testPlayerSpriteFrameCount() {
        let frames = SpriteGenerator.playerShip()
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].width, 30)
        XCTAssertEqual(frames[0].height, 30)
        XCTAssertEqual(frames[1].width, 30)
        XCTAssertEqual(frames[1].height, 30)
    }

    func testPlayerSpriteHasVisiblePixels() {
        let frames = SpriteGenerator.playerShip()
        // Should have non-transparent pixels
        var visibleCount = 0
        for y in 0..<frames[0].height {
            for x in 0..<frames[0].width {
                if frames[0].getPixel(x: x, y: y).a > 0 {
                    visibleCount += 1
                }
            }
        }
        XCTAssertGreaterThan(visibleCount, 50, "Player sprite should have substantial visible pixels")
    }

    func testPlayerSpriteIsSymmetric() {
        let frames = SpriteGenerator.playerShip()
        let canvas = frames[0]
        for y in 0..<canvas.height {
            for x in 0..<canvas.width / 2 {
                let left = canvas.getPixel(x: x, y: y)
                let right = canvas.getPixel(x: canvas.width - 1 - x, y: y)
                XCTAssertEqual(left, right, "Pixel at (\(x),\(y)) should mirror to (\(canvas.width - 1 - x),\(y))")
            }
        }
    }

    func testPlayerFramesDiffer() {
        let frames = SpriteGenerator.playerShip()
        // The two frames should have at least some pixel differences (thruster animation)
        var diffCount = 0
        for y in 0..<frames[0].height {
            for x in 0..<frames[0].width {
                let a = frames[0].getPixel(x: x, y: y)
                let b = frames[1].getPixel(x: x, y: y)
                if a != b { diffCount += 1 }
            }
        }
        XCTAssertGreaterThan(diffCount, 0, "Frames should differ for animation")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter SpriteGeneratorTests 2>&1 | tail -5`
Expected: Compilation error — `SpriteGenerator` not defined

**Step 3: Write the SpriteGenerator with player ship**

```swift
// SpriteGenerator.swift
public enum SpriteGenerator {

    // MARK: - Player Ship (30x30)
    // Top-down fighter: pointed nose, swept delta wings, central fuselage
    // Dark teal hull with cyan highlights, orange thruster at tail
    public static func playerShip() -> [PixelCanvas] {
        return [playerFrame(thrusterExtended: false), playerFrame(thrusterExtended: true)]
    }

    private static func playerFrame(thrusterExtended: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: 30, height: 30)

        // Colors
        let hullDark = PixelColor(r: 20, g: 120, b: 110, a: 255)   // dark teal
        let hullMid = PixelColor(r: 26, g: 156, b: 138, a: 255)    // mid teal
        let hullLight = PixelColor(r: 0, g: 255, b: 210, a: 255)   // cyan highlight
        let cockpit = PixelColor(r: 180, g: 255, b: 240, a: 255)   // bright cyan-white
        let engineOrange = PixelColor(r: 255, g: 160, b: 50, a: 255)
        let engineYellow = PixelColor(r: 255, g: 240, b: 100, a: 255)
        let wingTip = PixelColor(r: 0, g: 200, b: 180, a: 255)

        // Paint left half only, then mirror
        // Nose (top, narrow) — y=0 is top of sprite
        // Fuselage center is at x=14 (left half: 0-14)

        // Nose tip (rows 1-4)
        c.setPixel(x: 14, y: 1, color: hullLight)
        c.hLine(x: 13, y: 2, length: 2, color: hullMid)
        c.hLine(x: 13, y: 3, length: 2, color: hullMid)
        c.hLine(x: 12, y: 4, length: 3, color: hullMid)

        // Cockpit (rows 5-7)
        c.hLine(x: 12, y: 5, length: 3, color: hullDark)
        c.setPixel(x: 14, y: 5, color: cockpit)
        c.hLine(x: 12, y: 6, length: 3, color: hullDark)
        c.setPixel(x: 13, y: 6, color: cockpit)
        c.setPixel(x: 14, y: 6, color: cockpit)
        c.hLine(x: 11, y: 7, length: 4, color: hullDark)
        c.setPixel(x: 14, y: 7, color: cockpit)

        // Upper fuselage (rows 8-12)
        for row in 8...12 {
            let w = 4 + (row - 8)
            c.hLine(x: 15 - w, y: row, length: w, color: hullDark)
            c.setPixel(x: 14, y: row, color: hullLight) // center spine highlight
        }

        // Wing sweep begins (rows 13-20)
        for row in 13...20 {
            let wingSpread = 4 + (row - 8)
            let startX = max(0, 15 - wingSpread)
            c.hLine(x: startX, y: row, length: 15 - startX, color: hullDark)
            // Wing edge highlight
            c.setPixel(x: startX, y: row, color: wingTip)
            // Center spine
            c.setPixel(x: 14, y: row, color: hullLight)
        }

        // Lower fuselage + wing trailing edge (rows 21-25)
        for row in 21...25 {
            let wingSpread = min(14, 4 + (row - 8))
            let startX = max(0, 15 - wingSpread)
            c.hLine(x: startX, y: row, length: 15 - startX, color: hullDark)
            c.setPixel(x: startX, y: row, color: wingTip)
            c.setPixel(x: 14, y: row, color: hullMid)
        }

        // Engine section (rows 26-28)
        c.hLine(x: 11, y: 26, length: 4, color: hullDark)
        c.hLine(x: 12, y: 27, length: 3, color: hullDark)
        c.setPixel(x: 13, y: 27, color: engineOrange)
        c.setPixel(x: 14, y: 27, color: engineOrange)

        // Thruster glow
        if thrusterExtended {
            c.setPixel(x: 13, y: 28, color: engineYellow)
            c.setPixel(x: 14, y: 28, color: engineYellow)
            c.setPixel(x: 14, y: 29, color: engineOrange)
        } else {
            c.setPixel(x: 13, y: 28, color: engineOrange)
            c.setPixel(x: 14, y: 28, color: engineOrange)
        }

        c.mirrorHorizontally()
        return c
    }
}
```

Note: The exact pixel positions above are approximate. The implementer should adjust to create a visually appealing ship shape. The key requirements are:
- 30x30 canvas
- Symmetrical (mirrorHorizontally)
- Pointed nose at top, swept wings widening toward middle, engine at bottom
- Uses dark teal / cyan / cockpit colors
- 2 frames differing in thruster glow area

**Step 4: Run tests to verify they pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter SpriteGeneratorTests 2>&1 | tail -10`
Expected: All 4 tests PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteGenerator.swift Engine2043/Tests/Engine2043Tests/SpriteGeneratorTests.swift
git commit -m "feat: add SpriteGenerator with player ship pixel art"
```

---

### Task 6: SpriteGenerator — Enemy Sprites

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteGenerator.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteGeneratorTests.swift`

**Step 1: Write failing tests for each enemy type**

```swift
// Add to SpriteGeneratorTests.swift

func testSwarmerSpriteFrameCount() {
    let frames = SpriteGenerator.swarmer()
    XCTAssertEqual(frames.count, 2)
    XCTAssertEqual(frames[0].width, 24)
    XCTAssertEqual(frames[0].height, 24)
}

func testSwarmerHasVisiblePixels() {
    let frames = SpriteGenerator.swarmer()
    let visible = countVisiblePixels(frames[0])
    XCTAssertGreaterThan(visible, 30)
}

func testBruiserSpriteFrameCount() {
    let frames = SpriteGenerator.bruiser()
    XCTAssertEqual(frames.count, 2)
    XCTAssertEqual(frames[0].width, 32)
    XCTAssertEqual(frames[0].height, 32)
}

func testBruiserHasVisiblePixels() {
    let frames = SpriteGenerator.bruiser()
    let visible = countVisiblePixels(frames[0])
    XCTAssertGreaterThan(visible, 50)
}

func testCapitalShipSpriteFrameCount() {
    let frames = SpriteGenerator.capitalShip()
    XCTAssertEqual(frames.count, 2)
    XCTAssertEqual(frames[0].width, 280)
    XCTAssertEqual(frames[0].height, 120)
}

func testCapitalShipHasVisiblePixels() {
    let frames = SpriteGenerator.capitalShip()
    let visible = countVisiblePixels(frames[0])
    XCTAssertGreaterThan(visible, 5000)
}

func testBossSpriteFrameCount() {
    let frames = SpriteGenerator.boss()
    XCTAssertEqual(frames.count, 2)
    XCTAssertEqual(frames[0].width, 80)
    XCTAssertEqual(frames[0].height, 80)
}

func testBossHasVisiblePixels() {
    let frames = SpriteGenerator.boss()
    let visible = countVisiblePixels(frames[0])
    XCTAssertGreaterThan(visible, 500)
}

func testAllEnemySpritesAreSymmetric() {
    let allSprites: [(String, [PixelCanvas])] = [
        ("swarmer", SpriteGenerator.swarmer()),
        ("bruiser", SpriteGenerator.bruiser()),
        ("capitalShip", SpriteGenerator.capitalShip()),
        ("boss", SpriteGenerator.boss()),
    ]
    for (name, frames) in allSprites {
        let canvas = frames[0]
        for y in 0..<canvas.height {
            for x in 0..<canvas.width / 2 {
                let left = canvas.getPixel(x: x, y: y)
                let right = canvas.getPixel(x: canvas.width - 1 - x, y: y)
                XCTAssertEqual(left, right, "\(name) pixel at (\(x),\(y)) should mirror")
            }
        }
    }
}

// Helper
private func countVisiblePixels(_ canvas: PixelCanvas) -> Int {
    var count = 0
    for y in 0..<canvas.height {
        for x in 0..<canvas.width {
            if canvas.getPixel(x: x, y: y).a > 0 { count += 1 }
        }
    }
    return count
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter SpriteGeneratorTests 2>&1 | tail -5`
Expected: Compilation error — `swarmer()`, `bruiser()`, etc. not defined

**Step 3: Implement all four enemy sprite generators**

Add to `SpriteGenerator.swift`:

- `swarmer()` — 24x24 diamond/dart, dark magenta body, pink highlights, small thruster. Paint left half, mirror.
- `bruiser()` — 32x32 angular wedge, dark blue body, steel-blue highlights, dual thrusters. Paint left half, mirror.
- `capitalShip()` — 280x120 dreadnought hull, dark navy with panel lines, turret hardpoints as lighter spots at the 4 turret offset positions, 4-5 thrusters at stern. Paint left half, mirror.
- `boss()` — 80x80 hexagonal/octagonal core, deep blue with red weapon ports, central bridge, wide thruster bank. Paint left half, mirror.

Each returns `[PixelCanvas]` with 2 frames (thruster flicker between frames).

Color palette references from `GameConfig.Palette`:
- Swarmer: pink tones (#f7768e = 247,118,142 and darker #a0354a = 160,53,74)
- Bruiser: blue tones (#7aa2f7 = 122,162,247 and darker #2040a0 = 32,64,160)
- Capital Ship: dark hull (#283250 = 40,50,80), turret accents (#ff6633 = 255,102,51)
- Boss: core pink (#ff4499 = 255,68,153), red weapon ports, blue-white shield accents

The implementer should paint recognizable silhouettes using `setPixel`, `hLine`, `vLine`, `fillRect`, and `mirrorHorizontally`. Enemies face downward (nose at bottom, engines at top) since they fly toward the player.

**Step 4: Run tests to verify they pass**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test --filter SpriteGeneratorTests 2>&1 | tail -10`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteGenerator.swift Engine2043/Tests/Engine2043Tests/SpriteGeneratorTests.swift
git commit -m "feat: add swarmer, bruiser, capital ship, and boss pixel art sprites"
```

---

### Task 7: Wire Sprites Into the Game

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteGenerator.swift` (add `generateAll` + pack)
- Modify: `Engine2043/Sources/Engine2043/Rendering/Renderer.swift` (load atlas at init)
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift` (set textureId on entities, animation)

**Step 1: Add generateAll() to SpriteGenerator**

```swift
// SpriteGenerator.swift
public static func generateAll() -> SpriteAtlasPacker {
    let packer = SpriteAtlasPacker()

    for (i, frame) in playerShip().enumerated() {
        packer.addSprite(name: "player_\(i)", canvas: frame)
    }
    for (i, frame) in swarmer().enumerated() {
        packer.addSprite(name: "swarmer_\(i)", canvas: frame)
    }
    for (i, frame) in bruiser().enumerated() {
        packer.addSprite(name: "bruiser_\(i)", canvas: frame)
    }
    for (i, frame) in capitalShip().enumerated() {
        packer.addSprite(name: "capital_\(i)", canvas: frame)
    }
    for (i, frame) in boss().enumerated() {
        packer.addSprite(name: "boss_\(i)", canvas: frame)
    }

    return packer
}
```

**Step 2: Load atlas in Renderer init**

```swift
// Renderer.swift — at end of init():
let packer = SpriteGenerator.generateAll()
let packed = packer.pack()
try textureAtlas.loadAtlas(packed)
```

**Step 3: Set textureId on entity spawn in Galaxy1Scene**

Update each spawn function to set `textureId`:

- `setupPlayer()`: `RenderComponent(size: ..., color: ..., textureId: "player_0")`
- `spawnTier1Formation()`: `textureId: "swarmer_0"`
- `spawnTier2Group()`: `textureId: "bruiser_0"`
- `spawnCapitalShip()`: hull gets `textureId: "capital_0"`, turrets keep nil (they're small hardpoints)
- `spawnBoss()`: boss gets `textureId: "boss_0"`, shields keep nil

**Step 4: Add animation frame toggling**

Add to Galaxy1Scene a simple animation counter:

```swift
// Galaxy1Scene — new property
private var spriteAnimFrame: Int = 0
private var spriteAnimTimer: Double = 0
private let spriteAnimInterval: Double = 1.0 / 5.0  // 5 FPS animation

// In update(deltaTime:) — increment timer and toggle frame:
spriteAnimTimer += deltaTime
if spriteAnimTimer >= spriteAnimInterval {
    spriteAnimTimer -= spriteAnimInterval
    spriteAnimFrame = spriteAnimFrame == 0 ? 1 : 0
    updateSpriteAnimationFrames()
}
```

```swift
private func updateSpriteAnimationFrames() {
    let suffix = "\(spriteAnimFrame)"

    // Player
    if let render = player.component(ofType: RenderComponent.self) {
        render.textureId = "player_\(suffix)"
    }

    // Enemies
    for enemy in enemies {
        guard let render = enemy.component(ofType: RenderComponent.self) else { continue }
        if let tid = render.textureId {
            // Replace the frame suffix
            if tid.hasPrefix("swarmer_") { render.textureId = "swarmer_\(suffix)" }
            else if tid.hasPrefix("bruiser_") { render.textureId = "bruiser_\(suffix)" }
            else if tid.hasPrefix("boss_") { render.textureId = "boss_\(suffix)" }
        }
    }

    // Capital ship hulls
    for hull in capitalShipHulls {
        if let render = hull.component(ofType: RenderComponent.self) {
            render.textureId = "capital_\(suffix)"
        }
    }
}
```

**Step 5: Update collectSprites call site to pass atlas**

Find where `renderSystem.collectSprites()` is called in Galaxy1Scene and change to:
```swift
renderSystem.collectSprites(atlas: renderer.atlas)
```

This requires Galaxy1Scene to have a reference to the renderer. Check how the scene currently gets sprites to the renderer — likely through a `render()` call on the scene that returns `[SpriteInstance]`, which is then passed to `Renderer.render()`. The atlas lookup needs to happen wherever `collectSprites()` is called.

If the scene doesn't hold a renderer reference, the simplest approach: make `TextureAtlas` a standalone singleton or pass it to the scene. Alternative: have the scene hold a reference to a `SpriteUVLookup` protocol backed by TextureAtlas.

**Step 6: Update RenderComponent color behavior**

When a textureId is set, the color in `RenderComponent` acts as a tint multiplied with the texture in the shader (line 70 of Sprite.metal: `return texColor * in.color`). For pixel art sprites, set color to white `SIMD4(1,1,1,1)` so the sprite's own colors show through unmodified. Keep the existing palette color only for entities that still use the white-pixel fallback.

Update spawn functions: when setting a textureId, also set `color: SIMD4(1,1,1,1)`.

**Step 7: Run all tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test 2>&1 | tail -15`
Expected: All tests PASS

**Step 8: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteGenerator.swift \
       Engine2043/Sources/Engine2043/Rendering/Renderer.swift \
       Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift \
       Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift \
       Engine2043/Sources/Engine2043/ECS/Systems/RenderSystem.swift
git commit -m "feat: wire procedural pixel art sprites into game with 2-frame animation"
```

---

### Task 8: Visual Verification + Polish

**Files:**
- Potentially any rendering file for adjustments

**Step 1: Build and run the game**

Run: Build the macOS target in Xcode or via `xcodebuild`

**Step 2: Visually verify each entity**

Check that:
- Player ship shows a recognizable fighter silhouette (not a rectangle)
- Thruster animation flickers at ~5 FPS
- Swarmers appear as small dart shapes
- Bruisers appear as wider armored wedges
- Capital ship hull renders as a large detailed dreadnought
- Boss renders as an imposing hexagonal command ship
- Bloom post-processing makes engine glows bloom naturally
- CRT scanlines overlay the sprites correctly
- Projectiles, items, and effects still render as colored rectangles (no regression)

**Step 3: Adjust pixel art if needed**

Tweak individual pixel positions in the generator functions for better visual results. This is an artistic iteration step.

**Step 4: Run full test suite one final time**

Run: `cd /Users/david/Code/XCode/turbo-carnival/Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests PASS

**Step 5: Final commit if any polish was done**

```bash
git add -A
git commit -m "polish: refine pixel art sprite visuals after visual verification"
```
