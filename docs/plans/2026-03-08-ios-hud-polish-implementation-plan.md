# iOS HUD Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix HUD visibility on iOS (safe area), add bitmap font for numeric score and text, add weapon name flash, joystick default position, closer secondary buttons, and game over/victory screens.

**Architecture:** Bitmap font glyphs (5x7 in 6x8 cells) rendered into EffectTextureSheet, composed as SpriteInstances in Galaxy1Scene's effect pass. Safe area insets passed from platform MetalView to scene as game-coordinate offsets. Game over/restart flow via `shouldRestart` flag polled by platform layer.

**Tech Stack:** Swift 6, Metal, CoreGraphics, GameplayKit ECS

---

### Task 1: Bitmap Font Glyphs in SpriteFactory

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift` (append after line 1219)
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing test**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func makeBitmapGlyphReturnsCorrectSize() {
    let (pixels, width, height) = SpriteFactory.makeBitmapGlyph("A")
    #expect(width == 6)
    #expect(height == 8)
    #expect(pixels.count == 6 * 8 * 4)
}

@Test func makeBitmapGlyphHasNonTransparentPixels() {
    let (pixels, _, _) = SpriteFactory.makeBitmapGlyph("A")
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasVisiblePixels)
}

@Test func makeBitmapGlyphSpaceIsTransparent() {
    let (pixels, _, _) = SpriteFactory.makeBitmapGlyph(" ")
    let hasVisiblePixels = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(!hasVisiblePixels)
}

@Test func makeBitmapGlyphAllDigitsProduceContent() {
    for char: Character in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] {
        let (pixels, w, h) = SpriteFactory.makeBitmapGlyph(char)
        #expect(w == 6)
        #expect(h == 8)
        let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
        #expect(hasContent, "Glyph '\(char)' should have visible pixels")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --filter SpriteFactoryTests 2>&1 | tail -20`

Expected: FAIL — `makeBitmapGlyph` does not exist.

**Step 3: Write the implementation**

Append to `SpriteFactory.swift` before the closing `}` of the enum (line 1219):

```swift
    // MARK: - Bitmap Font Glyphs (6x8 each)
    // 5x7 pixel font in a 6x8 cell. Row 7 and column 5 are transparent spacing.
    // Each UInt8 encodes 5 pixels: bit 4 = leftmost, bit 0 = rightmost.

    private static let glyphPatterns: [Character: [UInt8]] = [
        "0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
        "1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
        "3": [0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E],
        "4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
        "5": [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
        "6": [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
        "7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        "8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        "9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
        "A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
        "C": [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
        "D": [0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C],
        "E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
        "F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
        "G": [0x0E, 0x11, 0x10, 0x13, 0x11, 0x11, 0x0E],
        "H": [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "J": [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
        "K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
        "L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
        "M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
        "N": [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11],
        "O": [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        "P": [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
        "Q": [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
        "R": [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
        "S": [0x0E, 0x11, 0x10, 0x0E, 0x01, 0x11, 0x0E],
        "T": [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
        "U": [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        "V": [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
        "W": [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11],
        "X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
        "Y": [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
        "Z": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
        "-": [0x00, 0x00, 0x00, 0x0E, 0x00, 0x00, 0x00],
        " ": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    ]

    public static func makeBitmapGlyph(_ char: Character) -> (pixels: [UInt8], width: Int, height: Int) {
        let w = 6, h = 8
        let pattern = glyphPatterns[char] ?? [UInt8](repeating: 0, count: 7)
        guard let ctx = makeContext(width: w, height: h) else {
            return (Array(repeating: 0, count: w * h * 4), w, h)
        }
        ctx.setFillColor(cgColor(255, 255, 255))
        for row in 0..<7 {
            let bits = pattern[row]
            for col in 0..<5 {
                if bits & (1 << (4 - col)) != 0 {
                    ctx.fill(CGRect(x: CGFloat(col), y: CGFloat(h - 1 - row), width: 1, height: 1))
                }
            }
        }
        return (extractPixels(from: ctx, width: w, height: h), w, h)
    }
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --filter SpriteFactoryTests 2>&1 | tail -20`

Expected: ALL PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: add bitmap font glyph generation to SpriteFactory"
```

---

### Task 2: Register Glyphs in EffectTextureSheet

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

**Step 1: Write the failing test**

Add to `SpriteFactoryTests.swift`:

```swift
@Test func effectTextureSheetIncludesGlyphSprites() {
    let names = EffectTextureSheet.spriteNames
    #expect(names.contains("glyph_0"))
    #expect(names.contains("glyph_9"))
    #expect(names.contains("glyph_A"))
    #expect(names.contains("glyph_Z"))
    #expect(names.contains("glyph_-"))
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --filter effectTextureSheetIncludesGlyphSprites 2>&1 | tail -20`

Expected: FAIL — glyph names not in spriteNames set.

**Step 3: Write the implementation**

Modify `EffectTextureSheet.swift`:

1. Add glyph characters to `spriteNames`:

Replace the `spriteNames` set (line 10-15) with:

```swift
    public static let spriteNames: Set<String> = {
        var names: Set<String> = [
            "gravBombBlast", "empFlash", "overchargeGlow",
            "hudBarFrame", "hudBarFill", "hudChargePip",
            "hudWeaponIcon", "hudHeatFrame", "hudHeatFill"
        ]
        for char in EffectTextureSheet.glyphChars {
            names.insert("glyph_\(char)")
        }
        return names
    }()

    static let glyphChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ- ")
```

2. Change `layout` from a static `let` to a static computed property that includes glyph entries. Replace the `static let layout` (lines 25-38) with:

```swift
    static let layout: [SpriteEntry] = {
        var entries: [SpriteEntry] = [
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
        // Row 208: Bitmap font glyphs (6x8 each, 38 chars fit in one row: 228px < 256px)
        for (i, char) in glyphChars.enumerated() {
            entries.append(SpriteEntry(
                name: "glyph_\(char)",
                x: i * 6,
                y: 208,
                width: 6,
                height: 8
            ))
        }
        return entries
    }()
```

3. Update the `generators` array in `init` (lines 64-74) to include glyph generators:

```swift
        var generators: [(String, () -> (pixels: [UInt8], width: Int, height: Int))] = [
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
        for char in Self.glyphChars {
            generators.append(("glyph_\(char)", { SpriteFactory.makeBitmapGlyph(char) }))
        }
```

Note: change `let generators` to `var generators` on the declaration line.

**Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --filter SpriteFactoryTests 2>&1 | tail -20`

Expected: ALL PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "feat: register bitmap font glyphs in EffectTextureSheet"
```

---

### Task 3: Safe Area Insets + HUD Repositioning

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift` (lines 49-57 game state section, and lines 449-561 appendEffectHUD)
- Modify: `Project2043-iOS/MetalView.swift` (setup + layoutSubviews)

**Step 1: Add hudInsets property to Galaxy1Scene**

Add after the `isSlowMo` property (line 55):

```swift
    public var hudInsets: (top: Float, bottom: Float) = (0, 0)
```

**Step 2: Update appendEffectHUD to use safe area offsets**

In `appendEffectHUD` (line 451), replace:

```swift
        let topY: Float = GameConfig.designHeight / 2 - 20
```

with:

```swift
        let topY: Float = GameConfig.designHeight / 2 - hudInsets.top - 10
        let bottomY: Float = -GameConfig.designHeight / 2 + hudInsets.bottom + 10
```

Then update all bottom-positioned HUD elements to use `bottomY` instead of `-GameConfig.designHeight / 2 + 20`:

- Line 491 (charge pips): change `-GameConfig.designHeight / 2 + 20` → `bottomY`
- Line 510 (weapon icon): change `-GameConfig.designHeight / 2 + 20` → `bottomY`
- Line 521 (heat frame): change `-GameConfig.designHeight / 2 + 30` → `bottomY + 10`
- Line 532/539 (heat fill): change `-GameConfig.designHeight / 2 + 30` → `bottomY + 10`
- Line 554 (overcharge indicator): change `-GameConfig.designHeight / 2 + 38` → `bottomY + 18`

**Step 3: Pass safe area insets from iOS MetalView**

In `Project2043-iOS/MetalView.swift`:

1. Add a stored reference to the scene. Add after `private var touchInput: TouchInputProvider!` (line 13):

```swift
    private var scene: Galaxy1Scene!
```

2. In `setup()`, store the scene reference. Change the scene creation (around line 46) to:

```swift
        scene = Galaxy1Scene()
        scene.inputProvider = touchInput

        let audio = AVAudioManager()
        scene.audioProvider = audio

        let sfxEngine = SynthAudioEngine()
        scene.sfx = sfxEngine

        engine.currentScene = scene
```

(Replace `let scene = Galaxy1Scene()` with `scene = Galaxy1Scene()` to use the stored property.)

3. In `layoutSubviews()`, compute and pass safe area insets (after the metalLayer.drawableSize update, around line 167):

```swift
        // Convert safe area insets from screen points to game-coordinate units
        let screenHeight = bounds.height
        if screenHeight > 0 {
            let gameUnitsPerPoint = GameConfig.designHeight / Float(screenHeight)
            scene.hudInsets = (
                top: Float(safeAreaInsets.top) * gameUnitsPerPoint,
                bottom: Float(safeAreaInsets.bottom) * gameUnitsPerPoint
            )
        }
```

**Step 4: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Project2043-iOS/MetalView.swift
git commit -m "feat: safe area-aware HUD positioning for iOS"
```

---

### Task 4: Numeric Score Display

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift` (appendEffectHUD, around line 477-483)

**Step 1: Add text rendering helper to Galaxy1Scene**

Add a private helper method after `appendEffectHUD` (after line 561):

```swift
    private func makeTextSprites(
        _ text: String,
        at position: SIMD2<Float>,
        color: SIMD4<Float>,
        scale: Float = 1.0,
        effectSheet: EffectTextureSheet
    ) -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []
        let glyphW: Float = 6 * scale
        let glyphH: Float = 8 * scale
        let totalWidth = Float(text.count) * glyphW
        var x = position.x - totalWidth / 2 + glyphW / 2
        for char in text {
            if char != " " {
                let key = "glyph_\(char)"
                if let uv = effectSheet.uvRect(for: key) {
                    sprites.append(SpriteInstance(
                        position: SIMD2(x, position.y),
                        size: SIMD2(glyphW, glyphH),
                        color: color,
                        uvRect: uv
                    ))
                }
            }
            x += glyphW
        }
        return sprites
    }
```

**Step 2: Replace score bar with numeric score**

In `appendEffectHUD`, replace the score bar section (lines 477-483):

```swift
        // Score bar (white quad via effect sheet white pixel)
        sprites.append(SpriteInstance(
            position: SIMD2(100, topY),
            size: SIMD2(max(min(Float(scoreSystem.currentScore) / 10.0, 100.0), 0), 8),
            color: SIMD4(1, 1, 1, 0.8),
            uvRect: effectSheet.whitePixelUV
        ))
```

with:

```swift
        // Numeric score (8-digit zero-padded)
        let scoreText = String(format: "%08d", scoreSystem.currentScore)
        sprites.append(contentsOf: makeTextSprites(
            scoreText,
            at: SIMD2(110, topY),
            color: SIMD4(1, 1, 1, 0.9),
            scale: 1.5,
            effectSheet: effectSheet
        ))
```

**Step 3: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: numeric 8-digit score display using bitmap font"
```

---

### Task 5: Weapon Name Flash

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add weapon tracking state**

Add after the `hudInsets` property (around line 56):

```swift
    private var lastWeaponType: WeaponType?
    private var weaponNameTimer: Double = 0
    private static let weaponNameDuration: Double = 2.0
```

**Step 2: Add weapon name lookup**

Add a private helper near `makeTextSprites`:

```swift
    private func weaponDisplayName(_ type: WeaponType) -> String {
        switch type {
        case .doubleCannon: return "DOUBLE CANNON"
        case .triSpread:    return "TRI-SPREAD"
        case .lightningArc: return "LIGHTNING ARC"
        case .phaseLaser:   return "PHASE LASER"
        }
    }
```

**Step 3: Track weapon changes in fixedUpdate**

In `fixedUpdate`, after the `handleInput()` call (around line 170), add:

```swift
        // Track weapon type changes for HUD flash
        if let weapon = player.component(ofType: WeaponComponent.self) {
            if lastWeaponType == nil {
                lastWeaponType = weapon.weaponType
            } else if weapon.weaponType != lastWeaponType {
                lastWeaponType = weapon.weaponType
                weaponNameTimer = Self.weaponNameDuration
            }
        }
        if weaponNameTimer > 0 {
            weaponNameTimer -= time.fixedDeltaTime
        }
```

**Step 4: Render weapon name in appendEffectHUD**

After the weapon indicator section (after line 515), add:

```swift
        // Weapon name flash
        if weaponNameTimer > 0, let effectSheet {
            let fadeAlpha = Float(min(weaponNameTimer / 0.3, 1.0))  // Fade out over last 0.3s
            let name = weaponDisplayName(weaponType)
            sprites.append(contentsOf: makeTextSprites(
                name,
                at: SIMD2(0, bottomY + 12),
                color: SIMD4(weaponColor.x, weaponColor.y, weaponColor.z, fadeAlpha),
                scale: 1.0,
                effectSheet: effectSheet
            ))
        }
```

**Step 5: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: weapon name flash on weapon switch"
```

---

### Task 6: Joystick Default Position

**Files:**
- Modify: `Project2043-iOS/MetalView.swift` (setupControlOverlays + updateControlOverlays)

**Step 1: Add default joystick position**

In `MetalView`, add a computed property after the control overlay declarations (after line 21):

```swift
    private var defaultJoystickCenter: CGPoint {
        CGPoint(x: 60 + safeAreaInsets.left, y: bounds.height - 60 - safeAreaInsets.bottom)
    }
```

**Step 2: Update setupControlOverlays**

In `setupControlOverlays`, change the joystick base and knob initial alpha from `0` to `0.15` (lines 71, 79):

```swift
        joystickBase.alpha = 0.15
```

```swift
        joystickKnob.alpha = 0.15
```

**Step 3: Update updateControlOverlays**

Replace the joystick section of `updateControlOverlays` (lines 133-155):

```swift
        // Dynamic joystick
        if let origin = touchInput.joystickOriginPoint {
            joystickBase.alpha = 1
            joystickBase.center = origin
            joystickKnob.alpha = 1

            if let current = touchInput.joystickCurrentPoint {
                var dx = current.x - origin.x
                var dy = current.y - origin.y
                let dist = sqrt(dx * dx + dy * dy)
                let maxR: CGFloat = 40
                if dist > maxR {
                    dx = dx / dist * maxR
                    dy = dy / dist * maxR
                }
                joystickKnob.center = CGPoint(x: origin.x + dx, y: origin.y + dy)
            } else {
                joystickKnob.center = origin
            }
        } else {
            // Return to default position with dim opacity
            joystickBase.alpha = 0.15
            joystickBase.center = defaultJoystickCenter
            joystickKnob.alpha = 0.15
            joystickKnob.center = defaultJoystickCenter
        }
```

**Step 4: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Project2043-iOS/MetalView.swift
git commit -m "feat: show joystick at default position when idle"
```

---

### Task 7: Secondary Button Spacing

**Files:**
- Modify: `Project2043-iOS/MetalView.swift` (layoutSubviews, line 187)

**Step 1: Change arcRadius**

In `layoutSubviews`, change line 187:

```swift
        let arcRadius: CGFloat = 100
```

to:

```swift
        let arcRadius: CGFloat = 85
```

**Step 2: Build and verify**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Project2043-iOS/MetalView.swift
git commit -m "feat: reduce secondary button arc radius from 100pt to 85pt"
```

---

### Task 8: Game Over / Victory Screen + Restart

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift` (game state, overlays, restart)
- Modify: `Project2043-iOS/MetalView.swift` (restart handling)
- Modify: `Project2043-macOS/MetalView.swift` (restart handling)
- Test: `Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift`

**Step 1: Write the failing test**

Add to `Galaxy1SceneTests.swift`:

```swift
@Test @MainActor func sceneShouldRestartIsFalseInitially() {
    let scene = Galaxy1Scene()
    #expect(scene.shouldRestart == false)
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --filter sceneShouldRestartIsFalseInitially 2>&1 | tail -10`

Expected: FAIL — `shouldRestart` does not exist.

**Step 3: Add game over state tracking and shouldRestart**

In `Galaxy1Scene`, add after the `weaponNameTimer` property:

```swift
    public private(set) var shouldRestart = false
    private var gameOverTimer: Double = 0
    private static let restartDelay: Double = 1.5
```

**Step 4: Update fixedUpdate to handle game over timer and restart input**

In `fixedUpdate`, find the game over check (around line 296 where `gameState = .gameOver` is set). After the existing game over and victory transitions, add timing/restart logic. At the end of `fixedUpdate` (before the closing `}`), add:

```swift
        // Game over / victory restart timer
        if gameState != .playing {
            gameOverTimer += time.fixedDeltaTime
            if gameOverTimer > Self.restartDelay {
                if let input = inputProvider?.poll(), input.primaryFire {
                    shouldRestart = true
                }
            }
        }
```

**Step 5: Replace game over overlay with bitmap text**

Replace `appendGameOverOverlay` (lines 1412-1423):

```swift
    private func appendGameOverOverlay(to sprites: inout [SpriteInstance]) {
        // Dim overlay
        sprites.append(SpriteInstance(
            position: .zero,
            size: SIMD2(GameConfig.designWidth * 2, GameConfig.designHeight * 2),
            color: SIMD4(0, 0, 0, 0.6)
        ))
    }
```

Then update `collectEffectSprites` to render the game over text as effect sprites. In the `collectEffectSprites` method (around line 444), before `appendEffectHUD`, add:

```swift
        if gameState == .gameOver, let effectSheet {
            sprites.append(contentsOf: makeTextSprites(
                "GAME OVER",
                at: SIMD2(0, 30),
                color: SIMD4(0.9, 0.15, 0.15, 0.95),
                scale: 3.0,
                effectSheet: effectSheet
            ))
            let scoreText = String(format: "%08d", scoreSystem.currentScore)
            sprites.append(contentsOf: makeTextSprites(
                scoreText,
                at: SIMD2(0, -10),
                color: SIMD4(1, 1, 1, 0.8),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        if gameState == .victory, let effectSheet {
            sprites.append(contentsOf: makeTextSprites(
                "VICTORY",
                at: SIMD2(0, 30),
                color: SIMD4(GameConfig.Palette.player.x, GameConfig.Palette.player.y, GameConfig.Palette.player.z, 0.95),
                scale: 3.0,
                effectSheet: effectSheet
            ))
            let scoreText = String(format: "%08d", scoreSystem.currentScore)
            sprites.append(contentsOf: makeTextSprites(
                scoreText,
                at: SIMD2(0, -10),
                color: SIMD4(1, 1, 1, 0.8),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }
```

**Step 6: Replace victory overlay**

Replace `appendVictoryOverlay` (lines 1425-1431):

```swift
    private func appendVictoryOverlay(to sprites: inout [SpriteInstance]) {
        // Dim overlay (lighter than game over)
        sprites.append(SpriteInstance(
            position: .zero,
            size: SIMD2(GameConfig.designWidth * 2, GameConfig.designHeight * 2),
            color: SIMD4(0, 0, 0, 0.4)
        ))
    }
```

**Step 7: Handle restart in iOS MetalView**

In the iOS `MetalView`'s `render(_:)` method (line 209-218), after `engine.update(deltaTime: dt)` and before `updateControlOverlays()`, add:

```swift
        // Check for scene restart
        if scene.shouldRestart {
            scene = Galaxy1Scene()
            scene.inputProvider = touchInput
            let audio = AVAudioManager()
            scene.audioProvider = audio
            let sfxEngine = SynthAudioEngine()
            scene.sfx = sfxEngine
            engine.currentScene = scene
            // Reapply safe area insets
            let screenHeight = bounds.height
            if screenHeight > 0 {
                let gameUnitsPerPoint = GameConfig.designHeight / Float(screenHeight)
                scene.hudInsets = (
                    top: Float(safeAreaInsets.top) * gameUnitsPerPoint,
                    bottom: Float(safeAreaInsets.bottom) * gameUnitsPerPoint
                )
            }
        }
```

**Step 8: Handle restart in macOS MetalView**

In the macOS `MetalView.swift`:

1. Add a stored scene reference. Add after `private var lastTimestamp: CFTimeInterval = 0` (line 11):

```swift
    private var scene: Galaxy1Scene!
```

2. Store the scene in `setup()`. Change `let scene = Galaxy1Scene()` to `scene = Galaxy1Scene()`.

3. In `render(_:)` (line 71), after `engine.update(deltaTime: dt)`, add:

```swift
        // Check for scene restart
        if scene.shouldRestart {
            scene = Galaxy1Scene()
            scene.inputProvider = inputProvider
            let audio = AVAudioManager()
            scene.audioProvider = audio
            let sfxEngine = SynthAudioEngine()
            scene.sfx = sfxEngine
            engine.currentScene = scene
        }
```

**Step 9: Run all tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test 2>&1 | tail -20`

Expected: ALL PASS

**Step 10: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Project2043-iOS/MetalView.swift Project2043-macOS/MetalView.swift Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift
git commit -m "feat: game over and victory screens with bitmap text and restart"
```
