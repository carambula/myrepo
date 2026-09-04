//
//  TireTracking.swift
//  SpinMin
//
//  Tracks current tire state for a wheelset (front and rear separately)
//

import Foundation
import SwiftData

@Model
final class TireTracking {
    var id: UUID
    
    // Position
    var position: String  // TirePosition: "front" or "rear"
    
    // Tire identification
    var tireBrand: String?
    var tireModel: String?
    var tireCompoundType: String  // TireCompoundType
    
    // Installation tracking
    var installDate: Date
    var initialMileageKm: Double  // Bike's odometer reading when tire was installed
    var currentMileageKm: Double  // Current bike odometer reading
    
    // Expected lifespan (calculated based on tire type and riding conditions)
    var expectedLifespanKm: Double
    
    // Manual condition tracking
    var lastInspectionDate: Date?
    var conditionNotes: String  // User notes on visual condition
    var punctureCount: Int
    
    // Wear indicators
    var hasVisibleWear: Bool
    var hasSquaredProfile: Bool
    var hasSidewallCracks: Bool
    var hasCasingExposure: Bool  // Critical - replace immediately
    var hasCuts: Bool
    
    // Relationship
    @Relationship(inverse: \Wheelset.tireTracking) var wheelset: Wheelset?
    
    init(
        position: TirePosition,
        tireBrand: String? = nil,
        tireModel: String? = nil,
        compoundType: TireCompoundType,
        installDate: Date = Date(),
        initialMileageKm: Double = 0,
        expectedLifespanKm: Double? = nil
    ) {
        self.id = UUID()
        self.position = position.rawValue
        self.tireBrand = tireBrand
        self.tireModel = tireModel
        self.tireCompoundType = compoundType.rawValue
        self.installDate = installDate
        self.initialMileageKm = initialMileageKm
        self.currentMileageKm = initialMileageKm
        
        // Calculate expected lifespan based on compound type and position
        if let provided = expectedLifespanKm {
            self.expectedLifespanKm = provided
        } else {
            self.expectedLifespanKm = compoundType.defaultLifespanKm(for: position)
        }
        
        self.lastInspectionDate = installDate
        self.conditionNotes = ""
        self.punctureCount = 0
        
        self.hasVisibleWear = false
        self.hasSquaredProfile = false
        self.hasSidewallCracks = false
        self.hasCasingExposure = false
        self.hasCuts = false
    }
    
    // MARK: - Computed Properties
    
    var tirePosition: TirePosition {
        get { TirePosition(rawValue: position) ?? .front }
        set { position = newValue.rawValue }
    }
    
    var compoundType: TireCompoundType {
        get { TireCompoundType(rawValue: tireCompoundType) ?? .training }
        set { tireCompoundType = newValue.rawValue }
    }
    
    /// Current mileage on this specific tire
    var tireMileageKm: Double {
        max(0, currentMileageKm - initialMileageKm)
    }
    
    /// Age of tire in days
    var tireAgeDays: Int {
        Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }
    
    /// Age of tire in years (fractional)
    var tireAgeYears: Double {
        Double(tireAgeDays) / 365.25
    }
    
    /// Percentage of expected lifespan used (mileage-based)
    var mileageWearPercentage: Double {
        guard expectedLifespanKm > 0 else { return 0 }
        return min(100, (tireMileageKm / expectedLifespanKm) * 100)
    }
    
    /// Display name for the tire
    var displayName: String {
        if let brand = tireBrand, let model = tireModel {
            return "\(brand) \(model)"
        }
        return "Tire"
    }
    
    /// Short position label
    var positionLabel: String {
        tirePosition == .front ? "F" : "R"
    }
}

// MARK: - Supporting Types

enum TirePosition: String, Codable, CaseIterable {
    case front = "front"
    case rear = "rear"
    
    var displayName: String {
        switch self {
        case .front: return "Front"
        case .rear: return "Rear"
        }
    }
}

enum TireCompoundType: String, Codable, CaseIterable {
    case racing = "racing"           // Soft compound, best grip, shortest life
    case training = "training"       // Balanced performance and durability
    case endurance = "endurance"     // Hard compound, long-lasting
    case touring = "touring"         // Extra durable, puncture-resistant
    case gravel = "gravel"           // Mixed terrain
    case mtbXC = "mtb_xc"           // Cross-country MTB
    case mtbTrail = "mtb_trail"     // All-mountain
    case mtbEnduro = "mtb_enduro"   // Aggressive terrain
    
    var displayName: String {
        switch self {
        case .racing: return "Racing"
        case .training: return "Training/All-Round"
        case .endurance: return "Endurance"
        case .touring: return "Touring/Puncture-Resistant"
        case .gravel: return "Gravel"
        case .mtbXC: return "MTB Cross-Country"
        case .mtbTrail: return "MTB Trail"
        case .mtbEnduro: return "MTB Enduro"
        }
    }
    
    var shortName: String {
        switch self {
        case .racing: return "Race"
        case .training: return "Train"
        case .endurance: return "Enduro"
        case .touring: return "Tour"
        case .gravel: return "Gravel"
        case .mtbXC: return "XC"
        case .mtbTrail: return "Trail"
        case .mtbEnduro: return "Enduro"
        }
    }
    
    /// Default expected lifespan in kilometers based on research
    func defaultLifespanKm(for position: TirePosition) -> Double {
        let baseMileage: Double
        
        switch self {
        case .racing:
            baseMileage = 2500  // 2,000-3,000 km
        case .training:
            baseMileage = 5000  // 4,000-6,000 km
        case .endurance:
            baseMileage = 8000  // 6,000-10,000 km
        case .touring:
            baseMileage = 10000 // 8,000-12,000 km
        case .gravel:
            baseMileage = 3500  // 2,000-5,000 km (mixed terrain)
        case .mtbXC:
            baseMileage = 3000  // 1,500-5,000 km
        case .mtbTrail:
            baseMileage = 2500  // Aggressive riding
        case .mtbEnduro:
            baseMileage = 2000  // Very aggressive
        }
        
        // Rear tire wears approximately 2x faster than front
        return position == .rear ? baseMileage : baseMileage * 2.0
    }
    
    /// Description of typical use case
    var description: String {
        switch self {
        case .racing:
            return "Soft compound for maximum grip in races. Shortest lifespan (~2,500 km rear, ~5,000 km front)."
        case .training:
            return "Balanced performance and durability for daily riding (~5,000 km rear, ~10,000 km front)."
        case .endurance:
            return "Hard compound for high mileage training and long rides (~8,000 km rear, ~16,000 km front)."
        case .touring:
            return "Maximum durability with puncture resistance for loaded touring (~10,000+ km rear)."
        case .gravel:
            return "Mixed terrain use with moderate lifespan (~3,500 km rear, ~7,000 km front)."
        case .mtbXC:
            return "Cross-country with moderate trail use (~3,000 km rear, ~6,000 km front)."
        case .mtbTrail:
            return "All-mountain with aggressive riding (~2,500 km rear, ~5,000 km front)."
        case .mtbEnduro:
            return "Very aggressive terrain and hard braking (~2,000 km rear, ~4,000 km front)."
        }
    }
}
