import Foundation

/// Protocol for app preferences stored as JSON in UserDefaults.
///
/// Conforming types get `load()` and `save()` for free:
/// ```swift
/// struct MyPrefs: CodablePreference {
///     static let storageKey = "my_prefs"
///     var featureEnabled: Bool = false
/// }
/// let prefs = MyPrefs.load()
/// prefs.save()
/// ```
public protocol CodablePreference: Codable {
    static var storageKey: String { get }
    init()
}

extension CodablePreference {
    public static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self()
        }
        return decoded
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
