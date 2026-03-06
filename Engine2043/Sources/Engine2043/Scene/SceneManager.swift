import GameplayKit

@MainActor
public final class SceneManager {
    private let engine: GameEngine
    private var scenes: [String: any GameScene] = [:]

    public init(engine: GameEngine) {
        self.engine = engine
    }

    public func register(_ scene: any GameScene, name: String) {
        scenes[name] = scene
    }

    public func transition(to name: String) {
        guard let scene = scenes[name] else { return }
        engine.currentScene = scene
    }
}
