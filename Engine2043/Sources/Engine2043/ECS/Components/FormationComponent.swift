import GameplayKit

public enum FormationPattern: Sendable {
    case vShape
    case sineWave
    case staggeredLine
}

public final class FormationComponent: GKComponent {
    public var pattern: FormationPattern = .vShape
    public var index: Int = 0
    public var formationID: Int = 0
    public var phaseOffset: Float = 0
    public var elapsedTime: Double = 0

    public override init() { super.init() }

    public convenience init(pattern: FormationPattern, index: Int, formationID: Int) {
        self.init()
        self.pattern = pattern
        self.index = index
        self.formationID = formationID
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
