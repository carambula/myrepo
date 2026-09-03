//
//  ProductDatabaseSeeder.swift
//  SpinMin
//
//  Seeds product database with popular products
//

import Foundation
import SwiftData

struct ProductDatabaseSeeder {
    
    // MARK: - Seed All Products
    
    static func seedDatabaseIfNeeded(context: ModelContext) {
        // Check if already seeded
        let descriptor = FetchDescriptor<TireProduct>()
        if let count = try? context.fetchCount(descriptor), count > 0 {
            return  // Already seeded
        }
        
        print("Seeding product database...")
        
        seedTires(context: context)
        seedChains(context: context)
        seedWheelsets(context: context)
        seedComponents(context: context)
        
        try? context.save()
        print("Product database seeded successfully")
    }
    
    // MARK: - Seed Tires
    
    private static func seedTires(context: ModelContext) {
        let tires: [TireProduct] = [
            // Continental
            TireProduct(
                brand: "Continental",
                model: "Grand Prix 5000",
                wheelSize: "700c",
                widthMM: 25,
                tireType: "clincher",
                compoundType: .training,
                year: 2024,
                casing: .standard,
                weight: 230,
                maxPSI: 120,
                description: "Premium all-around road tire with excellent grip and low rolling resistance",
                isPopular: true
            ),
            TireProduct(
                brand: "Continental",
                model: "Grand Prix 5000 S TR",
                wheelSize: "700c",
                widthMM: 28,
                tireType: "tubeless",
                compoundType: .training,
                year: 2024,
                casing: .supple,
                weight: 265,
                maxPSI: 95,
                description: "Tubeless version with lower rolling resistance",
                isPopular: true
            ),
            TireProduct(
                brand: "Continental",
                model: "Grand Prix 5000 S TR",
                wheelSize: "700c",
                widthMM: 32,
                tireType: "tubeless",
                compoundType: .training,
                year: 2024,
                casing: .supple,
                weight: 310,
                maxPSI: 85,
                isPopular: true
            ),
            
            // Schwalbe
            TireProduct(
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
                description: "Fast tubeless road tire with excellent grip",
                isPopular: true
            ),
            TireProduct(
                brand: "Schwalbe",
                model: "G-One Allround",
                wheelSize: "700c",
                widthMM: 38,
                tireType: "tubeless",
                compoundType: .gravel,
                year: 2024,
                casing: .standard,
                weight: 335,
                maxPSI: 75,
                description: "Versatile gravel tire for mixed surfaces",
                isPopular: true
            ),
            TireProduct(
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
                isPopular: true
            ),
            
            // Vittoria
            TireProduct(
                brand: "Vittoria",
                model: "Corsa N.EXT",
                wheelSize: "700c",
                widthMM: 26,
                tireType: "tubeless",
                compoundType: .racing,
                year: 2024,
                casing: .supple,
                weight: 260,
                maxPSI: 110,
                description: "Premium racing tire with graphene technology",
                isPopular: true
            ),
            TireProduct(
                brand: "Vittoria",
                model: "Terreno Dry",
                wheelSize: "700c",
                widthMM: 40,
                tireType: "tubeless",
                compoundType: .gravel,
                year: 2024,
                weight: 380,
                maxPSI: 70,
                description: "Fast-rolling gravel tire for dry conditions"
            ),
            
            // Pirelli
            TireProduct(
                brand: "Pirelli",
                model: "P Zero Race TLR",
                wheelSize: "700c",
                widthMM: 28,
                tireType: "tubeless",
                compoundType: .racing,
                year: 2024,
                casing: .supple,
                weight: 265,
                maxPSI: 95,
                description: "High-performance racing tire",
                isPopular: true
            ),
            
            // Specialized
            TireProduct(
                brand: "Specialized",
                model: "Turbo Cotton",
                wheelSize: "700c",
                widthMM: 28,
                tireType: "clincher",
                compoundType: .racing,
                year: 2024,
                casing: .supple,
                weight: 255,
                maxPSI: 100,
                description: "Cotton casing for supple ride quality"
            ),
            
            // Maxxis MTB
            TireProduct(
                brand: "Maxxis",
                model: "Minion DHR II",
                wheelSize: "29\"",
                widthMM: 61,  // 2.4"
                tireType: "tubeless",
                compoundType: .mtbTrail,
                year: 2024,
                weight: 920,
                maxPSI: 40,
                description: "Aggressive trail and enduro rear tire"
            ),
            TireProduct(
                brand: "Maxxis",
                model: "Rekon",
                wheelSize: "29\"",
                widthMM: 58,  // 2.3"
                tireType: "tubeless",
                compoundType: .mtbXC,
                year: 2024,
                weight: 720,
                maxPSI: 45,
                description: "Fast-rolling XC and trail tire"
            ),
        ]
        
        for tire in tires {
            context.insert(tire)
        }
    }
    
    // MARK: - Seed Chains
    
    private static func seedChains(context: ModelContext) {
        let chains: [ChainProduct] = [
            // Shimano
            ChainProduct(
                brand: "Shimano",
                model: "CN-M9100",
                speedCount: 12,
                year: 2024,
                compatibleBrands: ["Shimano"],
                linksCount: 126,
                weight: 257,
                coating: "Sil-Tec",
                description: "XTR 12-speed chain with low-friction coating",
                isPopular: true
            ),
            ChainProduct(
                brand: "Shimano",
                model: "CN-HG701",
                speedCount: 11,
                year: 2024,
                compatibleBrands: ["Shimano"],
                linksCount: 116,
                weight: 242,
                description: "Ultegra/XT level 11-speed chain",
                isPopular: true
            ),
            
            // SRAM
            ChainProduct(
                brand: "SRAM",
                model: "XX1 Eagle",
                speedCount: 12,
                year: 2024,
                compatibleBrands: ["SRAM"],
                linksCount: 126,
                weight: 258,
                coating: "Hard Chrome",
                description: "Top-level 12-speed MTB chain",
                isPopular: true
            ),
            ChainProduct(
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
            ),
            
            // KMC
            ChainProduct(
                brand: "KMC",
                model: "X11SL",
                speedCount: 11,
                year: 2024,
                compatibleBrands: ["Shimano", "SRAM", "Campagnolo"],
                linksCount: 116,
                weight: 239,
                coating: "DLC",
                description: "Lightweight 11-speed chain, universal compatibility",
                isPopular: true
            ),
            ChainProduct(
                brand: "KMC",
                model: "X12",
                speedCount: 12,
                year: 2024,
                compatibleBrands: ["Shimano", "SRAM"],
                linksCount: 126,
                weight: 258,
                description: "12-speed chain with universal compatibility"
            ),
            
            // Campagnolo
            ChainProduct(
                brand: "Campagnolo",
                model: "Record",
                speedCount: 12,
                year: 2024,
                compatibleBrands: ["Campagnolo"],
                linksCount: 114,
                weight: 252,
                description: "Ultra-smooth Campagnolo 12-speed chain",
                isPopular: true
            ),
        ]
        
        for chain in chains {
            context.insert(chain)
        }
    }
    
    // MARK: - Seed Wheelsets
    
    private static func seedWheelsets(context: ModelContext) {
        let wheelsets: [WheelsetProduct] = [
            // Zipp
            WheelsetProduct(
                brand: "Zipp",
                model: "303 Firecrest",
                wheelSize: "700c",
                year: 2024,
                rimDepthMM: 45,
                rimWidthMM: 23,
                isDiscBrake: true,
                freehubType: "Shimano HG",
                weight: 1450,
                material: "carbon",
                description: "Versatile all-around carbon wheelset",
                isPopular: true
            ),
            
            // DT Swiss
            WheelsetProduct(
                brand: "DT Swiss",
                model: "ERC 1400 Spline",
                wheelSize: "700c",
                year: 2024,
                rimDepthMM: 47,
                rimWidthMM: 20,
                isDiscBrake: true,
                freehubType: "Shimano HG",
                weight: 1495,
                material: "carbon",
                description: "Reliable endurance carbon wheels",
                isPopular: true
            ),
            
            // Mavic
            WheelsetProduct(
                brand: "Mavic",
                model: "Cosmic SLR 45",
                wheelSize: "700c",
                year: 2024,
                rimDepthMM: 45,
                rimWidthMM: 21,
                isDiscBrake: true,
                weight: 1520,
                material: "carbon",
                description: "Proven aero carbon wheelset"
            ),
        ]
        
        for wheelset in wheelsets {
            context.insert(wheelset)
        }
    }
    
    // MARK: - Seed Components
    
    private static func seedComponents(context: ModelContext) {
        let components: [ComponentProduct] = [
            // Cassettes
            ComponentProduct(
                brand: "Shimano",
                model: "CS-R8100 Ultegra",
                componentType: .cassette,
                year: 2024,
                specifications: ["speed": "12", "teeth": "11-30"],
                weight: 293,
                description: "Ultegra 12-speed cassette",
                isPopular: true
            ),
            ComponentProduct(
                brand: "SRAM",
                model: "XG-1295 Eagle",
                componentType: .cassette,
                year: 2024,
                specifications: ["speed": "12", "teeth": "10-52"],
                weight: 355,
                description: "Wide-range MTB cassette",
                isPopular: true
            ),
            
            // Brake Pads
            ComponentProduct(
                brand: "Shimano",
                model: "L03A Resin",
                componentType: .brakePads,
                year: 2024,
                specifications: ["type": "resin", "compatibility": "XTR/XT/SLX"],
                description: "Quiet resin pads with good modulation",
                isPopular: true
            ),
            ComponentProduct(
                brand: "Shimano",
                model: "L04C Metal",
                componentType: .brakePads,
                year: 2024,
                specifications: ["type": "metal", "compatibility": "Dura-Ace/Ultegra/105"],
                description: "Powerful metallic pads for road",
                isPopular: true
            ),
        ]
        
        for component in components {
            context.insert(component)
        }
    }
}
