import GameplayKit
import simd

public enum SteeringBehavior: Sendable {
    case hover
    case strafe
    case leadShot
    case tracking
}

public final class SteeringComponent: GKComponent {
    public var behavior: SteeringBehavior = .hover
    public var hoverY: Float = 100
    public var steerStrength: Float = 2.0
    public var hasReachedHover: Bool = false
    public var strafeDirection: Float = 1

    public override init() { super.init() }

    public convenience init(behavior: SteeringBehavior) {
        self.init()
        self.behavior = behavior
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
