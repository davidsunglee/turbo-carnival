import GameplayKit
import simd

public typealias Entity = GKEntity

public struct CollisionLayer: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let player            = CollisionLayer(rawValue: 1 << 0)
    public static let playerProjectile  = CollisionLayer(rawValue: 1 << 1)
    public static let enemy             = CollisionLayer(rawValue: 1 << 2)
    public static let enemyProjectile   = CollisionLayer(rawValue: 1 << 3)
    public static let item              = CollisionLayer(rawValue: 1 << 4)
    public static let bossShield        = CollisionLayer(rawValue: 1 << 5)
    public static let blast             = CollisionLayer(rawValue: 1 << 6)
}

public struct AABB: Sendable {
    public var min: SIMD2<Float>
    public var max: SIMD2<Float>

    public static let zero = AABB(min: .zero, max: .zero)

    public init(min: SIMD2<Float>, max: SIMD2<Float>) {
        self.min = min
        self.max = max
    }

    public init(center: SIMD2<Float>, halfExtents: SIMD2<Float>) {
        self.min = center - halfExtents
        self.max = center + halfExtents
    }

    public func intersects(_ other: AABB) -> Bool {
        min.x <= other.max.x && max.x >= other.min.x &&
        min.y <= other.max.y && max.y >= other.min.y
    }
}
