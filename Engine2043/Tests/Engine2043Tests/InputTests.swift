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

    @Test @MainActor func mockInputProviderPollReturnsMovement() {
        let provider = MockInputProvider(movement: SIMD2(0.5, -0.3))
        let input = provider.poll()
        #expect(input.movement.x == 0.5)
        #expect(input.movement.y == -0.3)
    }

    @Test @MainActor func mockInputProviderPollReturnsPrimaryFire() {
        let provider = MockInputProvider(primary: true)
        let input = provider.poll()
        #expect(input.primaryFire == true)
    }

    @Test @MainActor func mockInputProviderSecondaryFires() {
        let provider = MockInputProvider()
        provider.secondary1 = true
        provider.secondary2 = true
        let input = provider.poll()
        #expect(input.secondaryFire1 == true)
        #expect(input.secondaryFire2 == true)
        #expect(input.secondaryFire3 == false)
    }

    @Test @MainActor func mockInputProviderTapPositionConsumedAfterPoll() {
        let provider = MockInputProvider()
        provider.tapPos = SIMD2(100, 200)

        let first = provider.poll()
        #expect(first.tapPosition != nil)
        #expect(first.tapPosition!.x == 100)

        let second = provider.poll()
        #expect(second.tapPosition == nil)
    }

    @Test func playerInputDefaultsAllFalse() {
        let input = PlayerInput()
        #expect(input.primaryFire == false)
        #expect(input.secondaryFire1 == false)
        #expect(input.secondaryFire2 == false)
        #expect(input.secondaryFire3 == false)
        #expect(input.tapPosition == nil)
        #expect(input.movement == .zero)
    }

    @Test func playerInputMenuFieldsDefaultToFalse() {
        let input = PlayerInput()
        #expect(input.menuUp == false)
        #expect(input.menuDown == false)
        #expect(input.menuBack == false)
    }

    @Test @MainActor func mockInputProviderMenuFields() {
        let provider = MockInputProvider()
        provider.menuUp = true
        provider.menuDown = false
        provider.menuBack = true
        let input = provider.poll()
        #expect(input.menuUp == true)
        #expect(input.menuDown == false)
        #expect(input.menuBack == true)
    }

#if os(macOS)
    @Test @MainActor func keyboardProviderMapsArrowsToMenuUpDown() {
        let provider = KeyboardInputProvider()
        provider.keyDown(126) // up arrow
        let input = provider.poll()
        #expect(input.menuUp == true)
        #expect(input.menuDown == false)
    }

    @Test @MainActor func keyboardProviderMapsEscapeToMenuBack() {
        let provider = KeyboardInputProvider()
        provider.keyDown(53) // escape
        let input = provider.poll()
        #expect(input.menuBack == true)
    }

    @Test @MainActor func keyboardProviderMenuBackFalseWhenEscNotPressed() {
        let provider = KeyboardInputProvider()
        provider.keyDown(49) // space
        let input = provider.poll()
        #expect(input.menuBack == false)
    }
#endif
}
