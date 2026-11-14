import SwiftUI
import UniformTypeIdentifiers

struct PodcastGridFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Preference updates during scroll write here without invalidating `PodcastListView`.
private final class PodcastGridFrameCache {
    var frames: [String: CGRect] = [:]
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
    @State private var sortedListPodcasts: [Podcast] = []
    @State private var selectedLatestEpisode: LatestEpisodeSelection?
    @State private var hasAttemptedInitialLoad = false

    @State private var renderedLayoutMode = UserDefaults.standard.string(forKey: "layoutMode") ?? "grid"
    /// Top-card horizontal offset while sliding either direction to reveal the other layout.
    @State private var cardSwipeOffset: CGFloat = 0
    @State private var cardSwipeProgress: Double = 0
    @State private var cardSwipeSign: CGFloat = -1
    @State private var cardSwipeUnderMode: String?
    @State private var isCardSwipeInteractive = false
    @State private var cardSwipeAxisLocked = false
    @State private var suppressLayoutModeAnimation = false
    @State private var cardSwipeGeneration = 0

    // MARK: - Drag & Drop State
    @State private var draggedPodcastID: String?
    @State private var dragFingerLocation: CGPoint = .zero
    @State private var dragTouchOffset: CGSize = .zero
    @State private var latestGlobalTouchLocation: CGPoint = .zero
    @State private var gridItemFrames: [String: CGRect] = [:]
    @State private var gridFrameCache = PodcastGridFrameCache()
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

    /// Settled titled-grid only — never mid-swipe / never after FAB flipped to list.
    private var gridShowsTitles: Bool {
        MainScreenLayoutToggle.gridShowsTitles(
            renderedMode: renderedLayoutMode,
            layoutMode: layoutMode,
            showTitles: showPodcastTitlesOnMain,
            isSwipeActive: isCardSwipeActive
        )
    }

    /// List cards show titles during a peel even before AppStorage commits.
    private var listShowsTitles: Bool {
        MainScreenLayoutToggle.listShowsTitles(
            cardMode: "list",
            showTitles: showPodcastTitlesOnMain,
            isSwipeActive: isCardSwipeActive
        )
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

    private var isGridPosterStyle: Bool {
        MainScreenLayoutToggle.isGridPosterStyle(
            layoutMode: layoutMode,
            showTitles: showPodcastTitlesOnMain
        )
    }

    private var destinationLayoutMode: String {
        MainScreenLayoutToggle.otherMode(fromGridPoster: isGridPosterStyle)
    }

    private var underLayoutMode: String {
        cardSwipeUnderMode ?? destinationLayoutMode
    }

    private var isCardSwipeActive: Bool {
        isCardSwipeInteractive || cardSwipeProgress > 0 || cardSwipeOffset != 0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        scrollPinnedTopChrome

                        if !hasAttemptedInitialLoad {
                            initialLoadPlaceholder
                        } else if followedPodcasts.isEmpty {
                            emptyState
                        } else {
                            cardSwipeStack
                                .allowsHitTesting(!isCardSwipeActive)
                        }
                    }
                    .padding(.top, MinSpacing.TopControls.verticalPadding)
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
                .scrollDisabled(draggedPodcastID != nil || cardSwipeAxisLocked)
                .simultaneousGesture(dragTrackingGesture(proxy: proxy))
                .simultaneousGesture(layoutSwipeGesture)

                dragOverlay
            }
        }
        .safeAreaPadding(.top, floatingMiniTopInset)
        .refreshable {
            await refreshFeeds()
        }
        .themeBackground()
        .onChange(of: layoutMode) { _, newValue in
            guard !suppressLayoutModeAnimation, !isCardSwipeInteractive else { return }
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
        .onChange(of: followedPodcasts) { _, _ in
            rebuildSortedListPodcasts()
        }
        .onChange(of: latestEpisodes) { _, _ in
            rebuildSortedListPodcasts()
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

    // MARK: - Layout Content (card slide: either direction reveals the other)

    @ViewBuilder
    private var cardSwipeStack: some View {
        if isCardSwipeActive {
            ZStack(alignment: .top) {
                // Under card: lazy so revealing list/grid doesn't mount every row at once.
                layoutCard(for: underLayoutMode, lazyList: true)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                layoutCard(for: renderedLayoutMode, lazyList: true)
                    .background(DesignSystem.Colors.background)
                    .offset(x: cardSwipeOffset)
                    // Skip live shadows while dragging — they were a major frame-drop source.
            }
            .clipped()
        } else {
            // Flat into the outer LazyVStack so grid/list stay lazy when idle.
            layoutContentFlat
        }
    }

    @ViewBuilder
    private var layoutContentFlat: some View {
        // Non-hit-testing gap so the overhanging Account control stays tappable.
        Color.clear
            .frame(height: MinSpacing.TitleType.contentTopSpacing)
            .allowsHitTesting(false)

        layoutRows(for: renderedLayoutMode, lazyList: false)
    }

    private func layoutCard(for mode: String, lazyList: Bool) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: MinSpacing.TitleType.contentTopSpacing)
                .allowsHitTesting(false)
            layoutRows(for: mode, lazyList: lazyList)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func layoutRows(for mode: String, lazyList: Bool) -> some View {
        if mode == "grid" {
            gridContent
        } else if lazyList {
            LazyVStack(alignment: .leading, spacing: 0) {
                listRows
            }
        } else {
            listRows
        }
    }

    @ViewBuilder
    private var listRows: some View {
        ForEach(sortedListPodcasts) { podcast in
            listRow(for: podcast)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.bottom, DesignSystem.Spacing.sm)
        }
        Color.clear
            .frame(height: scrollBottomInset)
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
                        if !isCardSwipeActive {
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
        }
        .onPreferenceChange(PodcastGridFramesPreferenceKey.self) { frames in
            // Skip preference fan-out while the layout card is sliding — it's unused
            // for reorder then and was contributing to swipe jank.
            guard !isCardSwipeActive else { return }
            gridFrameCache.frames = frames
            if draggedPodcastID != nil {
                gridItemFrames = frames
            }
        }
        .padding(.horizontal, gridHorizontalPadding)
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

    /// Interactive card peel: swipe either way to slide the current layout off and
    /// reveal the other underneath. Release past halfway / with momentum commits;
    /// otherwise the card springs back.
    private var layoutSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                guard draggedPodcastID == nil else { return }
                handleCardSwipeChanged(value)
            }
            .onEnded { value in
                guard draggedPodcastID == nil else {
                    cancelCardSwipeAxisLock()
                    return
                }
                handleCardSwipeEnded(value)
            }
    }

    private func handleCardSwipeChanged(_ value: DragGesture.Value) {
        if !cardSwipeAxisLocked {
            guard let sign = MainScreenLayoutToggle.cardSwipeSign(
                translation: value.translation
            ) else { return }
            cardSwipeAxisLocked = true
            isCardSwipeInteractive = true
            cardSwipeSign = sign
            cardSwipeUnderMode = destinationLayoutMode
            cardSwipeGeneration += 1
        }

        guard isCardSwipeInteractive else { return }
        let newOffset = value.translation.width
        let newProgress = MainScreenLayoutToggle.cardSwipeProgress(translationWidth: newOffset)
        // Throttle sub-point churn so SwiftUI isn't invalidating every touch sample.
        guard abs(newOffset - cardSwipeOffset) >= 1 || abs(newProgress - cardSwipeProgress) >= 0.02 else {
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            // Follow the finger; keep the locked sign so a mid-gesture reverse cancels.
            cardSwipeOffset = newOffset
            cardSwipeProgress = newProgress
        }
    }

    private func handleCardSwipeEnded(_ value: DragGesture.Value) {
        guard isCardSwipeInteractive else {
            cancelCardSwipeAxisLock()
            return
        }

        let commit = MainScreenLayoutToggle.shouldCommitCardSwipe(
            progress: cardSwipeProgress,
            translationWidth: value.translation.width,
            predictedTranslationWidth: value.predictedEndTranslation.width,
            lockedSign: cardSwipeSign
        )
        finishInteractiveCardSwipe(commit: commit)
    }

    private func finishInteractiveCardSwipe(commit: Bool) {
        let sign = cardSwipeSign
        let generation = cardSwipeGeneration
        let targetOffset: CGFloat = commit
            ? sign * MainScreenLayoutToggle.dismissDistance
            : 0
        let targetProgress: Double = commit ? 1 : 0
        isCardSwipeInteractive = false
        cardSwipeAxisLocked = false

        withAnimation(.easeOut(duration: MainScreenLayoutToggle.swipeAnimationDuration)) {
            cardSwipeOffset = targetOffset
            cardSwipeProgress = targetProgress
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MainScreenLayoutToggle.swipeAnimationDuration) {
            guard generation == cardSwipeGeneration else { return }
            if commit {
                commitCardSwipe()
            } else {
                cardSwipeOffset = 0
                cardSwipeProgress = 0
                cardSwipeUnderMode = nil
            }
        }
    }

    private func commitCardSwipe() {
        var mode = layoutMode
        var titles = showPodcastTitlesOnMain
        var art = mainScreenArtEmphasisRaw
        MainScreenLayoutToggle.applyToggle(
            layoutMode: &mode,
            showTitles: &titles,
            artEmphasis: &art
        )
        suppressLayoutModeAnimation = true
        layoutMode = mode
        showPodcastTitlesOnMain = titles
        mainScreenArtEmphasisRaw = art
        renderedLayoutMode = mode
        cardSwipeOffset = 0
        cardSwipeProgress = 0
        cardSwipeUnderMode = nil
        DispatchQueue.main.async {
            suppressLayoutModeAnimation = false
        }
    }

    private func cancelCardSwipeAxisLock() {
        cardSwipeAxisLocked = false
        if isCardSwipeInteractive {
            isCardSwipeInteractive = false
            cardSwipeOffset = 0
            cardSwipeProgress = 0
            cardSwipeUnderMode = nil
        }
    }

    // MARK: - Drag Overlay (outside ScrollView)

    @ViewBuilder
    private var dragOverlay: some View {
        if layoutMode == "grid",
           let draggedPodcastID,
           let draggedPodcast = followedPodcasts.first(where: { $0.id == draggedPodcastID }) {
            let cellWidth = gridItemFrames[draggedPodcastID]?.width
            gridArtwork(
                podcast: draggedPodcast,
                unplayed: false,
                overlayBadgeOnArt: false
            )
            .frame(width: cellWidth, height: cellWidth)
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
        if gridItemFrames.isEmpty {
            gridItemFrames = gridFrameCache.frames
        }
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
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile)
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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

    private func listRow(for podcast: Podcast) -> some View {
        PodcastRowView(
            podcast: podcast,
            latestEpisode: latestEpisodes[podcast.id],
            showTitles: listShowsTitles,
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

    // MARK: - Scroll-Pinned Top Chrome (Title + Account)
    //
    // Height matches the 56pt account control so glass stays inside the bounds
    // that `minScrollPinnedChrome` / `visualEffect` rasterizes.

    private var scrollPinnedTopChrome: some View {
        ZStack(alignment: .topLeading) {
            Image("Title Type")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(themeManager.currentTheme.accentColor)
                .accessibilityHidden(true)
                .frame(maxWidth: MinSpacing.TitleType.maxWidth,
                       maxHeight: MinSpacing.TitleType.maxHeight,
                       alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: MinSpacing.TopControls.buttonSize, alignment: .leading)
                .padding(.leading, MinSpacing.TitleType.horizontalPadding)

            HStack {
                Spacer(minLength: 0)
                accountButton
            }
            .padding(.horizontal, MinSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: MinSpacing.TopControls.buttonSize, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: MinSpacing.TopControls.buttonSize)
        .offset(y: MinSpacing.TitleType.markOffsetY)
        .minScrollPinnedChrome(coordinateSpace: "podcastListScroll")
        .accessibilityElement(children: .contain)
    }

    private var accountButton: some View {
        let aff = MinAffordanceStyle.shared
        let size = MinSpacing.TopControls.buttonSize
        return Button {
            rootSheet = .account
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .frostedSurface(aff.insettableCircleShape)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("Account")
    }

    // MARK: - Layout Switch Animation (FAB / settings — non-interactive)

    private func animateLayoutSwitch(to newMode: String) {
        guard newMode != renderedLayoutMode || isCardSwipeActive else { return }

        cardSwipeSign = -1
        cardSwipeUnderMode = newMode
        cardSwipeGeneration += 1
        let generation = cardSwipeGeneration
        // Mark active before storage-driven title flags settle so list keeps titles
        // and grid doesn't expand on the first frame of the FAB peel.
        isCardSwipeInteractive = true
        cardSwipeOffset = 0
        cardSwipeProgress = 0

        withAnimation(.easeInOut(duration: MainScreenLayoutToggle.swipeAnimationDuration)) {
            cardSwipeOffset = cardSwipeSign * MainScreenLayoutToggle.dismissDistance
            cardSwipeProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MainScreenLayoutToggle.swipeAnimationDuration) {
            guard generation == cardSwipeGeneration else { return }
            renderedLayoutMode = newMode
            isCardSwipeInteractive = false
            cardSwipeOffset = 0
            cardSwipeProgress = 0
            cardSwipeUnderMode = nil
        }
    }

    // MARK: - Data Loading

    private func rebuildSortedListPodcasts() {
        sortedListPodcasts = PodcastListSorter.sort(followedPodcasts, latestEpisodes: latestEpisodes)
    }

    private func loadPodcasts() async {
        defer { hasAttemptedInitialLoad = true }
        followedPodcasts = Podcast.loadFollowedPodcasts()
        rebuildSortedListPodcasts()
    }

    private func savePodcastOrder() {
        let persisted = Podcast.loadFollowedPodcasts()
        let persistedIDs = Set(persisted.map(\.id))
        var ordered = followedPodcasts.filter { persistedIDs.contains($0.id) }
        let orderedIDs = Set(ordered.map(\.id))
        for podcast in persisted where !orderedIDs.contains(podcast.id) {
            ordered.append(podcast)
        }
        followedPodcasts = ordered
        Podcast.saveFollowedPodcasts(ordered)
    }

    private func refreshFeeds() async {
        await loadPodcasts()
        await loadLatestEpisodes()
    }

    private func loadLatestEpisodes() async {
        guard !followedPodcasts.isEmpty else {
            latestEpisodes = [:]
            rebuildSortedListPodcasts()
            return
        }
        let podcasts = followedPodcasts
        let autoDownload = UserDefaults.standard.object(forKey: DownloadSettingsKeys.autoDownloadFollowed) as? Bool ?? false
        var pendingDownloads: [(Episode, Podcast)] = []

        await withTaskGroup(of: (String, Episode)?.self) { group in
            for podcast in podcasts {
                group.addTask {
                    guard let episodes = try? await RSSFeedService.shared.fetchRecentEpisodes(
                        feedURL: podcast.feedURL,
                        limit: 1
                    ),
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
