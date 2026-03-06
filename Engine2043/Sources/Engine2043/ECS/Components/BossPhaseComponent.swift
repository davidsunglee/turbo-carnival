import GameplayKit

public final class BossPhaseComponent: GKComponent {
    public var currentPhase: Int = 0
    public var phaseThresholds: [Float] = [0.6, 0.3]
    public var totalHP: Float = 30
    public var isScrollLocked: Bool = false
    public var isDefeated: Bool = false
    public var shieldRotation: Float = 0
    public var shieldSpeed: Float = 1.5

    public override init() { super.init() }

    public convenience init(totalHP: Float) {
        self.init()
        self.totalHP = totalHP
    }

    public func updatePhase(healthFraction: Float) {
        for (i, threshold) in phaseThresholds.enumerated() {
            if healthFraction <= threshold {
                currentPhase = i + 1
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
