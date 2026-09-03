import SwiftUI

struct MinCloudAccountView: View {
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
                        Task { await signOut() }
                    }
                    .disabled(isWorking)
                } else {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
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
                Text("Server-side catalogs, streaming refresh, and notifications. Local fetching stays as a backup when the service is unreachable.")
            }
            .designSystemGroupedListRow()

            Section {
                Toggle("iCloud backup", isOn: $iCloudBackupEnabled)
            } header: {
                Text("Device backup")
            } footer: {
                Text("iCloud is optional. Turn it off if Min Cloud is your sync, or keep it as a backup. The app still works with neither.")
            }
            .designSystemGroupedListRow()

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(DesignSystem.Color.textSecondary)
                }
                .designSystemGroupedListRow()
            }
        }
        .navigationTitle("Min Cloud")
        .designSystemGroupedListStyle()
        .onChange(of: iCloudBackupEnabled) { _, enabled in
            MinCloudSettings.iCloudBackupEnabled = enabled
        }
    }

    private func signIn() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await MinCloudClient.shared.login(email: email, password: password)
            await MinCloudLibrarySync.shared.syncOnSignIn()
            statusMessage = "Signed in. Catalog and library now sync through Min Cloud."
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
            await MinCloudLibrarySync.shared.syncOnSignIn()
            statusMessage = "Account created. This device will prefer Min Cloud and keep local fetch as backup."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        isWorking = true
        defer { isWorking = false }
        await MinCloudClient.shared.logout()
        statusMessage = "Signed out. Local catalog and optional iCloud backup still work."
    }
}
