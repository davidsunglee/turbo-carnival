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

public struct ScriptedDrop: Sendable {
    public let triggerDistance: Float
    public let type: ScriptedDropType

    public enum ScriptedDropType: Sendable {
        case weaponModule
    }
}

public struct AsteroidFieldDefinition: Sendable {
    public let triggerDistance: Float
    public let count: Int
    public let largeFraction: Float
}

public enum GalaxyConfig: Sendable {
    case galaxy1
    case galaxy2
}

@MainActor
public final class SpawnDirector {
    private let waves: [WaveDefinition]
    private var nextWaveIndex: Int = 0
    public private(set) var pendingWaves: [WaveDefinition] = []
    public private(set) var shouldLockScroll: Bool = false

    private var scriptedDrops: [ScriptedDrop]
    private var nextDropIndex: Int = 0
    public private(set) var pendingDrops: [ScriptedDrop] = []

    private let asteroidFields: [AsteroidFieldDefinition]
    private var nextAsteroidFieldIndex: Int = 0
    public private(set) var pendingAsteroidFields: [AsteroidFieldDefinition] = []

    public init(galaxy: GalaxyConfig) {
        switch galaxy {
        case .galaxy1:
            waves = Self.galaxy1Waves()
            scriptedDrops = Self.galaxy1ScriptedDrops()
            asteroidFields = []
        case .galaxy2:
            waves = Self.galaxy2Waves()
            scriptedDrops = Self.galaxy2ScriptedDrops()
            asteroidFields = Self.galaxy2AsteroidFields()
        }
    }

    public convenience init() {
        self.init(galaxy: .galaxy1)
    }

    public func update(scrollDistance: Float) {
        pendingWaves.removeAll(keepingCapacity: true)
        pendingDrops.removeAll(keepingCapacity: true)
        pendingAsteroidFields.removeAll(keepingCapacity: true)

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

        while nextDropIndex < scriptedDrops.count,
              scrollDistance >= scriptedDrops[nextDropIndex].triggerDistance {
            pendingDrops.append(scriptedDrops[nextDropIndex])
            nextDropIndex += 1
        }

        while nextAsteroidFieldIndex < asteroidFields.count,
              scrollDistance >= asteroidFields[nextAsteroidFieldIndex].triggerDistance {
            pendingAsteroidFields.append(asteroidFields[nextAsteroidFieldIndex])
            nextAsteroidFieldIndex += 1
        }
    }

    public func unlockScroll() {
        shouldLockScroll = false
    }

    // MARK: - Galaxy 1

    private static func galaxy1ScriptedDrops() -> [ScriptedDrop] {
        return [
            ScriptedDrop(triggerDistance: 715, type: .weaponModule),
            ScriptedDrop(triggerDistance: 1430, type: .weaponModule),
        ]
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

    // MARK: - Galaxy 2

    private static func galaxy2Waves() -> [WaveDefinition] {
        return [
            // -- Tier 1 opener: sine waves and V-shapes (50–500)
            WaveDefinition(trigger: 50,   tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 150,  tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 260,  tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 370,  tier: .tier1, pattern: .staggeredLine, count: 5),
            WaveDefinition(trigger: 480,  tier: .tier1, pattern: .vShape,        count: 5),

            // -- Tier 1 + Tier 2 mix (500–1200)
            WaveDefinition(trigger: 530,  tier: .tier2, pattern: .vShape,        count: 2, spawnX: -50),
            WaveDefinition(trigger: 600,  tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 680,  tier: .tier1, pattern: .staggeredLine, count: 5),
            WaveDefinition(trigger: 750,  tier: .tier2, pattern: .vShape,        count: 3, spawnX: 40),
            WaveDefinition(trigger: 840,  tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 920,  tier: .tier2, pattern: .sineWave,      count: 3),
            WaveDefinition(trigger: 1000, tier: .tier1, pattern: .staggeredLine, count: 5),
            WaveDefinition(trigger: 1080, tier: .tier2, pattern: .vShape,        count: 2, spawnX: -60),
            WaveDefinition(trigger: 1150, tier: .tier1, pattern: .sineWave,      count: 5),

            // -- Tier 3 mining barges + Tier 1 escort (1200–1600)
            WaveDefinition(trigger: 1200, tier: .tier3, pattern: .vShape,        count: 2),
            WaveDefinition(trigger: 1260, tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 1340, tier: .tier3, pattern: .staggeredLine, count: 2),
            WaveDefinition(trigger: 1400, tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 1480, tier: .tier3, pattern: .vShape,        count: 2),
            WaveDefinition(trigger: 1540, tier: .tier1, pattern: .staggeredLine, count: 5),

            // -- Final gauntlet: Tier 1 + Tier 2 (1700–2200)
            WaveDefinition(trigger: 1700, tier: .tier2, pattern: .vShape,        count: 3),
            WaveDefinition(trigger: 1780, tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 1860, tier: .tier2, pattern: .staggeredLine, count: 3),
            WaveDefinition(trigger: 1950, tier: .tier1, pattern: .vShape,        count: 5),
            WaveDefinition(trigger: 2040, tier: .tier2, pattern: .vShape,        count: 3, spawnX: -70),
            WaveDefinition(trigger: 2130, tier: .tier1, pattern: .sineWave,      count: 5),
            WaveDefinition(trigger: 2200, tier: .tier2, pattern: .vShape,        count: 2, spawnX: 50),

            // -- Boss
            WaveDefinition(trigger: 2400, tier: .boss,  pattern: .vShape,        count: 1),
        ]
    }

    private static func galaxy2ScriptedDrops() -> [ScriptedDrop] {
        return [
            ScriptedDrop(triggerDistance: 600,  type: .weaponModule),
            ScriptedDrop(triggerDistance: 1400, type: .weaponModule),
        ]
    }

    private static func galaxy2AsteroidFields() -> [AsteroidFieldDefinition] {
        return [
            AsteroidFieldDefinition(triggerDistance: 200,  count: 12, largeFraction: 0.3),
            AsteroidFieldDefinition(triggerDistance: 600,  count: 12, largeFraction: 0.3),
            AsteroidFieldDefinition(triggerDistance: 1000, count: 12, largeFraction: 0.3),
            AsteroidFieldDefinition(triggerDistance: 1500, count: 12, largeFraction: 0.3),
            AsteroidFieldDefinition(triggerDistance: 1900, count: 12, largeFraction: 0.3),
        ]
    }
}
