//
//  MovieDetailView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI
import SwiftData
import UIKit


private struct CreditTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Movie Detail View

struct MovieDetailView: View {
    let movie: Movie
    var presentationSource: MovieDetailTransitionSource = .unknown
    var onCreditPersonTapped: ((String) -> Void)? = nil
    var onYearTapped: ((Int) -> Void)? = nil
    var onGenreTapped: ((String) -> Void)? = nil
    var onRatingTapped: ((String) -> Void)? = nil
    var onPhysicalMediaTapped: ((String) -> Void)? = nil
    @StateObject private var localDB = LocalDatabaseManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @AppStorage(StreamingPreferences.storageKey) private var preferredServicesData: Data = Data()
    @AppStorage(PodcastAppPreferences.storageKey) private var preferredPodcastAppName: String = PodcastApp.applePodcasts.rawValue
    @AppStorage("movieDetailLayoutStyle") private var layoutStyleRaw: String = MovieDetailLayoutStyle.posterFocus.rawValue
    @AppStorage(MovieDetailLayoutParameters.storageKey) private var layoutParametersData: Data = MovieDetailLayoutParameters().encode()
    @State private var isLoadingDetails = false
    @State private var showRewatchablesEditor = false
    @State private var showPhysicalPurchaseSheet = false
    @State private var hasTriggeredCatalogRefresh = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    // Local state for immediate visual feedback - initialized from movie
    @State private var localIsRewatched: Bool
    @State private var localIsListened: Bool
    @State private var localIsSaved: Bool
    @State private var buttonScale: [String: CGFloat] = [:]
    @State private var legacySourcesSnapshot: [LegacySourceSnapshot] = []
    @State private var sourceContentSnapshot: [SourceContentSnapshot] = []
    @State private var podcastFeedURLSnapshot: [String: String] = [:]
    @State private var hasLoadedSourceSnapshots = false
    
    // Get current movie state from database
    private var currentMovie: Movie? {
        localDB.movies.first { $0.id == movie.id }
    }
    
    private var layoutStyle: MovieDetailLayoutStyle {
        MovieDetailLayoutStyle(rawValue: layoutStyleRaw) ?? .classic
    }
    
    private var layoutParameters: MovieDetailLayoutParameters {
        MovieDetailLayoutParameters.decode(from: layoutParametersData)
    }

    private var isPosterFocusFullBleedMode: Bool {
        layoutStyle == .posterFocus && layoutParameters.posterFocusFullBleed
    }

    private var shouldShowTitleHeader: Bool {
        !isPosterFocusFullBleedMode
    }

    private var actionBarTopPadding: CGFloat {
        guard isPosterFocusFullBleedMode else { return 0 }
        switch layoutParameters.posterFocusActionBarPosition {
        case .below:
            return DesignSystem.Spacing.md
        case .overlapping:
            return -40
        }
    }

    private var posterFocusMetadataTopAdjustment: CGFloat {
        guard isPosterFocusFullBleedMode else { return 0 }
        return 0
    }

    private var actionBarFrameAlignment: Alignment {
        switch layoutParameters.actionBarLayout {
        case .centered:
            return .center
        case .leftAligned:
            return .leading
        }
    }
    
    private var displayMovie: Movie {
        guard let current = currentMovie else {
            return movie
        }
        
        return Movie(
            id: current.id,
            title: current.title.isEmpty ? movie.title : current.title,
            year: current.year ?? movie.year,
            tmdbId: current.tmdbId ?? movie.tmdbId,
            posterPath: current.posterPath ?? movie.posterPath,
            backdropPath: current.backdropPath ?? movie.backdropPath,
            overview: {
                if let currentOverview = current.overview, !currentOverview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return currentOverview
                }
                return movie.overview
            }(),
            mpaaRating: current.mpaaRating ?? movie.mpaaRating,
            genres: current.genres.isEmpty ? movie.genres : current.genres,
            streamingServices: current.streamingServices.isEmpty ? movie.streamingServices : current.streamingServices,
            podcastEpisode: current.podcastEpisode ?? movie.podcastEpisode,
            credits: current.credits ?? movie.credits,
            rewatchablesDiscussion: current.rewatchablesDiscussion ?? movie.rewatchablesDiscussion,
            trailer: current.trailer ?? movie.trailer,
            oscarAwards: current.oscarAwards ?? movie.oscarAwards,
            physicalMedia: current.physicalMedia ?? movie.physicalMedia,
            // Use local state so status toggles feel instant and glass transitions stay smooth
            isRewatched: localIsRewatched,
            isListened: localIsListened,
            isSaved: localIsSaved,
            lastUpdated: max(current.lastUpdated, movie.lastUpdated)
        )
    }

    private var uniqueStreamingServices: [StreamingService] {
        var bestByKey: [String: StreamingService] = [:]
        var bestScoreByKey: [String: Int] = [:]
        
        for service in displayMovie.streamingServices {
            guard StreamingServiceAssets.shouldShowService(service.name) else { continue }
            let normalizedName = StreamingServiceAssets.normalizedName(service.name)
            let key = normalizedName.lowercased()
            let score = StreamingServiceAssets.variantScore(service.name)
            
            if let existingScore = bestScoreByKey[key], existingScore >= score {
                continue
            }
            
            bestScoreByKey[key] = score
            if normalizedName != service.name {
                bestByKey[key] = StreamingService(
                    id: service.id,
                    name: normalizedName,
                    logoPath: service.logoPath,
                    url: service.url
                )
            } else {
                bestByKey[key] = service
            }
        }
        
        let preferredIndex = preferredServiceIndex
        return Array(bestByKey.values).sorted { lhs, rhs in
            let lhsKey = StreamingServiceAssets.normalizedName(lhs.name).lowercased()
            let rhsKey = StreamingServiceAssets.normalizedName(rhs.name).lowercased()
            let lhsIndex = preferredIndex[lhsKey]
            let rhsIndex = preferredIndex[rhsKey]
            
            switch (lhsIndex, rhsIndex) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var preferredServiceIndex: [String: Int] {
        var order: [String] = []
        var seen = Set<String>()
        for service in preferredServiceNames {
            let normalized = StreamingServiceAssets.normalizedName(service).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            order.append(normalized)
        }
        return Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
    }

    private var preferredServiceNames: [String] {
        StreamingPreferences.decode(from: preferredServicesData)
    }

    private var preferredPodcastApp: PodcastApp {
        PodcastAppPreferences.preferredApp(from: preferredPodcastAppName)
    }

    private var hasPhysicalPurchaseOptions: Bool {
        PhysicalPurchaseLinkBuilder.hasOptions(for: displayMovie.physicalMedia)
    }

    private var showsPlayMenu: Bool {
        !preferredServiceIndex.isEmpty || hasPhysicalPurchaseOptions
    }

    private var preferredStreamingServices: [StreamingService] {
        let preferredIndex = preferredServiceIndex
        guard !preferredIndex.isEmpty else { return [] }
        return uniqueStreamingServices
            .filter { service in
                let key = StreamingServiceAssets.normalizedName(service.name).lowercased()
                return preferredIndex[key] != nil
            }
            .sorted { lhs, rhs in
                let lhsKey = StreamingServiceAssets.normalizedName(lhs.name).lowercased()
                let rhsKey = StreamingServiceAssets.normalizedName(rhs.name).lowercased()
                return (preferredIndex[lhsKey] ?? Int.max) < (preferredIndex[rhsKey] ?? Int.max)
            }
    }

    private struct PodcastMenuItem: Identifiable {
        let id: String
        let podcastName: String
        let dataSourceIdentifier: String?
        let episode: PodcastEpisode
    }

    private var podcastMenuItems: [PodcastMenuItem] {
        var items: [PodcastMenuItem] = []
        for content in uniqueMovieSourceContentSnapshots {
            guard content.sourceType.lowercased() == "podcast",
                  let episode = content.podcastEpisode else { continue }
            let name = content.sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            items.append(PodcastMenuItem(
                id: "\(content.sourceIdentifier)-\(episode.episodeId)",
                podcastName: name,
                dataSourceIdentifier: content.sourceIdentifier,
                episode: episode
            ))
        }

        for legacySource in legacySources {
            guard let episode = legacySource.podcastEpisode else { continue }
            let name = legacySource.sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            items.append(PodcastMenuItem(
                id: "\(legacySource.sourceIdentifier)-\(episode.episodeId)",
                podcastName: name,
                dataSourceIdentifier: legacySource.sourceIdentifier,
                episode: episode
            ))
        }

        var bestByKey: [String: PodcastMenuItem] = [:]
        var bestScoreByKey: [String: Int] = [:]
        for item in items {
            let key = normalizedPodcastKey(item.podcastName)
            let score = podcastMenuScore(item)
            if let existing = bestScoreByKey[key], existing >= score { continue }
            bestScoreByKey[key] = score
            bestByKey[key] = item
        }

        return bestByKey.values.sorted {
            $0.podcastName.localizedCaseInsensitiveCompare($1.podcastName) == .orderedAscending
        }
    }
    
    struct SourceContentSnapshot: Identifiable {
        let id: String
        let sourceIdentifier: String
        let sourceName: String
        let sourceType: String
        let isRankedList: Bool
        let rank: Int?
        let sourceTitle: String?
        let sourceUrl: String?
        let podcastEpisode: PodcastEpisode?
    }

    struct LegacySourceSnapshot: Identifiable {
        let id = UUID()
        let sourceName: String
        let sourceIdentifier: String
        let rank: Int?
        let sourceTitle: String?
        let sourceUrl: String?
        let podcastEpisode: PodcastEpisode?
    }

    private var legacySources: [LegacySourceSnapshot] {
        legacySourcesSnapshot
    }
    
    private var movieSourceContentSnapshots: [SourceContentSnapshot] {
        sourceContentSnapshot
    }

    // Remove duplicate source contents by identifier (e.g. IMDb Auteurs)
    private var uniqueMovieSourceContentSnapshots: [SourceContentSnapshot] {
        var bestByIdentifier: [String: SourceContentSnapshot] = [:]

        for content in movieSourceContentSnapshots {
            let identifier = content.sourceIdentifier.lowercased()
            guard !identifier.isEmpty else { continue }
            if let existing = bestByIdentifier[identifier] {
                if sourceContentScore(content) > sourceContentScore(existing) {
                    bestByIdentifier[identifier] = content
                }
            } else {
                bestByIdentifier[identifier] = content
            }
        }

        return bestByIdentifier.values.sorted {
            $0.sourceName.localizedCaseInsensitiveCompare($1.sourceName) == .orderedAscending
        }
    }
    
    // Helper to get SourceContent for a specific source identifier
    private func sourceContent(for sourceIdentifier: String) -> SourceContentSnapshot? {
        uniqueMovieSourceContentSnapshots.first { $0.sourceIdentifier == sourceIdentifier }
    }

    private var podcastFeedURLByIdentifier: [String: String] {
        podcastFeedURLSnapshot
    }

    @MainActor
    private func loadSourceSnapshotsIfNeeded(force: Bool = false) {
        guard force || !hasLoadedSourceSnapshots else { return }
        let movieId = movie.id

        var legacy: [LegacySourceSnapshot] = []
        var sourceContents: [SourceContentSnapshot] = []
        var podcastFeeds: [String: String] = [:]

        var legacyDescriptor = FetchDescriptor<MovieDataSource>(
            predicate: #Predicate<MovieDataSource> { dataSource in
                dataSource.movie?.id == movieId
            }
        )
        legacyDescriptor.fetchLimit = 120
        let legacyRows = (try? modelContext.fetch(legacyDescriptor)) ?? []
        legacy = legacyRows.compactMap { dataSource in
            guard let source = dataSource.dataSource else { return nil }
            return LegacySourceSnapshot(
                sourceName: source.name,
                sourceIdentifier: source.identifier,
                rank: dataSource.rank,
                sourceTitle: dataSource.sourceTitle,
                sourceUrl: dataSource.sourceUrl,
                podcastEpisode: dataSource.podcastEpisode
            )
        }

        var sourceContentDescriptor = FetchDescriptor<SourceContent>(
            predicate: #Predicate<SourceContent> { content in
                content.movie?.id == movieId
            }
        )
        sourceContentDescriptor.fetchLimit = 120
        let contentRows = (try? modelContext.fetch(sourceContentDescriptor)) ?? []
        sourceContents = contentRows.compactMap { content in
            guard let source = content.source else { return nil }
            let identifier = source.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !identifier.isEmpty else { return nil }
            let sourceName = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return SourceContentSnapshot(
                id: "\(movieId)|\(identifier)",
                sourceIdentifier: identifier,
                sourceName: sourceName.isEmpty ? identifier : sourceName,
                sourceType: source.type,
                isRankedList: source.isRankedList,
                rank: content.rank,
                sourceTitle: content.sourceTitle,
                sourceUrl: content.sourceUrl,
                podcastEpisode: content.podcastEpisode
            )
        }

        let dataSources = (try? modelContext.fetch(FetchDescriptor<DataSource>())) ?? []
        for source in dataSources where source.type.lowercased() == "podcast" {
            let identifier = source.identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let feedURL = source.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !identifier.isEmpty, !feedURL.isEmpty else { continue }
            podcastFeeds[identifier] = feedURL
        }

        legacySourcesSnapshot = legacy
        sourceContentSnapshot = sourceContents
        podcastFeedURLSnapshot = podcastFeeds
        hasLoadedSourceSnapshots = true
    }

    private func sourceContentScore(_ content: SourceContentSnapshot) -> Int {
        var score = 0
        if content.rank != nil { score += 2 }
        if let sourceTitle = content.sourceTitle, !sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 1
        }
        if let sourceUrl = content.sourceUrl, !sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 1
        }
        if content.podcastEpisode != nil { score += 1 }
        return score
    }
    
    // Initialize state from movie
    init(
        movie: Movie,
        presentationSource: MovieDetailTransitionSource = .unknown,
        onCreditPersonTapped: ((String) -> Void)? = nil,
        onYearTapped: ((Int) -> Void)? = nil,
        onGenreTapped: ((String) -> Void)? = nil,
        onRatingTapped: ((String) -> Void)? = nil,
        onPhysicalMediaTapped: ((String) -> Void)? = nil
    ) {
        self.movie = movie
        self.presentationSource = presentationSource
        self.onCreditPersonTapped = onCreditPersonTapped
        self.onYearTapped = onYearTapped
        self.onGenreTapped = onGenreTapped
        self.onRatingTapped = onRatingTapped
        self.onPhysicalMediaTapped = onPhysicalMediaTapped
        _localIsRewatched = State(initialValue: movie.isRewatched)
        _localIsListened = State(initialValue: movie.isListened)
        _localIsSaved = State(initialValue: movie.isSaved)
    }
    
    // Sync local state with database when it updates
    private func syncLocalState() {
        if let updated = localDB.movies.first(where: { $0.id == movie.id }) {
            localIsRewatched = updated.isRewatched
            localIsListened = updated.isListened
            localIsSaved = updated.isSaved
        }
    }

    private func toggleListenedStatus() {
        // Immediate visual feedback - update state first
        localIsListened.toggle()

        // Animate button bounce immediately
        withAnimation(DesignSystem.Animation.springQuick) {
            buttonScale["listened"] = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(DesignSystem.Animation.springStandard) {
                buttonScale["listened"] = 1.0
            }
        }

        // Immediate haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif

        // Update in background - fire and forget
        // Don't sync back - local state is source of truth
        localDB.queueListenedStatusUpdate(displayMovie, isListened: localIsListened)
    }

    private func normalizedPodcastKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func podcastMenuScore(_ item: PodcastMenuItem) -> Int {
        var score = 0
        if item.episode.applePodcastsUrl != nil { score += 2 }
        if item.episode.spotifyUrl != nil { score += 2 }
        if item.episode.overcastUrl != nil { score += 1 }
        if item.episode.pocketCastsUrl != nil { score += 1 }
        return score
    }

    private func openPodcastMenuItem(_ item: PodcastMenuItem) {
        guard let url = preferredPodcastLink(for: item) else { return }
        #if os(tvOS)
        openURL(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func preferredPodcastLink(
        podcastName: String,
        dataSourceIdentifier: String?,
        episode: PodcastEpisode,
        movieTitle: String?
    ) -> URL? {
        switch preferredPodcastApp {
        case .applePodcasts:
            if let urlString = episode.applePodcastsUrl, let url = URL(string: urlString) {
                return url
            }
            return createApplePodcastsSearchURL(podcastName: podcastName, episodeTitle: episode.title)
        case .spotify:
            if let urlString = episode.spotifyUrl, let url = URL(string: urlString) {
                return url
            }
            return createSpotifySearchURL(
                podcastName: podcastName,
                episodeTitle: episode.title,
                movieTitle: movieTitle,
                dataSourceIdentifier: dataSourceIdentifier
            )
        case .overcast:
            if let urlString = episode.overcastUrl, let url = URL(string: urlString) {
                return url
            }
            return createOvercastSearchURL(podcastName: podcastName, episodeTitle: episode.title)
        case .pocketCasts:
            if let urlString = episode.pocketCastsUrl, let url = URL(string: urlString) {
                return url
            }
            return createPocketCastsSearchURL(podcastName: podcastName, episodeTitle: episode.title)
        case .podMin:
            if let deepLink = createPodMinDeepLinkURL(
                dataSourceIdentifier: dataSourceIdentifier,
                episode: episode
            ) {
                return deepLink
            }
            return createApplePodcastsSearchURL(podcastName: podcastName, episodeTitle: episode.title)
        }
    }

    private func preferredPodcastLink(for item: PodcastMenuItem) -> URL? {
        preferredPodcastLink(
            podcastName: item.podcastName,
            dataSourceIdentifier: item.dataSourceIdentifier,
            episode: item.episode,
            movieTitle: displayMovie.title
        )
    }

    private func createApplePodcastsSearchURL(podcastName: String, episodeTitle: String) -> URL? {
        let searchQuery = "\(podcastName) \(episodeTitle)"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        return URL(string: "https://podcasts.apple.com/search?term=\(encodedQuery)")
    }

    private func createOvercastSearchURL(podcastName: String, episodeTitle: String) -> URL? {
        let searchQuery = "\(podcastName) \(episodeTitle)"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        return URL(string: "https://overcast.fm/search?query=\(encodedQuery)")
    }

    private func createPocketCastsSearchURL(podcastName: String, episodeTitle: String) -> URL? {
        let searchQuery = "\(podcastName) \(episodeTitle)"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        return URL(string: "https://pocketcasts.com/search?q=\(encodedQuery)")
    }

    private func createPodMinDeepLinkURL(
        dataSourceIdentifier: String?,
        episode: PodcastEpisode
    ) -> URL? {
        guard let identifier = dataSourceIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !identifier.isEmpty,
              let feedURL = podcastFeedURL(for: identifier) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "podmin"
        var items = [URLQueryItem(name: "feed", value: feedURL)]

        // Our dataset has no per-episode audio URL, so deep link by episode title.
        // pod min matches the title within the feed and opens that episode directly,
        // falling back to the show screen if it can't find a match.
        let episodeTitle = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if episodeTitle.isEmpty {
            components.host = "show"
        } else {
            components.host = "episode"
            items.append(URLQueryItem(name: "title", value: episodeTitle))
        }

        components.queryItems = items
        return components.url
    }

    private func openTrailerOrYouTubeSearch() {
        #if os(tvOS)
        if let trailer = displayMovie.trailer, let youtubeURL = trailer.youtubeURL, UIApplication.shared.canOpenURL(youtubeURL) {
            openURL(youtubeURL)
        }
        return
        #else
        if let trailer = displayMovie.trailer, let youtubeURL = trailer.youtubeURL {
            UIApplication.shared.open(youtubeURL)
            return
        }
        
        var queryParts = [displayMovie.title]
        if let year = displayMovie.year {
            queryParts.append(String(year))
        }
        queryParts.append("trailer")
        
        let query = queryParts.joined(separator: " ")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let appURL = URL(string: "youtube://results?search_query=\(encodedQuery)")
        let webURL = URL(string: "https://www.youtube.com/results?search_query=\(encodedQuery)")
        
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL {
            UIApplication.shared.open(webURL)
        }
        #endif
    }

    private func handleCreditPersonTap(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        onCreditPersonTapped?(trimmedName)
    }

    private func handleYearTap(_ year: Int) {
        onYearTapped?(year)
    }

    private func handleGenreTap(_ genre: String) {
        let trimmedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGenre.isEmpty else { return }
        onGenreTapped?(trimmedGenre)
    }

    private func handlePhysicalMediaTap(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onPhysicalMediaTapped?(trimmed)
    }

    private func handleRatingTap(_ rating: String) {
        let trimmedRating = rating.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRating.isEmpty else { return }
        onRatingTapped?(trimmedRating)
    }

    private var ratingBadgeHeight: CGFloat {
        24
    }

    private var podcastItemsForRatingRow: [PodcastMenuItem] {
        var seenFeedURLs: Set<String> = []
        var items: [PodcastMenuItem] = []

        for item in podcastMenuItems {
            guard let feedURL = podcastFeedURL(for: item),
                  seenFeedURLs.insert(feedURL).inserted else {
                continue
            }
            items.append(item)
        }

        return Array(items.prefix(3))
    }

    private func podcastFeedURL(for item: PodcastMenuItem) -> String? {
        let identifier = item.dataSourceIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !identifier.isEmpty else { return nil }
        return podcastFeedURL(for: identifier)
    }

    private func podcastFeedURL(for identifier: String) -> String? {
        guard let feedURL = podcastFeedURLByIdentifier[identifier]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !feedURL.isEmpty else {
            return nil
        }
        return feedURL
    }

    @ViewBuilder
    private var ratingAndYearRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if let mpaaRating = displayMovie.mpaaRating {
                let podcastItems = podcastItemsForRatingRow
                HStack(spacing: DesignSystem.Spacing.md) {
                    if !podcastItems.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(podcastItems) { item in
                                if let feedURL = podcastFeedURL(for: item) {
                                    Button(action: { openPodcastMenuItem(item) }) {
                                        PodcastSourceArtworkView(feedURLString: feedURL)
                                            .frame(width: ratingBadgeHeight, height: ratingBadgeHeight)
                                    }
                                    .buttonStyle(CreditTapButtonStyle())
                                    .accessibilityLabel("Open \(item.podcastName)")
                                }
                            }
                        }
                    }

                    Button(action: { handleRatingTap(mpaaRating) }) {
                        Text(mpaaRating)
                            .labelMedium()
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Color.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .frame(minHeight: ratingBadgeHeight)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(DesignSystem.Color.accent.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Color.accent.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(CreditTapButtonStyle())
                }
            }

            if let year = displayMovie.year {
                Button(action: { handleYearTap(year) }) {
                    Text(String(year))
                        .titleMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .buttonStyle(CreditTapButtonStyle())
            }

            if let media = displayMovie.physicalMedia, media.hasDisplayableAvailability {
                if media.hasCriterion {
                    Button(action: { handlePhysicalMediaTap("criterion") }) {
                        Text("Criterion")
                            .labelMedium()
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Color.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .frame(minHeight: ratingBadgeHeight)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(DesignSystem.Color.accent.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Color.accent.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(CreditTapButtonStyle())
                    .accessibilityLabel("Criterion Collection")
                }
                if media.has4K {
                    Button(action: { handlePhysicalMediaTap("4k") }) {
                        Text("4K")
                            .labelMedium()
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Color.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .frame(minHeight: ratingBadgeHeight)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(DesignSystem.Color.accent.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Color.accent.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(CreditTapButtonStyle())
                    .accessibilityLabel("4K UHD")
                }
            }
        }
    }

    private func presentPhysicalPurchaseSheet() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            showPhysicalPurchaseSheet = true
        }
    }

    private func openStreamingService(_ service: StreamingService) {
        let link = StreamingServiceLinkBuilder.link(
            for: service,
            movieTitle: displayMovie.title,
            tmdbId: displayMovie.tmdbId
        )

        #if os(tvOS)
        if let appURL = link.appURL, UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if let fallbackAppURL = link.fallbackAppURL, UIApplication.shared.canOpenURL(fallbackAppURL) {
            openURL(fallbackAppURL)
        } else {
            print("⚠️ Streaming app not available for \(service.name)")
        }
        #else
        if let appURL = link.appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let fallbackAppURL = link.fallbackAppURL, UIApplication.shared.canOpenURL(fallbackAppURL) {
            UIApplication.shared.open(fallbackAppURL)
        } else if let webURL = link.webURL {
            UIApplication.shared.open(webURL)
        }
        #endif
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with poster/backdrop using selected layout style
                    MovieDetailHeaderLayout(
                        movie: displayMovie,
                        style: layoutStyle,
                        parameters: layoutParameters,
                        transitionSource: presentationSource
                    )
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Title Section
                    if shouldShowTitleHeader {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(displayMovie.title)
                                .displayLarge()
                                .foregroundHeadline()
                            ratingAndYearRow
                        }
                        .padding(.top, DesignSystem.Spacing.lg)
                    }
                    
                    // Top button row: play, rewatched, listened, save, menu
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        let hasPodcastEpisode = displayMovie.podcastEpisode != nil
                        let activeActionColor = DesignSystem.Color.secondaryAccent ?? DesignSystem.Color.accent
                        // Play button
                        if showsPlayMenu {
                            Menu {
                                Button(action: openTrailerOrYouTubeSearch) {
                                    Label("Trailer", systemImage: DesignSystem.Icon.play)
                                }

                                if !preferredStreamingServices.isEmpty {
                                    Divider()
                                    ForEach(preferredStreamingServices) { service in
                                        let serviceName = StreamingServiceAssets.normalizedName(service.name)
                                        Button(action: { openStreamingService(service) }) {
                                            Label(serviceName, systemImage: DesignSystem.Icon.streaming)
                                        }
                                    }
                                }

                                if hasPhysicalPurchaseOptions {
                                    Divider()
                                    Button(action: presentPhysicalPurchaseSheet) {
                                        Label("Buy disc…", systemImage: DesignSystem.Icon.disc)
                                    }
                                }
                            } label: {
                                DesignSystemIcon(DesignSystem.Icon.play, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textPrimary)
                                    .frame(width: 60, height: 60)
                            }
                            .buttonStyle(.liquidGlassCompact)
                            .accessibilityLabel("Play")
                        } else {
                            Button(action: openTrailerOrYouTubeSearch) {
                                DesignSystemIcon(DesignSystem.Icon.play, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textPrimary)
                                    .frame(width: 60, height: 60)
                            }
                            .buttonStyle(.liquidGlassCompact)
                            .accessibilityLabel("Play trailer")
                        }
                        
                        // Rewatched button
                        Button(action: {
                            // Immediate visual feedback - update state first
                            localIsRewatched.toggle()
                            
                            // Animate button bounce immediately
                            withAnimation(DesignSystem.Animation.springQuick) {
                                buttonScale["rewatched"] = 1.3
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(DesignSystem.Animation.springStandard) {
                                    buttonScale["rewatched"] = 1.0
                                }
                            }
                            
                            // Immediate haptic feedback
                            #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.prepare()
                            generator.impactOccurred()
                            #endif
                            
                            // Update in background - fire and forget
                            // Don't sync back - local state is source of truth
                            localDB.queueRewatchedStatusUpdate(displayMovie, isRewatched: localIsRewatched)
                        }) {
                            DesignSystemIcon(
                                localIsRewatched ? DesignSystem.Icon.rewatchFill : DesignSystem.Icon.rewatch,
                                size: DesignSystem.IconSize.lg,
                                color: localIsRewatched ? activeActionColor : DesignSystem.Color.textPrimary
                            )
                            .frame(width: 60, height: 60)
                            .scaleEffect(buttonScale["rewatched"] ?? 1.0)
                        }
                        .buttonStyle(.liquidGlassCompact)
                        
                        // Listened button
                        let listenedIcon = DesignSystemIcon(
                            localIsListened ? DesignSystem.Icon.listenFill : DesignSystem.Icon.listen,
                            size: DesignSystem.IconSize.lg,
                            color: hasPodcastEpisode
                                ? (localIsListened ? activeActionColor : DesignSystem.Color.textPrimary)
                                : DesignSystem.Color.textSecondary
                        )
                        if hasPodcastEpisode {
                            Menu {
                                Button(action: toggleListenedStatus) {
                                    Label(localIsListened ? "Mark unlistened" : "Mark listened",
                                          systemImage: localIsListened ? DesignSystem.Icon.listenFill : DesignSystem.Icon.listen)
                                }
                                if !podcastMenuItems.isEmpty {
                                    Divider()
                                    ForEach(podcastMenuItems) { item in
                                        Button(action: { openPodcastMenuItem(item) }) {
                                            Label(item.podcastName, systemImage: DesignSystem.Icon.podcast)
                                        }
                                    }
                                }
                            } label: {
                                listenedIcon
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(buttonScale["listened"] ?? 1.0)
                            }
                            .buttonStyle(.liquidGlassCompact)
                        }
                        
                        // Save button
                        Button(action: {
                            // Immediate visual feedback - update state first
                            localIsSaved.toggle()
                            
                            // Animate button bounce immediately
                            withAnimation(DesignSystem.Animation.springQuick) {
                                buttonScale["saved"] = 1.3
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(DesignSystem.Animation.springStandard) {
                                    buttonScale["saved"] = 1.0
                                }
                            }
                            
                            // Immediate haptic feedback
                            #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.prepare()
                            generator.impactOccurred()
                            #endif
                            
                            // Update in background - fire and forget
                            // Don't sync back - local state is source of truth
                            localDB.queueSavedStatusUpdate(displayMovie, isSaved: localIsSaved)
                        }) {
                            DesignSystemIcon(
                                localIsSaved ? DesignSystem.Icon.bookmarkFill : DesignSystem.Icon.bookmark,
                                size: DesignSystem.IconSize.lg,
                                color: localIsSaved ? activeActionColor : DesignSystem.Color.textPrimary
                            )
                            .frame(width: 60, height: 60)
                            .scaleEffect(buttonScale["saved"] ?? 1.0)
                        }
                        .buttonStyle(.liquidGlassCompact)
                        
                    }
                    .frame(maxWidth: .infinity, alignment: actionBarFrameAlignment)
                    .padding(.top, actionBarTopPadding)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                    if isPosterFocusFullBleedMode {
                        ratingAndYearRow
                            .padding(.top, posterFocusMetadataTopAdjustment)
                    }
                    
//                    Divider()
                    // Genres
                    if !displayMovie.genres.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    ForEach(displayMovie.genres, id: \.self) { genre in
                                        Button(action: { handleGenreTap(genre) }) {
                                            Text(genre)
                                                .bodyMedium()
                                                .fontWeight(.medium)
                                                .padding(.trailing, DesignSystem.Spacing.md)
                                        }
                                        .buttonStyle(CreditTapButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    
                    // Overview
                    if let overview = displayMovie.overview, !overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(overview)
                                .bodyMedium()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                                .lineSpacing(DesignSystem.Spacing.xs)
                        }
                    }
                    
                    // Key Credits
                    if let credits = displayMovie.credits {
                        let hasDirector = credits.director != nil && !credits.director!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let hasCast = !credits.cast.isEmpty
                        
                        if hasDirector || hasCast {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                                if let director = credits.director, !director.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        Text("Director")
                                            .labelMedium()
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignSystem.Color.textSecondary)
                                        Button(action: { handleCreditPersonTap(director) }) {
                                            Text(director)
                                                .bodyMedium()
                                                .foregroundColor(DesignSystem.Color.textPrimary)
                                                .padding(.vertical, DesignSystem.Spacing.xs)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(CreditTapButtonStyle())
                                    }
                                    .padding(.bottom, DesignSystem.Spacing.sm)
                                }
                                
                                if !credits.cast.isEmpty {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                        Text("Cast")
                                            .labelMedium()
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignSystem.Color.textSecondary)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: DesignSystem.Spacing.lg) {
                                                ForEach(credits.cast.prefix(10)) { member in
                                                    Button(action: {
                                                            handleCreditPersonTap(member.name)
                                                        }) {
                                                            CastMemberCard(member: member)
                                                                .contentShape(Rectangle())
                                                        }
                                                        .buttonStyle(CreditTapButtonStyle())
                                                }
                                            }
                                            .padding(.horizontal, DesignSystem.Spacing.xs)
                                        }
                                        .scrollClipDisabled()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Academy Awards
                    if let awards = displayMovie.oscarAwards, awards.hasOscars {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            Text("Academy Awards")
                                .labelMedium()
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Color.textSecondary)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                if !awards.wins.isEmpty {
                                    let grouped = Dictionary(grouping: awards.wins, by: { $0.category })
                                    let sortedKeys = grouped.keys.sorted { $0.rawValue < $1.rawValue }
                                    ForEach(sortedKeys, id: \.self) { category in
                                        let recipients = grouped[category]?.compactMap(\.recipient).filter { !$0.isEmpty } ?? []
                                        if recipients.isEmpty {
                                            Text(category.rawValue)
                                                .bodySmall()
                                                .foregroundColor(DesignSystem.Color.textPrimary)
                                        } else {
                                            Text("\(category.rawValue) — \(recipients.joined(separator: ", "))")
                                                .bodySmall()
                                                .foregroundColor(DesignSystem.Color.textPrimary)
                                        }
                                    }
                                } else if awards.totalWins > 0 {
                                    Text("\(awards.totalWins) Oscar Win\(awards.totalWins == 1 ? "" : "s")")
                                        .bodySmall()
                                        .foregroundColor(DesignSystem.Color.textPrimary)
                                }

                                if !awards.nominations.isEmpty {
                                    let grouped = Dictionary(grouping: awards.nominations, by: { $0.category })
                                    let sortedKeys = grouped.keys.sorted { $0.rawValue < $1.rawValue }
                                    ForEach(sortedKeys, id: \.self) { category in
                                        let nominees = grouped[category]?.compactMap(\.nominee).filter { !$0.isEmpty } ?? []
                                        if nominees.isEmpty {
                                            Text(category.rawValue)
                                                .bodySmall()
                                                .foregroundColor(DesignSystem.Color.textSecondary)
                                        } else {
                                            Text("\(category.rawValue) — \(nominees.joined(separator: ", "))")
                                                .bodySmall()
                                                .foregroundColor(DesignSystem.Color.textSecondary)
                                        }
                                    }
                                } else if awards.totalNominations > 0 {
                                    Text("\(awards.totalNominations) Nomination\(awards.totalNominations == 1 ? "" : "s")")
                                        .bodySmall()
                                        .foregroundColor(DesignSystem.Color.textSecondary)
                                }
                            }
                        }
                    }
                    
                    if let media = displayMovie.physicalMedia, media.hasDisplayableAvailability {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            Text("Physical Media")
                                .labelMedium()
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Color.textSecondary)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                if media.editions.isEmpty {
                                    let fallback = media.badgeLabels.joined(separator: "   ")
                                    Text(fallback)
                                        .bodySmall()
                                        .foregroundColor(DesignSystem.Color.textPrimary)
                                } else {
                                    ForEach(media.editions) { edition in
                                        Text(edition.displayLine)
                                            .bodySmall()
                                            .foregroundColor(DesignSystem.Color.textPrimary)
                                    }
                                }
                            }

                            if PhysicalPurchaseLinkBuilder.hasOptions(for: media) {
                                Button(action: presentPhysicalPurchaseSheet) {
                                    Text("Buy disc")
                                        .labelMedium()
                                        .fontWeight(.semibold)
                                        .foregroundColor(DesignSystem.Color.textPrimary)
                                }
                                .buttonStyle(CreditTapButtonStyle())
                                .accessibilityLabel("Buy disc")
                            }
                        }
                    }

                    // Streaming Services

                    
                    // Sources Section - Show all sources for this movie
                    if !uniqueMovieSourceContentSnapshots.isEmpty || !legacySources.isEmpty {
                        let podcastFeedURLs = podcastFeedURLByIdentifier
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            Text("Sources & Lists")
                                .labelMedium()
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Color.textSecondary)

                            // Use SourceContent (new schema) if available
                            if !uniqueMovieSourceContentSnapshots.isEmpty {
                                ForEach(
                                    uniqueMovieSourceContentSnapshots.sorted { lhs, rhs in
                                        let lhsIsPodcast = lhs.sourceType.lowercased() == "podcast"
                                        let rhsIsPodcast = rhs.sourceType.lowercased() == "podcast"
                                        if lhsIsPodcast != rhsIsPodcast {
                                            return lhsIsPodcast && !rhsIsPodcast
                                        }
                                        return lhs.sourceName.localizedCaseInsensitiveCompare(rhs.sourceName) == .orderedAscending
                                    }
                                ) { sourceContent in
                                    SourceContentCardView(
                                        sourceContent: sourceContent,
                                        podcastFeedURLString: podcastFeedURLs[sourceContent.sourceIdentifier.lowercased()],
                                        podcastDestinationURL: sourceContent.podcastEpisode.flatMap { episode in
                                            preferredPodcastLink(
                                                podcastName: sourceContent.sourceName,
                                                dataSourceIdentifier: sourceContent.sourceIdentifier,
                                                episode: episode,
                                                movieTitle: displayMovie.title
                                            )
                                        }
                                    )
                                }
                            } else {
                                // Fall back to old schema
                                ForEach(
                                    legacySources.sorted { lhs, rhs in
                                        let lhsIsPodcast = lhs.podcastEpisode != nil
                                        let rhsIsPodcast = rhs.podcastEpisode != nil
                                        if lhsIsPodcast != rhsIsPodcast {
                                            return lhsIsPodcast && !rhsIsPodcast
                                        }
                                        return lhs.sourceName.localizedCaseInsensitiveCompare(rhs.sourceName) == .orderedAscending
                                    }
                                ) { legacySource in
                                    LegacySourceCardView(
                                        legacySource: legacySource,
                                        movieTitle: displayMovie.title,
                                        podcastFeedURLString: podcastFeedURLs[legacySource.sourceIdentifier.lowercased()],
                                        podcastDestinationURL: legacySource.podcastEpisode.flatMap { episode in
                                            preferredPodcastLink(
                                                podcastName: legacySource.sourceName,
                                                dataSourceIdentifier: legacySource.sourceIdentifier,
                                                episode: episode,
                                                movieTitle: displayMovie.title
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
            }
        }

        .sheet(isPresented: $showPhysicalPurchaseSheet) {
            if let media = displayMovie.physicalMedia, media.hasDisplayableAvailability {
                PhysicalPurchaseSheet(
                    movieTitle: displayMovie.title,
                    year: displayMovie.year,
                    media: media
                )
            }
        }
        .onAppear {
            // Sync local state from database when view appears
            syncLocalState()
            loadSourceSnapshotsIfNeeded()
        }
        .task(id: movie.id) {
            await MainActor.run {
                loadSourceSnapshotsIfNeeded(force: true)
            }
        }
        .bottomSheetPullToDismiss()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button("Done") {
//                    dismiss()
//                }
//            }
//        }
        
    }
    
}

struct CastMemberCard: View {
    let member: CastMember
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Construct full TMDB URL for profile image
            if let profilePath = member.profilePath {
                let profileURL = profilePath.hasPrefix("http") ? profilePath : MovieDataService.shared.getPosterURL(path: profilePath, size: .small) ?? profilePath
                if let url = URL(string: profileURL), url.scheme != nil {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(DesignSystem.Color.surface)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                            )
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                } else {
                    // Fallback if URL construction fails
                    Circle()
                        .fill(DesignSystem.Color.surface)
                        .frame(width: 96, height: 96)
                        .overlay(
                            DesignSystemIcon(DesignSystem.Icon.person, size: DesignSystem.IconSize.xl, color: DesignSystem.Color.textSecondary)
                        )
                }
            } else {
                Circle()
                    .fill(DesignSystem.Color.surface)
                    .frame(width: 96, height: 96)
                    .overlay(
                        DesignSystemIcon(DesignSystem.Icon.person, size: DesignSystem.IconSize.xl, color: DesignSystem.Color.textSecondary)
                    )
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(member.name)
                    .captionMedium()
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                if let character = member.character {
                    Text(character)
                        .captionSmall()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
            }
            .frame(width: 100)
        }
    }
}

struct StreamingServiceIconButton: View {
    let service: StreamingService
    let movieTitle: String
    let tmdbId: Int?
    
    private var trimmedServiceName: String {
        service.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        Button(action: openStreamingService) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                StreamingServiceIcon(service: service)
                    .frame(width: 64, height: 64)
            }
            .background(DesignSystem.Color.cardBackground)
            .cornerRadiusMD()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(trimmedServiceName)")
    }
    
    private func openStreamingService() {
        let link = StreamingServiceLinkBuilder.link(
            for: service,
            movieTitle: movieTitle,
            tmdbId: tmdbId
        )
        
        if let appURL = link.appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let fallbackAppURL = link.fallbackAppURL, UIApplication.shared.canOpenURL(fallbackAppURL) {
            UIApplication.shared.open(fallbackAppURL)
        } else if let webURL = link.webURL {
            UIApplication.shared.open(webURL)
        }
    }
}

struct StreamingServiceIcon: View {
    let service: StreamingService
    @Environment(\.colorScheme) private var colorScheme
    
    private var trimmedServiceName: String {
        service.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(GlassControl.Border.subtle.color, lineWidth: GlassControl.Border.subtle.width)
                )
            
            serviceIcon
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        }
    }
    
    @ViewBuilder
    private var serviceIcon: some View {
        if let assetName = StreamingServiceAssets.iconName(for: trimmedServiceName, colorScheme: colorScheme) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .padding(DesignSystem.Spacing.sm)
        } else if let logoPath = service.logoPath,
                  let resolvedLogoURL = MovieDataService.shared.getThumbnailURL(path: logoPath),
                  let url = URL(string: resolvedLogoURL),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https"),
                  url.host != nil {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .padding(DesignSystem.Spacing.sm)
            } placeholder: {
                serviceInitials
            }
        } else {
            serviceInitials
        }
    }
    
    private var serviceInitials: some View {
        Text(StreamingServiceAssets.initials(for: trimmedServiceName))
            .captionMedium()
            .foregroundColor(DesignSystem.Color.textSecondary)
    }
}

private struct StreamingServiceLink {
    let appURL: URL?
    let fallbackAppURL: URL?
    let webURL: URL?
}

enum StreamingServiceAssets {
    private static let iconMap: [String: String] = [
        "netflix": "service_netflix",
        "netflix standard with ads": "service_netflix",
        "amazon prime video": "service_prime_video",
        "amazon prime video with ads": "service_prime_video",
        "amazon video": "service_prime_video",
        "prime video": "service_prime_video",
        "apple tv": "service_apple_tv",
        "apple tv+": "service_apple_tv",
        "disney plus": "service_disney_plus",
        "hbo max": "service_max",
        "max": "service_max",
        "hulu": "service_hulu",
        "paramount plus": "service_paramount_plus",
        "paramount+": "service_paramount_plus",
        "peacock premium": "service_peacock",
        "peacock premium plus": "service_peacock",
        "peacock": "service_peacock",
        "youtube": "service_youtube",
        "google play movies": "service_google_play",
        "fandango at home": "service_vudu",
        "vudu": "service_vudu",
        "plex": "service_plex",
        "mgm plus": "service_mgm_plus",
        "starz": "service_starz"
    ]

    static var knownServiceNames: [String] {
        let normalized = iconMap.keys.map { normalizedName($0) }
        return Array(Set(normalized))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    static func iconName(for serviceName: String) -> String? {
        iconMap[serviceName.lowercased()]
    }

    static func iconName(for serviceName: String, colorScheme: ColorScheme) -> String? {
        guard let baseName = iconMap[serviceName.lowercased()] else {
            return nil
        }
        let suffix = colorScheme == .dark ? "mono_dark" : "mono_light"
        return "\(baseName)_\(suffix)"
    }

    static func normalizedName(_ serviceName: String) -> String {
        let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        switch lowercased {
        case "amazon video", "amazon prime video", "amazon prime video with ads", "prime video":
            return "Prime Video"
        case "hbo max", "max", "hbo max amazon channel", "max amazon channel", "hbo max roku premium channel", "max roku premium channel":
            return "HBO Max"
        default:
            return trimmed
        }
    }

    static func shouldShowService(_ serviceName: String) -> Bool {
        let lowercased = serviceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.contains("amazon channel"), lowercased.contains("hbo") || lowercased.contains("max") {
            return false
        }
        if lowercased.contains("paramount"), !lowercased.contains("premium") {
            return false
        }
        return true
    }

    static func variantScore(_ serviceName: String) -> Int {
        let lowercased = serviceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var score = 0
        if lowercased.contains("premium plus") {
            score += 4
        }
        if lowercased.contains("premium") {
            score += 3
        }
        if lowercased.contains("plus") {
            score += 2
        }
        if lowercased.contains("ad") || lowercased.contains("ads") {
            score -= 2
        }
        return score
    }
    
    static func initials(for serviceName: String) -> String {
        let words = serviceName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        let initials = words.joined()
        return initials.isEmpty ? "?" : initials
    }
}

private enum StreamingServiceLinkBuilder {
    static func link(for service: StreamingService, movieTitle: String, tmdbId: Int?) -> StreamingServiceLink {
        let trimmedName = service.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let query = movieTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? movieTitle
        
        var appURL: URL?
        var fallbackAppURL: URL?
        var webURL: URL? = service.url.flatMap { URL(string: $0) }
        
        switch trimmedName {
        case "netflix":
            appURL = URL(string: "nflx://www.netflix.com/search?q=\(query)")
            webURL = webURL ?? URL(string: "https://www.netflix.com/search?q=\(query)")
        case "netflix standard with ads":
            appURL = URL(string: "nflx://www.netflix.com/search?q=\(query)")
            webURL = webURL ?? URL(string: "https://www.netflix.com/search?q=\(query)")
        case "amazon prime video", "amazon prime video with ads", "amazon video", "prime video":
            appURL = URL(string: "primevideo://search?keyword=\(query)")
            webURL = webURL ?? URL(string: "https://www.amazon.com/s?k=\(query)&i=instant-video")
        case "apple tv", "apple tv+", "apple tv plus":
            appURL = URL(string: "tv://search?term=\(query)")
            webURL = webURL ?? URL(string: "https://tv.apple.com/search?term=\(query)")
        case "disney plus", "disney+":
            appURL = URL(string: "disneyplus://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.disneyplus.com/search?q=\(query)")
        case "hbo max", "max":
            appURL = URL(string: "max://search?query=\(query)")
            fallbackAppURL = URL(string: "hbomax://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://play.max.com/search?q=\(query)")
        case "hulu":
            appURL = URL(string: "hulu://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.hulu.com/search?q=\(query)")
        case "paramount plus", "paramount+":
            appURL = URL(string: "paramountplus://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.paramountplus.com/search/titles/?query=\(query)")
        case "peacock premium", "peacock premium plus", "peacock":
            appURL = URL(string: "peacock://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.peacocktv.com/search?query=\(query)")
        case "youtube":
            appURL = URL(string: "youtube://results?search_query=\(query)")
            webURL = webURL ?? URL(string: "https://www.youtube.com/results?search_query=\(query)")
        case "google play movies":
            appURL = URL(string: "playmovies://search?q=\(query)")
            webURL = webURL ?? URL(string: "https://play.google.com/store/search?q=\(query)&c=movies")
        case "fandango at home", "vudu":
            appURL = URL(string: "vudu://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.vudu.com/content/movies/search?minVisible=0&offset=0&searchString=\(query)")
        case "plex":
            appURL = URL(string: "plex://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://watch.plex.tv/search?query=\(query)")
        case "mgm plus":
            appURL = URL(string: "mgmplus://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.mgmplus.com/search?query=\(query)")
        case "starz":
            appURL = URL(string: "starz://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.starz.com/us/en/search?searchTerm=\(query)")
        default:
            break
        }
        
        if webURL == nil, let tmdbId = tmdbId {
            webURL = URL(string: "https://www.themoviedb.org/movie/\(tmdbId)/watch")
        }
        
        return StreamingServiceLink(appURL: appURL, fallbackAppURL: fallbackAppURL, webURL: webURL)
    }
}

private func createSpotifySearchURL(
    podcastName: String,
    episodeTitle: String,
    movieTitle: String?,
    dataSourceIdentifier: String?
) -> URL? {
    let identifier = dataSourceIdentifier?.lowercased()
    let trimmedMovieTitle = movieTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    let query: String
    
    if let title = trimmedMovieTitle, !title.isEmpty,
       let identifier,
       (identifier == "rewatchables" || identifier == "confused-breakfast" || identifier == "big-picture" || identifier == "blank-check") {
        let keyword: String
        switch identifier {
        case "confused-breakfast": keyword = "confused breakfast"
        case "big-picture": keyword = "big picture"
        case "blank-check": keyword = "blank check"
        default: keyword = "rewatchables"
        }
        query = "\(title) \(keyword)"
    } else {
        query = "\(podcastName) \(episodeTitle)"
    }
    
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    return URL(string: "https://open.spotify.com/search/\(encodedQuery)")
}

private actor PodcastArtworkResolver {
    static let shared = PodcastArtworkResolver()

    private var cache: [String: URL] = [:]

    func artworkURL(feedURLString: String?) async -> URL? {
        guard let feedURLString = feedURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !feedURLString.isEmpty else {
            return nil
        }

        if let cached = cache[feedURLString] {
            return cached
        }

        guard let feedURL = URL(string: feedURLString) else { return nil }
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              !data.isEmpty else {
            return nil
        }

        let xml = String(decoding: data, as: UTF8.self)
        let itunesPattern = "<itunes:image[^>]*href=[\"']([^\"']+)[\"']"
        let channelImagePattern = "<image>[\\s\\S]*?<url>([^<]+)</url>[\\s\\S]*?</image>"

        if let urlString = firstCapture(in: xml, pattern: itunesPattern),
           let artworkURL = URL(string: urlString) {
            cache[feedURLString] = artworkURL
            return artworkURL
        }

        if let urlString = firstCapture(in: xml, pattern: channelImagePattern),
           let artworkURL = URL(string: urlString) {
            cache[feedURLString] = artworkURL
            return artworkURL
        }

        return nil
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PodcastSourceArtworkView: View {
    let feedURLString: String?
    @State private var artworkURL: URL?

    var body: some View {
        Group {
            if let artworkURL {
                CachedAsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
        .task(id: feedURLString) {
            artworkURL = await PodcastArtworkResolver.shared.artworkURL(feedURLString: feedURLString)
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .stroke(GlassControl.Border.card.color, lineWidth: GlassControl.Border.card.width)
            )
    }
}

/// View for displaying source content using new SourceContent schema
struct SourceContentCardView: View {
    let sourceContent: MovieDetailView.SourceContentSnapshot
    let podcastFeedURLString: String?
    let podcastDestinationURL: URL?
    
    var body: some View {
        Group {
            if sourceContent.podcastEpisode != nil, let podcastDestinationURL {
                Link(destination: podcastDestinationURL) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: sourceContent.sourceType.lowercased() == "podcast" ? .top : .center, spacing: DesignSystem.Spacing.md) {
                if sourceContent.sourceType.lowercased() == "podcast" {
                    podcastArtworkView
                } else {
                    listLeadingIconView
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(sourceContent.sourceName)
                            .headlineSmall()
                            .foregroundColor(DesignSystem.Color.textPrimary)
                        
                        // Only show rank if this source is marked as ranked
                        if sourceContent.isRankedList, let rank = sourceContent.rank {
                            Text("#\(rank)")
                                .headlineSmall()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                        }
                    }

                    if let episode = sourceContent.podcastEpisode {

                        Text(episode.title)
                            .captionMedium()
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                        if let publishDate = episode.publishDate {
                            Text(publishDate.formatted(date: .abbreviated, time: .omitted))
                                .captionMedium()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                        }

                    }
                }
            }
            
            // Podcast-only details
            if let episode = sourceContent.podcastEpisode {
                if let description = episode.description, !description.isEmpty {
                    Text(description)
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .lineLimit(4)
                }
            }
        }
    }

    @ViewBuilder
    private var podcastArtworkView: some View {
        PodcastSourceArtworkView(feedURLString: podcastFeedURLString)
            .frame(width: 40, height: 40)
    }

    private var listLeadingIconView: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                    .stroke(GlassControl.Border.card.color, lineWidth: GlassControl.Border.card.width)
            )
            .overlay(
                DesignSystemIcon(DesignSystem.Icon.link, size: DesignSystem.IconSize.md, color: DesignSystem.Color.textSecondary)
            )
            .frame(width: 40, height: 40)
    }
}

struct LegacySourceCardView: View {
    let legacySource: MovieDetailView.LegacySourceSnapshot
    let movieTitle: String?
    let podcastFeedURLString: String?
    let podcastDestinationURL: URL?
    
    var body: some View {
        Group {
            if legacySource.podcastEpisode != nil, let podcastDestinationURL {
                Link(destination: podcastDestinationURL) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: legacySource.podcastEpisode != nil ? .top : .center, spacing: DesignSystem.Spacing.md) {
                if legacySource.podcastEpisode != nil {
                    podcastArtworkView
                } else {
                    listLeadingIconView
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(legacySource.sourceName)
                            .headlineSmall()
                            .foregroundColor(DesignSystem.Color.textPrimary)
                        
                        // Only show ranking if this source is marked as ranked and movie has a rank
                        if let rank = legacySource.rank {
                            Text("#\(rank)")
                                .headlineSmall()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                        }
                    }

                    if let episode = legacySource.podcastEpisode {
                        if let publishDate = episode.publishDate {
                            Text(publishDate.formatted(date: .abbreviated, time: .omitted))
                                .captionMedium()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                        }

                        Text(episode.title)
                            .labelMedium()
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // Show episode title or source title
            if let episode = legacySource.podcastEpisode {
                // Episode description if available
                if let description = episode.description, !description.isEmpty {
                    Text(description)
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .lineLimit(4)
                }
            }
        }
        .task {
            // Auto-update source if we detect it has ranks but isn't marked as ranked
            if let rank = legacySource.rank {
                print("🔢 [Rank] Movie '\(movieTitle ?? "unknown")' has rank \(rank) in source '\(legacySource.sourceName)'")
            } else {
                print("⚠️ [Rank] Movie '\(movieTitle ?? "unknown")' has NO rank in source '\(legacySource.sourceName)'")
            }
        }
    }

    @ViewBuilder
    private var podcastArtworkView: some View {
        PodcastSourceArtworkView(feedURLString: podcastFeedURLString)
            .frame(width: 40, height: 40)
    }

    private var listLeadingIconView: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                    .stroke(GlassControl.Border.card.color, lineWidth: GlassControl.Border.card.width)
            )
            .overlay(
                DesignSystemIcon(DesignSystem.Icon.link, size: DesignSystem.IconSize.md, color: DesignSystem.Color.textSecondary)
            )
            .frame(width: 40, height: 40)
    }
}

// Helper function for preview
private func createPreviewContainer() -> ModelContainer {
    let schema = Schema([
        MovieData.self,
        MovieState.self,
        DataSource.self,
        MovieDataSource.self
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: [config])
}

#Preview {
    NavigationView {
        MovieDetailView(movie: Movie(
            title: "The Matrix",
            year: 1999,
            tmdbId: 603,
            posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
            overview: "A computer hacker learns about the true nature of reality.",
            mpaaRating: "R",
            streamingServices: [
                StreamingService(id: "1", name: "Netflix"),
                StreamingService(id: "2", name: "HBO Max")
            ],
            podcastEpisode: PodcastEpisode(
                title: "The Rewatchables: The Matrix",
                episodeId: "123",
                applePodcastsUrl: "https://podcasts.apple.com"
            ),
            credits: MovieCredits(
                director: "The Wachowskis",
                cast: [
                    CastMember(id: 1, name: "Keanu Reeves", character: "Neo"),
                    CastMember(id: 2, name: "Laurence Fishburne", character: "Morpheus")
                ]
            ),
            trailer: MovieTrailer(
                id: "test",
                name: "Official Trailer",
                youtubeKey: "vKQi3bBA1y8",
                isOfficial: true
            ),
            physicalMedia: PhysicalMedia(
                editions: [
                    PhysicalEdition(id: "matrix-4k", label: .other, format: .uhd4k)
                ],
                has4K: true,
                hasBluRay: true
            )
        ))
        .modelContainer(createPreviewContainer())
    }
}


