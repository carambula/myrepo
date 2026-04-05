import SwiftUI

struct ListeningHistoryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    @State private var entries: [ListeningHistoryEntry] = []
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var sort: ListeningHistorySort = .recent
    @State private var playSession: ListeningHistoryPlaySession?
    @State private var podcastOpenedFromPlayer: Podcast?
    @FocusState private var isSearchFieldFocused: Bool

    private let searchControlHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if resolvedItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(resolvedItems) { item in
                            EpisodeRowView(
                                episode: item.episode,
                                podcast: item.podcast,
                                onTap: { openPlay(item) },
                                showsDownloadAffordance: false
                            )

                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
            }

            if !isSearchActive {
                searchButton
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSearchActive {
                searchBar
            }
        }
        .navigationTitle("Listening history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $sort) {
                        ForEach(ListeningHistorySort.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.liquidGlassCompact)
                .accessibilityLabel("Filter")
            }
        }
        .themeBackground()
        .onChange(of: isSearchActive) { _, active in
            if active {
                playbackService.pushSearchUISession()
            } else {
                playbackService.popSearchUISession()
            }
        }
        .onDisappear {
            if isSearchActive {
                isSearchActive = false
                playbackService.popSearchUISession()
            }
        }
        .onAppear { reloadEntries() }
        .onReceive(NotificationCenter.default.publisher(for: .listeningHistoryDidChange)) { _ in
            reloadEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { _ in
            reloadEntries()
        }
        .sheet(item: $playSession) { session in
            EpisodePlayerSheet(
                episode: session.episode,
                fallbackPodcast: session.podcast,
                onOpenPodcast: { podcastOpenedFromPlayer = $0 }
            )
                .environment(themeManager)
                .environment(playbackService)
                .presentationDragIndicator(.visible)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        }
        .sheet(item: $podcastOpenedFromPlayer) { podcast in
            PodcastDetailView(podcast: podcast)
                .environment(themeManager)
                .environment(playbackService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .bottomSheetPullToDismiss()
                .sheetPullToDismissScrollBottomInset(playbackService: playbackService)
        }
    }

    // MARK: - Resolved Items

    private struct ResolvedItem: Identifiable {
        let id: String
        let episode: Episode
        let podcast: Podcast
    }

    private var resolvedItems: [ResolvedItem] {
        filteredAndSorted.compactMap { entry in
            guard let base = entry.makeBaseEpisode(),
                  let podcast = entry.preferredPodcastForPlayback() else { return nil }
            let merged = EpisodePlaybackStore.merge(base)
            return ResolvedItem(id: merged.id, episode: merged, podcast: podcast)
        }
    }

    private var filteredAndSorted: [ListeningHistoryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [ListeningHistoryEntry]
        if q.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter {
                $0.episodeTitle.localizedCaseInsensitiveContains(q)
                    || $0.podcastTitle.localizedCaseInsensitiveContains(q)
            }
        }
        return sort.apply(filtered)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.currentTheme.accentColor)
            Text("No history yet")
                .font(DesignSystem.Typography.headlineSmall())
                .foregroundStyle(DesignSystem.Colors.headlineColor)
            Text("Episodes you start or finish appear here and sync with iCloud.")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search

    private var searchButton: some View {
        Button {
            withAnimation(DesignSystem.Animation.standard) {
                isSearchActive = true
            }
            Task { @MainActor in
                await Task.yield()
                isSearchFieldFocused = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .buttonStyle(FrostedIconButtonStyle(foreground: DesignSystem.Colors.textPrimary))
        .padding(.trailing, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.bottom, DesignSystem.Spacing.sm)
        .transition(.scale.combined(with: .opacity))
    }

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                TextField("Search episodes or shows", text: $searchText)
                    .font(DesignSystem.Typography.bodyMedium())
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

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
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
            }

            Button {
                withAnimation(DesignSystem.Animation.standard) {
                    searchText = ""
                    isSearchActive = false
                    isSearchFieldFocused = false
                }
            } label: {
                Image(systemName: DesignSystem.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: searchControlHeight, height: searchControlHeight)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Search")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func reloadEntries() {
        entries = ListeningHistoryStore.loadEntriesForDisplay()
    }

    private func openPlay(_ item: ResolvedItem) {
        playSession = ListeningHistoryPlaySession(
            id: item.episode.id,
            episode: item.episode,
            podcast: item.podcast
        )
    }
}

// MARK: - Play session (sheet item)

private struct ListeningHistoryPlaySession: Identifiable {
    let id: String
    let episode: Episode
    let podcast: Podcast?
}

// MARK: - Sort

private enum ListeningHistorySort: String, CaseIterable {
    case recent
    case show
    case progress

    var title: String {
        switch self {
        case .recent: return "Date listened"
        case .show: return "Podcast"
        case .progress: return "Progress"
        }
    }

    func apply(_ items: [ListeningHistoryEntry]) -> [ListeningHistoryEntry] {
        switch self {
        case .recent:
            return items.sorted { $0.lastListenedAt > $1.lastListenedAt }
        case .show:
            return items.sorted {
                let t = $0.podcastTitle.localizedCaseInsensitiveCompare($1.podcastTitle)
                if t != .orderedSame { return t == .orderedAscending }
                return $0.episodeTitle.localizedCaseInsensitiveCompare($1.episodeTitle) == .orderedAscending
            }
        case .progress:
            return items.sorted { lhs, rhs in
                progressRank(lhs) > progressRank(rhs)
            }
        }
    }

    private func progressRank(_ entry: ListeningHistoryEntry) -> Double {
        guard let base = entry.makeBaseEpisode() else { return 0 }
        let m = EpisodePlaybackStore.merge(base)
        let d = m.duration
        if d > 0 {
            if m.isEffectivelyFinished { return 2 + m.playbackPosition / d }
            return m.playbackPosition / d
        }
        return m.isEffectivelyFinished ? 2 : (m.playbackPosition > 0 ? 1 : 0)
    }
}
