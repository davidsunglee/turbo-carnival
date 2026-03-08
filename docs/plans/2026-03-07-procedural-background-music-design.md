# Procedural Background Music Design

## Overview

Add procedurally synthesized synthwave background music to `SynthAudioEngine` with two distinct tracks: a driving/upbeat gameplay track and a contrasting boss fight track. Four layers each: bass line, arpeggiated lead, drum pattern (kick/snare/hihat), and pad/chord layer.

## Architecture

- All synthesis lives in `SynthAudioEngine` — extends the existing engine rather than using `AVAudioManager`
- Add an `AVAudioSourceNode` for music (similar to the existing `LaserState` pattern for real-time synthesis)
- Music state managed via a `MusicState` (Sendable) object with `Mutex`-wrapped parameters, matching the `LaserState` pattern for thread-safe audio-thread access

## Music Engine Details

- **Tempo:** ~120 BPM (0.5s per beat)
- **Real-time synthesis:** A single `AVAudioSourceNode` render callback mixes all four layers per sample
- **Layers (both tracks):**
  1. **Bass** — Square/sawtooth wave, root note pattern, steady eighth notes
  2. **Arpeggio** — Sine or pulse wave cycling through chord tones, sixteenth notes
  3. **Drums** — Synthesized kick (low sine sweep), snare (noise burst + tone), hihat (filtered noise)
  4. **Pad** — Low-amplitude chord tones with slow attack, fills out the sound

## Gameplay Track

- **Key:** C minor
- **Chord progression:** Cm -> Ab -> Bb -> G (i -> VI -> VII -> V), 4 bars looping
- **Character:** Driving, upbeat, pulsing

## Boss Track

- **Key:** E minor (distinct from gameplay)
- **Chord progression:** Em -> C -> D -> B (i -> VI -> VII -> V), 4 bars looping
- **Character:** Darker, more aggressive — faster arpeggios, heavier kick, distorted bass

## Transitions

- **Boss spawn:** Fade out gameplay track (~1s), silence (~0.5s), fade in boss track (~1s)
- **Boss defeated:** Fade out boss track, silence, fade in gameplay track
- **Game over / victory:** Fade out music
- Fade controlled by an amplitude envelope in the `MusicState`, stepped in the game's `update()` loop

## Volume

- Music source node output scaled to ~0.15-0.20 relative amplitude so SFX punch through
- Both music and SFX feed into the same `mainMixerNode`, controlled by the existing single master volume

## API Surface

```swift
public enum MusicTrack {
    case gameplay
    case boss
}

// On SynthAudioEngine:
public func startMusic(_ track: MusicTrack)
public func stopMusic()
public func fadeToTrack(_ track: MusicTrack, fadeOut: Float, silence: Float, fadeIn: Float)
```

## Out of Scope

- No menu music, no adaptive layering based on gameplay intensity
- No audio settings UI
- No per-level variations
