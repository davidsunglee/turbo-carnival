import GameplayKit

@MainActor
public final class SceneManager {
    public let engine: GameEngine

    // Scene factory closures — called to create fresh scenes
    public var makeTitleScene: (() -> any GameScene)?
    public var makeGameScene: (() -> any GameScene)?
    public var makeGameOverScene: ((GameResult) -> any GameScene)?
    public var makeVictoryScene: ((GameResult) -> any GameScene)?
    public var makeGalaxy2Scene: ((PlayerCarryover) -> any GameScene)?
    public var makeGalaxy3Scene: ((PlayerCarryover) -> any GameScene)?

    // Transition state
    public private(set) var isTransitioning: Bool = false
    public private(set) var transitionProgress: Float = 0
    private var pendingTransition: SceneTransition?
    private let transitionDuration: Double = 0.4
    private var transitionTimer: Double = 0
    private var transitionPhase: TransitionPhase = .none

    private enum TransitionPhase {
        case none
        case fadeOut   // noise ramps 0 → 1
        case fadeIn    // noise ramps 1 → 0
    }

    public init(engine: GameEngine) {
        self.engine = engine
    }

    public func checkForTransition() {
        guard transitionPhase == .none,
              let transition = engine.currentScene?.requestedTransition else { return }
        pendingTransition = transition
        transitionPhase = .fadeOut
        transitionTimer = 0
        isTransitioning = true
    }

    public func updateTransition(deltaTime: Double) {
        guard transitionPhase != .none else { return }

        transitionTimer += deltaTime
        let halfDuration = transitionDuration / 2

        switch transitionPhase {
        case .fadeOut:
            transitionProgress = Float(min(transitionTimer / halfDuration, 1.0))
            if transitionTimer >= halfDuration {
                // Switch scene at peak noise
                performSceneSwitch()
                transitionPhase = .fadeIn
                transitionTimer = 0
            }
        case .fadeIn:
            transitionProgress = Float(max(1.0 - transitionTimer / halfDuration, 0.0))
            if transitionTimer >= halfDuration {
                transitionPhase = .none
                transitionProgress = 0
                isTransitioning = false
                pendingTransition = nil
            }
        case .none:
            break
        }
    }

    private func performSceneSwitch() {
        guard let transition = pendingTransition else { return }
        let scene: (any GameScene)?
        switch transition {
        case .toTitle:
            scene = makeTitleScene?()
        case .toGame:
            scene = makeGameScene?()
        case .toGameOver(let result):
            scene = makeGameOverScene?(result)
        case .toVictory(let result):
            scene = makeVictoryScene?(result)
        case .toGalaxy2(let carryover):
            scene = makeGalaxy2Scene?(carryover)
        case .toGalaxy3(let carryover):
            scene = makeGalaxy3Scene?(carryover)
        }
        if let scene {
            engine.currentScene = scene
        }
    }
}
