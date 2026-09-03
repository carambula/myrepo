import SwiftUI

struct MinCloudAccountView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var email = MinCloudSettings.email ?? ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var statusMessage: String?
    @State private var isWorking = false
    @State private var iCloudBackupEnabled = MinCloudSettings.iCloudBackupEnabled

    var body: some View {
        List {
            Section {
                if MinCloudSettings.isSignedIn {
                    LabeledContent("Signed in as", value: MinCloudSettings.handle.map { "@\($0)" } ?? MinCloudSettings.email ?? "account")
                    Button("Sign out") {
                        Task { await MinCloudClient.shared.logout() }
                    }
                    .disabled(isWorking)
                } else {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                    TextField("Display name", text: $displayName)
                    Button("Sign in") {
                        Task { await signIn() }
                    }
                    .disabled(isWorking || email.isEmpty || password.count < 8)
                    Button("Create account") {
                        Task { await register() }
                    }
                    .disabled(isWorking || email.isEmpty || password.count < 8)
                }
            } header: {
                Text("Min Cloud")
            } footer: {
                Text("Server-side feed refresh and notifications. Local RSS stays as a backup when the service is unreachable.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Toggle("iCloud backup", isOn: $iCloudBackupEnabled)
            } header: {
                Text("Device backup")
            } footer: {
                Text("iCloud is optional. Keep it as a backup, or turn it off if you only want Min Cloud or local data.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
            }
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Min Cloud")
        .onChange(of: iCloudBackupEnabled) { _, enabled in
            MinCloudSettings.iCloudBackupEnabled = enabled
        }
    }

    private func signIn() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await MinCloudClient.shared.login(email: email, password: password)
            await pushFollowedPodcasts()
            statusMessage = "Signed in. Feeds and notifications can now use Min Cloud."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func register() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await MinCloudClient.shared.register(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
            await pushFollowedPodcasts()
            statusMessage = "Account created."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func pushFollowedPodcasts() async {
        let items = Podcast.loadFollowedPodcasts().map { podcast -> [String: Any] in
            var item: [String: Any] = [
                "podcastId": podcast.id,
                "feedUrl": podcast.feedURL.absoluteString,
                "title": podcast.title,
                "isFollowed": true,
                "notificationsEnabled": podcast.notificationsEnabled
            ]
            if let artwork = podcast.displayArtworkURL?.absoluteString {
                item["artworkUrl"] = artwork
            }
            return item
        }
        try? await MinCloudClient.shared.pushLibrary(items: items)
    }
}
