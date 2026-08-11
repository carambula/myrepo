//
//  VendorPreferencesView.swift
//  SpinMin
//
//  UI for managing vendor preferences
//

import SwiftUI
import SwiftData

struct VendorPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var preferences: [VendorPreference]
    @State private var selectedVendors: [Vendor] = []
    
    var body: some View {
        List {
            Section {
                ForEach(Vendor.allCases, id: \.self) { vendor in
                    VendorSelectionRow(
                        vendor: vendor,
                        isSelected: selectedVendors.contains(vendor),
                        onToggle: { toggleVendor(vendor) }
                    )
                }
            } header: {
                Text("Select Vendors")
            } footer: {
                Text("Selected vendors will appear first when ordering replacement components. Tap to add or remove vendors.")
            }
        }
        .navigationTitle("Preferred Vendors")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPreferences()
        }
        .onDisappear {
            savePreferences()
        }
    }
    
    private func loadPreferences() {
        if let existing = preferences.first {
            selectedVendors = existing.vendors
        } else {
            // Default vendors
            selectedVendors = [.competitiveCyclist, .jensonUSA, .silca]
        }
    }
    
    private func savePreferences() {
        if let existing = preferences.first {
            existing.vendors = selectedVendors
        } else {
            let newPreference = VendorPreference(preferredVendors: selectedVendors)
            modelContext.insert(newPreference)
        }
        
        try? modelContext.save()
    }
    
    private func toggleVendor(_ vendor: Vendor) {
        if let index = selectedVendors.firstIndex(of: vendor) {
            selectedVendors.remove(at: index)
        } else {
            selectedVendors.append(vendor)
        }
    }
}

struct VendorSelectionRow: View {
    let vendor: Vendor
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Vendor icon
                Image(systemName: vendor.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? DesignSystem.Color.accent : .secondary)
                    .frame(width: 40)
                
                // Vendor info
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.displayName)
                        .bodyMedium()
                        .foregroundHeadline()
                    
                    Text(vendor.description)
                        .captionSmall()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    // Specialties
                    HStack(spacing: 4) {
                        ForEach(vendor.specialties.prefix(3), id: \.self) { specialty in
                            Text(specialty.displayName)
                                .captionSmall()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if vendor.specialties.count > 3 {
                            Text("+\(vendor.specialties.count - 3)")
                                .captionSmall()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Color.accent)
                        .font(.system(size: 24))
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        VendorPreferencesView()
    }
    .modelContainer(for: [VendorPreference.self], inMemory: true)
}
