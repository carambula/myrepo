import Foundation

actor RecommendationFeedbackStore {
    static let shared = RecommendationFeedbackStore()

    private static let storageKey = "recommendationFeedbackEventsV1"
    private static let maxEvents = 2000

    enum EventType: String, Codable {
        case suggestionImpression
        case suggestionTap
        case suggestionSearchConversion
        case queueEpisodeFinished
        case queueEpisodeSkipped
    }

    struct Event: Codable, Hashable {
        let id: String
        let type: EventType
        let value: String
        let context: String
        let createdAt: Date
    }

    private func loadEvents() -> [Event] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Event].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist(_ events: [Event]) {
        let trimmed = Array(events.suffix(Self.maxEvents))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func record(_ type: EventType, value: String, context: String) {
        var events = loadEvents()
        events.append(
            Event(
                id: UUID().uuidString,
                type: type,
                value: value,
                context: context,
                createdAt: Date()
            )
        )
        persist(events)
    }

    func recordSuggestionImpressions(_ suggestions: [String], context: String) {
        guard !suggestions.isEmpty else { return }
        record(.suggestionImpression, value: suggestions.joined(separator: " | "), context: context)
    }

    func recordSuggestionTap(_ suggestion: String, context: String) {
        record(.suggestionTap, value: suggestion, context: context)
    }

    func recordSuggestionConversion(_ suggestion: String, context: String) {
        record(.suggestionSearchConversion, value: suggestion, context: context)
    }

    func recordQueueOutcome(episodeID: String, completed: Bool, context: String) {
        record(completed ? .queueEpisodeFinished : .queueEpisodeSkipped, value: episodeID, context: context)
    }

    func recentEvents(limit: Int = 50) -> [Event] {
        Array(loadEvents().suffix(max(1, limit)))
    }

    nonisolated static func loadEventsSnapshot() -> [Event] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Event].self, from: data) else {
            return []
        }
        return decoded
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
