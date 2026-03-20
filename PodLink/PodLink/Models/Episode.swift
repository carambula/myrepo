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
    var isInProgress: Bool { playbackPosition > 0 && !isPlayed }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var progressPercent: Double {
        guard duration > 0 else { return 0 }
        return playbackPosition / duration
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
