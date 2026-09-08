//
//  ClosetPicksSource.swift
//  WatchedIt
//

import Foundation
import SwiftUI

public struct ClosetPicksGuest: Codable, Hashable, Sendable {
    public let name: String
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

struct ClosetPicksGuestAttribution: Equatable {
    let name: String
    let url: URL?
}

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

    static func isIndexURL(_ url: URL) -> Bool {
        guard url.host?.lowercased().contains("criterion.com") == true else { return false }
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path == "closet-picks"
    }

    static func watchAndShopURL(from raw: String?) -> URL? {
        guard let url = httpURL(from: raw ?? "") else { return nil }
        if isIndexURL(url) {
            return nil
        }
        let path = url.path.lowercased()
        if path.range(of: #"/shop/collection/\d+-[^/]*closet-picks/?$"#, options: .regularExpression) != nil {
            return url
        }
        if path.hasPrefix("/closet-picks/"), path != "/closet-picks", path != "/closet-picks/" {
            return url
        }
        return nil
    }

    static func preferredPermalink(sourceUrl: String?, episodeId: String?) -> String? {
        watchAndShopURL(from: episodeId)?.absoluteString
            ?? watchAndShopURL(from: sourceUrl)?.absoluteString
    }

    static func guestNameFromEpisodeTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"[’']s\s+closet\s+picks\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"\s+closet\s+picks\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseDescriptionGuests(_ description: String) -> [String] {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.components(separatedBy: "   also ")
        guard parts.count > 1 else { return [trimmed] }
        let rest = parts.dropFirst()
            .joined(separator: "   also ")
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let first = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        return ([first] + rest).filter { !$0.isEmpty }
    }

    static func normalizedGuestName(_ name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9 ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func addGuestURLs(
        to index: inout [String: String],
        sourceTitle: String?,
        sourceUrl: String?,
        episode: PodcastEpisode?
    ) {
        for guest in episode?.guests ?? [] {
            addGuestURL(guest.name, guest.url, to: &index)
        }
        addGuestURL(
            guestNameFromEpisodeTitle(sourceTitle ?? episode?.title ?? ""),
            preferredPermalink(sourceUrl: sourceUrl, episodeId: episode?.episodeId),
            to: &index
        )
    }

    private static func addGuestURL(_ name: String?, _ url: String?, to index: inout [String: String]) {
        let key = normalizedGuestName(name ?? "")
        guard !key.isEmpty, let href = watchAndShopURL(from: url)?.absoluteString, index[key] == nil else { return }
        index[key] = href
    }

    static func formatGuestLine(_ names: [String]) -> String {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return "" }
        if cleaned.count == 1 { return cleaned[0] }
        return "\(cleaned[0])   also \(cleaned.dropFirst().joined(separator: ", "))"
    }

    static func guestAttributions(
        guests: [ClosetPicksGuest]?,
        description: String?,
        sourceTitle: String?,
        permalink: String?,
        knownURLs: [String: String] = [:]
    ) -> [ClosetPicksGuestAttribution] {
        let fromGuests = (guests ?? []).map(\.name).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let fromDescription = parseDescriptionGuests(description ?? "")
        var names = fromDescription.count >= fromGuests.count && !fromDescription.isEmpty ? fromDescription : fromGuests
        if names.isEmpty {
            let fromTitle = guestNameFromEpisodeTitle(sourceTitle ?? "")
            if !fromTitle.isEmpty {
                names = [fromTitle]
            }
        }
        var index = ClosetPicksGuestURLCatalog.urls
        for (key, url) in knownURLs {
            index[key] = url
        }
        for guest in guests ?? [] {
            if let href = watchAndShopURL(from: guest.url)?.absoluteString {
                let key = normalizedGuestName(guest.name)
                if !key.isEmpty {
                    index[key] = href
                }
            }
        }
        if let first = names.first {
            addGuestURL(first, permalink, to: &index)
        }
        return names.map { name in
            ClosetPicksGuestAttribution(
                name: name,
                url: watchAndShopURL(from: index[normalizedGuestName(name)])
            )
        }
    }

    static func attributionText(_ guests: [ClosetPicksGuestAttribution]) -> AttributedString {
        var attributed = AttributedString()
        for (index, guest) in guests.enumerated() {
            if index == 1 {
                attributed += AttributedString("   also ")
            } else if index > 1 {
                attributed += AttributedString(", ")
            }
            var name = AttributedString(guest.name)
            if let url = guest.url {
                name.link = url
                name.underlineStyle = .single
            }
            attributed += name
        }
        return attributed
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
