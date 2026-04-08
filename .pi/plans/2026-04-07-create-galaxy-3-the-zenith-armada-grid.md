# Create Galaxy 3: The Zenith Armada Grid

## Header

**Goal**: Implement Galaxy 3 as the next playable stage after the Lithic Harvester so a normal run can progress Title → Galaxy 1 → Galaxy 2 → Galaxy 3 → Victory, with Galaxy 3 delivering a complete end-to-end loop: megastructure presentation, restricted-but-reasonable corridor traversal, tracking drones, coordinated four-fighter squads, fortress encounters, and a defeat-able Zenith Core Sentinel boss. During implementation, resolve specification differences case-by-case by preserving the current codebase’s item cycling system, converting the spec’s 1080px tunnel numbers into practical design-space corridor widths for the engine’s 360x640 baseline plus dynamic viewport width, and favoring readable, fun safe lanes over pixel-perfect choke points.

**Architecture summary**: The game is a SwiftPM engine package (`Engine2043`) embedded in thin macOS/iOS app shells. Gameplay lives in scene-owned orchestrators (`Galaxy1Scene`, `Galaxy2Scene`) that wire ECS-style components and systems together, own entity arrays, process collisions, run scripted spawns, and handle boss flow plus transitions. Galaxy 3 should follow that pattern, but its content is richer than Galaxy 1/2, so the new stage should be decomposed into focused helpers: a Galaxy 3 environment system for megastructure presentation and corridor math, a dedicated encounter director that emits stage commands from scroll distance plus delta time, an entity factory that returns Galaxy 3 enemy/fortress/barrier bundles, and a scene that orchestrates those helpers, owns barrier collision push-out, and hands boss state to `BossSystem`.

**Tech stack**: Swift 6, Swift Package Manager, GameplayKit entities/components, custom ECS systems, Metal rendering with procedural sprite generation (`TextureAtlas` / `SpriteFactory`), AVFoundation audio, Swift Testing, Xcode app shells for macOS and iOS, and xcodegen project configuration via `project.yml`.

## File Structure

- `Engine2043/Sources/Engine2043/Core/GameConfig.swift` (Modify) — Add `GameConfig.Galaxy3` constants for palette, enemy/fortress/boss health, barrier damage, scroll tuning, and practical corridor widths in current design-space units.
- `Engine2043/Sources/Engine2043/ECS/Entity.swift` (Modify) — Add a dedicated `.barrier` collision layer and keep layer values explicit for collision tests and scene masks.
- `Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift` (Modify) — Track temporary secondary-weapon disable state without blocking primary fire or laser heat behavior.
- `Engine2043/Sources/Engine2043/ECS/Components/BarrierComponent.swift` (Create) — Describe barrier kind, open/close cadence, collision damage, push-out axis, and scroll behavior for trench walls and rotating gates.
- `Engine2043/Sources/Engine2043/ECS/Components/FortressNodeComponent.swift` (Create) — Describe fortress roles such as shield generator, main battery, pulse turret, and shield-group membership.
- `Engine2043/Sources/Engine2043/ECS/Components/ProjectileComponent.swift` (Create) — Attach projectile damage, effect payloads, homing data, and lifetime metadata to Galaxy 3 hostile shots.
- `Engine2043/Sources/Engine2043/ECS/Components/ZenithBossComponent.swift` (Create) — Hold Zenith-specific boss state; Task 1 creates the core phase/state data and Task 5 extends it with attack timers, shield cadence, and overlap sequencing.
- `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift` (Modify) — Add projectile-metadata damage/effects with Galaxy 1/2 fallback behavior, explicit player-vs-barrier handling, and a scene callback for barrier push-out.
- `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift` (Modify) — Tick secondary-disable timers and refuse secondary spawns while disabled, while leaving primary/projectile and laser logic unchanged.
- `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift` (Modify) — Add Zenith Core Sentinel registration, phase evaluation, projectile scheduling, invulnerability windows, and defeat signaling.
- `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EnvironmentSystem.swift` (Create) — Manage Galaxy 3 parallax plating, megastructure sprites, active barrier layouts, corridor bounds, and scroll-lock behavior.
- `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EncounterDirector.swift` (Create) — Define Galaxy 3 encounter script data plus the `update(scrollDistance:deltaTime:)`, `pendingCommands`, and boss-trigger interface consumed by the scene.
- `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EntityFactory.swift` (Create) — Centralize construction of tracking drones, four-fighter squads, fortress encounter bundles, barriers, and the Zenith boss shell/core.
- `Engine2043/Sources/Engine2043/Scene/Galaxy3Scene.swift` (Create) — Orchestrate Galaxy 3 systems, carryover restoration, scripted spawning, barrier traversal, boss state hooks, HUD/effects, and victory transition.
- `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift` (Modify) — Replace the current final-victory handoff with `PlayerCarryover` generation and `.toGalaxy3(carryover)`.
- `Engine2043/Sources/Engine2043/Scene/SceneTransition.swift` (Modify) — Add `.toGalaxy3(PlayerCarryover)`.
- `Engine2043/Sources/Engine2043/Scene/SceneManager.swift` (Modify) — Add Galaxy 3 factory storage and transition dispatch.
- `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift` (Modify) — Register Galaxy 3 sprite ids and atlas layout entries.
- `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift` (Modify) — Generate procedural Galaxy 3 sprites for drones, fighters, fortress parts, barriers, and the Zenith boss.
- `Project2043-macOS/MetalView.swift` (Modify) — Register Galaxy 3 scene creation in the macOS bootstrap.
- `Project2043-iOS/MetalView.swift` (Modify) — Register Galaxy 3 scene creation, add `updateHudInsets(for: Galaxy3Scene)`, and treat Galaxy 3 as a gameplay scene for control overlays.
- `Engine2043/Tests/Engine2043Tests/ComponentTests.swift` (Modify) — Cover defaults and invariants for new Galaxy 3 components.
- `Engine2043/Tests/Engine2043Tests/CollisionLayerTests.swift` (Modify) — Cover the new `.barrier` layer and any updated raw values.
- `Engine2043/Tests/Engine2043Tests/CollisionResponseHandlerTests.swift` (Modify) — Cover projectile metadata, Galaxy 1/2 fallback 5-damage behavior, and explicit barrier collision response.
- `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift` (Modify) — Cover secondary-disable timing and the guarantee that primary fire still works while secondaries are disabled.
- `Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift` (Modify) — Cover `.toGalaxy3` dispatch.
- `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift` (Modify) — Keep transition expectations aligned with the new enum case.
- `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift` (Modify) — Verify new Galaxy 3 sprite ids, dimensions, and non-empty pixel output.
- `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift` (Modify) — Update Galaxy 2 progression expectations to hand off to Galaxy 3 instead of immediate victory.
- `Engine2043/Tests/Engine2043Tests/Galaxy3EncounterDirectorTests.swift` (Create) — Own initial coverage for Galaxy 3 script timing, command sequencing, and boss-trigger state.
- `Engine2043/Tests/Engine2043Tests/Galaxy3SceneTests.swift` (Create) — Own initial coverage for Galaxy 3 scene startup, carryover, barrier traversal scaffolding, and boss-state handoff points.
- `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift` (Create) — Own initial coverage for Zenith phase behavior, shield windows, EMP disable effects, and victory handoff.

**Source:** `TODO-5309a639`

## Tasks

### Task 1: Add Galaxy 3 configuration and ECS data contracts

**Files:**
- Create: `Engine2043/Sources/Engine2043/ECS/Components/BarrierComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Components/FortressNodeComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Components/ProjectileComponent.swift`
- Create: `Engine2043/Sources/Engine2043/ECS/Components/ZenithBossComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/Core/GameConfig.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Entity.swift`
- Test: `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`
- Test: `Engine2043/Tests/Engine2043Tests/CollisionLayerTests.swift`

**Steps**
- [ ] **Step 1: Add `GameConfig.Galaxy3` constants** — Define Galaxy 3 palette values, tracking-drone HP (1.0), fighter HP (2.5), fortress node HP buckets, Zenith boss HP/phase thresholds, barrier collision damage, and first-pass corridor widths in current design-space units so lanes stay wider than a single 30-unit player ship.
- [ ] **Step 2: Add the `.barrier` collision layer symmetrically** — Extend `CollisionLayer` with `.barrier` and update masks/tests so barriers can collide with the player from either registration order, avoiding the collision system’s asymmetric higher-index blind spot.
- [ ] **Step 3: Create Galaxy 3 data components** — Add `BarrierComponent`, `FortressNodeComponent`, and `ProjectileComponent` with concrete fields for movement cadence, shielded-node membership, projectile damage, projectile effects, and lifetime/homing metadata.
- [ ] **Step 4: Create the core `ZenithBossComponent` contract** — Store the Zenith-specific phase thresholds, current state, scroll-lock intent, and defeat/shield flags in `ZenithBossComponent`, but leave per-pattern timers and overlap cooldowns for Task 5 so the file is extended instead of redefined later.

**Acceptance criteria:**
- `GameConfig.Galaxy3` contains concrete gameplay numbers for the initial implementation.
- Barrier collisions have their own explicit layer instead of pretending to be ordinary enemies.
- Projectile, fortress-node, and barrier behavior can be expressed in data components instead of scene-local booleans.
- `ZenithBossComponent` exists with core phase/state fields that later boss work can extend without replacing.

**Model recommendation:** standard

### Task 2: Wire combat primitives and progression plumbing without breaking Galaxies 1 and 2

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/WeaponComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneTransition.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/SceneManager.swift`
- Test: `Engine2043/Tests/Engine2043Tests/CollisionResponseHandlerTests.swift`
- Test: `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`

**Steps**
- [ ] **Step 1: Add secondary-disable state to the weapon pipeline** — Extend `WeaponComponent` and `WeaponSystem` with a timer-driven “secondaries disabled” state that blocks `.gravBomb`, `.empSweep`, and `.overcharge`, but still allows standard firing and Phase Laser heat behavior.
- [ ] **Step 2: Make projectile damage metadata backward-compatible** — Update `CollisionResponseHandler` so `ProjectileComponent` damage/effects are used when present, and when a projectile lacks the new component the handler falls back to the existing 5-damage behavior used by Galaxy 1 and Galaxy 2 projectiles.
- [ ] **Step 3: Add explicit player-vs-barrier collision handling** — Add a dedicated barrier branch in `CollisionResponseHandler` that applies Galaxy 3 barrier collision damage, never destroys the barrier entity, and reports a barrier-hit callback that Galaxy 3 can use for push-out resolution.
- [ ] **Step 4: Wire `.toGalaxy3` through shared transition plumbing** — Add `.toGalaxy3(PlayerCarryover)` to `SceneTransition` and thread it through `SceneManager` so Galaxy 2 can request the new stage before the app shells are updated in Task 4.

**Acceptance criteria:**
- Secondary weapons can be disabled temporarily without breaking primary weapons.
- `CollisionResponseHandler` preserves legacy 5-damage behavior for old projectile entities.
- Barrier collisions are handled as their own concern, not folded into projectile logic.
- The shared transition stack can represent and dispatch a Galaxy 3 request before app-shell scene registration is added later.

**Model recommendation:** standard

### Task 3: Build Galaxy 3 visuals, environment logic, and the encounter-director contract

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EnvironmentSystem.swift`
- Create: `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EncounterDirector.swift`
- Create: `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EntityFactory.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/TextureAtlas.swift`
- Modify: `Engine2043/Sources/Engine2043/Rendering/SpriteFactory.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`
- Test: `Engine2043/Tests/Engine2043Tests/Galaxy3EncounterDirectorTests.swift`

**Steps**
- [ ] **Step 1: Register Galaxy 3 sprites in the atlas** — Add sprite ids and layout entries for tracking drones, Galaxy 3 fighters, fortress hull parts, fortress nodes, barriers, and Zenith boss parts, and keep every layout width/height exactly matched to its sprite generator output so UVs remain correct.
- [ ] **Step 2: Create `Galaxy3EnvironmentSystem`** — Give Galaxy 3 its own scroll distance, scroll-lock flag, megastructure sprite collection, and lane-bound computation so the stage can render barriers and trenches without warping the starfield-only `BackgroundSystem`.
- [ ] **Step 3: Define a predictable `Galaxy3EncounterDirector` interface** — Implement `update(scrollDistance: Float, deltaTime: Double)`, `pendingCommands: [Galaxy3SpawnCommand]`, and boss-trigger state on a single director that emits `.droneCluster`, `.fighterSquad`, `.fortressEncounter`, `.barrierLayout`, and `.bossTrigger` commands in one queue.
- [ ] **Step 4: Create `Galaxy3EntityFactory` spawn bundles** — Centralize constructors for Galaxy 3 enemies, fortress sections, barrier entities, and a Zenith boss shell so the scene can register decorative hulls, interactive nodes, and projectile-enabled entities consistently.

**Acceptance criteria:**
- Galaxy 3 has dedicated rendering assets instead of overloading Galaxy 1/2 sprites.
- The environment system supports both free scrolling and boss scroll lock.
- The encounter director exposes a clear command queue and boss-trigger contract that `Galaxy3Scene` can consume without redesign.
- `Galaxy3EncounterDirectorTests.swift` is created here and becomes a modify-only file in later tasks.

**Model recommendation:** standard

### Task 4: Implement the playable Galaxy 3 stage loop and the Galaxy 2 → Galaxy 3 handoff

**Files:**
- Create: `Engine2043/Sources/Engine2043/Scene/Galaxy3Scene.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift`
- Modify: `Project2043-macOS/MetalView.swift`
- Modify: `Project2043-iOS/MetalView.swift`
- Test: `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift`
- Test: `Engine2043/Tests/Engine2043Tests/Galaxy3SceneTests.swift`

**Steps**
- [ ] **Step 1: Scaffold `Galaxy3Scene` from the established scene pattern** — Mirror the orchestration style used by `Galaxy2Scene`, including title card, HUD/effect sprite collection, entity arrays, collision handling, item system wiring, audio setup, and culling.
- [ ] **Step 2: Consume Galaxy 3 encounter commands for non-boss content** — Drive tracking-drone clusters, four-ship fighter squads, fortress encounter bundles, and barrier layouts from `Galaxy3EncounterDirector.pendingCommands`, keeping the current item spawn/cycle system intact instead of inventing a new Galaxy 3 item table.
- [ ] **Step 3: Add the explicit boss-flow handoff points Task 5 needs** — Scaffold a `Galaxy3Scene` stage-state enum (`scrolling`, `bossIntro`, `bossActive`, `bossDefeat`), `bossEntity` storage, scroll-lock hooks, and a `BossSystem` registration/integration path so the Zenith boss can be added later without restructuring the scene.
- [ ] **Step 4: Replace Galaxy 2’s final victory with Galaxy 3 carryover** — After the Lithic Harvester death animation, build `PlayerCarryover`, request `.toGalaxy3(carryover)`, and verify Galaxy 3 restores the carried weapon, score, charges, and shield drones while resetting energy to full.
- [ ] **Step 5: Register Galaxy 3 in both app shells once the scene exists** — Add `Galaxy3Scene` factory closures in the macOS and iOS `MetalView`s, add the iOS `updateHudInsets(for: Galaxy3Scene)` overload, and treat Galaxy 3 as a gameplay scene for control overlays.
- [ ] **Step 6: Implement barrier traversal resolution in the scene** — Use the environment system’s active lane bounds plus the collision handler’s barrier callback to push the player out of barrier overlap, apply kinetic damage, and keep first-pass corridors restrictive but still readable.

**Acceptance criteria:**
- Defeating the Galaxy 2 boss now reaches Galaxy 3 in normal progression.
- Galaxy 3 is playable from stage start through the pre-boss gauntlet.
- `Galaxy3Scene` already contains boss-state, scroll-lock, and `BossSystem` hooks before Zenith behavior is added.
- `Galaxy3SceneTests.swift` is created here and becomes a modify-only file in later tasks.

**Model recommendation:** capable

### Task 5: Implement The Zenith Core Sentinel boss encounter

**Files:**
- Modify: `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift`
- Modify: `Engine2043/Sources/Engine2043/ECS/Components/ZenithBossComponent.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy3Scene.swift`
- Test: `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift`

**Steps**
- [ ] **Step 1: Extend `ZenithBossComponent` with timed boss state** — Add attack cooldowns, shield-window cadence, homing/EMP timers, intro descent timing, and overlap bookkeeping to the Task 1 component instead of redefining a second boss-state structure.
- [ ] **Step 2: Add a Zenith branch to `BossSystem`** — Introduce `.zenithCoreSentinel`, keep using `BossPhaseComponent` for the generic health-fraction phase counter, and use `ZenithBossComponent` for Zenith-only attack sequencing and invulnerability rules.
- [ ] **Step 3: Implement the four boss phases with readable first-pass attacks** — Add geometric laser grids, spiral sweeps, homing bursts, dense-but-solvable bullet arrays, EMP projectiles that disable secondaries temporarily, and phase-3/4 shield windows that still leave deliberate damage opportunities.
- [ ] **Step 4: Replace the Task 4 placeholder flow with the real boss loop** — Spawn the real Zenith boss, lock the Galaxy 3 environment scroll during the arena, route boss shots through `ProjectileComponent`, and transition to `.toVictory(gameResult)` only after the Sentinel’s defeat sequence completes.
- [ ] **Step 5: Reuse existing audio tracks for the first pass** — Drive Galaxy 3 gameplay with existing gameplay/boss music rather than introducing missing bundle assets, so end-to-end flow works before any bespoke audio pass.

**Acceptance criteria:**
- The Zenith Core Sentinel has four distinct phases at 75%, 50%, and 25% thresholds.
- Boss hazards can apply differentiated damage and temporary secondary disable effects.
- Phase 4 overlaps are bounded and leave readable offensive windows.
- `ZenithCoreSentinelTests.swift` is created here and becomes a modify-only file in Task 6.

**Model recommendation:** capable

### Task 6: Expand automated coverage across the new progression, stage, and boss paths

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/ComponentTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/CollisionLayerTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/CollisionResponseHandlerTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/WeaponSystemTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SceneManagerTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SceneTransitionTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SpriteFactoryTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/Galaxy3EncounterDirectorTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/Galaxy3SceneTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift`

**Steps**
- [ ] **Step 1: Extend low-level regression tests** — Cover component defaults, the new barrier layer, projectile-component damage, the explicit 5-damage fallback for legacy projectiles, barrier collision damage, and secondary-disable timer expiration.
- [ ] **Step 2: Extend progression tests** — Verify `.toGalaxy3` dispatch, Galaxy 2 carryover integrity, and the Galaxy 2 → Galaxy 3 → Victory flow without relying on app-shell code.
- [ ] **Step 3: Extend the Galaxy 3 test files created earlier instead of recreating them** — Add command-order, boss-trigger, scroll-lock, scene-state, phase-threshold, invulnerability-window, and defeat-transition assertions to the Task 3–5 test files.
- [ ] **Step 4: Keep the suite SwiftPM-friendly** — Use existing test helpers and `@testable import Engine2043` so the new tests run under the package test target rather than depending on UIKit/AppKit bootstraps.

**Acceptance criteria:**
- No new Galaxy 3 test file is recreated here; `Galaxy3EncounterDirectorTests.swift`, `Galaxy3SceneTests.swift`, and `ZenithCoreSentinelTests.swift` are modify-only in this task.
- Automated tests cover progression, collisions, rendering asset registration, stage logic, and boss behavior.
- The suite remains runnable via SwiftPM.
- Existing Galaxy 1/2 behaviors remain covered while Galaxy 3 is added.

**Model recommendation:** standard

### Task 7: Run automated verification and document the required human playthrough

**Files:**
- Test: `Engine2043/Package.swift`
- Test: `Project2043.xcodeproj`
- Test: `Project2043-macOS/MetalView.swift`
- Test: `Project2043-iOS/MetalView.swift`

**Steps**
- [ ] **Step 1: Run the package test suite** — Execute `swift test --package-path Engine2043` and resolve failures before claiming Galaxy 3 is complete.
- [ ] **Step 2: Build a playable app target** — Run an app build such as `xcodebuild -project Project2043.xcodeproj -scheme Project2043-macOS build` to catch scene-factory, atlas, and target-membership issues that package tests do not exercise.
- [ ] **Step 3: Hand off a human-required playthrough checklist** — Have a human start at the title screen, clear Galaxy 1 and Galaxy 2, confirm the transition into Galaxy 3, and continue into the Zenith Core Sentinel fight.
- [ ] **Step 4: Hand off a human-required completion checklist** — Have a human defeat the Zenith Core Sentinel in a normal run and record any remaining issues as balance/readability follow-ups rather than missing end-to-end functionality.

**Acceptance criteria:**
- Automated verification steps are executable and complete.
- Manual playthrough work is clearly marked as human-required verification rather than an automated agent action.
- The project build succeeds after Galaxy 3 integration.
- Remaining issues after the first playable run are tuning notes, not missing stage flow.

**Model recommendation:** standard

## Dependencies

- Task 2 depends on: Task 1
- Task 3 depends on: Task 1, Task 2
- Task 4 depends on: Task 2, Task 3
- Task 5 depends on: Task 1, Task 4
- Task 6 depends on: Task 1, Task 2, Task 3, Task 4, Task 5
- Task 7 depends on: Task 6

## Risk Assessment

- **Spec conflict: Galaxy 3 corridor numbers vs current coordinate system** — The Galaxy 3 spec assumes 1080px-wide tunnels, but the engine’s design space is 360 units wide with a 30-unit player ship and a dynamic `ViewportManager`. **Mitigation:** author barrier widths in `GameConfig.Galaxy3` as design-space values and lane fractions, and keep the first pass above a defined minimum practical width.
- **Spec conflict: item system detail vs current codebase reality** — The spec documents a richer Galaxy 3 item table, but the actual codebase uses weapon modules plus three utility items (`energyCell`, `chargeCell`, `orbitingShield`). **Mitigation:** keep Galaxy 3 on the existing item spawn/cycle system exactly as requested and treat any broader item redesign as a later task.
- **Backward-compatibility risk: Galaxy 1/2 hostile projectiles have no `ProjectileComponent`** — Existing projectile collision code hard-codes 5 damage. **Mitigation:** preserve that 5-damage path when the new component is absent and only rely on metadata for new Galaxy 3 projectiles.
- **Barrier collision risk: current collision handler only damages/removes entities** — Architectural barriers need both damage and positional push-out, unlike ordinary enemy collisions. **Mitigation:** give barriers their own collision branch plus a scene callback so Galaxy 3 owns push-out resolution while the handler stays responsible for damage semantics.
- **Encounter-director ambiguity risk** — A vague Galaxy 3 encounter API would force `Galaxy3Scene` to redesign the stage logic while implementing it. **Mitigation:** lock the contract early around `update(scrollDistance:deltaTime:)`, `pendingCommands`, and explicit boss-trigger state.
- **Boss-system growth risk** — `BossSystem.swift` already handles two bosses and can become unwieldy. **Mitigation:** keep Zenith-specific timers in `ZenithBossComponent`, and keep phase logic structured around existing `BossPhaseComponent` plus private Zenith helper paths inside `BossSystem`.
- **Audio/content gap risk** — The repo only ships gameplay/boss tracks for existing stages. **Mitigation:** reuse existing gameplay and boss tracks for Galaxy 3 rather than adding bundle dependencies that do not exist.
- **Functional-first tuning risk** — The source spec trends toward punishing navigation and heavy pattern overlap. **Mitigation:** implement a readable, practical first pass with clear safe lanes and bounded overlap windows, then treat balance notes as follow-up work after end-to-end verification.

## Test Command

```bash
swift test --package-path Engine2043
```

## Review Notes

_Added by plan reviewer — informational, not blocking._

### Warnings
- **Task 3**: The plan creates a new `Galaxy3EncounterDirector` with `update(scrollDistance:deltaTime:)` and a `pendingCommands` queue using `Galaxy3SpawnCommand` enums. The existing codebase uses `SpawnDirector` with `WaveDefinition` structs, `pendingWaves`, `pendingDrops`, and `pendingAsteroidFields` as separate queues. The plan is intentionally diverging from the Galaxy 1/2 `SpawnDirector` pattern, but doesn't explicitly state why or acknowledge the divergence.
  - **What:** The plan creates a new `Galaxy3EncounterDirector` with `update(scrollDistance:deltaTime:)` and a `pendingCommands` queue using `Galaxy3SpawnCommand` enums. The existing codebase uses `SpawnDirector` with `WaveDefinition` structs, `pendingWaves`, `pendingDrops`, and `pendingAsteroidFields` as separate queues. The plan is intentionally diverging from the Galaxy 1/2 `SpawnDirector` pattern, but doesn't explicitly state why or acknowledge the divergence.
  - **Why it matters:** An implementing agent may try to reuse `SpawnDirector` or `WaveDefinition`, or may be confused by the intentional divergence. The Galaxy 3 spec has fundamentally different encounter content (barriers, fortress encounters, drone clusters, fighter squads, boss triggers) that doesn't map cleanly to `WaveDefinition`'s `EnemyTier` enum, so a new director is reasonable — but the agent should know this is deliberate.
  - **Recommendation:** No change required; the plan's architecture summary already explains the decomposition rationale. The implementing agent will see that `Galaxy3SpawnCommand` enums cover barrier layouts, drone clusters, fighter squads, fortress encounters, and boss triggers — content that `WaveDefinition.EnemyTier` (`.tier1`, `.tier2`, `.tier3`, `.boss`) can't express. This is informational only.
- **Task 4**: `Galaxy3Scene.swift` is modeled after `Galaxy2Scene.swift`, which is 1,831 lines. Task 4 asks the agent to scaffold the scene from the established Galaxy 2 pattern, including title card, HUD/effect sprite collection, entity arrays, collision handling, item system wiring, audio setup, culling, encounter command consumption, barrier traversal resolution, boss-flow scaffolding, and app-shell registration. This is a large scope for a single task.
  - **What:** `Galaxy3Scene.swift` is modeled after `Galaxy2Scene.swift`, which is 1,831 lines. Task 4 asks the agent to scaffold the scene from the established Galaxy 2 pattern, including title card, HUD/effect sprite collection, entity arrays, collision handling, item system wiring, audio setup, culling, encounter command consumption, barrier traversal resolution, boss-flow scaffolding, and app-shell registration. This is a large scope for a single task.
  - **Why it matters:** Galaxy2Scene is the largest file in the project and Galaxy3Scene will be at least as complex (adding barriers, environment system integration, encounter director consumption). The implementing agent needs to produce a large, cohesive file in one pass. However, the plan mitigates this by extracting Galaxy 3 helpers into separate files (`Galaxy3EnvironmentSystem`, `Galaxy3EncounterDirector`, `Galaxy3EntityFactory`) in Task 3, so the scene itself is primarily orchestration.
  - **Recommendation:** The `capable` model recommendation is appropriate for Task 4. No structural change needed, but this is the highest-risk task for execution quality.
- **Task 5**: Step 3 says "Add geometric laser grids, spiral sweeps, homing bursts, dense-but-solvable bullet arrays, EMP projectiles" but doesn't specify projectile counts, speeds, intervals, or safe-zone sizing in design-space units. The Galaxy 3 spec provides numbers in 1080px-space (e.g., 80-120px corridors, 120-180px laser separation, 40px beam width).
  - **What:** Step 3 says "Add geometric laser grids, spiral sweeps, homing bursts, dense-but-solvable bullet arrays, EMP projectiles" but doesn't specify projectile counts, speeds, intervals, or safe-zone sizing in design-space units. The Galaxy 3 spec provides numbers in 1080px-space (e.g., 80-120px corridors, 120-180px laser separation, 40px beam width).
  - **Why it matters:** The implementing agent must convert spec numbers to design-space units (360-wide baseline) and choose concrete values. The plan's `GameConfig.Galaxy3` (Task 1) should contain these numbers, and Task 5 just consumes them. However, Task 1 Step 1 only mentions corridor widths and HP values, not boss attack parameters specifically.
  - **Recommendation:** Task 1 should ideally include boss attack parameters (projectile counts, speeds, intervals) in `GameConfig.Galaxy3` so Task 5 can consume them. In practice, the Task 5 agent can define additional `GameConfig.Galaxy3` boss constants since it modifies `ZenithBossComponent` anyway. This is unlikely to block execution.

### Suggestions
- **Task 2**: Task 2 Step 3 adds "explicit player-vs-barrier collision handling" with "a barrier-hit callback that Galaxy 3 can use for push-out resolution." The existing `CollisionResponseHandler` works through the `CollisionContext` protocol. Adding a barrier callback means either extending `CollisionContext` with a new optional method or adding a separate callback mechanism.
  - **What:** Task 2 Step 3 adds "explicit player-vs-barrier collision handling" with "a barrier-hit callback that Galaxy 3 can use for push-out resolution." The existing `CollisionResponseHandler` works through the `CollisionContext` protocol. Adding a barrier callback means either extending `CollisionContext` with a new optional method or adding a separate callback mechanism.
  - **Why it matters:** The agent needs to decide how to wire the barrier callback. The plan doesn't specify whether `CollisionContext` gets a new method like `handleBarrierPushOut(entity:)` or whether the handler stores barrier hits in a separate array. Galaxy 1 and Galaxy 2 scenes would need default no-op implementations if the protocol is extended.
  - **Recommendation:** The agent should extend `CollisionContext` with an optional method (via protocol extension default) for barrier push-out, similar to how `asteroidSystem` already has a default `nil` extension. This is a minor implementation detail that the Task 2 agent can resolve.
- **Task 1**: Task 1 Step 1 defines "Galaxy 3 palette values, tracking-drone HP, fighter HP, fortress node HP buckets, Zenith boss HP/phase thresholds, barrier collision damage, and corridor widths." It does not mention boss attack parameters (projectile speeds, fire intervals, laser grid parameters, homing projectile behavior).
  - **What:** Task 1 Step 1 defines "Galaxy 3 palette values, tracking-drone HP, fighter HP, fortress node HP buckets, Zenith boss HP/phase thresholds, barrier collision damage, and corridor widths." It does not mention boss attack parameters (projectile speeds, fire intervals, laser grid parameters, homing projectile behavior).
  - **Why it matters:** Task 5 needs concrete boss attack numbers. If they aren't in `GameConfig.Galaxy3`, the Task 5 agent will either need to add them or inline them, which would be inconsistent with the project's pattern of centralizing gameplay numbers in `GameConfig`.
  - **Recommendation:** Add a note in Task 1 Step 1 to also include Galaxy 3 boss attack constants (fire intervals, projectile speeds, projectile counts, shield window durations, EMP disable duration). This prevents Task 5 from needing to modify `GameConfig.swift` when it's not listed in Task 5's file list.
- **Task 2**: Task 2 Step 1 adds secondary-disable state to `WeaponComponent`/`WeaponSystem`. Task 5 creates EMP boss projectiles that trigger this state. But the connection between EMP projectile collision and weapon-disable activation isn't explicitly owned by any task. Task 2 Step 2 makes `CollisionResponseHandler` use `ProjectileComponent` damage/effects, and Task 2 Step 3 describes `ProjectileComponent` effects — but "effects" is not clearly defined as including weapon-disable triggers.
  - **What:** Task 2 Step 1 adds secondary-disable state to `WeaponComponent`/`WeaponSystem`. Task 5 creates EMP boss projectiles that trigger this state. But the connection between EMP projectile collision and weapon-disable activation isn't explicitly owned by any task. Task 2 Step 2 makes `CollisionResponseHandler` use `ProjectileComponent` damage/effects, and Task 2 Step 3 describes `ProjectileComponent` effects — but "effects" is not clearly defined as including weapon-disable triggers.
  - **Why it matters:** The EMP disable flow crosses Task 2 (collision response + weapon system) and Task 5 (boss projectile creation). The implementing agents need to know that `ProjectileComponent.effects` (or similar) includes an EMP-disable flag that the collision handler reads and applies.
  - **Recommendation:** Task 2 Step 2 should explicitly note that `ProjectileComponent` effects include a secondary-disable payload that `CollisionResponseHandler` applies when processing enemy projectile hits. Task 1's `ProjectileComponent` creation (Step 3) already mentions "projectile effects" — the chain is plausible but could be more explicit.
