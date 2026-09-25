import Foundation

enum EpisodeArchive {
    static let archiveCap = 5000

    static func merge(_ primary: [Episode], _ extra: [Episode]) -> [Episode] {
        var indexByKey: [String: Int] = [:]
        var merged: [Episode] = []
        for episode in primary + extra {
            let keys = identityKeys(for: episode)
            guard !keys.isEmpty else { continue }
            if let existingIndex = keys.compactMap({ indexByKey[$0] }).first {
                if !hasUsablePublishDate(merged[existingIndex].publishDate),
                   hasUsablePublishDate(episode.publishDate) {
                    merged[existingIndex] = episode
                }
                continue
            }
            let index = merged.count
            merged.append(episode)
            for key in keys {
                indexByKey[key] = index
            }
        }
        let sorted = merged.sorted { lhs, rhs in
            if lhs.publishDate != rhs.publishDate {
                return lhs.publishDate > rhs.publishDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return Array(sorted.prefix(archiveCap))
    }

    static func identityKey(for episode: Episode) -> String {
        identityKeys(for: episode).first ?? ""
    }

    static func identityKeys(for episode: Episode) -> [String] {
        let guid = episode.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let audio = episode.audioURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = episode.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var keys: [String] = []
        if !guid.isEmpty, guid != "about:blank" {
            keys.append("g:\(guid)")
        }
        if !audio.isEmpty, !audio.hasPrefix("about:") {
            keys.append("a:\(audio)")
        }
        if keys.isEmpty, !title.isEmpty {
            keys.append("t:\(title)")
        }
        return keys
    }

    static func hasUsablePublishDate(_ date: Date) -> Bool {
        date.timeIntervalSince1970 > 0
    }
}
