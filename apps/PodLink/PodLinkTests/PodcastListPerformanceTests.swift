import Foundation
import Testing
@testable import PodLink

struct PodcastListPerformanceTests {
    @Test
    func listSortPutsUnplayedLatestAheadOfFinished() {
        let unplayedShow = podcast(id: "a", title: "Alpha")
        let finishedShow = podcast(id: "b", title: "Beta")
        let emptyShow = podcast(id: "c", title: "Gamma")

        let newerUnplayed = episode(
            id: "ep-a",
            podcastID: "a",
            publishDate: Date(timeIntervalSince1970: 2_000),
            isPlayed: false
        )
        let olderFinished = episode(
            id: "ep-b",
            podcastID: "b",
            publishDate: Date(timeIntervalSince1970: 3_000),
            isPlayed: true
        )

        let sorted = PodcastListSorter.sort(
            [finishedShow, emptyShow, unplayedShow],
            latestEpisodes: [
                "a": newerUnplayed,
                "b": olderFinished
            ]
        )

        #expect(sorted.map(\.id) == ["a", "b", "c"])
        #expect(PodcastListSorter.sortGroup(for: newerUnplayed) == 0)
        #expect(PodcastListSorter.sortGroup(for: olderFinished) == 1)
        #expect(PodcastListSorter.sortGroup(for: nil) == 2)
    }

    @Test
    func listSortBreaksDateTiesByTitle() {
        let date = Date(timeIntervalSince1970: 1_000)
        let zebra = podcast(id: "z", title: "Zebra")
        let apple = podcast(id: "a", title: "Apple")
        let latest = [
            "z": episode(id: "ez", podcastID: "z", publishDate: date),
            "a": episode(id: "ea", podcastID: "a", publishDate: date)
        ]

        let sorted = PodcastListSorter.sort([zebra, apple], latestEpisodes: latest)
        #expect(sorted.map(\.id) == ["a", "z"])
    }

    @Test
    func episodeFilterReturnsSameArrayWhenIdle() {
        let episodes = [
            episode(id: "1", podcastID: "p", title: "One"),
            episode(id: "2", podcastID: "p", title: "Two")
        ]
        let filtered = EpisodeListFilter.apply(episodes, searchText: "  ", statusFilter: .all)
        #expect(filtered == episodes)
    }

    @Test
    func episodeFilterMatchesTitleAndStatus() {
        let listened = episode(id: "1", podcastID: "p", title: "Morning News", isPlayed: true)
        let fresh = episode(id: "2", podcastID: "p", title: "Evening News", isPlayed: false)
        let episodes = [listened, fresh]

        let byTitle = EpisodeListFilter.apply(episodes, searchText: "morning", statusFilter: .all)
        #expect(byTitle.map(\.id) == ["1"])

        let unlistened = EpisodeListFilter.apply(episodes, searchText: "", statusFilter: .notListened)
        #expect(unlistened.map(\.id) == ["2"])
    }

    private func podcast(id: String, title: String) -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: "Host",
            feedURL: URL(string: "https://example.com/\(id).xml")!
        )
    }

    private func episode(
        id: String,
        podcastID: String,
        title: String = "Episode",
        publishDate: Date = Date(),
        isPlayed: Bool = false
    ) -> Episode {
        Episode(
            id: id,
            podcastID: podcastID,
            title: title,
            publishDate: publishDate,
            duration: 600,
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            isPlayed: isPlayed
        )
    }
}
