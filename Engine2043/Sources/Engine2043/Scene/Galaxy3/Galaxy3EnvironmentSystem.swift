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

    /// Update lane bounds based on active barrier entities.
    /// Finds the leftmost right-edge and rightmost left-edge of barriers
    /// to determine the passable corridor.
    public func updateLaneBounds(barriers: [GKEntity]) {
        guard !barriers.isEmpty else {
            activeLaneBounds = LaneBounds()
            return
        }

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
