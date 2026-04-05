import SwiftUI

struct DownloadSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(DownloadSettingsKeys.wifiOnly) private var wifiOnly = true
    @AppStorage(DownloadSettingsKeys.deleteAfterListened) private var deleteAfterListened = false
    @AppStorage(DownloadSettingsKeys.retentionDays) private var retentionDays = 30
    @AppStorage(DownloadSettingsKeys.autoDownloadFollowed) private var autoDownloadFollowed = false

    private let retentionOptions: [(title: String, value: Int)] = [
        ("Never", 0),
        ("1 day", 1),
        ("7 days", 7),
        ("30 days", 30)
    ]

    var body: some View {
        List {
            Section("Downloads") {
                Toggle("Download on Wi-Fi only", isOn: $wifiOnly)
                Toggle("Auto-download latest from followed podcasts", isOn: $autoDownloadFollowed)
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Toggle("Delete after listening", isOn: $deleteAfterListened)

                Picker("Keep downloads for", selection: $retentionDays) {
                    ForEach(retentionOptions, id: \.value) { option in
                        Text(option.title).tag(option.value)
                    }
                }
            } header: {
                Text("Cleanup")
            } footer: {
                Text("Retention runs automatically when the app launches and returns to foreground.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Download Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    DownloadRetentionEngine.runSweep()
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.checkmark)
                        .viewControlIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
        }
    }
}
