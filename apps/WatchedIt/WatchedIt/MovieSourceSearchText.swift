import Foundation

enum MovieSourceSearchText {
    static func join(_ pieces: [String?]) -> String {
        var seen = Set<String>()
        var unique: [String] = []
        for piece in pieces {
            let trimmed = piece?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            unique.append(trimmed)
        }
        return unique.joined(separator: " ")
    }
}
