# Galaxy Select Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a galaxy select screen so players can start on any of the 3 galaxies, accessed from the title screen.

**Architecture:** New `GalaxySelectScene` inserted between TitleScene and galaxy scenes, with a `ProgressStore` for tracking cleared galaxies. Input system extended with `menuUp`/`menuDown`/`menuBack` fields. Galaxy2/Galaxy3 scenes updated to accept optional carryover for fresh-start support.

**Tech Stack:** Swift 6, Swift Testing, GameplayKit, Metal (rendering via BitmapText)

---

### Task 1: Extend BitmapText Glyph Set

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift:24`
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift:1224`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`

The galaxy select screen needs `'` (apostrophe in KAY'SHARA), `*` (cleared indicator), and `>` (selection cursor). None are in the current glyph set. Space is in the set but never rendered (BitmapText skips it), so we remove it to stay within the 256px texture row (42 × 6px = 252px ≤ 256px).

- [ ] **Step 1: Write failing test for new glyphs**

```swift
// In SpriteFactoryTests.swift, add after existing glyph tests:

@Test func makeBitmapGlyphApostropheProducesContent() {
    let (pixels, w, h) = SpriteFactory.makeBitmapGlyph("'")
    #expect(w == 6)
    #expect(h == 8)
    let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasContent)
}

@Test func makeBitmapGlyphAsteriskProducesContent() {
    let (pixels, w, h) = SpriteFactory.makeBitmapGlyph("*")
    #expect(w == 6)
    #expect(h == 8)
    let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasContent)
}

@Test func makeBitmapGlyphGreaterThanProducesContent() {
    let (pixels, w, h) = SpriteFactory.makeBitmapGlyph(">")
    #expect(w == 6)
    #expect(h == 8)
    let hasContent = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 }
    #expect(hasContent)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "SpriteFactoryTests/makeBitmapGlyphApostrophe|SpriteFactoryTests/makeBitmapGlyphAsterisk|SpriteFactoryTests/makeBitmapGlyphGreaterThan" 2>&1`
Expected: FAIL — glyphs produce no visible pixels (no pattern defined, fallback is all zeros).

- [ ] **Step 3: Add glyph patterns to SpriteFactory**

In `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`, add three entries to the `glyphPatterns` dictionary (inside the existing dictionary literal, after the last entry):

```swift
        "'": [0x04, 0x04, 0x08, 0x00, 0x00, 0x00, 0x00],
        "*": [0x00, 0x04, 0x15, 0x0E, 0x15, 0x04, 0x00],
        ">": [0x00, 0x10, 0x08, 0x04, 0x08, 0x10, 0x00],
```

- [ ] **Step 4: Update glyphChars in EffectTextureSheet**

In `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift`, change line 24 from:

```swift
    static let glyphChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.: ")
```

to:

```swift
    static let glyphChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.:'*>")
```

This removes the trailing space (never rendered by BitmapText — it skips spaces and just advances the cursor) and adds `'`, `*`, `>`. Total: 42 chars × 6px = 252px, fits in the 256px texture row.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SpriteFactoryTests 2>&1`
Expected: All glyph tests PASS, including the 3 new ones.

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift
git commit -m "$(cat <<'EOF'
feat: add apostrophe, asterisk, and chevron glyphs to BitmapText

Galaxy select screen needs ' (KAY'SHARA), * (cleared indicator),
and > (selection cursor). Remove unused space glyph to stay within
the 256px texture row limit.
EOF
)"
```

---

### Task 2: ProgressStore

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/ProgressStore.swift`
- Create: `Engine2043/Tests/Engine2043Tests/ProgressStoreTests.swift`

A `UserDefaults`-backed store for tracking which galaxies have been cleared. Uses keys `"galaxy1Cleared"`, `"galaxy2Cleared"`, `"galaxy3Cleared"` (all `Bool`, default `false`).

- [ ] **Step 1: Write failing tests**

Create `Engine2043/Tests/Engine2043Tests/ProgressStoreTests.swift`:

```swift
import Testing
@testable import Engine2043

struct ProgressStoreTests {
    private func freshDefaults() -> UserDefaults {
        let suiteName = "ProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func isClearedDefaultsToFalse() {
        let defaults = freshDefaults()
        #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 2, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 3, store: defaults) == false)
    }

    @Test func markClearedPersists() {
        let defaults = freshDefaults()
        ProgressStore.markCleared(galaxy: 2, store: defaults)
        #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 2, store: defaults) == true)
        #expect(ProgressStore.isCleared(galaxy: 3, store: defaults) == false)
    }

    @Test func markClearedAllThreeGalaxies() {
        let defaults = freshDefaults()
        ProgressStore.markCleared(galaxy: 1, store: defaults)
        ProgressStore.markCleared(galaxy: 2, store: defaults)
        ProgressStore.markCleared(galaxy: 3, store: defaults)
        #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == true)
        #expect(ProgressStore.isCleared(galaxy: 2, store: defaults) == true)
        #expect(ProgressStore.isCleared(galaxy: 3, store: defaults) == true)
    }

    @Test func invalidGalaxyNumberReturnsFalse() {
        let defaults = freshDefaults()
        #expect(ProgressStore.isCleared(galaxy: 0, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 4, store: defaults) == false)
    }

    @Test func convenienceMethodsUseStandardDefaults() {
        // Verify the public API compiles and runs without crash
        _ = ProgressStore.isCleared(galaxy: 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter ProgressStoreTests 2>&1`
Expected: Compilation error — `ProgressStore` does not exist.

- [ ] **Step 3: Implement ProgressStore**

Create `Engine2043/Sources/Engine2043/Scene/ProgressStore.swift`:

```swift
import Foundation

public enum ProgressStore {
    private static func key(for galaxy: Int) -> String? {
        switch galaxy {
        case 1: return "galaxy1Cleared"
        case 2: return "galaxy2Cleared"
        case 3: return "galaxy3Cleared"
        default: return nil
        }
    }

    public static func markCleared(galaxy: Int, store: UserDefaults = .standard) {
        guard let key = key(for: galaxy) else { return }
        store.set(true, forKey: key)
    }

    public static func isCleared(galaxy: Int, store: UserDefaults = .standard) -> Bool {
        guard let key = key(for: galaxy) else { return false }
        return store.bool(forKey: key)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter ProgressStoreTests 2>&1`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/ProgressStore.swift Engine2043/Tests/Engine2043Tests/ProgressStoreTests.swift
git commit -m "$(cat <<'EOF'
feat: add ProgressStore for tracking cleared galaxies

UserDefaults-backed store with markCleared/isCleared API.
Accepts injectable UserDefaults for testability.
EOF
)"
```

---

### Task 3: PlayerInput Menu Fields

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/InputManager.swift:3-13`
- Modify: `Engine2043/Tests/Engine2043Tests/Helpers/TestHelpers.swift:9-33`
- Test: `Engine2043/Tests/Engine2043Tests/InputTests.swift`

Add `menuUp`, `menuDown`, `menuBack` fields to `PlayerInput` so menu navigation is explicit and separate from gameplay movement. Update `MockInputProvider` to support the new fields.

- [ ] **Step 1: Write failing test for new fields**

Add to `Engine2043/Tests/Engine2043Tests/InputTests.swift`:

```swift
@Test func playerInputMenuFieldsDefaultToFalse() {
    let input = PlayerInput()
    #expect(input.menuUp == false)
    #expect(input.menuDown == false)
    #expect(input.menuBack == false)
}

@Test @MainActor func mockInputProviderMenuFields() {
    let provider = MockInputProvider()
    provider.menuUp = true
    provider.menuDown = false
    provider.menuBack = true
    let input = provider.poll()
    #expect(input.menuUp == true)
    #expect(input.menuDown == false)
    #expect(input.menuBack == true)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "InputTests/playerInputMenuFieldsDefault|InputTests/mockInputProviderMenuFields" 2>&1`
Expected: Compilation error — `menuUp`, `menuDown`, `menuBack` do not exist.

- [ ] **Step 3: Add fields to PlayerInput**

In `Engine2043/Sources/Engine2043/Input/InputManager.swift`, add three fields after the `tapPosition` field:

```swift
    public var menuUp: Bool = false
    public var menuDown: Bool = false
    public var menuBack: Bool = false
```

The full struct becomes:

```swift
public struct PlayerInput: Sendable {
    public var movement: SIMD2<Float> = .zero
    public var primaryFire: Bool = false
    public var secondaryFire1: Bool = false  // Z — Grav-Bomb
    public var secondaryFire2: Bool = false  // X — EMP Sweep
    public var secondaryFire3: Bool = false  // C — Overcharge Protocol
    /// Screen-space tap/click position in game design coordinates, set on first frame of tap
    public var tapPosition: SIMD2<Float>?
    public var menuUp: Bool = false
    public var menuDown: Bool = false
    public var menuBack: Bool = false

    public init() {}
}
```

- [ ] **Step 4: Update MockInputProvider**

In `Engine2043/Tests/Engine2043Tests/Helpers/TestHelpers.swift`, add fields and update `poll()` in `MockInputProvider`:

```swift
@MainActor
final class MockInputProvider: InputProvider {
    var movement: SIMD2<Float>
    var primary: Bool
    var secondary1: Bool = false
    var secondary2: Bool = false
    var secondary3: Bool = false
    var tapPos: SIMD2<Float>?
    var menuUp: Bool = false
    var menuDown: Bool = false
    var menuBack: Bool = false

    init(movement: SIMD2<Float> = .zero, primary: Bool = false) {
        self.movement = movement
        self.primary = primary
    }

    func poll() -> PlayerInput {
        var input = PlayerInput()
        input.movement = movement
        input.primaryFire = primary
        input.secondaryFire1 = secondary1
        input.secondaryFire2 = secondary2
        input.secondaryFire3 = secondary3
        input.tapPosition = tapPos
        input.menuUp = menuUp
        input.menuDown = menuDown
        input.menuBack = menuBack
        tapPos = nil
        return input
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter InputTests 2>&1`
Expected: All tests PASS including the 2 new ones.

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/InputManager.swift Engine2043/Tests/Engine2043Tests/Helpers/TestHelpers.swift Engine2043/Tests/Engine2043Tests/InputTests.swift
git commit -m "$(cat <<'EOF'
feat: add menuUp, menuDown, menuBack fields to PlayerInput

Separate menu navigation from gameplay movement so menu scenes
can use explicit discrete inputs.
EOF
)"
```

---

### Task 4: KeyboardInputProvider Menu Inputs

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift:9-18` (KeyCode enum)
- Modify: `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift:41-62` (poll method)
- Test: `Engine2043/Tests/Engine2043Tests/InputTests.swift`

Map arrow up/down to `menuUp`/`menuDown` and ESC to `menuBack`. These coexist with gameplay movement — game scenes ignore menu fields and menu scenes ignore movement.

- [ ] **Step 1: Write failing tests**

Add to `Engine2043/Tests/Engine2043Tests/InputTests.swift`:

```swift
#if os(macOS)
@Test @MainActor func keyboardProviderMapsArrowsToMenuUpDown() {
    let provider = KeyboardInputProvider()
    provider.keyDown(126) // up arrow
    let input = provider.poll()
    #expect(input.menuUp == true)
    #expect(input.menuDown == false)
}

@Test @MainActor func keyboardProviderMapsEscapeToMenuBack() {
    let provider = KeyboardInputProvider()
    provider.keyDown(53) // escape
    let input = provider.poll()
    #expect(input.menuBack == true)
}

@Test @MainActor func keyboardProviderMenuBackFalseWhenEscNotPressed() {
    let provider = KeyboardInputProvider()
    provider.keyDown(49) // space
    let input = provider.poll()
    #expect(input.menuBack == false)
}
#endif
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "InputTests/keyboardProvider" 2>&1`
Expected: FAIL — `menuUp`, `menuDown`, `menuBack` all default to false regardless of keys pressed.

- [ ] **Step 3: Add ESC key code and menu mappings**

In `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift`, add the escape key code to the `KeyCode` enum:

```swift
        static let escape:     UInt16 = 53
```

Then in the `poll()` method, add menu mappings before the `return input` line:

```swift
        input.menuUp = keysPressed.contains(KeyCode.upArrow)
        input.menuDown = keysPressed.contains(KeyCode.downArrow)
        input.menuBack = keysPressed.contains(KeyCode.escape)
```

The full `poll()` method becomes:

```swift
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
        input.tapPosition = pendingClickPosition
        pendingClickPosition = nil

        input.menuUp = keysPressed.contains(KeyCode.upArrow)
        input.menuDown = keysPressed.contains(KeyCode.downArrow)
        input.menuBack = keysPressed.contains(KeyCode.escape)

        return input
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter InputTests 2>&1`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift Engine2043/Tests/Engine2043Tests/InputTests.swift
git commit -m "$(cat <<'EOF'
feat: map arrow keys to menuUp/menuDown and ESC to menuBack

Keyboard input now produces both movement and menu signals.
Game scenes ignore menu fields; menu scenes ignore movement.
EOF
)"
```

---

### Task 5: TouchInputProvider Swipe Detection

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift`
- Test: `Engine2043/Tests/Engine2043Tests/InputTests.swift`

Add vertical swipe detection (>30pt delta) that produces discrete `menuUp`/`menuDown` events. Swipe tracking coexists with joystick — the scene decides which to use. The iOS MetalView already hides control overlays on non-game scenes (line 366), so no joystick visual appears on menu screens.

- [ ] **Step 1: Write failing tests**

Add to `Engine2043/Tests/Engine2043Tests/InputTests.swift`:

```swift
#if os(iOS)
import UIKit

@Test @MainActor func touchProviderSwipeDownProducesMenuDown() {
    let provider = TouchInputProvider()
    provider.screenSize = CGSize(width: 390, height: 844)

    // Simulate touch at center, then move 35pt down (UIKit Y increases downward)
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let touch = FakeTouch(location: CGPoint(x: 195, y: 400))
    provider.touchesBegan([touch], in: view)

    touch.updateLocation(CGPoint(x: 195, y: 435)) // 35pt down
    provider.touchesMoved([touch], in: view)

    let input = provider.poll()
    #expect(input.menuDown == true)
    #expect(input.menuUp == false)
}

@Test @MainActor func touchProviderSwipeUpProducesMenuUp() {
    let provider = TouchInputProvider()
    provider.screenSize = CGSize(width: 390, height: 844)

    let view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let touch = FakeTouch(location: CGPoint(x: 195, y: 400))
    provider.touchesBegan([touch], in: view)

    touch.updateLocation(CGPoint(x: 195, y: 365)) // 35pt up
    provider.touchesMoved([touch], in: view)

    let input = provider.poll()
    #expect(input.menuUp == true)
    #expect(input.menuDown == false)
}

@Test @MainActor func touchProviderSmallMovementNoMenuEvent() {
    let provider = TouchInputProvider()
    provider.screenSize = CGSize(width: 390, height: 844)

    let view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let touch = FakeTouch(location: CGPoint(x: 195, y: 400))
    provider.touchesBegan([touch], in: view)

    touch.updateLocation(CGPoint(x: 195, y: 420)) // only 20pt
    provider.touchesMoved([touch], in: view)

    let input = provider.poll()
    #expect(input.menuUp == false)
    #expect(input.menuDown == false)
}

@Test @MainActor func touchProviderMenuEventsConsumedAfterPoll() {
    let provider = TouchInputProvider()
    provider.screenSize = CGSize(width: 390, height: 844)

    let view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let touch = FakeTouch(location: CGPoint(x: 195, y: 400))
    provider.touchesBegan([touch], in: view)
    touch.updateLocation(CGPoint(x: 195, y: 435))
    provider.touchesMoved([touch], in: view)

    _ = provider.poll() // consume the event
    let second = provider.poll()
    #expect(second.menuDown == false)
}
#endif
```

Note: `FakeTouch` is needed because `UITouch` cannot be directly instantiated in tests. Add this test helper inside the `#if os(iOS)` block in `InputTests.swift`:

```swift
#if os(iOS)
private class FakeTouch: UITouch {
    private var _location: CGPoint
    private let _id = UUID()

    init(location: CGPoint) {
        _location = location
        super.init()
    }

    func updateLocation(_ point: CGPoint) {
        _location = point
    }

    override func location(in view: UIView?) -> CGPoint { _location }
    override var phase: UITouch.Phase { .moved }
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FakeTouch else { return false }
        return _id == other._id
    }
    override var hash: Int { _id.hashValue }
}
#endif
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "InputTests/touchProviderSwipe|InputTests/touchProviderSmallMovement|InputTests/touchProviderMenuEvents" 2>&1`
Expected: FAIL — `menuUp`/`menuDown` always false in poll output.

- [ ] **Step 3: Add swipe tracking to TouchInputProvider**

In `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift`, add swipe tracking state after the existing button state fields:

```swift
    // Swipe detection for menu navigation
    private var swipeOriginY: Float?
    private var swipeTouchID: ObjectIdentifier?
    private var pendingMenuUp: Bool = false
    private var pendingMenuDown: Bool = false
    private let swipeThreshold: Float = 30
```

In `poll()`, add before `return input`:

```swift
        input.menuUp = pendingMenuUp
        input.menuDown = pendingMenuDown
        pendingMenuUp = false
        pendingMenuDown = false
```

In `touchesBegan(_:in:)`, add swipe origin tracking after the `pendingTapPosition` assignment:

```swift
            // Track swipe origin for menu navigation
            if swipeTouchID == nil {
                swipeOriginY = Float(loc.y)
                swipeTouchID = touchID
            }
```

In `touchesMoved(_:in:)`, add swipe detection after the existing joystick tracking:

```swift
            // Swipe detection
            if touchID == swipeTouchID, let originY = swipeOriginY {
                let currentY = Float(touch.location(in: view).y)
                let delta = currentY - originY
                if delta > swipeThreshold {
                    pendingMenuDown = true
                    swipeOriginY = currentY
                } else if delta < -swipeThreshold {
                    pendingMenuUp = true
                    swipeOriginY = currentY
                }
            }
```

In `cancelTouches(_:)`, add cleanup:

```swift
            if touchID == swipeTouchID {
                swipeOriginY = nil
                swipeTouchID = nil
            }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter InputTests 2>&1`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift Engine2043/Tests/Engine2043Tests/InputTests.swift
git commit -m "$(cat <<'EOF'
feat: add swipe-to-menuUp/menuDown detection in TouchInputProvider

Vertical swipes >30pt produce discrete menu navigation events.
Coexists with joystick tracking — scenes use whichever they need.
EOF
)"
```

---

### Task 6: SceneTransition and SceneManager Updates

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneTransition.swift:1-8`
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneManager.swift:4-91`
- Modify: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift`

Add `.toGalaxySelect` case, change `.toGalaxy2`/`.toGalaxy3` to accept optional `PlayerCarryover?`, and add a `makeGalaxySelectScene` factory to `SceneManager`.

- [ ] **Step 1: Update SceneTransition enum**

Replace the full contents of `Engine2043/Sources/Engine2043/Scene/SceneTransition.swift`:

```swift
public enum SceneTransition: Sendable {
    case toGame
    case toTitle
    case toGalaxySelect
    case toGameOver(GameResult)
    case toVictory(GameResult)
    case toGalaxy2(PlayerCarryover?)
    case toGalaxy3(PlayerCarryover?)
}
```

- [ ] **Step 2: Update SceneManager**

In `Engine2043/Sources/Engine2043/Scene/SceneManager.swift`, add the new factory property after line 13 (`makeGalaxy3Scene`):

```swift
    public var makeGalaxySelectScene: (() -> any GameScene)?
```

Update `performSceneSwitch()` to handle the new case and optional carryover. Replace the entire method:

```swift
    private func performSceneSwitch() {
        guard let transition = pendingTransition else { return }
        let scene: (any GameScene)?
        switch transition {
        case .toTitle:
            scene = makeTitleScene?()
        case .toGame:
            scene = makeGameScene?()
        case .toGalaxySelect:
            scene = makeGalaxySelectScene?()
        case .toGameOver(let result):
            scene = makeGameOverScene?(result)
        case .toVictory(let result):
            scene = makeVictoryScene?(result)
        case .toGalaxy2(let carryover):
            scene = makeGalaxy2Scene?(carryover)
        case .toGalaxy3(let carryover):
            scene = makeGalaxy3Scene?(carryover)
        }
        if let scene {
            engine.currentScene = scene
        }
    }
```

Update the factory type signatures for Galaxy2/Galaxy3 to accept optional:

```swift
    public var makeGalaxy2Scene: ((PlayerCarryover?) -> any GameScene)?
    public var makeGalaxy3Scene: ((PlayerCarryover?) -> any GameScene)?
```

- [ ] **Step 3: Fix SceneTransitionTests**

In `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`, update the tests that construct `.toGalaxy2`/`.toGalaxy3` transitions — they still pass non-nil carryover so only the enum count changes. Update `allSceneTransitionCasesCanBeConstructed`:

```swift
    @Test func allSceneTransitionCasesCanBeConstructed() {
        let result = GameResult(finalScore: 100, enemiesDestroyed: 5, elapsedTime: 30.0, didWin: false)
        let carryover = PlayerCarryover(
            weaponType: .doubleCannon, score: 0, secondaryCharges: 0,
            shieldDroneCount: 0, enemiesDestroyed: 0, elapsedTime: 0
        )

        // Verify every case can be constructed without error
        let transitions: [SceneTransition] = [
            .toGame,
            .toTitle,
            .toGalaxySelect,
            .toGameOver(result),
            .toVictory(result),
            .toGalaxy2(carryover),
            .toGalaxy3(carryover),
        ]
        #expect(transitions.count == 7, "All 7 transition cases should exist")
    }
```

Add a test for the new `.toGalaxySelect` case and for nil carryover:

```swift
    @Test func toGalaxySelectTransitionExists() {
        let transition = SceneTransition.toGalaxySelect
        if case .toGalaxySelect = transition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toGalaxySelect case")
        }
    }

    @Test func toGalaxy2AcceptsNilCarryover() {
        let transition = SceneTransition.toGalaxy2(nil)
        if case .toGalaxy2(let carryover) = transition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2 case")
        }
    }

    @Test func toGalaxy3AcceptsNilCarryover() {
        let transition = SceneTransition.toGalaxy3(nil)
        if case .toGalaxy3(let carryover) = transition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy3 case")
        }
    }
```

- [ ] **Step 4: Fix SceneManagerTests**

In `Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift`, update the factory signatures in the test methods that set `makeGalaxy2Scene` and `makeGalaxy3Scene`. The closures now receive `PlayerCarryover?`:

For `galaxy3TransitionCallsFactory` (around line 140):

```swift
        manager.makeGalaxy3Scene = { carryover in
            galaxy3FactoryCalled = true
            receivedCarryover = carryover
            return galaxy3Scene
        }
```

`receivedCarryover` should be declared as `PlayerCarryover?` (unchanged — it already is optional due to `var receivedCarryover: PlayerCarryover?`).

For `galaxy2TransitionCallsFactory` (around line 218):

```swift
        manager.makeGalaxy2Scene = { carryover in
            receivedCarryover = carryover
            return galaxy2Scene
        }
```

Same — the closure parameter type changes from `PlayerCarryover` to `PlayerCarryover?` but the body is the same.

Add a test for the galaxy select factory:

```swift
    @Test @MainActor func galaxySelectTransitionCallsFactory() {
        let (manager, engine) = makeManager()

        var galaxySelectFactoryCalled = false
        let galaxySelectScene = StubScene()
        manager.makeGalaxySelectScene = {
            galaxySelectFactoryCalled = true
            return galaxySelectScene
        }

        let scene = StubScene()
        scene.requestedTransition = .toGalaxySelect
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)

        #expect(galaxySelectFactoryCalled)
        #expect(engine.currentScene as AnyObject === galaxySelectScene)
    }
```

- [ ] **Step 5: Run tests to verify everything compiles and passes**

Run: `cd Engine2043 && swift test --filter "SceneTransitionTests|SceneManagerTests" 2>&1`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/SceneTransition.swift Engine2043/Sources/Engine2043/Scene/SceneManager.swift Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift
git commit -m "$(cat <<'EOF'
feat: add toGalaxySelect transition and optional carryover

SceneTransition gains .toGalaxySelect. Galaxy2/Galaxy3 transitions
now accept optional PlayerCarryover for fresh-start support.
SceneManager gains makeGalaxySelectScene factory.
EOF
)"
```

---

### Task 7: Galaxy Scene Changes (Optional Carryover + markCleared)

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:244`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift:98,307`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:106,250`
- Test: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`

Galaxy2Scene and Galaxy3Scene now accept `PlayerCarryover?` — when `nil`, start with default loadout. All three galaxy scenes call `ProgressStore.markCleared` at their boss-defeat transition point.

- [ ] **Step 1: Write tests for optional carryover and markCleared**

Add to `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`:

```swift
@Test @MainActor func galaxy2SceneAcceptsNilCarryover() {
    let scene = Galaxy2Scene(carryover: nil)
    #expect(scene.requestedTransition == nil)
}

@Test @MainActor func galaxy3SceneAcceptsNilCarryover() {
    let scene = Galaxy3Scene(carryover: nil)
    #expect(scene.requestedTransition == nil)
}
```

Add to `Engine2043/Tests/Engine2043Tests/ProgressStoreTests.swift`:

```swift
@Test func markClearedIsIdempotent() {
    let defaults = freshDefaults()
    ProgressStore.markCleared(galaxy: 1, store: defaults)
    ProgressStore.markCleared(galaxy: 1, store: defaults)
    #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == true)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "SceneTransitionTests/galaxy2SceneAcceptsNil|SceneTransitionTests/galaxy3SceneAcceptsNil" 2>&1`
Expected: Compilation error — Galaxy2Scene/Galaxy3Scene init requires non-optional `PlayerCarryover`.

- [ ] **Step 3: Update Galaxy2Scene to accept optional carryover**

In `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`, change the init signature (line 98) from:

```swift
    public init(carryover: PlayerCarryover) {
```

to:

```swift
    public init(carryover: PlayerCarryover? = nil) {
```

Then at the start of init, resolve the optional to a default:

```swift
    public init(carryover: PlayerCarryover? = nil) {
        let carryover = carryover ?? PlayerCarryover(
            weaponType: .doubleCannon,
            score: 0,
            secondaryCharges: 1,
            shieldDroneCount: 0,
            enemiesDestroyed: 0,
            elapsedTime: 0
        )
        collisionSystem = CollisionSystem(worldBounds: AABB(min: SIMD2(-200, -340), max: SIMD2(200, 340)))
        backgroundSystem.palette = .galaxy2
```

The rest of init remains unchanged — it already uses `carryover` as a local constant.

- [ ] **Step 4: Update Galaxy3Scene to accept optional carryover**

In `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift`, apply the same pattern. Change the init signature (line 106) from:

```swift
    public init(carryover: PlayerCarryover) {
```

to:

```swift
    public init(carryover: PlayerCarryover? = nil) {
        let carryover = carryover ?? PlayerCarryover(
            weaponType: .doubleCannon,
            score: 0,
            secondaryCharges: 1,
            shieldDroneCount: 0,
            enemiesDestroyed: 0,
            elapsedTime: 0
        )
```

The rest of init remains unchanged.

- [ ] **Step 5: Add markCleared to Galaxy1Scene**

In `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`, at line 244, add `ProgressStore.markCleared` right before the transition is set. The block around line 234-246 becomes:

```swift
            if bossDyingTimer >= totalBossDeathDuration {
                let weapon = player.component(ofType: WeaponComponent.self)
                let carryover = PlayerCarryover(
                    weaponType: weapon?.weaponType ?? .doubleCannon,
                    score: scoreSystem.currentScore,
                    secondaryCharges: max(1, weapon?.secondaryCharges ?? 1),
                    shieldDroneCount: shieldDrones.count,
                    enemiesDestroyed: enemiesDestroyed,
                    elapsedTime: elapsedTime
                )
                ProgressStore.markCleared(galaxy: 1)
                requestedTransition = .toGalaxy2(carryover)
                isBossDying = false
            }
```

- [ ] **Step 6: Add markCleared to Galaxy2Scene**

In `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`, at line 307, add `ProgressStore.markCleared` right before the transition. The block around line 297-309 becomes:

```swift
            if bossDyingTimer >= totalBossDeathDuration {
                let weapon = player.component(ofType: WeaponComponent.self)
                let carryover = PlayerCarryover(
                    weaponType: weapon?.weaponType ?? .doubleCannon,
                    score: scoreSystem.currentScore,
                    secondaryCharges: weapon?.secondaryCharges ?? 1,
                    shieldDroneCount: shieldDrones.count,
                    enemiesDestroyed: enemiesDestroyed,
                    elapsedTime: elapsedTime
                )
                ProgressStore.markCleared(galaxy: 2)
                requestedTransition = .toGalaxy3(carryover)
                isBossDying = false
            }
```

- [ ] **Step 7: Add markCleared to Galaxy3Scene**

In `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift`, at the victory transition (line 250), add `ProgressStore.markCleared` right before the transition is set. The block around line 246-252 becomes:

```swift
            if gameOverTimer > Self.restartDelay && requestedTransition == nil {
                if gameState == .gameOver {
                    requestedTransition = .toGameOver(gameResult)
                } else if gameState == .victory {
                    ProgressStore.markCleared(galaxy: 3)
                    requestedTransition = .toVictory(gameResult)
                }
            }
```

- [ ] **Step 8: Run full test suite to verify everything passes**

Run: `cd Engine2043 && swift test 2>&1`
Expected: All tests PASS. Compilation succeeds with the optional carryover changes.

- [ ] **Step 9: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift Engine2043/Tests/Engine2043Tests/ProgressStoreTests.swift
git commit -m "$(cat <<'EOF'
feat: optional carryover for Galaxy2/3 and markCleared on boss defeat

Galaxy2Scene and Galaxy3Scene now accept nil carryover, starting
with default loadout (double cannon, 0 score, 1 charge). All three
galaxy scenes call ProgressStore.markCleared at their boss-defeat
transition points.
EOF
)"
```

---

### Task 8: GalaxySelectScene

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/GalaxySelectScene.swift`
- Create: `Engine2043/Tests/Engine2043Tests/GalaxySelectSceneTests.swift`

The main new scene. Renders galaxy entries with cursor, handles keyboard/touch input, and dispatches transitions. Music continues from TitleScene uninterrupted.

- [ ] **Step 1: Write tests**

Create `Engine2043/Tests/Engine2043Tests/GalaxySelectSceneTests.swift`:

```swift
import Testing
import simd
@testable import Engine2043

struct GalaxySelectSceneTests {

    @MainActor
    private func runFrames(_ scene: GalaxySelectScene, count: Int) {
        var time = GameTime()
        for _ in 0..<count {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }
    }

    @Test @MainActor func initialStateIsCorrect() {
        let scene = GalaxySelectScene()
        #expect(scene.requestedTransition == nil)
        #expect(scene.selectedIndex == 0)
    }

    @Test @MainActor func menuDownMovesSelectionDown() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        #expect(scene.selectedIndex == 1)
    }

    @Test @MainActor func menuUpMovesSelectionUp() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Move down first, then up
        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1) // clear state

        input.menuUp = true
        runFrames(scene, count: 1)
        input.menuUp = false
        #expect(scene.selectedIndex == 0)
    }

    @Test @MainActor func selectionWrapsDownFromGalaxy3ToGalaxy1() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Move down 3 times: 0→1, 1→2, 2→0
        for _ in 0..<3 {
            input.menuDown = true
            runFrames(scene, count: 1)
            input.menuDown = false
            runFrames(scene, count: 1)
        }
        #expect(scene.selectedIndex == 0)
    }

    @Test @MainActor func selectionWrapsUpFromGalaxy1ToGalaxy3() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuUp = true
        runFrames(scene, count: 1)
        input.menuUp = false
        #expect(scene.selectedIndex == 2)
    }

    @Test @MainActor func fireOnGalaxy1TransitionsToGame() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Galaxy 1 is selected by default, fire
        input.primary = true
        runFrames(scene, count: 1)

        if case .toGame = scene.requestedTransition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toGame, got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func fireOnGalaxy2TransitionsToGalaxy2WithNilCarryover() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)

        input.primary = true
        runFrames(scene, count: 1)

        if case .toGalaxy2(let carryover) = scene.requestedTransition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2(nil), got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func fireOnGalaxy3TransitionsToGalaxy3WithNilCarryover() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Move to Galaxy 3
        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)
        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)

        input.primary = true
        runFrames(scene, count: 1)

        if case .toGalaxy3(let carryover) = scene.requestedTransition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy3(nil), got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func menuBackTransitionsToTitle() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuBack = true
        runFrames(scene, count: 1)

        if case .toTitle = scene.requestedTransition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toTitle, got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func tapOnGalaxyEntryLaunchesIt() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Tap on Galaxy 2 entry position (Y = 30 in the layout)
        input.tapPos = SIMD2(0, 30)
        runFrames(scene, count: 1)

        if case .toGalaxy2(let carryover) = scene.requestedTransition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2(nil), got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func collectEffectSpritesProducesOutput() {
        let scene = GalaxySelectScene()
        // Without an effectSheet we get an empty array — verify no crash
        let sprites = scene.collectEffectSprites(effectSheet: nil)
        #expect(sprites.isEmpty)
    }

    @Test @MainActor func repeatGuardPreventsRapidScrolling() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Hold menuDown for multiple frames — should only move once
        input.menuDown = true
        runFrames(scene, count: 5)
        // Should have moved from 0 to 1 (initial press), but not further
        // within 5 frames (~83ms at 60fps) which is less than repeat delay
        #expect(scene.selectedIndex == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter GalaxySelectSceneTests 2>&1`
Expected: Compilation error — `GalaxySelectScene` does not exist.

- [ ] **Step 3: Implement GalaxySelectScene**

Create `Engine2043/Sources/Engine2043/Scene/GalaxySelectScene.swift`:

```swift
import simd

@MainActor
public final class GalaxySelectScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?
    public var viewportManager: ViewportManager?

    // Selection state
    public private(set) var selectedIndex: Int = 0
    public private(set) var requestedTransition: SceneTransition?

    // Galaxy entry data
    private let galaxyNames = [
        "GALAXY 1  NGC-2043 PERIMETER",
        "GALAXY 2  KAY'SHARA EXPANSE",
        "GALAXY 3  ZENITH ARMADA GRID",
    ]

    // Layout constants
    private let titleY: Float = 180
    private let entryBaseY: Float = 70
    private let entrySpacing: Float = 40
    private let entryScale: Float = 2.0
    private let hintY: Float = -240

    // Hit-test options for galaxy entries (populated in init)
    private let entryOptions: [MenuInput.Option]

    // iOS "BACK" button
    #if os(iOS)
    private let backOption = MenuInput.Option(label: "BACK", position: SIMD2(0, -270), scale: 1.0)
    #endif

    // Repeat guard
    private var prevMenuUp = false
    private var prevMenuDown = false
    private var menuRepeatTimer: Double = 0
    private let initialRepeatDelay: Double = 0.3
    private let repeatRate: Double = 0.12

    public init() {
        entryOptions = (0..<3).map { i in
            MenuInput.Option(
                label: [
                    "GALAXY 1  NGC-2043 PERIMETER",
                    "GALAXY 2  KAY'SHARA EXPANSE",
                    "GALAXY 3  ZENITH ARMADA GRID",
                ][i],
                position: SIMD2(0, 70 - Float(i) * 40),
                scale: 2.0
            )
        }
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        backgroundSystem.update(deltaTime: dt)

        guard let input = inputProvider?.poll() else { return }

        // Back / ESC
        if input.menuBack {
            requestedTransition = .toTitle
            return
        }

        // Tap hit-test on galaxy entries
        if let tapPos = input.tapPosition {
            if let hit = MenuInput.hitTest(tapPosition: tapPos, options: entryOptions) {
                launchGalaxy(hit)
                return
            }
            #if os(iOS)
            if MenuInput.hitTest(tapPosition: tapPos, options: [backOption]) != nil {
                requestedTransition = .toTitle
                return
            }
            #endif
        }

        // Fire launches selected galaxy
        if input.primaryFire {
            launchGalaxy(selectedIndex)
            return
        }

        // Menu navigation with repeat guard
        if menuRepeatTimer > 0 { menuRepeatTimer -= dt }

        let freshDown = input.menuDown && !prevMenuDown
        let freshUp = input.menuUp && !prevMenuUp
        let repeatDown = input.menuDown && prevMenuDown && menuRepeatTimer <= 0
        let repeatUp = input.menuUp && prevMenuUp && menuRepeatTimer <= 0

        if freshDown || repeatDown {
            selectedIndex = (selectedIndex + 1) % 3
            menuRepeatTimer = freshDown ? initialRepeatDelay : repeatRate
        }
        if freshUp || repeatUp {
            selectedIndex = (selectedIndex + 2) % 3
            menuRepeatTimer = freshUp ? initialRepeatDelay : repeatRate
        }

        prevMenuUp = input.menuUp
        prevMenuDown = input.menuDown
    }

    public func update(time: GameTime) {}

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        backgroundSystem.collectSprites()
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        var sprites: [SpriteInstance] = []

        let cyanColor = GameConfig.Palette.player
        let goldColor = GameConfig.Palette.item
        let dimWhite = SIMD4<Float>(1, 1, 1, 0.5)

        // Title
        sprites.append(contentsOf: BitmapText.makeSprites(
            "SELECT GALAXY",
            at: SIMD2(0, titleY),
            color: dimWhite,
            scale: 2.0,
            effectSheet: effectSheet
        ))

        // Galaxy entries
        for i in 0..<3 {
            let entryY = entryBaseY - Float(i) * entrySpacing
            let isSelected = i == selectedIndex
            let entryColor = isSelected
                ? SIMD4<Float>(cyanColor.x, cyanColor.y, cyanColor.z, 1.0)
                : dimWhite
            let text = galaxyNames[i]

            // Entry text
            sprites.append(contentsOf: BitmapText.makeSprites(
                text,
                at: SIMD2(0, entryY),
                color: entryColor,
                scale: entryScale,
                effectSheet: effectSheet
            ))

            // Cursor > (left of highlighted entry)
            if isSelected {
                let glyphW: Float = 6 * entryScale
                let textWidth = Float(text.count) * glyphW
                let cursorX = -(textWidth / 2) - glyphW * 1.5
                sprites.append(contentsOf: BitmapText.makeSprites(
                    ">",
                    at: SIMD2(cursorX, entryY),
                    color: SIMD4(cyanColor.x, cyanColor.y, cyanColor.z, 1.0),
                    scale: entryScale,
                    effectSheet: effectSheet
                ))
            }

            // Cleared * indicator (right of entry)
            if ProgressStore.isCleared(galaxy: i + 1) {
                let glyphW: Float = 6 * entryScale
                let textWidth = Float(text.count) * glyphW
                let starX = (textWidth / 2) + glyphW * 1.5
                sprites.append(contentsOf: BitmapText.makeSprites(
                    "*",
                    at: SIMD2(starX, entryY),
                    color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 1.0),
                    scale: entryScale,
                    effectSheet: effectSheet
                ))
            }
        }

        // Input hint
        #if os(iOS)
        let hintText = "SWIPE TO SELECT  TAP TO LAUNCH"
        #else
        let hintText = "UP/DOWN SELECT  SPACE LAUNCH  ESC BACK"
        #endif
        sprites.append(contentsOf: BitmapText.makeSprites(
            hintText,
            at: SIMD2(0, hintY),
            color: SIMD4(1, 1, 1, 0.3),
            scale: 1.0,
            effectSheet: effectSheet
        ))

        // iOS "BACK" option
        #if os(iOS)
        sprites.append(contentsOf: BitmapText.makeSprites(
            backOption.label,
            at: backOption.position,
            color: dimWhite,
            scale: backOption.scale,
            effectSheet: effectSheet
        ))
        #endif

        return sprites
    }

    // MARK: - Private

    private func launchGalaxy(_ index: Int) {
        switch index {
        case 0: requestedTransition = .toGame
        case 1: requestedTransition = .toGalaxy2(nil)
        case 2: requestedTransition = .toGalaxy3(nil)
        default: break
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter GalaxySelectSceneTests 2>&1`
Expected: All tests PASS.

- [ ] **Step 5: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1`
Expected: All tests PASS. No regressions.

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/GalaxySelectScene.swift Engine2043/Tests/Engine2043Tests/GalaxySelectSceneTests.swift
git commit -m "$(cat <<'EOF'
feat: add GalaxySelectScene with cursor navigation and tap support

Three galaxy entries with keyboard up/down + fire, iOS swipe + tap,
repeat guard, cleared-galaxy indicator via ProgressStore, and
platform-appropriate input hints.
EOF
)"
```

---

### Task 9: TitleScene → GalaxySelect Transition

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/TitleScene.swift:99-103`
- Test: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`

TitleScene fire input now triggers `.toGalaxySelect` instead of `.toGame`.

- [ ] **Step 1: Update the existing test**

In `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`, update `titleSceneRequestsGameOnInput` to expect the new transition:

```swift
    @Test @MainActor func titleSceneRequestsGalaxySelectOnInput() {
        let scene = TitleScene()
        let input = MockInputProvider(primary: true)
        scene.inputProvider = input

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        while time.shouldPerformFixedUpdate() {
            scene.fixedUpdate(time: time)
            time.consumeFixedUpdate()
        }

        if case .toGalaxySelect = scene.requestedTransition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toGalaxySelect, got \(String(describing: scene.requestedTransition))")
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter "SceneTransitionTests/titleSceneRequestsGalaxySelect" 2>&1`
Expected: FAIL — TitleScene still sets `.toGame`.

- [ ] **Step 3: Update TitleScene**

In `Engine2043/Sources/Engine2043/Scene/TitleScene.swift`, change line 101 from:

```swift
                requestedTransition = .toGame
```

to:

```swift
                requestedTransition = .toGalaxySelect
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter SceneTransitionTests 2>&1`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/TitleScene.swift Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift
git commit -m "$(cat <<'EOF'
feat: TitleScene fire input now goes to galaxy select screen

Replaces the direct-to-Galaxy1 flow with an intermediate selection
screen. Title music continues uninterrupted through the transition.
EOF
)"
```

---

### Task 10: MetalView Wiring (macOS + iOS)

**Files:**
- Modify: `Project2043-macOS/MetalView.swift:49-105`
- Modify: `Project2043-iOS/MetalView.swift:59-117`

Wire up the `makeGalaxySelectScene` factory on both platforms and update Galaxy2/Galaxy3 factories to handle optional carryover.

- [ ] **Step 1: Wire macOS MetalView**

In `Project2043-macOS/MetalView.swift`, add the galaxy select factory after `makeTitleScene` (after line 55):

```swift
        sceneManager.makeGalaxySelectScene = { [weak self] in
            let scene = GalaxySelectScene()
            scene.inputProvider = self?.inputProvider
            scene.viewportManager = self?.viewportManager
            return scene
        }
```

Note: No audio stop — title music continues through the select screen.

Update `makeGalaxy2Scene` (around line 83) — the closure parameter type changes from `PlayerCarryover` to `PlayerCarryover?`:

```swift
        sceneManager.makeGalaxy2Scene = { [weak self] carryover in
            let scene = Galaxy2Scene(carryover: carryover)
            scene.inputProvider = self?.inputProvider
            scene.viewportManager = self?.viewportManager
            scene.audioProvider = audio
            scene.sfx = sfxEngine
            audio.stopAll()
            sfxEngine.stopLaser()
            sfxEngine.stopMusic()
            return scene
        }
```

Update `makeGalaxy3Scene` (around line 95) — same parameter type change:

```swift
        sceneManager.makeGalaxy3Scene = { [weak self] carryover in
            let scene = Galaxy3Scene(carryover: carryover)
            scene.inputProvider = self?.inputProvider
            scene.viewportManager = self?.viewportManager
            scene.audioProvider = audio
            scene.sfx = sfxEngine
            audio.stopAll()
            sfxEngine.stopLaser()
            sfxEngine.stopMusic()
            return scene
        }
```

- [ ] **Step 2: Wire iOS MetalView**

In `Project2043-iOS/MetalView.swift`, add the galaxy select factory after `makeTitleScene` (after line 67):

```swift
        sceneManager.makeGalaxySelectScene = { [weak self] in
            let scene = GalaxySelectScene()
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            return scene
        }
```

Update `makeGalaxy2Scene` (around line 95) — the closure parameter type changes from `PlayerCarryover` to `PlayerCarryover?`:

```swift
        sceneManager.makeGalaxy2Scene = { [weak self] carryover in
            let scene = Galaxy2Scene(carryover: carryover)
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            scene.audioProvider = audio
            scene.sfx = sfxEngine
            audio.stopAll()
            sfxEngine.stopLaser()
            sfxEngine.stopMusic()
            return scene
        }
```

Update `makeGalaxy3Scene` (around line 107) — same parameter type change:

```swift
        sceneManager.makeGalaxy3Scene = { [weak self] carryover in
            let scene = Galaxy3Scene(carryover: carryover)
            scene.inputProvider = self?.touchInput
            scene.viewportManager = self?.viewportManager
            scene.audioProvider = audio
            scene.sfx = sfxEngine
            audio.stopAll()
            sfxEngine.stopLaser()
            sfxEngine.stopMusic()
            return scene
        }
```

- [ ] **Step 3: Verify compilation**

Run: `cd Engine2043 && swift build 2>&1`
Expected: Build succeeds. (MetalView files are in the app targets, not the SPM package, so a full Xcode build is needed for complete verification. The engine package build confirms no type mismatches.)

- [ ] **Step 4: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1`
Expected: All tests PASS. No regressions.

- [ ] **Step 5: Commit**

```bash
git add Project2043-macOS/MetalView.swift Project2043-iOS/MetalView.swift
git commit -m "$(cat <<'EOF'
feat: wire GalaxySelectScene factory in macOS and iOS MetalViews

Galaxy select scene gets inputProvider and viewportManager but no
audio stop, so title music continues. Galaxy2/3 factories updated
for optional carryover parameter.
EOF
)"
```
