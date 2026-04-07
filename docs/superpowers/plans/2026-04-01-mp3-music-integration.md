# MP3 Music Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace procedural background music synthesis with MP3-based playback while keeping all procedural SFX intact.

**Architecture:** Extend `SynthAudioEngine` (renamed to `AudioEngine`) to load MP3 files from the bundle and play them via `AVAudioPlayerNode`. The existing fade state machine controls the player node's volume. Procedural SFX and laser synthesis are untouched.

**Tech Stack:** Swift 6.0, AVFoundation (AVAudioEngine, AVAudioPlayerNode), Swift Package Manager resource bundling

---

### Task 1: Add MP3 resource rule to Package.swift

**Files:**
- Modify: `Engine2043/Package.swift:17-19`

- [ ] **Step 1: Add the resource processing rule**

In `Engine2043/Package.swift`, add `.process("Audio/Music")` to the existing resources array:

```swift
resources: [
    .process("Rendering/Shaders"),
    .process("Audio/Music")
]
```

- [ ] **Step 2: Verify the package resolves**

Run: `cd /Users/david/Code/turbo-carnival && swift package resolve`
Expected: resolves without errors

- [ ] **Step 3: Commit**

```bash
git add Engine2043/Package.swift Engine2043/Sources/Engine2043/Audio/Music/gameplay.mp3 Engine2043/Sources/Engine2043/Audio/Music/boss.mp3
git commit -m "feat: add MP3 music assets and resource bundling rule"
```

---

### Task 2: Add filename property to MusicTrack

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/MusicTrack.swift`
- Test: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift`:

```swift
@Test func musicTrackFilenameMapping() {
    #expect(MusicTrack.gameplay.filename == "gameplay")
    #expect(MusicTrack.boss.filename == "boss")
    #expect(MusicTrack.title.filename == "gameplay")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/david/Code/turbo-carnival && swift test --filter musicTrackFilenameMapping 2>&1 | tail -20`
Expected: FAIL — `MusicTrack` has no member `filename`

- [ ] **Step 3: Implement the filename property**

Replace the contents of `Engine2043/Sources/Engine2043/Audio/MusicTrack.swift` with:

```swift
public enum MusicTrack: Sendable {
    case gameplay
    case boss
    case title

    var filename: String {
        switch self {
        case .gameplay, .title: "gameplay"
        case .boss: "boss"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/david/Code/turbo-carnival && swift test --filter musicTrackFilenameMapping 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/MusicTrack.swift Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift
git commit -m "feat: add filename property to MusicTrack enum"
```

---

### Task 3: Rename SynthAudioEngine to AudioEngine

**Files:**
- Rename: `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift` → `Engine2043/Sources/Engine2043/Audio/AudioEngine.swift`
- Modify: `Engine2043/Sources/Engine2043/Audio/AudioEngine.swift` (class name + error message)
- Modify: `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:31`
- Modify: `Engine2043/Sources/Engine2043/Scene/TitleScene.swift:8`
- Modify: `Project2043-macOS/MetalView.swift:45`
- Modify: `Project2043-iOS/MetalView.swift:57`
- Rename: `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift` → `Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift` (struct name + all references)

- [ ] **Step 1: Rename the source file**

```bash
cd /Users/david/Code/turbo-carnival
git mv Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift Engine2043/Sources/Engine2043/Audio/AudioEngine.swift
```

- [ ] **Step 2: Rename the class and error message inside AudioEngine.swift**

In `Engine2043/Sources/Engine2043/Audio/AudioEngine.swift`, replace:
- `public final class SynthAudioEngine {` → `public final class AudioEngine {`
- `print("SynthAudioEngine failed to start: \(error)")` → `print("AudioEngine failed to start: \(error)")`

- [ ] **Step 3: Update Galaxy1Scene.swift**

In `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift` line 31, replace:
- `public var sfx: SynthAudioEngine?` → `public var sfx: AudioEngine?`

- [ ] **Step 4: Update TitleScene.swift**

In `Engine2043/Sources/Engine2043/Scene/TitleScene.swift` line 8, replace:
- `public var sfx: SynthAudioEngine?` → `public var sfx: AudioEngine?`

- [ ] **Step 5: Update macOS MetalView.swift**

In `Project2043-macOS/MetalView.swift` line 45, replace:
- `let sfxEngine = SynthAudioEngine()` → `let sfxEngine = AudioEngine()`

- [ ] **Step 6: Update iOS MetalView.swift**

In `Project2043-iOS/MetalView.swift` line 57, replace:
- `let sfxEngine = SynthAudioEngine()` → `let sfxEngine = AudioEngine()`

- [ ] **Step 7: Rename the test file**

```bash
cd /Users/david/Code/turbo-carnival
git mv Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift
```

- [ ] **Step 8: Update test file references**

In `Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift`:
- Replace `struct SynthAudioTests {` → `struct AudioEngineTests {`
- Replace every `SynthAudioEngine()` → `AudioEngine()` (there are 12 occurrences)

- [ ] **Step 9: Build to verify rename**

Run: `cd /Users/david/Code/turbo-carnival && swift build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 10: Run all tests**

Run: `cd /Users/david/Code/turbo-carnival && swift test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "refactor: rename SynthAudioEngine to AudioEngine"
```

---

### Task 4: Replace procedural music with MP3 playback

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/AudioEngine.swift`
- Delete: `Engine2043/Sources/Engine2043/Audio/MusicState.swift`
- Delete: `Engine2043/Sources/Engine2043/Audio/MusicSynthesizer.swift`

This is the core change. Replace the `AVAudioSourceNode`-based music synthesis with `AVAudioPlayerNode` + MP3 buffer playback.

- [ ] **Step 1: Load MP3 buffers at init**

In `AudioEngine.swift`, replace the music-related properties:

```swift
// Background music real-time synthesis
private var musicNode: AVAudioSourceNode?
private let music = MusicState()
private var isMusicActive = false
```

with:

```swift
// Background music (MP3 playback)
private let musicPlayerNode = AVAudioPlayerNode()
private var musicBuffers: [MusicTrack: AVAudioPCMBuffer] = [:]
private var isMusicActive = false
private var currentMusicTrack: MusicTrack?
```

- [ ] **Step 2: Add MP3 loading method**

Add this private method to `AudioEngine`:

```swift
private func loadMusicBuffer(for track: MusicTrack) -> AVAudioPCMBuffer? {
    guard let url = Bundle.module.url(forResource: track.filename, withExtension: "mp3") else {
        print("AudioEngine: missing music file \(track.filename).mp3")
        return nil
    }
    do {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        try file.read(into: buffer)
        return buffer
    } catch {
        print("AudioEngine: failed to load \(track.filename).mp3 — \(error)")
        return nil
    }
}
```

- [ ] **Step 3: Update init to attach musicPlayerNode and load MP3 buffers**

In `init()`, after the SFX player node loop and before `audioEngine.mainMixerNode.outputVolume = volume`, add:

```swift
audioEngine.attach(musicPlayerNode)
audioEngine.connect(musicPlayerNode, to: audioEngine.mainMixerNode, format: nil)
```

After `synthesizeAllBuffers()` at the end of init, add:

```swift
loadMusicBuffers()
```

Add the loading method:

```swift
private func loadMusicBuffers() {
    for track in [MusicTrack.gameplay, .boss] {
        if let buffer = loadMusicBuffer(for: track) {
            musicBuffers[track] = buffer
        }
    }
}
```

- [ ] **Step 4: Replace startMusic**

Replace the existing `startMusic` method with:

```swift
public func startMusic(_ track: MusicTrack) {
    let resolvedTrack = (track == .title) ? MusicTrack.gameplay : track
    guard let buffer = musicBuffers[resolvedTrack] else { return }

    musicPlayerNode.stop()
    musicPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops)
    musicPlayerNode.volume = 1.0
    musicPlayerNode.play()
    currentMusicTrack = resolvedTrack
    isMusicActive = true
    fadePhase = .none
}
```

- [ ] **Step 5: Replace stopMusic**

Replace the existing `stopMusic` method with:

```swift
public func stopMusic() {
    guard isMusicActive else { return }
    isMusicActive = false
    fadePhase = .none
    musicPlayerNode.stop()
    currentMusicTrack = nil
}
```

- [ ] **Step 6: Update shutdown to stop musicPlayerNode**

In `shutdown()`, replace `stopMusic()` with keeping it as-is (it already calls `musicPlayerNode.stop()`). But also remove any reference to detaching musicNode since it's now permanently attached. The current shutdown is:

```swift
public func shutdown() {
    stopLaser()
    stopMusic()
    for node in playerNodes {
        node.stop()
    }
    audioEngine.stop()
}
```

This still works correctly — `stopMusic()` calls `musicPlayerNode.stop()`.

- [ ] **Step 7: Update updateMusicFade to use musicPlayerNode.volume**

Replace the `updateMusicFade` method with:

```swift
public func updateMusicFade(deltaTime: Float) {
    switch fadePhase {
    case .none:
        return

    case .fadingOut(let target, let fadeOut, let silence, let fadeIn):
        fadeTimer += deltaTime
        let progress = min(fadeTimer / fadeOut, 1.0)
        musicPlayerNode.volume = 1.0 - progress
        if progress >= 1.0 {
            fadeTimer = 0
            fadePhase = .silence(targetTrack: target, remaining: silence, fadeIn: fadeIn)
        }

    case .silence(let target, let remaining, let fadeIn):
        fadeTimer += deltaTime
        musicPlayerNode.volume = 0
        if fadeTimer >= remaining {
            let resolvedTrack = (target == .title) ? MusicTrack.gameplay : target
            if let buffer = musicBuffers[resolvedTrack] {
                musicPlayerNode.stop()
                musicPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops)
                musicPlayerNode.play()
                currentMusicTrack = resolvedTrack
            }
            fadeTimer = 0
            fadePhase = .fadingIn(fadeIn: fadeIn)
        }

    case .fadingIn(let fadeIn):
        fadeTimer += deltaTime
        let progress = min(fadeTimer / fadeIn, 1.0)
        musicPlayerNode.volume = progress
        if progress >= 1.0 {
            fadePhase = .none
        }
    }
}
```

- [ ] **Step 8: Delete MusicState.swift and MusicSynthesizer.swift**

```bash
cd /Users/david/Code/turbo-carnival
git rm Engine2043/Sources/Engine2043/Audio/MusicState.swift
git rm Engine2043/Sources/Engine2043/Audio/MusicSynthesizer.swift
```

- [ ] **Step 9: Build to verify**

Run: `cd /Users/david/Code/turbo-carnival && swift build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: replace procedural music synthesis with MP3 playback"
```

---

### Task 5: Update tests for MP3-based music

**Files:**
- Modify: `Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift`

The old tests referenced `MusicState` and `MusicSynthesizer` which are now deleted. Replace those tests with MP3-based equivalents.

- [ ] **Step 1: Remove deleted-class tests**

In `Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift`, remove these tests entirely:

- `musicStateDefaultValues` (references deleted `MusicState`)
- `musicSynthesizerProducesNonSilentOutput` (references deleted `MusicSynthesizer`)
- `musicSynthesizerBossTrackProducesOutput` (references deleted `MusicSynthesizer`)
- `musicSynthesizerOutputInRange` (references deleted `MusicSynthesizer`)

- [ ] **Step 2: Add MP3 bundle loading test**

Add this test to `AudioEngineTests`:

```swift
@Test func musicMP3FilesExistInBundle() {
    let gameplayURL = Bundle.module.url(forResource: "gameplay", withExtension: "mp3")
    let bossURL = Bundle.module.url(forResource: "boss", withExtension: "mp3")
    #expect(gameplayURL != nil, "gameplay.mp3 should be bundled")
    #expect(bossURL != nil, "boss.mp3 should be bundled")
}

@Test func musicMP3FilesLoadAsAudioBuffers() throws {
    let gameplayURL = try #require(Bundle.module.url(forResource: "gameplay", withExtension: "mp3"))
    let file = try AVAudioFile(forReading: gameplayURL)
    let frameCount = AVAudioFrameCount(file.length)
    #expect(frameCount > 0, "gameplay.mp3 should have audio frames")

    let bossURL = try #require(Bundle.module.url(forResource: "boss", withExtension: "mp3"))
    let bossFile = try AVAudioFile(forReading: bossURL)
    let bossFrameCount = AVAudioFrameCount(bossFile.length)
    #expect(bossFrameCount > 0, "boss.mp3 should have audio frames")
}
```

Add `import AVFoundation` at the top of the test file if not already present.

- [ ] **Step 3: Run all tests**

Run: `cd /Users/david/Code/turbo-carnival && swift test 2>&1 | tail -30`
Expected: All tests pass (existing music start/stop/fade tests still work since the API is unchanged)

- [ ] **Step 4: Commit**

```bash
git add Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift
git commit -m "test: update audio tests for MP3-based music playback"
```

---

### Task 6: Final verification

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/david/Code/turbo-carnival && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 2: Build both platform targets**

Run: `cd /Users/david/Code/turbo-carnival && xcodebuild -scheme Project2043-macOS -destination 'platform=macOS' build 2>&1 | tail -10`
Run: `cd /Users/david/Code/turbo-carnival && xcodebuild -scheme Project2043-iOS -destination 'generic/platform=iOS' build 2>&1 | tail -10`
Expected: Both build successfully

- [ ] **Step 3: Verify file cleanup**

Confirm these files no longer exist:
- `Engine2043/Sources/Engine2043/Audio/SynthAudioEngine.swift` (renamed)
- `Engine2043/Sources/Engine2043/Audio/MusicState.swift` (deleted)
- `Engine2043/Sources/Engine2043/Audio/MusicSynthesizer.swift` (deleted)
- `Engine2043/Tests/Engine2043Tests/SynthAudioTests.swift` (renamed)

Confirm these files exist:
- `Engine2043/Sources/Engine2043/Audio/AudioEngine.swift`
- `Engine2043/Sources/Engine2043/Audio/Music/gameplay.mp3`
- `Engine2043/Sources/Engine2043/Audio/Music/boss.mp3`
- `Engine2043/Tests/Engine2043Tests/AudioEngineTests.swift`
