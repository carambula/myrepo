//
//  RideChecklistView.swift
//  SpinMin
//
//  UI for pre-ride and race day checklists
//

import SwiftUI
import SwiftData

struct RideChecklistsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \RideChecklist.lastUsedDate, order: .reverse)
    private var checklists: [RideChecklist]
    
    @State private var showingCreateChecklist = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if checklists.isEmpty {
                    emptyStateView
                } else {
                    checklistListView
                }
            }
            .navigationTitle("Ride Checklists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ChecklistTemplate.templates, id: \.type) { template in
                            Button {
                                createFromTemplate(template)
                            } label: {
                                Label(template.name, systemImage: template.type.icon)
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            showingCreateChecklist = true
                        } label: {
                            Label("Custom Checklist", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateChecklist) {
                CreateChecklistView()
            }
        }
    }
    
    private var checklistListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(checklists) { checklist in
                    NavigationLink {
                        ChecklistDetailView(checklist: checklist)
                    } label: {
                        ChecklistCard(checklist: checklist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Checklists")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Create checklists for training rides, races, or bike packing")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Menu {
                ForEach(ChecklistTemplate.templates, id: \.type) { template in
                    Button {
                        createFromTemplate(template)
                    } label: {
                        Label(template.name, systemImage: template.type.icon)
                    }
                }
            } label: {
                Label("Create Checklist", systemImage: "plus")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
    
    private func createFromTemplate(_ template: ChecklistTemplate) {
        let items = template.items.enumerated().map { index, item in
            ChecklistItem(
                title: item.title,
                category: item.category,
                sortOrder: index,
                notes: ""
            )
        }
        
        let checklist = RideChecklist(
            name: template.name,
            type: template.type,
            items: items
        )
        
        modelContext.insert(checklist)
    }
}

// MARK: - Checklist Card

struct ChecklistCard: View {
    let checklist: RideChecklist
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: checklist.checklistType.icon)
                .font(.system(size: 32))
                .foregroundStyle(DesignSystem.Color.accent)
                .frame(width: 60, height: 60)
                .background(DesignSystem.Color.surfaceElevated)
                .cornerRadius(DesignSystem.CornerRadius.md)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(checklist.name)
                    .bodyLarge()
                    .foregroundHeadline()
                
                Text("\(checklist.items.count) items")
                    .captionMedium()
                    .foregroundStyle(.secondary)
                
                // Progress
                if checklist.completionPercentage > 0 {
                    HStack(spacing: 4) {
                        ProgressView(value: checklist.completionPercentage, total: 100)
                            .frame(maxWidth: 100)
                        Text(String(format: "%.0f%%", checklist.completionPercentage))
                            .captionSmall()
                            .monospacedDigit()
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
}

// MARK: - Checklist Detail View

struct ChecklistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let checklist: RideChecklist
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Progress header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("\(checklist.items.filter { $0.isChecked }.count) of \(checklist.items.count) complete")
                            .titleMedium()
                            .foregroundHeadline()
                        
                        Spacer()
                        
                        if checklist.isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 32))
                        }
                    }
                    
                    ProgressView(value: checklist.completionPercentage, total: 100)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.lg)
                
                // Grouped by category
                let grouped = Dictionary(grouping: checklist.items.sorted(by: { $0.sortOrder < $1.sortOrder }), by: { $0.category })
                
                ForEach(checklist.checklistType == .race ? ["Pre-Race", "Gear", "Bike", "Nutrition", "Post-Race"] : ["Safety", "Bike", "Tools", "Hydration", "Clothing"], id: \.self) { category in
                    if let items = grouped[category], !items.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(category)
                                .titleSmall()
                                .foregroundHeadline()
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                            
                            ForEach(items) { item in
                                ChecklistItemRow(item: item)
                            }
                        }
                    }
                }
                
                // Actions
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        checklist.resetChecklist()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .large))
                    
                    if checklist.isComplete {
                        Button {
                            checklist.useChecklist()
                            checklist.resetChecklist()
                        } label: {
                            Label("Use Again", systemImage: "checkmark")
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                    }
                }
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
        .navigationTitle(checklist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Checklist Item Row

struct ChecklistItemRow: View {
    @Bindable var item: ChecklistItem
    
    var body: some View {
        Button {
            item.isChecked.toggle()
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .font(.system(size: 24))
                
                Text(item.title)
                    .bodyMedium()
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked)
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.surfaceElevated)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Checklist View

struct CreateChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedType: ChecklistType = .training
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Checklist Name", text: $name)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(ChecklistType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section {
                    Text("Or use a template:")
                        .foregroundStyle(.secondary)
                    
                    ForEach(ChecklistTemplate.templates, id: \.type) { template in
                        Button {
                            createFromTemplate(template)
                        } label: {
                            HStack {
                                Image(systemName: template.type.icon)
                                Text(template.name)
                                Spacer()
                                Text("\(template.items.count) items")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChecklist()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createChecklist() {
        let checklist = RideChecklist(name: name, type: selectedType)
        modelContext.insert(checklist)
        dismiss()
    }
    
    private func createFromTemplate(_ template: ChecklistTemplate) {
        let items = template.items.enumerated().map { index, item in
            ChecklistItem(
                title: item.title,
                category: item.category,
                sortOrder: index,
                notes: ""
            )
        }
        
        let checklist = RideChecklist(
            name: template.name,
            type: template.type,
            items: items
        )
        
        modelContext.insert(checklist)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RideChecklistsView()
    }
    .modelContainer(for: [RideChecklist.self, ChecklistItem.self], inMemory: true)
}
