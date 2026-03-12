// Engine2043/Sources/Engine2043/Core/ViewportManager.swift
import simd

@MainActor
public final class ViewportManager {
    public let designHeight: Float = GameConfig.designHeight

    private static let minAspectRatio: Float = 9.0 / 16.0
    private static let maxAspectRatio: Float = 21.0 / 9.0
    private static let maxWidth: Float = GameConfig.designHeight * maxAspectRatio
    private static let chaseSpeed: Float = 12.0
    private static let snapThreshold: Float = 0.5

    public private(set) var currentAspectRatio: Float = 9.0 / 16.0

    public var targetAspectRatio: Float = 9.0 / 16.0 {
        didSet {
            targetAspectRatio = Self.clampAspect(targetAspectRatio)
        }
    }

    public var currentDesignWidth: Float {
        designHeight * currentAspectRatio
    }

    public var halfWidth: Float { currentDesignWidth / 2 }
    public var halfHeight: Float { designHeight / 2 }

    public var worldBounds: AABB {
        AABB(min: SIMD2(-halfWidth, -halfHeight),
             max: SIMD2(halfWidth, halfHeight))
    }

    /// Maximum possible design width (at 21:9). Used by BackgroundSystem
    /// to generate stars across the widest possible viewport.
    public static var maxDesignWidth: Float { maxWidth }

    public init() {}

    public func update(dt: Float) {
        guard currentAspectRatio != targetAspectRatio else { return }

        let delta = abs(targetAspectRatio - currentAspectRatio)
        if delta > Self.snapThreshold {
            currentAspectRatio = targetAspectRatio
            return
        }

        let t = 1 - exp(-dt * Self.chaseSpeed)
        currentAspectRatio += (targetAspectRatio - currentAspectRatio) * t

        // Snap when close enough
        if abs(currentAspectRatio - targetAspectRatio) / targetAspectRatio < 0.001 {
            currentAspectRatio = targetAspectRatio
        }
    }

    private static func clampAspect(_ ratio: Float) -> Float {
        max(minAspectRatio, min(maxAspectRatio, ratio))
    }
}
