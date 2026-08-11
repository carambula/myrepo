//
//  VendorModels.swift
//  SpinMin
//
//  Models for cycling component vendors and ordering
//

import Foundation
import SwiftData

// MARK: - Vendor

enum Vendor: String, CaseIterable, Codable {
    case competitiveCyclist = "competitive_cyclist"
    case jensonUSA = "jenson_usa"
    case backcountry = "backcountry"
    case rei = "rei"
    case silca = "silca"
    case chainReactionCycles = "chain_reaction"
    case modernBike = "modern_bike"
    
    var displayName: String {
        switch self {
        case .competitiveCyclist: return "Competitive Cyclist"
        case .jensonUSA: return "Jenson USA"
        case .backcountry: return "Backcountry"
        case .rei: return "REI"
        case .silca: return "Silca"
        case .chainReactionCycles: return "Chain Reaction Cycles"
        case .modernBike: return "Modern Bike"
        }
    }
    
    var baseURL: String {
        switch self {
        case .competitiveCyclist: return "https://www.competitivecyclist.com"
        case .jensonUSA: return "https://www.jensonusa.com"
        case .backcountry: return "https://www.backcountry.com"
        case .rei: return "https://www.rei.com"
        case .silca: return "https://silca.cc"
        case .chainReactionCycles: return "https://www.chainreactioncycles.com"
        case .modernBike: return "https://www.modernbike.com"
        }
    }
    
    var searchPath: String {
        switch self {
        case .competitiveCyclist: return "/store/search"
        case .jensonUSA: return "/search"
        case .backcountry: return "/search"
        case .rei: return "/search"
        case .silca: return "/search"
        case .chainReactionCycles: return "/us/en/search"
        case .modernBike: return "/search"
        }
    }
    
    var searchQueryParam: String {
        switch self {
        case .competitiveCyclist: return "q"
        case .jensonUSA: return "q"
        case .backcountry: return "q"
        case .rei: return "q"
        case .silca: return "q"
        case .chainReactionCycles: return "q"
        case .modernBike: return "q"
        }
    }
    
    var iconName: String {
        switch self {
        case .competitiveCyclist: return "bicycle.circle.fill"
        case .jensonUSA: return "bicycle.circle"
        case .backcountry: return "mountain.2.fill"
        case .rei: return "figure.outdoor.cycle"
        case .silca: return "wrench.and.screwdriver.fill"
        case .chainReactionCycles: return "link.circle.fill"
        case .modernBike: return "bicycle"
        }
    }
    
    var specialties: [ComponentCategory] {
        switch self {
        case .competitiveCyclist: return [.tires, .chains, .cassettes, .wheels, .tools]
        case .jensonUSA: return [.tires, .chains, .cassettes, .wheels, .tools]
        case .backcountry: return [.tires, .chains, .complete]
        case .rei: return [.tires, .chains, .complete, .tools]
        case .silca: return [.tools, .lubricants, .pumps]
        case .chainReactionCycles: return [.tires, .chains, .cassettes, .wheels]
        case .modernBike: return [.tires, .chains, .cassettes, .wheels, .tools]
        }
    }
    
    var description: String {
        switch self {
        case .competitiveCyclist:
            return "Premium cycling gear with expert staff and fast shipping"
        case .jensonUSA:
            return "Wide selection of cycling components at competitive prices"
        case .backcountry:
            return "Outdoor and cycling gear with great customer service"
        case .rei:
            return "Co-op with bike components, gear, and expert advice"
        case .silca:
            return "Premium pumps, tools, and chain wax directly from manufacturer"
        case .chainReactionCycles:
            return "Global cycling retailer with competitive international shipping"
        case .modernBike:
            return "Comprehensive bike parts with technical expertise"
        }
    }
}

// MARK: - Component Category

enum ComponentCategory: String, CaseIterable, Codable {
    case tires
    case chains
    case cassettes
    case chainrings
    case brakePads = "brake_pads"
    case cables
    case wheels
    case tools
    case lubricants
    case pumps
    case complete
    
    var displayName: String {
        switch self {
        case .tires: return "Tires"
        case .chains: return "Chains"
        case .cassettes: return "Cassettes"
        case .chainrings: return "Chainrings"
        case .brakePads: return "Brake Pads"
        case .cables: return "Cables"
        case .wheels: return "Wheels"
        case .tools: return "Tools"
        case .lubricants: return "Lubricants"
        case .pumps: return "Pumps"
        case .complete: return "Complete Bikes"
        }
    }
    
    var searchKeywords: [String] {
        switch self {
        case .tires: return ["tire", "tyre"]
        case .chains: return ["chain"]
        case .cassettes: return ["cassette"]
        case .chainrings: return ["chainring", "chain ring"]
        case .brakePads: return ["brake pad", "brake pads"]
        case .cables: return ["cable", "housing"]
        case .wheels: return ["wheelset", "wheel"]
        case .tools: return ["tool", "multitool"]
        case .lubricants: return ["lube", "lubricant", "wax", "chain wax"]
        case .pumps: return ["pump", "inflator"]
        case .complete: return ["bike", "bicycle", "complete"]
        }
    }
}

// MARK: - Vendor Preference

@Model
final class VendorPreference {
    var id: UUID
    var preferredVendors: [String]  // Vendor rawValues in order of preference
    var lastUpdated: Date
    
    init(preferredVendors: [Vendor] = [.competitiveCyclist, .jensonUSA, .silca]) {
        self.id = UUID()
        self.preferredVendors = preferredVendors.map { $0.rawValue }
        self.lastUpdated = Date()
    }
    
    var vendors: [Vendor] {
        get {
            preferredVendors.compactMap { Vendor(rawValue: $0) }
        }
        set {
            preferredVendors = newValue.map { $0.rawValue }
            lastUpdated = Date()
        }
    }
    
    func primaryVendor() -> Vendor {
        vendors.first ?? .competitiveCyclist
    }
}

// MARK: - Order Link

struct OrderLink: Identifiable {
    let id = UUID()
    let vendor: Vendor
    let url: URL
    let displayText: String
    let category: ComponentCategory
}
