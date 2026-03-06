public struct GameTime: Sendable {
    public var totalTime: Double = 0
    public var deltaTime: Double = 0
    public var fixedDeltaTime: Double = GameConfig.fixedTimeStep
    public private(set) var accumulator: Double = 0
    public private(set) var fixedUpdateCount: UInt64 = 0

    public init() {}

    public mutating func advance(by dt: Double) {
        let clampedDT = min(dt, GameConfig.maxFrameTime)
        deltaTime = clampedDT
        totalTime += clampedDT
        accumulator += clampedDT
    }

    public func shouldPerformFixedUpdate() -> Bool {
        accumulator >= fixedDeltaTime
    }

    public mutating func consumeFixedUpdate() {
        accumulator -= fixedDeltaTime
        fixedUpdateCount += 1
    }

    public var interpolationFactor: Double {
        accumulator / fixedDeltaTime
    }
}
