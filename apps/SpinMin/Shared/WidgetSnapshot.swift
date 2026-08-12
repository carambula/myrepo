//
//  WidgetSnapshot.swift
//  SpinMin
//
//  Lightweight data snapshot shared between the app, the widget, and
//  App Intents through the App Group container. The app refreshes it
//  whenever relevant data changes; the widget and Siri read it without
//  needing the SwiftData store.
//

import Foundation

struct WidgetSnapshot: Codable {
    struct BikePressure: Codable {
        let bikeName: String
        let wheelsetName: String?
        let frontPSI: Double
        let rearPSI: Double
    }
    
    struct UpcomingRide: Codable {
        let name: String
        let date: Date
        let rideTypeName: String
        let distanceKm: Double?
        let isPrepared: Bool
    }
    
    var generatedAt: Date
    var bikes: [BikePressure]
    var todayRide: UpcomingRide?
    var nextRide: UpcomingRide?
    
    static let appGroupId = "group.Carambula-Projects.SpinMin"
    private static let fileName = "widget-snapshot.json"
    
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(fileName)
    }
    
    static func load() -> WidgetSnapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
    
    func save() {
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
