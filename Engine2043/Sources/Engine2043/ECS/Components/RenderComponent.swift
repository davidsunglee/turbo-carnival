import GameplayKit
import simd

public final class RenderComponent: GKComponent {
    public var size: SIMD2<Float> = SIMD2(32, 32)
    public var color: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    public var isVisible: Bool = true

    public override init() { super.init() }

    public convenience init(size: SIMD2<Float>, color: SIMD4<Float>) {
        self.init()
        self.size = size
        self.color = color
    }

    required init?(coder: NSCoder) { fatalError("NSCoding not supported") }
}
