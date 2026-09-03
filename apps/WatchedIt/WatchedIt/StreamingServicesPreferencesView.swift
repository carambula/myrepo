//
//  StreamingServicesPreferencesView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 1/20/26.
//

import SwiftUI

struct StreamingServicesPreferencesView: View {
    @StateObject private var localDB = LocalDatabaseManager.shared
    @AppStorage(StreamingPreferences.storageKey) private var preferredServicesData: Data = Data()
    @AppStorage(StreamingPreferences.hiddenStorageKey) private var hiddenServicesData: Data = Data()
    @State private var preferredServices: [String] = []
    @State private var hiddenServices: [String] = []
    @State private var hasNormalizedDatabase = false
    
    private var availableServices: [String] {
        var normalizedServices: [String] = []
        for movie in localDB.movies {
            for service in movie.streamingServices {
                let normalized = StreamingServiceAssets.normalizedName(service.name)
                if !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    normalizedServices.append(normalized)
                }
            }
        }
        
        let fromMovies = Set(normalizedServices)
        let fromAssets = Set(StreamingServiceAssets.knownServiceNames)
        let allServices = canonicalizeServices(Array(fromMovies.union(fromAssets)))
        let hiddenSet = Set(hiddenServices.map { normalizedCaseKey($0) })
        return allServices
            .filter { !hiddenSet.contains(normalizedCaseKey($0)) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    var body: some View {
        List {
            Section {
                if preferredServices.isEmpty {
                    Text("No preferred services yet.")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } else {
                    ForEach(preferredServices, id: \.self) { service in
                        Text(service)
                    }
                    .onMove(perform: movePreferredServices)
                    .onDelete(perform: deletePreferredServices)
                }
            } header: {
                Text("Preferred Services")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Drag to reorder your preferred services.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
            
            Section {
                if hiddenServices.isEmpty {
                    Text("No hidden services.")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } else {
                    ForEach(hiddenServices, id: \.self) { service in
                        Button(action: {
                            unhideService(service)
                        }) {
                            HStack {
                                Text(service)
                                Spacer()
                                Text("Show")
                                    .captionMedium()
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                        .tint(DesignSystem.Color.textPrimary)
                    }
                    .onDelete(perform: deleteHiddenServices)
                }
            } header: {
                Text("Hidden Services")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Hidden services won't appear in movie details.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
            
            Section {
                if availableServices.isEmpty {
                    Text("Streaming services will appear here once they are loaded.")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } else {
                    ForEach(availableServices, id: \.self) { service in
                        Button(action: {
                            togglePreferredService(service)
                        }) {
                            HStack {
                                Text(service)
                                Spacer()
                                if preferredServices.contains(service) {
                                    Image(systemName: DesignSystem.Icon.checkmark)
                                        .foregroundColor(DesignSystem.Color.accent)
                                } else {
                                    #if os(tvOS)
                                    Button("Hide") {
                                        hideService(service)
                                    }
                                    .buttonStyle(.bordered)
                                    #endif
                                }
                            }
                        }
                        .tint(DesignSystem.Color.textPrimary)
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                hideService(service)
                            } label: {
                                Label("Hide", systemImage: "eye.slash")
                            }
                        }
                        #endif
                    }
                }
            } header: {
                Text("All Services")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Tap a service to add or remove it from your preferred order.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Streaming Services")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        #endif
        .onAppear {
            preferredServices = canonicalizeServices(StreamingPreferences.decode(from: preferredServicesData))
            hiddenServices = canonicalizeServices(StreamingPreferences.decode(from: hiddenServicesData))
        }
        .task {
            guard !hasNormalizedDatabase else { return }
            hasNormalizedDatabase = true
            await localDB.normalizeStreamingServicesCase()
        }
        .onChange(of: preferredServices) { _, newValue in
            preferredServicesData = StreamingPreferences.encode(canonicalizeServices(newValue))
            StreamingPreferences.updateLastUpdated()
            Task {
                await localDB.pushLocalStreamingPreferencesToCloudKitIfNeeded()
            }
        }
        .onChange(of: hiddenServices) { _, newValue in
            hiddenServicesData = StreamingPreferences.encode(canonicalizeServices(newValue))
            StreamingPreferences.updateLastUpdated()
            Task {
                await localDB.pushLocalStreamingPreferencesToCloudKitIfNeeded()
            }
        }
    }
    
    private func togglePreferredService(_ service: String) {
        let canonical = canonicalizeServices([service]).first ?? service
        if let index = indexForService(canonical, in: preferredServices) {
            preferredServices.remove(at: index)
        } else {
            if let hiddenIndex = indexForService(canonical, in: hiddenServices) {
                hiddenServices.remove(at: hiddenIndex)
            }
            preferredServices.append(canonical)
        }
    }
    
    private func movePreferredServices(from source: IndexSet, to destination: Int) {
        preferredServices.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deletePreferredServices(at offsets: IndexSet) {
        preferredServices.remove(atOffsets: offsets)
    }

    private func hideService(_ service: String) {
        let canonical = canonicalizeServices([service]).first ?? service
        if let preferredIndex = indexForService(canonical, in: preferredServices) {
            preferredServices.remove(at: preferredIndex)
        }
        if indexForService(canonical, in: hiddenServices) == nil {
            hiddenServices.append(canonical)
            hiddenServices.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }

    private func unhideService(_ service: String) {
        if let index = indexForService(service, in: hiddenServices) {
            hiddenServices.remove(at: index)
        }
    }

    private func deleteHiddenServices(at offsets: IndexSet) {
        hiddenServices.remove(atOffsets: offsets)
    }

    private func canonicalizeServices(_ services: [String]) -> [String] {
        var orderedKeys: [String] = []
        var entries: [String: String] = [:]
        var hasMixedCaps: [String: Bool] = [:]
        
        for service in services {
            let trimmedName = service.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let key = normalizedCaseKey(trimmedName)
            
            if entries[key] == nil {
                orderedKeys.append(key)
                entries[key] = trimmedName
                hasMixedCaps[key] = isMixedCaps(trimmedName)
                continue
            }
            
            let currentMixed = hasMixedCaps[key] ?? false
            let candidateMixed = isMixedCaps(trimmedName)
            if !currentMixed && candidateMixed {
                entries[key] = trimmedName
                hasMixedCaps[key] = true
            }
        }
        
        return orderedKeys.compactMap { entries[$0] }
    }
    
    private func indexForService(_ service: String, in services: [String]) -> Int? {
        let key = normalizedCaseKey(service)
        return services.firstIndex { normalizedCaseKey($0) == key }
    }
    
    private func normalizedCaseKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func isMixedCaps(_ value: String) -> Bool {
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let hasUpper = letters.contains { CharacterSet.uppercaseLetters.contains($0) }
        let hasLower = letters.contains { CharacterSet.lowercaseLetters.contains($0) }
        return hasUpper && hasLower
    }
}
