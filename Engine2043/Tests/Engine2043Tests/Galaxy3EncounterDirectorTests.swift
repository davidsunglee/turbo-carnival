import Testing
@testable import Engine2043

struct Galaxy3EncounterDirectorTests {

    @Test @MainActor func initialStateHasNoCommands() {
        let director = Galaxy3EncounterDirector()
        #expect(director.pendingCommands.isEmpty)
        #expect(!director.bossTriggered)
    }

    @Test @MainActor func earlyScrollEmitsDroneCluster() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 55, deltaTime: 1.0 / 60.0)

        #expect(!director.pendingCommands.isEmpty)

        let firstCommand = director.pendingCommands[0]
        if case .droneCluster(let count, _) = firstCommand {
            #expect(count == 4)
        } else {
            Issue.record("Expected droneCluster command, got \(firstCommand)")
        }
    }

    @Test @MainActor func bossTriggeredAtEndOfScript() {
        let director = Galaxy3EncounterDirector()
        // Scroll far enough to trigger the boss
        director.update(scrollDistance: 2500, deltaTime: 1.0 / 60.0)

        #expect(director.bossTriggered)

        let hasBossTrigger = director.pendingCommands.contains { command in
            if case .bossTrigger = command { return true }
            return false
        }
        #expect(hasBossTrigger)
    }

    @Test @MainActor func commandsResetEachUpdate() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 55, deltaTime: 1.0 / 60.0)
        #expect(!director.pendingCommands.isEmpty)
        let firstCount = director.pendingCommands.count

        // Second update at the same distance should yield no new commands
        director.update(scrollDistance: 55, deltaTime: 1.0 / 60.0)
        #expect(director.pendingCommands.isEmpty, "Commands should reset after each update, got \(director.pendingCommands.count) commands")

        _ = firstCount  // suppress unused warning
    }

    @Test @MainActor func noScrollProducesNoCommands() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 0, deltaTime: 1.0 / 60.0)
        #expect(director.pendingCommands.isEmpty)
    }

    @Test @MainActor func fighterSquadAppearsAfterDrones() {
        let director = Galaxy3EncounterDirector()
        // Fighters start at 550
        director.update(scrollDistance: 560, deltaTime: 1.0 / 60.0)

        let hasFighterSquad = director.pendingCommands.contains { command in
            if case .fighterSquad = command { return true }
            return false
        }
        #expect(hasFighterSquad)
    }

    @Test @MainActor func barrierLayoutEmitted() {
        let director = Galaxy3EncounterDirector()
        // First barrier at 350
        director.update(scrollDistance: 360, deltaTime: 1.0 / 60.0)

        let hasBarrier = director.pendingCommands.contains { command in
            if case .barrierLayout = command { return true }
            return false
        }
        #expect(hasBarrier)
    }

    @Test @MainActor func fortressEncounterEmitted() {
        let director = Galaxy3EncounterDirector()
        // First fortress at 1050
        director.update(scrollDistance: 1060, deltaTime: 1.0 / 60.0)

        let hasFortress = director.pendingCommands.contains { command in
            if case .fortressEncounter(let fID) = command {
                return fID == 1
            }
            return false
        }
        #expect(hasFortress)
    }

    @Test @MainActor func bossNotTriggeredBeforeThreshold() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 2100, deltaTime: 1.0 / 60.0)
        #expect(!director.bossTriggered)
    }

    @Test @MainActor func progressiveScrollAccumulatesCommands() {
        let director = Galaxy3EncounterDirector()

        // First update: early drones only
        director.update(scrollDistance: 55, deltaTime: 1.0 / 60.0)
        let firstBatch = director.pendingCommands.count
        #expect(firstBatch > 0)

        // Second update: more distance, more encounters
        director.update(scrollDistance: 300, deltaTime: 1.0 / 60.0)
        let secondBatch = director.pendingCommands.count
        #expect(secondBatch > 0)
    }
}
