//
//  ProductSelectionView.swift
//  SpinMin
//
//  Product selection with search, autocomplete, and filters
//

import SwiftUI
import SwiftData

// MARK: - Tire Selection View

struct TireSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var searchText = ""
    @State private var selectedWheelSize: String?
    @State private var selectedProduct: TireProduct?
    @State private var searchResults: [TireProduct] = []
    @State private var showingManualEntry = false
    
    let wheelSize: String?
    let onSelect: (TireProduct) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search tires (e.g., Continental GP5000)", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
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
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        FilterChip(
                            label: "All Sizes",
                            isSelected: selectedWheelSize == nil,
                            onTap: { selectedWheelSize = nil; performSearch() }
                        )
                        
                        ForEach(["700c", "650b", "29\"", "27.5\"", "26\""], id: \.self) { size in
                            FilterChip(
                                label: size,
                                isSelected: selectedWheelSize == size,
                                onTap: { selectedWheelSize = size; performSearch() }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                
                Divider()
                
                // Results
                if searchResults.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else if searchResults.isEmpty {
                    popularTiresView
                } else {
                    resultsListView
                }
            }
            .navigationTitle("Select Tire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Manual Entry", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                if let size = wheelSize {
                    selectedWheelSize = size
                }
                performSearch()
            }
            .onChange(of: searchText) { old, new in
                if new.count >= 2 {
                    performSearch()
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualTireEntryView { brand, model, specs in
                    // Create a custom tire product
                    let tire = TireProduct(
                        brand: brand,
                        model: model,
                        wheelSize: specs["wheelSize"] ?? "700c",
                        widthMM: Int(specs["widthMM"] ?? "28") ?? 28,
                        tireType: specs["tireType"] ?? "tubeless",
                        year: Int(specs["year"] ?? "")
                    )
                    modelContext.insert(tire)
                    onSelect(tire)
                    dismiss()
                }
            }
        }
    }
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(searchResults) { tire in
                    TireProductCard(tire: tire) {
                        onSelect(tire)
                        dismiss()
                    }
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
    }
    
    private var popularTiresView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Popular Tires")
                    .titleMedium()
                    .foregroundHeadline()
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(searchResults.filter { $0.isPopular }) { tire in
                        TireProductCard(tire: tire) {
                            onSelect(tire)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
            .padding(.top, DesignSystem.Spacing.lg)
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Tires Found")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Try a different search or add manually")
                .bodyMedium()
                .foregroundStyle(.secondary)
            
            Button {
                showingManualEntry = true
            } label: {
                Label("Add Manually", systemImage: "plus")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
    
    private func performSearch() {
        searchResults = ProductLookupService.searchTires(
            query: searchText,
            wheelSize: selectedWheelSize,
            context: modelContext
        )
    }
}

// MARK: - Tire Product Card

struct TireProductCard: View {
    let tire: TireProduct
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Product image placeholder
                Image(systemName: "circle.dotted")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
                    .background(DesignSystem.Color.surfaceElevated)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tire.brand)
                            .bodyLarge()
                            .fontWeight(.semibold)
                        
                        if tire.isPopular {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    Text(tire.model)
                        .bodyMedium()
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Text("\(tire.wheelSizeRawValue) × \(tire.widthMM)mm")
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        
                        if let year = tire.year {
                            Text("·")
                                .captionMedium()
                                .foregroundStyle(.secondary)
                            Text(String(year))
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                        
                        if let weight = tire.weight {
                            Text("·")
                                .captionMedium()
                                .foregroundStyle(.secondary)
                            Text("\(weight)g")
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                    }
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

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(label)
                .captionMedium()
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(isSelected ? DesignSystem.Color.accent : DesignSystem.Color.surfaceElevated)
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual Entry View

struct ManualTireEntryView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var brand = ""
    @State private var model = ""
    @State private var wheelSize = "700c"
    @State private var widthMM = "28"
    @State private var tireType = "tubeless"
    @State private var year = ""
    
    let onComplete: (String, String, [String: String]) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tire Details") {
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                }
                
                Section("Specifications") {
                    Picker("Wheel Size", selection: $wheelSize) {
                        Text("700c").tag("700c")
                        Text("650b").tag("650b")
                        Text("29\"").tag("29\"")
                        Text("27.5\"").tag("27.5\"")
                        Text("26\"").tag("26\"")
                    }
                    
                    TextField("Width (mm)", text: $widthMM)
                        .keyboardType(.numberPad)
                    
                    Picker("Type", selection: $tireType) {
                        Text("Tubeless").tag("tubeless")
                        Text("Clincher").tag("clincher")
                        Text("Tubular").tag("tubular")
                    }
                    
                    TextField("Year (optional)", text: $year)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Tire Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let specs: [String: String] = [
                            "wheelSize": wheelSize,
                            "widthMM": widthMM,
                            "tireType": tireType,
                            "year": year
                        ]
                        onComplete(brand, model, specs)
                    }
                    .disabled(brand.isEmpty || model.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TireSelectionView(wheelSize: "700c") { tire in
        print("Selected: \(tire.displayName)")
    }
    .environment(ThemeManager.shared)
    .modelContainer(for: [TireProduct.self], inMemory: true)
}
