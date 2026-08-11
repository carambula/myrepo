//
//  CalendarSyncSettingsView.swift
//  SpinMin
//
//  Connect a training platform calendar feed (ICS) for workout sync
//

import SwiftUI
import SwiftData

struct CalendarSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("trainingCalendarFeedURL") private var feedURL = ""
    @AppStorage("trainingCalendarLastSync") private var lastSyncTimestamp = 0.0
    
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var syncFailed = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("webcal:// or https:// feed URL", text: $feedURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Calendar Feed URL")
                } footer: {
                    Text("Workouts from the feed are imported as scheduled rides and kept in sync. Completed rides are never modified.")
                }
                
                Section {
                    Button {
                        Task { await syncNow() }
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .padding(.trailing, DesignSystem.Spacing.sm)
                                Text("Syncing…")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Now")
                            }
                        }
                    }
                    .disabled(feedURL.trimmingCharacters(in: .whitespaces).isEmpty || isSyncing)
                    
                    if let message = syncMessage {
                        HStack {
                            Image(systemName: syncFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(syncFailed ? .red : .green)
                            Text(message)
                                .bodySmall()
                        }
                    }
                    
                    if lastSyncTimestamp > 0 {
                        HStack {
                            Text("Last synced")
                            Spacer()
                            Text(Date(timeIntervalSince1970: lastSyncTimestamp).formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    instructionRow(
                        platform: "TrainingPeaks",
                        steps: "Settings → Calendar Sync → copy the webcal URL"
                    )
                    instructionRow(
                        platform: "intervals.icu",
                        steps: "Settings → Calendar → copy the calendar feed URL"
                    )
                    instructionRow(
                        platform: "TrainerRoad",
                        steps: "Account → Calendar → enable Calendar Sync and copy the URL"
                    )
                    instructionRow(
                        platform: "Final Surge",
                        steps: "Settings → Calendar Feed → copy the iCal URL"
                    )
                } header: {
                    Text("Where to Find Your Feed URL")
                } footer: {
                    Text("Garmin Connect does not publish a calendar feed. If you plan workouts in Garmin, push them to TrainingPeaks or intervals.icu and sync from there.")
                }
            }
            .navigationTitle("Training Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func instructionRow(platform: String, steps: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(platform)
                .bodyMedium()
            Text(steps)
                .captionMedium()
                .foregroundStyle(.secondary)
        }
    }
    
    private func syncNow() async {
        isSyncing = true
        syncMessage = nil
        syncFailed = false
        defer { isSyncing = false }
        
        do {
            let result = try await TrainingCalendarSyncService.sync(
                feedURLString: feedURL,
                context: modelContext
            )
            syncMessage = result.summary
            lastSyncTimestamp = Date().timeIntervalSince1970
        } catch {
            syncFailed = true
            syncMessage = error.localizedDescription
        }
    }
}
