import SwiftUI

struct SearchScreenView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(NetworkStatusService.self) private var networkStatusService
    @Environment(\.dismiss) private var dismiss

    let focusOnOpen: Bool

    @State private var searchText = ""
    @State private var searchScope: SearchScope = .discover
    @State private var discoverResults: [Podcast] = []
    @State private var libraryEpisodeResults: [LibraryEpisodeSearchResult] = []
    @State private var followedIds: Set<String> = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisodeResult: LibraryEpisodeSearchResult?
    @State private var urlAuthRequiredFor: URL?
    @State private var urlLookupError: String?
    @State private var showPrivateFeedSheet = false
    @State private var privateFeedPrefillURL: String = ""
    @State private var suggestedInterestKeywords: [String] = []
    @State private var suggestionRefreshTask: Task<Void, Never>?
    @State private var statusFilter: EpisodeStatusFilter = .all
    @State private var showNewOnly = false
    @State private var showVideoOnly = false
    @State private var selectedCategory: PodcastCategory?
    @AppStorage("searchSuggestionRefreshPolicy") private var searchSuggestionRefreshPolicyRaw = SearchSuggestionRefreshPolicy.onOpenAndLibraryChanges.rawValue
    @AppStorage("searchSuggestionLastRefreshAt") private var searchSuggestionLastRefreshAt: Double = 0
    @FocusState private var isSearchFieldFocused: Bool

    private enum SuggestionRefreshReason {
        case onOpen
        case libraryChange
        case historyChange
        case keywordsChange
    }

    private var suggestionRefreshPolicy: SearchSuggestionRefreshPolicy {
        SearchSuggestionRefreshPolicy(rawValue: searchSuggestionRefreshPolicyRaw) ?? .onOpenAndLibraryChanges
    }

    private func shouldRefreshSuggestions(for reason: SuggestionRefreshReason) -> Bool {
        let cooldown: TimeInterval
        switch suggestionRefreshPolicy {
        case .onOpenOnly:
            guard reason == .onOpen else { return false }
            cooldown = 30 * 60
        case .onOpenAndLibraryChanges:
            guard reason == .onOpen || reason == .libraryChange else { return false }
            cooldown = 10 * 60
        case .live:
            cooldown = 2 * 60
        }
        let lastRefresh = Date(timeIntervalSince1970: searchSuggestionLastRefreshAt)
        return Date().timeIntervalSince(lastRefresh) >= cooldown
    }

    private func scheduleSuggestedKeywordRefresh(reason: SuggestionRefreshReason) {
        guard shouldRefreshSuggestions(for: reason) else { return }
        suggestionRefreshTask?.cancel()
        suggestionRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            loadSuggestedInterestKeywords()
            searchSuggestionLastRefreshAt = Date().timeIntervalSince1970
        }
    }

    private let searchControlHeight: CGFloat = 56

    struct LibraryEpisodeSearchResult: Identifiable {
        let episode: Episode
        let podcast: Podcast

        var id: String { episode.id }
    }

    enum SearchScope: String, CaseIterable {
        case library = "My Library"
        case discover = "Discover"
    }

    private var isDiscoverOffline: Bool {
        searchScope == .discover && !networkStatusService.isOnline
    }

    init(focusOnOpen: Bool = false) {
        self.focusOnOpen = focusOnOpen
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scope picker
            Picker("Scope", selection: $searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 36)
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.md + DesignSystem.Spacing.xs)
            .padding(.bottom, DesignSystem.Spacing.md)

            FilterBarView(
                statusFilter: $statusFilter,
                selectedCategory: $selectedCategory,
                showNewOnly: $showNewOnly,
                showVideoOnly: $showVideoOnly
            )
            .padding(.bottom, DesignSystem.Spacing.sm)

            if isDiscoverOffline {
                Label("Discover search is unavailable offline. Downloaded and library content still works.", systemImage: "wifi.slash")
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }

            ScrollView {
                Group {
                    if isSearching {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text("Searching...")
                                .font(DesignSystem.Typography.bodyMedium())
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                        .padding(.vertical, DesignSystem.Spacing.xxl)
                    } else if currentResultsAreEmpty && hasActiveSearch {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text(urlAuthRequiredFor != nil ? "Authentication needed" : "No Results")
                                .font(DesignSystem.Typography.headlineLarge())
                                .foregroundColor(DesignSystem.Colors.headlineColor)
                            Text(
                                urlAuthRequiredFor != nil
                                    ? "This feed requires a token or login. Add it from the private RSS screen."
                                    : (urlLookupError
                        ?? (libraryFilters.isRestrictingLibrary
                            ? "No episodes match this filter."
                            : "Try a different search term."))
                            )
                                .font(DesignSystem.Typography.bodyMedium())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.leading)

                            if urlAuthRequiredFor != nil {
                                Button {
                                    if let u = urlAuthRequiredFor {
                                        privateFeedPrefillURL = u.absoluteString
                                    }
                                    showPrivateFeedSheet = true
                                } label: {
                                    Text("Add private RSS…")
                                }
                                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                        .padding(.vertical, DesignSystem.Spacing.xxl)
                    } else if currentResultsAreEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            categoriesSection
                            if !suggestedInterestKeywords.isEmpty {
                                suggestedSearchesSection
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                        .padding(.top, DesignSystem.Spacing.lg)
                    } else {
                        if searchScope == .library {
                            libraryEpisodeResultsList
                        } else {
                            SearchResultsView(
                                results: discoverResults,
                                followedIds: followedIds,
                                onSelectPodcast: openPodcastFromSearch(_:),
                                onToggleFollow: toggleFollow(_:)
                            )
                        }
                    }
                }
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        }
        .themeBackground()
        .safeAreaInset(edge: .bottom) {
            searchBottomControls
        }
        .onAppear {
            playbackService.pushSearchUISession()
            refreshFollowedIds()
            loadSuggestedInterestKeywords()
            scheduleSuggestedKeywordRefresh(reason: .onOpen)
            if focusOnOpen {
                Task { @MainActor in
                    await Task.yield()
                    isSearchFieldFocused = true
                }
            }
        }
        .onDisappear {
            playbackService.popSearchUISession()
            searchTask?.cancel()
            suggestionRefreshTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .followedPodcastsDidChange)) { _ in
            refreshFollowedIds()
            scheduleSuggestedKeywordRefresh(reason: .libraryChange)
        }
        .onReceive(NotificationCenter.default.publisher(for: .listeningHistoryDidChange)) { _ in
            scheduleSuggestedKeywordRefresh(reason: .historyChange)
        }
        .onReceive(NotificationCenter.default.publisher(for: .interestKeywordsDidChange)) { _ in
            scheduleSuggestedKeywordRefresh(reason: .keywordsChange)
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await performSearch(query: newValue)
            }
        }
        .onChange(of: searchScope) { _, _ in
            retriggerSearch()
        }
        .onChange(of: statusFilter) { _, newValue in
            if newValue != .all {
                searchScope = .library
            }
            retriggerSearch()
        }
        .onChange(of: showNewOnly) { _, _ in
            if showNewOnly { searchScope = .library }
            retriggerSearch()
        }
        .onChange(of: showVideoOnly) { _, _ in
            if showVideoOnly { searchScope = .library }
            retriggerSearch()
        }
        .onChange(of: selectedCategory) { _, _ in
            retriggerSearch()
        }
        .onChange(of: networkStatusService.isOnline) { _, isOnline in
            if !isOnline, searchScope == .discover {
                searchTask?.cancel()
                isSearching = false
                discoverResults = []
                libraryEpisodeResults = []
                urlAuthRequiredFor = nil
                urlLookupError = "Discover search is unavailable while offline."
            }
        }
        .bottomSheetPullToDismiss()
        .sheet(item: $selectedPodcast) { podcast in
            PodcastDetailView(podcast: podcast)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedEpisodeResult) { result in
            EpisodePlayerSheet(episode: result.episode, fallbackPodcast: result.podcast)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .environment(networkStatusService)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivateFeedSheet) {
            NavigationStack {
                AddPrivateFeedView(initialURLString: privateFeedPrefillURL.isEmpty ? nil : privateFeedPrefillURL)
                    .environment(themeManager)
                    .environment(playbackService)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showPrivateFeedSheet = false
                            } label: {
                                Image(systemName: DesignSystem.Icon.close)
                                    .viewControlIconStyle()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cancel")
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .environment(themeManager)
            .environment(playbackService)
            .bottomSheetPullToDismiss()
            .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        }
    }

    private var libraryFilters: LibrarySearchFilters {
        LibrarySearchFilters(
            status: statusFilter,
            showNewOnly: showNewOnly,
            showVideoOnly: showVideoOnly,
            selectedCategory: selectedCategory
        )
    }

    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (searchScope == .library && libraryFilters.isRestrictingLibrary)
    }

    private func retriggerSearch() {
        searchTask?.cancel()
        searchTask = Task { await performSearch(query: searchText) }
    }

    private var searchBottomControls: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            EpisodeStatusFilterButton(statusFilter: $statusFilter, size: searchControlHeight)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                TextField("Search or paste RSS URL…", text: $searchText)
                    .font(DesignSystem.Typography.bodyMedium())
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .disabled(isDiscoverOffline)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .frame(height: searchControlHeight)
            .background(.thinMaterial)
            .clipShape(MinAffordanceStyle.shared.capsuleShape)
            .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.capsuleShape.stroke(Color.white.opacity(0.28), lineWidth: 0.8) } }

            Button {
                dismiss()
            } label: {
                Image(systemName: DesignSystem.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: searchControlHeight, height: searchControlHeight)
                    .background(.thinMaterial)
                    .clipShape(MinAffordanceStyle.shared.circleShape)
                    .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.circleShape.stroke(Color.white.opacity(0.28), lineWidth: 0.8) } }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Search")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.clear)
    }

    private static let podcastCategories = [
        "True Crime", "Comedy", "Technology", "News",
        "Health & Fitness", "Business", "Sports", "Music",
        "Science", "Education", "History", "Society & Culture"
    ]

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Categories")
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.bottom, DesignSystem.Spacing.xs)

            ForEach(Self.podcastCategories, id: \.self) { category in
                Button {
                    applySuggestedKeyword(category)
                } label: {
                    Text(category)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestedSearchesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Suggested from your listening")
                .font(DesignSystem.Typography.bodySmall())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.bottom, DesignSystem.Spacing.xs)

            ForEach(suggestedInterestKeywords, id: \.self) { keyword in
                Button {
                    applySuggestedKeyword(keyword)
                } label: {
                    Text(keyword)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var libraryEpisodeResultsList: some View {
        LazyVStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(libraryEpisodeResults) { result in
                EpisodeRowView(
                    episode: result.episode,
                    podcast: result.podcast,
                    onTap: { openLibraryEpisodeFromSearch(result) }
                )
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
        }
    }

    private var currentResultsAreEmpty: Bool {
        switch searchScope {
        case .discover:
            return discoverResults.isEmpty
        case .library:
            return libraryEpisodeResults.isEmpty
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let filters = libraryFilters
        let canBrowseLibrary = searchScope == .library && filters.isRestrictingLibrary
        guard !trimmed.isEmpty || canBrowseLibrary else {
            discoverResults = []
            libraryEpisodeResults = []
            urlAuthRequiredFor = nil
            urlLookupError = nil
            return
        }

        if searchScope == .discover, !networkStatusService.isOnline {
            discoverResults = []
            libraryEpisodeResults = []
            urlAuthRequiredFor = nil
            urlLookupError = "Discover search is unavailable while offline."
            return
        }

        urlAuthRequiredFor = nil
        urlLookupError = nil

        // RSS URL resolution is for Discover; My Library should always filter saved podcasts.
        if searchScope == .discover, !trimmed.isEmpty, let feedURL = Self.normalizedFeedURL(from: query) {
            isSearching = true
            await resolveDirectFeedURL(feedURL)
            isSearching = false
            return
        }

        isSearching = true
        do {
            switch searchScope {
            case .discover:
                let results = trimmed.isEmpty
                    ? []
                    : try await PodcastSearchService.shared.search(query: query)
                discoverResults = results.filter { filters.matchesDiscover($0) }
                libraryEpisodeResults = []
            case .library:
                let podcasts = Podcast.loadFollowedPodcasts()
                libraryEpisodeResults = await searchLibraryEpisodes(
                    query: trimmed,
                    podcasts: podcasts,
                    filters: filters
                )
                discoverResults = []
            }
        } catch {
            discoverResults = []
            libraryEpisodeResults = []
        }
        isSearching = false
    }

    private func resolveDirectFeedURL(_ feedURL: URL) async {
        do {
            if let podcast = try await RSSFeedService.shared.fetchPodcastMetadata(feedURL: feedURL) {
                discoverResults = [podcast]
                libraryEpisodeResults = []
                urlLookupError = nil
            } else {
                discoverResults = []
                libraryEpisodeResults = []
                urlLookupError = "That URL does not look like a podcast RSS feed."
            }
        } catch RSSFeedError.authenticationRequired {
            discoverResults = []
            libraryEpisodeResults = []
            urlAuthRequiredFor = feedURL
        } catch RSSFeedError.httpFailure(let code) {
            discoverResults = []
            libraryEpisodeResults = []
            urlLookupError = "Server error (HTTP \(code))."
        } catch {
            discoverResults = []
            libraryEpisodeResults = []
            urlLookupError = error.localizedDescription
        }
    }

    private static func normalizedFeedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return PrivateFeedAuthStore.canonicalFeedURL(url)
    }

    private func refreshFollowedIds() {
        followedIds = Set(Podcast.loadFollowedPodcasts().map(\.id))
    }

    private func loadSuggestedInterestKeywords() {
        suggestedInterestKeywords = InterestKeywordService.shared.suggestedKeywords(limit: 12)
    }

    private func applySuggestedKeyword(_ keyword: String) {
        let cleaned = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        searchText = cleaned
        isSearchFieldFocused = true
    }

    private func searchLibraryEpisodes(
        query: String,
        podcasts: [Podcast],
        filters: LibrarySearchFilters
    ) async -> [LibraryEpisodeSearchResult] {
        let lowered = query.lowercased()
        var results: [LibraryEpisodeSearchResult] = []
        var seenEpisodeIDs = Set<String>()

        for podcast in podcasts {
            if Task.isCancelled { break }
            if results.count >= 250 { break }

            let episodes = await loadEpisodesForLibrarySearch(for: podcast)
            for episode in episodes {
                if Task.isCancelled { break }
                if results.count >= 250 { break }

                let merged = EpisodePlaybackStore.merge(episode)
                guard !seenEpisodeIDs.contains(merged.id) else { continue }
                guard filters.matches(episode: merged, podcast: podcast) else { continue }
                let matchesQuery: Bool
                if lowered.isEmpty {
                    matchesQuery = true
                } else {
                    matchesQuery = await episodeMatchesLibraryQuery(
                        merged,
                        podcast: podcast,
                        loweredQuery: lowered
                    )
                }
                if matchesQuery {
                    seenEpisodeIDs.insert(merged.id)
                    results.append(LibraryEpisodeSearchResult(episode: merged, podcast: podcast))
                }
            }
        }

        return results.sorted { lhs, rhs in
            lhs.episode.publishDate > rhs.episode.publishDate
        }
    }

    private func loadEpisodesForLibrarySearch(for podcast: Podcast) async -> [Episode] {
        if let cached = await RSSFeedService.shared.cachedEpisodes(feedURL: podcast.feedURL) {
            return cached
        }

        guard networkStatusService.isOnline else {
            return episodesFromDownloads(for: podcast)
        }

        do {
            return try await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL)
        } catch {
            return episodesFromDownloads(for: podcast)
        }
    }

    private func episodesFromDownloads(for podcast: Podcast) -> [Episode] {
        DownloadMetadataStore
            .allRecords()
            .values
            .filter { record in
                record.episode.podcastID == podcast.id ||
                record.episode.podcastID == podcast.feedURL.absoluteString ||
                record.podcast?.id == podcast.id ||
                record.podcast?.feedURL.absoluteString == podcast.feedURL.absoluteString
            }
            .map(\.episode)
    }

    private func episodeMatchesLibraryQuery(_ episode: Episode, podcast: Podcast, loweredQuery: String) async -> Bool {
        if episode.title.lowercased().contains(loweredQuery) || episode.description.lowercased().contains(loweredQuery) {
            return true
        }

        if podcast.title.lowercased().contains(loweredQuery) || podcast.author.lowercased().contains(loweredQuery) {
            return true
        }

        if let embeddedTranscript = episode.transcript?.lowercased(),
           embeddedTranscript.contains(loweredQuery) {
            return true
        }

        if InterestKeywordService.shared.transcriptKeywordsMatch(query: loweredQuery, episodeID: episode.id) {
            return true
        }

        if let cachedTranscriptText = await TranscriptService.shared.getCachedTranscriptText(forEpisodeID: episode.id),
           cachedTranscriptText.lowercased().contains(loweredQuery) {
            return true
        }

        return false
    }

    private func openLibraryEpisodeFromSearch(_ result: LibraryEpisodeSearchResult) {
        selectedEpisodeResult = result
    }

    private func openPodcastFromSearch(_ podcast: Podcast) {
        selectedPodcast = podcast
    }

    private func toggleFollow(_ podcast: Podcast) {
        var podcasts = Podcast.loadFollowedPodcasts()
        let feedStr = podcast.feedURL.absoluteString
        if let index = podcasts.firstIndex(where: { $0.id == podcast.id || $0.feedURL.absoluteString == feedStr }) {
            podcasts.remove(at: index)
        } else {
            var updated = podcast
            updated.isFollowed = true
            podcasts.append(updated)
        }
        Podcast.saveFollowedPodcasts(podcasts)
        refreshFollowedIds()
    }
}
