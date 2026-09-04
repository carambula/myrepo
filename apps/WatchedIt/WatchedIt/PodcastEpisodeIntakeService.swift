//
//  PodcastEpisodeIntakeService.swift
//  WatchedIt
//
//  Created by Cursor on 3/2/26.
//

import Foundation

public struct PodcastFeedSource: Codable, Hashable, Sendable {
    public let identifier: String
    public let name: String
    public let feedURL: String
    public let lastChecked: Date?

    public init(identifier: String, name: String, feedURL: String, lastChecked: Date?) {
        self.identifier = identifier
        self.name = name
        self.feedURL = feedURL
        self.lastChecked = lastChecked
    }
}

public struct PodcastFeedSourceState: Sendable {
    public let sourceIdentifier: String
    public let existingSourceTitles: Set<String>
    public let latestEpisodeDate: Date?
    public let latestKnownSourceTitle: String?
    public let latestKnownSourceTitleNormalized: String

    public init(
        sourceIdentifier: String,
        existingSourceTitles: Set<String>,
        latestEpisodeDate: Date?,
        latestKnownSourceTitle: String?,
        latestKnownSourceTitleNormalized: String
    ) {
        self.sourceIdentifier = sourceIdentifier
        self.existingSourceTitles = existingSourceTitles
        self.latestEpisodeDate = latestEpisodeDate
        self.latestKnownSourceTitle = latestKnownSourceTitle
        self.latestKnownSourceTitleNormalized = latestKnownSourceTitleNormalized
    }
}

public struct PendingPodcastEpisodeIntakeItem: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let sourceIdentifier: String
    public let sourceName: String
    public let sourceFeedURL: String
    public let sourceTitle: String
    public let normalizedSourceTitle: String
    public let episodeDate: Date?
    public let podcastEpisodeDescription: String?
    public let movie: Movie
    public let discoveredAt: Date
    public let enrichedAt: Date

    public var dedupeKey: String {
        let datePart = episodeDate?.timeIntervalSince1970.description ?? "nodate"
        return "\(sourceIdentifier.lowercased())|\(normalizedSourceTitle)|\(datePart)"
    }
}

public struct PodcastEpisodeSourceScanStats: Sendable {
    public let sourceIdentifier: String
    public let sourceName: String
    public let latestKnownEpisodeDate: Date?
    public let latestKnownSourceTitle: String?
    public let scannedCount: Int
    public let stoppedEarly: Bool
    public let stopReason: String?
    public let skippedByNoise: Int
    public let candidateCount: Int
}

public struct PodcastEpisodeIntakeRunResult: Sendable {
    public let pendingItems: [PendingPodcastEpisodeIntakeItem]
    public let sourceStats: [PodcastEpisodeSourceScanStats]
}

public struct PodcastRSSFeedItemInput: Sendable {
    public let title: String
    public let pubDate: String?
    public let description: String?
    public let guid: String?

    public init(title: String, pubDate: String? = nil, description: String? = nil, guid: String? = nil) {
        self.title = title
        self.pubDate = pubDate
        self.description = description
        self.guid = guid
    }
}

public struct PodcastFeedCandidateEvaluation: Sendable {
    public let candidateTitles: [String]
    public let scannedCount: Int
    public let stoppedEarly: Bool
    public let stopReason: String?
}

public struct PodcastTMDBSearchInput: Sendable {
    public let query: String
    public let year: Int?

    public init(query: String, year: Int?) {
        self.query = query
        self.year = year
    }
}

public final class PodcastEpisodeIntakeService {
    public static let shared = PodcastEpisodeIntakeService()

    public let fallbackLookbackDays = 60
    public let throttleInterval: TimeInterval = 60 * 60 * 24

    private init() {}

    public func normalizeEpisodeTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func cleanPodcastTitle(_ title: String) -> String {
        var cleaned = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            #"^the rewatchables\s*[:\-–—]\s*"#,
            #"^the big picture\s*[:\-–—]\s*"#,
            #"^blank check(?:\s+with griffin(?: and david)?)?\s*[:\-–—]\s*"#,
            #"^the confused breakfast\s*[:\-–—]\s*"#
        ]
        for prefix in prefixes {
            cleaned = cleaned.replacingOccurrences(of: prefix, with: "", options: [.regularExpression, .caseInsensitive])
        }

        if let quoted = extractQuotedMovieTitle(cleaned) {
            cleaned = quoted
        } else if let withRange = cleaned.range(of: #"\s+(?:with|feat\.?|featuring)\s+"#, options: [.regularExpression, .caseInsensitive]) {
            let after = String(cleaned[withRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if looksLikeGuestList(after) {
                cleaned = String(cleaned[..<withRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        cleaned = cleaned.replacingOccurrences(of: #"\s*[—–-]\s*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^episode\s+\d+\s*[:\-–—]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: #"^\d+[\.\):\-]\s+"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^["'“”‘’]+|["'“”‘’]+$"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractQuotedMovieTitle(_ title: String) -> String? {
        let pattern = #"^[“\"‘'](.+)[”\"’'](?:\s+(?:with|feat\.?|featuring|—|-)\b|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..<title.endIndex, in: title)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        let quoted = String(title[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return quoted.count >= 2 ? quoted : nil
    }

    private func looksLikeGuestList(_ after: String) -> Bool {
        let hosts = ["bill simmons", "chris ryan", "van lathan", "sean fennessey", "amanda dobbins", "griffin newman", "david sims"]
        let lower = after.lowercased()
        if hosts.contains(where: { lower.contains($0) }) {
            return true
        }
        let parts = after
            .replacingOccurrences(of: " and ", with: ",", options: .caseInsensitive)
            .components(separatedBy: CharacterSet(charactersIn: ",/&"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.count >= 1 && parts.allSatisfy { part in
            let words = part.split(whereSeparator: \.isWhitespace)
            return words.count >= 2 && words.count <= 4 && part.first?.isUppercase == true
        }
    }

    public func buildTMDBSearchInput(rawTitle: String, description: String? = nil) -> PodcastTMDBSearchInput {
        var query = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var year: Int?

        // First, try to extract year from title (in parentheses/brackets at end)
        if let regex = try? NSRegularExpression(pattern: #"[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]\s*$"#),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..<query.endIndex, in: query)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: query) {
            year = Int(query[range])
        }

        // If no year found in title, try parsing the description
        if year == nil, let description = description {
            year = extractYearFromDescription(description)
        }

        query = query.replacingOccurrences(of: #"[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$"#, with: "", options: .regularExpression)
        query = query.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return PodcastTMDBSearchInput(query: query.isEmpty ? rawTitle.trimmingCharacters(in: .whitespacesAndNewlines) : query, year: year)
    }
    
    /// Extracts year from podcast episode description using common patterns
    public func extractYearFromDescription(_ description: String) -> Int? {
        // Common patterns in podcast descriptions:
        // - "the 2011 film"
        // - "from 2011"
        // - "released in 2011"
        // - "2011's Crazy Stupid Love"
        // - "(2011)"
        let yearPatterns = [
            #"[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]"#,
            #"(?:the\s+)?((?:19|20)\d{2})\s+(?:south\s+)?(?:korean|japanese|chinese|hong\s+kong)\s+(?:film|movie|original|remake)"#,
            #"(?:the\s+)?((?:19|20)\d{2})\s+(?:film|movie|original|remake)"#,
            #"released\s+in\s+((?:19|20)\d{2})"#,
            #"((?:19|20)\d{2})(?:'s|\s+release)"#,
            #"(?:from|in)\s+((?:19|20)\d{2})(?=\s+(?:film|movie|starring|directed|with))"#
        ]
        
        for pattern in yearPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..<description.endIndex, in: description)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: description),
               let yearValue = Int(description[range]) {
                print("📅 Extracted year \(yearValue) from description using pattern: \(pattern)")
                return yearValue
            }
        }
        
        return nil
    }
    
    /// Extracts person names (cast/director) from description for validation
    /// Returns names that might help identify the correct movie
    public func extractPersonNamesFromDescription(_ description: String) -> [String] {
        var names: [String] = []
        
        // Common patterns:
        // - "starring Steve Carell"
        // - "with Ryan Gosling and Emma Stone"
        // - "directed by Glenn Ficarra"
        // - "stars Julianne Moore"
        let namePatterns = [
            #"(?:starring|stars?|featuring)\s+([A-Z][A-Za-z'.-]+(?:\s+[A-Z][A-Za-z'.-]+){1,3})"#,
            #"directed\s+by\s+([A-Z][A-Za-z'.-]+(?:\s+[A-Z][A-Za-z'.-]+){1,3})"#
        ]
        
        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let matches = regex.matches(in: description, range: NSRange(description.startIndex..<description.endIndex, in: description)) as [NSTextCheckingResult]? {
                for match in matches {
                    if match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: description) {
                        let name = String(description[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        // Filter out common false positives
                        if !name.contains("The ") && name.count < 30 {
                            names.append(name)
                        }
                    }
                }
            }
        }
        
        return Array(Set(names)) // Remove duplicates
    }

    public func parseRSSDate(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm Z"
        if let date = formatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }

    public func shouldSkipPodcastNoise(sourceIdentifier: String, rawTitle: String, cleanedTitle: String) -> Bool {
        let normalizedCleaned = normalizeEpisodeTitle(cleanedTitle)
        if normalizedCleaned.isEmpty {
            return true
        }
        if isBrunchPodcastNoiseTitle(rawTitle) || isBrunchPodcastNoiseTitle(cleanedTitle) {
            return true
        }

        let haystack = "\(rawTitle) \(cleanedTitle)"
        if sourceIdentifier == "big-picture" {
            let pattern = #"\b(mailbag|draft|auction|box office|top\s*\d+|rankings|hall of fame|interview|preview|q&a|questions|state of|awards? race|oscars?|emmys?|tv corner|trailer talk|news round(up)?|hot take|power rankings)\b"#
            if haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        if sourceIdentifier == "blank-check" {
            let pattern = #"\b(mailbag|patreon|miniseries announcement|housekeeping)\b"#
            if haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        if sourceIdentifier == "confused-breakfast" {
            let pattern = #"\b(mailbag|q\s*&\s*a|q and a)\b"#
            if haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    private func stripShowPrefixes(_ title: String) -> String {
        var cleaned = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            #"^the rewatchables\s*[:\-–—]\s*"#,
            #"^the big picture\s*[:\-–—]\s*"#,
            #"^blank check(?:\s+with griffin(?: and david)?)?\s*[:\-–—]\s*"#,
            #"^the confused breakfast\s*[:\-–—]\s*"#,
            #"^(?:miniseries|minisode|rewatch(?:ables)?)\s*[:\-–—]\s*"#
        ]
        for prefix in prefixes {
            cleaned = cleaned.replacingOccurrences(of: prefix, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBrunchPodcastNoiseTitle(_ title: String) -> Bool {
        let pattern = #"^\s*brunch\b"#
        if title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return stripShowPrefixes(title).range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func normalizedFeedURLString(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard let components = URLComponents(string: trimmed), components.scheme == nil else {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func fetchRSSItems(feedURLString: String) async throws -> [PodcastRSSItem] {
        let normalizedFeedURL = normalizedFeedURLString(feedURLString)
        guard let url = URL(string: normalizedFeedURL) else {
            throw URLError(.badURL)
        }

        // Run network fetch detached from UI task cancellation.
        // SwiftUI refresh tasks can be canceled during view updates, which
        // otherwise propagates as NSURLErrorDomain -999 on URLSession.
        let xml = try await Task.detached(priority: .utility) { () throws -> String in
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("WatchedIt/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return String(decoding: data, as: UTF8.self)
        }.value

        return parseRSSItems(xml)
    }

    public func scanAndEnrich(
        sources: [PodcastFeedSource],
        sourceStates: [String: PodcastFeedSourceState],
        existingPendingKeys: Set<String>,
        now: Date = Date()
    ) async -> PodcastEpisodeIntakeRunResult {
        var pendingItems: [PendingPodcastEpisodeIntakeItem] = []
        var sourceStats: [PodcastEpisodeSourceScanStats] = []
        var seenPendingKeys = existingPendingKeys

        for source in sources {
            if Task.isCancelled {
                break
            }

            let sourceState = sourceStates[source.identifier] ?? PodcastFeedSourceState(
                sourceIdentifier: source.identifier,
                existingSourceTitles: [],
                latestEpisodeDate: nil,
                latestKnownSourceTitle: nil,
                latestKnownSourceTitleNormalized: ""
            )

            let rssItems: [PodcastRSSItem]
            do {
                rssItems = try await fetchRSSItems(feedURLString: source.feedURL)
            } catch {
                print("⚠️ [PODCAST] Feed fetch failed source=\(source.identifier) url=\(source.feedURL) error=\(error)")
                sourceStats.append(
                    PodcastEpisodeSourceScanStats(
                        sourceIdentifier: source.identifier,
                        sourceName: source.name,
                        latestKnownEpisodeDate: sourceState.latestEpisodeDate,
                        latestKnownSourceTitle: sourceState.latestKnownSourceTitle,
                        scannedCount: 0,
                        stoppedEarly: false,
                        stopReason: "fetch-error",
                        skippedByNoise: 0,
                        candidateCount: 0
                    )
                )
                continue
            }

            let collection = collectNewPodcastItemsFromFeed(
                rssItems: rssItems,
                sourceState: sourceState,
                now: now
            )

            sourceStats.append(
                PodcastEpisodeSourceScanStats(
                    sourceIdentifier: source.identifier,
                    sourceName: source.name,
                    latestKnownEpisodeDate: collection.stats.latestEpisodeDate,
                    latestKnownSourceTitle: collection.stats.latestKnownSourceTitle,
                    scannedCount: collection.stats.scannedCount,
                    stoppedEarly: collection.stats.stoppedEarly,
                    stopReason: collection.stats.stopReason,
                    skippedByNoise: collection.stats.skippedByNoise,
                    candidateCount: collection.candidates.count
                )
            )

            for candidate in collection.candidates {
                let episodeDate = parseRSSDate(candidate.episodeDate)
                let dedupeKey = makePendingDedupeKey(
                    sourceIdentifier: source.identifier,
                    normalizedSourceTitle: normalizeEpisodeTitle(candidate.sourceTitle),
                    episodeDate: episodeDate
                )
                if seenPendingKeys.contains(dedupeKey) {
                    continue
                }

                if let pending = await enrichCandidate(candidate, source: source, now: now) {
                    pendingItems.append(pending)
                    seenPendingKeys.insert(dedupeKey)
                }
            }
        }

        return PodcastEpisodeIntakeRunResult(pendingItems: pendingItems, sourceStats: sourceStats)
    }

    public func makePendingDedupeKey(sourceIdentifier: String, normalizedSourceTitle: String, episodeDate: Date?) -> String {
        let datePart = episodeDate?.timeIntervalSince1970.description ?? "nodate"
        return "\(sourceIdentifier.lowercased())|\(normalizedSourceTitle)|\(datePart)"
    }

    public func evaluateFeedCandidates(
        items: [PodcastRSSFeedItemInput],
        sourceState: PodcastFeedSourceState,
        now: Date = Date()
    ) -> PodcastFeedCandidateEvaluation {
        let rssItems = items.map {
            PodcastRSSItem(
                title: $0.title,
                guid: $0.guid ?? "",
                pubDate: $0.pubDate ?? "",
                description: $0.description ?? ""
            )
        }
        let collection = collectNewPodcastItemsFromFeed(rssItems: rssItems, sourceState: sourceState, now: now)
        return PodcastFeedCandidateEvaluation(
            candidateTitles: collection.candidates.map(\.sourceTitle),
            scannedCount: collection.stats.scannedCount,
            stoppedEarly: collection.stats.stoppedEarly,
            stopReason: collection.stats.stopReason
        )
    }

    private func parseRSSItems(_ xml: String) -> [PodcastRSSItem] {
        let itemPattern = #"<item[\s\S]*?<\/item>"#
        guard let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsXML = xml as NSString
        let matches = itemRegex.matches(in: xml, range: NSRange(location: 0, length: nsXML.length))
        var items: [PodcastRSSItem] = []
        items.reserveCapacity(matches.count)

        for match in matches {
            let itemXML = nsXML.substring(with: match.range)
            let title = firstCapture(in: itemXML, pattern: #"<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>|<title>([\s\S]*?)<\/title>"#) ?? ""
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            let guid = firstCapture(in: itemXML, pattern: #"<guid[^>]*>([\s\S]*?)<\/guid>"#) ?? ""
            let pubDate = firstCapture(in: itemXML, pattern: #"<pubDate>([\s\S]*?)<\/pubDate>"#) ?? ""
            let description = firstCapture(in: itemXML, pattern: #"<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>|<description>([\s\S]*?)<\/description>"#) ?? ""

            items.append(
                PodcastRSSItem(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    guid: guid.trimmingCharacters(in: .whitespacesAndNewlines),
                    pubDate: pubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        return items
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        for captureIndex in 1..<match.numberOfRanges {
            if let capture = Range(match.range(at: captureIndex), in: text) {
                return String(text[capture])
            }
        }
        return nil
    }

    private func collectNewPodcastItemsFromFeed(
        rssItems: [PodcastRSSItem],
        sourceState: PodcastFeedSourceState,
        now: Date
    ) -> PodcastCandidateCollection {
        let latestEpisodeDate = sourceState.latestEpisodeDate
        let latestKnownSourceTitleNormalized = sourceState.latestKnownSourceTitleNormalized
        let existingSourceTitles = sourceState.existingSourceTitles
        var candidates: [PodcastEpisodeCandidate] = []
        var scannedCount = 0
        var stoppedEarly = false
        var stopReason: String?
        var skippedByNoise = 0

        for item in rssItems {
            scannedCount += 1
            let normalizedSourceTitle = normalizeEpisodeTitle(item.title)
            if normalizedSourceTitle.isEmpty {
                continue
            }

            if !latestKnownSourceTitleNormalized.isEmpty, normalizedSourceTitle == latestKnownSourceTitleNormalized {
                stoppedEarly = true
                stopReason = "latest-known-title"
                break
            }

            if existingSourceTitles.contains(normalizedSourceTitle) {
                continue
            }

            let pubDate = parseRSSDate(item.pubDate)
            if let latestEpisodeDate {
                guard let pubDate else {
                    continue
                }
                if pubDate <= latestEpisodeDate {
                    stoppedEarly = true
                    stopReason = "latest-known-date"
                    break
                }
            } else if !isRecentPodcastItem(pubDate: pubDate, now: now) {
                continue
            }

            let cleanedTitle = cleanPodcastTitle(item.title)
            if cleanedTitle.isEmpty {
                continue
            }
            if shouldSkipPodcastNoise(sourceIdentifier: sourceState.sourceIdentifier, rawTitle: item.title, cleanedTitle: cleanedTitle) {
                skippedByNoise += 1
                continue
            }

            candidates.append(
                PodcastEpisodeCandidate(
                    title: cleanedTitle,
                    sourceTitle: item.title,
                    episodeDate: item.pubDate.isEmpty ? nil : item.pubDate,
                    podcastEpisodeDescription: item.description.isEmpty ? nil : item.description,
                    guid: item.guid.isEmpty ? nil : item.guid
                )
            )
        }

        return PodcastCandidateCollection(
            candidates: candidates,
            stats: PodcastCandidateScanStats(
                latestEpisodeDate: latestEpisodeDate,
                latestKnownSourceTitle: sourceState.latestKnownSourceTitle,
                scannedCount: scannedCount,
                stoppedEarly: stoppedEarly,
                stopReason: stopReason,
                skippedByNoise: skippedByNoise
            )
        )
    }

    private func isRecentPodcastItem(pubDate: Date?, now: Date) -> Bool {
        guard let pubDate else { return true }
        let lookbackSeconds = TimeInterval(fallbackLookbackDays * 24 * 60 * 60)
        return pubDate >= now.addingTimeInterval(-lookbackSeconds)
    }

    private func enrichCandidate(
        _ candidate: PodcastEpisodeCandidate,
        source: PodcastFeedSource,
        now: Date
    ) async -> PendingPodcastEpisodeIntakeItem? {
        let cleanedTitle = TitleCleaner.shared.cleanTitle(candidate.title)
        guard !cleanedTitle.isEmpty else { return nil }
        
        // Pass both title and description to extract year information
        let searchInput = buildTMDBSearchInput(rawTitle: cleanedTitle, description: candidate.podcastEpisodeDescription)
        
        // Extract person names from description for validation (helps disambiguate when multiple movies have same title)
        let expectedPersonNames: [String]? = if let description = candidate.podcastEpisodeDescription {
            extractPersonNamesFromDescription(description)
        } else {
            nil
        }

        let movieService = MovieDataService.shared
        guard let match = try? await movieService.searchMovieBestMatch(
            title: searchInput.query,
            year: searchInput.year,
            preferredYear: searchInput.year,
            expectedPersonNames: expectedPersonNames
        ),
              let tmdbDetails = try? await movieService.getMovieDetails(tmdbId: match.id) else {
            print("❌ Failed to find TMDB match for '\(cleanedTitle)' (year: \(searchInput.year?.description ?? "none"))")
            return nil
        }
        
        // Log successful match with year info for debugging
        if let year = searchInput.year {
            print("✅ Matched '\(cleanedTitle)' to '\(tmdbDetails.title)' (\(tmdbDetails.year?.description ?? "N/A")) using year hint: \(year)")
        }

        async let servicesTask = movieService.getStreamingProviders(tmdbId: match.id)
        async let mpaaTask = movieService.getMPAARating(tmdbId: match.id)
        async let videosTask = movieService.getMovieVideos(tmdbId: match.id)

        let streamingServices = (try? await servicesTask) ?? []
        let mpaaRating = (try? await mpaaTask) ?? nil
        let videos = (try? await videosTask) ?? []

        let episodeDate = parseRSSDate(candidate.episodeDate)
        let normalizedSourceTitle = normalizeEpisodeTitle(candidate.sourceTitle)
        let episodeId = makeEpisodeID(source: source, candidate: candidate, episodeDate: episodeDate)
        let (appleURL, spotifyURL) = knownPodcastURLs(for: source.identifier)

        let podcastEpisode = PodcastEpisode(
            title: candidate.sourceTitle,
            episodeId: episodeId,
            publishDate: episodeDate,
            description: candidate.podcastEpisodeDescription,
            applePodcastsUrl: appleURL,
            spotifyUrl: spotifyURL,
            overcastUrl: nil,
            pocketCastsUrl: nil
        )

        let movie = Movie(
            id: Movie.idFromEpisode(episodeId: episodeId, tmdbId: tmdbDetails.id),
            title: tmdbDetails.title,
            year: tmdbDetails.year,
            tmdbId: tmdbDetails.id,
            posterPath: tmdbDetails.posterPath,
            backdropPath: tmdbDetails.backdropPath,
            overview: tmdbDetails.overview,
            mpaaRating: mpaaRating,
            genres: tmdbDetails.genres?.map(\.name) ?? [],
            streamingServices: streamingServices,
            podcastEpisode: podcastEpisode,
            credits: mapCredits(from: tmdbDetails.credits),
            rewatchablesDiscussion: nil,
            trailer: mapTrailer(from: videos.first),
            isRewatched: false,
            isListened: false,
            isSaved: false,
            lastUpdated: now
        )

        return PendingPodcastEpisodeIntakeItem(
            id: makePendingDedupeKey(
                sourceIdentifier: source.identifier,
                normalizedSourceTitle: normalizedSourceTitle,
                episodeDate: episodeDate
            ),
            sourceIdentifier: source.identifier,
            sourceName: source.name,
            sourceFeedURL: source.feedURL,
            sourceTitle: candidate.sourceTitle,
            normalizedSourceTitle: normalizedSourceTitle,
            episodeDate: episodeDate,
            podcastEpisodeDescription: candidate.podcastEpisodeDescription,
            movie: movie,
            discoveredAt: now,
            enrichedAt: Date()
        )
    }

    private func mapCredits(from credits: TMDBCredits?) -> MovieCredits? {
        guard let credits else { return nil }
        let cast = credits.cast.prefix(10).map {
            CastMember(id: $0.id, name: $0.name, character: $0.character, profilePath: $0.profilePath)
        }
        return MovieCredits(director: credits.director, cast: Array(cast))
    }

    private func mapTrailer(from video: TMDBVideo?) -> MovieTrailer? {
        guard let video else { return nil }
        return MovieTrailer(id: video.id, name: video.name, youtubeKey: video.key, isOfficial: video.official)
    }

    private func makeEpisodeID(source: PodcastFeedSource, candidate: PodcastEpisodeCandidate, episodeDate: Date?) -> String {
        if let guid = candidate.guid?.trimmingCharacters(in: .whitespacesAndNewlines), !guid.isEmpty {
            return guid.lowercased()
        }
        let normalized = normalizeEpisodeTitle(candidate.sourceTitle)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let datePart = episodeDate?.timeIntervalSince1970.description ?? "nodate"
        return "\(source.identifier)-\(normalized)-\(datePart)".lowercased()
    }

    private func knownPodcastURLs(for sourceIdentifier: String) -> (String?, String?) {
        switch sourceIdentifier {
        case "rewatchables":
            return ("https://podcasts.apple.com/us/podcast/the-rewatchables/id1268527882", "https://open.spotify.com/show/1lUPomulZRPquVAOOd56EW")
        case "big-picture":
            return ("https://podcasts.apple.com/us/podcast/the-big-picture/id1441925782", "https://open.spotify.com/show/6mTel3azvnK8isLs4VujvF")
        case "blank-check":
            return ("https://podcasts.apple.com/us/podcast/blank-check-with-griffin-and-david/id1048424828", "https://open.spotify.com/show/632fZ9OgoqbHKCr20sH5HI")
        case "confused-breakfast":
            return ("https://podcasts.apple.com/us/podcast/the-confused-breakfast/id1494516409", "https://open.spotify.com/show/3PNydDMS6GHuP5M5ddh5M8")
        default:
            return (nil, nil)
        }
    }
}

private struct PodcastRSSItem {
    let title: String
    let guid: String
    let pubDate: String
    let description: String
}

private struct PodcastEpisodeCandidate {
    let title: String
    let sourceTitle: String
    let episodeDate: String?
    let podcastEpisodeDescription: String?
    let guid: String?
}

private struct PodcastCandidateCollection {
    let candidates: [PodcastEpisodeCandidate]
    let stats: PodcastCandidateScanStats
}

private struct PodcastCandidateScanStats {
    let latestEpisodeDate: Date?
    let latestKnownSourceTitle: String?
    let scannedCount: Int
    let stoppedEarly: Bool
    let stopReason: String?
    let skippedByNoise: Int
}
