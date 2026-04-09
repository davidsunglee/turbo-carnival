import GameplayKit
import simd

@MainActor
public final class Galaxy3EnvironmentSystem {
    public private(set) var scrollDistance: Float = 0
    public var scrollSpeed: Float = 40
    public var isScrollLocked: Bool = false

    // Megastructure plating sprites (decorative, scrolled with environment)
    public var platingEntities: [GKEntity] = []

    // Active barrier bounds for corridor math
    public struct LaneBounds: Sendable {
        public var leftWall: Float
        public var rightWall: Float
        public var isActive: Bool

        public init(leftWall: Float = -GameConfig.designWidth / 2, rightWall: Float = GameConfig.designWidth / 2, isActive: Bool = false) {
            self.leftWall = leftWall
            self.rightWall = rightWall
            self.isActive = isActive
        }
    }

    public private(set) var activeLaneBounds: LaneBounds = LaneBounds()

    public init() {}

    // Track total scroll for plating spawn cadence
    private var lastPlatingSpawnDistance: Float = 0
    private let platingSpawnInterval: Float = 200

    public func update(deltaTime: Double) {
        guard !isScrollLocked else { return }
        scrollDistance += scrollSpeed * Float(deltaTime)

        // Scroll plating entities downward
        for entity in platingEntities {
            guard let transform = entity.component(ofType: TransformComponent.self) else { continue }
            transform.position.y -= scrollSpeed * Float(deltaTime)
        }

        // Remove off-screen plating entities (below the visible area)
        platingEntities.removeAll { entity in
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let render = entity.component(ofType: RenderComponent.self) else {
                return true
            }
            return transform.position.y + render.size.y / 2 < -50
        }

        // Spawn decorative plating pairs as the player scrolls
        if scrollDistance - lastPlatingSpawnDistance >= platingSpawnInterval {
            lastPlatingSpawnDistance = scrollDistance
            spawnPlatingPair()
        }
    }

    /// Spawns a pair of decorative hull strip entities at the top of the screen.
    private func spawnPlatingPair() {
        let spawnY = GameConfig.designHeight / 2 + 40
        let hullSize = GameConfig.Galaxy3.Enemy.fortressHullSize
        let halfDesign = GameConfig.designWidth / 2

        // Left plating strip — positioned along the left edge
        let leftX = -halfDesign + hullSize.x / 2 - 20
        let leftEntity = GKEntity()
        leftEntity.addComponent(TransformComponent(position: SIMD2(leftX, spawnY)))
        let leftRender = RenderComponent(size: hullSize, color: GameConfig.Galaxy3.Palette.g3FortressHull)
        leftRender.spriteId = "g3FortressHull"
        leftEntity.addComponent(leftRender)
        platingEntities.append(leftEntity)

        // Right plating strip — positioned along the right edge
        let rightX = halfDesign - hullSize.x / 2 + 20
        let rightEntity = GKEntity()
        rightEntity.addComponent(TransformComponent(position: SIMD2(rightX, spawnY)))
        let rightRender = RenderComponent(size: hullSize, color: GameConfig.Galaxy3.Palette.g3FortressHull)
        rightRender.spriteId = "g3FortressHull"
        rightEntity.addComponent(rightRender)
        platingEntities.append(rightEntity)
    }

    public func lockScroll() {
        isScrollLocked = true
    }

    public func unlockScroll() {
        isScrollLocked = false
    }

    /// Resets lane bounds to inactive, clearing any corridor restriction.
    public func resetLaneBounds() {
        activeLaneBounds = LaneBounds()
    }

    /// Update lane bounds based on active barrier entities near the player.
    /// Only barriers within ±100 units of the player's Y position contribute,
    /// so restrictions feel local rather than globally aggregated.
    public func updateLaneBounds(barriers: [GKEntity], playerY: Float = 0) {
        guard !barriers.isEmpty else {
            activeLaneBounds = LaneBounds()
            return
        }

        let yBand: Float = 100  // only consider barriers within this distance of player Y

        // Positions are centered around 0, not 0...designWidth
        let halfDesign = GameConfig.designWidth / 2
        var leftWall: Float = -halfDesign
        var rightWall: Float = halfDesign
        var foundBarriers = false

        for entity in barriers {
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self) else {
                continue
            }

            // Filter to barriers intersecting the player's Y band
            let halfHeight = physics.collisionSize.y / 2
            let barrierTop = transform.position.y + halfHeight
            let barrierBottom = transform.position.y - halfHeight
            guard barrierTop >= playerY - yBand && barrierBottom <= playerY + yBand else {
                continue
            }

            let halfWidth = physics.collisionSize.x / 2
            let barrierLeft = transform.position.x - halfWidth
            let barrierRight = transform.position.x + halfWidth

            // Barriers on the left side (position < 0) push the left wall right
            if transform.position.x < 0 {
                leftWall = max(leftWall, barrierRight)
            }
            // Barriers on the right side (position > 0) push the right wall left
            if transform.position.x > 0 {
                rightWall = min(rightWall, barrierLeft)
            }

            foundBarriers = true
        }

        activeLaneBounds = LaneBounds(
            leftWall: leftWall,
            rightWall: rightWall,
            isActive: foundBarriers
        )
    }
}
