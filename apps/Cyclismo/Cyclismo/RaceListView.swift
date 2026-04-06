import SwiftUI

enum SearchBarAppearance: String, CaseIterable {
    case classic = "Classic"
    case solid = "Solid"
    case elevated = "Elevated"
    case glass = "Glass"

    static var storageKey: String { "searchBarAppearance" }
}

enum MainListToolbarStyle: String, CaseIterable {
    case system = "System Toolbar"
    case customFloating = "Custom Floating Toolbar"

    static var storageKey: String { "mainListToolbarStyle" }
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

    var points: CGFloat {
        switch self {
        case .px8: return 8
        case .px12: return 12
        case .px16: return 16
        case .px20: return 20
        case .px24: return 24
        case .px28: return 28
        case .px32: return 32
        case .px36: return 36
        }
    }

    static var storageKey: String { "customToolbarIconSpacing" }
}

enum CalendarRaceDisplayStyle: String, CaseIterable, Identifiable {
    case `default` = "default"
    case raceNameOverlay = "raceNameOverlay"
    case fullOverlay = "fullOverlay"
    case boldOverlay = "boldOverlay"

    static var storageKey: String { "calendarRaceDisplayStyle" }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .raceNameOverlay:
            return "Race Name Overlay"
        case .fullOverlay:
            return "Full Overlay"
        case .boldOverlay:
            return "Bold Overlay"
        }
    }

    var description: String {
        switch self {
        case .default:
            return "Text above image"
        case .raceNameOverlay:
            return "16:9 image, race name overlaid"
        case .fullOverlay:
            return "4:3 image with full bottom overlay"
        case .boldOverlay:
            return "3:1 image with centered title"
        }
    }

    var imageAspectRatio: CGFloat {
        switch self {
        case .default:
            return 16.0 / 9.0
        case .raceNameOverlay:
            return 16.0 / 9.0
        case .fullOverlay:
            return 4.0 / 3.0
        case .boldOverlay:
            return 3.0 / 1.0
        }
    }
}

enum CalendarRaceMetadataPreference {
    static let showStageTypeKey = "calendarRaceShowStageTypeMetadata"
    static let showTimeAndStreamersKey = "calendarRaceShowTimeAndStreamersMetadata"
    static let showCategoryKey = "calendarRaceShowCategoryMetadata"
}

struct RaceListView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var races: [Race] = []
    @State private var searchText = ""
    @State private var isBottomSearchVisible = false
    @State private var isLoading = false
    @State private var filters = RaceFilters()
    @State private var selectedColloquialCategory: String?
    @State private var errorMessage: String?
    @State private var streamers: [Streamer] = []
    @State private var filterOptions: (classifications: [String], formats: [String], genders: [String]) = ([], [], [])
    @State private var raceIdToStreamerNames: [String: [String]] = [:]
    @State private var raceIdToFeaturedPodcastSlugs: [String: [String]] = [:]
    @State private var raceIdToCalendarStageTypeByDate: [String: [String: String]] = [:]
    @State private var featuredPodcastSourceIdBySlug: [String: String] = [:]
    @State private var featuredPodcastArtworkBySlug: [String: URL] = [:]
    @State private var selectedRace: Race?
    @State private var isShowingAccount = false
    @State private var podcastMappingTask: Task<Void, Never>?
    @State private var titleTypeInitialY: CGFloat? = nil
    @FocusState private var isBottomSearchFocused: Bool
    @AppStorage(SearchBarAppearance.storageKey) private var searchBarAppearanceRaw: String = SearchBarAppearance.classic.rawValue
    @AppStorage(MainListToolbarStyle.storageKey) private var mainListToolbarStyleRaw: String = MainListToolbarStyle.customFloating.rawValue
    @AppStorage(CustomToolbarIconSpacing.storageKey) private var customToolbarIconSpacingRaw: String = CustomToolbarIconSpacing.px12.rawValue
    @AppStorage(CalendarRaceDisplayStyle.storageKey) private var calendarRaceDisplayStyleRaw: String = CalendarRaceDisplayStyle.boldOverlay.rawValue
    @AppStorage(CalendarRaceMetadataPreference.showStageTypeKey) private var calendarRaceShowStageTypeMetadata: Bool = true
    @AppStorage(CalendarRaceMetadataPreference.showTimeAndStreamersKey) private var calendarRaceShowTimeAndStreamersMetadata: Bool = true
    @AppStorage(CalendarRaceMetadataPreference.showCategoryKey) private var calendarRaceShowCategoryMetadata: Bool = true
    private let glassControlHeight: CGFloat = 48
    private let customToolbarHeightBoost: CGFloat = 8
    private let featuredPodcastSlugs = ["how-the-race-was-won", "lanterne-rouge", "lanterne-rouge-youtube", "wheel-talk"]
    private let featuredPodcastArtworkFallbackBySlug: [String: String] = [
        "how-the-race-was-won": "https://is1-ssl.mzstatic.com/image/thumb/Podcasts221/v4/f2/8a/0b/f28a0b21-780e-c7d5-e6c0-9294759b50c5/mza_17796115950916795261.jpg/600x600bb.jpg",
        "lanterne-rouge-youtube": "https://www.youtube.com/s/desktop/8d6df9de/img/favicon_144x144.png"
    ]
    private let maxPodcastMappingRaceCount = 80
    private let raceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let monthSectionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let calendarDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let calendarWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let localClockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var searchBarAppearance: SearchBarAppearance {
        SearchBarAppearance(rawValue: searchBarAppearanceRaw) ?? .classic
    }

    private var mainListToolbarStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .customFloating
    }

    private var customToolbarIconSpacing: CustomToolbarIconSpacing {
        CustomToolbarIconSpacing(rawValue: customToolbarIconSpacingRaw) ?? .px12
    }

    private var calendarRaceDisplayStyle: CalendarRaceDisplayStyle {
        CalendarRaceDisplayStyle(rawValue: calendarRaceDisplayStyleRaw) ?? .boldOverlay
    }

    private var usesCustomFloatingToolbar: Bool {
        #if os(iOS)
        return mainListToolbarStyle == .customFloating
        #else
        return false
        #endif
    }

    private var customToolbarControlHeight: CGFloat {
        glassControlHeight + customToolbarHeightBoost
    }

    private var todayString: String {
        ISO8601DateFormatter().string(from: Date()).prefix(10).description
    }

    private var localTodayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private var thirtyDaysAgoString: String {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return ISO8601DateFormatter().string(from: thirtyDaysAgo).prefix(10).description
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                titleTypeMark
                    .padding(.horizontal, MinSpacing.TitleType.horizontalPadding)
                    .offset(y: MinSpacing.TitleType.markOffsetY)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    listContent
                }
                .padding(.top, MinSpacing.TitleType.contentTopSpacing)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .padding(.top, MinSpacing.TitleType.scrollTopPadding)
        }
        .coordinateSpace(name: "raceListScroll")
        .id("race-list-\(themeManager.currentTheme.name)")
        .background(DesignSystem.Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            if !usesCustomFloatingToolbar && !isBottomSearchVisible {
                bottomToolbar
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: MinSpacing.TopControls.horizontalPadding) {
                Spacer()
                accountToolbarButton
            }
            .padding(.horizontal, MinSpacing.lg)
            .padding(.top, MinSpacing.TopControls.verticalPadding)
            .padding(.bottom, MinSpacing.TopControls.verticalPadding)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .zIndex(100)
        }
        #if os(iOS)
        .toolbar(isBottomSearchVisible ? .hidden : .visible, for: .bottomBar)
        .toolbarBackground(usesCustomFloatingToolbar ? .hidden : .visible, for: .bottomBar)
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if usesCustomFloatingToolbar {
                if isBottomSearchVisible {
                    bottomSearchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    customFloatingBottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else if isBottomSearchVisible {
                bottomSearchBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DesignSystem.Animation.springStandard, value: isBottomSearchVisible)
        .onAppear {
            Task {
                await loadFilterOptions()
                await loadPodcastSources()
                await loadRaces()
                raceIdToStreamerNames = await BootstrapDataStore.shared.fetchRaceIdToStreamerNames()
            }
        }
        .onDisappear {
            podcastMappingTask?.cancel()
            podcastMappingTask = nil
        }
        .onChange(of: filters) { _, _ in
            Task { await loadRaces() }
        }
        .refreshable {
            APIClient.shared.clearCache()
            await loadFilterOptions()
            await loadPodcastSources()
            await loadRaces()
            raceIdToStreamerNames = await BootstrapDataStore.shared.fetchRaceIdToStreamerNames()
        }
        .alert("Unable to load races", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $selectedRace) { race in
            RaceDetailView(race: race)
        }
        .sheet(isPresented: $isShowingAccount) {
            AccountSheetView()
        }
        .onChange(of: isBottomSearchVisible) { _, newValue in
            if newValue {
                isBottomSearchFocused = true
            } else {
                isBottomSearchFocused = false
                searchText = ""
            }
        }
        .themeBackground()
    }

    @ViewBuilder
    private var listContent: some View {
        if isLoading {
            loadingState
                .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            if !recentRaces.isEmpty {
                recentSection
            }
            if !currentAndUpcomingEntries.isEmpty {
                remainingSection
            }
        }
    }

    private var loadingState: some View {
        MinMainAppLoadingView()
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Recent Races")
                .headlineMedium()
                .foregroundHeadline()
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                    ForEach(recentRaces) { race in
                        Button {
                            selectedRace = race
                        } label: {
                            upcomingRaceCard(race: race)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
        }
    }

    private var remainingSection: some View {
        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(monthGroupedCurrentAndUpcomingRaces) { section in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(section.title)
                        .headlineSmall()
                        .foregroundHeadline()
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.top, DesignSystem.Spacing.xs)

                    ForEach(section.days) { day in
                        calendarDayRow(day)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            categoryMenu
            formatMenu
            streamerMenu
            sortMenu
            Spacer()
            if !isBottomSearchVisible {
                searchButton
            }
        }
    }

    private var customFloatingFilterGroup: some View {
        let aff = MinAffordanceStyle.shared
        return HStack(spacing: customToolbarIconSpacing.points) {
            categoryMenu
            formatMenu
            streamerMenu
            sortMenu
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .frame(height: customToolbarControlHeight)
        .background(.thinMaterial)
        .clipShape(aff.capsuleShape)
        .overlay { if aff.borderEnabled { aff.capsuleShape.stroke(.white.opacity(0.28), lineWidth: 0.8) } }
        .shadow(color: searchFieldShadowColor, radius: searchFieldShadowRadius, x: 0, y: searchFieldShadowY)
    }

    private var customFloatingBottomToolbar: some View {
        HStack(spacing: 0) {
            customFloatingFilterGroup
            Spacer(minLength: DesignSystem.Spacing.sm)

            Button(action: {
                withAnimation(DesignSystem.Animation.springStandard) {
                    isBottomSearchVisible = true
                }
            }) {
                customFloatingSearchControlButton(
                    systemImage: DesignSystem.Icon.search,
                    foregroundColor: toolbarSecondaryAccentColor,
                    accessibilityLabel: "Search"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var categoryMenu: some View {
        Menu {
            Button {
                filters.classification = nil
            } label: {
                if filters.classification == nil {
                    Label("All", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("All")
                }
            }
            ForEach(filterOptions.classifications, id: \.self) { c in
                Button {
                    filters.classification = c
                } label: {
                    if filters.classification == c {
                        Label(c, systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Text(c)
                    }
                }
            }
        } label: {
            DesignSystemIcon(
                DesignSystem.Icon.category,
                size: DesignSystem.IconSize.md,
                color: toolbarIconColor(isActive: filters.classification != nil)
            )
        }
        .accessibilityLabel("Category")
    }

    private var formatMenu: some View {
        Menu {
            Section {
                Button {
                    setRaceTypeFilter(nil)
                    selectedColloquialCategory = nil
                } label: {
                    if filters.raceType == nil && selectedColloquialCategory == nil {
                        Label("All", systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Text("All")
                    }
                }
                ForEach(filterOptions.formats, id: \.self) { format in
                    Button {
                        setRaceTypeFilter(format)
                    } label: {
                        if filters.raceType == format && selectedColloquialCategory == nil {
                            Label(format, systemImage: DesignSystem.Icon.checkmark)
                        } else {
                            Text(format)
                        }
                    }
                }
            } header: {
                Text("Race format")
            }
            if !availableColloquialCategories.isEmpty {
                Section {
                    ForEach(availableColloquialCategories, id: \.self) { category in
                        Button {
                            setColloquialCategoryFilter(category)
                        } label: {
                            if selectedColloquialCategory == category {
                                Label(category, systemImage: DesignSystem.Icon.checkmark)
                            } else {
                                Text(category)
                            }
                        }
                    }
                } header: {
                    Text("Colloquial category")
                }
            }
        } label: {
            DesignSystemIcon(
                DesignSystem.Icon.format,
                size: DesignSystem.IconSize.md,
                color: toolbarIconColor(isActive: filters.raceType != nil || selectedColloquialCategory != nil)
            )
        }
        .accessibilityLabel("Format")
    }

    private var streamerMenu: some View {
        Menu {
            Button {
                filters.streamerId = nil
            } label: {
                if filters.streamerId == nil {
                    Label("All", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("All")
                }
            }
            ForEach(streamers) { s in
                Button {
                    filters.streamerId = s.streamerId
                } label: {
                    if filters.streamerId == s.streamerId {
                        Label(s.name, systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Text(s.name)
                    }
                }
            }
        } label: {
            DesignSystemIcon(
                DesignSystem.Icon.streamer,
                size: DesignSystem.IconSize.md,
                color: toolbarIconColor(isActive: filters.streamerId != nil)
            )
        }
        .accessibilityLabel("Streamer")
    }

    private var sortMenu: some View {
        Menu {
            Button {
                filters.sortOrder = .date
            } label: {
                if filters.sortOrder == .date {
                    Label("Date", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("Date")
                }
            }
            Button {
                filters.sortOrder = .alphabetical
            } label: {
                if filters.sortOrder == .alphabetical {
                    Label("Alphabetical", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("Alphabetical")
                }
            }
        } label: {
            DesignSystemIcon(
                DesignSystem.Icon.sort,
                size: DesignSystem.IconSize.md,
                color: toolbarIconColor(isActive: filters.sortOrder != .date)
            )
        }
    }

    private var searchButton: some View {
        Button {
            withAnimation(DesignSystem.Animation.springStandard) {
                isBottomSearchVisible = true
            }
        } label: {
            glassIconButton(systemImage: DesignSystem.Icon.search, accessibilityLabel: "Search")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
    }

    private var titleTypeMark: some View {
        Image("Title Type")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(DesignSystem.Color.accent)
            .frame(maxWidth: MinSpacing.TitleType.maxWidth,
                   maxHeight: MinSpacing.TitleType.maxHeight,
                   alignment: .leading)
            .compositingGroup()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("raceListScroll")).minY
            } action: { newValue in
                if titleTypeInitialY == nil {
                    titleTypeInitialY = newValue
                }
            }
            .visualEffect { content, proxy in
                let scrollY = proxy.frame(in: .named("raceListScroll")).minY
                let initial = titleTypeInitialY ?? scrollY
                let drift = initial - scrollY
                let progress = min(max(drift / MinSpacing.TitleType.blurDistance, 0), 1.0)
                return content
                    .offset(y: drift)
                    .blur(radius: progress * MinSpacing.TitleType.maxBlurRadius)
                    .opacity(1.0 - progress * MinSpacing.TitleType.maxOpacityReduction)
            }
            .zIndex(-1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var accountToolbarButton: some View {
        Button {
            isShowingAccount = true
        } label: {
            customFloatingSearchControlButton(
                systemImage: DesignSystem.Icon.personCircle,
                foregroundColor: toolbarSecondaryAccentColor,
                accessibilityLabel: "Account"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account")
    }

    private var bottomSearchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button(action: {
                withAnimation(DesignSystem.Animation.springStandard) {
                    isBottomSearchVisible = false
                }
            }) {
                closeButtonForAppearance
            }
            .buttonStyle(.plain)

            searchFiltersMenu
            searchFieldContainer
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, searchBarBottomPadding)
    }

    private var hasActiveSearchFilterControls: Bool {
        filters.classification != nil
            || filters.raceType != nil
            || selectedColloquialCategory != nil
            || filters.streamerId != nil
            || filters.sortOrder != .date
    }

    private var searchFilterButtonColor: SwiftUI.Color {
        hasActiveSearchFilterControls ? DesignSystem.Color.accent : toolbarSecondaryAccentColor
    }

    private var searchFiltersMenu: some View {
        Menu {
            Menu {
                categoryMenuContent
            } label: {
                Label("Category", systemImage: DesignSystem.Icon.category)
            }
            Menu {
                formatMenuContent
            } label: {
                Label("Format", systemImage: DesignSystem.Icon.format)
            }
            Menu {
                streamerMenuContent
            } label: {
                Label("Streamer", systemImage: DesignSystem.Icon.streamer)
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
    private var categoryMenuContent: some View {
        Button {
            filters.classification = nil
        } label: {
            if filters.classification == nil {
                Label("All", systemImage: DesignSystem.Icon.checkmark)
            } else {
                Text("All")
            }
        }
        ForEach(filterOptions.classifications, id: \.self) { classification in
            Button {
                filters.classification = classification
            } label: {
                if filters.classification == classification {
                    Label(classification, systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text(classification)
                }
            }
        }
    }

    @ViewBuilder
    private var formatMenuContent: some View {
        Section {
            Button {
                setRaceTypeFilter(nil)
                selectedColloquialCategory = nil
            } label: {
                if filters.raceType == nil && selectedColloquialCategory == nil {
                    Label("All", systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text("All")
                }
            }
            ForEach(filterOptions.formats, id: \.self) { format in
                Button {
                    setRaceTypeFilter(format)
                } label: {
                    if filters.raceType == format && selectedColloquialCategory == nil {
                        Label(format, systemImage: DesignSystem.Icon.checkmark)
                    } else {
                        Text(format)
                    }
                }
            }
        } header: {
            Text("Race format")
        }
        if !availableColloquialCategories.isEmpty {
            Section {
                ForEach(availableColloquialCategories, id: \.self) { category in
                    Button {
                        setColloquialCategoryFilter(category)
                    } label: {
                        if selectedColloquialCategory == category {
                            Label(category, systemImage: DesignSystem.Icon.checkmark)
                        } else {
                            Text(category)
                        }
                    }
                }
            } header: {
                Text("Colloquial category")
            }
        }
    }

    @ViewBuilder
    private var streamerMenuContent: some View {
        Button {
            filters.streamerId = nil
        } label: {
            if filters.streamerId == nil {
                Label("All", systemImage: DesignSystem.Icon.checkmark)
            } else {
                Text("All")
            }
        }
        ForEach(streamers) { streamer in
            Button {
                filters.streamerId = streamer.streamerId
            } label: {
                if filters.streamerId == streamer.streamerId {
                    Label(streamer.name, systemImage: DesignSystem.Icon.checkmark)
                } else {
                    Text(streamer.name)
                }
            }
        }
    }

    @ViewBuilder
    private var sortMenuContent: some View {
        Button {
            filters.sortOrder = .date
        } label: {
            if filters.sortOrder == .date {
                Label("Date", systemImage: DesignSystem.Icon.checkmark)
            } else {
                Text("Date")
            }
        }
        Button {
            filters.sortOrder = .alphabetical
        } label: {
            if filters.sortOrder == .alphabetical {
                Label("Alphabetical", systemImage: DesignSystem.Icon.checkmark)
            } else {
                Text("Alphabetical")
            }
        }
    }

    @ViewBuilder
    private var filterButtonForAppearance: some View {
        if usesCustomFloatingToolbar {
            customFloatingSearchControlButton(
                systemImage: DesignSystem.Icon.filter,
                foregroundColor: searchFilterButtonColor,
                accessibilityLabel: "Filters"
            )
        } else {
            switch searchBarAppearance {
            case .classic, .elevated:
                glassIconButton(
                    systemImage: DesignSystem.Icon.filter,
                    foregroundColor: searchFilterButtonColor,
                    accessibilityLabel: "Filters"
                )
            case .solid:
                solidIconButton(
                    systemImage: DesignSystem.Icon.filter,
                    foregroundColor: searchFilterButtonColor,
                    accessibilityLabel: "Filters"
                )
            case .glass:
                enhancedGlassIconButton(
                    systemImage: DesignSystem.Icon.filter,
                    foregroundColor: searchFilterButtonColor,
                    accessibilityLabel: "Filters"
                )
            }
        }
    }

    private var searchFieldContainer: some View {
        let aff = MinAffordanceStyle.shared
        return HStack(spacing: DesignSystem.Spacing.sm) {
            DesignSystemIcon(DesignSystem.Icon.search, size: DesignSystem.IconSize.sm, color: searchIconColor)
            TextField("Search races", text: $searchText)
                .focused($isBottomSearchFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
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
        glassIconButton(systemImage: DesignSystem.Icon.close, accessibilityLabel: "Close")
    }

    private func customFloatingSearchControlButton(
        systemImage: String,
        foregroundColor: SwiftUI.Color = DesignSystem.Color.textPrimary,
        accessibilityLabel: String
    ) -> some View {
        let aff = MinAffordanceStyle.shared
        return Label(accessibilityLabel, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: customToolbarControlHeight, height: customToolbarControlHeight)
            .foregroundStyle(foregroundColor)
            .background(.thinMaterial)
            .clipShape(aff.circleShape)
            .overlay { if aff.borderEnabled { aff.circleShape.stroke(.white.opacity(0.28), lineWidth: 0.8) } }
            .shadow(color: searchFieldShadowColor, radius: searchFieldShadowRadius, x: 0, y: searchFieldShadowY)
    }

    private func solidIconButton(
        systemImage: String,
        foregroundColor: SwiftUI.Color = DesignSystem.Color.textPrimary,
        accessibilityLabel: String
    ) -> some View {
        let aff = MinAffordanceStyle.shared
        return Label(accessibilityLabel, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: glassControlHeight, height: glassControlHeight)
            .foregroundStyle(foregroundColor)
            .background(DesignSystem.Color.accent)
            .clipShape(aff.circleShape)
            .overlay { if aff.borderEnabled { aff.circleShape.stroke(MinAffordanceStyle.borderColor, lineWidth: MinAffordanceStyle.borderLineWidth) } }
            .shadow(color: DesignSystem.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private func enhancedGlassIconButton(
        systemImage: String,
        foregroundColor: SwiftUI.Color = DesignSystem.Color.textPrimary,
        accessibilityLabel: String
    ) -> some View {
        let aff = MinAffordanceStyle.shared
        return Label(accessibilityLabel, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: glassControlHeight, height: glassControlHeight)
            .foregroundStyle(foregroundColor)
            .background(
                ZStack {
                    aff.circleShape.fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [
                            .white.opacity(0.2),
                            .white.opacity(0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(aff.circleShape)
                }
            )
            .overlay {
                if aff.borderEnabled {
                    aff.circleShape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
            }
            .overlay { if aff.borderEnabled { aff.circleShape.stroke(DesignSystem.Color.borderLight.opacity(0.5), lineWidth: 0.5) } }
            .shadow(color: DesignSystem.Shadow.md.color.opacity(0.3), radius: 6, x: 0, y: 3)
    }

    private func glassToolbarItem<Content: View>(isEmphasized: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        let aff = MinAffordanceStyle.shared
        return content()
            .frame(height: glassControlHeight)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(aff.capsuleShape)
            .overlay { if aff.borderEnabled { aff.capsuleShape.stroke(DesignSystem.Color.borderLight.opacity(isEmphasized ? 0.7 : 0.4), lineWidth: 0.5) } }
            .shadow(color: DesignSystem.Shadow.lg.color.opacity(isEmphasized ? 0.8 : 0.6), radius: isEmphasized ? 12 : 10, x: 0, y: isEmphasized ? 6 : 5)
    }

    private func glassIconButton(
        systemImage: String,
        foregroundColor: SwiftUI.Color = DesignSystem.Color.textPrimary,
        accessibilityLabel: String
    ) -> some View {
        glassToolbarItem(isEmphasized: true) {
            Label(accessibilityLabel, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: glassControlHeight)
                .foregroundStyle(foregroundColor)
                .clipShape(MinAffordanceStyle.shared.circleShape)
        }
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

    private var sortedFilteredRaces: [Race] {
        let typeFilteredRaces = races.filter { race in
            guard let selectedColloquialCategory else {
                return true
            }
            return race.displayColloquialCategories.contains {
                $0.caseInsensitiveCompare(selectedColloquialCategory) == .orderedSame
            }
        }

        guard !searchText.isEmpty else { return typeFilteredRaces }
        return typeFilteredRaces.filter { race in
            race.name.localizedCaseInsensitiveContains(searchText)
                || (race.locationCity?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (race.locationCountry?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var upcomingRaces: [Race] {
        sortedFilteredRaces.filter { race in
            race.endDate >= localTodayString
        }
            .sorted { $0.startDate < $1.startDate }
    }

    private var recentRaces: [Race] {
        sortedFilteredRaces
            .filter { race in
                race.endDate < todayString && race.endDate >= thirtyDaysAgoString
            }
            .sorted { $0.endDate > $1.endDate }
    }

    private var currentAndUpcomingEntries: [CalendarRaceEntry] {
        upcomingRaces
            .flatMap { race in
                calendarDisplayDates(for: race).map { displayDate in
                    CalendarRaceEntry(race: race, displayDate: displayDate)
                }
            }
            .sorted { lhs, rhs in
                if lhs.displayDate == rhs.displayDate {
                    if lhs.race.startDate == rhs.race.startDate {
                        return lhs.race.name < rhs.race.name
                    }
                    return lhs.race.startDate < rhs.race.startDate
                }
                return lhs.displayDate < rhs.displayDate
            }
    }

    private var monthGroupedCurrentAndUpcomingRaces: [RaceMonthSection] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let groupedByMonth = Dictionary(grouping: currentAndUpcomingEntries) { entry in
            guard
                let startDate = raceDateFormatter.date(from: entry.displayDate),
                let monthStart = calendar.dateInterval(of: .month, for: startDate)?.start
            else {
                return entry.displayDate
            }
            return raceDateFormatter.string(from: monthStart)
        }

        return groupedByMonth
            .map { monthKey, races in
                let title: String
                if let monthDate = raceDateFormatter.date(from: monthKey) {
                    title = monthSectionFormatter.string(from: monthDate)
                } else {
                    title = "TBD"
                }

                let groupedByDay = Dictionary(grouping: races) { entry in
                    entry.displayDate
                }
                let days = groupedByDay
                    .map { dayKey, dayEntries in
                        RaceDaySection(
                            dayKey: dayKey,
                            entries: dayEntries.sorted {
                                if $0.race.startDate == $1.race.startDate {
                                    return $0.race.name < $1.race.name
                                }
                                return $0.race.startDate < $1.race.startDate
                            }
                        )
                    }
                    .sorted { $0.dayKey < $1.dayKey }

                return RaceMonthSection(
                    monthKey: monthKey,
                    title: title,
                    days: days
                )
            }
            .sorted { $0.monthKey < $1.monthKey }
    }

    private func dateAndStreamerText(for race: Race) -> String {
        let base = race.formattedStartDate
        let names = streamerNames(for: race)
        let streamerText = names.isEmpty ? nil : names.joined(separator: ", ")
        let categoryText = primaryColloquialCategory(for: race)
        let statusTag = currentRaceStatusTag(for: race)

        var components: [String] = [base]
        if let categoryText {
            components.append(categoryText)
        }
        if let streamerText {
            components.append(streamerText)
        }
        if let statusTag {
            components.append(statusTag)
        }

        return components.joined(separator: "   ")
    }

    @ViewBuilder
    private func upcomingRaceCard(race: Race) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let urlString = race.effectiveImageUrl, let url = URL(string: urlString) {
                BlurredAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .raceImageTwoTone()
                } placeholder: {
                    Rectangle()
                        .fill(DesignSystem.Color.surface)
                        .overlay { ProgressView() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 200)
                .aspectRatio(CalendarRaceDisplayStyle.default.imageAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
                .overlay(alignment: .topLeading) {
                    if isRaceLive(race) {
                        Text("LIVE")
                            .captionMedium()
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Color.error)
                            .clipShape(Capsule())
                            .padding(DesignSystem.Spacing.sm)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    podcastBadgeStack(for: race)
                        .padding(.leading, 6)
                        .padding(.bottom, 6)
                }
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(race.name)
                    .headlineSmall()
                    .foregroundHeadline()
                    .lineLimit(2)
                Text(dateAndStreamerText(for: race))
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Color.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .frame(width: 200)
    }

    @ViewBuilder
    private func calendarDayRow(_ day: RaceDaySection) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                if let dayDate = day.date {
                    Text(calendarDayFormatter.string(from: dayDate))
                        .headlineSmall()
                        .foregroundHeadline()
                    Text(calendarWeekdayFormatter.string(from: dayDate).uppercased())
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                } else {
                    Text("TBD")
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
            }
            .frame(width: 44, alignment: .leading)
            .padding(.top, DesignSystem.Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        selectedRace = entry.race
                    } label: {
                        raceRowContent(race: entry.race, displayDate: entry.displayDate)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DesignSystem.Spacing.xs)
                            .padding(.bottom, DesignSystem.Spacing.sm)
                    }
                    .buttonStyle(.plain)

                    if index < day.entries.count - 1 {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Color.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    @ViewBuilder
    private func raceRowContent(race: Race, displayDate: String) -> some View {
        switch calendarRaceDisplayStyle {
        case .default:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(race.name)
                    .headlineSmall()
                    .foregroundHeadline()

                raceRowMetadataStack(race: race, displayDate: displayDate)

                raceRowImage(race: race, aspectRatio: calendarRaceDisplayStyle.imageAspectRatio)
            }
        case .raceNameOverlay:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                raceRowImage(race: race, aspectRatio: calendarRaceDisplayStyle.imageAspectRatio) {
                    overlayProtectionLayer
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                        Text(race.name)
                            .headlineSmall()
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.bottom, DesignSystem.Spacing.sm)
                    }
                }

                raceRowMetadataStack(race: race, displayDate: displayDate)
            }
        case .fullOverlay:
            raceRowImage(race: race, aspectRatio: calendarRaceDisplayStyle.imageAspectRatio) {
                overlayProtectionLayer
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Spacer()
                    Text(race.name)
                        .headlineSmall()
                        .foregroundColor(.white)
                        .lineLimit(2)
                    raceRowMetadataStack(race: race, displayDate: displayDate, foregroundColor: .white)
                }
                .padding(DesignSystem.Spacing.sm)
            }
        case .boldOverlay:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                raceRowImage(race: race, aspectRatio: calendarRaceDisplayStyle.imageAspectRatio) {
                    Text(race.name.uppercased())
                        .font(.system(size: 20, weight: .black, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                }

                raceRowMetadataStack(race: race, displayDate: displayDate)
            }
        }
    }

    @ViewBuilder
    private func raceRowImage(race: Race, aspectRatio: CGFloat) -> some View {
        raceRowImage(race: race, aspectRatio: aspectRatio) { EmptyView() }
    }

    @ViewBuilder
    private func raceRowImage<Overlay: View>(
        race: Race,
        aspectRatio: CGFloat,
        @ViewBuilder overlayContent: () -> Overlay
    ) -> some View {
        if let urlString = race.effectiveImageUrl, let url = URL(string: urlString) {
            // Size the row slot with outer aspect ratio; inner image uses scaledToFill (cover)
            // so the slot stays full without weak proposals inside CachedAsyncImage shrinking it.
            BlurredAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .raceImageTwoTone()
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .fill(DesignSystem.Color.surface)
                    .overlay { ProgressView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
            .overlay {
                overlayContent()
            }
            .overlay(alignment: .topLeading) {
                podcastBadgeStack(for: race)
                    .padding(.leading, 6)
                    .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func raceRowMetadataStack(
        race: Race,
        displayDate: String,
        foregroundColor: SwiftUI.Color = DesignSystem.Color.textSecondary
    ) -> some View {
        if calendarRaceShowStageTypeMetadata, let stageLine = raceCalendarStageTypeText(for: race, displayDate: displayDate) {
            Text(stageLine)
                .captionMedium()
                .foregroundColor(foregroundColor)
        }

        if calendarRaceShowTimeAndStreamersMetadata, let timeStreamerLine = raceRowTimeAndStreamerText(for: race) {
            Text(timeStreamerLine)
                .captionMedium()
                .foregroundColor(foregroundColor)
        }

        if calendarRaceShowCategoryMetadata, let categoryLine = primaryColloquialCategory(for: race) {
            Text(categoryLine)
                .captionMedium()
                .foregroundColor(foregroundColor)
                .lineLimit(1)
        }
    }

    private var overlayProtectionLayer: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.35),
                        .black.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func parsedRaceStartDate(for race: Race) -> Date? {
        raceDateFormatter.date(from: effectiveCalendarDateString(for: race))
    }

    private func effectiveCalendarDateString(for race: Race) -> String {
        isRaceOnLocalToday(race) ? localTodayString : race.startDate
    }

    private func isRaceOnLocalToday(_ race: Race) -> Bool {
        race.startDate <= localTodayString && race.endDate >= localTodayString
    }

    private func raceRowTimeAndStreamerText(for race: Race) -> String? {
        var components: [String] = []

        if let timeText = raceStartTimeText(for: race) {
            components.append(timeText)
        }

        let names = streamerNames(for: race)
        if !names.isEmpty {
            components.append(names.joined(separator: ", "))
        }

        return components.isEmpty ? nil : components.joined(separator: "   ")
    }

    private func primaryColloquialCategory(for race: Race) -> String? {
        if let colloquial = race.primaryDisplayColloquialCategory, !colloquial.isEmpty {
            return colloquial
        }
        if let classification = race.classification, !classification.isEmpty {
            return classification
        }
        if !race.raceType.isEmpty {
            return race.raceType
        }
        return race.discipline.isEmpty ? nil : race.discipline
    }

    private var availableColloquialCategories: [String] {
        Array(
            Set(
                races
                    .flatMap(\.displayColloquialCategories)
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    private func setRaceTypeFilter(_ value: String?) {
        selectedColloquialCategory = nil
        filters.raceType = value
    }

    private func setColloquialCategoryFilter(_ value: String?) {
        filters.raceType = nil
        selectedColloquialCategory = value
    }

    private func raceCalendarStageTypeText(for race: Race, displayDate: String) -> String? {
        raceIdToCalendarStageTypeByDate[race.raceId]?[displayDate]
    }

    nonisolated private static func calendarStageTypeText(stages: [Stage], for displayDate: String) -> String? {
        let candidates = stages.filter { stage in
            guard !stage.isRestDay else { return false }
            return stage.date == displayDate
        }
        guard let stage = candidates.sorted(by: stageSortComparator).first else {
            return nil
        }
        let type = stage.stageType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parcoursText = type.flatMap(Self.normalizedParcoursLabel(for:))

        if let stageNumber = stage.stageNumber {
            if let parcoursText {
                return "Stage \(stageNumber), \(parcoursText)"
            }
            return "Stage \(stageNumber)"
        }
        return parcoursText
    }

    nonisolated private static func stageSortComparator(_ lhs: Stage, _ rhs: Stage) -> Bool {
        let leftNumber = lhs.stageNumber ?? Int.max
        let rightNumber = rhs.stageNumber ?? Int.max
        if leftNumber != rightNumber {
            return leftNumber < rightNumber
        }
        return lhs.name < rhs.name
    }

    nonisolated private static func normalizedParcoursLabel(for rawType: String) -> String? {
        let trimmed = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased().replacingOccurrences(of: "_", with: " ")
        switch normalized {
        case "itt", "tt", "time trial":
            return "Individual Time Trial Parcours"
        case "ttt", "team tt":
            return "Team Time Trial Parcours"
        case "flat", "sprint", "desert sprint", "sprint finale", "champs-elysees", "madrid finale":
            return "Sprint Parcours"
        case "rolling", "hilly", "circuit", "gravel":
            return "Rolling Parcours"
        case "mountain",
             "medium mountain",
             "short mountain",
             "summit",
             "summit finish",
             "alpine",
             "queen stage",
             "mountain (jebel jais)",
             "mountain (jebel hafeet)":
            return "Mountain Parcours"
        default:
            if normalized.hasPrefix("mountain") || normalized.hasPrefix("summit") {
                return "Mountain Parcours"
            }
            if normalized.hasSuffix("parcours") {
                return trimmed
            }
            return "\(trimmed) Parcours"
        }
    }

    private func raceStartTimeText(for race: Race) -> String? {
        if let localDate = raceStartDateInLocalTime(for: race) {
            let localTime = localClockFormatter.string(from: localDate)
            let timezoneName = TimeZone.current.localizedName(for: .shortGeneric, locale: Locale.current)
                ?? TimeZone.current.abbreviation(for: localDate)
                ?? TimeZone.current.identifier
            return "\(localTime) \(timezoneName)"
        }

        guard let rawTime = race.startTimeLocal?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTime.isEmpty else {
            return nil
        }

        let formattedTime = formattedRaceStartTime(rawTime) ?? rawTime
        if let timezoneLabel = raceTimezoneLabel(for: race) {
            return "\(formattedTime) \(timezoneLabel)"
        }
        return formattedTime
    }

    private func raceStartDateInLocalTime(for race: Race) -> Date? {
        if let startDatetimeUtc = race.startDatetimeUtc,
           let utcDate = parseISODate(startDatetimeUtc) {
            return utcDate
        }

        guard
            let dateComponents = parsedRaceDateComponents(race.startDate),
            let timeComponents = parsedRaceTimeComponents(race.startTimeLocal)
        else {
            return nil
        }

        var combined = DateComponents()
        combined.calendar = Calendar(identifier: .gregorian)
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        combined.timeZone = raceTimezone(for: race) ?? TimeZone.current
        return combined.date
    }

    private func parsedRaceDateComponents(_ rawDate: String) -> DateComponents? {
        let parts = rawDate.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return components
    }

    private func parsedRaceTimeComponents(_ rawTime: String?) -> DateComponents? {
        guard let rawTime, !rawTime.isEmpty else { return nil }
        let normalized = rawTime.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains(":") {
            let pieces = normalized.split(separator: ":").map(String.init)
            guard pieces.count == 2 || pieces.count == 3 else { return nil }
            guard let hour = Int(pieces[0]), let minute = Int(pieces[1]) else { return nil }
            let second = pieces.count == 3 ? (Int(pieces[2]) ?? 0) : 0
            guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
                return nil
            }
            var result = DateComponents()
            result.hour = hour
            result.minute = minute
            result.second = second
            return result
        }

        if normalized.count == 4, let value = Int(normalized) {
            let hour = value / 100
            let minute = value % 100
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            var result = DateComponents()
            result.hour = hour
            result.minute = minute
            result.second = 0
            return result
        }
        return nil
    }

    private func parseISODate(_ value: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) {
            return date
        }
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: value)
    }

    private func formattedRaceStartTime(_ rawTime: String) -> String? {
        let inputFormats = ["HH:mm:ss", "HH:mm", "H:mm", "HHmm"]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.timeZone = TimeZone(secondsFromGMT: 0)
        output.dateFormat = "h:mm a"

        for format in inputFormats {
            parser.dateFormat = format
            if let date = parser.date(from: rawTime) {
                return output.string(from: date)
            }
        }
        return nil
    }

    private func raceTimezoneLabel(for race: Race) -> String? {
        guard let rawTimezone = race.startTimezone?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTimezone.isEmpty else {
            return nil
        }

        let referenceDate = parsedRaceStartDate(for: race) ?? Date()
        if let timezone = raceTimezone(for: race) {
            return timezone.abbreviation(for: referenceDate) ?? timezone.identifier
        }
        return rawTimezone
    }

    private func raceTimezone(for race: Race) -> TimeZone? {
        guard let rawTimezone = race.startTimezone?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTimezone.isEmpty else {
            return nil
        }
        if let timezone = TimeZone(identifier: rawTimezone) {
            return timezone
        }
        if let timezone = TimeZone(abbreviation: rawTimezone.uppercased()) {
            return timezone
        }
        return nil
    }

    private func isRaceLive(_ race: Race) -> Bool {
        isRaceCurrent(race) && hasStreamerCoverage(race)
    }

    private func isRaceCurrent(_ race: Race) -> Bool {
        race.startDate <= todayString && race.endDate >= todayString
    }

    private func hasStreamerCoverage(_ race: Race) -> Bool {
        streamerNames(for: race).isEmpty == false
    }

    private func currentRaceStatusTag(for race: Race) -> String? {
        guard isRaceCurrent(race) else { return nil }
        return hasStreamerCoverage(race) ? "(live)" : "(today)"
    }

    private func streamerNames(for race: Race) -> [String] {
        let explicit = raceIdToStreamerNames[race.raceId] ?? []
        if !explicit.isEmpty {
            return explicit
        }
        return StreamerFallback.inferredDisplayNames(for: race.name)
    }

    private func loadFilterOptions() async {
        streamers = await BootstrapDataStore.shared.fetchStreamers()
        filterOptions = await BootstrapDataStore.shared.fetchFilterOptions()
    }

    private func loadRaces() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var requestFilters = filters
            if requestFilters.startDate == nil {
                requestFilters.startDate = thirtyDaysAgoString
            }
            let fetchedRaces = try await APIClient.shared.fetchRaces(filters: requestFilters)
            races = fetchedRaces
            podcastMappingTask?.cancel()
            podcastMappingTask = Task {
                let cappedRaces = Array(fetchedRaces.prefix(maxPodcastMappingRaceCount))
                await loadRacePodcastMappings(for: cappedRaces)
            }
        } catch {
            errorMessage = "Please check that the API is running."
        }
    }

    private func loadPodcastSources() async {
        let sources = await BootstrapDataStore.shared.fetchPodcastSources()
        let featuredSources = sources.filter { featuredPodcastSlugs.contains($0.slug) }
        featuredPodcastSourceIdBySlug = Dictionary(uniqueKeysWithValues: featuredSources.map { ($0.slug, $0.sourceId.lowercased()) })

        let artworkURLs = await PodcastEpisodeFeedService.shared.fetchArtworkURLs(for: featuredSources)
        var artworkBySlug: [String: URL] = [:]
        for source in featuredSources {
            if let url = artworkURLs[source.sourceId.lowercased()] {
                artworkBySlug[source.slug] = url
            } else if let fallback = featuredPodcastArtworkFallbackBySlug[source.slug], let fallbackURL = URL(string: fallback) {
                artworkBySlug[source.slug] = fallbackURL
            }
        }
        featuredPodcastArtworkBySlug = artworkBySlug
    }

    private func loadRacePodcastMappings(for sourceRaces: [Race]) async {
        let raceIds = sourceRaces.map(\.raceId)
        guard !raceIds.isEmpty else {
            raceIdToFeaturedPodcastSlugs = [:]
            raceIdToCalendarStageTypeByDate = [:]
            return
        }
        let raceById = Dictionary(uniqueKeysWithValues: sourceRaces.map { ($0.raceId, $0) })
        let featuredSourceIdBySlug = featuredPodcastSourceIdBySlug
        let featuredSlugs = featuredPodcastSlugs
        let dataStore = BootstrapDataStore.shared

        let results = await withTaskGroup(of: (String, [String], [String: String]).self) { group in
            for raceId in raceIds {
                group.addTask {
                    if Task.isCancelled { return (raceId, [], [:]) }
                    let race = raceById[raceId]
                    let stages = await dataStore.fetchRaceStages(
                        raceId: raceId,
                        raceName: race?.name,
                        raceStartDate: race?.startDate
                    )
                    let uniqueStageDates = Array(Set(stages.compactMap(\.date))).sorted()
                    var stageTypesByDate: [String: String] = [:]
                    for date in uniqueStageDates {
                        if let text = Self.calendarStageTypeText(stages: stages, for: date) {
                            stageTypesByDate[date] = text
                        }
                    }

                    let sourceIds: [String]
                    if !stages.isEmpty {
                        let stageIdsForDate = stages.map(\.stageId)

                        if stageIdsForDate.isEmpty {
                            sourceIds = []
                        } else {
                            sourceIds = await withTaskGroup(of: [String].self) { stageGroup in
                                for stageId in stageIdsForDate {
                                    stageGroup.addTask {
                                        if Task.isCancelled { return [] }
                                        let links = await dataStore.fetchStagePodcasts(stageId: stageId)
                                        return links.map { $0.sourceId.lowercased() }
                                    }
                                }
                                var collected: [String] = []
                                for await ids in stageGroup {
                                    collected.append(contentsOf: ids)
                                }
                                return collected
                            }
                        }
                    } else {
                        let links = await dataStore.fetchRacePodcasts(
                            raceId: raceId,
                            raceName: race?.name,
                            raceStartDate: race?.startDate
                        )
                        sourceIds = links.map { $0.sourceId.lowercased() }
                    }

                    let resolvedSourceIds: [String]
                    if sourceIds.isEmpty {
                        let links = await dataStore.fetchRacePodcasts(
                            raceId: raceId,
                            raceName: race?.name,
                            raceStartDate: race?.startDate
                        )
                        resolvedSourceIds = links.map { $0.sourceId.lowercased() }
                    } else {
                        resolvedSourceIds = sourceIds
                    }

                    let sourceIdSet = Set(resolvedSourceIds)
                    var matchedSlugs = featuredSlugs.filter { slug in
                        guard let sourceId = featuredSourceIdBySlug[slug] else { return false }
                        return sourceIdSet.contains(sourceId)
                    }
                    let wheelTalkSlug = "wheel-talk"
                    if let genderDivision = race?.genderDivision?.lowercased(),
                       genderDivision.contains("women"),
                       featuredSourceIdBySlug[wheelTalkSlug] != nil,
                       !matchedSlugs.contains(wheelTalkSlug) {
                        matchedSlugs.append(wheelTalkSlug)
                    }
                    let lanterneRougeSlug = "lanterne-rouge"
                    let lanterneRougeYoutubeSlug = "lanterne-rouge-youtube"
                    if matchedSlugs.contains(lanterneRougeSlug),
                       featuredSourceIdBySlug[lanterneRougeYoutubeSlug] != nil,
                       !matchedSlugs.contains(lanterneRougeYoutubeSlug) {
                        matchedSlugs.append(lanterneRougeYoutubeSlug)
                    }

                    return (raceId, matchedSlugs, stageTypesByDate)
                }
            }

            var mapping: [String: [String]] = [:]
            var stageTypeMapping: [String: [String: String]] = [:]
            for await (raceId, slugs, stageTypeByDate) in group {
                mapping[raceId] = slugs
                stageTypeMapping[raceId] = stageTypeByDate
            }
            return (mapping, stageTypeMapping)
        }

        if Task.isCancelled { return }
        raceIdToFeaturedPodcastSlugs = results.0
        raceIdToCalendarStageTypeByDate = results.1
    }

    private func calendarDisplayDates(for race: Race) -> [String] {
        guard
            let startDate = raceDateFormatter.date(from: race.startDate),
            let endDate = raceDateFormatter.date(from: race.endDate)
        else {
            return [effectiveCalendarDateString(for: race)]
        }

        let lowerBound = max(startDate, raceDateFormatter.date(from: localTodayString) ?? startDate)
        if lowerBound > endDate {
            return [effectiveCalendarDateString(for: race)]
        }

        var dates: [String] = []
        var cursor = lowerBound
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        while cursor <= endDate {
            dates.append(raceDateFormatter.string(from: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    @ViewBuilder
    private func podcastBadgeStack(for race: Race) -> some View {
        let slugs = displayedPodcastSlugs(for: race)
        let priority: [String: Int] = [
            "how-the-race-was-won": 0,
            "lanterne-rouge-youtube": 1,
            "wheel-talk": 2,
            "lanterne-rouge": 3
        ]
        let visibleSlugs = Array(
            slugs
                .sorted { (priority[$0] ?? 99) < (priority[$1] ?? 99) }
                .prefix(2)
        )
        if visibleSlugs.count > 1 {
            HStack(spacing: -8) {
                ForEach(visibleSlugs, id: \.self) { slug in
                    podcastBadgeTile(for: slug)
                }
            }
        } else if let slug = visibleSlugs.first {
            podcastBadgeTile(for: slug)
        }
    }

    @ViewBuilder
    private func podcastBadgeTile(for slug: String) -> some View {
        if let artworkURL = featuredPodcastArtworkBySlug[slug] {
            BlurredAsyncImage(url: artworkURL, initialBlurRadius: 20, fadeInDuration: 0.18) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .fill(.ultraThinMaterial)
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
        } else {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                .fill(.ultraThinMaterial)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                        .stroke(.white.opacity(0.35), lineWidth: 0.5)
                )
        }
    }

    private func displayedPodcastSlugs(for race: Race) -> [String] {
        let raceSlugs = raceIdToFeaturedPodcastSlugs[race.raceId] ?? []
        let howTheRaceWasWonSlug = "how-the-race-was-won"
        let lanterneRougeSlug = "lanterne-rouge"

        guard raceSlugs.contains(howTheRaceWasWonSlug) else {
            return raceSlugs
        }

        if raceSlugs.contains(lanterneRougeSlug) {
            return raceSlugs
        }

        return raceSlugs + [lanterneRougeSlug]
    }
}

private struct RaceMonthSection: Identifiable {
    let monthKey: String
    let title: String
    let days: [RaceDaySection]

    var id: String { monthKey }
}

private struct RaceDaySection: Identifiable {
    let dayKey: String
    let entries: [CalendarRaceEntry]

    var id: String { dayKey }
    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dayKey)
    }
}

private struct CalendarRaceEntry: Identifiable {
    let race: Race
    let displayDate: String

    var id: String { "\(race.raceId)-\(displayDate)" }
}

private struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isShowingThemes = false
    @State private var isShowingNotifications = false
    @State private var isShowingCalendarAppearance = false
    @AppStorage(ICloudSyncManager.podcastPlayerPreferenceKey) private var podcastPlayerPreferenceRaw = PodcastPlayerPreference.system.rawValue
    @AppStorage(ICloudSyncManager.youtubeAppPreferenceKey) private var youtubeAppPreferenceRaw = YouTubeAppPreference.defaultBrowser.rawValue
    @Bindable private var affordanceStyle = MinAffordanceStyle.shared

    var body: some View {
        NavigationStack {
            List {
                Section("iCloud") {
                    Label("iCloud backup is always on", systemImage: "icloud")
                }
                .designSystemGroupedListRow()

                Section("Linked Apps") {
                    Picker("Podcast App", selection: $podcastPlayerPreferenceRaw) {
                        ForEach(PodcastPlayerPreference.allCases) { preference in
                            Text(preference.title).tag(preference.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("YouTube App", selection: $youtubeAppPreferenceRaw) {
                        ForEach(YouTubeAppPreference.allCases) { preference in
                            Text(preference.title).tag(preference.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .designSystemGroupedListRow()

                Section("Notifications") {
                    Button {
                        isShowingNotifications = true
                    } label: {
                        Label("Notification Preferences", systemImage: "bell")
                    }
                }
                .designSystemGroupedListRow()

                Section("Appearance") {
                    Button {
                        isShowingThemes = true
                    } label: {
                        HStack {
                            Label("Themes", systemImage: "paintbrush")
                            Spacer()
                            Text(themeManager.currentTheme.name)
                                .foregroundStyle(DesignSystem.Color.textSecondary)
                        }
                    }

                    Button {
                        isShowingCalendarAppearance = true
                    } label: {
                        Label("Calendar Race Display", systemImage: "rectangle.3.group")
                    }

                    Toggle("Affordance border", isOn: $affordanceStyle.borderEnabled)

                    Picker("Affordance shape", selection: $affordanceStyle.shape) {
                        ForEach(MinAffordanceStyle.Shape.allCases, id: \.self) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .designSystemGroupedListRow()

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .captionMedium()
                            .foregroundStyle(DesignSystem.Color.textSecondary)
                    }
                }
                .designSystemGroupedListRow()
            }
            .designSystemGroupedListStyle()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: podcastPlayerPreferenceRaw) { _, newValue in
                ICloudSyncManager.shared.syncPodcastPlayerPreference(newValue)
            }
            .onChange(of: youtubeAppPreferenceRaw) { _, newValue in
                ICloudSyncManager.shared.syncYouTubeAppPreference(newValue)
            }
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
            .sheet(isPresented: $isShowingThemes) {
                ThemesView()
            }
            .sheet(isPresented: $isShowingNotifications) {
                NavigationStack {
                    NotificationPreferencesView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented: $isShowingCalendarAppearance) {
                CalendarRaceAppearanceSettingsView()
            }
        }
    }
}

private struct CalendarRaceAppearanceSettingsView: View {
    @AppStorage(CalendarRaceDisplayStyle.storageKey) private var calendarRaceDisplayStyleRaw: String = CalendarRaceDisplayStyle.boldOverlay.rawValue
    @AppStorage(CalendarRaceMetadataPreference.showStageTypeKey) private var calendarRaceShowStageTypeMetadata: Bool = true
    @AppStorage(CalendarRaceMetadataPreference.showTimeAndStreamersKey) private var calendarRaceShowTimeAndStreamersMetadata: Bool = true
    @AppStorage(CalendarRaceMetadataPreference.showCategoryKey) private var calendarRaceShowCategoryMetadata: Bool = true

    private var selectedStyle: CalendarRaceDisplayStyle {
        CalendarRaceDisplayStyle(rawValue: calendarRaceDisplayStyleRaw) ?? .boldOverlay
    }

    var body: some View {
        List {
            Section("Calendar Race Display Style") {
                ForEach(CalendarRaceDisplayStyle.allCases) { style in
                    Button {
                        calendarRaceDisplayStyleRaw = style.rawValue
                    } label: {
                        styleOptionCard(style: style, isSelected: selectedStyle == style)
                    }
                    .buttonStyle(.plain)
                }
            }
            .designSystemGroupedListRow()

            Section("Visible Metadata") {
                Toggle("Stage Type", isOn: $calendarRaceShowStageTypeMetadata)
                Toggle("Time and Streamers", isOn: $calendarRaceShowTimeAndStreamersMetadata)
                Toggle("Category", isOn: $calendarRaceShowCategoryMetadata)
            }
            .designSystemGroupedListRow()
        }
        .designSystemGroupedListStyle()
        .navigationTitle("Calendar Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func styleOptionCard(style: CalendarRaceDisplayStyle, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(style.title)
                    .headlineSmall()
                    .foregroundHeadline()
                Spacer()
                if isSelected {
                    Image(systemName: DesignSystem.Icon.checkmarkCircle)
                        .foregroundColor(DesignSystem.Color.accent)
                }
            }

            Text(style.description)
                .captionMedium()
                .foregroundColor(DesignSystem.Color.textSecondary)

            stylePreview(style: style)
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(isSelected ? DesignSystem.Color.accent : DesignSystem.Color.borderLight, lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }

    @ViewBuilder
    private func stylePreview(style: CalendarRaceDisplayStyle) -> some View {
        switch style {
        case .default:
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(DesignSystem.Color.textSecondary.opacity(0.35))
                    .frame(height: 6)
                Rectangle()
                    .fill(DesignSystem.Color.textSecondary.opacity(0.25))
                    .frame(width: 120, height: 6)
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Color.surfaceElevated)
                    .frame(height: 60)
            }
        case .raceNameOverlay:
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Color.surfaceElevated)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 130, height: 6)
                    .padding(8)
            }
        case .fullOverlay:
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Color.surfaceElevated)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle().fill(.white.opacity(0.95)).frame(width: 130, height: 6)
                    Rectangle().fill(.white.opacity(0.8)).frame(width: 110, height: 5)
                    Rectangle().fill(.white.opacity(0.7)).frame(width: 90, height: 5)
                }
                .padding(8)
            }
        case .boldOverlay:
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Color.surfaceElevated)
                        .aspectRatio(3.0 / 1.0, contentMode: .fit)
                    Rectangle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 120, height: 8)
                }
                Rectangle()
                    .fill(DesignSystem.Color.textSecondary.opacity(0.35))
                    .frame(height: 6)
                Rectangle()
                    .fill(DesignSystem.Color.textSecondary.opacity(0.25))
                    .frame(width: 120, height: 6)
            }
        }
    }
}
