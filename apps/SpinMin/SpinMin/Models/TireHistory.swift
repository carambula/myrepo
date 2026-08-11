//
//  TireHistory.swift
//  SpinMin
//
//  Historical record of tire changes and lifecycle
//

import Foundation
import SwiftData

@Model
final class TireHistory {
    var id: UUID
    
    // Position and identification
    var position: String  // TirePosition
    var tireBrand: String?
    var tireModel: String?
    var tireCompoundType: String  // TireCompoundType
    
    // Lifecycle tracking
    var installDate: Date
    var removeDate: Date
    var totalMileageKm: Double
    var durationDays: Int
    
    // Condition at removal
    var removalReason: String  // RemovalReason
    var conditionAtRemoval: String
    var finalPunctureCount: Int
    
    // Visual wear indicators at removal
    var hadSquaredProfile: Bool
    var hadSidewallCracks: Bool
    var hadCasingExposure: Bool
    
    // Relationship
    @Relationship(inverse: \Wheelset.tireHistory) var wheelset: Wheelset?
    
    init(
        from tireTracking: TireTracking,
        removeDate: Date = Date(),
        removalReason: RemovalReason,
        conditionNotes: String = ""
    ) {
        self.id = UUID()
        self.position = tireTracking.position
        self.tireBrand = tireTracking.tireBrand
        self.tireModel = tireTracking.tireModel
        self.tireCompoundType = tireTracking.tireCompoundType
        
        self.installDate = tireTracking.installDate
        self.removeDate = removeDate
        self.totalMileageKm = tireTracking.tireMileageKm
        self.durationDays = Calendar.current.dateComponents(
            [.day],
            from: tireTracking.installDate,
            to: removeDate
        ).day ?? 0
        
        self.removalReason = removalReason.rawValue
        self.conditionAtRemoval = conditionNotes.isEmpty ? tireTracking.conditionNotes : conditionNotes
        self.finalPunctureCount = tireTracking.punctureCount
        
        self.hadSquaredProfile = tireTracking.hasSquaredProfile
        self.hadSidewallCracks = tireTracking.hasSidewallCracks
        self.hadCasingExposure = tireTracking.hasCasingExposure
    }
    
    // MARK: - Computed Properties
    
    var tirePosition: TirePosition {
        TirePosition(rawValue: position) ?? .front
    }
    
    var compoundType: TireCompoundType {
        TireCompoundType(rawValue: tireCompoundType) ?? .training
    }
    
    var reason: RemovalReason {
        RemovalReason(rawValue: removalReason) ?? .worn
    }
    
    var displayName: String {
        if let brand = tireBrand, let model = tireModel {
            return "\(brand) \(model)"
        }
        return "Tire"
    }
    
    var durationMonths: Double {
        Double(durationDays) / 30.44  // Average month length
    }
    
    var averageKmPerDay: Double {
        guard durationDays > 0 else { return 0 }
        return totalMileageKm / Double(durationDays)
    }
    
    /// Formatted summary for display
    var summary: String {
        let months = String(format: "%.1f", durationMonths)
        let km = String(format: "%.0f", totalMileageKm)
        return "\(displayName) · \(km) km over \(months) months · \(reason.displayName)"
    }
}

enum RemovalReason: String, Codable, CaseIterable {
    case worn = "worn"
    case damaged = "damaged"
    case puncture = "puncture"
    case aged = "aged"
    case upgrade = "upgrade"
    case seasonal = "seasonal"
    case experimental = "experimental"
    
    var displayName: String {
        switch self {
        case .worn: return "Worn Out"
        case .damaged: return "Damaged"
        case .puncture: return "Repeated Punctures"
        case .aged: return "Age Limit Reached"
        case .upgrade: return "Upgrade"
        case .seasonal: return "Seasonal Change"
        case .experimental: return "Testing/Experimentation"
        }
    }
}
