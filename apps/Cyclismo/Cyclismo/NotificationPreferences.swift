import SwiftUI

struct CyclismoNotificationPreferences: CodablePreference {
    static let storageKey = "cyclismo_notification_preferences"

    var morningRacesEnabled: Bool = false
    var morningRacesTime: String = "08:00"
    var recapEnabled: Bool = false
    var recapHoursAfterLastRace: Int = 3
    var streamStartEnabled: Bool = false
    var streamStartMinutesBefore: Int = 15
    var streamStartOnlySavedRaces: Bool = false
}

struct NotificationPreferencesView: View {
    @State private var preferences = CyclismoNotificationPreferences.load()

    var body: some View {
        SettingsSheet(title: "Notifications") {
            Section {
                Toggle("Morning Race Summary", isOn: $preferences.morningRacesEnabled)
                if preferences.morningRacesEnabled {
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(preferences.morningRacesTime)
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }
                }
            } header: {
                Text("Morning Summary")
            } footer: {
                Text("Daily notification with today's race schedule.")
            }
            .designSystemGroupedListRow()

            Section {
                Toggle("Stream Start Alerts", isOn: $preferences.streamStartEnabled)
                if preferences.streamStartEnabled {
                    Stepper("Alert \(preferences.streamStartMinutesBefore) min before",
                            value: $preferences.streamStartMinutesBefore, in: 5...60, step: 5)
                    Toggle("Only saved races", isOn: $preferences.streamStartOnlySavedRaces)
                }
            } header: {
                Text("Stream Alerts")
            } footer: {
                Text("Get notified before race streams begin.")
            }
            .designSystemGroupedListRow()

            Section {
                Toggle("Race Recaps", isOn: $preferences.recapEnabled)
                if preferences.recapEnabled {
                    Stepper("\(preferences.recapHoursAfterLastRace) hours after last race",
                            value: $preferences.recapHoursAfterLastRace, in: 1...12)
                }
            } header: {
                Text("Recaps")
            } footer: {
                Text("Notification when podcasts and replays are available.")
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .onChange(of: preferences.morningRacesEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.streamStartEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.streamStartMinutesBefore) { _, _ in preferences.save() }
        .onChange(of: preferences.streamStartOnlySavedRaces) { _, _ in preferences.save() }
        .onChange(of: preferences.recapEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.recapHoursAfterLastRace) { _, _ in preferences.save() }
    }
}
