import Metal

@MainActor
public final class TextureAtlas {
    public let defaultTexture: MTLTexture

    init(device: MTLDevice) throws {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        desc.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: desc) else {
            throw RendererError.failedToCreateTexture
        }

        let white: [UInt8] = [255, 255, 255, 255]
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: white,
            bytesPerRow: 4
        )

        self.defaultTexture = texture
    }
}
