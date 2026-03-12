# Title Screen, Game Over & Victory Screens Design

## Overview

Add three new scenes to the game flow: a title screen with attract mode, a game over screen with navigation options, and an expanded victory screen with stats. All rendered through the Metal pipeline with full post-processing. Transitions between scenes use a stylized CRT static/noise effect.

## Game Flow

```
TitleScene → Galaxy1Scene → GameOverScene → TitleScene / Retry
                          → VictoryScene  → TitleScene / Retry
```

## Title Screen (TitleScene)

- **Background**: Scrolling parallax starfield (reuse existing background system from Galaxy1Scene)
- **Attract mode**: Player ship autopiloting through the starfield, enemies drifting in formation patterns, projectiles firing — a scripted demo loop showcasing the game's visuals
- **Title text**: "PROJECT 2043" in large bitmap glyphs, centered upper third
- **Prompt**: "TAP TO START" (iOS) / "PRESS SPACE TO START" (macOS), blinking on/off cycle, lower third
- **Post-processing**: Full pipeline active (bloom, CRT scanlines, chromatic aberration)
- **Input**: Tap anywhere (iOS) or space/enter (macOS) starts the game

## Game Over Screen (GameOverScene)

- **Trigger**: Player health reaches 0 (replaces current 1.5s auto-restart)
- **Display**: "GAME OVER" in red bitmap text (#f7768e), centered
- **Score**: Final score in 8-digit format below title
- **Menu options** (bitmap text, tap/click targets):
  - "RETRY" — starts a fresh Galaxy1Scene
  - "TITLE SCREEN" — returns to TitleScene
- **Hit detection**: Touch/click position tested against text bounding rects
- **Post-processing**: Full pipeline active

## Victory Screen (VictoryScene)

- **Trigger**: Final boss defeated (or last galaxy completed)
- **Display**: "MISSION COMPLETE" in cyan bitmap text (#00ffd2), centered
- **Stats breakdown** (revealed sequentially with brief delays):
  - SCORE: 00012350
  - ENEMIES DESTROYED: 47
  - TIME: 03:22
- **Menu options** (same tap/click targets as game over):
  - "RETRY"
  - "TITLE SCREEN"
- **Colors**: Cyan title, gold (#e0af68) accent for stat labels
- **Post-processing**: Full pipeline active

## Stylized Transitions

- **Effect**: CRT static/noise burst — a brief (0.3–0.5s) frame where the screen fills with procedural noise/static, mimicking an old CRT switching channels
- **Implementation**: A transition pass in the Metal shader pipeline that blends procedural noise over the current frame, ramping from 0→1→0 intensity
- **Where it plays**: Between every scene change (title→game, game→game over, game→victory, any menu selection)

## Architecture

- **New scenes**: `TitleScene`, `GameOverScene`, `VictoryScene` — all conforming to the existing `GameScene` protocol
- **SceneManager**: Activate the existing but unused `SceneManager` to handle scene registry and transitions
- **Stat tracking**: Add `enemiesDestroyed` counter and `elapsedTime` tracker to Galaxy1Scene, passed to VictoryScene on completion
- **Hit testing**: New utility for mapping screen tap/click coordinates to bitmap text bounding rects
- **Transition system**: Renderer gets a transition state that drives the noise shader, controlled by SceneManager

## Decisions

- In-engine rendered (not native UI) — matches the game's retro-futuristic aesthetic
- Tap/click targets over joystick-cursor menus — more natural on mobile
- Expanded victory screen with stats (score, kills, time) — rewards completing the game
- CRT static transition — fits the retro-futuristic visual identity
