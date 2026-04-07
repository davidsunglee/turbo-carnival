public enum MusicTrack: Sendable {
    case gameplay
    case boss
    case title
    case galaxy2
    case galaxy2Boss

    var filename: String {
        switch self {
        case .gameplay, .title: "gameplay"
        case .boss: "boss"
        case .galaxy2: "g2 - gameplay"
        case .galaxy2Boss: "g2 - boss"
        }
    }
}
