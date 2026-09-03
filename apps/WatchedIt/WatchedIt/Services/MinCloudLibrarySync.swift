import Foundation
import SwiftData

@MainActor
final class MinCloudLibrarySync {
    static let shared = MinCloudLibrarySync()
    private init() {}

    func syncOnSignIn() async {
        guard MinCloudSettings.isSignedIn else { return }
        await MinCloudClient.shared.registerDevice()
        await pullAndMerge()
        await pushCurrentLibrary()
    }

    func pullAndMerge() async {
        guard MinCloudSettings.isSignedIn else { return }
        guard let items = try? await MinCloudClient.shared.fetchMovieLibrary() else { return }
        LocalDatabaseManager.shared.applyMinCloudLibrary(items)
    }

    func pushCurrentLibrary() async {
        guard MinCloudSettings.isSignedIn else { return }
        let items = LocalDatabaseManager.shared.minCloudLibraryPayload()
        guard !items.isEmpty else { return }
        try? await MinCloudClient.shared.pushLibrary(items: items)
    }

    func pushMovie(movieId: String, isSaved: Bool, isRewatched: Bool, isListened: Bool, isWatched: Bool) {
        guard MinCloudSettings.isSignedIn else { return }
        Task {
            try? await MinCloudClient.shared.pushLibrary(items: [[
                "movieId": movieId,
                "isSaved": isSaved,
                "isRewatched": isRewatched,
                "isListened": isListened,
                "isWatched": isWatched
            ]])
        }
    }
}
