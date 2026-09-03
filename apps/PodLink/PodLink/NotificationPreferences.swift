import SwiftUI

struct PodLinkNotificationPreferences: CodablePreference {
    static let storageKey = "podlink_notification_preferences"

    var morningQueueEnabled: Bool = false
    var morningQueueTimeHour: Int = 8
    var morningQueueTimeMinute: Int = 0
    var useAppleIntelligence: Bool = true
    var priorityPodcastsEnabled: Bool = false
    var checkIntervalMinutes: Int = 60
    var priorityPodcastIDs: [String] = []

    var morningQueueTimeDate: Date {
        get {
            Calendar.current.date(from: DateComponents(hour: morningQueueTimeHour, minute: morningQueueTimeMinute)) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            morningQueueTimeHour = components.hour ?? 8
            morningQueueTimeMinute = components.minute ?? 0
        }
    }
}

struct NotificationPreferencesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var preferences = PodLinkNotificationPreferences.load()
    @State private var followedPodcasts: [Podcast] = []

    var body: some View {
        SettingsSheet(title: "Notifications") {
            Section {
                Toggle("Morning Queue Summary", isOn: $preferences.morningQueueEnabled)
                if preferences.morningQueueEnabled {
                    DatePicker("Time",
                               selection: Binding(
                                   get: { preferences.morningQueueTimeDate },
                                   set: { preferences.morningQueueTimeDate = $0; preferences.save() }
                               ),
                               displayedComponents: .hourAndMinute)
                    Toggle("Apple Intelligence Summary", isOn: $preferences.useAppleIntelligence)
                }
            } header: {
                Text("Morning Summary")
            } footer: {
                Text("Daily summary of new episodes in your queue.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Toggle("Priority Podcast Alerts", isOn: $preferences.priorityPodcastsEnabled)
                if preferences.priorityPodcastsEnabled {
                    Stepper("Check every \(preferences.checkIntervalMinutes) min",
                            value: $preferences.checkIntervalMinutes, in: 15...360, step: 15)

                    if followedPodcasts.isEmpty {
                        Text("Follow podcasts to select priorities.")
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    } else {
                        ForEach(followedPodcasts) { podcast in
                            Button {
                                togglePriority(podcast)
                            } label: {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    AsyncCachedImage(url: podcast.displayArtworkURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                                            .fill(Color(.tertiarySystemFill))
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))

                                    Text(podcast.title)
                                        .font(DesignSystem.Typography.bodyMedium())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: preferences.priorityPodcastIDs.contains(podcast.id)
                                          ? "bell.fill" : "bell")
                                        .foregroundStyle(preferences.priorityPodcastIDs.contains(podcast.id)
                                                         ? themeManager.currentTheme.accentColor
                                                         : DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Priority Podcasts")
            } footer: {
                Text("Get notified immediately when priority podcasts publish new episodes. Tap a podcast to toggle priority.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .onAppear {
            followedPodcasts = Podcast.loadFollowedPodcasts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .followedPodcastsDidChange)) { _ in
            followedPodcasts = Podcast.loadFollowedPodcasts()
        }
        .onChange(of: preferences.morningQueueEnabled) { _, _ in preferences.save(); syncPreferencesToCloud() }
        .onChange(of: preferences.useAppleIntelligence) { _, _ in preferences.save(); syncPreferencesToCloud() }
        .onChange(of: preferences.priorityPodcastsEnabled) { _, enabled in
            preferences.save()
            syncPreferencesToCloud()
            if enabled {
                Task { await EpisodeNotificationService.shared.requestAuthorizationIfNeeded() }
            }
        }
        .onChange(of: preferences.checkIntervalMinutes) { _, _ in preferences.save(); syncPreferencesToCloud() }
    }

    private func syncPreferencesToCloud() {
        Task {
            await MinCloudClient.shared.syncFollowedWatches(Podcast.loadFollowedPodcasts())
            guard MinCloudSettings.isSignedIn else { return }
            try? await MinCloudClient.shared.saveNotificationPreferences([
                "morning_queue": [
                    "enabled": preferences.morningQueueEnabled,
                    "time": String(format: "%02d:%02d", preferences.morningQueueTimeHour, preferences.morningQueueTimeMinute),
                    "useAppleIntelligence": preferences.useAppleIntelligence
                ],
                "priority_podcasts": [
                    "enabled": preferences.priorityPodcastsEnabled,
                    "checkIntervalMinutes": preferences.checkIntervalMinutes,
                    "priorityPodcastIds": preferences.priorityPodcastIDs
                ]
            ])
        }
    }

    private func togglePriority(_ podcast: Podcast) {
        if let index = preferences.priorityPodcastIDs.firstIndex(of: podcast.id) {
            preferences.priorityPodcastIDs.remove(at: index)
        } else {
            preferences.priorityPodcastIDs.append(podcast.id)
        }
        preferences.save()
        syncPreferencesToCloud()
    }
}
