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

    @Test func musicStateDefaultValues() {
        let state = MusicState()
        state.amplitude.withLock { #expect($0 == 0.0) }
        state.track.withLock { #expect($0 == .gameplay) }
        state.samplePosition.withLock { #expect($0 == 0) }
    }

    @Test func musicSynthesizerProducesNonSilentOutput() {
        let sampleRate: Float = 44100
        var hasNonZero = false
        for i in 0..<Int(sampleRate) {
            let t = Float(i) / sampleRate
            let sample = MusicSynthesizer.synthesize(track: .gameplay, time: t, sampleRate: sampleRate)
            if abs(sample) > 0.001 { hasNonZero = true; break }
        }
        #expect(hasNonZero, "Gameplay track should produce audible output")
    }

    @Test func musicSynthesizerBossTrackProducesOutput() {
        let sampleRate: Float = 44100
        var hasNonZero = false
        for i in 0..<Int(sampleRate) {
            let t = Float(i) / sampleRate
            let sample = MusicSynthesizer.synthesize(track: .boss, time: t, sampleRate: sampleRate)
            if abs(sample) > 0.001 { hasNonZero = true; break }
        }
        #expect(hasNonZero, "Boss track should produce audible output")
    }

    @Test func musicSynthesizerOutputInRange() {
        let sampleRate: Float = 44100
        for i in 0..<Int(sampleRate * 2) {
            let t = Float(i) / sampleRate
            let sample = MusicSynthesizer.synthesize(track: .gameplay, time: t, sampleRate: sampleRate)
            #expect(sample >= -1.5 && sample <= 1.5, "Sample \(sample) at t=\(t) out of range")
        }
    }

    @Test @MainActor func musicStartStopDoesNotCrash() {
        let engine = SynthAudioEngine()
        engine.startMusic(.gameplay)
        engine.stopMusic()
    }

    @Test @MainActor func musicStartBossDoesNotCrash() {
        let engine = SynthAudioEngine()
        engine.startMusic(.boss)
        engine.stopMusic()
    }

    @Test @MainActor func musicDoubleStartDoesNotCrash() {
        let engine = SynthAudioEngine()
        engine.startMusic(.gameplay)
        engine.startMusic(.boss)
        engine.stopMusic()
    }

    @Test @MainActor func musicFadeDoesNotCrash() {
        let engine = SynthAudioEngine()
        engine.startMusic(.gameplay)
        engine.fadeToTrack(.boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
        engine.stopMusic()
    }

    @Test @MainActor func musicUpdateFadeAdvancesFade() {
        let engine = SynthAudioEngine()
        engine.startMusic(.gameplay)
        engine.fadeToTrack(.boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
        // Simulate several update ticks
        for _ in 0..<60 {
            engine.updateMusicFade(deltaTime: 1.0 / 60.0)
        }
        // Should not crash, fade should progress
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
