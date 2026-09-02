import AppIntents
import Foundation

// MARK: - Transport

struct ResumePodLinkPlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Podcast in PodLink"
    static var description = IntentDescription("Continues the last episode or your saved session.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PodLinkIntentPlayback.resumePlayback()
        return .result(dialog: IntentDialog("Resuming PodLink."))
    }
}

struct PausePodLinkPlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause PodLink"
    static var description = IntentDescription("Pauses podcast playback.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            PlaybackService.shared.pause()
        }
        return .result(dialog: IntentDialog("Paused."))
    }
}

struct SkipForwardPodLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Forward in PodLink"
    static var description = IntentDescription("Skips ahead using your PodLink skip interval (default 30 seconds).")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            PlaybackService.shared.skipForward()
        }
        return .result(dialog: IntentDialog("Skipped forward."))
    }
}

struct SkipBackwardPodLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Back in PodLink"
    static var description = IntentDescription("Skips back using your PodLink skip interval (default 15 seconds).")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            PlaybackService.shared.skipBackward()
        }
        return .result(dialog: IntentDialog("Skipped back."))
    }
}

// MARK: - Play from library

struct PlayPodLinkEpisodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Episode in PodLink"
    static var description = IntentDescription("Plays an episode from a show in your PodLink library.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Episode")
    var episode: EpisodeLibraryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$episode) in PodLink")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PodLinkIntentPlayback.playEpisode(compositeID: episode.id)
        return .result(dialog: IntentDialog("Playing in PodLink."))
    }
}

struct PlayLatestPodLinkEpisodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Latest Episode in PodLink"
    static var description = IntentDescription("Plays the newest unplayed episode, or the latest if you’ve heard them all.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Podcast")
    var podcast: PodcastLibraryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Play the latest from \(\.$podcast) in PodLink")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PodLinkIntentPlayback.playLatestEpisode(podcastID: podcast.id)
        return .result(dialog: IntentDialog("Playing the latest episode."))
    }
}

struct PlayLatestAnyPodLinkEpisodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Latest Podcast in PodLink"
    static var description = IntentDescription("Plays the newest unfinished episode from your PodLink library.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PodLinkIntentPlayback.playLatestEpisode()
        return .result(dialog: IntentDialog("Playing the latest podcast."))
    }
}

struct PlayPodLinkShowByNameIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Show in PodLink"
    static var description = IntentDescription("Plays the latest unfinished episode from a followed show.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Show", requestValueDialog: IntentDialog("Which show do you want to play?"))
    var show: String

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$show) in PodLink")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PodLinkIntentPlayback.playShow(named: show)
        return .result(dialog: IntentDialog("Playing \(show) in PodLink."))
    }
}

// MARK: - Queue (Up Next)

struct AddPodLinkEpisodeToQueueIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Episode to PodLink Queue"
    static var description = IntentDescription("Adds an episode to Up Next without starting it.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Episode")
    var episode: EpisodeLibraryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Queue \(\.$episode) in PodLink")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let (podcastID, episodeID) = PodLinkIntentEpisodeID.parse(episode.id),
              let podcast = PodLinkIntentPlayback.followedPodcast(id: podcastID)
        else {
            throw PodLinkIntentError.podcastNotInLibrary
        }
        let episodes = try await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL)
        guard let raw = episodes.first(where: { $0.id == episodeID }) else {
            throw PodLinkIntentError.episodeNotFound
        }
        let merged = EpisodePlaybackStore.merge(raw)
        await MainActor.run {
            PlaybackService.shared.addToQueue(merged)
        }
        return .result(dialog: IntentDialog("Added to Up Next."))
    }
}

struct PlayNextInPodLinkQueueIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Next in PodLink Queue"
    static var description = IntentDescription("Starts the next episode in Up Next.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let empty = await MainActor.run { PlaybackService.shared.state.queue.isEmpty }
        if empty { throw PodLinkIntentError.queueEmpty }
        await PlaybackService.shared.playNextInQueue()
        return .result(dialog: IntentDialog("Playing the next episode in your queue."))
    }
}

struct PlayNextPodcastInPodLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Next Podcast in PodLink"
    static var description = IntentDescription("Starts the next queued episode, or the newest unfinished episode from your library.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await PodLinkIntentPlayback.playNextPodcast()
        return .result(dialog: IntentDialog("Playing the next podcast."))
    }
}

struct ClearPodLinkQueueIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear PodLink Queue"
    static var description = IntentDescription("Removes all episodes from Up Next.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            PlaybackService.shared.clearQueue()
        }
        return .result(dialog: IntentDialog("Up Next is cleared."))
    }
}

// MARK: - Speed

enum PodLinkPlaybackSpeedChoice: String, AppEnum {
    case half
    case threeQuarter
    case normal
    case oneQuarter
    case oneHalf
    case oneThreeQuarter
    case doubleSpeed
    case twoQuarter
    case twoHalf
    case twoThreeQuarter
    case triple

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Playback Speed")
    }

    static var caseDisplayRepresentations: [PodLinkPlaybackSpeedChoice: DisplayRepresentation] = [
        .half: "0.5×",
        .threeQuarter: "0.75×",
        .normal: "1×",
        .oneQuarter: "1.25×",
        .oneHalf: "1.5×",
        .oneThreeQuarter: "1.75×",
        .doubleSpeed: "2×",
        .twoQuarter: "2.25×",
        .twoHalf: "2.5×",
        .twoThreeQuarter: "2.75×",
        .triple: "3×"
    ]

    var rate: Float {
        switch self {
        case .half: return 0.5
        case .threeQuarter: return 0.75
        case .normal: return 1
        case .oneQuarter: return 1.25
        case .oneHalf: return 1.5
        case .oneThreeQuarter: return 1.75
        case .doubleSpeed: return 2
        case .twoQuarter: return 2.25
        case .twoHalf: return 2.5
        case .twoThreeQuarter: return 2.75
        case .triple: return 3
        }
    }
}

struct SetPodLinkPlaybackSpeedIntent: AppIntent {
    static var title: LocalizedStringResource = "Set PodLink Playback Speed"
    static var description = IntentDescription("Sets podcast playback speed.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Speed")
    var speed: PodLinkPlaybackSpeedChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Set PodLink speed to \(\.$speed)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            PlaybackService.shared.setRate(speed.rate)
        }
        return .result(dialog: IntentDialog("Updated playback speed."))
    }
}

// MARK: - Discover / add (Apple Podcasts–style catalog search + follow)

struct SearchPodcastsInPodLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Podcasts with PodLink"
    static var description = IntentDescription("Searches the podcast catalog (same source as Discover).")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Query", requestValueDialog: IntentDialog("What do you want to search for?"))
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search podcasts for \(\.$query)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PodLinkIntentError.searchFoundNoPodcasts
        }
        let results = try await PodcastSearchService.shared.search(query: trimmed, limit: 8)
        guard !results.isEmpty else {
            throw PodLinkIntentError.searchFoundNoPodcasts
        }
        let lines = results.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: "Top results:\n\(lines)"))
    }
}

struct FollowPodcastFromSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Podcast to PodLink Library"
    static var description = IntentDescription("Finds a show in the catalog and adds it to the podcasts you follow.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search", requestValueDialog: IntentDialog("Which podcast?"))
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Follow \(\.$query) in PodLink")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PodLinkIntentError.searchFoundNoPodcasts
        }
        let results = try await PodcastSearchService.shared.search(query: trimmed, limit: 5)
        guard let first = results.first else {
            throw PodLinkIntentError.searchFoundNoPodcasts
        }
        var library = await MainActor.run { Podcast.loadFollowedPodcasts() }
        if library.contains(where: { $0.id == first.id }) {
            throw PodLinkIntentError.podcastAlreadyInLibrary
        }
        var toAdd = first
        toAdd.isFollowed = true
        library.append(toAdd)
        await MainActor.run { Podcast.saveFollowedPodcasts(library) }
        return .result(dialog: IntentDialog("Added “\(first.title)” to your library."))
    }
}

// MARK: - App shortcuts

struct PodLinkShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ResumePodLinkPlaybackIntent(),
            phrases: [
                "Resume podcast in \(.applicationName)",
                "Continue listening in \(.applicationName)",
                "Continue in \(.applicationName)"
            ],
            shortTitle: "Resume",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: PausePodLinkPlaybackIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Pause podcast in \(.applicationName)"
            ],
            shortTitle: "Pause",
            systemImageName: "pause.circle.fill"
        )
        AppShortcut(
            intent: PlayLatestPodLinkEpisodeIntent(),
            phrases: [
                "Play the latest from \(\.$podcast) in \(.applicationName)",
                "Play \(\.$podcast) in \(.applicationName)",
                "Play podcast \(\.$podcast) in \(.applicationName)",
                "Play show \(\.$podcast) in \(.applicationName)"
            ],
            shortTitle: "Play latest",
            systemImageName: "dot.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: PlayLatestAnyPodLinkEpisodeIntent(),
            phrases: [
                "Play the latest podcast in \(.applicationName)",
                "Play latest episode in \(.applicationName)",
                "Play a podcast in \(.applicationName)"
            ],
            shortTitle: "Latest podcast",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: PlayNextPodcastInPodLinkIntent(),
            phrases: [
                "Play next podcast in \(.applicationName)",
                "Next podcast in \(.applicationName)",
                "Play next in queue in \(.applicationName)"
            ],
            shortTitle: "Next podcast",
            systemImageName: "forward.end.fill"
        )
        AppShortcut(
            intent: SkipForwardPodLinkIntent(),
            phrases: [
                "Skip forward in \(.applicationName)",
                "Go forward in \(.applicationName)"
            ],
            shortTitle: "Skip forward",
            systemImageName: "goforward.30"
        )
        AppShortcut(
            intent: SkipBackwardPodLinkIntent(),
            phrases: [
                "Skip back in \(.applicationName)",
                "Go back in \(.applicationName)"
            ],
            shortTitle: "Skip back",
            systemImageName: "gobackward.15"
        )
        AppShortcut(
            intent: PlayNextInPodLinkQueueIntent(),
            phrases: [
                "Play next in \(.applicationName)",
                "Play up next in \(.applicationName)"
            ],
            shortTitle: "Up Next",
            systemImageName: "text.line.first.and.arrowtriangle.forward"
        )
        AppShortcut(
            intent: SetPodLinkPlaybackSpeedIntent(),
            phrases: [
                "Set \(.applicationName) speed to \(\.$speed)",
                "Change \(.applicationName) playback speed to \(\.$speed)",
                "Set podcast speed in \(.applicationName) to \(\.$speed)"
            ],
            shortTitle: "Set speed",
            systemImageName: "speedometer"
        )
    }
}
