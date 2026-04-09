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

    // MARK: - Command Ordering

    @Test @MainActor func commandsEmittedInTriggerDistanceOrder() {
        let director = Galaxy3EncounterDirector()
        // Scroll far enough to trigger everything
        director.update(scrollDistance: 3000, deltaTime: 1.0 / 60.0)

        let commands = director.pendingCommands
        #expect(commands.count > 1, "Should have multiple commands")

        // Verify droneCluster appears before bossTrigger (which should be last)
        var hasDrone = false
        var bossIndex: Int? = nil
        for (i, cmd) in commands.enumerated() {
            if case .droneCluster = cmd {
                hasDrone = true
                // No boss trigger should have appeared before any drone cluster
                #expect(bossIndex == nil, "Drone cluster should appear before boss trigger")
            }
            if case .bossTrigger = cmd {
                bossIndex = i
            }
        }
        #expect(hasDrone, "Script should contain drone clusters")
        #expect(bossIndex != nil, "Script should contain boss trigger")
    }

    @Test @MainActor func bossTriggerIsLastCommand() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 3000, deltaTime: 1.0 / 60.0)

        let commands = director.pendingCommands
        guard let lastCommand = commands.last else {
            Issue.record("No commands emitted")
            return
        }
        if case .bossTrigger = lastCommand {
            // Expected
        } else {
            Issue.record("Last command should be .bossTrigger, got \(lastCommand)")
        }
    }

    // MARK: - All Five Command Types Present

    @Test @MainActor func allFiveCommandTypesAppearInFullScript() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 3000, deltaTime: 1.0 / 60.0)

        var hasDroneCluster = false
        var hasFighterSquad = false
        var hasFortressEncounter = false
        var hasBarrierLayout = false
        var hasBossTrigger = false

        for cmd in director.pendingCommands {
            switch cmd {
            case .droneCluster: hasDroneCluster = true
            case .fighterSquad: hasFighterSquad = true
            case .fortressEncounter: hasFortressEncounter = true
            case .barrierLayout: hasBarrierLayout = true
            case .bossTrigger: hasBossTrigger = true
            }
        }

        #expect(hasDroneCluster, "Script should contain droneCluster commands")
        #expect(hasFighterSquad, "Script should contain fighterSquad commands")
        #expect(hasFortressEncounter, "Script should contain fortressEncounter commands")
        #expect(hasBarrierLayout, "Script should contain barrierLayout commands")
        #expect(hasBossTrigger, "Script should contain bossTrigger command")
    }

    // MARK: - No Repeat Firing

    @Test @MainActor func commandsFireOnlyOnce() {
        let director = Galaxy3EncounterDirector()

        // First update triggers everything
        director.update(scrollDistance: 3000, deltaTime: 1.0 / 60.0)
        let firstBatchCount = director.pendingCommands.count
        #expect(firstBatchCount > 0)

        // Second update at the same (or greater) distance should yield nothing
        director.update(scrollDistance: 3000, deltaTime: 1.0 / 60.0)
        #expect(director.pendingCommands.isEmpty, "Each trigger distance should fire only once")

        // Third update even further should yield nothing (all commands already consumed)
        director.update(scrollDistance: 5000, deltaTime: 1.0 / 60.0)
        #expect(director.pendingCommands.isEmpty, "No commands left after full script consumed")
    }

    // MARK: - Incremental Scroll Emits Incrementally

    @Test @MainActor func incrementalScrollEmitsCommandsProgressively() {
        let director = Galaxy3EncounterDirector()

        // Scroll to 55 — should get first drone cluster
        director.update(scrollDistance: 55, deltaTime: 1.0 / 60.0)
        let batch1 = director.pendingCommands.count

        // Scroll to 120 — should get the next drone cluster
        director.update(scrollDistance: 120, deltaTime: 1.0 / 60.0)
        let batch2 = director.pendingCommands.count

        // Each batch should be non-empty
        #expect(batch1 > 0)
        #expect(batch2 > 0)

        // The total from incremental should equal what we'd get from a single jump
        let director2 = Galaxy3EncounterDirector()
        director2.update(scrollDistance: 120, deltaTime: 1.0 / 60.0)
        #expect(director2.pendingCommands.count == batch1 + batch2,
                "Incremental scroll should yield same commands as single jump")
    }

    // MARK: - Two Fortress Encounters

    @Test @MainActor func twoFortressEncountersWithDistinctIDs() {
        let director = Galaxy3EncounterDirector()
        director.update(scrollDistance: 3000, deltaTime: 1.0 / 60.0)

        var fortressIDs: [Int] = []
        for cmd in director.pendingCommands {
            if case .fortressEncounter(let fID) = cmd {
                fortressIDs.append(fID)
            }
        }

        #expect(fortressIDs.count == 2, "Script should have exactly 2 fortress encounters")
        #expect(fortressIDs[0] != fortressIDs[1], "Fortress IDs should be distinct")
        #expect(fortressIDs.contains(1))
        #expect(fortressIDs.contains(2))
    }
}
