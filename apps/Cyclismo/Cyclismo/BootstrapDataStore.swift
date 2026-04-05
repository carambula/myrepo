import Foundation

actor BootstrapDataStore {
    static let shared = BootstrapDataStore()

    private var payload: BootstrapPayload?
    private var hasLoaded = false
    private let fileName = "bootstrap_database.json"

    private var bundleURL: URL? {
        Bundle.main.url(forResource: "bootstrap_database", withExtension: "json")
    }

    private var storedURL: URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent("Cyclismo", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    func loadIfNeeded() async {
        if hasLoaded { return }
        hasLoaded = true

        do {
            let bundleData = bundleURL.flatMap { try? Data(contentsOf: $0) }
            var bundlePayload: BootstrapPayload?
            if let bundleData {
                bundlePayload = await decodeBootstrapPayload(bundleData)
            }

            var storedPayload: BootstrapPayload?
            if let storedURL, FileManager.default.fileExists(atPath: storedURL.path) {
                if let data = try? Data(contentsOf: storedURL) {
                    storedPayload = await decodeBootstrapPayload(data)
                }
            }

            if let bundlePayload, let storedPayload {
                let bundleHasStreamers = (bundlePayload.streamers ?? []).isEmpty == false
                let storedHasStreamers = (storedPayload.streamers ?? []).isEmpty == false
                let bundleHasPodcasts = (bundlePayload.podcastEpisodes ?? []).isEmpty == false
                let storedHasPodcasts = (storedPayload.podcastEpisodes ?? []).isEmpty == false
                let bundleHasArtwork = bundlePayload.races.first?.imageUrl != nil
                let storedHasArtwork = storedPayload.races.first?.imageUrl != nil
                let useBundle = bundlePayload.races.count > storedPayload.races.count
                    || (bundleHasStreamers && !storedHasStreamers)
                    || bundleHasStreamers
                    || (bundleHasPodcasts && !storedHasPodcasts)
                    || bundleHasPodcasts
                    || (bundleHasArtwork && !storedHasArtwork)
                if useBundle {
                    payload = bundlePayload
                    if let storedURL, let bundleData {
                        try FileManager.default.createDirectory(
                            at: storedURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        try bundleData.write(to: storedURL, options: .atomic)
                    }
                } else {
                    payload = storedPayload
                }
                return
            }

            if let storedPayload {
                payload = storedPayload
                return
            }

            if let bundlePayload {
                payload = bundlePayload
                if let storedURL, let bundleData {
                    try FileManager.default.createDirectory(
                        at: storedURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try bundleData.write(to: storedURL, options: .atomic)
                }
                return
            }
        } catch {
            payload = nil
        }
    }

    func fetchRaces(filters: RaceFilters) async -> [Race] {
        await loadIfNeeded()
        guard var races = payload?.races else { return [] }

        if let startDate = filters.startDate {
            races = races.filter { $0.startDate >= startDate }
        }
        if let endDate = filters.endDate {
            races = races.filter { $0.endDate <= endDate }
        }
        if let series = filters.series, !series.isEmpty {
            races = races.filter { $0.series.caseInsensitiveCompare(series) == .orderedSame }
        }
        if let discipline = filters.discipline, !discipline.isEmpty {
            races = races.filter { $0.discipline.caseInsensitiveCompare(discipline) == .orderedSame }
        }
        if let raceType = filters.raceType, !raceType.isEmpty {
            races = races.filter { $0.raceType.caseInsensitiveCompare(raceType) == .orderedSame }
        }
        if let gender = filters.genderDivision, !gender.isEmpty {
            races = races.filter { ($0.genderDivision ?? "").caseInsensitiveCompare(gender) == .orderedSame }
        }
        if let classification = filters.classification, !classification.isEmpty {
            races = races.filter { ($0.classification ?? "").caseInsensitiveCompare(classification) == .orderedSame }
        }
        if let streamerId = filters.streamerId, !streamerId.isEmpty, let raceStreams = payload?.raceStreams {
            let raceIds = Set(raceStreams.filter { $0.streamerId == streamerId }.map(\.raceId))
            races = races.filter { raceIds.contains($0.raceId) }
        }

        switch filters.sortOrder {
        case .date:
            races = races.sorted { $0.startDate < $1.startDate }
        case .alphabetical:
            races = races.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return Array(races.prefix(filters.limit))
    }

    func fetchStreamers() async -> [Streamer] {
        await loadIfNeeded()
        return payload?.streamers ?? []
    }

    func fetchFilterOptions() async -> (classifications: [String], formats: [String], genders: [String]) {
        await loadIfNeeded()
        guard let races = payload?.races else { return ([], [], []) }
        let classifications = Array(Set(races.compactMap(\.classification).filter { !$0.isEmpty })).sorted()
        let formats = Array(Set(races.map(\.raceType))).sorted()
        let genders = Array(Set(races.compactMap(\.genderDivision).filter { !$0.isEmpty })).sorted()
        return (classifications, formats, genders)
    }

    func fetchRace(id: String) async -> Race? {
        await loadIfNeeded()
        return payload?.races.first { $0.raceId == id }
    }

    func fetchStreamers(for raceId: String) async -> [(streamer: Streamer, stream: RaceStream)] {
        await loadIfNeeded()
        guard let payload else { return [] }
        let streamers = payload.streamers ?? []
        let raceStreams = payload.raceStreams ?? []
        return raceStreams
            .filter { $0.raceId == raceId }
            .compactMap { stream in
                streamers.first { $0.streamerId == stream.streamerId }.map { (streamer: $0, stream: stream) }
            }
    }

    func fetchRaceIdsWithStreamers() async -> Set<String> {
        await loadIfNeeded()
        guard let raceStreams = payload?.raceStreams else { return [] }
        return Set(raceStreams.map(\.raceId))
    }

    func fetchRaceIdToStreamerNames() async -> [String: [String]] {
        await loadIfNeeded()
        guard let payload else { return [:] }
        let streamers = payload.streamers ?? []
        let streamerById = Dictionary(uniqueKeysWithValues: streamers.map { ($0.streamerId, $0.name) })
        var result: [String: Set<String>] = [:]
        for stream in payload.raceStreams ?? [] {
            if let name = streamerById[stream.streamerId] {
                result[stream.raceId, default: []].insert(name)
            }
        }
        return result.mapValues { Array($0).sorted() }
    }

    func fetchRacePodcasts(
        raceId: String,
        raceName: String? = nil,
        raceStartDate: String? = nil
    ) async -> [RacePodcastEpisodeLink] {
        await loadIfNeeded()
        guard let payload else { return [] }
        let raceLinks = payload.racePodcastEpisodes ?? []
        let stageLinks = payload.stagePodcastEpisodes ?? []
        let stages = payload.stages ?? []
        let episodes = payload.podcastEpisodes ?? []
        let sources = payload.podcastSources ?? []
        let episodeById = Dictionary(uniqueKeysWithValues: episodes.map { ($0.episodeId, $0) })
        let sourceById = Dictionary(uniqueKeysWithValues: sources.map { ($0.sourceId, $0) })
        let resolvedRaceIds = resolvedRaceIds(
            primaryRaceId: raceId,
            raceName: raceName,
            raceStartDate: raceStartDate
        )
        let stageIdsForRace = Set(stages.filter { resolvedRaceIds.contains($0.raceId) }.map(\.stageId))

        let joinedRace = raceLinks
            .filter { resolvedRaceIds.contains($0.raceId) }
            .compactMap { link -> RacePodcastEpisodeLink? in
                guard let episode = episodeById[link.episodeId] else { return nil }
                let source = sourceById[episode.sourceId]
                return RacePodcastEpisodeLink(
                    episodeId: episode.episodeId,
                    sourceId: episode.sourceId,
                    sourceSlug: source?.slug,
                    sourceName: source?.name ?? "Podcast",
                    title: episode.title,
                    rawTitle: episode.rawTitle,
                    description: episode.description,
                    episodeUrl: episode.episodeUrl,
                    publishedAt: episode.publishedAt,
                    matchedBy: link.matchedBy
                )
            }
        let joinedStage = stageLinks
            .filter { stageIdsForRace.contains($0.stageId) }
            .compactMap { link -> RacePodcastEpisodeLink? in
                guard let episode = episodeById[link.episodeId] else { return nil }
                let source = sourceById[episode.sourceId]
                return RacePodcastEpisodeLink(
                    episodeId: episode.episodeId,
                    sourceId: episode.sourceId,
                    sourceSlug: source?.slug,
                    sourceName: source?.name ?? "Podcast",
                    title: episode.title,
                    rawTitle: episode.rawTitle,
                    description: episode.description,
                    episodeUrl: episode.episodeUrl,
                    publishedAt: episode.publishedAt,
                    matchedBy: link.matchedBy
                )
            }
        var seenEpisodeIds: Set<String> = []
        let joined = (joinedRace + joinedStage).filter { seenEpisodeIds.insert($0.episodeId).inserted }

        return joined.sorted {
            ($0.publishedAt ?? "") > ($1.publishedAt ?? "")
        }
    }

    func fetchRaceStages(raceId: String, raceName: String? = nil, raceStartDate: String? = nil) async -> [Stage] {
        await loadIfNeeded()
        let allStages = payload?.stages ?? []

        let direct = allStages.filter { $0.raceId == raceId }
        if !direct.isEmpty {
            return Self.sortStages(direct)
        }

        guard
            let raceName,
            !raceName.isEmpty,
            let raceStartDate,
            !raceStartDate.isEmpty
        else {
            return []
        }

        let normalizedRaceName = Self.normalizedRaceName(raceName)
        let matchingRaceIds = Set(
            (payload?.races ?? [])
                .filter { race in
                    race.startDate == raceStartDate &&
                    Self.normalizedRaceName(race.name) == normalizedRaceName
                }
                .map(\.raceId)
        )
        guard !matchingRaceIds.isEmpty else { return [] }
        let matchedByIdentity = allStages.filter { matchingRaceIds.contains($0.raceId) }
        return Self.sortStages(matchedByIdentity)
    }

    func fetchStage(id: String) async -> Stage? {
        await loadIfNeeded()
        return payload?.stages?.first { $0.stageId == id }
    }

    private static func normalizedRaceName(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sortStages(_ stages: [Stage]) -> [Stage] {
        stages.sorted { lhs, rhs in
            let leftDate = lhs.date ?? "9999-12-31"
            let rightDate = rhs.date ?? "9999-12-31"
            if leftDate != rightDate { return leftDate < rightDate }
            let leftNumber = lhs.stageNumber ?? Int.max
            let rightNumber = rhs.stageNumber ?? Int.max
            if leftNumber != rightNumber { return leftNumber < rightNumber }
            return lhs.name < rhs.name
        }
    }

    private func resolvedRaceIds(
        primaryRaceId: String,
        raceName: String?,
        raceStartDate: String?
    ) -> Set<String> {
        var ids: Set<String> = [primaryRaceId]
        guard let payload else { return ids }
        guard let raceName, !raceName.isEmpty, let raceStartDate, !raceStartDate.isEmpty else {
            return ids
        }

        let normalizedRaceName = Self.normalizedRaceName(raceName)
        for race in payload.races where race.startDate == raceStartDate {
            if Self.normalizedRaceName(race.name) == normalizedRaceName {
                ids.insert(race.raceId)
            }
        }
        return ids
    }

    func fetchStagePodcasts(stageId: String) async -> [RacePodcastEpisodeLink] {
        await loadIfNeeded()
        guard let payload else { return [] }
        let stageLinks = payload.stagePodcastEpisodes ?? []
        let episodes = payload.podcastEpisodes ?? []
        let sources = payload.podcastSources ?? []
        let episodeById = Dictionary(uniqueKeysWithValues: episodes.map { ($0.episodeId, $0) })
        let sourceById = Dictionary(uniqueKeysWithValues: sources.map { ($0.sourceId, $0) })
        let joined = stageLinks
            .filter { $0.stageId == stageId }
            .compactMap { link -> RacePodcastEpisodeLink? in
                guard let episode = episodeById[link.episodeId] else { return nil }
                let source = sourceById[episode.sourceId]
                return RacePodcastEpisodeLink(
                    episodeId: episode.episodeId,
                    sourceId: episode.sourceId,
                    sourceSlug: source?.slug,
                    sourceName: source?.name ?? "Podcast",
                    title: episode.title,
                    rawTitle: episode.rawTitle,
                    description: episode.description,
                    episodeUrl: episode.episodeUrl,
                    publishedAt: episode.publishedAt,
                    matchedBy: link.matchedBy
                )
            }
        return joined.sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    func fetchRaceResults(raceId: String) async -> [RaceResult] {
        await loadIfNeeded()
        let results = payload?.raceResults ?? []
        return results
            .filter { $0.raceId == raceId }
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return ($0.updatedAt ?? "") > ($1.updatedAt ?? "")
            }
    }

    func fetchStageResults(stageId: String) async -> [StageResult] {
        await loadIfNeeded()
        let results = payload?.stageResults ?? []
        return results
            .filter { $0.stageId == stageId }
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return ($0.updatedAt ?? "") > ($1.updatedAt ?? "")
            }
    }

    func fetchPodcastSources() async -> [PodcastSource] {
        await loadIfNeeded()
        return payload?.podcastSources ?? []
    }

    func fetchTeam(id: String) async -> Team? {
        await loadIfNeeded()
        return payload?.teams.first { $0.teamId == id }
    }

    func fetchAthlete(id: String) async -> Athlete? {
        await loadIfNeeded()
        return payload?.athletes.first { $0.athleteId == id }
    }

    func fetchTeamRaces(id: String, upcomingOnly: Bool) async -> [Race] {
        await loadIfNeeded()
        guard let payload else { return [] }
        let raceIds = payload.participants
            .filter { $0.teamId == id }
            .map { $0.raceId }
        var races = payload.races.filter { raceIds.contains($0.raceId) }
        if upcomingOnly {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
            races = races.filter { $0.startDate >= today }
        }
        return races.sorted { $0.startDate < $1.startDate }
    }

    func fetchAthleteRaces(id: String, upcomingOnly: Bool) async -> [Race] {
        await loadIfNeeded()
        guard let payload else { return [] }
        let raceIds = payload.participants
            .filter { $0.athleteId == id }
            .map { $0.raceId }
        var races = payload.races.filter { raceIds.contains($0.raceId) }
        if upcomingOnly {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
            races = races.filter { $0.startDate >= today }
        }
        return races.sorted { $0.startDate < $1.startDate }
    }

    func search(query: String) async -> SearchResults {
        await loadIfNeeded()
        let needle = query.lowercased()
        let races = payload?.races.filter { race in
            race.name.lowercased().contains(needle) ||
            (race.locationCity?.lowercased().contains(needle) ?? false) ||
            (race.locationCountry?.lowercased().contains(needle) ?? false)
        } ?? []
        let teams = payload?.teams.filter { $0.name.lowercased().contains(needle) } ?? []
        let athletes = payload?.athletes.filter { $0.fullName.lowercased().contains(needle) } ?? []
        return SearchResults(races: races, teams: teams, athletes: athletes)
    }

    @MainActor
    private func decodeBootstrapPayload(_ data: Data) -> BootstrapPayload? {
        try? JSONDecoder.cyclismo.decode(BootstrapPayload.self, from: data)
    }
}
