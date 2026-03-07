# Gameplay Polish Design

Three targeted improvements to tighten gameplay feel in Galaxy1.

## 1. Wave Timing Compression

**Problem**: Too much dead air between enemy waves throughout the stage.

**Solution**: Compress all wave trigger distances by ~40%, preserving relative spacing within phases.

| Phase | Current Range | Compressed Range |
|-------|--------------|-----------------|
| Tutorial | 50-400 | 50-260 |
| Escalation | 550-1100 | 350-700 |
| Capital Approach | 1250-1900 | 800-1200 |
| Capital Ship | 2000-2500 | 1250-1550 |
| Final Gauntlet | 2800-3300 | 1700-2000 |
| Boss | 3500 | 2150 |

Total stage length drops from ~3500 to ~2150 scroll units. Difficulty curve shape is preserved.

## 2. Lightning Arc Weapon (replaces Vulcan Auto-Gun)

**Problem**: Vulcan Auto-Gun is not sufficiently differentiated from Double Cannon (same bullet, just faster/smaller).

**Solution**: Replace with Lightning Arc -- an auto-targeting chain lightning weapon.

**Properties:**

| Property | Value | Rationale |
|----------|-------|-----------|
| Range | ~200 units | Short range, forces aggressive positioning |
| Primary damage | 0.8 per tick | Slightly below Double Cannon DPS |
| Tick rate | 10/sec | Smooth continuous feel |
| Chain targets | Up to 2 additional | Core identity -- multi-target |
| Chain damage falloff | 50% per hop | 0.8 -> 0.4 -> 0.2 per tick |
| Chain range | ~80 units between targets | Enemies must be near each other |

**How it differs from Phase Laser:**
- Phase Laser: player-aimed straight-line hitscan beam with heat management
- Lightning Arc: auto-targets nearest enemy, chains to nearby targets, no heat mechanic

**Visuals:** Jagged electric arc lines (white-blue core, cyan glow), jittering each frame for electric crackle feel.

**Audio:** Continuous crackling/zapping synth loop. Pitch shifts based on number of active chain targets.

**Tactical niche:** The "lazy aim, get close" weapon. Excellent against mid-density formations. Weak against spread-out or distant single targets.

## 3. Drop System Overhaul

**Problem**: Too many drops (100% on every formation wipe) and too predictable (deterministic utility cycling).

### Weapon Drops -- Scripted
- Exactly 2 weapon drops per stage at ~1/3 (~715) and ~2/3 (~1430) stage progress
- Spawned as scripted SpawnDirector events, not tied to formation wipes
- Weapon module cycling behavior unchanged (shoot to cycle, excludes current weapon)

### Utility Drops -- Randomized and Reduced
- 45% chance per formation wipe (down from 100%)
- Utility type randomly selected (equal 1/3 probability each) instead of deterministic cycle
- Capital ship turrets no longer force weapon drops
- All other item behavior unchanged (8s despawn, bounce, shoot-to-cycle)

**Expected results:**
- ~10-12 utility drops per stage (down from ~20)
- Exactly 2 weapon drops per stage (down from ~5 random)
- Each drop feels more meaningful and surprising
