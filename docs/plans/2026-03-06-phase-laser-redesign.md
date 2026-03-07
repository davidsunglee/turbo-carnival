# Phase Laser Redesign: Sustained Melter

**Goal:** Replace burst/cooldown Phase Laser with continuous beam + overheat mechanic.

## Mechanic

Hold fire for continuous hitscan beam. Heat builds while firing, cools while not firing. Overheat triggers brief forced cooldown.

## Stats

- Damage: 1.0 per tick, tick interval 0.1s (10 DPS raw, ~8 effective with overheat)
- Heat: builds at 1.0/sec while firing, max 1.0
- Cooling: dissipates at 2.0/sec while not firing
- Overheat: 1.0s forced cooldown, heat resets to 0
- Release before overheat: heat cools naturally, no penalty

## Changes

- WeaponComponent: replace burst/cooldown state with heat/overheat state
- GameConfig: update laser constants (remove burst/cooldown, add heat values)
- WeaponSystem: rewrite laser branch — continuous firing with heat accumulation
- Galaxy1Scene HUD: heat gauge replaces burst/cooldown bar
