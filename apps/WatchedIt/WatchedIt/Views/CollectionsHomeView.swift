//
//  CollectionsHomeView.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import SwiftUI
import SwiftData

/// No `@Query` — touching `DataSource` / `SourceContent` while the store is SQLite-corrupt can fatal.
private struct CatalogStoreCorruptionRecoveryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Local database damaged")
                .headlineSmall()
                .foregroundStyle(DesignSystem.Color.accent)

            Text("The movie database file on this device is corrupted (SQLite error 11). WatchedIt cannot safely read it in this session.")
            Text("Quit WatchedIt completely and open it again. On the next launch the app will move the damaged file aside and restore the catalog from the bundled database.")
            #if os(iOS)
            Text("On iPhone: swipe up from the bottom, swipe WatchedIt away, then tap the icon to relaunch.")
            #elseif os(tvOS)
            Text("Press the TV button twice, close WatchedIt, then open it again.")
            #endif
        }
        .foregroundStyle(DesignSystem.Color.textSecondary)
        .font(DesignSystem.Typography.bodySmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
    }
}

private struct CollectionsHomeContentView: View {
    @Binding var deepLinkURL: URL?
    @StateObject private var localDB = LocalDatabaseManager.shared
    @StateObject private var viewModel = CollectionsHomeViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DataSource.name) private var allDataSources: [DataSource]

    @AppStorage(ListPreferences.storageKey) private var preferredListsData: Data = Data()
    @AppStorage(StreamingPreferences.storageKey) private var preferredServicesData: Data = Data()
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.customFloating.rawValue
    @AppStorage(MainToolbarLayoutStyle.storageKey) private var mainToolbarLayoutStyleRaw: String = MainToolbarLayoutStyle.separated.rawValue
    @AppStorage(CustomToolbarIconSpacing.storageKey) private var customToolbarIconSpacingRaw: String = CustomToolbarIconSpacing.px24.rawValue
    @AppStorage(PosterSizePreference.storageKey) private var posterSizePreferenceRaw: String = PosterSizePreference.plus60.rawValue
    @AppStorage(ToolbarScrollingBehavior.storageKey) private var toolbarBehaviorRaw: String = ToolbarScrollingBehavior.alwaysVisible.rawValue
    @AppStorage(BottomSheetPresentationStyle.storageKey) private var bottomSheetStyleRaw: String = BottomSheetPresentationStyle.defaultStyle.rawValue
    @AppStorage("podcast_feed_artwork_cache_v1") private var podcastFeedArtworkCacheData: Data = Data()
    @AppStorage("perf_logging_enabled") private var perfLoggingEnabled = false

    @State private var showAccountSheet = false
    @State private var selectedMovie: Movie? = nil
    @State private var pendingPersonSearchQuery: String? = nil
    @State private var pendingDetailSearchContext: SearchPresentationContext? = nil
    @State private var activeSearchContext: SearchPresentationContext? = nil
    @State private var viewAppearTime: TimeInterval? = nil
    @State private var hasLoggedFirstContentPaint = false
    @State private var podcastFeedArtworkURLs: [String: URL] = [:]
    @State private var hasHydratedPodcastFeedArtworkCache = false
    @State private var isLoadingPodcastFeedArtwork = false
    @State private var podcastFeedArtworkCacheSavedAt: Date? = nil
    @State private var isCommittingPendingPodcastEpisodes = false
    @StateObject private var toolbarScrollState = ToolbarScrollState()
    @State private var titleTypeInitialY: CGFloat? = nil

    private let basePosterWidth: CGFloat = 100
    private let basePosterHeight: CGFloat = 150
    /// Matches main list / `SearchResultsContent` content inset.
    private let inspirationLeadingPadding: CGFloat = DesignSystem.Spacing.screenHorizontalPadding
    private let inspirationPosterSpacing: CGFloat = DesignSystem.Spacing.md
    
    private var bottomSheetStyle: BottomSheetPresentationStyle {
        BottomSheetPresentationStyle(rawValue: bottomSheetStyleRaw) ?? .defaultStyle
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Color.background
                    .ignoresSafeArea()

                if shouldShowLoading {
                    loadingCollectionsView
                } else if viewModel.sections.isEmpty {
                    if shouldShowEmptyState {
                        EmptyStateView(
                            title: "No Collections Yet",
                            description: "Try enabling lists in Account settings."
                        )
                    } else {
                        loadingCollectionsView
                    }
                } else {
                    // Title Type Mark wiring: logo is the first item in the
                    // ScrollView so `.visualEffect` fires during scroll.
                    // `.coordinateSpace(name:)` on the ScrollView must match
                    // the name used inside titleTypeMark's geometry readers.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            titleTypeMark
                                .padding(.horizontal, MinSpacing.TitleType.horizontalPadding)
                                .offset(y: MinSpacing.TitleType.markOffsetY)

                            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                                ForEach(viewModel.sections) { section in
                                    CollectionSectionRow(
                                        section: section,
                                        posterWidth: posterWidth,
                                        posterHeight: posterHeight,
                                        leadingPadding: inspirationLeadingPadding,
                                        posterSpacing: inspirationPosterSpacing,
                                        podcastSourceIDsForMovie: { movie in
                                            podcastSourceIdentifiers(for: movie)
                                        },
                                        artworkURLForSourceID: { sourceID in
                                            podcastFeedArtworkURLs[sourceID.lowercased()]
                                        },
                                        onTapMovie: { selectedMovie = $0 },
                                        onOpenSectionSearch: { tappedSection in
                                            presentScopedSearch(title: tappedSection.title, section: tappedSection)
                                        }
                                    )
                                }
                            }
                            .padding(.top, MinSpacing.TitleType.contentTopSpacing)
                            .padding(.bottom, DesignSystem.Spacing.lg)
                        }
                        .padding(.top, MinSpacing.TitleType.scrollTopPadding)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geometry.frame(in: .named("collectionsHomeScroll")).minY
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "collectionsHomeScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        handleScrollOffset(value)
                    }
                    .scrollIndicators(.hidden)
                    #if os(iOS)
                    .refreshable {
                        await handleMainPagePullToRefresh()
                    }
                    #endif
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                HStack(spacing: MinSpacing.TopControls.horizontalPadding) {
                    Spacer()
                    if pendingPodcastEpisodeCount > 0 {
                        podcastNotificationsMenu
                    }
                    accountButton
                }
                .padding(.horizontal, MinSpacing.lg)
                .padding(.top, MinSpacing.TopControls.verticalPadding)
                .contentShape(Rectangle())
                .allowsHitTesting(true)
            }
            .safeAreaInset(edge: .bottom) {
                dynamicBottomToolbar
            }
            .animation(DesignSystem.Animation.springStandard, value: toolbarScrollState.isMinimized)
            .sheet(isPresented: $showAccountSheet) {
                AccountSheetView()
                    .presentationDragIndicator(.visible)
            }
            .modifier(MovieDetailPresentationModifier(
                selectedMovie: $selectedMovie,
                style: bottomSheetStyle,
                onDismiss: {
                    applyPendingDetailSearchFromDetails()
                    applyPendingPersonSearchFromDetails()
                },
                content: { movie in
                    MovieDetailView(
                        movie: movie,
                        presentationSource: .collections,
                        onCreditPersonTapped: startPersonSearchFromDetails,
                        onYearTapped: startYearSearchFromDetails,
                        onGenreTapped: startGenreSearchFromDetails,
                        onRatingTapped: startRatingSearchFromDetails,
                        onPhysicalMediaTapped: startPhysicalMediaSearchFromDetails,
                        onTheatricalTapped: startTheatricalSearchFromDetails
                    )
                }
            ))
            .sheet(item: $activeSearchContext) { context in
                SearchScreenView(context: context)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                viewAppearTime = ProcessInfo.processInfo.systemUptime
                if localDB.movies.isEmpty && !localDB.isLoading {
                    localDB.loadMovies()
                }
                rebuildSnapshot()
                loadPodcastFeedArtworkIfNeeded()
            }
            .onChange(of: localDB.movies) { _, _ in rebuildSnapshot() }
            .onChange(of: localDB.movieStatusVersion) { _, _ in rebuildSnapshot() }
            .onChange(of: allDataSources.count) { _, _ in
                rebuildSnapshot()
                loadPodcastFeedArtworkIfNeeded()
            }
            .onChange(of: preferredListsData) { _, _ in rebuildSnapshot() }
            .onChange(of: preferredServicesData) { _, _ in rebuildSnapshot() }
            .onChange(of: toolbarBehaviorRaw) { _, _ in
                toolbarScrollState.reset()
            }
            .onChange(of: deepLinkURL) { _, url in
                guard let url else { return }
                deepLinkURL = nil
                guard let deepLink = DeepLinkHandler.parse(url: url) else { return }
                switch deepLink {
                case .movie(let tmdbID):
                    if let movie = localDB.movies.first(where: { $0.tmdbId == tmdbID }) {
                        selectedMovie = movie
                    }
                }
            }
            .onChange(of: viewModel.sections.count) { _, newCount in
                guard perfLoggingEnabled, !hasLoggedFirstContentPaint, newCount > 0 else { return }
                hasLoggedFirstContentPaint = true
                if let viewAppearTime {
                    let elapsedMs = (ProcessInfo.processInfo.systemUptime - viewAppearTime) * 1000
                    print("⏱️ [PERF] [Home] first contentful collections paint: \(String(format: "%.1f", elapsedMs))ms")
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.supportsLightMode ? nil : .dark)
    }

    // MARK: - Title Type Mark (Scroll-Pinned Brand Logo with Blur)
    //
    // Reusable pattern for sister apps (PodLink, Cyclismo, YourTube):
    //
    // HOW IT WORKS
    // The logo lives INSIDE the ScrollView as the first item so that
    // `.visualEffect` receives continuous geometry updates during scroll.
    // `.onGeometryChange` captures the initial Y position on first layout.
    // `.visualEffect` then:
    //   1. Offsets the logo by `drift` (initial - current) to pin it in place.
    //   2. Applies blur and opacity fade proportional to scroll travel.
    // `.zIndex(-1)` keeps it behind subsequent scroll content.
    //
    // SETUP CHECKLIST FOR OTHER APPS
    // 1. Add a `@State private var titleTypeInitialY: CGFloat? = nil` property.
    // 2. Add your brand asset to Assets.xcassets as an image set (SVG works).
    //    Use `.renderingMode(.template)` so `.foregroundStyle()` tints it.
    // 3. Place `titleTypeMark` as the FIRST child of a LazyVStack/VStack
    //    inside a ScrollView.
    // 4. Apply `.coordinateSpace(name: "yourScrollSpace")` to the ScrollView.
    // 5. Match the coordinate space name in `.onGeometryChange` and
    //    `.visualEffect` below.
    // 6. Tune `maxWidth`, `maxHeight`, blur `distance` (80), max `radius` (12),
    //    and `opacity` multiplier (0.5) to taste.
    //
    private var titleTypeMark: some View {
        Image("TitleTypeMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(DesignSystem.Color.headline)
            .frame(maxWidth: MinSpacing.TitleType.maxWidth,
                   maxHeight: MinSpacing.TitleType.maxHeight,
                   alignment: .leading)
            .compositingGroup()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("collectionsHomeScroll")).minY
            } action: { newValue in
                if titleTypeInitialY == nil {
                    titleTypeInitialY = newValue
                }
            }
            .visualEffect { content, proxy in
                let scrollY = proxy.frame(in: .named("collectionsHomeScroll")).minY
                let initial = titleTypeInitialY ?? scrollY
                let drift = initial - scrollY
                let progress = min(max(drift / MinSpacing.TitleType.blurDistance, 0), 1.0)
                return content
                    .offset(y: drift)
                    .blur(radius: progress * MinSpacing.TitleType.maxBlurRadius)
                    .opacity(1.0 - progress * MinSpacing.TitleType.maxOpacityReduction)
            }
            .zIndex(-1)
            .accessibilityHidden(true)
    }

    private var loadingCollectionsView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
                .tint(DesignSystem.Color.textSecondary)
            Text("Loading collections…")
                .headlineSmall()
                .foregroundColor(DesignSystem.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, inspirationLeadingPadding)
    }

    private func handleMainPagePullToRefresh() async {
        if let context = localDB.modelContext {
            _ = await MinCloudCatalogSync.shared.syncIfAvailable(modelContext: context, force: true)
        }
        _ = await localDB.forcePodcastEpisodeIntake(reason: "collections-home-pull-to-refresh")
        rebuildSnapshot()
    }

    private var shouldShowLoading: Bool {
        let awaitingMovies = localDB.movies.isEmpty
            && (localDB.isLoading || !localDB.hasAttemptedInitialLoad)
        let awaitingSnapshot = !localDB.movies.isEmpty
            && viewModel.sections.isEmpty
            && !viewModel.isPrepared
        return awaitingMovies || awaitingSnapshot
    }

    /// Only treat sections as genuinely empty once @Query has delivered data sources.
    /// Without this guard the view flashes "No Collections" while SwiftData's
    /// lazy @Query is still materialising the DataSource rows.
    private var shouldShowEmptyState: Bool {
        viewModel.isPrepared && !allDataSources.isEmpty
    }

    private var mainListToolbarStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .customFloating
    }

    private var customToolbarIconSpacing: CustomToolbarIconSpacing {
        CustomToolbarIconSpacing(rawValue: customToolbarIconSpacingRaw) ?? .px24
    }

    private var mainToolbarLayoutStyle: MainToolbarLayoutStyle {
        MainToolbarLayoutStyle(rawValue: mainToolbarLayoutStyleRaw) ?? .separated
    }

    private var posterSizePreference: PosterSizePreference {
        PosterSizePreference(rawValue: posterSizePreferenceRaw) ?? .plus10
    }

    private var posterWidth: CGFloat {
        posterSizePreference.dimensions(baseWidth: basePosterWidth, baseHeight: basePosterHeight).width
    }

    private var posterHeight: CGFloat {
        posterSizePreference.dimensions(baseWidth: basePosterWidth, baseHeight: basePosterHeight).height
    }

    private var toolbarBehavior: ToolbarScrollingBehavior {
        ToolbarScrollingBehavior(rawValue: toolbarBehaviorRaw) ?? .alwaysVisible
    }

    private var preferredListIdentifiers: [String] {
        let decoded = ListPreferences.decode(from: preferredListsData)
        if decoded.isEmpty && !ListPreferences.hasInitialized() {
            return allDataSources.map(\.identifier)
        }
        return decoded
    }

    private var preferredStreamingServices: [String] {
        StreamingPreferences.decode(from: preferredServicesData)
    }

    private var preferredDataSources: [DataSource] {
        let lookup = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0) })
        return preferredListIdentifiers.compactMap { lookup[$0] }
    }

    private var toolbarSecondaryAccentColor: Color {
        DesignSystem.Color.secondaryAccent ?? DesignSystem.Color.accent
    }

    private var customToolbarControlHeight: CGFloat { GlassControl.standardHeight }

    private var hasPreferredStreamingServices: Bool { !preferredStreamingServices.isEmpty }

    private var allGenres: [String] {
        Array(Set(localDB.movies.flatMap(\.genres))).sorted()
    }

    private var customFloatingBottomToolbar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            GlassCapsuleToolbar(spacing: customToolbarIconSpacing.points, height: customToolbarControlHeight) {
                statusMenu
                listMenu
                if hasPreferredStreamingServices { streamingServiceMenu }
                genreMenu
                ratingMenu
            }

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
        Button(action: { presentGlobalSearch(focusSearchOnOpen: true) }) {
            GlassCircleButton(systemImage: DesignSystem.Icon.search, foregroundColor: toolbarSecondaryAccentColor, accessibilityLabel: "Search")
        }
    }

    @ViewBuilder
    private var dynamicBottomToolbar: some View {
        switch toolbarBehavior {
        case .alwaysVisible:
            customFloatingBottomToolbar
        case .minimizeOnScroll:
            minimizingToolbarLayout
        case .minimizeToCorners:
            cornerToolbarLayout
        case .showHide:
            showHideToolbarLayout
        }
    }

    @ViewBuilder
    private var minimizingToolbarLayout: some View {
        if toolbarScrollState.isMinimized {
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
            .transition(.scale.combined(with: .opacity))
        } else {
            customFloatingBottomToolbar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var cornerToolbarLayout: some View {
        if toolbarScrollState.isMinimized {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        toolbarScrollState.expand()
                    }
                } label: {
                    GlassCircleButton(systemImage: DesignSystem.Icon.filter, foregroundColor: DesignSystem.Color.accent, accessibilityLabel: "Filters")
                }

                Spacer()

                Button(action: { presentGlobalSearch(focusSearchOnOpen: true) }) {
                    GlassCircleButton(systemImage: DesignSystem.Icon.search, foregroundColor: toolbarSecondaryAccentColor, accessibilityLabel: "Search")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            customFloatingBottomToolbar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var showHideToolbarLayout: some View {
        if !toolbarScrollState.isMinimized {
            customFloatingBottomToolbar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var pendingPodcastEpisodeCount: Int {
        localDB.pendingPodcastEpisodeCount
    }

    private func handleScrollOffset(_ offset: CGFloat) {
        guard toolbarBehavior != .alwaysVisible else { return }
        toolbarScrollState.updateScroll(offset: offset, threshold: 50)
    }

    private var podcastNotificationsMenu: some View {
        Menu {
            Button {
                guard !isCommittingPendingPodcastEpisodes else { return }
                Task { @MainActor in
                    isCommittingPendingPodcastEpisodes = true
                    _ = await localDB.commitPendingPodcastEpisodes()
                    rebuildSnapshot()
                    isCommittingPendingPodcastEpisodes = false
                }
            } label: {
                if isCommittingPendingPodcastEpisodes {
                    Text("Adding new episodes…")
                } else {
                    Text("New episodes available, tap to add")
                }
            }
            .disabled(isCommittingPendingPodcastEpisodes)
        } label: {
            GlassCircleButton(systemImage: "bell.fill", foregroundColor: toolbarSecondaryAccentColor, accessibilityLabel: "Notifications")
        }
    }

    private var accountButton: some View {
        Button {
            showAccountSheet = true
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.account, foregroundColor: toolbarSecondaryAccentColor, accessibilityLabel: "Account")
        }
    }

    private var statusMenu: some View {
        Menu {
            ForEach(WatchFilter.allCases, id: \.self) { filter in
                Button {
                    applyStatusFilterFromToolbar(filter)
                } label: {
                    Label(filter.rawValue, systemImage: filter.systemImage)
                }
            }
        } label: {
            DesignSystemIcon(DesignSystem.Icon.status, size: DesignSystem.IconSize.md, color: toolbarSecondaryAccentColor)
        }
        .accessibilityLabel("Status filter")
    }

    private var listMenu: some View {
        Menu {
            Button("All Lists") { applyListFilterFromToolbar(nil) }
            if !preferredDataSources.isEmpty {
                Divider()
                ForEach(preferredDataSources) { list in
                    Button(list.name) { applyListFilterFromToolbar(list) }
                }
            }
        } label: {
            DesignSystemIcon(DesignSystem.Icon.listRectangle, size: DesignSystem.IconSize.md, color: toolbarSecondaryAccentColor)
        }
    }

    private var streamingServiceMenu: some View {
        Menu {
            Button("All Services") { applyStreamingServiceFilterFromToolbar(nil) }
            Divider()
            ForEach(preferredStreamingServices, id: \.self) { service in
                Button(service) { applyStreamingServiceFilterFromToolbar(service) }
            }
            Divider()
            Button("My Services") { applyStreamingServiceFilterFromToolbar("My Services") }
        } label: {
            DesignSystemIcon("play.square.stack.fill", size: DesignSystem.IconSize.md, color: toolbarSecondaryAccentColor)
        }
    }

    private var genreMenu: some View {
        Menu {
            Button("All") { applyGenreFilterFromToolbar(nil) }
            Divider()
            ForEach(allGenres, id: \.self) { genre in
                Button(genre) { applyGenreFilterFromToolbar(genre) }
            }
        } label: {
            DesignSystemIcon(DesignSystem.Icon.genre, size: DesignSystem.IconSize.md, color: toolbarSecondaryAccentColor)
        }
    }

    private var ratingMenu: some View {
        Menu {
            Button("All Ratings") { applyRatingFilterFromToolbar(nil) }
            Button("G") { applyRatingFilterFromToolbar("G") }
            Button("PG") { applyRatingFilterFromToolbar("PG") }
            Button("PG-13") { applyRatingFilterFromToolbar("PG-13") }
            Button("R") { applyRatingFilterFromToolbar("R") }
            Button("NC-17") { applyRatingFilterFromToolbar("NC-17") }
        } label: {
            DesignSystemIcon(DesignSystem.Icon.rating, size: DesignSystem.IconSize.md, color: toolbarSecondaryAccentColor)
        }
    }

    private func rebuildSnapshot() {
        viewModel.rebuildIfNeeded(
            movies: localDB.movies,
            dataSources: allDataSources,
            preferredListIdentifiers: preferredListIdentifiers,
            preferredStreamingServices: preferredStreamingServices,
            modelContext: modelContext
        )
    }

    private func presentGlobalSearch(initialFilters: MovieSearchFilters? = nil, focusSearchOnOpen: Bool = false) {
        activeSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: nil,
            initialFilters: initialFilters,
            focusSearchOnOpen: focusSearchOnOpen
        )
    }

    private func startPersonSearchFromDetails(_ personName: String) {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
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

    private func startTheatricalSearchFromDetails(_ filter: TheatricalFilter) {
        pendingPersonSearchQuery = nil
        var filters = MovieSearchFilters()
        filters.theatricalFilter = filter
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

    private func startPhysicalMediaSearchFromDetails(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingPersonSearchQuery = nil
        pendingDetailSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: trimmed,
            initialFilters: MovieSearchFilters(),
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

    private func applyPendingDetailSearchFromDetails() {
        guard let pendingContext = pendingDetailSearchContext else { return }
        pendingDetailSearchContext = nil
        pendingPersonSearchQuery = nil
        activeSearchContext = pendingContext
    }

    private func applyPendingPersonSearchFromDetails() {
        guard let pendingQuery = pendingPersonSearchQuery else { return }
        pendingPersonSearchQuery = nil
        activeSearchContext = SearchPresentationContext(
            title: "All Movies",
            restrictedMovieIDs: nil,
            allowsListFilter: true,
            initialQuery: pendingQuery,
            initialFilters: nil,
            focusSearchOnOpen: false
        )
    }

    private func presentScopedSearch(title: String, section: CollectionSection) {
        let ids = MovieQueryService.movieIdentifiers(for: section)
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

    private func applyStatusFilterFromToolbar(_ filter: WatchFilter) {
        var filters = MovieSearchFilters()
        filters.watchFilter = filter
        presentGlobalSearch(initialFilters: filters)
    }

    private func applyGenreFilterFromToolbar(_ genre: String?) {
        var filters = MovieSearchFilters()
        filters.selectedGenre = genre
        presentGlobalSearch(initialFilters: filters)
    }

    private func applyRatingFilterFromToolbar(_ rating: String?) {
        var filters = MovieSearchFilters()
        filters.selectedMPAARating = rating
        presentGlobalSearch(initialFilters: filters)
    }

    private func applyListFilterFromToolbar(_ list: DataSource?) {
        var filters = MovieSearchFilters()
        filters.selectedListIdentifier = list?.identifier
        if list?.isRankedList == true { filters.sortOption = .ranking }
        presentGlobalSearch(initialFilters: filters)
    }

    private func applyStreamingServiceFilterFromToolbar(_ service: String?) {
        var filters = MovieSearchFilters()
        filters.selectedStreamingService = service
        presentGlobalSearch(initialFilters: filters)
    }

    private var enabledPodcastSourceIds: Set<String> {
        let preferredSet = Set(preferredListIdentifiers)
        return Set(allDataSources.filter {
            $0.type == "podcast" && $0.isEnabled && preferredSet.contains($0.identifier)
        }.map(\.identifier))
    }

    private func podcastSourceIdentifiers(for movie: Movie) -> [String] {
        let sourceIDs = viewModel.movieToSourceIdentifiers[movie.id] ?? []
        let podcastIDs = sourceIDs.filter { enabledPodcastSourceIds.contains($0) }
        guard !podcastIDs.isEmpty else { return [] }
        let orderedPreferred = preferredListIdentifiers.filter { podcastIDs.contains($0) }
        let preferredSet = Set(orderedPreferred)
        let remaining = podcastIDs.filter { !preferredSet.contains($0) }.sorted()
        return orderedPreferred + remaining
    }

    private struct PodcastFeedArtworkCacheSnapshot: Codable {
        let savedAt: Date
        let urls: [String: String]
    }

    private func hydratePodcastFeedArtworkCacheIfNeeded() {
        guard !hasHydratedPodcastFeedArtworkCache else { return }
        hasHydratedPodcastFeedArtworkCache = true
        guard !podcastFeedArtworkCacheData.isEmpty,
              let snapshot = try? JSONDecoder().decode(PodcastFeedArtworkCacheSnapshot.self, from: podcastFeedArtworkCacheData) else {
            return
        }
        podcastFeedArtworkURLs = Dictionary(uniqueKeysWithValues: snapshot.urls.compactMap { key, urlString in
            guard let url = URL(string: urlString) else { return nil }
            return (key, url)
        })
        podcastFeedArtworkCacheSavedAt = snapshot.savedAt
    }

    private func shouldRefreshPodcastFeedArtworkCache() -> Bool {
        guard let savedAt = podcastFeedArtworkCacheSavedAt else { return true }
        return Date().timeIntervalSince(savedAt) > (60 * 60 * 24 * 14)
    }

    private func persistPodcastFeedArtworkCache() {
        let snapshot = PodcastFeedArtworkCacheSnapshot(
            savedAt: Date(),
            urls: Dictionary(uniqueKeysWithValues: podcastFeedArtworkURLs.map { ($0.key, $0.value.absoluteString) })
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        podcastFeedArtworkCacheData = data
        podcastFeedArtworkCacheSavedAt = snapshot.savedAt
    }

    private func loadPodcastFeedArtworkIfNeeded() {
        hydratePodcastFeedArtworkCacheIfNeeded()
        guard !isLoadingPodcastFeedArtwork else { return }
        let podcastSources = allDataSources.filter {
            $0.type == "podcast" && !(($0.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        guard !podcastSources.isEmpty else { return }
        let shouldRefreshAll = shouldRefreshPodcastFeedArtworkCache()
        let missingSources = podcastSources.filter { source in
            let sourceID = source.identifier.lowercased()
            return shouldRefreshAll || podcastFeedArtworkURLs[sourceID] == nil
        }
        guard !missingSources.isEmpty else { return }
        isLoadingPodcastFeedArtwork = true
        Task.detached {
            var resolvedURLs: [String: URL] = [:]
            await withTaskGroup(of: (String, URL?).self) { group in
                for source in missingSources {
                    let sourceID = source.identifier.lowercased()
                    let feedURLString = source.url ?? ""
                    group.addTask {
                        (sourceID, await fetchPodcastArtworkURL(feedURLString: feedURLString))
                    }
                }
                for await (sourceID, url) in group {
                    if let url {
                        resolvedURLs[sourceID] = url
                    }
                }
            }
            await MainActor.run {
                podcastFeedArtworkURLs.merge(resolvedURLs) { _, new in new }
                persistPodcastFeedArtworkCache()
                isLoadingPodcastFeedArtwork = false
            }
        }
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
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
        if let urlString = firstCapture(in: xml, pattern: "<itunes:image[^>]*href=[\"']([^\"']+)[\"']"),
           let url = URL(string: urlString) {
            return url
        }
        if let urlString = firstCapture(in: xml, pattern: "<image>[\\s\\S]*?<url>([^<]+)</url>[\\s\\S]*?</image>"),
           let url = URL(string: urlString) {
            return url
        }
        return nil
    }
}

private struct CollectionSectionRow: View {
    let section: CollectionSection
    let posterWidth: CGFloat
    let posterHeight: CGFloat
    let leadingPadding: CGFloat
    let posterSpacing: CGFloat
    let podcastSourceIDsForMovie: (Movie) -> [String]
    let artworkURLForSourceID: (String) -> URL?
    let onTapMovie: (Movie) -> Void
    let onOpenSectionSearch: (CollectionSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Button(action: { onOpenSectionSearch(section) }) {
                            Text(section.title)
                                .headlineSmall()
                                .foregroundColor(DesignSystem.Color.textPrimary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minWidth: geometry.size.width, alignment: .leading)
                    .padding(.horizontal, leadingPadding)
                }
            }
            .frame(height: 28)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: posterSpacing) {
                    ForEach(section.movies, id: \.id) { movie in
                        CollectionMovieCard(
                            movie: movie,
                            posterWidth: posterWidth,
                            posterHeight: posterHeight,
                            podcastSourceIDs: podcastSourceIDsForMovie(movie),
                            artworkURLForSourceID: artworkURLForSourceID,
                            onTap: { onTapMovie(movie) }
                        )
                    }
                }
                .padding(.horizontal, leadingPadding)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

private struct CollectionMovieCard: View {
    let movie: Movie
    let posterWidth: CGFloat
    let posterHeight: CGFloat
    let podcastSourceIDs: [String]
    let artworkURLForSourceID: (String) -> URL?
    let onTap: () -> Void
    
    @AppStorage("tapInteractionStyle") private var tapStyleRaw: String = TapInteractionStyle.bounce.rawValue
    @AppStorage(TapInteractionParameters.storageKey) private var parametersData: Data = TapInteractionParameters().encode()
    @AppStorage(PosterSizePreference.storageKey) private var posterSizePreferenceRaw: String = PosterSizePreference.plus60.rawValue
    
    private var tapStyle: TapInteractionStyle {
        TapInteractionStyle(rawValue: tapStyleRaw) ?? .bounce
    }
    
    private var tapParameters: TapInteractionParameters {
        TapInteractionParameters.decode(from: parametersData)
    }
    
    private var posterSizePreference: PosterSizePreference {
        PosterSizePreference(rawValue: posterSizePreferenceRaw) ?? .plus10
    }

    var body: some View {
        Button(action: onTap) {
            posterView
        }
        .interactiveTapStyle(
            style: tapStyle,
            parameters: tapParameters,
            accentColor: DesignSystem.Color.accent
        )
    }

    @ViewBuilder
    private var posterView: some View {
        if let posterPath = movie.posterPath,
           let posterURL = MovieDataService.shared.getPosterURL(path: posterPath, size: posterSizePreference.optimalImageSize),
           let url = URL(string: posterURL) {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(DesignSystem.Color.surface)
            }
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
            .overlay(alignment: .bottomLeading) { badgeStack }
        } else {
            Rectangle()
                .fill(DesignSystem.Color.surface)
                .frame(width: posterWidth, height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
                .overlay(DesignSystemIcon(DesignSystem.Icon.movie, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textSecondary))
                .overlay(alignment: .bottomLeading) { badgeStack }
        }
    }

    @ViewBuilder
    private var badgeStack: some View {
        let uniqueIDs = uniqueIdsPreservingOrder(podcastSourceIDs)
        if !uniqueIDs.isEmpty {
            HStack(spacing: -16) {
                ForEach(Array(uniqueIDs.prefix(4)), id: \.self) { sourceID in
                    Group {
                        if let artworkURL = artworkURLForSourceID(sourceID) {
                            CachedAsyncImage(url: artworkURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile).fill(.ultraThinMaterial)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                                        .stroke(GlassControl.Border.card.color, lineWidth: GlassControl.Border.card.width)
                                )
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
                }
            }
            .padding(.leading, 4)
            .padding(.bottom, 4)
        }
    }

    private func uniqueIdsPreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }
}

struct CollectionsHomeView: View {
    @Binding var deepLinkURL: URL?
    @StateObject private var localDB = LocalDatabaseManager.shared

    var body: some View {
        Group {
            if localDB.catalogNeedsRestartDueToCorruption {
                CatalogStoreCorruptionRecoveryView()
            } else {
                CollectionsHomeContentView(deepLinkURL: $deepLinkURL)
            }
        }
    }
}
