import SwiftUI
import SwiftData

struct AddChannelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var query = ""
    @State private var isSearching = false
    @State private var channels: [YTChannel] = []
    @State private var errorMessage: String?

    let theme: AppTheme
    let apiClient: YouTubeAPIClient
    let authService: GoogleOAuthService

    var body: some View {
        NavigationStack {
            List {
                Section("Search channels") {
                    HStack {
                        TextField("Add a channel", text: $query)
                            .textFieldStyle(.roundedBorder)
                        Button("Find") {
                            Task { await search() }
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Results") {
                    ForEach(channels) { channel in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(channel.title)
                                .foregroundStyle(theme.text)
                                .font(.headline)
                            if !channel.summary.isEmpty {
                                Text(channel.summary)
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(2)
                            }
                            Button("Add Channel") {
                                subscribeLocally(channel)
                            }
                            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .small))
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .yourTubeSettingsSurface(using: theme)
            .navigationTitle("Add Channel")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
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
        .bottomSheetPullToDismiss()
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        errorMessage = nil
        do {
            let token = try await authService.validAccessToken()
            channels = try await apiClient.searchChannels(accessToken: token, query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func subscribeLocally(_ channel: YTChannel) {
        let channelID = channel.channelID
        let channelDescriptor = FetchDescriptor<YTChannel>(
            predicate: #Predicate { $0.channelID == channelID }
        )
        if let existingChannel = try? modelContext.fetch(channelDescriptor).first {
            existingChannel.isUserSubscribed = true
            existingChannel.lastSyncedAt = .now
        } else {
            channel.isUserSubscribed = true
            channel.lastSyncedAt = .now
            modelContext.insert(channel)
        }

        let subscriptionDescriptor = FetchDescriptor<UserSubscription>(
            predicate: #Predicate { $0.channelID == channelID }
        )
        if (try? modelContext.fetch(subscriptionDescriptor).first) == nil {
            modelContext.insert(UserSubscription(channelID: channelID))
        }
        try? modelContext.save()
    }
}
