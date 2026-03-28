import Testing
@testable import Engine2043

struct AudioProviderTests {
    @Test @MainActor func mockAudioProviderRecordsEffects() {
        let audio = MockAudioProvider()
        audio.playEffect("laser")
        audio.playEffect("explosion")

        #expect(audio.playedEffects == ["laser", "explosion"])
    }

    @Test @MainActor func mockAudioProviderRecordsMusic() {
        let audio = MockAudioProvider()
        audio.playMusic("gameplay_theme")

        #expect(audio.playedMusic == ["gameplay_theme"])
    }

    @Test @MainActor func mockAudioProviderTracksStopAll() {
        let audio = MockAudioProvider()
        audio.stopAll()
        audio.stopAll()

        #expect(audio.stopAllCount == 2)
    }

    @Test @MainActor func mockAudioProviderStartsEmpty() {
        let audio = MockAudioProvider()
        #expect(audio.playedEffects.isEmpty)
        #expect(audio.playedMusic.isEmpty)
        #expect(audio.stopAllCount == 0)
    }
}
