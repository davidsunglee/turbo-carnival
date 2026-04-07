import GameplayKit

public enum AsteroidSize: Sendable {
    case small  // destructible
    case large  // indestructible
}

public final class AsteroidComponent: GKComponent {
    public var asteroidSize: AsteroidSize = .small
    public var isDestructible: Bool { asteroidSize == .small }

    public override init() { super.init() }

    public convenience init(size: AsteroidSize) {
        self.init()
        self.asteroidSize = size
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
