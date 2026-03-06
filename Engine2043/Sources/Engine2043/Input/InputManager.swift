import simd

public struct PlayerInput: Sendable {
    public var movement: SIMD2<Float> = .zero
    public var primaryFire: Bool = false
    public var secondaryFire: Bool = false

    public init() {}
}

@MainActor
public protocol InputProvider: AnyObject {
    func poll() -> PlayerInput
}
