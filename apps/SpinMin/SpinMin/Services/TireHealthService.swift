//
//  TireHealthService.swift
//  SpinMin
//
//  Calculate tire health status based on mileage, age, and visual indicators
//

import Foundation

struct TireHealthService {
    
    // MARK: - Health Status
    
    enum HealthStatus: String, Comparable {
        case excellent = "excellent"  // < 25% wear
        case good = "good"            // 25-50% wear
        case fair = "fair"            // 50-75% wear
        case worn = "worn"            // 75-90% wear
        case replaceSoon = "replace_soon"  // 90-100% wear
        case replaceNow = "replace_now"    // > 100% wear or critical condition
        case unsafe = "unsafe"        // Casing exposure or critical damage
        
        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .worn: return "Worn"
            case .replaceSoon: return "Replace Soon"
            case .replaceNow: return "Replace Now"
            case .unsafe: return "UNSAFE - Do Not Ride"
            }
        }
        
        var emoji: String {
            switch self {
            case .excellent: return "🟢"
            case .good: return "🟢"
            case .fair: return "🟡"
            case .worn: return "🟠"
            case .replaceSoon: return "🔴"
            case .replaceNow: return "🔴"
            case .unsafe: return "⛔️"
            }
        }
        
        var color: String {  // Semantic color name
            switch self {
            case .excellent, .good: return "green"
            case .fair: return "yellow"
            case .worn, .replaceSoon: return "orange"
            case .replaceNow, .unsafe: return "red"
            }
        }
        
        static func < (lhs: HealthStatus, rhs: HealthStatus) -> Bool {
            let order: [HealthStatus] = [.excellent, .good, .fair, .worn, .replaceSoon, .replaceNow, .unsafe]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Health Result
    
    struct HealthResult {
        let status: HealthStatus
        let mileagePercentage: Double
        let ageYears: Double
        let warnings: [Warning]
        let recommendations: [String]
        let estimatedRemainingKm: Double?
        
        var hasWarnings: Bool {
            !warnings.isEmpty
        }
        
        var criticalWarnings: [Warning] {
            warnings.filter { $0.severity == .critical }
        }
        
        var hasCriticalWarnings: Bool {
            !criticalWarnings.isEmpty
        }
    }
    
    enum Warning: Equatable {
        case casingExposure
        case sidewallCracks
        case aged(years: Double)
        case overMileage(percentage: Double)
        case squaredProfile
        case frequentPunctures(count: Int)
        case cuts
        case inspectionOverdue(days: Int)
        
        var severity: WarningSeverity {
            switch self {
            case .casingExposure:
                return .critical
            case .aged(let years):
                return years >= 10 ? .critical : .high
            case .sidewallCracks:
                return .high
            case .overMileage(let percentage):
                return percentage >= 100 ? .high : .medium
            case .squaredProfile, .frequentPunctures, .cuts:
                return .medium
            case .inspectionOverdue:
                return .low
            }
        }
        
        var message: String {
            switch self {
            case .casingExposure:
                return "⛔️ CRITICAL: Tire casing exposed. Do not ride. Replace immediately."
            case .sidewallCracks:
                return "⚠️ Sidewall cracks detected. Replace before next ride."
            case .aged(let years):
                if years >= 10 {
                    return "⛔️ CRITICAL: Tire is \(String(format: "%.1f", years)) years old (10+ year limit). Replace immediately."
                } else if years >= 5 {
                    return "⚠️ Tire is \(String(format: "%.1f", years)) years old. Recommended 5-6 year limit."
                } else {
                    return "⚠️ Tire is \(String(format: "%.1f", years)) years old. Monitor condition closely."
                }
            case .overMileage(let percentage):
                return "⚠️ Tire has reached \(String(format: "%.0f", percentage))% of expected lifespan."
            case .squaredProfile:
                return "⚠️ Tire profile is squared off. Reduced cornering grip."
            case .frequentPunctures(let count):
                return "⚠️ \(count) punctures recorded. Tire may be worn through."
            case .cuts:
                return "⚠️ Cuts detected. Inspect for casing damage."
            case .inspectionOverdue(let days):
                return "ℹ️ Last inspection was \(days) days ago. Visual check recommended."
            }
        }
        
        var shortMessage: String {
            switch self {
            case .casingExposure: return "Casing exposed"
            case .sidewallCracks: return "Sidewall cracks"
            case .aged(let years): return "\(String(format: "%.1f", years)) years old"
            case .overMileage(let pct): return "\(String(format: "%.0f", pct))% lifespan"
            case .squaredProfile: return "Squared profile"
            case .frequentPunctures(let count): return "\(count) punctures"
            case .cuts: return "Cuts detected"
            case .inspectionOverdue: return "Inspection overdue"
            }
        }
    }
    
    enum WarningSeverity {
        case critical  // Do not ride
        case high      // Replace before next ride
        case medium    // Replace soon
        case low       // Monitor
    }
    
    // MARK: - Health Calculation
    
    /// Calculate comprehensive tire health status
    static func calculateHealth(for tire: TireTracking) -> HealthResult {
        var warnings: [Warning] = []
        
        // Critical visual indicators
        if tire.hasCasingExposure {
            warnings.append(.casingExposure)
            return HealthResult(
                status: .unsafe,
                mileagePercentage: tire.mileageWearPercentage,
                ageYears: tire.tireAgeYears,
                warnings: warnings,
                recommendations: ["Do not ride this tire. Replace immediately."],
                estimatedRemainingKm: 0
            )
        }
        
        if tire.hasSidewallCracks {
            warnings.append(.sidewallCracks)
        }
        
        if tire.hasCuts {
            warnings.append(.cuts)
        }
        
        // Age-based warnings
        let ageYears = tire.tireAgeYears
        if ageYears >= 10 {
            warnings.append(.aged(years: ageYears))
            return HealthResult(
                status: .unsafe,
                mileagePercentage: tire.mileageWearPercentage,
                ageYears: ageYears,
                warnings: warnings,
                recommendations: [
                    "Tire exceeds 10-year age limit.",
                    "Rubber compounds degrade over time regardless of mileage.",
                    "Replace immediately."
                ],
                estimatedRemainingKm: 0
            )
        } else if ageYears >= 5 {
            warnings.append(.aged(years: ageYears))
        } else if ageYears >= 3 {
            warnings.append(.aged(years: ageYears))
        }
        
        // Mileage-based assessment
        let mileagePercentage = tire.mileageWearPercentage
        if mileagePercentage >= 100 {
            warnings.append(.overMileage(percentage: mileagePercentage))
        }
        
        // Visual wear indicators
        if tire.hasSquaredProfile {
            warnings.append(.squaredProfile)
        }
        
        // Puncture tracking
        if tire.punctureCount >= 5 {
            warnings.append(.frequentPunctures(count: tire.punctureCount))
        } else if tire.punctureCount >= 3 {
            warnings.append(.frequentPunctures(count: tire.punctureCount))
        }
        
        // Inspection reminder
        if let lastInspection = tire.lastInspectionDate {
            let daysSinceInspection = Calendar.current.dateComponents(
                [.day],
                from: lastInspection,
                to: Date()
            ).day ?? 0
            
            if daysSinceInspection > 90 {  // 3 months
                warnings.append(.inspectionOverdue(days: daysSinceInspection))
            }
        }
        
        // Determine overall health status
        let status = determineHealthStatus(
            mileagePercentage: mileagePercentage,
            ageYears: ageYears,
            hasHighWarnings: warnings.contains { $0.severity == .high },
            hasCriticalWarnings: warnings.contains { $0.severity == .critical }
        )
        
        // Calculate estimated remaining kilometers
        let estimatedRemaining = calculateRemainingKm(
            tire: tire,
            status: status
        )
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            status: status,
            warnings: warnings,
            estimatedRemainingKm: estimatedRemaining
        )
        
        return HealthResult(
            status: status,
            mileagePercentage: mileagePercentage,
            ageYears: ageYears,
            warnings: warnings,
            recommendations: recommendations,
            estimatedRemainingKm: estimatedRemaining
        )
    }
    
    private static func determineHealthStatus(
        mileagePercentage: Double,
        ageYears: Double,
        hasHighWarnings: Bool,
        hasCriticalWarnings: Bool
    ) -> HealthStatus {
        // Critical conditions
        if hasCriticalWarnings {
            return .unsafe
        }
        
        // High warnings
        if hasHighWarnings || mileagePercentage >= 110 || ageYears >= 6 {
            return .replaceNow
        }
        
        // Mileage-based with age consideration
        if mileagePercentage >= 90 || ageYears >= 5 {
            return .replaceSoon
        }
        
        if mileagePercentage >= 75 || ageYears >= 4 {
            return .worn
        }
        
        if mileagePercentage >= 50 || ageYears >= 3 {
            return .fair
        }
        
        if mileagePercentage >= 25 {
            return .good
        }
        
        return .excellent
    }
    
    private static func calculateRemainingKm(
        tire: TireTracking,
        status: HealthStatus
    ) -> Double? {
        if status == .unsafe || status == .replaceNow {
            return 0
        }
        
        let remainingMileage = tire.expectedLifespanKm - tire.tireMileageKm
        return max(0, remainingMileage)
    }
    
    private static func generateRecommendations(
        status: HealthStatus,
        warnings: [Warning],
        estimatedRemainingKm: Double?
    ) -> [String] {
        var recommendations: [String] = []
        
        switch status {
        case .excellent:
            recommendations.append("Tire is in excellent condition.")
            if let remaining = estimatedRemainingKm {
                recommendations.append("Estimated \(String(format: "%.0f", remaining)) km remaining.")
            }
            
        case .good:
            recommendations.append("Tire is performing well.")
            recommendations.append("Continue monitoring wear indicators.")
            if let remaining = estimatedRemainingKm {
                recommendations.append("Approximately \(String(format: "%.0f", remaining)) km remaining.")
            }
            
        case .fair:
            recommendations.append("Tire is showing moderate wear.")
            recommendations.append("Inspect visually every few rides.")
            if let remaining = estimatedRemainingKm {
                recommendations.append("Approximately \(String(format: "%.0f", remaining)) km remaining.")
            }
            
        case .worn:
            recommendations.append("Tire is approaching end of life.")
            recommendations.append("Start shopping for replacement tires.")
            recommendations.append("Inspect before each ride.")
            
        case .replaceSoon:
            recommendations.append("Replace this tire in the next 1-2 weeks.")
            recommendations.append("Have a replacement tire ready.")
            recommendations.append("Avoid aggressive riding or rough terrain.")
            
        case .replaceNow:
            recommendations.append("Replace this tire before your next ride.")
            if warnings.contains(where: { $0.severity == .high }) {
                recommendations.append("Visual wear indicators show replacement needed.")
            }
            
        case .unsafe:
            recommendations.append("DO NOT RIDE WITH THIS TIRE.")
            recommendations.append("Replace immediately.")
        }
        
        // Add specific recommendations for warnings
        if warnings.contains(where: { if case .aged = $0 { return true } else { return false } }) {
            recommendations.append("Consider upgrading to a newer tire model with updated compounds.")
        }
        
        if warnings.contains(where: { if case .frequentPunctures = $0 { return true } else { return false } }) {
            recommendations.append("Consider a more puncture-resistant tire for your riding conditions.")
        }
        
        return recommendations
    }
    
    // MARK: - Quick Status
    
    /// Get a simple health indicator for dashboard display
    static func quickStatus(for tire: TireTracking) -> (emoji: String, percentage: String, status: String) {
        let health = calculateHealth(for: tire)
        let pct = String(format: "%.0f%%", health.mileagePercentage)
        return (health.status.emoji, pct, health.status.displayName)
    }
}
