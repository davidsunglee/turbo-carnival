# Utility Drop Items — Visual Overhaul + Orbiting Shield

**Date:** 2026-03-07
**Scope:** Redraw all utility drop sprites at 24x24, add Orbiting Shield item type

## 1. Visual Overhaul — 24x24 Sprites

All utility drop items move from 16x16 to 24x24 procedural sprites with distinct silhouettes per type.

| Item | Shape | Primary Color | Sprite ID |
|------|-------|---------------|-----------|
| Energy Cell | Lightning bolt (larger, more detailed) | Gold `#e0af68` | `energyDrop` |
| Charge Cell | Hexagonal battery (larger, more detail) | Purple `#9966ff` | `chargeCell` |
| Orbiting Shield | Cyan halo/concentric rings with center dot | Cyan `#00ffd2` | `shieldDrop` |

### Changes
- `GameConfig.Item.size` → `SIMD2<Float>(24, 24)`
- Redraw `SpriteFactory.makeEnergyDrop()` at 24x24
- Redraw `SpriteFactory.makeChargeCell()` at 24x24
- New `SpriteFactory.makeShieldDrop()` at 24x24
- Register `"shieldDrop"` in `TextureAtlas`
- Update bounce margin in `ItemSystem` from hardcoded `16 / 2` to use `GameConfig.Item.size`

## 2. Orbiting Shield — Entity Architecture

### Approach: Separate ECS Entities (Approach A)

Each shield drone is a full ECS entity with its own components, using the existing collision and render pipeline.

### New `ShieldDroneComponent`
- `ownerEntity: GKEntity` — weak reference to player
- `orbitAngle: Float` — current angle in radians
- `orbitSpeed: Float` — radians/sec (~3.14 rad/s = full circle every ~2s)
- `orbitRadius: Float` — distance from player center (25 units)
- `hitsRemaining: Int` — starts at 3

### New `ShieldDroneSystem`
- Updates each drone's `TransformComponent.position` = player position + `(cos(angle) * radius, sin(angle) * radius)`
- Increments `orbitAngle` by `orbitSpeed * deltaTime`
- When `hitsRemaining` reaches 0, marks drone for removal

### Collision Setup
- New `CollisionLayer.shieldDrone` (bit 7, `1 << 7`)
- Drone physics: layer = `.shieldDrone`, mask = `.enemyProjectile`
- Enemy projectiles need `.shieldDrone` added to their collision mask

### Shield Drone Visual
- 10x10 cyan circle sprite (`"shieldDrone"` in TextureAtlas)
- New `SpriteFactory.makeShieldDrone()` method

## 3. Collection & Stacking Behavior

### On pickup (`.orbitingShield` case in `handlePlayerCollectsItem`):
- Spawn 2 drone entities at player position
- If drones already exist, add 2 more (cap at 4 total)
- Redistribute ALL drone orbit angles evenly:
  - 2 drones: 0°, 180°
  - 3 drones: 0°, 120°, 240°
  - 4 drones: 0°, 90°, 180°, 270°

### On collision (drone absorbs enemy projectile):
- Decrement `hitsRemaining`
- Remove the enemy projectile
- Play `bossShieldDeflect` SFX (reuse existing)
- If `hitsRemaining == 0`, remove the drone entity

### On player death:
- Remove all shield drone entities

## 4. Integration Wiring

### UtilityItemType enum
```swift
public enum UtilityItemType: Int, CaseIterable, Sendable {
    case energyCell = 0
    case chargeCell = 1
    case orbitingShield = 2
}
```

The existing `advanceCycle()` and `utilityItemType` computed property use `CaseIterable.allCases.count`, so adding a new case automatically includes it in the cycle.

### Item sprite switching
`ItemSystem.update()` must update both `render.color` AND `render.spriteId` when cycling between types:
- `.energyCell` → color: `Palette.item`, spriteId: `"energyDrop"`
- `.chargeCell` → color: `Palette.chargeCell`, spriteId: `"chargeCell"`
- `.orbitingShield` → color: `Palette.shieldDrone`, spriteId: `"shieldDrop"`

### New GameConfig entries
```swift
public enum ShieldDrone {
    public static let orbitRadius: Float = 25
    public static let orbitSpeed: Float = 3.14
    public static let hitsPerDrone: Int = 3
    public static let maxDrones: Int = 4
    public static let droneSize = SIMD2<Float>(10, 10)
}
```

New palette entry:
```swift
public static let shieldDrone = SIMD4<Float>(0.0, 1.0, 210.0 / 255.0, 1.0)
```

## 5. Files Touched

1. `ItemComponent.swift` — add `.orbitingShield` enum case
2. `ItemSystem.swift` — update color/sprite switch, fix bounce margin
3. `GameConfig.swift` — update item size to 24x24, add ShieldDrone constants + palette
4. `Entity.swift` — add `.shieldDrone` collision layer
5. `SpriteFactory.swift` — redraw energy/charge at 24x24, add shield drop + shield drone sprites
6. `TextureAtlas.swift` — register `"shieldDrop"` and `"shieldDrone"` sprites
7. `Galaxy1Scene.swift` — shield drone spawning, collection handling, collision handling, cleanup
8. **New** `ShieldDroneComponent.swift`
9. **New** `ShieldDroneSystem.swift`
