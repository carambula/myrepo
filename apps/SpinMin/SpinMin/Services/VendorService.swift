//
//  VendorService.swift
//  SpinMin
//
//  Service for generating vendor links and ordering components
//

import Foundation

struct VendorService {
    
    // MARK: - Generate Order Links
    
    /// Generate order links for a tire
    static func orderLinks(
        for tire: TireTracking,
        vendors: [Vendor] = Vendor.allCases
    ) -> [OrderLink] {
        let searchQuery = buildTireSearchQuery(tire)
        return generateLinks(
            query: searchQuery,
            category: .tires,
            vendors: vendors.filter { $0.specialties.contains(.tires) }
        )
    }
    
    /// Generate order links for a chain
    static func orderLinks(
        for chain: ComponentTracking,
        vendors: [Vendor] = Vendor.allCases
    ) -> [OrderLink] {
        guard chain.componentType == .chain else { return [] }
        
        let searchQuery = buildChainSearchQuery(chain)
        return generateLinks(
            query: searchQuery,
            category: .chains,
            vendors: vendors.filter { $0.specialties.contains(.chains) }
        )
    }
    
    /// Generate order links for any component
    static func orderLinks(
        for component: ComponentTracking,
        vendors: [Vendor] = Vendor.allCases
    ) -> [OrderLink] {
        let category = mapComponentToCategory(component.componentType)
        let searchQuery = buildComponentSearchQuery(component)
        
        return generateLinks(
            query: searchQuery,
            category: category,
            vendors: vendors.filter { $0.specialties.contains(category) }
        )
    }
    
    /// Generate order links for chain wax/lube
    static func orderLinksForChainWax(
        lubeType: ChainLubeType,
        vendors: [Vendor] = Vendor.allCases
    ) -> [OrderLink] {
        let searchQuery = buildLubeSearchQuery(lubeType)
        return generateLinks(
            query: searchQuery,
            category: .lubricants,
            vendors: vendors.filter { $0.specialties.contains(.lubricants) }
        )
    }
    
    /// Generate order links for a generic product search
    static func orderLinks(
        brand: String?,
        model: String?,
        category: ComponentCategory,
        vendors: [Vendor] = Vendor.allCases
    ) -> [OrderLink] {
        let searchQuery = buildGenericSearchQuery(brand: brand, model: model, category: category)
        return generateLinks(
            query: searchQuery,
            category: category,
            vendors: vendors.filter { $0.specialties.contains(category) }
        )
    }
    
    // MARK: - Search Query Builders
    
    private static func buildTireSearchQuery(_ tire: TireTracking) -> String {
        var parts: [String] = []
        
        if let brand = tire.brand {
            parts.append(brand)
        }
        if let model = tire.model {
            parts.append(model)
        }
        
        // Add tire width if no model specified
        if tire.model == nil {
            parts.append("\(tire.widthMM)mm")
        }
        
        // Fallback to generic search
        if parts.isEmpty {
            parts.append("road tire \(tire.widthMM)mm")
        }
        
        return parts.joined(separator: " ")
    }
    
    private static func buildChainSearchQuery(_ chain: ComponentTracking) -> String {
        var parts: [String] = []
        
        if let brand = chain.brand {
            parts.append(brand)
        }
        if let model = chain.model {
            parts.append(model)
        }
        
        parts.append("chain")
        
        return parts.joined(separator: " ")
    }
    
    private static func buildComponentSearchQuery(_ component: ComponentTracking) -> String {
        var parts: [String] = []
        
        if let brand = component.brand {
            parts.append(brand)
        }
        if let model = component.model {
            parts.append(model)
        }
        
        parts.append(component.componentType.displayName)
        
        return parts.joined(separator: " ")
    }
    
    private static func buildLubeSearchQuery(_ lubeType: ChainLubeType) -> String {
        switch lubeType {
        case .hotWax:
            return "Silca Super Secret chain wax"
        case .dripWax:
            return "chain drip wax"
        case .wetLube:
            return "wet chain lube"
        case .dryLube:
            return "dry chain lube"
        case .ceramic:
            return "ceramic chain lube"
        }
    }
    
    private static func buildGenericSearchQuery(
        brand: String?,
        model: String?,
        category: ComponentCategory
    ) -> String {
        var parts: [String] = []
        
        if let brand = brand {
            parts.append(brand)
        }
        if let model = model {
            parts.append(model)
        }
        
        if parts.isEmpty {
            parts.append(category.displayName)
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Link Generation
    
    private static func generateLinks(
        query: String,
        category: ComponentCategory,
        vendors: [Vendor]
    ) -> [OrderLink] {
        vendors.compactMap { vendor in
            guard let url = buildSearchURL(vendor: vendor, query: query) else {
                return nil
            }
            
            let displayText = "Search on \(vendor.displayName)"
            
            return OrderLink(
                vendor: vendor,
                url: url,
                displayText: displayText,
                category: category
            )
        }
    }
    
    private static func buildSearchURL(vendor: Vendor, query: String) -> URL? {
        var components = URLComponents(string: vendor.baseURL + vendor.searchPath)
        components?.queryItems = [
            URLQueryItem(name: vendor.searchQueryParam, value: query)
        ]
        return components?.url
    }
    
    // MARK: - Direct Product Links (for known SKUs)
    
    /// Generate direct product link for Silca chain wax
    static func silcaChainWaxLink() -> OrderLink {
        let url = URL(string: "https://silca.cc/collections/chain-lube-wax/products/super-secret-chain-lube")!
        return OrderLink(
            vendor: .silca,
            url: url,
            displayText: "Silca Super Secret Wax",
            category: .lubricants
        )
    }
    
    /// Generate direct product link for specific brand/model combinations
    static func directProductLink(
        vendor: Vendor,
        brand: String,
        model: String,
        category: ComponentCategory
    ) -> OrderLink? {
        // Known direct links for popular products
        let knownLinks: [String: (Vendor, String)] = [
            "Continental Grand Prix 5000": (.competitiveCyclist, "https://www.competitivecyclist.com/continental-grand-prix-5000-tire"),
            "Shimano CN-M9100": (.competitiveCyclist, "https://www.competitivecyclist.com/shimano-cn-m9100-chain"),
            "SRAM Red AXS Chain": (.jensonUSA, "https://www.jensonusa.com/SRAM-Red-AXS-Flattop-Chain"),
            "Silca Super Secret": (.silca, "https://silca.cc/collections/chain-lube-wax/products/super-secret-chain-lube"),
        ]
        
        let key = "\(brand) \(model)"
        if let (linkVendor, urlString) = knownLinks[key],
           linkVendor == vendor,
           let url = URL(string: urlString) {
            return OrderLink(
                vendor: vendor,
                url: url,
                displayText: "\(brand) \(model)",
                category: category
            )
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    private static func mapComponentToCategory(_ componentType: ComponentType) -> ComponentCategory {
        switch componentType {
        case .chain: return .chains
        case .cassette: return .cassettes
        case .chainring: return .chainrings
        case .brakePads: return .brakePads
        case .cables: return .cables
        case .derailleur: return .tools
        case .brakes: return .tools
        case .crankset: return .tools
        case .bottomBracket: return .tools
        case .headset: return .tools
        case .bearings: return .tools
        }
    }
    
    /// Get recommended vendors for a component type
    static func recommendedVendors(for category: ComponentCategory) -> [Vendor] {
        switch category {
        case .lubricants:
            return [.silca, .competitiveCyclist, .jensonUSA]
        case .tools:
            return [.silca, .jensonUSA, .competitiveCyclist]
        case .pumps:
            return [.silca, .competitiveCyclist]
        case .tires:
            return [.competitiveCyclist, .jensonUSA, .chainReactionCycles]
        case .chains:
            return [.competitiveCyclist, .jensonUSA, .modernBike]
        default:
            return [.competitiveCyclist, .jensonUSA, .backcountry]
        }
    }
    
    /// Filter vendors by user preferences
    static func filterByPreferences(
        vendors: [Vendor],
        preference: VendorPreference?
    ) -> [Vendor] {
        guard let preference = preference else {
            return vendors
        }
        
        let preferredVendors = preference.vendors
        let preferredSet = Set(preferredVendors)
        
        // Return vendors in order of preference, then remaining
        let preferred = preferredVendors.filter { vendors.contains($0) }
        let remaining = vendors.filter { !preferredSet.contains($0) }
        
        return preferred + remaining
    }
}
