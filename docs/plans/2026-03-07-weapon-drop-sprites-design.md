# Weapon Drop Sprite Redesign

## Problem
Weapon module drops use a single shared 20x20 diamond-with-crosshair sprite, differentiated only by color tint. Utility drops each have unique 24x24 silhouettes. This makes weapons harder to identify at a glance and visually inconsistent with utility drops.

## Goals
1. Resize weapon drop sprites from 20x20 to 24x24 (match utility drops)
2. Give each weapon type a unique, iconic silhouette readable without color

## Art Style
Bold filled shapes with white highlight strokes and subtle outer glow halo — same treatment as `energyDrop`. This makes weapons pop and visually distinguishes them from the outlined/geometric utility drop style.

## Sprite Designs (24x24 each)

| Weapon | Color | Silhouette |
|--------|-------|------------|
| doubleCannon | Light blue (0, 0.5, 1.0) | Two parallel vertical barrels side by side, bright dots at muzzle tips |
| triSpread | Magenta (1.0, 0, 0.2) | Three lines fanning upward from a common base point — trident/spread shape |
| lightningArc | Yellow (1.0, 1.0, 0) | Plasma ring — circle with 3-4 small jagged sparks radiating outward |
| phaseLaser | Cyan-green (0, 1.0, 0.2) | Focused beam line with lens circle at base, radiating lines at tip |

## Changes Required

### SpriteFactory.swift
- Remove `makeWeaponModuleSprite()`
- Add `makeDoubleCannonDrop()`, `makeTriSpreadDrop()`, `makeLightningArcDrop()`, `makePhaseLaserDrop()` — all 24x24

### TextureAtlas.swift
- Remove `weaponModule` entry (20x20)
- Add 4 entries: `weaponDoubleCannon`, `weaponTriSpread`, `weaponLightningArc`, `weaponPhaseLaser` — all 24x24
- Update `spriteNames` set accordingly

### ItemSystem.swift
- In weapon module branch, switch `render.spriteId` per `displayedWeapon` (like utility drops already do)

### Unchanged
- Color tinting per weapon type
- Drop behavior (drift, bounce, despawn)
- Projectile-hit cycling mechanic
