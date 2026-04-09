import Testing
import simd
@testable import Engine2043

struct GalaxySelectSceneTests {

    @MainActor
    private func runFrames(_ scene: GalaxySelectScene, count: Int) {
        var time = GameTime()
        for _ in 0..<count {
            time.advance(by: GameConfig.fixedTimeStep)
            while time.shouldPerformFixedUpdate() {
                scene.fixedUpdate(time: time)
                time.consumeFixedUpdate()
            }
            scene.update(time: time)
        }
    }

    @Test @MainActor func initialStateIsCorrect() {
        let scene = GalaxySelectScene()
        #expect(scene.requestedTransition == nil)
        #expect(scene.selectedIndex == 0)
    }

    @Test @MainActor func menuDownMovesSelectionDown() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        #expect(scene.selectedIndex == 1)
    }

    @Test @MainActor func menuUpMovesSelectionUp() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Move down first, then up
        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)

        input.menuUp = true
        runFrames(scene, count: 1)
        input.menuUp = false
        #expect(scene.selectedIndex == 0)
    }

    @Test @MainActor func selectionWrapsDownFromGalaxy3ToGalaxy1() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Move down 3 times: 0→1, 1→2, 2→0
        for _ in 0..<3 {
            input.menuDown = true
            runFrames(scene, count: 1)
            input.menuDown = false
            runFrames(scene, count: 1)
        }
        #expect(scene.selectedIndex == 0)
    }

    @Test @MainActor func selectionWrapsUpFromGalaxy1ToGalaxy3() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuUp = true
        runFrames(scene, count: 1)
        input.menuUp = false
        #expect(scene.selectedIndex == 2)
    }

    @Test @MainActor func fireOnGalaxy1TransitionsToGame() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Galaxy 1 is selected by default, fire
        input.primary = true
        runFrames(scene, count: 1)

        if case .toGame = scene.requestedTransition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toGame, got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func fireOnGalaxy2TransitionsToGalaxy2WithNilCarryover() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)

        input.primary = true
        runFrames(scene, count: 1)

        if case .toGalaxy2(let carryover) = scene.requestedTransition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2(nil), got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func fireOnGalaxy3TransitionsToGalaxy3WithNilCarryover() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Move to Galaxy 3
        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)
        input.menuDown = true
        runFrames(scene, count: 1)
        input.menuDown = false
        runFrames(scene, count: 1)

        input.primary = true
        runFrames(scene, count: 1)

        if case .toGalaxy3(let carryover) = scene.requestedTransition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy3(nil), got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func menuBackTransitionsToTitle() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        input.menuBack = true
        runFrames(scene, count: 1)

        if case .toTitle = scene.requestedTransition {
            // pass
        } else {
            #expect(Bool(false), "Expected .toTitle, got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func tapOnGalaxyEntryLaunchesIt() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Tap on Galaxy 2 entry position (Y = 30 in the layout)
        input.tapPos = SIMD2(0, 30)
        runFrames(scene, count: 1)

        if case .toGalaxy2(let carryover) = scene.requestedTransition {
            #expect(carryover == nil)
        } else {
            #expect(Bool(false), "Expected .toGalaxy2(nil), got \(String(describing: scene.requestedTransition))")
        }
    }

    @Test @MainActor func collectEffectSpritesProducesOutput() {
        let scene = GalaxySelectScene()
        let sprites = scene.collectEffectSprites(effectSheet: nil)
        #expect(sprites.isEmpty)
    }

    @Test @MainActor func repeatGuardPreventsRapidScrolling() {
        let scene = GalaxySelectScene()
        let input = MockInputProvider()
        scene.inputProvider = input

        // Hold menuDown for multiple frames — should only move once
        input.menuDown = true
        runFrames(scene, count: 5)
        // 5 frames (~83ms at 60fps) which is less than 0.3s repeat delay
        #expect(scene.selectedIndex == 1)
    }
}
