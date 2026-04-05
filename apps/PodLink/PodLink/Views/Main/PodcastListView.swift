import SwiftUI
import UniformTypeIdentifiers

struct PodcastGridFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct PodcastListView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService
    @Environment(DownloadManager.self) private var downloadManager

    @Binding var rootSheet: ContentRootSheet?

    @AppStorage("posterSize") private var posterSize = "plus60"
    @AppStorage("layoutMode") private var layoutMode = "grid"
    @AppStorage("tapInteraction") private var tapInteraction = "bounce"
    @AppStorage("mainScreenArtEmphasis") private var mainScreenArtEmphasisRaw = MainScreenArtEmphasis.largeArt.rawValue
    @AppStorage("showPodcastTitlesOnMain") private var showPodcastTitlesOnMain = false
    @AppStorage("newEpisodeBadgeMode") private var newEpisodeBadgeMode = NewEpisodeBadgeMode.notStartedLatest.rawValue
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerFloatVerticalSnap") private var miniPlayerFloatVerticalSnap = MiniPlayerFloatVerticalSnap.bottom.rawValue

    @State private var followedPodcasts: [Podcast] = []
    @State private var latestEpisodes: [String: Episode] = [:]
    @State private var selectedLatestEpisode: LatestEpisodeSelection?
    @State private var hasAttemptedInitialLoad = false

    @State private var renderedLayoutMode = UserDefaults.standard.string(forKey: "layoutMode") ?? "grid"
    @State private var layoutFadeOpacity: Double = 1

    @State private var titleTypeInitialY: CGFloat? = nil

    // MARK: - Drag & Drop State
    @State private var draggedPodcastID: String?
    @State private var dragFingerLocation: CGPoint = .zero
    @State private var dragTouchOffset: CGSize = .zero
    @State private var latestGlobalTouchLocation: CGPoint = .zero
    @State private var gridItemFrames: [String: CGRect] = [:]
    @State private var scrollViewportFrameGlobal: CGRect = .zero
    @State private var autoScrollDirection: AutoScrollDirection = .none
    @State private var autoScrollCadence: CGFloat = 0
    @State private var autoScrollTask: Task<Void, Never>?
    @State private var reorderPersistTask: Task<Void, Never>?
    @State private var lastReorderTargetID: String?
    @State private var lastReorderAt: Date = .distantPast

    private enum AutoScrollDirection {
        case none, up, down
    }

    private var columns: [GridItem] {
        return [
            GridItem(.flexible(), spacing: DesignSystem.Spacing.lg),
            GridItem(.flexible(), spacing: DesignSystem.Spacing.lg)
        ]
    }

    private var mainScreenArtEmphasis: MainScreenArtEmphasis {
        MainScreenArtEmphasis(rawValue: mainScreenArtEmphasisRaw) ?? .standard
    }

    private var artworkSize: CGFloat {
        let base: CGFloat
        switch posterSize {
        case "plus10": base = 110
        case "plus20": base = 120
        case "plus40": base = 140
        case "plus60": base = 160
        default: base = 160
        }
        switch mainScreenArtEmphasis {
        case .standard: return base
        case .largeArt: return base + MainScreenArtEmphasis.largeArtGridBonus
        }
    }

    private var gridHorizontalPadding: CGFloat { DesignSystem.Spacing.screenHorizontalPadding }

    /// Suppressed during layout transitions so grid tiles don't flash titles.
    private var gridShowsTitles: Bool {
        showPodcastTitlesOnMain && layoutMode == renderedLayoutMode
    }

    private var currentTapStyle: TapInteractionStyle {
        TapInteractionStyle(rawValue: tapInteraction) ?? .bounce
    }

    private var badgeMode: NewEpisodeBadgeMode {
        NewEpisodeBadgeMode(rawValue: newEpisodeBadgeMode) ?? .notStartedLatest
    }

    private var floatingMiniAtTop: Bool {
        miniPlayerFloatVerticalSnap == MiniPlayerFloatVerticalSnap.top.rawValue
    }

    private var floatingMiniTopInset: CGFloat {
        guard playbackService.state.currentEpisode != nil,
              miniPlayerDockMode != MiniPlayerDockMode.docked.rawValue,
              floatingMiniAtTop else { return 0 }
        return 100
    }

    private var scrollBottomInset: CGFloat {
        let hasMini = playbackService.state.currentEpisode != nil
            && miniPlayerDockMode != MiniPlayerDockMode.docked.rawValue
        guard hasMini else { return 48 }
        if floatingMiniAtTop { return 48 }
        return 100
    }

    private var sortedListPodcasts: [Podcast] {
        let episodeMap = latestEpisodes
        return followedPodcasts.sorted { lhs, rhs in
            let lhsEpisode = episodeMap[lhs.id]
            let rhsEpisode = episodeMap[rhs.id]

            let lhsGroup = listSortGroup(for: lhsEpisode)
            let rhsGroup = listSortGroup(for: rhsEpisode)
            if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

            let lhsDate = lhsEpisode?.publishDate ?? .distantPast
            let rhsDate = rhsEpisode?.publishDate ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func listSortGroup(for episode: Episode?) -> Int {
        guard let episode else { return 2 }
        return episode.isEffectivelyFinished ? 1 : 0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        titleTypeMark
                            .padding(.horizontal, MinSpacing.TitleType.horizontalPadding)
                            .offset(y: MinSpacing.TitleType.markOffsetY)

                        if !hasAttemptedInitialLoad {
                            initialLoadPlaceholder
                        } else if followedPodcasts.isEmpty {
                            emptyState
                        } else {
                            Group {
                                if renderedLayoutMode == "grid" {
                                    gridContent
                                } else {
                                    listLayout
                                }
                            }
                            .opacity(layoutFadeOpacity)
                        }
                    }
                    .padding(.top, MinSpacing.TitleType.scrollTopPadding)
                }
                .scrollClipDisabled()
                .coordinateSpace(name: "podcastListScroll")
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { scrollViewportFrameGlobal = geometry.frame(in: .global) }
                            .onChange(of: geometry.frame(in: .global)) { _, newValue in
                                scrollViewportFrameGlobal = newValue
                            }
                    }
                }
                .scrollDisabled(draggedPodcastID != nil)
                .simultaneousGesture(dragTrackingGesture(proxy: proxy))

                dragOverlay
            }
        }
        .safeAreaPadding(.top, floatingMiniTopInset)
        .refreshable {
            await refreshFeeds()
        }
        .themeBackground()
        .onChange(of: layoutMode) { _, newValue in
            animateLayoutSwitch(to: newValue)
        }
        .task {
            await loadPodcasts()
            await loadLatestEpisodes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .followedPodcastsDidChange)) { _ in
            Task { await loadPodcasts(); await loadLatestEpisodes() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .episodePlaybackStateDidChange)) { note in
            guard let changedID = note.object as? String else { return }
            if let (pid, ep) = latestEpisodes.first(where: { $0.value.id == changedID }) {
                latestEpisodes[pid] = EpisodePlaybackStore.merge(ep)
            }
        }
        .sheet(item: $selectedLatestEpisode) { selection in
            EpisodePlayerSheet(
                episode: selection.episode,
                fallbackPodcast: selection.podcast
            )
            .environment(themeManager)
            .environment(playbackService)
            .environment(downloadManager)
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Grid Content (inside ScrollView)

    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.lg) {
            ForEach(followedPodcasts) { podcast in
                podcastGridItem(podcast)
                    .id(podcast.id)
                    .onLongPressGesture(minimumDuration: 0.42, maximumDistance: 7) {
                        beginGridDragIfNeeded(for: podcast)
                    }
                    .background {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: PodcastGridFramesPreferenceKey.self,
                                    value: [podcast.id: geo.frame(in: .global)]
                                )
                        }
                    }
            }
        }
        .onPreferenceChange(PodcastGridFramesPreferenceKey.self) { gridItemFrames = $0 }
        .padding(.horizontal, gridHorizontalPadding)
        .padding(.top, MinSpacing.TitleType.contentTopSpacing)
        .padding(.bottom, scrollBottomInset)
    }

    // MARK: - Drag Tracking Gesture (on ScrollView)

    private func dragTrackingGesture(proxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                latestGlobalTouchLocation = value.location
                guard let draggedPodcastID else { return }
                dragFingerLocation = value.location
                updateGridReorder(for: draggedPodcastID, dragPoint: value.location)
                updateAutoScrollParameters(for: value.location)
                ensureAutoScrollTaskRunning(proxy: proxy)
            }
            .onEnded { _ in
                latestGlobalTouchLocation = .zero
                guard draggedPodcastID != nil else { return }
                endGridDrag()
            }
    }

    // MARK: - Drag Overlay (outside ScrollView)

    @ViewBuilder
    private var dragOverlay: some View {
        if layoutMode == "grid",
           let draggedPodcastID,
           let draggedPodcast = followedPodcasts.first(where: { $0.id == draggedPodcastID }) {
            gridArtwork(
                podcast: draggedPodcast,
                unplayed: false,
                overlayBadgeOnArt: false
            )
            .scaleEffect(1.06)
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            .position(
                x: dragFingerLocation.x - scrollViewportFrameGlobal.minX + dragTouchOffset.width,
                y: dragFingerLocation.y - scrollViewportFrameGlobal.minY + dragTouchOffset.height
            )
            .allowsHitTesting(false)
            .zIndex(1000)
        }
    }

    // MARK: - Drag Initiation

    private func beginGridDragIfNeeded(for podcast: Podcast) {
        guard draggedPodcastID == nil else { return }
        draggedPodcastID = podcast.id
        lastReorderTargetID = nil
        lastReorderAt = .distantPast

        if let frame = gridItemFrames[podcast.id] {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let touch = latestGlobalTouchLocation == .zero ? center : latestGlobalTouchLocation
            dragFingerLocation = touch
            dragTouchOffset = CGSize(
                width: center.x - touch.x,
                height: center.y - touch.y
            )
        } else {
            dragTouchOffset = .zero
        }
    }

    // MARK: - Grid Reorder Logic

    private func updateGridReorder(for draggedID: String, dragPoint: CGPoint) {
        guard let fromIndex = followedPodcasts.firstIndex(where: { $0.id == draggedID }) else { return }

        let hoverInflation = max(12, artworkSize * 0.12)
        var bestTargetID: String?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (id, frame) in gridItemFrames {
            guard id != draggedID else { continue }
            let hoverFrame = frame.insetBy(dx: -hoverInflation, dy: -hoverInflation)
            guard hoverFrame.contains(dragPoint) else { continue }
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let dist = hypot(dragPoint.x - center.x, dragPoint.y - center.y)
            if dist < bestDist {
                bestDist = dist
                bestTargetID = id
            }
        }

        guard let bestTargetID else {
            lastReorderTargetID = nil
            return
        }
        guard bestTargetID != lastReorderTargetID else { return }
        let now = Date()
        guard now.timeIntervalSince(lastReorderAt) >= 0.075 else { return }
        guard let toIndex = followedPodcasts.firstIndex(where: { $0.id == bestTargetID }),
              toIndex != fromIndex else {
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            followedPodcasts.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        lastReorderTargetID = bestTargetID
        lastReorderAt = now
        debouncePersistOrder()
    }

    private func debouncePersistOrder() {
        reorderPersistTask?.cancel()
        reorderPersistTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            savePodcastOrder()
        }
    }

    private func endGridDrag() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        autoScrollDirection = .none
        autoScrollCadence = 0
        lastReorderTargetID = nil
        lastReorderAt = .distantPast
        draggedPodcastID = nil
        dragFingerLocation = .zero
        dragTouchOffset = .zero
        savePodcastOrder()
    }

    // MARK: - Auto-Scroll

    private func updateAutoScrollParameters(for point: CGPoint) {
        let viewport = scrollViewportFrameGlobal
        guard !viewport.isEmpty else {
            autoScrollDirection = .none
            autoScrollCadence = 0
            return
        }

        let topEdge = viewport.minY + 60
        let bottomEdge = viewport.maxY - 60

        if point.y < topEdge {
            autoScrollDirection = .up
            autoScrollCadence = min(1.0, max(0.15, (topEdge - point.y) / 80))
        } else if point.y > bottomEdge {
            autoScrollDirection = .down
            autoScrollCadence = min(1.0, max(0.15, (point.y - bottomEdge) / 80))
        } else {
            autoScrollDirection = .none
            autoScrollCadence = 0
        }
    }

    private func ensureAutoScrollTaskRunning(proxy: ScrollViewProxy) {
        guard autoScrollDirection != .none, autoScrollTask == nil else { return }
        autoScrollTask = Task { @MainActor in
            while !Task.isCancelled, autoScrollDirection != .none, draggedPodcastID != nil {
                let step = autoScrollDirection
                let cadence = autoScrollCadence

                guard let draggedID = draggedPodcastID,
                      let currentIndex = followedPodcasts.firstIndex(where: { $0.id == draggedID }) else {
                    break
                }

                let targetIndex: Int
                switch step {
                case .up:
                    targetIndex = max(0, currentIndex - 1)
                case .down:
                    targetIndex = min(followedPodcasts.count - 1, currentIndex + 1)
                case .none:
                    break
                }

                if step != .none {
                    let target = followedPodcasts[step == .up ? max(0, currentIndex - 1) : min(followedPodcasts.count - 1, currentIndex + 1)]
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(target.id, anchor: step == .up ? .top : .bottom)
                    }
                }

                let sleepMs = UInt64(max(40, 180 - cadence * 140)) * 1_000_000
                try? await Task.sleep(nanoseconds: sleepMs)
            }
            autoScrollTask = nil
        }
    }

    // MARK: - Grid Item

    private func podcastGridItem(_ podcast: Podcast) -> some View {
        let latest = latestEpisodes[podcast.id]
        let unplayed = badgeMode.shouldShowBadge(for: latest)

        let stack = VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            gridArtwork(
                podcast: podcast,
                unplayed: unplayed,
                overlayBadgeOnArt: !gridShowsTitles
            )

            if gridShowsTitles {
                HStack(alignment: .center, spacing: DesignSystem.Spacing.xs) {
                    Text(podcast.title)
                        .font(DesignSystem.Typography.bodySmall())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if unplayed {
                        Circle()
                            .fill(themeManager.currentTheme.accentColor)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("Unplayed latest episode")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        return stack
            .modifier(PodcastGridCellAccessibility(showTitles: gridShowsTitles, podcastTitle: podcast.title))
            .opacity(draggedPodcastID == podcast.id ? 0 : 1)
            .tapInteraction(style: currentTapStyle) {
                rootSheet = .podcast(podcast)
            }
    }

    private func gridArtwork(podcast: Podcast, unplayed: Bool, overlayBadgeOnArt: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncCachedImage(url: podcast.displayArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))

            if overlayBadgeOnArt, unplayed {
                Circle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: 14, height: 14)
                    .padding(7)
                    .accessibilityLabel("Unplayed latest episode")
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - List Layout

    private var listLayout: some View {
        LazyVStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(sortedListPodcasts) { podcast in
                PodcastRowView(
                    podcast: podcast,
                    latestEpisode: latestEpisodes[podcast.id],
                    showTitles: showPodcastTitlesOnMain,
                    artEmphasis: mainScreenArtEmphasis,
                    badgeMode: badgeMode,
                    tapStyle: currentTapStyle,
                    onRowTap: {
                        if let latest = latestEpisodes[podcast.id] {
                            selectedLatestEpisode = LatestEpisodeSelection(
                                episode: latest,
                                podcast: podcast
                            )
                        } else {
                            rootSheet = .podcast(podcast)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .padding(.top, MinSpacing.TitleType.contentTopSpacing)
        .padding(.bottom, scrollBottomInset)
    }

    // MARK: - Initial load

    private var initialLoadPlaceholder: some View {
        VStack {
            Spacer(minLength: 200)
            ProgressView()
                .tint(themeManager.currentTheme.accentColor)
            Spacer(minLength: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, scrollBottomInset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.currentTheme.accentColor)

            Text("No Podcasts Yet")
                .font(DesignSystem.Typography.headlineLarge())
                .foregroundColor(DesignSystem.Colors.headlineColor)

            Text("Search for podcasts to follow and start listening.")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

            Button {
                rootSheet = .search
            } label: {
                Label("Find Podcasts", systemImage: "magnifyingglass")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, scrollBottomInset)
    }

    // MARK: - Title Type Mark (Scroll-Pinned Brand Logo with Blur)
    //
    // The logo lives INSIDE the ScrollView as the first item so that
    // `.visualEffect` receives continuous geometry updates during scroll.
    // `.onGeometryChange` captures the initial Y position on first layout.
    // `.visualEffect` then:
    //   1. Offsets the logo by `drift` (initial - current) to pin it in place.
    //   2. Applies blur and opacity fade proportional to scroll travel.
    // `.zIndex(-1)` keeps it behind subsequent scroll content.

    private var titleTypeMark: some View {
        Image("Title Type")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(themeManager.currentTheme.accentColor)
            .frame(maxWidth: MinSpacing.TitleType.maxWidth,
                   maxHeight: MinSpacing.TitleType.maxHeight,
                   alignment: .leading)
            .compositingGroup()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .named("podcastListScroll")).minY
            } action: { newValue in
                if titleTypeInitialY == nil {
                    titleTypeInitialY = newValue
                }
            }
            .visualEffect { content, proxy in
                let scrollY = proxy.frame(in: .named("podcastListScroll")).minY
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

    // MARK: - Layout Switch Animation

    private func animateLayoutSwitch(to newMode: String) {
        withAnimation(.easeOut(duration: 0.05)) {
            layoutFadeOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0) {
            renderedLayoutMode = newMode

            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.1)) {
                    layoutFadeOpacity = 1
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadPodcasts() async {
        defer { hasAttemptedInitialLoad = true }
        followedPodcasts = Podcast.loadFollowedPodcasts()
    }

    private func savePodcastOrder() {
        Podcast.saveFollowedPodcasts(followedPodcasts)
    }

    private func refreshFeeds() async {
        await loadPodcasts()
        await loadLatestEpisodes()
    }

    private func loadLatestEpisodes() async {
        guard !followedPodcasts.isEmpty else {
            latestEpisodes = [:]
            return
        }
        let podcasts = followedPodcasts
        let autoDownload = UserDefaults.standard.object(forKey: DownloadSettingsKeys.autoDownloadFollowed) as? Bool ?? false
        var pendingDownloads: [(Episode, Podcast)] = []

        await withTaskGroup(of: (String, Episode)?.self) { group in
            for podcast in podcasts {
                group.addTask {
                    guard let episodes = try? await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL),
                          let latest = episodes.first else { return nil }
                    let merged = EpisodePlaybackStore.merge(latest)
                    return (podcast.id, merged)
                }
            }
            var buffer: [String: Episode] = [:]
            for await result in group {
                guard let (podcastID, episode) = result else { continue }
                buffer[podcastID] = episode
                if autoDownload, !episode.isDownloaded, !episode.isEffectivelyFinished,
                   let podcast = podcasts.first(where: { $0.id == podcastID }) {
                    pendingDownloads.append((episode, podcast))
                }
                if buffer.count >= 3 {
                    latestEpisodes.merge(buffer) { _, new in new }
                    buffer.removeAll(keepingCapacity: true)
                }
            }
            if !buffer.isEmpty {
                latestEpisodes.merge(buffer) { _, new in new }
            }
        }

        for (episode, podcast) in pendingDownloads {
            downloadManager.startDownload(for: episode, podcast: podcast)
        }
    }
}

private struct LatestEpisodeSelection: Identifiable {
    let episode: Episode
    let podcast: Podcast

    var id: String { episode.id }
}

// MARK: - Accessibility

private struct PodcastGridCellAccessibility: ViewModifier {
    let showTitles: Bool
    let podcastTitle: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if showTitles {
            content
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(podcastTitle)
        }
    }
}
