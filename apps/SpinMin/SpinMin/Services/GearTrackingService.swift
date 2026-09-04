//
//  GearTrackingService.swift
//  SpinMin
//
//  Service for gear lifespan tracking and replacement recommendations
//

import Foundation

struct GearTrackingService {
    
    // MARK: - Gear Health Status
    
    enum GearHealth: String {
        case new
        case good
        case aging
        case replaceSoon
        case replaceNow
        case expired
        case unsafe
        
        var displayName: String {
            switch self {
            case .new: return "New"
            case .good: return "Good"
            case .aging: return "Aging"
            case .replaceSoon: return "Replace Soon"
            case .replaceNow: return "Replace Now"
            case .expired: return "Expired"
            case .unsafe: return "UNSAFE"
            }
        }
        
        var emoji: String {
            switch self {
            case .new: return "✨"
            case .good: return "🟢"
            case .aging: return "🟡"
            case .replaceSoon: return "🟠"
            case .replaceNow: return "🔴"
            case .expired: return "⛔️"
            case .unsafe: return "⚠️"
            }
        }
        
        var color: String {
            switch self {
            case .new, .good: return "green"
            case .aging: return "yellow"
            case .replaceSoon: return "orange"
            case .replaceNow, .expired, .unsafe: return "red"
            }
        }
    }
    
    struct GearHealthResult {
        let health: GearHealth
        let agePercentage: Double  // 0-100+
        let usagePercentage: Double  // 0-100+
        let warnings: [String]
        let recommendations: [String]
        let daysUntilExpiry: Int?
        let shouldOrder: Bool
    }
    
    // MARK: - Calculate Gear Health
    
    static func calculateHealth(for gear: GearItem) -> GearHealthResult {
        let gearType = gear.gearType
        
        // Check for retirement
        if gear.isRetired {
            return GearHealthResult(
                health: .expired,
                agePercentage: 100,
                usagePercentage: 100,
                warnings: ["Gear has been retired"],
                recommendations: gear.retirementReason.map { [$0] } ?? [],
                daysUntilExpiry: 0,
                shouldOrder: true
            )
        }
        
        // Safety critical checks
        if gearType == .helmet {
            return calculateHelmetHealth(gear)
        }
        
        // Get expected lifespan
        guard let expectedLifespanDays = gearType.expectedLifespanDays else {
            // Indefinite lifespan (tools, etc.)
            return calculateIndefiniteLifespanHealth(gear)
        }
        
        // Calculate age-based health
        let ageDays = gear.ageDays
        let agePercentage = Double(ageDays) / Double(expectedLifespanDays) * 100
        let daysUntilExpiry = expectedLifespanDays - ageDays
        
        // Calculate usage-based health (if applicable)
        let usagePercentage = calculateUsagePercentage(for: gear)
        
        // Determine health status
        let health = determineHealth(
            agePercentage: agePercentage,
            usagePercentage: usagePercentage,
            gearType: gearType
        )
        
        // Generate warnings and recommendations
        let warnings = generateWarnings(
            gear: gear,
            agePercentage: agePercentage,
            usagePercentage: usagePercentage,
            daysUntilExpiry: daysUntilExpiry
        )
        
        let recommendations = generateRecommendations(
            gear: gear,
            health: health,
            daysUntilExpiry: daysUntilExpiry
        )
        
        let shouldOrder = health == .replaceNow || health == .expired || health == .unsafe
        
        return GearHealthResult(
            health: health,
            agePercentage: agePercentage,
            usagePercentage: usagePercentage,
            warnings: warnings,
            recommendations: recommendations,
            daysUntilExpiry: daysUntilExpiry,
            shouldOrder: shouldOrder
        )
    }
    
    // MARK: - Helmet-Specific Health
    
    private static func calculateHelmetHealth(_ gear: GearItem) -> GearHealthResult {
        var warnings: [String] = []
        var recommendations: [String] = []
        var health: GearHealth = .good
        
        // Check for crash
        if gear.crashDate != nil {
            return GearHealthResult(
                health: .unsafe,
                agePercentage: 100,
                usagePercentage: 100,
                warnings: ["⚠️ HELMET HAS BEEN IN A CRASH", "IMMEDIATE REPLACEMENT REQUIRED"],
                recommendations: ["Replace helmet immediately - crash damage may be invisible"],
                daysUntilExpiry: 0,
                shouldOrder: true
            )
        }
        
        // Check age (5-year rule)
        let ageDays = gear.ageDays
        let ageYears = Double(ageDays) / 365.0
        let agePercentage = (Double(ageDays) / 1825.0) * 100  // 5 years
        
        if ageYears >= 5 {
            health = .expired
            warnings.append("Helmet is \(Int(ageYears)) years old - expired")
            recommendations.append("Replace helmet - safety standards and materials degrade over 5 years")
        } else if ageYears >= 4 {
            health = .replaceNow
            warnings.append("Helmet is nearing 5-year expiration")
            recommendations.append("Order replacement helmet soon")
        } else if ageYears >= 3 {
            health = .aging
            warnings.append("Helmet is \(Int(ageYears)) years old")
            recommendations.append("Inspect for cracks, loose straps, worn padding")
        }
        
        // Check last inspection
        if let lastInspection = gear.lastInspectionDate {
            let daysSinceInspection = Calendar.current.dateComponents([.day], from: lastInspection, to: Date()).day ?? 0
            if daysSinceInspection > 90 {
                warnings.append("No inspection in \(daysSinceInspection) days")
                recommendations.append("Inspect helmet for damage, cracks, loose retention system")
            }
        } else if ageDays > 30 {
            warnings.append("Never inspected")
            recommendations.append("Perform visual inspection of helmet shell, straps, and retention system")
        }
        
        let daysUntilExpiry = 1825 - ageDays  // Days until 5 years
        
        return GearHealthResult(
            health: health,
            agePercentage: agePercentage,
            usagePercentage: 0,
            warnings: warnings,
            recommendations: recommendations,
            daysUntilExpiry: max(0, daysUntilExpiry),
            shouldOrder: health == .replaceNow || health == .expired || health == .unsafe
        )
    }
    
    // MARK: - Indefinite Lifespan Health
    
    private static func calculateIndefiniteLifespanHealth(_ gear: GearItem) -> GearHealthResult {
        var warnings: [String] = []
        var recommendations: [String] = []
        
        // Check usage
        if gear.usageCount > 500 {
            recommendations.append("High usage - inspect for wear")
        }
        
        // Check age
        let ageMonths = gear.ageMonths
        if ageMonths > 60 {  // 5 years
            warnings.append("Gear is \(ageMonths / 12) years old")
            recommendations.append("Inspect for corrosion, wear, or damage")
        }
        
        return GearHealthResult(
            health: .good,
            agePercentage: 0,
            usagePercentage: 0,
            warnings: warnings,
            recommendations: recommendations,
            daysUntilExpiry: nil,
            shouldOrder: false
        )
    }
    
    // MARK: - Usage Percentage
    
    private static func calculateUsagePercentage(for gear: GearItem) -> Double {
        let gearType = gear.gearType
        
        switch gearType {
        case .shoes:
            // ~1000 hours expected life
            let expectedHours = 1000.0
            return (gear.totalHours / expectedHours) * 100
            
        case .cleats:
            // ~500 hours expected life
            let expectedHours = 500.0
            return (gear.totalHours / expectedHours) * 100
            
        case .brakePads:
            // Varies significantly by type and use
            // Road: ~1000km, MTB: ~500km, Wet conditions: much less
            // Approximate as 100 hours for mixed use
            let expectedHours = 100.0
            return (gear.totalHours / expectedHours) * 100
            
        case .brakeRotors:
            // Rotors last 2-3x longer than pads
            // Road: ~5000km, MTB: ~2000km
            let expectedHours = 250.0
            return (gear.totalHours / expectedHours) * 100
            
        case .computerGPS:
            // Battery cycles matter more than hours
            let expectedUses = 500  // charge cycles
            return (Double(gear.usageCount) / Double(expectedUses)) * 100
            
        default:
            return 0
        }
    }
    
    // MARK: - Determine Health Status
    
    private static func determineHealth(
        agePercentage: Double,
        usagePercentage: Double,
        gearType: GearType
    ) -> GearHealth {
        let maxPercentage = max(agePercentage, usagePercentage)
        
        // Consumables are more strict
        if gearType.isConsumable {
            if maxPercentage >= 100 { return .expired }
            if maxPercentage >= 90 { return .replaceNow }
            if maxPercentage >= 75 { return .replaceSoon }
            if maxPercentage >= 50 { return .aging }
            if maxPercentage < 10 { return .new }
            return .good
        }
        
        // Safety items
        if gearType == .helmet || gearType == .tailLight || gearType == .frontLight {
            if maxPercentage >= 100 { return .expired }
            if maxPercentage >= 85 { return .replaceNow }
            if maxPercentage >= 70 { return .replaceSoon }
            if maxPercentage >= 50 { return .aging }
            if maxPercentage < 10 { return .new }
            return .good
        }
        
        // General gear
        if maxPercentage >= 100 { return .expired }
        if maxPercentage >= 90 { return .replaceNow }
        if maxPercentage >= 75 { return .replaceSoon }
        if maxPercentage >= 50 { return .aging }
        if maxPercentage < 10 { return .new }
        return .good
    }
    
    // MARK: - Generate Warnings
    
    private static func generateWarnings(
        gear: GearItem,
        agePercentage: Double,
        usagePercentage: Double,
        daysUntilExpiry: Int
    ) -> [String] {
        var warnings: [String] = []
        let gearType = gear.gearType
        
        // Age warnings
        if agePercentage >= 100 {
            warnings.append("\(gearType.displayName) has exceeded expected lifespan")
        } else if agePercentage >= 90 {
            warnings.append("\(daysUntilExpiry) days until expected end of life")
        } else if agePercentage >= 75 {
            warnings.append("\(daysUntilExpiry) days remaining (~\(daysUntilExpiry / 30) months)")
        }
        
        // Usage warnings
        if usagePercentage >= 100 {
            warnings.append("Usage has exceeded expected lifespan")
        } else if usagePercentage >= 90 {
            warnings.append("High usage - inspect for wear")
        }
        
        // Type-specific warnings
        switch gearType {
        case .shoes:
            if usagePercentage >= 75 {
                warnings.append("Check for sole wear, upper separation")
            }
        case .cleats:
            if usagePercentage >= 50 {
                warnings.append("Inspect cleat wear - uneven wear affects pedaling")
            }
        case .brakePads:
            if usagePercentage >= 75 {
                warnings.append("Check pad thickness - metal-on-rotor contact damages rotors")
            } else if usagePercentage >= 50 {
                warnings.append("Inspect pad wear and contamination")
            }
        case .brakeRotors:
            if usagePercentage >= 75 {
                warnings.append("Measure rotor thickness - below minimum is unsafe")
            } else if usagePercentage >= 50 {
                warnings.append("Check for rotor warping and glazing")
            }
        case .spareKit:
            if agePercentage >= 50 {
                warnings.append("Check spare tubes for dry rot")
            }
        case .bottles:
            if agePercentage >= 50 {
                warnings.append("Replace bottles regularly for hygiene")
            }
        default:
            break
        }
        
        return warnings
    }
    
    // MARK: - Generate Recommendations
    
    private static func generateRecommendations(
        gear: GearItem,
        health: GearHealth,
        daysUntilExpiry: Int
    ) -> [String] {
        var recommendations: [String] = []
        
        switch health {
        case .new:
            recommendations.append("Gear is new - break in gradually")
        case .good:
            recommendations.append("Gear is in good condition")
        case .aging:
            recommendations.append("Monitor condition closely")
            recommendations.append("Order replacement when sales available")
        case .replaceSoon:
            recommendations.append("Order replacement within \(daysUntilExpiry / 30) months")
            recommendations.append("Look for deals on new gear")
        case .replaceNow:
            recommendations.append("Order replacement immediately")
            recommendations.append("Have backup ready")
        case .expired:
            recommendations.append("Replace immediately - gear has exceeded safe lifespan")
        case .unsafe:
            recommendations.append("DO NOT USE - safety compromised")
        }
        
        return recommendations
    }
    
    // MARK: - Gear Summary
    
    static func gearSummary(for items: [GearItem]) -> (
        total: Int,
        active: Int,
        needReplacement: Int,
        expired: Int
    ) {
        let active = items.filter { $0.isActive }
        let needReplacement = active.filter { item in
            let health = calculateHealth(for: item).health
            return health == .replaceNow || health == .replaceSoon
        }
        let expired = active.filter { item in
            let health = calculateHealth(for: item).health
            return health == .expired || health == .unsafe
        }
        
        return (
            total: items.count,
            active: active.count,
            needReplacement: needReplacement.count,
            expired: expired.count
        )
    }
}
