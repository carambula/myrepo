import Foundation
import Testing
@testable import PodLink

struct EpisodeQueueBuilderTests {
    @Test
    func picksNewestUnfinishedWithoutNeedingOlderEpisodesMerged() {
        let finishedNewer = episode(id: "new", date: date(2025, 5, 1), isPlayed: true)
        let unfinishedOlder = episode(id: "old", date: date(2025, 4, 1), isPlayed: false)
        let finishedOldest = episode(id: "ancient", date: date(2018, 1, 1), isPlayed: true)

        let pick = EpisodeQueueBuilder.latestUnfinished(
            in: [finishedOldest, unfinishedOlder, finishedNewer]
        )
        #expect(pick?.id == "old")
    }

    @Test
    func skipsExcludedCurrentEpisode() {
        let current = episode(id: "current", date: date(2025, 6, 1), isPlayed: false)
        let next = episode(id: "next", date: date(2025, 5, 1), isPlayed: false)

        let pick = EpisodeQueueBuilder.latestUnfinished(in: [current, next], excluding: "current")
        #expect(pick?.id == "next")
    }

    @Test
    func returnsNilWhenEveryEpisodeIsFinished() {
        let episodes = [
            episode(id: "a", date: date(2025, 1, 1), isPlayed: true),
            episode(id: "b", date: date(2024, 1, 1), isPlayed: true)
        ]
        #expect(EpisodeQueueBuilder.latestUnfinished(in: episodes) == nil)
    }

    private func episode(id: String, date: Date, isPlayed: Bool) -> Episode {
        Episode(
            id: id,
            podcastID: "show",
            title: id,
            publishDate: date,
            duration: 3_600,
            audioURL: URL(string: "https://example.com/\(id).mp3")!,
            isPlayed: isPlayed,
            playbackPosition: isPlayed ? 3_600 : 0
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
