# Plan Review: Create Galaxy 3 — The Zenith Armada Grid

## Status

**[Approved]**

---

## Issues

### Warning — Task 3: Galaxy3EncounterDirector uses a different contract model than existing SpawnDirector

- **What:** The plan creates a new `Galaxy3EncounterDirector` with `update(scrollDistance:deltaTime:)` and a `pendingCommands` queue using `Galaxy3SpawnCommand` enums. The existing codebase uses `SpawnDirector` with `WaveDefinition` structs, `pendingWaves`, `pendingDrops`, and `pendingAsteroidFields` as separate queues. The plan is intentionally diverging from the Galaxy 1/2 `SpawnDirector` pattern, but doesn't explicitly state why or acknowledge the divergence.
- **Why it matters:** An implementing agent may try to reuse `SpawnDirector` or `WaveDefinition`, or may be confused by the intentional divergence. The Galaxy 3 spec has fundamentally different encounter content (barriers, fortress encounters, drone clusters, fighter squads, boss triggers) that doesn't map cleanly to `WaveDefinition`'s `EnemyTier` enum, so a new director is reasonable — but the agent should know this is deliberate.
- **Recommendation:** No change required; the plan's architecture summary already explains the decomposition rationale. The implementing agent will see that `Galaxy3SpawnCommand` enums cover barrier layouts, drone clusters, fighter squads, fortress encounters, and boss triggers — content that `WaveDefinition.EnemyTier` (`.tier1`, `.tier2`, `.tier3`, `.boss`) can't express. This is informational only.

### Warning — Task 4: Galaxy3Scene will be a very large file

- **What:** `Galaxy3Scene.swift` is modeled after `Galaxy2Scene.swift`, which is 1,831 lines. Task 4 asks the agent to scaffold the scene from the established Galaxy 2 pattern, including title card, HUD/effect sprite collection, entity arrays, collision handling, item system wiring, audio setup, culling, encounter command consumption, barrier traversal resolution, boss-flow scaffolding, and app-shell registration. This is a large scope for a single task.
- **Why it matters:** Galaxy2Scene is the largest file in the project and Galaxy3Scene will be at least as complex (adding barriers, environment system integration, encounter director consumption). The implementing agent needs to produce a large, cohesive file in one pass. However, the plan mitigates this by extracting Galaxy 3 helpers into separate files (`Galaxy3EnvironmentSystem`, `Galaxy3EncounterDirector`, `Galaxy3EntityFactory`) in Task 3, so the scene itself is primarily orchestration.
- **Recommendation:** The `capable` model recommendation is appropriate for Task 4. No structural change needed, but this is the highest-risk task for execution quality.

### Warning — Task 5: Boss attack implementation is vague on geometric specifics

- **What:** Step 3 says "Add geometric laser grids, spiral sweeps, homing bursts, dense-but-solvable bullet arrays, EMP projectiles" but doesn't specify projectile counts, speeds, intervals, or safe-zone sizing in design-space units. The Galaxy 3 spec provides numbers in 1080px-space (e.g., 80-120px corridors, 120-180px laser separation, 40px beam width).
- **Why it matters:** The implementing agent must convert spec numbers to design-space units (360-wide baseline) and choose concrete values. The plan's `GameConfig.Galaxy3` (Task 1) should contain these numbers, and Task 5 just consumes them. However, Task 1 Step 1 only mentions corridor widths and HP values, not boss attack parameters specifically.
- **Recommendation:** Task 1 should ideally include boss attack parameters (projectile counts, speeds, intervals) in `GameConfig.Galaxy3` so Task 5 can consume them. In practice, the Task 5 agent can define additional `GameConfig.Galaxy3` boss constants since it modifies `ZenithBossComponent` anyway. This is unlikely to block execution.

### Suggestion — Task 2: `CollisionContext` protocol needs updating for barrier callbacks

- **What:** Task 2 Step 3 adds "explicit player-vs-barrier collision handling" with "a barrier-hit callback that Galaxy 3 can use for push-out resolution." The existing `CollisionResponseHandler` works through the `CollisionContext` protocol. Adding a barrier callback means either extending `CollisionContext` with a new optional method or adding a separate callback mechanism.
- **Why it matters:** The agent needs to decide how to wire the barrier callback. The plan doesn't specify whether `CollisionContext` gets a new method like `handleBarrierPushOut(entity:)` or whether the handler stores barrier hits in a separate array. Galaxy 1 and Galaxy 2 scenes would need default no-op implementations if the protocol is extended.
- **Recommendation:** The agent should extend `CollisionContext` with an optional method (via protocol extension default) for barrier push-out, similar to how `asteroidSystem` already has a default `nil` extension. This is a minor implementation detail that the Task 2 agent can resolve.

### Suggestion — Task 1: GameConfig.Galaxy3 boss attack parameters should be defined early

- **What:** Task 1 Step 1 defines "Galaxy 3 palette values, tracking-drone HP, fighter HP, fortress node HP buckets, Zenith boss HP/phase thresholds, barrier collision damage, and corridor widths." It does not mention boss attack parameters (projectile speeds, fire intervals, laser grid parameters, homing projectile behavior).
- **Why it matters:** Task 5 needs concrete boss attack numbers. If they aren't in `GameConfig.Galaxy3`, the Task 5 agent will either need to add them or inline them, which would be inconsistent with the project's pattern of centralizing gameplay numbers in `GameConfig`.
- **Recommendation:** Add a note in Task 1 Step 1 to also include Galaxy 3 boss attack constants (fire intervals, projectile speeds, projectile counts, shield window durations, EMP disable duration). This prevents Task 5 from needing to modify `GameConfig.swift` when it's not listed in Task 5's file list.

### Suggestion — Task 2: `WeaponComponent` secondary-disable state needs EMP projectile trigger path

- **What:** Task 2 Step 1 adds secondary-disable state to `WeaponComponent`/`WeaponSystem`. Task 5 creates EMP boss projectiles that trigger this state. But the connection between EMP projectile collision and weapon-disable activation isn't explicitly owned by any task. Task 2 Step 2 makes `CollisionResponseHandler` use `ProjectileComponent` damage/effects, and Task 2 Step 3 describes `ProjectileComponent` effects — but "effects" is not clearly defined as including weapon-disable triggers.
- **Why it matters:** The EMP disable flow crosses Task 2 (collision response + weapon system) and Task 5 (boss projectile creation). The implementing agents need to know that `ProjectileComponent.effects` (or similar) includes an EMP-disable flag that the collision handler reads and applies.
- **Recommendation:** Task 2 Step 2 should explicitly note that `ProjectileComponent` effects include a secondary-disable payload that `CollisionResponseHandler` applies when processing enemy projectile hits. Task 1's `ProjectileComponent` creation (Step 3) already mentions "projectile effects" — the chain is plausible but could be more explicit.

---

## Summary

The plan is well-structured and ready for execution. It correctly decomposes Galaxy 3 into 7 dependency-ordered tasks that match the established codebase patterns. All spec requirements are covered: megastructure environment, tracking drones, coordinated four-fighter squads, fortress encounters, barrier traversal, the four-phase Zenith Core Sentinel boss, progression wiring from Galaxy 2, and existing item cycling preservation. Dependencies are accurate — each task's file list and interface dependencies trace correctly to declared predecessors.

The plan has **0 errors**, **3 warnings**, and **3 suggestions**. The warnings are informational sizing and specificity concerns that are unlikely to block execution. The suggestions improve cross-task clarity but aren't required for successful implementation. The plan correctly identifies and mitigates the key risks (coordinate system conversion, backward-compatible projectile damage, barrier collision architecture, encounter director contract, boss system growth, and audio/content gaps).

The plan is **approved for execution**.
