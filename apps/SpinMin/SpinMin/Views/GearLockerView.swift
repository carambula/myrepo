//
//  GearLockerView.swift
//  SpinMin
//
//  UI for tracking personal gear (helmets, shoes, tools, accessories)
//

import SwiftUI
import SwiftData

struct GearLockerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @Query(filter: #Predicate<GearItem> { $0.retirementDate == nil }, sort: \GearItem.purchaseDate, order: .reverse)
    private var activeGear: [GearItem]
    
    @State private var selectedCategory: GearCategory? = nil
    @State private var showingAddGear = false
    @State private var showingRetiredGear = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary card
                summaryCard
                
                // Category filter
                categoryFilter
                
                Divider()
                
                // Gear list
                if filteredGear.isEmpty {
                    emptyStateView
                } else {
                    gearListView
                }
            }
            .navigationTitle("Gear Locker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddGear = true
                        } label: {
                            Label("Add Gear", systemImage: "plus")
                        }
                        
                        Button {
                            showingRetiredGear = true
                        } label: {
                            Label("Retired Gear", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddGear) {
                AddGearView()
            }
            .sheet(isPresented: $showingRetiredGear) {
                RetiredGearView()
            }
        }
    }
    
    private var filteredGear: [GearItem] {
        guard let category = selectedCategory else {
            return activeGear
        }
        return activeGear.filter { $0.gearType.category == category }
    }
    
    private var summaryCard: some View {
        let summary = GearTrackingService.gearSummary(for: activeGear)
        
        return HStack(spacing: DesignSystem.Spacing.lg) {
            SummaryBlock(label: "Active", value: "\(summary.active)", icon: "checkmark.circle.fill", color: .green)
            SummaryBlock(label: "Replace", value: "\(summary.needReplacement)", icon: "exclamationmark.triangle.fill", color: .orange)
            if summary.expired > 0 {
                SummaryBlock(label: "Expired", value: "\(summary.expired)", icon: "xmark.circle.fill", color: .red)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surfaceElevated)
        .padding(DesignSystem.Spacing.screenHorizontalPadding)
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                FilterChip(
                    label: "All",
                    isSelected: selectedCategory == nil,
                    onTap: { selectedCategory = nil }
                )
                
                ForEach(GearCategory.allCases, id: \.self) { category in
                    let count = activeGear.filter { $0.gearType.category == category }.count
                    FilterChip(
                        label: "\(category.displayName) (\(count))",
                        isSelected: selectedCategory == category,
                        onTap: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    private var gearListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(filteredGear) { gear in
                    NavigationLink {
                        GearDetailView(gear: gear)
                    } label: {
                        GearCard(gear: gear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "tshirt")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Gear Added")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Track helmets, shoes, tools, and accessories")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddGear = true
            } label: {
                Label("Add Gear", systemImage: "plus")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - Gear Card

struct GearCard: View {
    let gear: GearItem
    
    var body: some View {
        let health = GearTrackingService.calculateHealth(for: gear)
        
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: gear.gearType.icon)
                .font(.system(size: 32))
                .foregroundStyle(statusColor(for: health.health))
                .frame(width: 60, height: 60)
                .background(DesignSystem.Color.surfaceElevated)
                .cornerRadius(DesignSystem.CornerRadius.md)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(gear.displayName)
                        .bodyLarge()
                        .foregroundHeadline()
                    
                    Text(health.health.emoji)
                        .font(.system(size: 16))
                }
                
                Text(gear.gearType.displayName)
                    .captionMedium()
                    .foregroundStyle(.secondary)
                
                if let daysUntil = health.daysUntilExpiry, daysUntil > 0 {
                    Text("\(daysUntil) days remaining")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                } else if health.health == .expired {
                    Text("EXPIRED")
                        .captionSmall()
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            // Status badge
            Text(health.health.displayName)
                .captionMedium()
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 4)
                .background(statusColor(for: health.health).opacity(0.15))
                .foregroundStyle(statusColor(for: health.health))
                .cornerRadius(DesignSystem.CornerRadius.xs)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func statusColor(for health: GearTrackingService.GearHealth) -> Color {
        switch health.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Summary Block

struct SummaryBlock: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 20))
            Text(value)
                .titleLarge()
                .monospacedDigit()
            Text(label)
                .captionSmall()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Gear Detail View

struct GearDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let gear: GearItem
    
    @State private var showingRetireConfirmation = false
    @State private var showingOrderSheet = false
    
    var body: some View {
        let health = GearTrackingService.calculateHealth(for: gear)
        
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Image(systemName: gear.gearType.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(DesignSystem.Color.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gear.displayName)
                                .titleLarge()
                                .foregroundHeadline()
                            Text(gear.gearType.displayName)
                                .bodyMedium()
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(health.health.emoji)
                            .font(.system(size: 40))
                    }
                    
                    Text(health.health.displayName)
                        .bodyLarge()
                        .foregroundStyle(statusColor(for: health.health))
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.lg)
                
                // Stats
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Stats")
                        .titleMedium()
                        .foregroundHeadline()
                    
                    GearStatRow(label: "Age", value: "\(gear.ageMonths) months (\(gear.ageDays) days)")
                    GearStatRow(label: "Usage Count", value: "\(gear.usageCount) rides")
                    GearStatRow(label: "Total Hours", value: String(format: "%.1f hours", gear.totalHours))
                    GearStatRow(label: "Purchase Date", value: gear.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                    
                    if let price = gear.purchasePrice {
                        GearStatRow(label: "Purchase Price", value: String(format: "$%.2f", price))
                    }
                    
                    if let expiry = health.daysUntilExpiry {
                        GearStatRow(label: "Days Until Expiry", value: "\(expiry) days")
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.lg)
                
                // Warnings
                if !health.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Warnings")
                            .titleMedium()
                            .foregroundHeadline()
                        
                        ForEach(health.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(warning)
                                    .bodySmall()
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                }
                
                // Recommendations
                if !health.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Recommendations")
                            .titleMedium()
                            .foregroundHeadline()
                        
                        ForEach(health.recommendations, id: \.self) { rec in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(rec)
                                    .bodySmall()
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Color.surface)
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                }
                
                // Actions
                VStack(spacing: DesignSystem.Spacing.sm) {
                    if health.shouldOrder {
                        Button {
                            showingOrderSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "cart.fill")
                                Text("Order Replacement")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding(DesignSystem.Spacing.md)
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                    }
                    
                    Button {
                        showingRetireConfirmation = true
                    } label: {
                        Label("Retire Gear", systemImage: "archivebox")
                    }
                    .buttonStyle(DesignSystemButtonStyle(variant: .tertiary, size: .large))
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
        .navigationTitle("Gear Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Retire Gear", isPresented: $showingRetireConfirmation) {
            Button("Retire", role: .destructive) {
                gear.retire(reason: "User retired gear")
                dismiss()
            }
        } message: {
            Text("Are you sure you want to retire this gear?")
        }
        .sheet(isPresented: $showingOrderSheet) {
            OrderGearSheet(gear: gear)
        }
    }
    
    private func statusColor(for health: GearTrackingService.GearHealth) -> Color {
        switch health.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Add Gear View

struct AddGearView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: GearType = .helmet
    @State private var brand = ""
    @State private var model = ""
    @State private var purchaseDate = Date()
    @State private var purchasePrice = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Gear Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(GearType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section("Details") {
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: [.date])
                    TextField("Purchase Price (optional)", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Gear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGear()
                    }
                }
            }
        }
    }
    
    private func addGear() {
        let price = Double(purchasePrice)
        let gear = GearItem(
            gearType: selectedType,
            brand: brand.isEmpty ? nil : brand,
            model: model.isEmpty ? nil : model,
            purchaseDate: purchaseDate,
            purchasePrice: price,
            notes: notes
        )
        
        modelContext.insert(gear)
        dismiss()
    }
}

// MARK: - Stat Row

private struct GearStatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .bodyMedium()
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bodyMedium()
                .monospacedDigit()
        }
    }
}

// MARK: - Order Gear Sheet

struct OrderGearSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    let gear: GearItem
    
    var body: some View {
        let links = VendorService.orderLinks(
            brand: gear.brand,
            model: gear.model,
            category: mapGearToCategory(gear.gearType)
        )
        
        OrderReplacementSheet(
            title: "Order \(gear.gearType.displayName)",
            subtitle: gear.displayName,
            orderLinks: links
        )
    }
    
    private func mapGearToCategory(_ gearType: GearType) -> ComponentCategory {
        switch gearType {
        case .brakePads, .brakeRotors:
            return .brakePads
        case .pumpCO2:
            return .pumps
        case .chamoisCream:
            return .lubricants
        default:
            return .tools
        }
    }
}

// MARK: - Retired Gear View

struct RetiredGearView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<GearItem> { $0.retirementDate != nil }, sort: \GearItem.retirementDate, order: .reverse)
    private var retiredGear: [GearItem]
    
    var body: some View {
        NavigationStack {
            List(retiredGear) { gear in
                VStack(alignment: .leading, spacing: 4) {
                    Text(gear.displayName)
                        .bodyMedium()
                    if let reason = gear.retirementReason {
                        Text(reason)
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                    if let date = gear.retirementDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .captionSmall()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Retired Gear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GearLockerView()
    }
    .environment(ThemeManager.shared)
    .modelContainer(for: [GearItem.self], inMemory: true)
}
