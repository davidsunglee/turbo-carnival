import simd

public struct SpriteVertex: Sendable {
    public var position: SIMD2<Float>
    public var texCoord: SIMD2<Float>

    public init(position: SIMD2<Float>, texCoord: SIMD2<Float>) {
        self.position = position
        self.texCoord = texCoord
    }
}

public struct SpriteInstance: Sendable {
    public var position: SIMD2<Float>
    public var size: SIMD2<Float>
    public var uvRect: SIMD4<Float>
    public var color: SIMD4<Float>
    public var rotation: Float
    private var _pad1: Float = 0
    private var _pad2: Float = 0
    private var _pad3: Float = 0

    public init(
        position: SIMD2<Float>,
        size: SIMD2<Float>,
        color: SIMD4<Float>,
        rotation: Float = 0,
        uvRect: SIMD4<Float> = SIMD4<Float>(0, 0, 1, 1)
    ) {
        self.position = position
        self.size = size
        self.color = color
        self.rotation = rotation
        self.uvRect = uvRect
    }
}

public struct Uniforms: Sendable {
    public var viewProjection: simd_float4x4

    public init(viewProjection: simd_float4x4) {
        self.viewProjection = viewProjection
    }
}

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

public enum RendererError: Error, Sendable {
    case failedToCreateCommandQueue
    case failedToCreateTexture
    case failedToCreateBuffer
    case failedToCreatePipelineState(String)
    case failedToCreateSampler
}
