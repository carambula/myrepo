//
//  MaintenanceService.swift
//  SpinMin
//
//  Calculate maintenance due dates and component health
//

import Foundation

struct MaintenanceService {
    
    // MARK: - Component Health Status
    
    enum ComponentHealth: String, Comparable {
        case excellent = "excellent"
        case good = "good"
        case serviceDue = "service_due"
        case replaceSoon = "replace_soon"
        case replaceNow = "replace_now"
        
        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .serviceDue: return "Service Due"
            case .replaceSoon: return "Replace Soon"
            case .replaceNow: return "Replace Now"
            }
        }
        
        var emoji: String {
            switch self {
            case .excellent: return "🟢"
            case .good: return "🟡"
            case .serviceDue: return "🟠"
            case .replaceSoon: return "🔴"
            case .replaceNow: return "⛔️"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "yellow"
            case .serviceDue: return "orange"
            case .replaceSoon, .replaceNow: return "red"
            }
        }
        
        static func < (lhs: ComponentHealth, rhs: ComponentHealth) -> Bool {
            let order: [ComponentHealth] = [.excellent, .good, .serviceDue, .replaceSoon, .replaceNow]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Health Result
    
    struct ComponentHealthResult {
        let component: ComponentType
        let status: ComponentHealth
        let mileagePercentage: Double
        let warnings: [Warning]
        let recommendations: [String]
        let estimatedRemainingKm: Double?
        
        var needsAttention: Bool {
            status >= .serviceDue
        }
    }
    
    struct ChainMaintenanceResult {
        let waxDue: Bool
        let kmSinceWax: Double?
        let kmUntilWax: Double?
        
        let cleanDue: Bool
        let kmSinceClean: Double?
        let kmUntilClean: Double?
        
        let replacementDue: Bool
        let chainWearPercentage: Double?
        let wearLimit: Double
        
        let overallStatus: ComponentHealth
        let warnings: [String]
    }
    
    enum Warning {
        case wearLimitReached(percentage: Double, limit: Double)
        case exceedsLifespan(percentage: Double)
        case maintenanceOverdue(type: String, kmOverdue: Double)
        case ageWarning(days: Int)
        
        var message: String {
            switch self {
            case .wearLimitReached(let pct, let limit):
                return "⛔️ Chain wear at \(String(format: "%.2f%%", pct)) (limit: \(String(format: "%.2f%%", limit))). Replace immediately."
            case .exceedsLifespan(let pct):
                return "⚠️ Component at \(String(format: "%.0f%%", pct)) of expected lifespan."
            case .maintenanceOverdue(let type, let km):
                return "⚠️ \(type) overdue by \(String(format: "%.0f km", km))."
            case .ageWarning(let days):
                return "ℹ️ Component is \(days) days old. Consider condition inspection."
            }
        }
    }
    
    // MARK: - Component Health Calculation
    
    static func calculateComponentHealth(for component: ComponentTracking) -> ComponentHealthResult {
        var warnings: [Warning] = []
        
        let mileage = component.componentMileageKm
        let expectedLifespan = component.component.expectedLifespanKm
        let percentage = (mileage / expectedLifespan) * 100
        
        // Age warning
        if component.componentAgeDays > 730 {  // 2 years
            warnings.append(.ageWarning(days: component.componentAgeDays))
        }
        
        // Mileage warnings
        if percentage >= 100 {
            warnings.append(.exceedsLifespan(percentage: percentage))
        }
        
        // Determine status
        let status: ComponentHealth
        if percentage >= 100 {
            status = .replaceNow
        } else if percentage >= 85 {
            status = .replaceSoon
        } else if percentage >= 70 {
            status = .serviceDue
        } else if percentage >= 50 {
            status = .good
        } else {
            status = .excellent
        }
        
        // Calculate remaining km
        let remaining = max(0, expectedLifespan - mileage)
        
        // Generate recommendations
        let recommendations = generateComponentRecommendations(
            component: component.component,
            status: status,
            percentage: percentage,
            remainingKm: remaining
        )
        
        return ComponentHealthResult(
            component: component.component,
            status: status,
            mileagePercentage: percentage,
            warnings: warnings,
            recommendations: recommendations,
            estimatedRemainingKm: remaining
        )
    }
    
    // MARK: - Chain-Specific Maintenance
    
    static func calculateChainMaintenance(for chain: ComponentTracking, speedCount: Int = 11) -> ChainMaintenanceResult {
        guard let lubeType = chain.lubeType else {
            return ChainMaintenanceResult(
                waxDue: false,
                kmSinceWax: nil,
                kmUntilWax: nil,
                cleanDue: false,
                kmSinceClean: nil,
                kmUntilClean: nil,
                replacementDue: false,
                chainWearPercentage: nil,
                wearLimit: 0.5,
                overallStatus: .excellent,
                warnings: ["Set chain lube type for maintenance tracking"]
            )
        }
        
        var warnings: [String] = []
        
        // Wax/Lube due?
        let waxInterval = lubeType.intervalKm
        let kmSinceWax = chain.kmSinceLastWax ?? chain.componentMileageKm
        let waxDue = kmSinceWax >= waxInterval
        let kmUntilWax = max(0, waxInterval - kmSinceWax)
        
        if waxDue {
            let overdue = kmSinceWax - waxInterval
            warnings.append("\(lubeType.shortName) overdue by \(String(format: "%.0f km", overdue))")
        } else if kmUntilWax <= 100 {
            warnings.append("\(lubeType.shortName) due in \(String(format: "%.0f km", kmUntilWax))")
        }
        
        // Clean due?
        let cleanInterval = lubeType.cleaningIntervalKm
        let kmSinceClean = chain.kmSinceLastClean ?? chain.componentMileageKm
        let cleanDue = kmSinceClean >= cleanInterval
        let kmUntilClean = max(0, cleanInterval - kmSinceClean)
        
        if cleanDue && lubeType != .hotWax {  // Hot wax doesn't need separate cleaning
            let overdue = kmSinceClean - cleanInterval
            warnings.append("Chain clean overdue by \(String(format: "%.0f km", overdue))")
        }
        
        // Chain wear check
        let wearLimit = speedCount >= 11 ? 0.5 : 0.75  // 11+ speed: 0.5%, 8-10 speed: 0.75%
        let wearPercentage = chain.chainWearPercentage ?? 0.0
        let replacementDue = wearPercentage >= wearLimit
        
        if replacementDue {
            warnings.append("⛔️ Chain wear at \(String(format: "%.2f%%", wearPercentage)) - Replace immediately to save cassette")
        } else if wearPercentage >= wearLimit * 0.8 {  // 80% of limit
            warnings.append("Chain wear at \(String(format: "%.2f%%", wearPercentage)) - Check more frequently")
        }
        
        // Measurement staleness: mileage-based estimates drift, so prompt
        // for a fresh gauge reading when it has been a while
        if let kmSinceMeasurement = chain.kmSinceWearMeasurement {
            if kmSinceMeasurement > 500 {
                warnings.append("Wear last measured \(String(format: "%.0f km", kmSinceMeasurement)) ago - Re-check with a gauge")
            }
        } else if chain.componentMileageKm > 500 {
            warnings.append("Chain wear never measured - Check with a chain gauge")
        }
        
        // Overall status
        let overallStatus: ComponentHealth
        if replacementDue {
            overallStatus = .replaceNow
        } else if waxDue || cleanDue {
            overallStatus = .serviceDue
        } else if kmUntilWax <= 100 || kmUntilClean <= 100 {
            overallStatus = .good
        } else {
            overallStatus = .excellent
        }
        
        return ChainMaintenanceResult(
            waxDue: waxDue,
            kmSinceWax: kmSinceWax,
            kmUntilWax: kmUntilWax,
            cleanDue: cleanDue,
            kmSinceClean: kmSinceClean,
            kmUntilClean: kmUntilClean,
            replacementDue: replacementDue,
            chainWearPercentage: wearPercentage,
            wearLimit: wearLimit,
            overallStatus: overallStatus,
            warnings: warnings
        )
    }
    
    // MARK: - Recommendations
    
    private static func generateComponentRecommendations(
        component: ComponentType,
        status: ComponentHealth,
        percentage: Double,
        remainingKm: Double
    ) -> [String] {
        var recommendations: [String] = []
        
        switch status {
        case .excellent:
            recommendations.append("\(component.displayName) is in excellent condition.")
            recommendations.append("Estimated \(String(format: "%.0f km", remainingKm)) remaining.")
            
        case .good:
            recommendations.append("\(component.displayName) is performing well.")
            recommendations.append("Approximately \(String(format: "%.0f km", remainingKm)) remaining.")
            if component == .chain {
                recommendations.append("Check chain wear with gauge monthly.")
            }
            
        case .serviceDue:
            recommendations.append("\(component.displayName) approaching end of life.")
            if component == .chain {
                recommendations.append("Check chain wear with gauge before each ride.")
                recommendations.append("Have replacement chain ready.")
            } else {
                recommendations.append("Inspect for wear and prepare for replacement.")
            }
            
        case .replaceSoon:
            recommendations.append("Replace \(component.displayName) within next 200-500 km.")
            if component == .chain {
                recommendations.append("Replacing now will save your cassette and chainrings.")
            }
            
        case .replaceNow:
            recommendations.append("Replace \(component.displayName) immediately.")
            if component == .chain {
                recommendations.append("Worn chain is damaging cassette and chainrings.")
                recommendations.append("Each ride on worn chain shortens cassette life.")
            }
        }
        
        // Component-specific advice
        if component == .chain {
            recommendations.append("Use a chain wear gauge (Park CC-3.2) for accurate measurement.")
        } else if component == .cassette {
            recommendations.append("Replace chain at 0.5% wear to maximize cassette life.")
        } else if component == .brakePads {
            recommendations.append("Check pad thickness before long rides or descents.")
        }
        
        return recommendations
    }
    
    // MARK: - Bike-Level Maintenance Summary
    
    struct BikeMaintenanceSummary {
        let componentsNeedingAttention: [ComponentTracking]
        let chainStatus: ChainMaintenanceResult?
        let worstComponentHealth: ComponentHealth
        let upcomingMaintenance: [String]
        
        var needsAttention: Bool {
            worstComponentHealth >= .serviceDue
        }
    }
    
    static func calculateBikeMaintenance(
        components: [ComponentTracking],
        speedCount: Int = 11
    ) -> BikeMaintenanceSummary {
        var needsAttention: [ComponentTracking] = []
        var upcoming: [String] = []
        var worstHealth: ComponentHealth = .excellent
        
        let chain = components.first { $0.component == .chain }
        let chainStatus = chain.map { calculateChainMaintenance(for: $0, speedCount: speedCount) }
        
        // Check chain status first
        if let chainStatus = chainStatus {
            if chainStatus.overallStatus >= .serviceDue, let chain = chain {
                needsAttention.append(chain)
            }
            worstHealth = max(worstHealth, chainStatus.overallStatus)
            
            // Add upcoming maintenance
            if let kmUntil = chainStatus.kmUntilWax, kmUntil <= 200 {
                upcoming.append("Chain wax in \(String(format: "%.0f km", kmUntil))")
            }
        }
        
        // Check other components
        for component in components where component.component != .chain {
            let health = calculateComponentHealth(for: component)
            worstHealth = max(worstHealth, health.status)
            
            if health.needsAttention {
                needsAttention.append(component)
            }
            
            if let remaining = health.estimatedRemainingKm, remaining <= 500, health.status < .replaceSoon {
                upcoming.append("\(component.component.displayName) in \(String(format: "%.0f km", remaining))")
            }
        }
        
        return BikeMaintenanceSummary(
            componentsNeedingAttention: needsAttention,
            chainStatus: chainStatus,
            worstComponentHealth: worstHealth,
            upcomingMaintenance: upcoming
        )
    }
}
