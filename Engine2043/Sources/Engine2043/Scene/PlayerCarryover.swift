/// Captures player state that transfers between galaxies.
/// Energy is always reset to 100 by the receiving scene.
public struct PlayerCarryover: Sendable {
    public let weaponType: WeaponType
    public let score: Int
    public let secondaryCharges: Int
    public let shieldDroneCount: Int
    public let enemiesDestroyed: Int
    public let elapsedTime: Double

    public init(
        weaponType: WeaponType,
        score: Int,
        secondaryCharges: Int,
        shieldDroneCount: Int,
        enemiesDestroyed: Int,
        elapsedTime: Double
    ) {
        self.weaponType = weaponType
        self.score = score
        self.secondaryCharges = secondaryCharges
        self.shieldDroneCount = shieldDroneCount
        self.enemiesDestroyed = enemiesDestroyed
        self.elapsedTime = elapsedTime
    }
}
