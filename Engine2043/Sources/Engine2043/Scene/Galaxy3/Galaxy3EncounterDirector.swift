import simd

public enum Galaxy3SpawnCommand: Sendable {
    case droneCluster(count: Int, spawnX: Float)
    case fighterSquad(count: Int, spawnX: Float)
    case fortressEncounter(fortressID: Int)
    case barrierLayout(kind: BarrierKind, width: Float)
    case bossTrigger
}

@MainActor
public final class Galaxy3EncounterDirector {
    public private(set) var pendingCommands: [Galaxy3SpawnCommand] = []
    public private(set) var bossTriggered: Bool = false

    struct EncounterDefinition {
        let triggerDistance: Float
        let command: Galaxy3SpawnCommand
    }

    private let encounters: [EncounterDefinition]
    private var nextEncounterIndex: Int = 0

    public init() {
        encounters = Self.galaxy3Script()
    }

    public func update(scrollDistance: Float, deltaTime: Double) {
        pendingCommands.removeAll(keepingCapacity: true)

        while nextEncounterIndex < encounters.count {
            let encounter = encounters[nextEncounterIndex]
            if scrollDistance >= encounter.triggerDistance {
                pendingCommands.append(encounter.command)
                if case .bossTrigger = encounter.command {
                    bossTriggered = true
                }
                nextEncounterIndex += 1
            } else {
                break
            }
        }
    }

    // MARK: - Galaxy 3 Encounter Script

    private static func galaxy3Script() -> [EncounterDefinition] {
        return [
            // -- Opening: drone clusters (50-300)
            EncounterDefinition(triggerDistance: 50,   command: .droneCluster(count: 4, spawnX: 100)),
            EncounterDefinition(triggerDistance: 120,  command: .droneCluster(count: 5, spawnX: 220)),
            EncounterDefinition(triggerDistance: 200,  command: .droneCluster(count: 4, spawnX: 160)),
            EncounterDefinition(triggerDistance: 280,  command: .droneCluster(count: 6, spawnX: 80)),

            // -- First barrier corridor (350-500)
            EncounterDefinition(triggerDistance: 350,  command: .barrierLayout(kind: .trenchWall, width: GameConfig.Galaxy3.Corridor.standardWidth)),
            EncounterDefinition(triggerDistance: 400,  command: .droneCluster(count: 3, spawnX: 180)),
            EncounterDefinition(triggerDistance: 470,  command: .droneCluster(count: 4, spawnX: 140)),

            // -- Fighter introduction (550-800)
            EncounterDefinition(triggerDistance: 550,  command: .fighterSquad(count: 2, spawnX: 120)),
            EncounterDefinition(triggerDistance: 630,  command: .droneCluster(count: 5, spawnX: 200)),
            EncounterDefinition(triggerDistance: 700,  command: .fighterSquad(count: 3, spawnX: 180)),
            EncounterDefinition(triggerDistance: 780,  command: .droneCluster(count: 4, spawnX: 100)),

            // -- Second barrier: rotating gates (850-1000)
            EncounterDefinition(triggerDistance: 850,  command: .barrierLayout(kind: .rotatingGate, width: GameConfig.Galaxy3.Corridor.wideWidth)),
            EncounterDefinition(triggerDistance: 900,  command: .fighterSquad(count: 2, spawnX: 160)),
            EncounterDefinition(triggerDistance: 970,  command: .droneCluster(count: 5, spawnX: 240)),

            // -- First fortress encounter (1050)
            EncounterDefinition(triggerDistance: 1050, command: .fortressEncounter(fortressID: 1)),
            EncounterDefinition(triggerDistance: 1150, command: .droneCluster(count: 4, spawnX: 100)),
            EncounterDefinition(triggerDistance: 1200, command: .fighterSquad(count: 3, spawnX: 260)),

            // -- Narrow trench corridor (1300-1500)
            EncounterDefinition(triggerDistance: 1300, command: .barrierLayout(kind: .trenchWall, width: GameConfig.Galaxy3.Corridor.narrowWidth)),
            EncounterDefinition(triggerDistance: 1370, command: .droneCluster(count: 6, spawnX: 180)),
            EncounterDefinition(triggerDistance: 1430, command: .fighterSquad(count: 2, spawnX: 180)),
            EncounterDefinition(triggerDistance: 1500, command: .droneCluster(count: 5, spawnX: 160)),

            // -- Second fortress encounter (1600)
            EncounterDefinition(triggerDistance: 1600, command: .fortressEncounter(fortressID: 2)),
            EncounterDefinition(triggerDistance: 1700, command: .fighterSquad(count: 4, spawnX: 120)),
            EncounterDefinition(triggerDistance: 1780, command: .droneCluster(count: 5, spawnX: 200)),

            // -- Final gauntlet: rotating gates + mixed enemies (1850-2100)
            EncounterDefinition(triggerDistance: 1850, command: .barrierLayout(kind: .rotatingGate, width: GameConfig.Galaxy3.Corridor.standardWidth)),
            EncounterDefinition(triggerDistance: 1900, command: .fighterSquad(count: 3, spawnX: 180)),
            EncounterDefinition(triggerDistance: 1970, command: .droneCluster(count: 6, spawnX: 100)),
            EncounterDefinition(triggerDistance: 2050, command: .fighterSquad(count: 4, spawnX: 220)),
            EncounterDefinition(triggerDistance: 2100, command: .droneCluster(count: 5, spawnX: 160)),

            // -- Boss trigger (2200)
            EncounterDefinition(triggerDistance: 2200, command: .bossTrigger),
        ]
    }
}
