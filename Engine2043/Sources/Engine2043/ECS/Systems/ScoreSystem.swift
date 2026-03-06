@MainActor
public final class ScoreSystem {
    public private(set) var currentScore: Int = 0

    public init() {}

    public func addScore(_ points: Int) {
        currentScore += points
    }

    public func reset() {
        currentScore = 0
    }
}
