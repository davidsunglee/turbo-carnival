public enum SceneTransition: Sendable {
    case toGame
    case toTitle
    case toGalaxySelect
    case toGameOver(GameResult)
    case toVictory(GameResult)
    case toGalaxy2(PlayerCarryover?)
    case toGalaxy3(PlayerCarryover?)
}
