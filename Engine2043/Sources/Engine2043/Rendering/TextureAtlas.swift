import Metal
import simd

@MainActor
public final class TextureAtlas {
    public let texture: MTLTexture
    private var uvRects: [String: SIMD4<Float>] = [:]

    public static let atlasSize = 512

    public static let spriteNames: Set<String> = [
        "player", "swarmer", "bruiser", "capitalHull", "turret", "bossCore", "bossShield",
        "playerBullet", "triSpreadBullet", "lightningArcIcon", "enemyBullet", "gravBombSprite",
        "energyDrop", "chargeCell", "shieldDrop", "shieldDrone",
        "weaponDoubleCannon", "weaponTriSpread", "weaponLightningArc", "weaponPhaseLaser",
        "asteroidSmall", "asteroidLarge", "miningBargeHull", "miningBargeTurret",
        "lithicHarvesterCore", "tractorBeamSegment", "g2Interceptor", "g2Fighter"
    ]

    struct SpriteEntry {
        let name: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    static let layout: [SpriteEntry] = [
        SpriteEntry(name: "player",      x: 0,   y: 0,   width: 48,  height: 48),
        SpriteEntry(name: "swarmer",     x: 48,  y: 0,   width: 32,  height: 32),
        SpriteEntry(name: "bruiser",     x: 80,  y: 0,   width: 40,  height: 40),
        SpriteEntry(name: "capitalHull", x: 0,   y: 48,  width: 140, height: 60),
        SpriteEntry(name: "turret",      x: 140, y: 48,  width: 24,  height: 24),
        SpriteEntry(name: "bossCore",    x: 0,   y: 108, width: 64,  height: 64),
        SpriteEntry(name: "bossShield",  x: 64,  y: 108, width: 40,  height: 12),
        // Row 172: Projectiles
        SpriteEntry(name: "playerBullet",    x: 0,   y: 172, width: 6,  height: 12),
        SpriteEntry(name: "triSpreadBullet", x: 6,   y: 172, width: 8,  height: 8),
        SpriteEntry(name: "lightningArcIcon", x: 14, y: 172, width: 8, height: 8),
        SpriteEntry(name: "enemyBullet",     x: 18,  y: 172, width: 8,  height: 8),
        SpriteEntry(name: "gravBombSprite",  x: 26,  y: 172, width: 16, height: 16),
        // Row 188: Pickups
        SpriteEntry(name: "energyDrop",          x: 0,   y: 188, width: 24, height: 24),
        SpriteEntry(name: "chargeCell",          x: 24,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponDoubleCannon",  x: 48,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponTriSpread",     x: 72,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponLightningArc",  x: 96,  y: 188, width: 24, height: 24),
        SpriteEntry(name: "weaponPhaseLaser",    x: 120, y: 188, width: 24, height: 24),
        SpriteEntry(name: "shieldDrop",          x: 144, y: 188, width: 24, height: 24),
        SpriteEntry(name: "shieldDrone",         x: 168, y: 188, width: 10, height: 10),
        // Row 212: Galaxy 2 small enemies and asteroids
        SpriteEntry(name: "asteroidSmall",        x: 0,   y: 212, width: 16, height: 16),
        SpriteEntry(name: "asteroidLarge",        x: 16,  y: 212, width: 40, height: 40),
        SpriteEntry(name: "g2Interceptor",        x: 56,  y: 212, width: 20, height: 20),
        SpriteEntry(name: "g2Fighter",            x: 76,  y: 212, width: 40, height: 40),
        // Row 252: Mining barge
        SpriteEntry(name: "miningBargeHull",      x: 0,   y: 252, width: 108, height: 50),
        SpriteEntry(name: "miningBargeTurret",    x: 108, y: 252, width: 24,  height: 24),
        // Row 302: Lithic Harvester boss
        SpriteEntry(name: "lithicHarvesterCore",  x: 0,   y: 302, width: 80,  height: 80),
        SpriteEntry(name: "tractorBeamSegment",   x: 80,  y: 302, width: 4,   height: 32),
    ]

    public var defaultTexture: MTLTexture { texture }

    init(device: MTLDevice) throws {
        let size = Self.atlasSize
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

        // Place white 1x1 pixel at (511, 511) as fallback
        let white: [UInt8] = [255, 255, 255, 255]
        tex.replace(
            region: MTLRegionMake2D(size - 1, size - 1, 1, 1),
            mipmapLevel: 0,
            withBytes: white,
            bytesPerRow: 4
        )

        let s = Float(size)
        uvRects["_white"] = SIMD4<Float>(Float(size - 1) / s, Float(size - 1) / s, 1.0 / s, 1.0 / s)

        // Generate and blit all sprites
        let generators: [(String, () -> (pixels: [UInt8], width: Int, height: Int))] = [
            ("player",      SpriteFactory.makePlayerShip),
            ("swarmer",     SpriteFactory.makeSwarmer),
            ("bruiser",     SpriteFactory.makeBruiser),
            ("capitalHull", SpriteFactory.makeCapitalHull),
            ("turret",      SpriteFactory.makeTurret),
            ("bossCore",    SpriteFactory.makeBossCore),
            ("bossShield",  SpriteFactory.makeBossShield),
            ("playerBullet",    SpriteFactory.makePlayerBullet),
            ("triSpreadBullet", SpriteFactory.makeTriSpreadBullet),
            ("lightningArcIcon", SpriteFactory.makeLightningArcIcon),
            ("enemyBullet",     SpriteFactory.makeEnemyBullet),
            ("gravBombSprite",  SpriteFactory.makeGravBombSprite),
            ("energyDrop",      SpriteFactory.makeEnergyDrop),
            ("chargeCell",      SpriteFactory.makeChargeCell),
            ("weaponDoubleCannon",  SpriteFactory.makeDoubleCannonDrop),
            ("weaponTriSpread",     SpriteFactory.makeTriSpreadDrop),
            ("weaponLightningArc",  SpriteFactory.makeLightningArcDrop),
            ("weaponPhaseLaser",    SpriteFactory.makePhaseLaserDrop),
            ("shieldDrop",           SpriteFactory.makeShieldDrop),
            ("shieldDrone",          SpriteFactory.makeShieldDrone),
            ("asteroidSmall",        SpriteFactory.makeAsteroidSmall),
            ("asteroidLarge",        SpriteFactory.makeAsteroidLarge),
            ("g2Interceptor",        SpriteFactory.makeG2Interceptor),
            ("g2Fighter",            SpriteFactory.makeG2Fighter),
            ("miningBargeHull",      SpriteFactory.makeMiningBargeHull),
            ("miningBargeTurret",    SpriteFactory.makeMiningBargeTurret),
            ("lithicHarvesterCore",  SpriteFactory.makeLithicHarvesterCore),
            ("tractorBeamSegment",   SpriteFactory.makeTractorBeamSegment),
        ]

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
    }

    public func uvRect(for spriteId: String?) -> SIMD4<Float> {
        guard let id = spriteId, let rect = uvRects[id] else {
            return uvRects["_white"] ?? SpriteInstance.defaultUVRect
        }
        return rect
    }
}
