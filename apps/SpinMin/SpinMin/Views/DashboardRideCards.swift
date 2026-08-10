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
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(ride.scheduledDate, style: .time)
                        .h3()
                        .foregroundHeadline()
                    
                    if let hoursUntil = hoursUntilRide {
                        Text(hoursUntil)
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 70)
                
                // Details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(ride.name)
                            .bodyLarge()
                            .foregroundHeadline()
                        
                        Spacer()
                        
                        if ride.isPrepared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: ride.rideType.icon)
                            .font(.caption)
                        Text(ride.rideType.displayName)
                            .captionMedium()
                        
                        Text("   ")
                        
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDuration(ride.duration))
                            .captionMedium()
                        
                        if let distance = ride.distance {
                            Text("   ")
                            Image(systemName: "map")
                                .font(.caption)
                            Text(String(format: "%.0f km", distance))
                                .captionMedium()
                        }
                    }
                    .foregroundStyle(.secondary)
                    
                    // Weather alert
                    if let temp = ride.temperature, let precip = ride.precipitationChance {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            let tempCategory = WeatherService.TemperatureCategory(celsius: temp)
                            let precipLevel = WeatherService.PrecipitationLevel(probability: precip)
                            
                            Text(tempCategory.emoji)
                            Text(String(format: "%.0f°C", temp))
                                .captionSmall()
                            
                            Text(precipLevel.emoji)
                            Text("\(Int(precip * 100))%")
                                .captionSmall()
                            
                            if needsWeatherAttention(temp: temp, precip: precip) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var hoursUntilRide: String? {
        let hours = ride.hoursUntil
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "in \(minutes)m"
        } else if hours < 24 {
            return "in \(Int(hours))h"
        }
        return nil
    }
    
    private func needsWeatherAttention(temp: Double, precip: Double) -> Bool {
        return temp < 5 || temp > 35 || precip > 0.5
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
                // Icon
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: ride.rideType.icon)
                        .font(.title2)
                        .foregroundStyle(.orange)
                    
                    if let hoursUntil = hoursUntilText {
                        Text(hoursUntil)
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 60)
                
                // Details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(ride.name)
                            .bodyLarge()
                        
                        Spacer()
                        
                        Label("Prep", systemImage: "exclamationmark.circle.fill")
                            .captionSmall()
                            .foregroundStyle(.orange)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(ride.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                            .captionMedium()
                        
                        Text("   ")
                        
                        Text(ride.rideType.displayName)
                            .captionMedium()
                    }
                    .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.orange.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
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
