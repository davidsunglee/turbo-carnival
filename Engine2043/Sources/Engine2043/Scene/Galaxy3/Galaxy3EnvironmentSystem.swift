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

        public init(leftWall: Float = 0, rightWall: Float = GameConfig.designWidth, isActive: Bool = false) {
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

    /// Update lane bounds based on active barrier entities.
    /// Finds the leftmost right-edge and rightmost left-edge of barriers
    /// to determine the passable corridor.
    public func updateLaneBounds(barriers: [GKEntity]) {
        guard !barriers.isEmpty else {
            activeLaneBounds = LaneBounds()
            return
        }

        var leftWall: Float = 0
        var rightWall: Float = GameConfig.designWidth
        var foundBarriers = false

        for entity in barriers {
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let physics = entity.component(ofType: PhysicsComponent.self) else {
                continue
            }

            let halfWidth = physics.collisionSize.x / 2
            let barrierLeft = transform.position.x - halfWidth
            let barrierRight = transform.position.x + halfWidth

            // Barriers on the left side push the left wall right
            if transform.position.x < GameConfig.designWidth / 2 {
                leftWall = max(leftWall, barrierRight)
            }
            // Barriers on the right side push the right wall left
            if transform.position.x > GameConfig.designWidth / 2 {
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
