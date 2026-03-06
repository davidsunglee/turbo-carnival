import GameplayKit

public final class ScoreComponent: GKComponent {
    public var points: Int = 0

    public override init() { super.init() }

    public convenience init(points: Int) {
        self.init()
        self.points = points
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
