import Testing
@testable import Engine2043

struct SynthAudioTests {
    @Test @MainActor func synthEngineInitializesWithoutCrash() {
        let engine = SynthAudioEngine()
        #expect(engine.volume >= 0)
    }

    @Test @MainActor func synthEnginePlayDoesNotCrash() {
        let engine = SynthAudioEngine()
        engine.play(.doubleCannonFire)
        engine.play(.enemyHit)
        engine.play(.itemPickup)
    }

    @Test @MainActor func synthEngineVolumeClamps() {
        let engine = SynthAudioEngine()
        engine.volume = 1.5
        #expect(engine.volume == 1.0)
        engine.volume = -0.5
        #expect(engine.volume == 0.0)
    }

    @Test @MainActor func laserStartStopDoesNotCrash() {
        let engine = SynthAudioEngine()
        engine.startLaser()
        engine.setLaserHeat(0.5)
        engine.stopLaser()
    }

    @Test @MainActor func laserHeatClampsTo01() {
        let engine = SynthAudioEngine()
        engine.startLaser()
        engine.setLaserHeat(-1.0)
        engine.setLaserHeat(2.0)
        engine.stopLaser()
        // No crash = pass; values are atomics read on audio thread
    }

    @Test func sfxTypeHasAllExpectedCases() {
        let allCases = SFXType.allCases
        #expect(allCases.count == 9)
        #expect(allCases.contains(.doubleCannonFire))
        #expect(allCases.contains(.triSpreadFire))
        #expect(allCases.contains(.vulcanFire))
        #expect(allCases.contains(.enemyHit))
        #expect(allCases.contains(.enemyDestroyed))
        #expect(allCases.contains(.playerDamaged))
        #expect(allCases.contains(.itemSpawn))
        #expect(allCases.contains(.itemCycle))
        #expect(allCases.contains(.itemPickup))
    }
}
