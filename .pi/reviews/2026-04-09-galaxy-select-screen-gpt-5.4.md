# Workspace Review — feat/galaxy-select-screen

- Reviewer: subagent `reviewer`
- Model: `openai/gpt-5.4`
- Date: 2026-04-09
- Base: `0bfe82c1d61ffaa41d67161a2e0fd8ff8c3c50db`
- Head: `eda36a320eb0c552837260a0049e2e36a99004ae`
- Requirements context: `docs/superpowers/plans/2026-04-09-galaxy-select-screen.md`

### Strengths
- The overall implementation tracks the plan closely: `GalaxySelectScene`, `ProgressStore`, new `SceneTransition` cases, optional Galaxy 2/3 carryover, input extensions, and platform wiring are all present.
- Separation of concerns is mostly solid:
  - menu navigation was added as explicit `PlayerInput` fields instead of overloading movement
  - scene creation stays centralized in `SceneManager`
  - `ProgressStore` has a small, testable API
- The new scene reuses existing primitives well (`BitmapText`, `MenuInput`, `SceneManager`) instead of inventing a parallel UI stack.
- Test coverage is broad for the size of the change: glyph generation, input mappings, scene transitions/manager wiring, progress store behavior, and core galaxy select behavior all got tests.

### Issues

#### Critical (Must Fix)
- None found.

#### Important (Should Fix)

**1) Holding the start/confirm input can skip the galaxy select screen entirely**
- **File:** `Engine2043/Sources/Engine2043/Scene/TitleScene.swift:100`, `Engine2043/Sources/Engine2043/Scene/GalaxySelectScene.swift:79`, `Engine2043/Sources/Engine2043/Input/KeyboardInputProvider.swift:55`, `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift:80`
- **What's wrong:** `TitleScene` transitions on a level-triggered fire input, and `GalaxySelectScene` also launches on a level-triggered `primaryFire`. Because the input providers report held buttons continuously, holding Space / touch through the fade can cause the select scene to auto-launch Galaxy 1 on its first frame.
- **Why it matters:** This undermines the purpose of the new feature: users can accidentally bypass the galaxy select screen just by holding the same button a bit too long.
- **How to fix:** Make launch/back actions edge-triggered in `GalaxySelectScene` (fresh press only), or ignore menu/confirm input until all relevant buttons are released after scene entry. Add a regression test for “held input across Title → GalaxySelect transition”.

**2) iOS still does not actually support “tap to start” on the title screen**
- **File:** `Engine2043/Sources/Engine2043/Scene/TitleScene.swift:100,167`, `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift:107,116-131`, `Project2043-iOS/MetalView.swift:373`
- **What's wrong:** The title prompt says `TAP TO START`, but `TitleScene` only reacts to fire buttons. On iOS, `TouchInputProvider` only sets `primaryFire` for touches in the right-side control zone; center/left taps only populate `tapPosition`, which `TitleScene` ignores. Control overlays are hidden on non-game scenes, so there is no visible affordance explaining that only part of the screen works.
- **Why it matters:** This is a user-facing onboarding bug on iOS. The app can appear unresponsive unless the player happens to tap the invisible fire zone.
- **How to fix:** Let `TitleScene` accept `tapPosition != nil` as start input on iOS (or more generally on all platforms), or teach the touch input layer to expose a generic menu/select tap on non-game scenes. Add an iOS test for a center-screen tap starting from the title screen.

**3) Galaxy select’s iOS touch model cannot reliably distinguish tap-to-launch from swipe-to-select**
- **File:** `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift:107,150-154`, `Engine2043/Sources/Engine2043/Scene/GalaxySelectScene.swift:65-72,177`
- **What's wrong:** `TouchInputProvider` emits `tapPosition` immediately on `touchesBegan`, while swipe detection happens later in `touchesMoved`. `GalaxySelectScene` immediately treats `tapPosition` as a launch/hit-test action. So a touch-down on a menu item is effectively a launch on press, not a tap on release, and there is no cancellation path once the gesture becomes a swipe.
- **Why it matters:** The scene advertises `SWIPE TO SELECT  TAP TO LAUNCH`, but the current implementation makes those gestures ambiguous. On touch devices this can cause accidental launches when the user starts a swipe on or near an entry.
- **How to fix:** Move menu tap emission to touch-end with a movement threshold, or suppress/cancel `pendingTapPosition` once a swipe crosses threshold. Add a regression test where a touch begins on an entry and then moves >30pt before release.

#### Minor (Nice to Have)

**4) Progress persistence is still hard-wired to global `UserDefaults.standard` inside scenes**
- **File:** `Engine2043/Sources/Engine2043/Scene/Galaxy1Scene.swift:244`, `Engine2043/Sources/Engine2043/Scene/Galaxy2Scene.swift:315`, `Engine2043/Sources/Engine2043/Scene/Galaxy3/Galaxy3Scene.swift:258`, `Engine2043/Sources/Engine2043/Scene/GalaxySelectScene.swift:161`
- **What's wrong:** `ProgressStore` itself is injectable, but scene code directly reads/writes `.standard`.
- **Why it matters:** This makes scene tests and local runs share persistent state. It also makes future UI tests around cleared markers harder to isolate and can leak progress between runs.
- **How to fix:** Inject a progress-store abstraction or a `UserDefaults` instance through scene factories, defaulting to `.standard` in app code.

### Recommendations
- Add end-to-end navigation regression tests for:
  - held confirm across `TitleScene -> GalaxySelectScene`
  - iOS center-screen tap on the title scene
  - swipe beginning over a selectable galaxy row
- Normalize menu semantics around edge-triggered “confirm/back” events rather than raw held fire state.
- Consider injecting progress persistence through `SceneManager` factories to keep tests deterministic and avoid shared defaults state.

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The implementation is largely aligned with the plan and structurally sound, but there are still user-facing input issues in the new navigation flow—especially on iOS and around held confirm input—that should be addressed before calling it production-ready.
