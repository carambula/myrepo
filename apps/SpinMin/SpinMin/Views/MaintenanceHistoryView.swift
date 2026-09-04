//
//  MaintenanceHistoryView.swift
//  SpinMin
//
//  View chronological maintenance history
//

import SwiftUI
import SwiftData

struct MaintenanceHistoryView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let bike: BikeConfiguration
    
    var sortedRecords: [MaintenanceRecord] {
        bike.maintenanceRecords.sorted { $0.maintenanceDate > $1.maintenanceDate }
    }
    
    var recordsByCategory: [MaintenanceCategory: [MaintenanceRecord]] {
        Dictionary(grouping: sortedRecords) { $0.type.category }
    }
    
    @State private var selectedCategory: MaintenanceCategory? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        CategoryFilterChip(
                            category: nil,
                            isSelected: selectedCategory == nil,
                            count: sortedRecords.count,
                            onTap: { selectedCategory = nil }
                        )
                        
                        ForEach(MaintenanceCategory.allCases, id: \.self) { category in
                            if let records = recordsByCategory[category], !records.isEmpty {
                                CategoryFilterChip(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    count: records.count,
                                    onTap: { selectedCategory = category }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
                
                // Records
                if filteredRecords.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredRecords) { record in
                            MaintenanceRecordCard(record: record)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Color.background)
    }
    
    private var filteredRecords: [MaintenanceRecord] {
        if let category = selectedCategory {
            return sortedRecords.filter { $0.type.category == category }
        }
        return sortedRecords
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Maintenance History")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Start logging maintenance to track your bike's service history")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

struct CategoryFilterChip: View {
    let category: MaintenanceCategory?
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.system(size: 12))
                } else {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12))
                }
                Text(category?.displayName ?? "All")
                    .captionMedium()
                Text("(\(count))")
                    .captionSmall()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isSelected ? DesignSystem.Color.accent : DesignSystem.Color.surfaceElevated)
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}

struct MaintenanceRecordCard: View {
    let record: MaintenanceRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: record.type.icon)
                    .foregroundAccent()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.displayName)
                        .bodyLarge()
                        .foregroundHeadline()
                    
                    HStack {
                        Text(record.maintenanceDate.formatted(date: .abbreviated, time: .omitted))
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Text("   ")
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f km", record.bikeOdometerKm))
                            .captionMedium()
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Spacer()
                
                if let cost = record.cost {
                    Text(String(format: "$%.2f", cost))
                        .bodyMedium()
                        .foregroundAccent()
                }
            }
            
            if !record.notes.isEmpty {
                Text(record.notes)
                    .captionMedium()
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            if record.isReplacement, let lifespan = record.componentLifespanKm {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Lasted \(String(format: "%.0f km", lifespan))")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                }
            }
            
            if let performedBy = record.performedBy {
                Text("By: \(performedBy)")
                    .captionSmall()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

struct QuickMaintenanceActionsView: View {
    let bike: BikeConfiguration
    let onAction: (MaintenanceType) -> Void
    
    private let quickActions: [(MaintenanceType, String, String)] = [
        (.chainWax, "Chain Wax", "drop.fill"),
        (.chainClean, "Chain Clean", "sparkles"),
        (.chainReplace, "New Chain", "link.badge.plus"),
        (.wash, "Bike Wash", "drop"),
        (.brakePadReplace, "Brake Pads", "brake.signal"),
        (.fullService, "Full Service", "wrench.and.screwdriver"),
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DesignSystem.Spacing.lg),
                GridItem(.flexible(), spacing: DesignSystem.Spacing.lg)
            ], spacing: DesignSystem.Spacing.lg) {
                ForEach(quickActions, id: \.0.rawValue) { action in
                    QuickActionButton(
                        type: action.0,
                        title: action.1,
                        icon: action.2,
                        onTap: { onAction(action.0) }
                    )
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
        .background(DesignSystem.Color.background)
    }
}

struct QuickActionButton: View {
    let type: MaintenanceType
    let title: String
    let icon: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundAccent()
                
                Text(title)
                    .bodyMedium()
                    .foregroundHeadline()
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Color.surface)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
        .buttonStyle(.plain)
    }
}

struct LogMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let bike: BikeConfiguration
    
    @State private var maintenanceType: MaintenanceType = .general
    @State private var maintenanceDate = Date()
    @State private var notes = ""
    @State private var cost: Double? = nil
    @State private var performedBy = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Maintenance") {
                    Picker("Type", selection: $maintenanceType) {
                        ForEach(MaintenanceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    DatePicker("Date", selection: $maintenanceDate, displayedComponents: [.date])
                }
                
                Section("Details") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                    
                    HStack {
                        Text("Cost")
                        TextField("0.00", value: $cost, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    TextField("Performed By", text: $performedBy)
                }
            }
            .navigationTitle("Log Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMaintenance()
                    }
                }
            }
        }
    }
    
    private func saveMaintenance() {
        let record = MaintenanceRecord(
            maintenanceType: maintenanceType,
            date: maintenanceDate,
            bikeOdometerKm: bike.totalMileageKm,
            notes: notes,
            cost: cost,
            performedBy: performedBy.isEmpty ? nil : performedBy
        )
        
        modelContext.insert(record)
        bike.maintenanceRecords.append(record)
        
        dismiss()
    }
}

struct AddComponentTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let bike: BikeConfiguration
    
    @State private var componentType: ComponentType = .chain
    @State private var brand = ""
    @State private var model = ""
    @State private var installDate = Date()
    @State private var lubeType: ChainLubeType = .hotWax
    @State private var showingProductSearch = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Component") {
                    Picker("Type", selection: $componentType) {
                        ForEach(ComponentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    // Product lookup button for chain
                    if componentType == .chain {
                        Button {
                            showingProductSearch = true
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search Product Database")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                    
                    DatePicker("Install Date", selection: $installDate, displayedComponents: [.date])
                }
                
                if componentType == .chain {
                    Section("Chain Lube Type") {
                        Picker("Lube Type", selection: $lubeType) {
                            ForEach(ChainLubeType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        
                        Text(lubeType.description)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Track Component")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addComponent()
                    }
                    .disabled(brand.isEmpty)
                }
            }
            .sheet(isPresented: $showingProductSearch) {
                ChainSelectionView { chain in
                    brand = chain.brand
                    model = chain.model
                }
            }
        }
    }
    
    private func addComponent() {
        let component = ComponentTracking(
            componentType: componentType,
            brand: brand,
            model: model.isEmpty ? nil : model,
            installDate: installDate,
            installOdometerKm: bike.totalMileageKm
        )
        
        if componentType == .chain {
            component.lubeType = lubeType
            component.chainWearPercentage = 0.0
        }
        
        modelContext.insert(component)
        bike.componentTracking.append(component)
        
        dismiss()
    }
}

// MARK: - Chain Selection View

struct ChainSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [ChainProduct] = []
    
    let onSelect: (ChainProduct) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search chains", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Color.surfaceElevated)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .padding(DesignSystem.Spacing.screenHorizontalPadding)
                
                // Results
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(searchResults) { chain in
                            Button {
                                onSelect(chain)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(chain.brand) \(chain.model)")
                                            .bodyLarge()
                                            .foregroundHeadline()
                                        Text("\(chain.speedCount)-speed")
                                            .captionMedium()
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Color.surface)
                                .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DesignSystem.Spacing.screenHorizontalPadding)
                }
            }
            .navigationTitle("Select Chain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                performSearch()
            }
            .onChange(of: searchText) { old, new in
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        searchResults = ProductLookupService.searchChains(
            query: searchText,
            context: modelContext
        )
    }
}

#Preview {
    NavigationStack {
        MaintenanceHistoryView(bike: BikeConfiguration(
            name: "Road Bike",
            bikeType: .road,
            tireWidthMM: 28
        ))
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, MaintenanceRecord.self], inMemory: true)
    }
}
