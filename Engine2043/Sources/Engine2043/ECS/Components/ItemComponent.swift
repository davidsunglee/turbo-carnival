import GameplayKit

public enum UtilityItemType: Int, CaseIterable, Sendable {
    case energyCell = 0
    case chargeCell = 1
    case scoreBonus = 2
}

public final class ItemComponent: GKComponent {
    public var currentCycleIndex: Int = 0
    public var timeAlive: Double = 0
    public var bounceDirection: Float = 1
    public var isWeaponModule: Bool = false

    // For weapon module: which weapon is currently displayed
    public var displayedWeapon: WeaponType = .doubleCannon
    // Weapons available to cycle through (excludes current player weapon)
    public var weaponCycle: [WeaponType] = []
    public var weaponCycleIndex: Int = 0

    public var utilityItemType: UtilityItemType {
        UtilityItemType(rawValue: currentCycleIndex % UtilityItemType.allCases.count) ?? .energyCell
    }

    public var shouldDespawn: Bool {
        timeAlive >= 8.0
    }

    public func advanceCycle() {
        if isWeaponModule {
            guard !weaponCycle.isEmpty else { return }
            weaponCycleIndex = (weaponCycleIndex + 1) % weaponCycle.count
            displayedWeapon = weaponCycle[weaponCycleIndex]
        } else {
            currentCycleIndex = (currentCycleIndex + 1) % UtilityItemType.allCases.count
        }
    }

    public override init() { super.init() }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
