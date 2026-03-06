import GameplayKit

public enum ItemType: Int, CaseIterable, Sendable {
    case energyCell = 0
    case weaponModule = 1
}

public final class ItemComponent: GKComponent {
    public var currentCycleIndex: Int = 0
    public var timeAlive: Double = 0
    public var bounceDirection: Float = 1

    public var itemType: ItemType {
        ItemType(rawValue: currentCycleIndex % ItemType.allCases.count) ?? .energyCell
    }

    public var shouldDespawn: Bool {
        timeAlive >= 8.0
    }

    public func advanceCycle() {
        currentCycleIndex = (currentCycleIndex + 1) % ItemType.allCases.count
    }

    public override init() { super.init() }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
