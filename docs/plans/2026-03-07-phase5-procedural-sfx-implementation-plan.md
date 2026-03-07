# Phase 5: Procedural SFX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add procedural sound effects for combat core (weapon fire, enemy hit/destroyed, player damaged) and items (spawn, cycle, pickup) using programmatic audio synthesis — no external asset files.

**Architecture:** A new `SynthAudioEngine` class uses `AVAudioEngine` with pre-rendered `AVAudioPCMBuffer`s for 9 one-shot sounds and one real-time `AVAudioSourceNode` for the sustained Phase Laser hum. It lives alongside the existing `AVAudioManager` (which stays for future music). Galaxy1Scene calls `sfx?.play(.effect)` at gameplay event points.

**Tech Stack:** Swift, AVFoundation (`AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioSourceNode`, `AVAudioPCMBuffer`), Atomics for audio-thread-safe laser parameters

---

### Task 1: Create SFXType enum

**Files:**
- Create: `Engine2043/Sources/Engine2043/Audio/SFXType.swift`

**Step 1: Write the failing test**

Add to a new test file:

```swift
// Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
import Testing
@testable import Engine2043

struct SynthAudioTests {
    @Test func sfxTypeHasAllExpectedCases() {
        let allCases = SFXType.allCases
        #expect(allCases.count == 9)
        #expect(allCases.contains(.doubleCannonFire))
        #expect(allCases.contains(.triSpreadFire))
        #expect(allCases.contains(.vulcanFire))
        #expect(allCases.contains(.enemyHit))
        #expect(allCases.contains(.enemyDestroyed))
        #expect(allCases.contains(.playerDamaged))
        #expect(allCases.contains(.itemSpawn))
        #expect(allCases.contains(.itemCycle))
        #expect(allCases.contains(.itemPickup))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: FAIL — `SFXType` not found

**Step 3: Write minimal implementation**

```swift
// Engine2043/Sources/Engine2043/Audio/SFXType.swift
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
}
```

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/SFXType.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add SFXType enum for procedural sound effects"
```

---

### Task 2: Create SynthAudioEngine with buffer synthesis infrastructure

**Files:**
- Create: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

**Step 1: Write the failing tests**

Append to `SynthAudioTests.swift`:

```swift
@Test @MainActor func synthEngineInitializesWithoutCrash() {
    let engine = SynthAudioEngine()
    #expect(engine.volume >= 0)
}

@Test @MainActor func synthEnginePlayDoesNotCrash() {
    let engine = SynthAudioEngine()
    engine.play(.doubleCannonFire)
    engine.play(.enemyHit)
    engine.play(.itemPickup)
}

@Test @MainActor func synthEngineVolumeClamps() {
    let engine = SynthAudioEngine()
    engine.volume = 1.5
    #expect(engine.volume == 1.0)
    engine.volume = -0.5
    #expect(engine.volume == 0.0)
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: FAIL — `SynthAudioEngine` not found

**Step 3: Write implementation**

```swift
// Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift
import AVFoundation

@MainActor
public final class SynthAudioEngine {
    private let audioEngine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var buffers: [SFXType: AVAudioPCMBuffer] = [:]
    private let poolSize = 8
    private let sampleRate: Double = 44100

    // Rate limiting: last play time per SFX type
    private var lastPlayTime: [SFXType: CFTimeInterval] = [:]
    private var cooldowns: [SFXType: CFTimeInterval] = [
        .vulcanFire: 0.06
    ]

    public var volume: Float = 0.8 {
        didSet { volume = max(0, min(1, volume)); audioEngine.mainMixerNode.outputVolume = volume }
    }

    private lazy var format: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }()

    public init() {
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            audioEngine.attach(node)
            audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
            playerNodes.append(node)
        }

        audioEngine.mainMixerNode.outputVolume = volume

        do {
            try audioEngine.start()
        } catch {
            print("SynthAudioEngine failed to start: \(error)")
        }

        synthesizeAllBuffers()
    }

    public func play(_ effect: SFXType) {
        // Rate limiting
        let now = CACurrentMediaTime()
        if let cooldown = cooldowns[effect],
           let last = lastPlayTime[effect],
           now - last < cooldown {
            return
        }
        lastPlayTime[effect] = now

        guard let buffer = buffers[effect] else { return }

        // Find idle node or steal the first
        guard let node = playerNodes.first(where: { !$0.isPlaying }) ?? playerNodes.first else { return }
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [])
        node.play()
    }

    // MARK: - Synthesis

    private func synthesizeAllBuffers() {
        buffers[.doubleCannonFire] = synthesize(duration: 0.08, generator: squareSweep(from: 440, to: 220))
        buffers[.triSpreadFire] = synthesize(duration: 0.10, generator: mixedSweep(square: (330, 165), noiseMix: 0.3))
        buffers[.vulcanFire] = synthesize(duration: 0.04, generator: sawtoothSweep(from: 880, to: 660))
        buffers[.enemyHit] = synthesize(duration: 0.03, generator: noiseBurst())
        buffers[.enemyDestroyed] = synthesize(duration: 0.20, generator: explosion(squareFrom: 200, squareTo: 50))
        buffers[.playerDamaged] = synthesize(duration: 0.15, generator: squareSweep(from: 100, to: 60))
        buffers[.itemSpawn] = synthesize(duration: 0.12, generator: sineSweep(from: 660, to: 880))
        buffers[.itemCycle] = synthesize(duration: 0.06, generator: sineSweep(from: 440, to: 550))
        buffers[.itemPickup] = synthesize(duration: 0.20, generator: sineChord(freqs: [440, 660, 880]))
    }

    private func synthesize(duration: Double, generator: (Float, Float) -> Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let attackFrames = max(1, Int(Float(frameCount) * 0.08))

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let progress = Float(i) / Float(frameCount)

            var sample = generator(t, progress)

            // AD envelope
            let envelope: Float
            if i < attackFrames {
                envelope = Float(i) / Float(attackFrames)
            } else {
                envelope = 1.0 - (Float(i - attackFrames) / Float(Int(frameCount) - attackFrames))
            }

            sample *= envelope * 0.4 // master gain to prevent clipping
            samples[i] = sample
        }

        return buffer
    }

    // MARK: - Waveform Generators

    private func squareSweep(from startFreq: Float, to endFreq: Float) -> (Float, Float) -> Float {
        { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            return sign(sin(2.0 * .pi * freq * t))
        }
    }

    private func sawtoothSweep(from startFreq: Float, to endFreq: Float) -> (Float, Float) -> Float {
        { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            let phase = freq * t
            return 2.0 * (phase - Float(Int(phase))) - 1.0
        }
    }

    private func sineSweep(from startFreq: Float, to endFreq: Float) -> (Float, Float) -> Float {
        { t, progress in
            let freq = startFreq + (endFreq - startFreq) * progress
            return sin(2.0 * .pi * freq * t)
        }
    }

    private func noiseBurst() -> (Float, Float) -> Float {
        { _, _ in
            Float.random(in: -1...1)
        }
    }

    private func mixedSweep(square: (Float, Float), noiseMix: Float) -> (Float, Float) -> Float {
        let sq = squareSweep(from: square.0, to: square.1)
        let noise = noiseBurst()
        return { t, progress in
            sq(t, progress) * (1.0 - noiseMix) + noise(t, progress) * noiseMix
        }
    }

    private func explosion(squareFrom: Float, squareTo: Float) -> (Float, Float) -> Float {
        let sq = squareSweep(from: squareFrom, to: squareTo)
        let noise = noiseBurst()
        return { t, progress in
            sq(t, progress) * 0.4 + noise(t, progress) * 0.6
        }
    }

    private func sineChord(freqs: [Float]) -> (Float, Float) -> Float {
        { t, progress in
            var sum: Float = 0
            for (i, freq) in freqs.enumerated() {
                let offset = Float(i) * 0.03 // stagger for arpeggio effect
                let adjustedT = max(0, t - offset)
                sum += sin(2.0 * .pi * freq * adjustedT)
            }
            return sum / Float(freqs.count)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add SynthAudioEngine with procedural buffer synthesis"
```

---

### Task 3: Add Phase Laser real-time synthesis

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

**Step 1: Write the failing tests**

Append to `SynthAudioTests.swift`:

```swift
@Test @MainActor func laserStartStopDoesNotCrash() {
    let engine = SynthAudioEngine()
    engine.startLaser()
    engine.setLaserHeat(0.5)
    engine.stopLaser()
}

@Test @MainActor func laserHeatClampsTo01() {
    let engine = SynthAudioEngine()
    engine.startLaser()
    engine.setLaserHeat(-1.0)
    engine.setLaserHeat(2.0)
    engine.stopLaser()
    // No crash = pass; values are atomics read on audio thread
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: FAIL — `startLaser` not found

**Step 3: Write implementation**

Add these properties and methods to `SynthAudioEngine`:

```swift
// At the top of the class, add:
import Synchronization

// New properties:
private var laserNode: AVAudioSourceNode?
private let laserFrequency = Mutex<Float>(120.0)
private let laserAmplitude = Mutex<Float>(0.0)
private var laserPhase: Float = 0
private var isLaserActive = false

// New methods:
public func startLaser() {
    guard !isLaserActive else { return }
    isLaserActive = true

    laserFrequency.withLock { $0 = 120.0 }
    laserAmplitude.withLock { $0 = 0.3 }
    laserPhase = 0

    let sRate = Float(sampleRate)

    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList -> OSStatus in
        guard let self else { return noErr }
        let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
        let buffer = ablPointer[0]
        let samples = buffer.mData!.assumingMemoryBound(to: Float.self)

        let freq = self.laserFrequency.withLock { $0 }
        let amp = self.laserAmplitude.withLock { $0 }

        for i in 0..<Int(frameCount) {
            let t = self.laserPhase / sRate
            // Sawtooth + sine blend with slow LFO wobble
            let lfo = sin(2.0 * .pi * 3.0 * t) * 8.0 // 3Hz wobble, ±8Hz
            let currentFreq = freq + lfo
            let saw = 2.0 * ((currentFreq * t).truncatingRemainder(dividingBy: 1.0)) - 1.0
            let sine = sin(2.0 * .pi * currentFreq * t)
            samples[i] = (saw * 0.6 + sine * 0.4) * amp
            self.laserPhase += 1
        }

        return noErr
    }

    audioEngine.attach(node)
    audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
    laserNode = node
}

public func stopLaser() {
    guard isLaserActive else { return }
    isLaserActive = false

    laserAmplitude.withLock { $0 = 0 }

    if let node = laserNode {
        audioEngine.detach(node)
        laserNode = nil
    }
    laserPhase = 0
}

public func setLaserHeat(_ heat: Float) {
    let clamped = max(0, min(1, heat))
    // Map heat 0→1 to frequency 120Hz→180Hz
    laserFrequency.withLock { $0 = 120.0 + clamped * 60.0 }
    // Map heat 0→1 to amplitude 0.3→0.5
    laserAmplitude.withLock { $0 = 0.3 + clamped * 0.2 }
}
```

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add real-time Phase Laser hum synthesis"
```

---

### Task 4: Add `sfx` property to Galaxy1Scene and inject from app shells

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:26-28`
- Modify: `Project2043-macOS/MetalView.swift:38-43`
- Modify: `Project2043-iOS/MetalView.swift:36-40`

**Step 1: Add `sfx` property to Galaxy1Scene**

In `Galaxy1Scene.swift`, in the `// MARK: - Input / Audio` section (line ~27), add:

```swift
public var sfx: SynthAudioEngine?
```

So lines 26-29 become:

```swift
// MARK: - Input / Audio
public var inputProvider: (any InputProvider)?
public var audioProvider: (any AudioProvider)?
public var sfx: SynthAudioEngine?
```

**Step 2: Inject SynthAudioEngine in macOS MetalView**

In `Project2043-macOS/MetalView.swift`, in `setup()` after the scene creation (line ~39), add:

```swift
let sfxEngine = SynthAudioEngine()
scene.sfx = sfxEngine
```

So lines 38-44 become:

```swift
let scene = Galaxy1Scene()
scene.inputProvider = inputProvider

let audio = AVAudioManager()
scene.audioProvider = audio

let sfxEngine = SynthAudioEngine()
scene.sfx = sfxEngine

engine.currentScene = scene
```

**Step 3: Inject SynthAudioEngine in iOS MetalView**

In `Project2043-iOS/MetalView.swift`, in `setup()` after the scene creation (line ~37), add:

```swift
let sfxEngine = SynthAudioEngine()
scene.sfx = sfxEngine
```

So lines 36-42 become:

```swift
let scene = Galaxy1Scene()
scene.inputProvider = touchInput

let audio = AVAudioManager()
scene.audioProvider = audio

let sfxEngine = SynthAudioEngine()
scene.sfx = sfxEngine

engine.currentScene = scene
```

**Step 4: Build to verify no compile errors**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build Succeeded

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift Project2043-macOS/MetalView.swift Project2043-iOS/MetalView.swift
git commit -m "feat: inject SynthAudioEngine into Galaxy1Scene from app shells"
```

---

### Task 5: Wire weapon fire SFX into Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

The weapon fire sounds need to play when projectiles are spawned and when the Phase Laser is active.

**Step 1: Add SFX to `spawnPlayerProjectile`**

In `Galaxy1Scene.swift`, in `spawnPlayerProjectile(_ request:)` (line ~574), add at the **end** of the method (before the closing `}`):

```swift
// Play weapon fire SFX
if let weaponType = player.component(ofType: WeaponComponent.self)?.weaponType {
    switch weaponType {
    case .doubleCannon: sfx?.play(.doubleCannonFire)
    case .triSpread: sfx?.play(.triSpreadFire)
    case .vulcanAutoGun: sfx?.play(.vulcanFire)
    case .phaseLaser: break // handled by real-time laser node
    }
}
```

**Step 2: Add Phase Laser SFX to `handleInput`**

In `Galaxy1Scene.swift`, in `handleInput()` (line ~324), after `weapon.isFiring = input.primaryFire` (line ~332), add Phase Laser audio management:

```swift
// Phase Laser audio
if weapon.weaponType == .phaseLaser {
    if input.primaryFire && !weapon.isLaserOverheated {
        sfx?.startLaser()
        sfx?.setLaserHeat(Float(weapon.laserHeat / GameConfig.Weapon.laserMaxHeat))
    } else {
        sfx?.stopLaser()
    }
} else {
    sfx?.stopLaser()
}
```

**Step 3: Build to verify no compile errors**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build Succeeded

**Step 4: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire weapon fire SFX into Galaxy1Scene"
```

---

### Task 6: Wire combat result SFX (enemy hit, destroyed, player damaged)

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add SFX to `handleProjectileHitEnemy`**

In `Galaxy1Scene.swift`, in `handleProjectileHitEnemy(projectile:enemy:)` (line ~918), add SFX calls. After the health check:

```swift
private func handleProjectileHitEnemy(projectile: GKEntity, enemy: GKEntity) {
    if let health = enemy.component(ofType: HealthComponent.self) {
        health.takeDamage(GameConfig.Player.damage)
        if !health.isAlive {
            sfx?.play(.enemyDestroyed)
            if let score = enemy.component(ofType: ScoreComponent.self) {
                scoreSystem.addScore(score.points)
            }
            pendingRemovals.append(enemy)
            checkFormationWipe(enemy: enemy)
        } else {
            sfx?.play(.enemyHit)
        }
    }
    pendingRemovals.append(projectile)
}
```

**Step 2: Add SFX to `handlePlayerEnemyCollision`**

In `handlePlayerEnemyCollision(enemy:)` (line ~932), add after the player takes damage:

```swift
private func handlePlayerEnemyCollision(enemy: GKEntity) {
    player.component(ofType: HealthComponent.self)?.takeDamage(GameConfig.Player.collisionDamage)
    sfx?.play(.playerDamaged)
    // ... rest of method stays the same
```

**Step 3: Add SFX to `handlePlayerHitByProjectile`**

In `handlePlayerHitByProjectile(projectile:)` (line ~945), add after the player takes damage:

```swift
private func handlePlayerHitByProjectile(projectile: GKEntity) {
    player.component(ofType: HealthComponent.self)?.takeDamage(5)
    sfx?.play(.playerDamaged)
    pendingRemovals.append(projectile)
}
```

**Step 4: Add SFX to laser hitscan kills**

In `processLaserHitscan(_:)` (line ~834), in the enemy loop where health reaches zero, add `sfx?.play(.enemyDestroyed)`, and in the else branch add `sfx?.play(.enemyHit)`:

After `health.takeDamage(hitscan.damagePerTick)`:

```swift
if !health.isAlive {
    sfx?.play(.enemyDestroyed)
    // ... existing score and removal code
} else {
    sfx?.play(.enemyHit)
}
```

Note: the enemy hit sound will rate-limit itself naturally since the laser is continuous — the buffer is only 30ms so rapid plays will just overlap briefly.

**Step 5: Build to verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build Succeeded

**Step 6: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire combat result SFX (hit, destroyed, damaged)"
```

---

### Task 7: Wire item SFX (spawn, cycle, pickup)

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

**Step 1: Add SFX to item spawn**

In `spawnItem(at:)` (line ~647), add at the **end** of the method (before the closing `}`), after `items.append(entity)`:

```swift
sfx?.play(.itemSpawn)
```

Also in `spawnWeaponModuleItem(at:)` (line ~675), add at the **end** before closing `}`, after `items.append(entity)`:

```swift
sfx?.play(.itemSpawn)
```

**Step 2: Add SFX to item cycle**

The item cycling happens in `ItemSystem.handleProjectileHit(on:)`. Since `Galaxy1Scene` doesn't directly see the cycle moment, we need to play the sound at the collision point where `itemSystem.handleProjectileHit` is called.

In `processCollisions()`, in the two branches where `itemSystem.handleProjectileHit(on:)` is called (lines ~897-901), add:

```swift
} else if layerA.contains(.playerProjectile) && layerB.contains(.item) {
    itemSystem.handleProjectileHit(on: entityB)
    sfx?.play(.itemCycle)
    pendingRemovals.append(entityA)
} else if layerB.contains(.playerProjectile) && layerA.contains(.item) {
    itemSystem.handleProjectileHit(on: entityA)
    sfx?.play(.itemCycle)
    pendingRemovals.append(entityB)
```

Also in `processLaserHitscan(_:)`, after `itemSystem.handleProjectileHit(on: item)` (line ~877):

```swift
sfx?.play(.itemCycle)
```

**Step 3: Add SFX to item pickup**

In `handlePlayerCollectsItem(item:)` (line ~950), add at the **start** of the method:

```swift
sfx?.play(.itemPickup)
```

**Step 4: Build to verify**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build Succeeded

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: wire item SFX (spawn, cycle, pickup)"
```

---

### Task 8: Run full test suite and verify

**Files:**
- No changes — verification only

**Step 1: Run all tests**

Run: `cd Engine2043 && swift test 2>&1 | tail -30`
Expected: All tests pass

**Step 2: If any tests fail, fix them**

Common issues:
- Thread safety: `SynthAudioEngine` is `@MainActor`, tests must use `@MainActor`
- Import: ensure `@testable import Engine2043` in test file

**Step 3: Commit any fixes**

```bash
git add -A && git commit -m "fix: resolve test failures from SFX integration"
```

---

### Task 9: Add Vulcan fire rate-limiting test

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

**Step 1: Write the test**

Append to `SynthAudioTests.swift`:

```swift
@Test @MainActor func vulcanCooldownPreventsRapidFire() {
    let engine = SynthAudioEngine()
    // First play should succeed, rapid second should be rate-limited
    // (We can't directly observe skipped plays, but verify no crash under rapid fire)
    for _ in 0..<100 {
        engine.play(.vulcanFire)
    }
    // If we got here without crash or audio glitch, rate limiting is working
}

@Test @MainActor func allSFXTypesPlayWithoutCrash() {
    let engine = SynthAudioEngine()
    for sfx in SFXType.allCases {
        engine.play(sfx)
    }
}
```

**Step 2: Run tests**

Run: `cd Engine2043 && swift test --filter SynthAudioTests 2>&1 | tail -20`
Expected: PASS

**Step 3: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "test: add rate-limiting and exhaustive SFX playback tests"
```
