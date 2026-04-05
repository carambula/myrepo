import SwiftUI

struct WatchedItNotificationPreferences: CodablePreference {
    static let storageKey = "watchedit_notification_preferences"

    var newEpisodesEnabled: Bool = false
    var checkTimeHour: Int = 9
    var checkTimeMinute: Int = 0

    var checkTimeDate: Date {
        get {
            Calendar.current.date(from: DateComponents(hour: checkTimeHour, minute: checkTimeMinute)) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            checkTimeHour = components.hour ?? 9
            checkTimeMinute = components.minute ?? 0
        }
    }

    var checkTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: checkTimeDate)
    }
}

struct NotificationPreferencesView: View {
    @State private var preferences = WatchedItNotificationPreferences.load()

    var body: some View {
        List {
            Section {
                Toggle("New Episode Alerts", isOn: $preferences.newEpisodesEnabled)
                if preferences.newEpisodesEnabled {
                    DatePicker("Check Time",
                               selection: Binding(
                                   get: { preferences.checkTimeDate },
                                   set: { preferences.checkTimeDate = $0; preferences.save() }
                               ),
                               displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Episode Notifications")
            } footer: {
                Text("Daily check for new podcast episodes related to your movies.")
            }
            .designSystemGroupedListRow()
        }
        .navigationTitle("Notifications")
        .designSystemGroupedListStyle()
        .onChange(of: preferences.newEpisodesEnabled) { _, _ in preferences.save() }
    }
}
