import GameplayKit

public final class WeaponComponent: GKComponent {
    public var fireRate: Double = 5.0
    public var damage: Float = 1.0
    public var projectileSpeed: Float = 400.0
    public var timeSinceLastShot: Double = 0
    public var isFiring: Bool = false

    public override init() { super.init() }

    public convenience init(fireRate: Double, damage: Float, projectileSpeed: Float) {
        self.init()
        self.fireRate = fireRate
        self.damage = damage
        self.projectileSpeed = projectileSpeed
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
