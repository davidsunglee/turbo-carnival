#if os(iOS)
import UIKit
import simd

@MainActor
public final class TouchInputProvider: InputProvider {
    // Joystick state
    private var joystickOrigin: SIMD2<Float>?
    private var joystickCurrent: SIMD2<Float>?
    private var joystickTouchID: ObjectIdentifier?

    // Button state
    private var primaryFireActive: Bool = false
    private var secondaryFireActive: Bool = false
    private var primaryTouchID: ObjectIdentifier?
    private var secondaryTouchID: ObjectIdentifier?

    // Configuration
    private let maxJoystickRadius: Float = 60
    private let deadZone: Float = 10

    // Screen dimensions (set by MetalView on layout)
    public var screenSize: CGSize = .zero

    // Button rects (set by MetalView on layout)
    public var primaryButtonRect: CGRect = .zero
    public var secondaryButtonRect: CGRect = .zero

    public init() {}

    public func poll() -> PlayerInput {
        var input = PlayerInput()

        if let origin = joystickOrigin, let current = joystickCurrent {
            var delta = current - origin
            let length = simd_length(delta)

            if length < deadZone {
                delta = .zero
            } else if length > maxJoystickRadius {
                delta = simd_normalize(delta) * maxJoystickRadius
            }

            input.movement = delta / maxJoystickRadius
            // Flip Y: screen Y goes down, game Y goes up
            input.movement.y = -input.movement.y
        }

        input.primaryFire = primaryFireActive
        input.secondaryFire = secondaryFireActive

        return input
    }

    // MARK: - Touch handling (called by MetalView)

    public func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let loc = touch.location(in: view)
            let point = SIMD2<Float>(Float(loc.x), Float(loc.y))
            let touchID = ObjectIdentifier(touch)

            if loc.x < screenSize.width / 2 && joystickTouchID == nil {
                // Left half: joystick
                joystickOrigin = point
                joystickCurrent = point
                joystickTouchID = touchID
            } else if loc.x >= screenSize.width / 2 {
                // Right half: buttons
                if secondaryButtonRect.contains(loc) && secondaryTouchID == nil {
                    secondaryFireActive = true
                    secondaryTouchID = touchID
                } else if primaryTouchID == nil {
                    primaryFireActive = true
                    primaryTouchID = touchID
                }
            }
        }
    }

    public func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let touchID = ObjectIdentifier(touch)
            if touchID == joystickTouchID {
                let loc = touch.location(in: view)
                joystickCurrent = SIMD2<Float>(Float(loc.x), Float(loc.y))
            }
        }
    }

    public func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        cancelTouches(touches)
    }

    public func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        cancelTouches(touches)
    }

    private func cancelTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let touchID = ObjectIdentifier(touch)
            if touchID == joystickTouchID {
                joystickOrigin = nil
                joystickCurrent = nil
                joystickTouchID = nil
            }
            if touchID == primaryTouchID {
                primaryFireActive = false
                primaryTouchID = nil
            }
            if touchID == secondaryTouchID {
                secondaryFireActive = false
                secondaryTouchID = nil
            }
        }
    }
}

#endif
