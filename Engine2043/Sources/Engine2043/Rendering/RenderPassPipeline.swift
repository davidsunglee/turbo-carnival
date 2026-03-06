import Metal
import QuartzCore

@MainActor
final class RenderPassPipeline {
    private let device: MTLDevice
    let spritePipelineState: MTLRenderPipelineState
    let postProcessPipelineState: MTLRenderPipelineState
    let spriteSampler: MTLSamplerState
    let postProcessSampler: MTLSamplerState
    private var offscreenTexture: MTLTexture?

    private static let offscreenPixelFormat: MTLPixelFormat = .bgra8Unorm

    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device

        // --- Sprite pipeline ---
        let spriteDesc = MTLRenderPipelineDescriptor()
        spriteDesc.vertexFunction = library.makeFunction(name: "sprite_vertex")
        spriteDesc.fragmentFunction = library.makeFunction(name: "sprite_fragment")
        spriteDesc.colorAttachments[0].pixelFormat = Self.offscreenPixelFormat
        spriteDesc.colorAttachments[0].isBlendingEnabled = true
        spriteDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        spriteDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        spriteDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        spriteDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            spritePipelineState = try device.makeRenderPipelineState(descriptor: spriteDesc)
        } catch {
            throw RendererError.failedToCreatePipelineState("Sprite: \(error)")
        }

        // --- Post-process pipeline ---
        let postDesc = MTLRenderPipelineDescriptor()
        postDesc.vertexFunction = library.makeFunction(name: "postprocess_vertex")
        postDesc.fragmentFunction = library.makeFunction(name: "postprocess_fragment")
        postDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            postProcessPipelineState = try device.makeRenderPipelineState(descriptor: postDesc)
        } catch {
            throw RendererError.failedToCreatePipelineState("PostProcess: \(error)")
        }

        // --- Samplers ---
        let spriteSamplerDesc = MTLSamplerDescriptor()
        spriteSamplerDesc.minFilter = .nearest
        spriteSamplerDesc.magFilter = .nearest
        spriteSamplerDesc.sAddressMode = .clampToEdge
        spriteSamplerDesc.tAddressMode = .clampToEdge
        guard let ss = device.makeSamplerState(descriptor: spriteSamplerDesc) else {
            throw RendererError.failedToCreateSampler
        }
        spriteSampler = ss

        let ppSamplerDesc = MTLSamplerDescriptor()
        ppSamplerDesc.minFilter = .linear
        ppSamplerDesc.magFilter = .linear
        ppSamplerDesc.sAddressMode = .clampToEdge
        ppSamplerDesc.tAddressMode = .clampToEdge
        guard let ps = device.makeSamplerState(descriptor: ppSamplerDesc) else {
            throw RendererError.failedToCreateSampler
        }
        postProcessSampler = ps
    }

    func ensureOffscreenTexture(width: Int, height: Int) {
        if let existing = offscreenTexture,
           existing.width == width, existing.height == height {
            return
        }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.offscreenPixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        offscreenTexture = device.makeTexture(descriptor: desc)
    }

    func encodeForwardPass(
        commandBuffer: MTLCommandBuffer,
        batcher: SpriteBatcher,
        uniforms: inout Uniforms,
        texture: MTLTexture
    ) {
        guard let offscreen = offscreenTexture else { return }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = offscreen
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(GameConfig.Palette.background.x),
            green: Double(GameConfig.Palette.background.y),
            blue: Double(GameConfig.Palette.background.z),
            alpha: Double(GameConfig.Palette.background.w)
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.setRenderPipelineState(spritePipelineState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(spriteSampler, index: 0)

        batcher.encode(encoder: encoder)

        encoder.endEncoding()
    }

    func encodePostProcessPass(
        commandBuffer: MTLCommandBuffer,
        drawable: CAMetalDrawable
    ) {
        guard let offscreen = offscreenTexture else { return }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = drawable.texture
        passDesc.colorAttachments[0].loadAction = .dontCare
        passDesc.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.setRenderPipelineState(postProcessPipelineState)
        encoder.setFragmentTexture(offscreen, index: 0)
        encoder.setFragmentSamplerState(postProcessSampler, index: 0)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        encoder.endEncoding()
    }
}
