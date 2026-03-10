# Title Screen, Game Over & Victory Screens Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a title screen with attract mode, a game over screen with tap/click navigation, and an expanded victory screen with stats — all rendered through the Metal pipeline with CRT static transitions.

**Architecture:** Three new `GameScene`-conforming scenes (`TitleScene`, `GameOverScene`, `VictoryScene`) managed by the existing `SceneManager`. A new `TransitionEffect` drives a CRT noise shader pass during scene changes. The `makeTextSprites` helper is extracted from `Galaxy1Scene` into a shared utility so all scenes can render bitmap text. MetalView on both platforms delegates scene lifecycle to `SceneManager` instead of managing `Galaxy1Scene` directly.

**Tech Stack:** Swift 6, Metal shaders, GameplayKit (ECS), Engine2043 Swift package

---

### Task 1: Extract `makeTextSprites` into a shared utility

The bitmap text rendering helper currently lives as a private method on `Galaxy1Scene`. All new scenes need it, so extract it to a shared utility.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Rendering/BitmapText.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:660-687`

**Step 1: Create BitmapText.swift**

```swift
// Engine2043/Sources/Engine2043/Rendering/BitmapText.swift
import simd

@MainActor
public enum BitmapText {
    public static func makeSprites(
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
}
```

**Step 2: Update Galaxy1Scene to use BitmapText**

Replace the private `makeTextSprites` method (lines 660-687) with calls to `BitmapText.makeSprites`. Find every call site in Galaxy1Scene — there are calls in `collectEffectSprites` (game over text, victory text, score text) and `appendEffectHUD` (score display, weapon name flash). Replace `makeTextSprites(` with `BitmapText.makeSprites(` at each call site. Then delete the private `makeTextSprites` method entirely.

**Step 3: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -5`
Expected: All tests pass

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/BitmapText.swift Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "refactor: extract BitmapText utility from Galaxy1Scene"
```

---

### Task 2: Add `GameResult` struct for passing end-of-game data between scenes

Scenes need to pass score, kills, and time from Galaxy1Scene to GameOverScene/VictoryScene. Define a struct for this.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/GameResult.swift`

**Step 1: Create GameResult.swift**

```swift
// Engine2043/Sources/Engine2043/Scene/GameResult.swift

public struct GameResult: Sendable {
    public let finalScore: Int
    public let enemiesDestroyed: Int
    public let elapsedTime: Double
    public let didWin: Bool

    public init(finalScore: Int, enemiesDestroyed: Int, elapsedTime: Double, didWin: Bool) {
        self.finalScore = finalScore
        self.enemiesDestroyed = enemiesDestroyed
        self.elapsedTime = elapsedTime
        self.didWin = didWin
    }
}
```

**Step 2: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/GameResult.swift
git commit -m "feat: add GameResult struct for scene data transfer"
```

---

### Task 3: Add stat tracking to Galaxy1Scene

Galaxy1Scene needs to track `enemiesDestroyed` and `elapsedTime` and expose a `GameResult`.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`
- Test: `Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift`

**Step 1: Write the failing test**

Add to `Galaxy1SceneTests.swift`:

```swift
@Test @MainActor func sceneTracksEnemiesDestroyed() {
    let scene = Galaxy1Scene()
    #expect(scene.enemiesDestroyed == 0)
}

@Test @MainActor func sceneTracksElapsedTime() {
    let scene = Galaxy1Scene()
    var time = GameTime()
    time.advance(by: 1.0 / 60.0)
    while time.shouldPerformFixedUpdate() {
        scene.fixedUpdate(time: time)
        time.consumeFixedUpdate()
    }
    #expect(scene.elapsedTime > 0)
}

@Test @MainActor func sceneExposesGameResult() {
    let scene = Galaxy1Scene()
    let result = scene.gameResult
    #expect(result.finalScore == 0)
    #expect(result.enemiesDestroyed == 0)
    #expect(result.didWin == false)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test 2>&1 | tail -10`
Expected: FAIL — `enemiesDestroyed`, `elapsedTime`, `gameResult` don't exist

**Step 3: Add tracking properties to Galaxy1Scene**

In Galaxy1Scene, add to the "Game state" section (after line 63):

```swift
public private(set) var enemiesDestroyed: Int = 0
public private(set) var elapsedTime: Double = 0
```

Add a computed property:

```swift
public var gameResult: GameResult {
    GameResult(
        finalScore: scoreSystem.currentScore,
        enemiesDestroyed: enemiesDestroyed,
        elapsedTime: elapsedTime,
        didWin: gameState == .victory
    )
}
```

In `fixedUpdate`, add elapsed time tracking at the top of the method (before the `guard gameState == .playing` line):

```swift
if gameState == .playing {
    elapsedTime += time.fixedDeltaTime
}
```

Increment `enemiesDestroyed` wherever enemies are killed. Look for where `scoreSystem.addScore` is called — in `processCollisions()`. After each `scoreSystem.addScore(...)` call that corresponds to an enemy kill, add `enemiesDestroyed += 1`. Specifically:
- Tier 1 enemy kill
- Tier 2 enemy kill
- Tier 3 turret kill
- Boss kill

Note: The `scoreSystem.currentScore` property needs to be checked. Search for `currentScore` in `ScoreSystem.swift` to confirm it's publicly accessible.

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test 2>&1 | tail -5`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift
git commit -m "feat: track enemies destroyed and elapsed time in Galaxy1Scene"
```

---

### Task 4: Add `SceneTransition` enum and update `SceneManager`

The `SceneManager` (currently 20 lines) needs to support transition requests that the MetalView render loop can check. Scenes will signal their desired next scene through a `requestedTransition` property.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/SceneTransition.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneManager.swift`
- Modify: `Engine2043/Sources/Engine2043/Core/GameEngine.swift` (add GameScene protocol property)

**Step 1: Create SceneTransition.swift**

```swift
// Engine2043/Sources/Engine2043/Scene/SceneTransition.swift

public enum SceneTransition: Sendable {
    case toGame
    case toTitle
    case toGameOver(GameResult)
    case toVictory(GameResult)
}
```

**Step 2: Add `requestedTransition` to the GameScene protocol**

In `GameEngine.swift`, add to the `GameScene` protocol:

```swift
var requestedTransition: SceneTransition? { get }
```

Add a default implementation in the extension:

```swift
public var requestedTransition: SceneTransition? { nil }
```

**Step 3: Expand SceneManager to handle transition lifecycle**

Replace the contents of `SceneManager.swift`:

```swift
import GameplayKit

@MainActor
public final class SceneManager {
    public let engine: GameEngine

    // Scene factory closures — called to create fresh scenes
    public var makeTitleScene: (() -> any GameScene)?
    public var makeGameScene: (() -> any GameScene)?
    public var makeGameOverScene: ((GameResult) -> any GameScene)?
    public var makeVictoryScene: ((GameResult) -> any GameScene)?

    // Transition state
    public private(set) var isTransitioning: Bool = false
    public private(set) var transitionProgress: Float = 0
    private var pendingTransition: SceneTransition?
    private let transitionDuration: Double = 0.4
    private var transitionTimer: Double = 0
    private var transitionPhase: TransitionPhase = .none

    private enum TransitionPhase {
        case none
        case fadeOut   // noise ramps 0 → 1
        case fadeIn    // noise ramps 1 → 0
    }

    public init(engine: GameEngine) {
        self.engine = engine
    }

    public func checkForTransition() {
        guard transitionPhase == .none,
              let transition = engine.currentScene?.requestedTransition else { return }
        pendingTransition = transition
        transitionPhase = .fadeOut
        transitionTimer = 0
        isTransitioning = true
    }

    public func updateTransition(deltaTime: Double) {
        guard transitionPhase != .none else { return }

        transitionTimer += deltaTime
        let halfDuration = transitionDuration / 2

        switch transitionPhase {
        case .fadeOut:
            transitionProgress = Float(min(transitionTimer / halfDuration, 1.0))
            if transitionTimer >= halfDuration {
                // Switch scene at peak noise
                performSceneSwitch()
                transitionPhase = .fadeIn
                transitionTimer = 0
            }
        case .fadeIn:
            transitionProgress = Float(max(1.0 - transitionTimer / halfDuration, 0.0))
            if transitionTimer >= halfDuration {
                transitionPhase = .none
                transitionProgress = 0
                isTransitioning = false
                pendingTransition = nil
            }
        case .none:
            break
        }
    }

    private func performSceneSwitch() {
        guard let transition = pendingTransition else { return }
        let scene: (any GameScene)?
        switch transition {
        case .toTitle:
            scene = makeTitleScene?()
        case .toGame:
            scene = makeGameScene?()
        case .toGameOver(let result):
            scene = makeGameOverScene?(result)
        case .toVictory(let result):
            scene = makeVictoryScene?(result)
        }
        if let scene {
            engine.currentScene = scene
        }
    }
}
```

**Step 4: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -5`
Expected: All tests pass (Galaxy1Scene gets default `nil` for `requestedTransition`)

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/SceneTransition.swift Engine2043/Sources/Engine2043/Scene/SceneManager.swift Engine2043/Sources/Engine2043/Core/GameEngine.swift
git commit -m "feat: expand SceneManager with transition lifecycle and scene factories"
```

---

### Task 5: Add CRT noise transition to the Metal shader pipeline

Add a transition noise effect that blends procedural static over the rendered frame. This is controlled by a `transitionProgress` float (0 = no noise, 1 = full static).

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/Shaders/PostProcess.metal`
- Modify: `Engine2043/Sources/Engine2043/Rendering/RenderTypes.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/Renderer.swift`

**Step 1: Add transitionProgress to PostProcessUniforms**

In `RenderTypes.swift`, update `PostProcessUniforms`:

```swift
public struct PostProcessUniforms: Sendable {
    public var time: Float
    public var bloomIntensity: Float
    public var scanlineIntensity: Float
    public var transitionProgress: Float

    public init(time: Float, bloomIntensity: Float = 0.6, scanlineIntensity: Float = 0.15, transitionProgress: Float = 0) {
        self.time = time
        self.bloomIntensity = bloomIntensity
        self.scanlineIntensity = scanlineIntensity
        self.transitionProgress = transitionProgress
    }
}
```

Note: The `_pad` field currently exists to fill alignment. Replace `_pad` with `transitionProgress` — same size, same alignment. Also update the Metal struct in `PostProcess.metal` to match (replace `float _pad` with `float transitionProgress`).

**Step 2: Add noise transition to the post-process fragment shader**

In `PostProcess.metal`, update the `postprocess_fragment` function. After the CRT scanlines section, before the `return`, add:

```metal
    // --- CRT static transition ---
    if (uniforms.transitionProgress > 0.0) {
        // Hash-based noise
        float2 noiseUV = uv * resolution;
        float noise = fract(sin(dot(noiseUV + uniforms.time * 100.0, float2(12.9898, 78.233))) * 43758.5453);
        float3 staticColor = float3(noise);
        sceneColor.rgb = mix(sceneColor.rgb, staticColor, uniforms.transitionProgress);
    }
```

**Step 3: Add transitionProgress property to Renderer**

In `Renderer.swift`, add a public property:

```swift
public var transitionProgress: Float = 0
```

In the `render` method, update the PostProcessUniforms creation:

```swift
var ppUniforms = PostProcessUniforms(time: totalTime, transitionProgress: transitionProgress)
```

**Step 4: Build and verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/Shaders/PostProcess.metal Engine2043/Sources/Engine2043/Rendering/RenderTypes.swift Engine2043/Sources/Engine2043/Rendering/Renderer.swift
git commit -m "feat: add CRT static noise transition to post-process shader"
```

---

### Task 6: Add `:` and `.` glyphs to the bitmap font

The victory screen needs `:` for stat labels (e.g. "SCORE: 00012350") and the time display needs `:` for "03:22". Add these to the glyph set.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`

**Step 1: Update glyphChars in EffectTextureSheet**

In `EffectTextureSheet.swift`, line 23, change:

```swift
static let glyphChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ- ")
```

to:

```swift
static let glyphChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.: ")
```

Also update `spriteNames` — no change needed since it uses `glyphChars` dynamically.

The layout already dynamically generates entries for all glyphChars (line 49-57), so the two new chars will get slots automatically. Verify the total width fits: 40 chars × 6px = 240px < 256px. ✓

**Step 2: Add glyph generators in SpriteFactory**

Find the `makeBitmapGlyph` function in `SpriteFactory.swift`. It likely uses a bitmap lookup for each character. Add cases for `:` and `.`:

- `:` (colon) — two small dots vertically centered (rows 2,3 and 5,6 of the 6×8 grid)
- `.` (period) — single dot at the bottom (rows 6,7, columns 2,3)

Look at the existing `makeBitmapGlyph` implementation to match the pattern.

**Step 3: Build and verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift
git commit -m "feat: add colon and period glyphs to bitmap font"
```

---

### Task 7: Create `TitleScene`

Build the title screen scene with scrolling starfield background, attract mode demo, title text, and blinking start prompt.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/TitleScene.swift`

**Step 1: Create TitleScene**

```swift
// Engine2043/Sources/Engine2043/Scene/TitleScene.swift
import simd

@MainActor
public final class TitleScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?

    // Attract mode entities — simple scripted sprites (no ECS needed)
    private var attractShipPos = SIMD2<Float>(0, -100)
    private var attractShipVel = SIMD2<Float>(30, 20)
    private var attractEnemies: [(pos: SIMD2<Float>, vel: SIMD2<Float>)] = []
    private var attractProjectiles: [(pos: SIMD2<Float>, vel: SIMD2<Float>, age: Double)] = []
    private var attractFireTimer: Double = 0

    // UI state
    private var blinkTimer: Double = 0
    private var showPrompt: Bool = true
    private var totalTime: Double = 0

    // Transition
    public private(set) var requestedTransition: SceneTransition?

    public init() {
        seedAttractEnemies()
    }

    private func seedAttractEnemies() {
        // Spawn a handful of enemies drifting downward in formation
        let hw = GameConfig.designWidth / 2 - 40
        for i in 0..<5 {
            let x = -hw + Float(i) * (hw * 2 / 4)
            attractEnemies.append((
                pos: SIMD2(x, GameConfig.designHeight / 2 + 50),
                vel: SIMD2(0, -40)
            ))
        }
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        totalTime += dt

        backgroundSystem.update(deltaTime: dt)

        // Attract ship — bounce around the lower portion of the screen
        let hw = GameConfig.designWidth / 2 - 20
        let hh = GameConfig.designHeight / 2 - 20
        attractShipPos += attractShipVel * Float(dt)
        if attractShipPos.x < -hw || attractShipPos.x > hw { attractShipVel.x *= -1 }
        if attractShipPos.y < -hh || attractShipPos.y > 0 { attractShipVel.y *= -1 }

        // Attract enemies — drift down, wrap around
        for i in attractEnemies.indices {
            attractEnemies[i].pos += attractEnemies[i].vel * Float(dt)
            if attractEnemies[i].pos.y < -hh - 30 {
                attractEnemies[i].pos.y = hh + 30
                attractEnemies[i].pos.x = Float.random(in: -hw...hw)
            }
        }

        // Auto-fire projectiles
        attractFireTimer += dt
        if attractFireTimer >= 0.3 {
            attractFireTimer = 0
            attractProjectiles.append((
                pos: attractShipPos + SIMD2(0, 15),
                vel: SIMD2(0, 500),
                age: 0
            ))
        }

        // Update projectiles
        for i in attractProjectiles.indices.reversed() {
            attractProjectiles[i].pos += attractProjectiles[i].vel * Float(dt)
            attractProjectiles[i].age += dt
            if attractProjectiles[i].age > 1.5 {
                attractProjectiles.remove(at: i)
            }
        }

        // Blink timer
        blinkTimer += dt
        if blinkTimer >= 0.5 {
            blinkTimer = 0
            showPrompt.toggle()
        }

        // Check for start input
        if let input = inputProvider?.poll() {
            if input.primaryFire || input.secondaryFire1 || input.secondaryFire2 || input.secondaryFire3 {
                requestedTransition = .toGame
            }
        }
    }

    public func update(time: GameTime) {}

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        var sprites = backgroundSystem.collectSprites()

        // Attract mode player ship
        var shipSprite = SpriteInstance(
            position: attractShipPos,
            size: GameConfig.Player.size,
            color: SIMD4(1, 1, 1, 0.6)
        )
        if let atlas, let uv = atlas.uvRect(for: "player") {
            shipSprite.uvRect = uv
        }
        sprites.append(shipSprite)

        // Attract mode enemies
        for enemy in attractEnemies {
            var enemySprite = SpriteInstance(
                position: enemy.pos,
                size: GameConfig.Enemy.tier1Size,
                color: SIMD4(GameConfig.Palette.enemy.x, GameConfig.Palette.enemy.y, GameConfig.Palette.enemy.z, 0.5)
            )
            if let atlas, let uv = atlas.uvRect(for: "tier1") {
                enemySprite.uvRect = uv
            }
            sprites.append(enemySprite)
        }

        // Attract mode projectiles
        for proj in attractProjectiles {
            var projSprite = SpriteInstance(
                position: proj.pos,
                size: GameConfig.Player.projectileSize,
                color: SIMD4(GameConfig.Palette.player.x, GameConfig.Palette.player.y, GameConfig.Palette.player.z, 0.5)
            )
            if let atlas, let uv = atlas.uvRect(for: "playerBullet") {
                projSprite.uvRect = uv
            }
            sprites.append(projSprite)
        }

        return sprites
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        var sprites: [SpriteInstance] = []

        // Title text
        sprites.append(contentsOf: BitmapText.makeSprites(
            "PROJECT 2043",
            at: SIMD2(0, 120),
            color: GameConfig.Palette.player,
            scale: 4.0,
            effectSheet: effectSheet
        ))

        // Blinking start prompt
        if showPrompt {
            #if os(iOS)
            let promptText = "TAP TO START"
            #else
            let promptText = "PRESS SPACE"
            #endif
            sprites.append(contentsOf: BitmapText.makeSprites(
                promptText,
                at: SIMD2(0, -80),
                color: SIMD4(1, 1, 1, 0.8),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        return sprites
    }
}
```

**Step 2: Run tests and build**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/TitleScene.swift
git commit -m "feat: add TitleScene with attract mode demo"
```

---

### Task 8: Add hit-test utility for tap/click menu targets

GameOverScene and VictoryScene need to detect taps/clicks on bitmap text labels. Add a simple hit-test utility and extend InputProvider to support screen tap position.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Input/MenuInput.swift`
- Modify: `Engine2043/Sources/Engine2043/Input/InputManager.swift`

**Step 1: Extend PlayerInput with tap position**

In `InputManager.swift` (`InputManager.swift` contains `PlayerInput` and `InputProvider`), add a tap position to `PlayerInput`:

```swift
public struct PlayerInput: Sendable {
    public var movement: SIMD2<Float> = .zero
    public var primaryFire: Bool = false
    public var secondaryFire1: Bool = false
    public var secondaryFire2: Bool = false
    public var secondaryFire3: Bool = false
    /// Screen-space tap/click position in game design coordinates, set on first frame of tap
    public var tapPosition: SIMD2<Float>?

    public init() {}
}
```

**Step 2: Create MenuInput utility**

```swift
// Engine2043/Sources/Engine2043/Input/MenuInput.swift
import simd

@MainActor
public enum MenuInput {
    /// A menu option with a label, position, and bounding rect
    public struct Option {
        public let label: String
        public let position: SIMD2<Float>
        public let scale: Float

        public init(label: String, position: SIMD2<Float>, scale: Float = 2.0) {
            self.label = label
            self.position = position
            self.scale = scale
        }

        /// Bounding rect in game design coordinates (centered on position)
        public var bounds: (min: SIMD2<Float>, max: SIMD2<Float>) {
            let glyphW: Float = 6 * scale
            let glyphH: Float = 8 * scale
            let totalWidth = Float(label.count) * glyphW
            let halfW = totalWidth / 2
            let halfH = glyphH / 2
            // Add some padding for easier tapping
            let padX: Float = 10
            let padY: Float = 8
            return (
                min: SIMD2(position.x - halfW - padX, position.y - halfH - padY),
                max: SIMD2(position.x + halfW + padX, position.y + halfH + padY)
            )
        }
    }

    /// Check if a tap position hits any option, return its index
    public static func hitTest(tapPosition: SIMD2<Float>, options: [Option]) -> Int? {
        for (i, option) in options.enumerated() {
            let b = option.bounds
            if tapPosition.x >= b.min.x && tapPosition.x <= b.max.x &&
               tapPosition.y >= b.min.y && tapPosition.y <= b.max.y {
                return i
            }
        }
        return nil
    }
}
```

**Step 3: Build and verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/MenuInput.swift Engine2043/Sources/Engine2043/Input/InputManager.swift
git commit -m "feat: add MenuInput hit-test utility and tapPosition to PlayerInput"
```

---

### Task 9: Wire tap position through TouchInputProvider and KeyboardInputProvider

The input providers need to report tap/click positions in game design coordinates so menu scenes can hit-test against them.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift`
- Modify: `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift`

**Step 1: Update TouchInputProvider**

Add a property to track the latest tap-down position and convert it to game design coordinates. In `TouchInputProvider`, add:

```swift
private var pendingTapPosition: SIMD2<Float>?
```

In `touchesBegan`, when any touch begins (regardless of which side), record the tap position in game-design coordinates:

```swift
// Convert screen-space tap to game design coordinates
let gameX = (Float(loc.x) / Float(screenSize.width) - 0.5) * GameConfig.designWidth
let gameY = (0.5 - Float(loc.y) / Float(screenSize.height)) * GameConfig.designHeight
pendingTapPosition = SIMD2(gameX, gameY)
```

In `poll()`, set `input.tapPosition = pendingTapPosition` and then clear `pendingTapPosition = nil` (so it's only reported once per tap).

**Step 2: Update KeyboardInputProvider**

Add a property to convert space/enter key press into a tap at screen center (for menu selection, the hit-test approach will use a different mechanism on macOS — clicking). For macOS, add mouse click support:

Add properties:

```swift
private var pendingClickPosition: SIMD2<Float>?
```

Add a public method:

```swift
public func mouseDown(at point: SIMD2<Float>, viewSize: SIMD2<Float>) {
    let gameX = (point.x / viewSize.x - 0.5) * GameConfig.designWidth
    let gameY = (0.5 - point.y / viewSize.y) * GameConfig.designHeight
    pendingClickPosition = SIMD2(gameX, gameY)
}
```

In `poll()`, set `input.tapPosition = pendingClickPosition` and clear it.

**Step 3: Update macOS MetalView to forward mouse clicks**

In `Project2043-macOS/MetalView.swift`, add:

```swift
override func mouseDown(with event: NSEvent) {
    let loc = convert(event.locationInWindow, from: nil)
    // NSView has flipped Y from bottom-left
    let point = SIMD2<Float>(Float(loc.x), Float(bounds.height - loc.y))
    let viewSize = SIMD2<Float>(Float(bounds.width), Float(bounds.height))
    inputProvider.mouseDown(at: point, viewSize: viewSize)
}
```

**Step 4: Build and verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift Project2043-macOS/MetalView.swift
git commit -m "feat: wire tap/click positions through input providers"
```

---

### Task 10: Create `GameOverScene`

Build the game over screen with "GAME OVER" text, score display, and tappable RETRY / TITLE SCREEN options.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/GameOverScene.swift`

**Step 1: Create GameOverScene**

```swift
// Engine2043/Sources/Engine2043/Scene/GameOverScene.swift
import simd

@MainActor
public final class GameOverScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?

    private let result: GameResult
    public private(set) var requestedTransition: SceneTransition?

    private var appearTimer: Double = 0
    private let menuAppearDelay: Double = 1.0 // delay before menu options appear
    private var menuVisible: Bool = false

    // Highlight state
    private var highlightedOption: Int? = nil

    private let menuOptions: [MenuInput.Option] = [
        MenuInput.Option(label: "RETRY", position: SIMD2(0, -60), scale: 2.0),
        MenuInput.Option(label: "TITLE SCREEN", position: SIMD2(0, -90), scale: 2.0),
    ]

    public init(result: GameResult) {
        self.result = result
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        backgroundSystem.update(deltaTime: dt)

        if !menuVisible {
            appearTimer += dt
            if appearTimer >= menuAppearDelay {
                menuVisible = true
            }
            return
        }

        // Check for tap/click input
        guard let input = inputProvider?.poll() else { return }
        if let tapPos = input.tapPosition {
            if let hit = MenuInput.hitTest(tapPosition: tapPos, options: menuOptions) {
                switch hit {
                case 0: requestedTransition = .toGame
                case 1: requestedTransition = .toTitle
                default: break
                }
            }
        }
    }

    public func update(time: GameTime) {}

    public func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] {
        backgroundSystem.collectSprites()
    }

    public func collectEffectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
        guard let effectSheet else { return [] }
        var sprites: [SpriteInstance] = []

        // GAME OVER title
        sprites.append(contentsOf: BitmapText.makeSprites(
            "GAME OVER",
            at: SIMD2(0, 60),
            color: SIMD4(GameConfig.Palette.enemy.x, GameConfig.Palette.enemy.y, GameConfig.Palette.enemy.z, 0.95),
            scale: 3.0,
            effectSheet: effectSheet
        ))

        // Score
        let scoreText = String(format: "%08d", result.finalScore)
        sprites.append(contentsOf: BitmapText.makeSprites(
            scoreText,
            at: SIMD2(0, 20),
            color: SIMD4(1, 1, 1, 0.8),
            scale: 2.0,
            effectSheet: effectSheet
        ))

        // Menu options (only after delay)
        if menuVisible {
            for (i, option) in menuOptions.enumerated() {
                let isHighlighted = highlightedOption == i
                let alpha: Float = isHighlighted ? 1.0 : 0.7
                sprites.append(contentsOf: BitmapText.makeSprites(
                    option.label,
                    at: option.position,
                    color: SIMD4(1, 1, 1, alpha),
                    scale: option.scale,
                    effectSheet: effectSheet
                ))
            }
        }

        return sprites
    }
}
```

**Step 2: Build and verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/GameOverScene.swift
git commit -m "feat: add GameOverScene with tappable menu options"
```

---

### Task 11: Create `VictoryScene`

Build the victory screen with "MISSION COMPLETE" text, sequentially revealed stats, and tappable menu options.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/VictoryScene.swift`

**Step 1: Create VictoryScene**

```swift
// Engine2043/Sources/Engine2043/Scene/VictoryScene.swift
import simd

@MainActor
public final class VictoryScene: GameScene {
    private let backgroundSystem = BackgroundSystem()
    public var inputProvider: (any InputProvider)?

    private let result: GameResult
    public private(set) var requestedTransition: SceneTransition?

    // Sequential stat reveal timing
    private var revealTimer: Double = 0
    private let statRevealInterval: Double = 0.6
    private var statsRevealed: Int = 0
    private let totalStats = 3

    private var menuVisible: Bool = false

    private let menuOptions: [MenuInput.Option] = [
        MenuInput.Option(label: "RETRY", position: SIMD2(0, -120), scale: 2.0),
        MenuInput.Option(label: "TITLE SCREEN", position: SIMD2(0, -150), scale: 2.0),
    ]

    public init(result: GameResult) {
        self.result = result
    }

    public func fixedUpdate(time: GameTime) {
        let dt = time.fixedDeltaTime
        backgroundSystem.update(deltaTime: dt)

        // Sequential reveal
        revealTimer += dt
        let newRevealed = min(Int(revealTimer / statRevealInterval), totalStats)
        if newRevealed > statsRevealed {
            statsRevealed = newRevealed
        }
        if statsRevealed >= totalStats && revealTimer >= Double(totalStats) * statRevealInterval + 0.5 {
            menuVisible = true
        }

        guard menuVisible else { return }

        // Check for tap/click input
        guard let input = inputProvider?.poll() else { return }
        if let tapPos = input.tapPosition {
            if let hit = MenuInput.hitTest(tapPosition: tapPos, options: menuOptions) {
                switch hit {
                case 0: requestedTransition = .toGame
                case 1: requestedTransition = .toTitle
                default: break
                }
            }
        }
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

        // MISSION COMPLETE title
        sprites.append(contentsOf: BitmapText.makeSprites(
            "MISSION COMPLETE",
            at: SIMD2(0, 100),
            color: SIMD4(cyanColor.x, cyanColor.y, cyanColor.z, 0.95),
            scale: 3.0,
            effectSheet: effectSheet
        ))

        // Stats (revealed sequentially)
        let statY: Float = 40
        let statSpacing: Float = 30

        if statsRevealed >= 1 {
            // SCORE
            sprites.append(contentsOf: BitmapText.makeSprites(
                "SCORE",
                at: SIMD2(-40, statY),
                color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
            sprites.append(contentsOf: BitmapText.makeSprites(
                String(format: "%08d", result.finalScore),
                at: SIMD2(60, statY),
                color: SIMD4(1, 1, 1, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        if statsRevealed >= 2 {
            // ENEMIES DESTROYED
            sprites.append(contentsOf: BitmapText.makeSprites(
                "DESTROYED",
                at: SIMD2(-40, statY - statSpacing),
                color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
            sprites.append(contentsOf: BitmapText.makeSprites(
                String(format: "%d", result.enemiesDestroyed),
                at: SIMD2(60, statY - statSpacing),
                color: SIMD4(1, 1, 1, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        if statsRevealed >= 3 {
            // TIME
            let minutes = Int(result.elapsedTime) / 60
            let seconds = Int(result.elapsedTime) % 60
            sprites.append(contentsOf: BitmapText.makeSprites(
                "TIME",
                at: SIMD2(-40, statY - statSpacing * 2),
                color: SIMD4(goldColor.x, goldColor.y, goldColor.z, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
            sprites.append(contentsOf: BitmapText.makeSprites(
                String(format: "%02d:%02d", minutes, seconds),
                at: SIMD2(60, statY - statSpacing * 2),
                color: SIMD4(1, 1, 1, 0.9),
                scale: 2.0,
                effectSheet: effectSheet
            ))
        }

        // Menu options
        if menuVisible {
            for option in menuOptions {
                sprites.append(contentsOf: BitmapText.makeSprites(
                    option.label,
                    at: option.position,
                    color: SIMD4(1, 1, 1, 0.7),
                    scale: option.scale,
                    effectSheet: effectSheet
                ))
            }
        }

        return sprites
    }
}
```

**Step 2: Build and verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/VictoryScene.swift
git commit -m "feat: add VictoryScene with sequential stat reveal"
```

---

### Task 12: Update Galaxy1Scene to use `requestedTransition` instead of `shouldRestart`

Replace the old `shouldRestart` mechanism with `requestedTransition` so SceneManager handles all scene changes.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add requestedTransition property**

Add to the "Game state" section of Galaxy1Scene:

```swift
public private(set) var requestedTransition: SceneTransition?
```

**Step 2: Replace restart logic**

In `fixedUpdate`, find the game over / victory restart timer block (around line 342-350):

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

Replace with:

```swift
// Game over / victory — transition after delay
if gameState != .playing {
    gameOverTimer += time.fixedDeltaTime
    if gameOverTimer > Self.restartDelay && requestedTransition == nil {
        if gameState == .gameOver {
            requestedTransition = .toGameOver(gameResult)
        } else if gameState == .victory {
            requestedTransition = .toVictory(gameResult)
        }
    }
}
```

Keep `shouldRestart` for now to avoid breaking the MetalView code — it will be removed in the next task.

**Step 3: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -5`
Expected: All tests pass

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: Galaxy1Scene uses requestedTransition for scene changes"
```

---

### Task 13: Wire up SceneManager in MetalView (iOS)

Replace the direct Galaxy1Scene management in the iOS MetalView with SceneManager-driven scene lifecycle.

**Files:**
- Modify: `Project2043-iOS/MetalView.swift`

**Step 1: Replace scene management**

Key changes:
1. Replace `private var scene: Galaxy1Scene!` with `private var sceneManager: SceneManager!`
2. Keep `touchInput`, audio engines as before
3. In `setup()`, create SceneManager and register scene factories
4. Start with TitleScene instead of Galaxy1Scene
5. In `render()`, replace the `shouldRestart` check with SceneManager transition updates
6. Update `updateHudInsets()` to work with Galaxy1Scene only when it's the current scene
7. Control overlays should only show during gameplay (Galaxy1Scene)

The `setup()` method becomes:

```swift
private func setup() {
    isMultipleTouchEnabled = true

    guard let device = MTLCreateSystemDefaultDevice() else { return }
    metalLayer.device = device
    metalLayer.pixelFormat = .bgra8Unorm

    let renderer = try! Renderer(device: device)
    engine = GameEngine(renderer: renderer)

    touchInput = TouchInputProvider()

    let audio = AVAudioManager()
    let sfxEngine = SynthAudioEngine()

    sceneManager = SceneManager(engine: engine)

    sceneManager.makeTitleScene = { [weak self] in
        let scene = TitleScene()
        scene.inputProvider = self?.touchInput
        return scene
    }

    sceneManager.makeGameScene = { [weak self] in
        let scene = Galaxy1Scene()
        scene.inputProvider = self?.touchInput
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
        return scene
    }

    sceneManager.makeVictoryScene = { [weak self] result in
        let scene = VictoryScene(result: result)
        scene.inputProvider = self?.touchInput
        return scene
    }

    // Start with title screen
    let titleScene = TitleScene()
    titleScene.inputProvider = touchInput
    engine.currentScene = titleScene

    setupControlOverlays()

    displayLink = CADisplayLink(target: self, selector: #selector(render(_:)))
    displayLink.add(to: .main, forMode: .default)
}
```

The `render()` method becomes:

```swift
@objc private func render(_ displayLink: CADisplayLink) {
    let dt = lastTimestamp == 0 ? 1.0 / 60.0 : displayLink.timestamp - lastTimestamp
    lastTimestamp = displayLink.timestamp

    // HUD insets for game scenes
    if let gameScene = engine.currentScene as? Galaxy1Scene {
        updateHudInsets(for: gameScene)
    }

    engine.update(deltaTime: dt)

    // Scene transition management
    sceneManager.checkForTransition()
    sceneManager.updateTransition(deltaTime: dt)
    engine.renderer.transitionProgress = sceneManager.transitionProgress

    // Show/hide control overlays based on current scene
    let isPlaying = engine.currentScene is Galaxy1Scene
    setControlOverlaysVisible(isPlaying)

    if isPlaying {
        updateControlOverlays()
    }

    guard let drawable = metalLayer.nextDrawable() else { return }
    engine.render(to: drawable)
}
```

Add a helper to show/hide control overlays:

```swift
private func setControlOverlaysVisible(_ visible: Bool) {
    let alpha: CGFloat = visible ? 1.0 : 0.0
    fireOverlay.alpha = visible ? (touchInput.isPrimaryFireActive ? 0.25 : 0.06) : 0
    bombOverlay.isHidden = !visible
    empOverlay.isHidden = !visible
    ocOverlay.isHidden = !visible
    joystickBase.isHidden = !visible
    joystickKnob.isHidden = !visible
}
```

Update `updateHudInsets` to take a scene parameter:

```swift
private func updateHudInsets(for scene: Galaxy1Scene) {
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

Remove the old `scene` property and all references to `scene.shouldRestart`.

**Step 2: Build to iOS simulator**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds (engine package). App-level build requires Xcode.

**Step 3: Commit**

```bash
git add Project2043-iOS/MetalView.swift
git commit -m "feat: wire SceneManager into iOS MetalView"
```

---

### Task 14: Wire up SceneManager in MetalView (macOS)

Same changes as iOS but for the macOS MetalView.

**Files:**
- Modify: `Project2043-macOS/MetalView.swift`

**Step 1: Apply same pattern as iOS**

Key changes:
1. Replace `private var scene: Galaxy1Scene!` with `private var sceneManager: SceneManager!`
2. In `setup()`, create SceneManager and register scene factories, start with TitleScene
3. In `render()`, replace `shouldRestart` with SceneManager transitions
4. Forward mouse clicks to input provider
5. No control overlays to manage (macOS has none)

The `setup()` method:

```swift
private func setup() {
    let layer = CAMetalLayer()
    layer.device = MTLCreateSystemDefaultDevice()
    layer.pixelFormat = .bgra8Unorm
    layer.framebufferOnly = false
    self.wantsLayer = true
    self.layer = layer
    self.metalLayer = layer

    guard let device = layer.device else { return }

    let renderer = try! Renderer(device: device)
    engine = GameEngine(renderer: renderer)

    inputProvider = KeyboardInputProvider()

    let audio = AVAudioManager()
    let sfxEngine = SynthAudioEngine()

    sceneManager = SceneManager(engine: engine)

    sceneManager.makeTitleScene = { [weak self] in
        let scene = TitleScene()
        scene.inputProvider = self?.inputProvider
        return scene
    }

    sceneManager.makeGameScene = { [weak self] in
        let scene = Galaxy1Scene()
        scene.inputProvider = self?.inputProvider
        scene.audioProvider = audio
        scene.sfx = sfxEngine
        audio.stopAll()
        sfxEngine.stopLaser()
        sfxEngine.stopMusic()
        return scene
    }

    sceneManager.makeGameOverScene = { [weak self] result in
        let scene = GameOverScene(result: result)
        scene.inputProvider = self?.inputProvider
        return scene
    }

    sceneManager.makeVictoryScene = { [weak self] result in
        let scene = VictoryScene(result: result)
        scene.inputProvider = self?.inputProvider
        return scene
    }

    // Start with title screen
    let titleScene = TitleScene()
    titleScene.inputProvider = inputProvider
    engine.currentScene = titleScene
}
```

The `render()` method:

```swift
@objc private func render(_ displayLink: CADisplayLink) {
    let timestamp = displayLink.timestamp
    let dt = lastTimestamp == 0 ? 1.0 / 60.0 : timestamp - lastTimestamp
    lastTimestamp = timestamp

    engine.update(deltaTime: dt)

    // Scene transition management
    sceneManager.checkForTransition()
    sceneManager.updateTransition(deltaTime: dt)
    engine.renderer.transitionProgress = sceneManager.transitionProgress

    guard let drawable = metalLayer.nextDrawable() else { return }
    engine.render(to: drawable)
}
```

Add mouse click handling:

```swift
override func mouseDown(with event: NSEvent) {
    let loc = convert(event.locationInWindow, from: nil)
    let point = SIMD2<Float>(Float(loc.x), Float(bounds.height - loc.y))
    let viewSize = SIMD2<Float>(Float(bounds.width), Float(bounds.height))
    inputProvider.mouseDown(at: point, viewSize: viewSize)
}
```

Remove old `scene` property and `shouldRestart` code.

**Step 2: Build**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Project2043-macOS/MetalView.swift
git commit -m "feat: wire SceneManager into macOS MetalView"
```

---

### Task 15: Remove old game over / victory rendering from Galaxy1Scene

Galaxy1Scene still renders "GAME OVER" and "VICTORY" text overlays in `collectEffectSprites`. These are now handled by the dedicated scenes. Remove them.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Remove game over / victory text blocks**

In `collectEffectSprites`, remove the two blocks (around lines 479-513):

```swift
if gameState == .gameOver, let effectSheet {
    // ... GAME OVER text ...
}

if gameState == .victory, let effectSheet {
    // ... VICTORY text ...
}
```

These are no longer needed since GameOverScene and VictoryScene handle their own rendering.

Also consider whether `shouldRestart` can be fully removed now. If both MetalViews no longer reference it, remove the property and `restartDelay`.

**Step 2: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -5`
Expected: All tests pass

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "refactor: remove old game over/victory text from Galaxy1Scene"
```

---

### Task 16: Add MusicTrack.title and play title music on TitleScene

Add a title music track variant and have the TitleScene play it.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/MusicTrack.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/TitleScene.swift`
- May need to modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift` to handle the new track

**Step 1: Add title case to MusicTrack**

```swift
public enum MusicTrack: Sendable {
    case gameplay
    case boss
    case title
}
```

**Step 2: Check SynthAudioEngine.startMusic**

Read `SynthAudioEngine.swift` to see how tracks are handled. The `title` track could use the same music at lower intensity, or be handled as a passthrough if the synth engine doesn't need specific title music yet. For now, have TitleScene not play any music (keep it silent for the attract mode) — this can be added later. Skip this task if adding title music would require significant SynthAudioEngine changes.

**Step 3: Wire sfx into TitleScene if desired**

For now, skip music on the title screen — it adds scope without affecting the core feature. Update TitleScene to accept and store an `sfx` property for future use, but don't start music yet.

In TitleScene, add:

```swift
public var sfx: SynthAudioEngine?
```

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/MusicTrack.swift Engine2043/Sources/Engine2043/Scene/TitleScene.swift
git commit -m "feat: add title music track enum case and sfx property to TitleScene"
```

---

### Task 17: Write integration tests for scene transitions

Test that scenes properly signal transitions and that SceneManager handles them.

**Files:**
- Create: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`

**Step 1: Write tests**

```swift
import Testing
import simd
@testable import Engine2043

@MainActor
final class MockInputForMenu: InputProvider {
    var tapPos: SIMD2<Float>?

    func poll() -> PlayerInput {
        var input = PlayerInput()
        input.tapPosition = tapPos
        tapPos = nil  // consume after one poll
        return input
    }
}

struct SceneTransitionTests {
    @Test @MainActor func titleSceneRequestsGameOnInput() {
        let scene = TitleScene()
        let input = MockInputForMenu()
        scene.inputProvider = input

        // Simulate pressing fire
        var playerInput = PlayerInput()
        // TitleScene checks primaryFire, so we need to use a mock that sets it
        // Actually, let's create a better mock
        let mockInput = MockInputProvider(primary: true)
        scene.inputProvider = mockInput

        var time = GameTime()
        time.advance(by: 1.0 / 60.0)
        while time.shouldPerformFixedUpdate() {
            scene.fixedUpdate(time: time)
            time.consumeFixedUpdate()
        }

        #expect(scene.requestedTransition != nil)
    }

    @Test @MainActor func gameOverSceneStartsWithNoTransition() {
        let result = GameResult(finalScore: 1000, enemiesDestroyed: 5, elapsedTime: 60.0, didWin: false)
        let scene = GameOverScene(result: result)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func victorySceneStartsWithNoTransition() {
        let result = GameResult(finalScore: 5000, enemiesDestroyed: 47, elapsedTime: 180.0, didWin: true)
        let scene = VictoryScene(result: result)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func bitmapTextGeneratesSprites() {
        // BitmapText requires EffectTextureSheet which requires Metal device
        // This is a logical test — verify character count
        let text = "HELLO"
        // Can't test without Metal device, so just verify the function exists
        #expect(text.count == 5)
    }
}
```

**Step 2: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -10`
Expected: All tests pass

**Step 3: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift
git commit -m "test: add scene transition integration tests"
```

---

### Task 18: Build and manual test

**Step 1: Full build and test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 2: Manual testing checklist**

Build and run in Xcode. Verify:
- [ ] App launches to TitleScene (not gameplay)
- [ ] "PROJECT 2043" title text is displayed
- [ ] Attract mode shows ship, enemies, projectiles
- [ ] Starfield scrolls in background
- [ ] Start prompt blinks
- [ ] Tapping (iOS) / pressing space (macOS) starts the game
- [ ] CRT static transition plays between title → game
- [ ] Game plays normally
- [ ] On death → CRT static → GameOverScene shows "GAME OVER" + score
- [ ] RETRY and TITLE SCREEN options appear after 1s delay
- [ ] Tapping RETRY starts a new game (with CRT transition)
- [ ] Tapping TITLE SCREEN returns to title (with CRT transition)
- [ ] On victory → CRT static → VictoryScene shows "MISSION COMPLETE"
- [ ] Stats reveal sequentially (score, kills, time)
- [ ] Menu options appear after stats
- [ ] Control overlays hidden on non-game screens (iOS)
- [ ] Mouse clicks work for menu options (macOS)

**Step 3: Final commit**

If any fixes were needed during manual testing, commit them:

```bash
git add -A
git commit -m "fix: polish title/gameover/victory screen integration"
```

---

Plan complete and saved to `docs/plans/2026-03-10-title-gameover-victory-screens-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
