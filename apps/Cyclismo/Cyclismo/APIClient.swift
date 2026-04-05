import Foundation
import CryptoKit

enum APIError: Error {
    case invalidURL
    case badResponse
}

final class APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "http://localhost:4000")!
    private let cacheTTL: TimeInterval = 300
    private var cache: [String: CacheEntry<Data>] = [:]
    private let cacheQueue = DispatchQueue(label: "APIClient.cache")
    private let diskCacheDirectory: URL

    private init() {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cachesDirectory.appendingPathComponent("CyclismoAPICache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    func fetchRaces(filters: RaceFilters) async throws -> [Race] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/races"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []

        if let startDate = filters.startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: startDate))
        }
        if let endDate = filters.endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: endDate))
        }
        if let series = filters.series {
            queryItems.append(URLQueryItem(name: "series", value: series))
        }
        if let discipline = filters.discipline {
            queryItems.append(URLQueryItem(name: "discipline", value: discipline))
        }
        if let raceType = filters.raceType {
            queryItems.append(URLQueryItem(name: "raceType", value: raceType))
        }
        if let gender = filters.genderDivision {
            queryItems.append(URLQueryItem(name: "gender", value: gender))
        }
        if let classification = filters.classification {
            queryItems.append(URLQueryItem(name: "classification", value: classification))
        }
        if let streamerId = filters.streamerId {
            queryItems.append(URLQueryItem(name: "streamerId", value: streamerId))
        }
        queryItems.append(URLQueryItem(name: "sortOrder", value: filters.sortOrder.rawValue.lowercased()))
        queryItems.append(URLQueryItem(name: "limit", value: String(filters.limit)))

        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw APIError.invalidURL }

        let races = try await fetchCachedWithFallback(url: url, decode: [Race].self) {
            let races = await BootstrapDataStore.shared.fetchRaces(filters: filters)
            return races.isEmpty ? nil : races
        }

        // If a stale/limited API response comes back empty, use local bootstrap data.
        if races.isEmpty {
            let localRaces = await BootstrapDataStore.shared.fetchRaces(filters: filters)
            if !localRaces.isEmpty {
                return localRaces
            }
        }

        return races
    }

    func fetchRace(id: String) async throws -> Race {
        let url = baseURL.appendingPathComponent("/races/\(id)")
        return try await fetchCachedWithFallback(url: url, decode: Race.self) {
            await BootstrapDataStore.shared.fetchRace(id: id)
        }
    }

    func fetchRacePodcasts(raceId: String) async throws -> [RacePodcastEpisodeLink] {
        let url = baseURL.appendingPathComponent("/races/\(raceId)/podcasts")
        return try await fetchCachedWithFallback(url: url, decode: [RacePodcastEpisodeLink].self) {
            await BootstrapDataStore.shared.fetchRacePodcasts(raceId: raceId)
        }
    }

    func fetchRacePodcasts(race: Race) async throws -> [RacePodcastEpisodeLink] {
        let url = baseURL.appendingPathComponent("/races/\(race.raceId)/podcasts")
        return try await fetchCachedWithFallback(url: url, decode: [RacePodcastEpisodeLink].self) {
            await BootstrapDataStore.shared.fetchRacePodcasts(
                raceId: race.raceId,
                raceName: race.name,
                raceStartDate: race.startDate
            )
        }
    }

    func fetchRaceStages(raceId: String) async throws -> [Stage] {
        let localStages = await BootstrapDataStore.shared.fetchRaceStages(raceId: raceId)
        if !localStages.isEmpty {
            return localStages
        }

        let url = baseURL.appendingPathComponent("/races/\(raceId)/stages")
        let stages = try await fetchCachedWithFallback(url: url, decode: [Stage].self) {
            await BootstrapDataStore.shared.fetchRaceStages(raceId: raceId)
        }
        return stages
    }

    func fetchRaceStages(race: Race) async throws -> [Stage] {
        let localStages = await BootstrapDataStore.shared.fetchRaceStages(
            raceId: race.raceId,
            raceName: race.name,
            raceStartDate: race.startDate
        )
        if !localStages.isEmpty {
            return localStages
        }
        return try await fetchRaceStages(raceId: race.raceId)
    }

    func fetchRaceResults(raceId: String) async throws -> [RaceResult] {
        let url = baseURL.appendingPathComponent("/races/\(raceId)/results")
        let results = try await fetchCachedWithFallback(url: url, decode: [RaceResult].self) {
            await BootstrapDataStore.shared.fetchRaceResults(raceId: raceId)
        }

        // If an empty response was cached earlier, retry live once.
        if results.isEmpty,
           let refreshed = try? await fetchFresh(url: url, decode: [RaceResult].self),
           !refreshed.isEmpty {
            return refreshed
        }

        return results
    }

    func fetchStage(id: String) async throws -> Stage {
        let url = baseURL.appendingPathComponent("/stages/\(id)")
        return try await fetchCachedWithFallback(url: url, decode: Stage.self) {
            await BootstrapDataStore.shared.fetchStage(id: id)
        }
    }

    func fetchStagePodcasts(stageId: String) async throws -> [RacePodcastEpisodeLink] {
        let url = baseURL.appendingPathComponent("/stages/\(stageId)/podcasts")
        return try await fetchCachedWithFallback(url: url, decode: [RacePodcastEpisodeLink].self) {
            await BootstrapDataStore.shared.fetchStagePodcasts(stageId: stageId)
        }
    }

    func fetchStageResults(stageId: String) async throws -> [StageResult] {
        let url = baseURL.appendingPathComponent("/stages/\(stageId)/results")
        let results = try await fetchCachedWithFallback(url: url, decode: [StageResult].self) {
            await BootstrapDataStore.shared.fetchStageResults(stageId: stageId)
        }

        // If an empty response was cached earlier, retry live once.
        if results.isEmpty,
           let refreshed = try? await fetchFresh(url: url, decode: [StageResult].self),
           !refreshed.isEmpty {
            return refreshed
        }

        return results
    }

    func fetchTeam(id: String) async throws -> Team {
        let url = baseURL.appendingPathComponent("/teams/\(id)")
        return try await fetchCachedWithFallback(url: url, decode: Team.self) {
            await BootstrapDataStore.shared.fetchTeam(id: id)
        }
    }

    func fetchTeamRaces(id: String, upcomingOnly: Bool = true) async throws -> [Race] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/teams/\(id)/races"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "upcoming", value: upcomingOnly ? "true" : "false")
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        return try await fetchCachedWithFallback(url: url, decode: [Race].self) {
            let races = await BootstrapDataStore.shared.fetchTeamRaces(id: id, upcomingOnly: upcomingOnly)
            return races.isEmpty ? nil : races
        }
    }

    func fetchAthlete(id: String) async throws -> Athlete {
        let url = baseURL.appendingPathComponent("/athletes/\(id)")
        return try await fetchCachedWithFallback(url: url, decode: Athlete.self) {
            await BootstrapDataStore.shared.fetchAthlete(id: id)
        }
    }

    func fetchAthleteRaces(id: String, upcomingOnly: Bool = true) async throws -> [Race] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/athletes/\(id)/races"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "upcoming", value: upcomingOnly ? "true" : "false")
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        return try await fetchCachedWithFallback(url: url, decode: [Race].self) {
            let races = await BootstrapDataStore.shared.fetchAthleteRaces(id: id, upcomingOnly: upcomingOnly)
            return races.isEmpty ? nil : races
        }
    }

    func search(query: String) async throws -> SearchResults {
        var components = URLComponents(url: baseURL.appendingPathComponent("/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { throw APIError.invalidURL }

        return try await fetchCachedWithFallback(url: url, decode: SearchResults.self) {
            await BootstrapDataStore.shared.search(query: query)
        }
    }

    func clearCache() {
        cacheQueue.sync {
            cache.removeAll()
            try? FileManager.default.removeItem(at: diskCacheDirectory)
            try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        }
        Task {
            await UnifiedDataCache.shared.clear()
        }
    }

    private func fetchCached<T: Decodable>(url: URL, decode type: T.Type) async throws -> T {
        let cacheKey = url.absoluteString
        if let cached = cachedData(for: cacheKey) {
            return try JSONDecoder.cyclismo.decode(T.self, from: cached)
        }
        if let cached = diskCachedData(for: cacheKey) {
            cacheData(cached, for: cacheKey)
            return try JSONDecoder.cyclismo.decode(T.self, from: cached)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.badResponse }
        cacheData(data, for: cacheKey)
        storeDiskCache(data, for: cacheKey)
        return try JSONDecoder.cyclismo.decode(T.self, from: data)
    }

    private func fetchCachedWithFallback<T: Decodable>(
        url: URL,
        decode type: T.Type,
        fallback: () async -> T?
    ) async throws -> T {
        do {
            return try await fetchCached(url: url, decode: T.self)
        } catch {
            if let local = await fallback() {
                return local
            }
            throw error
        }
    }

    private func fetchFresh<T: Decodable>(url: URL, decode type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.badResponse }
        let cacheKey = url.absoluteString
        cacheData(data, for: cacheKey)
        storeDiskCache(data, for: cacheKey)
        return try JSONDecoder.cyclismo.decode(T.self, from: data)
    }

    private func cachedData(for key: String) -> Data? {
        cacheQueue.sync {
            guard let entry = cache[key], entry.expiry > Date() else {
                cache[key] = nil
                return nil
            }
            return entry.value
        }
    }

    private func cacheData(_ data: Data, for key: String) {
        let entry = CacheEntry(value: data, expiry: Date().addingTimeInterval(cacheTTL))
        cacheQueue.sync {
            cache[key] = entry
        }
    }

    private func diskCachedData(for key: String) -> Data? {
        cacheQueue.sync {
            let url = diskCacheURL(for: key)
            guard let data = try? Data(contentsOf: url) else { return nil }
            guard let entry = try? JSONDecoder().decode(DiskCacheEntry.self, from: data) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            guard entry.expiry > Date() else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return entry.value
        }
    }

    private func storeDiskCache(_ data: Data, for key: String) {
        let entry = DiskCacheEntry(value: data, expiry: Date().addingTimeInterval(cacheTTL))
        guard let encoded = try? JSONEncoder().encode(entry) else { return }
        let url = diskCacheURL(for: key)
        cacheQueue.sync {
            try? encoded.write(to: url, options: [.atomic])
        }
    }

    private func diskCacheURL(for key: String) -> URL {
        let hashedKey = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return diskCacheDirectory.appendingPathComponent(hashedKey).appendingPathExtension("json")
    }
}

extension JSONDecoder {
    static let cyclismo: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

private struct CacheEntry<Value> {
    let value: Value
    let expiry: Date
}

private struct DiskCacheEntry: Codable {
    let value: Data
    let expiry: Date
}

actor UnifiedDataCache {
    static let shared = UnifiedDataCache()

    private let cacheDirectory: URL
    private var memory: [String: DiskCacheEntry] = [:]
    private var inFlight: [String: Task<Data, Error>] = [:]

    init() {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("CyclismoUnifiedCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func data(for request: URLRequest, cacheKey: String? = nil, ttl: TimeInterval) async throws -> Data {
        let key = cacheKey ?? defaultCacheKey(for: request)
        let now = Date()

        if let entry = memory[key], entry.expiry > now {
            return entry.value
        }

        let diskEntry = await diskEntry(for: key)
        if let diskEntry, diskEntry.expiry > now {
            memory[key] = diskEntry
            return diskEntry.value
        }

        let staleData = diskEntry?.value ?? memory[key]?.value

        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task<Data, Error> {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw APIError.badResponse
                }
                let entry = DiskCacheEntry(value: data, expiry: Date().addingTimeInterval(ttl))
                await store(entry, for: key)
                return data
            } catch {
                if let staleData {
                    return staleData
                }
                throw error
            }
        }

        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    func clear() {
        memory.removeAll()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func store(_ entry: DiskCacheEntry, for key: String) async {
        memory[key] = entry
        guard let encoded = await MainActor.run(body: { try? JSONEncoder().encode(entry) }) else { return }
        let fileURL = cacheFileURL(for: key)
        try? encoded.write(to: fileURL, options: [.atomic])
    }

    private func diskEntry(for key: String) async -> DiskCacheEntry? {
        let fileURL = cacheFileURL(for: key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let entry = await MainActor.run(body: { try? JSONDecoder().decode(DiskCacheEntry.self, from: data) }) else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return entry
    }

    private func cacheFileURL(for key: String) -> URL {
        let hashedKey = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheDirectory.appendingPathComponent(hashedKey).appendingPathExtension("json")
    }

    private func defaultCacheKey(for request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        if let body = request.httpBody, !body.isEmpty {
            let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
            return "\(method):\(url):\(bodyHash)"
        }
        return "\(method):\(url)"
    }
}
