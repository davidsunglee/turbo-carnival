import GameplayKit

public final class ShieldDroneComponent: GKComponent {
    public weak var ownerEntity: GKEntity?
    public var orbitAngle: Float = 0
    public var orbitSpeed: Float = GameConfig.ShieldDrone.orbitSpeed
    public var orbitRadius: Float = GameConfig.ShieldDrone.orbitRadius
    public var hitsRemaining: Int = GameConfig.ShieldDrone.hitsPerDrone

    public var isDestroyed: Bool { hitsRemaining <= 0 }

    public func takeHit() {
        hitsRemaining -= 1
    }

    public override init() { super.init() }
    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
