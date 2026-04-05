//
//  ListPreferences.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 1/29/26.
//

import Foundation

public enum ListPreferences {
    public static let storageKey = "preferredListIdentifiers"
    private static let initializedKey = "preferredListsInitialized"
    private static let lastUpdatedKey = "listPreferencesLastUpdated"
    
    public static func decode(from data: Data) -> [String] {
        guard !data.isEmpty,
              let lists = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return lists
    }
    
    public static func encode(_ lists: [String]) -> Data {
        (try? JSONEncoder().encode(lists)) ?? Data()
    }
    
    public static func hasInitialized() -> Bool {
        UserDefaults.standard.bool(forKey: initializedKey)
    }
    
    public static func setHasInitialized(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: initializedKey)
    }

    public static func lastUpdated() -> Date {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date ?? Date.distantPast
    }

    public static func updateLastUpdated(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastUpdatedKey)
    }
}
