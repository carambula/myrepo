//
//  WeatherService.swift
//  SpinMin
//
//  Weather condition analysis and gear recommendations
//

import Foundation

struct WeatherService {
    
    // MARK: - Weather Conditions
    
    enum TemperatureCategory {
        case freezing      // < 0°C
        case veryCold      // 0-5°C
        case cold          // 5-10°C
        case cool          // 10-15°C
        case mild          // 15-20°C
        case warm          // 20-25°C
        case hot           // 25-30°C
        case veryHot       // 30-35°C
        case extreme       // > 35°C
        
        init(celsius: Double) {
            switch celsius {
            case ..<0: self = .freezing
            case 0..<5: self = .veryCold
            case 5..<10: self = .cold
            case 10..<15: self = .cool
            case 15..<20: self = .mild
            case 20..<25: self = .warm
            case 25..<30: self = .hot
            case 30..<35: self = .veryHot
            default: self = .extreme
            }
        }
        
        var displayName: String {
            switch self {
            case .freezing: return "Freezing"
            case .veryCold: return "Very Cold"
            case .cold: return "Cold"
            case .cool: return "Cool"
            case .mild: return "Mild"
            case .warm: return "Warm"
            case .hot: return "Hot"
            case .veryHot: return "Very Hot"
            case .extreme: return "Extreme Heat"
            }
        }
        
        var emoji: String {
            switch self {
            case .freezing: return "🥶"
            case .veryCold: return "❄️"
            case .cold: return "🧥"
            case .cool: return "🌡️"
            case .mild: return "😊"
            case .warm: return "☀️"
            case .hot: return "🔥"
            case .veryHot: return "🥵"
            case .extreme: return "⚠️"
            }
        }
    }
    
    enum PrecipitationLevel {
        case none          // < 10%
        case slight        // 10-30%
        case possible      // 30-50%
        case likely        // 50-70%
        case veryLikely    // 70-90%
        case certain       // > 90%
        
        init(probability: Double) {
            switch probability {
            case ..<0.1: self = .none
            case 0.1..<0.3: self = .slight
            case 0.3..<0.5: self = .possible
            case 0.5..<0.7: self = .likely
            case 0.7..<0.9: self = .veryLikely
            default: self = .certain
            }
        }
        
        var displayName: String {
            switch self {
            case .none: return "No rain expected"
            case .slight: return "Slight chance"
            case .possible: return "Possible"
            case .likely: return "Likely"
            case .veryLikely: return "Very likely"
            case .certain: return "Rain certain"
            }
        }
        
        var emoji: String {
            switch self {
            case .none: return "☀️"
            case .slight: return "🌤️"
            case .possible: return "⛅️"
            case .likely: return "🌧️"
            case .veryLikely: return "☔️"
            case .certain: return "⛈️"
            }
        }
    }
    
    // MARK: - Clothing Recommendations
    
    struct ClothingRecommendations {
        let jacket: ClothingItem?
        let gloves: ClothingItem?
        let legCovering: ClothingItem?
        let baseLayer: ClothingItem?
        let accessories: [ClothingItem]
        
        struct ClothingItem {
            let name: String
            let priority: Priority
            let reason: String
            
            enum Priority {
                case essential
                case recommended
                case optional
                
                var displayName: String {
                    switch self {
                    case .essential: return "Essential"
                    case .recommended: return "Recommended"
                    case .optional: return "Optional"
                    }
                }
            }
        }
    }
    
    static func recommendClothing(
        temperature: Double,
        precipitationChance: Double,
        rideDuration: TimeInterval
    ) -> ClothingRecommendations {
        let tempCategory = TemperatureCategory(celsius: temperature)
        let precipLevel = PrecipitationLevel(probability: precipitationChance)
        let isLongRide = rideDuration > 7200  // > 2 hours
        
        var jacket: ClothingRecommendations.ClothingItem?
        var gloves: ClothingRecommendations.ClothingItem?
        var legCovering: ClothingRecommendations.ClothingItem?
        var baseLayer: ClothingRecommendations.ClothingItem?
        var accessories: [ClothingRecommendations.ClothingItem] = []
        
        // Temperature-based recommendations
        switch tempCategory {
        case .freezing:
            jacket = .init(name: "Insulated winter jacket", priority: .essential, reason: "Below freezing - thermal protection critical")
            gloves = .init(name: "Winter gloves (lobster or full-finger)", priority: .essential, reason: "Prevent frostbite")
            legCovering = .init(name: "Thermal bib tights", priority: .essential, reason: "Full leg protection needed")
            baseLayer = .init(name: "Thermal base layer", priority: .essential, reason: "Core temperature regulation")
            accessories.append(.init(name: "Shoe covers", priority: .essential, reason: "Protect toes from freezing"))
            accessories.append(.init(name: "Neck warmer", priority: .recommended, reason: "Protect exposed skin"))
            accessories.append(.init(name: "Thermal cap under helmet", priority: .recommended, reason: "Prevent heat loss"))
            
        case .veryCold:
            jacket = .init(name: "Insulated jacket or thermal jersey + vest", priority: .essential, reason: "Very cold conditions")
            gloves = .init(name: "Winter gloves", priority: .essential, reason: "Hand protection critical")
            legCovering = .init(name: "Thermal leg warmers or bib tights", priority: .recommended, reason: "Leg warmth on long rides")
            baseLayer = .init(name: "Long sleeve base layer", priority: .recommended, reason: "Extra insulation layer")
            accessories.append(.init(name: "Shoe covers", priority: .recommended, reason: "Keep feet warm"))
            
        case .cold:
            jacket = .init(name: "Thermal jacket or vest + long sleeve", priority: .essential, reason: "Cold weather protection")
            gloves = .init(name: "Full-finger gloves", priority: .essential, reason: "Hand warmth")
            legCovering = .init(name: "Leg warmers or thermal bibs", priority: .optional, reason: "Personal preference")
            
        case .cool:
            if isLongRide {
                jacket = .init(name: "Vest or arm warmers", priority: .recommended, reason: "Temperature may drop on long ride")
                gloves = .init(name: "Light gloves", priority: .optional, reason: "Early morning chill")
            }
            
        case .mild, .warm:
            // Standard cycling kit sufficient
            break
            
        case .hot, .veryHot:
            accessories.append(.init(name: "Lightweight, breathable kit", priority: .recommended, reason: "Hot weather - maximize airflow"))
            accessories.append(.init(name: "Sunscreen", priority: .essential, reason: "UV protection"))
            accessories.append(.init(name: "Extra water bottles", priority: .essential, reason: "Increased hydration needs"))
            
        case .extreme:
            accessories.append(.init(name: "Ice vest or cooling sleeves", priority: .recommended, reason: "Core temperature management"))
            accessories.append(.init(name: "Electrolyte drinks", priority: .essential, reason: "Replace lost salts"))
            accessories.append(.init(name: "Sunscreen + cooling towel", priority: .essential, reason: "Heat management"))
        }
        
        // Precipitation-based additions
        switch precipLevel {
        case .none, .slight:
            break
            
        case .possible:
            if jacket == nil {
                jacket = .init(name: "Packable rain jacket", priority: .optional, reason: "Rain possible - easy to carry")
            }
            
        case .likely:
            if jacket != nil {
                // Upgrade existing jacket to waterproof
                jacket = .init(name: "Waterproof rain jacket", priority: .essential, reason: "Rain likely - stay dry")
            } else {
                jacket = .init(name: "Waterproof rain jacket", priority: .essential, reason: "Rain protection")
            }
            accessories.append(.init(name: "Fenders", priority: .recommended, reason: "Keep spray off"))
            
        case .veryLikely, .certain:
            jacket = .init(name: "Waterproof jacket + rain pants", priority: .essential, reason: "Heavy rain expected")
            accessories.append(.init(name: "Waterproof gloves", priority: .recommended, reason: "Keep hands dry"))
            accessories.append(.init(name: "Shoe covers", priority: .recommended, reason: "Waterproof feet"))
            accessories.append(.init(name: "Fenders", priority: .essential, reason: "Minimize spray"))
            accessories.append(.init(name: "Visibility lights", priority: .essential, reason: "Reduced visibility in rain"))
        }
        
        // Combined weather warnings
        if tempCategory == .cold || tempCategory == .veryCold || tempCategory == .freezing {
            if precipLevel == .likely || precipLevel == .veryLikely || precipLevel == .certain {
                // Cold + wet = hypothermia risk
                accessories.append(.init(name: "Full waterproof layer system", priority: .essential, reason: "Hypothermia risk - stay completely dry"))
            }
        }
        
        return ClothingRecommendations(
            jacket: jacket,
            gloves: gloves,
            legCovering: legCovering,
            baseLayer: baseLayer,
            accessories: accessories
        )
    }
    
    // MARK: - Hydration Recommendations
    
    static func recommendHydration(
        temperature: Double,
        rideDuration: TimeInterval,
        rideIntensity: Int  // 1-5 scale
    ) -> String {
        let durationHours = rideDuration / 3600
        let tempCategory = TemperatureCategory(celsius: temperature)
        
        // Base recommendation: 500-750ml per hour
        var mlPerHour = 500.0
        
        // Adjust for temperature
        switch tempCategory {
        case .hot, .veryHot:
            mlPerHour += 250
        case .extreme:
            mlPerHour += 500
        case .warm:
            mlPerHour += 100
        default:
            break
        }
        
        // Adjust for intensity
        mlPerHour += Double(rideIntensity * 50)
        
        let totalML = mlPerHour * durationHours
        let bottleCount = Int(ceil(totalML / 750))  // Standard 750ml bottle
        
        var recommendation = "\(bottleCount) bottle\(bottleCount > 1 ? "s" : "") (\(Int(totalML))ml total)"
        
        if tempCategory == .hot || tempCategory == .veryHot || tempCategory == .extreme {
            recommendation += " with electrolytes"
        }
        
        if durationHours > 3 {
            recommendation += " + plan refill stops"
        }
        
        return recommendation
    }
}
