//
//  ClosetPicksSource.swift
//  WatchedIt
//

import Foundation

enum ClosetPicksSource {
    static let identifier = "criterion-closet-picks"
    static let indexURL = URL(string: "https://www.criterion.com/closet-picks")!

    static let collectionIdentifier = "criterion"
    static let badgeAssetName = "source_criterion"
    static let badgeIdentifiers: Set<String> = [identifier, collectionIdentifier]

    static func normalizedIdentifier(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func showsPosterBadge(for sourceIdentifier: String) -> Bool {
        badgeIdentifiers.contains(normalizedIdentifier(sourceIdentifier))
    }

    static func showsListenedAction(hasPodcastEpisode: Bool, isOnClosetPicks: Bool) -> Bool {
        hasPodcastEpisode || isOnClosetPicks
    }

    static func youtubeVideoID(from raw: String?) -> String? {
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        let videoIDCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if value.count == 11, value.unicodeScalars.allSatisfy({ videoIDCharacters.contains($0) }) {
            return value
        }
        guard let url = URL(string: value) else { return nil }
        let host = url.host?.lowercased() ?? ""
        if host == "youtu.be" {
            let id = url.pathComponents.dropFirst().first ?? ""
            return id.count == 11 ? id : nil
        }
        if host.contains("youtube.com") {
            if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "v" })?
                .value,
               id.count == 11 {
                return id
            }
            for prefix in ["/embed/", "/shorts/", "/live/", "/v/"] {
                if url.path.hasPrefix(prefix) {
                    let id = String(url.path.dropFirst(prefix.count)).split(separator: "/").first.map(String.init) ?? ""
                    return id.count == 11 ? id : nil
                }
            }
        }
        return nil
    }

    static func vidMinURL(videoID: String) -> URL? {
        URL(string: "vidmin://watch?v=\(videoID)")
    }

    static func youtubeAppURL(videoID: String) -> URL? {
        URL(string: "youtube://www.youtube.com/watch?v=\(videoID)")
    }

    static func youtubeWebURL(videoID: String) -> URL? {
        URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }

    static func destinationURL(sourceUrl: String?, episodeId: String?, youtubeUrl: String? = nil) -> URL {
        if let videoID = youtubeVideoID(from: youtubeUrl), let url = youtubeWebURL(videoID: videoID) {
            return url
        }
        if let sourceUrl, let url = httpURL(from: sourceUrl) {
            return url
        }
        if let episodeId, let url = httpURL(from: episodeId) {
            return url
        }
        return indexURL
    }

    static func openURLs(sourceUrl: String?, episodeId: String?, youtubeUrl: String? = nil) -> [URL] {
        if let videoID = youtubeVideoID(from: youtubeUrl) {
            return [vidMinURL(videoID: videoID), youtubeAppURL(videoID: videoID), youtubeWebURL(videoID: videoID)]
                .compactMap { $0 }
        }
        return [destinationURL(sourceUrl: sourceUrl, episodeId: episodeId)]
    }

    static func menuTitle(sourceTitle: String?, sourceName: String?) -> String {
        let title = sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty { return title }
        let name = sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Criterion Closet Picks" : name
    }

    private static func httpURL(from raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return url
    }
}

enum SourceBadgeOrdering {
    static func identifiers(
        sourceIds: Set<String>,
        enabledPodcastIds: Set<String>,
        preferredOrder: [String],
        sourceNames: [String: String] = [:]
    ) -> [String] {
        let badgeIds = sourceIds.filter { sourceId in
            enabledPodcastIds.contains(sourceId) || ClosetPicksSource.showsPosterBadge(for: sourceId)
        }
        guard !badgeIds.isEmpty else { return [] }

        let orderedPreferred = preferredOrder.filter { badgeIds.contains($0) }
        let preferredSet = Set(orderedPreferred)
        let remaining = badgeIds
            .filter { !preferredSet.contains($0) }
            .sorted { lhs, rhs in
                let lhsName = sourceNames[lhs] ?? lhs
                let rhsName = sourceNames[rhs] ?? rhs
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }

        var seenCriterion = false
        return (orderedPreferred + remaining).filter { sourceId in
            guard ClosetPicksSource.showsPosterBadge(for: sourceId) else { return true }
            if seenCriterion { return false }
            seenCriterion = true
            return true
        }
    }
}
