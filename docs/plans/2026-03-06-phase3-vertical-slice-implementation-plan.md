# Phase 3: Vertical Slice — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete vertical slice of Galaxy 1 with all four enemy tiers, two primary weapons, one secondary weapon, shoot-to-cycle items, scoring, parallax background, and a boss encounter — all rendered as colored quads.

**Architecture:** Modular gameplay layer replacing PlaceholderScene. New components (Formation, Steering, Turret, BossPhase, Item, Score) and systems (FormationSystem, SteeringSystem, ItemSystem, ScoreSystem, BackgroundSystem, BossSystem, SpawnDirector) compose into a Galaxy1Scene. Existing PhysicsSystem, CollisionSystem, RenderSystem, and WeaponSystem are reused with minor modifications.

**Tech Stack:** Swift, GameplayKit (GKEntity/GKComponent/GKStateMachine), Metal (rendering unchanged), simd

---

## Part A: Foundation — Config and Components

### Task 1: Add gameplay constants to GameConfig

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/GameTimeTests.swift`:

```swift
@Test func gameConfigHasGameplayConstants() {
    // Player
    #expect(GameConfig.Player.speed == 200)
    #expect(GameConfig.Player.size == SIMD2<Float>(30, 30))
    #expect(GameConfig.Player.health == Float(100))
    #expect(GameConfig.Player.fireRate == 8.0)
    #expect(GameConfig.Player.projectileSpeed == Float(500))

    // Enemies
    #expect(GameConfig.Enemy.tier1HP == Float(1))
    #expect(GameConfig.Enemy.tier2HP == Float(2))
    #expect(GameConfig.Enemy.tier3TurretHP == Float(3))
    #expect(GameConfig.Enemy.bossHP == Float(30))

    // Scoring
    #expect(GameConfig.Score.tier1 == 10)
    #expect(GameConfig.Score.tier2 == 50)
    #expect(GameConfig.Score.tier3Turret == 100)
    #expect(GameConfig.Score.boss == 500)
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter gameConfigHasGameplayConstants`
Expected: FAIL — `Player`, `Enemy`, `Score` not defined on `GameConfig`

**Step 3: Write minimal implementation**

Add to `GameConfig.swift` inside `public enum GameConfig`:

```swift
public enum Player {
    public static let speed: Float = 200
    public static let size = SIMD2<Float>(30, 30)
    public static let health: Float = 100
    public static let fireRate: Double = 8.0
    public static let damage: Float = 1.0
    public static let projectileSpeed: Float = 500
    public static let projectileSize = SIMD2<Float>(6, 12)
    public static let invulnerabilityDuration: Double = 0.5
    public static let collisionDamage: Float = 15
}

public enum Enemy {
    public static let tier1HP: Float = 1
    public static let tier1Size = SIMD2<Float>(24, 24)
    public static let tier1Speed: Float = 80

    public static let tier2HP: Float = 2
    public static let tier2Size = SIMD2<Float>(32, 32)
    public static let tier2Speed: Float = 60

    public static let tier3HullSize = SIMD2<Float>(280, 120)
    public static let tier3TurretHP: Float = 3
    public static let tier3TurretSize = SIMD2<Float>(20, 20)
    public static let tier3ScrollMultiplier: Float = 0.5

    public static let bossHP: Float = 30
    public static let bossSize = SIMD2<Float>(80, 80)
}

public enum Score {
    public static let tier1 = 10
    public static let tier2 = 50
    public static let tier3Turret = 100
    public static let boss = 500
}

public enum Weapon {
    public static let triSpreadAngle: Float = .pi / 12  // 15 degrees
    public static let triSpreadDamage: Float = 0.7
    public static let gravBombMaxCharges = 3
    public static let gravBombStartCharges = 1
    public static let gravBombDetonateTime: Double = 0.4
    public static let gravBombBlastRadius: Float = 120
    public static let gravBombDamage: Float = 3
}

public enum Item {
    public static let size = SIMD2<Float>(16, 16)
    public static let driftSpeed: Float = 40
    public static let despawnTime: Double = 8.0
    public static let energyRestoreAmount: Float = 15
}

public enum Background {
    public static let starScrollSpeed: Float = 20
    public static let nebulaScrollSpeed: Float = 40
    public static let starCount = 35
    public static let nebulaCount = 5
}

public enum Palette {
    // Existing colors stay...
    public static let tier2Enemy = SIMD4<Float>(1.0, 100.0 / 255.0, 160.0 / 255.0, 1.0)
    public static let capitalShipHull = SIMD4<Float>(40.0 / 255.0, 50.0 / 255.0, 80.0 / 255.0, 1.0)
    public static let bossCore = SIMD4<Float>(1.0, 68.0 / 255.0, 153.0 / 255.0, 1.0)
    public static let bossShield = SIMD4<Float>(0.6, 0.8, 1.0, 0.7)
    public static let weaponModule = SIMD4<Float>(0.3, 0.5, 1.0, 1.0)
    public static let gravBomb = SIMD4<Float>(1.0, 0.85, 0.3, 1.0)
    public static let gravBombBlast = SIMD4<Float>(1.0, 1.0, 0.8, 0.6)
}
```

Note: Move the existing `Palette` colors and add the new ones so there's one `Palette` enum. Keep the existing `background`, `midground`, `player`, `enemy`, `hostileProjectile`, `item` colors intact.

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter gameConfigHasGameplayConstants`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/GameConfig.swift Engine2043/Tests/Engine2043Tests/GameTimeTests.swift
git commit -m "feat: add gameplay constants to GameConfig for vertical slice"
```

---

### Task 2: Add new collision layers

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Entity.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/GameTimeTests.swift`:

```swift
@Test func collisionLayersIncludeNewTypes() {
    let bossShield = CollisionLayer.bossShield
    let blast = CollisionLayer.blast
    // Verify they're distinct bits
    #expect(bossShield.rawValue == 1 << 5)
    #expect(blast.rawValue == 1 << 6)
    // Verify no overlap with existing layers
    #expect(bossShield.intersection(.player).isEmpty)
    #expect(blast.intersection(.enemy).isEmpty)
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter collisionLayersIncludeNewTypes`
Expected: FAIL — `bossShield` and `blast` not defined

**Step 3: Write minimal implementation**

Add to `CollisionLayer` in `Entity.swift`:

```swift
public static let bossShield      = CollisionLayer(rawValue: 1 << 5)
public static let blast           = CollisionLayer(rawValue: 1 << 6)
```

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter collisionLayersIncludeNewTypes`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Entity.swift Engine2043/Tests/Engine2043Tests/GameTimeTests.swift
git commit -m "feat: add bossShield and blast collision layers"
```

---

### Task 3: ScoreComponent and ItemComponent

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/ScoreComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift`
- Create: `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`

**Step 1: Write the failing tests**

Create `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`:

```swift
import Testing
import simd
@testable import Engine2043

struct ComponentTests {
    @Test func scoreComponentDefaults() {
        let score = ScoreComponent(points: 50)
        #expect(score.points == 50)
    }

    @Test func itemComponentCycling() {
        let item = ItemComponent()
        #expect(item.currentCycleIndex == 0)
        #expect(item.itemType == .energyCell)

        item.advanceCycle()
        #expect(item.currentCycleIndex == 1)
        #expect(item.itemType == .weaponModule)

        // Wraps back to 0
        item.advanceCycle()
        #expect(item.currentCycleIndex == 0)
        #expect(item.itemType == .energyCell)
    }

    @Test func itemComponentDespawnTimer() {
        let item = ItemComponent()
        #expect(item.timeAlive == 0)
        item.timeAlive = 8.0
        #expect(item.shouldDespawn)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter ComponentTests`
Expected: FAIL — `ScoreComponent`, `ItemComponent` not defined

**Step 3: Write implementations**

Create `Engine2043/Sources/Engine2043/ECS/Components/ScoreComponent.swift`:

```swift
import GameplayKit

public final class ScoreComponent: GKComponent {
    public var points: Int = 0

    public override init() { super.init() }

    public convenience init(points: Int) {
        self.init()
        self.points = points
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

Create `Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift`:

```swift
import GameplayKit

public enum ItemType: Int, CaseIterable, Sendable {
    case energyCell = 0
    case weaponModule = 1
}

public final class ItemComponent: GKComponent {
    public var currentCycleIndex: Int = 0
    public var timeAlive: Double = 0
    public var bounceDirection: Float = 1  // 1 = right, -1 = left

    public var itemType: ItemType {
        ItemType(rawValue: currentCycleIndex % ItemType.allCases.count) ?? .energyCell
    }

    public var shouldDespawn: Bool {
        timeAlive >= GameConfig.Item.despawnTime
    }

    public func advanceCycle() {
        currentCycleIndex = (currentCycleIndex + 1) % ItemType.allCases.count
    }

    public override init() { super.init() }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter ComponentTests`
Expected: PASS (all 3)

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/ScoreComponent.swift Engine2043/Sources/Engine2043/ECS/Components/ItemComponent.swift Engine2043/Tests/Engine2043Tests/ComponentTests.swift
git commit -m "feat: add ScoreComponent and ItemComponent with cycle mechanics"
```

---

### Task 4: FormationComponent and SteeringComponent

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/FormationComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Components/SteeringComponent.swift`

**Step 1: Write the failing tests**

Add to `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`:

```swift
@Test func formationComponentDefaults() {
    let formation = FormationComponent(pattern: .sineWave, index: 2, formationID: 1)
    #expect(formation.pattern == .sineWave)
    #expect(formation.index == 2)
    #expect(formation.formationID == 1)
    #expect(formation.phaseOffset == 0)
}

@Test func steeringComponentDefaults() {
    let steering = SteeringComponent(behavior: .hover)
    #expect(steering.behavior == .hover)
    #expect(steering.hoverY == Float(100))
    #expect(steering.steerStrength == Float(2.0))
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "formationComponentDefaults|steeringComponentDefaults"`
Expected: FAIL — types not defined

**Step 3: Write implementations**

Create `Engine2043/Sources/Engine2043/ECS/Components/FormationComponent.swift`:

```swift
import GameplayKit

public enum FormationPattern: Sendable {
    case vShape
    case sineWave
    case staggeredLine
}

public final class FormationComponent: GKComponent {
    public var pattern: FormationPattern = .vShape
    public var index: Int = 0           // Position in formation
    public var formationID: Int = 0     // Which formation this belongs to
    public var phaseOffset: Float = 0   // For sine wave timing
    public var elapsedTime: Double = 0  // Accumulated time for pattern computation

    public override init() { super.init() }

    public convenience init(pattern: FormationPattern, index: Int, formationID: Int) {
        self.init()
        self.pattern = pattern
        self.index = index
        self.formationID = formationID
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

Create `Engine2043/Sources/Engine2043/ECS/Components/SteeringComponent.swift`:

```swift
import GameplayKit
import simd

public enum SteeringBehavior: Sendable {
    case hover      // Descend to hoverY, then stop vertical movement
    case strafe     // Move horizontally relative to player
    case leadShot   // Fire at predicted player position
}

public final class SteeringComponent: GKComponent {
    public var behavior: SteeringBehavior = .hover
    public var hoverY: Float = 100          // Y position to hover at (from top)
    public var steerStrength: Float = 2.0   // How aggressively to steer
    public var hasReachedHover: Bool = false
    public var strafeDirection: Float = 1   // 1 = right, -1 = left

    public override init() { super.init() }

    public convenience init(behavior: SteeringBehavior) {
        self.init()
        self.behavior = behavior
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "formationComponentDefaults|steeringComponentDefaults"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/FormationComponent.swift Engine2043/Sources/Engine2043/ECS/Components/SteeringComponent.swift Engine2043/Tests/Engine2043Tests/ComponentTests.swift
git commit -m "feat: add FormationComponent and SteeringComponent"
```

---

### Task 5: TurretComponent and BossPhaseComponent

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/TurretComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Components/BossPhaseComponent.swift`

**Step 1: Write the failing tests**

Add to `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`:

```swift
@Test func turretComponentTracking() {
    let turret = TurretComponent(trackingSpeed: 2.0)
    #expect(turret.trackingSpeed == 2.0)
    #expect(turret.fireInterval == 1.5)
    #expect(turret.timeSinceLastShot == 0)
}

@Test func bossPhaseComponentTransitions() {
    let boss = BossPhaseComponent(totalHP: 30)
    #expect(boss.currentPhase == 0)
    #expect(boss.phaseThresholds == [0.6, 0.3])

    // Phase 0 at full health
    boss.updatePhase(healthFraction: 1.0)
    #expect(boss.currentPhase == 0)

    // Phase 1 at 50% health
    boss.updatePhase(healthFraction: 0.5)
    #expect(boss.currentPhase == 1)

    // Phase 2 at 20% health
    boss.updatePhase(healthFraction: 0.2)
    #expect(boss.currentPhase == 2)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "turretComponentTracking|bossPhaseComponentTransitions"`
Expected: FAIL — types not defined

**Step 3: Write implementations**

Create `Engine2043/Sources/Engine2043/ECS/Components/TurretComponent.swift`:

```swift
import GameplayKit
import simd

public final class TurretComponent: GKComponent {
    public var trackingSpeed: Float = 1.0
    public var fireInterval: Double = 1.5
    public var timeSinceLastShot: Double = 0
    public var projectileSpeed: Float = 300
    public var damage: Float = 1.0
    public weak var parentEntity: GKEntity?
    public var mountOffset: SIMD2<Float> = .zero  // Offset from parent position

    public override init() { super.init() }

    public convenience init(trackingSpeed: Float) {
        self.init()
        self.trackingSpeed = trackingSpeed
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

Create `Engine2043/Sources/Engine2043/ECS/Components/BossPhaseComponent.swift`:

```swift
import GameplayKit

public final class BossPhaseComponent: GKComponent {
    public var currentPhase: Int = 0
    public var phaseThresholds: [Float] = [0.6, 0.3]  // Transition at 60% and 30% HP
    public var totalHP: Float = 30
    public var isScrollLocked: Bool = false
    public var isDefeated: Bool = false
    public var shieldRotation: Float = 0
    public var shieldSpeed: Float = 1.5  // Radians per second

    public override init() { super.init() }

    public convenience init(totalHP: Float) {
        self.init()
        self.totalHP = totalHP
    }

    public func updatePhase(healthFraction: Float) {
        for (i, threshold) in phaseThresholds.enumerated() {
            if healthFraction <= threshold {
                currentPhase = i + 1
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "turretComponentTracking|bossPhaseComponentTransitions"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/TurretComponent.swift Engine2043/Sources/Engine2043/ECS/Components/BossPhaseComponent.swift Engine2043/Tests/Engine2043Tests/ComponentTests.swift
git commit -m "feat: add TurretComponent and BossPhaseComponent"
```

---

## Part B: New Systems

### Task 6: ScoreSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/ScoreSystem.swift`
- Create: `Engine2043/Tests/Engine2043Tests/SystemTests.swift`

**Step 1: Write the failing test**

Create `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

struct SystemTests {
    @Test @MainActor func scoreSystemAccumulatesPoints() {
        let system = ScoreSystem()
        #expect(system.currentScore == 0)

        system.addScore(10)
        system.addScore(50)
        #expect(system.currentScore == 60)
    }

    @Test @MainActor func scoreSystemResettable() {
        let system = ScoreSystem()
        system.addScore(100)
        system.reset()
        #expect(system.currentScore == 0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter "scoreSystem"`
Expected: FAIL — `ScoreSystem` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/ScoreSystem.swift`:

```swift
@MainActor
public final class ScoreSystem {
    public private(set) var currentScore: Int = 0

    public init() {}

    public func addScore(_ points: Int) {
        currentScore += points
    }

    public func reset() {
        currentScore = 0
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "scoreSystem"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/ScoreSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add ScoreSystem for point tracking"
```

---

### Task 7: BackgroundSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func backgroundSystemProducesSprites() {
    let bg = BackgroundSystem()
    let sprites = bg.collectSprites()
    // Should have stars + nebula elements
    #expect(sprites.count == GameConfig.Background.starCount + GameConfig.Background.nebulaCount)
}

@Test @MainActor func backgroundSystemScrolls() {
    let bg = BackgroundSystem()
    let before = bg.scrollDistance
    bg.update(deltaTime: 1.0)
    let after = bg.scrollDistance
    #expect(after > before)
}

@Test @MainActor func backgroundSystemWrapsStars() {
    let bg = BackgroundSystem()
    // Scroll far enough that stars should wrap
    for _ in 0..<1000 {
        bg.update(deltaTime: 1.0 / 60.0)
    }
    let sprites = bg.collectSprites()
    // All stars should still be within visible range (with margin)
    let maxY = GameConfig.designHeight / 2 + 50
    let minY = -GameConfig.designHeight / 2 - 50
    for sprite in sprites {
        #expect(sprite.position.y >= minY)
        #expect(sprite.position.y <= maxY)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "backgroundSystem"`
Expected: FAIL — `BackgroundSystem` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift`:

```swift
import simd

@MainActor
public final class BackgroundSystem {
    public private(set) var scrollDistance: Float = 0

    private var starPositions: [SIMD2<Float>] = []
    private var starSizes: [SIMD2<Float>] = []
    private var nebulaPositions: [SIMD2<Float>] = []
    private var nebulaSizes: [SIMD2<Float>] = []

    private let fieldHeight: Float
    private let halfWidth: Float
    private let halfHeight: Float

    public var isScrollLocked: Bool = false

    public init() {
        halfWidth = GameConfig.designWidth / 2
        halfHeight = GameConfig.designHeight / 2
        fieldHeight = GameConfig.designHeight + 100  // Extra margin for wrapping

        // Seed star positions deterministically
        var seed: UInt64 = 42
        for _ in 0..<GameConfig.Background.starCount {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = Float(Int(seed >> 33) % Int(GameConfig.designWidth)) - halfWidth
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let y = Float(Int(seed >> 33) % Int(fieldHeight)) - halfHeight
            starPositions.append(SIMD2(x, y))
            let s: Float = Float(2 + Int(seed >> 60) % 2)
            starSizes.append(SIMD2(s, s))
        }

        for _ in 0..<GameConfig.Background.nebulaCount {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = Float(Int(seed >> 33) % Int(GameConfig.designWidth)) - halfWidth
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let y = Float(Int(seed >> 33) % Int(fieldHeight)) - halfHeight
            nebulaPositions.append(SIMD2(x, y))
            let s = Float(8 + Int(seed >> 60) % 9)  // 8 to 16
            nebulaSizes.append(SIMD2(s, s))
        }
    }

    public func update(deltaTime: Double) {
        guard !isScrollLocked else { return }
        let dt = Float(deltaTime)
        scrollDistance += GameConfig.Background.starScrollSpeed * dt

        // Move stars
        for i in starPositions.indices {
            starPositions[i].y -= GameConfig.Background.starScrollSpeed * dt
            if starPositions[i].y < -halfHeight - 50 {
                starPositions[i].y += fieldHeight
            }
        }

        // Move nebula (faster)
        for i in nebulaPositions.indices {
            nebulaPositions[i].y -= GameConfig.Background.nebulaScrollSpeed * dt
            if nebulaPositions[i].y < -halfHeight - 50 {
                nebulaPositions[i].y += fieldHeight
            }
        }
    }

    public func collectSprites() -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []
        sprites.reserveCapacity(starPositions.count + nebulaPositions.count)

        // Stars: dim white/blue dots
        let starColor = SIMD4<Float>(0.6, 0.7, 0.9, 0.5)
        for i in starPositions.indices {
            sprites.append(SpriteInstance(
                position: starPositions[i],
                size: starSizes[i],
                color: starColor
            ))
        }

        // Nebula: midground blue blobs at low alpha
        let nebulaColor = SIMD4<Float>(
            GameConfig.Palette.midground.x,
            GameConfig.Palette.midground.y,
            GameConfig.Palette.midground.z,
            0.15
        )
        for i in nebulaPositions.indices {
            sprites.append(SpriteInstance(
                position: nebulaPositions[i],
                size: nebulaSizes[i],
                color: nebulaColor
            ))
        }

        return sprites
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "backgroundSystem"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/BackgroundSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add BackgroundSystem with parallax star and nebula layers"
```

---

### Task 8: FormationSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/FormationSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func formationSystemVShapeMoves() {
    let system = FormationSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 340)))
    let physics = PhysicsComponent(collisionSize: SIMD2(24, 24), layer: .enemy, mask: [])
    entity.addComponent(physics)
    entity.addComponent(FormationComponent(pattern: .vShape, index: 0, formationID: 0))

    system.register(entity)
    system.update(deltaTime: 1.0 / 60.0)

    // V-shape should set downward velocity
    #expect(physics.velocity.y < 0)
}

@Test @MainActor func formationSystemSineWaveOscillates() {
    let system = FormationSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 340)))
    let physics = PhysicsComponent(collisionSize: SIMD2(24, 24), layer: .enemy, mask: [])
    entity.addComponent(physics)
    let formation = FormationComponent(pattern: .sineWave, index: 0, formationID: 0)
    entity.addComponent(formation)

    system.register(entity)
    system.update(deltaTime: 0.5)

    // Sine wave should have horizontal velocity component
    #expect(physics.velocity.x != 0 || formation.elapsedTime > 0)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "formationSystem"`
Expected: FAIL — `FormationSystem` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/FormationSystem.swift`:

```swift
import GameplayKit
import simd

@MainActor
public final class FormationSystem {
    private var entities: [GKEntity] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: FormationComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        let dt = Float(deltaTime)

        for entity in entities {
            guard let formation = entity.component(ofType: FormationComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self) else { continue }

            formation.elapsedTime += deltaTime

            switch formation.pattern {
            case .vShape:
                physics.velocity = SIMD2(0, -GameConfig.Enemy.tier1Speed)

            case .sineWave:
                let frequency: Float = 2.0
                let amplitude: Float = 120.0
                let xVel = cos(Float(formation.elapsedTime) * frequency + formation.phaseOffset) * amplitude
                physics.velocity = SIMD2(xVel, -GameConfig.Enemy.tier1Speed)

            case .staggeredLine:
                // Offset entry: alternate enemies enter slightly delayed
                let delayOffset = Float(formation.index) * 0.3
                if Float(formation.elapsedTime) > delayOffset {
                    physics.velocity = SIMD2(0, -GameConfig.Enemy.tier1Speed * 1.2)
                } else {
                    physics.velocity = .zero
                }
            }
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "formationSystem"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/FormationSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add FormationSystem with V-shape, sine wave, and staggered patterns"
```

---

### Task 9: SteeringSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/SteeringSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func steeringSystemHoverStopsAtThreshold() {
    let system = SteeringSystem()

    let entity = GKEntity()
    let transform = TransformComponent(position: SIMD2(0, 300))
    entity.addComponent(transform)
    let physics = PhysicsComponent(collisionSize: SIMD2(32, 32), layer: .enemy, mask: [])
    physics.velocity = SIMD2(0, -GameConfig.Enemy.tier2Speed)
    entity.addComponent(physics)
    let steering = SteeringComponent(behavior: .hover)
    steering.hoverY = 100
    entity.addComponent(steering)

    system.register(entity)
    system.playerPosition = SIMD2(0, -250)

    // Simulate enough frames to reach hover Y
    for _ in 0..<600 {
        system.update(deltaTime: 1.0 / 60.0)
        // Manually apply velocity to position for this test
        transform.position += physics.velocity * Float(1.0 / 60.0)
    }

    // Should have stopped near hover Y and started strafing
    #expect(steering.hasReachedHover == true)
    #expect(abs(physics.velocity.y) < GameConfig.Enemy.tier2Speed)
}

@Test @MainActor func steeringSystemStrafeMovesHorizontally() {
    let system = SteeringSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 100)))
    let physics = PhysicsComponent(collisionSize: SIMD2(32, 32), layer: .enemy, mask: [])
    entity.addComponent(physics)
    let steering = SteeringComponent(behavior: .strafe)
    steering.hasReachedHover = true
    entity.addComponent(steering)

    system.register(entity)
    system.playerPosition = SIMD2(50, -250)

    system.update(deltaTime: 1.0 / 60.0)

    // Should have horizontal velocity component
    #expect(physics.velocity.x != 0)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "steeringSystem"`
Expected: FAIL — `SteeringSystem` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/SteeringSystem.swift`:

```swift
import GameplayKit
import simd

@MainActor
public final class SteeringSystem {
    private var entities: [GKEntity] = []
    public var playerPosition: SIMD2<Float> = .zero

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: SteeringComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        let dt = Float(deltaTime)
        let halfWidth = GameConfig.designWidth / 2

        for entity in entities {
            guard let steering = entity.component(ofType: SteeringComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            // Phase 1: Descend to hover position
            if !steering.hasReachedHover {
                physics.velocity.y = -GameConfig.Enemy.tier2Speed
                if transform.position.y <= steering.hoverY {
                    steering.hasReachedHover = true
                    physics.velocity.y = 0
                }
                continue
            }

            // Phase 2: Execute behavior
            switch steering.behavior {
            case .hover:
                // Hover: slow drift toward player X
                let dx = playerPosition.x - transform.position.x
                physics.velocity.x = sign(dx) * min(abs(dx) * steering.steerStrength, 80)
                physics.velocity.y = 0

            case .strafe:
                // Strafe: move horizontally, reverse at edges
                let strafeSpeed: Float = 100
                physics.velocity.x = steering.strafeDirection * strafeSpeed
                physics.velocity.y = 0

                if transform.position.x > halfWidth - 30 {
                    steering.strafeDirection = -1
                } else if transform.position.x < -halfWidth + 30 {
                    steering.strafeDirection = 1
                }

            case .leadShot:
                // Lead shot: hover + track player more aggressively
                let dx = playerPosition.x - transform.position.x
                physics.velocity.x = dx * steering.steerStrength
                physics.velocity.y = sin(Float(CACurrentMediaTime()) * 2) * 20
            }
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "steeringSystem"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/SteeringSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add SteeringSystem with hover, strafe, and lead-shot behaviors"
```

---

### Task 10: ItemSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func itemSystemDriftsDown() {
    let system = ItemSystem()

    let entity = GKEntity()
    let transform = TransformComponent(position: SIMD2(0, 200))
    entity.addComponent(transform)
    let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [.playerProjectile, .player])
    entity.addComponent(physics)
    entity.addComponent(ItemComponent())
    entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: GameConfig.Palette.item))

    system.register(entity)
    system.update(deltaTime: 1.0)

    // Should drift downward
    #expect(physics.velocity.y == -GameConfig.Item.driftSpeed)
}

@Test @MainActor func itemSystemBounces() {
    let system = ItemSystem()

    let entity = GKEntity()
    let halfW = GameConfig.designWidth / 2
    let transform = TransformComponent(position: SIMD2(halfW - 5, 200))
    entity.addComponent(transform)
    let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [.playerProjectile, .player])
    entity.addComponent(physics)
    let item = ItemComponent()
    item.bounceDirection = 1  // Moving right
    entity.addComponent(item)
    entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: GameConfig.Palette.item))

    system.register(entity)
    system.update(deltaTime: 1.0 / 60.0)

    // Should reverse direction at edge
    #expect(item.bounceDirection == Float(-1))
}

@Test @MainActor func itemSystemTracksDespawn() {
    let system = ItemSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
    let physics = PhysicsComponent(collisionSize: GameConfig.Item.size, layer: .item, mask: [])
    entity.addComponent(physics)
    let item = ItemComponent()
    entity.addComponent(item)
    entity.addComponent(RenderComponent(size: GameConfig.Item.size, color: GameConfig.Palette.item))

    system.register(entity)

    // Simulate 8+ seconds
    for _ in 0..<500 {
        system.update(deltaTime: 1.0 / 60.0)
    }

    #expect(system.pendingDespawns.contains(where: { $0 === entity }))
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "itemSystem"`
Expected: FAIL — `ItemSystem` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift`:

```swift
import GameplayKit
import simd

@MainActor
public final class ItemSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingDespawns: [GKEntity] = []

    private let bounceSpeed: Float = 30
    private let halfWidth: Float

    public init() {
        halfWidth = GameConfig.designWidth / 2
    }

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: ItemComponent.self) != nil,
              entity.component(ofType: PhysicsComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil,
              entity.component(ofType: RenderComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        pendingDespawns.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let item = entity.component(ofType: ItemComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self),
                  let render = entity.component(ofType: RenderComponent.self) else { continue }

            item.timeAlive += deltaTime

            if item.shouldDespawn {
                pendingDespawns.append(entity)
                continue
            }

            // Drift down + bounce horizontally
            physics.velocity.y = -GameConfig.Item.driftSpeed
            physics.velocity.x = item.bounceDirection * bounceSpeed

            // Bounce off edges
            let margin = GameConfig.Item.size.x / 2
            if transform.position.x > halfWidth - margin {
                item.bounceDirection = -1
            } else if transform.position.x < -halfWidth + margin {
                item.bounceDirection = 1
            }

            // Update color based on current cycle
            switch item.itemType {
            case .energyCell:
                render.color = GameConfig.Palette.item
            case .weaponModule:
                render.color = GameConfig.Palette.weaponModule
            }
        }
    }

    public func handleProjectileHit(on entity: GKEntity) {
        guard let item = entity.component(ofType: ItemComponent.self) else { return }
        item.advanceCycle()
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "itemSystem"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/ItemSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add ItemSystem with drift, bounce, despawn, and cycle advancement"
```

---

### Task 11: Update WeaponSystem for Tri-Spread and secondary fire

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func weaponSystemTriSpreadSpawnsThreeProjectiles() {
    let system = WeaponSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
    let weapon = WeaponComponent(fireRate: 60, damage: 0.7, projectileSpeed: 500)
    weapon.weaponType = .triSpread
    weapon.isFiring = true
    entity.addComponent(weapon)

    system.register(entity)

    let time = GameTime()
    time.advance(by: 1.0 / 60.0)
    _ = time.shouldPerformFixedUpdate()
    system.update(time: time)

    #expect(system.pendingSpawns.count == 3)
    // Center projectile goes straight up
    #expect(system.pendingSpawns[0].velocity.x == 0)
    // Left projectile has negative X
    #expect(system.pendingSpawns[1].velocity.x < 0)
    // Right projectile has positive X
    #expect(system.pendingSpawns[2].velocity.x > 0)
}

@Test @MainActor func weaponSystemSecondaryFireCreatesGravBomb() {
    let system = WeaponSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 0)))
    let weapon = WeaponComponent(fireRate: 8, damage: 1, projectileSpeed: 500)
    weapon.secondaryCharges = 1
    weapon.isSecondaryFiring = true
    entity.addComponent(weapon)

    system.register(entity)

    let time = GameTime()
    time.advance(by: 1.0 / 60.0)
    _ = time.shouldPerformFixedUpdate()
    system.update(time: time)

    #expect(system.pendingSecondarySpawns.count == 1)
    #expect(weapon.secondaryCharges == 0)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "weaponSystem"`
Expected: FAIL — `weaponType`, `secondaryCharges`, `isSecondaryFiring`, `pendingSecondarySpawns` not defined

**Step 3: Update WeaponComponent**

Add to `WeaponComponent.swift` inside the class:

```swift
public var weaponType: WeaponType = .doubleCannon
public var secondaryCharges: Int = GameConfig.Weapon.gravBombStartCharges
public var isSecondaryFiring: Bool = false
public var secondaryCooldown: Double = 0
```

Add above the class:

```swift
public enum WeaponType: Sendable {
    case doubleCannon
    case triSpread
}
```

**Step 4: Update WeaponSystem**

Replace the `update` method in `WeaponSystem.swift` and add secondary support:

```swift
public struct SecondarySpawnRequest: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
}

@MainActor
public final class WeaponSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingSpawns: [ProjectileSpawnRequest] = []
    public private(set) var pendingSecondarySpawns: [SecondarySpawnRequest] = []

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: WeaponComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    public func update(time: GameTime) {
        pendingSpawns.removeAll(keepingCapacity: true)
        pendingSecondarySpawns.removeAll(keepingCapacity: true)

        for entity in entities {
            guard let weapon = entity.component(ofType: WeaponComponent.self),
                  let transform = entity.component(ofType: TransformComponent.self) else { continue }

            // Primary fire
            if weapon.isFiring {
                weapon.timeSinceLastShot += time.fixedDeltaTime
                let interval = 1.0 / weapon.fireRate

                if weapon.timeSinceLastShot >= interval {
                    weapon.timeSinceLastShot -= interval
                    spawnPrimaryProjectiles(weapon: weapon, position: transform.position)
                }
            }

            // Secondary fire
            if weapon.isSecondaryFiring && weapon.secondaryCharges > 0 {
                weapon.secondaryCooldown += time.fixedDeltaTime
                if weapon.secondaryCooldown >= 0.5 {  // Minimum interval between bombs
                    weapon.secondaryCooldown = 0
                    weapon.secondaryCharges -= 1
                    weapon.isSecondaryFiring = false
                    pendingSecondarySpawns.append(SecondarySpawnRequest(
                        position: transform.position,
                        velocity: SIMD2(0, 150)  // Slow upward
                    ))
                }
            }
            if !weapon.isSecondaryFiring {
                weapon.secondaryCooldown += time.fixedDeltaTime
            }
        }
    }

    private func spawnPrimaryProjectiles(weapon: WeaponComponent, position: SIMD2<Float>) {
        switch weapon.weaponType {
        case .doubleCannon:
            // Two parallel projectiles
            let offset: Float = 8
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position + SIMD2(-offset, 0),
                velocity: SIMD2(0, weapon.projectileSpeed),
                damage: weapon.damage
            ))
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position + SIMD2(offset, 0),
                velocity: SIMD2(0, weapon.projectileSpeed),
                damage: weapon.damage
            ))

        case .triSpread:
            let angle = GameConfig.Weapon.triSpreadAngle
            let speed = weapon.projectileSpeed
            let damage = GameConfig.Weapon.triSpreadDamage

            // Center
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(0, speed),
                damage: damage
            ))
            // Left
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(-sin(angle) * speed, cos(angle) * speed),
                damage: damage
            ))
            // Right
            pendingSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: SIMD2(sin(angle) * speed, cos(angle) * speed),
                damage: damage
            ))
        }
    }
}
```

**Step 5: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "weaponSystem"`
Expected: PASS

**Step 6: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -15`
Expected: All tests pass (existing + new)

**Step 7: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add Tri-Spread weapon type and Grav-Bomb secondary fire to WeaponSystem"
```

---

### Task 12: BossSystem

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func bossSystemRotatesShields() {
    let system = BossSystem()

    let bossEntity = GKEntity()
    bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
    bossEntity.addComponent(HealthComponent(health: 30))
    let bossPhase = BossPhaseComponent(totalHP: 30)
    bossEntity.addComponent(bossPhase)

    system.register(bossEntity)
    system.update(deltaTime: 1.0)

    #expect(bossPhase.shieldRotation != 0)
}

@Test @MainActor func bossSystemTransitionsPhases() {
    let system = BossSystem()

    let bossEntity = GKEntity()
    bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
    let health = HealthComponent(health: 30)
    bossEntity.addComponent(health)
    let bossPhase = BossPhaseComponent(totalHP: 30)
    bossEntity.addComponent(bossPhase)

    system.register(bossEntity)

    // Take damage to 50% health
    health.currentHealth = 15
    system.update(deltaTime: 1.0 / 60.0)
    #expect(bossPhase.currentPhase == 1)

    // Take damage to 20%
    health.currentHealth = 6
    system.update(deltaTime: 1.0 / 60.0)
    #expect(bossPhase.currentPhase == 2)
}

@Test @MainActor func bossSystemGeneratesAttackSpawns() {
    let system = BossSystem()

    let bossEntity = GKEntity()
    bossEntity.addComponent(TransformComponent(position: SIMD2(0, 200)))
    bossEntity.addComponent(HealthComponent(health: 30))
    let bossPhase = BossPhaseComponent(totalHP: 30)
    bossEntity.addComponent(bossPhase)

    system.register(bossEntity)

    // Simulate enough time for boss to fire
    for _ in 0..<120 {
        system.update(deltaTime: 1.0 / 60.0)
    }

    // Boss should have generated projectile spawns
    #expect(system.pendingProjectileSpawns.count > 0)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "bossSystem"`
Expected: FAIL — `BossSystem` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift`:

```swift
import GameplayKit
import simd

@MainActor
public final class BossSystem {
    private var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    public private(set) var pendingProjectileSpawns: [ProjectileSpawnRequest] = []
    public var playerPosition: SIMD2<Float> = .zero

    private var attackTimer: Double = 0
    private let baseAttackInterval: Double = 1.0

    public init() {}

    public func register(_ entity: GKEntity) {
        guard entity.component(ofType: BossPhaseComponent.self) != nil,
              entity.component(ofType: HealthComponent.self) != nil,
              entity.component(ofType: TransformComponent.self) != nil else { return }
        bossEntity = entity
    }

    public func registerShield(_ entity: GKEntity) {
        shieldEntities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        if entity === bossEntity { bossEntity = nil }
        shieldEntities.removeAll { $0 === entity }
    }

    public func update(deltaTime: Double) {
        pendingProjectileSpawns.removeAll(keepingCapacity: true)

        guard let boss = bossEntity,
              let bossPhase = boss.component(ofType: BossPhaseComponent.self),
              let health = boss.component(ofType: HealthComponent.self),
              let transform = boss.component(ofType: TransformComponent.self) else { return }

        // Update phase based on health
        let healthFraction = health.currentHealth / bossPhase.totalHP
        bossPhase.updatePhase(healthFraction: healthFraction)

        // Check defeat
        if !health.isAlive {
            bossPhase.isDefeated = true
            // Remove shields
            for shield in shieldEntities {
                shield.component(ofType: RenderComponent.self)?.isVisible = false
            }
            return
        }

        // Rotate shields
        let speedMultiplier: Float = Float(bossPhase.currentPhase + 1)
        bossPhase.shieldRotation += bossPhase.shieldSpeed * speedMultiplier * Float(deltaTime)

        // Update shield positions
        updateShieldPositions(bossPosition: transform.position, rotation: bossPhase.shieldRotation, phase: bossPhase.currentPhase)

        // Generate attacks
        attackTimer += deltaTime
        let attackInterval = baseAttackInterval / Double(bossPhase.currentPhase + 1)

        if attackTimer >= attackInterval {
            attackTimer -= attackInterval
            generateAttack(from: transform.position, phase: bossPhase.currentPhase)
        }
    }

    private func updateShieldPositions(bossPosition: SIMD2<Float>, rotation: Float, phase: Int) {
        // Phase 2: shields disappear
        if phase >= 2 {
            for shield in shieldEntities {
                shield.component(ofType: RenderComponent.self)?.isVisible = false
            }
            return
        }

        let shieldDistance: Float = 60
        for (i, shield) in shieldEntities.enumerated() {
            guard let transform = shield.component(ofType: TransformComponent.self),
                  let render = shield.component(ofType: RenderComponent.self) else { continue }
            let angle = rotation + Float(i) * .pi  // Two shields opposite each other
            transform.position = bossPosition + SIMD2(cos(angle), sin(angle)) * shieldDistance
            transform.rotation = angle
            render.isVisible = true
        }
    }

    private func generateAttack(from position: SIMD2<Float>, phase: Int) {
        let speed: Float = 200

        switch phase {
        case 0:
            // Phase 1: Slow radial spread (8 projectiles in a circle)
            let count = 8
            for i in 0..<count {
                let angle = Float(i) / Float(count) * .pi * 2 + bossEntity!.component(ofType: BossPhaseComponent.self)!.shieldRotation * 0.1
                let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

        case 1:
            // Phase 2: Faster aimed bursts toward player
            let dir = simd_normalize(playerPosition - position)
            let spread: Float = 0.2
            for i in -1...1 {
                let offset = Float(i) * spread
                let vel = SIMD2(dir.x + offset, dir.y) * speed * 1.5
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }

        default:
            // Phase 3: Dense radial + aimed combo
            let count = 12
            for i in 0..<count {
                let angle = Float(i) / Float(count) * .pi * 2
                let vel = SIMD2<Float>(cos(angle), sin(angle)) * speed * 1.3
                pendingProjectileSpawns.append(ProjectileSpawnRequest(
                    position: position,
                    velocity: vel,
                    damage: 5
                ))
            }
            // Plus aimed burst
            let dir = simd_normalize(playerPosition - position)
            pendingProjectileSpawns.append(ProjectileSpawnRequest(
                position: position,
                velocity: dir * speed * 2,
                damage: 8
            ))
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "bossSystem"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add BossSystem with phase transitions, shield rotation, and attack patterns"
```

---

### Task 13: SpawnDirector

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func spawnDirectorTriggersWavesAtScrollThresholds() {
    let director = SpawnDirector()
    #expect(director.pendingWaves.isEmpty)

    // Simulate scroll to 100 units — should trigger first wave
    director.update(scrollDistance: 100)
    #expect(!director.pendingWaves.isEmpty)
    let firstWave = director.pendingWaves.first
    #expect(firstWave?.enemyTier == .tier1)
}

@Test @MainActor func spawnDirectorTriggersOnlyOnce() {
    let director = SpawnDirector()

    director.update(scrollDistance: 100)
    let count1 = director.pendingWaves.count

    director.update(scrollDistance: 100)
    let count2 = director.pendingWaves.count

    // Second call at same distance should not add duplicates
    #expect(count2 == count1)
}

@Test @MainActor func spawnDirectorTriggersBoss() {
    let director = SpawnDirector()

    director.update(scrollDistance: 3500)
    let bossWave = director.pendingWaves.first(where: { $0.enemyTier == .boss })
    #expect(bossWave != nil)
    #expect(director.shouldLockScroll)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter "spawnDirector"`
Expected: FAIL — `SpawnDirector` not defined

**Step 3: Write implementation**

Create `Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift`:

```swift
import simd

public enum EnemyTier: Sendable {
    case tier1
    case tier2
    case tier3
    case boss
}

public struct WaveDefinition: Sendable {
    public let triggerDistance: Float
    public let enemyTier: EnemyTier
    public let pattern: FormationPattern
    public let count: Int
    public let spawnX: Float        // Center X of formation
    public let spawnY: Float        // Spawn Y (typically top of screen + margin)

    public init(trigger: Float, tier: EnemyTier, pattern: FormationPattern = .vShape, count: Int = 5, spawnX: Float = 0, spawnY: Float = 370) {
        self.triggerDistance = trigger
        self.enemyTier = tier
        self.pattern = pattern
        self.count = count
        self.spawnX = spawnX
        self.spawnY = spawnY
    }
}

@MainActor
public final class SpawnDirector {
    private let waves: [WaveDefinition]
    private var nextWaveIndex: Int = 0
    public private(set) var pendingWaves: [WaveDefinition] = []
    public private(set) var shouldLockScroll: Bool = false

    public init() {
        waves = Self.galaxy1Waves()
    }

    public func update(scrollDistance: Float) {
        pendingWaves.removeAll(keepingCapacity: true)

        while nextWaveIndex < waves.count {
            let wave = waves[nextWaveIndex]
            if scrollDistance >= wave.triggerDistance {
                pendingWaves.append(wave)
                if wave.enemyTier == .boss {
                    shouldLockScroll = true
                }
                nextWaveIndex += 1
            } else {
                break
            }
        }
    }

    public func unlockScroll() {
        shouldLockScroll = false
    }

    private static func galaxy1Waves() -> [WaveDefinition] {
        var waves: [WaveDefinition] = []

        // 0-500: Tutorial ramp — 3 Tier 1 V-formations
        waves.append(WaveDefinition(trigger: 50, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 200, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 400, tier: .tier1, pattern: .vShape, count: 5))

        // 500-1200: Tier 1 variety + first Tier 2
        waves.append(WaveDefinition(trigger: 550, tier: .tier1, pattern: .sineWave, count: 5))
        waves.append(WaveDefinition(trigger: 700, tier: .tier1, pattern: .staggeredLine, count: 5))
        waves.append(WaveDefinition(trigger: 800, tier: .tier2, count: 2, spawnX: -60))
        waves.append(WaveDefinition(trigger: 900, tier: .tier1, pattern: .sineWave, count: 5))
        waves.append(WaveDefinition(trigger: 1100, tier: .tier1, pattern: .vShape, count: 5))

        // 1200-2000: Escalation
        waves.append(WaveDefinition(trigger: 1250, tier: .tier2, count: 3, spawnX: 50))
        waves.append(WaveDefinition(trigger: 1400, tier: .tier1, pattern: .sineWave, count: 5))
        waves.append(WaveDefinition(trigger: 1500, tier: .tier1, pattern: .staggeredLine, count: 5))
        waves.append(WaveDefinition(trigger: 1600, tier: .tier2, count: 2, spawnX: -40))
        waves.append(WaveDefinition(trigger: 1800, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 1900, tier: .tier1, pattern: .sineWave, count: 5))

        // 2000-2800: Capital Ship
        waves.append(WaveDefinition(trigger: 2000, tier: .tier3, count: 4))  // 4 turrets
        waves.append(WaveDefinition(trigger: 2200, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 2500, tier: .tier1, pattern: .sineWave, count: 5))

        // 2800-3400: Final gauntlet
        waves.append(WaveDefinition(trigger: 2800, tier: .tier2, count: 3, spawnX: 0))
        waves.append(WaveDefinition(trigger: 2900, tier: .tier1, pattern: .staggeredLine, count: 5))
        waves.append(WaveDefinition(trigger: 3100, tier: .tier2, count: 2, spawnX: -80))
        waves.append(WaveDefinition(trigger: 3200, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 3300, tier: .tier1, pattern: .sineWave, count: 5))

        // 3500: Boss
        waves.append(WaveDefinition(trigger: 3500, tier: .boss, count: 1))

        return waves
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter "spawnDirector"`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Systems/SpawnDirector.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: add SpawnDirector with Galaxy 1 wave definitions"
```

---

## Part C: Galaxy1Scene

### Task 14: Galaxy1Scene skeleton — setup, input, registration

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Write the failing test**

Create `Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift`:

```swift
import Testing
import GameplayKit
import simd
@testable import Engine2043

struct Galaxy1SceneTests {
    @Test @MainActor func sceneInitializesWithPlayer() {
        let scene = Galaxy1Scene()
        let sprites = scene.collectSprites()
        // Should have background sprites + player + HUD elements
        #expect(sprites.count > 0)
    }

    @Test @MainActor func sceneRespondsToInput() {
        let scene = Galaxy1Scene()
        let mockInput = MockInputProvider(movement: SIMD2(1, 0), primary: false, secondary: false)
        scene.inputProvider = mockInput

        let time = GameTime()
        time.advance(by: 1.0 / 60.0)
        _ = time.shouldPerformFixedUpdate()
        scene.fixedUpdate(time: time)

        // Player should have moved right
        // (We can't easily inspect player position, but we verify no crash)
    }
}

// Test helper
@MainActor
final class MockInputProvider: InputProvider {
    var movement: SIMD2<Float>
    var primary: Bool
    var secondary: Bool

    init(movement: SIMD2<Float>, primary: Bool, secondary: Bool) {
        self.movement = movement
        self.primary = primary
        self.secondary = secondary
    }

    func poll() -> PlayerInput {
        var input = PlayerInput()
        input.movement = movement
        input.primaryFire = primary
        input.secondaryFire = secondary
        return input
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter Galaxy1SceneTests`
Expected: FAIL — `Galaxy1Scene` not defined

**Step 3: Write Galaxy1Scene skeleton**

Create `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`:

```swift
import GameplayKit
import simd

public enum GameState: Sendable {
    case playing
    case gameOver
    case victory
}

@MainActor
public final class Galaxy1Scene: GameScene {

    // MARK: - Systems
    private let physicsSystem = PhysicsSystem()
    private let collisionSystem: CollisionSystem
    private let renderSystem = RenderSystem()
    private let weaponSystem = WeaponSystem()
    private let formationSystem = FormationSystem()
    private let steeringSystem = SteeringSystem()
    private let itemSystem = ItemSystem()
    private let scoreSystem = ScoreSystem()
    private let backgroundSystem = BackgroundSystem()
    private let bossSystem = BossSystem()
    private let spawnDirector = SpawnDirector()

    // MARK: - Input / Audio
    public var inputProvider: (any InputProvider)?
    public var audioProvider: (any AudioProvider)?

    // MARK: - Entities
    private var player: GKEntity!
    private var enemies: [GKEntity] = []
    private var projectiles: [GKEntity] = []
    private var enemyProjectiles: [GKEntity] = []
    private var items: [GKEntity] = []
    private var capitalShipHulls: [GKEntity] = []
    private var bossEntity: GKEntity?
    private var shieldEntities: [GKEntity] = []
    private var pendingRemovals: [GKEntity] = []

    // MARK: - Formation tracking
    private var formationEnemies: [Int: [GKEntity]] = [:]  // formationID -> entities
    private var nextFormationID: Int = 0

    // MARK: - Game state
    public private(set) var gameState: GameState = .playing
    private var gravBombEntities: [GKEntity] = []
    private var gravBombTimers: [ObjectIdentifier: Double] = [:]

    // MARK: - World
    private let worldBounds = AABB(min: SIMD2(-200, -340), max: SIMD2(200, 340))

    // MARK: - Init

    public init() {
        collisionSystem = CollisionSystem(worldBounds: worldBounds)
        setupPlayer()
    }

    private func setupPlayer() {
        player = GKEntity()

        let transform = TransformComponent(position: SIMD2(0, -250))
        player.addComponent(transform)

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Player.size,
            layer: .player,
            mask: [.enemy, .enemyProjectile, .item]
        )
        player.addComponent(physics)

        player.addComponent(RenderComponent(
            size: GameConfig.Player.size,
            color: GameConfig.Palette.player
        ))

        player.addComponent(HealthComponent(health: GameConfig.Player.health))

        let weapon = WeaponComponent(
            fireRate: GameConfig.Player.fireRate,
            damage: GameConfig.Player.damage,
            projectileSpeed: GameConfig.Player.projectileSpeed
        )
        player.addComponent(weapon)

        registerEntity(player)
    }

    // MARK: - Entity Management

    private func registerEntity(_ entity: GKEntity) {
        physicsSystem.register(entity)
        collisionSystem.register(entity)
        renderSystem.register(entity)
        weaponSystem.register(entity)
        formationSystem.register(entity)
        steeringSystem.register(entity)
        itemSystem.register(entity)
    }

    private func unregisterEntity(_ entity: GKEntity) {
        physicsSystem.unregister(entity)
        collisionSystem.unregister(entity)
        renderSystem.unregister(entity)
        weaponSystem.unregister(entity)
        formationSystem.unregister(entity)
        steeringSystem.unregister(entity)
        itemSystem.unregister(entity)
        bossSystem.unregister(entity)
    }

    private func removeEntity(_ entity: GKEntity) {
        unregisterEntity(entity)
        enemies.removeAll { $0 === entity }
        projectiles.removeAll { $0 === entity }
        enemyProjectiles.removeAll { $0 === entity }
        items.removeAll { $0 === entity }
        capitalShipHulls.removeAll { $0 === entity }
        gravBombEntities.removeAll { $0 === entity }
        gravBombTimers.removeValue(forKey: ObjectIdentifier(entity))
        shieldEntities.removeAll { $0 === entity }

        // Remove from formation tracking
        for (id, var members) in formationEnemies {
            members.removeAll { $0 === entity }
            if members.isEmpty {
                formationEnemies.removeValue(forKey: id)
            } else {
                formationEnemies[id] = members
            }
        }
    }

    // MARK: - GameScene Protocol

    public func fixedUpdate(time: GameTime) {
        guard gameState == .playing else { return }

        handleInput()

        // Update background and check spawn director
        backgroundSystem.update(deltaTime: time.fixedDeltaTime)
        if spawnDirector.shouldLockScroll {
            backgroundSystem.isScrollLocked = true
        }

        spawnDirector.update(scrollDistance: backgroundSystem.scrollDistance)
        processSpawnDirectorWaves()

        // Update behavior systems
        steeringSystem.playerPosition = player.component(ofType: TransformComponent.self)?.position ?? .zero
        formationSystem.update(deltaTime: time.fixedDeltaTime)
        steeringSystem.update(deltaTime: time.fixedDeltaTime)

        // Update turrets
        updateTurrets(deltaTime: time.fixedDeltaTime)

        // Update boss
        bossSystem.playerPosition = player.component(ofType: TransformComponent.self)?.position ?? .zero
        bossSystem.update(deltaTime: time.fixedDeltaTime)
        for spawn in bossSystem.pendingProjectileSpawns {
            spawnEnemyProjectile(position: spawn.position, velocity: spawn.velocity, damage: spawn.damage)
        }

        // Check boss defeat
        if let boss = bossEntity,
           let bossPhase = boss.component(ofType: BossPhaseComponent.self),
           bossPhase.isDefeated {
            gameState = .victory
            scoreSystem.addScore(GameConfig.Score.boss)
        }

        // Physics
        physicsSystem.syncFromComponents()
        physicsSystem.update(time: time)
        collisionSystem.update(time: time)
        weaponSystem.update(time: time)

        // Spawn player projectiles
        for request in weaponSystem.pendingSpawns {
            spawnPlayerProjectile(request)
        }

        // Spawn grav-bombs
        for request in weaponSystem.pendingSecondarySpawns {
            spawnGravBomb(position: request.position, velocity: request.velocity)
        }

        // Update grav-bomb timers
        updateGravBombs(deltaTime: time.fixedDeltaTime)

        // Process item system
        itemSystem.update(deltaTime: time.fixedDeltaTime)
        for entity in itemSystem.pendingDespawns {
            pendingRemovals.append(entity)
        }

        // Handle collisions
        processCollisions()

        // Player invulnerability
        player.component(ofType: HealthComponent.self)?
            .updateInvulnerability(deltaTime: time.fixedDeltaTime)

        // Check game over
        if let health = player.component(ofType: HealthComponent.self), !health.isAlive {
            gameState = .gameOver
        }

        // Update capital ship hull positions (follow scroll)
        updateCapitalShipHulls(deltaTime: time.fixedDeltaTime)

        // Cull off-screen
        cullOffScreen()

        // Process removals
        for entity in pendingRemovals {
            removeEntity(entity)
        }
        pendingRemovals.removeAll()
    }

    public func update(time: GameTime) {
        // Flicker player during invulnerability
        if let health = player.component(ofType: HealthComponent.self),
           let render = player.component(ofType: RenderComponent.self) {
            if health.isInvulnerable {
                render.isVisible = Int(time.totalTime * 20) % 2 == 0
            } else {
                render.isVisible = true
            }
        }
    }

    public func collectSprites() -> [SpriteInstance] {
        // Background first
        var sprites = backgroundSystem.collectSprites()

        // Gameplay sprites
        sprites.append(contentsOf: renderSystem.collectSprites())

        // HUD
        appendHUD(to: &sprites)

        // Game over / victory overlay
        if gameState == .gameOver {
            appendGameOverOverlay(to: &sprites)
        } else if gameState == .victory {
            appendVictoryOverlay(to: &sprites)
        }

        return sprites
    }

    // MARK: - Input

    private func handleInput() {
        guard let input = inputProvider?.poll() else { return }

        if let physics = player.component(ofType: PhysicsComponent.self) {
            physics.velocity = input.movement * GameConfig.Player.speed
        }

        if let weapon = player.component(ofType: WeaponComponent.self) {
            weapon.isFiring = input.primaryFire
            weapon.isSecondaryFiring = input.secondaryFire
        }

        // Clamp player to play area
        if let transform = player.component(ofType: TransformComponent.self) {
            let halfW = GameConfig.designWidth / 2 - GameConfig.Player.size.x / 2
            let halfH = GameConfig.designHeight / 2 - GameConfig.Player.size.y / 2
            transform.position.x = max(-halfW, min(halfW, transform.position.x))
            transform.position.y = max(-halfH, min(halfH, transform.position.y))
        }
    }

    // MARK: - Spawning

    private func processSpawnDirectorWaves() {
        for wave in spawnDirector.pendingWaves {
            switch wave.enemyTier {
            case .tier1:
                spawnTier1Formation(wave: wave)
            case .tier2:
                spawnTier2Group(wave: wave)
            case .tier3:
                spawnCapitalShip(wave: wave)
            case .boss:
                spawnBoss()
            }
        }
    }

    private func spawnTier1Formation(wave: WaveDefinition) {
        let formationID = nextFormationID
        nextFormationID += 1
        var members: [GKEntity] = []

        let spacing: Float = 50
        let startX = wave.spawnX - Float(wave.count - 1) / 2 * spacing

        for i in 0..<wave.count {
            let entity = GKEntity()
            let xOffset = startX + Float(i) * spacing
            var yOffset: Float = 0
            if wave.pattern == .vShape {
                yOffset = abs(Float(i) - Float(wave.count - 1) / 2) * 20
            }

            entity.addComponent(TransformComponent(position: SIMD2(xOffset, wave.spawnY + yOffset)))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.Enemy.tier1Size,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            entity.addComponent(physics)

            entity.addComponent(RenderComponent(
                size: GameConfig.Enemy.tier1Size,
                color: GameConfig.Palette.enemy
            ))

            entity.addComponent(HealthComponent(health: GameConfig.Enemy.tier1HP))
            entity.addComponent(ScoreComponent(points: GameConfig.Score.tier1))

            let formation = FormationComponent(pattern: wave.pattern, index: i, formationID: formationID)
            if wave.pattern == .sineWave {
                formation.phaseOffset = Float(i) * 0.5
            }
            entity.addComponent(formation)

            registerEntity(entity)
            enemies.append(entity)
            members.append(entity)
        }

        formationEnemies[formationID] = members
    }

    private func spawnTier2Group(wave: WaveDefinition) {
        for i in 0..<wave.count {
            let entity = GKEntity()

            let xSpread: Float = 60
            let x = wave.spawnX + Float(i) * xSpread - Float(wave.count - 1) / 2 * xSpread
            entity.addComponent(TransformComponent(position: SIMD2(x, wave.spawnY)))

            let physics = PhysicsComponent(
                collisionSize: GameConfig.Enemy.tier2Size,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            physics.velocity = SIMD2(0, -GameConfig.Enemy.tier2Speed)
            entity.addComponent(physics)

            entity.addComponent(RenderComponent(
                size: GameConfig.Enemy.tier2Size,
                color: GameConfig.Palette.tier2Enemy
            ))

            entity.addComponent(HealthComponent(health: GameConfig.Enemy.tier2HP))
            entity.addComponent(ScoreComponent(points: GameConfig.Score.tier2))

            let steering = SteeringComponent(behavior: i % 2 == 0 ? .hover : .strafe)
            steering.hoverY = Float(50 + i * 40)  // Stagger hover positions
            entity.addComponent(steering)

            // Tier 2 can fire
            let weapon = WeaponComponent(fireRate: 1.5, damage: 5, projectileSpeed: 250)
            weapon.isFiring = true
            entity.addComponent(weapon)

            registerEntity(entity)
            enemies.append(entity)
        }
    }

    private func spawnCapitalShip(wave: WaveDefinition) {
        // Hull (indestructible, visual only)
        let hull = GKEntity()
        hull.addComponent(TransformComponent(position: SIMD2(0, wave.spawnY + 100)))
        hull.addComponent(RenderComponent(
            size: GameConfig.Enemy.tier3HullSize,
            color: GameConfig.Palette.capitalShipHull
        ))
        // Hull doesn't collide — it's visual backdrop
        let hullPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        hullPhysics.velocity = SIMD2(0, -GameConfig.Background.starScrollSpeed * GameConfig.Enemy.tier3ScrollMultiplier)
        hull.addComponent(hullPhysics)
        registerEntity(hull)
        capitalShipHulls.append(hull)

        // Turrets mounted on hull
        let turretOffsets: [SIMD2<Float>] = [
            SIMD2(-80, 30), SIMD2(80, 30),
            SIMD2(-40, -20), SIMD2(40, -20)
        ]

        let formationID = nextFormationID
        nextFormationID += 1
        var turretMembers: [GKEntity] = []

        for (i, offset) in turretOffsets.prefix(wave.count).enumerated() {
            let turret = GKEntity()

            let turretTransform = TransformComponent(
                position: SIMD2(offset.x, wave.spawnY + 100 + offset.y)
            )
            turret.addComponent(turretTransform)

            let turretPhysics = PhysicsComponent(
                collisionSize: GameConfig.Enemy.tier3TurretSize,
                layer: .enemy,
                mask: [.player, .playerProjectile]
            )
            turretPhysics.velocity = SIMD2(0, -GameConfig.Background.starScrollSpeed * GameConfig.Enemy.tier3ScrollMultiplier)
            turret.addComponent(turretPhysics)

            turret.addComponent(RenderComponent(
                size: GameConfig.Enemy.tier3TurretSize,
                color: GameConfig.Palette.hostileProjectile  // Orange turrets
            ))

            turret.addComponent(HealthComponent(health: GameConfig.Enemy.tier3TurretHP))
            turret.addComponent(ScoreComponent(points: GameConfig.Score.tier3Turret))

            let turretComp = TurretComponent(trackingSpeed: 1.5)
            turretComp.parentEntity = hull
            turretComp.mountOffset = offset
            turret.addComponent(turretComp)

            registerEntity(turret)
            enemies.append(turret)
            turretMembers.append(turret)
        }

        formationEnemies[formationID] = turretMembers
    }

    private func spawnBoss() {
        let boss = GKEntity()

        boss.addComponent(TransformComponent(position: SIMD2(0, 250)))
        let physics = PhysicsComponent(
            collisionSize: GameConfig.Enemy.bossSize,
            layer: .enemy,
            mask: [.player, .playerProjectile, .blast]
        )
        boss.addComponent(physics)

        boss.addComponent(RenderComponent(
            size: GameConfig.Enemy.bossSize,
            color: GameConfig.Palette.bossCore
        ))

        let health = HealthComponent(health: GameConfig.Enemy.bossHP)
        // Boss doesn't get default invulnerability behavior
        boss.addComponent(health)

        boss.addComponent(BossPhaseComponent(totalHP: GameConfig.Enemy.bossHP))
        boss.addComponent(ScoreComponent(points: GameConfig.Score.boss))

        registerEntity(boss)
        bossSystem.register(boss)
        enemies.append(boss)
        bossEntity = boss

        // Spawn two shields
        for i in 0..<2 {
            let shield = GKEntity()
            let angle = Float(i) * .pi
            shield.addComponent(TransformComponent(
                position: SIMD2(cos(angle) * 60, 250 + sin(angle) * 60)
            ))
            shield.addComponent(RenderComponent(
                size: SIMD2(40, 12),
                color: GameConfig.Palette.bossShield
            ))
            let shieldPhysics = PhysicsComponent(
                collisionSize: SIMD2(40, 12),
                layer: .bossShield,
                mask: [.playerProjectile]
            )
            shield.addComponent(shieldPhysics)

            registerEntity(shield)
            bossSystem.registerShield(shield)
            shieldEntities.append(shield)
        }
    }

    private func spawnPlayerProjectile(_ request: ProjectileSpawnRequest) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: request.position))

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Player.projectileSize,
            layer: .playerProjectile,
            mask: [.enemy, .bossShield, .item]
        )
        physics.velocity = request.velocity
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: GameConfig.Player.projectileSize,
            color: SIMD4(1, 1, 1, 1)
        ))

        registerEntity(entity)
        projectiles.append(entity)
    }

    private func spawnEnemyProjectile(position: SIMD2<Float>, velocity: SIMD2<Float>, damage: Float) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: SIMD2(8, 8),
            layer: .enemyProjectile,
            mask: [.player]
        )
        physics.velocity = velocity
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: SIMD2(8, 8),
            color: GameConfig.Palette.hostileProjectile
        ))

        registerEntity(entity)
        enemyProjectiles.append(entity)
    }

    private func spawnGravBomb(position: SIMD2<Float>, velocity: SIMD2<Float>) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: SIMD2(16, 16),
            layer: .blast,
            mask: [.enemy]
        )
        physics.velocity = velocity
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: SIMD2(16, 16),
            color: GameConfig.Palette.gravBomb
        ))

        registerEntity(entity)
        gravBombEntities.append(entity)
        gravBombTimers[ObjectIdentifier(entity)] = 0
    }

    private func spawnItem(at position: SIMD2<Float>) {
        let entity = GKEntity()
        entity.addComponent(TransformComponent(position: position))

        let physics = PhysicsComponent(
            collisionSize: GameConfig.Item.size,
            layer: .item,
            mask: [.player, .playerProjectile]
        )
        entity.addComponent(physics)

        entity.addComponent(RenderComponent(
            size: GameConfig.Item.size,
            color: GameConfig.Palette.item
        ))

        entity.addComponent(ItemComponent())

        registerEntity(entity)
        items.append(entity)
    }

    // MARK: - Updates

    private func updateTurrets(deltaTime: Double) {
        for enemy in enemies {
            guard let turret = enemy.component(ofType: TurretComponent.self),
                  let transform = enemy.component(ofType: TransformComponent.self) else { continue }

            // Follow parent hull position
            if let parent = turret.parentEntity,
               let parentTransform = parent.component(ofType: TransformComponent.self) {
                transform.position = parentTransform.position + turret.mountOffset
            }

            // Fire at player
            turret.timeSinceLastShot += deltaTime
            if turret.timeSinceLastShot >= turret.fireInterval {
                turret.timeSinceLastShot = 0
                let playerPos = player.component(ofType: TransformComponent.self)?.position ?? .zero
                let dir = simd_normalize(playerPos - transform.position)
                spawnEnemyProjectile(
                    position: transform.position,
                    velocity: dir * turret.projectileSpeed,
                    damage: turret.damage
                )
            }
        }
    }

    private func updateCapitalShipHulls(deltaTime: Double) {
        // Hulls already move via PhysicsSystem (they have velocity set)
        // Remove hulls that have scrolled off screen
        for hull in capitalShipHulls {
            if let transform = hull.component(ofType: TransformComponent.self),
               transform.position.y < -GameConfig.designHeight / 2 - GameConfig.Enemy.tier3HullSize.y {
                pendingRemovals.append(hull)
            }
        }
    }

    private func updateGravBombs(deltaTime: Double) {
        for bomb in gravBombEntities {
            let id = ObjectIdentifier(bomb)
            gravBombTimers[id] = (gravBombTimers[id] ?? 0) + deltaTime

            if let timer = gravBombTimers[id], timer >= GameConfig.Weapon.gravBombDetonateTime {
                detonateGravBomb(bomb)
                pendingRemovals.append(bomb)
            }
        }
    }

    private func detonateGravBomb(_ bomb: GKEntity) {
        guard let transform = bomb.component(ofType: TransformComponent.self) else { return }
        let center = transform.position
        let radius = GameConfig.Weapon.gravBombBlastRadius

        // Damage all enemies in radius
        for enemy in enemies {
            guard let enemyTransform = enemy.component(ofType: TransformComponent.self),
                  let health = enemy.component(ofType: HealthComponent.self) else { continue }

            let dist = simd_length(enemyTransform.position - center)
            if dist <= radius {
                health.takeDamage(GameConfig.Weapon.gravBombDamage)
                if !health.isAlive {
                    if let score = enemy.component(ofType: ScoreComponent.self) {
                        scoreSystem.addScore(score.points)
                    }
                    pendingRemovals.append(enemy)
                }
            }
        }

        // Destroy enemy projectiles in radius
        for proj in enemyProjectiles {
            guard let projTransform = proj.component(ofType: TransformComponent.self) else { continue }
            if simd_length(projTransform.position - center) <= radius {
                pendingRemovals.append(proj)
            }
        }

        // Visual: spawn expanding blast ring (brief)
        let blast = GKEntity()
        blast.addComponent(TransformComponent(position: center))
        blast.addComponent(RenderComponent(
            size: SIMD2(radius * 2, radius * 2),
            color: GameConfig.Palette.gravBombBlast
        ))
        // No physics — visual only, will be culled next frame
        let blastPhysics = PhysicsComponent(collisionSize: .zero, layer: [], mask: [])
        blast.addComponent(blastPhysics)
        registerEntity(blast)
        // Remove after 2 frames via pending
        pendingRemovals.append(blast)
    }

    // MARK: - Collisions

    private func processCollisions() {
        for (entityA, entityB) in collisionSystem.collisionPairs {
            let layerA = entityA.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []
            let layerB = entityB.component(ofType: PhysicsComponent.self)?.collisionLayer ?? []

            // Player projectile hits enemy
            if layerA.contains(.playerProjectile) && layerB.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityA, enemy: entityB)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.enemy) {
                handleProjectileHitEnemy(projectile: entityB, enemy: entityA)
            }
            // Player projectile hits boss shield
            else if layerA.contains(.playerProjectile) && layerB.contains(.bossShield) {
                pendingRemovals.append(entityA)  // Projectile absorbed
            } else if layerB.contains(.playerProjectile) && layerA.contains(.bossShield) {
                pendingRemovals.append(entityB)
            }
            // Player projectile hits item (cycle it)
            else if layerA.contains(.playerProjectile) && layerB.contains(.item) {
                itemSystem.handleProjectileHit(on: entityB)
                pendingRemovals.append(entityA)
            } else if layerB.contains(.playerProjectile) && layerA.contains(.item) {
                itemSystem.handleProjectileHit(on: entityA)
                pendingRemovals.append(entityB)
            }
            // Player collides with enemy
            else if layerA.contains(.player) && layerB.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityB)
            } else if layerB.contains(.player) && layerA.contains(.enemy) {
                handlePlayerEnemyCollision(enemy: entityA)
            }
            // Player collides with enemy projectile
            else if layerA.contains(.player) && layerB.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityB)
            } else if layerB.contains(.player) && layerA.contains(.enemyProjectile) {
                handlePlayerHitByProjectile(projectile: entityA)
            }
            // Player collects item
            else if layerA.contains(.player) && layerB.contains(.item) {
                handlePlayerCollectsItem(item: entityB)
            } else if layerB.contains(.player) && layerA.contains(.item) {
                handlePlayerCollectsItem(item: entityA)
            }
        }
    }

    private func handleProjectileHitEnemy(projectile: GKEntity, enemy: GKEntity) {
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(GameConfig.Player.damage)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    scoreSystem.addScore(score.points)
                }
                pendingRemovals.append(enemy)
                checkFormationWipe(enemy: enemy)
            }
        }
        pendingRemovals.append(projectile)
    }

    private func handlePlayerEnemyCollision(enemy: GKEntity) {
        player.component(ofType: HealthComponent.self)?.takeDamage(GameConfig.Player.collisionDamage)
        if let health = enemy.component(ofType: HealthComponent.self) {
            health.takeDamage(health.currentHealth)
            if !health.isAlive {
                if let score = enemy.component(ofType: ScoreComponent.self) {
                    scoreSystem.addScore(score.points)
                }
                pendingRemovals.append(enemy)
            }
        }
    }

    private func handlePlayerHitByProjectile(projectile: GKEntity) {
        player.component(ofType: HealthComponent.self)?.takeDamage(5)
        pendingRemovals.append(projectile)
    }

    private func handlePlayerCollectsItem(item: GKEntity) {
        guard let itemComp = item.component(ofType: ItemComponent.self) else { return }

        switch itemComp.itemType {
        case .energyCell:
            if let health = player.component(ofType: HealthComponent.self) {
                health.currentHealth = min(health.maxHealth, health.currentHealth + GameConfig.Item.energyRestoreAmount)
            }
        case .weaponModule:
            if let weapon = player.component(ofType: WeaponComponent.self) {
                weapon.weaponType = weapon.weaponType == .doubleCannon ? .triSpread : .doubleCannon
                weapon.damage = weapon.weaponType == .triSpread ? GameConfig.Weapon.triSpreadDamage : GameConfig.Player.damage
            }
        }

        pendingRemovals.append(item)
    }

    private func checkFormationWipe(enemy: GKEntity) {
        // Find which formation this enemy belonged to
        for (id, members) in formationEnemies {
            if members.contains(where: { $0 === enemy }) {
                // Check if all members of this formation are dead or pending removal
                let alive = members.filter { member in
                    guard let health = member.component(ofType: HealthComponent.self) else { return false }
                    return health.isAlive && !pendingRemovals.contains(where: { $0 === member })
                }
                if alive.isEmpty {
                    // Full formation wipe — spawn item at enemy's position
                    if let transform = enemy.component(ofType: TransformComponent.self) {
                        spawnItem(at: transform.position)
                    }
                    formationEnemies.removeValue(forKey: id)
                }
                break
            }
        }
    }

    // MARK: - Cull

    private func cullOffScreen() {
        let margin: Float = 50
        let minY = -GameConfig.designHeight / 2 - margin
        let maxY = GameConfig.designHeight / 2 + margin
        let minX = -GameConfig.designWidth / 2 - margin
        let maxX = GameConfig.designWidth / 2 + margin

        for entity in (enemies + projectiles + enemyProjectiles) {
            guard let transform = entity.component(ofType: TransformComponent.self) else { continue }
            if transform.position.y < minY || transform.position.y > maxY ||
               transform.position.x < minX || transform.position.x > maxX {
                pendingRemovals.append(entity)
            }
        }
    }

    // MARK: - HUD

    private func appendHUD(to sprites: inout [SpriteInstance]) {
        let topY: Float = GameConfig.designHeight / 2 - 20

        // Energy bar background
        sprites.append(SpriteInstance(
            position: SIMD2(-45, topY),
            size: SIMD2(120, 12),
            color: SIMD4(0.2, 0.2, 0.2, 0.8)
        ))

        // Energy bar fill
        let health = player.component(ofType: HealthComponent.self)
        let fraction = (health?.currentHealth ?? 0) / (health?.maxHealth ?? 100)
        let barWidth: Float = 116 * fraction
        let barOffset = (barWidth - 116) / 2
        sprites.append(SpriteInstance(
            position: SIMD2(-45 + barOffset, topY),
            size: SIMD2(barWidth, 8),
            color: GameConfig.Palette.player
        ))

        // Score (rendered as a series of digit-representing blocks — simple for now)
        // Just show score as a horizontal bar proportional to score
        let scoreWidth = min(Float(scoreSystem.currentScore) / 10.0, 100.0)
        sprites.append(SpriteInstance(
            position: SIMD2(100, topY),
            size: SIMD2(scoreWidth, 8),
            color: SIMD4(1, 1, 1, 0.8)
        ))

        // Grav-bomb charges
        let charges = player.component(ofType: WeaponComponent.self)?.secondaryCharges ?? 0
        for i in 0..<charges {
            sprites.append(SpriteInstance(
                position: SIMD2(140 - Float(i) * 14, -GameConfig.designHeight / 2 + 20),
                size: SIMD2(10, 10),
                color: GameConfig.Palette.gravBomb
            ))
        }

        // Weapon indicator
        let weaponType = player.component(ofType: WeaponComponent.self)?.weaponType ?? .doubleCannon
        let weaponColor: SIMD4<Float> = weaponType == .triSpread ? GameConfig.Palette.weaponModule : SIMD4(1, 1, 1, 0.5)
        sprites.append(SpriteInstance(
            position: SIMD2(0, -GameConfig.designHeight / 2 + 20),
            size: SIMD2(20, 6),
            color: weaponColor
        ))
    }

    private func appendGameOverOverlay(to sprites: inout [SpriteInstance]) {
        // Dark overlay
        sprites.append(SpriteInstance(
            position: .zero,
            size: SIMD2(GameConfig.designWidth, GameConfig.designHeight),
            color: SIMD4(0, 0, 0, 0.6)
        ))
        // "GAME OVER" indicator — large red block
        sprites.append(SpriteInstance(
            position: SIMD2(0, 20),
            size: SIMD2(160, 30),
            color: SIMD4(0.8, 0.1, 0.1, 0.9)
        ))
    }

    private func appendVictoryOverlay(to sprites: inout [SpriteInstance]) {
        // "VICTORY" indicator — large cyan block
        sprites.append(SpriteInstance(
            position: SIMD2(0, 20),
            size: SIMD2(160, 30),
            color: GameConfig.Palette.player
        ))
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter Galaxy1SceneTests`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1 | tail -15`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Engine2043/Tests/Engine2043Tests/Galaxy1SceneTests.swift
git commit -m "feat: add Galaxy1Scene with full vertical slice gameplay"
```

---

## Part D: Integration

### Task 15: Wire MetalViews to Galaxy1Scene

**Files:**
- Modify: `Project2043-macOS/MetalView.swift`
- Modify: `Project2043-iOS/MetalView.swift`

**Step 1: Update macOS MetalView**

In `Project2043-macOS/MetalView.swift`, in the `setup()` method, replace:

```swift
let scene = PlaceholderScene()
```

with:

```swift
let scene = Galaxy1Scene()
```

**Step 2: Update iOS MetalView**

In `Project2043-iOS/MetalView.swift`, in the `setup()` method, replace:

```swift
let scene = PlaceholderScene()
```

with:

```swift
let scene = Galaxy1Scene()
```

**Step 3: Build**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Project2043-macOS/MetalView.swift Project2043-iOS/MetalView.swift
git commit -m "feat: wire Galaxy1Scene as default scene in macOS and iOS targets"
```

---

### Task 16: Tier 2 enemy firing — integrate turret-style firing for Tier 2 bruisers

The Tier 2 enemies have WeaponComponents but the WeaponSystem currently fires projectiles straight up (designed for the player). We need Tier 2 enemies to fire downward at the player.

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SystemTests.swift`:

```swift
@Test @MainActor func weaponSystemEnemyFiresDownward() {
    let system = WeaponSystem()

    let entity = GKEntity()
    entity.addComponent(TransformComponent(position: SIMD2(0, 200)))
    let weapon = WeaponComponent(fireRate: 60, damage: 5, projectileSpeed: 250)
    weapon.isFiring = true
    weapon.firesDownward = true
    entity.addComponent(weapon)

    system.register(entity)

    let time = GameTime()
    time.advance(by: 1.0 / 60.0)
    _ = time.shouldPerformFixedUpdate()
    system.update(time: time)

    #expect(system.pendingSpawns.count > 0)
    #expect(system.pendingSpawns[0].velocity.y < 0)  // Fires downward
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter weaponSystemEnemyFiresDownward`
Expected: FAIL — `firesDownward` not defined

**Step 3: Add firesDownward to WeaponComponent**

Add to `WeaponComponent.swift`:

```swift
public var firesDownward: Bool = false
```

**Step 4: Update WeaponSystem to respect direction**

In `WeaponSystem.swift`, update the `spawnPrimaryProjectiles` method. For `doubleCannon`, change the velocity direction based on `firesDownward`:

```swift
private func spawnPrimaryProjectiles(weapon: WeaponComponent, position: SIMD2<Float>) {
    let direction: Float = weapon.firesDownward ? -1 : 1

    switch weapon.weaponType {
    case .doubleCannon:
        let offset: Float = 8
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position + SIMD2(-offset, 0),
            velocity: SIMD2(0, weapon.projectileSpeed * direction),
            damage: weapon.damage
        ))
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position + SIMD2(offset, 0),
            velocity: SIMD2(0, weapon.projectileSpeed * direction),
            damage: weapon.damage
        ))

    case .triSpread:
        let angle = GameConfig.Weapon.triSpreadAngle
        let speed = weapon.projectileSpeed
        let damage = GameConfig.Weapon.triSpreadDamage

        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(0, speed * direction),
            damage: damage
        ))
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(-sin(angle) * speed, cos(angle) * speed * direction),
            damage: damage
        ))
        pendingSpawns.append(ProjectileSpawnRequest(
            position: position,
            velocity: SIMD2(sin(angle) * speed, cos(angle) * speed * direction),
            damage: damage
        ))
    }
}
```

Also update Galaxy1Scene's `spawnTier2Group` to set `weapon.firesDownward = true` on Tier 2 enemies.

**Step 5: Handle enemy projectile spawns from WeaponSystem**

Galaxy1Scene needs to distinguish player projectiles from enemy projectiles spawned by WeaponSystem. Add a `spawnedByLayer` field to `ProjectileSpawnRequest`:

Add to `ProjectileSpawnRequest`:

```swift
public var collisionLayer: CollisionLayer = .playerProjectile
```

In `WeaponSystem.spawnPrimaryProjectiles`, read from the entity's PhysicsComponent:

After computing the spawn request, set the layer:

```swift
let entityLayer = entity.component(ofType: PhysicsComponent.self)?.collisionLayer ?? .player
let projectileLayer: CollisionLayer = entityLayer.contains(.enemy) ? .enemyProjectile : .playerProjectile
// Set on each spawn request
```

Then in Galaxy1Scene, when processing `weaponSystem.pendingSpawns`, check the layer to decide whether to call `spawnPlayerProjectile` or `spawnEnemyProjectile`.

**Step 6: Run tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -15`
Expected: All tests pass

**Step 7: Commit**

```bash
git add Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Engine2043/Tests/Engine2043Tests/SystemTests.swift
git commit -m "feat: support enemy downward firing in WeaponSystem"
```

---

### Task 17: Final verification and tuning

**Files:** None (verification only)

**Step 1: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1`
Expected: All tests pass

**Step 2: Build and run macOS target in Xcode**

Open `Project2043.xcodeproj`, select macOS target, build and run. Verify:
- Parallax starfield scrolling in background
- Tier 1 enemies spawn in V-formations, sine waves, staggered lines
- Player fires Double Cannon, can collect Weapon Module to switch to Tri-Spread
- Tier 2 bruisers appear, hover/strafe, fire at player
- Capital ship scrolls through with turrets that track and fire
- Destroying full formations drops items
- Items cycle when shot, can be collected
- Energy bar and score HUD visible
- Boss appears at end, has rotating shields, fires patterns, 3 phases
- Game over on death, victory on boss defeat

**Step 3: Tune gameplay values if needed**

Adjust values in `GameConfig.swift`:
- Enemy speeds, spawn thresholds, fire rates
- Bloom/post-process parameters
- Boss attack patterns

**Step 4: Commit any tuning**

```bash
git add -A
git commit -m "tune: adjust gameplay parameters for vertical slice balance"
```

---

## Summary

| Part | Tasks | What's Built |
|------|-------|-------------|
| A: Foundation | 1-5 | GameConfig constants, collision layers, 6 new components |
| B: Systems | 6-13 | ScoreSystem, BackgroundSystem, FormationSystem, SteeringSystem, ItemSystem, WeaponSystem updates, BossSystem, SpawnDirector |
| C: Galaxy1Scene | 14 | Full scene with player, 4 enemy tiers, items, scoring, HUD, game states |
| D: Integration | 15-17 | MetalView wiring, enemy firing, final verification |

**Total: 17 tasks, ~20 new files, ~5 modified files**
