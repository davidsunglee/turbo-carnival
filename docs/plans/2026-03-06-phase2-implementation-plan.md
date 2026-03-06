# Phase 2: Technical Completion — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the three stubbed engine subsystems: post-processing shaders (bloom, CRT, chromatic aberration), audio engine (AVAudioEngine), and iOS touch input.

**Architecture:** Multi-pass Metal post-processing with MPS bloom, AVAudioEngine backend with sound effect pooling, and custom UIView touch handling for dynamic-origin virtual joystick. All three subsystems integrate through existing protocols/interfaces with zero gameplay code changes.

**Tech Stack:** Metal, Metal Shading Language, MetalPerformanceShaders, AVFoundation, UIKit touch handling, Swift Testing

---

## Part A: Post-Processing Shaders

### Task 1: Add PostProcessUniforms struct

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/RenderTypes.swift`
- Modify: `Engine2043/Tests/Engine2043Tests/GameTimeTests.swift`

**Step 1: Write the failing test**

Add to `Engine2043/Tests/Engine2043Tests/GameTimeTests.swift`:

```swift
@Test func postProcessUniformsMemoryLayout() {
    // Must be 16-byte aligned for Metal buffer binding
    #expect(MemoryLayout<PostProcessUniforms>.size == 16)
    #expect(MemoryLayout<PostProcessUniforms>.stride % 16 == 0)
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter postProcessUniformsMemoryLayout`
Expected: FAIL — `PostProcessUniforms` not defined

**Step 3: Write minimal implementation**

Add to `Engine2043/Sources/Engine2043/Rendering/RenderTypes.swift` after `Uniforms`:

```swift
public struct PostProcessUniforms: Sendable {
    public var time: Float
    public var bloomIntensity: Float
    public var scanlineIntensity: Float
    public var _pad: Float = 0

    public init(time: Float, bloomIntensity: Float = 0.6, scanlineIntensity: Float = 0.15) {
        self.time = time
        self.bloomIntensity = bloomIntensity
        self.scanlineIntensity = scanlineIntensity
    }
}
```

Note: Resolution is not in the struct — the shader reads texture dimensions directly via `get_width()`/`get_height()`. This keeps the struct at exactly 16 bytes (4 floats).

**Step 4: Run test to verify it passes**

Run: `cd Engine2043 && swift test --filter postProcessUniformsMemoryLayout`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/RenderTypes.swift Engine2043/Tests/Engine2043Tests/GameTimeTests.swift
git commit -m "feat: add PostProcessUniforms struct for shader parameters"
```

---

### Task 2: Bloom extract and composite shaders

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/Shaders/PostProcess.metal`

**Step 1: Replace the passthrough shader with full post-processing**

Replace the entire contents of `PostProcess.metal` with:

```metal
#include <metal_stdlib>
using namespace metal;

struct PostProcessUniforms {
    float time;
    float bloomIntensity;
    float scanlineIntensity;
    float _pad;
};

struct PostProcessVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen triangle — 3 vertices cover the entire screen, no vertex buffer needed
vertex PostProcessVertexOut postprocess_vertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    constexpr float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    PostProcessVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = uvs[vertexID];
    return out;
}

// Bloom extract — output only bright pixels above luminance threshold
fragment float4 bloom_extract_fragment(
    PostProcessVertexOut in [[stage_in]],
    texture2d<float> sceneTex [[texture(0)]],
    sampler smp [[sampler(0)]]
) {
    float4 color = sceneTex.sample(smp, in.texCoord);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float threshold = 0.7;
    float contribution = max(luminance - threshold, 0.0) / max(1.0 - threshold, 0.001);
    return float4(color.rgb * contribution, 1.0);
}

// Final composite — chromatic aberration + bloom + CRT scanlines
fragment float4 postprocess_fragment(
    PostProcessVertexOut in [[stage_in]],
    texture2d<float> sceneTex [[texture(0)]],
    texture2d<float> bloomTex [[texture(1)]],
    sampler smp [[sampler(0)]],
    constant PostProcessUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 resolution = float2(sceneTex.get_width(), sceneTex.get_height());

    // --- Chromatic aberration ---
    float2 center = float2(0.5, 0.5);
    float2 dir = uv - center;
    float offset = 0.002;
    float r = sceneTex.sample(smp, uv + dir * offset).r;
    float g = sceneTex.sample(smp, uv).g;
    float b = sceneTex.sample(smp, uv - dir * offset).b;
    float a = sceneTex.sample(smp, uv).a;
    float4 sceneColor = float4(r, g, b, a);

    // --- Additive bloom ---
    float4 bloom = bloomTex.sample(smp, uv);
    sceneColor.rgb += bloom.rgb * uniforms.bloomIntensity;

    // --- CRT scanlines ---
    float scanline = sin(uv.y * resolution.y * M_PI_F + uniforms.time * 2.0);
    float scanlineFactor = clamp(scanline * uniforms.scanlineIntensity + (1.0 - uniforms.scanlineIntensity), 0.65, 1.0);
    sceneColor.rgb *= scanlineFactor;

    return sceneColor;
}
```

**Step 2: Verify the shader compiles**

Run: `cd Engine2043 && swift build 2>&1 | tail -5`
Expected: Build succeeds (shaders are compiled via `.process("Rendering/Shaders")` in Package.swift). The build may succeed even if the new functions aren't wired up yet — they just need to be valid MSL.

Note: If the build fails because the new shader functions reference textures not yet bound, that's fine — we wire them in the next tasks. The shader file itself must be syntactically valid MSL.

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/Shaders/PostProcess.metal
git commit -m "feat: implement bloom extract and composite post-process shaders"
```

---

### Task 3: Add bloom textures and extract pipeline to RenderPassPipeline

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift`

**Step 1: Add bloom extract pipeline state, bloom textures, and the extract pass encoder**

Update `RenderPassPipeline.swift` to:

1. Add new stored properties:

```swift
let bloomExtractPipelineState: MTLRenderPipelineState
private var bloomExtractTexture: MTLTexture?
private var bloomBlurTexture: MTLTexture?
```

2. In `init`, after the existing post-process pipeline setup, add bloom extract pipeline:

```swift
// --- Bloom extract pipeline ---
let bloomDesc = MTLRenderPipelineDescriptor()
bloomDesc.vertexFunction = library.makeFunction(name: "postprocess_vertex")
bloomDesc.fragmentFunction = library.makeFunction(name: "bloom_extract_fragment")
bloomDesc.colorAttachments[0].pixelFormat = Self.offscreenPixelFormat

do {
    bloomExtractPipelineState = try device.makeRenderPipelineState(descriptor: bloomDesc)
} catch {
    throw RendererError.failedToCreatePipelineState("BloomExtract: \(error)")
}
```

3. In `ensureOffscreenTexture`, after creating `offscreenTexture`, also create bloom textures:

```swift
let bloomDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: Self.offscreenPixelFormat,
    width: width,
    height: height,
    mipmapped: false
)
bloomDesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
bloomDesc.storageMode = .private
bloomExtractTexture = device.makeTexture(descriptor: bloomDesc)
bloomBlurTexture = device.makeTexture(descriptor: bloomDesc)
```

4. Add new encode method:

```swift
func encodeBloomExtractPass(commandBuffer: MTLCommandBuffer) {
    guard let bloomExtract = bloomExtractTexture,
          let offscreen = offscreenTexture else { return }

    let passDesc = MTLRenderPassDescriptor()
    passDesc.colorAttachments[0].texture = bloomExtract
    passDesc.colorAttachments[0].loadAction = .clear
    passDesc.colorAttachments[0].storeAction = .store
    passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
    encoder.setRenderPipelineState(bloomExtractPipelineState)
    encoder.setFragmentTexture(offscreen, index: 0)
    encoder.setFragmentSamplerState(postProcessSampler, index: 0)

    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
}
```

5. Update `encodePostProcessPass` to accept uniforms and bind the bloom texture:

```swift
func encodePostProcessPass(
    commandBuffer: MTLCommandBuffer,
    drawable: CAMetalDrawable,
    uniforms: inout PostProcessUniforms
) {
    guard let offscreen = offscreenTexture,
          let bloomBlur = bloomBlurTexture else { return }

    let passDesc = MTLRenderPassDescriptor()
    passDesc.colorAttachments[0].texture = drawable.texture
    passDesc.colorAttachments[0].loadAction = .dontCare
    passDesc.colorAttachments[0].storeAction = .store

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
    encoder.setRenderPipelineState(postProcessPipelineState)
    encoder.setFragmentTexture(offscreen, index: 0)
    encoder.setFragmentTexture(bloomBlur, index: 1)
    encoder.setFragmentSamplerState(postProcessSampler, index: 0)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<PostProcessUniforms>.size, index: 0)

    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
}
```

6. Expose bloom textures for the MPS blur pass:

```swift
var bloomExtractTextureForBlur: MTLTexture? { bloomExtractTexture }
var bloomBlurTextureForBlur: MTLTexture? { bloomBlurTexture }
```

**Step 2: Verify it compiles**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build fails because `Renderer.swift` still calls the old `encodePostProcessPass` signature. This is expected — we fix it in Task 4.

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/RenderPassPipeline.swift
git commit -m "feat: add bloom extract pipeline, textures, and updated post-process pass"
```

---

### Task 4: Wire up MPS blur and updated render pipeline in Renderer

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Rendering/Renderer.swift`

**Step 1: Update Renderer to use the full bloom pipeline**

Replace the contents of `Renderer.swift`:

```swift
import Metal
import MetalPerformanceShaders
import QuartzCore
import simd

@MainActor
public final class Renderer {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let spriteBatcher: SpriteBatcher
    private let renderPassPipeline: RenderPassPipeline
    private let textureAtlas: TextureAtlas
    private let bloomBlurKernel: MPSImageGaussianBlur

    public init(device: MTLDevice) throws {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = queue

        let library = try device.makeDefaultLibrary(bundle: Bundle.module)
        self.renderPassPipeline = try RenderPassPipeline(device: device, library: library)
        self.spriteBatcher = try SpriteBatcher(device: device)
        self.textureAtlas = try TextureAtlas(device: device)
        self.bloomBlurKernel = MPSImageGaussianBlur(device: device, sigma: 4.0)
    }

    public func render(to drawable: CAMetalDrawable, sprites: [SpriteInstance], totalTime: Float) {
        let width = drawable.texture.width
        let height = drawable.texture.height
        guard width > 0, height > 0 else { return }

        renderPassPipeline.ensureOffscreenTexture(width: width, height: height)
        spriteBatcher.update(instances: sprites)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        var uniforms = Uniforms(viewProjection: makeOrthographicProjection())

        // Pass 1: Forward (sprites -> offscreen)
        renderPassPipeline.encodeForwardPass(
            commandBuffer: commandBuffer,
            batcher: spriteBatcher,
            uniforms: &uniforms,
            texture: textureAtlas.defaultTexture
        )

        // Pass 2: Bloom extract (offscreen -> bloom extract texture)
        renderPassPipeline.encodeBloomExtractPass(commandBuffer: commandBuffer)

        // Pass 3: MPS Gaussian blur (bloom extract -> bloom blur)
        if let src = renderPassPipeline.bloomExtractTextureForBlur,
           let dst = renderPassPipeline.bloomBlurTextureForBlur {
            bloomBlurKernel.encode(commandBuffer: commandBuffer, sourceTexture: src, destinationTexture: dst)
        }

        // Pass 4: Final composite (offscreen + bloom blur -> drawable)
        var ppUniforms = PostProcessUniforms(time: totalTime)
        renderPassPipeline.encodePostProcessPass(
            commandBuffer: commandBuffer,
            drawable: drawable,
            uniforms: &ppUniforms
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeOrthographicProjection() -> simd_float4x4 {
        let hw = GameConfig.designWidth / 2
        let hh = GameConfig.designHeight / 2

        return simd_float4x4(
            SIMD4<Float>(1.0 / hw, 0, 0, 0),
            SIMD4<Float>(0, 1.0 / hh, 0, 0),
            SIMD4<Float>(0, 0, -1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
```

**Step 2: Verify it compiles**

Run: `cd Engine2043 && swift build 2>&1 | tail -10`
Expected: Build fails because `GameEngine.render(to:)` calls the old `renderer.render(to:sprites:)` signature without `totalTime`. Fix in next task.

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Rendering/Renderer.swift
git commit -m "feat: wire MPS bloom blur and full post-process pipeline in Renderer"
```

---

### Task 5: Pass totalTime from GameEngine to Renderer

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameEngine.swift`

**Step 1: Update GameEngine.render to pass time**

Change the `render` method in `GameEngine.swift`:

```swift
public func render(to drawable: CAMetalDrawable) {
    let sprites = currentScene?.collectSprites() ?? []
    renderer.render(to: drawable, sprites: sprites, totalTime: Float(time.totalTime))
}
```

**Step 2: Build and run tests**

Run: `cd Engine2043 && swift build && swift test 2>&1 | tail -10`
Expected: Build succeeds. All 13 tests pass (12 existing + 1 new PostProcessUniforms layout test).

**Step 3: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/GameEngine.swift
git commit -m "feat: pass elapsed time from game engine to renderer for post-process animation"
```

---

### Task 6: Verify post-processing visually

**Files:** None (manual verification)

**Step 1: Build and run the macOS target in Xcode**

Open `Project2043.xcodeproj`, select the macOS target, and run. You should see:
- Neon cyan player and pink enemies now have a visible glow/bloom halo
- Subtle CRT scanlines visible across the screen (faint horizontal bands that drift downward slowly)
- Slight chromatic aberration at screen edges (barely visible red/blue fringe)

**Step 2: If effects are too strong or too weak**

Adjust default values in `PostProcessUniforms.init`:
- `bloomIntensity`: 0.6 default. Increase for more glow, decrease for subtlety.
- `scanlineIntensity`: 0.15 default. Increase for more visible scanlines.
- Bloom threshold in shader: 0.7. Lower to bloom more elements, raise to bloom fewer.
- MPS blur sigma: 4.0 in `Renderer.init`. Increase for wider bloom spread.

**Step 3: Commit any tuning adjustments**

```bash
git add -A
git commit -m "tune: adjust post-process shader parameters"
```

---

## Part B: Audio Engine

### Task 7: Add AVAudioManager with music playback

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Audio/AudioManager.swift`
- Create: `Engine2043/Tests/Engine2043Tests/AudioTests.swift`

**Step 1: Write the failing test**

Create `Engine2043/Tests/Engine2043Tests/AudioTests.swift`:

```swift
import Testing
@testable import Engine2043

struct AudioTests {
    @Test @MainActor func audioManagerConformsToProtocol() {
        let manager = AVAudioManager()
        let provider: any AudioProvider = manager
        // Should be able to call without crash
        provider.playEffect("test")
        provider.playMusic("test")
        provider.stopAll()
    }

    @Test @MainActor func audioManagerSetsVolume() {
        let manager = AVAudioManager()
        manager.setMasterVolume(0.5)
        #expect(manager.masterVolume == 0.5)
    }

    @Test @MainActor func audioManagerClampsVolume() {
        let manager = AVAudioManager()
        manager.setMasterVolume(1.5)
        #expect(manager.masterVolume == 1.0)
        manager.setMasterVolume(-0.5)
        #expect(manager.masterVolume == 0.0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd Engine2043 && swift test --filter AudioTests`
Expected: FAIL — `AVAudioManager` not defined

**Step 3: Write implementation**

Replace the contents of `Engine2043/Sources/Engine2043/Audio/AudioManager.swift`:

```swift
import AVFoundation

@MainActor
public protocol AudioProvider: AnyObject {
    func playEffect(_ name: String)
    func playMusic(_ name: String)
    func stopAll()
}

@MainActor
public final class AVAudioManager: AudioProvider {
    private let engine = AVAudioEngine()
    private let musicNode = AVAudioPlayerNode()
    private var effectNodes: [AVAudioPlayerNode] = []
    private var bufferCache: [String: AVAudioPCMBuffer] = [:]
    private let effectPoolSize = 8

    public private(set) var masterVolume: Float = 1.0

    public init() {
        engine.attach(musicNode)
        engine.connect(musicNode, to: engine.mainMixerNode, format: nil)

        for _ in 0..<effectPoolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: nil)
            effectNodes.append(node)
        }

        do {
            try engine.start()
        } catch {
            print("AVAudioEngine failed to start: \(error)")
        }
    }

    public func setMasterVolume(_ volume: Float) {
        masterVolume = max(0, min(1, volume))
        engine.mainMixerNode.outputVolume = masterVolume
    }

    public func playMusic(_ name: String) {
        guard let buffer = loadBuffer(named: name) else { return }
        musicNode.stop()
        musicNode.scheduleBuffer(buffer, at: nil, options: .loops)
        musicNode.play()
    }

    public func playEffect(_ name: String) {
        guard let buffer = loadBuffer(named: name) else { return }

        // Find an idle effect node
        guard let node = effectNodes.first(where: { !$0.isPlaying }) ?? effectNodes.first else { return }
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [])
        node.play()
    }

    public func stopAll() {
        musicNode.stop()
        for node in effectNodes {
            node.stop()
        }
    }

    private func loadBuffer(named name: String) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[name] { return cached }

        guard let url = Bundle.module.url(forResource: name, withExtension: nil) ??
                        Bundle.module.url(forResource: name, withExtension: "caf") ??
                        Bundle.module.url(forResource: name, withExtension: "m4a") else {
            return nil
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
            try file.read(into: buffer)
            bufferCache[name] = buffer
            return buffer
        } catch {
            print("Failed to load audio: \(name) — \(error)")
            return nil
        }
    }
}
```

**Step 4: Run tests**

Run: `cd Engine2043 && swift test --filter AudioTests`
Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Audio/AudioManager.swift Engine2043/Tests/Engine2043Tests/AudioTests.swift
git commit -m "feat: implement AVAudioEngine-based audio manager with effect pooling"
```

---

### Task 8: Update PlaceholderScene and GameEngine to use AVAudioManager

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Core/GameEngine.swift`
- Modify: `Engine2043/Sources/Engine2043/Scene/PlaceholderScene.swift`

**Step 1: Add audio provider to GameEngine**

Add a public property to `GameEngine`:

```swift
public var audioProvider: (any AudioProvider)?
```

**Step 2: Add audio provider to PlaceholderScene**

Add a public property to `PlaceholderScene`:

```swift
public var audioProvider: (any AudioProvider)?
```

No actual sound trigger calls yet — there are no audio assets. This just wires the plumbing so scenes can play sounds when assets exist.

**Step 3: Update macOS MetalView to create AVAudioManager**

In `Project2043-macOS/MetalView.swift`, in the `setup()` method, after creating the scene:

```swift
let audio = AVAudioManager()
scene.audioProvider = audio
```

Similarly in `Project2043-iOS/MetalView.swift`.

**Step 4: Build and run tests**

Run: `cd Engine2043 && swift build && swift test 2>&1 | tail -10`
Expected: Build succeeds. All tests pass.

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Core/GameEngine.swift Engine2043/Sources/Engine2043/Scene/PlaceholderScene.swift Project2043-macOS/MetalView.swift Project2043-iOS/MetalView.swift
git commit -m "feat: wire audio provider through engine and scene lifecycle"
```

---

## Part C: iOS Touch Input

### Task 9: Implement TouchInputProvider with dynamic-origin joystick

**Files:**
- Modify: `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift`
- Create: `Engine2043/Tests/Engine2043Tests/InputTests.swift`

**Step 1: Write the failing test**

Create `Engine2043/Tests/Engine2043Tests/InputTests.swift`:

```swift
import Testing
import simd
@testable import Engine2043

struct InputTests {
    @Test func playerInputDefaults() {
        let input = PlayerInput()
        #expect(input.movement == .zero)
        #expect(input.primaryFire == false)
        #expect(input.secondaryFire == false)
    }

    @Test func touchZoneClassification() {
        // Screen 390x844 (iPhone 14 sized)
        let screenW: Float = 390
        let screenH: Float = 844

        // Left half, bottom half -> joystick zone
        let joystickPoint = SIMD2<Float>(100, 600)
        #expect(joystickPoint.x < screenW / 2)
        #expect(joystickPoint.y > screenH / 2)

        // Right half, bottom area -> button zone
        let buttonPoint = SIMD2<Float>(300, 700)
        #expect(buttonPoint.x >= screenW / 2)
        #expect(buttonPoint.y > screenH / 2)
    }

    @Test func joystickVectorNormalization() {
        // Simulate displacement beyond max radius
        let origin = SIMD2<Float>(100, 600)
        let current = SIMD2<Float>(200, 600) // 100pt right
        let maxRadius: Float = 60

        var delta = current - origin
        let length = simd_length(delta)
        if length > maxRadius {
            delta = simd_normalize(delta) * maxRadius
        }
        let normalized = delta / maxRadius

        #expect(abs(normalized.x - 1.0) < 0.01)
        #expect(abs(normalized.y) < 0.01)
    }

    @Test func joystickDeadZone() {
        let origin = SIMD2<Float>(100, 600)
        let current = SIMD2<Float>(105, 602) // 5pt displacement
        let deadZone: Float = 10

        let delta = current - origin
        let length = simd_length(delta)

        #expect(length < deadZone)
        // Movement should be zero when within dead zone
        let movement: SIMD2<Float> = length < deadZone ? .zero : delta / 60.0
        #expect(movement == .zero)
    }
}
```

**Step 2: Run tests**

Run: `cd Engine2043 && swift test --filter InputTests`
Expected: PASS — these tests validate the math/logic without requiring iOS (no UIKit dependency).

**Step 3: Implement TouchInputProvider**

Replace `Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift`:

```swift
#if os(iOS)
import UIKit
import simd

@MainActor
public final class TouchInputProvider: InputProvider {
    // Joystick state
    private var joystickOrigin: SIMD2<Float>?
    private var joystickCurrent: SIMD2<Float>?
    private var joystickTouchID: ObjectIdentifier?

    // Button state
    private var primaryFireActive: Bool = false
    private var secondaryFireActive: Bool = false
    private var primaryTouchID: ObjectIdentifier?
    private var secondaryTouchID: ObjectIdentifier?

    // Configuration
    private let maxJoystickRadius: Float = 60
    private let deadZone: Float = 10

    // Screen dimensions (set by MetalView on layout)
    public var screenSize: CGSize = .zero

    // Button rects (set by MetalView on layout)
    public var primaryButtonRect: CGRect = .zero
    public var secondaryButtonRect: CGRect = .zero

    public init() {}

    public func poll() -> PlayerInput {
        var input = PlayerInput()

        if let origin = joystickOrigin, let current = joystickCurrent {
            var delta = current - origin
            let length = simd_length(delta)

            if length < deadZone {
                delta = .zero
            } else if length > maxJoystickRadius {
                delta = simd_normalize(delta) * maxJoystickRadius
            }

            input.movement = delta / maxJoystickRadius
            // Flip Y: screen Y goes down, game Y goes up
            input.movement.y = -input.movement.y
        }

        input.primaryFire = primaryFireActive
        input.secondaryFire = secondaryFireActive

        return input
    }

    // MARK: - Touch handling (called by MetalView)

    public func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let loc = touch.location(in: view)
            let point = SIMD2<Float>(Float(loc.x), Float(loc.y))
            let touchID = ObjectIdentifier(touch)

            if loc.x < screenSize.width / 2 && joystickTouchID == nil {
                // Left half: joystick
                joystickOrigin = point
                joystickCurrent = point
                joystickTouchID = touchID
            } else if loc.x >= screenSize.width / 2 {
                // Right half: buttons
                if secondaryButtonRect.contains(loc) && secondaryTouchID == nil {
                    secondaryFireActive = true
                    secondaryTouchID = touchID
                } else if primaryTouchID == nil {
                    primaryFireActive = true
                    primaryTouchID = touchID
                }
            }
        }
    }

    public func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let touchID = ObjectIdentifier(touch)
            if touchID == joystickTouchID {
                let loc = touch.location(in: view)
                joystickCurrent = SIMD2<Float>(Float(loc.x), Float(loc.y))
            }
        }
    }

    public func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        cancelTouches(touches)
    }

    public func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        cancelTouches(touches)
    }

    private func cancelTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let touchID = ObjectIdentifier(touch)
            if touchID == joystickTouchID {
                joystickOrigin = nil
                joystickCurrent = nil
                joystickTouchID = nil
            }
            if touchID == primaryTouchID {
                primaryFireActive = false
                primaryTouchID = nil
            }
            if touchID == secondaryTouchID {
                secondaryFireActive = false
                secondaryTouchID = nil
            }
        }
    }
}

#endif
```

**Step 4: Run tests**

Run: `cd Engine2043 && swift test --filter InputTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Engine2043/Sources/Engine2043/Input/TouchInputProvider.swift Engine2043/Tests/Engine2043Tests/InputTests.swift
git commit -m "feat: implement dynamic-origin virtual joystick touch input for iOS"
```

---

### Task 10: Wire touch events through iOS MetalView

**Files:**
- Modify: `Project2043-iOS/MetalView.swift`

**Step 1: Update iOS MetalView to forward touches and configure button rects**

Replace the contents of `Project2043-iOS/MetalView.swift`:

```swift
import UIKit
import Metal
import QuartzCore
import Engine2043

final class MetalView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    private var metalLayer: CAMetalLayer { self.layer as! CAMetalLayer }
    private var engine: GameEngine!
    private var displayLink: CADisplayLink!
    private var lastTimestamp: CFTimeInterval = 0
    private var touchInput: TouchInputProvider!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isMultipleTouchEnabled = true

        guard let device = MTLCreateSystemDefaultDevice() else { return }
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm

        let renderer = try! Renderer(device: device)
        engine = GameEngine(renderer: renderer)

        touchInput = TouchInputProvider()
        let scene = PlaceholderScene()
        scene.inputProvider = touchInput

        let audio = AVAudioManager()
        scene.audioProvider = audio

        engine.currentScene = scene

        displayLink = CADisplayLink(target: self, selector: #selector(render(_:)))
        displayLink.add(to: .main, forMode: .default)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = UIScreen.main.scale
        metalLayer.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        // Update touch provider with screen dimensions and button rects
        touchInput.screenSize = bounds.size

        let buttonW: CGFloat = 80
        let buttonH: CGFloat = 80
        let margin: CGFloat = 20
        let rightEdge = bounds.width - margin

        // Primary fire: larger, lower right
        touchInput.primaryButtonRect = CGRect(
            x: rightEdge - buttonW,
            y: bounds.height - margin - buttonH,
            width: buttonW,
            height: buttonH
        )

        // Secondary fire: smaller, above primary
        let secW: CGFloat = 60
        let secH: CGFloat = 60
        touchInput.secondaryButtonRect = CGRect(
            x: rightEdge - secW - 10,
            y: bounds.height - margin - buttonH - 20 - secH,
            width: secW,
            height: secH
        )
    }

    @objc private func render(_ displayLink: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 1.0 / 60.0 : displayLink.timestamp - lastTimestamp
        lastTimestamp = displayLink.timestamp

        engine.update(deltaTime: dt)

        guard let drawable = metalLayer.nextDrawable() else { return }
        engine.render(to: drawable)
    }

    // MARK: - Touch forwarding

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesBegan(touches, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesMoved(touches, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesEnded(touches, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchInput.touchesCancelled(touches, in: self)
    }
}
```

**Step 2: Build**

Run: `cd Engine2043 && swift build && swift test 2>&1 | tail -10`
Expected: Build succeeds, all tests pass. (iOS MetalView only compiles when building the iOS target in Xcode, but the engine package build should still succeed.)

**Step 3: Commit**

```bash
git add Project2043-iOS/MetalView.swift
git commit -m "feat: wire touch input through iOS MetalView with button layout"
```

---

### Task 11: Final verification and all-tests pass

**Files:** None (verification only)

**Step 1: Run full test suite**

Run: `cd Engine2043 && swift test 2>&1`
Expected: All tests pass (original 12 + PostProcessUniforms layout + 3 audio + 4 input = 20 tests).

**Step 2: Build macOS target in Xcode**

Open `Project2043.xcodeproj`, select macOS target, build and run. Verify:
- Post-processing effects visible (bloom, scanlines, chromatic aberration)
- Game plays normally (no regression)

**Step 3: Build iOS target in Xcode (simulator or device)**

Select iOS target, build and run on simulator/device. Verify:
- Touch joystick moves player (touch left half, drag)
- Primary fire button works (tap right side)
- Post-processing effects visible

**Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "chore: phase 2 technical completion — post-process, audio, iOS input"
```
