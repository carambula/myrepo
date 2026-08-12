//
//  RideHistoryView.swift
//  SpinMin
//
//  View ride logs for a wheelset
//

import SwiftUI
import SwiftData

struct RideHistoryView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    
    var sortedRides: [RideLog] {
        wheelset.rides.sorted { $0.rideDate > $1.rideDate }
    }
    
    var totalDistance: Double {
        wheelset.rides.reduce(0) { $0 + $1.distanceKm }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Summary stats
                HStack(spacing: DesignSystem.Spacing.xl) {
                    StatCard(
                        label: "Total Rides",
                        value: "\(wheelset.totalRides)",
                        icon: "list.bullet"
                    )
                    
                    StatCard(
                        label: "Total Distance",
                        value: String(format: "%.0f km", totalDistance),
                        icon: "map"
                    )
                    
                    if wheelset.totalRides > 0 {
                        StatCard(
                            label: "Avg per Ride",
                            value: String(format: "%.1f km", totalDistance / Double(wheelset.totalRides)),
                            icon: "chart.bar"
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                
                // Ride list
                if sortedRides.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(sortedRides) { ride in
                            RideLogCard(ride: ride)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Color.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "bicycle.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Rides Logged")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Use 'Log Ride' to track mileage on this wheelset")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundAccent()
            
            Text(value)
                .titleMedium()
                .foregroundHeadline()
                .monospacedDigit()
            
            Text(label)
                .captionSmall()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

private struct RideLogCard: View {
    let ride: RideLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.rideName)
                        .bodyLarge()
                        .foregroundHeadline()
                    
                    Text(ride.rideDate.formatted(date: .abbreviated, time: .omitted))
                        .captionMedium()
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", ride.distanceKm))
                        .titleMedium()
                        .foregroundAccent()
                        .monospacedDigit()
                    Text("km")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                }
            }
            
            if let terrain = ride.terrain {
                HStack(spacing: 4) {
                    Image(systemName: "mountain.2")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(terrain.displayName)
                        .captionMedium()
                        .foregroundStyle(.secondary)
                }
            }
            
            if !ride.notes.isEmpty {
                Text(ride.notes)
                    .captionMedium()
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.top, 2)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

#Preview {
    NavigationStack {
        RideHistoryView(wheelset: Wheelset(
            name: "Race Wheels",
            wheelDiameter: .road700c,
            tireWidthMM: 28
        ))
        .environment(ThemeManager.shared)
        .modelContainer(for: [Wheelset.self, RideLog.self], inMemory: true)
    }
}
