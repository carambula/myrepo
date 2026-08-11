//
//  ComponentTracking.swift
//  SpinMin
//
//  Track current components installed on bike
//

import Foundation
import SwiftData

@Model
final class ComponentTracking {
    var id: UUID
    var componentType: String  // ComponentType
    
    // Component identification
    var brand: String?
    var model: String?
    
    // Installation tracking
    var installDate: Date
    var installOdometerKm: Double
    
    // Current state
    var currentOdometerKm: Double  // Updated from bike odometer
    
    // Chain-specific tracking
    var chainLubeType: String?  // ChainLubeType
    var lastWaxDate: Date?
    var lastWaxOdometerKm: Double?
    var lastCleanDate: Date?
    var lastCleanOdometerKm: Double?
    var chainWearPercentage: Double?  // 0.5% = replace for 11-speed
    
    // Notes
    var notes: String
    
    // Relationship
    @Relationship(inverse: \BikeConfiguration.componentTracking) var bikeConfiguration: BikeConfiguration?
    
    init(
        componentType: ComponentType,
        brand: String? = nil,
        model: String? = nil,
        installDate: Date = Date(),
        installOdometerKm: Double,
        notes: String = ""
    ) {
        self.id = UUID()
        self.componentType = componentType.rawValue
        self.brand = brand
        self.model = model
        self.installDate = installDate
        self.installOdometerKm = installOdometerKm
        self.currentOdometerKm = installOdometerKm
        self.notes = notes
        
        // Chain-specific defaults
        self.chainLubeType = nil
        self.lastWaxDate = nil
        self.lastWaxOdometerKm = nil
        self.lastCleanDate = nil
        self.lastCleanOdometerKm = nil
        self.chainWearPercentage = 0.0
    }
    
    // MARK: - Computed Properties
    
    var component: ComponentType {
        get { ComponentType(rawValue: componentType) ?? .chain }
        set { componentType = newValue.rawValue }
    }
    
    var lubeType: ChainLubeType? {
        get {
            guard let raw = chainLubeType else { return nil }
            return ChainLubeType(rawValue: raw)
        }
        set {
            chainLubeType = newValue?.rawValue
        }
    }
    
    var componentMileageKm: Double {
        max(0, currentOdometerKm - installOdometerKm)
    }
    
    var componentAgeDays: Int {
        Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }
    
    var kmSinceLastWax: Double? {
        guard let lastWax = lastWaxOdometerKm else { return nil }
        return max(0, currentOdometerKm - lastWax)
    }
    
    var kmSinceLastClean: Double? {
        guard let lastClean = lastCleanOdometerKm else { return nil }
        return max(0, currentOdometerKm - lastClean)
    }
    
    var displayName: String {
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        } else if let brand = brand {
            return "\(brand) \(component.displayName)"
        }
        return component.displayName
    }
    
    /// Update odometer from bike
    func updateOdometer(_ newOdometerKm: Double) {
        currentOdometerKm = max(currentOdometerKm, newOdometerKm)
    }
    
    /// Record a wax
    func recordWax(date: Date = Date(), odometerKm: Double) {
        lastWaxDate = date
        lastWaxOdometerKm = odometerKm
        currentOdometerKm = max(currentOdometerKm, odometerKm)
    }
    
    /// Record a clean
    func recordClean(date: Date = Date(), odometerKm: Double) {
        lastCleanDate = date
        lastCleanOdometerKm = odometerKm
        currentOdometerKm = max(currentOdometerKm, odometerKm)
    }
}

// MARK: - Chain Lube Types

enum ChainLubeType: String, Codable, CaseIterable {
    case hotWax = "hot_wax"
    case dripWax = "drip_wax"
    case wet = "wet"
    case dry = "dry"
    
    var displayName: String {
        switch self {
        case .hotWax: return "Hot Wax (Immersion)"
        case .dripWax: return "Drip Wax"
        case .wet: return "Wet Lube"
        case .dry: return "Dry Lube"
        }
    }
    
    var shortName: String {
        switch self {
        case .hotWax: return "Hot Wax"
        case .dripWax: return "Drip Wax"
        case .wet: return "Wet"
        case .dry: return "Dry"
        }
    }
    
    /// Typical interval before reapplication (km)
    var intervalKm: Double {
        switch self {
        case .hotWax: return 500  // 300-600 km in dry
        case .dripWax: return 300  // 200-400 km
        case .wet: return 350  // 300-400 km
        case .dry: return 200  // 150-250 km
        }
    }
    
    /// Cleaning interval (km)
    var cleaningIntervalKm: Double {
        switch self {
        case .hotWax: return 1000  // Just wipe, re-wax is the clean
        case .dripWax: return 600
        case .wet: return 300  // Attracts dirt
        case .dry: return 400
        }
    }
    
    var description: String {
        switch self {
        case .hotWax:
            return "Cleanest and longest-lasting. Requires slow cooker setup. Lasts 300-600 km in dry, up to 1,000 km in wet."
        case .dripWax:
            return "Easy application, clean operation. Lasts 200-400 km. Needs clean chain to start."
        case .wet:
            return "Best for rain and mud. Lasts 300-400 km but attracts grit. Clean frequently."
        case .dry:
            return "For dry, dusty conditions. Lasts 150-250 km. Washes off in rain."
        }
    }
}
