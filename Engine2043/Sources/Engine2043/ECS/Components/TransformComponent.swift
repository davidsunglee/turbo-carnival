import GameplayKit
import simd

public final class TransformComponent: GKComponent {
    public var position: SIMD2<Float> = .zero
    public var rotation: Float = 0
    public var scale: SIMD2<Float> = .one

    public override init() { super.init() }

    public convenience init(position: SIMD2<Float>, rotation: Float = 0) {
        self.init()
        self.position = position
        self.rotation = rotation
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
