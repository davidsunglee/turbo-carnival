# Galaxy 3 follow-up review (`2fb24c5a92d541f722a0f4bc06cd675c538b04ba..HEAD`)

Date: 2026-04-09  
Reviewer: fresh `reviewer` subagent on `openai/gpt-5.4`, with follow-up manual validation in the worktree  
Guideline: `.pi/plans/2026-04-07-create-galaxy-3-the-zenith-armada-grid.md`  
Prior reviews for context only:
- `.pi/reviews/2026-04-09-galaxy3-2fb24c5a-to-HEAD-review.md`
- `.pi/reviews/2026-04-09-galaxy3-2fb24c5a-to-HEAD-rereview.md`
- `.pi/reviews/2026-04-09-galaxy3-2fb24c5a-to-HEAD-rerereview.md`

## Scope

Fresh follow-up review of the Galaxy 3 implementation from `2fb24c5a92d541f722a0f4bc06cd675c538b04ba` to `HEAD`, using the plan as the primary rubric and the prior reviews only as historical context.

Focus areas:
- Galaxy 2 → Galaxy 3 → Victory progression
- Galaxy 3 stage mechanics and boss behavior
- verification of fixes claimed since the prior review
- remaining correctness and coverage gaps

## Verification performed

- Ran `swift test --package-path Engine2043`
  - Result: **pass** (`494 tests`, `31 suites`)
- Ran `xcodebuild -project Project2043.xcodeproj -scheme Project2043-macOS build`
  - Result: **BUILD SUCCEEDED**

I also manually validated the most important current findings in the worktree, especially around:
- collision-state mutation vs `CollisionSystem` behavior
- player projectile damage semantics
- test names versus the assertions they actually perform

## Strengths

- **The Galaxy 3 decomposition still matches the plan well.** `Galaxy3Scene`, `Galaxy3EncounterDirector`, `Galaxy3EntityFactory`, `Galaxy3EnvironmentSystem`, and `BossSystem` remain split along sensible boundaries.
- **Progression plumbing is in place end-to-end.** Galaxy 2 now hands off through `.toGalaxy3`, `SceneManager` understands the transition, and both app shells register Galaxy 3.
- **Several previously weak Galaxy 3 combat paths are materially better.** Fortress shield-down propagation now happens after damage and before removals, player-contact no longer one-shots Zenith / fortress nodes, Lightning Arc now checks Zenith and fortress shield state, and boss-trigger cleanup clears leftover barriers and lane bounds.
- **Verification baseline is good.** Both the SwiftPM suite and the macOS app build succeed.

## Resolved since prior review

1. **Fortress generator destruction now properly unshields sibling nodes in frame order**
   - The post-damage `propagateFortressShieldDown()` flow in `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift` fixes the earlier “dead generator removed before shield propagation” bug.

2. **Boss-trigger arena cleanup is now implemented**
   - `triggerBoss()` clears barriers and resets lane bounds before the arena starts, fixing the earlier stale-corridor carryover problem.

3. **Lightning Arc now respects Galaxy 3 shield rules at the scene logic layer**
   - The scene now rejects Lightning Arc damage against active Zenith shields and shielded non-generator fortress nodes.

4. **Player-contact defense bypasses for Zenith / fortress content were improved**
   - `CollisionResponseHandler` no longer uses the old instant-kill behavior for these entities and now checks more boss / fortress state before applying contact damage.

5. **Megastructure presentation is no longer a complete stub**
   - `Galaxy3EnvironmentSystem` now actually spawns decorative plating entities instead of exposing an always-empty array.

## Findings

### Critical

1. **Runtime collision-state changes do not actually take effect in live gameplay because `CollisionSystem` snapshots physics data at registration**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/ECS/Systems/CollisionSystem.swift:90`
     - `Engine2043/Sources/Engine2043/ECS/Systems/CollisionSystem.swift:124`
     - `Engine2043/Sources/Engine2043/ECS/Systems/BossSystem.swift:376`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1003`
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1435`
     - `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift:675`
     - `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift:701`
   - **What’s wrong:**
     `BossSystem` and `Galaxy3Scene` mutate `PhysicsComponent.collisionLayer`, `collisionMask`, and `collisionSize` at runtime, but `CollisionSystem` only snapshots those values once in `register(_:)` and then only resyncs positions.
   - **Why it matters:**
     This means the headline runtime-collision fixes are not actually reliable in live play:
     - invisible Zenith shields can still behave as active colliders even when their `PhysicsComponent` was cleared after registration
     - rotating gates still collide at their original size even though `collisionSize` is being animated
     - the related tests currently validate component state, not the real collision-system path
   - **Suggested fix:**
     Make `CollisionSystem` resync `collisionSize`, `collisionLayer`, and `collisionMask` from each entity’s current `PhysicsComponent` during `update(time:)`, or explicitly unregister/re-register entities when those values change. Add integration tests that exercise the real `CollisionSystem` + `CollisionResponseHandler` path for:
     - phase-1 / phase-2 Zenith bullet hits with shields inactive
     - shield-window bullet deflection with shields active
     - rotating-gate open/close collision behavior

### Important

2. **Player projectile damage is still effectively hard-coded to base damage, so weapon-specific damage restoration is not wired into real combat**
   - **Refs:**
     - `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:1048`
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:160`
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:182`
     - `Engine2043/Sources/Engine2043/Scene/CollisionResponseHandler.swift:197`
     - `Engine2043/Sources/Engine2043/ECS/Systems/WeaponSystem.swift:1`
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:563`
     - `Engine2043/Tests/Engine2043Tests/Galaxy3SceneTests.swift:133`
   - **What’s wrong:**
     `WeaponSystem` emits `ProjectileSpawnRequest.damage`, and carryover tests assert that weapon damage was restored, but spawned player projectiles do not carry that damage into collision handling. `CollisionResponseHandler` still applies `GameConfig.Player.damage` directly for enemy / armor / asteroid hits.
   - **Why it matters:**
     In practice:
     - `triSpread` does not use its intended projectile damage
     - carryover “damage restored” checks are largely cosmetic rather than behavioral
     - future projectile-specific tuning will be ignored
   - **Suggested fix:**
     Attach damage metadata to player projectiles at spawn time, ideally via `ProjectileComponent(damage: request.damage, ...)` or a dedicated player-projectile component, and read that in `CollisionResponseHandler` with a legacy fallback only when metadata is absent. Add tests comparing actual damage dealt by different player projectile weapons against the same target.

### Minor

3. **Some tests still overstate what they verify**
   - **Refs:**
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:549`
     - `Engine2043/Tests/Engine2043Tests/Galaxy2SceneTests.swift:563`
     - `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift:675`
     - `Engine2043/Tests/Engine2043Tests/ZenithCoreSentinelTests.swift:701`
   - **What’s wrong:**
     A few test names imply stronger behavior than they actually assert. For example:
     - `bossDefeatStartsBossDyingAnimation` does not drive boss defeat; it only checks the scene is still playing
     - `bossDefeatTransitionHasCorrectCarryoverFields` manually reconstructs carryover instead of proving the Galaxy 2 boss-death path emits it
     - some Zenith shield-collision tests inspect `PhysicsComponent` state rather than the live `CollisionSystem` path
   - **Why it matters:**
     This is exactly how the remaining real-behavior bugs slipped through while the suite kept growing.
   - **Suggested fix:**
     Rename these tests to match what they currently verify, or replace them with stronger scene/integration tests that exercise actual boss defeat, transition requests, and collision-system-driven shield behavior.

## Overall assessment

**Verdict:** strong progress, but still not ready for final sign-off.

This implementation is materially better than in the earlier review rounds, and several prior blockers are genuinely resolved. However, two important gaps remain:
- runtime collision-state changes are not trustworthy while `CollisionSystem` treats physics data as immutable after registration
- player projectile damage restoration is still not wired into actual collision damage

Once those are fixed — and the tests are tightened to validate the real runtime paths rather than component state alone — this should be much closer to review-complete.
