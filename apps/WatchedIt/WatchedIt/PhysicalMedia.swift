//
//  PhysicalMedia.swift
//  WatchedIt
//
//  Catalog-level physical edition availability (Criterion, 4K UHD, boutique labels).
//

import Foundation

public enum PhysicalLabel: String, Codable, CaseIterable, Sendable, Hashable {
    case criterion
    case arrow
    case shoutFactory
    case kinoLorber
    case other

    public var displayName: String {
        switch self {
        case .criterion: return "Criterion"
        case .arrow: return "Arrow"
        case .shoutFactory: return "Shout Factory"
        case .kinoLorber: return "Kino Lorber"
        case .other: return "Other"
        }
    }

    public var searchTokens: [String] {
        switch self {
        case .criterion: return ["criterion"]
        case .arrow: return ["arrow"]
        case .shoutFactory: return ["shout", "shout factory"]
        case .kinoLorber: return ["kino", "kino lorber"]
        case .other: return []
        }
    }
}

public enum PhysicalFormat: String, Codable, CaseIterable, Sendable, Hashable {
    case uhd4k
    case bluRay
    case dvd

    public var displayName: String {
        switch self {
        case .uhd4k: return "4K UHD"
        case .bluRay: return "Blu-ray"
        case .dvd: return "DVD"
        }
    }

    public var searchTokens: [String] {
        switch self {
        case .uhd4k: return ["4k", "uhd", "4k uhd"]
        case .bluRay: return ["bluray", "blu-ray"]
        case .dvd: return ["dvd"]
        }
    }
}

public struct PhysicalEdition: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: PhysicalLabel
    public var format: PhysicalFormat
    public var spineNumber: String?
    public var notes: String?

    public init(
        id: String = UUID().uuidString,
        label: PhysicalLabel,
        format: PhysicalFormat,
        spineNumber: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.label = label
        self.format = format
        self.spineNumber = spineNumber
        self.notes = notes
    }

    public var identityKey: String {
        [
            label.rawValue,
            format.rawValue,
            spineNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ].joined(separator: "|")
    }

    /// Metadata line using three ASCII spaces, e.g. "Criterion   4K UHD   Spine 42"
    public var displayLine: String {
        var parts: [String] = [label.displayName, format.displayName]
        if let spine = spineNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !spine.isEmpty {
            parts.append("Spine \(spine)")
        }
        if let notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            parts.append(notes)
        }
        return parts.joined(separator: "   ")
    }
}

public struct PhysicalMedia: Codable, Hashable, Sendable {
    public var editions: [PhysicalEdition]
    public var hasCriterion: Bool
    public var has4K: Bool
    public var hasBluRay: Bool
    public var manualOverride: Bool

    public init(
        editions: [PhysicalEdition] = [],
        hasCriterion: Bool = false,
        has4K: Bool = false,
        hasBluRay: Bool = false,
        manualOverride: Bool = false
    ) {
        self.editions = editions
        self.hasCriterion = hasCriterion
        self.has4K = has4K
        self.hasBluRay = hasBluRay
        self.manualOverride = manualOverride
        reconcileFlags()
    }

    public var isEmpty: Bool {
        !hasCriterion && !has4K && !hasBluRay && editions.isEmpty
    }

    public var hasDisplayableAvailability: Bool {
        hasCriterion || has4K || !editions.isEmpty
    }

    public var badgeLabels: [String] {
        var badges: [String] = []
        if hasCriterion { badges.append("Criterion") }
        if has4K { badges.append("4K") }
        return badges
    }

    public var searchTokens: [String] {
        var tokens = Set<String>()
        if hasCriterion { tokens.formUnion(PhysicalLabel.criterion.searchTokens) }
        if has4K { tokens.formUnion(PhysicalFormat.uhd4k.searchTokens) }
        if hasBluRay { tokens.formUnion(PhysicalFormat.bluRay.searchTokens) }
        for edition in editions {
            tokens.formUnion(edition.label.searchTokens)
            tokens.formUnion(edition.format.searchTokens)
        }
        return Array(tokens)
    }

    public mutating func reconcileFlags() {
        if editions.contains(where: { $0.label == .criterion }) {
            hasCriterion = true
        }
        if editions.contains(where: { $0.format == .uhd4k }) {
            has4K = true
        }
        if editions.contains(where: { $0.format == .bluRay || $0.format == .uhd4k }) {
            hasBluRay = true
        }
    }

    public func matchesSearchQuery(_ query: String) -> Bool {
        let lower = query.lowercased()
        return searchTokens.contains { token in
            lower == token || lower.contains(token)
        }
    }

    /// Manual overrides win. Otherwise union editions and OR the availability flags.
    public func merging(inferred: PhysicalMedia) -> PhysicalMedia {
        if manualOverride { return self }
        return Self.combined(self, inferred)
    }

    public static func combined(_ lhs: PhysicalMedia, _ rhs: PhysicalMedia) -> PhysicalMedia {
        var byKey: [String: PhysicalEdition] = [:]
        for edition in lhs.editions + rhs.editions {
            if byKey[edition.identityKey] == nil {
                byKey[edition.identityKey] = edition
            }
        }
        var merged = PhysicalMedia(
            editions: Array(byKey.values).sorted { $0.displayLine < $1.displayLine },
            hasCriterion: lhs.hasCriterion || rhs.hasCriterion,
            has4K: lhs.has4K || rhs.has4K,
            hasBluRay: lhs.hasBluRay || rhs.hasBluRay,
            manualOverride: lhs.manualOverride || rhs.manualOverride
        )
        merged.reconcileFlags()
        return merged
    }
}

// MARK: - Bundled overlay (ships catalog tags without regenerating SwiftData)

public struct PhysicalMediaOverlayFile: Codable, Sendable {
    public var byTmdbId: [String: PhysicalMedia]
}

public final class PhysicalMediaCatalog: @unchecked Sendable {
    public static let shared = PhysicalMediaCatalog()

    private var byTmdbId: [Int: PhysicalMedia] = [:]
    private var didLoad = false
    private let lock = NSLock()

    private init() {}

    public func media(forTmdbId tmdbId: Int?) -> PhysicalMedia? {
        guard let tmdbId else { return nil }
        loadIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        return byTmdbId[tmdbId]
    }

    public func resolvedMedia(stored: PhysicalMedia?, tmdbId: Int?) -> PhysicalMedia? {
        let overlay = media(forTmdbId: tmdbId)
        switch (stored, overlay) {
        case (nil, nil):
            return nil
        case (let stored?, nil):
            return stored.isEmpty ? nil : stored
        case (nil, let overlay?):
            return overlay.isEmpty ? nil : overlay
        case (let stored?, let overlay?):
            let merged = stored.merging(inferred: overlay)
            return merged.isEmpty ? nil : merged
        }
    }

    public func apply(to movieData: MovieData) {
        guard let overlay = media(forTmdbId: movieData.tmdbId), !overlay.isEmpty else { return }
        if let existing = movieData.physicalMedia {
            movieData.physicalMedia = existing.merging(inferred: overlay)
        } else {
            movieData.physicalMedia = overlay
        }
    }

    func loadIfNeeded() {
        lock.lock()
        if didLoad {
            lock.unlock()
            return
        }
        lock.unlock()

        guard let url = Self.overlayURL(),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PhysicalMediaOverlayFile.self, from: data) else {
            lock.lock()
            didLoad = true
            lock.unlock()
            return
        }

        var mapped: [Int: PhysicalMedia] = [:]
        mapped.reserveCapacity(file.byTmdbId.count)
        for (key, value) in file.byTmdbId {
            if let tmdbId = Int(key), !value.isEmpty {
                mapped[tmdbId] = value
            }
        }

        lock.lock()
        byTmdbId = mapped
        didLoad = true
        lock.unlock()
    }

    /// Test helper — replaces the in-memory overlay.
    public func replaceForTesting(_ overlay: [Int: PhysicalMedia]) {
        lock.lock()
        byTmdbId = overlay
        didLoad = true
        lock.unlock()
    }

    private static func overlayURL() -> URL? {
        if let url = Bundle.main.url(forResource: "physical_media", withExtension: "json") {
            return url
        }
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "physical_media", withExtension: "json")
        #else
        return nil
        #endif
    }
}
