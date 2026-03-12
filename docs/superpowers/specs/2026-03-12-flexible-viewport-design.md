# Flexible Viewport & Landscape Orientation

## Problem

The game uses a fixed 360x640 design space hardcoded throughout the codebase. This prevents landscape orientation on iOS and resizable windows on macOS.

## Decision

Introduce a `ViewportManager` that fixes the vertical extent (640 game units) and lets width flex with the screen's aspect ratio. Approach B (Viewport Manager + Adaptive Layout) from the brainstorming session.

## Requirements

- Ship continues to fly up in all orientations
- Fixed vertical view (640 game units), width expands with aspect ratio
- Aspect ratio clamped between 9:16 (~0.5625) and 21:9 (~2.333)
- Enemies mostly spawn in the original ~360-wide corridor, occasionally using wider space (soft expand)
- Touch controls use fixed-width zones (~180pt from each edge) with a dead zone in the middle
- Smooth animated transition (~0.3s lerp) when aspect ratio changes
- macOS windows become resizable with min/max aspect ratio constraints

## Architecture

### ViewportManager

New class in `Engine2043/Sources/Engine2043/Core/`.

**Responsibilities:**
- Owns the dynamic design space dimensions
- `designHeight` is fixed at 640 (the anchor)
- `currentDesignWidth` is computed: `designHeight * currentAspectRatio`
- `targetAspectRatio` is set by the platform layer when screen size changes
- `currentAspectRatio` lerps toward `targetAspectRatio` over ~0.3s per frame
- Aspect ratio clamped to `[9/16, 21/9]`
- Exposes: `currentDesignWidth`, `halfWidth`, `halfHeight`, `worldBounds` (as AABB)

**Access pattern:** Injected into scenes the same way `inputProvider` and `audioProvider` are — set as a property at scene creation time, passed to systems that need it.

**GameConfig.designWidth (360)** stays as a constant representing the "reference width" / core corridor width for soft-expand spawning logic. All actual viewport calculations go through ViewportManager.

### Renderer & Projection

- `Renderer` receives a `ViewportManager` reference at init
- `makeOrthographicProjection()` reads `viewportManager.currentDesignWidth` and `designHeight` each frame
- As aspect ratio animates, the projection smoothly widens/narrows the visible area
- No changes to the 4-pass pipeline, shaders, or bloom (they already handle arbitrary texture dimensions)

### Touch Input & Control Zones

**Fixed-width touch zones (~180pt from each edge):**
- Joystick zone: `loc.x < touchZoneWidth` (left edge)
- Button zone: `loc.x > screenSize.width - touchZoneWidth` (right edge)
- Middle is a dead zone (no input response, except tap-position for menus)

**Coordinate conversion:**
- Replace `GameConfig.designWidth` with `viewportManager.currentDesignWidth` in screen-to-game-space formulas in both `TouchInputProvider` and `KeyboardInputProvider`

**Button overlay layout:**
- Already anchors to edges (`bounds.width - margin`, `safeAreaInsets.left`), so it adapts naturally

### Scene & Gameplay Adaptation

All ~15 references to `GameConfig.designWidth` across Galaxy1Scene, PlaceholderScene, TitleScene, SteeringSystem, and ItemSystem are replaced with `viewportManager.currentDesignWidth`.

**Specific changes:**
- **World bounds:** Computed property from ViewportManager, not hardcoded AABB. Width expands, height stays fixed.
- **Player clamping:** `halfW` reads from viewport manager
- **Culling margins:** Dynamic width for X boundaries, fixed height for Y
- **Laser beam height, EMP flash size, screen-fill overlays:** Use dynamic width
- **SteeringSystem:** Enemy strafe boundaries use dynamic half-width
- **ItemSystem:** Item bounce boundaries use dynamic half-width
- **TitleScene attract mode:** Spawn positions and bounce boundaries use dynamic width

**Soft-expand spawning:**
- `GameConfig.designWidth` (360) defines the core corridor
- Enemies spawn mostly within that corridor
- World bounds and occasional spawns extend to full `currentDesignWidth`
- Extra width is visible but not saturated with enemies

### Background System

- Takes viewport width parameter instead of reading `GameConfig.designWidth`
- Star/nebula X positions generated across full `currentDesignWidth`
- Wrapping boundaries use dynamic width
- `fieldHeight` stays the same (`designHeight + 100`)
- Existing stars outside new bounds get repositioned on width change (visually imperceptible)

### iOS Platform Layer

- **Orientations:** Add `INFOPLIST_KEY_UISupportedInterfaceOrientations` to project.yml for all orientations
- **MetalView `layoutSubviews()`:** Compute aspect ratio from `bounds.size`, set `viewportManager.targetAspectRatio`
- **HUD insets:** Already converts safe area to game units via `designHeight`. Also account for left/right safe area insets mapped to dynamic width in landscape.
- **Touch zone width:** Constant ~180pt, not half-screen

### macOS Platform Layer

- **Resizable window:** Add `.resizable` to `styleMask`, remove hardcoded 540x960 dimensions
- **Minimum window size:** Enforce ~360x640 points (9:16)
- **Maximum aspect ratio:** Clamp at 21:9, either via window delegate or ViewportManager's internal clamp
- **Default window size:** 540x960 (same as current)
- **Resize events:** macOS MetalView `layout()` sets `viewportManager.targetAspectRatio`

## Files Changed

| File | Change |
|------|--------|
| `Engine2043/.../Core/ViewportManager.swift` | **New** — core viewport logic |
| `Engine2043/.../Core/GameConfig.swift` | designWidth stays as reference constant |
| `Engine2043/.../Rendering/Renderer.swift` | Projection uses ViewportManager |
| `Engine2043/.../Input/TouchInputProvider.swift` | Fixed-width zones, dynamic coord conversion |
| `Engine2043/.../Input/KeyboardInputProvider.swift` | Dynamic coord conversion |
| `Engine2043/.../Scene/Galaxy1Scene.swift` | ~10 refs → ViewportManager |
| `Engine2043/.../Scene/PlaceholderScene.swift` | ~4 refs → ViewportManager |
| `Engine2043/.../Scene/TitleScene.swift` | ~3 refs → ViewportManager |
| `Engine2043/.../ECS/Systems/SteeringSystem.swift` | Strafe bounds → ViewportManager |
| `Engine2043/.../ECS/Systems/ItemSystem.swift` | Bounce bounds → ViewportManager |
| `Engine2043/.../ECS/Systems/BackgroundSystem.swift` | Generation/wrapping → dynamic width |
| `Project2043-iOS/MetalView.swift` | Set viewport aspect ratio on layout |
| `Project2043-iOS/SceneDelegate.swift` | No changes needed |
| `Project2043-macOS/AppDelegate.swift` | Resizable window, min/max size |
| `Project2043-macOS/MetalView.swift` | Set viewport aspect ratio on layout |
| `project.yml` | Orientation keys, macOS window settings |

## Aspect Ratio Examples

| Device / Mode | Aspect Ratio | Design Width | Design Height |
|---------------|-------------|-------------|--------------|
| iPhone portrait | 9:16 (0.5625) | 360 | 640 |
| iPhone landscape | 16:9 (1.778) | 1138 | 640 |
| iPad portrait | 3:4 (0.75) | 480 | 640 |
| iPad landscape | 4:3 (1.333) | 853 | 640 |
| macOS default | 9:16 (0.5625) | 360 | 640 |
| macOS ultrawide | 21:9 (2.333) | 1493 | 640 |

## Animated Transition

When the aspect ratio changes (iOS rotation, macOS resize):
- `targetAspectRatio` updates instantly
- `currentAspectRatio` lerps toward target at a rate that covers the gap in ~0.3s
- All systems read `currentDesignWidth` each frame, so the visible area smoothly expands/contracts
- The projection matrix, world bounds, and culling all animate together
