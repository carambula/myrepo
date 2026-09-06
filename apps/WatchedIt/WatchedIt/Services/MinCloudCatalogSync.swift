import Foundation
import SwiftData

struct CatalogApplyResult {
    var added = 0
    var updated = 0
    var newSourceLinks = 0
    var unmatched = 0
}

@MainActor
final class MinCloudCatalogSync {
    static let shared = MinCloudCatalogSync()
    private init() {}

    func syncIfAvailable(modelContext: ModelContext, force: Bool = false) async -> String {
        let reachable = await MinCloudClient.shared.isReachable()
        guard reachable else {
            return "Min Cloud unavailable. Using the local catalog."
        }
        do {
            let localCount = ((try? modelContext.fetchCount(FetchDescriptor<MovieData>())) ?? LocalDatabaseManager.shared.movies.count)
            let meta = try? await MinCloudClient.shared.fetchCatalogMeta()
            let hasSyncedBefore = MinCloudSettings.lastCatalogSyncedAt != nil
            let remoteCount = meta?.movieCount
            let shouldSkip = !force
                && hasSyncedBefore
                && meta?.revision == MinCloudSettings.lastCatalogRevision
                && (remoteCount == nil || remoteCount! <= localCount)

            if shouldSkip, let meta {
                return "Catalog already current (\(localCount) titles, revision \(meta.revision))."
            }

            let remoteHasMore = (remoteCount ?? 0) > localCount
            let revisionChanged = meta.map { $0.revision != MinCloudSettings.lastCatalogRevision } ?? true
            let needsFullPull = force || !hasSyncedBefore || remoteHasMore || revisionChanged
            let catalog = try await MinCloudClient.shared.fetchMovieCatalog(
                updatedSince: needsFullPull ? nil : MinCloudSettings.lastCatalogSyncedAt
            )
            let result = apply(catalog, modelContext: modelContext, reconcile: needsFullPull)
            let catalogCount = catalog.total ?? meta?.movieCount ?? catalog.movies.count
            MinCloudSettings.lastCatalogRevision = catalog.revision
            MinCloudSettings.lastCatalogSyncedAt = catalog.generatedAt ?? ISO8601DateFormatter().string(from: Date())
            MinCloudSettings.lastCatalogMovieCount = catalogCount
            LocalDatabaseManager.shared.refreshMovies()
            LocalDatabaseManager.shared.noteCatalogChanged()
            let incomplete = catalog.movies.count < catalogCount
            var unmatchedNote = result.unmatched > 0 ? " \(result.unmatched) titles have no TMDB match." : ""
            if let remoteUnmatched = meta?.unmatchedCount, remoteUnmatched > result.unmatched {
                unmatchedNote = " \(remoteUnmatched) titles have no TMDB match."
            }
            let incompleteNote = incomplete
                ? " Incomplete catalog: received \(catalog.movies.count) of \(catalogCount) titles."
                : ""
            if result.added > 0 {
                return "Added \(result.added) new titles, updated \(result.updated). Catalog \(catalogCount) titles, revision \(catalog.revision).\(unmatchedNote)\(incompleteNote)"
            }
            return "No new titles. Catalog \(catalogCount) titles, revision \(catalog.revision).\(unmatchedNote)\(incompleteNote)"
        } catch {
            return "Min Cloud sync failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func applyStreaming(tmdbId: Int, providers: [StreamingService], modelContext: ModelContext) -> Bool {
        guard !providers.isEmpty else { return false }
        let existing = (try? modelContext.fetch(FetchDescriptor<MovieData>())) ?? []
        guard let movie = existing.first(where: { $0.tmdbId == tmdbId }) else { return false }
        movie.streamingServices = providers
        try? modelContext.save()
        LocalDatabaseManager.shared.refreshMovies()
        return true
    }

    @discardableResult
    func apply(_ catalog: MinCloudMovieCatalog, modelContext: ModelContext, reconcile: Bool = false) -> CatalogApplyResult {
        let existing = (try? modelContext.fetch(FetchDescriptor<MovieData>())) ?? []
        var byId: [String: MovieData] = [:]
        var byTmdb: [Int: MovieData] = [:]
        for movie in existing {
            byId[movie.id] = movie
            if let tmdbId = movie.tmdbId {
                byTmdb[tmdbId] = movie
            }
        }

        let existingSources = (try? modelContext.fetch(FetchDescriptor<DataSource>())) ?? []
        var sourceById: [String: DataSource] = [:]
        for source in existingSources {
            sourceById[source.identifier] = source
        }
        for source in catalog.sources {
            if sourceById[source.identifier] == nil {
                let created = DataSource(
                    identifier: source.identifier,
                    name: source.name,
                    type: source.type,
                    url: source.url,
                    isEnabled: source.enabled ?? true,
                    isRankedList: source.is_ranked ?? false
                )
                modelContext.insert(created)
                sourceById[source.identifier] = created
            }
        }

        let existingContents = (try? modelContext.fetch(FetchDescriptor<SourceContent>())) ?? []
        var contentKeys = Set<String>()
        var contentByKey: [String: SourceContent] = [:]
        for content in existingContents {
            if let movieId = content.movie?.id, let sourceId = content.source?.identifier {
                let key = "\(movieId)|\(sourceId)"
                contentKeys.insert(key)
                contentByKey[key] = content
            }
        }

        var result = CatalogApplyResult()
        for remote in catalog.movies {
            let poster = remote.posterPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard remote.tmdbId != nil, !poster.isEmpty else {
                continue
            }
            let movie = byId[remote.id] ?? remote.tmdbId.flatMap { byTmdb[$0] }
            let providers = (remote.streamingServices ?? []).compactMap { provider -> StreamingService? in
                let name = provider.name ?? provider.providerName
                guard let name, !name.isEmpty else { return nil }
                return StreamingService(
                    id: provider.id ?? String(provider.providerId ?? 0),
                    name: name,
                    logoPath: provider.logoPath,
                    url: provider.url
                )
            }

            if let movie {
                if movie.id == remote.id, !remote.title.isEmpty {
                    movie.title = remote.title
                }
                if movie.id == remote.id, let year = remote.year {
                    movie.year = year
                }
                if !providers.isEmpty {
                    movie.streamingServices = providers
                }
                if let overview = remote.overview, !overview.isEmpty {
                    movie.overview = overview
                }
                if let poster = remote.posterPath {
                    movie.posterPath = poster
                }
                if let backdrop = remote.backdropPath {
                    movie.backdropPath = backdrop
                }
                applyPhysicalMedia(remote.physicalMedia, to: movie)
                if let credits = remote.credits {
                    movie.credits = credits
                }
                if let trailer = remote.trailer {
                    movie.trailer = trailer
                }
                if let oscars = remote.oscarAwards {
                    movie.oscarAwards = oscars
                }
                result.updated += 1
                if remote.tmdbId == nil {
                    result.unmatched += 1
                }
                let beforeLinks = contentKeys.count
                attachSources(
                    remote,
                    movie: movie,
                    sourceById: sourceById,
                    contentKeys: &contentKeys,
                    contentByKey: &contentByKey,
                    modelContext: modelContext
                )
                result.newSourceLinks += contentKeys.count - beforeLinks
                continue
            }

            let created = MovieData(
                id: remote.id,
                title: remote.title,
                year: remote.year,
                tmdbId: remote.tmdbId,
                posterPath: remote.posterPath,
                backdropPath: remote.backdropPath,
                overview: remote.overview,
                mpaaRating: remote.mpaaRating,
                genres: remote.genres ?? [],
                streamingServices: providers,
                credits: remote.credits,
                trailer: remote.trailer,
                oscarAwards: remote.oscarAwards,
                physicalMedia: remote.physicalMedia
            )
            modelContext.insert(created)
            byId[created.id] = created
            if let tmdbId = created.tmdbId {
                byTmdb[tmdbId] = created
            }
            attachSources(
                remote,
                movie: created,
                sourceById: sourceById,
                contentKeys: &contentKeys,
                contentByKey: &contentByKey,
                modelContext: modelContext
            )
            result.added += 1
            if created.tmdbId == nil {
                result.unmatched += 1
            }
        }

        if reconcile {
            reconcileSources(catalog, contentByKey: &contentByKey, contentKeys: &contentKeys, modelContext: modelContext)
            pruneDataPoorMovies(existing: existing, modelContext: modelContext)
        }

        try? modelContext.save()
        return result
    }

    private func movieHasUserFlags(_ movie: MovieData) -> Bool {
        if let user = movie.userData {
            if user.isSaved || user.isRewatched || user.isListened || user.isWatched { return true }
            if user.userRating != nil { return true }
            if let notes = user.userNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        }
        if let states = movie.states {
            return states.contains { $0.isSaved || $0.isRewatched || $0.isListened }
        }
        return false
    }

    private func pruneDataPoorMovies(existing: [MovieData], modelContext: ModelContext) {
        for movie in existing {
            let poster = movie.posterPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let dataPoor = movie.tmdbId == nil || poster.isEmpty
            guard dataPoor, !movieHasUserFlags(movie) else { continue }
            modelContext.delete(movie)
        }
    }

    private func reconcileSources(
        _ catalog: MinCloudMovieCatalog,
        contentByKey: inout [String: SourceContent],
        contentKeys: inout Set<String>,
        modelContext: ModelContext
    ) {
        var allowed = Set<String>()
        var remoteMovieIds = Set<String>()
        var remoteTmdbIds = Set<Int>()
        for remote in catalog.movies {
            remoteMovieIds.insert(remote.id)
            if let tmdbId = remote.tmdbId {
                remoteTmdbIds.insert(tmdbId)
            }
            for link in remote.sources ?? [] {
                guard let identifier = link.identifier else { continue }
                allowed.insert("\(remote.id)|\(identifier)")
                if let tmdbId = remote.tmdbId {
                    allowed.insert("tmdb-\(tmdbId)|\(identifier)")
                }
            }
        }
        for (key, content) in contentByKey {
            guard let movie = content.movie, let sourceId = content.source?.identifier else { continue }
            let onRemote = remoteMovieIds.contains(movie.id) || (movie.tmdbId.map { remoteTmdbIds.contains($0) } ?? false)
            guard onRemote else { continue }
            let tmdbKey = movie.tmdbId.map { "tmdb-\($0)|\(sourceId)" }
            if allowed.contains("\(movie.id)|\(sourceId)") || (tmdbKey != nil && allowed.contains(tmdbKey!)) {
                continue
            }
            guard content.source?.type == "podcast" else { continue }
            modelContext.delete(content)
            contentKeys.remove(key)
        }
    }

    private func applyPhysicalMedia(_ remote: PhysicalMedia?, to movie: MovieData) {
        guard let remote, !remote.isEmpty else { return }
        if let existing = movie.physicalMedia {
            movie.physicalMedia = existing.merging(inferred: remote)
        } else {
            movie.physicalMedia = remote
        }
    }

    private func attachSources(
        _ remote: MinCloudMovieCatalog.Movie,
        movie: MovieData,
        sourceById: [String: DataSource],
        contentKeys: inout Set<String>,
        contentByKey: inout [String: SourceContent],
        modelContext: ModelContext
    ) {
        for link in remote.sources ?? [] {
            guard let identifier = link.identifier, let source = sourceById[identifier] else { continue }
            let key = "\(movie.id)|\(identifier)"
            let episodeDate = Self.parseCatalogDate(link.episodeDate) ?? Self.parseCatalogDate(link.episode?.publishDate)
            let episode = Self.podcastEpisode(from: link, movieTitle: remote.title, fallbackDate: episodeDate)
            if let existing = contentByKey[key] {
                if existing.sourceTitle == nil || existing.sourceTitle?.isEmpty == true {
                    existing.sourceTitle = link.sourceTitle
                }
                if let episodeDate {
                    if let current = existing.sourceDate {
                        existing.sourceDate = max(current, episodeDate)
                    } else {
                        existing.sourceDate = episodeDate
                    }
                }
                if existing.podcastEpisode == nil {
                    existing.podcastEpisode = episode
                } else if let episode, let incomingDate = episode.publishDate {
                    let current = existing.podcastEpisode?.publishDate
                    if current == nil || incomingDate > current! {
                        existing.podcastEpisode = episode
                    }
                }
                if let rank = link.rank {
                    existing.rank = rank
                }
                if existing.sourceUrl == nil || existing.sourceUrl?.isEmpty == true {
                    existing.sourceUrl = Self.sourceUrl(from: link)
                }
                continue
            }
            let content = SourceContent(
                movie: movie,
                source: source,
                sourceTitle: link.sourceTitle,
                sourceDescription: link.episode?.description,
                sourceDate: episodeDate,
                rank: link.rank,
                podcastEpisode: episode,
                sourceUrl: Self.sourceUrl(from: link)
            )
            modelContext.insert(content)
            contentKeys.insert(key)
            contentByKey[key] = content
        }
    }

    private static func sourceUrl(from link: MinCloudMovieCatalog.Movie.SourceLink) -> String? {
        if let episodeId = link.episode?.episodeId?.trimmingCharacters(in: .whitespacesAndNewlines),
           episodeId.hasPrefix("http") {
            return episodeId
        }
        return nil
    }

    private static func podcastEpisode(
        from link: MinCloudMovieCatalog.Movie.SourceLink,
        movieTitle: String,
        fallbackDate: Date?
    ) -> PodcastEpisode? {
        let title = link.episode?.title ?? link.sourceTitle ?? movieTitle
        let date = fallbackDate ?? Self.parseCatalogDate(link.episode?.publishDate)
        let description = link.episode?.description
        let youtubeUrl = link.episode?.youtubeUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard date != nil || !(link.sourceTitle ?? "").isEmpty || description != nil || !(youtubeUrl ?? "").isEmpty else {
            return nil
        }
        return PodcastEpisode(
            title: title,
            episodeId: link.episode?.episodeId ?? "\(link.identifier ?? "source")|\(movieTitle)",
            publishDate: date,
            description: description,
            youtubeUrl: (youtubeUrl?.isEmpty == false) ? youtubeUrl : nil
        )
    }

    static func parseCatalogDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractional.date(from: raw) {
            return date
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd HH:mm:ssZ", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }
}
