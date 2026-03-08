import Metal
import simd

@MainActor
public final class EffectTextureSheet {
    public let texture: MTLTexture
    private var uvRects: [String: SIMD4<Float>] = [:]

    public static let sheetSize = 256

    public nonisolated(unsafe) static let spriteNames: Set<String> = [
        "gravBombBlast", "empFlash", "overchargeGlow",
        "hudBarFrame", "hudBarFill", "hudChargePip",
        "hudWeaponIcon", "hudHeatFrame", "hudHeatFill"
    ]

    struct SpriteEntry {
        let name: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    static let layout: [SpriteEntry] = [
        // Row 0: Effects
        SpriteEntry(name: "gravBombBlast",  x: 0,   y: 0,   width: 128, height: 128),
        SpriteEntry(name: "empFlash",       x: 128, y: 0,   width: 128, height: 128),
        // Row 128: Overcharge
        SpriteEntry(name: "overchargeGlow", x: 0,   y: 128, width: 64,  height: 64),
        // Row 192: HUD elements
        SpriteEntry(name: "hudBarFrame",    x: 0,   y: 192, width: 64,  height: 8),
        SpriteEntry(name: "hudBarFill",     x: 64,  y: 192, width: 32,  height: 4),
        SpriteEntry(name: "hudChargePip",   x: 96,  y: 192, width: 12,  height: 12),
        SpriteEntry(name: "hudWeaponIcon",  x: 108, y: 192, width: 16,  height: 8),
        SpriteEntry(name: "hudHeatFrame",   x: 124, y: 192, width: 16,  height: 3),
        SpriteEntry(name: "hudHeatFill",    x: 140, y: 192, width: 14,  height: 2),
    ]

    init(device: MTLDevice) throws {
        let size = Self.sheetSize
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        desc.usage = [.shaderRead]

        guard let tex = device.makeTexture(descriptor: desc) else {
            throw RendererError.failedToCreateTexture
        }
        self.texture = tex

        // Place white 1x1 pixel at (255, 255) as fallback for untextured quads
        let white: [UInt8] = [255, 255, 255, 255]
        tex.replace(
            region: MTLRegionMake2D(size - 1, size - 1, 1, 1),
            mipmapLevel: 0,
            withBytes: white,
            bytesPerRow: 4
        )

        let generators: [(String, () -> (pixels: [UInt8], width: Int, height: Int))] = [
            ("gravBombBlast",  SpriteFactory.makeGravBombBlast),
            ("empFlash",       SpriteFactory.makeEmpFlash),
            ("overchargeGlow", SpriteFactory.makeOverchargeGlow),
            ("hudBarFrame",    SpriteFactory.makeHudBarFrame),
            ("hudBarFill",     SpriteFactory.makeHudBarFill),
            ("hudChargePip",   SpriteFactory.makeHudChargePip),
            ("hudWeaponIcon",  SpriteFactory.makeHudWeaponIcon),
            ("hudHeatFrame",   SpriteFactory.makeHudHeatFrame),
            ("hudHeatFill",    SpriteFactory.makeHudHeatFill),
        ]

        let s = Float(size)

        for entry in Self.layout {
            guard let gen = generators.first(where: { $0.0 == entry.name }) else { continue }
            let (pixels, w, h) = gen.1()
            guard pixels.count == w * h * 4 else { continue }

            pixels.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                tex.replace(
                    region: MTLRegionMake2D(entry.x, entry.y, w, h),
                    mipmapLevel: 0,
                    withBytes: base,
                    bytesPerRow: w * 4
                )
            }

            uvRects[entry.name] = SIMD4<Float>(
                Float(entry.x) / s,
                Float(entry.y) / s,
                Float(entry.width) / s,
                Float(entry.height) / s
            )
        }

        // Store white pixel UV for fallback
        uvRects["_white"] = SIMD4<Float>(Float(size - 1) / s, Float(size - 1) / s, 1.0 / s, 1.0 / s)
    }

    public func uvRect(for spriteId: String) -> SIMD4<Float>? {
        uvRects[spriteId]
    }

    public var whitePixelUV: SIMD4<Float> {
        uvRects["_white"] ?? SIMD4<Float>(255.0 / 256.0, 255.0 / 256.0, 1.0 / 256.0, 1.0 / 256.0)
    }
}
