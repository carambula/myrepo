//
//  MaintenanceRecord.swift
//  SpinMin
//
//  Track all bike maintenance activities
//

import Foundation
import SwiftData

@Model
final class MaintenanceRecord {
    var id: UUID
    var maintenanceType: String  // MaintenanceType
    var maintenanceDate: Date
    var bikeOdometerKm: Double  // Bike's odometer at time of maintenance
    
    // Component identification
    var componentBrand: String?
    var componentModel: String?
    var componentType: String?  // ComponentType (for part replacements)
    
    // Maintenance details
    var notes: String
    var cost: Double?
    var performedBy: String?  // "Self" or mechanic/shop name
    
    // For tracking component lifespan (when replacing parts)
    var isReplacement: Bool
    var replacedAtOdometerKm: Double?  // When component was installed
    var componentLifespanKm: Double?  // How long component lasted
    
    // Relationship
    @Relationship var bikeConfiguration: BikeConfiguration?
    
    init(
        maintenanceType: MaintenanceType,
        date: Date = Date(),
        bikeOdometerKm: Double,
        componentBrand: String? = nil,
        componentModel: String? = nil,
        componentType: ComponentType? = nil,
        notes: String = "",
        cost: Double? = nil,
        performedBy: String? = nil,
        isReplacement: Bool = false,
        replacedAtOdometerKm: Double? = nil
    ) {
        self.id = UUID()
        self.maintenanceType = maintenanceType.rawValue
        self.maintenanceDate = date
        self.bikeOdometerKm = bikeOdometerKm
        self.componentBrand = componentBrand
        self.componentModel = componentModel
        self.componentType = componentType?.rawValue
        self.notes = notes
        self.cost = cost
        self.performedBy = performedBy
        self.isReplacement = isReplacement
        self.replacedAtOdometerKm = replacedAtOdometerKm
        
        if let replaced = replacedAtOdometerKm {
            self.componentLifespanKm = max(0, bikeOdometerKm - replaced)
        } else {
            self.componentLifespanKm = nil
        }
    }
    
    // MARK: - Computed Properties
    
    var type: MaintenanceType {
        get { MaintenanceType(rawValue: maintenanceType) ?? .general }
        set { maintenanceType = newValue.rawValue }
    }
    
    var component: ComponentType? {
        get {
            guard let raw = componentType else { return nil }
            return ComponentType(rawValue: raw)
        }
        set {
            componentType = newValue?.rawValue
        }
    }
    
    var displayName: String {
        if isReplacement, let comp = component {
            return "New \(comp.displayName)"
        }
        return type.displayName
    }
    
    var summary: String {
        let date = maintenanceDate.formatted(date: .abbreviated, time: .omitted)
        let km = String(format: "%.0f km", bikeOdometerKm)
        
        if let lifespan = componentLifespanKm, isReplacement {
            let lifespanStr = String(format: "%.0f km", lifespan)
            return "\(displayName) at \(km) · \(date) · lasted \(lifespanStr)"
        }
        
        return "\(displayName) at \(km) · \(date)"
    }
}

// MARK: - Maintenance Types

enum MaintenanceType: String, Codable, CaseIterable {
    // Chain maintenance
    case chainWax = "chain_wax"
    case chainClean = "chain_clean"
    case chainLube = "chain_lube"
    case chainReplace = "chain_replace"
    
    // Drivetrain
    case cassetteReplace = "cassette_replace"
    case chainringReplace = "chainring_replace"
    case derailleurService = "derailleur_service"
    case shiftCableReplace = "shift_cable_replace"
    
    // Brakes
    case brakePadReplace = "brake_pad_replace"
    case brakeCableReplace = "brake_cable_replace"
    case brakeBleed = "brake_bleed"
    case rotorReplace = "rotor_replace"
    
    // Bearings & headset
    case bottomBracketReplace = "bottom_bracket_replace"
    case headsetService = "headset_service"
    case wheelBearingService = "wheel_bearing_service"
    
    // Wheels
    case wheelTrue = "wheel_true"
    case spokeReplace = "spoke_replace"
    
    // General
    case fullService = "full_service"
    case wash = "wash"
    case general = "general"
    
    var displayName: String {
        switch self {
        // Chain
        case .chainWax: return "Chain Wax"
        case .chainClean: return "Chain Clean"
        case .chainLube: return "Chain Lube"
        case .chainReplace: return "Chain Replacement"
            
        // Drivetrain
        case .cassetteReplace: return "Cassette Replacement"
        case .chainringReplace: return "Chainring Replacement"
        case .derailleurService: return "Derailleur Service"
        case .shiftCableReplace: return "Shift Cable Replacement"
            
        // Brakes
        case .brakePadReplace: return "Brake Pad Replacement"
        case .brakeCableReplace: return "Brake Cable Replacement"
        case .brakeBleed: return "Brake Bleed"
        case .rotorReplace: return "Rotor Replacement"
            
        // Bearings & headset
        case .bottomBracketReplace: return "Bottom Bracket Replacement"
        case .headsetService: return "Headset Service"
        case .wheelBearingService: return "Wheel Bearing Service"
            
        // Wheels
        case .wheelTrue: return "Wheel Truing"
        case .spokeReplace: return "Spoke Replacement"
            
        // General
        case .fullService: return "Full Service"
        case .wash: return "Bike Wash"
        case .general: return "General Maintenance"
        }
    }
    
    var icon: String {
        switch self {
        // Chain
        case .chainWax, .chainClean, .chainLube: return "link"
        case .chainReplace: return "link.badge.plus"
            
        // Drivetrain
        case .cassetteReplace, .chainringReplace: return "gearshape"
        case .derailleurService: return "gearshape.2"
        case .shiftCableReplace: return "cable.connector"
            
        // Brakes
        case .brakePadReplace, .brakeCableReplace, .brakeBleed: return "brake.signal"
        case .rotorReplace: return "record.circle"
            
        // Bearings & headset
        case .bottomBracketReplace, .headsetService, .wheelBearingService: return "circle.circle"
            
        // Wheels
        case .wheelTrue, .spokeReplace: return "circle.dotted"
            
        // General
        case .fullService: return "wrench.and.screwdriver"
        case .wash: return "drop"
        case .general: return "wrench"
        }
    }
    
    var category: MaintenanceCategory {
        switch self {
        case .chainWax, .chainClean, .chainLube, .chainReplace:
            return .chain
        case .cassetteReplace, .chainringReplace, .derailleurService, .shiftCableReplace:
            return .drivetrain
        case .brakePadReplace, .brakeCableReplace, .brakeBleed, .rotorReplace:
            return .brakes
        case .bottomBracketReplace, .headsetService, .wheelBearingService:
            return .bearings
        case .wheelTrue, .spokeReplace:
            return .wheels
        case .fullService, .wash, .general:
            return .general
        }
    }
    
    /// Recommended interval in kilometers (nil for as-needed)
    var recommendedIntervalKm: Double? {
        switch self {
        case .chainWax: return 400  // Hot wax: 300-600 km, using middle
        case .chainClean: return 350
        case .chainLube: return 300
        case .chainReplace: return 3500  // 2,000-5,000 km typical
        case .cassetteReplace: return 15000  // With proper chain replacement
        case .chainringReplace: return 20000
        case .brakePadReplace: return 3000  // Varies greatly
        case .brakeBleed: return 10000  // Hydraulic
        case .bottomBracketReplace: return 15000
        case .wheelBearingService: return 10000
        case .wash: return 500
        default: return nil  // As-needed maintenance
        }
    }
}

enum MaintenanceCategory: String, CaseIterable {
    case chain = "chain"
    case drivetrain = "drivetrain"
    case brakes = "brakes"
    case bearings = "bearings"
    case wheels = "wheels"
    case general = "general"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .chain: return "link"
        case .drivetrain: return "gearshape.2"
        case .brakes: return "brake.signal"
        case .bearings: return "circle.circle"
        case .wheels: return "circle.dotted"
        case .general: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Component Types

enum ComponentType: String, Codable, CaseIterable {
    // Chain types
    case chain = "chain"
    
    // Drivetrain
    case cassette = "cassette"
    case chainring = "chainring"
    case derailleur = "derailleur"
    case shiftCable = "shift_cable"
    
    // Brakes
    case brakePads = "brake_pads"
    case brakeCable = "brake_cable"
    case brakeRotor = "brake_rotor"
    
    // Bearings
    case bottomBracket = "bottom_bracket"
    case headset = "headset"
    case wheelBearing = "wheel_bearing"
    
    // Other
    case handlebarTape = "handlebar_tape"
    case cables = "cables"
    case housing = "housing"
    
    var displayName: String {
        switch self {
        case .chain: return "Chain"
        case .cassette: return "Cassette"
        case .chainring: return "Chainring"
        case .derailleur: return "Derailleur"
        case .shiftCable: return "Shift Cable"
        case .brakePads: return "Brake Pads"
        case .brakeCable: return "Brake Cable"
        case .brakeRotor: return "Brake Rotor"
        case .bottomBracket: return "Bottom Bracket"
        case .headset: return "Headset"
        case .wheelBearing: return "Wheel Bearing"
        case .handlebarTape: return "Handlebar Tape"
        case .cables: return "Cables"
        case .housing: return "Housing"
        }
    }
    
    /// Expected lifespan in kilometers
    var expectedLifespanKm: Double {
        switch self {
        case .chain: return 3500  // 2,000-5,000 km with proper maintenance
        case .cassette: return 15000  // With regular chain replacement
        case .chainring: return 20000
        case .derailleur: return 50000  // Long-lasting with service
        case .shiftCable: return 10000
        case .brakePads: return 3000  // 800-5,600 km depending on conditions
        case .brakeCable: return 10000
        case .brakeRotor: return 15000
        case .bottomBracket: return 15000
        case .headset: return 30000
        case .wheelBearing: return 10000
        case .handlebarTape: return 8000
        case .cables: return 10000
        case .housing: return 20000
        }
    }
}
