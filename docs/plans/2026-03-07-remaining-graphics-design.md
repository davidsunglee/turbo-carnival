# Remaining Graphics Design

Replace all placeholder colored quads (projectiles, pickups, effects, HUD) with procedurally generated sprite art.

## Approach: Dual-Texture System

- **Crisp atlas** (existing 512x512, AA off): projectile and pickup sprites added alongside entity sprites
- **Soft texture sheet** (new 256x256, AA on): effect overlays and HUD elements with smooth gradients
- Two draw calls per frame, split by texture slot — no shader changes needed

## Projectiles (Crisp Atlas)

| Weapon Type | Sprite ID | Size | Design |
|---|---|---|---|
| Double Cannon | `playerBullet` | 6x12 | Vertical elongated diamond, white core with cyan (#00ffd2) trailing edge |
| Tri-Spread | `triSpreadBullet` | 8x8 | Small rotated diamond, orange (#ff8033) outline, bright center |
| Vulcan AutoGun | `vulcanBullet` | 4x8 | Narrow dart, red (#ff3333) outline, white tip |
| Enemy Standard | `enemyBullet` | 8x8 | Downward-pointing arrowhead, hostile orange (#ff9e64) outline, dark fill |
| Gravity Bomb | `gravBomb` | 16x16 | Octagonal shell, gold (#ffda4d) outline, dark center, bright core dot |
| Laser Beam | (stays as quad) | 8xvar | Variable height — colored quad with bloom is sufficient |

## Pickups (Crisp Atlas)

| Type | Sprite ID | Size | Design |
|---|---|---|---|
| Energy Drop | `energyDrop` | 16x16 | Lightning bolt silhouette, gold (#e0af68) fill, white highlight line |
| Charge Cell | `chargeCell` | 16x16 | Hexagonal battery, purple (#9966ff) outline, segmented interior, bright core |
| Weapon Module | `weaponModule` | 20x20 | Diamond frame with crosshair/plus inside, blue (#4d80ff) outline. Tinted at runtime per weapon type via RenderComponent.color |

## Effects (Soft Sheet, AA On)

| Effect | Sprite ID | Size | Design |
|---|---|---|---|
| Grav Bomb Blast | `gravBombBlast` | 128x128 | Radial gradient ring — gold-white center fading to transparent gold at edges. Hollow center for shockwave look |
| EMP Flash | `empFlash` | 128x128 | Full radial gradient — cyan-white center fading to transparent blue. Scaled to screen size |
| Overcharge Glow | `overchargeGlow` | 64x64 | Soft diamond/star shape — orange-yellow center with transparent falloff. Echoes player ship silhouette |

## HUD (Soft Sheet, AA On)

| Element | Sprite ID | Size | Design |
|---|---|---|---|
| Energy Bar Frame | `hudBarFrame` | 64x8 | Rounded-rect border, cyan (#00ffd2) outline, transparent interior. Stretched to 120px at render |
| Energy Bar Fill | `hudBarFill` | 32x4 | Horizontal gradient pill, player cyan. Stretched dynamically by health fraction |
| Charge Pip | `hudChargePip` | 12x12 | Small octagon, gold outline, dark fill, bright center dot |
| Weapon Indicator | `hudWeaponIcon` | 16x8 | Small chevron pointing up, tinted per weapon type at runtime |
| Heat Gauge Frame | `hudHeatFrame` | 16x3 | Thin rounded-rect outline, neutral gray |
| Heat Gauge Fill | `hudHeatFill` | 14x2 | Simple gradient pill, tinted green-to-red at runtime |

Score bar stays as white quad. Game Over / Victory overlays are out of scope.

## Architecture

### New Files
- `EffectTextureSheet.swift` — 256x256 AA-on texture sheet, mirrors `TextureAtlas` API

### Modified Files
- `SpriteFactory.swift` — 11 new sprite methods + 6 HUD methods + `makeSoftContext` helper
- `TextureAtlas.swift` — layout entries and generators for 8 new crisp sprites
- `SpriteInstance.swift` — add `textureSlot: UInt8` field (default 0)
- `Galaxy1Scene.swift` — set spriteId + white color on spawns; update appendHUD; effect sprites use textureSlot 1
- Renderer draw call — split into two passes by texture slot

### Atlas Layouts

```
512x512 Crisp Atlas (AA off):
Row 0:    player(48x48)  swarmer(32x32)  bruiser(40x40)
Row 48:   capitalHull(140x60)            turret(24x24)
Row 108:  bossCore(64x64)  bossShield(40x12)
Row 172:  playerBullet(6x12)  triSpreadBullet(8x8)  vulcanBullet(4x8)
          enemyBullet(8x8)  gravBomb(16x16)
Row 188:  energyDrop(16x16)  chargeCell(16x16)  weaponModule(20x20)
(511,511): white 1x1 fallback

256x256 Soft Sheet (AA on):
Row 0:    gravBombBlast(128x128)  empFlash(128x128)
Row 128:  overchargeGlow(64x64)
Row 192:  hudBarFrame(64x8) hudBarFill(32x4) hudChargePip(12x12)
          hudWeaponIcon(16x8) hudHeatFrame(16x3) hudHeatFill(14x2)
```

### Test Coverage
- Unit tests for all new SpriteFactory methods (pixel count, dimensions, non-empty)
- Same pattern as existing SpriteFactoryTests.swift

### Not Changing
- Metal shaders
- Entity system architecture
- Game logic (spawn functions only change render properties)
- Laser beam (stays as colored quad)
- Score bar (stays as white quad)
- Game Over / Victory overlays
