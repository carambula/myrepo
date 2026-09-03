import MinAppKit
import SwiftUI

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager

    @State private var showThemes = false
    @State private var showAppearance = false
    @State private var showPlaybackSettings = false
    @State private var showListeningHistory = false
    @State private var showConnectedAccounts = false
    @State private var showOPML = false
    @State private var showTranscription = false
    @State private var showDownloadedEpisodes = false
    @State private var showDownloadSettings = false
    @State private var showPerformancePreferences = false
    @State private var showNotificationPreferences = false
    @State private var showMinCloud = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Button {
                        showThemes = true
                    } label: {
                        Label("Themes", systemImage: "paintbrush")
                    }

                    Button {
                        showAppearance = true
                    } label: {
                        Label("Interface Options", systemImage: "slider.horizontal.3")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Playback") {
                    Button {
                        showListeningHistory = true
                    } label: {
                        Label("Listening History", systemImage: "clock.arrow.circlepath")
                    }

                    Button {
                        showPlaybackSettings = true
                    } label: {
                        Label("Playback Settings", systemImage: "play.circle")
                    }

                    Button {
                        showPerformancePreferences = true
                    } label: {
                        Label("Background Activity", systemImage: "gauge.with.dots.needle.33percent")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Downloads") {
                    Button {
                        showDownloadedEpisodes = true
                    } label: {
                        Label("Downloaded Episodes", systemImage: "arrow.down.circle")
                    }

                    Button {
                        showDownloadSettings = true
                    } label: {
                        Label("Download Settings", systemImage: "externaldrive")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Transcripts") {
                    Button {
                        showTranscription = true
                    } label: {
                        Label("Cloud transcription (AssemblyAI)", systemImage: "text.badge.plus")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Min Cloud") {
                    Button {
                        showMinCloud = true
                    } label: {
                        Label(
                            MinCloudSettings.isSignedIn ? "Account   @\(MinCloudSettings.handle ?? "signed in")" : "Sign in or create an account",
                            systemImage: "cloud"
                        )
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Accounts") {
                    Button {
                        showConnectedAccounts = true
                    } label: {
                        Label("Member & private feeds", systemImage: "person.badge.key")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Subscriptions") {
                    Button {
                        showOPML = true
                    } label: {
                        Label("Import & export (OPML)", systemImage: "arrow.left.arrow.right.circle")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Notifications") {
                    Button {
                        showNotificationPreferences = true
                    } label: {
                        Label("Notification Preferences", systemImage: "bell")
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("Agents") {
                    AgentSettingsLink(app: .pod, exporter: PodcastAgentService.shared)
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .font(DesignSystem.Typography.bodySmall())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
            }
            .podLinkSettingsListSurface()
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
            .sheet(isPresented: $showThemes) {
                NavigationStack {
                    ThemesView()
                        .environment(themeManager)
                        .environment(playbackService)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showAppearance) {
                NavigationStack {
                    AppearanceSettingsView()
                        .environment(themeManager)
                        .environment(playbackService)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showPlaybackSettings) {
                NavigationStack {
                    PlaybackSettingsView()
                        .environment(themeManager)
                        .environment(playbackService)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showListeningHistory) {
                NavigationStack {
                    ListeningHistoryView()
                        .environment(themeManager)
                        .environment(playbackService)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showConnectedAccounts) {
                NavigationStack {
                    ConnectedAccountsView()
                        .environment(themeManager)
                        .environment(playbackService)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showOPML) {
                NavigationStack {
                    SubscriptionOPMLView()
                        .environment(themeManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showTranscription) {
                NavigationStack {
                    TranscriptionSettingsView()
                        .environment(themeManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showDownloadedEpisodes) {
                NavigationStack {
                    DownloadedEpisodesView()
                        .environment(themeManager)
                        .environment(playbackService)
                        .environment(downloadManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showPerformancePreferences) {
                NavigationStack {
                    PerformancePreferencesView()
                        .environment(themeManager)
                        .environment(playbackService)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showDownloadSettings) {
                NavigationStack {
                    DownloadSettingsView()
                        .environment(themeManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            .sheet(isPresented: $showNotificationPreferences) {
                NavigationStack {
                    NotificationPreferencesView()
                        .environment(themeManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
            .sheet(isPresented: $showMinCloud) {
                NavigationStack {
                    MinCloudAccountView()
                        .environment(themeManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(themeManager)
                .environment(playbackService)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
            }
        }
        .bottomSheetPullToDismiss()
    }
}

struct PerformancePreferencesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("autoQueueRefreshPolicy") private var autoQueueRefreshPolicy = AutoQueueRefreshPolicy.libraryChanges.rawValue
    @AppStorage("autoQueueMetadataIndexingEnabled") private var autoQueueMetadataIndexingEnabled = true
    @AppStorage("searchSuggestionRefreshPolicy") private var searchSuggestionRefreshPolicy = SearchSuggestionRefreshPolicy.onOpenAndLibraryChanges.rawValue

    private var selectedAutoQueuePolicy: Binding<AutoQueueRefreshPolicy> {
        Binding(
            get: { AutoQueueRefreshPolicy(rawValue: autoQueueRefreshPolicy) ?? .libraryChanges },
            set: { autoQueueRefreshPolicy = $0.rawValue }
        )
    }

    private var selectedSearchPolicy: Binding<SearchSuggestionRefreshPolicy> {
        Binding(
            get: { SearchSuggestionRefreshPolicy(rawValue: searchSuggestionRefreshPolicy) ?? .onOpenAndLibraryChanges },
            set: { searchSuggestionRefreshPolicy = $0.rawValue }
        )
    }

    var body: some View {
        List {
            Section {
                Picker("Refresh Policy", selection: selectedAutoQueuePolicy) {
                    ForEach(AutoQueueRefreshPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }

                Toggle("Metadata Indexing", isOn: $autoQueueMetadataIndexingEnabled)
            } header: {
                Text("Auto Queue")
            } footer: {
                Text("Controls when the auto queue rebuilds and whether episode metadata is indexed for recommendations. Reducing these saves battery.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Picker("Refresh Policy", selection: selectedSearchPolicy) {
                    ForEach(SearchSuggestionRefreshPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
            } header: {
                Text("Search Suggestions")
            } footer: {
                Text("Controls how often suggested search keywords are recalculated from your listening history.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)

            Section {
                Button("Battery Saver") {
                    autoQueueRefreshPolicy = AutoQueueRefreshPolicy.launchOnly.rawValue
                    autoQueueMetadataIndexingEnabled = false
                    searchSuggestionRefreshPolicy = SearchSuggestionRefreshPolicy.onOpenOnly.rawValue
                }
                Button("Balanced (Default)") {
                    autoQueueRefreshPolicy = AutoQueueRefreshPolicy.libraryChanges.rawValue
                    autoQueueMetadataIndexingEnabled = true
                    searchSuggestionRefreshPolicy = SearchSuggestionRefreshPolicy.onOpenAndLibraryChanges.rawValue
                }
                Button("Full Features") {
                    autoQueueRefreshPolicy = AutoQueueRefreshPolicy.adaptive.rawValue
                    autoQueueMetadataIndexingEnabled = true
                    searchSuggestionRefreshPolicy = SearchSuggestionRefreshPolicy.live.rawValue
                }
            } header: {
                Text("Presets")
            } footer: {
                Text("Quickly apply a set of background activity preferences.")
            }
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
        }
        .podLinkSettingsListSurface()
        .navigationTitle("Background Activity")
        .navigationBarTitleDisplayMode(.inline)
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
}
