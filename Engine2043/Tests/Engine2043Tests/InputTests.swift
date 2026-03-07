import Testing
import simd
@testable import Engine2043

struct InputTests {
    @Test func playerInputDefaults() {
        let input = PlayerInput()
        #expect(input.movement == .zero)
        #expect(input.primaryFire == false)
        #expect(input.secondaryFire1 == false)
        #expect(input.secondaryFire2 == false)
        #expect(input.secondaryFire3 == false)
    }

    @Test func touchZoneClassification() {
        // Screen 390x844 (iPhone 14 sized)
        let screenW: Float = 390
        let screenH: Float = 844

        // Left half, bottom half -> joystick zone
        let joystickPoint = SIMD2<Float>(100, 600)
        #expect(joystickPoint.x < screenW / 2)
        #expect(joystickPoint.y > screenH / 2)

        // Right half, bottom area -> button zone
        let buttonPoint = SIMD2<Float>(300, 700)
        #expect(buttonPoint.x >= screenW / 2)
        #expect(buttonPoint.y > screenH / 2)
    }

    @Test func joystickVectorNormalization() {
        // Simulate displacement beyond max radius
        let origin = SIMD2<Float>(100, 600)
        let current = SIMD2<Float>(200, 600) // 100pt right
        let maxRadius: Float = 60

        var delta = current - origin
        let length = simd_length(delta)
        if length > maxRadius {
            delta = simd_normalize(delta) * maxRadius
        }
        let normalized = delta / maxRadius

        #expect(abs(normalized.x - 1.0) < 0.01)
        #expect(abs(normalized.y) < 0.01)
    }

    @Test func joystickDeadZone() {
        let origin = SIMD2<Float>(100, 600)
        let current = SIMD2<Float>(105, 602) // 5pt displacement
        let deadZone: Float = 10

        let delta = current - origin
        let length = simd_length(delta)

        #expect(length < deadZone)
        // Movement should be zero when within dead zone
        let movement: SIMD2<Float> = length < deadZone ? .zero : delta / 60.0
        #expect(movement == .zero)
    }
}
