// Engine2043/Tests/Engine2043Tests/ViewportManagerTests.swift
import Testing
import simd
@testable import Engine2043

struct ViewportManagerTests {
    @Test @MainActor func defaultAspectRatioIsPortrait() {
        let vm = ViewportManager()
        #expect(vm.currentDesignWidth == 360)
        #expect(vm.designHeight == 640)
    }

    @Test @MainActor func settingTargetAspectRatioAndUpdating() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 16.0 / 9.0  // landscape
        // After enough updates, should converge
        for _ in 0..<60 {
            vm.update(dt: 1.0 / 60.0)
        }
        let expected: Float = 640 * (16.0 / 9.0)
        #expect(abs(vm.currentDesignWidth - expected) < 1.0)
    }

    @Test @MainActor func aspectRatioClampsToMinimum() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 0.1  // way below 9:16
        vm.update(dt: 1.0)
        #expect(vm.currentAspectRatio >= 9.0 / 16.0 - 0.001)
    }

    @Test @MainActor func aspectRatioClampsToMaximum() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 5.0  // way above 21:9
        vm.update(dt: 1.0)
        #expect(vm.currentAspectRatio <= 21.0 / 9.0 + 0.001)
    }

    @Test @MainActor func largeJumpSnapsInstantly() {
        let vm = ViewportManager()
        vm.targetAspectRatio = 16.0 / 9.0  // delta > 0.5 from default 9/16
        vm.update(dt: 1.0 / 60.0)
        // Should snap, not animate
        let expected: Float = 16.0 / 9.0
        #expect(abs(vm.currentAspectRatio - expected) < 0.01)
    }

    @Test @MainActor func halfWidthAndHalfHeight() {
        let vm = ViewportManager()
        #expect(vm.halfWidth == 180)
        #expect(vm.halfHeight == 320)
    }

    @Test @MainActor func worldBoundsMatchesDimensions() {
        let vm = ViewportManager()
        let bounds = vm.worldBounds
        #expect(bounds.min.x == -180)
        #expect(bounds.max.x == 180)
        #expect(bounds.min.y == -320)
        #expect(bounds.max.y == 320)
    }
}
