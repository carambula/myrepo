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
        #expect(service.cleanPodcastTitle("Gone with the Wind With Bill Simmons and Chris Ryan") == "Gone with the Wind")
        #expect(service.cleanPodcastTitle("The Man with the Golden Gun") == "The Man with the Golden Gun")
        #expect(service.cleanPodcastTitle("'Taxi Driver' With Bill Simmons and Chris Ryan") == "Taxi Driver")
    }

    @Test func tmdbSearchInputExtractsYearFromTrailingSuffix() async throws {
        let service = PodcastEpisodeIntakeService.shared
        let input = service.buildTMDBSearchInput(rawTitle: "The Thing (1982)")
        #expect(input.query == "The Thing")
        #expect(input.year == 1982)
    }

    @Test func physicalMediaEncodesAndDecodes() throws {
        let media = PhysicalMedia(
            editions: [
                PhysicalEdition(id: "c-4k", label: .criterion, format: .uhd4k, spineNumber: "42")
            ],
            hasCriterion: true,
            has4K: true,
            hasBluRay: true
        )
        let data = try JSONEncoder().encode(media)
        let decoded = try JSONDecoder().decode(PhysicalMedia.self, from: data)
        #expect(decoded.hasCriterion)
        #expect(decoded.has4K)
        #expect(decoded.editions.first?.spineNumber == "42")
        #expect(decoded.editions.first?.displayLine == "Criterion   4K UHD   Spine 42")
    }

    @Test func physicalMediaMergeKeepsManualOverride() {
        let stored = PhysicalMedia(hasCriterion: true, has4K: false, manualOverride: true)
        let inferred = PhysicalMedia(
            editions: [PhysicalEdition(label: .arrow, format: .uhd4k)],
            has4K: true
        )
        let merged = stored.merging(inferred: inferred)
        #expect(merged.manualOverride)
        #expect(merged.hasCriterion)
        #expect(!merged.has4K)
        #expect(merged.editions.isEmpty)
    }

    @Test func physicalMediaMergeUnionsInferredData() {
        let stored = PhysicalMedia(hasCriterion: true)
        let inferred = PhysicalMedia(
            editions: [PhysicalEdition(id: "arrow", label: .arrow, format: .uhd4k)],
            has4K: true
        )
        let merged = stored.merging(inferred: inferred)
        #expect(merged.hasCriterion)
        #expect(merged.has4K)
        #expect(merged.editions.contains(where: { $0.label == .arrow }))
    }

    @Test func physicalMediaSearchTokensMatchQueries() {
        let media = PhysicalMedia(
            editions: [PhysicalEdition(label: .criterion, format: .uhd4k, spineNumber: "1")],
            hasCriterion: true,
            has4K: true
        )
        #expect(media.matchesSearchQuery("criterion"))
        #expect(media.matchesSearchQuery("4k"))
        #expect(media.matchesSearchQuery("uhd"))
        #expect(!media.matchesSearchQuery("shout"))
    }

    @Test func physicalMediaSearchIndexIncludesTokens() {
        let movie = Movie(
            title: "Seven Samurai",
            year: 1954,
            tmdbId: 346,
            physicalMedia: PhysicalMedia(hasCriterion: true, has4K: true)
        )
        let index = MovieSearchEngine.buildIndex(from: [movie])
        let haystack = index[movie.id] ?? ""
        #expect(haystack.contains("criterion"))
        #expect(haystack.contains("4k"))
    }

    @Test func latestPodcastCarouselKeepsOneNewestPerSource() {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let mid = Date(timeIntervalSince1970: 1_750_000_000)
        let newest = Date(timeIntervalSince1970: 1_800_000_000)
        let ids = LatestPodcastPicker.carouselMovieIds(from: [
            .init(movieId: "old-rewatchable", date: older, sourceIdentifier: "rewatchables"),
            .init(movieId: "new-rewatchable", date: newest, sourceIdentifier: "rewatchables"),
            .init(movieId: "mid-rewatchable", date: mid, sourceIdentifier: "rewatchables"),
            .init(movieId: "blank-check-old", date: older, sourceIdentifier: "blank-check"),
            .init(movieId: "blank-check-latest", date: mid, sourceIdentifier: "blank-check"),
            .init(movieId: "big-picture", date: newest, sourceIdentifier: "big-picture")
        ])
        #expect(ids == ["new-rewatchable", "big-picture", "blank-check-latest"])
    }

    @Test func latestPodcastCarouselDedupesSharedMovieAcrossSources() {
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        let ids = LatestPodcastPicker.carouselMovieIds(from: [
            .init(movieId: "shared", date: earlier, sourceIdentifier: "rewatchables"),
            .init(movieId: "shared", date: later, sourceIdentifier: "blank-check"),
            .init(movieId: "other", date: earlier, sourceIdentifier: "big-picture")
        ])
        #expect(ids == ["shared", "other"])
    }

    @Test func podcastSourceCarouselIsLatestFirstAndIgnoresMissingDates() {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newest = Date(timeIntervalSince1970: 1_800_000_000)
        let ids = LatestPodcastPicker.sourceCarouselMovieIds(from: [
            .init(movieId: "undated-saved", date: nil, title: "Heat"),
            .init(movieId: "older-episode", date: older, title: "Fargo"),
            .init(movieId: "newest-episode", date: newest, title: "Zodiac")
        ])
        #expect(ids == ["newest-episode", "older-episode", "undated-saved"])
    }

    @Test func minCloudSourceLinkDecodesEpisodeDate() throws {
        let json = Data(#"""
        {"identifier":"rewatchables","sourceTitle":"Heat","episodeDate":"2026-01-15T12:00:00.000Z"}
        """#.utf8)
        let link = try JSONDecoder().decode(MinCloudMovieCatalog.Movie.SourceLink.self, from: json)
        #expect(link.identifier == "rewatchables")
        #expect(link.episodeDate == "2026-01-15T12:00:00.000Z")
    }

    @Test func movieRoundTripKeepsPhysicalMedia() throws {
        let movie = Movie(
            title: "The Night of the Hunter",
            year: 1955,
            tmdbId: 1152,
            physicalMedia: PhysicalMedia(hasCriterion: true, has4K: true)
        )
        let data = try JSONEncoder().encode(movie)
        let decoded = try JSONDecoder().decode(Movie.self, from: data)
        #expect(decoded.physicalMedia?.hasCriterion == true)
        #expect(decoded.physicalMedia?.has4K == true)
    }

    @Test func physicalPurchaseLinksIncludeBoutiqueAndMarketplaces() {
        let media = PhysicalMedia(
            editions: [
                PhysicalEdition(id: "c-4k", label: .criterion, format: .uhd4k, spineNumber: "2")
            ],
            hasCriterion: true,
            has4K: true
        )
        let groups = PhysicalPurchaseLinkBuilder.groups(
            for: media,
            title: "Seven Samurai",
            year: 1954
        )
        #expect(groups.count == 1)
        #expect(groups[0].headline == "Criterion   4K UHD   Spine 2")
        let retailers = groups[0].offers.map(\.retailer)
        #expect(retailers == [.criterion, .amazon, .ebay])
        #expect(groups[0].offers.contains { offer in
            offer.retailer == .criterion && offer.url.absoluteString.contains("criterion.com/search")
        })
        #expect(groups[0].offers.contains { offer in
            offer.retailer == .amazon
                && offer.url.absoluteString.contains("amazon.com/s")
                && offer.url.absoluteString.contains("Seven")
                && offer.url.absoluteString.contains("1954")
                && offer.url.absoluteString.contains("4K")
        })
    }

    @Test func physicalPurchaseFlagOnlyStillOffersAmazon() {
        let media = PhysicalMedia(has4K: true)
        #expect(PhysicalPurchaseLinkBuilder.hasOptions(for: media))
        let groups = PhysicalPurchaseLinkBuilder.groups(for: media, title: "The Matrix", year: 1999)
        #expect(groups.count == 1)
        #expect(groups[0].headline == "4K")
        #expect(groups[0].offers.contains { $0.retailer == .amazon })
        #expect(groups[0].offers.contains { $0.retailer == .ebay })
        #expect(!groups[0].offers.contains { $0.retailer == .criterion })
    }

    @Test func physicalPurchaseEmptyMediaHasNoOffers() {
        #expect(!PhysicalPurchaseLinkBuilder.hasOptions(for: nil))
        #expect(!PhysicalPurchaseLinkBuilder.hasOptions(for: PhysicalMedia()))
        #expect(PhysicalPurchaseLinkBuilder.groups(for: nil, title: "Heat", year: 1995).isEmpty)
    }

    @Test func physicalPurchaseCompactOffersDedupesRetailers() {
        let media = PhysicalMedia(
            editions: [
                PhysicalEdition(id: "c-4k", label: .criterion, format: .uhd4k),
                PhysicalEdition(id: "arrow", label: .arrow, format: .bluRay)
            ],
            hasCriterion: true,
            has4K: true
        )
        let offers = PhysicalPurchaseLinkBuilder.compactOffers(
            for: media,
            title: "Heat",
            year: 1995
        )
        let retailers = offers.map(\.retailer)
        #expect(retailers == [.arrow, .amazon, .ebay, .criterion])
    }

}
