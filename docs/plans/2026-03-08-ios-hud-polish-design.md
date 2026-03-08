# iOS HUD Polish Design

## Problem

HUD elements (energy bar, score, charge pips, weapon icon) are positioned at fixed offsets from the design space edges (±320 game units), mapping to the physical screen edge. On iPhones with Dynamic Island/notch, the top HUD is obscured. Other issues: no persistent joystick visual, secondary buttons too far from primary, no numeric score, no weapon name feedback, no game over/victory screen.

## Changes

### 1. Safe Area-Aware HUD Positioning

Pass iOS safe area insets from `MetalView` into the engine as game-coordinate offsets. `Galaxy1Scene.appendEffectHUD` uses these to push HUD elements inward from screen edges. On macOS, insets are zero.

Conversion: screen-point insets → game-unit insets using the ratio `designHeight / screenHeight`.

### 2. Numeric Score (Bitmap Font)

Pre-render monospaced digit glyphs `0-9` into `EffectTextureSheet` via CoreGraphics. Each glyph ~6x8 pixels in the atlas. Render 8 zero-padded digits as individual sprite instances in `appendEffectHUD`. Replaces the current score bar. Gets full bloom/CRT treatment. Works on both platforms.

Format: `00012450` (8 digits, zero-padded).

### 3. Weapon Name Flash

Pre-render alphabet characters needed for weapon names (`A-Z`, space, hyphen) into the effect sheet. When `WeaponComponent.weaponType` changes, display the weapon name as bitmap text near the weapon icon for ~2 seconds, then fade out.

Weapon names: `DOUBLE CANNON`, `TRI-SPREAD`, `LIGHTNING ARC`, `PHASE LASER`.

### 4. Joystick Default Position

Show joystick base + knob at a default lower-left position (~60pt from left, ~60pt from bottom) at reduced opacity when idle. On touch in left half, relocate to touch point as before. On release, return to default position and dim back to idle opacity.

### 5. Secondary Button Spacing

Reduce `arcRadius` from 100pt to 85pt in `MetalView.layoutSubviews`.

### 6. Game Over / Victory Screen

When player health reaches 0 or boss is defeated:
- Dim the screen with a semi-transparent overlay (rendered as a full-screen sprite in the effect pass)
- Render "GAME OVER" or "VICTORY" as bitmap text, centered
- Show final 8-digit score below the title
- ~1.5 second delay before accepting input
- Tap (iOS) or any key (macOS) to restart

### 7. Energy Bar & Charge Pips

Already implemented in `appendEffectHUD`. The safe area fix (item 1) makes them visible by pushing them inward from the screen edges. No logic changes needed.
