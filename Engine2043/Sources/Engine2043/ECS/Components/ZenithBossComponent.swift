import GameplayKit

public enum ZenithPhase: Int, Sendable {
    case intro = 0
    case phase1 = 1
    case phase2 = 2
    case phase3 = 3
    case phase4 = 4
    case defeated = 5
}

public final class ZenithBossComponent: GKComponent {
    public var phaseThresholds: [Float] = GameConfig.Galaxy3.Enemy.bossPhaseThresholds
    public var currentPhase: ZenithPhase = .intro
    public var isShieldActive: Bool = false
    public var scrollLockRequested: Bool = false
    public var isDefeated: Bool = false

    public override init() { super.init() }

    public func updatePhase(healthFraction: Float) {
        guard currentPhase != .defeated else { return }

        var newPhase: ZenithPhase = .phase1
        for (i, threshold) in phaseThresholds.enumerated() {
            if healthFraction <= threshold {
                // phase2 at index 0 (0.75), phase3 at index 1 (0.50), phase4 at index 2 (0.25)
                newPhase = ZenithPhase(rawValue: i + 2) ?? newPhase
            }
        }
        currentPhase = newPhase
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
