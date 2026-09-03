import Foundation

@MainActor
final class TheatricalAvailabilitySync {
    static let shared = TheatricalAvailabilitySync()
    private init() {}

    func refresh(catalogTmdbIds: [Int]) async {
        let catalog = Set(catalogTmdbIds)
        var runs: [Int: TheatricalRun] = [:]

        if let remote = try? await MinCloudClient.shared.fetchNowPlaying() {
            for movie in remote.movies {
                runs[movie.tmdbId] = TheatricalRun(
                    tmdbId: movie.tmdbId,
                    isInTheaters: true,
                    hasIMAX: movie.hasIMAX ?? false,
                    title: movie.title,
                    ticketLinks: movie.ticketLinks.map {
                        TheatricalTicketLinks(amc: $0.amc, fandango: $0.fandango, atom: $0.atom)
                    }
                )
            }
        } else {
            for run in await MovieDataService.shared.fetchNowPlayingMovies() {
                if let tmdbId = run.tmdbId {
                    runs[tmdbId] = run
                }
            }
            let intersection = catalog.intersection(runs.keys)
            for tmdbId in intersection.prefix(40) {
                if await MovieDataService.shared.releaseHasIMAX(tmdbId: tmdbId) {
                    runs[tmdbId]?.hasIMAX = true
                }
            }
        }

        TheatricalCatalog.shared.replace(runs)
        LocalDatabaseManager.shared.refreshMovies()
        LocalDatabaseManager.shared.noteCatalogChanged()
    }
}
