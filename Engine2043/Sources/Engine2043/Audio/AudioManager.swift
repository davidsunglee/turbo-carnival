@MainActor
public protocol AudioProvider: AnyObject {
    func playEffect(_ name: String)
    func playMusic(_ name: String)
    func stopAll()
}

@MainActor
public final class AudioManager: AudioProvider {
    public init() {}

    public func playEffect(_ name: String) {}
    public func playMusic(_ name: String) {}
    public func stopAll() {}
}
