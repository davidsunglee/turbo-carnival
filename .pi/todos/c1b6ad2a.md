{
  "id": "c1b6ad2a",
  "title": "Implement Galaxy 2: The Kay'Shara Expanse",
  "tags": [
    "feature",
    "gameplay",
    "galaxy2"
  ],
  "status": "done",
  "created_at": "2026-04-07T02:21:23.319Z"
}

## Overview

Implement the second galactic sector, representing a significant difficulty ramp over Galaxy 1. The Kay'Shara Expanse introduces environmental hazards (asteroids) as a core gameplay mechanic, fundamentally changing how the player engages with enemies and navigates the screen.

## Scene Flow & Progression

- Galaxy 2 starts **automatically** after the Galaxy 1 boss is defeated (no stage select)
- Add **galaxy title cards** for both galaxies for consistency:
  - "Galaxy 1: NGC-2043 Perimeter" before Galaxy 1 enemies begin
  - "Galaxy 2: Kay'Shara Expanse" before Galaxy 2 enemies begin
- Requires a new scene transition type or in-scene state to handle G1 → G2 continuity

## Player State Carryover (G1 → G2)

- **Keep:** current weapon, score, shields (shield drones)
- **Secondary charges:** keep if > 1, otherwise reset to 1
- **Energy:** start with full 100
- Speed upgrades: carry over if implemented

## Aesthetic Profile

- Background shifts from deep space (#0a0047) to **deep bruised violet and dark magenta**
- Dense **asteroid belts** and **volatile particle clouds**
- Reduced contrast compared to Galaxy 1 to increase tension
- Parallax scrolling through asteroid layers

## Environmental Hazards: Asteroids

The signature mechanic of Galaxy 2:

### Collision Rules
- **Block player projectiles** (absorbed on contact)
- **Do NOT block enemy energy weapons** (pass through)
- **Player ship collision = kinetic damage** (15-20 energy points, same as enemy hull collision)

### Spawning
- **Sparse background asteroids** scattered throughout, scrolling with background
- **Occasional dense fields** triggered by scroll distance (like wave definitions)
- Both layers combined for visual variety and gameplay pacing

### Destructibility
- **Small asteroids:** destructible, ~2-3 HP. Rewards aggressive path-clearing, gives Phase Laser a natural tactical advantage (piercing)
- **Large asteroids:** fully indestructible, must navigate around. Core repositioning hazard

## Adversarial Profile

### Tier 1: Armored Interceptor Variants
- Still die in **one hit** (1.0 HP)
- Feature **smaller hitboxes** (harder to hit)
- Same formation-based behavior (V-shapes, arcs, sine waves)

### Tier 2: Smarter Fighters
- 2.0–2.5 HP (same as Galaxy 1 Tier 2)
- **Smarter/harder** than Galaxy 1 variants — more aggressive steering, better predictive fire
- Flavor: operate around asteroid fields but no literal cover-seeking AI needed

### Tier 3: Mining Barges
- Heavily armored mining barges that **take up 60% of horizontal screen space**
- Indestructible main chassis with modular destructible structures (3.0–4.0 HP each)
- Slower vertical scroll multiplier (parallax effect)
- Turrets with independent player-tracking algorithms

## Sector Boss: The Lithic Harvester

A heavily armored mining dreadnought that manipulates the local asteroid environment.

### Defensive Mechanics
- Uses **visible tractor beams** (rendered line/beam effect) to pull in floating asteroids
- Creates a **dynamic, physical ablative armor layer** around itself
- Player must chip away asteroid armor using piercing weapons (Phase Laser is ideal)

### Offensive Mechanics
- Launches **high-velocity kinetic asteroid fragments** at the player
- Fires **sporadic, predictive energy bursts**
- Multi-phase attack patterns per the general boss design spec

### Arena
- Background scroll halts upon engagement (standard boss behavior)
- Player locked in fixed 2D arena until boss is destroyed

## Music

- Galaxy 2 needs a **distinct MP3 track** (not reusing Galaxy 1's)
- Suggested prompt for Gemini/Lyria generation:
  > Synthwave instrumental track, 95-105 BPM, darker and more brooding than a standard arcade theme. Heavy detuned sawtooth bass, reverb-drenched snare on beats 2 and 4, minor key. Atmosphere of drifting through a dangerous asteroid field — tension building, percussive hits synced to imagined impacts. Less melodic than a title theme, more textural and rhythmic. Think Carpenter Brut meets deep space mining operation. No vocals. 2-3 minutes, loopable.

## Gameplay Focus

- Navigating environmental hazards is the core skill test
- Weapon choice matters more: Phase Laser excels against boss armor and small asteroids, Tri-Spread struggles with asteroid obstruction
- Item cycling is more dangerous due to asteroid hazards during collection

## Reference

Extracted from `Project 2043 Specification.md`, section "Galaxy 2: The Kay'Shara Expanse". See also Adversarial AI, Arsenal Architecture, and Energy Attrition sections for cross-cutting mechanics.

Completed via plan: .pi/plans/done/2026-04-07-galaxy2-kayshara-expanse.md
