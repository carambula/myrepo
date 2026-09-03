//
//  ClosetPicksSource.swift
//  WatchedIt
//

import Foundation

enum ClosetPicksSource {
    static let identifier = "criterion-closet-picks"
    static let indexURL = URL(string: "https://www.criterion.com/closet-picks")!

    static func showsListenedAction(hasPodcastEpisode: Bool, isOnClosetPicks: Bool) -> Bool {
        hasPodcastEpisode || isOnClosetPicks
    }

    static func destinationURL(sourceUrl: String?, episodeId: String?) -> URL {
        if let sourceUrl, let url = httpURL(from: sourceUrl) {
            return url
        }
        if let episodeId, let url = httpURL(from: episodeId) {
            return url
        }
        return indexURL
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
