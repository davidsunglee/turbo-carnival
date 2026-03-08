# Procedural Background Music Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add procedurally synthesized synthwave background music with two tracks (gameplay + boss) and fade transitions to SynthAudioEngine.

**Architecture:** A `MusicState` Sendable class (matching the existing `LaserState` pattern) holds all music parameters behind `Mutex` locks. A single `AVAudioSourceNode` render callback reads from `MusicState` to synthesize four layers (bass, arpeggio, drums, pad) per sample. The main thread controls track selection and fade via public API on `SynthAudioEngine`. `Galaxy1Scene` calls these APIs at game start, boss spawn, boss defeat, and game over/victory.

**Tech Stack:** Swift 6, AVFoundation, Synchronization (Mutex), Swift Testing

---

### Task 1: MusicTrack enum

**Files:**
- Create: `Engine2043/Sources/Engine2043/Audio/MusicTrack.swift`

**Step 1: Create the enum**

```swift
public enum MusicTrack: Sendable {
    case gameplay
    case boss
}
```

**Step 2: Build**

Run: `cd Engine2043 && swift build`
Expected: Build succeeds

**Step 3: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/MusicTrack.swift
git commit -m "feat: add MusicTrack enum"
```

---

### Task 2: MusicState — thread-safe shared state

**Files:**
- Create: `Engine2043/Sources/Engine2043/Audio/MusicState.swift`

This class follows the `LaserState` pattern in `SynthAudioEngine.swift:5-37`. It holds all parameters the audio-thread render callback needs, wrapped in `Mutex` for thread safety.

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`:

```swift
@Test func musicStateDefaultValues() {
    let state = MusicState()
    state.amplitude.withLock { #expect($0 == 0.0) }
    state.track.withLock { #expect($0 == .gameplay) }
    state.samplePosition.withLock { #expect($0 == 0) }
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter musicStateDefaultValues`
Expected: FAIL — `MusicState` not defined

**Step 3: Write MusicState**

Create `Engine2043/Sources/Engine2043/Audio/MusicState.swift`:

```swift
import AVFoundation
import Synchronization

/// Thread-safe shared state for background music, accessible from both main and audio threads.
final class MusicState: Sendable {
    let amplitude = Mutex<Float>(0.0)
    let track = Mutex<MusicTrack>(.gameplay)
    let samplePosition = Mutex<Int>(0)

    /// Creates an AVAudioSourceNode that synthesizes music on the audio thread.
    func makeSourceNode(format: AVAudioFormat, sampleRate: Float) -> AVAudioSourceNode {
        let state = self
        return AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let buffer = ablPointer[0]
            let samples = buffer.mData!.assumingMemoryBound(to: Float.self)

            let amp = state.amplitude.withLock { $0 }
            let currentTrack = state.track.withLock { $0 }

            state.samplePosition.withLock { position in
                for i in 0..<Int(frameCount) {
                    let t = Float(position) / sampleRate
                    let sample = MusicSynthesizer.synthesize(track: currentTrack, time: t, sampleRate: sampleRate)
                    samples[i] = sample * amp
                    position += 1
                }
            }

            return noErr
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter musicStateDefaultValues`
Expected: PASS

**Step 5: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/MusicState.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add MusicState with thread-safe shared state"
```

---

### Task 3: MusicSynthesizer — pure synthesis functions

**Files:**
- Create: `Engine2043/Sources/Engine2043/Audio/MusicSynthesizer.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

This is a pure enum with static functions — no state, easy to test. The render callback in `MusicState` calls `MusicSynthesizer.synthesize()`.

**Step 1: Write failing tests**

Add to `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`:

```swift
@Test func musicSynthesizerProducesNonSilentOutput() {
    let sampleRate: Float = 44100
    var hasNonZero = false
    for i in 0..<Int(sampleRate) {
        let t = Float(i) / sampleRate
        let sample = MusicSynthesizer.synthesize(track: .gameplay, time: t, sampleRate: sampleRate)
        if abs(sample) > 0.001 { hasNonZero = true; break }
    }
    #expect(hasNonZero, "Gameplay track should produce audible output")
}

@Test func musicSynthesizerBossTrackProducesOutput() {
    let sampleRate: Float = 44100
    var hasNonZero = false
    for i in 0..<Int(sampleRate) {
        let t = Float(i) / sampleRate
        let sample = MusicSynthesizer.synthesize(track: .boss, time: t, sampleRate: sampleRate)
        if abs(sample) > 0.001 { hasNonZero = true; break }
    }
    #expect(hasNonZero, "Boss track should produce audible output")
}

@Test func musicSynthesizerOutputInRange() {
    let sampleRate: Float = 44100
    for i in 0..<Int(sampleRate * 2) {
        let t = Float(i) / sampleRate
        let sample = MusicSynthesizer.synthesize(track: .gameplay, time: t, sampleRate: sampleRate)
        #expect(sample >= -1.5 && sample <= 1.5, "Sample \(sample) at t=\(t) out of range")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter musicSynthesizer`
Expected: FAIL — `MusicSynthesizer` not defined

**Step 3: Write MusicSynthesizer**

Create `Engine2043/Sources/Engine2043/Audio/MusicSynthesizer.swift`:

```swift
import Foundation

/// Pure synthesis functions for procedural background music.
/// Called from the audio thread — must be lock-free and deterministic.
enum MusicSynthesizer {

    // MARK: - Track Definitions

    // Gameplay: C minor, 120 BPM, Cm -> Ab -> Bb -> G
    // Boss: E minor, 120 BPM, Em -> C -> D -> B

    private static let bpm: Float = 120.0
    private static let beatDuration: Float = 60.0 / bpm  // 0.5s

    // Chord root frequencies (Hz)
    // Gameplay: Cm(C3=130.81) Ab(Ab2=103.83) Bb(Bb2=116.54) G(G2=98.00)
    private static let gameplayChords: [(root: Float, third: Float, fifth: Float)] = [
        (130.81, 155.56, 196.00),  // Cm:  C3, Eb3, G3
        (103.83, 130.81, 155.56),  // Ab:  Ab2, C3, Eb3
        (116.54, 146.83, 174.61),  // Bb:  Bb2, D3, F3
        (98.00,  123.47, 146.83),  // G:   G2, B2, D3
    ]

    // Boss: Em(E3=164.81) C(C3=130.81) D(D3=146.83) B(B2=123.47)
    private static let bossChords: [(root: Float, third: Float, fifth: Float)] = [
        (164.81, 196.00, 246.94),  // Em:  E3, G3, B3
        (130.81, 164.81, 196.00),  // C:   C3, E3, G3
        (146.83, 185.00, 220.00),  // D:   D3, F#3, A3
        (123.47, 155.56, 185.00),  // B:   B2, D#3, F#3
    ]

    // MARK: - Main Entry Point

    static func synthesize(track: MusicTrack, time: Float, sampleRate: Float) -> Float {
        let chords: [(root: Float, third: Float, fifth: Float)]
        switch track {
        case .gameplay: chords = gameplayChords
        case .boss:     chords = bossChords
        }

        // Each chord lasts 4 beats (2 seconds at 120 BPM), 4 chords = 8 seconds loop
        let loopDuration = beatDuration * 16.0  // 4 chords x 4 beats
        let loopTime = time.truncatingRemainder(dividingBy: loopDuration)
        let chordIndex = Int(loopTime / (beatDuration * 4.0)) % chords.count
        let chord = chords[chordIndex]

        // Beat position within the loop
        let beatInLoop = loopTime / beatDuration
        let beatFraction = beatInLoop.truncatingRemainder(dividingBy: 1.0)

        let bass = synthBass(root: chord.root, time: time, beatFraction: beatFraction, track: track)
        let arp = synthArpeggio(chord: chord, time: time, beatInLoop: beatInLoop, track: track)
        let drums = synthDrums(beatInLoop: beatInLoop, beatFraction: beatFraction, track: track, sampleRate: sampleRate)
        let pad = synthPad(chord: chord, time: time)

        // Mix levels — keep total under ~0.4 to leave headroom
        let mix: Float
        switch track {
        case .gameplay:
            mix = bass * 0.12 + arp * 0.08 + drums * 0.10 + pad * 0.05
        case .boss:
            mix = bass * 0.14 + arp * 0.09 + drums * 0.12 + pad * 0.04
        }

        return mix
    }

    // MARK: - Bass Layer

    private static func synthBass(root: Float, time: Float, beatFraction: Float, track: MusicTrack) -> Float {
        let freq = root * 0.5  // One octave down
        let saw = 2.0 * ((freq * time).truncatingRemainder(dividingBy: 1.0)) - 1.0
        let square = sign(sin(2.0 * .pi * freq * time))
        let wave: Float
        switch track {
        case .gameplay:
            wave = saw * 0.6 + square * 0.4
        case .boss:
            // Distorted: clip the sawtooth
            let clipped = max(-0.7, min(0.7, saw * 1.5))
            wave = clipped * 0.7 + square * 0.3
        }
        // Eighth-note envelope (gate on each eighth)
        let eighthFrac = (beatFraction * 2.0).truncatingRemainder(dividingBy: 1.0)
        let envelope = max(0, 1.0 - eighthFrac * 1.5)
        return wave * envelope
    }

    // MARK: - Arpeggio Layer

    private static func synthArpeggio(chord: (root: Float, third: Float, fifth: Float), time: Float, beatInLoop: Float, track: MusicTrack) -> Float {
        // Cycle through chord tones as sixteenth notes
        let sixteenthIndex = Int(beatInLoop * 4.0) % 4
        let tones = [chord.root * 2, chord.third * 2, chord.fifth * 2, chord.third * 2]  // Up one octave
        let freq = tones[sixteenthIndex]

        let wave: Float
        switch track {
        case .gameplay:
            wave = sin(2.0 * .pi * freq * time)
        case .boss:
            // Pulse wave for more aggressive feel
            let phase = (freq * time).truncatingRemainder(dividingBy: 1.0)
            wave = phase < 0.3 ? 1.0 : -1.0
        }

        // Sixteenth-note envelope
        let sixteenthFrac = (beatInLoop * 4.0).truncatingRemainder(dividingBy: 1.0)
        let envelope = max(0, 1.0 - sixteenthFrac * 2.0)
        return wave * envelope
    }

    // MARK: - Drums Layer

    private static func synthDrums(beatInLoop: Float, beatFraction: Float, track: MusicTrack, sampleRate: Float) -> Float {
        let beatIndex = Int(beatInLoop) % 16  // 16 beats in loop

        var drum: Float = 0

        // Kick: beats 0, 4, 8, 12 (quarter notes)
        let kickBeats = [0, 4, 8, 12]
        if kickBeats.contains(beatIndex) && beatFraction < 0.3 {
            let kickProgress = beatFraction / 0.3
            let kickFreq = 150.0 - 100.0 * kickProgress  // Sweep from 150 to 50 Hz
            drum += sin(2.0 * .pi * kickFreq * beatFraction * beatDuration) * (1.0 - kickProgress)
        }

        // Boss gets extra kick on off-beats
        if track == .boss && [2, 6, 10, 14].contains(beatIndex) && beatFraction < 0.2 {
            let kickProgress = beatFraction / 0.2
            let kickFreq = 120.0 - 70.0 * kickProgress
            drum += sin(2.0 * .pi * kickFreq * beatFraction * beatDuration) * (1.0 - kickProgress) * 0.6
        }

        // Snare: beats 4, 12
        let snareBeats = [4, 12]
        if snareBeats.contains(beatIndex) && beatFraction < 0.2 {
            let snareProgress = beatFraction / 0.2
            // Noise burst + tone
            let noise = Float(Int(time(beatFraction, sampleRate)) % 17) / 8.5 - 1.0  // Deterministic pseudo-noise
            let tone = sin(2.0 * .pi * 200.0 * beatFraction * beatDuration)
            drum += (noise * 0.6 + tone * 0.4) * (1.0 - snareProgress)
        }

        // Hihat: every other eighth note
        let eighthIndex = Int(beatInLoop * 2.0) % 32
        if eighthIndex % 2 == 1 && beatFraction > 0.5 {
            let hihatFrac = (beatFraction - 0.5) / 0.5
            if hihatFrac < 0.15 {
                let noise = Float(Int(time(beatFraction + Float(eighthIndex), sampleRate)) % 13) / 6.5 - 1.0
                drum += noise * 0.3 * (1.0 - hihatFrac / 0.15)
            }
        }

        return drum
    }

    /// Deterministic pseudo-noise seed from beat fraction and sample rate
    private static func time(_ beatFraction: Float, _ sampleRate: Float) -> Float {
        beatFraction * sampleRate
    }

    // MARK: - Pad Layer

    private static func synthPad(chord: (root: Float, third: Float, fifth: Float), time: Float) -> Float {
        // Soft sine tones at chord frequencies with slow LFO
        let lfo = (1.0 + sin(2.0 * .pi * 0.5 * time)) * 0.5  // 0.5 Hz tremolo
        let root = sin(2.0 * .pi * chord.root * time)
        let third = sin(2.0 * .pi * chord.third * time)
        let fifth = sin(2.0 * .pi * chord.fifth * time)
        return (root + third + fifth) / 3.0 * lfo
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter musicSynthesizer`
Expected: PASS

**Step 5: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/MusicSynthesizer.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add MusicSynthesizer with gameplay and boss track synthesis"
```

---

### Task 4: Music API on SynthAudioEngine

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

Add `startMusic`, `stopMusic`, and `fadeToTrack` to `SynthAudioEngine`, following the same pattern as the existing `startLaser`/`stopLaser` methods (lines 262-297).

**Step 1: Write failing tests**

Add to `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`:

```swift
@Test @MainActor func musicStartStopDoesNotCrash() {
    let engine = SynthAudioEngine()
    engine.startMusic(.gameplay)
    engine.stopMusic()
}

@Test @MainActor func musicStartBossDoesNotCrash() {
    let engine = SynthAudioEngine()
    engine.startMusic(.boss)
    engine.stopMusic()
}

@Test @MainActor func musicDoubleStartDoesNotCrash() {
    let engine = SynthAudioEngine()
    engine.startMusic(.gameplay)
    engine.startMusic(.boss)
    engine.stopMusic()
}

@Test @MainActor func musicFadeDoesNotCrash() {
    let engine = SynthAudioEngine()
    engine.startMusic(.gameplay)
    engine.fadeToTrack(.boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
    engine.stopMusic()
}

@Test @MainActor func musicUpdateFadeAdvancesFade() {
    let engine = SynthAudioEngine()
    engine.startMusic(.gameplay)
    engine.fadeToTrack(.boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
    // Simulate several update ticks
    for _ in 0..<60 {
        engine.updateMusicFade(deltaTime: 1.0 / 60.0)
    }
    // Should not crash, fade should progress
}
```

**Step 2: Run tests to verify they fail**

Run: `cd Engine2043 && swift test --filter music`
Expected: FAIL — `startMusic`, `stopMusic`, `fadeToTrack`, `updateMusicFade` not defined

**Step 3: Add music properties and methods to SynthAudioEngine**

Add these properties after the laser properties (after line 57 in `SynthAudioEngine.swift`):

```swift
// Background music real-time synthesis
private var musicNode: AVAudioSourceNode?
private let music = MusicState()
private var isMusicActive = false

// Fade state (main thread only)
private enum FadePhase {
    case none
    case fadingOut(targetTrack: MusicTrack, fadeOut: Float, silence: Float, fadeIn: Float)
    case silence(targetTrack: MusicTrack, remaining: Float, fadeIn: Float)
    case fadingIn(fadeIn: Float)
}
private var fadePhase: FadePhase = .none
private var fadeTimer: Float = 0
```

Add these methods after the `setLaserHeat` method (after line 296):

```swift
// MARK: - Background Music

public func startMusic(_ track: MusicTrack) {
    music.track.withLock { $0 = track }
    music.amplitude.withLock { $0 = 0.20 }
    music.samplePosition.withLock { $0 = 0 }

    if !isMusicActive {
        isMusicActive = true
        let node = music.makeSourceNode(format: format, sampleRate: Float(sampleRate))
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        musicNode = node
    }

    fadePhase = .none
}

public func stopMusic() {
    guard isMusicActive else { return }
    isMusicActive = false
    fadePhase = .none

    music.amplitude.withLock { $0 = 0 }

    if let node = musicNode {
        audioEngine.detach(node)
        musicNode = nil
    }
    music.samplePosition.withLock { $0 = 0 }
}

public func fadeToTrack(_ track: MusicTrack, fadeOut: Float, silence: Float, fadeIn: Float) {
    fadeTimer = 0
    fadePhase = .fadingOut(targetTrack: track, fadeOut: fadeOut, silence: silence, fadeIn: fadeIn)
}

public func updateMusicFade(deltaTime: Float) {
    let musicVolume: Float = 0.20

    switch fadePhase {
    case .none:
        return

    case .fadingOut(let target, let fadeOut, let silence, let fadeIn):
        fadeTimer += deltaTime
        let progress = min(fadeTimer / fadeOut, 1.0)
        music.amplitude.withLock { $0 = musicVolume * (1.0 - progress) }
        if progress >= 1.0 {
            fadeTimer = 0
            fadePhase = .silence(targetTrack: target, remaining: silence, fadeIn: fadeIn)
        }

    case .silence(let target, let remaining, let fadeIn):
        fadeTimer += deltaTime
        music.amplitude.withLock { $0 = 0 }
        if fadeTimer >= remaining {
            // Switch track and start fading in
            music.track.withLock { $0 = target }
            music.samplePosition.withLock { $0 = 0 }
            fadeTimer = 0
            fadePhase = .fadingIn(fadeIn: fadeIn)
        }

    case .fadingIn(let fadeIn):
        fadeTimer += deltaTime
        let progress = min(fadeTimer / fadeIn, 1.0)
        music.amplitude.withLock { $0 = musicVolume * progress }
        if progress >= 1.0 {
            fadePhase = .none
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd Engine2043 && swift test --filter music`
Expected: PASS

**Step 5: Run all existing tests to check for regressions**

Run: `cd Engine2043 && swift test`
Expected: All tests pass

**Step 6: Commit**

```
git add Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add startMusic/stopMusic/fadeToTrack to SynthAudioEngine"
```

---

### Task 5: Integrate music into Galaxy1Scene

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift`

Hook music playback into game lifecycle events:
- Game start → `startMusic(.gameplay)`
- Boss spawn (line 758 `spawnBoss()`) → `fadeToTrack(.boss, ...)`
- Boss defeated (line 196-199) → `fadeToTrack(.gameplay, ...)`
- Game over (line 270) → `stopMusic()`
- Victory (line 197) → `stopMusic()`
- Every `update()` tick → `updateMusicFade(deltaTime:)`

**Step 1: Add music start in init**

In `Galaxy1Scene.init()`, after all systems are set up, add:

```swift
sfx?.startMusic(.gameplay)
```

**Step 2: Add fade call to updateMusicFade in update()**

In the `update(time:)` method, add near the top (after the `guard gameState == .playing` check on line 146):

```swift
sfx?.updateMusicFade(deltaTime: Float(time.fixedDeltaTime))
```

Note: This should be called even when `gameState != .playing` so fades complete during game over/victory. Place it before the guard.

**Step 3: Add fade to boss track in spawnBoss()**

At the end of the `spawnBoss()` method (around line 786, after `bossEntity = boss`), add:

```swift
sfx?.fadeToTrack(.boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
```

**Step 4: Add fade back to gameplay on boss defeat**

At line 197 where `gameState = .victory`, change the block to:

```swift
gameState = .victory
scoreSystem.addScore(GameConfig.Score.boss)
sfx?.play(.victory)
sfx?.stopLaser()
sfx?.stopMusic()
```

**Step 5: Add music stop on game over**

At line 270 where `gameState = .gameOver`, add after it:

```swift
sfx?.stopMusic()
```

**Step 6: Run all tests**

Run: `cd Engine2043 && swift test`
Expected: All tests pass

**Step 7: Commit**

```
git add Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift
git commit -m "feat: integrate background music into Galaxy1Scene lifecycle"
```

---

### Task 6: Manual play test and tuning

**Step 1: Build and run the game**

Run in Xcode: Build and run on macOS target.

**Step 2: Verify**

- Gameplay music starts and loops
- Music volume sits well under SFX
- Boss spawn triggers fade out → silence → boss track fade in
- Boss defeat stops music
- Game over stops music
- No audio glitches or pops

**Step 3: Tune if needed**

Adjust in `MusicSynthesizer.swift`:
- Mix levels in `synthesize()` if too loud/quiet
- `musicVolume` constant in `SynthAudioEngine` (currently 0.20)
- Waveform generators if a layer sounds off
- Fade durations in `Galaxy1Scene.spawnBoss()` call

**Step 4: Commit any tuning changes**

```
git add -u
git commit -m "feat: tune background music mix levels"
```
