import SwiftUI

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var themeManager: ThemeManager
    @Bindable var authService: GoogleOAuthService
    @Binding var searchPlacement: NavigationSearchPlacement
    var onAddChannel: () -> Void
    var onSignInTapped: () -> Void
    @AppStorage("filterShorts") private var filterShorts = true
    @AppStorage("autoUnmuteVideos") private var autoUnmuteVideos = true
    @AppStorage("backgroundPlaybackBehavior") private var backgroundPlaybackBehaviorRawValue = BackgroundPlaybackBehavior.continuePlaying.rawValue
    @AppStorage("playbackTimeLimit") private var playbackTimeLimitRawValue = PlaybackTimeLimit.off.rawValue
    @AppStorage("videoDetailPresentationMode") private var videoDetailPresentationModeRawValue = VideoDetailPresentationMode.fullYouTubePage.rawValue
    @Bindable private var affordanceStyle = MinAffordanceStyle.shared
    @State private var showsThemeSelection = false
    @State private var showsNotificationPreferences = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if authService.isSignedIn {
                        HStack {
                            Label("Google connected", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Disconnect", role: .destructive) {
                                authService.signOut()
                            }
                        }
                    } else {
                        Text("Connect Google to sync your subscriptions and load your feed.")
                            .foregroundStyle(DesignSystem.Color.textSecondary)
                            .font(DesignSystem.Typography.captionLarge)

                        Button("Sign in with Google") {
                            onSignInTapped()
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .medium))
                    }
                }
                .designSystemGroupedListRow()

                Section("Channels") {
                    Button {
                        onAddChannel()
                    } label: {
                        Label("Add Channel", systemImage: "plus.circle")
                    }
                }
                .designSystemGroupedListRow()

                Section("Notifications") {
                    Button {
                        showsNotificationPreferences = true
                    } label: {
                        Label("Notification Preferences", systemImage: "bell")
                    }
                }
                .designSystemGroupedListRow()

                Section("Appearance") {
                    Button {
                        showsThemeSelection = true
                    } label: {
                        HStack {
                            Label("Themes", systemImage: "paintbrush")
                            Spacer()
                            Text(themeManager.currentTheme.name)
                                .foregroundStyle(DesignSystem.Color.textSecondary)
                        }
                    }

                    Picker("Search Placement", selection: $searchPlacement) {
                        Text("Top leading").tag(NavigationSearchPlacement.topLeading)
                        Text("Bottom trailing").tag(NavigationSearchPlacement.bottomTrailing)
                    }
                    .pickerStyle(.menu)

                    Toggle("Affordance border", isOn: $affordanceStyle.borderEnabled)

                    Picker("Affordance shape", selection: $affordanceStyle.shape) {
                        ForEach(MinAffordanceStyle.Shape.allCases, id: \.self) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .designSystemGroupedListRow()

                Section("Feed") {
                    Toggle("Filter Shorts", isOn: $filterShorts)
                }
                .designSystemGroupedListRow()

                Section("Playback") {
                    Toggle("Auto-unmute Videos", isOn: $autoUnmuteVideos)

                    Picker("When Backgrounded", selection: $backgroundPlaybackBehaviorRawValue) {
                        ForEach(BackgroundPlaybackBehavior.allCases, id: \.rawValue) { behavior in
                            Text(behavior.title).tag(behavior.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Time Limit", selection: $playbackTimeLimitRawValue) {
                        ForEach(PlaybackTimeLimit.allCases, id: \.rawValue) { limit in
                            Text(limit.title).tag(limit.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Video Detail Layout", selection: $videoDetailPresentationModeRawValue) {
                        ForEach(VideoDetailPresentationMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .designSystemGroupedListRow()

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(DesignSystem.Typography.captionLarge)
                            .foregroundStyle(DesignSystem.Color.textSecondary)
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Account")
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
            .sheet(isPresented: $showsThemeSelection) {
                NavigationStack {
                    ThemeSelectionView(themeManager: themeManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsNotificationPreferences) {
                NavigationStack {
                    NotificationPreferencesView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .bottomSheetPullToDismiss()
    }
}
