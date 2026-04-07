# Galaxy 2: The Kay'Shara Expanse

## Goal

Implement Galaxy 2 — the Kay'Shara Expanse — as the second playable sector. After the Galaxy 1 boss falls, gameplay continues seamlessly into Galaxy 2 with asteroid environmental hazards, three new enemy tiers, a multi-phase sector boss (the Lithic Harvester), galaxy title cards, a distinct background aesthetic, and a new music track. Player state carries over per the spec (weapon, score, shields, conditional secondary charges, full energy reset).

## Architecture Summary

The engine uses a scene-based architecture with an ECS (GameplayKit `GKEntity` + components). `Galaxy1Scene` is the primary gameplay scene — it owns all systems, entity arrays, and the game loop. `SpawnDirector` triggers waves by scroll distance. `CollisionSystem` uses a quad-tree for broadphase. `CollisionResponseHandler` dispatches collision pairs via a `CollisionContext` protocol. `SceneManager` handles scene transitions via factory closures registered by platform-specific `MetalView`. `BackgroundSystem` scrolls stars/nebulae and tracks `scrollDistance`. Sprites are procedurally generated in `SpriteFactory` and packed into `TextureAtlas` (512×512) and `EffectTextureSheet` (256×256). Music is loaded from MP3s via `AudioEngine` (bundled in `Engine2043/Sources/Engine2043/Audio/Music/`). `CollisionLayer` is a `UInt8` `OptionSet` with all 8 bits used — must widen to `UInt16` to add the asteroid layer.

## Tech Stack

- **Language:** Swift 6.0
- **Frameworks:** Metal, GameplayKit, AVFoundation, simd
- **Structure:** SPM package (`Engine2043`) + xcodegen Xcode project (`project.yml`) with iOS and macOS targets
- **Testing:** Swift Testing (`import Testing`, `@Test`, `#expect`)
- **Min deployment:** macOS 15, iOS 18

## File Structure

```
- Engine2043/Sources/Engine2043/ECS/Entity.swift (Modify) — Widen CollisionLayer to UInt16, add .asteroid layer
- Engine2043/Sources/Engine2043/Core/GameConfig.swift (Modify) — Add Galaxy2 namespace with enemy stats, asteroid config, boss config, palette
- Engine2043/Sources/Engine2043/ECS/Components/AsteroidComponent.swift (Create) — Component marking an entity as an asteroid (size enum, destructibility, HP)
- Engine2043/Sources/Engine2043/ECS/Systems/AsteroidSystem.swift (Create) — Owns asteroid entity lifecycle: spawning (via explicit API), scrolling, rendering, removal
- Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift (Modify) — Refactor to accept galaxy wave/drop tables; add Galaxy 2 waves, asteroid field triggers, and pendingAsteroidFields
- Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift (Modify) — Accept palette config for Galaxy 2 colors; add parallax asteroid layer rendering
- Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift (Create) — Component for Lithic Harvester armor slot state (attached asteroid entity refs, coverage arcs)
- Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift (Modify) — Add Lithic Harvester phase logic: tractor beams, armor management, fragment attacks, predictive bursts
- Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift (Modify) — Add asteroid collision rules (player→asteroid, projectile→asteroid, laser→asteroid)
- Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift (Create) — Galaxy 2 gameplay scene (parallels Galaxy1Scene), wires asteroid system, G2 spawn director, G2 background, G2 boss
- Engine2043/Sources/Engine2043/Scene/SceneTransition.swift (Modify) — Add .toGalaxy2(PlayerCarryover) transition case
- Engine2043/Sources/Engine2043/Scene/SceneManager.swift (Modify) — Add makeGalaxy2Scene factory, handle .toGalaxy2 transition
- Engine2043/Sources/Engine2043/Scene/PlayerCarryover.swift (Create) — Struct capturing player state for galaxy transitions
- Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift (Modify) — On boss defeat, transition to Galaxy 2 instead of victory; extract title card overlay
- Engine2043/Sources/Engine2043/Scene/GalaxyTitleCard.swift (Create) — Reusable title card state machine (fade in text, hold, fade out, callback)
- Engine2043/Sources/Engine2043/Audio/MusicTrack.swift (Modify) — Add .galaxy2 case mapping to "gameplay - g2" filename
- Engine2043/Sources/Engine2043/Audio/AudioEngine.swift (Modify) — Load galaxy2 music buffer at init
- Engine2043/Sources/Engine2043/Audio/SFXType.swift (Modify) — Add asteroid SFX types (.asteroidHit, .asteroidDestroyed, .tractorBeam)
- Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift (Modify) — Add asteroid sprites (small + large), mining barge hull, mining barge turret, Lithic Harvester core, tractor beam segment
- Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift (Modify) — Register new Galaxy 2 sprite entries in layout and generators
- Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift (Modify) — Add tractor beam effect sprite
- Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift (Modify) — Add per-scene clear color support for Galaxy 2 background
- Project2043-iOS/MetalView.swift (Modify) — Add makeGalaxy2Scene factory closure in scene manager setup
- Project2043-macOS/MetalView.swift (Modify) — Add makeGalaxy2Scene factory closure in scene manager setup
- Engine2043/Tests/Engine2043Tests/AsteroidSystemTests.swift (Create) — Tests for asteroid spawning, scrolling, destruction, collision rules
- Engine2043/Tests/Engine2043Tests/Galaxy2SpawnDirectorTests.swift (Create) — Tests for Galaxy 2 wave progression and asteroid field triggers
- Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift (Create) — Integration tests for Galaxy 2 scene lifecycle, player carryover, title card
- Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift (Create) — Tests for boss armor mechanics, phase transitions, tractor beam behavior
- Engine2043/Tests/Engine2043Tests/CollisionLayerTests.swift (Create) — Tests verifying UInt16 migration didn't break existing layers, asteroid layer works
```

**Source:** `TODO-c1b6ad2a`

## Tasks

### Task 1: Widen CollisionLayer to UInt16 and Add Asteroid Layer

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Entity.swift`
- Create: `Engine2043/Tests/Engine2043Tests/CollisionLayerTests.swift`

**Steps:**
- [ ] **Step 1: Widen CollisionLayer rawValue** — In `Entity.swift`, change `CollisionLayer`'s `rawValue` type from `UInt8` to `UInt16` and update the `init(rawValue:)` signature. All existing bit definitions (`1 << 0` through `1 << 7`) remain unchanged. Add `public static let asteroid = CollisionLayer(rawValue: 1 << 8)`.
- [ ] **Step 2: Write collision layer tests** — Create `CollisionLayerTests.swift`. Test that all existing layers retain their raw values (player=1, playerProjectile=2, enemy=4, etc.), that `.asteroid` has rawValue 256 (`1 << 8`), that OptionSet intersection/union still works across old and new layers, and that `.asteroid` can coexist with existing layers in a mask.
- [ ] **Step 3: Run tests** — Run `swift test` from the `Engine2043` directory. Verify all existing tests still pass (the UInt8→UInt16 change is source-compatible since all usages go through the OptionSet API, not raw values directly).

**Acceptance criteria:**
- `CollisionLayer.rawValue` is `UInt16`
- `CollisionLayer.asteroid` exists with rawValue `1 << 8`
- All existing tests pass without modification
- New collision layer tests pass

**Model recommendation:** cheap

---

### Task 2: Galaxy 2 Config, Carryover Struct, and Music Track

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift`
- Create: `Engine2043/Sources/Engine2043/Scene/PlayerCarryover.swift`
- Modify: `Engine2043/Sources/Engine2043/Audio/MusicTrack.swift`
- Modify: `Engine2043/Sources/Engine2043/Audio/AudioEngine.swift`
- Modify: `Engine2043/Sources/Engine2043/Audio/SFXType.swift`

**Steps:**
- [ ] **Step 1: Add Galaxy2 config namespace** — In `GameConfig.swift`, add `public enum Galaxy2` with nested enums:
  - `Enemy`: `tier1HP: Float = 1.0`, `tier1Size = SIMD2<Float>(20, 20)` (smaller hitbox than G1's 24×24), `tier2HP: Float = 2.5`, `tier2Size = SIMD2<Float>(32, 32)`, `tier2Speed: Float = 70`, `tier3HullSize = SIMD2<Float>(216, 100)` (60% of 360 design width), `tier3TurretHP: Float = 3.5`, `tier3TurretSize = SIMD2<Float>(20, 20)`, `bossHP: Float = 100`, `bossSize = SIMD2<Float>(100, 100)`, `bossArmorSlots: Int = 6`, `bossArmorSlotHP: Float = 4.0`
  - `Asteroid`: `smallSize = SIMD2<Float>(16, 16)`, `largeSize = SIMD2<Float>(40, 40)`, `smallHP: Float = 2.5`, `scrollSpeed: Float = 30` (parallax with background), `collisionDamage: Float = 18` (15-20 range), `sparseCount: Int = 8`, `denseFieldCount: Int = 12`, `denseFieldLargeFraction: Float = 0.3`
  - `Score`: `g2Tier1 = 15`, `g2Tier2 = 75`, `g2Tier3Turret = 150`, `g2Boss = 1000`, `asteroidSmall = 5`
  - `Palette`: `g2Background = SIMD4<Float>(30.0/255.0, 10.0/255.0, 50.0/255.0, 1.0)` (deep bruised violet), `g2Midground = SIMD4<Float>(80.0/255.0, 20.0/255.0, 60.0/255.0, 1.0)` (dark magenta), `g2AsteroidSmall = SIMD4<Float>(0.5, 0.4, 0.35, 1.0)`, `g2AsteroidLarge = SIMD4<Float>(0.35, 0.3, 0.25, 1.0)`, `g2Tier1 = SIMD4<Float>(0.8, 0.5, 0.6, 1.0)`, `g2Tier2 = SIMD4<Float>(0.7, 0.4, 0.8, 1.0)`, `g2BossCore = SIMD4<Float>(0.9, 0.3, 0.5, 1.0)`, `g2TractorBeam = SIMD4<Float>(0.4, 0.8, 1.0, 0.6)`
- [ ] **Step 2: Create PlayerCarryover struct** — Create `PlayerCarryover.swift` with:
  ```swift
  public struct PlayerCarryover: Sendable {
      public let weaponType: WeaponType
      public let score: Int
      public let secondaryCharges: Int
      public let shieldDroneCount: Int
      public let enemiesDestroyed: Int
      public let elapsedTime: Double
  }
  ```
  This captures all state that transfers between galaxies. Energy is always reset to 100 by the receiving scene.
- [ ] **Step 3: Add Galaxy 2 music tracks** — In `MusicTrack.swift`, add `.galaxy2` and `.galaxy2Boss` cases. Their filenames should return `"g2 - gameplay"` and `"g2 - boss"` respectively (matching the existing `g2 - gameplay.mp3` and `g2 - boss.mp3` files in `Audio/Music/`). In `AudioEngine.swift`, add `.galaxy2` and `.galaxy2Boss` to the `loadMusicBuffers()` loop alongside `.gameplay` and `.boss`.
- [ ] **Step 4: Add asteroid SFX types** — In `SFXType.swift`, add `case asteroidHit`, `case asteroidDestroyed`, `case tractorBeam`. In `AudioEngine.swift`'s `synthesizeAllBuffers()`, add synthesis for these:
  - `.asteroidHit`: 0.04s, noise burst mixed with low square sweep (100→80 Hz)
  - `.asteroidDestroyed`: 0.15s, explosion generator (100→40 Hz) — rocky crumble
  - `.tractorBeam`: 0.08s, sine sweep (200→400 Hz) — energy whine
- [ ] **Step 5: Run tests** — Run `swift test` to verify all existing tests still pass.

**Acceptance criteria:**
- `GameConfig.Galaxy2` namespace exists with all sub-enums
- Galaxy 2 Tier 2 HP is 2.5 (matching spec's 2.0–2.5 range)
- `PlayerCarryover` struct compiles and is `Sendable`
- `MusicTrack.galaxy2` maps to `"g2 - gameplay"` filename, `.galaxy2Boss` maps to `"g2 - boss"`
- Three new SFX types exist with synthesized buffers
- All existing tests pass

**Model recommendation:** cheap

---

### Task 3: AsteroidComponent and AsteroidSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/AsteroidComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/AsteroidSystem.swift`
- Create: `Engine2043/Tests/Engine2043Tests/AsteroidSystemTests.swift`

**Steps:**
- [ ] **Step 1: Create AsteroidComponent** — Create `AsteroidComponent.swift`:
  ```swift
  import GameplayKit

  public enum AsteroidSize: Sendable {
      case small  // destructible
      case large  // indestructible
  }

  public final class AsteroidComponent: GKComponent {
      public var asteroidSize: AsteroidSize = .small
      public var isDestructible: Bool { asteroidSize == .small }

      public override init() { super.init() }

      public convenience init(size: AsteroidSize) {
          self.init()
          self.asteroidSize = size
      }

      required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
  }
  ```
- [ ] **Step 2: Create AsteroidSystem** — Create `AsteroidSystem.swift`. This system owns asteroid entity lifecycle. It does NOT own scheduling (that's the SpawnDirector's job). Key API:
  ```swift
  @MainActor
  public final class AsteroidSystem {
      private var entities: [GKEntity] = []
      public private(set) var pendingRemovals: [GKEntity] = []

      // Called by the scene when SpawnDirector emits a pendingAsteroidField
      public func spawnField(count: Int, largeFraction: Float, spawnYBase: Float,
                              viewportHalfWidth: Float) -> [GKEntity]
      // Spawn sparse background asteroids (called once at scene init)
      public func spawnSparseLayer(count: Int, viewportHalfWidth: Float,
                                    fieldHeight: Float) -> [GKEntity]

      public func register(_ entity: GKEntity)
      public func unregister(_ entity: GKEntity)
      public func update(deltaTime: Double)  // scrolls asteroids, checks off-screen removal
  }
  ```
  - `spawnField` creates `count` asteroid entities. Each is randomly small or large (large probability = `largeFraction`). Positions are random X within viewport width, Y spread from `spawnYBase` to `spawnYBase + 200`. Returns the new entities (scene is responsible for registerEntity).
  - `spawnSparseLayer` creates ambient asteroids scattered across the full viewport height. These are pre-placed (not triggered by scroll distance).
  - `update` scrolls all registered asteroids downward at `GameConfig.Galaxy2.Asteroid.scrollSpeed`, adds off-screen asteroids to `pendingRemovals`.
  - Each spawned entity gets: `TransformComponent`, `PhysicsComponent` (layer: `.asteroid`, mask: `[.player, .playerProjectile]`), `RenderComponent`, `AsteroidComponent`, and if small: `HealthComponent(health: GameConfig.Galaxy2.Asteroid.smallHP)` + `ScoreComponent(points: GameConfig.Galaxy2.Score.asteroidSmall)`.
  - Large asteroids: no `HealthComponent` (indestructible), no `ScoreComponent`.
- [ ] **Step 3: Write AsteroidSystem tests** — Create `AsteroidSystemTests.swift`:
  - Test `spawnField` returns correct count of entities with correct components
  - Test large fraction: spawn 100 asteroids with `largeFraction: 0.5`, verify roughly half are large (±20%)
  - Test small asteroids have HealthComponent with correct HP
  - Test large asteroids have no HealthComponent
  - Test `update` moves asteroids downward
  - Test `update` adds off-screen asteroids to `pendingRemovals`
  - Test all spawned entities have `.asteroid` collision layer
- [ ] **Step 4: Run tests** — Run `swift test`, verify new and existing tests pass.

**Acceptance criteria:**
- `AsteroidComponent` exists with `AsteroidSize` enum
- `AsteroidSystem.spawnField()` creates entities with correct components
- `AsteroidSystem.spawnSparseLayer()` creates ambient asteroid entities
- `AsteroidSystem.update()` scrolls and removes off-screen asteroids
- Small asteroids are destructible (have HealthComponent), large are not
- All asteroids use `.asteroid` collision layer
- Tests pass

**Model recommendation:** standard

---

### Task 4: Asteroid Collision Rules in CollisionResponseHandler

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/CollisionResponseHandlerTests.swift`

**Steps:**
- [ ] **Step 1: Extend CollisionContext** — Add `var asteroidSystem: AsteroidSystem? { get }` to the `CollisionContext` protocol with a default extension returning `nil` (Galaxy1Scene won't have one; Galaxy2Scene will). This keeps Galaxy1Scene unchanged.
- [ ] **Step 2: Add asteroid collision branches** — In `processCollisions(pairs:)`, add handling for asteroid collisions. These must be checked BEFORE the existing projectile/enemy branches since asteroids use `.asteroid` layer which is distinct from `.enemy`:
  - **playerProjectile → asteroid**: If the asteroid has `HealthComponent` (small/destructible), deal `GameConfig.Player.damage` to it. If destroyed: play `.asteroidDestroyed`, add score, add to `pendingRemovals`. If damaged but alive: play `.asteroidHit`. Always remove the projectile (asteroids block player projectiles).
  - **player → asteroid**: Deal `GameConfig.Galaxy2.Asteroid.collisionDamage` to the player. Play `.playerDamaged`. Do NOT destroy the asteroid (even small ones survive player collision — player bounces off).
  - Enemy projectiles do NOT collide with asteroids (per spec: "Do NOT block enemy energy weapons"). This is enforced by the asteroid's collision mask `[.player, .playerProjectile]` which excludes `.enemyProjectile`.
- [ ] **Step 3: Update processLaserHitscan for asteroids** — Note: `processLaserHitscan` is in the scene, not in `CollisionResponseHandler`. The scene's `processLaserHitscan` will need to iterate asteroids in Galaxy2Scene (handled in Task 8). In this task, just add a `NOTE:` comment in the CollisionResponseHandler explaining that Phase Laser vs asteroid is handled by the scene's hitscan method, not by collision pairs.
- [ ] **Step 4: Write collision handler tests** — In `CollisionResponseHandlerTests.swift`, add tests:
  - Player projectile hitting a small asteroid: asteroid takes damage, projectile removed
  - Player projectile destroying a small asteroid: asteroid removed, score added, SFX played
  - Player colliding with asteroid: player takes collisionDamage
  - Player projectile hitting a large (indestructible) asteroid: projectile removed, asteroid NOT removed
- [ ] **Step 5: Run tests** — `swift test`, verify all pass.

**Acceptance criteria:**
- Player projectiles are absorbed by asteroids (removed on contact)
- Small asteroids take damage and can be destroyed
- Large asteroids are indestructible (no HealthComponent means no damage path)
- Player takes kinetic damage from asteroid collision (18 energy)
- Enemy projectiles pass through asteroids (no collision path)
- Existing collision behavior unchanged for non-asteroid entities
- Tests pass

**Model recommendation:** standard

---

### Task 5: Galaxy 2 SpawnDirector Waves and Asteroid Field Triggers

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift`
- Create: `Engine2043/Tests/Engine2043Tests/Galaxy2SpawnDirectorTests.swift`

**Steps:**
- [ ] **Step 1: Add AsteroidFieldDefinition struct** — In `SpawnDirector.swift`, add:
  ```swift
  public struct AsteroidFieldDefinition: Sendable {
      public let triggerDistance: Float
      public let count: Int
      public let largeFraction: Float
  }
  ```
- [ ] **Step 2: Refactor SpawnDirector to accept galaxy config** — Change `SpawnDirector.init()` to accept an enum or to support a `configure(galaxy:)` method. The simplest approach matching codebase patterns: add an `init(galaxy: GalaxyConfig)` where `GalaxyConfig` is an enum:
  ```swift
  public enum GalaxyConfig: Sendable {
      case galaxy1
      case galaxy2
  }
  ```
  Internally, switch on the config to set `waves`, `scriptedDrops`, and a new `asteroidFields: [AsteroidFieldDefinition]` array (empty for galaxy1). Keep the existing `init()` as `init() { self.init(galaxy: .galaxy1) }` for backward compatibility.
- [ ] **Step 3: Add pendingAsteroidFields output** — Add `public private(set) var pendingAsteroidFields: [AsteroidFieldDefinition] = []`. In `update(scrollDistance:)`, process the `asteroidFields` array the same way waves and drops are processed: check trigger distance, append to pending, advance index.
- [ ] **Step 4: Define Galaxy 2 wave tables** — Add `private static func galaxy2Waves() -> [WaveDefinition]`:
  - Scroll distances 50–500: Tier 1 waves (smaller hitbox interceptors) with sine waves and V-shapes
  - 500–1200: Mix of Tier 1 and Tier 2 (smarter fighters, HP 2.5)
  - 1200–1600: Tier 3 mining barges with Tier 1 escort waves
  - 1700–2200: Final gauntlet with mixed Tier 1/2
  - 2400: Boss wave
  Add `private static func galaxy2ScriptedDrops() -> [ScriptedDrop]` with weapon module drops at 600 and 1400.
  Add `private static func galaxy2AsteroidFields() -> [AsteroidFieldDefinition]` with dense fields at: 200, 600, 1000, 1500, 1900 (5 asteroid field events spread across the level).
- [ ] **Step 5: Write Galaxy 2 SpawnDirector tests** — Create `Galaxy2SpawnDirectorTests.swift`:
  - Test Galaxy 2 director triggers tier 1 waves at early scroll distances
  - Test Galaxy 2 director triggers asteroid fields at defined distances
  - Test `pendingAsteroidFields` is populated correctly and cleared between updates
  - Test Galaxy 2 director triggers boss at final scroll distance
  - Test Galaxy 1 director has empty asteroid fields (backward compat)
  - Test Galaxy 2 has all 4 tiers represented
- [ ] **Step 6: Run tests** — `swift test`, verify all pass including existing `SpawnDirectorTests`.

**Acceptance criteria:**
- `SpawnDirector` supports both galaxy configs
- Galaxy 2 waves include tiers 1–3 + boss with appropriate scroll distances
- `pendingAsteroidFields` emitted at defined trigger distances
- Galaxy 1 behavior is unchanged (backward compatible default init)
- All SpawnDirector tests pass (old and new)

**Model recommendation:** standard

---

### Task 6: Galaxy 2 Background and Galaxy Title Card

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift`
- Create: `Engine2043/Sources/Engine2043/Scene/GalaxyTitleCard.swift`

**Steps:**
- [ ] **Step 1: Parameterize BackgroundSystem colors** — Add a `public struct BackgroundPalette` to `BackgroundSystem.swift`:
  ```swift
  public struct BackgroundPalette: Sendable {
      public let starColor: SIMD4<Float>
      public let nebulaColor: SIMD4<Float>

      public static let galaxy1 = BackgroundPalette(
          starColor: SIMD4<Float>(0.6, 0.7, 0.9, 0.5),
          nebulaColor: SIMD4<Float>(
              GameConfig.Palette.midground.x,
              GameConfig.Palette.midground.y,
              GameConfig.Palette.midground.z,
              0.15
          )
      )

      public static let galaxy2 = BackgroundPalette(
          starColor: SIMD4<Float>(0.7, 0.5, 0.6, 0.4),
          nebulaColor: SIMD4<Float>(
              GameConfig.Galaxy2.Palette.g2Midground.x,
              GameConfig.Galaxy2.Palette.g2Midground.y,
              GameConfig.Galaxy2.Palette.g2Midground.z,
              0.2
          )
      )
  }
  ```
  Add `public var palette: BackgroundPalette = .galaxy1` property. In `collectSprites()`, use `palette.starColor` and `palette.nebulaColor` instead of the hardcoded values.
- [ ] **Step 2: Create GalaxyTitleCard** — Create `GalaxyTitleCard.swift`:
  ```swift
  @MainActor
  public final class GalaxyTitleCard {
      public enum Phase { case fadeIn, hold, fadeOut, done }
      public private(set) var phase: Phase = .fadeIn
      public private(set) var alpha: Float = 0

      private let title: String
      private let fadeInDuration: Double = 0.8
      private let holdDuration: Double = 1.5
      private let fadeOutDuration: Double = 0.8
      private var timer: Double = 0

      public var isDone: Bool { phase == .done }

      public init(title: String) { self.title = title }

      public func update(deltaTime: Double) { /* advance timer, transition phases, compute alpha */ }

      public func collectSprites(effectSheet: EffectTextureSheet?) -> [SpriteInstance] {
          // Render title text centered on screen using BitmapText
      }
  }
  ```
  Implement `update` with a simple state machine: fadeIn (0→1 alpha), hold (1 alpha), fadeOut (1→0 alpha), then phase = .done.
  Implement `collectSprites` to return BitmapText sprites for the title string at center-screen, scaled at 3.0, with color `SIMD4(1, 1, 1, alpha)`.
- [ ] **Step 3: Add per-scene clear color to RenderPassPipeline** — In `RenderPassPipeline.swift`, the clear color is currently hardcoded to `GameConfig.Palette.background` (line ~124). Add a `public var clearColor: SIMD4<Float> = GameConfig.Palette.background` property on the pipeline (or on `Renderer` if that's the public-facing type). In the render pass setup, use `self.clearColor` instead of the hardcoded `GameConfig.Palette.background`. Galaxy2Scene will set this to `GameConfig.Galaxy2.Palette.g2Background` at init. Galaxy1Scene continues using the default.
- [ ] **Step 4: Run tests** — `swift test`, verify existing tests still pass (BackgroundSystem color parameterization is source-compatible since the default is `.galaxy1`).

**Acceptance criteria:**
- `BackgroundSystem` accepts a `palette` property; defaults to galaxy1 colors
- Galaxy 2 palette uses bruised violet/dark magenta colors
- `RenderPassPipeline` (or `Renderer`) exposes a `clearColor` property; Galaxy2Scene can set it to the G2 background color
- `GalaxyTitleCard` fades in, holds, fades out, reports `isDone`
- `GalaxyTitleCard.collectSprites` returns text sprites with correct alpha
- Existing tests pass

**Model recommendation:** cheap

---

### Task 7: Galaxy 2 Sprites and Atlas Registration

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/EffectTextureSheet.swift`

**Steps:**
- [ ] **Step 1: Add asteroid sprites to SpriteFactory** — Add two methods:
  - `makeAsteroidSmall() -> (pixels: [UInt8], width: Int, height: Int)`: 16×16, irregular polygon, gray-brown fill with slightly lighter edge highlights. Use `makeContext(width: 16, height: 16)`. Draw a 5-6 sided polygon with random-ish but deterministic vertices (hardcoded offsets, not random at runtime — sprites are baked into atlas).
  - `makeAsteroidLarge() -> (pixels: [UInt8], width: Int, height: Int)`: 40×40, same style but bigger, darker, more angular. Heavier outlines.
- [ ] **Step 2: Add mining barge sprites** — Add:
  - `makeMiningBargeHull() -> (pixels: [UInt8], width: Int, height: Int)`: 108×50 (half of G1's capital hull sprite dimensions, but representing 60% screen width at runtime via RenderComponent size). Dark industrial gray-purple with panel lines and structural detail. Similar approach to `makeCapitalHull`.
  - `makeMiningBargeTurret() -> (pixels: [UInt8], width: Int, height: Int)`: 24×24, similar to existing turret but purple-tinted.
- [ ] **Step 3: Add Lithic Harvester sprites** — Add:
  - `makeLithicHarvesterCore() -> (pixels: [UInt8], width: Int, height: Int)`: 80×80, octagonal core similar to `makeBossCore` but with purple-magenta tones. Heavier armor plating visual. Industrial mining dreadnought aesthetic.
  - `makeTractorBeamSegment() -> (pixels: [UInt8], width: Int, height: Int)`: 4×32, thin cyan-white beam segment for tractor beam rendering.
- [ ] **Step 4: Add G2 tier enemy sprites** — Add:
  - `makeG2Interceptor() -> (pixels: [UInt8], width: Int, height: Int)`: 20×20 (smaller than G1 swarmer's 32×32 sprite). Sleek downward dart, muted pink/violet tones.
  - `makeG2Fighter() -> (pixels: [UInt8], width: Int, height: Int)`: 40×40, hexagonal like bruiser but with violet/magenta tones and extra detail.
- [ ] **Step 5: Register in TextureAtlas** — In `TextureAtlas.swift`:
  - Add new entries to `spriteNames` set: `"asteroidSmall"`, `"asteroidLarge"`, `"miningBargeHull"`, `"miningBargeTurret"`, `"lithicHarvesterCore"`, `"tractorBeamSegment"`, `"g2Interceptor"`, `"g2Fighter"`
  - Add entries to `layout` array. Place them starting at row 212 (after existing row 188 pickups which end at y=212): 
    - `asteroidSmall` at (0, 212, 16, 16)
    - `asteroidLarge` at (16, 212, 40, 40)
    - `g2Interceptor` at (56, 212, 20, 20)
    - `g2Fighter` at (76, 212, 40, 40)
    - `miningBargeHull` at (0, 252, 108, 50)
    - `miningBargeTurret` at (108, 252, 24, 24)
    - `lithicHarvesterCore` at (0, 302, 80, 80)
    - `tractorBeamSegment` at (80, 302, 4, 32)
  - Add corresponding generator entries in the `init(device:)` generators array.
  - Verify all entries fit within 512×512 atlas (row 302 + 80 = 382, within bounds).
- [ ] **Step 6: Add tractor beam effect to EffectTextureSheet** — In `EffectTextureSheet.swift`, add `"tractorBeamGlow"` to `spriteNames`, add a layout entry at a free position (e.g., `(64, 128, 32, 64)`), and add a generator in init. The generator creates a soft cyan gradient glow strip (32×64, fading from center outward). Add to `SpriteFactory` as `makeTractorBeamGlow()`.
- [ ] **Step 7: Run tests** — `swift test`, verify `SpriteFactoryTests` and all existing tests pass.

**Acceptance criteria:**
- All 8 new game sprites + 1 effect sprite are generated by SpriteFactory
- All sprites are registered in TextureAtlas with correct layout positions
- No atlas entries overlap
- All entries fit within 512×512 / 256×256 sheets
- Existing sprite tests pass

**Model recommendation:** standard

---

### Task 8: Galaxy 2 Scene — Core Gameplay Loop

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneTransition.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneManager.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`
- Modify: `Project2043-iOS/MetalView.swift`
- Modify: `Project2043-macOS/MetalView.swift`
- Create: `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift`

**Steps:**
- [ ] **Step 1: Add toGalaxy2 transition** — In `SceneTransition.swift`, add `case toGalaxy2(PlayerCarryover)`. In `SceneManager.swift`, add `public var makeGalaxy2Scene: ((PlayerCarryover) -> any GameScene)?` factory. In `performSceneSwitch()`, add the `.toGalaxy2` case that calls this factory.
- [ ] **Step 2: Modify Galaxy1Scene boss defeat** — In `Galaxy1Scene.swift`, when `bossDyingTimer >= totalBossDeathDuration` (currently sets `gameState = .victory`): instead, build a `PlayerCarryover` from current state and set `requestedTransition = .toGalaxy2(carryover)`. Capture: `weaponType` from player's WeaponComponent, `score` from scoreSystem, `secondaryCharges` (keep if > 1, else reset to 1), `shieldDroneCount` from shieldDrones.count, `enemiesDestroyed`, `elapsedTime`.
- [ ] **Step 3: Add title card to Galaxy1Scene** — Add a `GalaxyTitleCard` instance initialized with `"GALAXY 1: NGC-2043 PERIMETER"`. At the start of `fixedUpdate`, if the title card is not done, update it and skip spawning/gameplay. In `collectEffectSprites`, append the title card's sprites. This means the title card plays before enemies start, then gameplay begins normally.
- [ ] **Step 4: Create Galaxy2Scene** — Create `Galaxy2Scene.swift` following the same structure as `Galaxy1Scene` (implements `GameScene`, owns systems, entity arrays, game loop). Key differences from Galaxy1Scene:
  - Takes `PlayerCarryover` in `init(carryover:)` to restore player state
  - Owns an `AsteroidSystem` instance
  - Uses `SpawnDirector(galaxy: .galaxy2)` 
  - `BackgroundSystem` with `palette = .galaxy2`
  - Has a `GalaxyTitleCard` initialized with `"GALAXY 2: KAY'SHARA EXPANSE"` — plays before gameplay begins
  - Starts music with `.galaxy2` track
  - Implements `CollisionContext` (with `asteroidSystem` returning its instance)
  - In `fixedUpdate`, processes `spawnDirector.pendingAsteroidFields` by calling `asteroidSystem.spawnField()` for each, then registers the returned entities
  - In `fixedUpdate`, calls `asteroidSystem.update()` and processes `asteroidSystem.pendingRemovals`
  - `processLaserHitscan` iterates asteroids in addition to enemies: if Phase Laser beam overlaps a small asteroid, deal laser damage. If destroyed, add to pendingRemovals. Phase Laser does NOT pass through large asteroids — it checks asteroids sorted by Y position (nearest to player first), and stops at the first large asteroid hit. This makes Phase Laser effective at clearing small asteroids but still blocked by large ones.
  - Boss defeat leads to `gameState = .victory` and `requestedTransition = .toVictory(gameResult)` (Galaxy 2 is the final galaxy for now)
  - In `setupPlayer`, restore from carryover: weapon type, score, secondary charges (use carryover value which is already adjusted — if original was <=1, carryover has 1), shield drones, energy = full 100
  - Spawn sparse background asteroids at init via `asteroidSystem.spawnSparseLayer()`
  - `collectSprites` renders asteroids between background and gameplay entities (behind enemies, ahead of background)
- [ ] **Step 5: Wire Galaxy2Scene in platform MetalViews** — In `Project2043-iOS/MetalView.swift`, add:
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
  In the render loop, add `Galaxy2Scene` to the HUD insets check (alongside Galaxy1Scene). Add `Galaxy2Scene` to the `isPlaying` check for control overlay visibility.
  
  In `Project2043-macOS/MetalView.swift`, add the same `makeGalaxy2Scene` factory closure (without touch/control overlay code since macOS uses keyboard input).
- [ ] **Step 6: Write Galaxy2Scene tests** — Create `Galaxy2SceneTests.swift`:
  - Test scene initializes with player from carryover (weapon type preserved, score preserved, energy = 100)
  - Test scene updates without crash (60 frames)
  - Test game state starts as playing
  - Test title card plays before enemies spawn
  - Test asteroid field triggers create asteroid entities
  - Test Phase Laser hitscan damages small asteroids
  - Test Phase Laser hitscan is blocked by large asteroids (beam stops)
  - Test player projectile removed on asteroid contact
- [ ] **Step 7: Run tests** — `swift test`, verify all pass.

**Acceptance criteria:**
- Galaxy1Scene boss defeat transitions to Galaxy2Scene (not victory)
- Galaxy1Scene shows title card "GALAXY 1: NGC-2043 PERIMETER" before gameplay
- Galaxy2Scene receives PlayerCarryover and restores player state correctly
- Galaxy2Scene shows title card "GALAXY 2: KAY'SHARA EXPANSE" before gameplay
- Asteroid fields are spawned when SpawnDirector triggers them
- AsteroidSystem is the single owner of asteroid entity spawning/lifecycle
- SpawnDirector is the single owner of asteroid field timing/scheduling
- Phase Laser interacts with asteroids correctly (damages small, blocked by large)
- Platform MetalViews wire Galaxy2Scene factory (iOS in MetalView.swift, macOS in MetalView.swift)
- Galaxy2Scene uses galaxy2 music track and galaxy2 background palette
- Sparse background asteroids present from scene start
- All tests pass

**Model recommendation:** capable

---

### Task 9: Galaxy 2 Enemy Tiers (Tier 1, 2, 3)

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`

**Steps:**
- [ ] **Step 1: Implement G2 Tier 1 spawning** — Add `spawnG2Tier1Formation(wave:)` in Galaxy2Scene. Same formation logic as Galaxy1Scene's `spawnTier1Formation` but using:
  - `GameConfig.Galaxy2.Enemy.tier1Size` (20×20 — smaller hitbox)
  - `GameConfig.Galaxy2.Enemy.tier1HP` (1.0 — one hit kill)
  - `GameConfig.Galaxy2.Score.g2Tier1` score value
  - `spriteId = "g2Interceptor"`
  - Same formation patterns (vShape, sineWave, staggeredLine)
- [ ] **Step 2: Implement G2 Tier 2 spawning** — Add `spawnG2Tier2Group(wave:)`. Similar to Galaxy1Scene's `spawnTier2Group` but with:
  - `GameConfig.Galaxy2.Enemy.tier2HP` (2.5)
  - `GameConfig.Galaxy2.Enemy.tier2Speed` (70 — faster)
  - `spriteId = "g2Fighter"`
  - `GameConfig.Galaxy2.Score.g2Tier2` score
  - More aggressive steering: use `.leadShot` behavior for all (not alternating hover/strafe). Set `steerStrength = 3.0` (vs Galaxy 1's default 2.0)
  - Faster turret fire: `fireInterval = 1.5` (vs Galaxy 1's 2.0), `projectileSpeed = 300` (vs 250)
- [ ] **Step 3: Implement G2 Tier 3 mining barge** — Add `spawnG2MiningBarge(wave:)`. Similar to Galaxy1Scene's `spawnCapitalShip` but:
  - Hull uses `GameConfig.Galaxy2.Enemy.tier3HullSize` (216×100)
  - `spriteId = "miningBargeHull"` for hull
  - Turrets use `GameConfig.Galaxy2.Enemy.tier3TurretHP` (3.5) and `spriteId = "miningBargeTurret"`
  - `GameConfig.Galaxy2.Score.g2Tier3Turret` score
  - 6 turret mount offsets spread across the wider hull (3 on each side)
  - Turrets have `trackingSpeed = 2.0` (independent player-tracking per spec)
- [ ] **Step 4: Wire processSpawnDirectorWaves** — In Galaxy2Scene's `processSpawnDirectorWaves`, route tiers to the G2 spawn methods.
- [ ] **Step 5: Run tests** — `swift test`, verify all pass.

**Acceptance criteria:**
- G2 Tier 1 enemies have 20×20 hitbox and 1.0 HP
- G2 Tier 2 enemies have 2.5 HP with leadShot steering and faster fire
- G2 Tier 3 mining barges take 60% screen width with 6 destructible turrets
- All tiers use correct G2 sprites and score values
- Tests pass

**Model recommendation:** standard

---

### Task 10: Lithic Harvester Boss — Armor, Tractor Beams, and Attack Patterns

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`
- Create: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

**Steps:**
- [ ] **Step 1: Create BossArmorComponent** — Create `BossArmorComponent.swift`:
  ```swift
  import GameplayKit
  import simd

  public struct ArmorSlot: Sendable {
      public var angle: Float          // position around boss (radians)
      public var entity: GKEntity?     // the asteroid entity acting as armor (nil = gap)
      public var isActive: Bool { entity != nil }
  }

  public final class BossArmorComponent: GKComponent {
      public var slots: [ArmorSlot] = []
      public var tractorBeamTargets: [GKEntity] = []  // asteroids being pulled in
      public var tractorBeamTimer: Double = 0
      public var tractorBeamInterval: Double = 8.0     // seconds between armor rebuilds
      public var armorRadius: Float = 70               // distance from boss center

      public override init() { super.init() }
      required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
  }
  ```
- [ ] **Step 2: Add Lithic Harvester logic to BossSystem** — The existing `BossSystem` handles Galaxy 1's boss. Extend it to support the Lithic Harvester:
  - Add a `public var bossType: BossType = .galaxy1` enum (`galaxy1`, `lithicHarvester`).
  - When `bossType == .lithicHarvester`, use different attack patterns in `generateAttack`:
    - **Phase 0 (HP > 60%)**: Sporadic aimed energy bursts (3 predictive shots toward player, `fireInterval = 2.0`). Tractor beams pull asteroids to fill armor slots.
    - **Phase 1 (HP 30-60%)**: Adds asteroid fragment launches — append additional `ProjectileSpawnRequest` entries with higher speed (400) aimed at player. Tractor beam interval decreases to 5.0s.
    - **Phase 2 (HP < 30%)**: Dense radial energy burst (12 projectiles) + rapid predictive shots. Tractor beam interval 3.0s. Fragment launches every attack cycle.
  - Add `public private(set) var pendingTractorBeamPulls: [(source: SIMD2<Float>, target: GKEntity)] = []` — the scene uses this to render tractor beam visuals and move asteroid entities toward the boss.
  - Add `public private(set) var pendingArmorAttachments: [(slot: Int, entity: GKEntity)] = []` — when a pulled asteroid reaches the boss, it becomes an armor piece.
- [ ] **Step 3: Implement boss armor damage contract** — The key mechanic: **the boss takes no projectile/hitscan damage while an armor slot covers the path**. Implementation:
  - In Galaxy2Scene's `processCollisions`: when a playerProjectile hits the boss entity, check if any active armor slot's angle is within ±30° of the projectile's approach angle. If yes, redirect damage to the armor asteroid entity instead. If the armor asteroid is destroyed, the slot becomes a gap.
  - In Galaxy2Scene's `processLaserHitscan`: when the Phase Laser beam overlaps the boss, check armor slots. The laser damages the first armor piece in its path. Only when the slot is empty (gap) does laser damage reach the boss. Phase Laser is ideal because it can continuously chip away armor.
  - In the `CollisionResponseHandler`, the existing `handleProjectileHitEnemy` for boss entities needs to be intercepted. Add a check: if the enemy has a `BossArmorComponent` with active armor in the projectile's path, damage the armor entity instead and play `asteroidHit` SFX.
- [ ] **Step 4: Wire Lithic Harvester in Galaxy2Scene** — In `spawnBoss()`:
  - Create boss entity with `GameConfig.Galaxy2.Enemy.bossHP` (100), `bossSize` (100×100)
  - `spriteId = "lithicHarvesterCore"`
  - Add `BossArmorComponent` with `bossArmorSlots` (6) slots evenly spaced in a ring
  - Set `bossSystem.bossType = .lithicHarvester`
  - Spawn initial armor asteroids: create 6 small asteroid entities positioned around the boss, attach to armor slots
  - In `fixedUpdate`, process `bossSystem.pendingTractorBeamPulls`: move targeted asteroids toward the boss. When they arrive (distance < armorRadius + 10), attach to empty armor slot.
  - Render tractor beams in `collectSprites`: for each active pull, draw line segments from boss to target asteroid using tractorBeamSegment sprite.
  - Background scroll halts on boss spawn (standard — SpawnDirector sets `shouldLockScroll`)
  - Boss defeat triggers `gameState = .victory`
- [ ] **Step 5: Write Lithic Harvester tests** — Create `LithicHarvesterTests.swift`:
  - Test boss spawns with correct HP and armor slots
  - Test armor slots block projectile damage (projectile hits armor, not boss)
  - Test destroying an armor slot creates a gap
  - Test boss takes damage through gaps in armor
  - Test Phase Laser damages armor first, then boss through gaps
  - Test tractor beam timer triggers armor rebuild attempts
  - Test phase transitions change attack patterns (verify `pendingProjectileSpawns` count changes between phases)
  - Test boss death when HP reaches 0
- [ ] **Step 6: Run tests** — `swift test`, verify all pass.

**Acceptance criteria:**
- Lithic Harvester has 100 HP with 6 armor slots
- Armor blocks projectile and laser damage (redirected to armor entity)
- Destroying armor creates gaps; boss takes damage through gaps
- Phase Laser is effective at clearing armor (continuous damage)
- Tractor beams visually connect boss to target asteroids
- Tractor beams rebuild armor on a timer (8s → 5s → 3s per phase)
- Three attack phases with escalating difficulty
- Boss defeat triggers victory transition
- All tests pass

**Model recommendation:** capable

---

### Task 11: Integration Testing and Polish

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`

**Steps:**
- [ ] **Step 1: Full progression integration test** — Add a test that simulates a complete Galaxy 1 → Galaxy 2 transition:
  - Create Galaxy1Scene, advance until boss spawn (scroll distance > 2150)
  - Kill the boss (set health to 0, advance frames)
  - Verify `requestedTransition` is `.toGalaxy2` with valid carryover
  - Create Galaxy2Scene from the carryover
  - Verify player state is correctly restored
  - Advance several frames to verify no crash
- [ ] **Step 2: Verify asteroid field lifecycle** — Add a test:
  - Create Galaxy2Scene, advance past title card
  - Advance scroll distance past first asteroid field trigger (200)
  - Verify asteroid entities were created
  - Continue advancing until asteroids scroll off-screen
  - Verify they are removed
- [ ] **Step 3: GameOver in Galaxy 2** — Add a test:
  - Create Galaxy2Scene
  - Set player health to 0
  - Advance frames
  - Verify `requestedTransition` is `.toGameOver` with correct game result (score includes G1 carryover)
- [ ] **Step 4: Polish — enemy SFX and visual feedback** — In Galaxy2Scene, ensure:
  - Asteroid destruction plays `.asteroidDestroyed` SFX
  - Asteroid hit plays `.asteroidHit` SFX
  - Tractor beam activation plays `.tractorBeam` SFX
  - Boss phase transitions trigger appropriate audio (reuse `.bossShieldDeflect` for armor hits)
- [ ] **Step 5: Run full test suite** — `swift test`, verify every test passes.

**Acceptance criteria:**
- Galaxy 1 → Galaxy 2 transition works end-to-end
- Player state carries over correctly (weapon, score, shields, charges)
- Asteroid lifecycle works (spawn, scroll, destroy/remove)
- Game over in Galaxy 2 produces correct game result
- All SFX play at appropriate moments
- Full test suite passes with zero failures

**Model recommendation:** standard

## Dependencies

```
- Task 2 depends on: Task 1 (needs UInt16 CollisionLayer for asteroid config references)
- Task 3 depends on: Task 1, Task 2 (needs .asteroid layer and GameConfig.Galaxy2.Asteroid)
- Task 4 depends on: Task 1, Task 2, Task 3 (needs AsteroidComponent for collision type checks)
- Task 5 depends on: Task 2 (needs GalaxyConfig, AsteroidFieldDefinition references GameConfig)
- Task 6 depends on: Task 2 (needs GameConfig.Galaxy2.Palette)
- Task 7 depends on: Task 2 (needs GameConfig references for sprite sizing)
- Task 8 depends on: Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7 (wires everything together)
- Task 9 depends on: Task 8 (modifies Galaxy2Scene)
- Task 10 depends on: Task 3, Task 8 (needs AsteroidSystem for armor, needs Galaxy2Scene)
- Task 11 depends on: Task 8, Task 9, Task 10 (integration tests need all features)
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CollisionLayer UInt16 migration breaks binary compatibility with serialized data | Low | Low | No serialization exists — all state is runtime-only. Change is source-compatible. |
| TextureAtlas 512×512 runs out of space | Low | Medium | Current usage through row ~212. Galaxy 2 sprites fit through row ~382. 130px headroom remains. |
| Galaxy2Scene becomes as large as Galaxy1Scene (~1400 lines) | High | Medium | Acceptable for now — both scenes share the same architectural pattern. Extracting shared code would require protocol/base-class refactoring that's out of scope. |
| Phase Laser armor interaction creates edge cases (beam width vs armor arc) | Medium | Medium | Use simple angle-based check (±30° per slot). Test with explicit geometry in unit tests. |
| Boss armor mechanic feels unfair if player has no Phase Laser | Medium | Low | All weapons can damage armor (it has HP). Phase Laser is just more efficient. Double Cannon and Tri-Spread work, just slower. |
| Existing SpawnDirector tests break with galaxy config refactor | Medium | Low | Default `init()` preserves galaxy1 behavior. Existing tests use default init. |

## Test Command

```bash
cd Engine2043 && swift test
```

## Review Notes

_Added by plan reviewer (v2) — informational, not blocking. All errors from v1 and v2 reviews have been resolved in the plan text above._

### Review v1 (resolved)
- Asteroid field ownership clarified: SpawnDirector owns timing, AsteroidSystem owns spawning
- iOS wiring corrected to MetalView.swift
- Boss armor damage contract fully specified
- Tier 2 HP corrected to 2.5
- Cross-task Phase Laser reference corrected to Task 8

### Review v2 (resolved)
- Music filename corrected to `"g2 - gameplay"` and `"g2 - boss"` matching on-disk assets
- `CollisionResponseHandler.swift` added to Task 10 file list
- Per-scene clear color support added to Task 6 via `RenderPassPipeline.swift`
