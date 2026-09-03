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
            let needsFullPull = force || !hasSyncedBefore || remoteHasMore
            let catalog = try await MinCloudClient.shared.fetchMovieCatalog(
                updatedSince: needsFullPull ? nil : MinCloudSettings.lastCatalogSyncedAt
            )
            let result = apply(catalog, modelContext: modelContext)
            let catalogCount = catalog.total ?? meta?.movieCount ?? catalog.movies.count
            MinCloudSettings.lastCatalogRevision = catalog.revision
            MinCloudSettings.lastCatalogSyncedAt = catalog.generatedAt ?? ISO8601DateFormatter().string(from: Date())
            MinCloudSettings.lastCatalogMovieCount = catalogCount
            LocalDatabaseManager.shared.refreshMovies()
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
    func apply(_ catalog: MinCloudMovieCatalog, modelContext: ModelContext) -> CatalogApplyResult {
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
        for content in existingContents {
            if let movieId = content.movie?.id, let sourceId = content.source?.identifier {
                contentKeys.insert("\(movieId)|\(sourceId)")
            }
        }

        var result = CatalogApplyResult()
        for remote in catalog.movies {
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
                movie.lastUpdated = Date()
                result.updated += 1
                if remote.tmdbId == nil {
                    result.unmatched += 1
                }
                let beforeLinks = contentKeys.count
                attachSources(remote, movie: movie, sourceById: sourceById, contentKeys: &contentKeys, modelContext: modelContext)
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
            attachSources(remote, movie: created, sourceById: sourceById, contentKeys: &contentKeys, modelContext: modelContext)
            result.added += 1
            if created.tmdbId == nil {
                result.unmatched += 1
            }
        }

        try? modelContext.save()
        return result
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
        modelContext: ModelContext
    ) {
        for link in remote.sources ?? [] {
            guard let identifier = link.identifier, let source = sourceById[identifier] else { continue }
            let key = "\(movie.id)|\(identifier)"
            guard !contentKeys.contains(key) else { continue }
            let content = SourceContent(
                movie: movie,
                source: source,
                sourceTitle: link.sourceTitle,
                rank: link.rank
            )
            modelContext.insert(content)
            contentKeys.insert(key)
        }
    }
}
