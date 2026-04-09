import Testing
import Foundation
@testable import Engine2043

struct ProgressStoreTests {
    private func freshDefaults() -> UserDefaults {
        let suiteName = "ProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func isClearedDefaultsToFalse() {
        let defaults = freshDefaults()
        #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 2, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 3, store: defaults) == false)
    }

    @Test func markClearedPersists() {
        let defaults = freshDefaults()
        ProgressStore.markCleared(galaxy: 2, store: defaults)
        #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 2, store: defaults) == true)
        #expect(ProgressStore.isCleared(galaxy: 3, store: defaults) == false)
    }

    @Test func markClearedAllThreeGalaxies() {
        let defaults = freshDefaults()
        ProgressStore.markCleared(galaxy: 1, store: defaults)
        ProgressStore.markCleared(galaxy: 2, store: defaults)
        ProgressStore.markCleared(galaxy: 3, store: defaults)
        #expect(ProgressStore.isCleared(galaxy: 1, store: defaults) == true)
        #expect(ProgressStore.isCleared(galaxy: 2, store: defaults) == true)
        #expect(ProgressStore.isCleared(galaxy: 3, store: defaults) == true)
    }

    @Test func invalidGalaxyNumberReturnsFalse() {
        let defaults = freshDefaults()
        #expect(ProgressStore.isCleared(galaxy: 0, store: defaults) == false)
        #expect(ProgressStore.isCleared(galaxy: 4, store: defaults) == false)
    }

    @Test func convenienceMethodsUseStandardDefaults() {
        _ = ProgressStore.isCleared(galaxy: 1)
    }
}
