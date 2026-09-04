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

    @Test func podcastIntakeSkipsConfusedBreakfastBrunchAndBlankCheckNoise() async throws {
        let service = PodcastEpisodeIntakeService.shared
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "confused-breakfast",
            rawTitle: "BRUNCH: Talking Movies With Our DADS!",
            cleanedTitle: "BRUNCH: Talking Movies With Our DADS!"
        ))
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "confused-breakfast",
            rawTitle: "BRUNCH- We Got These Movie Ratings WRONG...",
            cleanedTitle: "BRUNCH- We Got These Movie Ratings WRONG..."
        ))
        #expect(!service.shouldSkipPodcastNoise(
            sourceIdentifier: "confused-breakfast",
            rawTitle: "The Shawshank Redemption (1994)",
            cleanedTitle: "The Shawshank Redemption"
        ))
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "blank-check",
            rawTitle: "Patreon Mailbag",
            cleanedTitle: "Patreon Mailbag"
        ))
        #expect(!service.shouldSkipPodcastNoise(
            sourceIdentifier: "blank-check",
            rawTitle: "The Matrix",
            cleanedTitle: "The Matrix"
        ))
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "criterion-closet-picks",
            rawTitle: "Available January 15, 2025",
            cleanedTitle: "Available January 15, 2025"
        ))
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "rewatchables",
            rawTitle: "Available now",
            cleanedTitle: "Available now"
        ))
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "criterion-closet-picks",
            rawTitle: "Available March 4",
            cleanedTitle: "Available March 4"
        ))
        #expect(service.shouldSkipPodcastNoise(
            sourceIdentifier: "criterion-closet-picks",
            rawTitle: "Available 4/15/26",
            cleanedTitle: "Available 4/15/26"
        ))
        #expect(!service.shouldSkipPodcastNoise(
            sourceIdentifier: "rewatchables",
            rawTitle: "The Shawshank Redemption",
            cleanedTitle: "The Shawshank Redemption"
        ))
        #expect(!service.shouldSkipPodcastNoise(
            sourceIdentifier: "rewatchables",
            rawTitle: "Heat",
            cleanedTitle: "Heat"
        ))
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

    @Test func latestCarouselDateUsesClosetDiscoveryFallback() {
        let discovered = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(
            LatestPodcastPicker.entryDate(
                sourceIdentifier: ClosetPicksSource.identifier,
                sourceDate: nil,
                episodePublishDate: nil,
                discoveredAt: discovered
            ) == discovered
        )
        #expect(
            LatestPodcastPicker.entryDate(
                sourceIdentifier: "rewatchables",
                sourceDate: nil,
                episodePublishDate: nil,
                discoveredAt: discovered
            ) == nil
        )
    }

    @Test func latestCarouselIncludesMultipleClosetPicksFromLatestDrop() {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newest = Date(timeIntervalSince1970: 1_800_000_000)
        let ids = LatestPodcastPicker.carouselMovieIds(from: [
            .init(movieId: "closet-old-a", date: older, sourceIdentifier: ClosetPicksSource.identifier, groupKey: "old-drop"),
            .init(movieId: "closet-old-b", date: older, sourceIdentifier: ClosetPicksSource.identifier, groupKey: "old-drop"),
            .init(movieId: "closet-new-a", date: newest, sourceIdentifier: ClosetPicksSource.identifier, groupKey: "new-drop"),
            .init(movieId: "closet-new-b", date: newest, sourceIdentifier: ClosetPicksSource.identifier, groupKey: "new-drop"),
            .init(movieId: "closet-new-c", date: newest, sourceIdentifier: ClosetPicksSource.identifier, groupKey: "new-drop"),
            .init(movieId: "rewatchable", date: newest, sourceIdentifier: "rewatchables")
        ], multiEntryLimit: 3)
        #expect(ids == ["closet-new-a", "closet-new-b", "closet-new-c", "rewatchable"])
    }

    @Test func latestCarouselCapsClosetPicksAndKeepsOnePodcastPerSource() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var entries: [LatestPodcastPicker.Entry] = [
            .init(movieId: "rewatch-old", date: Date(timeIntervalSince1970: 1_700_000_000), sourceIdentifier: "rewatchables"),
            .init(movieId: "rewatch-new", date: date, sourceIdentifier: "rewatchables"),
            .init(movieId: "blank-check", date: date, sourceIdentifier: "blank-check")
        ]
        for index in 1...10 {
            entries.append(
                .init(
                    movieId: "closet-\(index)",
                    date: date,
                    sourceIdentifier: ClosetPicksSource.identifier,
                    groupKey: "guest-drop"
                )
            )
        }
        let ids = LatestPodcastPicker.carouselMovieIds(from: entries, limit: 8, multiEntryLimit: 5)
        #expect(ids.contains("rewatch-new"))
        #expect(!ids.contains("rewatch-old"))
        #expect(ids.contains("blank-check"))
        #expect(ids.filter { $0.hasPrefix("closet-") }.count == 5)
        #expect(ids.count == 7)
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

    @Test func latestPodcastSearchIncludesMultipleEpisodesPerShowAndCaps() {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let mid = Date(timeIntervalSince1970: 1_750_000_000)
        let newest = Date(timeIntervalSince1970: 1_800_000_000)
        let entries = [
            LatestPodcastPicker.Entry(movieId: "old-rewatchable", date: older, sourceIdentifier: "rewatchables"),
            LatestPodcastPicker.Entry(movieId: "new-rewatchable", date: newest, sourceIdentifier: "rewatchables"),
            LatestPodcastPicker.Entry(movieId: "mid-rewatchable", date: mid, sourceIdentifier: "rewatchables"),
            LatestPodcastPicker.Entry(movieId: "blank-check-old", date: older, sourceIdentifier: "blank-check"),
            LatestPodcastPicker.Entry(movieId: "blank-check-latest", date: mid, sourceIdentifier: "blank-check"),
            LatestPodcastPicker.Entry(movieId: "big-picture", date: newest, sourceIdentifier: "big-picture")
        ]
        #expect(
            LatestPodcastPicker.recentMovieIds(from: entries)
            == ["big-picture", "new-rewatchable", "blank-check-latest", "mid-rewatchable", "blank-check-old", "old-rewatchable"]
        )
        #expect(LatestPodcastPicker.recentMovieIds(from: entries, limit: 3) == ["big-picture", "new-rewatchable", "blank-check-latest"])
        #expect(LatestPodcastPicker.searchLimit == 100)
    }

    @Test func collectionHeaderSearchUsesFullListOrLatestCap() {
        let carousel = [
            Movie(id: "visible-1", title: "Heat"),
            Movie(id: "visible-2", title: "Fargo")
        ]
        let podcastSection = CollectionSection(
            id: "source-rewatchables",
            title: "The Rewatchables",
            subtitle: "Podcast collection",
            sourceIdentifier: "rewatchables",
            isRankedList: false,
            movies: carousel,
            headerSearchMovieIDs: nil
        )
        #expect(MovieQueryService.headerSearchScope(for: podcastSection) == .list(identifier: "rewatchables", isRankedList: false))

        let latestIDs = Set((1...120).map { "episode-\($0)" })
        let latestSection = CollectionSection(
            id: "inspiration-latest-podcasts",
            title: "Latest podcasts",
            subtitle: "Recent episodes",
            sourceIdentifier: nil,
            isRankedList: false,
            movies: carousel,
            headerSearchMovieIDs: latestIDs
        )
        #expect(MovieQueryService.headerSearchScope(for: latestSection) == .movieIDs(latestIDs))
        #expect(MovieQueryService.headerSearchMovieIDs(for: latestSection).count == 120)
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

    @Test func watchFilterMatchesEachStatusPair() {
        let rewatched = movie(isRewatched: true)
        let notRewatched = movie(isRewatched: false)
        let saved = movie(isSaved: true)
        let notSaved = movie(isSaved: false)
        let listened = movie(isListened: true)
        let notListened = movie(isListened: false)
        let complete = movie(isRewatched: true, isListened: true)
        let incompleteXOR = movie(isRewatched: true, isListened: false)
        let untouched = movie()

        #expect(WatchFilter.rewatched.matches(rewatched))
        #expect(!WatchFilter.rewatched.matches(notRewatched))
        #expect(WatchFilter.notRewatched.matches(notRewatched))
        #expect(!WatchFilter.notRewatched.matches(rewatched))

        #expect(WatchFilter.saved.matches(saved))
        #expect(!WatchFilter.saved.matches(notSaved))
        #expect(WatchFilter.notSaved.matches(notSaved))
        #expect(!WatchFilter.notSaved.matches(saved))

        #expect(WatchFilter.listened.matches(listened))
        #expect(!WatchFilter.listened.matches(notListened))
        #expect(WatchFilter.notListened.matches(notListened))
        #expect(!WatchFilter.notListened.matches(listened))

        #expect(WatchFilter.completed.matches(complete))
        #expect(!WatchFilter.completed.matches(incompleteXOR))
        #expect(WatchFilter.notComplete.matches(incompleteXOR))
        #expect(WatchFilter.notComplete.matches(untouched))
        #expect(!WatchFilter.notComplete.matches(complete))

        #expect(WatchFilter.incomplete.matches(incompleteXOR))
        #expect(!WatchFilter.incomplete.matches(complete))
        #expect(!WatchFilter.incomplete.matches(untouched))
        #expect(WatchFilter.all.matches(untouched))
    }

    @Test func theatricalFilterAndTicketLinks() {
        let run = TheatricalRun(tmdbId: 550, isInTheaters: true, hasIMAX: true, title: "Fight Club")
        #expect(run.matches(.inTheaters))
        #expect(run.matches(.imax))
        #expect(TheatricalTicketLinkBuilder.hasOptions(for: run))
        let groups = TheatricalTicketLinkBuilder.groups(for: run, title: "Fight Club", year: 1999)
        #expect(groups.map(\.headline) == ["Tickets", "IMAX"])
        #expect(groups[0].offers.contains(where: { $0.title == "Fandango" }))
        #expect(groups[1].offers.contains(where: { $0.url.absoluteString.contains("IMAX") }))

        let resolved = TheatricalRun(
            tmdbId: 550,
            isInTheaters: true,
            hasIMAX: false,
            title: "The End of Oak Street",
            ticketLinks: TheatricalTicketLinks(
                amc: "https://www.amctheatres.com/movies/the-end-of-oak-street-71226/showtimes"
            )
        )
        let amc = TheatricalTicketLinkBuilder.groups(for: resolved, title: "The End of Oak Street", year: 2026)
            .flatMap(\.offers)
            .first { $0.title == "AMC" }
        #expect(amc?.url.absoluteString == "https://www.amctheatres.com/movies/the-end-of-oak-street-71226/showtimes")

        var filters = MovieSearchFilters()
        filters.theatricalFilter = .imax
        let movie = Movie(title: "Fight Club", year: 1999, tmdbId: 550, theatricalRun: run)
        let filtered = MovieSearchEngine.filterMovies(
            movies: [movie, Movie(title: "Heat", year: 1995)],
            query: "",
            filters: filters,
            movieSearchIndex: [:],
            sourceCache: [:],
            restrictedMovieIDs: nil
        )
        #expect(filtered.map(\.title) == ["Fight Club"])
    }

    @Test func movieSearchEngineAppliesWatchFilterFromHomeToolbar() {
        let saved = movie(isSaved: true)
        let rewatched = movie(isRewatched: true)
        let listened = movie(isListened: true)
        let complete = movie(isRewatched: true, isListened: true)
        let movies = [saved, rewatched, listened, complete]
        let index = MovieSearchEngine.buildIndex(from: movies)

        func ids(for filter: WatchFilter) -> [String] {
            var filters = MovieSearchFilters()
            filters.watchFilter = filter
            return MovieSearchEngine.filterMovies(
                movies: movies,
                query: "",
                filters: filters,
                movieSearchIndex: index,
                sourceCache: [:],
                restrictedMovieIDs: nil
            ).map(\.id)
        }

        #expect(ids(for: .saved) == [saved.id])
        #expect(ids(for: .rewatched) == [rewatched.id, complete.id])
        #expect(ids(for: .listened) == [listened.id, complete.id])
        #expect(ids(for: .completed) == [complete.id])
        #expect(ids(for: .notSaved) == [rewatched.id, listened.id, complete.id])
        #expect(Set(ids(for: .all)) == Set(movies.map(\.id)))
    }

    @Test func watchFilterMenuIncludesPairedStatusCases() {
        let labels = WatchFilter.allCases.map(\.rawValue)
        #expect(labels.contains("Rewatched"))
        #expect(labels.contains("Not rewatched"))
        #expect(labels.contains("Saved"))
        #expect(labels.contains("Not saved"))
        #expect(labels.contains("Listened"))
        #expect(labels.contains("Not listened"))
        #expect(labels.contains("Complete"))
        #expect(labels.contains("Not complete"))
    }

    @Test func closetPicksKeepsListenedAffordanceWithoutPodcastEpisode() {
        #expect(ClosetPicksSource.showsListenedAction(hasPodcastEpisode: true, isOnClosetPicks: false))
        #expect(ClosetPicksSource.showsListenedAction(hasPodcastEpisode: false, isOnClosetPicks: true))
        #expect(ClosetPicksSource.showsListenedAction(hasPodcastEpisode: true, isOnClosetPicks: true))
        #expect(!ClosetPicksSource.showsListenedAction(hasPodcastEpisode: false, isOnClosetPicks: false))
    }

    @Test func closetPicksDestinationPrefersEpisodePageThenIndex() {
        let episodeURL = "https://www.criterion.com/current/closet-picks-matthew-mcconaughey"
        #expect(ClosetPicksSource.destinationURL(sourceUrl: episodeURL, episodeId: nil).absoluteString == episodeURL)
        #expect(
            ClosetPicksSource.destinationURL(
                sourceUrl: nil,
                episodeId: "https://www.criterion.com/current/posts/123"
            ).absoluteString == "https://www.criterion.com/current/posts/123"
        )
        #expect(ClosetPicksSource.destinationURL(sourceUrl: "not-a-url", episodeId: nil) == ClosetPicksSource.indexURL)
        #expect(ClosetPicksSource.destinationURL(sourceUrl: nil, episodeId: nil) == ClosetPicksSource.indexURL)
    }

    @Test func closetPicksMenuTitleUsesEpisodeName() {
        #expect(
            ClosetPicksSource.menuTitle(
                sourceTitle: "Matthew McConaughey's Closet Picks",
                sourceName: "Criterion Closet Picks"
            ) == "Matthew McConaughey's Closet Picks"
        )
        #expect(
            ClosetPicksSource.menuTitle(sourceTitle: "  ", sourceName: "Criterion Closet Picks")
                == "Criterion Closet Picks"
        )
        #expect(ClosetPicksSource.menuTitle(sourceTitle: nil, sourceName: nil) == "Criterion Closet Picks")
    }

    private func movie(
        isRewatched: Bool = false,
        isListened: Bool = false,
        isSaved: Bool = false
    ) -> Movie {
        Movie(
            title: "Test",
            isRewatched: isRewatched,
            isListened: isListened,
            isSaved: isSaved
        )
    }

}
