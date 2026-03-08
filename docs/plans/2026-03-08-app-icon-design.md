# App Icon Design: Project 2043

## Summary

Programmatically generated app icon using Core Graphics, matching the game's procedural sprite rendering approach. No external assets required.

## Visual Design

**Subject:** Player ship — cyan diamond/chevron shape with glowing outline, matching SpriteFactory rendering style.

**Composition:**
- Ship centered, rotated ~15° clockwise for dynamic feel
- Deep space background (#0a0047) filling full icon canvas
- Radial cyan glow (#00ffd2 at ~20-30% opacity) behind the ship, mimicking the game's bloom post-processing
- 2-3 short thrust lines trailing from the ship's rear, cyan at decreasing opacity

**Colors (TokyoNight palette):**
- Background: #0a0047 (deep space)
- Ship outline/fill: #00ffd2 (player cyan)
- Glow: #00ffd2 radial gradient, fading out
- Thrust lines: #00ffd2 tapering to transparent

## Implementation Approach

- Swift script using Core Graphics to render 1024x1024 PNG
- Create AppIcon.appiconset in asset catalog with Contents.json
- Wire into both iOS and macOS targets via project.yml

## Design Rationale

- Procedural generation is consistent with how the game renders all sprites
- Single 1024x1024 source — Xcode generates all size variants
- Cyan-on-indigo color scheme pops on any home screen
- Slight tilt + thrust lines add dynamism without hurting readability at small sizes
- Radial glow references the game's bloom post-processing aesthetic
