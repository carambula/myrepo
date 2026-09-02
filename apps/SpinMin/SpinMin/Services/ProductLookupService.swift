//
//  ProductLookupService.swift
//  SpinMin
//
//  Product search and autocomplete service
//

import Foundation
import SwiftData

struct ProductLookupService {
    
    // MARK: - Search Results
    
    struct SearchResult<T> {
        let product: T
        let relevanceScore: Double
    }
    
    // MARK: - Tire Search
    
    static func searchTires(
        query: String,
        wheelSize: String? = nil,
        widthRange: ClosedRange<Int>? = nil,
        context: ModelContext
    ) -> [TireProduct] {
        let descriptor = FetchDescriptor<TireProduct>()
        guard let allTires = try? context.fetch(descriptor) else {
            return []
        }
        
        let queryLower = query.lowercased()
        
        // Filter and score
        var results = allTires
            .filter { tire in
                // Apply filters
                if let size = wheelSize, tire.wheelSizeRawValue != size {
                    return false
                }
                if let range = widthRange, !range.contains(tire.widthMM) {
                    return false
                }
                
                // Search match
                if query.isEmpty {
                    return true
                }
                
                return tire.searchableText.contains(queryLower) ||
                       tire.brand.lowercased().contains(queryLower) ||
                       tire.model.lowercased().contains(queryLower)
            }
            .map { tire in
                SearchResult(
                    product: tire,
                    relevanceScore: calculateRelevance(
                        searchable: tire.searchableText,
                        query: queryLower,
                        isPopular: tire.isPopular
                    )
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .map { $0.product }
        
        // Prioritize popular products
        results.sort { lhs, rhs in
            if lhs.isPopular != rhs.isPopular {
                return lhs.isPopular
            }
            return lhs.brand < rhs.brand
        }
        
        return Array(results.prefix(50))  // Limit results
    }
    
    // MARK: - Chain Search
    
    static func searchChains(
        query: String,
        speedCount: Int? = nil,
        compatibleWith: String? = nil,
        context: ModelContext
    ) -> [ChainProduct] {
        let descriptor = FetchDescriptor<ChainProduct>()
        guard let allChains = try? context.fetch(descriptor) else {
            return []
        }
        
        let queryLower = query.lowercased()
        
        var results = allChains
            .filter { chain in
                // Apply filters
                if let speed = speedCount, chain.speedCount != speed {
                    return false
                }
                if let brand = compatibleWith, !chain.compatibleBrands.contains(brand) {
                    return false
                }
                
                // Search match
                if query.isEmpty {
                    return true
                }
                
                return chain.searchableText.contains(queryLower) ||
                       chain.brand.lowercased().contains(queryLower) ||
                       chain.model.lowercased().contains(queryLower)
            }
            .map { chain in
                SearchResult(
                    product: chain,
                    relevanceScore: calculateRelevance(
                        searchable: chain.searchableText,
                        query: queryLower,
                        isPopular: chain.isPopular
                    )
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .map { $0.product }
        
        results.sort { lhs, rhs in
            if lhs.isPopular != rhs.isPopular {
                return lhs.isPopular
            }
            return lhs.brand < rhs.brand
        }
        
        return Array(results.prefix(50))
    }
    
    // MARK: - Wheelset Search
    
    static func searchWheelsets(
        query: String,
        wheelSize: String? = nil,
        isDiscBrake: Bool? = nil,
        context: ModelContext
    ) -> [WheelsetProduct] {
        let descriptor = FetchDescriptor<WheelsetProduct>()
        guard let allWheelsets = try? context.fetch(descriptor) else {
            return []
        }
        
        let queryLower = query.lowercased()
        
        var results = allWheelsets
            .filter { wheelset in
                if let size = wheelSize, wheelset.wheelSizeRawValue != size {
                    return false
                }
                if let disc = isDiscBrake, wheelset.isDiscBrake != disc {
                    return false
                }
                
                if query.isEmpty {
                    return true
                }
                
                return wheelset.searchableText.contains(queryLower) ||
                       wheelset.brand.lowercased().contains(queryLower) ||
                       wheelset.model.lowercased().contains(queryLower)
            }
            .map { wheelset in
                SearchResult(
                    product: wheelset,
                    relevanceScore: calculateRelevance(
                        searchable: wheelset.searchableText,
                        query: queryLower,
                        isPopular: wheelset.isPopular
                    )
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .map { $0.product }
        
        results.sort { lhs, rhs in
            if lhs.isPopular != rhs.isPopular {
                return lhs.isPopular
            }
            return lhs.brand < rhs.brand
        }
        
        return Array(results.prefix(50))
    }
    
    // MARK: - Component Search
    
    static func searchComponents(
        query: String,
        componentType: ComponentType? = nil,
        context: ModelContext
    ) -> [ComponentProduct] {
        let descriptor = FetchDescriptor<ComponentProduct>()
        guard let allComponents = try? context.fetch(descriptor) else {
            return []
        }
        
        let queryLower = query.lowercased()
        
        var results = allComponents
            .filter { component in
                if let type = componentType, component.componentType != type {
                    return false
                }
                
                if query.isEmpty {
                    return true
                }
                
                return component.searchableText.contains(queryLower) ||
                       component.brand.lowercased().contains(queryLower) ||
                       component.model.lowercased().contains(queryLower)
            }
            .map { component in
                SearchResult(
                    product: component,
                    relevanceScore: calculateRelevance(
                        searchable: component.searchableText,
                        query: queryLower,
                        isPopular: component.isPopular
                    )
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .map { $0.product }
        
        results.sort { lhs, rhs in
            if lhs.isPopular != rhs.isPopular {
                return lhs.isPopular
            }
            return lhs.brand < rhs.brand
        }
        
        return Array(results.prefix(50))
    }
    
    // MARK: - Bike Search
    
    static func searchBikes(
        query: String,
        bikeType: TirePressureCalculationService.BikeType? = nil,
        context: ModelContext
    ) -> [BikeProduct] {
        let descriptor = FetchDescriptor<BikeProduct>()
        guard let allBikes = try? context.fetch(descriptor) else {
            return []
        }
        
        let queryLower = query.lowercased()
        
        var results = allBikes
            .filter { bike in
                if let type = bikeType, bike.bikeType != type {
                    return false
                }
                
                if query.isEmpty {
                    return true
                }
                
                return bike.searchableText.contains(queryLower) ||
                       bike.brand.lowercased().contains(queryLower) ||
                       bike.model.lowercased().contains(queryLower)
            }
            .map { bike in
                SearchResult(
                    product: bike,
                    relevanceScore: calculateRelevance(
                        searchable: bike.searchableText,
                        query: queryLower,
                        isPopular: bike.isPopular
                    )
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .map { $0.product }
        
        results.sort { lhs, rhs in
            if lhs.isPopular != rhs.isPopular {
                return lhs.isPopular
            }
            return lhs.brand < rhs.brand
        }
        
        return Array(results.prefix(50))
    }
    
    // MARK: - Autocomplete
    
    static func autocompleteTires(
        query: String,
        context: ModelContext
    ) -> [String] {
        guard query.count >= 2 else { return [] }
        
        let results = searchTires(query: query, context: context)
        return results.prefix(10).map { $0.displayName }
    }
    
    static func autocompleteChains(
        query: String,
        context: ModelContext
    ) -> [String] {
        guard query.count >= 2 else { return [] }
        
        let results = searchChains(query: query, context: context)
        return results.prefix(10).map { $0.displayName }
    }
    
    // MARK: - Helpers
    
    private static func calculateRelevance(
        searchable: String,
        query: String,
        isPopular: Bool
    ) -> Double {
        var score = 0.0
        
        // Exact match
        if searchable == query {
            score += 100.0
        }
        
        // Starts with query
        if searchable.hasPrefix(query) {
            score += 50.0
        }
        
        // Contains query
        if searchable.contains(query) {
            score += 25.0
        }
        
        // Popular boost
        if isPopular {
            score += 10.0
        }
        
        return score
    }
    
    // MARK: - Brand/Model Extraction
    
    static func extractUniqueBrands(
        from tires: [TireProduct]
    ) -> [String] {
        Array(Set(tires.map { $0.brand })).sorted()
    }
    
    static func extractUniqueModels(
        from tires: [TireProduct],
        brand: String
    ) -> [String] {
        Array(Set(tires.filter { $0.brand == brand }.map { $0.model })).sorted()
    }
}
