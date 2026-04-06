//
//  MovieListView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI
import SwiftData

enum WatchFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case incomplete = "Incomplete"
    case rewatched = "Rewatched"
    case listened = "Listened"
    case saved = "Saved"
}

enum SearchBarAppearance: String, CaseIterable {
    case classic = "Classic"
    case solid = "Solid"
    case elevated = "Elevated"
    case glass = "Glass"
    
    var description: String {
        switch self {
        case .classic:
            return "Ultra thin glass with subtle border"
        case .solid:
            return "Solid background with accent border"
        case .elevated:
            return "Thick glass with prominent shadow"
        case .glass:
            return "Toolbar-matched glass with vibrancy"
        }
    }
    
    static var storageKey: String {
        return "searchBarAppearance"
    }
}

enum SearchCloseButtonVisibilityPreference {
    static var showOnlyWhenSearchFocusedStorageKey: String {
        return "searchCloseButtonShowOnlyWhenSearchFocused"
    }
}

enum LoadingScreenStyle: String, CaseIterable {
    case minimal = "Minimal"
    case skeletonCollections = "Skeleton Collections"
    case posterWall = "Poster Wall"
    case spotlight = "Spotlight"
    
    var description: String {
        switch self {
        case .minimal:
            return "Simple spinner with loading text"
        case .skeletonCollections:
            return "Collection-shaped placeholders with soft pulsing tint"
        case .posterWall:
            return "Poster grid placeholders with shimmer highlights"
        case .spotlight:
            return "Cinematic hero skeleton with featured placeholders"
        }
    }
    
    var systemImage: String {
        switch self {
        case .minimal:
            return "circle.dotted"
        case .skeletonCollections:
            return "rectangle.stack"
        case .posterWall:
            return "square.grid.3x3"
        case .spotlight:
            return "sparkles.tv"
        }
    }
    
    static var storageKey: String {
        return "loadingScreenStyle"
    }
}

enum MainListToolbarStyle: String, CaseIterable {
    case system = "System Toolbar"
    case customFloating = "Custom Floating Toolbar"

    var description: String {
        switch self {
        case .system:
            return "Uses the native iOS bottom toolbar treatment."
        case .customFloating:
            return "Floating frosted toolbar with white icons and separate search button."
        }
    }

    static var storageKey: String {
        return "mainListToolbarStyle"
    }
}

enum MainListToolbarAutoHidePreference {
    static var storageKey: String {
        return "mainListToolbarAutoHideEnabled"
    }
}

enum MainToolbarLayoutStyle: String, CaseIterable {
    case groupedCentered = "Grouped (Centered)"
    case separated = "Separated"

    var description: String {
        switch self {
        case .groupedCentered:
            return "Filter toolbar and search button stay grouped near the center."
        case .separated:
            return "Filter toolbar aligns to the left margin and search aligns to the right margin."
        }
    }

    static var storageKey: String {
        return "mainToolbarLayoutStyle"
    }
}

enum CustomToolbarIconSpacing: String, CaseIterable {
    case px8 = "8 px"
    case px12 = "12 px"
    case px16 = "16 px"
    case px20 = "20 px"
    case px24 = "24 px"
    case px28 = "28 px"
    case px32 = "32 px"
    case px36 = "36 px"

    var description: String {
        switch self {
        case .px8:
            return "Tight icon spacing."
        case .px12:
            return "Compact spacing."
        case .px16:
            return "Relaxed spacing."
        case .px20:
            return "Wide spacing."
        case .px24:
            return "Extra-wide spacing."
        case .px28:
            return "Very wide spacing."
        case .px32:
            return "Ultra-wide spacing."
        case .px36:
            return "Maximum spacing."
        }
    }

    var points: CGFloat {
        switch self {
        case .px8:
            return 8
        case .px12:
            return 12
        case .px16:
            return 16
        case .px20:
            return 20
        case .px24:
            return 24
        case .px28:
            return 28
        case .px32:
            return 32
        case .px36:
            return 36
        }
    }

    static var storageKey: String {
        return "customToolbarIconSpacing"
    }
}

enum PosterSizePreference: String, CaseIterable {
    case plus10 = "+10%"
    case plus20 = "+20%"
    case plus40 = "+40%"
    case plus60 = "+60%"
    
    var description: String {
        switch self {
        case .plus10:
            return "Slightly larger posters."
        case .plus20:
            return "Roomier cards with stronger visual emphasis."
        case .plus40:
            return "Big posters for a more visual browsing style."
        case .plus60:
            return "Extra-large posters for maximum artwork focus."
        }
    }
    
    private var scale: CGFloat {
        switch self {
        case .plus10:
            return 1.10
        case .plus20:
            return 1.20
        case .plus40:
            return 1.40
        case .plus60:
            return 1.60
        }
    }
    
    static var storageKey: String {
        return "mainListPosterSizePreference"
    }
    
    func dimensions(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let scaledWidth = baseWidth * scale
        let scaledHeight = baseHeight * scale
        return CGSize(width: snapTo8px(scaledWidth), height: snapTo8px(scaledHeight))
    }
    
    private func snapTo8px(_ value: CGFloat) -> CGFloat {
        (value / 8).rounded() * 8
    }
    
    /// Returns the optimal TMDB image size for crisp rendering at this poster size
    var optimalImageSize: MovieDataService.ImageSize {
        switch self {
        case .plus10:
            return .thumbnail  // w185 - sufficient for 110px posters
        case .plus20:
            return .small      // w342 - better quality for 120px posters
        case .plus40:
            return .small      // w342 - good for 140px posters
        case .plus60:
            return .medium     // w500 - crisp for 160px posters
        }
    }
}

enum SortOption: String, CaseIterable {
    case title = "Title"
    case releaseDateAsc = "Release Date (Oldest First)"
    case releaseDateDesc = "Release Date (Newest First)"
    case episodeDateAsc = "Episode Date (Oldest First)"
    case episodeDateDesc = "Episode Date (Newest First)"
    case ranking = "Ranking"
    
    // Computed property to get available sort options based on context
    static func availableOptions(for selectedList: DataSource?, allMovieDataSources: [MovieDataSource] = []) -> [SortOption] {
        let options = SortOption.allCases
        
        // Check if the selected list is ranked
        // Only check if source is marked as ranked - don't auto-mark sources
        let isRanked = selectedList?.isRankedList ?? false
        if isRanked {
            return options
        } else {
            // Remove ranking option if no ranked list is selected
            return options.filter { $0 != .ranking }
        }
    }
}

struct MovieStatus: Hashable {
    let isRewatched: Bool
    let isListened: Bool
    let isSaved: Bool
}

struct MovieListView: View {
    let collectionsOnlyMode: Bool
    @StateObject private var localDB = LocalDatabaseManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DataSource.name) private var allDataSources: [DataSource]

    // Preferred lists for inspiration and filters
    var preferredDataSources: [DataSource] {
        let lookup = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0) })
        return preferredListIdentifiers.compactMap { lookup[$0] }
    }
    
    // Lazy-loaded cache for movie-to-sources mapping - build on demand
    @State private var hasLoadedSourceContents = false
    
    // Build source cache from @Query results on demand
    @MainActor
    private func buildSourceCacheIfNeeded() {
        guard !hasBuiltSourceCache else { return }
        buildMovieSourceCache()
    }
    @State private var searchText = ""
    @State private var watchFilter: WatchFilter = .all
    @State private var selectedGenre: String? = nil
    @State private var selectedMPAARating: String? = nil // Filter by MPAA rating
    @State private var selectedList: DataSource? = nil // Filter by list (unified - can be external source or local list)
    @State private var selectedStreamingService: String? = nil
    @State private var sortOption: SortOption = .episodeDateDesc
    @State private var showAccountSheet = false
    @State private var showSearch = false
    @State private var activeSearchContext: SearchPresentationContext? = nil
    @State private var selectedMovie: Movie? = nil
    @State private var pendingPersonSearchQuery: String? = nil
    @State private var pendingDetailSearchContext: SearchPresentationContext? = nil
    @State private var activePersonSearchQuery: String? = nil
    @State private var skipNextSearchAutofocus = false
    @AppStorage(StreamingPreferences.storageKey) private var preferredServicesData: Data = Data()
    @AppStorage(ListPreferences.storageKey) private var preferredListsData: Data = Data()
    @AppStorage(SearchBarAppearance.storageKey) private var searchBarAppearanceRaw: String = SearchBarAppearance.classic.rawValue
    @AppStorage(LoadingScreenStyle.storageKey) private var loadingScreenStyleRaw: String = LoadingScreenStyle.skeletonCollections.rawValue
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.system.rawValue
    @AppStorage(MainToolbarLayoutStyle.storageKey) private var mainToolbarLayoutStyleRaw: String = MainToolbarLayoutStyle.separated.rawValue
    @AppStorage(MainListToolbarAutoHidePreference.storageKey) private var isToolbarAutoHideEnabled: Bool = true
    @AppStorage(CustomToolbarIconSpacing.storageKey) private var customToolbarIconSpacingRaw: String = CustomToolbarIconSpacing.px24.rawValue
    @AppStorage(PosterSizePreference.storageKey) private var posterSizePreferenceRaw: String = PosterSizePreference.plus60.rawValue
    @AppStorage("tapInteractionStyle") private var tapStyleRaw: String = TapInteractionStyle.bounce.rawValue
    @AppStorage(TapInteractionParameters.storageKey) private var tapParametersData: Data = TapInteractionParameters().encode()
    @AppStorage(ToolbarScrollingBehavior.storageKey) private var toolbarBehaviorRaw: String = ToolbarScrollingBehavior.alwaysVisible.rawValue
    @AppStorage(BottomSheetPresentationStyle.storageKey) private var bottomSheetStyleRaw: String = BottomSheetPresentationStyle.defaultStyle.rawValue
    @State private var hasNormalizedStreamingServices = false
    @StateObject private var toolbarScrollState = ToolbarScrollState()
    @State private var titleTypeBlurRadius: CGFloat = 0
    
    private var tapStyle: TapInteractionStyle {
        TapInteractionStyle(rawValue: tapStyleRaw) ?? .bounce
    }
    
    private var tapParameters: TapInteractionParameters {
        TapInteractionParameters.decode(from: tapParametersData)
    }
    
    private var toolbarBehavior: ToolbarScrollingBehavior {
        ToolbarScrollingBehavior(rawValue: toolbarBehaviorRaw) ?? .alwaysVisible
    }

    private var bottomSheetStyle: BottomSheetPresentationStyle {
        BottomSheetPresentationStyle(rawValue: bottomSheetStyleRaw) ?? .defaultStyle
    }
    
    private var searchBarAppearance: SearchBarAppearance {
        SearchBarAppearance(rawValue: searchBarAppearanceRaw) ?? .classic
    }
    
    private var loadingScreenStyle: LoadingScreenStyle {
        LoadingScreenStyle(rawValue: loadingScreenStyleRaw) ?? .skeletonCollections
    }
    
    private var mainListToolbarStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .system
    }

    private var mainToolbarLayoutStyle: MainToolbarLayoutStyle {
        MainToolbarLayoutStyle(rawValue: mainToolbarLayoutStyleRaw) ?? .separated
    }

    private var customToolbarIconSpacing: CustomToolbarIconSpacing {
        CustomToolbarIconSpacing(rawValue: customToolbarIconSpacingRaw) ?? .px24
    }
    
    private var posterSizePreference: PosterSizePreference {
        PosterSizePreference(rawValue: posterSizePreferenceRaw) ?? .plus10
    }
    
    private var usesCustomFloatingToolbar: Bool {
        #if os(iOS)
        return mainListToolbarStyle == .customFloating
        #else
        return false
        #endif
    }
    @FocusState private var isSearchFieldFocused: Bool
    private let glassControlHeight: CGFloat = GlassControl.compactHeight
    private let customToolbarHeightBoost: CGFloat = 8
    private let titleTypeBlurDistance: CGFloat = 140
    private let titleTypeMaxBlurRadius: CGFloat = 10
    @State private var selectedInspiration: InspirationSection? = nil
    private let myServicesFilterLabel = "My Services"
    private let perfLoggingDefaultsKey = "perf_logging_enabled"
    
    // Cache for filtered movies to avoid recalculation
    @State private var cachedFilteredMovies: [Movie] = []
    @State private var lastFilterHash: Int = 0
    @State private var filterVersion: Int = 0
    @State private var effectiveSearchText = ""
    @State private var searchRecomputeTask: Task<Void, Never>? = nil
    @State private var searchIndexBuildTask: Task<Void, Never>? = nil
    @State private var isSearchFiltering = false
    @State private var movieSearchIndex: [String: String] = [:]
    @State private var movieStatusLookup: [String: MovieStatus] = [:]
    @State private var cachedAllGenres: [String] = []
    @State private var previousSearchQuery = ""
    @State private var previousSearchResultIds: Set<String> = []
    @State private var previousSearchFilterVersion: Int = 0
    @State private var lastScheduledSearchQuery = ""
    @State private var movieDetailOpenRequestedAt: TimeInterval? = nil
    @State private var movieDetailOpenRequestedMovieID: String? = nil
    @State private var movieDetailPresentedAt: TimeInterval? = nil
    @State private var movieDetailPresentedMovieID: String? = nil
    
    // Pagination state
    @State private var displayedMovieCount = 50 // Start showing only 50 movies
    @State private var isLoadingMore = false
    @State private var podcastFeedArtworkURLs: [String: URL] = [:]
    @State private var isLoadingPodcastFeedArtwork = false
    @State private var hasHydratedPodcastFeedArtworkCache = false
    @State private var podcastFeedArtworkCacheSavedAt: Date? = nil
    @State private var prefetchedPodcastArtworkSourceIds: Set<String> = []
    @AppStorage("podcast_feed_artwork_cache_v1") private var podcastFeedArtworkCacheData: Data = Data()
    
    private let baseInspirationPosterWidth: CGFloat = 100
    private let baseInspirationPosterHeight: CGFloat = 150
    private let inspirationLimit = 25
    /// Aligns with `SearchResultsContent` / `SearchResultRow`: outer `md + xs` plus row inner horizontal `sm`.
    private let inspirationLeadingPadding: CGFloat = DesignSystem.Spacing.screenHorizontalPadding
    private let inspirationPosterSpacing: CGFloat = DesignSystem.Spacing.md
    private let latestPodcastLimit = 20
    private let podcastBadgeSize: CGFloat = 24
    private let podcastBadgeInset: CGFloat = 4
    private let podcastBadgePeekWidth: CGFloat = 8
    private let podcastFeedArtworkCacheMaxAge: TimeInterval = 60 * 60 * 24 * 14

    init(collectionsOnlyMode: Bool = false) {
        self.collectionsOnlyMode = collectionsOnlyMode
    }
    
    private var inspirationPosterWidth: CGFloat {
        posterSizePreference.dimensions(baseWidth: baseInspirationPosterWidth, baseHeight: baseInspirationPosterHeight).width
    }
    
    private var inspirationPosterHeight: CGFloat {
        posterSizePreference.dimensions(baseWidth: baseInspirationPosterWidth, baseHeight: baseInspirationPosterHeight).height
    }

    private struct PodcastFeedArtworkCacheSnapshot: Codable {
        let savedAt: Date
        let urls: [String: String]
    }

    private var customToolbarControlHeight: CGFloat {
        glassControlHeight + customToolbarHeightBoost
    }

    private enum InspirationSection: String, CaseIterable {
        case recentlySaved
        case latestPodcasts
        case toComplete
        case longestSaved

        var title: String {
            switch self {
            case .recentlySaved:
                return "Recently saved"
            case .latestPodcasts:
                return "Latest podcasts"
            case .toComplete:
                return "To complete"
            case .longestSaved:
                return "Longest saved"
            }
        }
    }
    
    var allGenres: [String] {
        cachedAllGenres
    }

    private var preferredStreamingServices: [String] {
        let decoded = StreamingPreferences.decode(from: preferredServicesData)
            .map { StreamingServiceAssets.normalizedName($0) }
        return canonicalizeServices(decoded)
    }

    private var preferredListIdentifiers: [String] {
        let decoded = ListPreferences.decode(from: preferredListsData)
        if decoded.isEmpty && !ListPreferences.hasInitialized() {
            return allDataSources.map { $0.identifier }
        }
        return decoded
    }

    private var preferredListIdentifierSet: Set<String> {
        Set(preferredListIdentifiers)
    }
    
    private var hasPreferredStreamingServices: Bool {
        !preferredStreamingServices.isEmpty
    }
    
    private var hasActiveFilters: Bool {
        watchFilter != .all
            || selectedGenre != nil
            || selectedMPAARating != nil
            || selectedList != nil
            || selectedStreamingService != nil
    }
    
    private var shouldShowInspirationSections: Bool {
        if collectionsOnlyMode {
            return true
        }
        return !showSearch && (!hasActiveFilters || selectedInspiration != nil)
    }

    private var isPerfLoggingEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: perfLoggingDefaultsKey) as? Bool ?? false
        #else
        return UserDefaults.standard.bool(forKey: perfLoggingDefaultsKey)
        #endif
    }

    private func logPerf(_ label: String, start: TimeInterval, thresholdMs: Double = 0) {
        guard isPerfLoggingEnabled else { return }
        let elapsedMs = (ProcessInfo.processInfo.systemUptime - start) * 1000
        guard elapsedMs >= thresholdMs else { return }
        print("⏱️ [PERF] [MovieListView] \(label): \(String(format: "%.1f", elapsedMs))ms")
    }

    private func logFilterInteraction(_ source: String, start: TimeInterval, thresholdMs: Double = 8) {
        guard isPerfLoggingEnabled else { return }
        let elapsedMs = (ProcessInfo.processInfo.systemUptime - start) * 1000
        guard elapsedMs >= thresholdMs else { return }
        print("⏱️ [PERF] [Filter] \(source): \(String(format: "%.1f", elapsedMs))ms")
    }

    private func logMovieDetailPresented(_ movieID: String) {
        guard isPerfLoggingEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        movieDetailPresentedAt = now
        movieDetailPresentedMovieID = movieID
        if movieDetailOpenRequestedMovieID == movieID, let openStart = movieDetailOpenRequestedAt {
            let elapsedMs = (now - openStart) * 1000
            if elapsedMs >= 8 {
                print("⏱️ [PERF] [Detail] open -> presented (\(movieID)): \(String(format: "%.1f", elapsedMs))ms")
            }
        }
    }

    private func logMovieDetailDismissed() {
        guard isPerfLoggingEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let presentedAt = movieDetailPresentedAt {
            let elapsedMs = (now - presentedAt) * 1000
            print("⏱️ [PERF] [Detail] presented -> dismissed (\(movieDetailPresentedMovieID ?? "unknown")): \(String(format: "%.1f", elapsedMs))ms")
        }
        movieDetailPresentedAt = nil
        movieDetailPresentedMovieID = nil
        movieDetailOpenRequestedAt = nil
        movieDetailOpenRequestedMovieID = nil
    }
    
    // Cache for movie-to-sources mapping to avoid repeated filtering
    @State private var movieToSourcesCache: [String: Set<String>] = [:]
    @State private var hasBuiltSourceCache = false
    
    /// Builds a cache mapping movie IDs to their source identifiers (one-time operation)
    private func buildMovieSourceCache() {
        guard !hasBuiltSourceCache else { return }
        movieToSourcesCache = buildMovieSourceCacheSnapshot()
        hasBuiltSourceCache = true
    }
    
    /// Builds a cache snapshot without mutating view state.
    private func buildMovieSourceCacheSnapshot() -> [String: Set<String>] {
        var cache: [String: Set<String>] = [:]

        let descriptor = FetchDescriptor<MovieData>()
        let movieDataList = (try? modelContext.fetch(descriptor)) ?? []

        for movieData in movieDataList {
            guard movieData.modelContext != nil else { continue }
            let movieId = movieData.id
            var sourceIds = cache[movieId, default: Set<String>()]

            for content in movieData.sourceContents ?? [] {
                if let sourceId = content.source?.identifier {
                    sourceIds.insert(sourceId)
                }
            }

            for dataSource in movieData.dataSources ?? [] {
                if let sourceId = dataSource.dataSource?.identifier {
                    sourceIds.insert(sourceId)
                }
            }

            cache[movieId] = sourceIds
        }

        return cache
    }
    
    /// Filters movies to only show those with at least one preferred list
    private func filterMoviesByEnabledSources(movies: [Movie], enabledSourceIds: Set<String>) -> [Movie] {
        let cache = hasBuiltSourceCache ? movieToSourcesCache : buildMovieSourceCacheSnapshot()
        
        // Use cached lookup instead of filtering all SourceContents/MovieDataSources for each movie
        return movies.filter { movie in
            guard let sourceIds = cache[movie.id] else {
                // Movie has no sources, keep it (might be manually added)
                return true
            }
            
            // Check if at least one source is enabled (O(1) lookup)
            return !sourceIds.intersection(enabledSourceIds).isEmpty
        }
    }

    private func movieMatchesSearch(_ movie: Movie, searchText: String) -> Bool {
        // Check most common/important fields first for early exit
        // Title is the most common search target
        if movie.title.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        
        // Year is quick to check
        if let year = movie.year, String(year).contains(searchText) {
            return true
        }
        
        // Director and cast are common search targets
        if let credits = movie.credits {
            if matchesSearchText(searchText, in: credits.director) {
                return true
            }
            // Limit cast search to first 10 for performance (most searches find matches in top billed actors)
            if credits.cast.prefix(10).contains(where: { castMember in
                matchesSearchText(searchText, in: castMember.name)
            }) {
                return true
            }
        }
        
        // Genres and rating are often searched
        if matchesSearchText(searchText, in: movie.genres) {
            return true
        }
        
        if matchesSearchText(searchText, in: movie.mpaaRating) {
            return true
        }
        
        // Overview and streaming services
        if matchesSearchText(searchText, in: movie.overview) {
            return true
        }
        
        if movie.streamingServices.contains(where: { service in
            matchesSearchText(searchText, in: service.name)
        }) {
            return true
        }
        
        // Podcast episode data (less common)
        if let episode = movie.podcastEpisode {
            if matchesSearchText(searchText, in: episode.title) {
                return true
            }
            if matchesSearchText(searchText, in: episode.description) {
                return true
            }
        }
        
        // Extended cast and character search (less common, checked later)
        if let credits = movie.credits, credits.cast.count > 10 {
            if credits.cast.dropFirst(10).contains(where: { castMember in
                matchesSearchText(searchText, in: castMember.name)
                    || matchesSearchText(searchText, in: castMember.character)
            }) {
                return true
            }
        }
        
        // Oscar awards search
        if let awards = movie.oscarAwards {
            // Search for "oscar", "academy award", "win", "nomination"
            let lowerSearch = searchText.lowercased()
            if lowerSearch.contains("oscar") 
                || lowerSearch.contains("academy") 
                || (lowerSearch.contains("win") && awards.totalWins > 0)
                || (lowerSearch.contains("nom") && awards.totalNominations > 0)
                || lowerSearch.contains("award") {
                return true
            }
            
            // Search for specific numbers
            if let searchNumber = Int(searchText) {
                if searchNumber == awards.totalWins || searchNumber == awards.totalNominations {
                    return true
                }
            }
        }
        
        // Rewatchables discussion data (least common, checked last)
        if let discussion = movie.rewatchablesDiscussion {
            if matchesSearchText(searchText, in: discussion.apexMountain)
                || matchesSearchText(searchText, in: discussion.dionWaiters)
                || matchesSearchText(searchText, in: discussion.agedBest)
                || matchesSearchText(searchText, in: discussion.agedWorst)
                || matchesSearchText(searchText, in: discussion.joeyPants)
                || matchesSearchText(searchText, in: discussion.thatGuy)
                || matchesSearchText(searchText, in: discussion.castingWhatIf)
                || matchesSearchText(searchText, in: discussion.unanswerableQuestions) {
                return true
            }
            if let score = discussion.rewatchabilityScore, String(score).contains(searchText) {
                return true
            }
            if let apexYear = discussion.apexMountainYear, String(apexYear).contains(searchText) {
                return true
            }
            if let dionYear = discussion.dionWaitersYear, String(dionYear).contains(searchText) {
                return true
            }
        }
        return false
    }

    private func movieMatchesPersonSearch(_ movie: Movie, personName: String) -> Bool {
        guard let credits = movie.credits else { return false }

        if let director = credits.director, director.localizedCaseInsensitiveContains(personName) {
            return true
        }

        return credits.cast.contains { castMember in
            castMember.name.localizedCaseInsensitiveContains(personName)
        }
    }

    private func matchesSearchText(_ searchText: String, in value: String?) -> Bool {
        guard let value, !value.isEmpty else { return false }
        return value.localizedCaseInsensitiveContains(searchText)
    }

    private func matchesSearchText(_ searchText: String, in values: [String]) -> Bool {
        values.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Cache for movie ranks by source to avoid repeated lookups.
    // Keep this off SwiftUI @State so cache refreshes during sorting don't mutate view state.
    @State private var rankCacheStore = RankCacheStore()
    
    final class RankCacheStore {
        var rankCache: [String: [String: Int]] = [:] // [sourceId: [movieId: rank]]
        var lastRankCacheSourceId: String? = nil
    }
    
    /// Gets the rank for a movie in a specific source/list (uses cache for performance)
    private func getRankForMovie(_ movie: Movie, in source: DataSource) -> Int? {
        let sourceId = source.identifier
        
        // Build cache if needed or if source changed
        if rankCacheStore.rankCache[sourceId] == nil || rankCacheStore.lastRankCacheSourceId != sourceId {
            buildRankCache(for: source)
            rankCacheStore.lastRankCacheSourceId = sourceId
        }
        
        return rankCacheStore.rankCache[sourceId]?[movie.id]
    }
    
    /// Builds a cache of movie ranks for a specific source
    /// Only includes ranks if the source is marked as ranked
    /// IMPORTANT: Only includes ranks that belong to the specified source
    private func buildRankCache(for source: DataSource) {
        var cache: [String: Int] = [:]
        let sourceId = source.identifier
        
        // Only build rank cache for sources that are marked as ranked
        guard source.isRankedList else {
            rankCacheStore.rankCache[sourceId] = cache
            return
        }

        let descriptor = FetchDescriptor<MovieData>()
        let movieDataList = (try? modelContext.fetch(descriptor)) ?? []

        for movieData in movieDataList {
            guard movieData.modelContext != nil else { continue }
            let movieId = movieData.id

            if let sourceContents = movieData.sourceContents {
                for content in sourceContents {
                    guard let contentSourceId = content.source?.identifier,
                          contentSourceId == sourceId,
                          let rank = content.rank else {
                        continue
                    }
                    cache[movieId] = rank
                }
            }

            if let dataSources = movieData.dataSources {
                for dataSource in dataSources {
                    guard let dataSourceId = dataSource.dataSource?.identifier,
                          dataSourceId == sourceId,
                          let rank = dataSource.rank,
                          cache[movieId] == nil else {
                        continue
                    }
                    cache[movieId] = rank
                }
            }
        }

        // Store cache with the source identifier as the key
        rankCacheStore.rankCache[sourceId] = cache
    }
    
    // Compute hash of filter state for cache invalidation
    private func computeFilterHash() -> Int {
        var hasher = Hasher()
        hasher.combine(effectiveSearchText)
        hasher.combine(activePersonSearchQuery ?? "")
        hasher.combine(watchFilter.rawValue)
        hasher.combine(selectedInspiration?.rawValue ?? "")
        hasher.combine(selectedGenre ?? "")
        hasher.combine(selectedMPAARating ?? "")
        hasher.combine(selectedList?.identifier ?? "")
        hasher.combine(selectedStreamingService ?? "")
        hasher.combine(sortOption.rawValue)
        hasher.combine(filterVersion)
        hasher.combine(localDB.movieStatusVersion)
        hasher.combine(localDB.movies.count)
        // Include preferred lists in hash to invalidate when list prefs change
        hasher.combine(preferredListIdentifiers.count)
        for listId in preferredListIdentifiers {
            hasher.combine(listId)
        }
        // Hash movie IDs and states to detect when movies or their states change
        for movie in localDB.movies.prefix(20) {
            hasher.combine(movie.id)
            hasher.combine(movie.isRewatched)
            hasher.combine(movie.isListened)
            hasher.combine(movie.isSaved)
        }
        return hasher.finalize()
    }
    
    private var filteredMovies: [Movie] {
        cachedFilteredMovies
    }
    
    private func computeFilteredMovies(searchText: String) -> [Movie] {
        var movies = localDB.movies
        
        // Apply search filter using the effective debounced value passed in.
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let normalizedSearch = trimmedSearch.lowercased()
            if let personQuery = activePersonSearchQuery,
               personQuery.compare(trimmedSearch, options: .caseInsensitive) == .orderedSame {
                movies = movies.filter { movie in
                    movieMatchesPersonSearch(movie, personName: personQuery)
                }
            } else {
                movies = movies.filter { movie in
                    if let indexedContent = movieSearchIndex[movie.id] {
                        return indexedContent.contains(normalizedSearch)
                    }
                    // If index is still warming, keep matching useful fields.
                    if movie.title.lowercased().contains(normalizedSearch) {
                        return true
                    }
                    if let year = movie.year, String(year).contains(trimmedSearch) {
                        return true
                    }
                    return false
                }
            }
        }
        
        // Apply watch filter
        switch watchFilter {
        case .all:
            break
        case .completed:
            movies = movies.filter { $0.isRewatched && $0.isListened }
        case .incomplete:
            movies = movies.filter { $0.isRewatched != $0.isListened }
        case .rewatched:
            movies = movies.filter { $0.isRewatched }
        case .listened:
            movies = movies.filter { $0.isListened }
        case .saved:
            movies = movies.filter { $0.isSaved }
        }
        
        // Apply genre filter
        if let selectedGenre = selectedGenre {
            movies = movies.filter { $0.genres.contains(selectedGenre) }
        }
        
        // Apply MPAA Rating filter
        if let selectedMPAARating = selectedMPAARating {
            movies = movies.filter { $0.mpaaRating == selectedMPAARating }
        }
        
        // Apply list filter (unified - works for both external sources and local lists)
        if let selectedList = selectedList {
            let cache = hasBuiltSourceCache ? movieToSourcesCache : buildMovieSourceCacheSnapshot()
            
            // Get movies from this source using the cache
            let movieIdsInList = Set(cache.compactMap { (movieId, sourceIds) in
                sourceIds.contains(selectedList.identifier) ? movieId : nil
            })
            
            movies = movies.filter { movie in
                movieIdsInList.contains(movie.id)
            }
        }

        // Apply streaming service filter
        if let selectedStreamingService = selectedStreamingService {
            if selectedStreamingService == myServicesFilterLabel {
                let preferredKeys = Set(preferredStreamingServices.map { StreamingServiceAssets.normalizedName($0).lowercased() })
                movies = movies.filter { movie in
                    movie.streamingServices.contains { service in
                        preferredKeys.contains(StreamingServiceAssets.normalizedName(service.name).lowercased())
                    }
                }
            } else {
                let normalizedSelectedService = StreamingServiceAssets.normalizedName(selectedStreamingService).lowercased()
                movies = movies.filter { movie in
                    movie.streamingServices.contains { service in
                        StreamingServiceAssets.normalizedName(service.name).lowercased() == normalizedSelectedService
                    }
                }
            }
        }

        // Apply inspiration selection (overrides sort option)
        if selectedInspiration != nil {
            return applyInspirationFilter(to: movies)
        }
        
        // Apply sorting
        switch sortOption {
        case .title:
            movies = movies.sorted { $0.title < $1.title }
        case .releaseDateAsc:
            movies = movies.sorted { (m1, m2) in
                let y1 = m1.year ?? 0
                let y2 = m2.year ?? 0
                if y1 != y2 { return y1 < y2 }
                return m1.title < m2.title
            }
        case .releaseDateDesc:
            movies = movies.sorted { (m1, m2) in
                let y1 = m1.year ?? 0
                let y2 = m2.year ?? 0
                if y1 != y2 { return y1 > y2 }
                return m1.title < m2.title
            }
        case .episodeDateAsc:
            movies = movies.sorted { (m1, m2) in
                let d1 = m1.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = m2.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 < d2 }
                return m1.title < m2.title
            }
        case .episodeDateDesc:
            movies = movies.sorted { (m1, m2) in
                let d1 = m1.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = m2.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 > d2 }
                return m1.title < m2.title
            }
        case .ranking:
            // Sort by ranking from the selected list
            // Only sort by rank if a ranked list is selected
            if let selectedList = selectedList, selectedList.isRankedList {
                // ALWAYS rebuild cache for the selected source to ensure we have the correct ranks
                // This prevents using ranks from a different source
                let sourceId = selectedList.identifier
                
                // Clear any stale cache and rebuild for the selected source
                // This ensures we're always using ranks from the currently selected source
                buildRankCache(for: selectedList)
                rankCacheStore.lastRankCacheSourceId = sourceId
                
                // Get ranks from the cache we just built for this specific source
                    guard let ranks = rankCacheStore.rankCache[sourceId] else {
                        // Fallback if cache build failed
                        movies = movies.sorted { $0.title < $1.title }
                        break
                    }
                
                // Sort using cached ranks from the selected source only (O(1) lookups)
                // Only use ranks that belong to the selected source
                movies = movies.sorted { (m1, m2) in
                    // Get ranks from the selected source's cache only
                    let rank1 = ranks[m1.id]
                    let rank2 = ranks[m2.id]
                    
                    // Movies with ranks come first, sorted by rank
                    if let r1 = rank1, let r2 = rank2 {
                        return r1 < r2
                    } else if rank1 != nil {
                        return true // m1 has rank, m2 doesn't
                    } else if rank2 != nil {
                        return false // m2 has rank, m1 doesn't
                    } else {
                        // Neither has rank, sort by title
                        return m1.title < m2.title
                    }
                }
            } else {
                // Fallback to title sort if no ranked list selected
                movies = movies.sorted { $0.title < $1.title }
            }
        }
        
        return movies
    }
    
    /// Performs filtering in the background to avoid blocking the UI thread
    /// This is called from a Task.detached context for better performance
    private func performFiltering(
        movies: [Movie],
        trimmedSearch: String,
        activePersonQuery: String?,
        watchFilter: WatchFilter,
        selectedGenre: String?,
        selectedRating: String?,
        selectedList: DataSource?,
        selectedStreaming: String?,
        sortOption: SortOption,
        selectedInspiration: InspirationSection?,
        preferredServices: [String],
        sourceCache: [String: Set<String>]
    ) async -> [Movie] {
        var filteredMovies = movies
        
        // Apply search filter
        if !trimmedSearch.isEmpty {
            if let personQuery = activePersonQuery,
               personQuery.compare(trimmedSearch, options: .caseInsensitive) == .orderedSame {
                filteredMovies = filteredMovies.filter { movie in
                    movieMatchesPersonSearch(movie, personName: personQuery)
                }
            } else {
                filteredMovies = filteredMovies.filter { movie in
                    movieMatchesSearch(movie, searchText: trimmedSearch)
                }
            }
        }
        
        // Apply watch filter
        switch watchFilter {
        case .all:
            break
        case .completed:
            filteredMovies = filteredMovies.filter { $0.isRewatched && $0.isListened }
        case .incomplete:
            filteredMovies = filteredMovies.filter { $0.isRewatched != $0.isListened }
        case .rewatched:
            filteredMovies = filteredMovies.filter { $0.isRewatched }
        case .listened:
            filteredMovies = filteredMovies.filter { $0.isListened }
        case .saved:
            filteredMovies = filteredMovies.filter { $0.isSaved }
        }
        
        // Apply genre filter
        if let selectedGenre = selectedGenre {
            filteredMovies = filteredMovies.filter { $0.genres.contains(selectedGenre) }
        }
        
        // Apply MPAA Rating filter
        if let selectedRating = selectedRating {
            filteredMovies = filteredMovies.filter { $0.mpaaRating == selectedRating }
        }
        
        // Apply list filter
        if let selectedList = selectedList {
            let movieIdsInList = Set(sourceCache.compactMap { (movieId, sourceIds) in
                sourceIds.contains(selectedList.identifier) ? movieId : nil
            })
            
            filteredMovies = filteredMovies.filter { movie in
                movieIdsInList.contains(movie.id)
            }
        }
        
        // Apply streaming service filter
        if let selectedStreaming = selectedStreaming {
            if selectedStreaming == myServicesFilterLabel {
                let preferredKeys = Set(preferredServices.map { StreamingServiceAssets.normalizedName($0).lowercased() })
                filteredMovies = filteredMovies.filter { movie in
                    movie.streamingServices.contains { service in
                        preferredKeys.contains(StreamingServiceAssets.normalizedName(service.name).lowercased())
                    }
                }
            } else {
                let normalizedSelectedService = StreamingServiceAssets.normalizedName(selectedStreaming).lowercased()
                filteredMovies = filteredMovies.filter { movie in
                    movie.streamingServices.contains { service in
                        StreamingServiceAssets.normalizedName(service.name).lowercased() == normalizedSelectedService
                    }
                }
            }
        }
        
        // Apply inspiration selection (needs main actor for applyInspirationFilter)
        if selectedInspiration != nil {
            return await MainActor.run {
                applyInspirationFilter(to: filteredMovies)
            }
        }
        
        // Apply sorting
        return await applySorting(to: filteredMovies, sortOption: sortOption, selectedList: selectedList)
    }
    
    /// Applies sorting to filtered movies
    private func applySorting(to movies: [Movie], sortOption: SortOption, selectedList: DataSource?) async -> [Movie] {
        var sortedMovies = movies
        
        switch sortOption {
        case .title:
            sortedMovies = movies.sorted { $0.title < $1.title }
        case .releaseDateAsc:
            sortedMovies = movies.sorted { (m1, m2) in
                let y1 = m1.year ?? 0
                let y2 = m2.year ?? 0
                if y1 != y2 { return y1 < y2 }
                return m1.title < m2.title
            }
        case .releaseDateDesc:
            sortedMovies = movies.sorted { (m1, m2) in
                let y1 = m1.year ?? 0
                let y2 = m2.year ?? 0
                if y1 != y2 { return y1 > y2 }
                return m1.title < m2.title
            }
        case .episodeDateAsc:
            sortedMovies = movies.sorted { (m1, m2) in
                let d1 = m1.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = m2.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 < d2 }
                return m1.title < m2.title
            }
        case .episodeDateDesc:
            sortedMovies = movies.sorted { (m1, m2) in
                let d1 = m1.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = m2.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 > d2 }
                return m1.title < m2.title
            }
        case .ranking:
            if let selectedList = selectedList, selectedList.isRankedList {
                return await MainActor.run {
                    let sourceId = selectedList.identifier
                    buildRankCache(for: selectedList)
                    rankCacheStore.lastRankCacheSourceId = sourceId
                    
                    guard let ranks = rankCacheStore.rankCache[sourceId] else {
                        return movies.sorted { $0.title < $1.title }
                    }
                    
                    return movies.sorted { (m1, m2) in
                        let rank1 = ranks[m1.id]
                        let rank2 = ranks[m2.id]
                        
                        if let r1 = rank1, let r2 = rank2 {
                            return r1 < r2
                        } else if rank1 != nil {
                            return true
                        } else if rank2 != nil {
                            return false
                        } else {
                            return m1.title < m2.title
                        }
                    }
                }
            } else {
                sortedMovies = movies.sorted { $0.title < $1.title }
            }
        }
        
        return sortedMovies
    }
    
    /// Paginated version of filtered movies - only shows first N items
    private var paginatedMovies: [Movie] {
        Array(filteredMovies.prefix(displayedMovieCount))
    }

    private static func buildSearchIndex(from movies: [Movie]) -> [String: String] {
        var index: [String: String] = [:]
        index.reserveCapacity(movies.count)

        for movie in movies {
            var fields: [String] = [movie.title]
            if let year = movie.year { fields.append(String(year)) }
            if let mpaaRating = movie.mpaaRating { fields.append(mpaaRating) }
            fields.append(contentsOf: movie.genres)
            fields.append(contentsOf: movie.streamingServices.map(\.name))

            if let credits = movie.credits {
                if let director = credits.director { fields.append(director) }
                fields.append(contentsOf: credits.cast.map(\.name))
            }

            if let episode = movie.podcastEpisode {
                fields.append(episode.title)
            }

            if let discussion = movie.rewatchablesDiscussion {
                fields.append(contentsOf: [
                    discussion.apexMountain,
                    discussion.dionWaiters,
                    discussion.agedBest,
                    discussion.agedWorst,
                    discussion.joeyPants,
                    discussion.thatGuy,
                    discussion.castingWhatIf
                ].compactMap { $0 })
            }

            index[movie.id] = fields.joined(separator: " ").lowercased()
        }

        return index
    }

    private func rebuildMovieSearchIndex() {
        let snapshot = localDB.movies
        guard !snapshot.isEmpty else { return }
        if searchIndexBuildTask != nil { return }
        if movieSearchIndex.count == snapshot.count { return }
        let buildRequestedAt = ProcessInfo.processInfo.systemUptime
        let shouldLogPerf = isPerfLoggingEnabled
        searchIndexBuildTask?.cancel()
        searchIndexBuildTask = nil
        searchIndexBuildTask = Task.detached(priority: .utility) {
            let buildStart = ProcessInfo.processInfo.systemUptime
            let builtIndex = Self.buildSearchIndex(from: snapshot)
            if Task.isCancelled { return }
            await MainActor.run {
                movieSearchIndex = builtIndex
                searchIndexBuildTask = nil
                guard shouldLogPerf else { return }
                let buildMs = (ProcessInfo.processInfo.systemUptime - buildStart) * 1000
                let totalMs = (ProcessInfo.processInfo.systemUptime - buildRequestedAt) * 1000
                print("⏱️ [PERF] [MovieListView] rebuildMovieSearchIndex build: \(String(format: "%.1f", buildMs))ms (movies=\(snapshot.count))")
                print("⏱️ [PERF] [MovieListView] rebuildMovieSearchIndex total: \(String(format: "%.1f", totalMs))ms")
            }
        }
    }

    private func rebuildGenreCache() {
        let genres = localDB.movies
            .flatMap(\.genres)
            .filter {
                $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare("TV Movie") != .orderedSame
            }
        cachedAllGenres = Array(Set(genres)).sorted()
    }

    private static func computeFilteredMoviesFastPath(
        movies: [Movie],
        searchText: String,
        previousSearchQuery: String,
        previousSearchResultIds: Set<String>,
        canNarrowWithinPreviousSearchResults: Bool,
        watchFilter: WatchFilter,
        selectedGenre: String?,
        selectedMPAARating: String?,
        selectedListIdentifier: String?,
        selectedStreamingService: String?,
        sortOption: SortOption,
        preferredStreamingServices: [String],
        sourceCache: [String: Set<String>],
        movieSearchIndex: [String: String],
        myServicesFilterLabel: String
    ) -> [Movie] {
        var filtered = movies

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let normalizedSearch = trimmedSearch.lowercased()
            let normalizedTerms = normalizedSearch
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            let normalizedPrevious = previousSearchQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            var candidates = filtered
            if canNarrowWithinPreviousSearchResults,
               !normalizedPrevious.isEmpty,
               normalizedSearch.hasPrefix(normalizedPrevious),
               !previousSearchResultIds.isEmpty {
                candidates = candidates.filter { previousSearchResultIds.contains($0.id) }
            }

            filtered = candidates.filter { movie in
                if let indexedContent = movieSearchIndex[movie.id] {
                    if normalizedTerms.isEmpty {
                        return indexedContent.contains(normalizedSearch)
                    }
                    for term in normalizedTerms where !indexedContent.contains(term) {
                        return false
                    }
                    return true
                }
                // If index is still warming, keep matching useful fields.
                if movie.title.lowercased().contains(normalizedSearch) {
                    return true
                }
                if let year = movie.year, String(year).contains(trimmedSearch) {
                    return true
                }
                return false
            }
        }

        switch watchFilter {
        case .all:
            break
        case .completed:
            filtered = filtered.filter { $0.isRewatched && $0.isListened }
        case .incomplete:
            filtered = filtered.filter { $0.isRewatched != $0.isListened }
        case .rewatched:
            filtered = filtered.filter { $0.isRewatched }
        case .listened:
            filtered = filtered.filter { $0.isListened }
        case .saved:
            filtered = filtered.filter { $0.isSaved }
        }

        if let selectedGenre = selectedGenre {
            filtered = filtered.filter { $0.genres.contains(selectedGenre) }
        }

        if let selectedMPAARating = selectedMPAARating {
            filtered = filtered.filter { $0.mpaaRating == selectedMPAARating }
        }

        if let selectedListIdentifier = selectedListIdentifier {
            let movieIdsInList = Set(sourceCache.compactMap { (movieId, sourceIds) in
                sourceIds.contains(selectedListIdentifier) ? movieId : nil
            })
            filtered = filtered.filter { movie in
                movieIdsInList.contains(movie.id)
            }
        }

        if let selectedStreamingService = selectedStreamingService {
            if selectedStreamingService == myServicesFilterLabel {
                let preferredKeys = Set(preferredStreamingServices.map { StreamingServiceAssets.normalizedName($0).lowercased() })
                filtered = filtered.filter { movie in
                    movie.streamingServices.contains { service in
                        preferredKeys.contains(StreamingServiceAssets.normalizedName(service.name).lowercased())
                    }
                }
            } else {
                let normalizedSelectedService = StreamingServiceAssets.normalizedName(selectedStreamingService).lowercased()
                filtered = filtered.filter { movie in
                    movie.streamingServices.contains { service in
                        StreamingServiceAssets.normalizedName(service.name).lowercased() == normalizedSelectedService
                    }
                }
            }
        }

        switch sortOption {
        case .title:
            filtered = filtered.sorted { $0.title < $1.title }
        case .releaseDateAsc:
            filtered = filtered.sorted { m1, m2 in
                let y1 = m1.year ?? 0
                let y2 = m2.year ?? 0
                if y1 != y2 { return y1 < y2 }
                return m1.title < m2.title
            }
        case .releaseDateDesc:
            filtered = filtered.sorted { m1, m2 in
                let y1 = m1.year ?? 0
                let y2 = m2.year ?? 0
                if y1 != y2 { return y1 > y2 }
                return m1.title < m2.title
            }
        case .episodeDateAsc:
            filtered = filtered.sorted { m1, m2 in
                let d1 = m1.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = m2.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 < d2 }
                return m1.title < m2.title
            }
        case .episodeDateDesc:
            filtered = filtered.sorted { m1, m2 in
                let d1 = m1.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = m2.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 > d2 }
                return m1.title < m2.title
            }
        case .ranking:
            // Ranking sort depends on rank cache built on the main actor.
            filtered = filtered.sorted { $0.title < $1.title }
        }

        return filtered
    }

    private func scheduleFilterRecompute(debounceSearch: Bool = false, source: String = "unspecified") {
        let latestTrimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let recomputeRequestedAt = ProcessInfo.processInfo.systemUptime
        let shouldLogPerf = isPerfLoggingEnabled
        let shouldIncludeSearchIndex = !latestTrimmedSearch.isEmpty

        if latestTrimmedSearch.isEmpty,
           activePersonSearchQuery == nil,
           watchFilter == .all,
           selectedGenre == nil,
           selectedMPAARating == nil,
           selectedList == nil,
           selectedStreamingService == nil,
           selectedInspiration == nil,
           sortOption == .episodeDateDesc {
            searchRecomputeTask?.cancel()
            isSearchFiltering = false
            effectiveSearchText = ""
            cachedFilteredMovies = localDB.movies
            lastFilterHash = computeFilterHash()
            if shouldLogPerf {
                logFilterInteraction(source, start: recomputeRequestedAt)
            }
            return
        }
        searchRecomputeTask?.cancel()

        if !debounceSearch {
            isSearchFiltering = false
            effectiveSearchText = latestTrimmedSearch
        }

        searchRecomputeTask = Task {
            if debounceSearch {
                await MainActor.run {
                    isSearchFiltering = true
                }

                do {
                    try await Task.sleep(nanoseconds: 30_000_000)
                } catch {
                    await MainActor.run { isSearchFiltering = false }
                    return
                }

                if Task.isCancelled {
                    await MainActor.run { isSearchFiltering = false }
                    return
                }

                await MainActor.run {
                    effectiveSearchText = latestTrimmedSearch
                }
            }

            if Task.isCancelled { return }

            let snapshotStart = ProcessInfo.processInfo.systemUptime
            let snapshot = await MainActor.run {
                (
                    currentHash: computeFilterHash(),
                    lastHash: lastFilterHash,
                    cachedIsEmpty: cachedFilteredMovies.isEmpty,
                    effectiveSearchText: effectiveSearchText,
                    movies: localDB.movies,
                    watchFilter: watchFilter,
                    selectedGenre: selectedGenre,
                    selectedMPAARating: selectedMPAARating,
                    selectedListIdentifier: selectedList?.identifier,
                    selectedStreamingService: selectedStreamingService,
                    sortOption: sortOption,
                    selectedInspiration: selectedInspiration,
                    activePersonSearchQuery: activePersonSearchQuery,
                    preferredStreamingServices: preferredStreamingServices,
                    filterVersion: filterVersion,
                    previousSearchQuery: previousSearchQuery,
                    previousSearchResultIds: previousSearchResultIds,
                    previousSearchFilterVersion: previousSearchFilterVersion,
                    sourceCache: selectedList == nil
                        ? [:]
                        : (hasBuiltSourceCache ? movieToSourcesCache : buildMovieSourceCacheSnapshot()),
                    movieSearchIndex: shouldIncludeSearchIndex ? movieSearchIndex : [:]
                )
            }
            if shouldLogPerf {
                let snapshotMs = (ProcessInfo.processInfo.systemUptime - snapshotStart) * 1000
                if snapshotMs >= 8 {
                    print("⏱️ [PERF] [MovieListView] snapshot filter state: \(String(format: "%.1f", snapshotMs))ms")
                }
            }

            if !snapshot.cachedIsEmpty && snapshot.currentHash == snapshot.lastHash {
                await MainActor.run {
                    isSearchFiltering = false
                }
                if shouldLogPerf {
                    let totalMs = (ProcessInfo.processInfo.systemUptime - recomputeRequestedAt) * 1000
                    if totalMs >= 12 {
                        print("⏱️ [PERF] [MovieListView] recompute skipped (cache hit, query=\"\(latestTrimmedSearch)\"): \(String(format: "%.1f", totalMs))ms")
                    }
                    logFilterInteraction(source, start: recomputeRequestedAt)
                }
                return
            }

            let canUseFastPath =
                snapshot.selectedInspiration == nil &&
                snapshot.activePersonSearchQuery == nil &&
                snapshot.sortOption != .ranking

            if canUseFastPath {
                let computeStart = ProcessInfo.processInfo.systemUptime
                let computed = await Task.detached(priority: .userInitiated) {
                    Self.computeFilteredMoviesFastPath(
                        movies: snapshot.movies,
                        searchText: snapshot.effectiveSearchText,
                        previousSearchQuery: snapshot.previousSearchQuery,
                        previousSearchResultIds: snapshot.previousSearchResultIds,
                        canNarrowWithinPreviousSearchResults: snapshot.filterVersion == snapshot.previousSearchFilterVersion,
                        watchFilter: snapshot.watchFilter,
                        selectedGenre: snapshot.selectedGenre,
                        selectedMPAARating: snapshot.selectedMPAARating,
                        selectedListIdentifier: snapshot.selectedListIdentifier,
                        selectedStreamingService: snapshot.selectedStreamingService,
                        sortOption: snapshot.sortOption,
                        preferredStreamingServices: snapshot.preferredStreamingServices,
                        sourceCache: snapshot.sourceCache,
                        movieSearchIndex: snapshot.movieSearchIndex,
                        myServicesFilterLabel: myServicesFilterLabel
                    )
                }.value
                if shouldLogPerf {
                    let computeMs = (ProcessInfo.processInfo.systemUptime - computeStart) * 1000
                    if computeMs >= 12 {
                        print("⏱️ [PERF] [MovieListView] fast-path compute (query=\"\(latestTrimmedSearch)\", movies=\(snapshot.movies.count)): \(String(format: "%.1f", computeMs))ms")
                    }
                }

                if Task.isCancelled { return }

                await MainActor.run {
                    // Drop stale results if state changed while background work was running.
                    guard computeFilterHash() == snapshot.currentHash else {
                        isSearchFiltering = false
                        return
                    }
                    cachedFilteredMovies = computed
                    lastFilterHash = snapshot.currentHash
                    let trimmedQuery = snapshot.effectiveSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedQuery.isEmpty {
                        previousSearchQuery = ""
                        previousSearchResultIds.removeAll()
                        previousSearchFilterVersion = snapshot.filterVersion
                    } else {
                        previousSearchQuery = trimmedQuery
                        previousSearchResultIds = Set(computed.map(\.id))
                        previousSearchFilterVersion = snapshot.filterVersion
                    }
                    isSearchFiltering = false
                }
                if shouldLogPerf {
                    let totalMs = (ProcessInfo.processInfo.systemUptime - recomputeRequestedAt) * 1000
                    if totalMs >= 16 {
                        print("⏱️ [PERF] [MovieListView] recompute total (fast-path, query=\"\(latestTrimmedSearch)\"): \(String(format: "%.1f", totalMs))ms")
                    }
                    logFilterInteraction(source, start: recomputeRequestedAt)
                }
            } else {
                let fallbackStart = ProcessInfo.processInfo.systemUptime
                await MainActor.run {
                    let currentHash = computeFilterHash()
                    if currentHash != lastFilterHash || cachedFilteredMovies.isEmpty {
                        cachedFilteredMovies = computeFilteredMovies(searchText: effectiveSearchText)
                        lastFilterHash = currentHash
                        let trimmedQuery = effectiveSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedQuery.isEmpty {
                            previousSearchQuery = ""
                            previousSearchResultIds.removeAll()
                            previousSearchFilterVersion = filterVersion
                        } else {
                            previousSearchQuery = trimmedQuery
                            previousSearchResultIds = Set(cachedFilteredMovies.map(\.id))
                            previousSearchFilterVersion = filterVersion
                        }
                    }
                    isSearchFiltering = false
                }
                if shouldLogPerf {
                    let fallbackMs = (ProcessInfo.processInfo.systemUptime - fallbackStart) * 1000
                    let totalMs = (ProcessInfo.processInfo.systemUptime - recomputeRequestedAt) * 1000
                    if fallbackMs >= 12 || totalMs >= 16 {
                        print("⏱️ [PERF] [MovieListView] recompute total (fallback, query=\"\(latestTrimmedSearch)\"): \(String(format: "%.1f", totalMs))ms [fallback=\(String(format: "%.1f", fallbackMs))ms]")
                    }
                    logFilterInteraction(source, start: recomputeRequestedAt)
                }
            }
        }
    }
    
    private var recentlySavedMovies: [Movie] {
        let movies = localDB.movies
            .filter { $0.isSaved }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        let visibleMovies = inspirationVisibleMovies(from: movies)
        return Array(visibleMovies.prefix(inspirationLimit))
    }

    private var latestPodcastMovies: [Movie] {
        let entries = latestPodcastEntries()
            .sorted { $0.date > $1.date }
            .map { $0.movie }
        let visibleMovies = inspirationVisibleMovies(from: entries)
        return Array(visibleMovies.prefix(latestPodcastLimit))
    }

    private var toCompleteMovies: [Movie] {
        let movies = localDB.movies.filter { movie in
            isPodcastToCompleteMovie(movie)
        }
        let visibleMovies = inspirationVisibleMovies(from: movies)
        return Array(visibleMovies.prefix(inspirationLimit))
    }
    
    private var longestSavedMovies: [Movie] {
        let movies = localDB.movies
            .filter { $0.isSaved }
            .sorted { $0.lastUpdated < $1.lastUpdated }
            .filter { !($0.isRewatched && $0.isListened) }
        let visibleMovies = inspirationVisibleMovies(from: movies)
        return Array(visibleMovies.prefix(inspirationLimit))
    }

    private var savedMovieCount: Int {
        localDB.movies.filter { $0.isSaved }.count
    }

    private var selectedInspirationMovies: [Movie] {
        guard let selectedInspiration else { return [] }
        switch selectedInspiration {
        case .recentlySaved:
            return recentlySavedMovies
        case .latestPodcasts:
            return latestPodcastMovies
        case .toComplete:
            return toCompleteMovies
        case .longestSaved:
            return longestSavedMovies
        }
    }

    private struct SourceCollectionUnit: Identifiable {
        let source: DataSource
        let movies: [Movie]

        var id: String { source.identifier }
    }

    private var sourceCollectionUnits: [SourceCollectionUnit] {
        guard !preferredDataSources.isEmpty,
              !preferredListIdentifierSet.isEmpty else { return [] }

        let sourceCache = hasBuiltSourceCache ? movieToSourcesCache : buildMovieSourceCacheSnapshot()
        let visibleMovies = uniqueMoviesPreservingOrder(
            filterMoviesByEnabledSources(
                movies: localDB.movies,
                enabledSourceIds: preferredListIdentifierSet
            )
        )

        let podcastDateBySource: [String: [String: Date]] = {
            var map: [String: [String: Date]] = [:]
            for entry in latestPodcastEntries() {
                let sourceId = entry.sourceIdentifier
                let movieId = entry.movie.id
                if let existingDate = map[sourceId]?[movieId] {
                    if entry.date > existingDate {
                        map[sourceId]?[movieId] = entry.date
                    }
                } else {
                    map[sourceId, default: [:]][movieId] = entry.date
                }
            }
            return map
        }()

        let podcasts = preferredDataSources.filter { $0.isEnabled && $0.type == "podcast" }
        let lists = preferredDataSources.filter { $0.isEnabled && $0.type != "podcast" }
        let orderedSources = podcasts + lists

        return orderedSources.compactMap { source in
            let sourceMovies = visibleMovies.filter { movie in
                sourceCache[movie.id]?.contains(source.identifier) == true
            }
            guard !sourceMovies.isEmpty else { return nil }
            let orderedMovies = prioritizeSourceMovies(
                sourceMovies,
                for: source,
                podcastDateMap: podcastDateBySource[source.identifier] ?? [:]
            )
            guard !orderedMovies.isEmpty else { return nil }
            return SourceCollectionUnit(source: source, movies: Array(orderedMovies.prefix(inspirationLimit)))
        }
    }

    private func prioritizeSourceMovies(_ movies: [Movie], for source: DataSource, podcastDateMap: [String: Date]) -> [Movie] {
        let baseSorted = defaultSortedMoviesForSourceUnit(movies, source: source, podcastDateMap: podcastDateMap)
        let saved = baseSorted.filter { $0.isSaved }
        let needsCompletion = baseSorted.filter { !$0.isSaved && $0.isRewatched != $0.isListened }
        let remaining = baseSorted.filter { !$0.isSaved && $0.isRewatched == $0.isListened }
        return uniqueMoviesPreservingOrder(saved + needsCompletion + remaining)
    }

    private func defaultSortedMoviesForSourceUnit(_ movies: [Movie], source: DataSource, podcastDateMap: [String: Date]) -> [Movie] {
        if source.isRankedList {
            buildRankCache(for: source)
            let ranks = rankCacheStore.rankCache[source.identifier] ?? [:]
            return movies.sorted { lhs, rhs in
                let leftRank = ranks[lhs.id]
                let rightRank = ranks[rhs.id]

                if let leftRank, let rightRank {
                    return leftRank < rightRank
                } else if leftRank != nil {
                    return true
                } else if rightRank != nil {
                    return false
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }

        if source.type == "podcast" {
            return movies.sorted { lhs, rhs in
                let leftDate = podcastDateMap[lhs.id] ?? Date.distantPast
                let rightDate = podcastDateMap[rhs.id] ?? Date.distantPast
                if leftDate != rightDate {
                    return leftDate > rightDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }

        return movies.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func applyInspirationFilter(to movies: [Movie]) -> [Movie] {
        guard let selectedInspiration else { return movies }
        let orderedIds: [String]
        switch selectedInspiration {
        case .recentlySaved:
            orderedIds = uniqueIdsPreservingOrder(recentlySavedMovies.map { $0.id })
        case .latestPodcasts:
            orderedIds = uniqueIdsPreservingOrder(
                latestPodcastEntries()
                    .sorted { $0.date > $1.date }
                    .map { $0.movie.id }
            )
        case .toComplete:
            orderedIds = uniqueIdsPreservingOrder(
                localDB.movies
                    .filter { isPodcastToCompleteMovie($0) }
                    .map { $0.id }
            )
        case .longestSaved:
            orderedIds = uniqueIdsPreservingOrder(longestSavedMovies.map { $0.id })
        }

        let orderMap = Dictionary(uniqueKeysWithValues: orderedIds.enumerated().map { ($1, $0) })
        let filtered = movies.filter { orderMap[$0.id] != nil }
        return filtered.sorted { (orderMap[$0.id] ?? Int.max) < (orderMap[$1.id] ?? Int.max) }
    }

    private func uniqueIdsPreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func isPodcastToCompleteMovie(_ movie: Movie) -> Bool {
        movie.podcastEpisode != nil
            && (movie.isListened || movie.isRewatched)
            && movie.isListened != movie.isRewatched
    }

    private var enabledPodcastSourceIds: Set<String> {
        guard !preferredListIdentifierSet.isEmpty else { return [] }
        let enabledPodcasts = allDataSources.filter { source in
            source.type == "podcast"
                && source.isEnabled
                && preferredListIdentifierSet.contains(source.identifier)
        }
        return Set(enabledPodcasts.map { $0.identifier })
    }

    private func latestPodcastEntries() -> [(movie: Movie, date: Date, sourceIdentifier: String)] {
        let enabledIds = enabledPodcastSourceIds
        guard !enabledIds.isEmpty else { return [] }
        var entries: [(movie: Movie, date: Date, sourceIdentifier: String)] = []

        let descriptor = FetchDescriptor<MovieData>()
        let movieDataList = (try? modelContext.fetch(descriptor)) ?? []

        for movieData in movieDataList {
            guard movieData.modelContext != nil,
                  let movie = movieData.toMovieIfValid() else { continue }

            for content in movieData.sourceContents ?? [] {
                guard let source = content.source,
                      enabledIds.contains(source.identifier) else {
                    continue
                }
                let date = content.podcastEpisode?.publishDate ?? content.sourceDate
                if let date {
                    entries.append((movie: movie, date: date, sourceIdentifier: source.identifier))
                }
            }

            for dataSource in movieData.dataSources ?? [] {
                guard let source = dataSource.dataSource,
                      enabledIds.contains(source.identifier),
                      let date = dataSource.podcastEpisode?.publishDate else {
                        continue
                }
                entries.append((movie: movie, date: date, sourceIdentifier: source.identifier))
            }
        }

        return entries
    }

    private func toggleInspirationSelection(_ section: InspirationSection) {
        withAnimation(DesignSystem.Animation.springStandard) {
            if selectedInspiration == section {
                selectedInspiration = nil
            } else {
                selectedInspiration = section
            }
        }
    }
    
    private func inspirationVisibleMovies(from movies: [Movie]) -> [Movie] {
        guard !preferredListIdentifierSet.isEmpty else { return [] }
        let visibleMovies = filterMoviesByEnabledSources(movies: movies, enabledSourceIds: preferredListIdentifierSet)
        return uniqueMoviesPreservingOrder(visibleMovies)
    }
    
    private func uniqueMoviesPreservingOrder(_ movies: [Movie]) -> [Movie] {
        var seen = Set<String>()
        return movies.filter { seen.insert($0.id).inserted }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var movieListContent: some View {
        ZStack {
            // Show loading if actively loading OR if we haven't attempted load yet AND movies are empty
            if (localDB.isLoading && localDB.movies.isEmpty) || (!localDB.hasAttemptedInitialLoad && localDB.movies.isEmpty) {
                loadingView
            } else if filteredMovies.isEmpty {
                let hasSearchText = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !hasSearchText && !hasActiveFilters && selectedInspiration == nil {
                    loadingView
                } else {
                    emptyStateView
                }
            } else {
                movieListView
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        switch loadingScreenStyle {
        case .minimal:
            HStack(spacing: DesignSystem.Spacing.sm) {
                ProgressView()
                    .tint(DesignSystem.Color.textSecondary)
                Text("Loading movies…")
                    .headlineSmall()
                    .foregroundColor(DesignSystem.Color.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.md + DesignSystem.Spacing.xs + DesignSystem.Spacing.sm)
        case .skeletonCollections:
            skeletonCollectionsLoadingView
        case .posterWall:
            posterWallLoadingView
        case .spotlight:
            spotlightLoadingView
        }
    }
    
    private var skeletonCollectionsLoadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        loadingPill(width: 120, height: 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(0..<5, id: \.self) { _ in
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        loadingBlock(width: 100, height: 150, cornerRadius: DesignSystem.CornerRadius.md)
                                        loadingPill(width: 86, height: 10)
                                        loadingPill(width: 62, height: 8)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                        }
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(DesignSystem.Color.background)
    }
    
    private var posterWallLoadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                loadingPill(width: 170, height: 14)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.md), count: 3), spacing: DesignSystem.Spacing.md) {
                    ForEach(0..<18, id: \.self) { _ in
                        loadingBlock(width: nil, height: 156, cornerRadius: DesignSystem.CornerRadius.md, shimmer: true)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(DesignSystem.Color.background)
    }
    
    private var spotlightLoadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                ZStack(alignment: .bottomLeading) {
                    loadingBlock(width: nil, height: 210, cornerRadius: DesignSystem.CornerRadius.lg, shimmer: true)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        loadingPill(width: 180, height: 12)
                        loadingPill(width: 120, height: 9)
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                
                loadingPill(width: 140, height: 12)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        loadingBlock(width: 64, height: 96, cornerRadius: DesignSystem.CornerRadius.sm)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            loadingPill(width: 180, height: 10)
                            loadingPill(width: 140, height: 8)
                            loadingPill(width: 100, height: 8)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                }
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(DesignSystem.Color.background)
    }
    
    @ViewBuilder
    private func loadingBlock(width: CGFloat?, height: CGFloat, cornerRadius: CGFloat, shimmer: Bool = false) -> some View {
        let block = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DesignSystem.Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Color.borderLight.opacity(0.5), lineWidth: 0.5)
            )
            .modifier(LoadingPulseModifier())
        
        if let width {
            if shimmer {
                block
                    .modifier(LoadingShimmerModifier())
                    .frame(width: width, height: height)
            } else {
                block
                    .frame(width: width, height: height)
            }
        } else if shimmer {
            block
                .modifier(LoadingShimmerModifier())
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        } else {
            block
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
    }
    
    private func loadingPill(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(DesignSystem.Color.cardBackground)
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Color.borderLight.opacity(0.5), lineWidth: 0.5)
            )
            .modifier(LoadingPulseModifier())
            .frame(width: width, height: height)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if localDB.movies.isEmpty {
            EmptyStateView(
                title: "No Movies Yet",
                description: "Your catalog will appear once the bundled database loads."
            )
        } else {
            VStack(spacing: DesignSystem.Spacing.sm) {
                if hasActiveFilters || selectedInspiration != nil {
                    filterHeaderRow(excludingInspiration: false)
                }
                
                EmptyStateView(
                    title: "No Results",
                    description: searchText.isEmpty ? nil : "No results for \"\(searchText)\""
                )
                .padding(.top, DesignSystem.Spacing.xxl)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }
    
    private var movieListView: some View {
        Group {
            if localDB.movies.count > 1000 {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        scrollOffsetTrackingMarker

                        if hasActiveFilters || selectedInspiration != nil {
                            if selectedInspiration == nil {
                                filterHeaderRow(excludingInspiration: false)
                            }
                        }

                        if shouldShowInspirationSections {
                            if let selectedInspiration {
                                inspirationSectionRow(section: selectedInspiration, movies: selectedInspirationMovies, isCollapsed: true)
                            } else {
                                inspirationSectionRow(section: .latestPodcasts, movies: latestPodcastMovies, isCollapsed: false)
                                inspirationSectionRow(section: .recentlySaved, movies: recentlySavedMovies, isCollapsed: false)
                                inspirationSectionRow(section: .toComplete, movies: toCompleteMovies, isCollapsed: false)
                                if savedMovieCount >= 20 {
                                    inspirationSectionRow(section: .longestSaved, movies: longestSavedMovies, isCollapsed: false)
                                }
                                ForEach(sourceCollectionUnits) { unit in
                                    sourceCollectionRow(source: unit.source, movies: unit.movies)
                                }
                            }

                            if selectedInspiration == nil && !collectionsOnlyMode {
                                Text("All movies")
                                    .headlineSmall()
                                    .foregroundColor(DesignSystem.Color.textPrimary)
                                    .padding(.horizontal, inspirationLeadingPadding)
                                    .padding(.top, DesignSystem.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !collectionsOnlyMode {
                            ForEach(Array(paginatedMovies.enumerated()), id: \.element.id) { index, movie in
                                movieRow(movie: movie, index: index)
                                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                                    .onAppear {
                                        if index >= paginatedMovies.count - 10 &&
                                           displayedMovieCount < filteredMovies.count &&
                                           !isLoadingMore {
                                            loadMoreMovies()
                                        }
                                    }
                            }

                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .background(DesignSystem.Color.background)
                #if os(iOS)
                .refreshable {
                    await handleMainPagePullToRefresh()
                }
                #endif
            } else {
                List {
                    scrollOffsetTrackingListRow

                    if hasActiveFilters || selectedInspiration != nil {
                        if selectedInspiration == nil {
                            filterHeaderRow(excludingInspiration: false)
                        }
                    }

                    if shouldShowInspirationSections {
                        if let selectedInspiration {
                            inspirationSectionRow(section: selectedInspiration, movies: selectedInspirationMovies, isCollapsed: true)
                        } else {
                            inspirationSectionRow(section: .latestPodcasts, movies: latestPodcastMovies, isCollapsed: false)
                            inspirationSectionRow(section: .recentlySaved, movies: recentlySavedMovies, isCollapsed: false)
                            inspirationSectionRow(section: .toComplete, movies: toCompleteMovies, isCollapsed: false)
                            if savedMovieCount >= 20 {
                                inspirationSectionRow(section: .longestSaved, movies: longestSavedMovies, isCollapsed: false)
                            }
                            ForEach(sourceCollectionUnits) { unit in
                                sourceCollectionRow(source: unit.source, movies: unit.movies)
                            }
                        }
                        
                        if selectedInspiration == nil && !collectionsOnlyMode {
                            Text("All movies")
                                .headlineSmall()
                                .foregroundColor(DesignSystem.Color.textPrimary)
                                .padding(.horizontal, inspirationLeadingPadding)
                                .padding(.top, DesignSystem.Spacing.sm)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(DesignSystem.Color.background)
                                #if os(iOS)
                                .listRowSeparator(.hidden)
                                #endif
                        }
                    }
                    
                    if !collectionsOnlyMode {
                        ForEach(Array(paginatedMovies.enumerated()), id: \.element.id) { index, movie in
                            movieRow(movie: movie, index: index)
                                .listRowBackground(DesignSystem.Color.background)
                                .onAppear {
                                    // When user scrolls near the end, load more
                                    if index >= paginatedMovies.count - 10 &&
                                       displayedMovieCount < filteredMovies.count &&
                                       !isLoadingMore {
                                        loadMoreMovies()
                                    }
                                }
                        }
                        
                        // Show loading indicator at bottom if loading more
                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .listRowBackground(DesignSystem.Color.background)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(DesignSystem.Color.background)
                .listStyle(.plain)
                #if os(iOS)
                .listRowSpacing(DesignSystem.Spacing.sm)
                .refreshable {
                    await handleMainPagePullToRefresh()
                }
                #endif
            }
        }
        .transaction { transaction in
            if isSearchFiltering {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private var scrollOffsetTrackingMarker: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: ScrollOffsetPreferenceKey.self,
                value: geometry.frame(in: .named("scrollArea")).minY
            )
        }
        .frame(height: 0)
    }

    @ViewBuilder
    private var scrollOffsetTrackingListRow: some View {
        scrollOffsetTrackingMarker
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            #if os(iOS)
            .listRowSeparator(.hidden)
            #endif
    }

    private func handleMainPagePullToRefresh() async {
        await localDB.forcePodcastEpisodeIntake(reason: "main-page-pull-to-refresh")
    }

    private func filterHeaderRow(excludingInspiration: Bool) -> some View {
        leadingScrollHeader(spacing: DesignSystem.Spacing.lg) {
            ForEach(activeFilterChips(excludingInspiration: excludingInspiration)) { chip in
                Button(action: chip.action) {
                    Text(chip.label)
                        .headlineSmall()
                        .foregroundColor(DesignSystem.Color.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: 0, bottom: DesignSystem.Spacing.xs, trailing: 0))
        .listRowBackground(DesignSystem.Color.background)
        #if os(iOS)
        .listRowSeparator(.hidden)
        #endif
    }

    private struct FilterChip: Identifiable {
        let id = UUID()
        let label: String
        let action: () -> Void
    }

    private func activeFilterChips(excludingInspiration: Bool) -> [FilterChip] {
        var chips: [FilterChip] = []

        if !excludingInspiration, let selectedInspiration {
            chips.append(FilterChip(label: selectedInspiration.title) {
                self.selectedInspiration = nil
            })
        }

        if let selectedList {
            chips.append(FilterChip(label: selectedList.name) {
                self.selectedList = nil
                sortOption = .episodeDateDesc
            })
        }

        if let selectedStreamingService {
            chips.append(FilterChip(label: selectedStreamingService) {
                self.selectedStreamingService = nil
            })
        }

        if let selectedGenre {
            chips.append(FilterChip(label: selectedGenre) {
                self.selectedGenre = nil
            })
        }

        if let selectedMPAARating {
            chips.append(FilterChip(label: selectedMPAARating) {
                self.selectedMPAARating = nil
            })
        }

        if watchFilter != .all {
            chips.append(FilterChip(label: watchFilter.rawValue) {
                watchFilter = .all
            })
        }

        return chips
    }
    
    @ViewBuilder
    private func inspirationSectionRow(section: InspirationSection, movies: [Movie], isCollapsed: Bool) -> some View {
        if movies.isEmpty && !isCollapsed {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                leadingScrollHeader(spacing: DesignSystem.Spacing.lg) {
                    Button(action: {
                        if collectionsOnlyMode {
                            presentScopedSearch(title: section.title, movies: movies)
                        } else {
                            toggleInspirationSelection(section)
                        }
                    }) {
                        Text(section.title)
                            .headlineSmall()
                            .foregroundColor(DesignSystem.Color.textPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)

                    if selectedInspiration == section {
                        ForEach(activeFilterChips(excludingInspiration: true)) { chip in
                            Button(action: chip.action) {
                                Text(chip.label)
                                    .headlineSmall()
                                    .foregroundColor(DesignSystem.Color.textPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if !isCollapsed {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: inspirationPosterSpacing) {
                            ForEach(movies, id: \.id) { movie in
                                Button {
                                    selectedMovie = movie
                                } label: {
                                    inspirationPoster(for: movie, section: section)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(movie.title)
                            }
                        }
                        .padding(.horizontal, inspirationLeadingPadding)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)
            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: 0, bottom: DesignSystem.Spacing.xs, trailing: 0))
            .listRowBackground(DesignSystem.Color.background)
            #if os(iOS)
            .listRowSeparator(.hidden)
            #endif
        }
    }

    private func leadingScrollHeader(spacing: CGFloat, @ViewBuilder content: @escaping () -> some View) -> some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    content()
                }
                .frame(minWidth: geometry.size.width, alignment: .leading)
                .padding(.horizontal, inspirationLeadingPadding)
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private func sourceCollectionRow(source: DataSource, movies: [Movie]) -> some View {
        if movies.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                leadingScrollHeader(spacing: DesignSystem.Spacing.lg) {
                    Button(action: {
                        if collectionsOnlyMode {
                            presentScopedSearch(title: source.name, movies: movies)
                        } else {
                            selectedList = source
                            if source.isRankedList {
                                sortOption = .ranking
                            }
                        }
                    }) {
                        Text(source.name)
                            .headlineSmall()
                            .foregroundColor(DesignSystem.Color.textPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(source.name)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: inspirationPosterSpacing) {
                        ForEach(movies, id: \.id) { movie in
                            Button {
                                selectedMovie = movie
                            } label: {
                                inspirationPoster(for: movie, section: .latestPodcasts)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(movie.title)
                        }
                    }
                    .padding(.horizontal, inspirationLeadingPadding)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)
            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: 0, bottom: DesignSystem.Spacing.xs, trailing: 0))
            .listRowBackground(DesignSystem.Color.background)
            #if os(iOS)
            .listRowSeparator(.hidden)
            #endif
        }
    }
    
    @ViewBuilder
    private func inspirationPoster(for movie: Movie, section: InspirationSection) -> some View {
        let badgeSourceIds = podcastSourceIdentifiers(for: movie)

        if let posterPath = movie.posterPath,
           let posterURL = MovieDataService.shared.getPosterURL(path: posterPath, size: posterSizePreference.optimalImageSize),
           let url = URL(string: posterURL) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(DesignSystem.Color.surface)
            }
            .frame(width: inspirationPosterWidth, height: inspirationPosterHeight)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
            .overlay(alignment: .bottomLeading) {
                if !badgeSourceIds.isEmpty {
                    podcastArtworkBadgeStack(for: badgeSourceIds)
                        .padding(.leading, podcastBadgeInset)
                        .padding(.bottom, podcastBadgeInset)
                }
            }
        } else {
            Rectangle()
                .fill(DesignSystem.Color.surface)
                .frame(width: inspirationPosterWidth, height: inspirationPosterHeight)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
                .overlay(
                    DesignSystemIcon(DesignSystem.Icon.movie, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textSecondary)
                )
                .overlay(alignment: .bottomLeading) {
                    if !badgeSourceIds.isEmpty {
                        podcastArtworkBadgeStack(for: badgeSourceIds)
                            .padding(.leading, podcastBadgeInset)
                            .padding(.bottom, podcastBadgeInset)
                    }
                }
        }
    }

    private func podcastSourceIdentifiers(for movie: Movie) -> [String] {
        let sourceCache = hasBuiltSourceCache ? movieToSourcesCache : buildMovieSourceCacheSnapshot()
        guard let sourceIds = sourceCache[movie.id], !sourceIds.isEmpty else { return [] }

        let podcastIds = sourceIds.filter { enabledPodcastSourceIds.contains($0) }
        guard !podcastIds.isEmpty else { return [] }

        let sourceNameById = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0.name) })
        let orderedPreferred = preferredListIdentifiers.filter { podcastIds.contains($0) }
        let preferredSet = Set(orderedPreferred)

        let remaining = podcastIds
            .filter { !preferredSet.contains($0) }
            .sorted { lhs, rhs in
                let lhsName = sourceNameById[lhs] ?? lhs
                let rhsName = sourceNameById[rhs] ?? rhs
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }

        return orderedPreferred + remaining
    }

    private func podcastArtworkBadgeStack(for sourceIdentifiers: [String]) -> some View {
        let uniqueIdentifiers = uniqueIdsPreservingOrder(sourceIdentifiers)
        let visibleIdentifiers = Array(uniqueIdentifiers.prefix(4))
        let overlapSpacing = podcastBadgePeekWidth - podcastBadgeSize

        return HStack(spacing: overlapSpacing) {
            ForEach(Array(visibleIdentifiers.enumerated()), id: \.element) { index, sourceIdentifier in
                podcastArtworkBadge(for: sourceIdentifier)
                    .zIndex(Double(visibleIdentifiers.count - index))
            }
        }
    }

    private func podcastArtworkBadge(for sourceIdentifier: String) -> some View {
        let trimmedId = sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artworkURL = podcastFeedArtworkURLs[trimmedId]

        return Group {
            if let artworkURL {
                PodcastArtworkBadgeImageView(url: artworkURL)
            } else {
                podcastArtworkGlassPlaceholder()
            }
        }
        .frame(width: podcastBadgeSize, height: podcastBadgeSize)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
    }

    private func podcastArtworkGlassPlaceholder() -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
            .fill(GlassControl.floatingMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .stroke(GlassControl.Border.card.color, lineWidth: GlassControl.Border.card.width)
            )
    }

    private func loadPodcastFeedArtworkIfNeeded() {
        hydratePodcastFeedArtworkCacheIfNeeded()

        let podcastSources = allDataSources.filter { source in
            source.type == "podcast"
                && !(source.url?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
        guard !podcastSources.isEmpty, !isLoadingPodcastFeedArtwork else { return }

        let shouldRefreshAll = shouldRefreshPodcastFeedArtworkCache()

        let missingSources = podcastSources.filter { source in
            let sourceId = source.identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !sourceId.isEmpty else { return false }
            if shouldRefreshAll {
                return true
            }
            return podcastFeedArtworkURLs[sourceId] == nil
        }
        guard !missingSources.isEmpty else {
            prefetchPodcastArtworkImagesIfNeeded()
            return
        }

        isLoadingPodcastFeedArtwork = true

        Task.detached {
            var resolvedURLs: [String: URL] = [:]

            await withTaskGroup(of: (String, URL?).self) { group in
                for source in missingSources {
                    let sourceId = source.identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let feedURLString = source.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !sourceId.isEmpty, !feedURLString.isEmpty else { continue }
                    group.addTask {
                        let artworkURL = await fetchPodcastArtworkURL(feedURLString: feedURLString)
                        return (sourceId, artworkURL)
                    }
                }

                for await (sourceId, artworkURL) in group {
                    if let artworkURL {
                        resolvedURLs[sourceId] = artworkURL
                    }
                }
            }

            let resolvedURLSnapshot = resolvedURLs
            await MainActor.run {
                podcastFeedArtworkURLs.merge(resolvedURLSnapshot) { _, new in new }
                persistPodcastFeedArtworkCache()
                prefetchPodcastArtworkImagesIfNeeded(for: Array(resolvedURLSnapshot.keys))
                isLoadingPodcastFeedArtwork = false
            }
        }
    }

    private func hydratePodcastFeedArtworkCacheIfNeeded() {
        guard !hasHydratedPodcastFeedArtworkCache else { return }
        hasHydratedPodcastFeedArtworkCache = true

        guard !podcastFeedArtworkCacheData.isEmpty,
              let snapshot = try? JSONDecoder().decode(PodcastFeedArtworkCacheSnapshot.self, from: podcastFeedArtworkCacheData) else {
            podcastFeedArtworkCacheSavedAt = nil
            return
        }

        var hydratedURLs: [String: URL] = [:]
        for (sourceId, urlString) in snapshot.urls {
            guard let url = URL(string: urlString) else { continue }
            hydratedURLs[sourceId] = url
        }

        podcastFeedArtworkURLs = hydratedURLs
        podcastFeedArtworkCacheSavedAt = snapshot.savedAt
        prefetchPodcastArtworkImagesIfNeeded()
    }

    private func shouldRefreshPodcastFeedArtworkCache() -> Bool {
        guard let savedAt = podcastFeedArtworkCacheSavedAt else { return true }
        return Date().timeIntervalSince(savedAt) > podcastFeedArtworkCacheMaxAge
    }

    private func persistPodcastFeedArtworkCache() {
        let serializedURLs = Dictionary(
            uniqueKeysWithValues: podcastFeedArtworkURLs.map { ($0.key, $0.value.absoluteString) }
        )
        let snapshot = PodcastFeedArtworkCacheSnapshot(
            savedAt: Date(),
            urls: serializedURLs
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        podcastFeedArtworkCacheSavedAt = snapshot.savedAt
        podcastFeedArtworkCacheData = data
    }

    private func prefetchPodcastArtworkImagesIfNeeded(for sourceIdentifiers: [String]? = nil) {
        let sourceIdFilter = sourceIdentifiers.map { Set($0.map { $0.lowercased() }) }
        let candidates = podcastFeedArtworkURLs
            .filter { sourceId, _ in
                guard !prefetchedPodcastArtworkSourceIds.contains(sourceId) else { return false }
                if let sourceIdFilter {
                    return sourceIdFilter.contains(sourceId)
                }
                return true
            }

        guard !candidates.isEmpty else { return }
        let sourceIdsToMark = Set(candidates.map(\.key))
        prefetchedPodcastArtworkSourceIds.formUnion(sourceIdsToMark)
        let urlsToPrefetch = Array(candidates.values)

        Task.detached {
            await withTaskGroup(of: Void.self) { group in
                for url in urlsToPrefetch {
                    group.addTask {
                        await ImageCache.shared.prefetchImage(from: url)
                    }
                }
            }
        }
    }

    private struct PodcastArtworkBadgeImageView: View {
        let url: URL
        @State private var imageOpacity: Double

        init(url: URL) {
            self.url = url
            let hasCachedImage = ImageCache.shared.getImage(for: url) != nil
            _imageOpacity = State(initialValue: hasCachedImage ? 1 : 0)
        }

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .fill(GlassControl.floatingMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                            .stroke(GlassControl.Border.card.color, lineWidth: GlassControl.Border.card.width)
                    )

                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .opacity(imageOpacity)
                        .onAppear {
                            guard imageOpacity < 1 else { return }
                            withAnimation(.easeOut(duration: 0.25)) {
                                imageOpacity = 1
                            }
                        }
                } placeholder: {
                    Color.clear
                }
            }
            .onChange(of: url.absoluteString) { _, _ in
                let hasCachedImage = ImageCache.shared.getImage(for: url) != nil
                imageOpacity = hasCachedImage ? 1 : 0
            }
        }
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
        return String(text[captureRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func fetchPodcastArtworkURL(feedURLString: String) async -> URL? {
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
            return artworkURL
        }

        if let urlString = firstCapture(in: xml, pattern: channelImagePattern),
           let artworkURL = URL(string: urlString) {
            return artworkURL
        }

        return nil
    }

    private func topPreferredStreamingService(for movie: Movie) -> String? {
        guard !preferredStreamingServices.isEmpty else { return nil }
        for preferredService in preferredStreamingServices {
            let preferredKey = StreamingServiceAssets.normalizedName(preferredService).lowercased()
            if let match = movie.streamingServices.first(where: { service in
                StreamingServiceAssets.normalizedName(service.name).lowercased() == preferredKey
            }) {
                return match.name
            }
        }
        return nil
    }

    private func sourcesAndListsText(for movie: Movie) -> String {
        let sourceCache = hasBuiltSourceCache ? movieToSourcesCache : buildMovieSourceCacheSnapshot()
        guard let sourceIds = sourceCache[movie.id], !sourceIds.isEmpty else {
            return ""
        }

        let sourceNameById = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0.name) })
        var orderedNames: [String] = []
        var seenNames = Set<String>()

        for preferredId in preferredListIdentifiers where sourceIds.contains(preferredId) {
            guard let sourceName = sourceNameById[preferredId] else { continue }
            if seenNames.insert(sourceName).inserted {
                orderedNames.append(sourceName)
            }
        }

        let remainingNames = sourceIds
            .compactMap { sourceNameById[$0] }
            .filter { seenNames.insert($0).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        orderedNames.append(contentsOf: remainingNames)
        return orderedNames.joined(separator: "  ")
    }
    
    private func movieRow(movie: Movie, index: Int) -> some View {
        let movieRank: Int? = {
            guard let selectedList, selectedList.isRankedList else { return nil }
            return getRankForMovie(movie, in: selectedList)
        }()

        return Button(action: {
            movieDetailOpenRequestedAt = ProcessInfo.processInfo.systemUptime
            movieDetailOpenRequestedMovieID = movie.id
            selectedMovie = movie
        }) {
            MovieRowView(
                movie: movie,
                selectedList: selectedList,
                rank: movieRank,
                topPreferredStreamingService: topPreferredStreamingService(for: movie),
                sourcesAndListsText: sourcesAndListsText(for: movie)
            )
                .id(movie.id)
                .contentShape(Rectangle())
                .onAppear {
                    let hasSearchQuery = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if !hasSearchQuery && !isSearchFiltering {
                        prefetchUpcomingImages(startingFrom: index, in: paginatedMovies)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(
            top: DesignSystem.Spacing.xs,
            leading: DesignSystem.Spacing.md + DesignSystem.Spacing.xs,
            bottom: DesignSystem.Spacing.xs,
            trailing: DesignSystem.Spacing.md + DesignSystem.Spacing.xs
        ))
        #if os(iOS)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            swipeActions(for: movie)
        }
        #endif
    }
    
    @ViewBuilder
    private func swipeActions(for movie: Movie) -> some View {
        let currentMovie = localDB.movies.first { $0.id == movie.id } ?? movie
        let hasPodcastEpisode = (currentMovie.podcastEpisode ?? movie.podcastEpisode) != nil
        // Full swipe toggles saved
        Button(action: {
            localDB.queueSavedStatusUpdate(currentMovie, isSaved: !currentMovie.isSaved)
        }) {
            DesignSystemIcon(
                (localDB.movies.first { $0.id == movie.id } ?? movie).isSaved ? DesignSystem.Icon.bookmarkCircleFill : DesignSystem.Icon.bookmarkCircle,
                size: DesignSystem.IconSize.md
            )
        }
        .tint(DesignSystem.Color.accent)
        
        // Rewatched button
        Button(action: {
            localDB.queueRewatchedStatusUpdate(currentMovie, isRewatched: !currentMovie.isRewatched)
        }) {
            DesignSystemIcon(DesignSystem.Icon.rewatchCircleFill, size: DesignSystem.IconSize.md)
        }
        .tint(DesignSystem.Color.accent)
        
        // Listened button
        Button(action: {
            localDB.queueListenedStatusUpdate(currentMovie, isListened: !currentMovie.isListened)
        }) {
            DesignSystemIcon(DesignSystem.Icon.listenCircleFill, size: DesignSystem.IconSize.md)
        }
        .tint(hasPodcastEpisode ? DesignSystem.Color.accent : DesignSystem.Color.textSecondary)
        .disabled(!hasPodcastEpisode)
    }
    
    // MARK: - Toolbar Components
    
    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        if localDB.isCatalogRefreshInProgress {
            ToolbarItem(placement: .topBarLeading) {
                catalogRefreshBanner
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                titleTypeMark
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            accountButton
        }
    }

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            listMenu
            if hasPreferredStreamingServices {
                streamingServiceMenu
            }
            genreMenu
            ratingMenu
            Spacer()
            if !showSearch {
                searchButton
            }
        }
    }

    #if os(iOS)
    private var customFloatingFilterGroup: some View {
        GlassCapsuleToolbar(spacing: 24, height: customToolbarControlHeight) {
            listMenu
            if hasPreferredStreamingServices {
                streamingServiceMenu
            }
            genreMenu
            ratingMenu
        }
        .shadow(color: searchFieldShadowColor, radius: searchFieldShadowRadius, x: 0, y: searchFieldShadowY)
    }

    private var customFloatingBottomToolbar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            customFloatingFilterGroup

            if mainToolbarLayoutStyle == .separated {
                Spacer(minLength: DesignSystem.Spacing.sm)
            }

            customFloatingSearchButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var customFloatingSearchButton: some View {
        Button(action: {
            presentGlobalSearch(focusSearchOnOpen: true)
        }) {
            GlassCircleButton(systemImage: DesignSystem.Icon.search, foregroundColor: toolbarSecondaryAccentColor, accessibilityLabel: "Search")
        }
        .shadow(color: searchFieldShadowColor, radius: searchFieldShadowRadius, x: 0, y: searchFieldShadowY)
    }
    #endif

    private var catalogRefreshBanner: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ProgressView()
                .tint(DesignSystem.Color.accent)
            Text("Refreshing catalog")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Color.textPrimary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(DesignSystem.Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Color.borderLight, lineWidth: 1)
        )
        .accessibilityLabel("Refreshing catalog")
    }

    private var titleTypeMark: some View {
        Image("TitleTypeMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(DesignSystem.Color.headline)
            .blur(radius: titleTypeBlurRadius)
            .frame(maxWidth: 220, maxHeight: 38, alignment: .leading)
            .accessibilityHidden(true)
    }
    
    private var accountButton: some View {
        Button(action: {
            showAccountSheet = true
        }) {
            Image(systemName: DesignSystem.Icon.account)
                .font(DesignSystem.Typography.glassIcon)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Account")
    }
    
    private var statusMenu: some View {
        Menu {
            ForEach(WatchFilter.allCases, id: \.self) { filter in
                Button {
                    watchFilter = filter
                } label: {
                    if filter == watchFilter {
                        Label(filter.rawValue, systemImage: "checkmark")
                    } else {
                        Text(filter.rawValue)
                    }
                }
            }
        } label: {
            DesignSystemIcon(DesignSystem.Icon.status, size: DesignSystem.IconSize.md, color: toolbarIconColor(isActive: watchFilter != .all))
        }
    }
    
    private var genreMenu: some View {
        Menu {
            genreMenuContent
        } label: {
            DesignSystemIcon(DesignSystem.Icon.genre, size: DesignSystem.IconSize.md, color: toolbarIconColor(isActive: selectedGenre != nil))
        }
    }
    
    @ViewBuilder
    private var genreMenuContent: some View {
        Button {
            applyGenreFilterFromToolbar(nil)
        } label: {
            if selectedGenre == nil {
                Label("All", systemImage: DesignSystem.Icon.checkmark)
            } else {
                Text("All")
            }
        }
        
        Divider()
        
        ForEach(allGenres, id: \.self) { genre in
            Button {
                applyGenreFilterFromToolbar(genre)
            } label: {
                if selectedGenre == genre {
                    Label(genre, systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text(genre)
                }
            }
        }
    }
    
    private var ratingMenu: some View {
        Menu {
            ratingMenuContent
        } label: {
            DesignSystemIcon(DesignSystem.Icon.rating, size: DesignSystem.IconSize.md, color: toolbarIconColor(isActive: selectedMPAARating != nil))
        }
    }
    
    @ViewBuilder
    private var ratingMenuButtons: some View {
        Button {
            applyRatingFilterFromToolbar("G")
        } label: {
            if selectedMPAARating == "G" {
                Label("G", systemImage: "checkmark")
            } else {
                Text("G")
            }
        }
        Button {
            applyRatingFilterFromToolbar("PG")
        } label: {
            if selectedMPAARating == "PG" {
                Label("PG", systemImage: "checkmark")
            } else {
                Text("PG")
            }
        }
        Button {
            applyRatingFilterFromToolbar("PG-13")
        } label: {
            if selectedMPAARating == "PG-13" {
                Label("PG-13", systemImage: "checkmark")
            } else {
                Text("PG-13")
            }
        }
        Button {
            applyRatingFilterFromToolbar("R")
        } label: {
            if selectedMPAARating == "R" {
                Label("R", systemImage: "checkmark")
            } else {
                Text("R")
            }
        }
        Button {
            applyRatingFilterFromToolbar("NC-17")
        } label: {
            if selectedMPAARating == "NC-17" {
                Label("NC-17", systemImage: "checkmark")
            } else {
                Text("NC-17")
            }
        }
    }
    
    @ViewBuilder
    private var ratingMenuContent: some View {
        Section("MPAA Rating") {
            Button {
                applyRatingFilterFromToolbar(nil)
            } label: {
                if selectedMPAARating == nil {
                    Label("All Ratings", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("All Ratings")
                }
            }
            ratingMenuButtons
        }
    }
    
    private var listMenu: some View {
        Menu {
            listMenuContent
        } label: {
            DesignSystemIcon(DesignSystem.Icon.listRectangle, size: DesignSystem.IconSize.md, color: toolbarIconColor(isActive: selectedList != nil))
        }
    }
    
    @ViewBuilder
    private var listMenuContent: some View {
        Button {
            applyListFilterFromToolbar(nil)
        } label: {
            if selectedList == nil {
                Label("All Lists", systemImage: "checkmark")
            } else {
                Text("All Lists")
            }
        }
        
        if !preferredDataSources.isEmpty {
            Divider()
            
            ForEach(preferredDataSources) { list in
                Button {
                    applyListFilterFromToolbar(list)
                } label: {
                    if selectedList?.identifier == list.identifier {
                        Label(list.name, systemImage: "checkmark")
                    } else {
                        Text(list.name)
                    }
                }
            }
        }
    }
    
    private var sortMenu: some View {
        Menu {
            sortMenuContent
        } label: {
            DesignSystemIcon(DesignSystem.Icon.sort, size: DesignSystem.IconSize.md, color: toolbarIconColor(isActive: sortOption != .episodeDateDesc))
        }
    }
    
    @ViewBuilder
    private var sortMenuContent: some View {
        ForEach(SortOption.availableOptions(for: selectedList), id: \.self) { option in
            Button {
                sortOption = option
            } label: {
                if sortOption == option {
                    Label(option.rawValue, systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text(option.rawValue)
                }
            }
        }
    }

    private var streamingServiceMenu: some View {
        Menu {
            streamingServiceMenuContent
        } label: {
            DesignSystemIcon(
                "play.square.stack.fill",
                size: DesignSystem.IconSize.md,
                color: toolbarIconColor(isActive: selectedStreamingService != nil)
            )
        }
    }
    
    @ViewBuilder
    private var streamingServiceMenuContent: some View {
        Button {
            applyStreamingServiceFilterFromToolbar(nil)
        } label: {
            if selectedStreamingService == nil {
                Label("All Services", systemImage: DesignSystem.Icon.checkmark)
            } else {
                Text("All Services")
            }
        }
        
        if hasPreferredStreamingServices {
            Divider()
            
            ForEach(preferredStreamingServices, id: \.self) { service in
                Button {
                    applyStreamingServiceFilterFromToolbar(service)
                } label: {
                    if selectedStreamingService == service {
                        Label(service, systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Text(service)
                    }
                }
            }
            
            Divider()
            
            Button {
                applyStreamingServiceFilterFromToolbar(myServicesFilterLabel)
            } label: {
                if selectedStreamingService == myServicesFilterLabel {
                    Label("My Services", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("My Services")
                }
            }
        }
    }
    
    private var searchButton: some View {
        Button(action: {
            presentGlobalSearch(focusSearchOnOpen: true)
        }) {
            GlassCircleButton(systemImage: DesignSystem.Icon.search, size: .compact, accessibilityLabel: "Search")
        }
    }

    private func presentGlobalSearch(
        initialFilters: MovieSearchFilters? = nil,
        initialQuery: String? = nil,
        focusSearchOnOpen: Bool = false
    ) {
        activeSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: initialQuery,
            initialFilters: initialFilters,
            focusSearchOnOpen: focusSearchOnOpen
        )
    }

    private func presentScopedSearch(title: String, movies: [Movie]) {
        let ids = Set(movies.map(\.id))
        guard !ids.isEmpty else { return }
        activeSearchContext = SearchPresentationContext(
            title: title,
            restrictedMovieIDs: ids,
            allowsListFilter: false,
            initialQuery: nil,
            initialFilters: nil,
            focusSearchOnOpen: false
        )
    }

    private func applyGenreFilterFromToolbar(_ genre: String?) {
        if collectionsOnlyMode {
            var filters = MovieSearchFilters()
            filters.selectedGenre = genre
            presentGlobalSearch(initialFilters: filters, focusSearchOnOpen: false)
            return
        }
        selectedGenre = genre
    }

    private func applyRatingFilterFromToolbar(_ rating: String?) {
        if collectionsOnlyMode {
            var filters = MovieSearchFilters()
            filters.selectedMPAARating = rating
            presentGlobalSearch(initialFilters: filters, focusSearchOnOpen: false)
            return
        }
        selectedMPAARating = rating
    }

    private func applyListFilterFromToolbar(_ list: DataSource?) {
        if collectionsOnlyMode {
            var filters = MovieSearchFilters()
            filters.selectedListIdentifier = list?.identifier
            if list?.isRankedList == true {
                filters.sortOption = .ranking
            }
            presentGlobalSearch(initialFilters: filters, focusSearchOnOpen: false)
            return
        }
        selectedList = list
        if list == nil {
            sortOption = .episodeDateDesc
        } else if list?.isRankedList == true {
            sortOption = .ranking
        }
    }

    private func applyStreamingServiceFilterFromToolbar(_ service: String?) {
        if collectionsOnlyMode {
            var filters = MovieSearchFilters()
            filters.selectedStreamingService = service
            presentGlobalSearch(initialFilters: filters, focusSearchOnOpen: false)
            return
        }
        selectedStreamingService = service
    }

    private func toolbarIconColor(isActive: Bool) -> SwiftUI.Color {
        if usesCustomFloatingToolbar {
            return isActive ? DesignSystem.Color.accent : toolbarSecondaryAccentColor
        }
        return isActive ? DesignSystem.Color.accent : DesignSystem.Color.textPrimary
    }

    private var toolbarSecondaryAccentColor: SwiftUI.Color {
        DesignSystem.Color.secondaryAccent ?? DesignSystem.Color.accent
    }

    private func startPersonSearchFromDetails(_ personName: String) {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if isPerfLoggingEnabled {
            print("⏱️ [PERF] [Detail] person tap from detail: \(trimmedName)")
        }
        pendingPersonSearchQuery = nil
        var filters = MovieSearchFilters()
        filters.selectedPersonName = trimmedName
        pendingDetailSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: nil,
            initialFilters: filters,
            focusSearchOnOpen: false
        )
        selectedMovie = nil
    }

    private func startGenreSearchFromDetails(_ genre: String) {
        let trimmedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGenre.isEmpty else { return }
        pendingPersonSearchQuery = nil
        var filters = MovieSearchFilters()
        filters.selectedGenre = trimmedGenre
        pendingDetailSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: nil,
            initialFilters: filters,
            focusSearchOnOpen: false
        )
        selectedMovie = nil
    }

    private func startRatingSearchFromDetails(_ rating: String) {
        let trimmedRating = rating.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRating.isEmpty else { return }
        pendingPersonSearchQuery = nil
        var filters = MovieSearchFilters()
        filters.selectedMPAARating = trimmedRating
        pendingDetailSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: nil,
            initialFilters: filters,
            focusSearchOnOpen: false
        )
        selectedMovie = nil
    }

    private func startYearSearchFromDetails(_ year: Int) {
        pendingPersonSearchQuery = nil
        var filters = MovieSearchFilters()
        filters.selectedReleaseYear = year
        pendingDetailSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: nil,
            initialFilters: filters,
            focusSearchOnOpen: false
        )
        selectedMovie = nil
    }

    private func applyPendingDetailSearchFromDetails() {
        guard let pendingContext = pendingDetailSearchContext else { return }
        pendingDetailSearchContext = nil
        pendingPersonSearchQuery = nil
        activeSearchContext = pendingContext
    }

    private func applyPendingPersonSearchFromDetails() {
        guard let pendingQuery = pendingPersonSearchQuery else { return }

        pendingPersonSearchQuery = nil
        
        // Use inline search instead of full-screen search
        skipNextSearchAutofocus = true
        activePersonSearchQuery = pendingQuery
        searchText = pendingQuery
        showSearch = true
        isSearchFieldFocused = false
    }
    
    private var searchBarView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            searchFiltersMenu
            searchFieldContainer
            
            Button(action: {
                withAnimation(DesignSystem.Animation.springStandard) {
                    showSearch = false
                }
            }) {
                closeButtonForAppearance
            }
            .padding(DesignSystem.Spacing.xs)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, searchBarBottomPadding)
    }
    
    // MARK: - Dynamic Toolbar Behaviors
    
    @ViewBuilder
    private var dynamicBottomToolbar: some View {
        switch toolbarBehavior {
        case .alwaysVisible:
            standardToolbarLayout
        case .minimizeOnScroll:
            minimizingToolbarLayout
        case .minimizeToCorners:
            cornerToolbarLayout
        case .showHide:
            showHideToolbarLayout
        }
    }
    
    @ViewBuilder
    private var standardToolbarLayout: some View {
        if usesCustomFloatingToolbar {
            if showSearch {
                searchBarView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                #if os(iOS)
                customFloatingBottomToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                #endif
            }
        } else if showSearch {
            searchBarView
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var minimizingToolbarLayout: some View {
        if showSearch {
            if toolbarScrollState.isMinimized {
                minimizedSearchPill
                    .transition(.scale.combined(with: .opacity))
            } else {
                searchBarView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } else {
            if toolbarScrollState.isMinimized {
                minimizedToolbarPill
                    .transition(.scale.combined(with: .opacity))
            } else {
                if usesCustomFloatingToolbar {
                    #if os(iOS)
                    customFloatingBottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    #endif
                }
            }
        }
    }
    
    @ViewBuilder
    private var minimizedToolbarPill: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                toolbarScrollState.expand()
            }
        } label: {
            MinAffordanceStyle.shared.capsuleShape
                .fill(GlassControl.floatingMaterial)
                .frame(width: 100, height: 24)
                .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.capsuleShape.stroke(GlassControl.Border.subtle.color, lineWidth: GlassControl.Border.subtle.width) } }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var minimizedSearchPill: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                toolbarScrollState.expand()
                isSearchFieldFocused = true
            }
        } label: {
            MinAffordanceStyle.shared.capsuleShape
                .fill(GlassControl.floatingMaterial)
                .frame(width: 100, height: 24)
                .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.capsuleShape.stroke(GlassControl.Border.subtle.color, lineWidth: GlassControl.Border.subtle.width) } }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            // Hide keyboard when minimized
            isSearchFieldFocused = false
        }
    }
    
    @ViewBuilder
    private var cornerToolbarLayout: some View {
        if showSearch {
            if toolbarScrollState.isMinimized {
                HStack {
                    cornerFilterButton
                    Spacer()
                    cornerCloseButton
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                searchBarView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } else {
            if toolbarScrollState.isMinimized {
                HStack {
                    cornerFilterButton
                    Spacer()
                    cornerSearchButton
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                if usesCustomFloatingToolbar {
                    #if os(iOS)
                    customFloatingBottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    #endif
                }
            }
        }
    }
    
    @ViewBuilder
    private var cornerFilterButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                toolbarScrollState.expand()
            }
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.filter, size: .compact, foregroundColor: DesignSystem.Color.accent, accessibilityLabel: "Filters")
                .shadow(color: DesignSystem.Shadow.sm.color, radius: 4, x: 0, y: 2)
        }
    }
    
    @ViewBuilder
    private var cornerSearchButton: some View {
        Button {
            presentGlobalSearch(focusSearchOnOpen: true)
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.search, size: .compact, foregroundColor: DesignSystem.Color.accent, accessibilityLabel: "Search")
                .shadow(color: DesignSystem.Shadow.sm.color, radius: 4, x: 0, y: 2)
        }
    }
    
    @ViewBuilder
    private var cornerCloseButton: some View {
        Button {
            withAnimation(DesignSystem.Animation.springStandard) {
                showSearch = false
            }
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.close, size: .compact, foregroundColor: DesignSystem.Color.accent, accessibilityLabel: "Close")
                .shadow(color: DesignSystem.Shadow.sm.color, radius: 4, x: 0, y: 2)
        }
    }
    
    @ViewBuilder
    private var showHideToolbarLayout: some View {
        if !toolbarScrollState.isMinimized {
            if showSearch {
                searchBarView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                if usesCustomFloatingToolbar {
                    #if os(iOS)
                    customFloatingBottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    #endif
                }
            }
        }
    }
    
    private var hasActiveSearchFilterControls: Bool {
        hasActiveFilters || sortOption != .episodeDateDesc
    }
    
    private var searchFilterButtonColor: SwiftUI.Color {
        hasActiveSearchFilterControls ? DesignSystem.Color.accent : toolbarSecondaryAccentColor
    }
    
    private var searchFiltersMenu: some View {
        Menu {
            Menu {
                listMenuContent
            } label: {
                Label("Lists", systemImage: DesignSystem.Icon.listRectangle)
            }
            
            if hasPreferredStreamingServices {
                Menu {
                    streamingServiceMenuContent
                } label: {
                    Label("Streaming", systemImage: "play.square.stack.fill")
                }
            }
            
            Menu {
                genreMenuContent
            } label: {
                Label("Genres", systemImage: DesignSystem.Icon.genre)
            }
            
            Menu {
                ratingMenuContent
            } label: {
                Label("Ratings", systemImage: DesignSystem.Icon.rating)
            }
            
            Menu {
                sortMenuContent
            } label: {
                Label("Sort", systemImage: DesignSystem.Icon.sort)
            }
        } label: {
            filterButtonForAppearance
        }
        .accessibilityLabel("Filters")
    }
    
    @ViewBuilder
    private var filterButtonForAppearance: some View {
        if usesCustomFloatingToolbar {
            GlassCircleButton(systemImage: DesignSystem.Icon.filter, foregroundColor: searchFilterButtonColor, accessibilityLabel: "Filters")
        } else {
            switch searchBarAppearance {
            case .classic, .elevated, .glass:
                GlassCircleButton(systemImage: DesignSystem.Icon.filter, size: .compact, foregroundColor: searchFilterButtonColor, accessibilityLabel: "Filters")
            case .solid:
                Label("Filters", systemImage: DesignSystem.Icon.filter)
                    .labelStyle(.iconOnly)
                    .font(DesignSystem.Typography.glassIcon)
                    .frame(width: GlassControl.compactHeight, height: GlassControl.compactHeight)
                    .foregroundStyle(searchFilterButtonColor)
                    .background(DesignSystem.Color.accent)
                    .clipShape(MinAffordanceStyle.shared.circleShape)
                    .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.circleShape.stroke(MinAffordanceStyle.borderColor, lineWidth: MinAffordanceStyle.borderLineWidth) } }
                    .shadow(color: DesignSystem.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var searchFieldContainer: some View {
        let aff = MinAffordanceStyle.shared
        return HStack(spacing: DesignSystem.Spacing.sm) {
            DesignSystemIcon(DesignSystem.Icon.search, size: DesignSystem.IconSize.sm, color: searchIconColor)
            DebouncedSearchInputField(
                committedText: $searchText,
                isFocused: $isSearchFieldFocused,
                placeholder: "Search movies"
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .frame(height: usesCustomFloatingToolbar ? customToolbarControlHeight : glassControlHeight)
        .background(searchFieldBackground)
        .clipShape(aff.capsuleShape)
        .overlay { if aff.borderEnabled { searchFieldOverlay } }
        .shadow(color: searchFieldShadowColor, radius: searchFieldShadowRadius, x: 0, y: searchFieldShadowY)
    }
    
    @ViewBuilder
    private var searchFieldBackground: some View {
        if usesCustomFloatingToolbar {
            Rectangle().fill(.thinMaterial)
        } else {
        switch searchBarAppearance {
        case .classic:
            Rectangle().fill(.ultraThinMaterial)
        case .solid:
            DesignSystem.Color.cardBackground
        case .elevated:
            Rectangle().fill(.thickMaterial)
        case .glass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                
                // Add subtle gradient highlight to simulate glass distortion
                LinearGradient(
                    colors: [
                        .white.opacity(0.15),
                        .white.opacity(0.05),
                        .clear,
                        .white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        }
    }
    
    @ViewBuilder
    private var searchFieldOverlay: some View {
        let s = MinAffordanceStyle.shared.capsuleShape
        switch searchBarAppearance {
        case .classic:
            s.stroke(DesignSystem.Color.borderLight.opacity(0.6), lineWidth: 0.5)
        case .solid:
            s.stroke(DesignSystem.Color.accent, lineWidth: 1.5)
        case .elevated:
            s.stroke(DesignSystem.Color.borderLight.opacity(0.8), lineWidth: 0.5)
        case .glass:
            ZStack {
                s.stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear,
                            .white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
                s.stroke(DesignSystem.Color.borderLight.opacity(0.5), lineWidth: 0.5)
            }
        }
    }
    
    private var searchIconColor: SwiftUI.Color {
        switch searchBarAppearance {
        case .classic, .elevated, .glass:
            return DesignSystem.Color.textSecondary
        case .solid:
            return DesignSystem.Color.accent
        }
    }
    
    private var searchFieldShadowColor: SwiftUI.Color {
        switch searchBarAppearance {
        case .classic:
            return .clear
        case .solid:
            return DesignSystem.Color.accent.opacity(0.2)
        case .elevated:
            return DesignSystem.Shadow.lg.color.opacity(0.4)
        case .glass:
            return DesignSystem.Shadow.md.color.opacity(0.3)
        }
    }
    
    private var searchFieldShadowRadius: CGFloat {
        switch searchBarAppearance {
        case .classic:
            return 0
        case .solid:
            return 8
        case .elevated:
            return 12
        case .glass:
            return 6
        }
    }
    
    private var searchFieldShadowY: CGFloat {
        switch searchBarAppearance {
        case .classic:
            return 0
        case .solid:
            return 4
        case .elevated:
            return 6
        case .glass:
            return 3
        }
    }
    
    private var searchBarBottomPadding: CGFloat {
        switch searchBarAppearance {
        case .classic:
            return DesignSystem.Spacing.sm
        case .solid:
            return DesignSystem.Spacing.md
        case .elevated:
            return DesignSystem.Spacing.lg
        case .glass:
            return DesignSystem.Spacing.sm
        }
    }
    
    @ViewBuilder
    private var closeButtonForAppearance: some View {
        if usesCustomFloatingToolbar {
            GlassCircleButton(systemImage: DesignSystem.Icon.close, accessibilityLabel: "Close")
                .shadow(color: searchFieldShadowColor, radius: searchFieldShadowRadius, x: 0, y: searchFieldShadowY)
        } else {
            switch searchBarAppearance {
            case .classic, .elevated, .glass:
                GlassCircleButton(systemImage: DesignSystem.Icon.close, size: .compact, accessibilityLabel: "Close")
            case .solid:
                Label("Close", systemImage: DesignSystem.Icon.close)
                    .labelStyle(.iconOnly)
                    .font(DesignSystem.Typography.glassIcon)
                    .frame(width: GlassControl.compactHeight, height: GlassControl.compactHeight)
                    .foregroundStyle(DesignSystem.Color.textPrimary)
                    .background(DesignSystem.Color.accent)
                    .clipShape(MinAffordanceStyle.shared.circleShape)
                    .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.circleShape.stroke(MinAffordanceStyle.borderColor, lineWidth: MinAffordanceStyle.borderLineWidth) } }
                    .shadow(color: DesignSystem.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var baseContentView: some View {
        VStack(spacing: 0) {
            if localDB.isRestoringUserData {
                syncBanner
            }
            movieListContent
        }
        .coordinateSpace(name: "scrollArea")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            handleScrollOffset(value)
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
        .toolbar {
            topToolbar
            if !usesCustomFloatingToolbar && !showSearch {
                bottomToolbar
            }
        }
        #if os(iOS)
        .toolbar(showSearch ? .hidden : .visible, for: .bottomBar)
        .toolbarBackground(usesCustomFloatingToolbar ? .hidden : .visible, for: .bottomBar)
        #endif
        .safeAreaInset(edge: .bottom) {
            dynamicBottomToolbar
        }
        .animation(DesignSystem.Animation.springStandard, value: showSearch)
        .animation(DesignSystem.Animation.springStandard, value: toolbarScrollState.isMinimized)
        .onChange(of: showSearch) { _, newValue in
            if newValue {
                // Reset toolbar state when opening search
                toolbarScrollState.reset()
            }
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        let downwardTravel = max(0, -offset)
        let progress = min(downwardTravel / titleTypeBlurDistance, 1)
        titleTypeBlurRadius = progress * titleTypeMaxBlurRadius

        guard toolbarBehavior != .alwaysVisible else { return }
        toolbarScrollState.updateScroll(offset: offset, threshold: 50)
    }

    private var syncBanner: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Welcome back!")
                .headlineSmall()
                .foregroundColor(DesignSystem.Color.textPrimary)
            Text("Fetching your data from iCloud…")
                .bodySmall()
                .foregroundColor(DesignSystem.Color.textSecondary)
            ProgressView()
                .progressViewStyle(.linear)
                .tint(DesignSystem.Color.accent)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Color.borderLight, lineWidth: 1)
        )
        .cornerRadius(DesignSystem.CornerRadius.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.md)
    }
    
    private var contentWithSheets: some View {
        baseContentView
            .sheet(isPresented: $showAccountSheet) {
                AccountSheetView()
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $activeSearchContext) { context in
                SearchScreenView(context: context)
            }
            .modifier(MovieDetailPresentationModifier(
                selectedMovie: $selectedMovie,
                style: bottomSheetStyle,
                onDismiss: {
                    logMovieDetailDismissed()
                    applyPendingDetailSearchFromDetails()
                    applyPendingPersonSearchFromDetails()
                },
                content: { movie in
                    MovieDetailView(
                        movie: movie,
                        presentationSource: .mainList,
                        onCreditPersonTapped: startPersonSearchFromDetails,
                        onYearTapped: startYearSearchFromDetails,
                        onGenreTapped: startGenreSearchFromDetails,
                        onRatingTapped: startRatingSearchFromDetails
                    )
                    .onAppear {
                        logMovieDetailPresented(movie.id)
                    }
                }
            ))
    }
    
    private var contentWithFirstChangeHandlers: some View {
        contentWithSheets
            // Removed onChange for selectedMovie - not needed since:
            // - State changes already update cache via updateMovieInCache
            // - Deletions/edits handle their own reloads
            // - Removing this prevents "Modifying state during view update" warnings
            .onChange(of: showSearch) { oldValue, newValue in
                if newValue {
                    if skipNextSearchAutofocus {
                        isSearchFieldFocused = false
                        skipNextSearchAutofocus = false
                    } else {
                        isSearchFieldFocused = true
                    }
                } else {
                    isSearchFieldFocused = false
                }
                if !newValue {
                    searchText = ""
                    lastScheduledSearchQuery = ""
                    previousSearchQuery = ""
                    previousSearchResultIds.removeAll()
                }
            }
            .onChange(of: selectedMovie?.id) { oldValue, newValue in
                guard isPerfLoggingEnabled else { return }
                if oldValue == nil, let newValue {
                    print("⏱️ [PERF] [Detail] selectedMovie set: \(newValue)")
                } else if oldValue != nil, newValue == nil {
                    print("⏱️ [PERF] [Detail] selectedMovie cleared")
                }
            }
    }
    
    private var contentWithFilterChangeHandlers: some View {
        contentWithFirstChangeHandlers
            .onChange(of: searchText) { _, newValue in
                let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedValue == lastScheduledSearchQuery {
                    return
                }
                lastScheduledSearchQuery = trimmedValue
                if !trimmedValue.isEmpty && movieSearchIndex.count != localDB.movies.count {
                    rebuildMovieSearchIndex()
                }
                if let activePersonSearchQuery,
                   activePersonSearchQuery.compare(trimmedValue, options: .caseInsensitive) != .orderedSame {
                    self.activePersonSearchQuery = nil
                }
                lastFilterHash = 0
                displayedMovieCount = 50 // Reset to first page
                scheduleFilterRecompute(debounceSearch: true, source: "searchText")
            }
            .onChange(of: watchFilter) { _, _ in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                scheduleFilterRecompute(source: "watchFilter")
            }
            .onChange(of: selectedGenre) { _, _ in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                scheduleFilterRecompute(source: "selectedGenre")
            }
            .onChange(of: selectedMPAARating) { _, _ in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                scheduleFilterRecompute(source: "selectedMPAARating")
            }
            .onChange(of: selectedStreamingService) { _, _ in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                scheduleFilterRecompute(source: "selectedStreamingService")
            }
            .onChange(of: selectedInspiration) { _, _ in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                scheduleFilterRecompute(source: "selectedInspiration")
            }
            .onChange(of: selectedList) { oldValue, newValue in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                
                // Clear rank cache when list changes
                if oldValue?.identifier != newValue?.identifier {
                    rankCacheStore.rankCache.removeAll()
                    rankCacheStore.lastRankCacheSourceId = nil
                }
                
                // Auto-set sorting to ranking if the newly selected list is ranked
                if let newList = newValue, newList.isRankedList {
                    // Only change if ranking is available and not already set
                    let availableOptions = SortOption.availableOptions(for: newList)
                    if availableOptions.contains(.ranking) && sortOption != .ranking {
                        sortOption = .ranking
                    }
                } else if newValue == nil {
                    // Reset to default sort when clearing list filter
                    sortOption = .episodeDateDesc
                }
                scheduleFilterRecompute(source: "selectedList")
            }
            .onChange(of: sortOption) { oldValue, newValue in
                filterVersion += 1
                displayedMovieCount = 50 // Reset to first page
                
                // Clear rank cache when switching to ranking sort to ensure we use the correct source
                if newValue == .ranking && oldValue != .ranking {
                    rankCacheStore.rankCache.removeAll()
                    rankCacheStore.lastRankCacheSourceId = nil
                }
                scheduleFilterRecompute(source: "sortOption")
            }
    }
    
    private var contentWithDataChangeHandlers: some View {
        contentWithFilterChangeHandlers
            .onChange(of: preferredListIdentifiers.count) { _, _ in
                // Defer to avoid modifying state during view update
                Task { @MainActor in
                    await Task.yield()
                    filterVersion += 1
                    displayedMovieCount = 50 // Reset to first page
                    scheduleFilterRecompute()
                }
            }
            .onChange(of: localDB.movies.count) { _, newCount in
                // Defer to avoid modifying state during view update
                Task { @MainActor in
                    await Task.yield()
                    // If cache is empty and we just loaded movies, populate cache immediately
                    if cachedFilteredMovies.isEmpty && newCount > 0 {
                        cachedFilteredMovies = localDB.movies
                    }
                    filterVersion += 1
                    displayedMovieCount = 50 // Reset to first page
                    rebuildGenreCache()
                    scheduleFilterRecompute()
                }
            }
    }
    
    private var contentWithCacheChangeHandlers: some View {
        contentWithDataChangeHandlers
            .onChange(of: allDataSources.count) { _, _ in
                // Defer to avoid modifying state during view update
                Task { @MainActor in
                    await Task.yield()
                    filterVersion += 1
                    displayedMovieCount = 50 // Reset to first page
                    scheduleFilterRecompute()
                }
            }
    }
    
    private var contentWithChangeHandlers: some View {
        contentWithCacheChangeHandlers
            .onChange(of: preferredServicesData) { _, _ in
                let preferredKeys = Set(preferredStreamingServices.map { normalizedCaseKey($0) })
                if let selectedStreamingService, !preferredKeys.contains(normalizedCaseKey(selectedStreamingService)) {
                    Task { @MainActor in
                        await Task.yield()
                        self.selectedStreamingService = nil
                        filterVersion += 1
                        displayedMovieCount = 50 // Reset to first page
                        scheduleFilterRecompute()
                    }
                }
            }
            .onChange(of: preferredListsData) { _, _ in
                let preferredIds = preferredListIdentifierSet
                if let selectedList, !preferredIds.contains(selectedList.identifier) {
                    Task { @MainActor in
                        await Task.yield()
                        self.selectedList = nil
                        sortOption = .episodeDateDesc
                        filterVersion += 1
                        displayedMovieCount = 50 // Reset to first page
                        scheduleFilterRecompute()
                    }
                } else {
                    filterVersion += 1
                    displayedMovieCount = 50 // Reset to first page
                    scheduleFilterRecompute()
                }
            }
    }
    
    var body: some View {
        NavigationView {
            contentWithChangeHandlers
                .onAppear {
                    let onAppearStart = ProcessInfo.processInfo.systemUptime
                    // Initialize cache with all movies if empty to show initial content
                    if cachedFilteredMovies.isEmpty && !localDB.movies.isEmpty {
                        cachedFilteredMovies = localDB.movies
                        filterVersion += 1 // Trigger background filtering
                    }
                    
                    // Build source cache when needed (uses @Query which auto-loads)
                    Task { @MainActor in
                        buildSourceCacheIfNeeded()
                    }
                    if cachedFilteredMovies.isEmpty && !localDB.movies.isEmpty {
                        cachedFilteredMovies = localDB.movies
                    }
                    rebuildGenreCache()
                    scheduleFilterRecompute()
                    loadPodcastFeedArtworkIfNeeded()
                    logPerf("MovieListView onAppear setup", start: onAppearStart, thresholdMs: 8)
                    
                    if localDB.movies.isEmpty && !localDB.isLoading {
                        localDB.loadMovies()
                    }

                    // CloudKit restore/sync runs once from WatchedItApp.performInitialLoad to avoid duplicate work and flicker.

                    if !hasNormalizedStreamingServices {
                        hasNormalizedStreamingServices = true
                        Task {
                            await localDB.normalizeStreamingServicesCase()
                        }
                    }

                    // Defer catalog refresh until after first load and CloudKit restore to avoid
                    // multiple load cycles and list flicker (refresh uses refreshMovies(), not loadMovies())
                    Task { @MainActor in
                        let refreshGateStart = ProcessInfo.processInfo.systemUptime
                        var waited = 0.0
                        while localDB.isLoading && waited < 3.0 {
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                            waited += 0.2
                        }
                        if !localDB.movies.isEmpty || waited >= 3.0 {
                            localDB.refreshCatalogFromBundleIfNeeded(modelContext: modelContext)
                        }
                        logPerf("catalog refresh gate wait", start: refreshGateStart, thresholdMs: 20)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MovieListNeedsRefresh"))) { _ in
                    filterVersion += 1
                    displayedMovieCount = 50 // Reset to first page
                    localDB.loadMovies()
                    rebuildGenreCache()
                    scheduleFilterRecompute()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MovieUpdated"))) { _ in
                    // Invalidate filter cache immediately when a movie is updated
                    // This ensures the view reflects state changes right away
                    filterVersion += 1
                    // Don't reset pagination on individual movie updates - just invalidate cache
                    scheduleFilterRecompute()
                }
                .onChange(of: allDataSources.count) { _, _ in
                    loadPodcastFeedArtworkIfNeeded()
                }
                .onChange(of: localDB.movieStatusVersion) { _, _ in
                    // Avoid expensive full-array equality checks during typing; this scalar
                    // signal tracks status mutations and keeps search responsive.
                    filterVersion += 1
                    // Don't reset pagination on status updates - just invalidate cache
                    let hasSearchText = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if !hasSearchText && !hasActiveFilters && selectedInspiration == nil {
                        cachedFilteredMovies = localDB.movies
                    }
                    scheduleFilterRecompute()
                }
        }
    }
    
    /// Loads more movies when user scrolls near the end
    private func loadMoreMovies() {
        guard !isLoadingMore else { return }
        guard displayedMovieCount < filteredMovies.count else { return }
        
        isLoadingMore = true
        
        // Load in batches of 50
        let newCount = min(displayedMovieCount + 50, filteredMovies.count)
        
        // Use a small delay to allow UI to update smoothly
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            displayedMovieCount = newCount
            isLoadingMore = false
        }
    }
    
    /// Prefetch images for upcoming items in the list
    private func prefetchUpcomingImages(startingFrom index: Int, in movies: [Movie]) {
        // Prefetch next 10 images that aren't already cached
        let prefetchRange = (index + 1)..<min(index + 11, movies.count)
        let imageSize = posterSizePreference.optimalImageSize
        
        Task.detached {
            for movieIndex in prefetchRange {
                let movie = movies[movieIndex]
                if let posterPath = movie.posterPath,
                   let posterURL = await MovieDataService.shared.getPosterURL(path: posterPath, size: imageSize),
                   let url = URL(string: posterURL) {
                    // Only prefetch if not already cached
                    if await ImageCache.shared.getImage(for: url) == nil {
                        await ImageCache.shared.prefetchImage(from: url)
                    }
                }
            }
        }
    }

    private func canonicalizeServices(_ services: [String]) -> [String] {
        var orderedKeys: [String] = []
        var entries: [String: String] = [:]
        var hasMixedCaps: [String: Bool] = [:]
        
        for service in services {
            let trimmedName = service.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let key = normalizedCaseKey(trimmedName)
            
            if entries[key] == nil {
                orderedKeys.append(key)
                entries[key] = trimmedName
                hasMixedCaps[key] = isMixedCaps(trimmedName)
                continue
            }
            
            let currentMixed = hasMixedCaps[key] ?? false
            let candidateMixed = isMixedCaps(trimmedName)
            if !currentMixed && candidateMixed {
                entries[key] = trimmedName
                hasMixedCaps[key] = true
            }
        }
        
        return orderedKeys.compactMap { entries[$0] }
    }
    
    private func normalizedCaseKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func isMixedCaps(_ value: String) -> Bool {
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let hasUpper = letters.contains { CharacterSet.uppercaseLetters.contains($0) }
        let hasLower = letters.contains { CharacterSet.lowercaseLetters.contains($0) }
        return hasUpper && hasLower
    }
    
}

private struct DebouncedSearchInputField: View {
    @Binding var committedText: String
    let isFocused: FocusState<Bool>.Binding
    let placeholder: String

    @State private var draftText: String = ""
    @State private var debounceTask: Task<Void, Never>? = nil

    var body: some View {
        TextField(placeholder, text: $draftText)
            .focused(isFocused)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .submitLabel(.search)
            .onAppear {
                draftText = committedText
            }
            .onChange(of: committedText) { _, newValue in
                if newValue != draftText {
                    draftText = newValue
                }
            }
            .onChange(of: draftText) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 20_000_000)
                    } catch {
                        return
                    }
                    if Task.isCancelled { return }
                    await MainActor.run {
                        committedText = newValue
                    }
                }
            }
            .onDisappear {
                debounceTask?.cancel()
            }
    }
}

struct MovieRowView: View {
    let movie: Movie
    let selectedList: DataSource?
    let rank: Int?
    let topPreferredStreamingService: String?
    let sourcesAndListsText: String
    let statusOverride: MovieStatus?
    
    @AppStorage(PosterSizePreference.storageKey) private var posterSizePreferenceRaw: String = PosterSizePreference.plus60.rawValue
    
    private var posterSizePreference: PosterSizePreference {
        PosterSizePreference(rawValue: posterSizePreferenceRaw) ?? .plus60
    }
    
    private var effectiveStatus: MovieStatus {
        if let statusOverride {
            return statusOverride
        }
        
        return MovieStatus(
            isRewatched: movie.isRewatched,
            isListened: movie.isListened,
            isSaved: movie.isSaved
        )
    }
    
    // Read status from the live cache so rows refresh immediately.
    private var isRewatched: Bool { effectiveStatus.isRewatched }
    private var isListened: Bool { effectiveStatus.isListened }
    private var isSaved: Bool { effectiveStatus.isSaved }
    
    // Get display title with rank prefix if applicable
    private var displayTitle: String {
        // Show rank only if a ranked list is selected and the movie has a rank in that list
        if let selectedList = selectedList, selectedList.isRankedList, let rank = rank {
            return "#\(rank) \(movie.title)"
        }
        return movie.title
    }
    
    init(
        movie: Movie,
        status: MovieStatus? = nil,
        selectedList: DataSource? = nil,
        rank: Int? = nil,
        topPreferredStreamingService: String? = nil,
        sourcesAndListsText: String = ""
    ) {
        self.movie = movie
        self.statusOverride = status
        self.selectedList = selectedList
        self.rank = rank
        self.topPreferredStreamingService = topPreferredStreamingService
        self.sourcesAndListsText = sourcesAndListsText
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Poster thumbnail - optimized for performance
            Group {
                if let posterPath = movie.posterPath,
                   let posterURL = MovieDataService.shared.getThumbnailURL(path: posterPath),
                   let url = URL(string: posterURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(DesignSystem.Color.surface)
                    }
                    .frame(width: 50, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                } else {
                    Rectangle()
                        .fill(DesignSystem.Color.surface)
                        .frame(width: 50, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                        .overlay(
                            DesignSystemIcon(DesignSystem.Icon.movie, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textSecondary)
                        )
                }
            }
            
            // Title and info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(displayTitle)
                    .headlineSmall()
                    .strikethrough(isRewatched && isListened)
                    .foregroundColor((isRewatched && isListened) ? DesignSystem.Color.textSecondary : DesignSystem.Color.headline)
                
                // Year and rating
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let year = movie.year {
                        Text(String(year))
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }
                    
                    if let rating = movie.mpaaRating {
                        Text(rating)
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }

                    if let topPreferredStreamingService {
                        Text(topPreferredStreamingService)
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                // Sources and lists
                if !sourcesAndListsText.isEmpty {
                    Text(sourcesAndListsText)
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status indicators on the right (only show when "on")
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Listened indicator (only show when listened)
                if isListened {
                    DesignSystemIcon(DesignSystem.Icon.listenCircleFill, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.accent)
                }
                
                // Rewatched indicator (only show when rewatched)
                if isRewatched {
                    DesignSystemIcon(DesignSystem.Icon.rewatchCircleFill, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.accent)
                }
                
                // Saved indicator (only show when saved)
                if isSaved {
                    DesignSystemIcon(DesignSystem.Icon.bookmarkCircleFill, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }
}

struct FilterSortView: View {
    @Binding var watchFilter: WatchFilter
    @Binding var selectedGenre: String?
    @Binding var selectedMPAARating: String?
    @Binding var selectedList: DataSource?
    @Binding var sortOption: SortOption
    let allGenres: [String]
    @Query(sort: \DataSource.name) private var allDataSources: [DataSource]
    @AppStorage(ListPreferences.storageKey) private var preferredListsData: Data = Data()
    @Environment(\.dismiss) private var dismiss
    
    // MPAA Rating options
    private let mpaaRatings: [String?] = [nil, "G", "PG", "PG-13", "R", "NC-17"]
    private var mpaaRatingLabels: [String] {
        mpaaRatings.map { rating in
            rating ?? "All Ratings"
        }
    }

    private var preferredListIdentifiers: [String] {
        let decoded = ListPreferences.decode(from: preferredListsData)
        if decoded.isEmpty && !ListPreferences.hasInitialized() {
            return allDataSources.map { $0.identifier }
        }
        return decoded
    }

    private var preferredDataSources: [DataSource] {
        let lookup = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0) })
        return preferredListIdentifiers.compactMap { lookup[$0] }
    }

    private var listSelection: Binding<String> {
        Binding(
            get: { selectedList?.identifier ?? "All" },
            set: { identifier in
                selectedList = identifier == "All" ? nil : preferredDataSources.first { $0.identifier == identifier }
            }
        )
    }
    
    private func clearAllFilters() {
        watchFilter = .all
        selectedGenre = nil
        selectedMPAARating = nil
        sortOption = .episodeDateDesc
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Filter by Status") {
                    Picker(selection: $watchFilter) {
                        ForEach(WatchFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
                .designSystemGroupedListRow()
                
                Section("Filter by Genre") {
                    Picker(selection: Binding(
                        get: { selectedGenre ?? "All" },
                        set: { selectedGenre = $0 == "All" ? nil : $0 }
                    )) {
                        Text("All").tag("All")
                        ForEach(allGenres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    } label: {
                        EmptyView()
                    }
                }
                .designSystemGroupedListRow()
                
                Section("Filter by Rating") {
                    Picker(selection: $selectedMPAARating) {
                        ForEach(Array(mpaaRatings.enumerated()), id: \.offset) { index, rating in
                            Text(mpaaRatingLabels[index]).tag(rating)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                }
                .designSystemGroupedListRow()
                
                Section("Filter by Source/List") {
                    Picker(selection: listSelection) {
                        Text("All Lists").tag("All")
                        ForEach(preferredDataSources, id: \.identifier) { source in
                            Text(source.name).tag(source.identifier)
                        }
                    } label: {
                        EmptyView()
                    }
                }
                .designSystemGroupedListRow()
                
                Section("Sort By") {
                    Picker(selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    } label: {
                        EmptyView()
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Filters & Sort")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.checkmark)
                    }
                    .accessibilityLabel("Done")
                }
            }
            #endif
        }
    }
}

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var localDB = LocalDatabaseManager.shared
    @State private var showThemes = false
    @State private var isRefreshingCatalog = false
    @State private var refreshAlertMessage: String? = nil
    @Bindable private var affordanceStyle = MinAffordanceStyle.shared

    private func accountActionRowLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(DesignSystem.Color.textPrimary)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("iCloud") {
                    Label("iCloud backup is always on", systemImage: "icloud")
                        .foregroundStyle(DesignSystem.Color.textPrimary)
                }
                .designSystemGroupedListRow()
                
                Section("Preferences") {
                    NavigationLink(destination: StreamingServicesPreferencesView()) {
                        Label("Streaming Services", systemImage: DesignSystem.Icon.streaming)
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    NavigationLink(destination: PodcastAppPreferencesView()) {
                        Label("Podcast App", systemImage: DesignSystem.Icon.podcast)
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    NavigationLink(destination: ListPreferencesView()) {
                        Label("Lists", systemImage: DesignSystem.Icon.list)
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    NavigationLink(destination: NotificationPreferencesView()) {
                        Label("Notifications", systemImage: "bell")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                }
                .designSystemGroupedListRow()
                
                Section("Catalog") {
                    Button(action: refreshCatalogFromBundle) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            accountActionRowLabel("Refresh Catalog from Bundle", systemImage: DesignSystem.Icon.refresh)
                            if isRefreshingCatalog {
                                Spacer()
                                ProgressView()
                                    .tint(DesignSystem.Color.accent)
                            }
                        }
                    }
                    .disabled(isRefreshingCatalog)
                }
                .designSystemGroupedListRow()
                
                Section("Appearance") {
                    Button(action: {
                        showThemes = true
                    }) {
                        accountActionRowLabel("Themes", systemImage: DesignSystem.Icon.settings)
                    }
                    .buttonStyle(.plain)

                    Toggle(isOn: $affordanceStyle.borderEnabled) {
                        Label("Affordance border", systemImage: "square.dashed")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }

                    HStack {
                        Label("Affordance shape", systemImage: "square.on.circle")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                        Spacer()
                        Picker("", selection: $affordanceStyle.shape) {
                            ForEach(MinAffordanceStyle.Shape.allCases, id: \.self) { shape in
                                Text(shape.displayName).tag(shape)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    NavigationLink(destination: LoadingScreenStyleView()) {
                        Label("Loading Screen Style", systemImage: "sparkles.rectangle.stack")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: SearchBarAppearanceView()) {
                        Label("Search Bar Appearance", systemImage: DesignSystem.Icon.search)
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: FontOverrideSettingsView()) {
                        Label("Fonts", systemImage: "textformat")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }

                    NavigationLink(destination: MainListToolbarStyleView()) {
                        Label("Main Toolbar Style", systemImage: "rectangle.bottomthird.inset.filled")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }

                    NavigationLink(destination: MainToolbarLayoutStyleView()) {
                        Label("Toolbar Layout", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }

                    NavigationLink(destination: CustomToolbarIconSpacingView()) {
                        Label("Custom Toolbar Icon Spacing", systemImage: "arrow.left.and.right")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: ToolbarBehaviorSettingsView()) {
                        Label("Toolbar Behavior", systemImage: "arrow.up.and.down.circle")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: PosterSizePreferenceView()) {
                        Label("Poster Size", systemImage: "rectangle.portrait")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: BottomSheetCloseButtonBlurPreferenceView()) {
                        Label("Bottom Sheet Style", systemImage: "rectangle.bottomhalf.inset.filled")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: TapInteractionSettingsView()) {
                        Label("Tap Interactions", systemImage: "hand.tap.fill")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                    
                    NavigationLink(destination: MovieDetailLayoutSettingsView()) {
                        Label("Movie Details Layout", systemImage: "film")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                    }
                }
                .designSystemGroupedListRow()
                
                #if os(iOS)
                Section {
                    Button(action: {
                        OnboardingState.resetNewUserExperience()
                        dismiss()
                    }) {
                        accountActionRowLabel("Reset settings and new user experience", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("Marks all onboarding screens as unseen so you can go through the new user experience again.")
                }
                .designSystemGroupedListRow()
                #endif

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(DesignSystem.Color.textPrimary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.close)
                    }
                    .accessibilityLabel("Close")
                }
            }
            #endif
            .sheet(isPresented: $showThemes) {
                ThemesView()
                    .presentationDragIndicator(.visible)
            }
            .alert("Catalog Refresh", isPresented: Binding(get: { refreshAlertMessage != nil }, set: { _ in refreshAlertMessage = nil })) {
                Button("OK") {}
            } message: {
                Text(refreshAlertMessage ?? "")
            }
        }
        .bottomSheetPullToDismiss()
    }
    
    private func refreshCatalogFromBundle() {
        guard !isRefreshingCatalog else { return }
        isRefreshingCatalog = true
        Task { @MainActor in
            do {
                try await localDB.rebaseOnBootstrapDatabase(modelContext: modelContext)
                refreshAlertMessage = "Catalog refreshed from the bundled database."
            } catch {
                refreshAlertMessage = "Catalog refresh failed: \(error.localizedDescription)"
            }
            isRefreshingCatalog = false
        }
    }
}


#Preview {
    MovieListView()
}

// MARK: - Search Bar Appearance View

struct SearchBarAppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SearchBarAppearance.storageKey) private var searchBarAppearanceRaw: String = SearchBarAppearance.classic.rawValue
    @AppStorage(SearchCloseButtonVisibilityPreference.showOnlyWhenSearchFocusedStorageKey)
    private var showCloseButtonOnlyWhenSearchFocused: Bool = false
    
    private var searchBarAppearance: SearchBarAppearance {
        SearchBarAppearance(rawValue: searchBarAppearanceRaw) ?? .classic
    }
    
    var body: some View {
        List {
            Section {
                ForEach(SearchBarAppearance.allCases, id: \.rawValue) { appearance in
                    SearchBarAppearanceRow(
                        appearance: appearance,
                        isSelected: searchBarAppearance == appearance,
                        onSelect: {
                            searchBarAppearanceRaw = appearance.rawValue
                        }
                    )
                }
            } header: {
                Text("Select Style")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Choose how the search bar appears next to the glass effect toolbar.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()

            Section {
                Toggle("Show Close Search Only While Focused", isOn: $showCloseButtonOnlyWhenSearchFocused)
                    .tint(DesignSystem.Color.accent)
            } header: {
                Text("Search Screen Close Button")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("When enabled, the Close Search button appears only while the search field is focused.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Search Bar Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MainListToolbarStyleView: View {
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.system.rawValue

    private var selectedStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .system
    }

    var body: some View {
        List {
            Section {
                ForEach(MainListToolbarStyle.allCases, id: \.rawValue) { style in
                    Button {
                        mainListToolbarStyleRaw = style.rawValue
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: style == .system ? "rectangle.bottomthird.inset.filled" : "capsule")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(DesignSystem.Color.accent)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(style.rawValue)
                                    .headlineSmall()
                                    .foregroundColor(DesignSystem.Color.textPrimary)

                                Text(style.description)
                                    .captionMedium()
                                    .foregroundColor(DesignSystem.Color.textSecondary)
                            }

                            Spacer()

                            if selectedStyle == style {
                                Image(systemName: DesignSystem.Icon.checkmarkCircle)
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Main List Toolbar")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("System uses native iOS chrome. Custom uses a floating frosted toolbar with white icons.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Main Toolbar Style")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MainToolbarLayoutStyleView: View {
    @AppStorage(MainToolbarLayoutStyle.storageKey) private var mainToolbarLayoutStyleRaw: String = MainToolbarLayoutStyle.separated.rawValue

    private var selectedLayoutStyle: MainToolbarLayoutStyle {
        MainToolbarLayoutStyle(rawValue: mainToolbarLayoutStyleRaw) ?? .separated
    }

    var body: some View {
        List {
            Section {
                ForEach(MainToolbarLayoutStyle.allCases, id: \.rawValue) { style in
                    Button {
                        mainToolbarLayoutStyleRaw = style.rawValue
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: style == .groupedCentered ? "capsule" : "rectangle.split.3x1")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(DesignSystem.Color.accent)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(style.rawValue)
                                    .headlineSmall()
                                    .foregroundColor(DesignSystem.Color.textPrimary)

                                Text(style.description)
                                    .captionMedium()
                                    .foregroundColor(DesignSystem.Color.textSecondary)
                            }

                            Spacer()

                            if selectedLayoutStyle == style {
                                Image(systemName: DesignSystem.Icon.checkmarkCircle)
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Custom Floating Toolbar Layout")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Applies to Custom Floating Toolbar only. Grouped keeps controls centered; Separated places filters left and search right.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Toolbar Layout")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct CustomToolbarIconSpacingView: View {
    @AppStorage(CustomToolbarIconSpacing.storageKey) private var customToolbarIconSpacingRaw: String = CustomToolbarIconSpacing.px24.rawValue

    private var selectedSpacing: CustomToolbarIconSpacing {
        CustomToolbarIconSpacing(rawValue: customToolbarIconSpacingRaw) ?? .px24
    }

    private func previewSpacing(for spacing: CustomToolbarIconSpacing) -> CGFloat {
        // Slightly scale spacing down so all options fit in the row preview.
        max(6, spacing.points * 0.65)
    }

    var body: some View {
        List {
            Section {
                ForEach(CustomToolbarIconSpacing.allCases, id: \.rawValue) { spacing in
                    Button {
                        customToolbarIconSpacingRaw = spacing.rawValue
                    } label: {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(spacing.rawValue)
                                        .headlineSmall()
                                        .foregroundColor(DesignSystem.Color.textPrimary)

                                    Text(spacing.description)
                                        .captionMedium()
                                        .foregroundColor(DesignSystem.Color.textSecondary)
                                }

                                Spacer()

                                if selectedSpacing == spacing {
                                    Image(systemName: DesignSystem.Icon.checkmarkCircle)
                                        .foregroundColor(DesignSystem.Color.accent)
                                }
                            }

                            HStack(spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: previewSpacing(for: spacing)) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        Circle()
                                            .fill(.white.opacity(0.92))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .frame(height: 34)
                                .background(.thinMaterial)
                                .clipShape(MinAffordanceStyle.shared.capsuleShape)
                                .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.capsuleShape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }

                                MinAffordanceStyle.shared.circleShape
                                    .fill(.thinMaterial)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: DesignSystem.Icon.search)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(DesignSystem.Color.secondaryAccent ?? DesignSystem.Color.accent)
                                    )
                                    .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.circleShape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Custom Toolbar Icon Spacing")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Applies only to the Custom Floating Toolbar. Each option increases spacing by 4 px.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Toolbar Icon Spacing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct PosterSizePreferenceView: View {
    @AppStorage(PosterSizePreference.storageKey) private var posterSizePreferenceRaw: String = PosterSizePreference.plus60.rawValue
    private let basePosterWidth: CGFloat = 100
    private let basePosterHeight: CGFloat = 150
    private let previewPosterCount = 3
    
    private var selectedSize: PosterSizePreference {
        PosterSizePreference(rawValue: posterSizePreferenceRaw) ?? .plus10
    }
    
    private func previewDimensions(for size: PosterSizePreference) -> CGSize {
        size.dimensions(baseWidth: basePosterWidth, baseHeight: basePosterHeight)
    }
    
    var body: some View {
        List {
            Section {
                ForEach(PosterSizePreference.allCases, id: \.rawValue) { size in
                    Button {
                        posterSizePreferenceRaw = size.rawValue
                    } label: {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(size.rawValue)
                                        .headlineSmall()
                                        .foregroundColor(DesignSystem.Color.textPrimary)
                                    
                                    Text(size.description)
                                        .captionMedium()
                                        .foregroundColor(DesignSystem.Color.textSecondary)
                                }
                                
                                Spacer()
                                
                                if selectedSize == size {
                                    Image(systemName: DesignSystem.Icon.checkmarkCircle)
                                        .foregroundColor(DesignSystem.Color.accent)
                                }
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    ForEach(0..<previewPosterCount, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                            .fill(DesignSystem.Color.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                                    .stroke(DesignSystem.Color.borderLight, lineWidth: 0.5)
                                            )
                                            .frame(
                                                width: previewDimensions(for: size).width,
                                                height: previewDimensions(for: size).height
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Main List Horizontal Collections")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Each option shows one horizontal row preview at that exact poster size. Sizes snap to an 8px grid.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Poster Size")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Loading Screen Style View

struct LoadingScreenStyleView: View {
    @AppStorage(LoadingScreenStyle.storageKey) private var loadingScreenStyleRaw: String = LoadingScreenStyle.skeletonCollections.rawValue
    
    private var selectedStyle: LoadingScreenStyle {
        LoadingScreenStyle(rawValue: loadingScreenStyleRaw) ?? .skeletonCollections
    }
    
    var body: some View {
        List {
            Section {
                ForEach(LoadingScreenStyle.allCases, id: \.rawValue) { style in
                    LoadingScreenStyleRow(
                        style: style,
                        isSelected: selectedStyle == style,
                        onSelect: {
                            loadingScreenStyleRaw = style.rawValue
                        }
                    )
                }
            } header: {
                Text("Select Style")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Changes how the startup loading state appears before your movie catalog is ready.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Loading Screen Style")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct BottomSheetCloseButtonBlurPreferenceView: View {
    @AppStorage(BottomSheetCloseButtonBlurMode.storageKey)
    private var blurModeRaw: String = BottomSheetCloseButtonBlurMode.default.rawValue
    @AppStorage(BottomSheetPresentationStyle.storageKey)
    private var bottomSheetStyleRaw: String = BottomSheetPresentationStyle.defaultStyle.rawValue
    
    var body: some View {
        List {
            Section {
                ForEach(BottomSheetPresentationStyle.allCases, id: \.rawValue) { style in
                    Button {
                        bottomSheetStyleRaw = style.rawValue
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(style.rawValue)
                                    .headlineSmall()
                                    .foregroundColor(DesignSystem.Color.textPrimary)

                                Text(style.description)
                                    .captionMedium()
                                    .foregroundColor(DesignSystem.Color.textSecondary)
                            }

                            Spacer()

                            if bottomSheetStyleRaw == style.rawValue {
                                Image(systemName: DesignSystem.Icon.checkmarkCircle)
                                    .foregroundColor(DesignSystem.Color.accent)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Bottom Sheet Presentation")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Default keeps the current large-sheet style. Full Bleed presents movie details full-screen from the bottom without a top handle.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()

            Section {
                Picker("Close Button Blur", selection: $blurModeRaw) {
                    ForEach(BottomSheetCloseButtonBlurMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue)
                            .lineLimit(2)
                            .minimumScaleFactor(1)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Bottom Sheet Dismiss Button")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            } footer: {
                Text("Choose how much blur is used in the pull-to-dismiss close button.")
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Bottom Sheet Style")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct LoadingScreenStyleRow: View {
    let style: LoadingScreenStyle
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: style.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignSystem.Color.accent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(style.rawValue)
                        .headlineSmall()
                        .foregroundColor(DesignSystem.Color.textPrimary)
                    
                    Text(style.description)
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: DesignSystem.Icon.checkmarkCircle)
                        .foregroundColor(DesignSystem.Color.accent)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}

struct SearchBarAppearanceRow: View {
    let appearance: SearchBarAppearance
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Visual preview
                previewView
                    .frame(width: 80, height: 60)
                
                // Appearance name and description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(appearance.rawValue)
                        .headlineSmall()
                        .foregroundColor(DesignSystem.Color.textPrimary)
                    
                    Text(appearance.description)
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: DesignSystem.Icon.checkmarkCircle)
                        .foregroundColor(DesignSystem.Color.accent)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var previewView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Color.backgroundSecondary)
            
            VStack(spacing: 4) {
                // Mini search bar preview
                HStack(spacing: 4) {
                    Image(systemName: DesignSystem.Icon.search)
                        .font(.system(size: 8))
                        .foregroundColor(iconColorForPreview)
                    Rectangle()
                        .fill(DesignSystem.Color.textSecondary.opacity(0.3))
                        .frame(height: 2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(backgroundForPreview)
                .clipShape(MinAffordanceStyle.shared.capsuleShape)
                .overlay { if MinAffordanceStyle.shared.borderEnabled { overlayForPreview } }
                .shadow(color: shadowColorForPreview, radius: shadowRadiusForPreview, x: 0, y: 2)
                .padding(.horizontal, 8)
                
                // Mini toolbar preview
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 12)
            }
        }
    }
    
    @ViewBuilder
    private var backgroundForPreview: some View {
        switch appearance {
        case .classic:
            Rectangle().fill(.ultraThinMaterial)
        case .solid:
            DesignSystem.Color.cardBackground
        case .elevated:
            Rectangle().fill(.thickMaterial)
        case .glass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        .white.opacity(0.15),
                        .white.opacity(0.05),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    @ViewBuilder
    private var overlayForPreview: some View {
        let s = MinAffordanceStyle.shared.capsuleShape
        switch appearance {
        case .classic:
            s.stroke(DesignSystem.Color.borderLight.opacity(0.6), lineWidth: 0.5)
        case .solid:
            s.stroke(DesignSystem.Color.accent, lineWidth: 1)
        case .elevated:
            s.stroke(DesignSystem.Color.borderLight.opacity(0.8), lineWidth: 0.5)
        case .glass:
            ZStack {
                s.stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
                s.stroke(DesignSystem.Color.borderLight.opacity(0.5), lineWidth: 0.3)
            }
        }
    }
    
    private var iconColorForPreview: SwiftUI.Color {
        switch appearance {
        case .classic, .elevated, .glass:
            return DesignSystem.Color.textSecondary
        case .solid:
            return DesignSystem.Color.accent
        }
    }
    
    private var shadowColorForPreview: SwiftUI.Color {
        switch appearance {
        case .classic:
            return .clear
        case .solid:
            return DesignSystem.Color.accent.opacity(0.2)
        case .elevated:
            return DesignSystem.Shadow.lg.color.opacity(0.4)
        case .glass:
            return DesignSystem.Shadow.md.color.opacity(0.25)
        }
    }
    
    private var shadowRadiusForPreview: CGFloat {
        switch appearance {
        case .classic:
            return 0
        case .solid:
            return 2
        case .elevated:
            return 4
        case .glass:
            return 2
        }
    }
}

// MARK: - Loading Animation Modifiers

struct LoadingPulseModifier: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * 2.4) + 1) / 2
            let opacity = 0.42 + (phase * 0.36)
            content.opacity(opacity)
        }
    }
}

struct LoadingShimmerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let progress = t.truncatingRemainder(dividingBy: 1.8) / 1.8
                        let offset = (progress * (width * 2.2)) - width
                        
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.18),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: width * 0.45)
                        .rotationEffect(.degrees(18))
                        .offset(x: offset)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipped()
    }
}

// MARK: - Conditional Searchable Modifier

struct ConditionalSearchableModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let prompt: String
    
    func body(content: Content) -> some View {
        if isPresented {
            #if os(iOS)
            content
                .searchable(text: $searchText, isPresented: $isPresented, prompt: prompt)
            #else
            content
            #endif
        } else {
            content
        }
    }
}


