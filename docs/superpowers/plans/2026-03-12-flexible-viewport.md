# Flexible Viewport Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed 360x640 design space with a flexible viewport that adapts to screen aspect ratio, enabling landscape orientation on iOS and resizable windows on macOS.

**Architecture:** A new `ViewportManager` class owns the dynamic design width (height stays fixed at 640). It uses exponential decay to smoothly animate aspect ratio changes. All code that previously read `GameConfig.designWidth` now reads from ViewportManager instead.

**Tech Stack:** Swift 6.0, Metal, UIKit (iOS), AppKit (macOS), XCTest/Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-12-flexible-viewport-design.md`

---

## Chunk 1: ViewportManager Core + Renderer Integration

### Task 1: Create ViewportManager

**Files:**
- Create: `Engine2043/Sources/Engine2043/Core/ViewportManager.swift`
- Test: `Engine2043/Tests/Engine2043Tests/ViewportManagerTests.swift`

- [ ] **Step 1: Write failing tests for ViewportManager**

```swift
// Engine2043/Tests/Engine2043Tests/ViewportManagerTests.swift
import Testing
import simd
@testable import Engine2043

struct ViewportManagerTests {
    @Test @MainActor func defaultAspectRatioIsPortrait() {
        let vm = ViewportManager()
        #expect(vm.currentDesignWidth == 360)
        #expect(vm.designHeight == 640)
    }

    @Test @MainActor func settingTargetAspectRatioAndUpdating() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 16.0 / 9.0  // landscape
        // After enough updates, should converge
        for _ in 0..<60 {
            vm.update(dt: 1.0 / 60.0)
        }
        let expected: Float = 640 * (16.0 / 9.0)
        #expect(abs(vm.currentDesignWidth - expected) < 1.0)
    }

    @Test @MainActor func aspectRatioClampsToMinimum() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 0.1  // way below 9:16
        vm.update(dt: 1.0)
        #expect(vm.currentAspectRatio >= 9.0 / 16.0 - 0.001)
    }

    @Test @MainActor func aspectRatioClampsToMaximum() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 5.0  // way above 21:9
        vm.update(dt: 1.0)
        #expect(vm.currentAspectRatio <= 21.0 / 9.0 + 0.001)
    }

    @Test @MainActor func largeJumpSnapsInstantly() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 16.0 / 9.0  // delta > 0.5 from default 9/16
        vm.update(dt: 1.0 / 60.0)
        // Should snap, not animate
        let expected: Float = 16.0 / 9.0
        #expect(abs(vm.currentAspectRatio - expected) < 0.01)
    }

    @Test @MainActor func halfWidthAndHalfHeight() {
        let vm = ViewportManager()
        #expect(vm.halfWidth == 180)
        #expect(vm.halfHeight == 320)
    }

    @Test @MainActor func worldBoundsMatchesDimensions() {
        let vm = ViewportManager()
        let bounds = vm.worldBounds
        #expect(bounds.min.x == -180)
        #expect(bounds.max.x == 180)
        #expect(bounds.min.y == -320)
        #expect(bounds.max.y == 320)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter ViewportManagerTests 2>&1 | tail -20`
Expected: Compilation error — `ViewportManager` not defined

- [ ] **Step 3: Implement ViewportManager**

```swift
// Engine2043/Sources/Engine2043/Core/ViewportManager.swift
import simd

@MainActor
public final class ViewportManager {
    public let designHeight: Float = GameConfig.designHeight

    private static let minAspectRatio: Float = 9.0 / 16.0
    private static let maxAspectRatio: Float = 21.0 / 9.0
    private static let maxWidth: Float = GameConfig.designHeight * maxAspectRatio
    private static let chaseSpeed: Float = 12.0
    private static let snapThreshold: Float = 0.5

    public private(set) var currentAspectRatio: Float = 9.0 / 16.0

    public var targetAspectRatio: Float = 9.0 / 16.0 {
        didSet {
            targetAspectRatio = Self.clampAspect(targetAspectRatio)
        }
    }

    public var currentDesignWidth: Float {
        designHeight * currentAspectRatio
    }

    public var halfWidth: Float { currentDesignWidth / 2 }
    public var halfHeight: Float { designHeight / 2 }

    public var worldBounds: AABB {
        AABB(min: SIMD2(-halfWidth, -halfHeight),
             max: SIMD2(halfWidth, halfHeight))
    }

    /// Maximum possible design width (at 21:9). Used by BackgroundSystem
    /// to generate stars across the widest possible viewport.
    public static var maxDesignWidth: Float { maxWidth }

    public init() {}

    public func update(dt: Float) {
        guard currentAspectRatio != targetAspectRatio else { return }

        let delta = abs(targetAspectRatio - currentAspectRatio)
        if delta > Self.snapThreshold {
            currentAspectRatio = targetAspectRatio
            return
        }

        let t = 1 - exp(-dt * Self.chaseSpeed)
        currentAspectRatio += (targetAspectRatio - currentAspectRatio) * t

        // Snap when close enough
        if abs(currentAspectRatio - targetAspectRatio) / targetAspectRatio < 0.001 {
            currentAspectRatio = targetAspectRatio
        }
    }

    private static func clampAspect(_ ratio: Float) -> Float {
        max(minAspectRatio, min(maxAspectRatio, ratio))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter ViewportManagerTests 2>&1 | tail -20`
Expected: All 7 tests pass

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/ViewportManager.swift Engine2043/Tests/Engine2043Tests/ViewportManagerTests.swift
git commit -m "feat: add ViewportManager with animated aspect ratio transitions"
```

### Task 2: Wire ViewportManager into Renderer

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/Renderer.swift:18,87-97`

- [ ] **Step 1: Modify Renderer to accept ViewportManager**

In `Renderer.swift`, add a `viewportManager` property and update the projection:

```swift
// Add property after line 16 (public var transitionProgress)
public var viewportManager: ViewportManager?

// Replace makeOrthographicProjection() (lines 87-97) with:
private func makeOrthographicProjection() -> simd_float4x4 {
    let hw = (viewportManager?.halfWidth) ?? (GameConfig.designWidth / 2)
    let hh = GameConfig.designHeight / 2

    return simd_float4x4(
        SIMD4<Float>(1.0 / hw, 0, 0, 0),
        SIMD4<Float>(0, 1.0 / hh, 0, 0),
        SIMD4<Float>(0, 0, -1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}
```

- [ ] **Step 2: Run existing tests to verify no regressions**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All existing tests still pass (viewportManager defaults to nil, fallback to GameConfig.designWidth)

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/Renderer.swift
git commit -m "feat: renderer projection reads from ViewportManager"
```

### Task 3: Wire ViewportManager into iOS MetalView

**Files:**
- Modify: `Project2043-iOS/MetalView.swift:10,47-48,91-95,197-201,247-256,267-276`

- [ ] **Step 1: Add ViewportManager to MetalView**

Add a `viewportManager` property to `MetalView` and initialize it in `setup()`:

```swift
// Add after line 13 (private var sceneManager: SceneManager!)
private var viewportManager: ViewportManager!
```

In `setup()`, after creating the renderer (line 47), create and wire the viewport manager:

```swift
// After: let renderer = try! Renderer(device: device)
viewportManager = ViewportManager()
renderer.viewportManager = viewportManager
```

- [ ] **Step 2: Update layoutSubviews to set targetAspectRatio**

In `layoutSubviews()`, after updating `metalLayer.drawableSize`, add:

```swift
// After metalLayer.drawableSize = ...
if bounds.height > 0 {
    viewportManager.targetAspectRatio = Float(bounds.width / bounds.height)
}
```

- [ ] **Step 3: Update render loop to tick ViewportManager**

In `render(_:)`, after computing `dt`, add:

```swift
// After: let dt = lastTimestamp == 0 ? ...
viewportManager.update(dt: Float(dt))
```

- [ ] **Step 4: Commit**

Note: `updateHudInsets` will be updated to produce 4-field insets in Task 7, alongside the Galaxy1Scene `hudInsets` type change, to avoid a non-compiling intermediate state.

```bash
git add Project2043-iOS/MetalView.swift
git commit -m "feat: iOS MetalView drives ViewportManager from screen bounds"
```

### Task 4: Wire ViewportManager into macOS MetalView + AppDelegate

**Files:**
- Modify: `Project2043-macOS/MetalView.swift:9,35-36,91-99,101-106`
- Modify: `Project2043-macOS/AppDelegate.swift:7,13-18`

- [ ] **Step 1: Add ViewportManager to macOS MetalView**

```swift
// Add after line 11 (private var displayLink: CADisplayLink?)
private var viewportManager: ViewportManager!
```

In `setup()`, after creating the renderer (line 35):

```swift
// After: let renderer = try! Renderer(device: device)
viewportManager = ViewportManager()
renderer.viewportManager = viewportManager
```

- [ ] **Step 2: Update layout() to set targetAspectRatio**

In `layout()`, after updating `metalLayer.drawableSize`:

```swift
// After metalLayer.drawableSize = ...
if bounds.height > 0 {
    viewportManager.targetAspectRatio = Float(bounds.width / bounds.height)
}
```

- [ ] **Step 3: Update render loop to tick ViewportManager**

In `render(_:)`, after computing `dt`:

```swift
// After: let dt = lastTimestamp == 0 ? ...
viewportManager.update(dt: Float(dt))
```

- [ ] **Step 4: Add min/max window size constraints in AppDelegate**

```swift
// After window.title = "Project 2043" (line 19), add:
window.minSize = NSSize(width: 360, height: 640)
```

- [ ] **Step 5: Commit**

```bash
git add Project2043-macOS/MetalView.swift Project2043-macOS/AppDelegate.swift
git commit -m "feat: macOS MetalView drives ViewportManager, add min window size"
```

---

## Chunk 2: Input System Adaptation

### Task 5: Update TouchInputProvider for fixed-width zones and dynamic coordinates

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift:27,53,84-114`

- [ ] **Step 1: Add viewportManager property and touchZoneWidth**

```swift
// Replace line 27 (public var screenSize)
public var screenSize: CGSize = .zero
public weak var viewportManager: ViewportManager?
```

- [ ] **Step 2: Update coordinate conversion in touchesBegan**

Replace lines 91-93 (the coordinate conversion):

```swift
// Convert screen-space tap to game design coordinates
let designWidth = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
let gameX = (Float(loc.x) / Float(screenSize.width) - 0.5) * designWidth
let gameY = (0.5 - Float(loc.y) / Float(screenSize.height)) * GameConfig.designHeight
pendingTapPosition = SIMD2(gameX, gameY)
```

- [ ] **Step 3: Update zone detection in touchesBegan**

Replace lines 95-113 (the left/right half split):

```swift
let zoneWidth = min(180.0, screenSize.width / 2)
if loc.x < zoneWidth && joystickTouchID == nil {
    joystickOrigin = point
    joystickCurrent = point
    joystickTouchID = touchID
} else if loc.x > screenSize.width - zoneWidth {
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
```

- [ ] **Step 4: Wire viewportManager in iOS MetalView setup()**

In `Project2043-iOS/MetalView.swift`, after `touchInput = TouchInputProvider()`:

```swift
touchInput.viewportManager = viewportManager
```

- [ ] **Step 5: Run existing tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift Project2043-iOS/MetalView.swift
git commit -m "feat: touch input uses fixed-width zones and dynamic coordinate conversion"
```

### Task 6: Update KeyboardInputProvider for dynamic coordinates

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift:5,32-35`

- [ ] **Step 1: Add viewportManager property**

```swift
// Add after line 5 (public final class KeyboardInputProvider)
public weak var viewportManager: ViewportManager?
```

- [ ] **Step 2: Update mouseDown coordinate conversion**

Replace lines 33-34:

```swift
let designWidth = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
let gameX = (point.x / viewSize.x - 0.5) * designWidth
let gameY = (0.5 - point.y / viewSize.y) * GameConfig.designHeight
```

- [ ] **Step 3: Wire viewportManager in macOS MetalView setup()**

In `Project2043-macOS/MetalView.swift`, after `inputProvider = KeyboardInputProvider()`:

```swift
inputProvider.viewportManager = viewportManager
```

- [ ] **Step 4: Run existing tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift Project2043-macOS/MetalView.swift
git commit -m "feat: keyboard input uses dynamic coordinate conversion"
```

---

## Chunk 3: Scene Adaptation — Galaxy1Scene

### Task 7: Add viewportManager to Galaxy1Scene and update hudInsets type

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:29,56,81,86`
- Modify: `Project2043-iOS/MetalView.swift:247-256`

- [ ] **Step 1: Add viewportManager property**

After line 31 (`public var sfx: SynthAudioEngine?`), add:

```swift
public var viewportManager: ViewportManager?
```

- [ ] **Step 2: Change hudInsets to 4-field tuple**

Replace line 56:

```swift
public var hudInsets: (top: Float, bottom: Float, left: Float, right: Float) = (0, 0, 0, 0)
```

- [ ] **Step 3: Change worldBounds to computed property**

Replace line 81 (`private let worldBounds = AABB(...)`) with:

```swift
private var worldBounds: AABB {
    let hw = viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)
    let hh = GameConfig.designHeight / 2
    return AABB(min: SIMD2(-hw, -hh), max: SIMD2(hw, hh))
}
```

Update the `init()` to pass worldBounds lazily — change line 86 from:
```swift
collisionSystem = CollisionSystem(worldBounds: worldBounds)
```
to:
```swift
collisionSystem = CollisionSystem(worldBounds: AABB(min: SIMD2(-200, -340), max: SIMD2(200, 340)))
```

Note: The collision system gets the initial bounds. It will be updated each frame in `fixedUpdate` if `CollisionSystem` supports it, or we can pass bounds at collision check time. For now this is safe since it's used for spatial partitioning and culling happens separately.

- [ ] **Step 4: Update iOS MetalView `updateHudInsets` to produce 4-field tuple**

In `Project2043-iOS/MetalView.swift`, update `updateHudInsets(for:)` to output all four insets:

```swift
private func updateHudInsets(for scene: Galaxy1Scene) {
    let screenHeight = bounds.height
    let screenWidth = bounds.width
    if screenHeight > 0 && screenWidth > 0 {
        let vUnitsPerPt = GameConfig.designHeight / Float(screenHeight)
        let designWidth = scene.viewportManager?.currentDesignWidth ?? GameConfig.designWidth
        let hUnitsPerPt = designWidth / Float(screenWidth)
        scene.hudInsets = (
            top: Float(safeAreaInsets.top) * vUnitsPerPt,
            bottom: Float(safeAreaInsets.bottom) * vUnitsPerPt,
            left: Float(safeAreaInsets.left) * hUnitsPerPt,
            right: Float(safeAreaInsets.right) * hUnitsPerPt
        )
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Project2043-iOS/MetalView.swift
git commit -m "feat: Galaxy1Scene gets viewportManager, 4-field hudInsets, dynamic worldBounds"
```

### Task 8: Update Galaxy1Scene designWidth references

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:515,535,538,572,709,1274,1509-1510,1531,1540`

- [ ] **Step 1: Add a helper computed property**

Add near the top of the class (after the `worldBounds` computed property):

```swift
private var currentHalfWidth: Float {
    viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)
}
```

- [ ] **Step 2: Update EMP flash detection (line 515)**

```swift
// Before:
let isEmp = render.size.x >= GameConfig.designWidth * 0.9
// After:
let dw = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
let isEmp = render.size.x >= dw * 0.9
```

- [ ] **Step 3: Update HUD positioning (line 535)**

The HUD uses `designHeight` for topY (unchanged) but HUD element X positions need inset awareness:

```swift
// Before:
let topY: Float = GameConfig.designHeight / 2 - hudInsets.top - 10
// After (same — designHeight is fixed):
let topY: Float = GameConfig.designHeight / 2 - hudInsets.top - 10

// Update energyX to use left inset:
let energyX: Float = -currentHalfWidth + hudInsets.left + 80

// Update weaponIconX to use right inset:
let weaponIconX: Float = currentHalfWidth - hudInsets.right - 50
```

- [ ] **Step 4: Update player clamping (lines 709-712)**

```swift
// Before:
let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2
// After:
let halfW = currentHalfWidth - GameConfig.Player.size.x / 2
```

- [ ] **Step 5: Update EMP flash size (line 1274)**

```swift
// Before:
size: SIMD2(GameConfig.designWidth, GameConfig.designHeight),
// After:
let empWidth = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
size: SIMD2(empWidth, GameConfig.designHeight),
```

- [ ] **Step 6: Update culling (lines 1509-1510)**

```swift
// Before:
let minX = -GameConfig.designWidth / 2 - margin
let maxX = GameConfig.designWidth / 2 + margin
// After:
let minX = -currentHalfWidth - margin
let maxX = currentHalfWidth + margin
```

- [ ] **Step 7: Update screen-fill overlays (lines 1531, 1540)**

```swift
// Before (both lines):
size: SIMD2(GameConfig.designWidth * 2, GameConfig.designHeight * 2),
// After (both lines):
let overlayW = (viewportManager?.currentDesignWidth ?? GameConfig.designWidth) * 2
size: SIMD2(overlayW, GameConfig.designHeight * 2),
```

- [ ] **Step 8: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: Galaxy1Scene uses dynamic viewport width for all layout and culling"
```

---

## Chunk 4: Other Scenes, Factory Wiring + Systems

### Task 9: Update TitleScene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/TitleScene.swift:6,28-37,47-51`

- [ ] **Step 1: Add viewportManager property**

After line 6 (`public var inputProvider`):

```swift
public var viewportManager: ViewportManager?
```

- [ ] **Step 2: Update seedAttractEnemies (lines 28-37)**

```swift
private func seedAttractEnemies() {
    let hw = (viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)) - 40
    for i in 0..<5 {
        let x = -hw + Float(i) * (hw * 2 / 4)
        attractEnemies.append((
            pos: SIMD2(x, GameConfig.designHeight / 2 + 50),
            vel: SIMD2(0, -40)
        ))
    }
}
```

Note: `seedAttractEnemies()` is called from `init()` before `viewportManager` is set. Move the call to be lazy — call it on first `fixedUpdate` instead:

```swift
private var attractSeeded = false

public func fixedUpdate(time: GameTime) {
    if !attractSeeded {
        seedAttractEnemies()
        attractSeeded = true
    }
    // ... rest of fixedUpdate
}
```

Remove `seedAttractEnemies()` from `init()`.

- [ ] **Step 3: Update attract ship bounce bounds (lines 47-51)**

```swift
// Before:
let hw = GameConfig.designWidth / 2 - 20
let hh = GameConfig.designHeight / 2 - 20
// After:
let hw = (viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)) - 20
let hh = GameConfig.designHeight / 2 - 20
```

Also update enemy wrap bounds (line 56-58) to use same `hw` and `hh`.

- [ ] **Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/TitleScene.swift
git commit -m "feat: TitleScene uses dynamic viewport width for attract mode"
```

### Task 10: Update PlaceholderScene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/PlaceholderScene.swift:14,35-38,244-245,288-291`

- [ ] **Step 1: Add viewportManager property**

After `public var inputProvider`:

```swift
public var viewportManager: ViewportManager?
```

- [ ] **Step 2: Update worldBounds (lines 35-38)**

Change to a computed property or update at runtime. Simplest: keep hardcoded for collision init, add a helper:

```swift
private var currentHalfWidth: Float {
    viewportManager?.halfWidth ?? (GameConfig.designWidth / 2)
}
```

- [ ] **Step 3: Update player clamping (lines 244-245)**

```swift
let halfW = currentHalfWidth - playerSize.x / 2
```

- [ ] **Step 4: Update culling (lines 288-291)**

Add X culling using `currentHalfWidth`:

```swift
let margin: Float = 50
let minY = -GameConfig.designHeight / 2 - margin
let maxY = GameConfig.designHeight / 2 + margin
let minX = -currentHalfWidth - margin
let maxX = currentHalfWidth + margin

for entity in (enemies + projectiles) {
    guard let transform = entity.component(ofType: TransformComponent.self) else { continue }
    if transform.position.y < minY || transform.position.y > maxY ||
       transform.position.x < minX || transform.position.x > maxX {
        pendingRemovals.append(entity)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/PlaceholderScene.swift
git commit -m "feat: PlaceholderScene uses dynamic viewport width"
```

### Task 11: Update GameOverScene and VictoryScene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/GameOverScene.swift:6`
- Modify: `Engine2043/Sources/Engine2043/Scene/VictoryScene.swift:6`

- [ ] **Step 1: Add viewportManager property to both scenes**

In both files, after `public var inputProvider`:

```swift
public var viewportManager: ViewportManager?
```

These scenes don't reference `designWidth` directly — they only use `BackgroundSystem` which will be updated separately (Task 14).

- [ ] **Step 2: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/GameOverScene.swift Engine2043/Sources/Engine2043/Scene/VictoryScene.swift
git commit -m "feat: GameOverScene and VictoryScene get viewportManager property"
```

### Task 12: Wire viewportManager in SceneManager factory closures

**Files:**
- Modify: `Project2043-iOS/MetalView.swift:57-84`
- Modify: `Project2043-macOS/MetalView.swift:45-72`

- [ ] **Step 1: Update iOS MetalView factory closures**

In each factory closure, after setting `inputProvider`, add `scene.viewportManager = self?.viewportManager`:

```swift
sceneManager.makeTitleScene = { [weak self] in
    let scene = TitleScene()
    scene.inputProvider = self?.touchInput
    scene.viewportManager = self?.viewportManager
    return scene
}

sceneManager.makeGameScene = { [weak self] in
    let scene = Galaxy1Scene()
    scene.inputProvider = self?.touchInput
    scene.viewportManager = self?.viewportManager
    scene.audioProvider = audio
    scene.sfx = sfxEngine
    audio.stopAll()
    sfxEngine.stopLaser()
    sfxEngine.stopMusic()
    return scene
}

sceneManager.makeGameOverScene = { [weak self] result in
    let scene = GameOverScene(result: result)
    scene.inputProvider = self?.touchInput
    scene.viewportManager = self?.viewportManager
    return scene
}

sceneManager.makeVictoryScene = { [weak self] result in
    let scene = VictoryScene(result: result)
    scene.inputProvider = self?.touchInput
    scene.viewportManager = self?.viewportManager
    return scene
}

// Also update the initial title scene:
let titleScene = TitleScene()
titleScene.inputProvider = touchInput
titleScene.viewportManager = viewportManager
engine.currentScene = titleScene
```

- [ ] **Step 2: Update macOS MetalView factory closures (same pattern)**

Same changes as iOS — add `scene.viewportManager = self?.viewportManager` in each closure and the initial title scene.

- [ ] **Step 3: Commit**

```bash
git add Project2043-iOS/MetalView.swift Project2043-macOS/MetalView.swift
git commit -m "feat: wire viewportManager into all scene factory closures"
```

### Task 13: Update SteeringSystem and ItemSystem

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/SteeringSystem.swift:24-26,53-55`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift:10,12-13,48-51`

- [ ] **Step 1: Update SteeringSystem to accept halfWidth parameter**

Change `update(deltaTime:)` to `update(deltaTime:viewportHalfWidth:)`:

```swift
public func update(deltaTime: Double, viewportHalfWidth: Float = GameConfig.designWidth / 2) {
    accumulatedTime += deltaTime
    let halfWidth = viewportHalfWidth

    // ... rest unchanged
}
```

- [ ] **Step 2: Update ItemSystem to accept halfWidth parameter**

Remove the stored `halfWidth` property. Change `update(deltaTime:)` to `update(deltaTime:viewportHalfWidth:)`:

```swift
public init() {}  // Remove halfWidth = ... from init

public func update(deltaTime: Double, viewportHalfWidth: Float = GameConfig.designWidth / 2) {
    pendingDespawns.removeAll(keepingCapacity: true)
    let halfWidth = viewportHalfWidth

    // ... rest unchanged
}
```

- [ ] **Step 3: Update callers in Galaxy1Scene**

Find where `steeringSystem.update(deltaTime:)` and `itemSystem.update(deltaTime:)` are called and pass `currentHalfWidth`:

```swift
steeringSystem.update(deltaTime: time.fixedDeltaTime, viewportHalfWidth: currentHalfWidth)
itemSystem.update(deltaTime: time.fixedDeltaTime, viewportHalfWidth: currentHalfWidth)
```

- [ ] **Step 4: Update tests**

Existing tests still pass with default parameter values. Add new tests to verify custom halfWidth works:

In `ItemSystemTests.swift`:

```swift
@Test @MainActor func itemSystemBouncesAtCustomWidth() {
    let system = ItemSystem()
    let customHalfWidth: Float = 500

    let entity = GKEntity()
    let transform = TransformComponent(position: SIMD2(customHalfWidth - 5, 200))
    entity.addComponent(transform)
    entity.addComponent(PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [.playerProjectile, .player]))
    let item = ItemComponent()
    item.bounceDirection = 1
    entity.addComponent(item)
    entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: SIMD4(1, 1, 0, 1)))

    system.register(entity)
    system.update(deltaTime: 1.0 / 60.0, viewportHalfWidth: customHalfWidth)

    #expect(item.bounceDirection == Float(-1))
}
```

In `SteeringSystemTests.swift`:

```swift
@Test @MainActor func steeringSystemStrafeBoundsAtCustomWidth() {
    let system = SteeringSystem()
    let customHalfWidth: Float = 500

    let entity = GKEntity()
    let transform = TransformComponent(position: SIMD2(customHalfWidth - 25, 100))
    entity.addComponent(transform)
    let physics = PhysicsComponent(collisionSize: SIMD2(32, 32), layer: .enemy, mask: [])
    entity.addComponent(physics)
    let steering = SteeringComponent(behavior: .strafe)
    steering.hasReachedHover = true
    steering.strafeDirection = 1
    entity.addComponent(steering)

    system.register(entity)
    system.playerPosition = SIMD2(0, -250)
    system.update(deltaTime: 1.0 / 60.0, viewportHalfWidth: customHalfWidth)

    // At x=475, past halfWidth-30=470, direction should flip to -1
    #expect(steering.strafeDirection == Float(-1))
}
```

- [ ] **Step 5: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/SteeringSystem.swift Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Engine2043/Tests/Engine2043Tests/ItemSystemTests.swift Engine2043/Tests/Engine2043Tests/SteeringSystemTests.swift
git commit -m "feat: SteeringSystem and ItemSystem accept dynamic viewport width"
```

### Task 14: Update BackgroundSystem to generate at max width

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift:18-42`

- [ ] **Step 1: Update init to use max width**

```swift
public init() {
    let maxWidth = ViewportManager.maxDesignWidth
    halfWidth = maxWidth / 2
    halfHeight = GameConfig.designHeight / 2
    fieldHeight = GameConfig.designHeight + 100

    var seed: UInt64 = 42
    for _ in 0..<GameConfig.Background.starCount {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let x = Float(Int(seed >> 33) % Int(maxWidth)) - halfWidth
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let y = Float(Int(seed >> 33) % Int(fieldHeight)) - halfHeight
        starPositions.append(SIMD2(x, y))
        let s: Float = Float(2 + Int(seed >> 60) % 2)
        starSizes.append(SIMD2(s, s))
    }

    for _ in 0..<GameConfig.Background.nebulaCount {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let x = Float(Int(seed >> 33) % Int(maxWidth)) - halfWidth
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let y = Float(Int(seed >> 33) % Int(fieldHeight)) - halfHeight
        nebulaPositions.append(SIMD2(x, y))
        let s = Float(8 + Int(seed >> 60) % 9)
        nebulaSizes.append(SIMD2(s, s))
    }
}
```

- [ ] **Step 2: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift
git commit -m "feat: BackgroundSystem generates stars across maximum viewport width"
```

---

## Chunk 5: Platform Configuration

### Task 15: Add iOS orientation support in project.yml

**Files:**
- Modify: `project.yml:47`

- [ ] **Step 1: Add orientation keys**

After `INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES`, add:

```yaml
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortraitUpsideDown"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortraitUpsideDown"
```

- [ ] **Step 2: Regenerate Xcode project**

Run: `xcodegen generate 2>&1`
Expected: "Created project at .../Project2043.xcodeproj"

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -project Project2043.xcodeproj -scheme Project2043-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add project.yml Project2043.xcodeproj
git commit -m "feat: enable all iOS orientations in project.yml"
```

### Task 16: Final integration build and test

**Files:** None (verification only)

- [ ] **Step 1: Run all engine tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 2: Build iOS**

Run: `xcodebuild build -project Project2043.xcodeproj -scheme Project2043-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 3: Build macOS**

Run: `xcodebuild build -project Project2043.xcodeproj -scheme Project2043-macOS -quiet 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 4: Commit any remaining fixes if needed**
