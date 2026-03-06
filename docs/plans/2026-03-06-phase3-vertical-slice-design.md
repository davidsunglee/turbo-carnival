# Phase 3: Vertical Slice — Design

**Date:** 2026-03-06
**Approach:** Modular gameplay layer (Approach B)
**Prerequisite:** Phase 2 technical completion (complete)

## Overview

Minimal but complete implementation of every gameplay system from the spec, proving feasibility end-to-end. One galaxy (NGC-2043 Perimeter) with all four enemy tiers, two primary weapons, one secondary weapon, shoot-to-cycle items with two item types, scoring, parallax background, and a boss encounter. Everything renders as colored quads — no sprite art.

## New Components

### FormationComponent
Drives Tier 1 swarmer movement patterns. Stores: pattern type enum (vShape, sineWave, staggeredLine), phase offset, formation index. Computes velocity each frame, writes to PhysicsComponent.

### SteeringComponent
Drives Tier 2 bruiser semi-autonomous behavior. Stores: behavior enum (hover, strafe, leadShot), target reference, steer strength. Updates velocity based on player position.

### TurretComponent
For Tier 3 capital ship mounted structures. Stores: tracking speed, fire pattern enum, parent entity reference. Each turret is its own entity with its own HealthComponent, independent from the hull.

### BossPhaseComponent
Wraps GKStateMachine for multi-phase boss behavior. Stores: current phase index, phase health thresholds, attack pattern per phase.

### ItemComponent
For shoot-to-cycle power-ups. Stores: current cycle index, item type enum, bounce velocity. Advances cycle on projectile hit.

### ScoreComponent
Attached to enemies. Stores: point value awarded on kill.

## New Systems

### SpawnDirector
Master orchestrator for Galaxy 1. Drives encounter pacing based on scroll distance (not time). Maintains a queue of wave definitions: enemy type, formation pattern, spawn position, trigger distance. When scroll position crosses a threshold, spawns the next wave. At the end, locks scrolling and triggers boss.

### FormationSystem
Processes FormationComponent + PhysicsComponent. Computes velocity based on formation pattern (V-shape straight down, sine wave oscillation, parabolic arc). Entities still move via PhysicsSystem.

### SteeringSystem
Processes SteeringComponent + PhysicsComponent. Implements semi-autonomous behaviors for Tier 2 bruisers: hover (arrest forward momentum at Y threshold), strafe (horizontal movement relative to player), lead-shot (fire at predicted player position). Needs player position reference.

### ItemSystem
Processes ItemComponent. Handles: advancing cycle state on projectile hit (via collision), bounce off horizontal screen edges, slow downward drift, despawn timer. Spawns triggered by SpawnDirector when a full formation is destroyed or capital ship turrets are all down.

### ScoreSystem
When an enemy with ScoreComponent is destroyed, adds points to running total. Tracks current score. Feeds into HUD.

### BackgroundSystem
Manages two parallax scrolling layers. Distant stars (slow scroll) and mid-ground nebula elements (faster scroll). Wraps seamlessly. Outputs SpriteInstances rendered before gameplay sprites. Scroll speed is the master clock that SpawnDirector reads.

### BossSystem
Processes BossPhaseComponent. Manages state machine transitions based on health thresholds. Each phase defines: attack pattern, shield rotation speed, vulnerable windows. Triggers scroll-lock on entry, unlocks on defeat.

## Enemy Tier Designs

### Tier 1 — Swarmers (existing, enhanced)
- 1 HP, 24x24, pink (#f7768e), 10 points
- Patterns: V-formation, sine-wave, staggered-line via FormationComponent
- Fire slow, unguided orange projectiles when crossing Y threshold toward player's last-known X
- Full formation kill triggers item drop

### Tier 2 — Bruisers
- 2 HP, 32x32, brighter magenta
- Appear in pairs or triples, no large formations
- SteeringComponent: descend to hover Y-line, strafe horizontally, fire predictive bursts (lead player movement)
- 50 points

### Tier 3 — Capital Ship
- Composite entity: 1 indestructible hull (~280x120, dark blue-gray) + 3-4 turret entities
- Hull scrolls at 0.5x background speed
- Each turret: 3 HP, 20x20, TurretComponent tracks player, fires aimed patterns
- Destroying all turrets triggers item drop
- Hull has no HealthComponent — RenderComponent + TransformComponent only

### Tier 4 — Orbital Bulwark Alpha (Boss)
- ~80x80 central core, 30 HP total across phases
- Phase 1 (100-60% HP): Slow radial spreads, two rotating indestructible shield segments
- Phase 2 (60-30% HP): Faster aimed bursts, faster shield rotation, horizontal sweep laser
- Phase 3 (<30% HP): Dense radial + aimed combo, shields gone, core exposed
- Scroll locks on entry, unlocks on defeat
- 500 points

## Weapons

### Primary — Double Cannon (starting)
Two parallel projectiles, 6x12, 500 speed, 1 damage. Already implemented.

### Primary — Tri-Spread (acquired via item)
Three projectiles — one straight up, two angled +/-15 degrees. 0.7 damage per projectile. Same fire rate. Excellent coverage, lower focused DPS.

### Secondary — Grav-Bomb
3 charges max, starts with 1. Fires slow-moving gold orb (16x16) that detonates after 0.4 seconds or on contact. Creates circular hitbox (~120 radius) for 2 frames — kills Tier 1-2 instantly, deals 3 damage to turrets/boss. Visual: expanding ring in gold/white.

## Shoot-to-Cycle Items

Spawn conditions: full Tier 1 formation destroyed, or all turrets on capital ship destroyed.

| Cycle | Item | Visual | Effect |
|-------|------|--------|--------|
| 1 (default) | Energy Cell | Gold, 16x16 | Restores 15 energy |
| 2 | Weapon Module | Blue, 16x16 | Swaps to Tri-Spread or back to Double Cannon |

Physics: 40 units/sec downward drift, bounces off horizontal screen edges. Despawn after 8 seconds. Only 2 types for the slice.

## Scoring

- Tier 1: 10 pts, Tier 2: 50 pts, Tier 3 turret: 100 pts, Boss: 500 pts
- No multiplier system in the slice

## HUD

- Energy bar (existing, top-left area)
- Score counter (top-right)
- Grav-Bomb stock indicator (bottom-right)
- Current weapon indicator (bottom-center)

## Background and Level Flow

### Parallax Background
- Layer 1 — Deep stars: 2x2 dim white/blue dots, scroll at 20 units/sec, ~30-40 stars wrapping
- Layer 2 — Nebula wisps: 8x8 to 16x16 blobs, midground blue (#004687) at low alpha, scroll at 40 units/sec, 5-6 elements wrapping

### Galaxy 1 Encounter Flow (by scroll distance)

```
0-500:     Tutorial ramp — 3 Tier 1 V-formations, widely spaced
500-1200:  Tier 1 variety — sine-wave and staggered formations, first Tier 2 pair at 800
1200-2000: Escalation — mixed Tier 1 + Tier 2 waves, denser spacing
2000-2800: Capital Ship — hull scrolls through, 4 turrets active, Tier 1 swarms alongside
2800-3400: Final gauntlet — fast Tier 1 + Tier 2 combos
3500:      Scroll locks. Boss: Orbital Bulwark Alpha.
Boss defeated: Victory state (freeze + score display)
```

### Game Over
Energy hits 0: gameplay freezes, "GAME OVER" text sprite, score displayed. Restart by tap/keypress (reloads Galaxy1Scene).

## File Plan

### New Files (19)

```
Engine2043/Sources/Engine2043/
├── ECS/
│   ├── Components/
│   │   ├── FormationComponent.swift
│   │   ├── SteeringComponent.swift
│   │   ├── TurretComponent.swift
│   │   ├── BossPhaseComponent.swift
│   │   ├── ItemComponent.swift
│   │   └── ScoreComponent.swift
│   └── Systems/
│       ├── FormationSystem.swift
│       ├── SteeringSystem.swift
│       ├── ItemSystem.swift
│       ├── ScoreSystem.swift
│       ├── BackgroundSystem.swift
│       ├── BossSystem.swift
│       └── SpawnDirector.swift
├── Scene/
│   └── Galaxy1Scene.swift
```

### Modified Files
- `GameConfig.swift` — Gameplay constants (enemy stats, spawn thresholds, weapon values)
- `WeaponSystem.swift` — Support angled projectiles (Tri-Spread) and secondary fire (Grav-Bomb)
- `CollisionSystem.swift` — Additional collision response types for items, boss shields, blasts
- `Entity.swift` / `CollisionLayer` — Add layers: bossShield, blast, item (if not present)
- macOS/iOS `MetalView.swift` — Point to Galaxy1Scene instead of PlaceholderScene

### Untouched
- Rendering pipeline, shaders, SpriteBatcher, TextureAtlas
- PhysicsSystem (formations/steering just set velocity on PhysicsComponent)
- RenderSystem (everything is still SpriteInstances)
- AudioManager, InputManager, input providers
- GameEngine, GameTime, SceneManager

## Key Technical Decisions

- **Scroll distance as level clock** — deterministic pacing independent of frame rate
- **Formations set velocity, PhysicsSystem moves** — no parallel movement systems
- **Capital ship as composite entity** — hull + independent turret entities, not one monolith
- **Boss uses GKStateMachine** — clean phase transitions, per the original engine design
- **Colored quads only** — no art assets needed, visual differentiation via size/color/behavior
