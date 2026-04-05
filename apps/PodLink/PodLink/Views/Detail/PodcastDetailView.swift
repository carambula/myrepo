import SwiftUI

// MARK: - Bottom Detection Preference Key

struct BottomDetectionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PodcastDetailView: View {
    let podcast: Podcast
    var initialDeepLinkEpisode: PodLinkEpisodeHint? = nil
    var onHandledInitialDeepLinkEpisode: (() -> Void)? = nil

    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager

    @State private var selectedEpisode: Episode?
    @State private var episodeForTranscript: Episode?
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var isFollowed: Bool = false
    @State private var showDescription = false
    @State private var hasAttemptedInitialDeepLinkResolve = false

    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFieldFocused: Bool
    private let searchControlHeight: CGFloat = 56
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isNearBottom = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    GeometryReader { geometry in
                        showArtHero(width: geometry.size.width)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .top) {
                        Color.clear
                            .frame(height: 0)
                            .scrollOffset($scrollOffset)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(podcast.title)
                            .font(DesignSystem.Typography.displayLarge())
                            .foregroundColor(DesignSystem.Colors.headlineColor)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(podcast.author)
                            .font(DesignSystem.Typography.titleMedium())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                    if !podcast.description.isEmpty {
                        Button {
                            withAnimation { showDescription.toggle() }
                        } label: {
                            Text(podcast.description.strippingHTML)
                                .font(DesignSystem.Typography.bodyMedium())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(showDescription ? nil : 3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    }

                    actionBar

                    catalogContinuationSection

                    episodeList
                }
                .font(DesignSystem.Typography.bodyMedium())
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear.preference(
                            key: BottomDetectionPreferenceKey.self,
                            value: scrollGeometry.frame(in: .named("scroll")).maxY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(BottomDetectionPreferenceKey.self) { maxY in
                detectBottomProximity(maxY: maxY)
            }

            ZStack(alignment: .bottomTrailing) {
                if !isSearchActive {
                    episodeSearchButton
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            
            ZStack(alignment: .bottomLeading) {
                ScrollDismissButton(
                    scrollOffset: scrollOffset,
                    isNearBottom: isNearBottom
                )
                .padding(.leading, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .safeAreaInset(edge: .bottom) {
            if isSearchActive {
                episodeSearchBar
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
        .sheet(item: $selectedEpisode) { episode in
            EpisodePlayerSheet(episode: episode)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $episodeForTranscript) { episode in
            EpisodeDetailView(episode: episode, podcast: podcast)
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .presentationDragIndicator(.visible)
        }
        .task {
            await loadEpisodes()
            isFollowed = Podcast.loadFollowedPodcasts().contains { $0.id == podcast.id }
            resolveInitialDeepLinkEpisodeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { note in
            if let changedID = note.object as? String {
                refreshMergedEpisode(id: changedID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodeDownloadStateDidChange)) { note in
            if let changedID = note.object as? String {
                refreshMergedEpisode(id: changedID)
            }
        }
    }

    // MARK: - Hero

    private func showArtHero(width: CGFloat) -> some View {
        AsyncCachedImage(url: podcast.artworkURL600 ?? podcast.artworkURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: width, height: width)
        .clipped()
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        let activeAccent = themeManager.currentTheme.accentColor
        return HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                isFollowed.toggle()
                toggleFollow()
            } label: {
                Image(systemName: isFollowed ? "minus.circle" : "plus.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isFollowed ? activeAccent : DesignSystem.Colors.textPrimary)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.liquidGlassCompact)
            .accessibilityLabel(isFollowed ? "Remove podcast from library" : "Add podcast to library")

            Button {
                // Share podcast
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.liquidGlassCompact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Resume / Up next (back catalog)

    /// Shown when the listener’s last episode for this show sits deeper than the first 10 rows (newest-first feeds).
    private struct CatalogContinuation {
        let title: String
        let episode: Episode
    }

    private func podcast(_ a: Podcast, matches b: Podcast) -> Bool {
        a.id == b.id || a.feedURL == b.feedURL
    }

    private var catalogContinuation: CatalogContinuation? {
        guard !isLoading, episodes.count > 10 else { return nil }

        let refEpisodeID: String?
        if let cur = playbackService.state.currentEpisode,
           let pod = playbackService.state.currentPodcast,
           podcast(pod, matches: podcast) {
            refEpisodeID = cur.id
        } else {
            refEpisodeID = EpisodePlaybackStore.lastPlayedEpisodeID(forPodcastID: podcast.feedURL.absoluteString)
        }

        guard let refEpisodeID else { return nil }
        guard let idx = episodes.firstIndex(where: { $0.id == refEpisodeID }) else { return nil }
        guard idx >= 10 else { return nil }

        let ref = EpisodePlaybackStore.merge(episodes[idx])

        if !ref.isEffectivelyFinished {
            return CatalogContinuation(title: "Resume", episode: ref)
        }
        guard idx > 0 else { return nil }
        let next = EpisodePlaybackStore.merge(episodes[idx - 1])
        return CatalogContinuation(title: "Up next", episode: next)
    }

    @ViewBuilder
    private var catalogContinuationSection: some View {
        if let item = catalogContinuation {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(item.title)
                    .font(DesignSystem.Typography.headlineMedium())
                    .foregroundColor(DesignSystem.Colors.headlineColor)

                EpisodeRowView(
                    episode: item.episode,
                    podcast: podcast,
                    onTap: { selectedEpisode = item.episode },
                    onShowDetails: { episodeForTranscript = item.episode },
                    showsDownloadAffordance: false
                )

                Divider()
                    .padding(.leading, 76)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        }
    }

    // MARK: - Episode List

    private var filteredEpisodes: [Episode] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return episodes }
        return episodes.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.description.localizedCaseInsensitiveContains(q)
        }
    }

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Episodes")
                .font(DesignSystem.Typography.headlineMedium())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xxl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEpisodes) { episode in
                        EpisodeRowView(
                            episode: episode,
                            podcast: podcast,
                            onTap: {
                                selectedEpisode = episode
                            },
                            onShowDetails: {
                                episodeForTranscript = episode
                            },
                            showsDownloadAffordance: false
                        )

                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
    }

    // MARK: - Episode Search

    private var episodeSearchButton: some View {
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
        .padding(.trailing, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.sm)
        .transition(.scale.combined(with: .opacity))
    }

    private var episodeSearchBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                TextField("Search episodes", text: $searchText)
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

    // MARK: - Data

    private func loadEpisodes() async {
        isLoading = true
        do {
            let fetched = try await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL)
            episodes = fetched.map { EpisodePlaybackStore.merge($0) }
        } catch {
            episodes = []
        }
        isLoading = false
    }

    private func resolveInitialDeepLinkEpisodeIfNeeded() {
        guard !hasAttemptedInitialDeepLinkResolve else { return }
        hasAttemptedInitialDeepLinkResolve = true
        defer { onHandledInitialDeepLinkEpisode?() }

        guard let hint = initialDeepLinkEpisode else { return }

        if let url = hint.episodeURL,
           let matched = episodes.first(where: { episodeMatchesDeepLinkURL($0, targetURL: url) }) {
            selectedEpisode = matched
            return
        }

        if let title = hint.episodeTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !title.isEmpty,
           let matched = episodes.first(where: {
               $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == title
                   || $0.title.lowercased().contains(title)
           }) {
            selectedEpisode = matched
        }
    }

    private func episodeMatchesDeepLinkURL(_ episode: Episode, targetURL: URL) -> Bool {
        let lhs = normalizedEpisodeIdentityURL(episode.audioURL)
        let rhs = normalizedEpisodeIdentityURL(targetURL)
        if lhs == rhs { return true }
        if let video = episode.videoURL {
            return normalizedEpisodeIdentityURL(video) == rhs
        }
        return false
    }

    private func normalizedEpisodeIdentityURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let normalized = components?.url?.absoluteString ?? url.absoluteString
        return normalized
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func refreshMergedEpisodes() {
        episodes = episodes.map { EpisodePlaybackStore.merge($0) }
    }

    private func refreshMergedEpisode(id: String) {
        guard let idx = episodes.firstIndex(where: { $0.id == id }) else { return }
        episodes[idx] = EpisodePlaybackStore.merge(episodes[idx])
    }

    private func toggleFollow() {
        var podcasts = Podcast.loadFollowedPodcasts()
        if isFollowed {
            var updated = podcast
            updated.isFollowed = true
            if !podcasts.contains(where: { $0.id == podcast.id }) {
                podcasts.append(updated)
            }
        } else {
            podcasts.removeAll { $0.id == podcast.id }
        }
        Podcast.saveFollowedPodcasts(podcasts)
    }
    
    // MARK: - Bottom Detection
    
    private func detectBottomProximity(maxY: CGFloat) {
        // Consider "near bottom" if within 50px of the bottom of the visible area
        let threshold: CGFloat = 50
        isNearBottom = maxY < threshold
    }
}
