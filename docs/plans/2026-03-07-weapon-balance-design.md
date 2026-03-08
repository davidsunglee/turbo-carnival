# Weapon Balance Design

## Philosophy

Each weapon has a clear power niche. Some shine against groups, some against bosses, some reward skilled aim. Weapons are not equal DPS — they're equal *value* in their intended role.

## Primary Weapons

### Double Cannon (All-Rounder) — No Changes

- 2 projectiles x 1.0 damage x 4.0 fire rate = 8.0 DPS
- Baseline weapon. All others balance relative to it.

### Tri-Spread (Wave-Clear Specialist)

- **Reduce fire rate:** 4.0 → 3.0
- **Widen spread angle:** π/12 (15°) → π/9 (20°)
- Per-projectile damage stays at 0.7
- Result: 6.3 single-target DPS (worse than Double Cannon), but hits 3 targets per volley. Pick it for waves, not bosses.

### Lightning Arc (Easy-Mode Crowd Control)

- **Add damage ramp-up:** Starts at 25% damage, ramps to 100% over 0.5s of sustained lock on the same primary target. Ramp resets when primary target changes. Chain targets use falloff against the ramped base damage.
- **Reduce base damage per tick:** 0.8 → 0.6
- Tick rate, range, chain count, chain falloff, chain range unchanged.
- Result at full ramp: 6.0 primary + 3.0 second + 1.5 third = 10.5 group DPS, but only after 0.5s commitment. Quick flicking stays at ~1.5 DPS.

### Phase Laser (Boss-Killer / High-Skill)

- **Add heat-scaling damage:** Damage per tick scales linearly from 1.0x (at 0 heat) to 1.6x (at max heat).
- Overheat cooldown, heat rates, beam width, tick interval all unchanged.
- Result: DPS ramps from 10.0 to 16.0 over 1s, then 1s forced cooldown. Average ~6.5 effective DPS; skilled heat management pushes higher. Best-in-slot for bosses with precise aim.

## Secondary Weapons

### Grav Bomb — No Changes

- 3 damage, 120 radius, 0.4s detonation delay
- Offensive burst. One-shots tier1 groups.

### EMP Sweep

- **Increase slow-mo duration:** 0.3s → 0.8s
- Projectile clear + full-screen flash unchanged.
- Defensive panic button with real repositioning window during boss bullet hell.

### Overcharge Protocol

- **Reduce duration:** 5s → 4s
- Fire rate multiplier (2x) and hitbox scale (1.5x) unchanged.
- Still a strong DPS steroid, slightly less dominant.

## DPS Summary Table

| Weapon | Single-Target DPS | Group DPS | Skill Required |
|---|---|---|---|
| Double Cannon | 8.0 | 8.0 | Low |
| Tri-Spread | 6.3 | ~13+ (3 targets) | Low |
| Lightning Arc | 1.5→6.0 (ramp) | 10.5 (full ramp) | None |
| Phase Laser | 10→16 (heat curve) | 10→16 (single beam) | High |

## Implementation Notes

### GameConfig Changes

- `triSpreadAngle`: π/12 → π/9
- `triSpreadFireRate`: new constant, 3.0
- `lightningArcDamagePerTick`: 0.8 → 0.6
- `lightningArcRampDuration`: new constant, 0.5s
- `lightningArcMinRampMultiplier`: new constant, 0.25
- `laserMaxHeatDamageMultiplier`: new constant, 1.6
- `empSlowMoDuration`: 0.3 → 0.8
- `overchargeDuration`: 5.0 → 4.0

### Code Changes

- **LightningArcSystem:** Track current primary target entity. Accumulate ramp timer when primary is the same. Reset on target change. Apply ramp multiplier to base damage.
- **WeaponSystem (Phase Laser branch):** Multiply `laserDamagePerTick` by `1.0 + (weapon.laserHeat / laserMaxHeat) * (maxHeatDamageMultiplier - 1.0)`.
- **WeaponSystem (Tri-Spread branch):** Use new `triSpreadFireRate` instead of the weapon's default `fireRate`.

### Preserved Elements

- Lightning Arc chain visuals (ArcSegment rendering)
- Phase Laser tick feel and sound
- All existing SFX triggers
