import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyField = ""
    @State private var statusMessage: String?
    @State private var isSaving = false

    private var hasExistingKey: Bool { TranscriptionAPIKeyStore.hasAPIKey }

    var body: some View {
        List {
            Section {
                SecureField(
                    hasExistingKey ? "New key (leave blank to keep)" : "AssemblyAI API key",
                    text: $apiKeyField
                )
                .textContentType(.password)
                .autocorrectionDisabled()

                Button {
                    saveKey()
                } label: {
                    if isSaving {
                        HStack {
                            ProgressView()
                            Text("Saving…")
                        }
                    } else {
                        Text("Save key")
                    }
                }
                .disabled(isSaving)

                if hasExistingKey {
                    Button("Remove saved key", role: .destructive) {
                        removeKey()
                    }
                }
            } header: {
                Text("AssemblyAI")
            } footer: {
                Text(
                    "PodLink sends your episode’s public audio URL to AssemblyAI; their servers download and transcribe it. You pay AssemblyAI per minute according to your plan. The key is stored only in this device’s Keychain."
                )
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Link("AssemblyAI dashboard", destination: URL(string: "https://www.assemblyai.com/app")!)
                    .foregroundColor(themeManager.currentTheme.accentColor)
            } header: {
                Text("Account")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Transcription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: DesignSystem.Icon.close)
                        .viewControlIconStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
        .onAppear {
            apiKeyField = ""
        }
        .safeAreaInset(edge: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    private func saveKey() {
        isSaving = true
        statusMessage = nil
        let trimmed = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                if trimmed.isEmpty, hasExistingKey {
                    await MainActor.run {
                        statusMessage = "Existing key kept."
                        isSaving = false
                    }
                    return
                }
                if trimmed.isEmpty {
                    await MainActor.run {
                        statusMessage = "Enter a key or remove the old one first."
                        isSaving = false
                    }
                    return
                }
                try TranscriptionAPIKeyStore.saveAPIKey(trimmed)
                await MainActor.run {
                    apiKeyField = ""
                    statusMessage = "Saved."
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Could not save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func removeKey() {
        Task {
            do {
                try TranscriptionAPIKeyStore.saveAPIKey(nil)
                await MainActor.run {
                    apiKeyField = ""
                    statusMessage = "Key removed."
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                }
            }
        }
    }
}
