import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LiquidGlassButtonStyle: ButtonStyle {
    var role: ButtonRole?
    var isCompact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let aff = MinAffordanceStyle.shared
        let circleShape = aff.circleShape
        let rectShape = aff.capsuleShape
        let strokeColor: Color = role == .destructive ? DesignSystem.Color.error.opacity(0.3) : .white.opacity(0.2)
        let compactShape = circleShape
        let fullShape = rectShape

        configuration.label
            .if(!isCompact) { view in
                view
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            }
            .background {
                if isCompact {
                    compactShape
                        .fill(.thinMaterial)
                        .background { compactShape.fill(.thinMaterial).blur(radius: 10) }
                } else {
                    fullShape
                        .fill(.thinMaterial)
                        .background { fullShape.fill(.thinMaterial).blur(radius: 10) }
                }
            }
            .overlay {
                if aff.borderEnabled {
                    if isCompact {
                        compactShape.stroke(strokeColor, lineWidth: 0.5)
                    } else {
                        fullShape.stroke(strokeColor, lineWidth: 0.5)
                    }
                }
            }
            .foregroundColor(role == .destructive ? DesignSystem.Color.error : DesignSystem.Color.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(DesignSystem.Animation.springStandard, value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlassCompact: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(isCompact: true)
    }
}

struct RaceDetailView: View {
    let race: Race
    @Environment(\.openURL) private var openURL
    @State private var streamers: [(streamer: Streamer, stream: RaceStream)] = []
    @State private var podcasts: [RacePodcastEpisodeLink] = []
    @State private var stages: [Stage] = []
    @State private var stagePodcastsByStageId: [String: [RacePodcastEpisodeLink]] = [:]
    @State private var podcastArtworkBySourceId: [String: URL] = [:]
    @State private var podcastFeedURLBySourceId: [String: String] = [:]
    @State private var raceResults: [RaceResult] = []
    @State private var stagePath: [Stage] = []
    @State private var localIsSaved = false
    @State private var localIsListened = false
    @State private var localIsWatched = false
    @State private var buttonScale: [String: CGFloat] = [:]
    @AppStorage(Self.podcastPlayerPreferenceKey) private var podcastPlayerPreferenceRaw = PodcastPlayerPreference.system.rawValue
    @AppStorage(Self.streamOpenPreferenceKey) private var streamOpenPreferenceRaw = StreamOpenPreference.associatedAppFirst.rawValue
    @AppStorage(Self.youtubeAppPreferenceKey) private var youtubeAppPreferenceRaw = YouTubeAppPreference.defaultBrowser.rawValue

    var body: some View {
        NavigationStack(path: $stagePath) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        if let urlString = race.effectiveImageUrl, let url = URL(string: urlString) {
                            heroImage(url: url)
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(race.name)
                                .displayLarge()
                                .foregroundHeadline()
                            Text(headerSubtitle)
                                .titleMedium()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                        actionButtons
                            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                        if !stages.isEmpty {
                            detailSection("Stages") {
                                ForEach(stages) { stage in
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        NavigationLink(value: stage) {
                                            stageTitleRow(stage)
                                        }
                                        .buttonStyle(.plain)

                                        if let stageMeta = stageMetaLine(stage) {
                                            Text(stageMeta)
                                                .captionSmall()
                                                .foregroundColor(DesignSystem.Color.textTertiary)
                                                // .padding(.top, DesignSystem.Spacing.sm)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }

                                        let stagePodcasts = podcastsForStage(stage)
                                        if !stagePodcasts.isEmpty {
                                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                                ForEach(stagePodcasts) { podcast in
                                                    podcastRow(podcast)
                                                }
                                            }
                                            .padding(.top, DesignSystem.Spacing.sm)
                                            .padding(.trailing, DesignSystem.Spacing.sm)
                                            .padding(.vertical, DesignSystem.Spacing.sm)
                                            .background(DesignSystem.Color.surface.opacity(0.22))
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                                        }
                                    }
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                }
                            }
                        }

                        if !unattachedPodcasts.isEmpty {
                            detailSection("Podcasts") {
                                ForEach(unattachedPodcasts) { podcast in
                                    podcastRow(podcast)
                                }
                            }
                        }

                        if !raceResults.isEmpty {
                            detailSection("Results") {
                                ForEach(raceResults) { result in
                                    raceResultRow(result)
                                }
                            }
                        }

                        detailSection("Overview") {
                            LabeledContent("Series", value: race.series)
                            if let classification = race.classification {
                                LabeledContent("Classification", value: classification)
                            }
                            if !race.displayColloquialCategories.isEmpty {
                                LabeledContent("Category", value: race.displayColloquialCategories.joined(separator: "   "))
                            }
                            LabeledContent("Discipline", value: race.discipline)
                            LabeledContent("Format", value: race.raceType)
                            if let gender = race.genderDivision {
                                LabeledContent("Gender", value: gender)
                            }
                            if let organizer = race.organizer {
                                LabeledContent("Organizer", value: organizer)
                            }
                        }

                        detailSection("Dates") {
                            LabeledContent("Start", value: race.startDate)
                            LabeledContent("End", value: race.endDate)
                        }

                        if let officialWebsite = race.officialWebsite, let url = URL(string: officialWebsite) {
                            detailSection("Links") {
                                Link(destination: url) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        DesignSystemIcon(DesignSystem.Icon.link, size: DesignSystem.IconSize.sm, color: DesignSystem.Color.accent)
                                        Text("Official website")
                                            .labelMedium()
                                            .foregroundColor(DesignSystem.Color.accent)
                                    }
                                }
                            }
                        }

                        if !streamers.isEmpty {
                            detailSection("Streaming") {
                                ForEach(streamers, id: \.streamer.streamerId) { item in
                                    streamingRow(streamer: item.streamer, stream: item.stream)
                                }
                            }
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .leading)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationDestination(for: Stage.self) { stage in
                StageDetailView(race: race, stage: stage)
            }
        }
        .font(DesignSystem.Typography.bodyMedium)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            migrateWatchedItPreferencesIfNeeded()
            let directStreamers = await BootstrapDataStore.shared.fetchStreamers(for: race.raceId)
            streamers = directStreamers.isEmpty ? await fallbackStreamers() : directStreamers
            let podcastSources = await BootstrapDataStore.shared.fetchPodcastSources()
            podcastFeedURLBySourceId = Dictionary(
                uniqueKeysWithValues: podcastSources.map { ($0.sourceId.lowercased(), $0.feedUrl) }
            )
            let artworkURLs = await PodcastEpisodeFeedService.shared.fetchArtworkURLs(for: podcastSources)
            podcastArtworkBySourceId = artworkURLs
            let livePodcasts = await PodcastEpisodeFeedService.shared.fetchEpisodes(for: race, sources: podcastSources)
            let seededPodcasts = (try? await APIClient.shared.fetchRacePodcasts(race: race)) ?? []
            podcasts = mergePodcastLinks(seededPodcasts, livePodcasts)
            stages = (try? await APIClient.shared.fetchRaceStages(race: race)) ?? []
            stagePodcastsByStageId = await fetchStagePodcastsByStageId(stages: stages)
            raceResults = (try? await APIClient.shared.fetchRaceResults(raceId: race.raceId)) ?? []
            loadUserState()
        }
        .onChange(of: podcastPlayerPreferenceRaw) { _, newValue in
            ICloudSyncManager.shared.syncPodcastPlayerPreference(newValue)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .bottomSheetPullToDismiss()
        .themeBackground()
    }

    @ViewBuilder
    private func heroImage(url: URL) -> some View {
        CachedAsyncImage(url: url, cacheTTL: 60 * 60 * 24 * 7) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(DesignSystem.Color.surface)
                    .overlay { ProgressView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .raceImageTwoTone()
            case .failure:
                Rectangle()
                    .fill(DesignSystem.Color.surface)
                    .overlay {
                        DesignSystemIcon(DesignSystem.Icon.race, size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            playButton
            watchedButton
            if hasPodcasts {
                listenedButton
            }
            savedButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .headlineMedium()
                .foregroundHeadline()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                content()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.groupedListCardBackground.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
    }

    @ViewBuilder
    private var playButton: some View {
        if isPlayableRace {
            if streamingLinks.isEmpty {
                Button(action: openFallbackStreamSearch) {
                    DesignSystemIcon("play.fill", size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textPrimary)
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.liquidGlassCompact)
            } else {
                Menu {
                    ForEach(streamingLinks) { item in
                        Button(action: { openActionLink(item) }) {
                            Label(item.title, systemImage: "play.rectangle")
                        }
                    }
                    Divider()
                    Menu("Stream preference") {
                        ForEach(StreamOpenPreference.allCases, id: \.rawValue) { preference in
                            Button {
                                streamOpenPreferenceRaw = preference.rawValue
                            } label: {
                                if streamOpenPreference == preference {
                                    Label(preference.title, systemImage: DesignSystem.Icon.checkmark)
                                } else {
                                    Text(preference.title)
                                }
                            }
                        }
                    }
                } label: {
                    DesignSystemIcon("play.fill", size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textPrimary)
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.liquidGlassCompact)
            }
        } else {
            Button(action: {}) {
                DesignSystemIcon("play.fill", size: DesignSystem.IconSize.lg, color: DesignSystem.Color.textSecondary)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.liquidGlassCompact)
            .disabled(true)
        }
    }

    private var watchedButton: some View {
        Button(action: toggleWatchedStatus) {
            DesignSystemIcon(
                localIsWatched ? "eye.fill" : "eye",
                size: DesignSystem.IconSize.lg,
                color: localIsWatched ? DesignSystem.Color.accent : DesignSystem.Color.textPrimary
            )
            .frame(width: 60, height: 60)
            .scaleEffect(buttonScale["watched"] ?? 1.0)
        }
        .buttonStyle(.liquidGlassCompact)
    }

    @ViewBuilder
    private var listenedButton: some View {
        let listenedIcon = DesignSystemIcon(
            localIsListened ? "mic.fill" : "mic",
            size: DesignSystem.IconSize.lg,
            color: localIsListened ? DesignSystem.Color.accent : DesignSystem.Color.textPrimary
        )
        Menu {
            Button(action: toggleListenedStatus) {
                Label(localIsListened ? "Mark unlistened" : "Mark listened", systemImage: localIsListened ? "mic.fill" : "mic")
            }
            if !podcastLinks.isEmpty {
                Divider()
                ForEach(podcastLinks) { item in
                    Button(action: { openActionLink(item) }) {
                        Label(item.title, systemImage: "mic")
                    }
                }
            }
            Divider()
            Menu("Podcast player") {
                ForEach(PodcastPlayerPreference.allCases, id: \.rawValue) { preference in
                    Button {
                        podcastPlayerPreferenceRaw = preference.rawValue
                    } label: {
                        if podcastPlayerPreference == preference {
                            Label(preference.title, systemImage: DesignSystem.Icon.checkmark)
                        } else {
                            Text(preference.title)
                        }
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

    private var savedButton: some View {
        Button(action: toggleSavedStatus) {
            DesignSystemIcon(
                localIsSaved ? "bookmark.fill" : "bookmark",
                size: DesignSystem.IconSize.lg,
                color: localIsSaved ? DesignSystem.Color.accent : DesignSystem.Color.textPrimary
            )
            .frame(width: 60, height: 60)
            .scaleEffect(buttonScale["saved"] ?? 1.0)
        }
        .buttonStyle(.liquidGlassCompact)
    }

    private var todayString: String {
        ISO8601DateFormatter().string(from: Date()).prefix(10).description
    }

    /// e.g. "July 12", "July 12 – 14", or "July 12 – August 3" plus " on Streamer" when streamers loaded
    private var headerSubtitle: String {
        let datePart = Self.formattedDateRange(start: race.startDate, end: race.endDate)
        let streamerPart: String? = {
            guard !streamers.isEmpty else { return nil }
            let streamerNames = streamers.map(\.streamer.name).joined(separator: ", ")
            return "on \(streamerNames)"
        }()
        let parts = [datePart, streamerPart, raceWinnerMetadata, headerLocation].compactMap { $0 }
        return parts.joined(separator: "   ")
    }

    private var raceWinnerMetadata: String? {
        guard let winner = raceResults.first(where: { $0.rank == 1 }) else { return nil }
        return "Winner: \(winner.athleteName)"
    }

    private var headerLocation: String? {
        let city = race.locationCity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = race.locationCountry?.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasCity = city?.isEmpty == false
        let hasCountry = country?.isEmpty == false

        if hasCity && hasCountry {
            return "\(city!), \(country!)"
        }
        if hasCountry {
            return country
        }
        if hasCity {
            return city
        }
        return nil
    }

    private static let dateInputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        f.locale = Locale.current
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.locale = Locale.current
        return f
    }()

    /// Returns "July 12", "July 12 – 14", or "July 12 – August 3"
    private static func formattedDateRange(start: String, end: String) -> String {
        guard let startDate = dateInputFormatter.date(from: start) else { return start }
        guard let endDate = dateInputFormatter.date(from: end) else { return start }
        let startStr = monthDayFormatter.string(from: startDate)
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return startStr
        }
        if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .month) {
            let endDay = dayFormatter.string(from: endDate)
            return "\(startStr) – \(endDay)"
        }
        let endStr = monthDayFormatter.string(from: endDate)
        return "\(startStr) – \(endStr)"
    }

    private var isPlayableRace: Bool {
        race.startDate <= todayString
    }

    private var hasPodcasts: Bool {
        !podcasts.isEmpty
    }

    private var unattachedPodcasts: [RacePodcastEpisodeLink] {
        let attachedKeys: Set<String> = Set(
            stagePodcastsByStageId.values
                .flatMap { $0 }
                .map(podcastIdentityKey(for:))
        )
        return podcasts.filter { !attachedKeys.contains(podcastIdentityKey(for: $0)) }
    }

    private var streamingLinks: [ActionLink] {
        var links: [ActionLink] = streamers.compactMap { item in
            streamingActionLink(streamer: item.streamer, stream: item.stream)
        }

        if shouldOfferYouTubeFallbackSearch {
            links.append(contentsOf: youTubeFallbackStreamingLinks())
        }

        if links.isEmpty, let fallback = fallbackStreamingSearchURL() {
            links.append(ActionLink(title: "Search for \(race.name)", primaryURL: fallback, fallbackURL: nil, kind: .stream))
        }

        return uniqueLinks(links)
    }

    private var podcastLinks: [ActionLink] {
        let links = podcasts.compactMap { podcast -> ActionLink? in
            let title = "\(podcast.sourceName): \(podcast.title)"
            let searchQuery = "\(podcast.sourceName) \(podcast.title)"
            let feedURL = podcastFeedURL(for: podcast)
            if let urlString = podcast.episodeUrl, let url = URL(string: urlString) {
                return ActionLink(
                    title: title,
                    primaryURL: url,
                    fallbackURL: podcastSearchURL(podcast: podcast),
                    kind: .podcast,
                    searchQuery: searchQuery,
                    podcastFeedURL: feedURL,
                    podcastEpisodeTitle: podcast.title,
                    podcastEpisodeURL: url.absoluteString
                )
            }
            if let searchURL = podcastSearchURL(podcast: podcast) {
                return ActionLink(
                    title: title,
                    primaryURL: searchURL,
                    fallbackURL: nil,
                    kind: .podcast,
                    searchQuery: searchQuery,
                    podcastFeedURL: feedURL,
                    podcastEpisodeTitle: podcast.title
                )
            }
            return nil
        }
        return uniqueLinks(links)
    }

    private func streamingActionLink(streamer: Streamer, stream: RaceStream) -> ActionLink? {
        if let streamUrl = stream.streamUrl, let url = URL(string: streamUrl), !isCyclismoPlaceholderURL(url) {
            return ActionLink(
                title: streamer.name,
                primaryURL: url,
                fallbackURL: streamer.websiteUrl.flatMap { URL(string: $0) },
                kind: .stream,
                associatedAppURLs: associatedStreamerAppURLs(for: streamer, primaryURL: url)
            )
        }
        if let sourceUrl = stream.sourceUrl, let url = URL(string: sourceUrl), !isCyclismoPlaceholderURL(url) {
            return ActionLink(
                title: streamer.name,
                primaryURL: url,
                fallbackURL: streamer.websiteUrl.flatMap { URL(string: $0) },
                kind: .stream,
                associatedAppURLs: associatedStreamerAppURLs(for: streamer, primaryURL: url)
            )
        }
        return searchActionLinkForStreamer(streamer)
    }

    private func searchActionLinkForStreamer(_ streamer: Streamer) -> ActionLink? {
        let query = "\(race.name) cycling".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? race.name
        switch streamer.slug.lowercased() {
        case "flobikes":
            guard let web = URL(string: "https://www.flobikes.com/search?query=\(query)") else { return nil }
            return ActionLink(
                title: streamer.name,
                primaryURL: web,
                fallbackURL: URL(string: "https://www.flobikes.com"),
                kind: .stream,
                associatedAppURLs: streamerAppCandidates(slug: "flobikes", encodedQuery: query)
            )
        case "peacock":
            guard let web = URL(string: "https://www.peacocktv.com/search?query=\(query)") else { return nil }
            return ActionLink(
                title: streamer.name,
                primaryURL: web,
                fallbackURL: URL(string: "https://www.peacocktv.com/sports/cycling"),
                kind: .stream,
                associatedAppURLs: streamerAppCandidates(slug: "peacock", encodedQuery: query)
            )
        case "max":
            guard let web = URL(string: "https://play.max.com/search?q=\(query)") else { return nil }
            return ActionLink(
                title: streamer.name,
                primaryURL: web,
                fallbackURL: URL(string: "https://play.max.com/sports/cycling"),
                kind: .stream,
                associatedAppURLs: streamerAppCandidates(slug: "max", encodedQuery: query)
            )
        default:
            if let website = streamer.websiteUrl, let url = URL(string: website) {
                return ActionLink(title: streamer.name, primaryURL: url, fallbackURL: nil, kind: .stream)
            }
            return nil
        }
    }

    private func fallbackStreamers() async -> [(streamer: Streamer, stream: RaceStream)] {
        let inferredSlugs = StreamerFallback.inferredSlugs(for: race.name)
        guard !inferredSlugs.isEmpty else { return [] }

        let availableStreamers = await BootstrapDataStore.shared.fetchStreamers()
        let streamersBySlug = Dictionary(
            uniqueKeysWithValues: availableStreamers.map { ($0.slug.lowercased(), $0) }
        )

        return inferredSlugs.compactMap { slug in
            guard let streamer = streamersBySlug[slug.lowercased()] else { return nil }
            let syntheticStream = RaceStream(
                raceId: race.raceId,
                streamerId: streamer.streamerId,
                regionCodes: StreamerFallback.defaultRegions(for: slug),
                streamUrl: nil,
                sourceUrl: streamer.websiteUrl
            )
            return (streamer: streamer, stream: syntheticStream)
        }
    }

    private func associatedStreamerAppURLs(for streamer: Streamer, primaryURL: URL) -> [URL] {
        let host = primaryURL.host?.lowercased() ?? ""
        let query = race.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? race.name
        switch streamer.slug.lowercased() {
        case "peacock":
            return streamerAppCandidates(slug: "peacock", encodedQuery: query)
        case "max":
            return streamerAppCandidates(slug: "max", encodedQuery: query)
        case "flobikes":
            return streamerAppCandidates(slug: "flobikes", encodedQuery: query)
        default:
            if host.contains("peacocktv.com") {
                return streamerAppCandidates(slug: "peacock", encodedQuery: query)
            }
            if host.contains("max.com") || host.contains("play.max.com") {
                return streamerAppCandidates(slug: "max", encodedQuery: query)
            }
            if host.contains("flobikes.com") || host.contains("flosports.tv") {
                return streamerAppCandidates(slug: "flobikes", encodedQuery: query)
            }
            if host.contains("youtube.com") || host.contains("youtu.be") {
                return youtubeAppPreference.appURLs(for: primaryURL)
            }
            return []
        }
    }

    private func streamerAppCandidates(slug: String, encodedQuery: String) -> [URL] {
        switch slug.lowercased() {
        case "flobikes":
            return [
                URL(string: "flobikes://"),
                URL(string: "flosports://")
            ].compactMap { $0 }
        case "peacock":
            return [
                URL(string: "peacock://"),
                URL(string: "peacocktv://"),
                URL(string: "peacock://search?query=\(encodedQuery)"),
                URL(string: "peacocktv://search?query=\(encodedQuery)")
            ].compactMap { $0 }
        case "max":
            return [
                URL(string: "max://"),
                URL(string: "hbomax://"),
                URL(string: "max://search?query=\(encodedQuery)"),
                URL(string: "hbomax://search?query=\(encodedQuery)")
            ].compactMap { $0 }
        default:
            return []
        }
    }

    private func podcastSearchURL(podcast: RacePodcastEpisodeLink) -> URL? {
        let rawQuery = "\(podcast.sourceName) \(podcast.title)"
        let encodedQuery = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawQuery

        switch podcastPlayerPreference {
        case .system, .apple:
            return URL(string: "https://podcasts.apple.com/search?term=\(encodedQuery)")
        case .spotify:
            return URL(string: "https://open.spotify.com/search/\(encodedQuery)")
        case .overcast:
            return URL(string: "https://overcast.fm/search?query=\(encodedQuery)")
        case .pocketCasts:
            return URL(string: "https://pocketcasts.com/search?q=\(encodedQuery)")
        case .podLink:
            return URL(string: "https://podcasts.apple.com/search?term=\(encodedQuery)")
        }
    }

    private func podcastFeedURL(for podcast: RacePodcastEpisodeLink) -> String? {
        podcastFeedURLBySourceId[podcast.sourceId.lowercased()]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallbackStreamingSearchURL() -> URL? {
        let query = "\(race.name) cycling race stream".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? race.name
        return URL(string: "https://www.google.com/search?q=\(query)")
    }

    private var shouldOfferYouTubeFallbackSearch: Bool {
        if streamers.isEmpty {
            return true
        }
        return streamers.allSatisfy { item in
            item.streamer.slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "flobikes"
        }
    }

    private func youTubeFallbackStreamingLinks() -> [ActionLink] {
        let raceQuery = race.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raceQuery.isEmpty else { return [] }

        let options: [(title: String, query: String)] = [
            ("YouTube: Live coverage", "\(raceQuery) cycling live"),
            ("YouTube: Full replay", "\(raceQuery) full race replay cycling")
        ]

        return options.compactMap { option in
            let encoded = option.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? option.query
            guard let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
                return nil
            }
            return ActionLink(
                title: option.title,
                primaryURL: url,
                fallbackURL: fallbackStreamingSearchURL(),
                kind: .stream,
                associatedAppURLs: youtubeAppPreference.appURLs(for: url)
            )
        }
    }

    private func isCyclismoPlaceholderURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "cyclismo.app" || host.hasSuffix(".cyclismo.app")
    }

    private func openFallbackStreamSearch() {
        guard isPlayableRace, let url = fallbackStreamingSearchURL() else { return }
        openExternalURL(url)
    }

    private func toggleSavedStatus() {
        localIsSaved.toggle()
        animateButtonPress("saved")
        triggerMediumHaptic()
        persistStatus(localIsSaved, key: Self.savedKey)
    }

    private func toggleListenedStatus() {
        localIsListened.toggle()
        animateButtonPress("listened")
        triggerMediumHaptic()
        persistStatus(localIsListened, key: Self.listenedKey)
    }

    private func toggleWatchedStatus() {
        localIsWatched.toggle()
        animateButtonPress("watched")
        triggerMediumHaptic()
        persistStatus(localIsWatched, key: Self.watchedKey)
    }

    private func animateButtonPress(_ key: String) {
        withAnimation(DesignSystem.Animation.springQuick) {
            buttonScale[key] = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(DesignSystem.Animation.springStandard) {
                buttonScale[key] = 1.0
            }
        }
    }

    private func triggerMediumHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func loadUserState() {
        let status = RaceStatusStore.status(for: race.raceId)
        localIsSaved = status.isSaved
        localIsListened = status.isListened
        localIsWatched = status.isWatched
    }

    private func persistStatus(_ isOn: Bool, key: String) {
        RaceStatusStore.set(isOn, raceId: race.raceId, key: key)
    }

    private func uniqueLinks(_ links: [ActionLink]) -> [ActionLink] {
        var seen: Set<String> = []
        var result: [ActionLink] = []
        for link in links {
            let key = link.primaryURL.absoluteString
            if seen.insert(key).inserted {
                result.append(link)
            }
        }
        return result
    }

    private func mergePodcastLinks(_ primary: [RacePodcastEpisodeLink], _ live: [RacePodcastEpisodeLink]) -> [RacePodcastEpisodeLink] {
        var seen: Set<String> = []
        var merged: [RacePodcastEpisodeLink] = []

        for podcast in primary + live {
            let dedupeKey = podcastIdentityKey(for: podcast)
            if seen.insert(dedupeKey).inserted {
                if isPodcastRelevantToRaceDate(podcast) {
                    merged.append(podcast)
                }
            }
        }

        return merged.sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    private func isPodcastRelevantToRaceDate(_ podcast: RacePodcastEpisodeLink) -> Bool {
        guard let raceDate = parseRaceDate(race.startDate),
              let publishedAt = podcast.publishedAt,
              let publishDate = ISO8601DateFormatter().date(from: publishedAt) else {
            return false
        }

        let raceYear = Calendar.current.component(.year, from: raceDate)
        let pubYear = Calendar.current.component(.year, from: publishDate)
        let dayDelta = Calendar.current.dateComponents([.day], from: publishDate, to: raceDate).day ?? 0

        if pubYear == raceYear && (-21...35).contains(dayDelta) {
            return true
        }

        let text = "\(podcast.title) \(podcast.description ?? "")".lowercased()
        let isPreview = text.contains("preview")
            || text.contains("route")
            || text.contains("startlist")
            || text.contains("season preview")
        return isPreview && (raceYear - pubYear == 1) && (250...430).contains(dayDelta)
    }

    private func parseRaceDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func fetchStagePodcastsByStageId(stages: [Stage]) async -> [String: [RacePodcastEpisodeLink]] {
        guard !stages.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, [RacePodcastEpisodeLink]).self) { group in
            for stage in stages {
                group.addTask {
                    let stagePodcasts = (try? await APIClient.shared.fetchStagePodcasts(stageId: stage.stageId)) ?? []
                    return (stage.stageId, stagePodcasts.sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") })
                }
            }

            var result: [String: [RacePodcastEpisodeLink]] = [:]
            for await (stageId, stagePodcasts) in group {
                result[stageId] = stagePodcasts
            }
            return result
        }
    }

    private func podcastsForStage(_ stage: Stage) -> [RacePodcastEpisodeLink] {
        let stageSpecific = stagePodcastsByStageId[stage.stageId] ?? []
        guard !stageSpecific.isEmpty else { return [] }

        let mergedByKey = podcasts.reduce(into: [String: RacePodcastEpisodeLink]()) { partialResult, podcast in
            partialResult[podcastIdentityKey(for: podcast)] = podcast
        }

        return stageSpecific.map { stagePodcast in
            mergedByKey[podcastIdentityKey(for: stagePodcast)] ?? stagePodcast
        }
    }

    private func podcastIdentityKey(for podcast: RacePodcastEpisodeLink) -> String {
        podcast.episodeUrl?.lowercased()
            ?? "\(podcast.sourceId.lowercased())::\(podcast.title.lowercased())::\(podcast.publishedAt ?? "")"
    }

    private func openActionLink(_ link: ActionLink) {
        let preferredPodcastURLs = preferredPodcastAppURLs(for: link)
        let appCandidates = uniqueURLList(preferredPodcastURLs + link.associatedAppURLs)
        let webCandidates = [link.primaryURL, link.fallbackURL].compactMap { $0 }
        let openOrder: [URL]
        if link.kind == .stream && streamOpenPreference == .webFirst {
            openOrder = uniqueURLList(webCandidates + appCandidates)
        } else {
            openOrder = uniqueURLList(appCandidates + webCandidates)
        }

        #if os(iOS)
        for candidate in openOrder where UIApplication.shared.canOpenURL(candidate) {
            UIApplication.shared.open(candidate)
            return
        }
        #endif
        if let firstWeb = webCandidates.first {
            openURL(firstWeb)
            return
        }
        if let firstCandidate = openOrder.first {
            openURL(firstCandidate)
        }
    }

    private func openExternalURL(_ url: URL) {
        #if os(iOS)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        #endif
        openURL(url)
    }

    private static let savedKey = "Cyclismo.savedRaceIds"
    private static let listenedKey = "Cyclismo.listenedRaceIds"
    private static let watchedKey = "Cyclismo.watchedRaceIds"
    private static let podcastPlayerPreferenceKey = "Cyclismo.podcastPlayerPreference"
    private static let streamOpenPreferenceKey = "Cyclismo.streamOpenPreference"
    private static let youtubeAppPreferenceKey = "Cyclismo.youtubeAppPreference"
    private static let migratedWatchedItPreferencesKey = "Cyclismo.migratedWatchedItPreferences"

    private var podcastPlayerPreference: PodcastPlayerPreference {
        PodcastPlayerPreference(rawValue: podcastPlayerPreferenceRaw) ?? .system
    }

    private var streamOpenPreference: StreamOpenPreference {
        StreamOpenPreference(rawValue: streamOpenPreferenceRaw) ?? .associatedAppFirst
    }

    private var youtubeAppPreference: YouTubeAppPreference {
        YouTubeAppPreference(rawValue: youtubeAppPreferenceRaw) ?? .defaultBrowser
    }

    private func preferredPodcastAppURLs(for link: ActionLink) -> [URL] {
        guard link.kind == .podcast else { return [] }
        let host = link.primaryURL.host?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return associatedPodcastAppURLs(for: link.primaryURL)
        }
        let rawQuery = link.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let query = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawQuery
        switch podcastPlayerPreference {
        case .system:
            return associatedPodcastAppURLs(for: link.primaryURL)
        case .apple:
            return [
                URL(string: "podcasts://search?term=\(query)"),
                URL(string: "podcasts://")
            ].compactMap { $0 }
        case .spotify:
            return [
                URL(string: "spotify://search/\(query)"),
                URL(string: "spotify://")
            ].compactMap { $0 }
        case .overcast:
            return [
                URL(string: "overcast://x-callback-url/search?q=\(query)"),
                URL(string: "overcast://")
            ].compactMap { $0 }
        case .pocketCasts:
            return [
                URL(string: "pktc://search/\(query)"),
                URL(string: "pktc://")
            ].compactMap { $0 }
        case .podLink:
            return [podLinkDeepLinkURL(for: link)].compactMap { $0 }
        }
    }

    private func podLinkDeepLinkURL(for link: ActionLink) -> URL? {
        guard link.kind == .podcast else { return nil }
        guard let feedURL = link.podcastFeedURL?.trimmingCharacters(in: .whitespacesAndNewlines), !feedURL.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "podmin"
        let episodeURL = link.podcastEpisodeURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let episodeTitle = link.podcastEpisodeTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEpisode = (episodeURL?.isEmpty == false) || (episodeTitle?.isEmpty == false)
        components.host = hasEpisode ? "episode" : "show"
        var items: [URLQueryItem] = [URLQueryItem(name: "feed", value: feedURL)]
        if let episodeURL, !episodeURL.isEmpty {
            items.append(URLQueryItem(name: "episode", value: episodeURL))
        }
        // Title fallback lets pod min resolve the episode when the feed's enclosure URL
        // differs from ours (or no episode URL is known).
        if let episodeTitle, !episodeTitle.isEmpty {
            items.append(URLQueryItem(name: "title", value: episodeTitle))
        }
        components.queryItems = items
        return components.url
    }

    private func associatedPodcastAppURLs(for url: URL) -> [URL] {
        let host = url.host?.lowercased() ?? ""
        if host.contains("podcasts.apple.com") {
            let rewritten = url.absoluteString.replacingOccurrences(of: "https://", with: "podcasts://")
            return [URL(string: rewritten), URL(string: "podcasts://")].compactMap { $0 }
        }
        if host.contains("open.spotify.com") {
            if let spotifyPath = spotifyAppPath(from: url) {
                return [URL(string: spotifyPath), URL(string: "spotify://")].compactMap { $0 }
            }
            return [URL(string: "spotify://")].compactMap { $0 }
        }
        if host.contains("overcast.fm") {
            return [URL(string: "overcast://")].compactMap { $0 }
        }
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return youtubeAppPreference.appURLs(for: url)
        }
        return []
    }

    private func spotifyAppPath(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard components.count >= 2 else { return nil }
        return "spotify://\(components[0])/\(components[1])"
    }

    private func uniqueURLList(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in urls {
            if seen.insert(url.absoluteString).inserted {
                result.append(url)
            }
        }
        return result
    }

    private func migrateWatchedItPreferencesIfNeeded() {
        if UserDefaults.standard.bool(forKey: Self.migratedWatchedItPreferencesKey) {
            return
        }

        if UserDefaults.standard.object(forKey: Self.podcastPlayerPreferenceKey) == nil,
           let watchedPodcastPreference = UserDefaults.standard.string(forKey: "WatchedIt.podcastPlayerPreference"),
           PodcastPlayerPreference(rawValue: watchedPodcastPreference) != nil {
            podcastPlayerPreferenceRaw = watchedPodcastPreference
            UserDefaults.standard.set(Date(), forKey: ICloudSyncManager.podcastPlayerPreferenceLastUpdatedKey)
        }

        if UserDefaults.standard.object(forKey: Self.streamOpenPreferenceKey) == nil,
           let watchedStreamPreference = UserDefaults.standard.string(forKey: "WatchedIt.streamOpenPreference"),
           StreamOpenPreference(rawValue: watchedStreamPreference) != nil {
            streamOpenPreferenceRaw = watchedStreamPreference
        }

        UserDefaults.standard.set(true, forKey: Self.migratedWatchedItPreferencesKey)
    }

    @ViewBuilder
    private func streamingRow(streamer: Streamer, stream: RaceStream) -> some View {
        let regions = stream.regionCodes.isEmpty ? nil : stream.regionCodes.joined(separator: ", ")

        if let actionLink = streamingActionLink(streamer: streamer, stream: stream) {
            Button(action: { openActionLink(actionLink) }) {
                LabeledContent(streamer.name, value: regions ?? "Watch")
            }
        } else {
            LabeledContent(streamer.name, value: regions ?? "—")
        }
    }

    @ViewBuilder
    private func podcastRow(_ podcast: RacePodcastEpisodeLink) -> some View {
        let thumbnailURL = podcastArtworkBySourceId[podcast.sourceId.lowercased()]
        if let actionLink = podcastActionLink(for: podcast) {
            Button(action: { openActionLink(actionLink) }) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    podcastThumbnail(url: thumbnailURL)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(podcast.sourceName)
                            .captionSmall()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(podcast.title)
                            .labelMedium()
                            .foregroundColor(DesignSystem.Color.accent)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let publishedAt = podcast.publishedAt, !publishedAt.isEmpty {
                            Text(publishedAt.prefix(10))
                                .captionMedium()
                                .foregroundColor(DesignSystem.Color.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                podcastThumbnail(url: thumbnailURL)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(podcast.sourceName)
                        .captionSmall()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(podcast.title)
                        .labelMedium()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let publishedAt = podcast.publishedAt, !publishedAt.isEmpty {
                        Text(publishedAt.prefix(10))
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func podcastThumbnail(url: URL?) -> some View {
        if let url {
            BlurredAsyncImage(url: url, initialBlurRadius: 20, fadeInDuration: 0.18) { image in
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

    private func podcastActionLink(for podcast: RacePodcastEpisodeLink) -> ActionLink? {
        let title = "\(podcast.sourceName): \(podcast.title)"
        let searchQuery = "\(podcast.sourceName) \(podcast.title)"
        let feedURL = podcastFeedURL(for: podcast)
        if let urlString = podcast.episodeUrl, let url = URL(string: urlString) {
            return ActionLink(
                title: title,
                primaryURL: url,
                fallbackURL: podcastSearchURL(podcast: podcast),
                kind: .podcast,
                searchQuery: searchQuery,
                podcastFeedURL: feedURL,
                podcastEpisodeTitle: podcast.title,
                podcastEpisodeURL: url.absoluteString
            )
        }
        if let searchURL = podcastSearchURL(podcast: podcast) {
            return ActionLink(
                title: title,
                primaryURL: searchURL,
                fallbackURL: nil,
                kind: .podcast,
                searchQuery: searchQuery,
                podcastFeedURL: feedURL,
                podcastEpisodeTitle: podcast.title
            )
        }
        return nil
    }

    @ViewBuilder
    private func stageTitleRow(_ stage: Stage) -> some View {
        Text(stageDisplayName(stage))
            .headlineSmall()
            .foregroundColor(DesignSystem.Color.accent)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stageDisplayName(_ stage: Stage) -> String {
        if stage.isRestDay {
            if let date = stage.date, !date.isEmpty {
                return "Rest day (\(date))"
            }
            return "Rest day"
        }

        let stageType = stage.stageType?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stageNumber = stage.stageNumber {
            if let title = stagePreferredTitle(stage), !title.isEmpty {
                if let stageType, !stageType.isEmpty, !stringsAreEquivalent(title, stageType) {
                    return "Stage \(stageNumber): \(title) (\(stageType))"
                }
                return "Stage \(stageNumber): \(title)"
            }
            return "Stage \(stageNumber)"
        }

        let base = stage.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stageType, !stageType.isEmpty, !stringsAreEquivalent(base, stageType), !base.isEmpty {
            return "\(base) (\(stageType))"
        }
        return base.isEmpty ? (stageType ?? stage.name) : base
    }

    private func stagePreferredTitle(_ stage: Stage) -> String? {
        let trimmedName = stage.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedType = stage.stageType?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let stageNumber = stage.stageNumber {
            if !trimmedName.isEmpty, !isGenericStageName(trimmedName, stageNumber: stageNumber) {
                return trimmedName
            }
            if let trimmedType, !trimmedType.isEmpty {
                return trimmedType
            }
            return nil
        }

        if !trimmedName.isEmpty {
            return trimmedName
        }
        if let trimmedType, !trimmedType.isEmpty {
            return trimmedType
        }
        return nil
    }

    private func isGenericStageName(_ value: String, stageNumber: Int) -> Bool {
        let compact = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        let number = String(stageNumber)
        let allowedSuffixes = ["", "a", "b"]
        let genericTokens = allowedSuffixes.map { "stage\(number)\($0)" }
        return genericTokens.contains(compact)
    }

    private func stringsAreEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        let normalize: (String) -> String = { value in
            value
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalize(lhs) == normalize(rhs)
    }

    private func stageMetaLine(_ stage: Stage) -> String? {
        var parts: [String] = []
        if let date = stage.date, !date.isEmpty {
            parts.append(date)
        }
        let route = [stage.startLocation, stage.endLocation]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if route.count == 2 {
            parts.append("\(route[0]) -> \(route[1])")
        }
        if let departTime = stage.departTimeLocal, !departTime.isEmpty {
            parts.append("Depart \(departTime)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    @ViewBuilder
    private func raceResultRow(_ result: RaceResult) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(raceResultDisplayName(result))
                .labelMedium()
                .foregroundColor(DesignSystem.Color.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtitle = raceResultSubtitle(result) {
                Text(subtitle)
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func raceResultDisplayName(_ result: RaceResult) -> String {
        if result.rank == 1 {
            return "Winner: \(result.athleteName)"
        }
        return "#\(result.rank) \(result.athleteName)"
    }

    private func raceResultSubtitle(_ result: RaceResult) -> String? {
        var parts: [String] = []
        if let teamName = result.teamName, !teamName.isEmpty {
            parts.append(teamName)
        }
        if let nationality = result.nationality, !nationality.isEmpty {
            parts.append(nationality)
        }
        if let resultText = result.resultText, !resultText.isEmpty {
            parts.append(resultText)
        }
        parts.append("Source: \(resultSourceLabel(result.source))")
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    private func resultSourceLabel(_ source: String) -> String {
        switch source.lowercased() {
        case "wikidata":
            return "Wikidata"
        case "pcs":
            return "PCS"
        case "official":
            return "Official"
        default:
            return source.isEmpty ? "Unknown" : source
        }
    }
}

private struct ActionLink: Identifiable {
    let title: String
    let primaryURL: URL
    let fallbackURL: URL?
    let kind: LinkKind
    var searchQuery: String? = nil
    var associatedAppURLs: [URL] = []
    var podcastFeedURL: String? = nil
    var podcastEpisodeTitle: String? = nil
    var podcastEpisodeURL: String? = nil

    var id: String { "\(title)-\(primaryURL.absoluteString)" }
}

private enum LinkKind {
    case stream
    case podcast
}

private enum StreamOpenPreference: String, CaseIterable {
    case associatedAppFirst = "associatedAppFirst"
    case webFirst = "webFirst"

    var title: String {
        switch self {
        case .associatedAppFirst:
            return "Try app first"
        case .webFirst:
            return "Prefer web links"
        }
    }
}

private struct StageDetailView: View {
    let race: Race
    let stage: Stage
    @State private var podcasts: [RacePodcastEpisodeLink] = []
    @Environment(\.openURL) private var openURL
    @AppStorage(ICloudSyncManager.podcastPlayerPreferenceKey) private var podcastPlayerPreferenceRaw = PodcastPlayerPreference.system.rawValue
    @AppStorage(ICloudSyncManager.youtubeAppPreferenceKey) private var youtubeAppPreferenceRaw = YouTubeAppPreference.defaultBrowser.rawValue
    @State private var stageResults: [StageResult] = []
    @State private var podcastFeedURLBySourceId: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(stageTitle)
                        .titleLarge()
                        .foregroundHeadline()
                    Text(race.name)
                        .labelMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)

                detailSection("Parent race") {
                    LabeledContent("Race", value: race.name)
                    LabeledContent("Dates", value: "\(race.startDate) -> \(race.endDate)")
                }

                detailSection("Stage details") {
                    if let date = stage.date {
                        LabeledContent("Date", value: date)
                    }
                    if let stageType = stage.stageType {
                        LabeledContent("Type", value: stageType)
                    }
                    if let start = stage.startLocation {
                        LabeledContent("Start", value: start)
                    }
                    if let end = stage.endLocation {
                        LabeledContent("Finish", value: end)
                    }
                    if let depart = stage.departTimeLocal {
                        LabeledContent("Depart", value: depart)
                    }
                }

                if !stageResults.isEmpty {
                    detailSection("Results") {
                        ForEach(stageResults) { result in
                            stageResultRow(result)
                        }
                    }
                }

                if podcasts.isEmpty {
                    detailSection("Stage podcasts") {
                        Text("No stage-specific podcasts yet. Use the parent race podcasts for full coverage.")
                            .bodyMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    detailSection("Stage podcasts") {
                        ForEach(podcasts) { podcast in
                            podcastRow(podcast)
                        }
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .navigationTitle(stageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let podcastSources = await BootstrapDataStore.shared.fetchPodcastSources()
            podcastFeedURLBySourceId = Dictionary(
                uniqueKeysWithValues: podcastSources.map { ($0.sourceId.lowercased(), $0.feedUrl) }
            )
            podcasts = (try? await APIClient.shared.fetchStagePodcasts(stageId: stage.stageId)) ?? []
            stageResults = (try? await APIClient.shared.fetchStageResults(stageId: stage.stageId)) ?? []
        }
        .themeBackground()
    }

    private var stageTitle: String {
        if stage.isRestDay {
            return stage.date.map { "Rest day \($0)" } ?? "Rest day"
        }
        if let stageNumber = stage.stageNumber {
            return "Stage \(stageNumber)"
        }
        return stage.name
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .headlineMedium()
                .foregroundHeadline()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                content()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.groupedListCardBackground.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
    }

    @ViewBuilder
    private func stageResultRow(_ result: StageResult) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(stageResultDisplayName(result))
                .labelMedium()
                .foregroundColor(DesignSystem.Color.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtitle = stageResultSubtitle(result) {
                Text(subtitle)
                    .captionMedium()
                    .foregroundColor(DesignSystem.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stageResultDisplayName(_ result: StageResult) -> String {
        if result.rank == 1 {
            return "Stage winner: \(result.athleteName)"
        }
        return "#\(result.rank) \(result.athleteName)"
    }

    private func stageResultSubtitle(_ result: StageResult) -> String? {
        var parts: [String] = []
        if let teamName = result.teamName, !teamName.isEmpty {
            parts.append(teamName)
        }
        if let nationality = result.nationality, !nationality.isEmpty {
            parts.append(nationality)
        }
        if let resultText = result.resultText, !resultText.isEmpty {
            parts.append(resultText)
        }
        parts.append("Source: \(resultSourceLabel(result.source))")
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    private func resultSourceLabel(_ source: String) -> String {
        switch source.lowercased() {
        case "wikidata":
            return "Wikidata"
        case "pcs":
            return "PCS"
        case "official":
            return "Official"
        default:
            return source.isEmpty ? "Unknown" : source
        }
    }

    @ViewBuilder
    private func podcastRow(_ podcast: RacePodcastEpisodeLink) -> some View {
        let label = "\(podcast.sourceName) - \(podcast.title)"
        if podcastPrimaryURL(for: podcast) != nil {
            Button(action: { openPodcast(for: podcast) }) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(label)
                        .labelMedium()
                        .foregroundColor(DesignSystem.Color.accent)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let publishedAt = podcast.publishedAt, !publishedAt.isEmpty {
                        Text(publishedAt.prefix(10))
                            .captionMedium()
                            .foregroundColor(DesignSystem.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(label)
                    .labelMedium()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let publishedAt = podcast.publishedAt, !publishedAt.isEmpty {
                    Text(publishedAt.prefix(10))
                        .captionMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var podcastPlayerPreference: PodcastPlayerPreference {
        PodcastPlayerPreference(rawValue: podcastPlayerPreferenceRaw) ?? .system
    }

    private var youtubeAppPreference: YouTubeAppPreference {
        YouTubeAppPreference(rawValue: youtubeAppPreferenceRaw) ?? .defaultBrowser
    }

    private func openPodcast(for podcast: RacePodcastEpisodeLink) {
        guard let primary = podcastPrimaryURL(for: podcast) else { return }
        let appCandidates = preferredPodcastAppURLs(primaryURL: primary, podcast: podcast)
        let webCandidates = [primary, podcastWebSearchURL(for: podcast)].compactMap { $0 }
        let openOrder = uniqueURLs(appCandidates + webCandidates)

        #if os(iOS)
        for candidate in openOrder where UIApplication.shared.canOpenURL(candidate) {
            UIApplication.shared.open(candidate)
            return
        }
        #endif

        if let firstWeb = webCandidates.first {
            openURL(firstWeb)
            return
        }
        if let firstCandidate = openOrder.first {
            openURL(firstCandidate)
        }
    }

    private func podcastPrimaryURL(for podcast: RacePodcastEpisodeLink) -> URL? {
        if let episodeURL = podcast.episodeUrl, let url = URL(string: episodeURL) {
            return url
        }
        return podcastWebSearchURL(for: podcast)
    }

    private func preferredPodcastAppURLs(primaryURL: URL, podcast: RacePodcastEpisodeLink) -> [URL] {
        let host = primaryURL.host?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return youtubeAppPreference.appURLs(for: primaryURL)
        }
        let rawQuery = "\(podcast.sourceName) \(podcast.title)"
        let query = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawQuery

        switch podcastPlayerPreference {
        case .system:
            return associatedPodcastAppURLs(for: primaryURL)
        case .apple:
            return [URL(string: "podcasts://search?term=\(query)"), URL(string: "podcasts://")].compactMap { $0 }
        case .spotify:
            return [URL(string: "spotify://search/\(query)"), URL(string: "spotify://")].compactMap { $0 }
        case .overcast:
            return [URL(string: "overcast://x-callback-url/search?q=\(query)"), URL(string: "overcast://")].compactMap { $0 }
        case .pocketCasts:
            return [URL(string: "pktc://search/\(query)"), URL(string: "pktc://")].compactMap { $0 }
        case .podLink:
            return [podLinkDeepLinkURL(podcast: podcast)].compactMap { $0 }
        }
    }

    private func podLinkDeepLinkURL(podcast: RacePodcastEpisodeLink) -> URL? {
        guard let feedURL = podcastFeedURLBySourceId[podcast.sourceId.lowercased()]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !feedURL.isEmpty else {
            return nil
        }

        let explicitEpisodeURL = podcast.episodeUrl?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let episodeTitle = podcast.title.trimmingCharacters(in: .whitespacesAndNewlines)

        var components = URLComponents()
        components.scheme = "podmin"
        let hasEpisode = (explicitEpisodeURL?.isEmpty == false) || !episodeTitle.isEmpty
        components.host = hasEpisode ? "episode" : "show"
        var items: [URLQueryItem] = [URLQueryItem(name: "feed", value: feedURL)]
        if let explicitEpisodeURL, !explicitEpisodeURL.isEmpty {
            items.append(URLQueryItem(name: "episode", value: explicitEpisodeURL))
        }
        // Title fallback lets pod min resolve the episode when the feed's enclosure URL
        // differs from ours (or no episode URL is known).
        if !episodeTitle.isEmpty {
            items.append(URLQueryItem(name: "title", value: episodeTitle))
        }
        components.queryItems = items
        return components.url
    }

    private func associatedPodcastAppURLs(for url: URL) -> [URL] {
        let host = url.host?.lowercased() ?? ""
        if host.contains("podcasts.apple.com") {
            let rewritten = url.absoluteString.replacingOccurrences(of: "https://", with: "podcasts://")
            return [URL(string: rewritten), URL(string: "podcasts://")].compactMap { $0 }
        }
        if host.contains("open.spotify.com") {
            let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            if components.count >= 2 {
                return [URL(string: "spotify://\(components[0])/\(components[1])"), URL(string: "spotify://")].compactMap { $0 }
            }
            return [URL(string: "spotify://")].compactMap { $0 }
        }
        if host.contains("overcast.fm") {
            return [URL(string: "overcast://")].compactMap { $0 }
        }
        return []
    }

    private func podcastWebSearchURL(for podcast: RacePodcastEpisodeLink) -> URL? {
        let rawQuery = "\(podcast.sourceName) \(podcast.title)"
        let encodedQuery = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawQuery
        switch podcastPlayerPreference {
        case .system, .apple:
            return URL(string: "https://podcasts.apple.com/search?term=\(encodedQuery)")
        case .spotify:
            return URL(string: "https://open.spotify.com/search/\(encodedQuery)")
        case .overcast:
            return URL(string: "https://overcast.fm/search?query=\(encodedQuery)")
        case .pocketCasts:
            return URL(string: "https://pocketcasts.com/search?q=\(encodedQuery)")
        case .podLink:
            return URL(string: "https://podcasts.apple.com/search?term=\(encodedQuery)")
        }
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in urls {
            if seen.insert(url.absoluteString).inserted {
                result.append(url)
            }
        }
        return result
    }
}
