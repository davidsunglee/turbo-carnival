import Testing
@testable import Engine2043

struct AudioTests {
    @Test @MainActor func audioManagerConformsToProtocol() {
        let manager = AVAudioManager()
        let provider: any AudioProvider = manager
        // Should be able to call without crash
        provider.playEffect("test")
        provider.playMusic("test")
        provider.stopAll()
    }

    @Test @MainActor func audioManagerSetsVolume() {
        let manager = AVAudioManager()
        manager.setMasterVolume(0.5)
        #expect(manager.masterVolume == 0.5)
    }

    @Test @MainActor func audioManagerClampsVolume() {
        let manager = AVAudioManager()
        manager.setMasterVolume(1.5)
        #expect(manager.masterVolume == 1.0)
        manager.setMasterVolume(-0.5)
        #expect(manager.masterVolume == 0.0)
    }
}
