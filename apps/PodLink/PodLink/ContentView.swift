import SwiftUI

extension NavigationSearchPlacement {
    var displayName: String {
        switch self {
        case .topLeading: return "Top Left"
        case .bottomTrailing: return "Bottom Right (WatchEdit)"
        }
    }

    var description: String {
        switch self {
        case .topLeading: return "Classic navigation bar search button"
        case .bottomTrailing: return "Floating glass search button above content"
        }
    }
}

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("layoutMode") private var layoutMode = "grid"
    @AppStorage("showPodcastTitlesOnMain") private var showPodcastTitlesOnMain = false
    @AppStorage("mainScreenArtEmphasis") private var mainScreenArtEmphasisRaw = MainScreenArtEmphasis.largeArt.rawValue
    @AppStorage("navigationSearchPlacement") private var navigationSearchPlacement = NavigationSearchPlacement.topLeading.rawValue
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue
    @AppStorage("miniPlayerFloatVerticalSnap") private var miniPlayerFloatVerticalSnap = MiniPlayerFloatVerticalSnap.bottom.rawValue
    @AppStorage("autoQueueRefreshPolicy") private var autoQueueRefreshPolicyRaw = AutoQueueRefreshPolicy.libraryChanges.rawValue

    private var autoQueueRefreshPolicy: AutoQueueRefreshPolicy {
        AutoQueueRefreshPolicy(rawValue: autoQueueRefreshPolicyRaw) ?? .libraryChanges
    }

    @State private var rootSheet: ContentRootSheet?
    @State private var autoQueueRefreshTask: Task<Void, Never>?
    @State private var isSearchSheetPresented = false
    @State private var deepLinkEpisodeHint: PodLinkEpisodeHint?

    /// Grid + no titles (compact posters). List + titles uses the same large-art emphasis.
    private var isGridPosterStyle: Bool {
        layoutMode == "grid" && !showPodcastTitlesOnMain
    }

    private func toggleMainViewDisplayStyle() {
        if isGridPosterStyle {
            layoutMode = "list"
            showPodcastTitlesOnMain = true
        } else {
            layoutMode = "grid"
            showPodcastTitlesOnMain = false
        }
        mainScreenArtEmphasisRaw = MainScreenArtEmphasis.largeArt.rawValue
    }

    private var searchPlacement: NavigationSearchPlacement {
        NavigationSearchPlacement(rawValue: navigationSearchPlacement) ?? .topLeading
    }

    private var isMicroplayerSelected: Bool {
        miniPlayerSize == MiniPlayerSize.microplayer.rawValue
    }

    private var usesBottomTrailingSearch: Bool {
        isMicroplayerSelected || searchPlacement == .bottomTrailing
    }

    private var floatingMiniAtBottom: Bool {
        (miniPlayerDockMode != MiniPlayerDockMode.docked.rawValue || miniPlayerSize == MiniPlayerSize.microplayer.rawValue)
            && (miniPlayerFloatVerticalSnap == MiniPlayerFloatVerticalSnap.bottom.rawValue
                || miniPlayerSize == MiniPlayerSize.microplayer.rawValue)
            && playbackService.state.currentEpisode != nil
            && !playbackService.isEpisodePlayerUIVisible
    }

    private var bottomTrailingSearchBottomPadding: CGFloat {
        if isMicroplayerSelected { return DesignSystem.Spacing.sm }
        return floatingMiniAtBottom ? 96 : DesignSystem.Spacing.lg
    }

    private var topControlSize: CGFloat { MinSpacing.TopControls.buttonSize }

    /// Now-playing sheet over the main `NavigationStack` (no podcast/search/account sheet open).
    private var nowPlayingOverNavigationStack: Binding<Bool> {
        Binding(
            get: {
                playbackService.isNowPlayingSheetPresented
                    && rootSheet == nil
                    && !isSearchSheetPresented
                    && playbackService.state.currentEpisode != nil
            },
            set: { presented in
                if !presented { playbackService.isNowPlayingSheetPresented = false }
            }
        )
    }

    /// Now-playing sheet stacked on top of podcast / search / account.
    private var nowPlayingOverRootModal: Binding<Bool> {
        Binding(
            get: {
                playbackService.isNowPlayingSheetPresented
                    && rootSheet != nil
                    && playbackService.state.currentEpisode != nil
            },
            set: { presented in
                if !presented { playbackService.isNowPlayingSheetPresented = false }
            }
        )
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                NavigationStack {
                    VStack(spacing: 0) {
                        MainScreenDockedMiniPlayerSlot()
                        PodcastListView(rootSheet: $rootSheet)
                    }
                    .overlay(alignment: .bottomLeading) {
                        containedTopControlButton(
                            systemName: isGridPosterStyle ? "list.bullet" : "square.grid.2x2",
                            accessibilityLabel: isGridPosterStyle ? "Switch to list view" : "Switch to grid view",
                            action: toggleMainViewDisplayStyle
                        )
                        .padding(.leading, DesignSystem.Spacing.lg)
                        .padding(.bottom, bottomTrailingSearchBottomPadding)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if usesBottomTrailingSearch {
                            containedTopControlButton(
                                systemName: "magnifyingglass",
                                accessibilityLabel: "Search",
                                action: openSearch
                            )
                            .padding(.trailing, DesignSystem.Spacing.lg)
                            .padding(.bottom, bottomTrailingSearchBottomPadding)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .overlay(alignment: .top) {
                        mainTopControls
                    }
                }
                .themeBackground()
                .sheet(isPresented: nowPlayingOverNavigationStack) {
                    nowPlayingSheetContent
                }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .task(id: hasCompletedOnboarding) {
            guard hasCompletedOnboarding else { return }
            await playbackService.restoreResumeSessionIfNeeded()
            scheduleLaunchMaintenance()
        }
        .onDisappear {
            autoQueueRefreshTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                autoQueueRefreshTask?.cancel()
                playbackService.saveResumeSessionNow()
            } else if phase == .active {
                scheduleDeferredRetentionSweep()
            }
        }
        .sheet(item: $rootSheet) { sheet in
            Group {
                switch sheet {
                case .podcast(let podcast):
                    PodcastDetailView(
                        podcast: podcast,
                        initialDeepLinkEpisode: deepLinkEpisodeHint,
                        onHandledInitialDeepLinkEpisode: { deepLinkEpisodeHint = nil }
                    )
                case .account:
                    AccountSheetView()
                case .offline:
                    OfflineView()
                case .search:
                    SearchScreenView(focusOnOpen: true)
                }
            }
            .environment(themeManager)
            .environment(playbackService)
            .environment(downloadManager)
            .environment(networkStatusService)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .sheet(isPresented: nowPlayingOverRootModal) {
                nowPlayingSheetContent
            }
        }
        .sheet(isPresented: $isSearchSheetPresented) {
            SearchScreenView(focusOnOpen: true)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .environment(networkStatusService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .sheet(isPresented: nowPlayingOverRootModal) {
                    nowPlayingSheetContent
                }
        }
        .onOpenURL { url in
            Task { await handleIncomingDeepLink(url) }
        }
    }

    private func scheduleLaunchMaintenance() {
        autoQueueRefreshTask?.cancel()
        let playbackService = playbackService
        autoQueueRefreshTask = Task(priority: .background) {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            while playbackService.isPlaybackStartupInProgress {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }

            let followed = Podcast.loadFollowedPodcasts()
            await MinCloudClient.shared.syncFollowedWatches(followed)
            await EpisodeNotificationService.shared.presentCloudInbox()
            let feedMap = await withTaskGroup(of: (String, [Episode])?.self, returning: [String: [Episode]].self) { group in
                for podcast in followed {
                    group.addTask {
                        guard let episodes = try? await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL) else { return nil }
                        return (podcast.id, episodes)
                    }
                }
                var map: [String: [Episode]] = [:]
                for await result in group {
                    guard let (id, episodes) = result else { continue }
                    map[id] = episodes
                }
                return map
            }

            guard !Task.isCancelled else { return }
            await playbackService.queueLatestUnfinishedFromFollowedPodcasts(prefetchedFeeds: feedMap)
            guard !Task.isCancelled else { return }
            DownloadRetentionEngine.runSweep()
        }
    }

    private func scheduleDeferredRetentionSweep() {
        let playbackService = playbackService
        Task(priority: .background) {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard !playbackService.isPlaybackStartupInProgress else { return }
            DownloadRetentionEngine.runSweep()
        }
    }

    private var mainTopControls: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Spacer()

            if !usesBottomTrailingSearch {
                containedTopControlButton(
                    systemName: "magnifyingglass",
                    accessibilityLabel: "Search",
                    action: openSearch
                )
            }

            if !networkStatusService.isOnline {
                containedTopControlButton(
                    systemName: "arrow.down.circle",
                    accessibilityLabel: "Offline",
                    action: { presentRootSheet(.offline) }
                )
            }

            containedTopControlButton(
                systemName: "person.crop.circle",
                accessibilityLabel: "Account",
                action: { presentRootSheet(.account) }
            )
        }
        .padding(.horizontal, MinSpacing.lg)
        .padding(.top, MinSpacing.TopControls.verticalPadding)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .zIndex(100)
    }

    private func containedTopControlButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        let aff = MinAffordanceStyle.shared
        return Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: topControlSize, height: topControlSize)
                .contentShape(Rectangle())
                .frostedSurface(aff.insettableCircleShape)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
    }

    private func presentRootSheet(_ sheet: ContentRootSheet) {
        if rootSheet == sheet {
            rootSheet = nil
            DispatchQueue.main.async {
                rootSheet = sheet
            }
        } else {
            rootSheet = sheet
        }
    }

    private func openSearch() {
        playbackService.isNowPlayingSheetPresented = false
        if rootSheet != nil {
            rootSheet = nil
            DispatchQueue.main.async {
                isSearchSheetPresented = true
            }
        } else {
            isSearchSheetPresented = true
        }
    }

    @MainActor
    private func handleIncomingDeepLink(_ url: URL) async {
        guard let deepLink = PodLinkDeepLink(url: url) else { return }

        let feedURL: URL
        let episodeHint: PodLinkEpisodeHint?
        switch deepLink {
        case .show(let targetFeedURL):
            feedURL = targetFeedURL
            episodeHint = nil
        case .episode(let targetFeedURL, let hint):
            feedURL = targetFeedURL
            episodeHint = hint
        }

        let canonicalFeedURL = PrivateFeedAuthStore.canonicalFeedURL(feedURL)
        let followed = Podcast.loadFollowedPodcasts()
        let existing = followed.first {
            PrivateFeedAuthStore.canonicalFeedURL($0.feedURL) == canonicalFeedURL
        }

        deepLinkEpisodeHint = episodeHint
        isSearchSheetPresented = false
        playbackService.isNowPlayingSheetPresented = false

        // Open immediately so deep links feel responsive, then hydrate metadata in background.
        let placeholderPodcast = Podcast(
            id: canonicalFeedURL.absoluteString,
            title: placeholderPodcastTitle(for: canonicalFeedURL),
            author: "",
            description: "",
            feedURL: canonicalFeedURL
        )
        let initialPodcast = existing ?? placeholderPodcast
        presentRootSheet(.podcast(initialPodcast))

        guard existing == nil else { return }

        let resolvedPodcast = try? await RSSFeedService.shared.fetchPodcastMetadata(feedURL: canonicalFeedURL)
        guard let resolvedPodcast else { return }

        if let currentPodcast = currentRootSheetPodcast(),
           PrivateFeedAuthStore.canonicalFeedURL(currentPodcast.feedURL) == canonicalFeedURL {
            presentRootSheet(.podcast(resolvedPodcast))
        }
    }

    private func placeholderPodcastTitle(for feedURL: URL) -> String {
        if let host = feedURL.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
        }
        return "Podcast"
    }

    private func currentRootSheetPodcast() -> Podcast? {
        guard case .podcast(let podcast) = rootSheet else { return nil }
        return podcast
    }

    // MARK: - Auto-Queue Refresh

    private enum AutoQueueRefreshReason {
        case followedPodcasts
        case playback
    }

    private func scheduleAutoQueueRefresh() {
        guard scenePhase == .active else { return }
        autoQueueRefreshTask?.cancel()
        autoQueueRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await playbackService.queueLatestUnfinishedFromFollowedPodcasts()
        }
    }

    private func scheduleAutoQueueRefreshIfAllowed(reason: AutoQueueRefreshReason) {
        switch autoQueueRefreshPolicy {
        case .launchOnly:
            return
        case .libraryChanges:
            guard reason == .followedPodcasts else { return }
            scheduleAutoQueueRefresh()
        case .adaptive:
            scheduleAutoQueueRefresh()
        }
    }

    @ViewBuilder
    private var nowPlayingSheetContent: some View {
        if let episode = playbackService.state.currentEpisode {
            EpisodePlayerSheet(
                episode: episode,
                onOpenPodcast: { podcast in
                    playbackService.isNowPlayingSheetPresented = false
                    rootSheet = .podcast(podcast)
                }
            )
                .environment(themeManager)
                .environment(playbackService)
                .presentationDragIndicator(.visible)
        }
    }
}
