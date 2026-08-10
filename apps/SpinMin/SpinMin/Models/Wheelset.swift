//
//  Wheelset.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation
import SwiftData

@Model
final class Wheelset {
    var id: UUID
    var name: String
    
    // Wheel specs
    var wheelDiameterRawValue: String  // WheelSize
    var tireWidthMM: Int
    
    // Optional details
    var tireBrand: String?
    var tireModel: String?
    var tireCasingRawValue: String?  // TireCasingType
    
    // Weight (affects total bike weight)
    var wheelsetWeightKg: Double?
    
    // Visual/organizational
    var notes: String
    var isDefault: Bool  // Primary wheelset for this bike
    
    // Relationship
    var bikeConfiguration: BikeConfiguration?
    
    var createdAt: Date
    var lastUsed: Date
    
    init(
        name: String,
        wheelDiameter: WheelSize,
        tireWidthMM: Int,
        tireBrand: String? = nil,
        tireModel: String? = nil,
        tireCasing: TirePressureCalculationService.TireCasingType? = nil,
        wheelsetWeightKg: Double? = nil,
        notes: String = "",
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.wheelDiameterRawValue = wheelDiameter.rawValue
        self.tireWidthMM = tireWidthMM
        self.tireBrand = tireBrand
        self.tireModel = tireModel
        self.tireCasingRawValue = tireCasing?.rawValue
        self.wheelsetWeightKg = wheelsetWeightKg
        self.notes = notes
        self.isDefault = isDefault
        self.createdAt = Date()
        self.lastUsed = Date()
    }
    
    var wheelDiameter: WheelSize {
        get {
            WheelSize(rawValue: wheelDiameterRawValue) ?? .road700c
        }
        set {
            wheelDiameterRawValue = newValue.rawValue
        }
    }
    
    var tireCasing: TirePressureCalculationService.TireCasingType? {
        get {
            guard let raw = tireCasingRawValue else { return nil }
            return TirePressureCalculationService.TireCasingType(rawValue: raw)
        }
        set {
            tireCasingRawValue = newValue?.rawValue
        }
    }
    
    var displayName: String {
        if let brand = tireBrand, let model = tireModel {
            return "\(name) - \(brand) \(model) \(tireWidthMM)mm"
        }
        return "\(name) - \(wheelDiameter.rawValue) × \(tireWidthMM)mm"
    }
    
    var tireDescription: String {
        if let brand = tireBrand, let model = tireModel {
            return "\(brand) \(model) \(tireWidthMM)mm"
        }
        return "\(wheelDiameter.rawValue) × \(tireWidthMM)mm"
    }
}

// Update BikeConfiguration to support wheelsets
extension BikeConfiguration {
    // Remove old single tire fields, use wheelsets instead
    // Keep for backwards compatibility during migration
    
    var defaultWheelset: Wheelset? {
        // This will be a relationship query once we add @Relationship
        // For now, need to query from context
        return nil
    }
    
    var effectiveTireWidth: Int {
        // Use default wheelset if available, otherwise fall back to tireWidthMM
        return defaultWheelset?.tireWidthMM ?? Int(tireWidthMM)
    }
    
    var effectiveWheelDiameter: WheelSize {
        return defaultWheelset?.wheelDiameter ?? wheelDiameter ?? .road700c
    }
    
    var effectiveBikeWeight: Double {
        let baseWeight = bikeWeightKg ?? 10.0
        if let wheelsetWeight = defaultWheelset?.wheelsetWeightKg {
            // Already includes wheels in base weight, so this is for different wheelsets
            return baseWeight
        }
        return baseWeight
    }
}
