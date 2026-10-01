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
    public static let defaultOnAppliedKey = "defaultOnListIdentifiersApplied"
    public static let defaultOnIdentifiers = [DeltaInFlightSource.identifier]
    
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

    @discardableResult
    public static func applyDefaultOnListsIfNeeded(availableIdentifiers: [String]) -> Bool {
        guard hasInitialized() else { return false }
        let available = Set(availableIdentifiers)
        var applied = Set(decode(from: UserDefaults.standard.data(forKey: defaultOnAppliedKey) ?? Data()))
        var preferred = decode(from: UserDefaults.standard.data(forKey: storageKey) ?? Data())
        var changed = false
        for identifier in defaultOnIdentifiers {
            guard available.contains(identifier), applied.insert(identifier).inserted else { continue }
            changed = true
            if !preferred.contains(identifier) {
                preferred.append(identifier)
            }
        }
        guard changed else { return false }
        UserDefaults.standard.set(encode(preferred), forKey: storageKey)
        UserDefaults.standard.set(encode(Array(applied)), forKey: defaultOnAppliedKey)
        updateLastUpdated()
        return true
    }
}
