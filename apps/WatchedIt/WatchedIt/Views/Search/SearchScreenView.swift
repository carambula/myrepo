//
//  SearchScreenView.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import SwiftUI
import SwiftData
import Combine

struct SearchPresentationContext: Identifiable {
    let id = UUID()
    let title: String
    let restrictedMovieIDs: Set<String>?
    let allowsListFilter: Bool
    let initialQuery: String?
    let initialFilters: MovieSearchFilters?
    let focusSearchOnOpen: Bool
}

struct SearchScreenView: View {
    let context: SearchPresentationContext

    @StateObject private var localDB = LocalDatabaseManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DataSource.name) private var allDataSources: [DataSource]

    @AppStorage(StreamingPreferences.storageKey) private var preferredServicesData: Data = Data()
    @AppStorage(ListPreferences.storageKey) private var preferredListsData: Data = Data()
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.system.rawValue
    @AppStorage(MainToolbarLayoutStyle.storageKey) private var mainToolbarLayoutStyleRaw: String = MainToolbarLayoutStyle.separated.rawValue
    @AppStorage(ToolbarScrollingBehavior.storageKey) private var toolbarBehaviorRaw: String = ToolbarScrollingBehavior.alwaysVisible.rawValue
    @AppStorage(BottomSheetPresentationStyle.storageKey) private var bottomSheetStyleRaw: String = BottomSheetPresentationStyle.defaultStyle.rawValue
    @AppStorage(SearchCloseButtonVisibilityPreference.showOnlyWhenSearchFocusedStorageKey)
    private var showCloseButtonOnlyWhenSearchFocused: Bool = false

    @State private var selectedMovie: Movie? = nil
    @State private var pendingPersonFilter: String? = nil
    @State private var pendingReleaseYearFilter: Int? = nil
    @State private var pendingGenreFilter: String? = nil
    @State private var pendingRatingFilter: String? = nil
    @State private var session: MovieSearchSession? = nil
    @State private var isKeyboardVisible = false
    @State private var forceCompactSearchControls = false
    @StateObject private var toolbarScrollState = ToolbarScrollState()
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.isBottomSheetPullToDismissVisible) private var isPullToDismissVisible
    
    private var toolbarBehavior: ToolbarScrollingBehavior {
        ToolbarScrollingBehavior(rawValue: toolbarBehaviorRaw) ?? .alwaysVisible
    }
    
    private var bottomSheetStyle: BottomSheetPresentationStyle {
        BottomSheetPresentationStyle(rawValue: bottomSheetStyleRaw) ?? .defaultStyle
    }
    private let glassControlHeight: CGFloat = 48
    private let customToolbarHeightBoost: CGFloat = 8
    private let compactExpandedIconSpacing: CGFloat = 24
    private let horizontalToolbarInset: CGFloat = DesignSystem.Spacing.lg

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Color.background
                    .ignoresSafeArea()

                if let session {
                    SearchResultsContent(
                        session: session,
                        context: context,
                        onTapMovie: { movie in
                            selectedMovie = movie
                        },
                        allDataSources: allDataSources,
                        onTapActiveSearchToken: clearActiveSearchToken(_:in:)
                    )
                    .environment(\.preferredSearchStreamingServices, preferredStreamingServices)
                } else {
                    ProgressView("Preparing search…")
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
            }
            .coordinateSpace(name: "searchScrollArea")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                handleScrollOffset(value)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                if let session {
                    dynamicSearchControls(session: session)
                        .opacity(isPullToDismissVisible ? 0 : 1)
                        .offset(y: isPullToDismissVisible ? 120 : 0)
                        .allowsHitTesting(!isPullToDismissVisible)
                        .animation(DesignSystem.Animation.springQuick, value: isPullToDismissVisible)
                }
            }
            .animation(DesignSystem.Animation.springStandard, value: toolbarScrollState.isMinimized)
            .safeAreaInset(edge: .top) {
                persistentSheetHandle
            }
            .modifier(MovieDetailPresentationModifier(
                selectedMovie: $selectedMovie,
                style: bottomSheetStyle,
                onDismiss: {
                    applyPendingPersonSearchFromDetails()
                },
                content: { movie in
                    MovieDetailView(
                        movie: movie,
                        presentationSource: .searchList,
                        onCreditPersonTapped: startPersonSearchFromDetails,
                        onYearTapped: startYearSearchFromDetails,
                        onGenreTapped: startGenreSearchFromDetails,
                        onRatingTapped: startRatingSearchFromDetails
                    )
                }
            ))
            .onAppear {
                if session == nil {
                    rebuildSession(preservingState: false)
                }
                if context.focusSearchOnOpen {
                    forceCompactSearchControls = true
                    Task { @MainActor in
                        await Task.yield()
                        isSearchFieldFocused = true
                    }
                }
            }
            .onChange(of: localDB.movies.count) { _, _ in
                guard localDB.movies.count > 0 else { return }
                rebuildSession(preservingState: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .onChange(of: isSearchFieldFocused) { _, isFocused in
                if !isFocused, !isKeyboardVisible, isSearchQueryEmpty {
                    forceCompactSearchControls = false
                }
            }
            .onChange(of: isKeyboardVisible) { _, visible in
                if !visible, !isSearchFieldFocused, isSearchQueryEmpty {
                    forceCompactSearchControls = false
                }
            }
        }
        .bottomSheetPullToDismiss()
    }

    private func rebuildSession(preservingState: Bool) {
        let previousQuery = preservingState ? session?.query : nil
        let previousFilters = preservingState ? session?.filters : nil

        let newSession = MovieSearchSession(
            title: context.title,
            movies: localDB.movies,
            restrictedMovieIDs: context.restrictedMovieIDs,
            allowsListFilter: context.allowsListFilter,
            modelContext: modelContext,
            preferredStreamingServices: preferredStreamingServices
        )

        if let previousFilters {
            newSession.updateFilters { $0 = previousFilters }
        } else if let initialFilters = context.initialFilters {
            newSession.updateFilters { $0 = initialFilters }
        }
        if let previousQuery, !previousQuery.isEmpty {
            newSession.updateQuery(previousQuery)
        } else if let initialQuery = context.initialQuery, !initialQuery.isEmpty {
            newSession.updateQuery(initialQuery)
        }

        session = newSession
    }

    private func startPersonSearchFromDetails(_ personName: String) {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        pendingReleaseYearFilter = nil
        pendingGenreFilter = nil
        pendingRatingFilter = nil
        pendingPersonFilter = trimmedName
        selectedMovie = nil
    }

    private func startYearSearchFromDetails(_ year: Int) {
        pendingPersonFilter = nil
        pendingReleaseYearFilter = year
        pendingGenreFilter = nil
        pendingRatingFilter = nil
        selectedMovie = nil
    }

    private func startGenreSearchFromDetails(_ genre: String) {
        let trimmedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGenre.isEmpty else { return }
        pendingPersonFilter = nil
        pendingReleaseYearFilter = nil
        pendingRatingFilter = nil
        pendingGenreFilter = trimmedGenre
        selectedMovie = nil
    }

    private func startRatingSearchFromDetails(_ rating: String) {
        let trimmedRating = rating.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRating.isEmpty else { return }
        pendingPersonFilter = nil
        pendingReleaseYearFilter = nil
        pendingGenreFilter = nil
        pendingRatingFilter = trimmedRating
        selectedMovie = nil
    }

    private func applyPendingPersonSearchFromDetails() {
        if let pendingPerson = pendingPersonFilter {
            pendingPersonFilter = nil
            session?.updateQuery("")
            session?.updateFilters {
                $0.selectedPersonName = pendingPerson
                $0.selectedReleaseYear = nil
            }
            return
        }

        if let pendingYear = pendingReleaseYearFilter {
            pendingReleaseYearFilter = nil
            session?.updateQuery("")
            session?.updateFilters {
                $0.selectedReleaseYear = pendingYear
                $0.selectedPersonName = nil
            }
            return
        }

        if let pendingGenre = pendingGenreFilter {
            pendingGenreFilter = nil
            session?.updateQuery("")
            session?.updateFilters {
                $0.selectedGenre = pendingGenre
                $0.selectedMPAARating = nil
            }
            return
        }

        if let pendingRating = pendingRatingFilter {
            pendingRatingFilter = nil
            session?.updateQuery("")
            session?.updateFilters {
                $0.selectedMPAARating = pendingRating
                $0.selectedGenre = nil
            }
            return
        }
    }

    private func handleScrollOffset(_ offset: CGFloat) {
        guard toolbarBehavior != .alwaysVisible else { return }
        toolbarScrollState.updateScroll(offset: offset, threshold: 50)
        
        // Hide keyboard when scrolling down and minimizing
        if toolbarScrollState.isMinimized && isSearchFieldFocused {
            isSearchFieldFocused = false
        }
    }
    
    @ViewBuilder
    private func dynamicSearchControls(session: MovieSearchSession) -> some View {
        switch toolbarBehavior {
        case .alwaysVisible:
            floatingSearchControls(session: session)
        case .minimizeOnScroll:
            minimizingSearchControls(session: session)
        case .minimizeToCorners:
            cornerSearchControls(session: session)
        case .showHide:
            showHideSearchControls(session: session)
        }
    }
    
    private func floatingSearchControls(session: MovieSearchSession) -> some View {
        VStack(spacing: 0) {
            if shouldShowExpandedFilterToolbar(session: session) {
                expandedFilterToolbar(session: session)
            } else {
                compactSearchToolbar(session: session)
            }
        }
    }
    
    @ViewBuilder
    private func minimizingSearchControls(session: MovieSearchSession) -> some View {
        if toolbarScrollState.isMinimized {
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
            .transition(.scale.combined(with: .opacity))
        } else {
            floatingSearchControls(session: session)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private func cornerSearchControls(session: MovieSearchSession) -> some View {
        if toolbarScrollState.isMinimized {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        toolbarScrollState.expand()
                    }
                } label: {
                    GlassCircleButton(systemImage: DesignSystem.Icon.filter, foregroundColor: DesignSystem.Color.accent, accessibilityLabel: "Filters")
                        .shadow(color: DesignSystem.Shadow.sm.color, radius: 4, x: 0, y: 2)
                }
                
                Spacer()

                if shouldShowCloseSearchButton {
                    Button {
                        dismiss()
                    } label: {
                        GlassCircleButton(systemImage: DesignSystem.Icon.close, foregroundColor: DesignSystem.Color.accent, accessibilityLabel: "Close")
                            .shadow(color: DesignSystem.Shadow.sm.color, radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, horizontalToolbarInset)
            .padding(.bottom, DesignSystem.Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            floatingSearchControls(session: session)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private func showHideSearchControls(session: MovieSearchSession) -> some View {
        if !toolbarScrollState.isMinimized {
            floatingSearchControls(session: session)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func shouldShowExpandedFilterToolbar(session: MovieSearchSession) -> Bool {
        session.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSearchFieldFocused
            && !isKeyboardVisible
            && !forceCompactSearchControls
    }

    private func compactSearchToolbar(session: MovieSearchSession) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            SearchFilterMenus(
                filters: Binding(
                    get: { session.filters },
                    set: { newValue in
                        session.updateFilters { filters in
                            filters = newValue
                        }
                    }
                ),
                allowsListFilter: context.allowsListFilter,
                availableGenres: session.availableGenres,
                availableMPAARatings: session.availableMPAARatings,
                availableStreamingServices: session.availableStreamingServices,
                preferredStreamingServices: preferredStreamingServices,
                preferredDataSources: preferredDataSources,
                controlSize: searchControlSize
            )

            SearchInputBar(
                committedText: Binding(
                    get: { session.query },
                    set: { session.updateQuery($0) }
                ),
                placeholder: "Search movies",
                iconColor: searchControlForegroundColor,
                isFocused: $isSearchFieldFocused,
                controlHeight: searchControlSize
            )

            if shouldShowCloseSearchButton {
                closeSearchButton
            }
        }
        .padding(.horizontal, horizontalToolbarInset)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.clear)
    }

    private func expandedFilterToolbar(session: MovieSearchSession) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: compactExpandedIconSpacing) {
                if context.allowsListFilter {
                    Menu {
                        Button {
                            session.updateFilters {
                                $0.selectedListIdentifier = nil
                                $0.sortOption = .episodeDateDesc
                            }
                        } label: {
                            if session.filters.selectedListIdentifier == nil {
                                Label("All Lists", systemImage: "checkmark")
                            } else {
                                Text("All Lists")
                            }
                        }
                        if !preferredDataSources.isEmpty {
                            Divider()
                            ForEach(preferredDataSources) { list in
                                Button {
                                    session.updateFilters {
                                        $0.selectedListIdentifier = list.identifier
                                        if list.isRankedList {
                                            $0.sortOption = .ranking
                                        }
                                    }
                                } label: {
                                    if session.filters.selectedListIdentifier == list.identifier {
                                        Label(list.name, systemImage: "checkmark")
                                    } else {
                                        Text(list.name)
                                    }
                                }
                            }
                        }
                    } label: {
                        toolbarIcon(DesignSystem.Icon.listRectangle, isActive: session.filters.selectedListIdentifier != nil)
                    }
                }

                Menu {
                    Button {
                        session.updateFilters { $0.selectedStreamingService = nil }
                    } label: {
                        if session.filters.selectedStreamingService == nil {
                            Label("All Services", systemImage: DesignSystem.Icon.checkmark)
                        } else {
                            Text("All Services")
                        }
                    }
                    if hasPreferredStreamingServices {
                        Divider()
                        ForEach(preferredStreamingServices, id: \.self) { service in
                            Button {
                                session.updateFilters { $0.selectedStreamingService = service }
                            } label: {
                                if session.filters.selectedStreamingService == service {
                                    Label(service, systemImage: DesignSystem.Icon.checkmark)
                                } else {
                                    Text(service)
                                }
                            }
                        }
                        Divider()
                        Button {
                            session.updateFilters { $0.selectedStreamingService = "My Services" }
                        } label: {
                            if session.filters.selectedStreamingService == "My Services" {
                                Label("My Services", systemImage: DesignSystem.Icon.checkmark)
                            } else {
                                Text("My Services")
                            }
                        }
                    }
                } label: {
                    toolbarIcon("play.square.stack.fill", isActive: session.filters.selectedStreamingService != nil)
                }

                Menu {
                    Button {
                        session.updateFilters { $0.selectedGenre = nil }
                    } label: {
                        if session.filters.selectedGenre == nil {
                            Label("All", systemImage: DesignSystem.Icon.checkmark)
                        } else {
                            Text("All")
                        }
                    }
                    Divider()
                    ForEach(session.availableGenres, id: \.self) { genre in
                        Button {
                            session.updateFilters { $0.selectedGenre = genre }
                        } label: {
                            if session.filters.selectedGenre == genre {
                                Label(genre, systemImage: DesignSystem.Icon.checkmark)
                            } else {
                                Text(genre)
                            }
                        }
                    }
                } label: {
                    toolbarIcon(DesignSystem.Icon.genre, isActive: session.filters.selectedGenre != nil)
                }

                Menu {
                    Section("MPAA Rating") {
                        Button {
                            session.updateFilters { $0.selectedMPAARating = nil }
                        } label: {
                            if session.filters.selectedMPAARating == nil {
                                Label("All Ratings", systemImage: DesignSystem.Icon.checkmark)
                            } else {
                                Text("All Ratings")
                            }
                        }
                        ratingButton("G", session: session)
                        ratingButton("PG", session: session)
                        ratingButton("PG-13", session: session)
                        ratingButton("R", session: session)
                        ratingButton("NC-17", session: session)
                    }
                } label: {
                    toolbarIcon(DesignSystem.Icon.rating, isActive: session.filters.selectedMPAARating != nil)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .frame(height: searchControlSize)
            .background(GlassControl.toolbarMaterial)
            .clipShape(MinAffordanceStyle.shared.capsuleShape)
            .overlay { if MinAffordanceStyle.shared.borderEnabled { MinAffordanceStyle.shared.capsuleShape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }

            if mainToolbarLayoutStyle == .separated {
                Spacer(minLength: DesignSystem.Spacing.sm)
            }

            if shouldShowCloseSearchButton && mainToolbarLayoutStyle == .separated {
                closeSearchButton
            }

            expandedToolbarSearchButton

            if shouldShowCloseSearchButton && mainToolbarLayoutStyle != .separated {
                closeSearchButton
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var expandedToolbarSearchButton: some View {
        Button {
            forceCompactSearchControls = true
            Task { @MainActor in
                await Task.yield()
                isSearchFieldFocused = true
            }
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.search, foregroundColor: searchControlForegroundColor, accessibilityLabel: "Search")
        }
    }

    private func toolbarIcon(_ systemImage: String, isActive: Bool) -> some View {
        DesignSystemIcon(
            systemImage,
            size: DesignSystem.IconSize.md,
            color: isActive ? DesignSystem.Color.accent : searchControlForegroundColor
        )
    }

    private var closeSearchButton: some View {
        Button {
            dismiss()
        } label: {
            GlassCircleButton(systemImage: DesignSystem.Icon.close, foregroundColor: searchControlForegroundColor, accessibilityLabel: "Close Search")
        }
        .buttonStyle(.plain)
    }

    private var shouldShowCloseSearchButton: Bool {
        if showCloseButtonOnlyWhenSearchFocused {
            return isSearchFieldFocused
        }
        return true
    }

    private var usesCustomFloatingToolbar: Bool {
        #if os(iOS)
        return mainListToolbarStyle == .customFloating
        #else
        return false
        #endif
    }

    private var mainListToolbarStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .system
    }

    private var mainToolbarLayoutStyle: MainToolbarLayoutStyle {
        MainToolbarLayoutStyle(rawValue: mainToolbarLayoutStyleRaw) ?? .separated
    }

    private var searchControlSize: CGFloat {
        usesCustomFloatingToolbar ? glassControlHeight + customToolbarHeightBoost : glassControlHeight
    }

    private var toolbarSecondaryAccentColor: Color {
        DesignSystem.Color.secondaryAccent ?? DesignSystem.Color.accent
    }

    private var searchControlForegroundColor: Color {
        usesCustomFloatingToolbar ? toolbarSecondaryAccentColor : DesignSystem.Color.textPrimary
    }

    private var preferredStreamingServices: [String] {
        guard let decoded = try? JSONDecoder().decode([String].self, from: preferredServicesData) else {
            return []
        }
        return decoded
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

    private var hasPreferredStreamingServices: Bool {
        !preferredStreamingServices.isEmpty
    }

    @ViewBuilder
    private func ratingButton(_ rating: String, session: MovieSearchSession) -> some View {
        Button {
            session.updateFilters { $0.selectedMPAARating = rating }
        } label: {
            if session.filters.selectedMPAARating == rating {
                Label(rating, systemImage: "checkmark")
            } else {
                Text(rating)
            }
        }
    }

    private var isSearchQueryEmpty: Bool {
        session?.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private var persistentSheetHandle: some View {
        Capsule()
            .fill(DesignSystem.Color.textSecondary.opacity(0.35))
            .frame(width: BottomSheetHandleStyle.width, height: BottomSheetHandleStyle.height)
            .frame(maxWidth: .infinity)
            .padding(.top, BottomSheetHandleStyle.topPadding)
            .padding(.bottom, BottomSheetHandleStyle.bottomPadding)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        if value.translation.height > 40 {
                            dismiss()
                        }
                    }
            )
    }

    private func clearActiveSearchToken(_ token: ActiveSearchToken, in session: MovieSearchSession) {
        switch token {
        case .collectionScope:
            dismiss()
        case .keyword(let term):
            let originalTerms = session.query
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            var didRemoveTerm = false
            let updatedTerms = originalTerms.filter { current in
                if !didRemoveTerm, current.caseInsensitiveCompare(term) == .orderedSame {
                    didRemoveTerm = true
                    return false
                }
                return true
            }
            session.updateQuery(updatedTerms.joined(separator: " "))
        case .watchFilter:
            session.updateFilters { $0.watchFilter = .all }
        case .genre:
            session.updateFilters { $0.selectedGenre = nil }
        case .mpaaRating:
            session.updateFilters { $0.selectedMPAARating = nil }
        case .person:
            session.updateFilters { $0.selectedPersonName = nil }
        case .releaseYear:
            session.updateFilters { $0.selectedReleaseYear = nil }
        case .list:
            session.updateFilters {
                $0.selectedListIdentifier = nil
                $0.sortOption = .episodeDateDesc
            }
        case .streamingService:
            session.updateFilters { $0.selectedStreamingService = nil }
        }
    }
}

private enum ActiveSearchToken: Identifiable, Hashable {
    case collectionScope
    case keyword(String)
    case watchFilter(WatchFilter)
    case genre(String)
    case mpaaRating(String)
    case person(String)
    case releaseYear(Int)
    case list(String)
    case streamingService(String)

    var id: String {
        switch self {
        case .collectionScope:
            return "collection-scope"
        case .keyword(let term):
            return "keyword:\(term.lowercased())"
        case .watchFilter(let filter):
            return "watch:\(filter.rawValue.lowercased())"
        case .genre(let genre):
            return "genre:\(genre.lowercased())"
        case .mpaaRating(let rating):
            return "mpaa:\(rating.lowercased())"
        case .person(let person):
            return "person:\(person.lowercased())"
        case .releaseYear(let year):
            return "year:\(year)"
        case .list(let identifier):
            return "list:\(identifier.lowercased())"
        case .streamingService(let service):
            return "stream:\(service.lowercased())"
        }
    }
}

private struct ActiveSearchTokenItem: Identifiable {
    let token: ActiveSearchToken
    let label: String

    var id: String { token.id }
}

private struct SearchResultsContent: View {
    @ObservedObject var session: MovieSearchSession
    let context: SearchPresentationContext
    let onTapMovie: (Movie) -> Void
    let allDataSources: [DataSource]
    let onTapActiveSearchToken: (ActiveSearchToken, MovieSearchSession) -> Void
    @Environment(\.preferredSearchStreamingServices) private var preferredStreamingServices

    init(
        session: MovieSearchSession,
        context: SearchPresentationContext,
        onTapMovie: @escaping (Movie) -> Void,
        allDataSources: [DataSource],
        onTapActiveSearchToken: @escaping (ActiveSearchToken, MovieSearchSession) -> Void
    ) {
        self.session = session
        self.context = context
        self.onTapMovie = onTapMovie
        self.allDataSources = allDataSources
        self.onTapActiveSearchToken = onTapActiveSearchToken
    }

    var body: some View {
        VStack(spacing: 0) {
            activeSearchTokensHeader

            ScrollView {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("searchScrollArea")).minY
                    )
                }
                .frame(height: 0)

                if session.results.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("No Results")
                            .headlineSmall()
                            .foregroundColor(DesignSystem.Color.textPrimary)
                        Text("Try a broader search or tap filters above to clear them.")
                            .bodyMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
                } else {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(session.results, id: \.id) { movie in
                            SearchResultRow(
                                movie: movie,
                                preferredStreamingServices: preferredStreamingServices,
                                sourcesAndListsLine: session.sourceLineByMovieID[movie.id]
                            ) {
                                onTapMovie(movie)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.bottomSafeArea)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(nil, value: session.results.count)
        }
    }

    @ViewBuilder
    private var activeSearchTokensHeader: some View {
        if !activeSearchTokens.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(activeSearchTokens.enumerated()), id: \.element.id) { index, item in
                        Button {
                            onTapActiveSearchToken(item.token, session)
                        } label: {
                            Text(item.label)
                                .headlineSmall()
                                .foregroundColor(DesignSystem.Color.accent)
                        }
                        .buttonStyle(.plain)

                        if index < activeSearchTokens.count - 1 {
                            Text("  ")
                                .headlineSmall()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.leading, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }
    
    private var isScopedToCollection: Bool {
        context.restrictedMovieIDs != nil && context.title != "All Movies"
    }
    
    private var activeSearchTokens: [ActiveSearchTokenItem] {
        var items: [ActiveSearchTokenItem] = []
        if isScopedToCollection {
            items.append(ActiveSearchTokenItem(token: .collectionScope, label: context.title))
        }
        let keywordTerms = session.query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        var seenKeywordTerms = Set<String>()
        for term in keywordTerms {
            let normalized = term.lowercased()
            if seenKeywordTerms.insert(normalized).inserted {
                items.append(ActiveSearchTokenItem(token: .keyword(term), label: term))
            }
        }

        let filters = session.filters
        if filters.watchFilter != .all {
            items.append(ActiveSearchTokenItem(token: .watchFilter(filters.watchFilter), label: filters.watchFilter.rawValue))
        }
        if let selectedGenre = filters.selectedGenre, !selectedGenre.isEmpty {
            items.append(ActiveSearchTokenItem(token: .genre(selectedGenre), label: selectedGenre))
        }
        if let selectedRating = filters.selectedMPAARating, !selectedRating.isEmpty {
            items.append(ActiveSearchTokenItem(token: .mpaaRating(selectedRating), label: selectedRating))
        }
        if let selectedPerson = filters.selectedPersonName, !selectedPerson.isEmpty {
            items.append(ActiveSearchTokenItem(token: .person(selectedPerson), label: selectedPerson))
        }
        if let selectedYear = filters.selectedReleaseYear {
            items.append(ActiveSearchTokenItem(token: .releaseYear(selectedYear), label: String(selectedYear)))
        }
        if let selectedListIdentifier = filters.selectedListIdentifier, !selectedListIdentifier.isEmpty {
            let sourceNameByIdentifier = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0.name) })
            let displayName = sourceNameByIdentifier[selectedListIdentifier] ?? selectedListIdentifier
            items.append(ActiveSearchTokenItem(token: .list(selectedListIdentifier), label: displayName))
        }
        if let selectedStreamingService = filters.selectedStreamingService, !selectedStreamingService.isEmpty {
            items.append(ActiveSearchTokenItem(token: .streamingService(selectedStreamingService), label: selectedStreamingService))
        }
        return items
    }
}


private struct SearchResultRow: View {
    let movie: Movie
    let preferredStreamingServices: [String]
    let sourcesAndListsLine: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                if let posterPath = movie.posterPath,
                   let posterURL = MovieDataService.shared.getThumbnailURL(path: posterPath),
                   let url = URL(string: posterURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(DesignSystem.Color.surface)
                    }
                    .frame(width: 50, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                } else {
                    Rectangle()
                        .fill(DesignSystem.Color.surface)
                        .frame(width: 50, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(movie.title)
                        .headlineSmall()
                        .foregroundColor(DesignSystem.Color.textPrimary)
                        .lineLimit(2)

                    Text(primaryMetadataLine)
                        .bodySmall()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .lineLimit(1)

                    if let sourcesAndListsLine, !sourcesAndListsLine.isEmpty {
                        Text(sourcesAndListsLine)
                            .bodySmall()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    if movie.isListened {
                        DesignSystemIcon(DesignSystem.Icon.listenCircleFill, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.accent)
                    }
                    if movie.isRewatched {
                        DesignSystemIcon(DesignSystem.Icon.rewatchCircleFill, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.accent)
                    }
                    if movie.isSaved {
                        DesignSystemIcon(DesignSystem.Icon.bookmarkCircleFill, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.accent)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Color.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        }
        .buttonStyle(.plain)
    }

    private var primaryMetadataLine: String {
        var segments: [String] = []
        if let rating = movie.mpaaRating, !rating.isEmpty {
            segments.append(rating)
        }
        if let year = movie.year {
            segments.append(String(year))
        }
        if !preferredStreamingServicesLine.isEmpty {
            segments.append(preferredStreamingServicesLine)
        }
        return segments.joined(separator: "  ")
    }

    private var preferredStreamingServicesLine: String {
        guard !preferredStreamingServices.isEmpty, !movie.streamingServices.isEmpty else {
            return ""
        }
        var movieServiceByNormalized: [String: String] = [:]
        for service in movie.streamingServices {
            let normalized = normalizedServiceName(service.name)
            if movieServiceByNormalized[normalized] == nil {
                movieServiceByNormalized[normalized] = service.name
            }
        }

        var seen = Set<String>()
        let orderedMatches = preferredStreamingServices.compactMap { preferred -> String? in
            let normalized = normalizedServiceName(preferred)
            guard seen.insert(normalized).inserted else { return nil }
            return movieServiceByNormalized[normalized]
        }
        return orderedMatches.joined(separator: ", ")
    }

    private func normalizedServiceName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct PreferredSearchStreamingServicesKey: EnvironmentKey {
    static let defaultValue: [String] = []
}

private extension EnvironmentValues {
    var preferredSearchStreamingServices: [String] {
        get { self[PreferredSearchStreamingServicesKey.self] }
        set { self[PreferredSearchStreamingServicesKey.self] = newValue }
    }
}
