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
    private var secondary1Active: Bool = false
    private var secondary2Active: Bool = false
    private var secondary3Active: Bool = false
    private var primaryTouchID: ObjectIdentifier?
    private var secondary1TouchID: ObjectIdentifier?
    private var secondary2TouchID: ObjectIdentifier?
    private var secondary3TouchID: ObjectIdentifier?

    // Swipe detection for menu navigation
    private var swipeOriginY: Float?
    private var swipeTouchID: ObjectIdentifier?
    private var pendingMenuUp: Bool = false
    private var pendingMenuDown: Bool = false
    private let swipeThreshold: Float = 30

    // Configuration
    private let maxJoystickRadius: Float = 60
    private let deadZone: Float = 10

    // Screen dimensions (set by MetalView on layout)
    public var screenSize: CGSize = .zero
    public weak var viewportManager: ViewportManager?

    // Button rects (set by MetalView on layout)
    public var primaryButtonRect: CGRect = .zero
    public var secondary1ButtonRect: CGRect = .zero
    public var secondary2ButtonRect: CGRect = .zero
    public var secondary3ButtonRect: CGRect = .zero

    // Public accessors for control overlay rendering
    public var joystickOriginPoint: CGPoint? {
        guard let o = joystickOrigin else { return nil }
        return CGPoint(x: CGFloat(o.x), y: CGFloat(o.y))
    }

    public var joystickCurrentPoint: CGPoint? {
        guard let c = joystickCurrent else { return nil }
        return CGPoint(x: CGFloat(c.x), y: CGFloat(c.y))
    }

    public var isPrimaryFireActive: Bool { primaryFireActive }
    public var isSecondary1Active: Bool { secondary1Active }
    public var isSecondary2Active: Bool { secondary2Active }
    public var isSecondary3Active: Bool { secondary3Active }

    private var pendingTapPosition: SIMD2<Float>?

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
            input.movement.y = -input.movement.y
        }

        input.primaryFire = primaryFireActive
        input.secondaryFire1 = secondary1Active
        input.secondaryFire2 = secondary2Active
        input.secondaryFire3 = secondary3Active
        input.tapPosition = pendingTapPosition
        pendingTapPosition = nil

        input.menuUp = pendingMenuUp
        input.menuDown = pendingMenuDown
        pendingMenuUp = false
        pendingMenuDown = false

        return input
    }

    // MARK: - Touch handling (called by MetalView)

    public func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let loc = touch.location(in: view)
            let point = SIMD2<Float>(Float(loc.x), Float(loc.y))
            let touchID = ObjectIdentifier(touch)

            // Convert screen-space tap to game design coordinates
            let designWidth = viewportManager?.currentDesignWidth ?? GameConfig.designWidth
            let gameX = (Float(loc.x) / Float(screenSize.width) - 0.5) * designWidth
            let gameY = (0.5 - Float(loc.y) / Float(screenSize.height)) * GameConfig.designHeight
            pendingTapPosition = SIMD2(gameX, gameY)

            // Track swipe origin for menu navigation
            if swipeTouchID == nil {
                swipeOriginY = Float(loc.y)
                swipeTouchID = touchID
            }

            let zoneWidth = min(180.0, screenSize.width / 2)
            if loc.x < zoneWidth && joystickTouchID == nil {
                joystickOrigin = point
                joystickCurrent = point
                joystickTouchID = touchID
            } else if loc.x > screenSize.width - zoneWidth {
                if secondary3ButtonRect.contains(loc) && secondary3TouchID == nil {
                    secondary3Active = true
                    secondary3TouchID = touchID
                } else if secondary2ButtonRect.contains(loc) && secondary2TouchID == nil {
                    secondary2Active = true
                    secondary2TouchID = touchID
                } else if secondary1ButtonRect.contains(loc) && secondary1TouchID == nil {
                    secondary1Active = true
                    secondary1TouchID = touchID
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

            // Swipe detection
            if touchID == swipeTouchID, let originY = swipeOriginY {
                let currentY = Float(touch.location(in: view).y)
                let delta = currentY - originY
                if delta > swipeThreshold {
                    pendingMenuDown = true
                    swipeOriginY = currentY
                } else if delta < -swipeThreshold {
                    pendingMenuUp = true
                    swipeOriginY = currentY
                }
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
            if touchID == swipeTouchID {
                swipeOriginY = nil
                swipeTouchID = nil
            }
            if touchID == primaryTouchID {
                primaryFireActive = false
                primaryTouchID = nil
            }
            if touchID == secondary1TouchID {
                secondary1Active = false
                secondary1TouchID = nil
            }
            if touchID == secondary2TouchID {
                secondary2Active = false
                secondary2TouchID = nil
            }
            if touchID == secondary3TouchID {
                secondary3Active = false
                secondary3TouchID = nil
            }
        }
    }
}

#endif
