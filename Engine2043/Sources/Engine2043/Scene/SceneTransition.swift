public enum SceneTransition: Sendable {
    case toGame
    case toTitle
    case toGameOver(GameResult)
    case toVictory(GameResult)
}
