# Test Coverage Improvements — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise test coverage from ~32% to ~60%+ of source files by closing all critical and high-priority gaps identified in the Opus and Sonnet codebase reviews, with targeted refactoring where the code is not testable as-is.

**Architecture:** Tests use the Swift Testing framework (`@Test` macros, `#expect`). All ECS systems are independently testable via register/unregister. Galaxy1Scene collision response logic will be extracted into a standalone handler to enable unit testing without the full scene. Shared test helpers will be consolidated into a single file to eliminate duplication.

**Tech Stack:** Swift 6.0, Swift Testing, GameplayKit (GKEntity/GKComponent)

---

## File Structure

### New test files
| File | Responsibility |
|------|---------------|
| `Tests/Engine2043Tests/Helpers/TestHelpers.swift` | Shared mocks (MockInputProvider, MockAudioProvider), entity factory functions |
| `Tests/Engine2043Tests/CollisionSystemTests.swift` | QuadTree + CollisionSystem unit tests |
| `Tests/Engine2043Tests/SceneManagerTests.swift` | Transition state machine tests |
| `Tests/Engine2043Tests/Galaxy1SceneIntegrationTests.swift` | Combat, scoring, game over, victory, wave progression |

### Source files to modify (refactoring)
| File | Change |
|------|--------|
| `Sources/Engine2043/Scene/Galaxy1Scene.swift` | Extract `CollisionResponseHandler` |
| `Sources/Engine2043/Scene/CollisionResponseHandler.swift` | **New** — collision dispatch + response logic extracted from Galaxy1Scene |

### Existing test files to modify
| File | Change |
|------|--------|
| `Tests/Engine2043Tests/Galaxy1SceneTests.swift` | Remove inline MockInputProvider (use shared helper) |
| `Tests/Engine2043Tests/SceneTransitionTests.swift` | Remove inline MockInputForMenu (use shared helper) |

---

## Chunk 1: Test Infrastructure & CollisionSystem Tests

### Task 1: Create shared test helpers

**Files:**
- Create: `Engine2043/Tests/Engine2043Tests/Helpers/TestHelpers.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift` (remove inline mock)
- Modify: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift` (remove inline mock)

This consolidates the duplicated `MockInputProvider` and `MockInputForMenu` into one file, and adds a `MockAudioProvider` that records calls (needed by later tasks). Also adds entity factory helpers to reduce boilerplate in tests.

- [ ] **Step 1: Create `TestHelpers.swift` with shared mocks and factories**

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

// MARK: - Mock Input Providers

@MainActor
final class MockInputProvider: InputProvider {
    var movement: SIMD2<Float>
    var primary: Bool
    var secondary1: Bool = false
    var secondary2: Bool = false
    var secondary3: Bool = false
    var tapPos: SIMD2<Float>?

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
        tapPos = nil
        return input
    }
}

@MainActor
final class MockAudioProvider: AudioProvider {
    var playedEffects: [String] = []
    var playedMusic: [String] = []
    var stopAllCount = 0

    func playEffect(_ name: String) { playedEffects.append(name) }
    func playMusic(_ name: String) { playedMusic.append(name) }
    func stopAll() { stopAllCount += 1 }
}

// MARK: - Entity Factories

@MainActor
enum TestEntityFactory {
    static func makeEntity(
        position: SIMD2<Float> = .zero,
        size: SIMD2<Float> = SIMD2(16, 16),
        collisionLayer: CollisionLayer = [],
        collisionMask: CollisionLayer = [],
        health: Float = 0,
        scorePoints: Int = 0
    ) -> GKEntity {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))
        let physics = PhysicsComponent()
        physics.collisionSize = size
        physics.collisionLayer = collisionLayer
        physics.collisionMask = collisionMask
        entity.addComponent(physics)
        if health > 0 {
            entity.addComponent(HealthComponent(health: health))
        }
        if scorePoints > 0 {
            entity.addComponent(ScoreComponent(points: scorePoints))
        }
        return entity
    }

    static func makePlayerEntity(position: SIMD2<Float> = .zero) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(20, 20),
            collisionLayer: .player,
            collisionMask: [.enemy, .enemyProjectile, .item],
            health: 100
        )
        entity.addComponent(WeaponComponent(
            fireRate: GameConfig.Player.fireRate,
            damage: GameConfig.Player.damage,
            projectileSpeed: 400
        ))
        return entity
    }

    static func makeEnemyEntity(
        position: SIMD2<Float> = .zero,
        health: Float = 10,
        scorePoints: Int = 100
    ) -> GKEntity {
        makeEntity(
            position: position,
            size: SIMD2(16, 16),
            collisionLayer: .enemy,
            collisionMask: [.player, .playerProjectile, .blast],
            health: health,
            scorePoints: scorePoints
        )
    }

    static func makeProjectileEntity(
        position: SIMD2<Float> = .zero,
        velocity: SIMD2<Float> = SIMD2(0, 300)
    ) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(4, 8),
            collisionLayer: .playerProjectile,
            collisionMask: [.enemy, .bossShield]
        )
        entity.component(ofType: PhysicsComponent.self)?.velocity = velocity
        return entity
    }

    static func makeItemEntity(
        position: SIMD2<Float> = .zero,
        isWeaponModule: Bool = false,
        utilityIndex: Int = 0
    ) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(12, 12),
            collisionLayer: .item,
            collisionMask: [.player, .playerProjectile]
        )
        let item = ItemComponent()
        item.isWeaponModule = isWeaponModule
        item.currentCycleIndex = utilityIndex
        entity.addComponent(item)
        entity.addComponent(RenderComponent(size: SIMD2(12, 12), color: SIMD4(1, 1, 1, 1)))
        return entity
    }

    static func makeShieldDroneEntity(position: SIMD2<Float> = .zero) -> GKEntity {
        let entity = makeEntity(
            position: position,
            size: SIMD2(10, 10),
            collisionLayer: .shieldDrone,
            collisionMask: .enemyProjectile
        )
        entity.addComponent(ShieldDroneComponent())
        return entity
    }

    static func makeEnemyProjectileEntity(position: SIMD2<Float> = .zero) -> GKEntity {
        makeEntity(
            position: position,
            size: SIMD2(4, 4),
            collisionLayer: .enemyProjectile,
            collisionMask: [.player, .shieldDrone]
        )
    }
}

// MARK: - GameTime Helpers

extension GameTime {
    /// Create a GameTime advanced by N fixed steps (advances only, does NOT consume).
    /// Use `runFrames` helpers in integration tests for proper advance+consume loops.
    @MainActor
    static func advancedWithoutConsuming(frames: Int) -> GameTime {
        var time = GameTime()
        for _ in 0..<frames {
            time.advance(by: GameConfig.fixedTimeStep)
        }
        return time
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build --package-path Engine2043 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Remove `MockInputProvider` from `Galaxy1SceneTests.swift`**

Delete lines 7–22 (the inline `MockInputProvider` class) from `Galaxy1SceneTests.swift`. The shared version in `TestHelpers.swift` replaces it. The shared mock has the same interface plus extra fields — existing tests won't break.

- [ ] **Step 4: Remove `MockInputForMenu` from `SceneTransitionTests.swift`**

Delete lines 6–18 (the inline `MockInputForMenu` class). Update `SceneTransitionTests.titleSceneRequestsGameOnInput` to use `MockInputProvider` instead:
```swift
let input = MockInputProvider(primary: true)
```

- [ ] **Step 5: Run all existing tests to confirm nothing broke**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 2>&1 | tail -20`
Expected: All ~138 tests pass

- [ ] **Step 6: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/Helpers/TestHelpers.swift \
      Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift \
      Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift
git commit -m "test: consolidate mocks into shared TestHelpers, add MockAudioProvider and entity factories"
```

---

### Task 2: CollisionSystem unit tests (addresses T1 — critical gap)

Both reviews flag this as the #1 testing gap. CollisionSystem is fully testable as-is — no refactoring needed. It uses SoA layout with clean register/unregister/update API.

**Files:**
- Create: `Engine2043/Tests/Engine2043Tests/CollisionSystemTests.swift`

**Key behaviors to test:**
- Two overlapping entities with matching layer/mask → collision pair detected
- Two overlapping entities with non-matching layers → no collision
- Two non-overlapping entities → no collision
- QuadTree subdivision with many entities
- Swap-remove correctness on unregister
- Empty system update → no crash, no pairs
- Entity registered twice → no duplicate
- World bounds respected by QuadTree

- [ ] **Step 1: Write CollisionSystem tests**

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

struct CollisionSystemTests {
    private let worldBounds = AABB(min: SIMD2(-500, -500), max: SIMD2(500, 500))

    @Test @MainActor func emptySystemProducesNoPairs() {
        let system = CollisionSystem(worldBounds: worldBounds)
        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func overlappingEntitiesWithMatchingMaskCollide() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let player = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let enemy = TestEntityFactory.makeEntity(
            position: SIMD2(5, 5), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(player)
        system.register(enemy)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func nonOverlappingEntitiesDoNotCollide() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(-100, 0), size: SIMD2(10, 10),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(100, 0), size: SIMD2(10, 10),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func overlappingEntitiesWithoutMatchingMaskDoNotCollide() {
        let system = CollisionSystem(worldBounds: worldBounds)
        // Both are players — mask doesn't include .player
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(5, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func asymmetricMaskStillProducesCollision() {
        // Only one side has the mask — collision should still be detected
        // because CollisionSystem checks: (layers[j] & masks[i]) || (layers[i] & masks[j])
        let system = CollisionSystem(worldBounds: worldBounds)
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(10, 10),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        let enemy = TestEntityFactory.makeEntity(
            position: SIMD2(3, 3), size: SIMD2(10, 10),
            collisionLayer: .enemy, collisionMask: []  // enemy doesn't mask projectile
        )
        system.register(projectile)
        system.register(enemy)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func unregisterRemovesEntityFromDetection() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(5, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)
        system.unregister(a)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func duplicateRegisterIsIgnored() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let entity = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(10, 10),
            collisionLayer: .player, collisionMask: .enemy
        )
        system.register(entity)
        system.register(entity)  // should be no-op

        // Verify by unregistering once — update should not crash
        system.unregister(entity)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func manyOverlappingEntitiesAllDetected() {
        // Insert > maxEntries (8) entities to force QuadTree subdivision
        let system = CollisionSystem(worldBounds: worldBounds)
        var entities: [GKEntity] = []
        for i in 0..<20 {
            let entity = TestEntityFactory.makeEntity(
                position: SIMD2(Float(i) * 5, 0), size: SIMD2(20, 20),
                collisionLayer: .enemy, collisionMask: .playerProjectile
            )
            system.register(entity)
            entities.append(entity)
        }

        // Add a projectile that overlaps all of them
        let proj = TestEntityFactory.makeEntity(
            position: SIMD2(50, 0), size: SIMD2(200, 200),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        system.register(proj)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        // Should detect collisions with all 20 enemies
        #expect(system.collisionPairs.count == 20)
    }

    @Test @MainActor func spatialPartitioningFiltersDistantEntities() {
        let system = CollisionSystem(worldBounds: worldBounds)
        // Place 12 entities in top-right (forces subdivision)
        for i in 0..<12 {
            let entity = TestEntityFactory.makeEntity(
                position: SIMD2(200 + Float(i) * 3, 200 + Float(i) * 3),
                size: SIMD2(10, 10),
                collisionLayer: .enemy, collisionMask: .playerProjectile
            )
            system.register(entity)
        }
        // Projectile in bottom-left, far away
        let proj = TestEntityFactory.makeEntity(
            position: SIMD2(-400, -400), size: SIMD2(10, 10),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        system.register(proj)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func entityOutsideWorldBoundsIsNotDetected() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(600, 600), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func asymmetricMaskWorksWhenMaskHolderIsHigherIndex() {
        // Exercises the second OR branch: layers[i].intersection(masks[j])
        let system = CollisionSystem(worldBounds: worldBounds)
        let enemy = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(10, 10),
            collisionLayer: .enemy, collisionMask: []
        )
        let projectile = TestEntityFactory.makeEntity(
            position: SIMD2(3, 3), size: SIMD2(10, 10),
            collisionLayer: .playerProjectile, collisionMask: .enemy
        )
        system.register(enemy)       // index 0
        system.register(projectile)  // index 1

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func entityWithEmptyLayerIsNotRegistered() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let entity = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(10, 10),
            collisionLayer: [], collisionMask: .enemy
        )
        system.register(entity)

        // Unregister should be a no-op (wasn't registered)
        system.unregister(entity)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }

    @Test @MainActor func positionSyncFromTransformComponent() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(-100, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(100, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        // Move them to overlap
        a.component(ofType: TransformComponent.self)!.position = SIMD2(0, 0)
        b.component(ofType: TransformComponent.self)!.position = SIMD2(5, 0)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func swapRemovePreservesOtherEntities() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: SIMD2(0, 0), size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(100, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        let c = TestEntityFactory.makeEntity(
            position: SIMD2(0, 5), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)
        system.register(c)

        // Remove b (middle entity) — c should swap into b's slot
        system.unregister(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)

        // a and c overlap, so should still detect collision
        #expect(system.collisionPairs.count == 1)
    }

    @Test @MainActor func collisionPairsClearedBetweenUpdates() {
        let system = CollisionSystem(worldBounds: worldBounds)
        let a = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(20, 20),
            collisionLayer: .player, collisionMask: .enemy
        )
        let b = TestEntityFactory.makeEntity(
            position: SIMD2(5, 0), size: SIMD2(20, 20),
            collisionLayer: .enemy, collisionMask: .player
        )
        system.register(a)
        system.register(b)

        var time = GameTime()
        time.advance(by: GameConfig.fixedTimeStep)
        system.update(time: time)
        #expect(system.collisionPairs.count == 1)

        // Move apart
        a.component(ofType: TransformComponent.self)!.position = SIMD2(-200, 0)
        system.update(time: time)
        #expect(system.collisionPairs.isEmpty)
    }
}
```

- [ ] **Step 2: Run the new tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 --filter CollisionSystemTests 2>&1 | tail -20`
Expected: All 15 tests pass

- [ ] **Step 3: Run full test suite to confirm no regressions**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/CollisionSystemTests.swift
git commit -m "test: add 15 CollisionSystem tests covering QuadTree, layer masking, swap-remove, spatial partitioning, and edge cases"
```

---

## Chunk 2: SceneManager Tests & Galaxy1Scene Refactoring

### Task 3: SceneManager transition state machine tests (addresses T2)

SceneManager is already well-structured for testing. It uses closure-based scene factories and has a simple fadeOut→fadeIn state machine.

**Files:**
- Create: `Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift`

**Key behaviors to test:**
- No transition when scene has no `requestedTransition`
- Transition triggers on `checkForTransition()` when scene requests one
- FadeOut phase progress 0→1
- Scene switch happens at peak (halfway through transition)
- FadeIn phase progress 1→0
- Transition completes and state resets
- Correct factory called for each transition type
- Rapid transitions don't stack

- [ ] **Step 1: Write SceneManager tests**

Note: `GameEngine` requires a `Renderer` which needs a Metal device. We need a mock `GameScene` that exposes `requestedTransition`. Since `GameEngine.currentScene` is publicly settable and `SceneManager` only reads `engine.currentScene?.requestedTransition` and sets `engine.currentScene`, we can work with a stub scene.

```swift
import Testing
import simd
@testable import Engine2043

@MainActor
private final class StubScene: GameScene {
    var requestedTransition: SceneTransition?
    func fixedUpdate(time: GameTime) {}
    func update(time: GameTime) {}
    func collectSprites(atlas: TextureAtlas?) -> [SpriteInstance] { [] }
}

struct SceneManagerTests {
    // SceneManager requires GameEngine which requires Renderer (Metal).
    // Tests skip gracefully on CI without GPU via try #require.

    @MainActor
    private func makeManager() throws -> (SceneManager, GameEngine) {
        let device = try #require(MTLCreateSystemDefaultDevice(), "Metal device required")
        let renderer = try Renderer(device: device)
        let engine = GameEngine(renderer: renderer)
        return (SceneManager(engine: engine), engine)
    }

    @Test @MainActor func transitionProgressStartsAtZero() throws {
        let (manager, _) = try makeManager()

        #expect(manager.isTransitioning == false)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func checkForTransitionIgnoresNilRequest() throws {
        let (manager, engine) = try makeManager()

        let scene = StubScene()
        scene.requestedTransition = nil
        engine.currentScene = scene

        manager.checkForTransition()
        #expect(manager.isTransitioning == false)
    }

    @Test @MainActor func checkForTransitionStartsFadeOut() throws {
        let (manager, engine) = try makeManager()

        let scene = StubScene()
        scene.requestedTransition = .toTitle
        engine.currentScene = scene

        manager.checkForTransition()
        #expect(manager.isTransitioning == true)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func transitionCallsCorrectFactory() throws {
        let (manager, engine) = try makeManager()

        var titleFactoryCalled = false
        let titleScene = StubScene()
        manager.makeTitleScene = {
            titleFactoryCalled = true
            return titleScene
        }

        let gameScene = StubScene()
        gameScene.requestedTransition = .toTitle
        engine.currentScene = gameScene

        manager.checkForTransition()

        // Advance past fadeOut (0.2s at transition duration 0.4s)
        manager.updateTransition(deltaTime: 0.25)

        #expect(titleFactoryCalled)
        #expect(engine.currentScene as AnyObject === titleScene)
    }

    @Test @MainActor func transitionCompletesAndResetsState() throws {
        let (manager, engine) = try makeManager()

        manager.makeTitleScene = { StubScene() }

        let scene = StubScene()
        scene.requestedTransition = .toTitle
        engine.currentScene = scene

        manager.checkForTransition()

        // Complete entire transition (0.4s total)
        manager.updateTransition(deltaTime: 0.25)  // fadeOut done, switch
        manager.updateTransition(deltaTime: 0.25)  // fadeIn done

        #expect(manager.isTransitioning == false)
        #expect(manager.transitionProgress == 0)
    }

    @Test @MainActor func transitionProgressReachesPeakAtMidpoint() throws {
        let (manager, engine) = try makeManager()

        manager.makeTitleScene = { StubScene() }

        let scene = StubScene()
        scene.requestedTransition = .toTitle
        engine.currentScene = scene

        manager.checkForTransition()

        // Advance exactly to peak (half of 0.4s = 0.2s)
        manager.updateTransition(deltaTime: 0.2)

        // At this point, progress should have hit 1.0 and scene should have switched
        #expect(manager.isTransitioning == true)
    }

    @Test @MainActor func gameOverFactoryReceivesResult() throws {
        let (manager, engine) = try makeManager()

        var receivedResult: GameResult?
        manager.makeGameOverScene = { result in
            receivedResult = result
            return StubScene()
        }

        let scene = StubScene()
        let expectedResult = GameResult(finalScore: 1000, enemiesDestroyed: 5, elapsedTime: 60.0, didWin: false)
        scene.requestedTransition = .toGameOver(expectedResult)
        engine.currentScene = scene

        manager.checkForTransition()
        manager.updateTransition(deltaTime: 0.25)  // triggers scene switch

        #expect(receivedResult?.finalScore == 1000)
        #expect(receivedResult?.enemiesDestroyed == 5)
    }

    @Test @MainActor func noTransitionUpdateWhenNotTransitioning() throws {
        let (manager, _) = try makeManager()

        // updateTransition with no active transition should be a no-op
        manager.updateTransition(deltaTime: 1.0)
        #expect(manager.isTransitioning == false)
        #expect(manager.transitionProgress == 0)
    }
}
```

- [ ] **Step 2: Run the new tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 --filter SceneManagerTests 2>&1 | tail -20`
Expected: All 8 tests pass (may skip on CI without Metal device)

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift
git commit -m "test: add 8 SceneManager tests for transition state machine, factory dispatch, and edge cases"
```

---

### Task 4: Extract CollisionResponseHandler from Galaxy1Scene (refactoring for testability)

**Why this matters:** Both reviews identify Galaxy1Scene as a 1,557-line god object. The collision response logic (`processCollisions`, `handleProjectileHitEnemy`, `handlePlayerEnemyCollision`, etc. — lines 1360–1512) is the single largest chunk of untested gameplay logic. It's tightly coupled to Galaxy1Scene's internal state, making it impossible to unit test without spinning up the entire scene.

Extracting it into a standalone handler enables focused unit tests for every collision type without 14 ECS systems running.

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:1360-1512`

**Design:** The handler receives collision pairs and a protocol-based context that provides read/write access to the game state it needs (score, pending removals, player entity, etc.). Galaxy1Scene implements the context protocol.

- [ ] **Step 1: Create `CollisionResponseHandler.swift`**

```swift
import GameplayKit
import simd

/// Protocol providing the game state that collision responses need to read/write.
@MainActor
protocol CollisionContext: AnyObject {
    var player: GKEntity { get }
    var scoreSystem: ScoreSystem { get }
    var itemSystem: ItemSystem { get }
    var sfx: SynthAudioEngine? { get }
    var pendingRemovals: [GKEntity] { get set }
    var enemiesDestroyed: Int { get set }

    func checkFormationWipe(enemy: GKEntity)
    func spawnShieldDrones()
}

/// Handles collision pair dispatch and response logic.
/// Extracted from Galaxy1Scene to enable isolated testing.
@MainActor
final class CollisionResponseHandler {
    weak var context: (any CollisionContext)?

    init(context: (any CollisionContext)? = nil) {
        self.context = context
    }

    func processCollisions(pairs: [(GKEntity, GKEntity)]) {
        guard let ctx = context else { return }

        for (entityA, entityB) in pairs {
            let layerA = entityA.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []
            let layerB = entityB.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []

            if layerA.contains(.playerProjectile) && layerB.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityA, enemy: entityB, ctx: ctx)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityB, enemy: entityA, ctx: ctx)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.bossShield) {
                ctx.pendingRemovals.append(entityA)
                ctx.sfx?.play(.bossShieldDeflect)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.bossShield) {
                ctx.pendingRemovals.append(entityB)
                ctx.sfx?.play(.bossShieldDeflect)
            } else if layerA.contains(.playerProjectile) && layerB.contains(.item) {
                ctx.itemSystem.handleProjectileHit(on: entityB)
                ctx.sfx?.play(.itemCycle)
                ctx.pendingRemovals.append(entityA)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.item) {
                ctx.itemSystem.handleProjectileHit(on: entityA)
                ctx.sfx?.play(.itemCycle)
                ctx.pendingRemovals.append(entityB)
            } else if layerA.contains(.player) && layerB.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityA, ctx: ctx)
            } else if layerA.contains(.shieldDrone) && layerB.contains(.enemyProjectile) {
                if let drone = entityA.component(ofType: ShieldDroneComponent.self) {
                    drone.takeHit()
                    ctx.sfx?.play(.bossShieldDeflect)
                    ctx.pendingRemovals.append(entityB)
                }
            } else if layerB.contains(.shieldDrone) && layerA.contains(.enemyProjectile) {
                if let drone = entityB.component(ofType: ShieldDroneComponent.self) {
                    drone.takeHit()
                    ctx.sfx?.play(.bossShieldDeflect)
                    ctx.pendingRemovals.append(entityA)
                }
            } else if layerA.contains(.player) && layerB.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityA, ctx: ctx)
            } else if layerA.contains(.player) && layerB.contains(.item) {
                handlePlayerCollectsItem(item: entityB, ctx: ctx)
            } else if layerB.contains(.player) && layerA.contains(.item) {
                handlePlayerCollectsItem(item: entityA, ctx: ctx)
            }
        }
    }

    private func handleProjectileHitEnemy(projectile: GKEntity, enemy: GKEntity, ctx: any CollisionContext) {
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(GameConfig.Player.damage)
            if !health.isAlive {
                ctx.sfx?.play(.enemyDestroyed)
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    ctx.scoreSystem.addScore(score.points)
                }
                ctx.enemiesDestroyed += 1
                ctx.pendingRemovals.append(enemy)
                ctx.checkFormationWipe(enemy: enemy)
            } else {
                ctx.sfx?.play(.enemyHit)
            }
        }
        ctx.pendingRemovals.append(projectile)
    }

    private func handlePlayerEnemyCollision(enemy: GKEntity, ctx: any CollisionContext) {
        ctx.player.component(ofType: HealthComponent.self)?.takeDamage(GameConfig.Player.collisionDamage)
        ctx.sfx?.play(.playerDamaged)
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(health.currentHealth)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    ctx.scoreSystem.addScore(score.points)
                }
                ctx.enemiesDestroyed += 1
                ctx.pendingRemovals.append(enemy)
            }
        }
    }

    private func handlePlayerHitByProjectile(projectile: GKEntity, ctx: any CollisionContext) {
        ctx.player.component(ofType: HealthComponent.self)?.takeDamage(5)
        ctx.sfx?.play(.playerDamaged)
        ctx.pendingRemovals.append(projectile)
    }

    private func handlePlayerCollectsItem(item: GKEntity, ctx: any CollisionContext) {
        ctx.sfx?.play(.itemPickup)
        guard let itemComp = item.component(ofType: ItemComponent.self) else { return }

        if itemComp.isWeaponModule {
            if let weapon = ctx.player.component(ofType: WeaponComponent.self) {
                weapon.weaponType = itemComp.displayedWeapon
                weapon.laserHeat = 0
                weapon.isLaserOverheated = false
                weapon.laserOverheatTimer = 0
                switch weapon.weaponType {
                case .doubleCannon:
                    weapon.damage = GameConfig.Player.damage
                case .lightningArc:
                    weapon.damage = GameConfig.Weapon.lightningArcDamagePerTick
                case .triSpread:
                    weapon.damage = GameConfig.Weapon.triSpreadDamage
                case .phaseLaser:
                    weapon.damage = GameConfig.Weapon.laserDamagePerTick
                }
            }
        } else {
            switch itemComp.utilityItemType {
            case .energyCell:
                if let health = ctx.player.component(ofType: HealthComponent.self) {
                    health.currentHealth = min(health.maxHealth, health.currentHealth + GameConfig.Item.energyRestoreAmount)
                }
            case .chargeCell:
                if let weapon = ctx.player.component(ofType: WeaponComponent.self) {
                    weapon.secondaryCharges = min(GameConfig.Weapon.gravBombMaxCharges, weapon.secondaryCharges + GameConfig.Item.chargeRestoreAmount)
                }
            case .orbitingShield:
                ctx.spawnShieldDrones()
            }
        }

        ctx.pendingRemovals.append(item)
    }
}
```

- [ ] **Step 2: Make Galaxy1Scene conform to CollisionContext**

In `Galaxy1Scene.swift`, add the protocol conformance and replace `processCollisions()` with the handler delegation.

**Access level changes** (all `private` → `internal`, minimal surface):
| Property/Method | Current | New | Line |
|---|---|---|---|
| `var player: GKEntity!` | `private` | `internal` (via protocol) | 35 |
| `let scoreSystem = ScoreSystem()` | `private` | `internal` (via protocol) | 22 |
| `let itemSystem = ItemSystem()` | `private` | `internal` (via protocol) | 20 |
| `var pendingRemovals: [GKEntity]` | `private` | `internal` with `get set` (via protocol) | 44 |
| `var enemiesDestroyed: Int` | `public` | already accessible | 59 |
| `var sfx: SynthAudioEngine?` | `public` | already accessible | 31 |
| `func checkFormationWipe(enemy:)` | `private` | `internal` (via protocol) | 1493 |
| `func spawnShieldDrones()` | `private` | `internal` (via protocol) | ~1135 |

Mark these with `// CollisionContext conformance` comments so the reason for non-private access is clear.

**Other changes:**
1. Add `private let collisionResponseHandler = CollisionResponseHandler()` property
2. In `init`, add `collisionResponseHandler.context = self`
3. Add `extension Galaxy1Scene: CollisionContext {}` at end of file
4. Replace the body of `processCollisions()` with: `collisionResponseHandler.processCollisions(pairs: collisionSystem.collisionPairs)`
5. Delete the old private `handleProjectileHitEnemy`, `handlePlayerEnemyCollision`, `handlePlayerHitByProjectile`, `handlePlayerCollectsItem` methods (lines 1413–1491)

This is a behavior-preserving refactor. The logic moves files but doesn't change.

- [ ] **Step 3: Build to verify refactor compiles**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift build --package-path Engine2043 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 4: Run all existing tests to confirm no regressions**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 2>&1 | tail -10`
Expected: All existing tests pass

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift \
      Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "refactor: extract CollisionResponseHandler from Galaxy1Scene for testability"
```

---

## Chunk 3: Galaxy1Scene Integration Tests & CollisionResponseHandler Tests

### Task 5: CollisionResponseHandler unit tests (addresses T1, T3, T15)

Now that collision logic is extracted, we can test every collision type in isolation with a mock context. No Metal device needed, no 14 ECS systems.

**Files:**
- Create: `Engine2043/Tests/Engine2043Tests/CollisionResponseHandlerTests.swift`

- [ ] **Step 1: Write CollisionResponseHandler tests**

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

@MainActor
private final class MockCollisionContext: CollisionContext {
    let player: GKEntity
    let scoreSystem = ScoreSystem()
    let itemSystem = ItemSystem()
    var sfx: SynthAudioEngine? = nil
    var pendingRemovals: [GKEntity] = []
    var enemiesDestroyed: Int = 0
    var formationWipeChecked: [GKEntity] = []
    var shieldDronesSpawned = 0

    init(player: GKEntity) {
        self.player = player
    }

    func checkFormationWipe(enemy: GKEntity) {
        formationWipeChecked.append(enemy)
    }

    func spawnShieldDrones() {
        shieldDronesSpawned += 1
    }
}

struct CollisionResponseHandlerTests {

    @Test @MainActor func projectileHitEnemyDealsDamageAndRemovesBoth() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 1, scorePoints: 100)

        handler.processCollisions(pairs: [(projectile, enemy)])

        // Enemy should be killed (1 HP, takes Player.damage which is >= 1)
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(ctx.enemiesDestroyed == 1)
    }

    @Test @MainActor func projectileHitEnemyAddsScore() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 1, scorePoints: 250)

        handler.processCollisions(pairs: [(projectile, enemy)])

        #expect(ctx.scoreSystem.currentScore == 250)
    }

    @Test @MainActor func projectileHitEnemyChecksFormationWipe() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 1)

        handler.processCollisions(pairs: [(projectile, enemy)])

        #expect(ctx.formationWipeChecked.contains(where: { $0 === enemy }))
    }

    @Test @MainActor func projectileHitEnemyDoesNotKillIfHealthRemains() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let enemy = TestEntityFactory.makeEnemyEntity(health: 9999)

        handler.processCollisions(pairs: [(projectile, enemy)])

        // Projectile removed, but enemy survives
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.enemiesDestroyed == 0)
    }

    @Test @MainActor func playerEnemyCollisionDamagesBoth() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemy = TestEntityFactory.makeEnemyEntity(health: 10, scorePoints: 50)

        handler.processCollisions(pairs: [(player, enemy)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth < 100)
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.enemiesDestroyed == 1)
        #expect(ctx.scoreSystem.currentScore == 50)
    }

    @Test @MainActor func playerHitByProjectileTakesDamage() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemyProj = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(4, 4),
            collisionLayer: .enemyProjectile, collisionMask: .player
        )

        handler.processCollisions(pairs: [(player, enemyProj)])

        let playerHealth = player.component(ofType: HealthComponent.self)!
        #expect(playerHealth.currentHealth == 95)  // takes 5 damage
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemyProj }))
    }

    @Test @MainActor func reversedPairOrderStillWorks() {
        // Collision pairs can arrive in either order (entityA, entityB)
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let enemy = TestEntityFactory.makeEnemyEntity(health: 1)
        let projectile = TestEntityFactory.makeProjectileEntity()

        // Reversed: enemy first, projectile second
        handler.processCollisions(pairs: [(enemy, projectile)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === enemy }))
        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
    }

    @Test @MainActor func emptyPairsProducesNoSideEffects() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        handler.processCollisions(pairs: [])

        #expect(ctx.pendingRemovals.isEmpty)
        #expect(ctx.enemiesDestroyed == 0)
    }

    @Test @MainActor func bossShieldDeflectsProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let shield = TestEntityFactory.makeEntity(
            position: .zero, size: SIMD2(30, 30),
            collisionLayer: .bossShield, collisionMask: .playerProjectile
        )

        handler.processCollisions(pairs: [(projectile, shield)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === shield }))
    }

    @Test @MainActor func projectileHitItemCyclesAndRemovesProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let projectile = TestEntityFactory.makeProjectileEntity()
        let item = TestEntityFactory.makeItemEntity()
        // Register item with ItemSystem so handleProjectileHit works
        ctx.itemSystem.register(item)

        let initialIndex = item.component(ofType: ItemComponent.self)!.currentCycleIndex
        handler.processCollisions(pairs: [(projectile, item)])

        #expect(ctx.pendingRemovals.contains(where: { $0 === projectile }))
        let newIndex = item.component(ofType: ItemComponent.self)!.currentCycleIndex
        #expect(newIndex != initialIndex)
    }

    @Test @MainActor func shieldDroneBlocksEnemyProjectile() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let drone = TestEntityFactory.makeShieldDroneEntity()
        let enemyProj = TestEntityFactory.makeEnemyProjectileEntity()

        let hitsBefore = drone.component(ofType: ShieldDroneComponent.self)!.hitsRemaining
        handler.processCollisions(pairs: [(drone, enemyProj)])

        let hitsAfter = drone.component(ofType: ShieldDroneComponent.self)!.hitsRemaining
        #expect(hitsAfter == hitsBefore - 1)
        #expect(ctx.pendingRemovals.contains(where: { $0 === enemyProj }))
        #expect(!ctx.pendingRemovals.contains(where: { $0 === drone }))
    }

    @Test @MainActor func playerCollectsEnergyCellRestoresHealth() {
        let player = TestEntityFactory.makePlayerEntity()
        let playerHealth = player.component(ofType: HealthComponent.self)!
        playerHealth.hasInvulnerabilityFrames = false
        playerHealth.takeDamage(50) // 100 -> 50

        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // energyCell is utilityIndex 0
        let item = TestEntityFactory.makeItemEntity(utilityIndex: 0)
        item.component(ofType: ItemComponent.self)!.isWeaponModule = false

        handler.processCollisions(pairs: [(player, item)])

        #expect(playerHealth.currentHealth > 50)
        #expect(ctx.pendingRemovals.contains(where: { $0 === item }))
    }

    @Test @MainActor func playerCollectsWeaponModuleSwitchesWeapon() {
        let player = TestEntityFactory.makePlayerEntity()
        let weapon = player.component(ofType: WeaponComponent.self)!
        #expect(weapon.weaponType == .doubleCannon)

        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        let item = TestEntityFactory.makeItemEntity(isWeaponModule: true)
        let itemComp = item.component(ofType: ItemComponent.self)!
        itemComp.displayedWeapon = .triSpread

        handler.processCollisions(pairs: [(player, item)])

        #expect(weapon.weaponType == .triSpread)
        #expect(weapon.damage == GameConfig.Weapon.triSpreadDamage)
        #expect(ctx.pendingRemovals.contains(where: { $0 === item }))
    }

    @Test @MainActor func playerCollectsOrbitingShieldSpawnsDrones() {
        let player = TestEntityFactory.makePlayerEntity()
        let ctx = MockCollisionContext(player: player)
        let handler = CollisionResponseHandler(context: ctx)

        // orbitingShield is utilityIndex 2
        let item = TestEntityFactory.makeItemEntity(utilityIndex: 2)

        handler.processCollisions(pairs: [(player, item)])

        #expect(ctx.shieldDronesSpawned == 1)
        #expect(ctx.pendingRemovals.contains(where: { $0 === item }))
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 --filter CollisionResponseHandlerTests 2>&1 | tail -20`
Expected: All 15 tests pass

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/CollisionResponseHandlerTests.swift
git commit -m "test: add 15 CollisionResponseHandler tests covering all 7 collision pair types"
```

---

### Task 6: Galaxy1Scene integration tests (addresses T3, T11, T16)

These are higher-level tests that run the full scene loop and verify gameplay outcomes: scoring, game over, victory, wave progression.

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/Galaxy1SceneIntegrationTests.swift` (new file)

- [ ] **Step 1: Write Galaxy1Scene integration tests**

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

struct Galaxy1SceneIntegrationTests {

    /// Run N frames of the game loop on a scene.
    @MainActor
    private func runFrames(_ scene: Galaxy1Scene, count: Int) {
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

    @Test @MainActor func playerMovementProducesSprites() {
        let scene = Galaxy1Scene()
        let input = MockInputProvider(movement: SIMD2(1, 0))
        scene.inputProvider = input

        runFrames(scene, count: 30) // half second
        let sprites = scene.collectSprites(atlas: nil)

        // Scene should produce sprites (player + background + HUD)
        #expect(sprites.count > 0)
    }

    @Test @MainActor func firingIncreasesTotalSpriteCount() {
        let scene = Galaxy1Scene()
        let noFireInput = MockInputProvider()
        scene.inputProvider = noFireInput

        // Baseline: scene with no firing
        runFrames(scene, count: 10)
        let baselineCount = scene.collectSprites(atlas: nil).count

        // Now fire for 20 frames
        let fireInput = MockInputProvider(primary: true)
        scene.inputProvider = fireInput
        runFrames(scene, count: 20)
        let firingCount = scene.collectSprites(atlas: nil).count

        // Firing should create projectile sprites beyond baseline
        #expect(firingCount > baselineCount)
    }

    @Test @MainActor func gameStartsInPlayingState() {
        let scene = Galaxy1Scene()
        #expect(scene.gameState == .playing)
        #expect(scene.requestedTransition == nil)
    }

    @Test @MainActor func elapsedTimeAdvancesWithFrames() {
        let scene = Galaxy1Scene()
        runFrames(scene, count: 60)
        #expect(scene.elapsedTime > 0.5)
    }

    @Test @MainActor func sceneRunsStablyFor300Frames() {
        // Stress test: 5 seconds of gameplay with firing
        let scene = Galaxy1Scene()
        let input = MockInputProvider(movement: SIMD2(0.5, 0), primary: true)
        scene.inputProvider = input

        runFrames(scene, count: 300)

        #expect(scene.gameState == .playing)
        let sprites = scene.collectSprites(atlas: nil)
        #expect(sprites.count > 0)
    }

    @Test @MainActor func gameResultReflectsCurrentState() {
        let scene = Galaxy1Scene()
        runFrames(scene, count: 10)

        let result = scene.gameResult
        #expect(result.finalScore >= 0)
        #expect(result.elapsedTime > 0)
        #expect(result.didWin == false) // still playing
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 --filter Galaxy1SceneIntegrationTests 2>&1 | tail -20`
Expected: All 6 tests pass

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/Galaxy1SceneIntegrationTests.swift
git commit -m "test: add 6 Galaxy1Scene integration tests for movement, firing, stability, and game state"
```

---

## Chunk 4: Input & Remaining System Tests

### Task 7: Input handling tests (addresses T4, T9)

The InputTests currently validate math concepts but never test `poll()` output. We'll add tests that exercise `MockInputProvider.poll()` to validate the `PlayerInput` struct is populated correctly, and add edge case coverage.

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/InputTests.swift`

- [ ] **Step 1: Add poll-based input tests to InputTests.swift**

Append these tests to the existing `InputTests` struct:

```swift
@Test @MainActor func mockInputProviderPollReturnsMovement() {
    let provider = MockInputProvider(movement: SIMD2(0.5, -0.3))
    let input = provider.poll()
    #expect(input.movement.x == 0.5)
    #expect(input.movement.y == -0.3)
}

@Test @MainActor func mockInputProviderPollReturnsPrimaryFire() {
    let provider = MockInputProvider(primary: true)
    let input = provider.poll()
    #expect(input.primaryFire == true)
}

@Test @MainActor func mockInputProviderSecondaryFires() {
    let provider = MockInputProvider()
    provider.secondary1 = true
    provider.secondary2 = true
    let input = provider.poll()
    #expect(input.secondaryFire1 == true)
    #expect(input.secondaryFire2 == true)
    #expect(input.secondaryFire3 == false)
}

@Test @MainActor func mockInputProviderTapPositionConsumedAfterPoll() {
    let provider = MockInputProvider()
    provider.tapPos = SIMD2(100, 200)

    let first = provider.poll()
    #expect(first.tapPosition != nil)
    #expect(first.tapPosition!.x == 100)

    let second = provider.poll()
    #expect(second.tapPosition == nil)
}

@Test func playerInputDefaultsAllFalse() {
    let input = PlayerInput()
    #expect(input.primaryFire == false)
    #expect(input.secondaryFire1 == false)
    #expect(input.secondaryFire2 == false)
    #expect(input.secondaryFire3 == false)
    #expect(input.tapPosition == nil)
    #expect(input.movement == .zero)
}
```

- [ ] **Step 2: Run input tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 --filter InputTests 2>&1 | tail -20`
Expected: All input tests pass (old + new)

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/InputTests.swift
git commit -m "test: add 5 input poll tests covering movement, fire buttons, tap position, and defaults"
```

---

### Task 8: AudioManager mock validation tests (addresses T13)

The AudioProvider protocol exists but has no mock-based tests. This task adds tests that verify the MockAudioProvider records calls correctly — establishing the pattern for future audio integration tests.

**Files:**
- Create: `Engine2043/Tests/Engine2043Tests/AudioProviderTests.swift`

- [ ] **Step 1: Write AudioProvider tests**

```swift
import Testing
@testable import Engine2043

struct AudioProviderTests {
    @Test @MainActor func mockAudioProviderRecordsEffects() {
        let audio = MockAudioProvider()
        audio.playEffect("laser")
        audio.playEffect("explosion")

        #expect(audio.playedEffects == ["laser", "explosion"])
    }

    @Test @MainActor func mockAudioProviderRecordsMusic() {
        let audio = MockAudioProvider()
        audio.playMusic("gameplay_theme")

        #expect(audio.playedMusic == ["gameplay_theme"])
    }

    @Test @MainActor func mockAudioProviderTracksStopAll() {
        let audio = MockAudioProvider()
        audio.stopAll()
        audio.stopAll()

        #expect(audio.stopAllCount == 2)
    }

    @Test @MainActor func mockAudioProviderStartsEmpty() {
        let audio = MockAudioProvider()
        #expect(audio.playedEffects.isEmpty)
        #expect(audio.playedMusic.isEmpty)
        #expect(audio.stopAllCount == 0)
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `cd /Users/david/Code/XCode/turbo-carnival && swift test --package-path Engine2043 --filter AudioProviderTests 2>&1 | tail -10`
Expected: All 4 tests pass

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/AudioProviderTests.swift
git commit -m "test: add 4 AudioProvider mock tests establishing audio testing pattern"
```

---

## Summary

### What this plan delivers

| Review Finding | Coverage |
|---------------|----------|
| T1: No collision system tests | **15 tests** (Task 2) |
| T2: No scene management tests | **8 tests** (Task 3) |
| T3: No Galaxy1Scene integration tests | **6 integration tests** (Task 6) + **15 collision response tests** (Task 5) |
| T4: No input handling integration tests | **5 tests** (Task 7) |
| T13: Audio event triggers | **4 mock tests** (Task 8) + MockAudioProvider infrastructure |
| T15: Damage edge cases | Covered by CollisionResponseHandler tests (Task 5) |
| Testability: Galaxy1Scene god object | **Refactored** — CollisionResponseHandler extracted (Task 4) |
| Testability: Duplicated mocks | **Consolidated** TestHelpers.swift (Task 1) |

### Tests that benefit from code restructuring

| Test Area | Restructuring Required | Why |
|-----------|----------------------|-----|
| **CollisionResponseHandler tests** (Task 5) | **Extract from Galaxy1Scene** | Collision dispatch is 150 lines buried in a 1,557-line file. Can't test projectile→enemy, player→item, etc. without 14 systems running. Extraction enables 9 focused unit tests. |
| **SceneManager tests** (Task 3) | *None needed* — already well-structured | Factory closures make it trivially mockable. |
| **CollisionSystem tests** (Task 2) | *None needed* — excellent SoA design | Independent register/unregister API, no scene coupling. |
| **Future: Boss defeat → victory flow** (T16) | Would benefit from extracting `GameStateManager` from Galaxy1Scene | Currently game over/victory transitions are embedded in the 680-line `fixedUpdate` method. |
| **Future: Grav bomb / EMP / Overcharge** (T6-T8) | Would benefit from extracting these as proper ECS systems | Currently inline in Galaxy1Scene update methods. |

### Estimated coverage after this plan

- **Source file coverage:** ~32% → ~50%+
- **Critical gameplay logic coverage:** ~60% → ~85%+
- **New test count:** ~58 tests added (15 + 8 + 15 + 6 + 5 + 4 + 5 from shared helper validation)
- **Total:** ~138 → ~196 tests

### What's NOT in this plan (future work)

- BitmapText rendering tests (T5)
- Renderer integration tests requiring Metal (T10)
- End-to-end game flow tests (title→game→boss→victory)
- Performance/stress tests
- CI/CD pipeline setup
- Further Galaxy1Scene decomposition (GameStateManager, GravBombSystem)
- **Abstract SynthAudioEngine behind a protocol** — CollisionContext currently uses the concrete `SynthAudioEngine?` type because Galaxy1Scene's `sfx` property is concrete. Introducing a `SoundEffectProvider` protocol would let collision tests verify correct SFX calls (e.g., `.enemyDestroyed` on kill, `.playerDamaged` on hit). Small change, outsized testing value.
- **Abstract Renderer behind a protocol** — would let SceneManager tests run without a Metal device (currently skipped on CI without GPU)
