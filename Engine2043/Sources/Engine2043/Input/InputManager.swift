import simd

public struct PlayerInput: Sendable {
    public var movement: SIMD2<Float> = .zero
    public var primaryFire: Bool = false
    public var secondaryFire1: Bool = false  // Z — Grav-Bomb
    public var secondaryFire2: Bool = false  // X — EMP Sweep
    public var secondaryFire3: Bool = false  // C — Overcharge Protocol

    public init() {}
}

@MainActor
public protocol InputProvider: AnyObject {
    func poll() -> PlayerInput
}
