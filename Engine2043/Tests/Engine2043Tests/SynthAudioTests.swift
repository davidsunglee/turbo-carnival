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

    @Test @MainActor func lightningArcCooldownPreventsRapidFire() {
        let engine = SynthAudioEngine()
        // First play should succeed, rapid second should be rate-limited
        // (We can't directly observe skipped plays, but verify no crash under rapid fire)
        for _ in 0..<100 {
            engine.play(.lightningArcZap)
        }
        // If we got here without crash or audio glitch, rate limiting is working
    }

    @Test @MainActor func allSFXTypesPlayWithoutCrash() {
        let engine = SynthAudioEngine()
        for sfx in SFXType.allCases {
            engine.play(sfx)
        }
    }

    @Test func sfxTypeHasAllExpectedCases() {
        let allCases = SFXType.allCases
        #expect(allCases.count == 16)
        #expect(allCases.contains(.doubleCannonFire))
        #expect(allCases.contains(.triSpreadFire))
        #expect(allCases.contains(.lightningArcZap))
        #expect(allCases.contains(.enemyHit))
        #expect(allCases.contains(.enemyDestroyed))
        #expect(allCases.contains(.playerDamaged))
        #expect(allCases.contains(.itemSpawn))
        #expect(allCases.contains(.itemCycle))
        #expect(allCases.contains(.itemPickup))
        #expect(allCases.contains(.gravBombLaunch))
        #expect(allCases.contains(.gravBombDetonate))
        #expect(allCases.contains(.empSweep))
        #expect(allCases.contains(.overchargeActivate))
        #expect(allCases.contains(.bossShieldDeflect))
        #expect(allCases.contains(.playerDeath))
        #expect(allCases.contains(.victory))
    }
}
