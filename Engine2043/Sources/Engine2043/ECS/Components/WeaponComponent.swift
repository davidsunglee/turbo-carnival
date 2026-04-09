import GameplayKit

public enum WeaponType: Int, CaseIterable, Sendable {
    case doubleCannon = 0
    case triSpread = 1
    case lightningArc = 2
    case phaseLaser = 3
}

public enum SecondaryType: Sendable {
    case gravBomb
    case empSweep
    case overcharge
}

public final class WeaponComponent: GKComponent {
    public var fireRate: Double = 5.0
    public var damage: Float = 1.0
    public var projectileSpeed: Float = 400.0
    public var timeSinceLastShot: Double = 0
    public var isFiring: Bool = false
    public var weaponType: WeaponType = .doubleCannon
    public var secondaryCharges: Int = 1
    public var secondaryFiring: SecondaryType? = nil
    public var secondaryCooldown: Double = 0.5
    public var firesDownward: Bool = false

    // Phase Laser state
    public var laserHeat: Double = 0
    public var isLaserOverheated: Bool = false
    public var laserOverheatTimer: Double = 0

    // Overcharge state
    public var overchargeActive: Bool = false
    public var overchargeTimer: Double = 0

    // Secondary-disable state (e.g. from EMP attacks)
    public var secondaryDisabled: Bool = false
    public var secondaryDisableTimer: Double = 0

    public override init() { super.init() }

    public convenience init(fireRate: Double, damage: Float, projectileSpeed: Float) {
        self.init()
        self.fireRate = fireRate
        self.damage = damage
        self.projectileSpeed = projectileSpeed
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
