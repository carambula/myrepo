import Foundation

enum PodcastDateParser {
    /// Parses RSS, Atom, and min-cloud ISO dates.
    /// Min-cloud sends `toISOString()` values (`2025-04-01T10:00:00.000Z`); the default
    /// `ISO8601DateFormatter` rejects fractional seconds and must not fall back to `Date()`.
    static func parse(_ string: String?) -> Date? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for candidate in Self.parseCandidates(from: raw) {
            for format in Self.legacyFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: candidate) {
                    return date
                }
            }
        }
        return nil
    }

    /// `String(date)` from Node is `Tue Mar 04 2025 05:09:00 GMT+0000 (Coordinated Universal Time)`.
    private static func parseCandidates(from raw: String) -> [String] {
        var candidates = [raw]
        if let paren = raw.range(of: " (") {
            candidates.append(String(raw[..<paren.lowerBound]))
        }
        return candidates
    }

    private static let legacyFormats = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm:ss z",
        "EEE MMM dd yyyy HH:mm:ss 'GMT'Z",
        "EEE MMM dd yyyy HH:mm:ss zzz",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd HH:mm:ssXXXXX",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd"
    ]
}
