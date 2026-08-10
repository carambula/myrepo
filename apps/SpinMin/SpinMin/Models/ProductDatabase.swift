//
//  ProductDatabase.swift
//  SpinMin
//
//  Product catalog for autocomplete and structured selection
//

import Foundation
import SwiftData

// MARK: - Base Product Protocol

protocol Product {
    var id: UUID { get }
    var brand: String { get }
    var model: String { get }
    var year: Int? { get }
    var productCategory: ProductCategory { get }
    var displayName: String { get }
    var searchableText: String { get }
}

enum ProductCategory: String, Codable, CaseIterable {
    case bike = "bike"
    case tire = "tire"
    case wheelset = "wheelset"
    case chain = "chain"
    case cassette = "cassette"
    case chainring = "chainring"
    case brakePad = "brake_pad"
    case groupset = "groupset"
    case frame = "frame"
    
    var displayName: String {
        switch self {
        case .bike: return "Complete Bike"
        case .tire: return "Tire"
        case .wheelset: return "Wheelset"
        case .chain: return "Chain"
        case .cassette: return "Cassette"
        case .chainring: return "Chainring"
        case .brakePad: return "Brake Pad"
        case .groupset: return "Groupset"
        case .frame: return "Frame"
        }
    }
}

// MARK: - Tire Product

@Model
final class TireProduct {
    var id: UUID
    var brand: String
    var model: String
    var year: Int?
    
    // Tire-specific specs
    var wheelSizeRawValue: String  // "700c", "650b", "29", "27.5", "26"
    var widthMM: Int
    var tireTypeRawValue: String  // "clincher", "tubeless", "tubular"
    var compoundTypeRawValue: String  // TireCompoundType
    var casingRawValue: String?  // TireCasingType
    
    // Additional details
    var weight: Int?  // grams
    var treadPattern: String?
    var maxPSI: Int?
    var description: String
    var isPopular: Bool
    
    init(
        brand: String,
        model: String,
        wheelSize: String,
        widthMM: Int,
        tireType: String,
        compoundType: TireCompoundType = .training,
        year: Int? = nil,
        casing: TirePressureCalculationService.TireCasingType? = nil,
        weight: Int? = nil,
        maxPSI: Int? = nil,
        description: String = "",
        isPopular: Bool = false
    ) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.year = year
        self.wheelSizeRawValue = wheelSize
        self.widthMM = widthMM
        self.tireTypeRawValue = tireType
        self.compoundTypeRawValue = compoundType.rawValue
        self.casingRawValue = casing?.rawValue
        self.weight = weight
        self.maxPSI = maxPSI
        self.description = description
        self.isPopular = isPopular
    }
    
    var displayName: String {
        "\(brand) \(model) \(widthMM)mm"
    }
    
    var fullDisplayName: String {
        var parts = [brand, model]
        if let year = year {
            parts.append("(\(year))")
        }
        parts.append("\(wheelSizeRawValue) × \(widthMM)mm")
        return parts.joined(separator: " ")
    }
    
    var searchableText: String {
        "\(brand) \(model) \(widthMM) \(wheelSizeRawValue) \(tireTypeRawValue)".lowercased()
    }
    
    var compoundType: TireCompoundType {
        TireCompoundType(rawValue: compoundTypeRawValue) ?? .training
    }
}

// MARK: - Chain Product

@Model
final class ChainProduct {
    var id: UUID
    var brand: String
    var model: String
    var year: Int?
    
    // Chain-specific specs
    var speedCount: Int  // 11, 12, etc.
    var compatibleBrands: [String]  // ["Shimano", "SRAM", "Campagnolo"]
    var linksCount: Int?  // 116, 126, etc.
    
    // Details
    var weight: Int?  // grams
    var coating: String?  // "nickel", "chrome", "gold"
    var description: String
    var isPopular: Bool
    
    init(
        brand: String,
        model: String,
        speedCount: Int,
        year: Int? = nil,
        compatibleBrands: [String] = [],
        linksCount: Int? = nil,
        weight: Int? = nil,
        coating: String? = nil,
        description: String = "",
        isPopular: Bool = false
    ) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.year = year
        self.speedCount = speedCount
        self.compatibleBrands = compatibleBrands
        self.linksCount = linksCount
        self.weight = weight
        self.coating = coating
        self.description = description
        self.isPopular = isPopular
    }
    
    var displayName: String {
        "\(brand) \(model) \(speedCount)-speed"
    }
    
    var fullDisplayName: String {
        var parts = [brand, model]
        if let year = year {
            parts.append("(\(year))")
        }
        parts.append("\(speedCount)-speed")
        if !compatibleBrands.isEmpty {
            parts.append("(\(compatibleBrands.joined(separator: "/")))")
        }
        return parts.joined(separator: " ")
    }
    
    var searchableText: String {
        "\(brand) \(model) \(speedCount) \(compatibleBrands.joined(separator: " "))".lowercased()
    }
}

// MARK: - Wheelset Product

@Model
final class WheelsetProduct {
    var id: UUID
    var brand: String
    var model: String
    var year: Int?
    
    // Wheelset specs
    var wheelSizeRawValue: String  // "700c", "650b", "29", etc.
    var rimDepthMM: Int?  // 30, 50, 60, 80, etc.
    var rimWidthMM: Int?  // Internal width
    var isDiscBrake: Bool
    var freehubTypeRawValue: String?  // "Shimano HG", "SRAM XDR", "Campag"
    
    // Details
    var weight: Int?  // grams (pair)
    var material: String?  // "carbon", "aluminum", "alloy"
    var description: String
    var isPopular: Bool
    
    init(
        brand: String,
        model: String,
        wheelSize: String,
        year: Int? = nil,
        rimDepthMM: Int? = nil,
        rimWidthMM: Int? = nil,
        isDiscBrake: Bool = true,
        freehubType: String? = nil,
        weight: Int? = nil,
        material: String? = nil,
        description: String = "",
        isPopular: Bool = false
    ) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.year = year
        self.wheelSizeRawValue = wheelSize
        self.rimDepthMM = rimDepthMM
        self.rimWidthMM = rimWidthMM
        self.isDiscBrake = isDiscBrake
        self.freehubTypeRawValue = freehubType
        self.weight = weight
        self.material = material
        self.description = description
        self.isPopular = isPopular
    }
    
    var displayName: String {
        "\(brand) \(model)"
    }
    
    var fullDisplayName: String {
        var parts = [brand, model]
        if let year = year {
            parts.append("(\(year))")
        }
        parts.append(wheelSizeRawValue)
        if let depth = rimDepthMM {
            parts.append("\(depth)mm")
        }
        return parts.joined(separator: " ")
    }
    
    var searchableText: String {
        "\(brand) \(model) \(wheelSizeRawValue) \(material ?? "")".lowercased()
    }
}

// MARK: - Component Product (Generic)

@Model
final class ComponentProduct {
    var id: UUID
    var brand: String
    var model: String
    var year: Int?
    var componentTypeRawValue: String  // ComponentType
    
    // Generic specs (key-value pairs for flexibility)
    var specifications: [String: String]  // e.g., ["speed": "12", "teeth": "10-52"]
    
    var weight: Int?  // grams
    var description: String
    var isPopular: Bool
    
    init(
        brand: String,
        model: String,
        componentType: ComponentType,
        year: Int? = nil,
        specifications: [String: String] = [:],
        weight: Int? = nil,
        description: String = "",
        isPopular: Bool = false
    ) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.year = year
        self.componentTypeRawValue = componentType.rawValue
        self.specifications = specifications
        self.weight = weight
        self.description = description
        self.isPopular = isPopular
    }
    
    var componentType: ComponentType {
        ComponentType(rawValue: componentTypeRawValue) ?? .chain
    }
    
    var displayName: String {
        "\(brand) \(model)"
    }
    
    var fullDisplayName: String {
        var parts = [brand, model]
        if let year = year {
            parts.append("(\(year))")
        }
        parts.append("(\(componentType.displayName))")
        return parts.joined(separator: " ")
    }
    
    var searchableText: String {
        let specsText = specifications.values.joined(separator: " ")
        return "\(brand) \(model) \(componentType.displayName) \(specsText)".lowercased()
    }
}

// MARK: - Bike Product

@Model
final class BikeProduct {
    var id: UUID
    var brand: String
    var model: String
    var year: Int?
    
    // Bike specs
    var bikeTypeRawValue: String  // BikeType
    var frameSize: String?  // "54cm", "M", "L", etc.
    var frameMaterial: String?  // "carbon", "aluminum", "steel", "titanium"
    var groupsetBrand: String?  // "Shimano", "SRAM", "Campagnolo"
    var groupsetModel: String?  // "Ultegra", "Force", "GRX"
    
    // Details
    var weight: Int?  // grams
    var msrp: Double?  // USD
    var description: String
    var isPopular: Bool
    
    init(
        brand: String,
        model: String,
        bikeType: TirePressureCalculationService.BikeType,
        year: Int? = nil,
        frameSize: String? = nil,
        frameMaterial: String? = nil,
        groupsetBrand: String? = nil,
        groupsetModel: String? = nil,
        weight: Int? = nil,
        msrp: Double? = nil,
        description: String = "",
        isPopular: Bool = false
    ) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.year = year
        self.bikeTypeRawValue = bikeType.rawValue
        self.frameSize = frameSize
        self.frameMaterial = frameMaterial
        self.groupsetBrand = groupsetBrand
        self.groupsetModel = groupsetModel
        self.weight = weight
        self.msrp = msrp
        self.description = description
        self.isPopular = isPopular
    }
    
    var bikeType: TirePressureCalculationService.BikeType {
        TirePressureCalculationService.BikeType(rawValue: bikeTypeRawValue) ?? .road
    }
    
    var displayName: String {
        "\(brand) \(model)"
    }
    
    var fullDisplayName: String {
        var parts = [brand, model]
        if let year = year {
            parts.append("(\(year))")
        }
        if let size = frameSize {
            parts.append(size)
        }
        if let groupset = groupsetModel {
            parts.append("-")
            parts.append(groupset)
        }
        return parts.joined(separator: " ")
    }
    
    var searchableText: String {
        "\(brand) \(model) \(bikeTypeRawValue) \(groupsetBrand ?? "") \(groupsetModel ?? "")".lowercased()
    }
}
