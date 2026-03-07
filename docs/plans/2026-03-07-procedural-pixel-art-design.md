# Procedural Pixel Art Sprites Design

## Overview

Replace all placeholder rectangle visuals for the player ship and enemy entities with procedurally generated pixel art sprites. Sprites are created at runtime by painting individual pixels into RGBA buffers, then packed into a texture atlas for GPU rendering.

## Scope (Phase 1)

Player ship and all enemy types:
- Player ship (30x30, 2 frames)
- Enemy Tier 1 — Swarmers (24x24, 2 frames)
- Enemy Tier 2 — Bruisers (32x32, 2 frames)
- Enemy Tier 3 — Capital Ships (280x120, 2 frames)
- Boss (80x80, 2 frames)

Projectiles, items, and effects remain as colored rectangles for now.

## Art Style

- Detailed shading (Gradius/R-Type feel) — no outlines, highlights and shadows create form
- Metallic hulls with glowing engines
- TokyoNight color palette
- Vertically symmetric (mirrored left-right) to halve painting work
- 2-frame idle animation: thruster flicker (alternating glow intensity/length)

## Sprite Resolutions

Match existing entity sizes to preserve gameplay feel and collision tuning:
| Entity | Size | Frames |
|--------|------|--------|
| Player | 30x30 | 2 |
| Swarmer | 24x24 | 2 |
| Bruiser | 32x32 | 2 |
| Capital Ship | 280x120 | 2 |
| Boss | 80x80 | 2 |

## Sprite Descriptions

### Player Ship (30x30)
Top-down fighter with pointed nose, swept-back delta wings, central fuselage.
- Hull: Dark teal (#1a9c8a) with cyan highlights (#00ffd2) along nose ridge and wing edges
- Cockpit: Small bright pixel cluster near nose tip
- Engine: 2-3px thruster port at tail in orange/yellow
- Frame 2: Thruster glow alternates orange/bright yellow, extends 1-2px further

### Enemy Tier 1 — Swarmers (24x24)
Small insectoid aggressors.
- Body: Compact diamond/dart shape in dark magenta (#a0354a) with pink highlights (#f7768e)
- Wings: Two small angular fins
- Engine: Small pink-white thruster glow at rear
- Frame 2: Thruster flicker

### Enemy Tier 2 — Bruisers (32x32)
Heavier armored fighters.
- Body: Wider, bulkier angular wedge in dark blue (#2040a0) with steel-blue highlights (#7aa2f7)
- Armor plates: Darker shading on flanks suggesting layered plating
- Engines: Dual thruster ports, brighter blue glow
- Frame 2: Thruster flicker

### Enemy Tier 3 — Capital Ship (280x120)
Massive carrier/destroyer.
- Hull: Long dreadnought shape with stepped geometry, bridge at center, tapered bow
- Surface detail: Panel lines, antenna arrays, darker recessed sections
- Turret mounts: Highlighted hardpoints at turret positions
- Engines: Array of 4-5 thruster ports across stern, orange-yellow glow
- Frame 2: Engine flicker across all thrusters

### Boss (80x80)
Imposing command ship.
- Body: Symmetrical hexagonal/octagonal core, heavily armored
- Details: Layered hull plating with dark seams, red/orange weapon ports, central bridge in bright contrasting color
- Engine: Wide thruster bank across bottom
- Frame 2: Thruster and weapon port glow pulse

## Architecture

### New Components

1. **`PixelCanvas`** — Wraps `[UInt8]` RGBA buffer with drawing primitives:
   - `setPixel(x, y, color)`
   - `hLine(x, y, length, color)`, `vLine(x, y, length, color)`
   - `fillRect(x, y, w, h, color)`
   - `mirrorHorizontally()` — copies left half to right half (flipped)

2. **`SpriteGenerator`** — One function per entity type returning `[PixelCanvas]` (array of 2 for animation frames). All sprites are painted programmatically.

3. **Texture atlas packing** — All generated canvases packed into a single power-of-2 texture (512x512). `TextureAtlas` stores a dictionary mapping sprite names to UV rects.

### Modified Components

4. **`RenderComponent`** — Add optional `textureId: String?`. When nil, falls back to white pixel (backward compat for projectiles/items/effects).

5. **`SpriteInstance` struct** — Add `uvOffset: SIMD2<Float>` and `uvScale: SIMD2<Float>` fields for atlas sampling.

6. **`Sprite.metal` fragment shader** — Use per-instance UV offset/scale to sample the correct atlas region.

7. **`SpriteBatcher`** — Pass UV data through with instance data.

8. **`RenderSystem`** — Look up UV rects from atlas when building sprite instances.

### Data Flow

```
Startup:
  SpriteGenerator.generateAll()
    -> [PixelCanvas] per entity type (2 frames each)
    -> TextureAtlas.packAll() -> single Metal texture + UV rect dictionary

Runtime:
  Entity spawn -> RenderComponent(textureId: "player_0")
  RenderSystem -> looks up UV rect for textureId
  SpriteBatcher -> includes uvOffset/uvScale in SpriteInstance
  Sprite.metal -> samples atlas texture at UV region
  Animation: frame counter at ~4-5 FPS toggles _0/_1 suffix
```

## Testing

- Unit tests for `PixelCanvas` drawing primitives (verify expected pixel values)
- Unit test for atlas packing (all sprites fit, no overlap)
- Visual verification by running the game
