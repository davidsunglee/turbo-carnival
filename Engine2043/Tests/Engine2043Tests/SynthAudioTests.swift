import Testing
@testable import Engine2043

struct SynthAudioTests {
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
