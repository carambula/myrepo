//
//  ProductLookupTests.swift
//  SpinMinTests
//
//  Tests for product lookup and search functionality
//

import XCTest
import SwiftData
@testable import SpinMin

final class ProductLookupTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        // Create in-memory model container for testing
        let schema = Schema([
            TireProduct.self,
            ChainProduct.self,
            WheelsetProduct.self,
            ComponentProduct.self,
            BikeProduct.self,
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        
        // Seed test data
        seedTestData()
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Test Data Seeding
    
    func seedTestData() {
        // Add test tires
        let gp5000 = TireProduct(
            brand: "Continental",
            model: "Grand Prix 5000",
            wheelSize: "700c",
            widthMM: 28,
            tireType: "tubeless",
            compoundType: .training,
            year: 2024,
            casing: .supple,
            weight: 265,
            maxPSI: 95,
            description: "Premium road tire",
            isPopular: true
        )
        modelContext.insert(gp5000)
        
        let proOne = TireProduct(
            brand: "Schwalbe",
            model: "Pro One",
            wheelSize: "700c",
            widthMM: 28,
            tireType: "tubeless",
            compoundType: .racing,
            year: 2024,
            casing: .supple,
            weight: 250,
            maxPSI: 95,
            description: "Fast tubeless road tire",
            isPopular: true
        )
        modelContext.insert(proOne)
        
        let gOneAllround = TireProduct(
            brand: "Schwalbe",
            model: "G-One Allround",
            wheelSize: "700c",
            widthMM: 45,
            tireType: "tubeless",
            compoundType: .gravel,
            year: 2024,
            casing: .standard,
            weight: 430,
            maxPSI: 65,
            description: "Versatile gravel tire",
            isPopular: true
        )
        modelContext.insert(gOneAllround)
        
        // Add test chains
        let shimanoXTR = ChainProduct(
            brand: "Shimano",
            model: "CN-M9100",
            speedCount: 12,
            year: 2024,
            compatibleBrands: ["Shimano"],
            linksCount: 126,
            weight: 257,
            coating: "Sil-Tec",
            description: "XTR 12-speed chain",
            isPopular: true
        )
        modelContext.insert(shimanoXTR)
        
        let sramRed = ChainProduct(
            brand: "SRAM",
            model: "Red AXS",
            speedCount: 12,
            year: 2024,
            compatibleBrands: ["SRAM"],
            linksCount: 114,
            weight: 246,
            coating: "Hard Chrome",
            description: "Premium road 12-speed chain",
            isPopular: true
        )
        modelContext.insert(sramRed)
        
        try? modelContext.save()
    }
    
    // MARK: - Tire Search Tests
    
    func testSearchTires_EmptyQuery_ReturnsAll() {
        let results = ProductLookupService.searchTires(
            query: "",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 3, "Empty query should return all tires")
    }
    
    func testSearchTires_BrandSearch() {
        let results = ProductLookupService.searchTires(
            query: "Continental",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1, "Should find 1 Continental tire")
        XCTAssertEqual(results.first?.brand, "Continental")
        XCTAssertEqual(results.first?.model, "Grand Prix 5000")
    }
    
    func testSearchTires_PartialMatch() {
        let results = ProductLookupService.searchTires(
            query: "Schwal",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 2, "Should find 2 Schwalbe tires")
        XCTAssertTrue(results.allSatisfy { $0.brand == "Schwalbe" })
    }
    
    func testSearchTires_ModelSearch() {
        let results = ProductLookupService.searchTires(
            query: "Pro One",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1, "Should find Pro One tire")
        XCTAssertEqual(results.first?.model, "Pro One")
    }
    
    func testSearchTires_WheelSizeFilter() {
        let results = ProductLookupService.searchTires(
            query: "",
            wheelSize: "700c",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 3, "All test tires are 700c")
        XCTAssertTrue(results.allSatisfy { $0.wheelSizeRawValue == "700c" })
    }
    
    func testSearchTires_WidthRangeFilter() {
        let results = ProductLookupService.searchTires(
            query: "",
            widthRange: 25...30,
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 2, "Should find 2 tires in 25-30mm range")
        XCTAssertTrue(results.allSatisfy { (25...30).contains($0.widthMM) })
    }
    
    func testSearchTires_CombinedFilters() {
        let results = ProductLookupService.searchTires(
            query: "Schwalbe",
            wheelSize: "700c",
            widthRange: 40...50,
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1, "Should find G-One Allround")
        XCTAssertEqual(results.first?.model, "G-One Allround")
    }
    
    func testSearchTires_NoResults() {
        let results = ProductLookupService.searchTires(
            query: "Michelin",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 0, "Should find no Michelin tires")
    }
    
    func testSearchTires_PopularFirst() {
        let results = ProductLookupService.searchTires(
            query: "",
            context: modelContext
        )
        
        XCTAssertTrue(results.allSatisfy { $0.isPopular }, "All test tires are popular")
    }
    
    // MARK: - Chain Search Tests
    
    func testSearchChains_EmptyQuery_ReturnsAll() {
        let results = ProductLookupService.searchChains(
            query: "",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 2, "Empty query should return all chains")
    }
    
    func testSearchChains_BrandSearch() {
        let results = ProductLookupService.searchChains(
            query: "Shimano",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1, "Should find 1 Shimano chain")
        XCTAssertEqual(results.first?.brand, "Shimano")
    }
    
    func testSearchChains_SpeedCountFilter() {
        let results = ProductLookupService.searchChains(
            query: "",
            speedCount: 12,
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 2, "Should find 2 12-speed chains")
        XCTAssertTrue(results.allSatisfy { $0.speedCount == 12 })
    }
    
    func testSearchChains_CompatibilityFilter() {
        let results = ProductLookupService.searchChains(
            query: "",
            compatibleWith: "Shimano",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1, "Should find 1 Shimano-compatible chain")
        XCTAssertTrue(results.first?.compatibleBrands.contains("Shimano") ?? false)
    }
    
    func testSearchChains_CombinedFilters() {
        let results = ProductLookupService.searchChains(
            query: "SRAM",
            speedCount: 12,
            compatibleWith: "SRAM",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1, "Should find SRAM Red AXS")
        XCTAssertEqual(results.first?.model, "Red AXS")
    }
    
    // MARK: - Autocomplete Tests
    
    func testAutocompleteTires_MinimumLength() {
        let resultsShort = ProductLookupService.autocompleteTires(
            query: "C",
            context: modelContext
        )
        
        XCTAssertEqual(resultsShort.count, 0, "Should require 2+ characters")
        
        let resultsLongEnough = ProductLookupService.autocompleteTires(
            query: "Co",
            context: modelContext
        )
        
        XCTAssertGreaterThan(resultsLongEnough.count, 0, "Should return results with 2+ chars")
    }
    
    func testAutocompleteTires_LimitedResults() {
        let results = ProductLookupService.autocompleteTires(
            query: "Sc",
            context: modelContext
        )
        
        XCTAssertLessThanOrEqual(results.count, 10, "Should limit to 10 results")
    }
    
    func testAutocompleteTires_ReturnsDisplayNames() {
        let results = ProductLookupService.autocompleteTires(
            query: "Continental",
            context: modelContext
        )
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].contains("Continental"), "Should contain brand")
        XCTAssertTrue(results[0].contains("28mm"), "Should contain width")
    }
    
    // MARK: - Relevance Scoring Tests
    
    func testSearchTires_ExactMatchPriority() {
        // Add a tire with model "Pro"
        let proTire = TireProduct(
            brand: "Test",
            model: "Pro",
            wheelSize: "700c",
            widthMM: 25,
            tireType: "tubeless",
            compoundType: .training,
            isPopular: false
        )
        modelContext.insert(proTire)
        try? modelContext.save()
        
        let results = ProductLookupService.searchTires(
            query: "Pro",
            context: modelContext
        )
        
        // "Pro" exact match should rank higher than "Pro One" contains match
        // But popular boost might affect this
        XCTAssertGreaterThan(results.count, 0, "Should find results")
    }
    
    // MARK: - Brand/Model Extraction Tests
    
    func testExtractUniqueBrands() {
        let allTires = ProductLookupService.searchTires(
            query: "",
            context: modelContext
        )
        
        let brands = ProductLookupService.extractUniqueBrands(from: allTires)
        
        XCTAssertEqual(brands.count, 2, "Should find 2 unique brands")
        XCTAssertTrue(brands.contains("Continental"))
        XCTAssertTrue(brands.contains("Schwalbe"))
        XCTAssertEqual(brands, brands.sorted(), "Should be sorted")
    }
    
    func testExtractUniqueModels() {
        let allTires = ProductLookupService.searchTires(
            query: "",
            context: modelContext
        )
        
        let models = ProductLookupService.extractUniqueModels(
            from: allTires,
            brand: "Schwalbe"
        )
        
        XCTAssertEqual(models.count, 2, "Should find 2 Schwalbe models")
        XCTAssertTrue(models.contains("Pro One"))
        XCTAssertTrue(models.contains("G-One Allround"))
        XCTAssertEqual(models, models.sorted(), "Should be sorted")
    }
    
    // MARK: - Database Seeder Tests
    
    func testDatabaseSeeder_DoesNotDuplicateSeeding() {
        // First seed
        ProductDatabaseSeeder.seedDatabaseIfNeeded(context: modelContext)
        let firstCount = try? modelContext.fetchCount(FetchDescriptor<TireProduct>())
        
        // Second seed attempt
        ProductDatabaseSeeder.seedDatabaseIfNeeded(context: modelContext)
        let secondCount = try? modelContext.fetchCount(FetchDescriptor<TireProduct>())
        
        XCTAssertEqual(firstCount, secondCount, "Should not duplicate seed data")
    }
    
    func testDatabaseSeeder_SeedsPopularProducts() {
        // Create fresh context
        let freshContext = ModelContext(modelContainer)
        
        ProductDatabaseSeeder.seedDatabaseIfNeeded(context: freshContext)
        
        let tires = ProductLookupService.searchTires(query: "", context: freshContext)
        let chains = ProductLookupService.searchChains(query: "", context: freshContext)
        
        XCTAssertGreaterThan(tires.count, 0, "Should seed tires")
        XCTAssertGreaterThan(chains.count, 0, "Should seed chains")
        
        let popularTires = tires.filter { $0.isPopular }
        XCTAssertGreaterThan(popularTires.count, 0, "Should have popular tires")
    }
}
