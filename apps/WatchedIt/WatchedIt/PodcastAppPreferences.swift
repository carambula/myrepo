//
//  PodcastAppPreferences.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 2/8/26.
//

import Foundation

public enum PodcastApp: String, CaseIterable, Identifiable {
    case applePodcasts = "Apple Podcasts"
    case spotify = "Spotify"
    case overcast = "Overcast"
    case pocketCasts = "Pocket Casts"
    case podMin = "Pod Min"
    
    public var id: String { rawValue }
    
    private static let legacyNames: [String: PodcastApp] = [
        "podlink": .podMin
    ]
    
    public static func fromStoredValue(_ value: String) -> PodcastApp? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let match = PodcastApp.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        return legacyNames[trimmed.lowercased()]
    }
}

public enum PodcastAppPreferences {
    public static let storageKey = "preferredPodcastApp"
    public static let lastUpdatedKey = "preferredPodcastAppLastUpdated"
    
    public static func preferredApp(from storedValue: String) -> PodcastApp {
        PodcastApp.fromStoredValue(storedValue) ?? .applePodcasts
    }

    public static func preferredAppName() -> String? {
        UserDefaults.standard.string(forKey: storageKey)
    }

    public static func setPreferredAppName(_ name: String) {
        UserDefaults.standard.set(name, forKey: storageKey)
    }

    public static func lastUpdated() -> Date {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date ?? Date.distantPast
    }

    public static func updateLastUpdated(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastUpdatedKey)
    }
}
