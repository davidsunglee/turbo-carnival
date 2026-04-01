public enum MusicTrack: Sendable {
    case gameplay
    case boss
    case title

    var filename: String {
        switch self {
        case .gameplay, .title: "gameplay"
        case .boss: "boss"
        }
    }
}
