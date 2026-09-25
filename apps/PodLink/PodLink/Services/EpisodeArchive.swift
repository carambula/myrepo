import Foundation

enum EpisodeArchive {
    static let archiveCap = 5000

    static func merge(_ primary: [Episode], _ extra: [Episode]) -> [Episode] {
        var seen = Set<String>()
        var merged: [Episode] = []
        for episode in primary + extra {
            let keys = identityKeys(for: episode)
            guard !keys.isEmpty, keys.allSatisfy({ !seen.contains($0) }) else { continue }
            seen.formUnion(keys)
            merged.append(episode)
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
}
