import Foundation
import MinAppKit

@MainActor
final class MovieAgentService: AgentLibraryExporting {
    static let shared = MovieAgentService()
    static let libraryDidChange = Notification.Name("MovieAgentService.libraryDidChange")

    private struct FlagUndo: Codable {
        let movieId: String
        let field: String
        let previous: Bool
    }

    func listMovies(saved: Bool? = nil, rewatched: Bool? = nil, listened: Bool? = nil, query: String? = nil) -> [Movie] {
        var items = LocalDatabaseManager.shared.movies
        if saved == nil, rewatched == nil, listened == nil, (query ?? "").isEmpty {
            items = items.filter { $0.isSaved || $0.isRewatched }
        }
        if let saved { items = items.filter { $0.isSaved == saved } }
        if let rewatched { items = items.filter { $0.isRewatched == rewatched } }
        if let listened { items = items.filter { $0.isListened == listened } }
        if let query, !query.isEmpty {
            let needle = query.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(needle)
                    || $0.id.lowercased() == needle
                    || ($0.tmdbId.map { String($0) } == query)
            }
        }
        return items
    }

    func resolveMovie(id: String?, title: String?, year: Int?) throws -> Movie {
        let movies = LocalDatabaseManager.shared.movies
        if let id, !id.isEmpty {
            if let match = movies.first(where: { $0.id == id || $0.tmdbId.map(String.init) == id }) {
                return match
            }
        }
        if let title, !title.isEmpty {
            let matches = movies.filter { movie in
                let titleHit = movie.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                    || movie.title.range(of: title, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                if !titleHit { return false }
                if let year, let movieYear = movie.year, movieYear != year { return false }
                return true
            }
            if matches.count == 1 { return matches[0] }
            if matches.count > 1 {
                let labels = matches.prefix(5).map { "\($0.title) \($0.year.map(String.init) ?? "")" }.joined(separator: AgentSecurity.metadataSeparator)
                throw AgentKitError.ambiguous("Multiple movies matched. Specify a year or id. \(labels)")
            }
        }
        throw AgentKitError.notFound("No movie matched.")
    }

    func setSaved(id: String?, title: String?, year: Int?, saved: Bool) throws -> Movie {
        let movie = try resolveMovie(id: id, title: title, year: year)
        let undoId = AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .mov,
            tool: "set_movie_saved",
            summary: saved ? "Saved \(movie.title)" : "Unsaved \(movie.title)",
            payload: FlagUndo(movieId: movie.id, field: "saved", previous: movie.isSaved)
        )
        try LocalDatabaseManager.shared.updateSavedStatus(movie, isSaved: saved)
        NotificationCenter.default.post(name: Self.libraryDidChange, object: undoId)
        return movie
    }

    func setRewatched(id: String?, title: String?, year: Int?, rewatched: Bool) throws -> Movie {
        let movie = try resolveMovie(id: id, title: title, year: year)
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .mov,
            tool: "set_movie_rewatched",
            summary: rewatched ? "Marked \(movie.title) rewatched" : "Cleared rewatched on \(movie.title)",
            payload: FlagUndo(movieId: movie.id, field: "rewatched", previous: movie.isRewatched)
        )
        try LocalDatabaseManager.shared.updateRewatchedStatus(movie, isRewatched: rewatched)
        NotificationCenter.default.post(name: Self.libraryDidChange, object: nil)
        return movie
    }

    func setListened(id: String?, title: String?, year: Int?, listened: Bool) throws -> Movie {
        let movie = try resolveMovie(id: id, title: title, year: year)
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .mov,
            tool: "set_movie_listened",
            summary: listened ? "Marked \(movie.title) listened" : "Cleared listened on \(movie.title)",
            payload: FlagUndo(movieId: movie.id, field: "listened", previous: movie.isListened)
        )
        try LocalDatabaseManager.shared.updateListenedStatus(movie, isListened: listened)
        NotificationCenter.default.post(name: Self.libraryDidChange, object: nil)
        return movie
    }

    func exportLibraryJSON() throws -> Data {
        let payload: [String: Any] = [
            "movies": LocalDatabaseManager.shared.movies.map { movie in
                [
                    "id": movie.id,
                    "title": movie.title,
                    "year": movie.year as Any,
                    "tmdbId": movie.tmdbId as Any,
                    "isSaved": movie.isSaved,
                    "isRewatched": movie.isRewatched,
                    "isListened": movie.isListened
                ]
            }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func undoLastAgentWrite() throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .mov) else {
            throw AgentKitError.nothingToUndo
        }
        let payload = try AgentJournal.shared.decodePayload(record, as: FlagUndo.self)
        let movie = try resolveMovie(id: payload.movieId, title: nil, year: nil)
        switch payload.field {
        case "saved":
            try LocalDatabaseManager.shared.updateSavedStatus(movie, isSaved: payload.previous)
        case "rewatched":
            try LocalDatabaseManager.shared.updateRewatchedStatus(movie, isRewatched: payload.previous)
        case "listened":
            try LocalDatabaseManager.shared.updateListenedStatus(movie, isListened: payload.previous)
        default:
            throw AgentKitError.notFound("Unknown undo field.")
        }
        _ = try AgentJournal.shared.markUndone(id: record.id)
        NotificationCenter.default.post(name: Self.libraryDidChange, object: nil)
        return "Undid \(record.summary)"
    }
}
