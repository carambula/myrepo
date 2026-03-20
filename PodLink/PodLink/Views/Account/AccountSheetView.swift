import SwiftUI

struct AccountSheetView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showThemes = false
    @State private var showThemeBuilder = false
    @State private var showAppearance = false
    @State private var showPlaybackSettings = false
    @State private var showConnectedAccounts = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Button { showThemes = true } label: {
                        Label("Themes", systemImage: "paintbrush")
                    }
                    Button { showThemeBuilder = true } label: {
                        Label("Create Theme", systemImage: "paintbrush.pointed")
                    }
                    Button { showAppearance = true } label: {
                        Label("Interface Options", systemImage: "slider.horizontal.3")
                    }
                }

                Section("Playback") {
                    Button { showPlaybackSettings = true } label: {
                        Label("Playback Settings", systemImage: "play.circle")
                    }
                }

                Section("Accounts") {
                    Button { showConnectedAccounts = true } label: {
                        Label("Connected Accounts", systemImage: "person.badge.key")
                    }
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }
            }
            .navigationDestination(isPresented: $showThemes) {
                ThemesView()
            }
            .navigationDestination(isPresented: $showThemeBuilder) {
                ThemeBuilderView()
            }
            .navigationDestination(isPresented: $showAppearance) {
                AppearanceSettingsView()
            }
            .navigationDestination(isPresented: $showPlaybackSettings) {
                PlaybackSettingsView()
            }
            .navigationDestination(isPresented: $showConnectedAccounts) {
                ConnectedAccountsView()
            }
        }
        .bottomSheetPullToDismiss()
    }
}
