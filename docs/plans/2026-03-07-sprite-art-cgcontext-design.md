# Sprite Art via CGContext Design

## Overview

Replace placeholder colored-quad visuals for player ship and enemy entities with procedurally generated pixel art sprites. Sprites are drawn at runtime using `CGContext` with anti-aliasing disabled, producing crisp geometric/abstract neon designs. Packed into a single texture atlas for GPU rendering.

## Scope

Player ship and all enemy types only:
- Player ship
- Enemy Tier 1 -- Swarmers
- Enemy Tier 2 -- Bruisers
- Enemy Tier 3 -- Capital Ship (hull + turrets)
- Boss -- Orbital Bulwark Alpha (core + shield segments)

Projectiles, power-ups, background elements, and effects remain as colored quads.

## Art Style

- Geometric/abstract neon constructs -- clean shapes, glowing outlines, bright cores
- No attempt at realism; lean into the TokyoNight aesthetic
- Anti-aliasing disabled in CGContext for crisp pixel edges
- Post-processing (bloom, CRT scanlines, chromatic aberration) enhances the neon glow

## Sprite Resolutions

Higher-res than current entity sizes for visual detail:

| Entity | Sprite Size | Current Quad Size | Notes |
|--------|-------------|-------------------|-------|
| Player Ship | 48x48 | 30x30 | Diamond/chevron shape |
| Swarmer | 32x32 | 24x24 | Downward-pointing dart |
| Bruiser | 40x40 | 32x32 | Hexagonal body |
| Capital Hull | 140x60 | 280x120 | Drawn at half-res, displayed at 2x |
| Turret | 24x24 | 20x20 | Octagonal ring |
| Boss Core | 64x64 | 80x80 | Concentric geometric rings |
| Boss Shield | 40x12 | 40x12 | Elongated bar |

## Sprite Descriptions

### Player Ship (48x48)
Diamond/chevron shape pointing upward. Two angled lines forming a V-hull. Dark interior with bright cyan (#00ffd2) outline and edges. Glowing engine trail at bottom (lighter cyan core fading to transparent). Small bright dot at center as cockpit/core.

### Tier 1 Swarmer (32x32)
Downward-pointing triangle/dart shape. Pink/magenta (#f7768e) outline with darker fill. Single bright pixel cluster at center as energy core.

### Tier 2 Bruiser (40x40)
Hexagonal body conveying armored mass. Blue-cyan (#6490c0) outline with thicker edges. Two small turret dots on the sides. Brighter core at center.

### Tier 3 Capital Ship Hull (140x60)
Long rectangular hull with angular cutouts at edges (not a plain rectangle). Dark gray-blue (#323250) fill with subtle lighter panel lines suggesting structure.

### Tier 3 Turrets (24x24)
Small octagon or circle with bright orange-red (#ff6633) ring. Dark center with bright dot suggesting barrel.

### Boss Core (64x64)
Concentric geometric rings -- outer ring, inner ring, bright center. Blue (#4499ff) outer glow, brighter white-blue center. Angular/faceted edges (octagon or diamond, not smooth circle).

### Boss Shield Segments (40x12)
Elongated bar with rounded-rect shape. Light cyan (#99ccff) with brighter edge highlights. Lighter interior suggesting semi-transparency.

## Architecture

### New File: `SpriteFactory.swift`

Static class in `Rendering/`. One method per entity type.

Each method:
1. Creates a `CGContext` at the target pixel resolution (RGBA8, 4 bytes/pixel)
2. Disables anti-aliasing (`setShouldAntialias(false)`, `interpolationQuality = .none`)
3. Draws the entity design using Core Graphics paths, arcs, filled rects, strokes
4. Returns raw `[UInt8]` pixel data via `context.data`

Methods:
- `makePlayerShip() -> [UInt8]`
- `makeSwarmer() -> [UInt8]`
- `makeBruiser() -> [UInt8]`
- `makeCapitalHull() -> [UInt8]`
- `makeTurret() -> [UInt8]`
- `makeBossCore() -> [UInt8]`
- `makeBossShield() -> [UInt8]`

### Modified File: `TextureAtlas.swift`

At init time:
1. Call `SpriteFactory` to generate all 7 sprites
2. Create a single 512x512 `MTLTexture` (RGBA8Unorm)
3. Blit each sprite's pixel data into its designated region
4. Store UV rects as `SIMD4<Float>` (u, v, width, height) normalized to 0-1
5. Retain the 1x1 white pixel at (511, 511) as fallback

Atlas layout (simple grid, no bin-packing needed):

| Sprite | Size | Position |
|--------|------|----------|
| Player Ship | 48x48 | (0, 0) |
| Swarmer | 32x32 | (48, 0) |
| Bruiser | 40x40 | (80, 0) |
| Capital Hull | 140x60 | (0, 48) |
| Turret | 24x24 | (140, 48) |
| Boss Core | 64x64 | (0, 108) |
| Boss Shield | 40x12 | (64, 108) |
| White 1x1 | 1x1 | (511, 511) |

### Modified File: `Galaxy1Scene.swift`

When spawning entities, assign the correct UV rect from the atlas. Set `color` to white (1,1,1,1) so sprite colors render as drawn by CGContext.

### Sampler State

Ensure texture sampler uses `minFilter = .nearest`, `magFilter = .nearest` to preserve pixel art crispness.

### What Doesn't Change

- Metal shaders (already sample texture * color)
- SpriteBatcher (already supports uvRect per instance)
- RenderComponent struct
- Post-processing pipeline
- Gameplay logic or collision sizes

## Testing

- Unit tests for `SpriteFactory` (verify returned buffer sizes, non-empty pixel data)
- Unit test for atlas packing (all sprites fit within 512x512, no overlap)
- Visual verification by running the game
