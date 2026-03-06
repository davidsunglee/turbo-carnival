import GameplayKit
import simd

public final class TurretComponent: GKComponent {
    public var trackingSpeed: Float = 1.0
    public var fireInterval: Double = 1.5
    public var timeSinceLastShot: Double = 0
    public var projectileSpeed: Float = 300
    public var damage: Float = 1.0
    public weak var parentEntity: GKEntity?
    public var mountOffset: SIMD2<Float> = .zero

    public override init() { super.init() }

    public convenience init(trackingSpeed: Float) {
        self.init()
        self.trackingSpeed = trackingSpeed
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
