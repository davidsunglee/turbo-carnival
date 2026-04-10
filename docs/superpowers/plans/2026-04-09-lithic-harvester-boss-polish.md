# Lithic Harvester Boss Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Galaxy 2 boss feel alive by adding an entry descent, sinusoidal lateral drift that escalates per phase, and continuous armor ring rotation.

**Architecture:** All movement and rotation logic lives in `BossSystem.updateLithicHarvester`. New timing/state fields are added to `BossPhaseComponent` (intro timer, drift elapsed) and `BossArmorComponent` (rotation angle). Tuning constants go in `GameConfig.Galaxy2`. The boss spawns just above the visible top edge but still below Galaxy 2's off-screen cull threshold, then descends to its resting Y before attacking, mirroring Galaxy 3's intro pattern but using the simpler `BossPhaseComponent` (no new component needed). Armor coverage math must be shared between movement visuals and hit detection so projectile and Phase Laser interception use `slot.angle + rotationAngle`, not the old static slot angles.

**Tech Stack:** Swift 6, GameplayKit ECS, Swift Testing (`import Testing`, `#expect`), SPM

---

## Files to Create or Modify

| Action | File | Description |
|--------|------|-------------|
| Modify | `Engine2043/Sources/Engine2043/Core/GameConfig.swift` | Add `Galaxy2.Boss` enum with movement/rotation constants |
| Modify | `Engine2043/Sources/Engine2043/ECS/Components/BossPhaseComponent.swift` | Add `introTimer`, `introComplete`, `driftElapsed` fields for Lithic Harvester intro/drift |
| Modify | `Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift` | Add `rotationAngle` and a shared helper for rotated armor-slot coverage |
| Modify | `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift` | Add intro descent, lateral drift, and armor rotation to `updateLithicHarvester` |
| Modify | `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift` | Update projectile-vs-boss armor interception to use rotated slot coverage |
| Modify | `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift` | Change boss spawn Y to a cull-safe above-viewport position and update Phase Laser armor interception to use rotated slot coverage |
| Modify | `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift` | Add tests for intro descent, lateral drift, armor rotation, and rotated armor coverage |

---

## Task 1: Add GameConfig Constants for Lithic Harvester Movement

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift:134-179`
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write a test that reads the new config constants to confirm they exist and have expected values.**

Add to the bottom of the `LithicHarvesterTests` struct in `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`:

```swift
    // MARK: - Config constants exist

    @Test func lithicHarvesterConfigConstantsExist() {
        // Boss intro
        #expect(GameConfig.Galaxy2.Boss.spawnY == 340)
        #expect(GameConfig.Galaxy2.Boss.restingY == 250)
        #expect(GameConfig.Galaxy2.Boss.introDuration == 1.5)

        // Lateral drift
        #expect(GameConfig.Galaxy2.Boss.driftAmplitude == [30.0, 45.0, 60.0])
        #expect(GameConfig.Galaxy2.Boss.driftPeriod == [5.0, 4.0, 3.0])

        // Armor rotation
        #expect(GameConfig.Galaxy2.Boss.armorRotationSpeed == [0.4, 0.7, 1.1])
    }
```

- [ ] **Step 2: Verify the test fails (constants don't exist yet).**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/lithicHarvesterConfigConstantsExist 2>&1 | tail -5
```

Expected: compilation error — `Boss` has no member.

- [ ] **Step 3: Add the `Boss` enum inside `GameConfig.Galaxy2`.**

In `Engine2043/Sources/Engine2043/Core/GameConfig.swift`, inside the `Galaxy2` enum (after the `Palette` enum closing brace at line 178, before the `Galaxy2` closing brace at line 179), add:

```swift
        public enum Boss {
            // Intro descent
            public static let spawnY: Float = 340
            public static let restingY: Float = 250
            public static let introDuration: Double = 1.5

            // Lateral drift (per phase: 0, 1, 2)
            public static let driftAmplitude: [Float] = [30.0, 45.0, 60.0]
            public static let driftPeriod: [Double] = [5.0, 4.0, 3.0]

            // Armor ring rotation speed in rad/s (per phase: 0, 1, 2)
            public static let armorRotationSpeed: [Float] = [0.4, 0.7, 1.1]
        }
```

- [ ] **Step 4: Verify the test passes.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/lithicHarvesterConfigConstantsExist 2>&1 | tail -5
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 5: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "feat(config): add Lithic Harvester boss movement and rotation constants"
```

---

## Task 2: Add Intro and Drift State to BossPhaseComponent

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/BossPhaseComponent.swift:1-28`
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write a test that the new fields exist with default values.**

Add to `LithicHarvesterTests`:

```swift
    // MARK: - BossPhaseComponent intro/drift fields

    @Test @MainActor func bossPhaseComponentHasIntroAndDriftFields() {
        let phase = BossPhaseComponent(totalHP: 100)
        #expect(phase.introTimer == 0)
        #expect(phase.introComplete == true)
        #expect(phase.driftElapsed == 0)
    }
```

- [ ] **Step 2: Verify the test fails.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/bossPhaseComponentHasIntroAndDriftFields 2>&1 | tail -5
```

Expected: compilation error — `introTimer` does not exist on `BossPhaseComponent`.

- [ ] **Step 3: Add the fields to `BossPhaseComponent`.**

In `Engine2043/Sources/Engine2043/ECS/Components/BossPhaseComponent.swift`, after the `shieldSpeed` property (line 10), add:

```swift
    public var introTimer: Double = 0
    public var introComplete: Bool = true
    public var driftElapsed: Double = 0
```

- [ ] **Step 4: Verify the test passes.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/bossPhaseComponentHasIntroAndDriftFields 2>&1 | tail -5
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 5: Verify existing BossSystem and LithicHarvester tests still pass (no regressions).**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "BossSystemTests|LithicHarvesterTests" 2>&1 | tail -10
```

Expected: existing tests still pass because intro is now opt-in (`introComplete` defaults to `true`), and intro-specific tests/scenes explicitly set it to `false`.

- [ ] **Step 6: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "feat(component): add introTimer, introComplete, driftElapsed to BossPhaseComponent"
```

---

## Task 3: Add rotationAngle to BossArmorComponent

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift:1-19`
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write a test that the new field exists with default value 0.**

Add to `LithicHarvesterTests`:

```swift
    // MARK: - BossArmorComponent rotationAngle field

    @Test @MainActor func bossArmorComponentHasRotationAngle() {
        let comp = BossArmorComponent()
        #expect(comp.rotationAngle == 0)
    }
```

- [ ] **Step 2: Verify the test fails.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/bossArmorComponentHasRotationAngle 2>&1 | tail -5
```

Expected: compilation error.

- [ ] **Step 3: Add `rotationAngle` to `BossArmorComponent`.**

In `Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift`, after the `armorRadius` property (line 15), add:

```swift
    public var rotationAngle: Float = 0
```

- [ ] **Step 4: Verify the test passes.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/bossArmorComponentHasRotationAngle 2>&1 | tail -5
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 5: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "feat(component): add rotationAngle to BossArmorComponent for armor ring spin"
```

---

## Task 4: Implement Boss Entry Descent

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift:168-221`
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write a test that the boss descends during intro and does not fire.**

Add to `LithicHarvesterTests`:

```swift
    // MARK: - Boss entry descent

    @Test @MainActor func lithicHarvesterDescendsDuringIntro() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, _) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        transform.position = SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)
        let phase = boss.component(ofType: BossPhaseComponent.self)!
        phase.introComplete = false

        system.register(boss)

        let startY = transform.position.y

        // Run 30 frames (~0.5s)
        for _ in 0..<30 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(transform.position.y < startY, "Boss should descend during intro")
        #expect(system.pendingProjectileSpawns.isEmpty, "Boss should not fire during intro")
    }

    @Test @MainActor func lithicHarvesterIntroCompletesAtRestingY() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, _) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        transform.position = SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)
        let phase = boss.component(ofType: BossPhaseComponent.self)!
        phase.introComplete = false

        system.register(boss)

        // Run for 2 seconds (intro is 1.5s)
        for _ in 0..<120 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(phase.introComplete == true, "Intro should be complete after 1.5s")
        #expect(transform.position.y == GameConfig.Galaxy2.Boss.restingY,
                "Boss should be at resting Y after intro")
    }
```

- [ ] **Step 2: Verify the tests fail.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "LithicHarvesterTests/lithicHarvesterDescendsDuringIntro|LithicHarvesterTests/lithicHarvesterIntroCompletesAtRestingY" 2>&1 | tail -10
```

Expected: tests fail (boss does not move, `introComplete` stays false).

- [ ] **Step 3: Implement intro descent in `updateLithicHarvester`.**

In `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift`, replace the entire `updateLithicHarvester` method (lines 168-221) with:

```swift
    private func updateLithicHarvester(boss: GKEntity, bossPhase: BossPhaseComponent, health: HealthComponent, transform: TransformComponent, deltaTime: Double) {
        let phase = bossPhase.currentPhase

        // --- Intro descent ---
        if !bossPhase.introComplete {
            bossPhase.introTimer += deltaTime
            let introDuration = GameConfig.Galaxy2.Boss.introDuration
            if bossPhase.introTimer < introDuration {
                let t = Float(bossPhase.introTimer / introDuration)
                let spawnY = GameConfig.Galaxy2.Boss.spawnY
                let restingY = GameConfig.Galaxy2.Boss.restingY
                transform.position.y = spawnY - t * (spawnY - restingY)
                // Update armor positions even during intro so they follow the boss
                updateLithicArmor(boss: boss, transform: transform, deltaTime: deltaTime, phase: phase)
                return  // no attacks during intro
            }
            // Intro complete
            transform.position.y = GameConfig.Galaxy2.Boss.restingY
            bossPhase.introComplete = true
        }

        // --- Lateral drift (sinusoidal sway) ---
        bossPhase.driftElapsed += deltaTime
        let clampedPhase = min(phase, GameConfig.Galaxy2.Boss.driftAmplitude.count - 1)
        let amplitude = GameConfig.Galaxy2.Boss.driftAmplitude[clampedPhase]
        let period = GameConfig.Galaxy2.Boss.driftPeriod[clampedPhase]
        transform.position.x = amplitude * sin(Float(bossPhase.driftElapsed) * (2.0 * .pi / Float(period)))

        // --- Armor ring rotation + position update ---
        updateLithicArmor(boss: boss, transform: transform, deltaTime: deltaTime, phase: phase)

        // --- Attacks ---
        let fireInterval: Double
        switch phase {
        case 0: fireInterval = 2.0
        case 1: fireInterval = 1.5
        default: fireInterval = 1.0
        }

        attackTimer += deltaTime

        if attackTimer >= fireInterval {
            attackTimer -= fireInterval
            generateLithicHarvesterAttack(from: transform.position, phase: phase)
        }

        // --- Tractor beam logic ---
        if let armor = boss.component(ofType: BossArmorComponent.self) {
            switch phase {
            case 0: armor.tractorBeamInterval = 8.0
            case 1: armor.tractorBeamInterval = 5.0
            default: armor.tractorBeamInterval = 3.0
            }

            armor.tractorBeamTimer += deltaTime

            if armor.tractorBeamTimer >= armor.tractorBeamInterval {
                armor.tractorBeamTimer -= armor.tractorBeamInterval

                let hasEmptySlot = armor.slots.contains { !$0.isActive }
                if hasEmptySlot {
                    for target in armor.tractorBeamTargets {
                        pendingTractorBeamPulls.append((source: transform.position, target: target))
                    }
                }
            }
        }
    }

    private func updateLithicArmor(boss: GKEntity, transform: TransformComponent, deltaTime: Double, phase: Int) {
        guard let armor = boss.component(ofType: BossArmorComponent.self) else { return }

        // Rotate the armor ring
        let clampedPhase = min(phase, GameConfig.Galaxy2.Boss.armorRotationSpeed.count - 1)
        armor.rotationAngle += GameConfig.Galaxy2.Boss.armorRotationSpeed[clampedPhase] * Float(deltaTime)

        // Update armor slot positions around boss
        let bossPos = transform.position
        for i in 0..<armor.slots.count {
            if let armorEntity = armor.slots[i].entity,
               let armorTransform = armorEntity.component(ofType: TransformComponent.self) {
                let effectiveAngle = armor.slots[i].angle + armor.rotationAngle
                armorTransform.position = bossPos + SIMD2(cos(effectiveAngle), sin(effectiveAngle)) * armor.armorRadius
            }
        }
    }
```

- [ ] **Step 4: Verify both intro tests pass.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "LithicHarvesterTests/lithicHarvesterDescendsDuringIntro|LithicHarvesterTests/lithicHarvesterIntroCompletesAtRestingY" 2>&1 | tail -5
```

Expected: `Test run with 2 tests passed`.

- [ ] **Step 5: Verify all existing LithicHarvester and BossSystem tests still pass.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "LithicHarvesterTests|BossSystemTests" 2>&1 | tail -10
```

Expected: all tests pass. Existing helper-based tests should continue to work because `BossPhaseComponent.introComplete` now defaults to `true`; only intro-specific tests set it to `false`.

- [ ] **Step 6: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "feat(boss): add Lithic Harvester entry descent with intro state"
```

---

## Task 5: Implement Lateral Drift

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift` (already done in Task 4)
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write a test that the boss drifts laterally over time.**

Add to `LithicHarvesterTests`:

```swift
    // MARK: - Lateral drift

    @Test @MainActor func lithicHarvesterDriftsLaterally() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, _) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        system.register(boss)

        // Run for ~1.25s (quarter of the 5.0s period in phase 0) — should be near peak
        let frames = Int(1.25 / (1.0 / 60.0))
        for _ in 0..<frames {
            system.update(deltaTime: 1.0 / 60.0)
        }

        #expect(abs(transform.position.x) > 1.0,
                "Boss should have drifted away from x=0, got \(transform.position.x)")
    }

    @Test @MainActor func lithicHarvesterPhase2DriftProducesLargerOffsetAtSharedSampleTime() {
        // Phase 0: amplitude 30, period 5
        let system0 = BossSystem()
        system0.bossType = .lithicHarvester
        system0.playerPosition = SIMD2(0, -200)
        let (boss0, _) = makeBossEntity(hp: 100)
        system0.register(boss0)
        let transform0 = boss0.component(ofType: TransformComponent.self)!

        // Phase 2: amplitude 60, period 3
        let system2 = BossSystem()
        system2.bossType = .lithicHarvester
        system2.playerPosition = SIMD2(0, -200)
        let (boss2, _) = makeBossEntity(hp: 100)
        system2.register(boss2)
        let health2 = boss2.component(ofType: HealthComponent.self)!
        health2.currentHealth = 20  // 20% -> phase 2
        let transform2 = boss2.component(ofType: TransformComponent.self)!

        // Run both for 0.75s.
        // phase 0 offset ~= 30 * sin(2π * 0.75 / 5)  ≈ 24.3
        // phase 2 offset ~= 60 * sin(2π * 0.75 / 3)  = 60
        let frames = Int(0.75 / (1.0 / 60.0))
        for _ in 0..<frames {
            system0.update(deltaTime: 1.0 / 60.0)
            system2.update(deltaTime: 1.0 / 60.0)
        }

        #expect(abs(transform2.position.x) > abs(transform0.position.x) + 10,
                "Phase 2 drift should have a clearly larger offset than phase 0")
    }
```

- [ ] **Step 2: Verify the tests pass (drift was already implemented in Task 4).**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "LithicHarvesterTests/lithicHarvesterDriftsLaterally|LithicHarvesterTests/lithicHarvesterPhase2DriftProducesLargerOffsetAtSharedSampleTime" 2>&1 | tail -5
```

Expected: `Test run with 2 tests passed`. (The implementation was added in Task 4 Step 3.)

- [ ] **Step 3: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "test(boss): add lateral drift tests for Lithic Harvester"
```

---

## Task 6: Test Armor Ring Rotation and Rotated Armor Coverage

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift` (rotation motion already added in Task 4)
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write tests for armor rotation and for coverage math that honors `rotationAngle`.**

Add to `LithicHarvesterTests`:

```swift
    // MARK: - Armor ring rotation

    @Test @MainActor func armorRingRotatesOverTime() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, armor) = makeBossEntity(hp: 100)
        // Attach an armor entity to slot 0 so we can track its position
        let armorEntity = makeArmorAsteroidEntity(position: .zero)
        armor.slots[0].entity = armorEntity

        system.register(boss)

        #expect(armor.rotationAngle == 0, "Rotation should start at 0")

        // Run for 1 second
        for _ in 0..<60 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        // Phase 0 rotation speed is 0.4 rad/s, so after 1s: ~0.4 rad
        #expect(armor.rotationAngle > 0.35 && armor.rotationAngle < 0.45,
                "Rotation angle should be ~0.4 after 1s, got \(armor.rotationAngle)")
    }

    @Test @MainActor func armorAsteroidPositionChangesWithRotation() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, armor) = makeBossEntity(hp: 100)
        let armorEntity = makeArmorAsteroidEntity(position: .zero)
        armor.slots[0].entity = armorEntity
        let armorTransform = armorEntity.component(ofType: TransformComponent.self)!

        system.register(boss)

        // Record initial position after first frame
        system.update(deltaTime: 1.0 / 60.0)
        let initialPos = armorTransform.position

        // Run 59 more frames (total 1s)
        for _ in 0..<59 {
            system.update(deltaTime: 1.0 / 60.0)
        }

        let finalPos = armorTransform.position
        let distance = simd_length(finalPos - initialPos)
        #expect(distance > 1.0,
                "Armor asteroid should have moved due to rotation, distance: \(distance)")
    }

    @Test @MainActor func armorRotationSpeedIncreasesWithPhase() {
        // Phase 0
        let system0 = BossSystem()
        system0.bossType = .lithicHarvester
        system0.playerPosition = SIMD2(0, -200)
        let (boss0, armor0) = makeBossEntity(hp: 100)
        system0.register(boss0)

        // Phase 2
        let system2 = BossSystem()
        system2.bossType = .lithicHarvester
        system2.playerPosition = SIMD2(0, -200)
        let (boss2, armor2) = makeBossEntity(hp: 100)
        let health2 = boss2.component(ofType: HealthComponent.self)!
        health2.currentHealth = 20  // 20% -> phase 2
        system2.register(boss2)

        // Run both for 1 second
        for _ in 0..<60 {
            system0.update(deltaTime: 1.0 / 60.0)
            system2.update(deltaTime: 1.0 / 60.0)
        }

        #expect(armor2.rotationAngle > armor0.rotationAngle,
                "Phase 2 rotation should be faster: p0=\(armor0.rotationAngle), p2=\(armor2.rotationAngle)")
    }

    @Test @MainActor func rotatedArmorCoverageUsesRotationAngle() {
        let armor = BossArmorComponent()
        armor.slots = [ArmorSlot(angle: 0, entity: makeArmorAsteroidEntity())]

        #expect(armor.coveringSlotIndex(for: 0) == 0)

        armor.rotationAngle = .pi / 2

        #expect(armor.coveringSlotIndex(for: 0) == nil)
        #expect(armor.coveringSlotIndex(for: .pi / 2) == 0)
    }
```

- [ ] **Step 2: Verify the tests fail.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "LithicHarvesterTests/armorRingRotatesOverTime|LithicHarvesterTests/armorAsteroidPositionChangesWithRotation|LithicHarvesterTests/armorRotationSpeedIncreasesWithPhase|LithicHarvesterTests/rotatedArmorCoverageUsesRotationAngle" 2>&1 | tail -10
```

Expected: compilation error — `coveringSlotIndex` does not exist yet.

- [ ] **Step 3: Add a shared rotated-coverage helper to `BossArmorComponent`, then use it from both projectile and Phase Laser interception.**

In `Engine2043/Sources/Engine2043/ECS/Components/BossArmorComponent.swift`, after `rotationAngle`, add:

```swift
    public func coveringSlotIndex(for angle: Float, halfArc: Float = .pi / 6) -> Int? {
        for (i, slot) in slots.enumerated() where slot.isActive {
            var diff = angle - (slot.angle + rotationAngle)
            while diff > .pi  { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            if abs(diff) <= halfArc {
                return i
            }
        }
        return nil
    }
```

Then update:

- `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift` so `handleProjectileHitEnemy(...)` uses `armor.coveringSlotIndex(for: approachAngle)` instead of duplicating static-angle math.
- `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift` so `processLaserHitscan(...)` uses the same helper for boss armor interception.

This keeps the rotating armor visuals and the armor-hit logic in sync.

- [ ] **Step 4: Verify all rotation and rotated-coverage tests pass.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter "LithicHarvesterTests/armorRingRotatesOverTime|LithicHarvesterTests/armorAsteroidPositionChangesWithRotation|LithicHarvesterTests/armorRotationSpeedIncreasesWithPhase|LithicHarvesterTests/rotatedArmorCoverageUsesRotationAngle" 2>&1 | tail -5
```

Expected: `Test run with 4 tests passed`.

- [ ] **Step 5: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "feat(boss): apply Lithic Harvester armor rotation to visuals and hit coverage"
```

---

## Task 7: Update Boss Spawn Position in Galaxy2Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift:1088-1141`

- [ ] **Step 1: Change the boss spawn Y from 250 to `GameConfig.Galaxy2.Boss.spawnY` and set `introComplete = false`. Use the cull-safe value from Task 1 (`340`, not `400`).**

In `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`, in the `spawnBoss()` method at line 1091, change:

```swift
        boss.addComponent(TransformComponent(position: SIMD2(0, 250)))
```

to:

```swift
        boss.addComponent(TransformComponent(position: SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)))
```

Then after line 1109 (`boss.addComponent(BossPhaseComponent(totalHP: GameConfig.Galaxy2.Enemy.bossHP))`), add:

```swift
        boss.component(ofType: BossPhaseComponent.self)!.introComplete = false
```

- [ ] **Step 2: Update the initial armor positions to use the spawn Y instead of hard-coded 250.**

No code change needed here because line 1129 already reads from `boss.component(ofType: TransformComponent.self)!.position`, which will now be `(0, spawnY)`. The armor asteroids will spawn at the top and descend with the boss during intro.

- [ ] **Step 3: Build to verify no compilation errors.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 4: Run the full test suite to check for regressions.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 5: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "feat(scene): spawn Lithic Harvester above viewport for entry descent"
```

---

## Task 8: Final Integration Verification

**Files:**
- Test: `Engine2043/Tests/Engine2043Tests/LithicHarvesterTests.swift`

- [ ] **Step 1: Write an integration test that runs the full boss lifecycle (intro -> drift + rotation -> attacks).**

Add to `LithicHarvesterTests`:

```swift
    // MARK: - Integration: full lifecycle

    @Test @MainActor func lithicHarvesterFullLifecycle() {
        let system = BossSystem()
        system.bossType = .lithicHarvester
        system.playerPosition = SIMD2(0, -200)

        let (boss, armor) = makeBossEntity(hp: 100)
        let transform = boss.component(ofType: TransformComponent.self)!
        let phase = boss.component(ofType: BossPhaseComponent.self)!
        transform.position = SIMD2(0, GameConfig.Galaxy2.Boss.spawnY)
        phase.introComplete = false

        // Attach armor to slot 0
        let armorEntity = makeArmorAsteroidEntity(position: .zero)
        armor.slots[0].entity = armorEntity

        system.register(boss)

        // Phase 1: Intro descent (run slightly past 1.5s to avoid boundary flake)
        for _ in 0..<120 {
            system.update(deltaTime: 1.0 / 60.0)
        }
        #expect(phase.introComplete == true, "Intro should be complete")
        #expect(transform.position.y == GameConfig.Galaxy2.Boss.restingY)

        // Phase 2: Post-intro — drift should be active, armor should rotate, attacks should fire
        var totalProjectiles = 0
        let preRotation = armor.rotationAngle
        for _ in 0..<180 { // 3 more seconds
            system.update(deltaTime: 1.0 / 60.0)
            totalProjectiles += system.pendingProjectileSpawns.count
        }

        #expect(abs(transform.position.x) > 0.1, "Boss should have drifted laterally")
        #expect(armor.rotationAngle > preRotation, "Armor should have continued rotating")
        #expect(totalProjectiles > 0, "Boss should have fired projectiles after intro")
    }
```

- [ ] **Step 2: Verify the integration test passes.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test --filter LithicHarvesterTests/lithicHarvesterFullLifecycle 2>&1 | tail -5
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 3: Run the entire test suite one final time.**

```bash
cd /Users/david/Code/turbo-carnival/Engine2043 && swift test 2>&1 | tail -15
```

Expected: all tests pass, no regressions.

- [ ] **Step 4: Commit.**

```bash
cd /Users/david/Code/turbo-carnival && git add -A && git commit -m "test(boss): add Lithic Harvester full lifecycle integration test"
```
