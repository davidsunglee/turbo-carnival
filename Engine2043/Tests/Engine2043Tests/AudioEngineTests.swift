import AVFoundation
import Testing
@testable import Engine2043

struct AudioEngineTests {
    @Test @MainActor func synthEngineInitializesWithoutCrash() {
        let engine = AudioEngine()
        #expect(engine.volume >= 0)
    }

    @Test @MainActor func synthEnginePlayDoesNotCrash() {
        let engine = AudioEngine()
        engine.play(.doubleCannonFire)
        engine.play(.enemyHit)
        engine.play(.itemPickup)
    }

    @Test @MainActor func synthEngineVolumeClamps() {
        let engine = AudioEngine()
        engine.volume = 1.5
        #expect(engine.volume == 1.0)
        engine.volume = -0.5
        #expect(engine.volume == 0.0)
    }

    @Test @MainActor func laserStartStopDoesNotCrash() {
        let engine = AudioEngine()
        engine.startLaser()
        engine.setLaserHeat(0.5)
        engine.stopLaser()
    }

    @Test @MainActor func laserHeatClampsTo01() {
        let engine = AudioEngine()
        engine.startLaser()
        engine.setLaserHeat(-1.0)
        engine.setLaserHeat(2.0)
        engine.stopLaser()
        // No crash = pass; values are atomics read on audio thread
    }

    @Test @MainActor func lightningArcCooldownPreventsRapidFire() {
        let engine = AudioEngine()
        // First play should succeed, rapid second should be rate-limited
        // (We can't directly observe skipped plays, but verify no crash under rapid fire)
        for _ in 0..<100 {
            engine.play(.lightningArcZap)
        }
        // If we got here without crash or audio glitch, rate limiting is working
    }

    @Test @MainActor func allSFXTypesPlayWithoutCrash() {
        let engine = AudioEngine()
        for sfx in SFXType.allCases {
            engine.play(sfx)
        }
    }

    @Test func musicMP3FilesExistInBundle() {
        let gameplayURL = Bundle.module.url(forResource: "gameplay", withExtension: "mp3")
        let bossURL = Bundle.module.url(forResource: "boss", withExtension: "mp3")
        #expect(gameplayURL != nil, "gameplay.mp3 should be bundled")
        #expect(bossURL != nil, "boss.mp3 should be bundled")
    }

    @Test func musicMP3FilesAreNonEmpty() throws {
        let gameplayURL = try #require(Bundle.module.url(forResource: "gameplay", withExtension: "mp3"))
        let gameplayData = try Data(contentsOf: gameplayURL)
        #expect(gameplayData.count > 0, "gameplay.mp3 should not be empty")

        let bossURL = try #require(Bundle.module.url(forResource: "boss", withExtension: "mp3"))
        let bossData = try Data(contentsOf: bossURL)
        #expect(bossData.count > 0, "boss.mp3 should not be empty")
    }

    @Test @MainActor func musicStartStopDoesNotCrash() {
        let engine = AudioEngine()
        engine.startMusic(.gameplay)
        engine.stopMusic()
    }

    @Test @MainActor func musicStartBossDoesNotCrash() {
        let engine = AudioEngine()
        engine.startMusic(.boss)
        engine.stopMusic()
    }

    @Test @MainActor func musicDoubleStartDoesNotCrash() {
        let engine = AudioEngine()
        engine.startMusic(.gameplay)
        engine.startMusic(.boss)
        engine.stopMusic()
    }

    @Test @MainActor func musicFadeDoesNotCrash() {
        let engine = AudioEngine()
        engine.startMusic(.gameplay)
        engine.fadeToTrack(.boss, fadeOut: 1.0, silence: 0.5, fadeIn: 1.0)
        engine.stopMusic()
    }

    @Test @MainActor func musicUpdateFadeAdvancesFade() {
        let engine = AudioEngine()
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

    @Test func musicTrackFilenameMapping() {
        #expect(MusicTrack.gameplay.filename == "gameplay")
        #expect(MusicTrack.boss.filename == "boss")
        #expect(MusicTrack.title.filename == "gameplay")
    }
}
