# Galaxy 3 re-re-review (`2fb24c5a92d541f722a0f4bc06cd675c538b04ba..HEAD`)

Date: 2026-04-09  
Reviewer: fresh `reviewer` subagent on `openai/gpt-5.4`, with follow-up manual validation in the worktree  
Guideline: `.pi/plans/2026-04-07-create-galaxy-3-the-zenith-armada-grid.md`  
Prior reviews for comparison:
- `.pi/reviews/2026-04-09-galaxy3-2fb24c5a-to-HEAD-review.md`
- `.pi/reviews/2026-04-09-galaxy3-2fb24c5a-to-HEAD-rereview.md`

## Scope

Fresh re-re-review of the Galaxy 3 implementation from `2fb24c5a92d541f722a0f4bc06cd675c538b04ba` to `HEAD`, using the plan as the primary rubric and the prior reviews only as historical context.

Focus areas:
- Galaxy 2 → Galaxy 3 → Victory progression
- Galaxy 3 stage mechanics and boss behavior
- verification of fixes claimed since the prior re-review
- remaining correctness and coverage gaps

## Verification performed

- Ran `swift test --package-path Engine2043`
  - Result: **pass** (`486 tests`, `31 suites`)
- Ran `xcodebuild -project Project2043.xcodeproj -scheme Project2043-macOS build`
  - Result: **BUILD SUCCEEDED**

I also manually spot-checked the current implementation against the new review’s key claims, especially around:
- Zenith shield collider behavior while visually hidden
- player-contact damage behavior for Zenith / fortress content
- Lightning Arc damage application versus Galaxy 3 shielding rules
- whether the new tests actually assert what their names claim

## Strengths

- **Progression plumbing is in place.** Galaxy 2 now hands off to Galaxy 3 through `SceneTransition`, `SceneManager`, and both app shells, and the macOS target builds successfully.
- **The Galaxy 3 code is still decomposed sensibly.** Splitting work across `Galaxy3Scene`, `Galaxy3EncounterDirector`, `Galaxy3EntityFactory`, `Galaxy3EnvironmentSystem`, and `BossSystem` matches the plan well.
- **Low-level compatibility work remains solid.** The barrier layer, projectile fallback behavior, and temporary secondary-disable state integrate cleanly with the existing engine and test suite.
- **Verification baseline is healthy.** Both package tests and the macOS app build succeed.

## Resolved since prior re-review

1. **Fortress shield propagation ordering is fixed**
   - Shield-down propagation now happens after the frame’s damage systems and before removals, which addresses the earlier “generator dies but siblings stay shielded” problem.

2. **Tracking drones now actually track**
   - They use `.tracking` steering instead of only moving downward.

3. **Zenith radial bursts now use their own cadence**
   - They no longer piggyback on the grid timer.

4. **Boss trigger cleanup improved**
   - Remaining barriers are cleared and lane bounds reset when the boss fight begins.

5. **The earlier instant one-shot collision bug is partially fixed**
   - Player contact no longer deletes Zenith / fortress entities outright, although the replacement behavior still bypasses defenses in ways noted below.

6. **Previously fixed items remain fixed**
   - Phase Laser blocker handling is in place.
   - Barrier double-rendering is gone.
   - `bossIntro` now persists through the intro descent.

## Findings

### Critical

1. **Invisible Zenith shield colliders remain active in phases 1–2, so normal bullet weapons are blocked before shield windows even start**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1003`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EntityFactory.swift:240`
     - `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift:368`
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:71`
   - **What’s wrong:**
     The four shield entities are registered as active `.bossShield` colliders as soon as the boss spawns. “Shield off” currently only hides their render components; it does not disable their collision participation.
   - **Why it matters:**
     Standard projectile weapons can be deflected by invisible colliders during phases 1–2, making the early Zenith fight much more restrictive than intended and unintentionally favoring `phaseLaser`.
   - **Suggested fix:**
     Tie shield collision enablement to actual shield state, not just visibility. For example:
     - disable the shields’ collision layer/mask while `isShieldActive == false`, or
     - register/unregister shield entities from collision handling with shield windows.
     Add a regression test proving Double Cannon projectiles can damage the Zenith core during phase 1/2.

2. **Player-contact damage still bypasses boss defense mechanics, including Galaxy 3 shield windows and Galaxy 2 armor gating**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:213`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EntityFactory.swift:195`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift:1082`
   - **What’s wrong:**
     The current “bosses survive contact” fix applies `GameConfig.Player.collisionDamage` directly to boss-like enemies on player contact, without consulting their active defenses.
   - **Why it matters:**
     This creates two real problems:
     - **Galaxy 3:** the player can ram the Zenith core during shield windows and still deal damage.
     - **Galaxy 2:** the player can ram the Lithic Harvester core and bypass armor-gated damage expectations.
   - **Suggested fix:**
     Split boss-contact logic from generic enemy-contact logic. Boss contact should damage / bounce the player, but only damage the boss if that boss’s current defense state allows it. Add explicit collision tests for shielded Zenith contact and Lithic Harvester contact.

### Important

3. **Lightning Arc bypasses Galaxy 3 shield logic entirely**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/ECS/Systems/LightningArcSystem.swift:82`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:387`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:951`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1000`
   - **What’s wrong:**
     `LightningArcSystem` targets any registered enemy in range, and Galaxy 3 applies its pending damage directly with no Zenith shield or fortress-shield checks.
   - **Why it matters:**
     Lightning Arc can still damage shielded fortress nodes and the Zenith core during shield windows, recreating the same class of bug already fixed for Phase Laser.
   - **Suggested fix:**
     Centralize player-damage eligibility behind one helper used by projectile, hitscan, collision, and arc paths. At minimum, reject Lightning Arc damage for:
     - `ZenithBossComponent.isShieldActive == true`
     - shielded non-generator `FortressNodeComponent`s
     Add regression tests for arc-vs-shielded-fortress and arc-vs-shielded-Zenith.

4. **The barrier system still undershoots the planned corridor-traversal feel**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:960`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EnvironmentSystem.swift:63`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:366`
   - **What’s wrong:**
     Each `barrierLayout` still spawns just one left wall and one right wall, and lane bounds are computed from all active barriers globally rather than from a local corridor segment the player is traversing.
   - **Why it matters:**
     The result feels more like broad pinch-point clamping than actual corridor traversal, which still falls short of the plan’s “restricted-but-reasonable corridor traversal” goal.
   - **Suggested fix:**
     Spawn multi-segment barrier layouts over distance, and compute lane bounds only from barriers intersecting the player’s current Y band (or a tight lookahead band) so restrictions feel local and traversed.

5. **Most non-boss Galaxy 3 hostile shots still ignore `ProjectileComponent`; turret damage is effectively dead data**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1067`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1295`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:891`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:941`
   - **What’s wrong:**
     Fighters and fortress turrets still spawn legacy hostile projectiles without `ProjectileComponent`, and the `damage` parameter passed into `spawnEnemyProjectile(...)` is unused.
   - **Why it matters:**
     The plan specifically introduced projectile metadata so Galaxy 3 hostile shots could carry differentiated damage/effects while Galaxy 1/2 kept the 5-damage fallback. That still is not true for most non-boss Galaxy 3 shots.
   - **Suggested fix:**
     Make `spawnEnemyProjectile(...)` attach `ProjectileComponent(damage: damage, ...)` for Galaxy 3 hostile shots, and add tests proving turret/fighter damage comes from metadata rather than the fallback path.

6. **Some tests still overstate coverage and miss real scene behavior**
   - **Refs:**
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:549`
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:672`
     - `Engine2043/Tests/Engine2043Tests/Galaxy3SceneTests.swift:636`
   - **What’s wrong:**
     Several tests are named as if they verify full behavior, but they do not actually assert it:
     - `bossDefeatTransitionsToGalaxy3` does not verify a Galaxy 3 transition.
     - `galaxy2ToGalaxy3FlowWithoutAppShell` stops before asserting Victory behavior.
     - `triggerBossClearsBarriersAndLaneBounds` only checks that the boss spawned, not that barriers were cleared or lane bounds reset.
   - **Why it matters:**
     These names imply stronger guarantees than the tests actually provide, which can hide real gameplay regressions.
   - **Suggested fix:**
     Either rename these tests to match what they truly cover, or extend them to assert the claimed behavior. Add regression tests for:
     - phase-1 / phase-2 Zenith taking normal projectile damage
     - shielded Zenith rejecting contact damage
     - Lightning Arc respecting shield windows
     - boss-trigger barrier/lane reset

### Minor

7. **The “megastructure presentation” part of the plan is still mostly a stub**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3EnvironmentSystem.swift:10`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:517`
   - **What’s wrong:**
     `Galaxy3EnvironmentSystem` exposes `platingEntities`, and `Galaxy3Scene.collectSprites` renders them, but nothing currently populates that array.
   - **Why it matters:**
     Galaxy 3 still reads mostly as starfield + enemies + barriers rather than the planned megastructure / trench environment.
   - **Suggested fix:**
     Have `Galaxy3EnvironmentSystem` spawn and recycle decorative plating / hull-strip entities as scroll distance advances, then add light tests around those assets.

## Overall assessment

**Verdict:** materially improved again, but still not ready for final sign-off.

The implementation is clearly better than in the prior two reviews, and several previously blocking issues are now genuinely fixed. However, the remaining bugs are concentrated in the most important gameplay layer: Zenith’s defenses are still not authoritative across all damage paths, and some of the Galaxy 3-specific stage semantics remain thinner than the plan describes. Once those are fixed — and the tests are tightened to match their names and cover the real behavior — this should be much closer to review-complete.
