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
        return [
            // -- Tutorial ramp (was 50-400, now 50-260)
            WaveDefinition(trigger: 50,   tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 155,  tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 260,  tier: .tier1, pattern: .vShape,        count: 5),

            // -- Escalation (was 550-1100, now 350-700)
            WaveDefinition(trigger: 350,  tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 440,  tier: .tier1, pattern: .staggeredLine, count: 5),
            WaveDefinition(trigger: 500,  tier: .tier2, pattern: .vShape,        count: 2, spawnX: -60),
            WaveDefinition(trigger: 560,  tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 700,  tier: .tier1, pattern: .vShape,        count: 5),

            // -- Capital ship approach (was 1250-1900, now 800-1200)
            WaveDefinition(trigger: 800,  tier: .tier2, pattern: .vShape,        count: 3, spawnX: 50),
            WaveDefinition(trigger: 880,  tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 960,  tier: .tier1, pattern: .staggeredLine, count: 5),
            WaveDefinition(trigger: 1020, tier: .tier2, pattern: .vShape,        count: 2, spawnX: -40),
            WaveDefinition(trigger: 1120, tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 1200, tier: .tier1, pattern: .sineWave,      count: 5),

            // -- Capital ship battle (was 2000-2500, now 1250-1550)
            WaveDefinition(trigger: 1250, tier: .tier3, pattern: .vShape,        count: 4),
            WaveDefinition(trigger: 1370, tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 1550, tier: .tier1, pattern: .sineWave,      count: 5),

            // -- Final gauntlet (was 2800-3300, now 1700-2000)
            WaveDefinition(trigger: 1700, tier: .tier2, pattern: .vShape,        count: 3),
            WaveDefinition(trigger: 1760, tier: .tier1, pattern: .staggeredLine, count: 5),
            WaveDefinition(trigger: 1880, tier: .tier2, pattern: .vShape,        count: 2, spawnX: -80),
            WaveDefinition(trigger: 1940, tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 2000, tier: .tier1, pattern: .sineWave,      count: 5),

            // -- Boss (was 3500, now 2150)
            WaveDefinition(trigger: 2150, tier: .boss,  pattern: .vShape,        count: 1),
        ]
    }
}
