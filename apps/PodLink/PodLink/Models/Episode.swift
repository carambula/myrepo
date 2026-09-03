import Foundation

struct Episode: Identifiable, Codable, Hashable {
    let id: String
    let podcastID: String
    let title: String
    let description: String
    let publishDate: Date
    let duration: TimeInterval
    let audioURL: URL
    let videoURL: URL?
    let artworkURL: URL?
    let episodeNumber: Int?
    let seasonNumber: Int?
    let transcript: String?
    let transcriptURL: URL?
    let chapters: [Chapter]?

    var playbackPosition: TimeInterval = 0
    var isPlayed: Bool = false
    var isBookmarked: Bool = false
    var isDownloaded: Bool = false
    var downloadedFileURL: URL?
    var mediaLinks: [MediaLink] = []

    var hasVideo: Bool { videoURL != nil }

    /// True when the episode is marked played or position/duration meets the “finished” thresholds.
    var isEffectivelyFinished: Bool {
        if isPlayed { return true }
        return PlaybackProgressPolicy.current.isFinished(playbackPosition: playbackPosition, duration: duration)
    }

    /// Partially listened (past “started” thresholds) but not finished — drives list progress UI and play-button style.
    var isInProgress: Bool {
        PlaybackProgressPolicy.current.shouldShowPartialProgress(
            isPlayed: isPlayed,
            playbackPosition: playbackPosition,
            duration: duration
        )
    }

    /// 0…1 for mini progress bars in episode lists (uses feed duration).
    var listProgressVisualFraction: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, playbackPosition / duration))
    }

    /// Any meaningful listening, including finished — used for “latest episode” dot on the main list.
    var hasBeenListenedTo: Bool {
        if isEffectivelyFinished { return true }
        return PlaybackProgressPolicy.current.hasMeaningfulProgress(
            playbackPosition: playbackPosition,
            duration: duration
        )
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var progressPercent: Double { listProgressVisualFraction }

    /// Episode-specific art when present; otherwise show art from the podcast (feeds often omit per-episode images).
    func resolvedArtworkURL(podcast: Podcast?) -> URL? {
        artworkURL ?? podcast?.displayArtworkURL
    }

    init(
        id: String = UUID().uuidString,
        podcastID: String,
        title: String,
        description: String = "",
        publishDate: Date = Date(),
        duration: TimeInterval = 0,
        audioURL: URL,
        videoURL: URL? = nil,
        artworkURL: URL? = nil,
        episodeNumber: Int? = nil,
        seasonNumber: Int? = nil,
        transcript: String? = nil,
        transcriptURL: URL? = nil,
        chapters: [Chapter]? = nil,
        playbackPosition: TimeInterval = 0,
        isPlayed: Bool = false,
        isBookmarked: Bool = false,
        isDownloaded: Bool = false,
        downloadedFileURL: URL? = nil,
        mediaLinks: [MediaLink] = []
    ) {
        self.id = id
        self.podcastID = podcastID
        self.title = title
        self.description = description
        self.publishDate = publishDate
        self.duration = duration
        self.audioURL = audioURL
        self.videoURL = videoURL
        self.artworkURL = artworkURL
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.transcript = transcript
        self.transcriptURL = transcriptURL
        self.chapters = chapters
        self.playbackPosition = playbackPosition
        self.isPlayed = isPlayed
        self.isBookmarked = isBookmarked
        self.isDownloaded = isDownloaded
        self.downloadedFileURL = downloadedFileURL
        self.mediaLinks = mediaLinks
    }
}

struct Chapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval?
    let imageURL: URL?
    let linkURL: URL?

    init(
        id: String = UUID().uuidString,
        title: String,
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        imageURL: URL? = nil,
        linkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.imageURL = imageURL
        self.linkURL = linkURL
    }
}
