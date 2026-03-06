import Metal

@MainActor
final class SpriteBatcher {
    static let maxInstances = 4096

    private let device: MTLDevice
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    private var instanceBuffer: MTLBuffer?
    private(set) var instanceCount: Int = 0

    init(device: MTLDevice) throws {
        self.device = device

        let vertices: [SpriteVertex] = [
            SpriteVertex(position: SIMD2(-0.5, -0.5), texCoord: SIMD2(0, 1)),
            SpriteVertex(position: SIMD2( 0.5, -0.5), texCoord: SIMD2(1, 1)),
            SpriteVertex(position: SIMD2( 0.5,  0.5), texCoord: SIMD2(1, 0)),
            SpriteVertex(position: SIMD2(-0.5,  0.5), texCoord: SIMD2(0, 0)),
        ]
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]

        guard let vb = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SpriteVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            throw RendererError.failedToCreateBuffer
        }

        guard let ib = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        ) else {
            throw RendererError.failedToCreateBuffer
        }

        self.vertexBuffer = vb
        self.indexBuffer = ib
    }

    func update(instances: [SpriteInstance]) {
        instanceCount = min(instances.count, Self.maxInstances)
        guard instanceCount > 0 else {
            instanceBuffer = nil
            return
        }

        let byteLength = MemoryLayout<SpriteInstance>.stride * instanceCount
        instances.withUnsafeBytes { raw in
            guard let baseAddress = raw.baseAddress else { return }
            if let existing = instanceBuffer, existing.length >= byteLength {
                memcpy(existing.contents(), baseAddress, byteLength)
            } else {
                instanceBuffer = device.makeBuffer(
                    bytes: baseAddress,
                    length: byteLength,
                    options: .storageModeShared
                )
            }
        }
    }

    func encode(encoder: MTLRenderCommandEncoder) {
        guard instanceCount > 0, let instanceBuffer else { return }
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }
}
