//
//  GearModels.swift
//  SpinMin
//
//  Models for rider gear tracking (helmets, shoes, tools, accessories)
//

import Foundation
import SwiftData

// MARK: - Gear Type

enum GearType: String, CaseIterable, Codable {
    case helmet
    case shoes
    case cleats
    case pedals
    case computerGPS = "computer_gps"
    case lights
    case multiTool = "multi_tool"
    case pumpCO2 = "pump_co2"
    case spareKit = "spare_kit"
    case bottles
    case nutrition
    case jersey
    case bibs
    case jacket
    case gloves
    case sunglasses
    case saddleBag = "saddle_bag"
    
    var displayName: String {
        switch self {
        case .helmet: return "Helmet"
        case .shoes: return "Cycling Shoes"
        case .cleats: return "Cleats"
        case .pedals: return "Pedals"
        case .computerGPS: return "Computer/GPS"
        case .lights: return "Lights"
        case .multiTool: return "Multi-Tool"
        case .pumpCO2: return "Pump/CO2"
        case .spareKit: return "Spare Kit"
        case .bottles: return "Water Bottles"
        case .nutrition: return "Nutrition"
        case .jersey: return "Jersey"
        case .bibs: return "Bibs/Shorts"
        case .jacket: return "Jacket"
        case .gloves: return "Gloves"
        case .sunglasses: return "Sunglasses"
        case .saddleBag: return "Saddle Bag"
        }
    }
    
    var icon: String {
        switch self {
        case .helmet: return "figure.cooldown"
        case .shoes: return "shoe.fill"
        case .cleats: return "arrow.triangle.2.circlepath"
        case .pedals: return "gear.circle"
        case .computerGPS: return "location.circle.fill"
        case .lights: return "flashlight.on.fill"
        case .multiTool: return "wrench.and.screwdriver.fill"
        case .pumpCO2: return "wind"
        case .spareKit: return "bandage.fill"
        case .bottles: return "waterbottle.fill"
        case .nutrition: return "carrot.fill"
        case .jersey: return "tshirt.fill"
        case .bibs: return "figure.walk"
        case .jacket: return "jacket.fill"
        case .gloves: return "hand.raised.fill"
        case .sunglasses: return "sun.max.fill"
        case .saddleBag: return "bag.fill"
        }
    }
    
    var category: GearCategory {
        switch self {
        case .helmet, .shoes, .cleats, .pedals:
            return .safety
        case .computerGPS, .lights:
            return .electronics
        case .multiTool, .pumpCO2, .spareKit, .saddleBag:
            return .tools
        case .bottles, .nutrition:
            return .consumables
        case .jersey, .bibs, .jacket, .gloves, .sunglasses:
            return .clothing
        }
    }
    
    var isConsumable: Bool {
        switch self {
        case .nutrition, .bottles:
            return true
        default:
            return false
        }
    }
    
    var expectedLifespanDays: Int? {
        switch self {
        case .helmet: return 1825  // 5 years (safety standard)
        case .shoes: return 730    // 2 years (~1000 hours)
        case .cleats: return 365   // 1 year
        case .pedals: return 1825  // 5 years
        case .computerGPS: return 1095  // 3 years (battery life)
        case .lights: return 730   // 2 years (battery/LED life)
        case .multiTool: return nil  // Indefinite with care
        case .pumpCO2: return nil
        case .spareKit: return 730  // 2 years (tubes/patches degrade)
        case .bottles: return 365  // 1 year (wear/bacteria)
        case .nutrition: return 30  // 1 month (consumable)
        case .jersey, .bibs: return 730  // 2 years (~200 washes)
        case .jacket: return 1095  // 3 years
        case .gloves: return 365   // 1 year
        case .sunglasses: return 730  // 2 years (scratches/coating)
        case .saddleBag: return nil
        }
    }
}

enum GearCategory: String, CaseIterable, Codable {
    case safety
    case electronics
    case tools
    case consumables
    case clothing
    
    var displayName: String {
        switch self {
        case .safety: return "Safety"
        case .electronics: return "Electronics"
        case .tools: return "Tools"
        case .consumables: return "Consumables"
        case .clothing: return "Clothing"
        }
    }
}

// MARK: - Gear Item

@Model
final class GearItem {
    var id: UUID
    var gearTypeRawValue: String
    var brand: String?
    var model: String?
    var purchaseDate: Date
    var purchasePrice: Double?
    var notes: String
    
    // Wear tracking
    var usageCount: Int  // Number of rides/uses
    var totalHours: Double  // Estimated hours of use
    var retirementDate: Date?
    var retirementReason: String?
    
    // Safety critical items
    var isSafetyCritical: Bool
    var lastInspectionDate: Date?
    var crashDate: Date?  // For helmets
    
    // Checklist integration
    var isRequiredForRides: Bool
    var isRequiredForRaces: Bool
    
    init(
        gearType: GearType,
        brand: String? = nil,
        model: String? = nil,
        purchaseDate: Date = Date(),
        purchasePrice: Double? = nil,
        notes: String = "",
        isSafetyCritical: Bool = false,
        isRequiredForRides: Bool = false,
        isRequiredForRaces: Bool = false
    ) {
        self.id = UUID()
        self.gearTypeRawValue = gearType.rawValue
        self.brand = brand
        self.model = model
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.notes = notes
        self.usageCount = 0
        self.totalHours = 0
        self.isSafetyCritical = isSafetyCritical
        self.isRequiredForRides = isRequiredForRides
        self.isRequiredForRaces = isRequiredForRaces
        
        // Auto-set safety critical for certain gear
        if gearType == .helmet {
            self.isSafetyCritical = true
        }
    }
    
    var gearType: GearType {
        GearType(rawValue: gearTypeRawValue) ?? .helmet
    }
    
    var displayName: String {
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        } else if let brand = brand {
            return "\(brand) \(gearType.displayName)"
        } else {
            return gearType.displayName
        }
    }
    
    var ageDays: Int {
        Calendar.current.dateComponents([.day], from: purchaseDate, to: Date()).day ?? 0
    }
    
    var ageMonths: Int {
        Calendar.current.dateComponents([.month], from: purchaseDate, to: Date()).month ?? 0
    }
    
    var isRetired: Bool {
        retirementDate != nil
    }
    
    var isActive: Bool {
        !isRetired
    }
    
    // Record usage
    func recordUse(hours: Double = 2.0) {
        usageCount += 1
        totalHours += hours
    }
    
    // Retire gear
    func retire(reason: String) {
        retirementDate = Date()
        retirementReason = reason
    }
    
    // Inspect gear (for safety items)
    func markInspected() {
        lastInspectionDate = Date()
    }
    
    // Helmet crash
    func recordCrash() {
        crashDate = Date()
        retire(reason: "Helmet crash - immediate replacement required")
    }
}

// MARK: - Ride Checklist

@Model
final class RideChecklist {
    var id: UUID
    var name: String
    var checklistTypeRawValue: String
    var createdDate: Date
    var lastUsedDate: Date?
    
    @Relationship(deleteRule: .cascade) var items: [ChecklistItem] = []
    
    init(
        name: String,
        type: ChecklistType,
        items: [ChecklistItem] = []
    ) {
        self.id = UUID()
        self.name = name
        self.checklistTypeRawValue = type.rawValue
        self.createdDate = Date()
        self.items = items
    }
    
    var checklistType: ChecklistType {
        ChecklistType(rawValue: checklistTypeRawValue) ?? .training
    }
    
    var completionPercentage: Double {
        guard !items.isEmpty else { return 0 }
        let completed = items.filter { $0.isChecked }.count
        return Double(completed) / Double(items.count) * 100
    }
    
    var isComplete: Bool {
        !items.isEmpty && items.allSatisfy { $0.isChecked }
    }
    
    func resetChecklist() {
        items.forEach { $0.isChecked = false }
    }
    
    func useChecklist() {
        lastUsedDate = Date()
    }
}

@Model
final class ChecklistItem {
    var id: UUID
    var title: String
    var category: String
    var isChecked: Bool
    var sortOrder: Int
    var notes: String
    
    // Optional gear reference
    var linkedGearId: UUID?
    
    init(
        title: String,
        category: String = "",
        sortOrder: Int = 0,
        linkedGearId: UUID? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.isChecked = false
        self.sortOrder = sortOrder
        self.linkedGearId = linkedGearId
        self.notes = notes
    }
}

enum ChecklistType: String, CaseIterable, Codable {
    case training
    case race
    case longRide = "long_ride"
    case bikePacking = "bike_packing"
    case gravel
    case maintenance
    
    var displayName: String {
        switch self {
        case .training: return "Training Ride"
        case .race: return "Race Day"
        case .longRide: return "Long Ride"
        case .bikePacking: return "Bike Packing"
        case .gravel: return "Gravel Adventure"
        case .maintenance: return "Pre-Maintenance"
        }
    }
    
    var icon: String {
        switch self {
        case .training: return "figure.outdoor.cycle"
        case .race: return "flag.checkered"
        case .longRide: return "arrow.forward.circle.fill"
        case .bikePacking: return "backpack.fill"
        case .gravel: return "mountain.2.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Checklist Templates

struct ChecklistTemplate {
    let type: ChecklistType
    let name: String
    let categories: [String]
    let items: [(title: String, category: String, gearType: GearType?)]
    
    static let templates: [ChecklistTemplate] = [
        // Training Ride
        ChecklistTemplate(
            type: .training,
            name: "Training Ride",
            categories: ["Safety", "Bike", "Tools", "Hydration"],
            items: [
                ("Helmet", "Safety", .helmet),
                ("Cycling shoes", "Safety", .shoes),
                ("Sunglasses", "Safety", .sunglasses),
                ("Front & rear lights", "Safety", .lights),
                ("Bike computer/GPS", "Bike", .computerGPS),
                ("Tire pressure checked", "Bike", nil),
                ("Chain lubed", "Bike", nil),
                ("Multi-tool", "Tools", .multiTool),
                ("Spare tube", "Tools", .spareKit),
                ("CO2 or mini pump", "Tools", .pumpCO2),
                ("Water bottles filled", "Hydration", .bottles),
            ]
        ),
        
        // Race Day
        ChecklistTemplate(
            type: .race,
            name: "Race Day",
            categories: ["Pre-Race", "Gear", "Bike", "Nutrition", "Post-Race"],
            items: [
                ("Registration confirmed", "Pre-Race", nil),
                ("Course map reviewed", "Pre-Race", nil),
                ("Weather checked", "Pre-Race", nil),
                ("Helmet", "Gear", .helmet),
                ("Race shoes & cleats", "Gear", .shoes),
                ("Race kit (jersey/bibs)", "Gear", .jersey),
                ("Sunglasses", "Gear", .sunglasses),
                ("Bike computer/GPS", "Gear", .computerGPS),
                ("Bike cleaned", "Bike", nil),
                ("Tire pressure optimal", "Bike", nil),
                ("Chain waxed/lubed", "Bike", nil),
                ("Shifting checked", "Bike", nil),
                ("Brakes checked", "Bike", nil),
                ("Wheels secured", "Bike", nil),
                ("Pre-race meal eaten", "Nutrition", nil),
                ("Water bottles filled", "Nutrition", .bottles),
                ("Race nutrition packed", "Nutrition", .nutrition),
                ("Spare tube in pocket", "Post-Race", .spareKit),
                ("Multi-tool", "Post-Race", .multiTool),
                ("CO2 cartridges", "Post-Race", .pumpCO2),
            ]
        ),
        
        // Long Ride
        ChecklistTemplate(
            type: .longRide,
            name: "Long Ride (3+ hours)",
            categories: ["Safety", "Bike", "Tools", "Nutrition", "Clothing"],
            items: [
                ("Helmet", "Safety", .helmet),
                ("Cycling shoes", "Safety", .shoes),
                ("Front & rear lights", "Safety", .lights),
                ("Bike computer with route", "Bike", .computerGPS),
                ("Tire pressure checked", "Bike", nil),
                ("Chain condition good", "Bike", nil),
                ("Multi-tool", "Tools", .multiTool),
                ("2x spare tubes", "Tools", .spareKit),
                ("Tire levers", "Tools", nil),
                ("CO2 or pump", "Tools", .pumpCO2),
                ("2-3 water bottles", "Nutrition", .bottles),
                ("Energy bars/gels", "Nutrition", .nutrition),
                ("Cash/card for cafe stop", "Nutrition", nil),
                ("Arm warmers", "Clothing", nil),
                ("Gilet/jacket", "Clothing", .jacket),
                ("Gloves", "Clothing", .gloves),
            ]
        ),
    ]
}
