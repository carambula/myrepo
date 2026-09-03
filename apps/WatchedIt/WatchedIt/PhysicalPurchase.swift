//
//  PhysicalPurchase.swift
//  WatchedIt
//
//  Client-side disc-shop search links from catalog physical-media editions.
//

import Foundation

public enum PhysicalPurchaseRetailer: String, Codable, CaseIterable, Sendable, Hashable {
    case criterion
    case arrow
    case shoutFactory
    case kinoLorber
    case amazon
    case ebay

    public var displayName: String {
        switch self {
        case .criterion: return "Criterion"
        case .arrow: return "Arrow"
        case .shoutFactory: return "Shout Factory"
        case .kinoLorber: return "Kino Lorber"
        case .amazon: return "Amazon"
        case .ebay: return "eBay"
        }
    }
}

public enum PhysicalPurchaseKind: String, Codable, Sendable, Hashable {
    case search
    case direct
}

public struct PhysicalPurchaseOffer: Identifiable, Hashable, Sendable {
    public var id: String
    public var retailer: PhysicalPurchaseRetailer
    public var title: String
    public var kind: PhysicalPurchaseKind
    public var url: URL

    public init(
        id: String,
        retailer: PhysicalPurchaseRetailer,
        title: String,
        kind: PhysicalPurchaseKind,
        url: URL
    ) {
        self.id = id
        self.retailer = retailer
        self.title = title
        self.kind = kind
        self.url = url
    }
}

public struct PhysicalPurchaseEditionGroup: Identifiable, Hashable, Sendable {
    public var id: String
    public var headline: String
    public var offers: [PhysicalPurchaseOffer]

    public init(id: String, headline: String, offers: [PhysicalPurchaseOffer]) {
        self.id = id
        self.headline = headline
        self.offers = offers
    }
}

public enum PhysicalPurchaseLinkBuilder {
    public static func hasOptions(for media: PhysicalMedia?) -> Bool {
        media?.hasDisplayableAvailability == true
    }

    public static func groups(
        for media: PhysicalMedia?,
        title: String,
        year: Int?
    ) -> [PhysicalPurchaseEditionGroup] {
        guard let media, media.hasDisplayableAvailability else { return [] }
        if !media.editions.isEmpty {
            return media.editions
                .sorted { $0.displayLine.localizedCaseInsensitiveCompare($1.displayLine) == .orderedAscending }
                .map { editionGroup(for: $0, title: title, year: year) }
        }
        return [flagGroup(for: media, title: title, year: year)]
    }

    /// One offer per retailer for compact menus (tvOS).
    public static func compactOffers(
        for media: PhysicalMedia?,
        title: String,
        year: Int?
    ) -> [PhysicalPurchaseOffer] {
        var seen = Set<PhysicalPurchaseRetailer>()
        var offers: [PhysicalPurchaseOffer] = []
        for group in groups(for: media, title: title, year: year) {
            for offer in group.offers where !seen.contains(offer.retailer) {
                seen.insert(offer.retailer)
                offers.append(offer)
            }
        }
        return offers
    }

    private static func editionGroup(
        for edition: PhysicalEdition,
        title: String,
        year: Int?
    ) -> PhysicalPurchaseEditionGroup {
        var offers: [PhysicalPurchaseOffer] = []
        if let shop = shopOffer(label: edition.label, title: title, idPrefix: edition.id) {
            offers.append(shop)
        }
        offers.append(contentsOf: marketplaceOffers(
            title: title,
            year: year,
            extras: extras(for: edition),
            idPrefix: edition.id
        ))
        return PhysicalPurchaseEditionGroup(
            id: edition.id,
            headline: edition.displayLine,
            offers: offers
        )
    }

    private static func flagGroup(
        for media: PhysicalMedia,
        title: String,
        year: Int?
    ) -> PhysicalPurchaseEditionGroup {
        var extras: [String] = []
        if media.hasCriterion { extras.append("Criterion") }
        if media.has4K {
            extras.append("4K")
            extras.append("Blu-ray")
        } else if media.hasBluRay {
            extras.append("Blu-ray")
        }

        var offers: [PhysicalPurchaseOffer] = []
        if media.hasCriterion, let shop = shopOffer(label: .criterion, title: title, idPrefix: "flags") {
            offers.append(shop)
        }
        offers.append(contentsOf: marketplaceOffers(
            title: title,
            year: year,
            extras: extras,
            idPrefix: "flags"
        ))

        let headline = media.badgeLabels.isEmpty
            ? "Disc"
            : media.badgeLabels.joined(separator: "   ")
        return PhysicalPurchaseEditionGroup(id: "flags", headline: headline, offers: offers)
    }

    private static func extras(for edition: PhysicalEdition) -> [String] {
        var parts: [String] = []
        if edition.label != .other {
            parts.append(edition.label.displayName)
        }
        switch edition.format {
        case .uhd4k:
            parts.append("4K")
            parts.append("Blu-ray")
        case .bluRay:
            parts.append("Blu-ray")
        case .dvd:
            parts.append("DVD")
        }
        return parts
    }

    private static func shopOffer(
        label: PhysicalLabel,
        title: String,
        idPrefix: String
    ) -> PhysicalPurchaseOffer? {
        let retailer: PhysicalPurchaseRetailer
        let template: String
        switch label {
        case .criterion:
            retailer = .criterion
            template = "https://www.criterion.com/search?q="
        case .arrow:
            retailer = .arrow
            template = "https://www.arrowvideo.com/search?q="
        case .shoutFactory:
            retailer = .shoutFactory
            template = "https://www.shoutfactory.com/search?q="
        case .kinoLorber:
            retailer = .kinoLorber
            template = "https://www.kinolorber.com/search?q="
        case .other:
            return nil
        }
        let query = encodeQuery(title)
        guard let url = URL(string: template + query) else { return nil }
        return PhysicalPurchaseOffer(
            id: "\(idPrefix)-\(retailer.rawValue)",
            retailer: retailer,
            title: retailer.displayName,
            kind: .search,
            url: url
        )
    }

    private static func marketplaceOffers(
        title: String,
        year: Int?,
        extras: [String],
        idPrefix: String
    ) -> [PhysicalPurchaseOffer] {
        let query = searchTerms(title: title, year: year, extras: extras)
        let encoded = encodeQuery(query)
        var offers: [PhysicalPurchaseOffer] = []
        if let amazon = URL(string: "https://www.amazon.com/s?k=\(encoded)&i=movies-tv") {
            offers.append(PhysicalPurchaseOffer(
                id: "\(idPrefix)-amazon",
                retailer: .amazon,
                title: PhysicalPurchaseRetailer.amazon.displayName,
                kind: .search,
                url: amazon
            ))
        }
        if let ebay = URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(encoded)") {
            offers.append(PhysicalPurchaseOffer(
                id: "\(idPrefix)-ebay",
                retailer: .ebay,
                title: PhysicalPurchaseRetailer.ebay.displayName,
                kind: .search,
                url: ebay
            ))
        }
        return offers
    }

    static func searchTerms(title: String, year: Int?, extras: [String]) -> String {
        var parts = [title.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let year {
            parts.append(String(year))
        }
        parts.append(contentsOf: extras)
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func encodeQuery(_ raw: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }
}
