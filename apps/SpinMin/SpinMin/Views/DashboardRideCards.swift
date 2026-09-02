//
//  DashboardRideCards.swift
//  SpinMin
//
//  Compact ride cards for dashboard display
//

import SwiftUI

// MARK: - Today's Ride Card

struct TodayRideCard: View {
    let ride: ScheduledRide
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Time
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(ride.scheduledDate, style: .time)
                        .bodyLarge()
                        .monospacedDigit()
                    
                    if let hoursUntil = hoursUntilRide {
                        Text(hoursUntil)
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 60, alignment: .leading)
                
                // Details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(ride.name)
                            .bodyLarge()
                        
                        Spacer()
                        
                        statusBadge
                    }
                    
                    HStack {
                        Text(ride.rideType.displayName)
                            .captionMedium()
                        
                        Text("   ")
                        
                        Text(formatDuration(ride.duration))
                            .captionMedium()
                        
                        if let distance = ride.distance {
                            Text("   ")
                            Text(String(format: "%.0f km", distance))
                                .captionMedium()
                        }
                        
                        if hasWeatherAlert {
                            Text("   ")
                            Text("⚠️")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
    
    private var statusBadge: some View {
        Group {
            if ride.isPrepared {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var hasWeatherAlert: Bool {
        guard let temp = ride.temperature, let precip = ride.precipitationChance else {
            return false
        }
        return temp < 5 || temp > 35 || precip > 0.5
    }
    
    private var hoursUntilRide: String? {
        let hours = ride.hoursUntil
        if hours < 1 {
            let minutes = Int(hours * 60)
            return minutes > 0 ? "in \(minutes)m" : "now"
        } else if hours < 24 {
            return "in \(Int(hours))h"
        }
        return nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Prep Needed Card

struct PrepNeededCard: View {
    let ride: ScheduledRide
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon + time
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    
                    if let hoursUntil = hoursUntilText {
                        Text(hoursUntil)
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 40, alignment: .leading)
                
                // Details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(ride.name)
                        .bodyLarge()
                    
                    HStack {
                        Text(ride.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                            .captionMedium()
                        
                        Text("   ")
                        
                        Text(ride.rideType.displayName)
                            .captionMedium()
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
    
    private var hoursUntilText: String? {
        let hours = ride.hoursUntil
        if hours < 24 {
            return "in \(Int(hours))h"
        } else {
            let days = Int(hours / 24)
            return "in \(days)d"
        }
    }
}
