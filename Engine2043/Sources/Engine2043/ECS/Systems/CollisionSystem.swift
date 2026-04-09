import GameplayKit
import simd

// MARK: - QuadTree

@MainActor
final class QuadTree {
    static let maxEntries = 8
    static let maxDepth = 6

    let bounds: AABB
    var entries: [(index: Int, bounds: AABB)] = []
    var children: [QuadTree]?

    init(bounds: AABB) {
        self.bounds = bounds
    }

    func insert(index: Int, entityBounds: AABB, depth: Int = 0) {
        guard bounds.intersects(entityBounds) else { return }

        if let children {
            for child in children {
                child.insert(index: index, entityBounds: entityBounds, depth: depth + 1)
            }
            return
        }

        entries.append((index, entityBounds))

        if entries.count > Self.maxEntries && depth < Self.maxDepth {
            subdivide(depth: depth)
        }
    }

    func query(bounds queryBounds: AABB, results: inout [Int]) {
        guard bounds.intersects(queryBounds) else { return }

        for entry in entries {
            if entry.bounds.intersects(queryBounds) {
                results.append(entry.index)
            }
        }

        if let children {
            for child in children {
                child.query(bounds: queryBounds, results: &results)
            }
        }
    }

    private func subdivide(depth: Int) {
        let mid = (bounds.min + bounds.max) * 0.5
        children = [
            QuadTree(bounds: AABB(min: bounds.min, max: mid)),
            QuadTree(bounds: AABB(min: SIMD2(mid.x, bounds.min.y), max: SIMD2(bounds.max.x, mid.y))),
            QuadTree(bounds: AABB(min: SIMD2(bounds.min.x, mid.y), max: SIMD2(mid.x, bounds.max.y))),
            QuadTree(bounds: AABB(min: mid, max: bounds.max)),
        ]

        let oldEntries = entries
        entries = []
        for entry in oldEntries {
            for child in children! {
                child.insert(index: entry.index, entityBounds: entry.bounds, depth: depth + 1)
            }
        }
    }
}

// MARK: - CollisionSystem

@MainActor
public final class CollisionSystem {
    private var entities: ContiguousArray<GKEntity> = []
    private var positions: ContiguousArray<SIMD2<Float>> = []
    private var halfExtents: ContiguousArray<SIMD2<Float>> = []
    private var layers: ContiguousArray<CollisionLayer> = []
    private var masks: ContiguousArray<CollisionLayer> = []
    private var entityIndices: [ObjectIdentifier: Int] = [:]

    public private(set) var collisionPairs: [(GKEntity, GKEntity)] = []

    public let worldBounds: AABB

    public init(worldBounds: AABB) {
        self.worldBounds = worldBounds
    }

    public func register(_ entity: GKEntity) {
        guard let physics = entity.component(ofType: PhysicsComponent.self),
              entity.component(ofType: TransformComponent.self) != nil,
              !physics.collisionLayer.isEmpty else { return }
        guard entityIndices[ObjectIdentifier(entity)] == nil else { return }

        let transform = entity.component(ofType: TransformComponent.self)!
        let index = entities.count
        entityIndices[ObjectIdentifier(entity)] = index
        entities.append(entity)
        positions.append(transform.position)
        halfExtents.append(physics.collisionSize * 0.5)
        layers.append(physics.collisionLayer)
        masks.append(physics.collisionMask)
    }

    public func unregister(_ entity: GKEntity) {
        guard let index = entityIndices.removeValue(forKey: ObjectIdentifier(entity)) else { return }
        let lastIndex = entities.count - 1
        if index != lastIndex {
            entities[index] = entities[lastIndex]
            positions[index] = positions[lastIndex]
            halfExtents[index] = halfExtents[lastIndex]
            layers[index] = layers[lastIndex]
            masks[index] = masks[lastIndex]
            entityIndices[ObjectIdentifier(entities[index])] = index
        }
        entities.removeLast()
        positions.removeLast()
        halfExtents.removeLast()
        layers.removeLast()
        masks.removeLast()
    }

    public func update(time: GameTime) {
        // Sync positions and physics data from components each frame so that
        // runtime mutations (e.g. shield toggle, rotating gate resize) take effect.
        for i in entities.indices {
            if let transform = entities[i].component(ofType: TransformComponent.self) {
                positions[i] = transform.position
            }
            if let physics = entities[i].component(ofType: PhysicsComponent.self) {
                halfExtents[i] = physics.collisionSize * 0.5
                layers[i] = physics.collisionLayer
                masks[i] = physics.collisionMask
            }
        }

        // Build QuadTree
        let tree = QuadTree(bounds: worldBounds)
        for i in positions.indices {
            let aabb = AABB(center: positions[i], halfExtents: halfExtents[i])
            tree.insert(index: i, entityBounds: aabb)
        }

        // Detect collisions
        collisionPairs.removeAll(keepingCapacity: true)
        var queryResults: [Int] = []

        for i in positions.indices {
            guard !masks[i].isEmpty else { continue }
            let aabb = AABB(center: positions[i], halfExtents: halfExtents[i])
            queryResults.removeAll(keepingCapacity: true)
            tree.query(bounds: aabb, results: &queryResults)

            for j in queryResults where j > i {
                let layerMatch = !layers[j].intersection(masks[i]).isEmpty ||
                                 !layers[i].intersection(masks[j]).isEmpty
                guard layerMatch else { continue }

                let aabbJ = AABB(center: positions[j], halfExtents: halfExtents[j])
                if aabb.intersects(aabbJ) {
                    collisionPairs.append((entities[i], entities[j]))
                }
            }
        }
    }
}
