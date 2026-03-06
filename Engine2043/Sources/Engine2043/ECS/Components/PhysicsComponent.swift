import GameplayKit
import simd

public final class PhysicsComponent: GKComponent {
    public var velocity: SIMD2<Float> = .zero
    public var acceleration: SIMD2<Float> = .zero
    public var collisionSize: SIMD2<Float> = .zero
    public var collisionLayer: CollisionLayer = []
    public var collisionMask: CollisionLayer = []

    public override init() { super.init() }

    public convenience init(
        collisionSize: SIMD2<Float>,
        layer: CollisionLayer,
        mask: CollisionLayer
    ) {
        self.init()
        self.collisionSize = collisionSize
        self.collisionLayer = layer
        self.collisionMask = mask
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
