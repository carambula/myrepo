import Foundation
import SwiftData

@MainActor
final class MinCloudCatalogSync {
    static let shared = MinCloudCatalogSync()
    private init() {}

    func syncIfAvailable(modelContext: ModelContext) async -> String {
        let reachable = await MinCloudClient.shared.isReachable()
        guard reachable else {
            return "Min Cloud unavailable. Using the local catalog."
        }
        do {
            let catalog = try await MinCloudClient.shared.fetchMovieCatalog()
            let applied = apply(catalog, modelContext: modelContext)
            MinCloudSettings.lastCatalogRevision = catalog.revision
            LocalDatabaseManager.shared.refreshMovies()
            return "Updated \(applied) titles from Min Cloud (revision \(catalog.revision))."
        } catch {
            return "Min Cloud sync failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func apply(_ catalog: MinCloudMovieCatalog, modelContext: ModelContext) -> Int {
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

        var applied = 0
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
                movie.lastUpdated = Date()
                applied += 1
                attachSources(remote, movie: movie, sourceById: sourceById, contentKeys: &contentKeys, modelContext: modelContext)
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
                streamingServices: providers
            )
            modelContext.insert(created)
            byId[created.id] = created
            if let tmdbId = created.tmdbId {
                byTmdb[tmdbId] = created
            }
            attachSources(remote, movie: created, sourceById: sourceById, contentKeys: &contentKeys, modelContext: modelContext)
            applied += 1
        }

        try? modelContext.save()
        return applied
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
