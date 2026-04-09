import Foundation

public enum ProgressStore {
    private static func key(for galaxy: Int) -> String? {
        switch galaxy {
        case 1: return "galaxy1Cleared"
        case 2: return "galaxy2Cleared"
        case 3: return "galaxy3Cleared"
        default: return nil
        }
    }

    public static func markCleared(galaxy: Int, store: UserDefaults = .standard) {
        guard let key = key(for: galaxy) else { return }
        store.set(true, forKey: key)
    }

    public static func isCleared(galaxy: Int, store: UserDefaults = .standard) -> Bool {
        guard let key = key(for: galaxy) else { return false }
        return store.bool(forKey: key)
    }
}
