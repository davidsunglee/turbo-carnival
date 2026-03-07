# Phase 5b: Remaining Procedural SFX Design

**Date:** 2026-03-07
**Scope:** 7 new procedural sound effects for secondary weapons, boss shield, and game state transitions
**Approach:** Pre-rendered synth buffers, extending existing SynthAudioEngine

## Architecture

No new files or structural changes. Extend existing system:
- Add 7 new cases to `SFXType` enum
- Add 7 new buffer generators in `SynthAudioEngine`
- Wire `sfx?.play(...)` calls at 7 event sites in `Galaxy1Scene`

## Sound Palette

| Sound | Waveform | Freq (Hz) | Duration | Character |
|-------|----------|-----------|----------|-----------|
| Grav Bomb launch | Sine sweep down | 300->100 | ~100ms | Whooshing drop |
| Grav Bomb detonate | Noise + square sweep | 150->30 | ~300ms | Heavy bass explosion, bigger than enemyDestroyed |
| EMP Sweep | Noise + sine sweep up | 200->2000 | ~250ms | Rising electric zap/crackle |
| Overcharge activate | Sine chord ascending | 330+440+660 | ~150ms | Power-up arpeggio, brighter than itemPickup |
| Boss shield deflect | Square ping | 1200->1400 | ~40ms | Short metallic ping, high and thin |
| Player death | Square + noise two-stage | 200->40 | ~500ms | Heavy descending groan + noise tail |
| Victory | Sine chord staggered 4-note | 440->550->660->880 | ~600ms | Ascending major arpeggio, triumphant |

## Synthesis Details

All buffers pre-rendered at init, 44100 Hz mono float32 with AD envelopes — same as existing.

- **Grav Bomb launch:** Reuse `sineSweep()` with downward sweep.
- **Grav Bomb detonate:** Reuse `explosion()` generator (square + noise mix) with lower freq range and longer duration.
- **EMP Sweep:** New blend — noise burst mixed with `sineSweep()` upward at ~40%/60% ratio.
- **Overcharge activate:** Reuse `sineChord()` with different frequencies (330/440/660) and shorter duration.
- **Boss shield deflect:** Reuse `squareSweep()` with narrow upward range and very short duration.
- **Player death:** `explosion()` variant — heavier square/noise mix (50/50) at low freq, longer AD envelope with extended decay.
- **Victory:** `sineChord()` with 4 frequencies and longer stagger for arpeggio feel.

## Scene Integration Points

```
Grav Bomb launch     -> spawnGravBomb()
Grav Bomb detonate   -> detonateGravBomb()
EMP Sweep activate   -> activateEMPSweep()
Overcharge activate  -> activateOvercharge()
Boss shield deflect  -> processCollisions() boss shield branches
Player death         -> update() where gameState = .gameOver
Victory              -> update() where gameState = .victory
```

## Testing

Extend existing `SynthAudioTests`:
- `sfxTypeHasAllExpectedCases()` already covers enum completeness (CaseIterable)
- `allSFXTypesPlayWithoutCrash()` already covers exhaustive playback
- Both tests auto-cover new cases with no code changes needed

## Principles

- Secondary weapon SFX should feel distinct from primary weapon fire — lower/wider frequency ranges
- Boss shield ping should be clearly different from enemy hit (high pitch vs noise burst)
- Death/victory are the longest sounds in the game — emotional weight through duration, not complexity
- No new scheduling or engine mechanisms needed
