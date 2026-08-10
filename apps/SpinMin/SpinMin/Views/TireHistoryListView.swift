//
//  TireHistoryListView.swift
//  SpinMin
//
//  View historical tire changes and lifecycle
//

import SwiftUI
import SwiftData

struct TireHistoryListView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    
    var sortedHistory: [TireHistory] {
        wheelset.tireHistory.sorted { $0.removeDate > $1.removeDate }
    }
    
    var body: some View {
        ScrollView {
            if sortedHistory.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(sortedHistory) { history in
                        TireHistoryCard(history: history)
                    }
                }
                .padding(DesignSystem.Spacing.screenHorizontalPadding)
            }
        }
        .background(DesignSystem.Color.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Tire History")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Replaced tires will appear here for reference")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

struct TireHistoryCard: View {
    let history: TireHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(history.tirePosition.displayName)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Text("   ")
                            .foregroundStyle(.secondary)
                        Text(history.removeDate.formatted(date: .abbreviated, time: .omitted))
                            .captionMedium()
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(history.displayName)
                        .titleMedium()
                        .foregroundHeadline()
                    
                    Text(history.reason.displayName)
                        .captionMedium()
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(reasonColor.opacity(0.15))
                        .foregroundStyle(reasonColor)
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Stats
            HStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Mileage")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f km", history.totalMileageKm))
                        .bodyLarge()
                        .monospacedDigit()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f months", history.durationMonths))
                        .bodyLarge()
                        .monospacedDigit()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg per Day")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f km", history.averageKmPerDay))
                        .bodyLarge()
                        .monospacedDigit()
                }
            }
            
            // Install/Remove dates
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installed")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Text(history.installDate.formatted(date: .abbreviated, time: .omitted))
                        .captionMedium()
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Removed")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Text(history.removeDate.formatted(date: .abbreviated, time: .omitted))
                        .captionMedium()
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.Color.background)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            
            // Wear indicators at removal
            if history.hadSquaredProfile || history.hadSidewallCracks || history.hadCasingExposure {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Condition at Removal:")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if history.hadSquaredProfile {
                            ConditionBadge(label: "Squared", icon: "triangle")
                        }
                        if history.hadSidewallCracks {
                            ConditionBadge(label: "Cracks", icon: "exclamationmark.triangle")
                        }
                        if history.hadCasingExposure {
                            ConditionBadge(label: "Casing Exposed", icon: "exclamationmark.octagon")
                        }
                    }
                }
            }
            
            // Condition notes
            if !history.conditionAtRemoval.isEmpty {
                Text(history.conditionAtRemoval)
                    .captionMedium()
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Color.background)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            // Punctures if any
            if history.finalPunctureCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    Text("\(history.finalPunctureCount) punctures")
                        .captionMedium()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    private var reasonColor: Color {
        switch history.reason {
        case .worn: return .orange
        case .damaged: return .red
        case .puncture: return .red
        case .aged: return .orange
        case .upgrade: return .blue
        case .seasonal: return .green
        case .experimental: return .purple
        }
    }
}

struct ConditionBadge: View {
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .cornerRadius(DesignSystem.CornerRadius.xs)
    }
}

#Preview {
    NavigationStack {
        TireHistoryListView(wheelset: Wheelset(
            name: "Race Wheels",
            wheelDiameter: .road700c,
            tireWidthMM: 28
        ))
        .environment(ThemeManager.shared)
        .modelContainer(for: [Wheelset.self, TireHistory.self], inMemory: true)
    }
}
