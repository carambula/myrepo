//
//  WatchedItTests.swift
//  WatchedItTests
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Testing
@testable import WatchedIt

struct WatchedItTests {

    @Test func podcastIntakeStopsAtLatestKnownDate() async throws {
        let service = PodcastEpisodeIntakeService.shared
        let latestKnownDate = service.parseRSSDate("Mon, 01 Jan 2024 12:00:00 +0000")
        let sourceState = PodcastFeedSourceState(
            sourceIdentifier: "rewatchables",
            existingSourceTitles: [],
            latestEpisodeDate: latestKnownDate,
            latestKnownSourceTitle: "Existing Episode",
            latestKnownSourceTitleNormalized: ""
        )

        let evaluation = service.evaluateFeedCandidates(
            items: [
                .init(title: "Brand New Episode", pubDate: "Tue, 02 Jan 2024 12:00:00 +0000"),
                .init(title: "Older Episode", pubDate: "Mon, 01 Jan 2024 11:00:00 +0000")
            ],
            sourceState: sourceState
        )

        #expect(evaluation.candidateTitles == ["Brand New Episode"])
        #expect(evaluation.stoppedEarly == true)
        #expect(evaluation.stopReason == "latest-known-date")
    }

    @Test func podcastIntakeStopsAtLatestKnownTitle() async throws {
        let service = PodcastEpisodeIntakeService.shared
        let sourceState = PodcastFeedSourceState(
            sourceIdentifier: "rewatchables",
            existingSourceTitles: [],
            latestEpisodeDate: nil,
            latestKnownSourceTitle: "The Stop Marker",
            latestKnownSourceTitleNormalized: service.normalizeEpisodeTitle("The Stop Marker")
        )

        let evaluation = service.evaluateFeedCandidates(
            items: [
                .init(title: "Episode Above Marker", pubDate: "Tue, 02 Jan 2024 12:00:00 +0000"),
                .init(title: "The Stop Marker", pubDate: "Mon, 01 Jan 2024 12:00:00 +0000"),
                .init(title: "Episode Below Marker", pubDate: "Sun, 31 Dec 2023 12:00:00 +0000")
            ],
            sourceState: sourceState
        )

        #expect(evaluation.candidateTitles == ["Episode Above Marker"])
        #expect(evaluation.stoppedEarly == true)
        #expect(evaluation.stopReason == "latest-known-title")
    }

    @Test func podcastIntakeSkipsBigPictureNoise() async throws {
        let service = PodcastEpisodeIntakeService.shared
        #expect(service.shouldSkipPodcastNoise(sourceIdentifier: "big-picture", rawTitle: "Oscars Mailbag 2026", cleanedTitle: "Oscars Mailbag 2026"))
        #expect(!service.shouldSkipPodcastNoise(sourceIdentifier: "big-picture", rawTitle: "Heat", cleanedTitle: "Heat"))
    }

    @Test func podcastTitleCleaningRemovesTrailingYearSuffix() async throws {
        let service = PodcastEpisodeIntakeService.shared
        #expect(service.cleanPodcastTitle("Heat (1995)") == "Heat")
        #expect(service.cleanPodcastTitle("Heat [1995]") == "Heat")
    }

    @Test func tmdbSearchInputExtractsYearFromTrailingSuffix() async throws {
        let service = PodcastEpisodeIntakeService.shared
        let input = service.buildTMDBSearchInput(rawTitle: "The Thing (1982)")
        #expect(input.query == "The Thing")
        #expect(input.year == 1982)
    }

}
