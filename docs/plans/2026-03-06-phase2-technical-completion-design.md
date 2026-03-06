# Phase 2: Technical Completion — Design

**Date:** 2026-03-06
**Approach:** Sequential (Shaders -> iOS Input -> Audio)
**Prerequisite:** Phase 1 engine-first foundation (complete)

## Overview

Complete the three stubbed engine subsystems in order:
1. Post-processing shaders (bloom, CRT scanlines, chromatic aberration)
2. iOS touch input (dynamic-origin virtual joystick + fire buttons)
3. Audio engine (AVAudioEngine backend for music and effects)

## Part 1: Post-Processing Pipeline

### Pipeline Architecture

Current pipeline:
```
Forward Pass (sprites -> offscreen A) -> PostProcess (passthrough -> drawable)
```

New pipeline:
```
Forward Pass (sprites -> offscreen A)
    -> Bloom Extract (threshold -> bloom texture B)
    -> MPS Gaussian Blur (B -> blurred texture C)
    -> Final Composite (A + C -> drawable)
        applies: additive bloom + CRT scanlines + chromatic aberration
```

Two additional offscreen textures managed by `RenderPassPipeline`. MPS blur encoded directly into the command buffer between render passes. Forward pass and sprite pipeline untouched.

### Shader Design

**Bloom Extract (`bloom_extract_fragment`):**
- Luminance: `dot(rgb, float3(0.2126, 0.7152, 0.0722))`
- Output pixel if luminance > ~0.7, otherwise black
- Bright neon elements bloom; dark background does not

**MPS Gaussian Blur:**
- `MPSImageGaussianBlur` with sigma ~4.0 (tunable)
- Operates on bloom extract texture -> separate blur output texture

**Final Composite (`postprocess_fragment`):**
1. Chromatic aberration — offset R/B channels by 0.002 UV from screen center (3 texture samples)
2. Additive bloom — sample blurred bloom texture, add to scene
3. CRT scanlines — `clamp(sin(uv.y * resolution.y * pi) * intensity + base, darkFloor, 1.0)` modulated by `time` for downward drift. Dark bands remain translucent per spec.

**PostProcessUniforms struct:**
- `time: Float` — elapsed seconds, drives scanline animation
- `resolution: SIMD2<Float>` — screen pixel dimensions
- `bloomIntensity: Float` — additive bloom strength
- `scanlineIntensity: Float` — CRT effect strength

### Swift-Side Changes

**Modified files (5):**
1. `RenderTypes.swift` — Add `PostProcessUniforms` struct
2. `RenderPassPipeline.swift` — Bloom extract pipeline state, two additional textures, `encodeBloomExtractPass()`, MPS blur kernel, updated `encodePostProcessPass()` accepting uniforms and bloom texture
3. `PostProcess.metal` — Replace passthrough with bloom extract + full composite shader
4. `Renderer.swift` — Accept `totalTime: Float`, construct PostProcessUniforms, encode bloom extract + MPS blur between forward and composite
5. `GameEngine.swift` — Pass `gameTime.totalTime` to renderer

**Untouched:** All ECS, input, audio, scene, sprite shader, and app shell files.

**New dependency:** MetalPerformanceShaders (system framework).

## Part 2: iOS Touch Input

Custom touch handling on `MetalView` UIView (not GCVirtualController) for full control over dynamic-origin behavior and expanded hitboxes.

**Dynamic-origin virtual joystick (lower-left quadrant):**
- Touch-down in left half sets joystick origin
- Drag displacement -> normalized movement vector
- Touch-up resets (no persistent on-screen graphic)
- ~10pt dead zone

**Fire buttons (lower-right quadrant):**
- Primary fire: larger, lower button
- Secondary fire: smaller, upper button
- Expanded hitboxes per spec
- Multi-touch: joystick + fire simultaneous

**Integration:** Fill in existing `TouchInputProvider` stub. Rest of engine unchanged.

## Part 3: Audio Engine

`AVAudioEngine` backend implementing the existing `AudioManager` protocol.

**Music:**
- `AVAudioPlayerNode` for looping background tracks
- Crossfade support for scene transitions
- Compressed audio (m4a/caf) as bundled resources

**Sound effects:**
- Pool of `AVAudioPlayerNode` instances for concurrency
- Pre-loaded `AVAudioPCMBuffer` cache (no disk I/O during gameplay)
- `AVAudioUnitDistortion` for tape saturation on explosions (per spec)

**Integration:** Concrete `AVAudioManager` class conforming to existing `AudioManager` protocol. No interface changes.

**Not in scope:** Production audio assets. Build engine and test with placeholder/synthesized tones.

## Key Technical Decisions

- **MPS for bloom blur** — follows spec, leverages Apple's TBDR-optimized Gaussian implementation
- **Custom touch input, not GCVirtualController** — full control over dynamic-origin joystick and expanded hitboxes
- **AVAudioEngine, not AVAudioPlayer** — low-latency, supports concurrent effects and real-time audio processing (distortion)
- **Sequential implementation** — shaders may require pipeline architectural changes; land those before touching other subsystems
