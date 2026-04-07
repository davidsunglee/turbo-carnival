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

    public override init() { super.init() }
    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
