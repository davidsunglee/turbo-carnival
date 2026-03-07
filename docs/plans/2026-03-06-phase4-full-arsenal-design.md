# Phase 4: Full Arsenal — Design

**Date:** 2026-03-06
**Scope:** Complete all primary and secondary weapons, separate Weapon Module item
**Prerequisite:** Phase 3 vertical slice (complete)

## Overview

Complete the weapon arsenal from the spec. Add Vulcan Auto-Gun and Phase Laser primaries, EMP Sweep and Overcharge Protocol secondaries, and a separate Weapon Module item for primary weapon acquisition. All three secondaries are always available on dedicated keys with a shared charge pool.

## Primary Weapons (4 total)

### Double Cannon (existing)
- 2 parallel projectiles, 6x12, 500 speed, 1.0 damage each
- Base fire rate
- Reliable baseline DPS, narrow arc

### Tri-Spread (existing)
- 3 projectiles: one straight, two at +/-15 degrees
- Base fire rate, 0.7 damage per projectile
- Excellent horizontal coverage, lower focused DPS

### Vulcan Auto-Gun (new)
- 1 narrow projectile, 2x base fire rate, 1.0 damage
- Effectively 2x DPS of Double Cannon
- Demands precision aiming — minimal width means misses are punished
- Fast projectile speed per spec

### Phase Laser (new)
- Instant hitscan: vertical line from ship to top of screen
- 0.8s active burst, then 0.5s cooldown (cannot fire during cooldown)
- Deals 0.4 damage per tick, ticks every 0.1s (8 ticks per burst = 3.2 damage max per burst to a single target)
- Pierces all enemies in the column — damages every overlapping enemy each tick
- Devastating against stationary/aligned targets (turrets, boss), poor horizontal coverage

## Secondary Weapons (3 total)

All three always available. Shared charge pool: 3 max, starts with 1.

### Grav-Bomb (existing) — Z key / iOS button 1 (lowest)
- Slow-moving gold orb, detonates after 0.4s or on contact
- ~120 radius circular blast for 2 frames
- Kills Tier 1-2 instantly, 3 damage to turrets/boss

### EMP Sweep (new) — X key / iOS button 2 (middle)
- Screen-wide instant bullet cancel
- Zero structural damage to enemies
- Brief ~0.3s slow-mo effect after activation for repositioning
- Costs 1 charge

### Overcharge Protocol (new) — C key / iOS button 3 (top)
- 5 second buff on current primary weapon
- Doubles fire rate, widens projectile hitbox
- Costs 1 charge

## Weapon Module Item

Separate item from the utility power-up cycle. Visually distinct (Blue Hexagon per spec).

- When shot: cycles through the 3 primary weapons the player does NOT currently have, in fixed order (Double Cannon -> Tri-Spread -> Vulcan -> Phase Laser, skipping current)
- When collected: overwrites current primary weapon with displayed weapon
- Drop triggers: ~20% chance from full Tier 1 formation kills, guaranteed from capital ship turret clears
- Physics: 40 units/sec downward drift, bounces off horizontal screen edges, despawns after 8 seconds

## Input Changes

### macOS
- Z = Grav-Bomb (existing, unchanged)
- X = EMP Sweep (new binding)
- C = Overcharge Protocol (new binding)

### iOS
- Lower-right quadrant, stacked vertically:
  - Primary fire: large button (bottom, existing)
  - Grav-Bomb: smaller button above primary
  - EMP Sweep: smaller button above Grav-Bomb
  - Overcharge Protocol: smaller button above EMP Sweep

## What's NOT in this phase

- Utility item cycle expansion (Secondary Charge, Speed Thruster, Weapon Upgrade, Orbiting Shield, Point Multiplier, Max Energy) — Phase 4b
- New galaxies, enemies, or bosses
- Production art or audio assets
- Score multiplier system

## Key Technical Decisions

- **Hitscan for Phase Laser** — no projectile entity, just a per-frame overlap test against all enemies in a vertical column
- **Shared charge pool** — simpler than tracking per-weapon charges, forces strategic choice between offensive and defensive secondary use
- **Separate Weapon Module item** — distinct from utility cycle, rarer drop, dedicated to weapon acquisition
- **Direct key mapping for secondaries** — no cycling through secondaries, instant access via Z/X/C
