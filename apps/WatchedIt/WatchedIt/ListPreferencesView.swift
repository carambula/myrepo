//
//  ListPreferencesView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 1/29/26.
//

import SwiftUI
import SwiftData

struct ListPreferencesView: View {
    @Query(sort: \DataSource.name) private var allDataSources: [DataSource]
    @AppStorage(ListPreferences.storageKey) private var preferredListsData: Data = Data()
    @State private var preferredListIds: [String] = []
    @State private var hasLoadedPreferences = false
    
    private let christmasListIdentifier = "rt-christmas"
    
    private var preferredLists: [DataSource] {
        let lookup = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0) })
        return preferredListIds.compactMap { lookup[$0] }
    }
    
    private var availableLists: [DataSource] {
        let preferredSet = Set(preferredListIds)
        return allDataSources.filter { !preferredSet.contains($0.identifier) }
    }
    
    var body: some View {
        List {
            Section {
                if preferredLists.isEmpty {
                    Text("No preferred lists yet.")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } else {
                    ForEach(preferredLists, id: \.identifier) { list in
                        Text(list.name)
                    }
                    .onMove(perform: movePreferredLists)
                    .onDelete(perform: deletePreferredLists)
                }
            } header: {
                Text("Preferred Lists")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Drag to reorder the lists shown in Inspiration and filters.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
            
            Section {
                if availableLists.isEmpty {
                    Text("All lists are already preferred.")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } else {
                    ForEach(availableLists, id: \.identifier) { list in
                        Button(action: {
                            addPreferredList(list)
                        }) {
                            HStack {
                                Text(list.name)
                                Spacer()
                                Text("Add")
                                    .captionMedium()
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                        .tint(DesignSystem.Color.textPrimary)
                    }
                }
            } header: {
                Text("All Lists")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Lists removed from Preferred Lists appear here and won't show in Inspiration or filters.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Lists")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        #endif
        .onAppear {
            initializePreferredListsIfNeeded()
        }
        .onChange(of: allDataSources.count) { _, _ in
            syncPreferredLists()
        }
        .onChange(of: preferredListIds) { _, newValue in
            preferredListsData = ListPreferences.encode(newValue)
            ListPreferences.updateLastUpdated()
            Task { @MainActor in
                await LocalDatabaseManager.shared.pushLocalListPreferencesToCloudKitIfNeeded()
            }
        }
    }
    
    private func initializePreferredListsIfNeeded() {
        guard !hasLoadedPreferences else { return }
        hasLoadedPreferences = true
        
        if !ListPreferences.hasInitialized() {
            preferredListIds = allDataSources.map { $0.identifier }
            preferredListsData = ListPreferences.encode(preferredListIds)
            ListPreferences.setHasInitialized(true)
            applySeasonalListPreferences()
            return
        }
        
        preferredListIds = ListPreferences.decode(from: preferredListsData)
        syncPreferredLists()
    }
    
    private func syncPreferredLists() {
        guard ListPreferences.hasInitialized() else { return }
        let existingIds = Set(allDataSources.map { $0.identifier })
        let filtered = preferredListIds.filter { existingIds.contains($0) }
        if filtered != preferredListIds {
            preferredListIds = filtered
        }
        applySeasonalListPreferences()
    }
    
    private func applySeasonalListPreferences() {
        guard allDataSources.contains(where: { $0.identifier == christmasListIdentifier }) else { return }
        if isChristmasSeason() {
            if !preferredListIds.contains(christmasListIdentifier) {
                preferredListIds.append(christmasListIdentifier)
            }
        } else if let index = preferredListIds.firstIndex(of: christmasListIdentifier) {
            preferredListIds.remove(at: index)
        }
    }
    
    private func isChristmasSeason(date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return false }
        if month == 11 || month == 12 {
            return true
        }
        return month == 1 && day == 1
    }
    
    private func addPreferredList(_ list: DataSource) {
        guard !preferredListIds.contains(list.identifier) else { return }
        preferredListIds.append(list.identifier)
    }
    
    private func movePreferredLists(from source: IndexSet, to destination: Int) {
        preferredListIds.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deletePreferredLists(at offsets: IndexSet) {
        preferredListIds.remove(atOffsets: offsets)
    }
}
