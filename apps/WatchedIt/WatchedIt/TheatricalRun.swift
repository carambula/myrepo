//
//  TheatricalRun.swift
//  WatchedIt
//
//  Live "in theaters" / IMAX overlay and ticket search links.
//

import Foundation

public enum TheatricalFilter: String, CaseIterable, Sendable {
    case inTheaters = "In Theaters"
    case imax = "IMAX"
}

public struct TheatricalRun: Codable, Hashable, Sendable {
    public var tmdbId: Int?
    public var isInTheaters: Bool
    public var hasIMAX: Bool
    public var title: String?

    public init(
        tmdbId: Int? = nil,
        isInTheaters: Bool = false,
        hasIMAX: Bool = false,
        title: String? = nil
    ) {
        self.tmdbId = tmdbId
        self.isInTheaters = isInTheaters
        self.hasIMAX = hasIMAX
        self.title = title
    }

    public var hasDisplayableAvailability: Bool {
        isInTheaters || hasIMAX
    }

    public var badgeLabels: [String] {
        var badges: [String] = []
        if isInTheaters { badges.append("In Theaters") }
        if hasIMAX { badges.append("IMAX") }
        return badges
    }

    public var searchTokens: [String] {
        var tokens = Set<String>()
        if isInTheaters {
            tokens.formUnion(["theater", "theaters", "in theaters"])
        }
        if hasIMAX {
            tokens.insert("imax")
        }
        return Array(tokens)
    }

    public func matchesSearchQuery(_ query: String) -> Bool {
        let lower = query.lowercased()
        return searchTokens.contains { token in
            lower == token || lower.contains(token)
        }
    }

    public func matches(_ filter: TheatricalFilter) -> Bool {
        switch filter {
        case .inTheaters:
            return isInTheaters
        case .imax:
            return hasIMAX
        }
    }
}

public struct TheatricalTicketOffer: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let url: URL

    public init(id: String, title: String, url: URL) {
        self.id = id
        self.title = title
        self.url = url
    }
}

public struct TheatricalTicketGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let headline: String
    public let offers: [TheatricalTicketOffer]

    public init(id: String, headline: String, offers: [TheatricalTicketOffer]) {
        self.id = id
        self.headline = headline
        self.offers = offers
    }
}

public enum TheatricalTicketLinkBuilder {
    public static func hasOptions(for run: TheatricalRun?) -> Bool {
        run?.hasDisplayableAvailability == true
    }

    public static func groups(for run: TheatricalRun?, title: String, year: Int?) -> [TheatricalTicketGroup] {
        guard let run, run.hasDisplayableAvailability else { return [] }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return [] }

        var groups: [TheatricalTicketGroup] = []
        if run.isInTheaters {
            groups.append(TheatricalTicketGroup(
                id: "tickets",
                headline: "Tickets",
                offers: ticketOffers(title: trimmedTitle, year: year, extras: [])
            ))
        }
        if run.hasIMAX {
            groups.append(TheatricalTicketGroup(
                id: "imax",
                headline: "IMAX",
                offers: ticketOffers(title: trimmedTitle, year: year, extras: ["IMAX"])
            ))
        }
        return groups.filter { !$0.offers.isEmpty }
    }

    public static func compactOffers(for run: TheatricalRun?, title: String, year: Int?) -> [TheatricalTicketOffer] {
        var seen = Set<String>()
        var offers: [TheatricalTicketOffer] = []
        for group in groups(for: run, title: title, year: year) {
            for offer in group.offers where seen.insert(offer.title).inserted {
                offers.append(offer)
            }
        }
        return offers
    }

    private static func ticketOffers(title: String, year: Int?, extras: [String]) -> [TheatricalTicketOffer] {
        let query = PhysicalPurchaseLinkBuilder.searchTerms(title: title, year: year, extras: extras)
        let suffix = extras.joined()
        return [
            offer(id: "fandango-\(suffix)", title: "Fandango", prefix: "https://www.fandango.com/search?q=", query: query),
            offer(id: "atom-\(suffix)", title: "Atom Tickets", prefix: "https://www.atomtickets.com/search?query=", query: query),
            offer(id: "amc-\(suffix)", title: "AMC", prefix: "https://www.amctheatres.com/search?q=", query: query),
            offer(id: "google-\(suffix)", title: "Google", prefix: "https://www.google.com/search?q=", query: query + " movie tickets")
        ].compactMap { $0 }
    }

    private static func offer(id: String, title: String, prefix: String, query: String) -> TheatricalTicketOffer? {
        let encoded = PhysicalPurchaseLinkBuilder.encodeQuery(query)
        guard let url = URL(string: prefix + encoded) else { return nil }
        return TheatricalTicketOffer(id: id, title: title, url: url)
    }
}

public final class TheatricalCatalog: @unchecked Sendable {
    public static let shared = TheatricalCatalog()

    private var byTmdbId: [Int: TheatricalRun] = [:]
    private let lock = NSLock()

    private init() {}

    public func run(forTmdbId tmdbId: Int?) -> TheatricalRun? {
        guard let tmdbId else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return byTmdbId[tmdbId]
    }

    public func replace(_ runs: [Int: TheatricalRun]) {
        lock.lock()
        byTmdbId = runs
        lock.unlock()
    }

    public func replaceForTesting(_ runs: [Int: TheatricalRun]) {
        replace(runs)
    }
}
