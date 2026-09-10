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

enum PlayMenuStreamingFilter {
    static func services(
        available: [StreamingService],
        preferredNames: [String],
        hiddenNames: [String] = []
    ) -> [StreamingService] {
        let hidden = Set(hiddenNames.map(normalizedKey).filter { !$0.isEmpty })
        let visible = available.filter { !hidden.contains(normalizedKey($0.name)) }
        let preferredOrder = uniquePreferredKeys(preferredNames)
        guard !preferredOrder.isEmpty else {
            return visible
        }
        let preferredSet = Set(preferredOrder)
        return visible
            .filter { preferredSet.contains(normalizedKey($0.name)) }
            .sorted {
                (preferredOrder.firstIndex(of: normalizedKey($0.name)) ?? .max)
                    < (preferredOrder.firstIndex(of: normalizedKey($1.name)) ?? .max)
            }
    }

    private static func uniquePreferredKeys(_ names: [String]) -> [String] {
        var order: [String] = []
        var seen = Set<String>()
        for name in names {
            let key = normalizedKey(name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            order.append(key)
        }
        return order
    }

    private static func normalizedKey(_ name: String) -> String {
        StreamingServiceAssets.normalizedName(name).lowercased()
    }
}
