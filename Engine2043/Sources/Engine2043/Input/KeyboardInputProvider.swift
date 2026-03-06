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
    }

    public init() {}

    public func keyDown(_ keyCode: UInt16) {
        keysPressed.insert(keyCode)
    }

    public func keyUp(_ keyCode: UInt16) {
        keysPressed.remove(keyCode)
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
        input.secondaryFire = keysPressed.contains(KeyCode.z)

        return input
    }
}
#endif
