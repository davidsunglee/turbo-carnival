# Phase 5: Procedural SFX Design

**Date:** 2026-03-07
**Scope:** Procedural sound effects for combat core + items
**Approach:** Hybrid — pre-rendered synth buffers for one-shots, real-time oscillator for Phase Laser

## Architecture

A new `SynthAudioEngine` class lives alongside the existing `AVAudioManager`. The existing manager stays for future music playback. The synth engine handles all gameplay SFX.

```
Engine2043/Audio/
├── AudioManager.swift          # Existing — file-based, for music
├── SynthAudioEngine.swift      # NEW — procedural synthesis + playback
└── SFXType.swift               # NEW — enum of all sound effects
```

**Integration:** `Galaxy1Scene` gets a `public var sfx: SynthAudioEngine?` property. The scene calls `sfx?.play(.doubleCannonFire)` at gameplay event points. macOS/iOS app shells create the engine and inject it.

**Phase Laser special case:** One dedicated `AVAudioSourceNode` generates the laser hum in real time. `startLaser()` / `stopLaser()` / `setLaserHeat(Float)` control pitch wobble and intensity tied to the heat gauge.

## Sound Palette

| Sound | Waveform | Freq (Hz) | Duration | Character |
|-------|----------|-----------|----------|-----------|
| Double Cannon fire | Square wave | 440→220 | ~80ms | Sharp descending pulse, classic arcade blaster |
| Tri-Spread fire | Square + noise | 330→165 | ~100ms | Wider, slightly distorted spread feel |
| Vulcan Auto-Gun fire | Sawtooth | 880→660 | ~40ms | Very short, high-pitched tick |
| Phase Laser hum | Sawtooth + sine | 120±10 | Sustained | Low drone with slow LFO wobble, pitch rises with heat |
| Enemy hit | Noise burst | White noise | ~30ms | Tiny crunch confirming damage |
| Enemy destroyed | Noise + square | 200→50 | ~200ms | Descending explosion with noise tail |
| Player damaged | Square wave | 100→60 | ~150ms | Heavy low thud |
| Item spawn | Sine wave | 660→880 | ~120ms | Rising sparkle tone |
| Item cycle | Sine wave | 440→550 | ~60ms | Quick ascending pip |
| Item pickup | Sine chord | 440+660+880 | ~200ms | Bright major triad arpeg |

**Principles:**
- Weapon fire sounds short enough to not pile up at high fire rates
- Player vs enemy sounds use different frequency ranges for instant recognition
- All buffers rendered at 44100Hz, mono, float32

## Synthesis Implementation

**Waveforms:**
- Square: `sign(sin(2pi * freq * t))`
- Sawtooth: `2 * (freq * t mod 1) - 1`
- Sine: `sin(2pi * freq * t)`
- White noise: `Float.random(in: -1...1)`
- Frequency sweep: linear interpolation startFreq→endFreq over duration
- Amplitude envelope: simple AD (attack 5-10% of duration, linear decay to zero)
- Mixing: multiple waveforms summed and normalized

**Playback pool:** 8 `AVAudioPlayerNode`s connected to the engine mixer. `play()` finds an idle node (or steals oldest), schedules pre-rendered buffer, plays.

**Phase Laser (real-time):** One `AVAudioSourceNode` with render callback generating sawtooth + sine per-frame. Heat maps 0→1 to pitch 120Hz→180Hz and amplitude boost. Fade-out over ~50ms on stop.

**Thread safety:** Synthesis at init on main thread. `AVAudioPlayerNode` handles audio thread scheduling. `AVAudioSourceNode` render callback reads frequency/amplitude via atomics, no locks.

## Scene Integration Points

```
Weapon fired       → where projectiles are spawned (per weapon type)
                     Phase Laser: startLaser() / stopLaser()
Enemy hit          → handleProjectileHitsEnemy() when damage applied, not destroyed
Enemy destroyed    → handleProjectileHitsEnemy() when health <= 0
Player damaged     → handleEnemyProjectileHitsPlayer() / handlePlayerCollidesEnemy()
Item spawn         → item creation after formation wipe
Item cycle         → handleProjectileHitsItem() when type advances
Item pickup        → handlePlayerCollectsItem()
```

**Vulcan rate limiting:** ~60ms cooldown per SFX type to prevent cacophony at max fire rate.

**Phase Laser heat:** During `update()`, call `setLaserHeat(currentHeat)` to modulate drone pitch each frame.
