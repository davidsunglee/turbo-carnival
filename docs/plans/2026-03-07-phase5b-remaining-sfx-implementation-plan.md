# Phase 5b: Remaining SFX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 7 procedural sound effects for secondary weapons, boss shield deflection, and game state transitions.

**Architecture:** Extend existing `SFXType` enum with 7 new cases, add buffer generators in `SynthAudioEngine`, wire `sfx?.play()` calls at event sites in `Galaxy1Scene`. No new files or structural changes.

**Tech Stack:** Swift, AVFoundation, GameplayKit

---

### Task 1: Add new SFXType cases and update test

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SFXType.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

**Step 1: Update SFXType enum**

In `SFXType.swift`, add 7 new cases after `itemPickup`:

```swift
public enum SFXType: CaseIterable, Sendable {
    case doubleCannonFire
    case triSpreadFire
    case vulcanFire
    case enemyHit
    case enemyDestroyed
    case playerDamaged
    case itemSpawn
    case itemCycle
    case itemPickup
    case gravBombLaunch
    case gravBombDetonate
    case empSweep
    case overchargeActivate
    case bossShieldDeflect
    case playerDeath
    case victory
}
```

**Step 2: Update the enum completeness test**

In `SynthAudioTests.swift`, update `sfxTypeHasAllExpectedCases()`:

```swift
@Test func sfxTypeHasAllExpectedCases() {
    let allCases = SFXType.allCases
    #expect(allCases.count == 16)
    #expect(allCases.contains(.doubleCannonFire))
    #expect(allCases.contains(.triSpreadFire))
    #expect(allCases.contains(.vulcanFire))
    #expect(allCases.contains(.enemyHit))
    #expect(allCases.contains(.enemyDestroyed))
    #expect(allCases.contains(.playerDamaged))
    #expect(allCases.contains(.itemSpawn))
    #expect(allCases.contains(.itemCycle))
    #expect(allCases.contains(.itemPickup))
    #expect(allCases.contains(.gravBombLaunch))
    #expect(allCases.contains(.gravBombDetonate))
    #expect(allCases.contains(.empSweep))
    #expect(allCases.contains(.overchargeActivate))
    #expect(allCases.contains(.bossShieldDeflect))
    #expect(allCases.contains(.playerDeath))
    #expect(allCases.contains(.victory))
}
```

**Step 3: Run tests**

Run: `swift test --filter SynthAudioTests`

Expected: `sfxTypeHasAllExpectedCases` PASSES (enum has 16 cases). `allSFXTypesPlayWithoutCrash` FAILS — new cases don't have buffers yet, so `play()` returns early on nil buffer (no crash, but the test still passes since play() guards on nil). Actually both tests should pass since `play()` silently returns when buffer is nil. Verify all tests pass.

**Step 4: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/SFXType.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add 7 new SFXType cases for secondary weapons, boss shield, and game state"
```

---

### Task 2: Add buffer generators for secondary weapon SFX

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift`

**Step 1: Add new buffer synthesis calls**

In `synthesizeAllBuffers()` (after line 115), append:

```swift
buffers[.gravBombLaunch] = synthesize(duration: 0.10, generator: sineSweep(from: 300, to: 100))
buffers[.gravBombDetonate] = synthesize(duration: 0.30, generator: explosion(squareFrom: 150, squareTo: 30))
buffers[.empSweep] = synthesize(duration: 0.25, generator: empZap())
buffers[.overchargeActivate] = synthesize(duration: 0.15, generator: sineChord(freqs: [330, 440, 660]))
```

**Step 2: Add the empZap waveform generator**

After the `explosion()` method (~line 191), add:

```swift
private func empZap() -> (Float, Float) -> Float {
    let sweep = sineSweep(from: 200, to: 2000)
    let noise = noiseBurst()
    return { t, progress in
        sweep(t, progress) * 0.6 + noise(t, progress) * 0.4
    }
}
```

**Step 3: Run tests**

Run: `swift test --filter SynthAudioTests`

Expected: All pass. The `allSFXTypesPlayWithoutCrash` test now exercises these 4 new buffers.

**Step 4: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift
git commit -m "feat: add buffer synthesis for grav bomb, EMP sweep, and overcharge SFX"
```

---

### Task 3: Add buffer generators for boss shield and game state SFX

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift`

**Step 1: Add buffer synthesis calls**

In `synthesizeAllBuffers()`, after the lines added in Task 2, append:

```swift
buffers[.bossShieldDeflect] = synthesize(duration: 0.04, generator: squareSweep(from: 1200, to: 1400))
buffers[.playerDeath] = synthesize(duration: 0.50, generator: deathGroan())
buffers[.victory] = synthesize(duration: 0.60, generator: sineChord(freqs: [440, 550, 660, 880]))
```

**Step 2: Add the deathGroan waveform generator**

After the `empZap()` method, add:

```swift
private func deathGroan() -> (Float, Float) -> Float {
    let sq = squareSweep(from: 200, to: 40)
    let noise = noiseBurst()
    return { t, progress in
        sq(t, progress) * 0.5 + noise(t, progress) * 0.5
    }
}
```

**Step 3: Run tests**

Run: `swift test --filter SynthAudioTests`

Expected: All pass. All 16 SFX types now have buffers and play without crash.

**Step 4: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift
git commit -m "feat: add buffer synthesis for boss shield deflect, player death, and victory SFX"
```

---

### Task 4: Wire secondary weapon SFX in Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add sfx calls at secondary weapon event sites**

In `spawnGravBomb()` (line 648), add after `gravBombTimers[ObjectIdentifier(entity)] = 0` (line 667):
```swift
sfx?.play(.gravBombLaunch)
```

In `detonateGravBomb()` (line 788), add at the top of the method after the guard (after line 790):
```swift
sfx?.play(.gravBombDetonate)
```

In `activateEMPSweep()` (line 829), add at the top of the method (after line 829, before the for loop):
```swift
sfx?.play(.empSweep)
```

In `activateOvercharge()` (line 852), add inside the if-let after `weapon.overchargeTimer = ...` (after line 855):
```swift
sfx?.play(.overchargeActivate)
```

**Step 2: Run tests**

Run: `swift test --filter SynthAudioTests`

Expected: All pass (scene wiring doesn't affect unit tests).

**Step 3: Commit**

```
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire secondary weapon SFX (grav bomb, EMP, overcharge)"
```

---

### Task 5: Wire boss shield and game state SFX in Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add boss shield deflect SFX**

In `processCollisions()`, the two boss shield collision branches (lines 921-924) currently just call `pendingRemovals.append(entity)`. Add sfx calls:

Line 922 — after `pendingRemovals.append(entityA)`:
```swift
sfx?.play(.bossShieldDeflect)
```

Line 924 — after `pendingRemovals.append(entityB)`:
```swift
sfx?.play(.bossShieldDeflect)
```

**Step 2: Add game state transition SFX**

At the boss defeat check (~line 183), after `scoreSystem.addScore(GameConfig.Score.boss)` (line 184), add:
```swift
sfx?.play(.victory)
sfx?.stopLaser()
```

At the game over check (~line 243), after `gameState = .gameOver` (line 243), add:
```swift
sfx?.play(.playerDeath)
sfx?.stopLaser()
```

Note: `stopLaser()` ensures the Phase Laser drone stops on death/victory. It's safe to call even if the laser isn't active (guarded internally).

**Step 3: Run tests**

Run: `swift test --filter SynthAudioTests`

Expected: All pass.

**Step 4: Commit**

```
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire boss shield deflect, player death, and victory SFX"
```

---

### Task 6: Add rate limiting for boss shield deflect

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift`

**Step 1: Add cooldown for bossShieldDeflect**

In the `cooldowns` dictionary (line 49-51), add an entry for boss shield deflect to prevent rapid-fire pinging when multiple projectiles hit the shield in quick succession:

```swift
private var cooldowns: [SFXType: CFTimeInterval] = [
    .vulcanFire: 0.06,
    .bossShieldDeflect: 0.08
]
```

**Step 2: Run tests**

Run: `swift test --filter SynthAudioTests`

Expected: All pass.

**Step 3: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift
git commit -m "feat: add rate limiting for boss shield deflect SFX"
```

---

### Task 7: Full test run and final verification

**Step 1: Run full test suite**

Run: `swift test`

Expected: All tests pass across all test targets.

**Step 2: Build for macOS**

Run: `xcodebuild -scheme Project2043-macOS -destination 'platform=macOS' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 3: Verify SFXType count is 16**

Check that `SFXType.allCases.count` matches in the test (16 cases).

**Step 4: Final commit if any cleanup needed, otherwise done**
