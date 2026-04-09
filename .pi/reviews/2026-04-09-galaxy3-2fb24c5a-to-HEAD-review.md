# Galaxy 3 implementation review (`2fb24c5a92d541f722a0f4bc06cd675c538b04ba..HEAD`)

Date: 2026-04-09  
Reviewer: `reviewer` subagent on `openai/gpt-5.4`, with follow-up manual validation in the worktree  
Guideline: `.pi/plans/2026-04-07-create-galaxy-3-the-zenith-armada-grid.md`

## Scope

Reviewed the changes from `2fb24c5a92d541f722a0f4bc06cd675c538b04ba` to `HEAD` against the Galaxy 3 plan, with emphasis on:

- Galaxy 2 → Galaxy 3 progression
- Galaxy 3 stage mechanics and boss behavior
- regression risk for existing weapons/collision behavior
- test coverage realism

## Verification performed

- Ran `swift test --package-path Engine2043`
- Result: **pass** (`469 tests`, `31 suites`)

The suite passing is a good sign, but several gameplay defects still appear to be untested.

## Strengths

- **Progression plumbing looks solid.** Galaxy 2 now hands off to Galaxy 3 cleanly and the new transition is wired through `SceneTransition`, `SceneManager`, and both app shells.
- **Shared combat plumbing kept backward compatibility in mind.** `CollisionResponseHandler` preserves legacy hostile-projectile behavior while supporting `ProjectileComponent`, and `WeaponSystem` adds secondary disable timing without obviously breaking primary fire.
- **The Galaxy 3 code is decomposed in the right direction.** Splitting logic across `Galaxy3Scene`, `Galaxy3EncounterDirector`, `Galaxy3EntityFactory`, `Galaxy3EnvironmentSystem`, and `BossSystem` matches the plan well.

## Findings

### Critical

1. **Phase Laser ignores Galaxy 3 shield and barrier blockers**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1496`
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:154`
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:251`
   - **What’s wrong:**
     `CollisionResponseHandler` correctly deflects ordinary projectiles when `ZenithBossComponent.isShieldActive` is true, but `Galaxy3Scene.processLaserHitscan` directly damages every overlapping enemy with no shield check, no `bossShield` blocker handling, and no barrier occlusion logic.
   - **Why it matters:**
     A carried `phaseLaser` can damage the Zenith boss through intended invulnerability windows and can also hit targets through corridor barriers. That breaks both the boss design and the stage’s traversal rules.
   - **Suggested fix:**
     Make `processLaserHitscan` honor blockers before applying damage:
     - stop the beam at the nearest barrier / shield blocker
     - skip boss damage while `ZenithBossComponent.isShieldActive` is true
     - add Galaxy 3 laser-blocking tests similar to the existing Galaxy 2 asteroid regression test

2. **Barrier / corridor traversal mechanics are only partially implemented; rotating gates are effectively cosmetic**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:323`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:952`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1369`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1584`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EnvironmentSystem.swift:61`
     - `Engine2043/Sources/Engine2043/ECS/Components/PhysicsComponent.swift:7`
     - `Engine2043/Sources/Engine2043/ECS/Systems/CollisionSystem.swift:135`
   - **What’s wrong:**
     Several pieces don’t connect into real gameplay:
     - each `barrierLayout` spawns only one left wall and one right wall, so layouts behave more like isolated pinch points than traversed corridor sections
     - rotating gates only change `transform.rotation`, but collisions are AABB-only via `collisionSize`, so the gate never actually opens/closes in collision space
     - `Galaxy3EnvironmentSystem.updateLaneBounds` computes bounds using `0...designWidth` assumptions while Galaxy 3 gameplay positions are centered around `0`
     - `activeLaneBounds` is updated but never consumed by push-out logic; `handleBarrierPushOut` resolves overlap purely against the touched entity
   - **Why it matters:**
     The plan calls corridor traversal and rotating gates out as core Galaxy 3 features. In the current implementation, much of that behavior is visual only or too local to produce the intended stage flow.
   - **Suggested fix:**
     - spawn actual multi-segment corridor/gate layouts over scroll distance
     - make gate state alter collision geometry, not just sprite rotation
     - compute lane bounds in centered world coordinates
     - use lane bounds during clamping / push-out so the corridor rules are consistent and readable

### Important

3. **Fortress shield-generator logic is dead data**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/ECS/Components/FortressNodeComponent.swift:11`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1320`
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:154`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1496`
   - **What’s wrong:**
     `FortressNodeComponent.isShielded` is set and later flipped off when a generator dies, but no damage path checks that flag. Both normal projectiles and the Phase Laser can still damage non-generator fortress nodes immediately.
   - **Why it matters:**
     That means the planned “destroy the generator, then open the rest of the fortress” mechanic never actually exists in play.
   - **Suggested fix:**
     Gate damage application on `FortressNodeComponent.isShielded` for non-generator nodes in both collision and hitscan damage paths, with visible shield feedback.

4. **Tracking drones do not track the player**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EntityFactory.swift:9`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:855`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:879`
   - **What’s wrong:**
     `makeTrackingDrone` gives drones a fixed downward velocity only. Fighters get a `SteeringComponent`, but drones do not.
   - **Why it matters:**
     One of the stage’s named encounter features is missing in practice, making the pre-boss section flatter than the plan intends.
   - **Suggested fix:**
     Add steering or dedicated update logic so drones bias toward the player within bounded, readable limits.

5. **Boss overlap cadence does not use the configured radial-burst interval**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Core/GameConfig.swift:225`
     - `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift:318`
     - `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift:339`
   - **What’s wrong:**
     `GameConfig.Galaxy3.BossAttack.radialBurstInterval` exists, but phase 3 and phase 4 radial bursts are fired whenever the grid-beam timer fires instead of on their own cadence.
   - **Why it matters:**
     That makes the boss materially denser than the declared config suggests and cuts against the plan’s “bounded overlap / readable windows” goal.
   - **Suggested fix:**
     Give radial bursts their own timer and add tests that assert real spawn cadence, not just relative projectile counts.

6. **The test suite misses the most important Galaxy 3 beam/blocker cases**
   - **Refs:**
     - `Engine2043/Tests/Engine2043Tests/Galaxy3SceneTests.swift:222`
     - `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift:142`
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:251`
   - **What’s wrong:**
     The new Galaxy 3 tests cover boss spawning, scroll lock, and projectile-based shield behavior, but they do not cover `Galaxy3Scene.processLaserHitscan` at all.
   - **Why it matters:**
     That gap is exactly why the shield/barrier Phase Laser bug can slip through while all tests still pass.
   - **Suggested fix:**
     Add Galaxy 3 tests for:
     - Phase Laser blocked by barriers
     - Phase Laser blocked during Zenith shield windows
     - fortress nodes ignoring damage while shielded
     - rotating-gate collision behavior changing over time

### Minor

7. **Barrier sprites appear to be rendered twice**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:175`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:526`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:962`
   - **What’s wrong:**
     Barriers are registered into `renderSystem` through `registerEntity`, then also appended manually in `collectSprites`.
   - **Why it matters:**
     This can produce duplicate draws and subtle visual artifacts.
   - **Suggested fix:**
     Render barriers through exactly one path: either manual sprite collection or `renderSystem`, not both.

8. **`bossIntro` does not really persist as a scene state**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:974`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1009`
   - **What’s wrong:**
     `triggerBoss()` sets `stageState = .bossIntro`, but `registerBoss()` immediately flips it to `.bossActive` in the same flow.
   - **Why it matters:**
     The dedicated intro hook is effectively unavailable for scene logic or tests.
   - **Suggested fix:**
     Keep the scene in `.bossIntro` until the boss exits its intro phase, then switch to `.bossActive`.

## Overall assessment

**Verdict:** Not ready to sign off as complete against the plan yet.

The foundation is good: progression plumbing, shared weapon/collision changes, app-shell registration, and general stage decomposition are all in decent shape. But the implementation still has meaningful gameplay gaps in the Galaxy 3-specific mechanics, especially around Phase Laser blocking, fortress shielding, and corridor/gate behavior. Those should be fixed before considering this review clean.
