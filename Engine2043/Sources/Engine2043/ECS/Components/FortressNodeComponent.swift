import GameplayKit

public enum FortressNodeRole: Sendable {
    case shieldGenerator
    case mainBattery
    case pulseTurret
}

public final class FortressNodeComponent: GKComponent {
    public var role: FortressNodeRole = .pulseTurret
    public var isShielded: Bool = true
    public var fortressID: Int = 0
    public var fireInterval: Double = 2.0
    public var timeSinceLastShot: Double = 0

    public override init() { super.init() }

    public convenience init(role: FortressNodeRole, fortressID: Int) {
        self.init()
        self.role = role
        self.fortressID = fortressID
        switch role {
        case .shieldGenerator:
            self.fireInterval = 0 // does not fire
        case .mainBattery:
            self.fireInterval = 2.5
        case .pulseTurret:
            self.fireInterval = 1.5
        }
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
