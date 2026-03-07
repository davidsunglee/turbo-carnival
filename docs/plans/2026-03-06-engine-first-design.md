# Project 2043 — Engine-First Design

**Date:** 2026-03-06
**Approach:** Engine-first with placeholder gameplay

## Key Decisions

- **Rendering:** Full custom Metal pipeline (no SpriteKit)
- **ECS:** Hybrid — GKEntity/GKComponent for lifecycle, flat arrays for hot-path data
- **Platform:** Universal Xcode project, macOS as primary dev target
- **Post-processing:** Multi-pass architecture with stub shaders (bloom/CRT deferred)
- **Audio:** Protocol stub only, no implementation
- **Project structure:** Xcode project + local Swift Package for engine

## Architecture Overview

A universal Xcode project with two thin app targets (macOS, iOS) depending on a local Swift Package (`Engine2043`) that contains all game logic, rendering, ECS, and input abstraction.

## Project Structure

```
turbo-carnival/
├── Project2043.xcodeproj
├── Project2043-macOS/              # Thin macOS app shell
│   ├── AppDelegate.swift
│   └── MetalView.swift             # NSView + CAMetalLayer
├── Project2043-iOS/                # Thin iOS app shell
│   ├── AppDelegate.swift
│   └── MetalView.swift             # UIView + CAMetalLayer
├── Engine2043/                     # Local Swift Package
│   ├── Package.swift
│   └── Sources/
│       └── Engine2043/
│           ├── Core/
│           │   ├── GameEngine.swift        # Top-level game loop
│           │   ├── GameTime.swift          # Delta time, fixed timestep
│           │   └── GameConfig.swift        # Constants, TokyoNight palette
│           ├── ECS/
│           │   ├── Entity.swift            # GKEntity-based entities
│           │   ├── Components/
│           │   │   ├── TransformComponent.swift
│           │   │   ├── PhysicsComponent.swift
│           │   │   ├── HealthComponent.swift
│           │   │   ├── RenderComponent.swift
│           │   │   └── WeaponComponent.swift
│           │   └── Systems/
│           │       ├── PhysicsSystem.swift      # Flat-array hot path
│           │       ├── CollisionSystem.swift     # QuadTree + AABB
│           │       ├── RenderSystem.swift        # Feeds Metal pipeline
│           │       └── WeaponSystem.swift
│           ├── Rendering/
│           │   ├── Renderer.swift          # Metal command buffer orchestration
│           │   ├── SpriteBatcher.swift      # Instanced quad rendering
│           │   ├── TextureAtlas.swift       # Texture management
│           │   ├── RenderPassPipeline.swift # Multi-pass architecture
│           │   └── Shaders/
│           │       ├── Sprite.metal         # Vertex/fragment for textured quads
│           │       └── PostProcess.metal    # Passthrough now, bloom/CRT later
│           ├── Input/
│           │   ├── InputManager.swift       # Protocol: normalized vectors + action booleans
│           │   ├── KeyboardInputProvider.swift   # macOS (platform-conditional)
│           │   └── TouchInputProvider.swift      # iOS (platform-conditional)
│           ├── Audio/
│           │   └── AudioManager.swift       # Protocol stub, no implementation
│           └── Scene/
│               ├── SceneManager.swift       # Scene lifecycle
│               └── PlaceholderScene.swift    # Test scene with placeholder entities
│   └── Tests/
│       └── Engine2043Tests/
└── docs/
    └── plans/
```

## Core Systems (Build Order)

### 1. Metal Rendering Pipeline
- `Renderer` owns the `MTLDevice`, `MTLCommandQueue`, and presentation lifecycle
- `SpriteBatcher` uses instanced rendering — one draw call for all sprites sharing a texture atlas
- `RenderPassPipeline` defines the multi-pass chain: forward pass -> post-process stub
- The post-process stub is a passthrough shader that copies the framebuffer, giving us the attachment point for bloom/CRT later
- Vertex/fragment shaders handle textured, tinted quads with alpha blending

### 2. Game Loop & Timing
- `GameEngine` runs a fixed-timestep update loop (physics at 60Hz) with variable rendering
- Update order: Input -> Physics -> Collision -> Weapons -> ECS bookkeeping -> Render
- `GameTime` provides delta time, total elapsed, and fixed-step accumulator

### 3. Hybrid ECS
- Entities use `GKEntity`/`GKComponent` for lifecycle and organization
- Hot-path data (transforms, velocities, AABBs) mirrored in flat `ContiguousArray` storage iterated by `PhysicsSystem` and `CollisionSystem`
- `CollisionSystem` uses a QuadTree rebuilt each frame for broad-phase, then AABB narrow-phase
- `GKStateMachine` reserved for complex state (boss phases, player damage/invulnerability)

### 4. Input Abstraction
- `InputManager` protocol outputs a `PlayerInput` struct: `movementVector: SIMD2<Float>`, `primaryFire: Bool`, `secondaryFire: Bool`
- `KeyboardInputProvider` (macOS): continuous key-state polling, not event-driven
- `TouchInputProvider` (iOS): stubbed with the dynamic-origin virtual joystick design, implemented later

### 5. Audio Stub
- `AudioManager` protocol with methods like `playEffect(_:)`, `playMusic(_:)`, `stopAll()`
- No-op default implementation

## Placeholder Gameplay (Validation Layer)

Once the engine systems are up, a `PlaceholderScene` wires them together:
- Player entity: cyan quad, moves with keyboard, fires forward projectiles
- Tier 1 enemies: red quads, spawn from top in V-formation, scroll downward
- Collision: projectiles destroy enemies, enemies damage player energy gauge
- One shoot-to-cycle item drop when a formation is fully destroyed
- Energy HUD: simple numeric overlay

This is explicitly throwaway content to validate the engine, not production gameplay.

## What's Explicitly Deferred
- CRT scanlines, bloom, chromatic aberration (post-process stubs in place)
- Audio implementation
- All production sprites/art
- iOS touch input (protocol exists, no-op implementation)
- Galaxies 1-3, bosses, Tier 2-4 enemies
- Full weapon arsenal (only Double Cannon in placeholder)
- Score system, menus, game over flow

## Key Technical Decisions
- **Metal directly, no SpriteKit** — we own the full render pipeline
- **Instanced sprite batching** — one draw call per texture atlas, scales to hundreds of entities
- **Fixed timestep physics** — deterministic behavior across hardware
- **QuadTree collision** — O(n log n) broad-phase instead of O(n^2)
- **Platform code isolated** — only the app shells and input providers have `#if os()` conditionals
