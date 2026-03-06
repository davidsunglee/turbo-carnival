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
