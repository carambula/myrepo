//
//  TireManagementView.swift
//  SpinMin
//
//  Comprehensive tire management - add, replace, inspect, view history
//

import SwiftUI
import SwiftData

struct TireManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    
    @State private var selectedTab = 0
    @State private var showingAddTire = false
    @State private var showingReplaceTire: TirePosition? = nil
    @State private var showingInspection: TirePosition? = nil
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Current Status Tab
            CurrentTiresView(
                wheelset: wheelset,
                onAddTire: { showingAddTire = true },
                onReplaceTire: { position in showingReplaceTire = position },
                onInspect: { position in showingInspection = position }
            )
            .tabItem {
                Label("Current", systemImage: "gauge")
            }
            .tag(0)
            
            // History Tab
            TireHistoryListView(wheelset: wheelset)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)
            
            // Rides Tab
            RideHistoryView(wheelset: wheelset)
                .tabItem {
                    Label("Rides", systemImage: "list.bullet")
                }
                .tag(2)
        }
        .navigationTitle(wheelset.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddTire) {
            AddTireTrackingView(wheelset: wheelset)
        }
        .sheet(item: $showingReplaceTire) { position in
            ReplaceTireView(wheelset: wheelset, position: position)
        }
        .sheet(item: $showingInspection) { position in
            TireInspectionView(wheelset: wheelset, position: position)
        }
    }
}

// MARK: - Current Tires Tab

struct CurrentTiresView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    let onAddTire: () -> Void
    let onReplaceTire: (TirePosition) -> Void
    let onInspect: (TirePosition) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Wheelset overview
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.system(size: 40))
                            .foregroundAccent()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Odometer")
                                .bodyMedium()
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f km", wheelset.totalMileageKm))
                                .displaySmall()
                                .foregroundAccent()
                                .monospacedDigit()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Rides")
                                .bodyMedium()
                                .foregroundStyle(.secondary)
                            Text("\(wheelset.totalRides)")
                                .displaySmall()
                                .foregroundAccent()
                                .monospacedDigit()
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Color.surfaceElevated)
                .cornerRadius(DesignSystem.CornerRadius.lg)
                
                // Front tire
                if let frontTire = wheelset.frontTire {
                    TireDetailCard(
                        tire: frontTire,
                        onReplace: { onReplaceTire(.front) },
                        onInspect: { onInspect(.front) }
                    )
                } else {
                    EmptyTireCard(position: .front, onAdd: onAddTire)
                }
                
                // Rear tire
                if let rearTire = wheelset.rearTire {
                    TireDetailCard(
                        tire: rearTire,
                        onReplace: { onReplaceTire(.rear) },
                        onInspect: { onInspect(.rear) }
                    )
                } else {
                    EmptyTireCard(position: .rear, onAdd: onAddTire)
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
        .background(DesignSystem.Color.background)
    }
}

struct TireDetailCard: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let tire: TireTracking
    let onReplace: () -> Void
    let onInspect: () -> Void
    
    var body: some View {
        let health = TireHealthService.calculateHealth(for: tire)
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tire.tirePosition.displayName)
                            .bodyLarge()
                            .foregroundStyle(.secondary)
                        Text(health.status.emoji)
                            .font(.system(size: 20))
                    }
                    Text(tire.displayName)
                        .titleMedium()
                        .foregroundHeadline()
                }
                
                Spacer()
                
                Text(health.status.displayName)
                    .captionMedium()
                    .foregroundStyle(statusColor(for: health.status))
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(statusColor(for: health.status).opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.xs)
            }
            
            Divider()
            
            // Stats
            HStack(spacing: DesignSystem.Spacing.xl) {
                StatBlock(
                    label: "Mileage",
                    value: String(format: "%.0f km", tire.tireMileageKm),
                    icon: "gauge"
                )
                
                StatBlock(
                    label: "Age",
                    value: "\(tire.tireAgeDays) days",
                    icon: "calendar"
                )
                
                StatBlock(
                    label: "Wear",
                    value: String(format: "%.0f%%", health.mileagePercentage),
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expected Lifespan")
                        .captionMedium()
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let remaining = health.estimatedRemainingKm, remaining > 0 {
                        Text("\(String(format: "%.0f", remaining)) km remaining")
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor(for: health.status))
                            .frame(width: geometry.size.width * min(1.0, health.mileagePercentage / 100), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Warnings
            if health.hasWarnings {
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(health.warnings.prefix(3).enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: warningIcon(for: warning.severity))
                                .foregroundStyle(warningColor(for: warning.severity))
                                .font(.system(size: 14))
                            Text(warning.shortMessage)
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: onInspect) {
                    Label("Inspect", systemImage: "magnifyingglass")
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .medium))
                
                Button(action: onReplace) {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .tertiary, size: .medium))
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    private func statusColor(for status: TireHealthService.HealthStatus) -> Color {
        switch status.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    private func warningIcon(for severity: TireHealthService.WarningSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle"
        case .low: return "info.circle"
        }
    }
    
    private func warningColor(for severity: TireHealthService.WarningSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }
}

struct StatBlock: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            Text(value)
                .bodyLarge()
                .foregroundHeadline()
                .monospacedDigit()
            Text(label)
                .captionSmall()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyTireCard: View {
    let position: TirePosition
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "plus.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No \(position.displayName) Tire Tracked")
                .bodyMedium()
                .foregroundHeadline()
            
            Text("Start tracking to monitor mileage and replacement timing")
                .captionMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAdd) {
                Label("Start Tracking", systemImage: "plus")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// Make TirePosition Identifiable for sheet binding
extension TirePosition: Identifiable {
    var id: String { rawValue }
}

#Preview {
    NavigationStack {
        TireManagementView(wheelset: Wheelset(
            name: "Race Wheels",
            wheelDiameter: .road700c,
            tireWidthMM: 28
        ))
        .environment(ThemeManager.shared)
        .modelContainer(for: [Wheelset.self, TireTracking.self], inMemory: true)
    }
}
