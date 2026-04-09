import GameplayKit

public enum BarrierKind: Sendable {
    case trenchWall
    case rotatingGate
}

public final class BarrierComponent: GKComponent {
    public var kind: BarrierKind = .trenchWall
    public var contactDamage: Float = GameConfig.Galaxy3.Barrier.collisionDamage
    public var rotationSpeed: Float = 0
    public var currentAngle: Float = 0

    public override init() { super.init() }

    public convenience init(kind: BarrierKind) {
        self.init()
        self.kind = kind
        if kind == .rotatingGate {
            self.rotationSpeed = GameConfig.Galaxy3.Barrier.rotatingGateSpeed
        }
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
