import Foundation
import CryptoKit

struct Race: Identifiable, Codable, Hashable {
    let raceId: String
    let name: String
    let series: String
    let classification: String?
    let colloquialCategories: [String]?
    let discipline: String
    let raceType: String
    let startDate: String
    let endDate: String
    let startTimeLocal: String?
    let startTimezone: String?
    let startDatetimeUtc: String?
    let locationCountry: String?
    let locationCity: String?
    let organizer: String?
    let officialWebsite: String?
    let dataTimestamp: String?
    let genderDivision: String?
    /// Optional artwork/hero image URL for the race (e.g. for detail header or list thumbnail).
    let imageUrl: String?

    var id: String { raceId }

    var displayColloquialCategories: [String] {
        (colloquialCategories ?? []).map(Self.displayCategoryName)
    }

    var primaryDisplayColloquialCategory: String? {
        displayColloquialCategories.first
    }

    nonisolated private static func displayCategoryName(_ raw: String) -> String {
        switch raw {
        case "Monuments":
            return "Monument"
        default:
            return raw
        }
    }

    /// URL to use for race artwork: stored imageUrl if present, otherwise a deterministic placeholder (matches ingestion seed).
    var effectiveImageUrl: String? {
        if
            let imageUrl,
            !imageUrl.isEmpty,
            let url = URL(string: imageUrl),
            !isLikelyUnsupportedArtworkURL(url)
        {
            return imageUrl
        }
        let loc = [locationCity, locationCountry].compactMap { $0 }.filter { !$0.isEmpty }
        let seedStr = loc.isEmpty ? "\(name)|\(startDate)|\(discipline)" : loc.joined(separator: "|")
        guard let data = seedStr.data(using: .utf8) else { return nil }
        let hash = Insecure.MD5.hash(data: data)
        let hex = hash.prefix(6).map { String(format: "%02x", $0) }.joined()
        return "https://picsum.photos/seed/\(hex)/800/400"
    }

    nonisolated private func isLikelyUnsupportedArtworkURL(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "pdf" {
            return true
        }
        return url.absoluteString.lowercased().contains(".pdf")
    }

    /// Formatted date string, e.g. "January 12, 2026"
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: startDate) else { return startDate }
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct Team: Identifiable, Codable, Hashable {
    let teamId: String
    let name: String
    let uciCode: String?
    let discipline: String
    let region: String?
    let website: String?
    let socialHandles: [String: String]?
    let logoUrl: String?

    var id: String { teamId }
}

struct Athlete: Identifiable, Codable, Hashable {
    let athleteId: String
    let fullName: String
    let teamId: String?
    let nationality: String?
    let discipline: String?
    let dob: String?
    let socialHandles: [String: String]?

    var id: String { athleteId }
}

struct SearchResults: Codable, Hashable {
    let races: [Race]
    let teams: [Team]
    let athletes: [Athlete]
}

struct RaceParticipant: Codable, Hashable {
    let raceId: String
    let athleteId: String
    let teamId: String?
    let role: String?
}

struct Streamer: Identifiable, Codable, Hashable {
    let streamerId: String
    let name: String
    let slug: String
    let websiteUrl: String?

    var id: String { streamerId }
}

struct RaceStream: Codable, Hashable {
    let raceId: String
    let streamerId: String
    let regionCodes: [String]
    let streamUrl: String?
    let sourceUrl: String?
}

struct PodcastSource: Identifiable, Codable, Hashable {
    let sourceId: String
    let slug: String
    let name: String
    let feedUrl: String
    let websiteUrl: String?

    var id: String { sourceId }
}

struct PodcastEpisode: Identifiable, Codable, Hashable {
    let episodeId: String
    let sourceId: String
    let guid: String?
    let title: String
    let rawTitle: String?
    let description: String?
    let episodeUrl: String?
    let publishedAt: String?

    var id: String { episodeId }
}

struct RacePodcastEpisode: Codable, Hashable {
    let raceId: String
    let episodeId: String
    let matchedBy: String?
}

struct Stage: Identifiable, Codable, Hashable {
    let stageId: String
    let raceId: String
    let sourceStageId: String?
    let stageNumber: Int?
    let stageType: String?
    let name: String
    let date: String?
    let startLocation: String?
    let endLocation: String?
    let distanceKm: Double?
    let departTimeLocal: String?
    let departTimezone: String?
    let departDatetimeUtc: String?
    let isRestDay: Bool
    let sourceUrl: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { stageId }
}

struct StagePodcastEpisode: Codable, Hashable {
    let stageId: String
    let episodeId: String
    let matchedBy: String?
}

struct RaceResult: Identifiable, Codable, Hashable {
    let raceResultId: String
    let raceId: String
    let resultType: String
    let rank: Int
    let athleteName: String
    let teamName: String?
    let nationality: String?
    let resultText: String?
    let source: String
    let sourceUrl: String?
    let syncedAt: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { raceResultId }
}

struct StageResult: Identifiable, Codable, Hashable {
    let stageResultId: String
    let stageId: String
    let resultType: String
    let rank: Int
    let athleteName: String
    let teamName: String?
    let nationality: String?
    let resultText: String?
    let source: String
    let sourceUrl: String?
    let syncedAt: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { stageResultId }
}

struct RacePodcastEpisodeLink: Identifiable, Codable, Hashable {
    let episodeId: String
    let sourceId: String
    let sourceSlug: String?
    let sourceName: String
    let title: String
    let rawTitle: String?
    let description: String?
    let episodeUrl: String?
    let publishedAt: String?
    let matchedBy: String?

    var id: String { episodeId }
}

struct BootstrapPayload: Codable, Hashable {
    let races: [Race]
    let teams: [Team]
    let athletes: [Athlete]
    let participants: [RaceParticipant]
    let streamers: [Streamer]?
    let raceStreams: [RaceStream]?
    let podcastSources: [PodcastSource]?
    let podcastEpisodes: [PodcastEpisode]?
    let racePodcastEpisodes: [RacePodcastEpisode]?
    let stages: [Stage]?
    let stagePodcastEpisodes: [StagePodcastEpisode]?
    let raceResults: [RaceResult]?
    let stageResults: [StageResult]?
}

enum RaceSortOrder: String, CaseIterable, Hashable {
    case date = "Date"
    case alphabetical = "Alphabetical"
}

struct RaceFilters: Hashable {
    var startDate: String?
    var endDate: String?
    var series: String?
    var discipline: String?
    var raceType: String?
    var genderDivision: String?
    var classification: String?
    var streamerId: String?
    var limit: Int = 200
    var sortOrder: RaceSortOrder = .date
}
