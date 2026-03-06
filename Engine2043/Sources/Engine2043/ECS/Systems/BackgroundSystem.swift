import simd

@MainActor
public final class BackgroundSystem {
    public private(set) var scrollDistance: Float = 0

    private var starPositions: [SIMD2<Float>] = []
    private var starSizes: [SIMD2<Float>] = []
    private var nebulaPositions: [SIMD2<Float>] = []
    private var nebulaSizes: [SIMD2<Float>] = []

    private let fieldHeight: Float
    private let halfWidth: Float
    private let halfHeight: Float

    public var isScrollLocked: Bool = false

    public init() {
        halfWidth = GameConfig.designWidth / 2
        halfHeight = GameConfig.designHeight / 2
        fieldHeight = GameConfig.designHeight + 100

        var seed: UInt64 = 42
        for _ in 0..<GameConfig.Background.starCount {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = Float(Int(seed >> 33) % Int(GameConfig.designWidth)) - halfWidth
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let y = Float(Int(seed >> 33) % Int(fieldHeight)) - halfHeight
            starPositions.append(SIMD2(x, y))
            let s: Float = Float(2 + Int(seed >> 60) % 2)
            starSizes.append(SIMD2(s, s))
        }

        for _ in 0..<GameConfig.Background.nebulaCount {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = Float(Int(seed >> 33) % Int(GameConfig.designWidth)) - halfWidth
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let y = Float(Int(seed >> 33) % Int(fieldHeight)) - halfHeight
            nebulaPositions.append(SIMD2(x, y))
            let s = Float(8 + Int(seed >> 60) % 9)
            nebulaSizes.append(SIMD2(s, s))
        }
    }

    public func update(deltaTime: Double) {
        guard !isScrollLocked else { return }
        let dt = Float(deltaTime)
        scrollDistance += GameConfig.Background.starScrollSpeed * dt

        for i in starPositions.indices {
            starPositions[i].y -= GameConfig.Background.starScrollSpeed * dt
            if starPositions[i].y < -halfHeight - 50 {
                starPositions[i].y += fieldHeight
            }
        }

        for i in nebulaPositions.indices {
            nebulaPositions[i].y -= GameConfig.Background.nebulaScrollSpeed * dt
            if nebulaPositions[i].y < -halfHeight - 50 {
                nebulaPositions[i].y += fieldHeight
            }
        }
    }

    public func collectSprites() -> [SpriteInstance] {
        var sprites: [SpriteInstance] = []
        sprites.reserveCapacity(starPositions.count + nebulaPositions.count)

        let starColor = SIMD4<Float>(0.6, 0.7, 0.9, 0.5)
        for i in starPositions.indices {
            sprites.append(SpriteInstance(
                position: starPositions[i],
                size: starSizes[i],
                color: starColor
            ))
        }

        let nebulaColor = SIMD4<Float>(
            GameConfig.Palette.midground.x,
            GameConfig.Palette.midground.y,
            GameConfig.Palette.midground.z,
            0.15
        )
        for i in nebulaPositions.indices {
            sprites.append(SpriteInstance(
                position: nebulaPositions[i],
                size: nebulaSizes[i],
                color: nebulaColor
            ))
        }

        return sprites
    }
}
