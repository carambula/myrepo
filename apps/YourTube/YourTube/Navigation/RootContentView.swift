import SwiftData
import SwiftUI

struct RootContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var rootSheet: RootSheet?
    @State private var selectedVideoForDetail: YTVideo?
    @State private var selectedVideoForPlayer: YTVideo?
    @State private var pendingVideoForPlayer: YTVideo?
    @State private var selectedChannelForDetail: YTChannel?
    @State private var searchPlacement: NavigationSearchPlacement = .topLeading
    @State private var authErrorMessage: String?

    @Bindable var themeManager: ThemeManager
    @Bindable var authService: GoogleOAuthService
    @Bindable var syncStore: UserDataSyncStore
    @Binding var deepLinkVideoID: String?
    @State var feedViewModel: SubscriptionsFeedViewModel

    init(themeManager: ThemeManager, authService: GoogleOAuthService, syncStore: UserDataSyncStore, deepLinkVideoID: Binding<String?>) {
        self.themeManager = themeManager
        self.authService = authService
        self.syncStore = syncStore
        _deepLinkVideoID = deepLinkVideoID
        _feedViewModel = State(initialValue: SubscriptionsFeedViewModel(apiClient: YouTubeAPIClient(), authService: authService))
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainExperience
            } else {
                OnboardingView(
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    searchPlacement: $searchPlacement,
                    themeManager: themeManager,
                    authService: authService,
                    onConnectGoogle: {
                        try await connectGoogleAndRefreshFeed()
                    }
                )
                .onChange(of: searchPlacement) {
                    syncStore.syncSearchPlacementToCloud(searchPlacement)
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
    }

    private var mainExperience: some View {
        NavigationStack {
            SubscriptionsFeedView(
                viewModel: feedViewModel,
                theme: themeManager.currentTheme,
                onVideoSelected: { video in
                    selectedVideoForDetail = video
                },
                onVideoPlaySelected: { video in
                    selectedVideoForPlayer = video
                },
                onChannelSelected: { channel in
                    selectedChannelForDetail = channel
                },
                onConnectGoogle: {
                    Task { await signInAndRefresh() }
                },
                onAddChannel: {
                    rootSheet = .addChannel
                }
            )
            .overlay(alignment: .bottomLeading) {
                Button {
                    feedViewModel.toggleLayout()
                } label: {
                    Image(systemName: feedViewModel.isGrid ? DesignSystem.Icon.list : DesignSystem.Icon.grid)
                }
                .buttonStyle(CircularGlassIconButtonStyle(size: DesignSystem.Controls.iconButtonSize))
                .accessibilityIdentifier("layoutToggleButton")
                .padding(.leading, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .overlay(alignment: .bottomTrailing) {
                if searchPlacement == .bottomTrailing {
                    Button {
                        rootSheet = .search
                    } label: {
                        Image(systemName: DesignSystem.Icon.search)
                    }
                    .buttonStyle(CircularGlassIconButtonStyle(size: DesignSystem.Controls.iconButtonSize))
                    .accessibilityIdentifier("floatingSearchButton")
                    .padding(.trailing, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
            .themeBackground(using: themeManager.currentTheme)
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                topControls
                    .padding(.horizontal, MinSpacing.lg)
                    .padding(.top, MinSpacing.TopControls.verticalPadding)
            }
            .sheet(item: $rootSheet) { sheet in
                switch sheet {
                case .account:
                    AccountSheetView(
                        themeManager: themeManager,
                        authService: authService,
                        searchPlacement: $searchPlacement,
                        onAddChannel: { rootSheet = .addChannel },
                        onSignInTapped: {
                            Task { await signInAndRefresh() }
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .search:
                    SubscriptionSearchView(theme: themeManager.currentTheme) { video in
                        selectedVideoForDetail = video
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .addChannel:
                    AddChannelView(
                        theme: themeManager.currentTheme,
                        apiClient: YouTubeAPIClient(),
                        authService: authService
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $selectedVideoForDetail, onDismiss: {
                if let pendingVideoForPlayer {
                    selectedVideoForPlayer = pendingVideoForPlayer
                    self.pendingVideoForPlayer = nil
                }
            }) { video in
                VideoDetailView(
                    video: video,
                    channel: feedViewModel.channels.first(where: { $0.channelID == video.channelID }),
                    theme: themeManager.currentTheme,
                    onPlayFullscreen: { selectedVideo in
                        pendingVideoForPlayer = selectedVideo
                        selectedVideoForDetail = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedChannelForDetail) { channel in
                ChannelDetailView(
                    channel: channel,
                    theme: themeManager.currentTheme,
                    onVideoSelected: { video in
                        selectedChannelForDetail = nil
                        selectedVideoForDetail = video
                    },
                    onVideoPlaySelected: { video in
                        selectedChannelForDetail = nil
                        selectedVideoForPlayer = video
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedVideoForPlayer) { video in
                VideoPlayerSheet(video: video, theme: themeManager.currentTheme)
            }
            .onChange(of: deepLinkVideoID) {
                guard let videoID = deepLinkVideoID else { return }
                deepLinkVideoID = nil
                selectedVideoForDetail = nil
                selectedChannelForDetail = nil
                rootSheet = nil
                let video = YTVideo(videoID: videoID, channelID: "", title: "")
                selectedVideoForPlayer = video
            }
            .alert("Sign-in error", isPresented: .constant(authErrorMessage != nil), actions: {
                Button("OK", role: .cancel) { authErrorMessage = nil }
            }, message: {
                Text(authErrorMessage ?? "")
            })
            .task {
                if let cloudPlacement = syncStore.searchPlacementFromCloud() {
                    searchPlacement = cloudPlacement
                }
                syncStore.hydrateLocalSubscriptions(modelContext: modelContext)
            }
            .onChange(of: searchPlacement) {
                syncStore.syncSearchPlacementToCloud(searchPlacement)
            }
            .onChange(of: feedViewModel.channels) {
                let subscribed = feedViewModel.channels
                    .filter(\.isUserSubscribed)
                    .map(\.channelID)
                syncStore.syncSubscriptionsToCloud(channelIDs: subscribed)
            }
        }
    }

    private var topControls: some View {
        HStack(spacing: MinSpacing.TopControls.horizontalPadding) {
            Spacer()

            if searchPlacement == .topLeading {
                Button {
                    rootSheet = .search
                } label: {
                    Image(systemName: DesignSystem.Icon.search)
                }
                .buttonStyle(CircularGlassIconButtonStyle())
                .accessibilityIdentifier("topSearchButton")
            }

            Button {
                rootSheet = .account
            } label: {
                Image(systemName: DesignSystem.Icon.account)
            }
            .buttonStyle(CircularGlassIconButtonStyle())
            .accessibilityIdentifier("accountButton")
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .zIndex(100)
    }

    private func signInAndRefresh() async {
        do {
            try await connectGoogleAndRefreshFeed()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func connectGoogleAndRefreshFeed() async throws {
        try await authService.signIn()
        await feedViewModel.refresh(modelContext: modelContext)
    }
}
