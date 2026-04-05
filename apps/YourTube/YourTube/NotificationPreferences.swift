import SwiftUI

struct YourTubeNotificationPreferences: CodablePreference {
    static let storageKey = "yourtube_notification_preferences"

    var morningQueueEnabled: Bool = false
    var morningQueueTime: String = "08:00"
    var useAppleIntelligence: Bool = true
    var priorityChannelsEnabled: Bool = false
    var checkIntervalMinutes: Int = 60
}

struct NotificationPreferencesView: View {
    @State private var preferences = YourTubeNotificationPreferences.load()

    var body: some View {
        SettingsSheet(title: "Notifications") {
            Section {
                Toggle("Morning Queue Summary", isOn: $preferences.morningQueueEnabled)
                if preferences.morningQueueEnabled {
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(preferences.morningQueueTime)
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }
                    Toggle("Apple Intelligence Summary", isOn: $preferences.useAppleIntelligence)
                }
            } header: {
                Text("Morning Summary")
            } footer: {
                Text("Daily summary of new videos from your subscriptions.")
            }
            .designSystemGroupedListRow()

            Section {
                Toggle("Priority Channel Alerts", isOn: $preferences.priorityChannelsEnabled)
                if preferences.priorityChannelsEnabled {
                    Stepper("Check every \(preferences.checkIntervalMinutes) min",
                            value: $preferences.checkIntervalMinutes, in: 15...360, step: 15)
                }
            } header: {
                Text("Priority Channels")
            } footer: {
                Text("Get notified immediately when priority channels upload new videos.")
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .onChange(of: preferences.morningQueueEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.useAppleIntelligence) { _, _ in preferences.save() }
        .onChange(of: preferences.priorityChannelsEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.checkIntervalMinutes) { _, _ in preferences.save() }
    }
}
