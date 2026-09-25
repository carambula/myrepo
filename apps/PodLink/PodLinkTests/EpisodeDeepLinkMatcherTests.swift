import Foundation
import Testing
@testable import PodLink

struct EpisodeDeepLinkMatcherTests {
    @Test
    func matchesFullRewatchablesSourceTitle() {
        let episodes = rockyFranchise()
        let matched = EpisodeDeepLinkMatcher.bestEpisode(
            in: episodes,
            matchingTitle: "‘Rocky’ With Bill Simmons, Chris Ryan, and Van Lathan"
        )
        #expect(matched?.id == "rocky-1")
    }

    @Test
    func prefersFirstFilmWhenHintIsJustRocky() {
        let matched = EpisodeDeepLinkMatcher.bestEpisode(in: rockyFranchise(), matchingTitle: "Rocky")
        #expect(matched?.id == "rocky-1")
    }

    @Test
    func doesNotPreferSequelWhenHintIsRocky() {
        let matched = EpisodeDeepLinkMatcher.bestEpisode(in: rockyFranchise(), matchingTitle: "Rocky (1976)")
        #expect(matched?.id == "rocky-1")
    }

    @Test
    func roundTripsWatchedItDeepLinkTitle() {
        var components = URLComponents()
        components.scheme = "podmin"
        components.host = "episode"
        components.queryItems = [
            URLQueryItem(name: "feed", value: "https://feeds.megaphone.fm/the-rewatchables"),
            URLQueryItem(name: "title", value: "‘Rocky’ With Bill Simmons, Chris Ryan, and Van Lathan"),
            URLQueryItem(name: "movie", value: "Rocky")
        ]
        let url = components.url!
        let deepLink = PodLinkDeepLink(url: url)
        guard case .episode(_, let hint) = deepLink else {
            Issue.record("expected episode deep link")
            return
        }
        #expect(hint.episodeTitle?.contains("Rocky") == true)
        #expect(hint.movieTitle == "Rocky")
        let matched = EpisodeDeepLinkMatcher.bestEpisode(in: rockyFranchise(), matchingTitle: hint.episodeTitle)
        #expect(matched?.id == "rocky-1")
    }

    @Test
    func episodeFilterDoesNotScanShowNotes() {
        let hit = episode(id: "title-hit", title: "Rocky", description: "")
        let notesOnly = episode(
            id: "notes-only",
            title: "Heat",
            description: "Bill talks about Rocky for an hour in these show notes."
        )
        let filtered = EpisodeListFilter.apply([hit, notesOnly], searchText: "Rocky", statusFilter: .all)
        #expect(filtered.map(\.id) == ["title-hit"])
    }

    private func rockyFranchise() -> [Episode] {
        [
            episode(id: "rocky-2", title: "‘Rocky II’ With Bill Simmons, Chris Ryan, and Van Lathan"),
            episode(id: "rocky-1", title: "‘Rocky’ With Bill Simmons, Chris Ryan, and Van Lathan"),
            episode(id: "rocky-3", title: "‘Rocky III’ With Bill Simmons, Cousin Sal, and Gus Ramsey"),
            episode(id: "rocky-4", title: "‘Rocky IV’ With Bill Simmons, Cousin Sal, and Kyle Brandt")
        ]
    }

    private func episode(id: String, title: String, description: String = "") -> Episode {
        Episode(
            id: id,
            podcastID: "rewatchables",
            title: title,
            description: description,
            publishDate: Date(timeIntervalSince1970: 1_000),
            audioURL: URL(string: "https://example.com/\(id).mp3")!
        )
    }
}
