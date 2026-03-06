import simd

public enum EnemyTier: Sendable {
    case tier1
    case tier2
    case tier3
    case boss
}

public struct WaveDefinition: Sendable {
    public let triggerDistance: Float
    public let enemyTier: EnemyTier
    public let pattern: FormationPattern
    public let count: Int
    public let spawnX: Float
    public let spawnY: Float

    public init(trigger: Float, tier: EnemyTier, pattern: FormationPattern = .vShape, count: Int = 5, spawnX: Float = 0, spawnY: Float = 370) {
        self.triggerDistance = trigger
        self.enemyTier = tier
        self.pattern = pattern
        self.count = count
        self.spawnX = spawnX
        self.spawnY = spawnY
    }
}

@MainActor
public final class SpawnDirector {
    private let waves: [WaveDefinition]
    private var nextWaveIndex: Int = 0
    public private(set) var pendingWaves: [WaveDefinition] = []
    public private(set) var shouldLockScroll: Bool = false

    public init() {
        waves = Self.galaxy1Waves()
    }

    public func update(scrollDistance: Float) {
        pendingWaves.removeAll(keepingCapacity: true)

        while nextWaveIndex < waves.count {
            let wave = waves[nextWaveIndex]
            if scrollDistance >= wave.triggerDistance {
                pendingWaves.append(wave)
                if wave.enemyTier == .boss {
                    shouldLockScroll = true
                }
                nextWaveIndex += 1
            } else {
                break
            }
        }
    }

    public func unlockScroll() {
        shouldLockScroll = false
    }

    private static func galaxy1Waves() -> [WaveDefinition] {
        var waves: [WaveDefinition] = []

        // 0-500: Tutorial ramp
        waves.append(WaveDefinition(trigger: 50, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 200, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 400, tier: .tier1, pattern: .vShape, count: 5))

        // 500-1200: Tier 1 variety + first Tier 2
        waves.append(WaveDefinition(trigger: 550, tier: .tier1, pattern: .sineWave, count: 5))
        waves.append(WaveDefinition(trigger: 700, tier: .tier1, pattern: .staggeredLine, count: 5))
        waves.append(WaveDefinition(trigger: 800, tier: .tier2, count: 2, spawnX: -60))
        waves.append(WaveDefinition(trigger: 900, tier: .tier1, pattern: .sineWave, count: 5))
        waves.append(WaveDefinition(trigger: 1100, tier: .tier1, pattern: .vShape, count: 5))

        // 1200-2000: Escalation
        waves.append(WaveDefinition(trigger: 1250, tier: .tier2, count: 3, spawnX: 50))
        waves.append(WaveDefinition(trigger: 1400, tier: .tier1, pattern: .sineWave, count: 5))
        waves.append(WaveDefinition(trigger: 1500, tier: .tier1, pattern: .staggeredLine, count: 5))
        waves.append(WaveDefinition(trigger: 1600, tier: .tier2, count: 2, spawnX: -40))
        waves.append(WaveDefinition(trigger: 1800, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 1900, tier: .tier1, pattern: .sineWave, count: 5))

        // 2000-2800: Capital Ship
        waves.append(WaveDefinition(trigger: 2000, tier: .tier3, count: 4))
        waves.append(WaveDefinition(trigger: 2200, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 2500, tier: .tier1, pattern: .sineWave, count: 5))

        // 2800-3400: Final gauntlet
        waves.append(WaveDefinition(trigger: 2800, tier: .tier2, count: 3, spawnX: 0))
        waves.append(WaveDefinition(trigger: 2900, tier: .tier1, pattern: .staggeredLine, count: 5))
        waves.append(WaveDefinition(trigger: 3100, tier: .tier2, count: 2, spawnX: -80))
        waves.append(WaveDefinition(trigger: 3200, tier: .tier1, pattern: .vShape, count: 5))
        waves.append(WaveDefinition(trigger: 3300, tier: .tier1, pattern: .sineWave, count: 5))

        // 3500: Boss
        waves.append(WaveDefinition(trigger: 3500, tier: .boss, count: 1))

        return waves
    }
}
