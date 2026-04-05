import Foundation
import Observation

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let selectedThemeKey = "selectedThemeID"
    private let store = NSUbiquitousKeyValueStore.default

    private(set) var availableThemes: [BuiltInTheme] = BuiltInThemes.all
    var selectedThemeID: String {
        didSet {
            UserDefaults.standard.set(selectedThemeID, forKey: selectedThemeKey)
            store.set(selectedThemeID, forKey: selectedThemeKey)
            store.synchronize()
        }
    }

    var currentTheme: BuiltInTheme {
        availableThemes.first(where: { $0.id == selectedThemeID }) ?? BuiltInThemes.midnight
    }

    private init() {
        let localThemeID = UserDefaults.standard.string(forKey: selectedThemeKey)
        let cloudThemeID = store.string(forKey: selectedThemeKey)
        selectedThemeID = localThemeID ?? cloudThemeID ?? BuiltInThemes.midnight.id
        syncFromCloud()
    }

    func select(themeID: String) {
        selectedThemeID = themeID
    }

    func syncFromCloud() {
        guard let cloudTheme = store.string(forKey: selectedThemeKey), !cloudTheme.isEmpty else {
            return
        }
        selectedThemeID = cloudTheme
    }
}
