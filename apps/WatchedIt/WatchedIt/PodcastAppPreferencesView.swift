//
//  PodcastAppPreferencesView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 2/8/26.
//

import SwiftUI

struct PodcastAppPreferencesView: View {
    @StateObject private var localDB = LocalDatabaseManager.shared
    @AppStorage(PodcastAppPreferences.storageKey) private var preferredAppName: String = PodcastApp.applePodcasts.rawValue
    @State private var selectedApp: PodcastApp = .applePodcasts
    
    var body: some View {
        List {
            Section {
                ForEach(PodcastApp.allCases) { app in
                    Button(action: {
                        selectedApp = app
                    }) {
                        HStack {
                            Text(app.rawValue)
                            Spacer()
                            if selectedApp == app {
                                Image(systemName: DesignSystem.Icon.checkmark)
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                    }
                    .tint(DesignSystem.Color.textPrimary)
                }
            } header: {
                Text("Preferred Podcast App")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("This app opens when you tap podcast links or the listened action.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Podcast App")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if let stored = PodcastApp.fromStoredValue(preferredAppName) {
                selectedApp = stored
            } else {
                selectedApp = .applePodcasts
                preferredAppName = selectedApp.rawValue
            }
        }
        .onChange(of: selectedApp) { _, newValue in
            preferredAppName = newValue.rawValue
            PodcastAppPreferences.updateLastUpdated()
            Task {
                await localDB.pushLocalPodcastAppPreferencesToCloudKitIfNeeded()
            }
        }
    }
}
