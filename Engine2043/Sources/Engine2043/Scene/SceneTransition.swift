public enum SceneTransition: Sendable {
    case toGame
    case toTitle
    case toGameOver(GameResult)
    case toVictory(GameResult)
    case toGalaxy2(PlayerCarryover)
}
