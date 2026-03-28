# Codebase Review Report — 2026-03-12

**Project:** Project 2043 (turbo-carnival)
**Type:** iOS/macOS game (Swift 6.0, Metal, GameplayKit)
**Reviewed by:** Security, Performance, and Testing agents (coordinated)

---

## Executive Summary

This codebase is a well-structured single-player game with a custom ECS engine, Metal rendering pipeline, and procedural audio. The project has **no network communication, no third-party dependencies, and no sensitive data storage** — which significantly limits the attack surface.

However, there are notable findings across all three review domains:

| Domain | Critical | High | Medium | Low/Info |
|--------|----------|------|--------|----------|
| **Security** | 1 | 4 | 6 | 9 |
| **Performance** | 0 | 1 | 6 | 5 |
| **Testing** | 4 gaps | 6 gaps | 6 gaps | 8 gaps |

**Top concerns:**
1. Memory safety issues (force unwraps, unsafe pointers) that can crash the app
2. O(n^2) lightning arc algorithm that will degrade with many entities
3. No collision system tests — the foundation of all gameplay
4. ~32% file coverage in tests; critical integration paths untested

---

## PART 1: SECURITY FINDINGS

### Critical

| # | Finding | File | Line |
|---|---------|------|------|
| S1 | **Force unwrap `try!` in Renderer init** — crashes on Metal initialization failure | `Renderer.swift` | init |

### High

| # | Finding | File | Line |
|---|---------|------|------|
| S2 | **Force cast of CAMetalLayer** — unsafe `as!` cast can crash if layer type changes | `MetalView.swift` (iOS & macOS) | layer setup |
| S3 | **Division by zero in TouchInputProvider** — `screenSize` can be `(0,0)` before layout | `TouchInputProvider.swift` | ~97 |
| S4 | **Unsafe memory access in audio buffer** — `assumingMemoryBound` without validation | `SynthAudioEngine.swift`, `MusicState.swift` | buffer access |
| S5 | **Unsafe pointer in sprite pixel extraction** — no integer overflow protection | `SpriteFactory.swift` | `extractPixels` |

### Medium

| # | Finding | File | Description |
|---|---------|------|-------------|
| S6 | Array bounds risk in glyph generation | `BitmapText.swift` | No bounds check on glyph lookup |
| S7 | Unvalidated game results | `Galaxy1Scene.swift` | Score/state not validated (future-proofing) |
| S8 | Integer overflow risk in batch size calc | `SpriteBatcher.swift` | Large sprite counts |
| S9 | NaN risk in viewport math | `ViewportManager.swift` | Edge case aspect ratios |
| S10 | Missing bounds check in touch zones | `TouchInputProvider.swift` | Zero-width screen |
| S11 | Insufficient key code validation | `KeyboardInputProvider.swift` | Arbitrary codes accepted |

### Low / Informational

- S12: Unvalidated audio file loading (Medium if exposed to user input)
- S13: Error details printed to console (`print()` statements)
- S14: `assumingMemoryBound` used in multiple places (necessary for Metal/audio, but should be documented)
- S15: No game state invariant checking
- S16-S20: No network, no crypto, no sensitive data, no third-party deps, default ATS — **all secure by default**

### Security Recommendations (Immediate)

1. Replace `try!` with `try`/`guard` in Renderer initialization
2. Guard `screenSize` against zero before division in TouchInputProvider
3. Replace `as!` CAMetalLayer casts with `guard let ... as?`
4. Add bounds checking around unsafe pointer operations in audio/sprite code

---

## PART 2: PERFORMANCE FINDINGS

### High Impact

| # | Finding | File | Description |
|---|---------|------|-------------|
| P1 | **Lightning Arc O(n^2) chain search** | `LightningArcSystem.swift` | Iterates all entities to find nearest chain target. With 50+ enemies, this is a frame-time bottleneck. **Fix:** Use HashSet for visited tracking, cache distances, or spatial partitioning. |

### Medium Impact

| # | Finding | File | Description |
|---|---------|------|-------------|
| P2 | **Score text regenerated every frame** | HUD rendering | String → sprite array rebuilt per frame even when score hasn't changed. **Fix:** Cache sprite arrays, regenerate only on change. |
| P3 | **Entity unregister uses O(n) array removal** | All ECS systems | `removeAll(where:)` on arrays during entity destruction. **Fix:** Swap-remove pattern or use Sets. |
| P4 | **Formation member filtering iterates all entities** | `FormationSystem.swift` | Filters all entities every frame. **Fix:** Maintain indexed formation groups. |
| P5 | **Laser hitscan duplicated across systems** | `LaserBeamSystem.swift` | Same raycast logic runs in multiple systems. **Fix:** Consolidate into single pass. |
| P6 | **Lightning arc jitter allocation** | `LightningArcSystem.swift` | New arrays allocated per frame for visual jitter. **Fix:** Pre-allocate and reuse buffers. |
| P7 | **No object pooling for projectiles/enemies** | `Galaxy1Scene.swift` | Every projectile/enemy is `GKEntity()` created and destroyed with full system registration. **Fix:** Pool ~100 enemies and ~500 projectiles. |

### Low Impact

| # | Finding | File | Description |
|---|---------|------|-------------|
| P8 | Chromatic aberration = 3 texture samples/pixel | `PostProcess.metal` | Consider disabling on mobile |
| P9 | Audio `synchronize()` on main thread | `SynthAudioEngine.swift` | I/O on render thread |
| P10 | Control overlay recalculated every frame | `MetalView.swift` (iOS) | Recalc only on layout change |
| P11 | Offscreen textures reallocated on resize | `Renderer.swift` | No texture pooling |
| P12 | `Float(elapsedTime)` conversion per entity per frame | `FormationSystem.swift` | Convert once per update |

### Configuration Issues

| # | Finding | File | Description |
|---|---------|------|-------------|
| P13 | **No Swift optimization level set** | `project.yml` | Release builds may default to `-Onone`. Add `SWIFT_OPTIMIZATION_LEVEL: -O` and `SWIFT_COMPILATION_MODE: wholemodule`. |
| P14 | **No frame rate cap on 120Hz displays** | `MetalView.swift` (iOS) | CADisplayLink has no `preferredFramesPerSecond`. Consider capping at 60fps for battery. |
| P15 | **No frame time profiling** | `MetalView.swift` (iOS) | Dropped frames are silent. Add debug frame time logging. |

### Performance Recommendations (Priority Order)

1. Fix lightning arc chain search algorithm (HIGH)
2. Implement swap-remove for entity unregistration (MEDIUM)
3. Cache score HUD text — regenerate only on change (MEDIUM)
4. Add object pooling for projectiles and enemies (MEDIUM)
5. Set `-O` optimization in Release build configuration (MEDIUM, trivial fix)

---

## PART 3: TEST COVERAGE FINDINGS

### Current State

- **Overall coverage:** ~32% of source files, ~60% of critical gameplay logic
- **Test quality:** Strong assertions where tests exist
- **Infrastructure:** No CI/CD, no coverage reports, no end-to-end tests

### Critical Gaps (Must fix before release)

| # | Gap | Impact |
|---|-----|--------|
| T1 | **No collision system tests** | Collision detection is the foundation of ALL combat, pickups, and enemy interactions. One bug breaks the entire game. |
| T2 | **No scene management tests** | Scene transitions (title -> game -> boss -> victory/gameover) are completely untested. Breaks game flow. |
| T3 | **No Galaxy1Scene integration tests** | The main game loop — spawning, combat, scoring, wave progression — has no integration tests. |
| T4 | **No input handling integration tests** | TouchInputProvider.poll() and full touch event flow are untested. Core playability at risk. |

### High Priority Gaps

| # | Gap | What's Missing |
|---|-----|----------------|
| T5 | BitmapText rendering | Text centering, glyph spacing, color, scale |
| T6 | Gravity Bomb system | Gravity well radius, enemy pull-in, detonation damage |
| T7 | EMP Sweep system | Stun/disable duration |
| T8 | Overcharge system | Charge time, damage boost, cooldown |
| T9 | Menu input hit testing | Edge cases, boundary conditions |
| T10 | Renderer integration | Metal pipeline, error handling |

### Medium Priority Gaps

| # | Gap | What's Missing |
|---|-----|----------------|
| T11 | Game state machine transitions | playing -> gameOver -> victory flows |
| T12 | Viewport rapid changes | Device rotation stress testing |
| T13 | Audio event triggers | SFX on fire/hit/death, music transitions |
| T14 | Score formatting/overflow | 8-digit padding, multipliers |
| T15 | Damage edge cases | Overkill, simultaneous sources, shield absorption |
| T16 | Boss defeat -> victory flow | End-to-end boss sequence |

### Test Quality Issues

- **InputTests:** Validate math concepts but never test actual `poll()` results
- **AudioTests:** "No crash" tests pass even if audio is silent
- **Missing negative tests:** No error path coverage (texture allocation failure, missing sprites, corrupted input)
- **No state validation:** Galaxy1Scene tests don't verify HUD; WeaponSystem tests don't check heat/cooldown state

### Test Infrastructure Gaps

- No GitHub Actions / CI pipeline
- No automated test runs on commits
- No code coverage tracking
- No shared test helpers (MockInputProvider duplicated)
- No end-to-end gameplay simulation tests
- No performance/stress tests

### Testing Recommendations (Priority Order)

1. **CollisionSystemTests** (NEW) — 15 tests covering spatial partitioning, pair detection, layer masking
2. **Galaxy1Scene Integration Tests** (EXPAND) — 20+ tests for player-enemy collision, scoring, game over, victory, wave progression
3. **SceneManagerTests** (NEW) — 8 tests for transition state machine, scene switching
4. **TouchInputProviderIntegrationTests** (NEW) — 10 tests for full touch event flow
5. Create shared test helpers/fixtures to reduce duplication

---

## CROSS-CUTTING OBSERVATIONS

### Issues that span multiple domains

| Issue | Security | Performance | Testing |
|-------|----------|-------------|---------|
| **Force unwraps in Renderer** | Crash vulnerability (S1) | — | No error path tests (T10) |
| **Collision system** | — | Potential hotspot with many entities | Zero test coverage (T1) |
| **Entity lifecycle** | — | O(n) unregistration (P3) | No integration tests (T3) |
| **Input handling** | Division by zero (S3) | — | No integration tests (T4) |
| **Lightning arc** | — | O(n^2) algorithm (P1) | Edge cases untested |

### What's done well

- Clean ECS architecture with well-separated systems
- No third-party dependencies — minimal supply chain risk
- No network surface — no remote attack vectors
- Existing tests have strong, meaningful assertions
- Metal rendering pipeline is well-structured
- Procedural audio/music system is creative and functional

---

## ACTION ITEMS SUMMARY

### Immediate (Before next release)

1. Fix `try!` force unwrap in Renderer init (S1)
2. Guard against division by zero in TouchInputProvider (S3)
3. Replace `as!` CAMetalLayer casts (S2)
4. Add CollisionSystem tests (T1)
5. Add Galaxy1Scene integration tests (T3)

### Short-term (Next sprint)

6. Fix lightning arc O(n^2) algorithm (P1)
7. Implement entity unregister swap-remove (P3)
8. Cache score HUD text (P2)
9. Set Release build optimization flags (P13)
10. Add SceneManager and input integration tests (T2, T4)

### Medium-term

11. Implement object pooling for projectiles/enemies (P7)
12. Add CI/CD pipeline with automated tests
13. Add frame time profiling (P15)
14. Build shared test infrastructure
15. Add performance/stress tests

---

*Report generated 2026-03-12 by coordinated agent review team.*
