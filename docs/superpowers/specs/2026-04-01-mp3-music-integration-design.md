# MP3 Music Integration Design

Replace procedural background music synthesis with MP3-based playback while keeping all procedural SFX intact.

## Context

Project 2043's audio is handled by `SynthAudioEngine`, which synthesizes all SFX and background music in real-time via AVAudioSourceNode. The background music uses `MusicState` and `MusicSynthesizer` to generate four-layer synth tracks (bass, arpeggio, drums, pad) on the audio thread.

We're replacing the synthesized background music with two original MP3 compositions — one for gameplay and one for boss battles. The procedural SFX system (17 sound effects + real-time laser tone) remains unchanged.

## Asset Location

MP3 files placed at:

```
Engine2043/Sources/Engine2043/Audio/Music/
├── gameplay.mp3
└── boss.mp3
```

`Package.swift` gets an additional resource rule: `.process("Audio/Music")` so SPM bundles them via `Bundle.module`.

## Architecture Changes

### Rename: SynthAudioEngine → AudioEngine

The class is no longer purely synthesis-based. Rename to `AudioEngine` to reflect its hybrid nature (procedural SFX + file-based music). This is the only class scenes interact with for audio.

All scene call sites update the type name. The `sfx` property name in scenes remains unchanged — it still refers to the same object.

### Music Playback: Synthesis → AVAudioPlayerNode

Replace the `AVAudioSourceNode` real-time synthesis approach with a single `AVAudioPlayerNode` for music:

- At init, load both MP3 files into `AVAudioPCMBuffer` objects (cached, like SFX buffers)
- `startMusic(_ track:)` stops the current buffer, schedules the new track's buffer with `.loops`, and plays
- `stopMusic()` stops the player node

The `MusicState` and `MusicSynthesizer` classes are deleted — they are no longer needed.

### MusicTrack Enum

Add a computed property mapping tracks to filenames:

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

`.title` and `.gameplay` both map to `gameplay.mp3`, matching the current behavior where the title screen and gameplay share the same music.

### Fade State Machine

The existing `FadePhase` enum and `updateMusicFade(deltaTime:)` method stay exactly as-is in terms of logic. The only change is the volume target:

- **Before:** `music.amplitude.withLock { $0 = value }` (Mutex on audio thread)
- **After:** `musicPlayerNode.volume = value` (AVAudioPlayerNode property)

During the silence phase track switch: stop the current buffer, schedule the new track's buffer with `.loops`, and play — then proceed with fade-in.

### Public API (Unchanged)

The public interface remains identical — no scene code changes beyond the type name:

- `startMusic(_ track: MusicTrack)`
- `stopMusic()`
- `fadeToTrack(_ track: MusicTrack, fadeOut: Float, silence: Float, fadeIn: Float)`
- `updateMusicFade(deltaTime: Float)`
- `play(_ effect: SFXType)`
- `startLaser()` / `stopLaser()` / `setLaserHeat(_ heat: Float)`
- `volume: Float`
- `shutdown()`

### Untouched Systems

- All 17 SFX types and their waveform generators
- SFX player node pool (8 nodes)
- Rate limiting for lightningArcZap and bossShieldDeflect
- Phase Laser real-time synthesis (LaserState + AVAudioSourceNode)
- Master volume control
- AudioManager.swift (unused fallback, no changes)

## Error Handling

Both MP3 buffers are loaded at init. If a file is missing or fails to load, a warning is logged and music playback silently becomes a no-op for that track. No fallback to procedural synthesis — a missing MP3 is a build/bundling issue.

## File Changes

| File | Change |
|------|--------|
| `Package.swift` | Add `.process("Audio/Music")` resource rule |
| `SynthAudioEngine.swift` → `AudioEngine.swift` | Rename class. Replace MusicState/AVAudioSourceNode with AVAudioPlayerNode + MP3 buffer loading. Keep all SFX/laser code. |
| `MusicTrack.swift` | Add `var filename: String` computed property |
| `MusicState.swift` | Delete |
| `MusicSynthesizer.swift` | Delete |
| Scene files referencing `SynthAudioEngine` | Update type name to `AudioEngine` |
| `SynthAudioTests.swift` → `AudioEngineTests.swift` | Rename, update class references, add MP3 loading tests |

## Testing

Update existing audio tests (renamed to `AudioEngineTests`):

- Verify both MP3 buffers load from the bundle
- Verify looping playback starts without crash
- Verify fade transitions work with file-based music
- All existing SFX synthesis tests remain unchanged
