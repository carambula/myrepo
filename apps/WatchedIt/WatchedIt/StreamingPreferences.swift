//
//  StreamingPreferences.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 1/20/26.
//

import Foundation

public enum StreamingPreferences {
    public static let storageKey = "preferredStreamingServices"
    public static let hiddenStorageKey = "hiddenStreamingServices"
    public static let lastUpdatedKey = "streamingPreferencesLastUpdated"
    
    public static func decode(from data: Data) -> [String] {
        guard !data.isEmpty,
              let services = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return services
    }
    
    public static func encode(_ services: [String]) -> Data {
        (try? JSONEncoder().encode(services)) ?? Data()
    }

    public static func preferredServicesData() -> Data {
        UserDefaults.standard.data(forKey: storageKey) ?? Data()
    }

    public static func hiddenServicesData() -> Data {
        UserDefaults.standard.data(forKey: hiddenStorageKey) ?? Data()
    }

    public static func lastUpdated() -> Date {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date ?? Date.distantPast
    }

    public static func setPreferredServicesData(_ data: Data) {
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    public static func setHiddenServicesData(_ data: Data) {
        UserDefaults.standard.set(data, forKey: hiddenStorageKey)
    }

    public static func updateLastUpdated(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastUpdatedKey)
    }
}
