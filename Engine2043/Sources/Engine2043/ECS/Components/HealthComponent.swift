import GameplayKit

public final class HealthComponent: GKComponent {
    public var currentHealth: Float = 100
    public var maxHealth: Float = 100
    public var isInvulnerable: Bool = false
    public var invulnerabilityTimer: Double = 0
    public static let invulnerabilityDuration: Double = 0.5

    public override init() { super.init() }

    public convenience init(health: Float) {
        self.init()
        self.currentHealth = health
        self.maxHealth = health
    }

    public var isAlive: Bool { currentHealth > 0 }

    public func takeDamage(_ amount: Float) {
        guard !isInvulnerable else { return }
        currentHealth = max(0, currentHealth - amount)
        isInvulnerable = true
        invulnerabilityTimer = Self.invulnerabilityDuration
    }

    public func updateInvulnerability(deltaTime: Double) {
        guard isInvulnerable else { return }
        invulnerabilityTimer -= deltaTime
        if invulnerabilityTimer <= 0 {
            isInvulnerable = false
            invulnerabilityTimer = 0
        }
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
