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
- Touch controls use fixed-width zones (180pt from each edge) with a dead zone in the middle
- Smooth animated transition (~0.3s) when aspect ratio changes
- macOS windows become resizable with min/max aspect ratio constraints

## Architecture

### ViewportManager

New class in `Engine2043/Sources/Engine2043/Core/`.

**Ownership:** A single instance, owned by the platform layer (MetalView on iOS, AppDelegate/MetalView on macOS). Shared across all scenes — not created per-scene.

**Responsibilities:**
- Owns the dynamic design space dimensions
- `designHeight` is fixed at 640 (the anchor)
- `currentDesignWidth` is computed: `designHeight * currentAspectRatio`
- `targetAspectRatio` is set by the platform layer when screen size changes
- `currentAspectRatio` chases `targetAspectRatio` using exponential decay: `current = mix(current, target, 1 - exp(-dt * speed))` where `speed ≈ 12` gives a half-life of ~0.06s (effectively reaches target in ~0.3s). This is a continuous chase with no fixed timer — retargeting mid-animation is free.
- Aspect ratio clamped to `[9/16, 21/9]`
- Exposes: `currentDesignWidth`, `halfWidth`, `halfHeight`, `worldBounds` (as AABB)
- `update(dt:)` method called once per frame to advance the interpolation
- When `abs(current - target) / target < 0.001`, snap to target (avoid perpetual micro-updates)

**Pause/resume:** If the app is backgrounded and resumed with a stale `currentAspectRatio`, the first frame may have a large `dt`. Clamp `dt` to `maxFrameTime` (already done by GameEngine) so the exponential decay doesn't overshoot. Alternatively, if `abs(target - current)` exceeds a threshold (e.g., 0.5), snap instantly rather than animating.

**Access pattern:** Systems that need the viewport width read it from a `viewportManager` property on their owning scene. Each concrete scene type declares a `viewportManager` property (same pattern as `inputProvider` — per-scene, not in the `GameScene` protocol). The `SceneManager` factory closures set `viewportManager` on each scene at creation time, just as they set `inputProvider` today. Systems receive it either:
- As a parameter to their `update()` method (preferred for stateless reads like culling, clamping, steering)
- As an init parameter (for BackgroundSystem, which needs the width at generation time — see below)

**GameConfig.designWidth (360)** stays as a constant representing the "reference width" / core corridor width for soft-expand spawning logic. All actual viewport calculations go through ViewportManager.

### Renderer & Projection

- `Renderer` receives a `ViewportManager` reference at init
- `makeOrthographicProjection()` reads `viewportManager.currentDesignWidth` and `designHeight` each frame
- As aspect ratio animates, the projection smoothly widens/narrows the visible area
- The transition animation affects only the orthographic projection (game-space visible area), not the drawable/texture dimensions, which change immediately on layout via `metalLayer.drawableSize`
- No changes to the 4-pass pipeline, shaders, or bloom (they already handle arbitrary texture dimensions)

### Touch Input & Control Zones

**Fixed-width touch zones (180pt from each edge):**
- Joystick zone: `loc.x < 180` (left edge)
- Button zone: `loc.x > screenSize.width - 180` (right edge)
- Middle is a dead zone (no input response, except tap-position for menus)
- In narrow portrait mode (screen width < 360pt), both zones shrink proportionally: `touchZoneWidth = min(180, screenSize.width / 2)` to prevent overlap
- **Behavioral change from current code:** The current implementation splits the screen in half (`loc.x < screenSize.width / 2`). With 180pt fixed zones, the joystick zone shrinks significantly in landscape (from ~406pt to 180pt on a typical iPhone) and users can no longer start a joystick touch near screen center. This is intentional — it prevents accidental input in the wide landscape dead zone.

**Coordinate conversion:**
- Replace `GameConfig.designWidth` with `viewportManager.currentDesignWidth` in screen-to-game-space formulas in both `TouchInputProvider` and `KeyboardInputProvider`

**Button overlay layout:**
- Already anchors to edges (`bounds.width - margin`, `safeAreaInsets.left`), so it adapts naturally

**Rotation with active touches:** UIKit delivers `touchesCancelled` for all active touches on rotation, which `TouchInputProvider.cancelTouches` already handles. After rotation, the new zone boundaries apply immediately.

### Scene & Gameplay Adaptation

All references to `GameConfig.designWidth` across Galaxy1Scene, PlaceholderScene, TitleScene, GameOverScene, VictoryScene, SteeringSystem, and ItemSystem are replaced with `viewportManager.currentDesignWidth`.

**Specific changes:**
- **World bounds:** Computed property from ViewportManager, not hardcoded AABB. Width expands, height stays fixed.
- **Player clamping:** `halfW` reads from viewport manager
- **Culling margins:** Dynamic width for X boundaries, fixed height for Y
- **Laser beam height:** Uses dynamic width where applicable (height calculation already uses designHeight, which is unchanged)
- **EMP flash size:** Currently uses `SIMD2(designWidth, designHeight)` (1x, not 2x). At 21:9 the viewport is 1493 wide but the flash would only be 360 wide. Change to `SIMD2(currentDesignWidth, designHeight)` to cover the full viewport.
- **Screen-fill overlays:** Game-over and victory tint overlays currently use `designWidth * 2` which is 720. At 21:9 the viewport is 1493 wide, so these must use `currentDesignWidth * 2` to avoid visible gaps.
- **SteeringSystem:** Enemy strafe boundaries use dynamic half-width
- **ItemSystem:** Item bounce boundaries use dynamic half-width
- **TitleScene attract mode:** Spawn positions and bounce boundaries use dynamic width

**Soft-expand spawning rules:**
- `GameConfig.designWidth` (360) defines the core corridor
- `SpawnDirector` wave definitions have hardcoded `spawnX` values (e.g., -60, 50, -40, -80) — these all fall within the 360-wide corridor and require no change
- World bounds extend to full `currentDesignWidth`
- Tier 1 and Tier 2 enemies spawn within the 360-wide corridor (existing behavior unchanged)
- Items drift and bounce within the full `currentDesignWidth` bounds
- Background elements (stars, nebulae) fill the full width
- Boss and capital ship spawning centered at X=0, unaffected by width changes
- Future enhancement: allow tier 1 stragglers to occasionally spawn in the extended area

**HUD insets:**
- Current `hudInsets` type is `(top: Float, bottom: Float)`. Expand to `(top: Float, bottom: Float, left: Float, right: Float)`.
- In landscape on notched iPhones, `safeAreaInsets.left`/`.right` are significant. Convert to game units using `currentDesignWidth / screenWidth`.
- HUD elements anchor relative to viewport edges minus insets: energy bar (upper left, inset from left), score (upper center), charge pips (upper right, inset from right).

### Background System

- `BackgroundSystem` generates stars/nebulae across the **maximum possible width** (1493 game units, the 21:9 limit) at init time. This avoids regeneration on resize and the seed-based PRNG positions remain stable.
- Only stars within the current `currentDesignWidth` viewport are visible — the rest exist but are off-screen.
- Wrapping boundaries use the maximum width so positions stay consistent.
- `fieldHeight` stays the same (`designHeight + 100`).
- This approach means `BackgroundSystem.init()` does not need the ViewportManager — it always generates for the widest case.

### iOS Platform Layer

- **Orientations:** Add `INFOPLIST_KEY_UISupportedInterfaceOrientations` to project.yml for all orientations (portrait, landscape left, landscape right, portrait upside down)
- **MetalView `layoutSubviews()`:** Compute aspect ratio from `bounds.size`, set `viewportManager.targetAspectRatio`
- **HUD insets:** Convert all four safe area insets to game units
- **Touch zone width:** Constant 180pt, with proportional fallback for narrow screens

### macOS Platform Layer

- **Resizable window:** Window already has `.resizable` in its style mask. Add `window.minSize` and `window.maxSize` (or use `NSWindowDelegate.windowWillResize(_:to:)`) to enforce aspect ratio constraints.
- **Default window size:** 540x960 (same as current), user can resize from there
- **Minimum size:** ~360x640 points
- **Maximum aspect ratio:** Clamped at 21:9 via ViewportManager's internal clamp (window can be any shape, viewport clamps internally)
- **Resize events:** macOS MetalView `layout()` sets `viewportManager.targetAspectRatio`

## Files Changed

| File | Change |
|------|--------|
| `Engine2043/.../Core/ViewportManager.swift` | **New** — core viewport logic |
| `Engine2043/.../Core/GameConfig.swift` | designWidth stays as reference constant |
| `Engine2043/.../Rendering/Renderer.swift` | Projection uses ViewportManager |
| `Engine2043/.../Input/TouchInputProvider.swift` | Fixed-width zones, dynamic coord conversion |
| `Engine2043/.../Input/KeyboardInputProvider.swift` | Dynamic coord conversion |
| `Engine2043/.../Scene/Galaxy1Scene.swift` | designWidth refs → ViewportManager |
| `Engine2043/.../Scene/PlaceholderScene.swift` | designWidth refs → ViewportManager |
| `Engine2043/.../Scene/TitleScene.swift` | designWidth refs → ViewportManager |
| `Engine2043/.../Scene/GameOverScene.swift` | BackgroundSystem uses max width |
| `Engine2043/.../Scene/VictoryScene.swift` | BackgroundSystem uses max width |
| `Engine2043/.../ECS/Systems/SteeringSystem.swift` | Strafe bounds → ViewportManager |
| `Engine2043/.../ECS/Systems/ItemSystem.swift` | Bounce bounds → ViewportManager |
| `Engine2043/.../ECS/Systems/BackgroundSystem.swift` | Generate at max width, wrap at max width |
| `Engine2043/.../Scene/SceneManager.swift` | Factory closures set viewportManager on each scene |
| `Project2043-iOS/MetalView.swift` | Set viewport aspect ratio on layout, 4-field HUD insets |
| `Project2043-macOS/AppDelegate.swift` | Min/max window size constraints |
| `Project2043-macOS/MetalView.swift` | Set viewport aspect ratio on layout |
| `project.yml` | Orientation keys |
| `Engine2043/Tests/.../*Tests.swift` | Tests referencing designWidth or dependent on strafe/bounce boundaries need viewport mock (at minimum ItemSystemTests, SteeringSystemTests) |

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
- `currentAspectRatio` chases target via exponential decay (`speed ≈ 12`), effectively reaching target in ~0.3s
- Retargeting mid-animation is free (no timer to restart)
- If delta exceeds 0.5 (e.g., after app resume), snap instantly
- All systems read `currentDesignWidth` each frame, so the visible area smoothly expands/contracts
- The animation is purely in projection space — drawable pixel dimensions change immediately on layout, the projection matrix animates the game-space visible area within those fixed pixels
