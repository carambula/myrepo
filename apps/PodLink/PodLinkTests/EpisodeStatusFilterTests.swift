import Foundation
import Testing
@testable import PodLink

struct EpisodeStatusFilterTests {
    @Test
    func statusFilterMatchesEachPair() {
        let saved = episode(isBookmarked: true)
        let unsaved = episode(isBookmarked: false)
        let listened = episode(isPlayed: true)
        let unlistened = episode()
        let complete = episode(isPlayed: true)
        let incomplete = episode(playbackPosition: 40, duration: 600)
        let downloaded = episode(isDownloaded: true)
        let notDownloaded = episode(isDownloaded: false)

        #expect(EpisodeStatusFilter.saved.matches(saved))
        #expect(!EpisodeStatusFilter.saved.matches(unsaved))
        #expect(EpisodeStatusFilter.notSaved.matches(unsaved))
        #expect(!EpisodeStatusFilter.notSaved.matches(saved))

        #expect(EpisodeStatusFilter.listened.matches(listened))
        #expect(!EpisodeStatusFilter.listened.matches(unlistened))
        #expect(EpisodeStatusFilter.notListened.matches(unlistened))
        #expect(!EpisodeStatusFilter.notListened.matches(listened))

        #expect(EpisodeStatusFilter.complete.matches(complete))
        #expect(!EpisodeStatusFilter.complete.matches(incomplete))
        #expect(EpisodeStatusFilter.notComplete.matches(incomplete))
        #expect(!EpisodeStatusFilter.notComplete.matches(complete))

        #expect(EpisodeStatusFilter.downloaded.matches(downloaded))
        #expect(!EpisodeStatusFilter.downloaded.matches(notDownloaded))
        #expect(EpisodeStatusFilter.notDownloaded.matches(notDownloaded))
        #expect(!EpisodeStatusFilter.notDownloaded.matches(downloaded))

        #expect(EpisodeStatusFilter.all.matches(unlistened))
        #expect(EpisodeStatusFilter.all.matches(downloaded))
    }

    @Test
    func libraryFiltersCombineStatusVideoAndCategory() {
        let comedyPodcast = Podcast(
            id: "show-1",
            title: "Comedy Hour",
            author: "Jane",
            feedURL: URL(string: "https://example.com/comedy.xml")!,
            categories: ["Comedy"]
        )
        let newsPodcast = Podcast(
            id: "show-2",
            title: "Daily News",
            author: "Sam",
            feedURL: URL(string: "https://example.com/news.xml")!,
            categories: ["News"]
        )
        let savedVideo = episode(
            podcastID: comedyPodcast.id,
            videoURL: URL(string: "https://example.com/video.mp4"),
            isBookmarked: true
        )
        let savedAudio = episode(podcastID: comedyPodcast.id, isBookmarked: true)

        let filters = LibrarySearchFilters(
            status: .saved,
            showNewOnly: false,
            showVideoOnly: true,
            selectedCategory: .comedy
        )

        #expect(filters.matches(episode: savedVideo, podcast: comedyPodcast))
        #expect(!filters.matches(episode: savedAudio, podcast: comedyPodcast))
        #expect(!filters.matches(episode: savedVideo, podcast: newsPodcast))
        #expect(filters.matchesDiscover(comedyPodcast))
        #expect(!filters.matchesDiscover(newsPodcast))
    }

    @Test
    func newOnlyExcludesOlderEpisodes() {
        let podcast = Podcast(
            id: "show-3",
            title: "Fresh",
            author: "A",
            feedURL: URL(string: "https://example.com/fresh.xml")!
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recent = episode(publishDate: now.addingTimeInterval(-2 * 24 * 60 * 60))
        let old = episode(publishDate: now.addingTimeInterval(-30 * 24 * 60 * 60))
        var filters = LibrarySearchFilters()
        filters.showNewOnly = true

        #expect(filters.matches(episode: recent, podcast: podcast, now: now))
        #expect(!filters.matches(episode: old, podcast: podcast, now: now))
    }

    private func episode(
        podcastID: String = "podcast-1",
        publishDate: Date = Date(),
        duration: TimeInterval = 600,
        videoURL: URL? = nil,
        playbackPosition: TimeInterval = 0,
        isPlayed: Bool = false,
        isBookmarked: Bool = false,
        isDownloaded: Bool = false
    ) -> Episode {
        Episode(
            id: UUID().uuidString,
            podcastID: podcastID,
            title: "Episode",
            publishDate: publishDate,
            duration: duration,
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            videoURL: videoURL,
            playbackPosition: playbackPosition,
            isPlayed: isPlayed,
            isBookmarked: isBookmarked,
            isDownloaded: isDownloaded
        )
    }
}
