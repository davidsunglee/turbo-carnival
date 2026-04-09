# Galaxy Select Screen

Add a galaxy select screen so players can start on any of the 3 galaxies. Accessed from the title screen, replaces the current direct-to-Galaxy-1 flow.

## Scene Flow

```
TitleScene  ──(fire)──▸  GalaxySelectScene  ──(fire)──▸  Galaxy1 / Galaxy2 / Galaxy3
                              ▴                                    │
                              └──────── (ESC / back) ◂─── GameOver/Victory → Title
```

- TitleScene is unchanged except its fire input triggers `.toGalaxySelect` instead of `.toGame`.
- GalaxySelectScene dispatches `.toGame`, `.toGalaxy2(nil)`, or `.toGalaxy3(nil)` depending on the player's selection.
- Starting a galaxy directly (skipping earlier ones) uses a fresh default loadout: double cannon, 0 score, 1 secondary charge, 0 shield drones.

## GalaxySelectScene

### Layout

All rendering uses the existing `BitmapText` system. Starfield background scrolls via `BackgroundSystem`.

| Element | Position | Style |
|---------|----------|-------|
| "SELECT GALAXY" | Top area | Scale 2.0, dim white |
| Galaxy entries (3) | Stacked vertically, centered | Highlighted = cyan (player color), others = dim white |
| `▸` cursor | Left of highlighted entry | Cyan, moves with selection |
| `*` cleared indicator | Right of entry name | Gold (item color), only on beaten galaxies. Uses ASCII `*` glyph to stay within BitmapText's glyph set. |
| Input hint (macOS) | Bottom | "UP/DOWN SELECT  SPACE LAUNCH  ESC BACK", dim, scale 1.0 |
| Input hint (iOS) | Bottom | "SWIPE TO SELECT  TAP TO LAUNCH", dim, scale 1.0 |
| "BACK" option (iOS) | Fixed Y position below the input hint | Dim white, tappable via `MenuInput.hitTest`, same pattern as GameOverScene menu items |

Each galaxy entry shows its number and name:
- GALAXY 1  NGC-2043 PERIMETER
- GALAXY 2  KAY'SHARA EXPANSE
- GALAXY 3  ZENITH ARMADA GRID

### Input

#### macOS
- **Up/down arrow keys** cycle the highlight (one step per press, not continuous).
- **Space** (primary fire) launches the highlighted galaxy.
- **ESC** returns to title screen.

#### iOS
- **Swipe up/down** cycles the highlight. A vertical swipe gesture (>30pt delta) maps to a discrete menu step.
- **Tap** on a galaxy entry launches it directly (via `MenuInput.hitTest`).
- **Tap "BACK"** returns to title screen.
- **No virtual joystick** — the joystick should not appear on menu screens.

### Navigation Behavior
- Selection wraps: down from Galaxy 3 goes to Galaxy 1, up from Galaxy 1 goes to Galaxy 3.
- A repeat guard prevents continuous scrolling when holding an arrow key — one move per key press, with a short repeat delay if held.

## Input Additions

Add three fields to `PlayerInput`:

```swift
public var menuUp: Bool = false
public var menuDown: Bool = false
public var menuBack: Bool = false
```

These are separate from gameplay movement so menu navigation is explicit.

- **KeyboardInputProvider**: arrow up/down map to `menuUp`/`menuDown`. ESC maps to `menuBack`.
- **TouchInputProvider**: vertical swipes (>30pt delta) map to `menuUp`/`menuDown`. No joystick rendering on menu screens. The `menuBack` is handled by tap on a "BACK" text option via `MenuInput.hitTest`.

## SceneTransition Changes

```swift
public enum SceneTransition: Sendable {
    case toGame
    case toTitle
    case toGalaxySelect              // NEW
    case toGameOver(GameResult)
    case toVictory(GameResult)
    case toGalaxy2(PlayerCarryover?) // changed: optional
    case toGalaxy3(PlayerCarryover?) // changed: optional
}
```

- `.toGalaxySelect` is new.
- `.toGalaxy2` and `.toGalaxy3` change from required to optional `PlayerCarryover`. When `nil`, the scene initializes with the default loadout.

## Galaxy Scene Changes

Galaxy2Scene and Galaxy3Scene currently require a `PlayerCarryover` parameter. Change this to optional:

- If `carryover` is `nil`: start with double cannon, 0 score, 1 secondary charge, 0 shield drones, 0 enemies destroyed, 0 elapsed time.
- If `carryover` is provided: use it as today (the normal progression path).

Each galaxy scene calls `ProgressStore.markCleared(galaxy:)` at the moment it triggers its victory transition — right where the `PlayerCarryover` is built and `requestedTransition` is set.

## SceneManager Changes

`SceneManager` needs to handle the new `.toGalaxySelect` transition by instantiating `GalaxySelectScene` and wiring up its `inputProvider`, `viewportManager`, and `sfx`.

For `.toGalaxy2(nil)` and `.toGalaxy3(nil)`, the scene factories must handle the optional carryover.

## ProgressStore

A `UserDefaults`-backed store for tracking which galaxies the player has cleared.

```swift
public enum ProgressStore {
    static func markCleared(galaxy: Int)
    static func isCleared(galaxy: Int) -> Bool
}
```

- Keys: `"galaxy1Cleared"`, `"galaxy2Cleared"`, `"galaxy3Cleared"` — all `Bool`, default `false`.
- `GalaxySelectScene` reads these on init to display `*` on cleared entries.
- Galaxy1Scene writes on boss defeat (at the `.toGalaxy2` transition).
- Galaxy2Scene writes on boss defeat (at the `.toGalaxy3` transition).
- Galaxy3Scene writes on boss defeat (at the `.toVictory` transition).
- iOS and macOS track progress independently (separate app containers). No cloud sync.

## What Does Not Change

- Attract mode on TitleScene (bouncing ship, enemies, projectiles) is untouched.
- Galaxy gameplay scenes are unchanged except for optional carryover and the `markCleared` call.
- Music: title music continues playing through the select screen. The Title → GalaxySelect transition must not restart or interrupt the playing music. No new track needed.
- The visual transition between screens continues to use the existing noise-based fade.
