import GameplayKit

public struct ProjectileEffect: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let empDisable = ProjectileEffect(rawValue: 1 << 0)
}

public final class ProjectileComponent: GKComponent {
    public var damage: Float = 1.0
    public var effects: ProjectileEffect = []
    public var lifetime: Double = 5.0
    public var age: Double = 0
    public var isHoming: Bool = false
    public var homingTurnRate: Float = 0
    public var speed: Float = 300

    public var isExpired: Bool { age >= lifetime }

    public override init() { super.init() }

    public convenience init(damage: Float, speed: Float, effects: ProjectileEffect = []) {
        self.init()
        self.damage = damage
        self.speed = speed
        self.effects = effects
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
