public struct GameResult: Sendable {
    public let finalScore: Int
    public let enemiesDestroyed: Int
    public let elapsedTime: Double
    public let didWin: Bool

    public init(finalScore: Int, enemiesDestroyed: Int, elapsedTime: Double, didWin: Bool) {
        self.finalScore = finalScore
        self.enemiesDestroyed = enemiesDestroyed
        self.elapsedTime = elapsedTime
        self.didWin = didWin
    }
}
