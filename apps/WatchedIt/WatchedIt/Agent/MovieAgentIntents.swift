import AppIntents
import Foundation
import MinAppKit

struct MovieLibraryEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Movie")
    static var defaultQuery = MovieLibraryEntityQuery()

    let id: String
    let title: String
    let year: Int?

    var displayRepresentation: DisplayRepresentation {
        if let year {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(year)")
        }
        return DisplayRepresentation(title: "\(title)")
    }
}

struct MovieLibraryEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [MovieLibraryEntity] {
        await MainActor.run {
            MovieAgentService.shared.listMovies(query: string).prefix(20).map {
                MovieLibraryEntity(id: $0.id, title: $0.title, year: $0.year)
            }
        }
    }

    func entities(for identifiers: [String]) async throws -> [MovieLibraryEntity] {
        await MainActor.run {
            MovieAgentService.shared.listMovies().filter { identifiers.contains($0.id) }.map {
                MovieLibraryEntity(id: $0.id, title: $0.title, year: $0.year)
            }
        }
    }

    func suggestedEntities() async throws -> [MovieLibraryEntity] {
        await MainActor.run {
            MovieAgentService.shared.listMovies().prefix(20).map {
                MovieLibraryEntity(id: $0.id, title: $0.title, year: $0.year)
            }
        }
    }
}

struct ListWatchedItMoviesIntent: AppIntent {
    static var title: LocalizedStringResource = "List Movies in WatchedIt"
    static var description = IntentDescription("Shows saved and rewatched movies.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let movies = await MainActor.run { MovieAgentService.shared.listMovies() }
        if movies.isEmpty {
            return .result(dialog: IntentDialog("Your movie library is empty."))
        }
        let lines = movies.prefix(12).map { movie in
            let flags = [
                movie.isSaved ? "saved" : nil,
                movie.isRewatched ? "rewatched" : nil
            ].compactMap { $0 }.joined(separator: AgentSecurity.metadataSeparator)
            return "\(movie.title)\(movie.year.map { " (\($0))" } ?? "")   \(flags)"
        }.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: lines))
    }
}

struct SaveMovieInWatchedItIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Movie in WatchedIt"
    static var description = IntentDescription("Adds a movie to your saved list. Undo from Account, Agents.")
    static var openAppWhenRun = false

    @Parameter(title: "Movie")
    var movie: MovieLibraryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$movie) in WatchedIt")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = try await MainActor.run {
            try MovieAgentService.shared.setSaved(id: movie.id, title: movie.title, year: movie.year, saved: true).title
        }
        return .result(dialog: IntentDialog("Saved \(title)."))
    }
}

struct MarkMovieRewatchedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Movie Rewatched in WatchedIt"
    static var description = IntentDescription("Marks a movie as rewatched. Undo from Account, Agents.")
    static var openAppWhenRun = false

    @Parameter(title: "Movie")
    var movie: MovieLibraryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$movie) rewatched")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = try await MainActor.run {
            try MovieAgentService.shared.setRewatched(id: movie.id, title: movie.title, year: movie.year, rewatched: true).title
        }
        return .result(dialog: IntentDialog("Marked \(title) rewatched."))
    }
}

struct UnsaveMovieInWatchedItIntent: AppIntent {
    static var title: LocalizedStringResource = "Unsave Movie in WatchedIt"
    static var description = IntentDescription("Removes a movie from your saved list. Reversible for 7 days.")
    static var openAppWhenRun = false

    @Parameter(title: "Movie")
    var movie: MovieLibraryEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = try await MainActor.run {
            try MovieAgentService.shared.setSaved(id: movie.id, title: movie.title, year: movie.year, saved: false).title
        }
        return .result(dialog: IntentDialog("Removed \(title) from saved."))
    }
}

struct UndoLastWatchedItAgentWriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last WatchedIt Agent Change"
    static var description = IntentDescription("Reverses the most recent agent movie write.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await MainActor.run { try MovieAgentService.shared.undoLastAgentWrite() }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct WatchedItAgentShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveMovieInWatchedItIntent(),
            phrases: [
                "Save \(\.$movie) in \(.applicationName)",
                "Add \(\.$movie) to \(.applicationName)"
            ],
            shortTitle: "Save movie",
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: ListWatchedItMoviesIntent(),
            phrases: [
                "What have I watched in \(.applicationName)",
                "List my movies in \(.applicationName)"
            ],
            shortTitle: "List movies",
            systemImageName: "film"
        )
    }
}
