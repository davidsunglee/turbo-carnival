#if os(macOS)
import simd

@MainActor
public final class KeyboardInputProvider: InputProvider {
    private var keysPressed: Set<UInt16> = []

    // macOS virtual key codes
    private enum KeyCode {
        static let leftArrow:  UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow:  UInt16 = 125
        static let upArrow:    UInt16 = 126
        static let space:      UInt16 = 49
        static let z:          UInt16 = 6
        static let x:          UInt16 = 7
        static let c:          UInt16 = 8
        static let escape:     UInt16 = 53
    }

    public weak var viewportManager: ViewportManager?

    private var pendingClickPosition: SIMD2<Float>?

    public init() {}

    public func keyDown(_ keyCode: UInt16) {
        keysPressed.insert(keyCode)
    }

    public func keyUp(_ keyCode: UInt16) {
        keysPressed.remove(keyCode)
    }

    public func mouseDown(at point: SIMD2<Float>, viewSize: SIMD2<Float>) {
        let designWidth = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
        let gameX = (point.x / viewSize.x - 0.5) * designWidth
        let gameY = (0.5 - point.y / viewSize.y) * GameConfig.designHeight
        pendingClickPosition = SIMD2(gameX, gameY)
    }

    public func poll() -> PlayerInput {
        var input = PlayerInput()

        if keysPressed.contains(KeyCode.leftArrow)  { input.movement.x -= 1 }
        if keysPressed.contains(KeyCode.rightArrow)  { input.movement.x += 1 }
        if keysPressed.contains(KeyCode.upArrow)     { input.movement.y += 1 }
        if keysPressed.contains(KeyCode.downArrow)    { input.movement.y -= 1 }

        let length = simd_length(input.movement)
        if length > 1 {
            input.movement /= length
        }

        input.primaryFire = keysPressed.contains(KeyCode.space)
        input.secondaryFire1 = keysPressed.contains(KeyCode.z)
        input.secondaryFire2 = keysPressed.contains(KeyCode.x)
        input.secondaryFire3 = keysPressed.contains(KeyCode.c)
        input.tapPosition = pendingClickPosition
        pendingClickPosition = nil

        input.menuUp = keysPressed.contains(KeyCode.upArrow)
        input.menuDown = keysPressed.contains(KeyCode.downArrow)
        input.menuBack = keysPressed.contains(KeyCode.escape)

        return input
    }
}
#endif
