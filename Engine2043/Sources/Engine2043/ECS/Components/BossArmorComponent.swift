import GameplayKit
import simd

public struct ArmorSlot {
    public var angle: Float          // position around boss (radians)
    public var entity: GKEntity?     // the asteroid entity acting as armor (nil = gap)
    public var isActive: Bool { entity != nil }
}

public final class BossArmorComponent: GKComponent {
    public var slots: [ArmorSlot] = []
    public var tractorBeamTargets: [GKEntity] = []  // asteroids being pulled in
    public var tractorBeamTimer: Double = 0
    public var tractorBeamInterval: Double = 8.0     // seconds between armor rebuilds
    public var armorRadius: Float = 70               // distance from boss center
    public var rotationAngle: Float = 0

    /// Returns the index of the active armor slot covering the given approach angle,
    /// accounting for the current `rotationAngle`. Returns `nil` if no slot covers it.
    public func coveringSlotIndex(for angle: Float, halfArc: Float = .pi / 6) -> Int? {
        for (i, slot) in slots.enumerated() where slot.isActive {
            var diff = angle - (slot.angle + rotationAngle)
            while diff > .pi  { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            if abs(diff) <= halfArc {
                return i
            }
        }
        return nil
    }

    public override init() { super.init() }
    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
