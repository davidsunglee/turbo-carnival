import GameplayKit
import simd

@MainActor
public final class AsteroidSystem {
    private var entities: [GKEntity] = []
    public private(set) var pendingRemovals: [GKEntity] = []

    // Random source for spawn positions and size selection
    private let rng = GKRandomSource.sharedRandom()

    public init() {}

    /// Called by the scene when SpawnDirector emits a pendingAsteroidField.
    /// Creates `count` asteroid entities with random sizes based on `largeFraction`.
    /// Positions are random X within viewport width, Y spread from `spawnYBase` to `spawnYBase + 200`.
    /// Returns the new entities; the scene is responsible for calling `register(_:)`.
    @discardableResult
    public func spawnField(count: Int, largeFraction: Float, spawnYBase: Float,
                            viewportHalfWidth: Float) -> [GKEntity] {
        var spawned: [GKEntity] = []
        for _ in 0..<count {
            let isLarge = Float.random(in: 0..<1) < largeFraction
            let size: AsteroidSize = isLarge ? .large : .small
            let x = Float.random(in: -viewportHalfWidth...viewportHalfWidth)
            let y = spawnYBase + Float.random(in: 0...200)
            let entity = makeAsteroid(size: size, position: SIMD2(x, y))
            spawned.append(entity)
        }
        return spawned
    }

    /// Spawn sparse background asteroids scattered across the full viewport height.
    /// Called once at scene init.
    /// Returns the new entities; the scene is responsible for calling `register(_:)`.
    @discardableResult
    public func spawnSparseLayer(count: Int, viewportHalfWidth: Float,
                                  fieldHeight: Float) -> [GKEntity] {
        var spawned: [GKEntity] = []
        for _ in 0..<count {
            let isLarge = Float.random(in: 0..<1) < GameConfig.Galaxy2.Asteroid.denseFieldLargeFraction
            let size: AsteroidSize = isLarge ? .large : .small
            let x = Float.random(in: -viewportHalfWidth...viewportHalfWidth)
            let y = Float.random(in: 0...fieldHeight)
            let entity = makeAsteroid(size: size, position: SIMD2(x, y))
            spawned.append(entity)
        }
        return spawned
    }

    public func register(_ entity: GKEntity) {
        entities.append(entity)
    }

    public func unregister(_ entity: GKEntity) {
        entities.removeAll { $0 === entity }
    }

    /// Scrolls all registered asteroids downward and collects off-screen entities in `pendingRemovals`.
    public func update(deltaTime: Double) {
        pendingRemovals.removeAll(keepingCapacity: true)

        let dy = GameConfig.Galaxy2.Asteroid.scrollSpeed * Float(deltaTime)

        for entity in entities {
            guard let transform = entity.component(ofType: TransformComponent.self),
                  let asteroid = entity.component(ofType: AsteroidComponent.self) else { continue }

            transform.position.y -= dy

            // Off-screen check: asteroid has scrolled below the visible area.
            // Use the render size for the bottom threshold.
            let halfHeight: Float
            if asteroid.asteroidSize == .large {
                halfHeight = GameConfig.Galaxy2.Asteroid.largeSize.y / 2
            } else {
                halfHeight = GameConfig.Galaxy2.Asteroid.smallSize.y / 2
            }

            if transform.position.y < -halfHeight {
                pendingRemovals.append(entity)
            }
        }
    }

    // MARK: - Private helpers

    private func makeAsteroid(size: AsteroidSize, position: SIMD2<Float>) -> GKEntity {
        let entity = GKEntity()

        let transform = TransformComponent(position: position)
        entity.addComponent(transform)

        let collisionSize: SIMD2<Float>
        let color: SIMD4<Float>
        if size == .large {
            collisionSize = GameConfig.Galaxy2.Asteroid.largeSize
            color = GameConfig.Galaxy2.Palette.g2AsteroidLarge
        } else {
            collisionSize = GameConfig.Galaxy2.Asteroid.smallSize
            color = GameConfig.Galaxy2.Palette.g2AsteroidSmall
        }

        let physics = PhysicsComponent(
            collisionSize: collisionSize,
            layer: .asteroid,
            mask: [.player, .playerProjectile]
        )
        entity.addComponent(physics)

        let render = RenderComponent(size: collisionSize, color: color)
        entity.addComponent(render)

        let asteroid = AsteroidComponent(size: size)
        entity.addComponent(asteroid)

        if size == .small {
            entity.addComponent(HealthComponent(health: GameConfig.Galaxy2.Asteroid.smallHP))
            entity.addComponent(ScoreComponent(points: GameConfig.Galaxy2.Score.asteroidSmall))
        }

        return entity
    }
}
